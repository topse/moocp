// Die Regeln der Wiederherstellung ohne Netz: Prüfung der Sicherungsdatei
// (.mbz), Zustände und erlaubte Übergänge. Gespeichert wird in wiederherstellung.dart.
//
// Die Prüfung läuft vor dem Hochladen. Sie liest das Archiv selbst (Tar-Köpfe
// Feld für Feld) statt einem Entpacker zu vertrauen: jede Eintragsart, jeder
// Pfad und jede Größe wird einzeln geprüft. Nutzerdaten im Archiv lehnt sie ab
// (A1); die Fehlertexte nennen nie Inhalte aus dem Archiv (E11).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'elemente.dart' show codeImText, codeInDatei, elementFehler, hatKopf, istElementdatei;
import 'moodle_zugang.dart' show MoodleZugang, MoodleFehler;
import 'sicherung_regeln.dart' show nutzerdatenOptionen;
import 'wiederherstellung_fragen.dart' show QuizFrage, quizFragenAusXml;

/// Obergrenze für eine Sicherung. Fest 200 MB; der Wert aus dem Upload-Formular
/// (maxbytes) wird nicht gelesen. Sie gilt für alles, was aus dem Sicherungsordner
/// kommt, und schon für das Herunterladen (`MoodleZugang.herunterladen` setzt sie
/// während des Ladens durch, nicht erst danach).
const int archivGrenzeStandard = 200 * 1024 * 1024;

/// Die Prüfung liest das Archiv ganz in den Speicher, der Upload (`readAsBytes`)
/// ebenso; ob das auf schwachen Rechnern trägt, ist ungemessen (ein Strom wäre
/// die Alternative). Unterstützt wird nur .tar.gz (.mbz), ZIP lehnt die Prüfung ab.
/// Die drei folgenden Grenzen sind Schätzwerte, nicht gemessen.
///
/// Obergrenze für den entpackten Inhalt (Schutz vor Gzip-Bomben).
const int entpacktGrenzeStandard = 1024 * 1024 * 1024;

/// Obergrenze für die Zahl der Einträge im Archiv.
const int eintragGrenzeStandard = 20000;

/// Das Verhältnis entpackt zu gepackt, ab dem das Archiv als verdächtig gilt.
const int verhaeltnisGrenze = 200;

/// Was mit der Sichtbarkeit der wiederhergestellten Inhalte geschieht. Eine
/// Vorgabe gibt es nicht ([aus] fragt zurück): Bei moocp ist sonst alles Neue
/// zunächst verborgen (A3), und „wie Quelle" macht Inhalte auf der Stufe „keine"
/// ohne jede Freigabe sofort für Lernende sichtbar. „Verborgen" wiederum
/// verändert die Unterrichtseinheit gegenüber der Quelle. Beides riskiert
/// etwas, also entscheidet die Lehrkraft (oder eine Kursseite CLAUDE.md, A7).
enum WiederherstellungsSichtbarkeit {
  wieQuelle('wie_quelle'),
  verborgen('verborgen');

  const WiederherstellungsSichtbarkeit(this.wert);
  final String wert;

  String get freigabe => this == wieQuelle
      ? 'Sichtbarkeit: wie Quelle. Sichtbarkeit und Voraussetzungen der Sicherung bleiben unverändert; '
          'Inhalte können sofort für Lernende sichtbar sein. Sichtbarkeit und Voraussetzungen werden nicht gegengeprüft.'
      : 'Sichtbarkeit: verborgen. Die App verbirgt die eindeutig zugeordneten neuen Aktivitäten nach der '
          'Wiederherstellung. Sie können kurzzeitig sichtbar sein. Voraussetzungen bleiben unverändert. '
          'Verborgen ist kein Schutz vor Personen mit Bearbeitungsrechten.';

  /// Die Rückfrage, wenn die Angabe fehlt. Sie geht an die Lehrkraft, nicht an
  /// die KI: Die KI wählt nicht an ihrer Stelle.
  static const String rueckfrage =
      'Die Angabe sichtbarkeit fehlt (wie_quelle oder verborgen). Frag die Lehrkraft, ob die wiederhergestellten '
      'Inhalte wie in der Quelle sichtbar bleiben oder verborgen werden sollen; eine Kursseite CLAUDE.md kann einen '
      'Vorschlag machen, den der Plan nennt. Nichts geändert.';

  /// Wirft die Rückfrage ([MoodleFehler]) bei fehlender oder unbekannter Angabe;
  /// aufgerufen vor der ersten Anfrage an Moodle.
  static WiederherstellungsSichtbarkeit aus(String? wert) => switch (wert) {
    'wie_quelle' => wieQuelle,
    'verborgen' => verborgen,
    null => throw MoodleFehler(rueckfrage),
    _ => throw MoodleFehler('sichtbarkeit muss wie_quelle oder verborgen sein. Nichts geändert.'),
  };
}

/// Der Stand einer Wiederherstellung, in vorgaenge.json als wiederherstellung_status.
enum WiederherstellungStand {
  /// Angelegt, noch nichts bei Moodle geändert.
  anstehend,

  /// Die Datei liegt im Entwurfsbereich der Lehrkraft.
  hochgeladen,

  /// Moodle hat die Wiederherstellung angenommen; sie läuft im Hintergrund.
  laufend,

  /// Moodle meldet Ende, und der Kurs ist gegengelesen.
  fertig,

  /// Vor dem Start abgebrochen oder von Moodle abgelehnt. Im Kurs ist nichts geändert.
  fehlgeschlagen,

  /// Ob Moodle die Wiederherstellung ausgeführt hat, ist nicht bekannt. Nie blind wiederholen.
  unklar;

  String get text => switch (this) {
        anstehend => 'anstehend',
        hochgeladen => 'hochgeladen',
        laufend => 'laufend',
        fertig => 'fertig',
        fehlgeschlagen => 'fehlgeschlagen',
        unklar => 'unklar',
      };

  static WiederherstellungStand? aus(String? s) {
    for (final v in values) {
      if (v.name == s) return v;
    }
    return null;
  }
}

/// Die erlaubten Übergänge. Ein Vorgang, der fertig oder fehlgeschlagen ist,
/// bewegt sich nicht mehr. „unklar" löst sich nur durch Gegenlesen auf.
bool erlaubterUebergang(WiederherstellungStand von, WiederherstellungStand nach) => switch (von) {
      WiederherstellungStand.anstehend =>
        nach == WiederherstellungStand.hochgeladen || nach == WiederherstellungStand.fehlgeschlagen,
      WiederherstellungStand.hochgeladen =>
        nach == WiederherstellungStand.laufend || nach == WiederherstellungStand.fehlgeschlagen,
      WiederherstellungStand.laufend => nach == WiederherstellungStand.fertig ||
          nach == WiederherstellungStand.fehlgeschlagen ||
          nach == WiederherstellungStand.unklar,
      WiederherstellungStand.unklar => nach == WiederherstellungStand.fertig ||
          nach == WiederherstellungStand.fehlgeschlagen ||
          nach == WiederherstellungStand.unklar,
      WiederherstellungStand.fertig || WiederherstellungStand.fehlgeschlagen => false,
    };

/// Eine Aktivität aus dem Archiv, für die Freigabe: Art und Titel.
typedef ArchivAktivitaet = ({String modul, String titel});

typedef WiederhergestellteAktivitaet = ({int cmid, String modul, String titel});

/// Liefert cmids nur bei einer eindeutigen 1:1-Zuordnung zum geprüften Archiv.
List<int>? importierteCmidsEindeutig({required List<ArchivAktivitaet> erwartet, required Set<int> vorher,
  required List<WiederhergestellteAktivitaet> aktuell}) {
  if (erwartet.isEmpty) return null;
  final neu = aktuell.where((a) => !vorher.contains(a.cmid)).toList();
  if (neu.length != erwartet.length) return null;
  final erwartete = erwartet.map((a) => '${a.modul}\u0000${a.titel}').toSet();
  final aktuelle = neu.map((a) => '${a.modul}\u0000${a.titel}').toList();
  if (erwartete.length != erwartet.length || aktuelle.toSet().length != aktuelle.length ||
      !erwartete.containsAll(aktuelle) || !aktuelle.toSet().containsAll(erwartete)) {
    return null;
  }
  return [for (final a in neu) a.cmid];
}

/// Ergebnis der Prüfung. [grund] ist null, wenn das Archiv angenommen ist.
class ArchivBefund {
  const ArchivBefund({
    this.grund,
    this.nutzerdaten = false,
    this.moodleVersion,
    this.typ,
    this.aktivitaeten = const [],
    this.quizFragen = const {},
    this.quizUnlesbar = const {},
    this.quizTitel = const {},
    this.code = const [],
    this.ungeprueft = const [],
  });
  final String? grund;

  /// Der Grund der Ablehnung sind Nutzerdaten (nicht ein beschädigtes oder zu
  /// großes Archiv, nicht Code): Nur dann löscht die Sicherung die Datei wieder
  /// (sicherung.dart).
  final bool nutzerdaten;
  final String? moodleVersion;

  /// „activity" oder „course", wie Moodle es im Archiv nennt.
  final String? typ;
  final List<ArchivAktivitaet> aktivitaeten;

  /// Fragen je Quiz (Ordnername wie quiz_21), aus quiz.xml und questions.xml.
  final Map<String, List<QuizFrage>> quizFragen;

  /// Quizze, deren quiz.xml oder questions.xml nicht lesbar ist: kein Abbruch
  /// des Archivs, sondern eine Prüflücke bei der Herkunft.
  final Set<String> quizUnlesbar;

  /// Titel je Quiz-Ordner (quiz_21), aus moodle_backup.xml. Fehlt der Ordner dort, fehlt der Eintrag.
  final Map<String, String> quizTitel;

  /// Stellen im Archiv, an denen Code am abgeschotteten Rahmen vorbei liefe (E22),
  /// je als Pfad im Archiv und Art, nie mit Text daraus (E11). Bei
  /// `codeAblehnen: false` steht hier der Befund, ohne dass das Archiv abgelehnt wird.
  final List<String> code;

  /// Die Aktivitätsarten im Archiv, deren Dateiaufbau die Prüfung nicht kennt und die Eingaben
  /// von Lernenden tragen können: Für sie sagt die Prüfung nichts ([archivUngepruefteArten]).
  final List<String> ungeprueft;

  bool get ok => grund == null;
}

/// Der Hinweis zu dem, was die Prüfung nicht liest: In `files.xml` und
/// `questions.xml` stehen auch in einer Sicherung ohne Nutzerdaten Kennungen der
/// Lehrkraft, die die Datei hochgeladen oder die Frage geschrieben hat (`userid`,
/// `author`, `createdby`, `modifiedby`), und Kalender-, Badge- und Kompetenzdateien
/// können solche tragen. Das sind keine Daten von Lernenden. Die App liest sie nicht
/// aus (A1) und kann deshalb nicht sagen, dass keine Namen darin stehen.
const archivAutorenHinweis =
    'Die Datei kann Namen und Kennungen von Autorinnen und Autoren enthalten, etwa bei Dateien und Fragen.';

/// Was die Prüfung eines Archivs geprüft hat und was nicht, für Freigabe und Bericht.
/// [ungeprueft] ist [ArchivBefund.ungeprueft]. „Geprüft" meint hier: nach den Dateien
/// und Elementen, die Moodle dafür anlegt -- nach dem Quelltext von Moodle, an echten
/// Sicherungen nicht gemessen (UNGEMESSEN).
String archivPruefbericht(List<String> ungeprueft) =>
    'Auf Nutzerdaten geprüft: die Einstellungen der Sicherung; Teilnehmende, Einschreibungen, Rollen, Bewertungen, '
    'Kommentare, Abschluss, Gruppen und Protokolle; Beiträge und Einträge von Lernenden in Foren, Glossaren, '
    'Datenbanken, Wikis, Aufgaben, Tests, Auswahl, Feedback, Lektionen, Workshops, Chats, Journalen, H5P-Aktivitäten '
    'und SCORM. Nicht geprüft: '
    '${ungeprueft.isEmpty ? '' : 'Eingaben von Lernenden in ${ungeprueft.join(', ')}; '}'
    'alles, was Moodle in anderen Dateien ablegt, als die App kennt. $archivAutorenHinweis';

/// Prüft eine Sicherungsdatei vollständig, bevor sie hochgeladen wird -- und
/// nach dem Herunterladen, bevor die App sie als geprüft meldet.
/// [maxBytes] gilt für die gepackte Größe, [maxEntpackt] für den Inhalt.
/// [codeAblehnen]: Code am Rahmen vorbei (E22) lehnt das Archiv ab. Die
/// Sicherung schaltet es aus: Sie legt nichts an, sondern meldet nur, dass das
/// Wiederherstellen das Archiv ablehnen würde.
Future<ArchivBefund> archivPruefen(
  Uint8List bytes, {
  int maxBytes = archivGrenzeStandard,
  int maxEntpackt = entpacktGrenzeStandard,
  int maxEintraege = eintragGrenzeStandard,
  bool codeAblehnen = true,
}) async {
  ArchivBefund nein(String g, {bool nutzerdaten = false}) => ArchivBefund(grund: g, nutzerdaten: nutzerdaten);
  if (bytes.length > maxBytes) return nein('Die Datei ist größer als die erlaubten ${maxBytes ~/ (1024 * 1024)} MB.');
  if (bytes.length < 18 || bytes[0] != 0x1f || bytes[1] != 0x8b) {
    return nein('Keine gepackte Sicherung (.mbz mit gzip-Tar). Andere Formate werden nicht angenommen.');
  }

  // Entpacken mit Obergrenze: beim Überschreiten bricht der Strom ab, bevor
  // der Speicher voll ist.
  final out = BytesBuilder(copy: false);
  var n = 0;
  try {
    await for (final stueck in gzip.decoder.bind(Stream.value(bytes))) {
      n += stueck.length;
      if (n > maxEntpackt) return nein('Der entpackte Inhalt ist zu groß.');
      if (n > 10 * 1024 * 1024 && n > verhaeltnisGrenze * bytes.length) {
        return nein('Das Verhältnis von gepackter zu entpackter Größe ist verdächtig.');
      }
      out.add(stueck);
    }
  } on FormatException {
    return nein('Die Sicherung ist beschädigt (gzip).');
  }
  final tar = out.takeBytes();

  // Tar Feld für Feld.
  final dateien = <String, Uint8List>{};
  var pos = 0;
  var eintraege = 0;
  while (pos + 512 <= tar.length) {
    final kopf = Uint8List.sublistView(tar, pos, pos + 512);
    if (kopf.every((b) => b == 0)) break;
    if (!_kopfOk(kopf)) return nein('Die Sicherung ist beschädigt (Tar-Kopf).');
    eintraege++;
    if (eintraege > maxEintraege) return nein('Das Archiv hat zu viele Einträge.');

    final typ = kopf[156];
    final ustar = _text(kopf, 257, 263) == 'ustar';
    final name = _text(kopf, 0, 100);
    final pfad = ustar && _text(kopf, 345, 500).isNotEmpty ? '${_text(kopf, 345, 500)}/$name' : name;
    final groesse = _oktal(kopf, 124, 136);
    if (groesse == null) return nein('Die Sicherung ist beschädigt (Größe im Tar-Kopf).');

    // Nur einfache Dateien und Ordner. Links, Geräte und Erweiterungsköpfe
    // (verlängerte Namen) lehnt die Prüfung ab, weil sie aus dem Zielordner
    // hinausführen oder Inhalte verbergen können.
    final istDatei = typ == 0x30 || typ == 0x00 || typ == 0x37;
    final istOrdner = typ == 0x35;
    if (!istDatei && !istOrdner) {
      if (typ == 0x78 || typ == 0x67 || typ == 0x4c || typ == 0x4b) {
        return nein('Das Archiv nutzt verlängerte Namen; nicht angenommen.');
      }
      return nein('Das Archiv enthält Links oder Sonderdateien; nicht angenommen.');
    }
    final fehler = pfadFehler(pfad);
    if (fehler != null) return nein('Unsicherer Pfad im Archiv ($fehler).');

    final anfang = pos + 512;
    final ende = anfang + groesse;
    if (ende > tar.length) return nein('Die Sicherung ist abgeschnitten.');
    // Ansichten auf das entpackte Archiv, keine Kopien: Die Inhaltsprüfungen
    // unten lesen nur die Dateien, die sie brauchen.
    if (istDatei) dateien[pfad] = Uint8List.sublistView(tar, anfang, ende);
    if (istDatei) {
      // Nutzerdaten erkennt der Name, bevor der Inhalt zählt.
      if (nutzerdatenPfad(pfad)) {
        return nein('Das Archiv enthält Nutzerdaten (Pfad); nicht angenommen.', nutzerdaten: true);
      }
    }
    pos = anfang + ((groesse + 511) ~/ 512) * 512;
  }
  if (!dateien.containsKey('moodle_backup.xml')) {
    return nein('Im Archiv fehlt moodle_backup.xml: keine Moodle-Sicherung.');
  }

  // Die Beschreibung des Archivs.
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(utf8.decode(dateien['moodle_backup.xml']!, allowMalformed: true));
  } on XmlException {
    return nein('moodle_backup.xml ist nicht lesbar.');
  }
  final format = _text1(doc, 'format');
  if (format != 'moodle2') return nein('Kein Moodle-2-Archiv (Format ${format ?? 'unbekannt'}).');
  final typ = _text1(doc, 'type');
  if (typ != 'activity' && typ != 'course') return nein('Unbekannter Sicherungstyp.');

  // Nutzerdaten-Einstellungen müssen aus sein.
  for (final s in doc.findAllElements('setting')) {
    final name = s.getElement('name')?.innerText.trim() ?? '';
    final wert = s.getElement('value')?.innerText.trim() ?? '';
    final nutzer = nutzerdatenOptionen.contains(name) || name.endsWith('_userinfo');
    if (nutzer && wert != '0') {
      return nein('Die Sicherung enthält Nutzerdaten (Einstellung $name); nicht angenommen.', nutzerdaten: true);
    }
  }

  // Einträge zu Personen in den Dateien, die Moodle dafür anlegt, und Beiträge
  // von Lernenden in den Aktivitäten.
  final personen = _personenInDateien(dateien);
  if (personen != null) return nein(personen, nutzerdaten: true);

  final aktivitaeten = <ArchivAktivitaet>[
    for (final a in archivAktivitaetsElemente(doc))
      (modul: a.getElement('modulename')?.innerText.trim() ?? '', titel: a.getElement('title')?.innerText.trim() ?? ''),
  ];

  final quizTitel = <String, String>{
    for (final a in archivAktivitaetsElemente(doc))
      if (a.getElement('modulename')?.innerText.trim() == 'quiz' &&
          (a.getElement('directory')?.innerText.trim() ?? '').isNotEmpty)
        a.getElement('directory')!.innerText.trim().split('/').last: a.getElement('title')?.innerText.trim() ?? '',
  };

  // Fragen der Quizze. Lesbar nur, wenn beide Dateien es sind.
  final fragenXml = dateien['questions.xml'] == null ? null : utf8.decode(dateien['questions.xml']!, allowMalformed: true);
  final quizFragen = <String, List<QuizFrage>>{};
  final quizUnlesbar = <String>{};
  for (final e in dateien.entries) {
    final ordner = _quizOrdner(e.key);
    if (ordner == null) continue;
    try {
      quizFragen[ordner] = quizFragenAusXml(utf8.decode(e.value, allowMalformed: true), fragenXml);
    } on XmlException {
      quizUnlesbar.add(ordner);
    }
  }
  // Code am abgeschotteten Rahmen vorbei (E22): dieselben Regeln wie beim
  // Schreiben, auf alles, was die Wiederherstellung anlegen würde.
  final code = _codeImArchiv(dateien);
  final ungeprueft = archivUngepruefteArten(aktivitaeten.map((a) => a.modul));
  if (code.isNotEmpty && codeAblehnen) {
    return ArchivBefund(
      grund: 'Das Archiv enthält Code, der am abgeschotteten Rahmen vorbei in der Sitzung jedes Betrachters '
          'liefe (E22): ${code.take(5).join('; ')}${code.length > 5 ? '; und ${code.length - 5} weitere' : ''}. '
          'moocp legt so etwas nicht an. Interaktives gehört als Element in einen abgeschotteten Rahmen.',
      code: code,
      ungeprueft: ungeprueft,
    );
  }
  return ArchivBefund(
    moodleVersion: _text1(doc, 'moodle_version'),
    typ: typ,
    aktivitaeten: aktivitaeten,
    quizFragen: quizFragen,
    quizUnlesbar: quizUnlesbar,
    quizTitel: quizTitel,
    code: code,
    ungeprueft: ungeprueft,
  );
}

/// Dateien, die Einträge zu Personen führen (Basisname, gleich in welchem Ordner
/// des Archivs), und das Muster, das so einen Eintrag erkennt. Leere Platzhalter
/// sind in Ordnung (auch das Wurzelelement grade_history, gemessen an einer
/// Sicherung ohne Nutzerdaten), Einträge zu Personen nicht. Gemessen ist nur
/// der erste Teil der Liste (grades, grade_history, roles am Wurzelordner); der
/// Rest folgt den Elementnamen aus dem Quelltext von Moodle (UNGEMESSEN): Jeder
/// Eintrag in diesen Dateien gehört dort zu einer Person, und ohne `users` legt
/// Moodle sie leer an.
///
/// Bewusst nicht dabei, weil sie auch Kennungen der Lehrkraft tragen: files.xml,
/// questions.xml, calendar.xml und contentbank.xml ([archivAutorenHinweis]).
final Map<String, RegExp> _personenDateien = {
  'grades.xml': RegExp(r'<(grade_grade|role_assignment|userid)\b'),
  'grade_history.xml': RegExp(r'<(grade_grade|role_assignment|userid)\b'),
  'roles.xml': RegExp(r'<(grade_grade|role_assignment|userid)\b'),
  'gradebook.xml': RegExp(r'<(grade_grade|userid)\b'),
  'comments.xml': RegExp(r'<(comment|userid)\b'),
  'logs.xml': RegExp(r'<(log|userid)\b'),
  'completion.xml': RegExp(r'<userid\b'),
  'enrolments.xml': RegExp(r'<(enrolment|userid)\b'),
  'groups.xml': RegExp(r'<userid\b'),
  'badges.xml': RegExp(r'<userid\b'),
  'competency.xml': RegExp(r'<(user_competency|user_evidence|userid)'),
  'competencies.xml': RegExp(r'<(user_competency|user_evidence|userid)'),
};

/// Die Elemente, die in der Hauptdatei einer Aktivität (`activities/<art>_<n>/<art>.xml`)
/// Beiträge, Einträge oder Abgaben von Lernenden sind, je Aktivitätsart. Ohne
/// Nutzerdaten legt Moodle diese Elemente nicht an (UNGEMESSEN, nach dem Quelltext der
/// Sicherung der Aktivität); ein Treffer lehnt das Archiv ab, ein Fehlen belegt nichts.
/// Andere Arten stehen nicht darin und erscheinen als [archivUngepruefteArten].
const Map<String, Set<String>> lernendenEintraege = {
  'forum': {'discussion', 'post'},
  'glossary': {'entry'},
  'data': {'record'},
  'wiki': {'subwiki'},
  'assign': {'submission'},
  'quiz': {'attempt'},
  'choice': {'answer'},
  'feedback': {'completed'},
  'lesson': {'attempt'},
  'workshop': {'submission'},
  'chat': {'message'},
  'journal': {'entry'},
  'h5pactivity': {'attempt'},
  'scorm': {'sco_track'},
};

String _basisname(String pfad) => pfad.substring(pfad.lastIndexOf('/') + 1);

final RegExp _aktivitaetsDatei = RegExp(r'^activities/([^/]+)_\d+/\1\.xml$');

/// Der Grund, aus dem ein Archiv wegen Einträgen zu Personen abgelehnt wird, oder
/// null. Der Grund nennt Dateien und Elementnamen, nie Inhalte (E11).
String? _personenInDateien(Map<String, Uint8List> dateien) {
  for (final e in dateien.entries) {
    final pfad = e.key;
    if (pfad.startsWith('files/')) continue;
    final muster = _personenDateien[_basisname(pfad)];
    if (muster != null && muster.hasMatch(utf8.decode(e.value, allowMalformed: true))) {
      return 'Die Sicherung enthält Bewertungen, Rollen oder andere Einträge von Personen '
          '(${_basisname(pfad)}); nicht angenommen.';
    }
    final art = _aktivitaetsDatei.firstMatch(pfad)?.group(1);
    final namen = art == null ? null : lernendenEintraege[art];
    if (namen == null) continue;
    final text = utf8.decode(e.value, allowMalformed: true);
    var gefunden = false;
    try {
      final doc = XmlDocument.parse(text);
      gefunden = namen.any((n) => doc.findAllElements(n).isNotEmpty);
    } on XmlException {
      // Eine Datei, die sich nicht als XML lesen lässt (bei Quizzen eine Prüflücke der Herkunft, kein
      // Grund, das Archiv abzulehnen), wird am Rohtext geprüft: Ein Element dieses Namens steht dort
      // auch in kaputtem XML als `<name ` oder `<name>`.
      gefunden = RegExp('<(?:${namen.join('|')})' r'[\s>/]').hasMatch(text);
    }
    if (gefunden) {
      return 'Die Sicherung enthält Beiträge, Einträge oder Abgaben von Lernenden (Aktivitätsart $art); '
          'nicht angenommen.';
    }
  }
  return null;
}

/// Die Aktivitätsarten unter [module], die Eingaben von Lernenden tragen können und für die
/// die Prüfung keinen Dateiaufbau kennt: weder reine Inhaltsart ([inhaltsModule]) noch
/// in [lernendenEintraege]. Ohne Doppelte, sortiert.
List<String> archivUngepruefteArten(Iterable<String> module) => {
      for (final m in module)
        if (m.isNotEmpty && !inhaltsModule.contains(m) && !lernendenEintraege.containsKey(m)) m,
    }.toList()
      ..sort();

/// Dateien aus `files/`, die der Browser als Skript öffnet.
final RegExp _skriptDatei = RegExp(r'\.m?js$', caseSensitive: false);

/// Wo im Archiv Code am Rahmen vorbei liefe (E22), je als Pfad und Art ohne Inhalt
/// (E11). Dieselben Regeln wie beim Schreiben: Code im Text eines Felds
/// ([codeImText], wie `skripteImTextPruefen`), Rahmen ohne genau die Abschottung,
/// Elemente in Fragen (nicht vorgesehen), Dateien, die der Browser als Dokument
/// öffnet und die Code enthalten, ohne ein abgeschottetes Element mit dem Kopf der
/// App zu sein (`dateienPruefen`), und Skriptdateien (ein .js liefe, sobald eine
/// Seite es einbindet -- der Text darf es nicht, die Datei soll es auch nicht
/// mitbringen).
///
/// Die Texte stehen in den XML-Dateien von Aktivitäten, Abschnitten und Kurs
/// sowie in questions.xml (Felder wie intro, content, summary, questiontext). Den
/// Dateinamen zu einer Datei in files/ nennt nur files.xml: In files/ heißen die
/// Dateien nach ihrem Inhalts-Hash, ohne Endung.
List<String> _codeImArchiv(Map<String, Uint8List> dateien) {
  final aus = <String>[];
  final elementNamen = <String>{};
  // Vorfilter am rohen Text: Im XML steht `<script>` als `&lt;script&gt;`, `script`
  // und `iframe` bleiben also stehen. Nur was ihn besteht, wird als XML gelesen.
  final vorfilter = RegExp(r'script|srcdoc|iframe|\bon[a-z]+\s*=|javascript', caseSensitive: false);
  for (final e in dateien.entries) {
    final pfad = e.key;
    if (pfad.startsWith('files/') || !pfad.toLowerCase().endsWith('.xml')) continue;
    if (pfad == 'moodle_backup.xml' || pfad == 'files.xml') continue;
    final text = utf8.decode(e.value, allowMalformed: true);
    if (!vorfilter.hasMatch(text)) continue;
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(text);
    } on XmlException {
      aus.add('$pfad: nicht lesbar, nicht auf Code geprüft');
      continue;
    }
    var stellen = 0, offen = 0, elementeInFrage = 0;
    for (final n in doc.descendants) {
      if (n is! XmlText && n is! XmlCDATA) continue;
      final html = n.value ?? '';
      if (!html.contains('<')) continue;
      final b = codeImText(html);
      stellen += b.code;
      offen += b.offeneRahmen;
      elementNamen.addAll(b.elemente);
      if (pfad == 'questions.xml') elementeInFrage += b.elemente.length;
    }
    if (stellen > 0) aus.add('$pfad: Code im Text ($stellen ${stellen == 1 ? 'Stelle' : 'Stellen'})');
    if (offen > 0) aus.add('$pfad: Rahmen ohne Abschottung ($offen)');
    if (elementeInFrage > 0) aus.add('$pfad: Element in einer Frage (hier nicht vorgesehen)');
  }

  final filesXml = dateien['files.xml'];
  if (filesXml == null) return aus;
  final XmlDocument fdoc;
  try {
    fdoc = XmlDocument.parse(utf8.decode(filesXml, allowMalformed: true));
  } on XmlException {
    aus.add('files.xml: nicht lesbar, Dateien nicht auf Code geprüft');
    return aus;
  }
  final namenJeHash = <String, Set<String>>{};
  for (final f in fdoc.findAllElements('file')) {
    final hash = f.getElement('contenthash')?.innerText.trim() ?? '';
    final name = f.getElement('filename')?.innerText.trim() ?? '';
    if (hash.length < 3 || name.isEmpty || name == '.') continue;
    (namenJeHash[hash] ??= {}).add(name);
  }
  for (final h in namenJeHash.entries) {
    final pfad = 'files/${h.key.substring(0, 2)}/${h.key}';
    final inhalt = dateien[pfad];
    if (inhalt == null) continue;
    for (final name in h.value) {
      if (_skriptDatei.hasMatch(name)) {
        aus.add('$pfad: Skriptdatei (${p.extension(name).toLowerCase()})');
        break;
      }
      final stellen = codeInDatei(name, inhalt);
      if (stellen.isEmpty) continue;
      // Ein Element ist eine HTML-Datei mit dem Kopf der App, die ein abgeschotteter Rahmen
      // einbindet und die die Regeln für Elemente einhält: Sie darf Code haben.
      if (istElementdatei(name) && elementNamen.contains(name)) {
        final text = utf8.decode(inhalt, allowMalformed: true);
        if (hatKopf(text) && elementFehler(text).isEmpty) continue;
      }
      aus.add('$pfad: ${p.extension(name).toLowerCase()}-Datei mit Code, kein abgeschottetes Element');
      break;
    }
  }
  return aus;
}

/// Ein Pfad ist unsicher, wenn er absolut ist, Trennzeichen fremder Systeme
/// enthält oder „..“ als Abschnitt hat. Gibt den Grund zurück, sonst null.
/// Den Pfad selbst nennt der Grund nicht.
String? pfadFehler(String pfad) {
  if (pfad.isEmpty) return 'leer';
  if (pfad.startsWith('/') || pfad.contains('\\') || pfad.contains(':') || pfad.contains('\u0000')) {
    return 'absolut oder mit fremdem Trennzeichen';
  }
  for (final s in pfad.split('/')) {
    if (s == '..') return 'Pfad mit „..“';
  }
  return null;
}

/// Die Sicherungsdatei [name] (relativ zu [ordner], nur .mbz, ohne „..") als Datei mit
/// aufgelösten Verknüpfungen -- oder null, wenn es sie nicht gibt oder ihr Ziel
/// außerhalb von [ordner] liegt. Verknüpfungen werden aufgelöst, bevor verglichen
/// wird: Eine Verknüpfung im Sicherungsordner, die auf eine Datei außerhalb zeigt,
/// ist keine Sicherung der App. Eine Stelle für Wiederherstellung und Testkopien.
Future<File?> sicherungsDatei(String ordner, String name) async {
  if (pfadFehler(name) != null || !name.toLowerCase().endsWith('.mbz')) return null;
  try {
    final datei = File(p.join(ordner, name));
    if (!await datei.exists()) return null;
    final wurzel = await Directory(ordner).resolveSymbolicLinks();
    final pfad = await datei.resolveSymbolicLinks();
    return p.isWithin(wurzel, pfad) ? File(pfad) : null;
  } on FileSystemException {
    return null;
  }
}

/// Dateien, die auf Nutzerdaten hindeuten: die Liste der Nutzer, Nutzerordner
/// und Nutzerdaten je Aktivität.
bool nutzerdatenPfad(String pfad) =>
    pfad == 'users.xml' ||
    pfad.endsWith('/users.xml') ||
    pfad.startsWith('user/') ||
    pfad.contains('/userdata/');

/// Der Ordnername eines Quiz (quiz_21) aus activities/quiz_21/quiz.xml, sonst null.
String? _quizOrdner(String pfad) => RegExp(r'^activities/(quiz_[^/]+)/quiz\.xml$').firstMatch(pfad)?.group(1);

bool _kopfOk(Uint8List kopf) {
  final soll = _oktal(kopf, 148, 156);
  if (soll == null) return false;
  var summe = 0;
  for (var i = 0; i < 512; i++) {
    summe += (i >= 148 && i < 156) ? 0x20 : kopf[i];
  }
  return summe == soll;
}

String _text(Uint8List b, int von, int bis) {
  var ende = von;
  while (ende < bis && b[ende] != 0) {
    ende++;
  }
  return latin1.decode(b.sublist(von, ende));
}

/// Eine Oktalzahl aus dem Feld, mit Leerzeichen und NUL am Rand. Null, wenn
/// das Feld keine Oktalzahl ist (auch nicht die Binärform).
int? _oktal(Uint8List b, int von, int bis) {
  if ((b[von] & 0x80) != 0) return null;
  final s = _text(b, von, bis).trim();
  if (s.isEmpty) return 0;
  if (!RegExp(r'^[0-7]+$').hasMatch(s)) return null;
  return int.parse(s, radix: 8);
}

String? _text1(XmlDocument doc, String name) {
  final e = doc.findAllElements(name).firstOrNull;
  return e?.innerText.trim();
}

/// Die fünf Zielwege einer Wiederherstellung (E9-Ablauf). [moodle] ist
/// Moodles Wert für `target`. Löschende Wege (0, 3) entfernen vorhandene Inhalte
/// des Zielkurses, bevor sie wiederherstellen; nur mit `loeschend: true`.
enum Zielweg {
  neuerKurs(2, 'neuer_kurs', false),
  aktuellerKursVerschmelzen(1, 'aktueller_kurs_verschmelzen', false),
  aktuellerKursErsetzen(0, 'aktueller_kurs_ersetzen', true),
  anderKursVerschmelzen(4, 'anderer_kurs_verschmelzen', false),
  anderKursErsetzen(3, 'anderer_kurs_ersetzen', true);

  const Zielweg(this.moodle, this.nennung, this.loescht);

  final int moodle;

  /// Der Name, mit dem der Auftrag den Weg nennt (und den Moodle-Fehlertexten fehlt).
  final String nennung;

  final bool loescht;

  /// Der neue Kurs hat noch keine Nummer; alle anderen Wege brauchen die Kurs-ID.
  bool get brauchtKurs => this != neuerKurs;

  static Zielweg? aus(String text) {
    for (final z in values) {
      if (z.nennung == text) return z;
    }
    return null;
  }

  static String get optionen => values.map((z) => z.nennung).join(', ');
}

/// Entscheidet den Zielweg aus den Angaben des Auftrags, bevor Moodle gelesen
/// wird. `weg` ist Pflicht: Fehlt er, wird nichts geraten, sondern gefragt; der
/// Befund ist dann eine Rückfrage mit den Optionen. Wird keine Rückfrage
/// zurückgegeben, ist [weg] gesetzt.
({Zielweg? weg, String? rueckfrage}) zielwegPruefen({
  required String? weg,
  required bool loeschend,
  required int? kurs,
  required String? neuerKursName,
  required String? kurzname,
}) {
  const nichtGeraten = 'Nichts geändert.';
  if (weg == null) {
    return (
      weg: null,
      rueckfrage: 'Der Parameter weg fehlt. Möglich sind: ${Zielweg.optionen}. $nichtGeraten',
    );
  }
  final gewaehlt = Zielweg.aus(weg);
  if (gewaehlt == null) {
    return (
      weg: null,
      rueckfrage: 'Der Weg „$weg" ist unbekannt. Möglich sind: ${Zielweg.optionen}. $nichtGeraten',
    );
  }
  if (gewaehlt.brauchtKurs) {
    if (kurs == null) {
      return (
        weg: null,
        rueckfrage: 'Der Weg ${gewaehlt.nennung} braucht die Kurs-ID (kurs). $nichtGeraten',
      );
    }
    if (neuerKursName != null || kurzname != null) {
      return (
        weg: null,
        rueckfrage: 'neuer_kurs_name und kurzname gehören nur zum Weg neuer_kurs. $nichtGeraten',
      );
    }
  } else {
    if (kurs != null) {
      return (
        weg: null,
        rueckfrage: 'Der Weg neuer_kurs legt einen Kurs an; kurs bitte weglassen. $nichtGeraten',
      );
    }
    if ((neuerKursName ?? '').trim().isEmpty || (kurzname ?? '').trim().isEmpty) {
      return (
        weg: null,
        rueckfrage: 'Für neuer_kurs sind neuer_kurs_name und kurzname Pflicht. $nichtGeraten',
      );
    }
  }
  if (gewaehlt.loescht && !loeschend) {
    return (
      weg: null,
      rueckfrage: 'Der Weg ${gewaehlt.nennung} löscht vorhandene Inhalte des Zielkurses. '
          'Dafür braucht es loeschend: true. $nichtGeraten',
    );
  }
  if (loeschend && !gewaehlt.loescht) {
    return (
      weg: null,
      rueckfrage: 'loeschend gilt nur für die löschenden Wege. Bitte loeschend weglassen. $nichtGeraten',
    );
  }
  return (weg: gewaehlt, rueckfrage: null);
}

/// Doppelstart-Schutz. Der Fingerabdruck hängt am Inhalt der
/// Datei, nie am Namen: umbenannt bleibt es dieselbe Wiederherstellung. Kurs (0 bei
/// neuem Kurs) und Zielweg gehören dazu, damit ein anderer Ziel-Lauf nicht gesperrt wird.
/// Das Profil ([instanz]) gehört ebenfalls dazu: Dieselbe Datei auf zwei Instanzen
/// sperrt sich nicht gegenseitig.
String fingerabdruck(List<int> bytes, {required String instanz, required int kurs, required Zielweg weg}) =>
    '${sha256.convert(bytes)}|$instanz|$kurs|${weg.name}';

/// Was die Doppelstart-Prüfung von einem Vorgang braucht. Ohne Dateien und Texte.
typedef DoppelstartEintrag = ({
  String id,
  String? fingerabdruck,
  String? wiederholungVon,
  WiederherstellungStand? stand,
  int kurs,
});

/// Die Nummer des offenen Vorgangs, der die neue Wiederherstellung sperrt, sonst null.
///
/// Offen heißt: anstehend, hochgeladen, laufend, unklar oder fertig (Moodle kann die
/// Wiederherstellung schon ausgeführt haben, oder sie ist noch nicht gegengelesen).
/// Fehlgeschlagen heißt nur noch: vor dem Start abgebrochen, oder Prozess beendet und im
/// Zielkurs nachweislich nichts Neues (siehe [fehlerBeendet]); das sperrt nicht, außer bei
/// neuem Kurs (kurs 0), weil dort ein Platzhalterkurs bleiben kann. Ein von Moodle gemeldeter
/// Fehler allein macht keinen Vorgang fehlgeschlagen: Er bleibt unklar (gesperrt), bis der
/// Zielkurs geprüft ist. Nur der Kopf zählt: Ein Vorgang, auf den ein anderer mit
/// wiederholungVon zeigt, ist nur durch einen weiterhin sperrenden Nachfolger überholt. Eine Wiederholung ist nur zulässig, wenn sie
/// genau den sperrenden Kopf nennt.
String? doppelstartSperre(
  Iterable<DoppelstartEintrag> alle, {
  required String fingerabdruck,
  required String? wiederholungVon,
  required int kurs,
}) {
  final gleiche = [for (final e in alle) if (e.fingerabdruck == fingerabdruck) e];
  final nachId = {for (final e in gleiche) e.id: e};
  final ueberholt = <String>{};
  for (final e in gleiche.where((e) => _sperrt(e, kurs))) {
    // Gescheiterte Versuche lassen den Vorgänger gesperrt. Ein später gestarteter
    // Nachfolger überholt die ganze Kette, auch über solche Zwischenversuche hinweg.
    var von = e.wiederholungVon;
    final besucht = <String>{e.id};
    while (von != null && besucht.add(von)) {
      ueberholt.add(von);
      von = nachId[von]?.wiederholungVon;
    }
  }
  final sperrend = [
    for (final e in gleiche)
      if (!ueberholt.contains(e.id) && _sperrt(e, kurs)) e.id,
  ];
  if (sperrend.isEmpty) return null;
  if (wiederholungVon != null && sperrend.contains(wiederholungVon)) return null;
  return sperrend.first;
}

bool _sperrt(DoppelstartEintrag e, int kurs) => switch (e.stand) {
      WiederherstellungStand.anstehend ||
      WiederherstellungStand.hochgeladen ||
      WiederherstellungStand.laufend ||
      WiederherstellungStand.unklar ||
      WiederherstellungStand.fertig =>
        true,
      WiederherstellungStand.fehlgeschlagen => e.kurs == 0 && kurs == 0,
      null => false,
    };

/// Typen außerhalb der Positivliste (nicht schreibbar) werden nicht
/// verifiziert. Liefert den Prüflücke-Text oder null, wenn alle schreibbar sind.
String? nichtSchreibbarePruefluecke(Iterable<String> moduln) {
  final nein = {for (final m in moduln) if (!MoodleZugang.schreibbareModule.contains(m)) m}.toList()..sort();
  if (nein.isEmpty) return null;
  return 'Prüflücke: Inhalt und Anhänge von ${nein.map((m) => 'Typ „$m"').join(', ')} sind nicht gegengeprüft '
      '(der Typ ist nicht schreibbar, sein Formular wird nicht gelesen); nicht verifiziert.';
}

/// Die Nachfrage an die Verwaltung der Moodle-Instanz, wenn der Hintergrundauftrag nach einem
/// gemeldeten Fehler noch hängen könnte. Die Lehrkraft gibt sie weiter; die App betritt den
/// Adminbereich nie (A9). Nur Nummer, Zeiten, Kursnummer und Fehlerart: keine Kursnamen, keine
/// Inhalte, keine Personen (E11).
String verwaltungsNachfrage({
  required String nummer,
  required DateTime start,
  required DateTime? letzteBeobachtung,
  required int? zielkurs,
  required String fehlerart,
  required double? fortschritt,
}) {
  String uhr(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final ziel = zielkurs == null ? 'in einem neuen Kurs (Nummer noch nicht bekannt)' : 'im Kurs $zielkurs';
  final prozent = fortschritt == null ? 'unbekannt' : '${(fortschritt * 100).round()} %';
  return 'Guten Tag, über die Lehrkraft-App wurde $ziel um ${uhr(start)} Uhr eine Wiederherstellung '
      'angestoßen (Vorgang $nummer). Moodle meldet dazu den Fehler „$fehlerart"; die letzte Beobachtung '
      '${letzteBeobachtung == null ? 'liegt nicht vor' : 'war um ${uhr(letzteBeobachtung)} Uhr'} (Fortschritt: $prozent). '
      'Die Wiederherstellung wurde angestoßen und soll nicht wiederholt werden, damit keine Dubletten '
      'entstehen. Was ist mit dem Hintergrundauftrag (Ad-hoc-Aufgabe, Cron) los: läuft er noch, ist er '
      'abgebrochen oder hängt er?';
}

/// Die Aktivitäten, die `moodle_backup.xml` auflistet. Dasselbe Element `activity` steht auch
/// in den Einstellungen als bloße Kennung (`<activity>quiz_1941</activity>`); diese haben weder
/// Typ noch Titel und sind keine Aktivitäten des Archivs.
Iterable<XmlElement> archivAktivitaetsElemente(XmlDocument doc) =>
    doc.findAllElements('activity').where((a) => a.getElement('modulename') != null);

/// Aktivitätsarten, die nur Inhalte der Lehrkraft tragen und keine Daten von
/// Lernenden aufnehmen: Textseite, Textfeld, Link, Datei, Verzeichnis, Buch,
/// Unterabschnitt, Fragensammlung, Lernlandkarte. Alles andere kann welche
/// enthalten (Abgaben, Forenbeiträge, Testversuche, Wiki- und Boardbeiträge,
/// Abhaklisten, Bewertungen, Umfrageantworten ...) -- und schon der Name der Art
/// sagt nicht verlässlich, ob es so ist (ein Zusatzmodul, das moocp nicht
/// kennt). Deshalb gilt die Umkehrung: Verdächtig ist, was nicht ausdrücklich
/// hier steht. Die Liste ist bewusst kurz; eine Art kommt erst hinein, wenn
/// feststeht, dass sie keine Eingaben von Lernenden speichert.
const Set<String> inhaltsModule = {
  'page',
  'label',
  'url',
  'resource',
  'folder',
  'book',
  'subsection',
  'qbank',
  'learningmap',
};

/// Eine Aktivität des Zielkurses, die ein löschender Weg entfernt.
typedef LoeschAktivitaet = ({int cmid, String modul, String name});

/// Warum eine Aktivität in der Freigabe vor dem Löschen hervorgehoben wird.
/// Beides sind Gründe, genauer hinzusehen: Wer die Liste prüft, sieht die
/// Inhalte dort nicht mit moocp, sondern muss sie in Moodle öffnen.
class LoeschHinweis {
  const LoeschHinweis({required this.lernendendaten, required this.nichtUnterstuetzt});

  /// Die Art ist keine reine Inhaltsart ([inhaltsModule]): Sie kann Abgaben,
  /// Beiträge, Versuche oder Bewertungen von Lernenden enthalten.
  final bool lernendendaten;

  /// moocp unterstützt die Art nicht (kann sie weder anlegen noch ändern):
  /// Ihren Inhalt kann die Lehrkraft in moocp nicht ansehen.
  final bool nichtUnterstuetzt;

  bool get auffaellig => lernendendaten || nichtUnterstuetzt;

  /// Die Begründung in der Zeile; leer, wenn die Aktivität nicht auffällt.
  String get text => [
        if (lernendendaten) 'kann Daten von Lernenden enthalten',
        if (nichtUnterstuetzt) 'von moocp nicht unterstützt, Inhalt dort nicht einsehbar',
      ].join('; ');
}

/// Bewertet die Art einer Aktivität für die Löschliste. „Unterstützt" sind die
/// Arten, die moocp anlegen und ändern kann ([MoodleZugang.anlegbareModule]:
/// schreibbar plus Lernlandkarte, die ihr eigenes Werkzeug hat); die
/// Gruppen-Ausnahmen (`nurGruppenModule`) zeigen ihren Inhalt nicht.
LoeschHinweis loeschHinweis(String modul) => LoeschHinweis(
      lernendendaten: !inhaltsModule.contains(modul),
      nichtUnterstuetzt: !MoodleZugang.anlegbareModule.contains(modul),
    );

/// Die Adresse einer Aktivität in Moodle, damit die Lehrkraft sie vor dem
/// Löschen öffnen kann. Die Art muss ein schlichter Modulname sein; sonst
/// (ein Wert, den kein Moodle liefert) die Kursseite -- nie eine Adresse aus
/// ungeprüftem Text. Moodle leitet `view.php` von Arten ohne eigene Ansicht
/// (Textfeld, Unterabschnitt) auf die Kursseite um.
Uri aktivitaetsAdresse(Uri basis, LoeschAktivitaet a, int kurs) =>
    RegExp(r'^[a-z0-9_]{1,40}$').hasMatch(a.modul)
        ? basis.resolve('/mod/${a.modul}/view.php?id=${a.cmid}')
        : basis.resolve('/course/view.php?id=$kurs');

/// Vergleicht die Liste, die die Lehrkraft in der Freigabe gesehen hat, mit dem
/// Kurs von jetzt. Null: gleich (dieselben Aktivitäten mit demselben Namen und
/// derselben Art). Sonst eine kurze Beschreibung, was abweicht -- mit Namen
/// aus dem Kurs, die auch in der Liste standen.
String? listeWeichtAb(List<LoeschAktivitaet> freigegeben, List<LoeschAktivitaet> jetzt) {
  final alt = {for (final a in freigegeben) a.cmid: a};
  final neu = {for (final a in jetzt) a.cmid: a};
  String nenne(Iterable<String> namen) {
    final l = namen.toList();
    return l.take(5).join(', ') + (l.length > 5 ? ' und ${l.length - 5} weitere' : '');
  }

  final dazu = [for (final a in neu.values) if (!alt.containsKey(a.cmid)) '„${a.name}"'];
  final weg = [for (final a in alt.values) if (!neu.containsKey(a.cmid)) '„${a.name}"'];
  final anders = [
    for (final a in alt.values)
      if (neu[a.cmid] case final n? when n.name != a.name || n.modul != a.modul) '„${a.name}" ist jetzt „${n.name}"',
  ];
  if (dazu.isEmpty && weg.isEmpty && anders.isEmpty) return null;
  return [
    if (dazu.isNotEmpty) 'dazugekommen: ${nenne(dazu)}',
    if (weg.isNotEmpty) 'nicht mehr da: ${nenne(weg)}',
    if (anders.isNotEmpty) 'geändert: ${nenne(anders)}',
  ].join('; ');
}
