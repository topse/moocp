// Bilder und Anhänge importierter Aktivitäten zurücklesen und vergleichen (E2, E3, E17).
//
// Quelle: die Sicherungsdatei im Sicherungsordner (vorgaenge.ordner/datei). Je
// eindeutig zugeordneter Aktivität nennt inforef.xml alle Dateien ihres Bereichs,
// files.xml gibt Name und contenthash (SHA-1 des Inhalts). Gezählt wird nur, was der
// Text der Aktivität einbindet oder was im Dateimanager liegt; eine im Bereich
// liegende, im Text nicht verwendete Datei gehört nicht zur Quelle. Nutzerdateien
// (component „user…") bleiben außen (A1); ihre Inhalte werden nie gelesen.
//
// Ziel: das Bearbeitungsformular der Aktivität (GET /course/modedit.php?update=cmid,
// Positivliste). Seine Verweise auf /pluginfile.php und /draftfile.php werden nur
// über den Pfad abgerufen, nie über einen anderen Host. Verglichen wird der Inhalt
// (SHA-1), nicht die Adresse: URLs allein beweisen keine Gleichheit.
//
// Die Prüfung repariert nichts. Eine Reparatur über aktivitaet_aendern wäre ein
// eigener Schritt mit Freigabe und hier nicht enthalten.
//
// Dateimanager-Dateien ohne lesbaren Verweis in der Formularinitialisierung bleiben
// eine Prüflücke („nicht lesbar“); ihr Fehlen dort belegt keine fehlende Zieldatei.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'formular_lesen.dart' show hauptformular, dateibereiche;
import 'moodle_zugang.dart';
import 'sicherung.dart';
import 'wiederherstellung_regeln.dart' show WiederhergestellteAktivitaet, archivAktivitaetsElemente;

/// Eine Datei der Quellaufnahme.
///
/// [dateimanager]: Die Datei liegt im Dateimanager der Aktivität (Datei, Verzeichnis), nicht
/// als Verweis im Text. Das Bearbeitungsformular zeigt sie nicht als Verweis; ihr Fehlen
/// dort belegt darum nichts.
typedef QuellDatei = ({String name, String sha1, bool dateimanager});

/// Ein abgerufener Verweis aus dem Formular. [status] null: keine Antwort (Netzfehler).
/// [sha1] nur bei HTTP 200.
typedef ZielAbruf = ({String name, bool entwurf, int? status, String? sha1});

/// Ergebnis für eine Aktivität oder für alle zusammen.
class AnhangPruefung {
  AnhangPruefung(this.befunde, {required this.vollstaendig, this.abweichend = false});

  /// Mindestens ein Fund ist ein Unterschied zur Quelle (geändert, fremd, fehlend im Ziel,
  /// Fehlerstatus), nicht nur eine Prüflücke (unlesbar, Quelle fehlt, Dateimanager).
  final bool abweichend;

  /// Leer, wenn alles übereinstimmt. Sonst je Fund ein Satz mit dem Namen.
  final List<String> befunde;

  /// Nur wahr, wenn jede Datei mit der Quellaufnahme übereinstimmt und nichts fehlt.
  final bool vollstaendig;

  String get text => vollstaendig
      ? 'Anhänge und Bilder: verglichen, übereinstimmend.'
      : 'Anhänge und Bilder nicht vollständig verifiziert: ${befunde.join('; ')}. '
          'Nichts wurde repariert.';
}

final RegExp _verweis = RegExp(r'/(pluginfile|draftfile)\.php/[^\s"\x27<>]+');

/// Einbindungen im Text der Sicherung (`$@FILEPHP@$`) und im Formular (`@@PLUGINFILE@@`,
/// Adressen unter /pluginfile.php und /draftfile.php).
final RegExp _einbindung =
    RegExp(r'(?:\$@FILEPHP@\$|@@PLUGINFILE@@|/pluginfile\.php|/draftfile\.php)/[^\s"\x27<>]+');

/// Moodle hängt bei Namensgleichheit im Bereich „ (n)“ vor die Endung an.
final RegExp _zaehlerName = RegExp(r'^(.*) \((\d+)\)(\.[^.]*)?$');

String? _text(XmlElement e, String name) => e.getElement(name)?.innerText.trim();

/// Löst escapetes HTML auf. Das `&amp;` kommt zuletzt, sonst würden doppelt escapete
/// Zeichen zu früh aufgelöst.
String _entschluesselt(String html) => html
    .replaceAll('&quot;', '"')
    .replaceAll('&#039;', "'")
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

/// Der Dateiname einer Adresse: letztes Segment ohne Query und Anker, prozentkodiert
/// (Leerzeichen als %20, Klammern als %28/%29). Eine nicht dekodierbare Kodierung bleibt roh.
String _dateiname(String adresse) {
  var roh = adresse;
  final ende = roh.indexOf(RegExp(r'[?#]'));
  if (ende > 0) roh = roh.substring(0, ende);
  final letzter = roh.split('/').last;
  try {
    return Uri.decodeComponent(letzter);
  } on FormatException {
    return letzter;
  }
}

/// Die Dateinamen, die der Text der Aktivität einbindet. Gelesen wird nur die Datei
/// `<modul>.xml` der Aktivität: dort steht ihr Text (Intro, Inhalt, Kapitel). Die übrigen
/// Dateien des Verzeichnisses (Rollen, Noten, Fragen) gehören nicht zur Einbindung und
/// bleiben ungelesen (A1).
Set<String> _eingebundeneNamen(Uint8List? xml) {
  if (xml == null) return {};
  final text = _entschluesselt(utf8.decode(xml, allowMalformed: true));
  return {for (final m in _einbindung.allMatches(text)) _dateiname(m.group(0)!)};
}

/// Der Name der Quelle, zu dem ein Zielname gehört: der Name selbst, oder der Name ohne
/// Moodle-Zähler („bild (1).png“ zu „bild.png“). Nur wenn der Grundname in der Quelle
/// vorkommt; ähnliche Namen werden nie zugeordnet.
String? _quellname(String name, Map<String, Set<String>> namen) {
  if (namen.containsKey(name)) return name;
  final m = _zaehlerName.firstMatch(name);
  if (m == null) return null;
  final grundname = '${m.group(1)}${m.group(3) ?? ''}';
  return namen.containsKey(grundname) ? grundname : null;
}

/// Die Dateien einer Aktivität aus der Quellaufnahme. null, wenn es keine gibt, weil
/// das Archiv unlesbar ist, die Aktivität nicht eindeutig darin vorkommt oder ihre
/// Dateiliste fehlt. Dann ist die Quelle „fehlend", nicht „leer".
List<QuellDatei>? quelldateienAus(Uint8List mbz, {required String modul, required String titel}) {
  final Map<String, Uint8List> dateien;
  try {
    final tar = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(mbz));
    dateien = {
      for (final f in tar.files)
        if (f.isFile) f.name: Uint8List.fromList(f.content as List<int>),
    };
  } catch (_) {
    // Jeder Fehler beim Entpacken heißt: keine Quellaufnahme. Der Aufrufer meldet null
    // als Prüflücke („Quellaufnahme fehlt"), nie als leere Dateiliste.
    return null;
  }

  final backup = dateien['moodle_backup.xml'];
  final filesXml = dateien['files.xml'];
  if (backup == null || filesXml == null) return null;
  try {
    final doc = XmlDocument.parse(utf8.decode(backup, allowMalformed: true));
    final verzeichnisse = [
      for (final a in archivAktivitaetsElemente(doc))
        if (_text(a, 'modulename') == modul && _text(a, 'title') == titel) _text(a, 'directory') ?? '',
    ];
    if (verzeichnisse.length != 1) return null;
    final verz = verzeichnisse.single;
    if (verz.isEmpty || verz.startsWith('/') || verz.contains('..')) return null;
    final inforef = dateien['$verz/inforef.xml'];
    if (inforef == null) return null;

    final ids = {
      for (final f in XmlDocument.parse(utf8.decode(inforef, allowMalformed: true)).findAllElements('file'))
        if ((_text(f, 'id') ?? '').isNotEmpty) _text(f, 'id')!,
    };
    // inforef.xml nennt alle Dateien des Bereichs, auch alte, die der Text nicht mehr
    // einbindet. Gezählt wird nur, was der Text einbindet oder im Dateimanager liegt.
    final eingebunden = _eingebundeneNamen(dateien['$verz/$modul.xml']);
    final liste = <QuellDatei>[];
    for (final f in XmlDocument.parse(utf8.decode(filesXml, allowMalformed: true)).findAllElements('file')) {
      // files.xml trägt die ID als Attribut; inforef.xml referenziert sie als Kindelement.
      if (!ids.contains(f.getAttribute('id'))) continue;
      if ((_text(f, 'component') ?? '').startsWith('user')) continue; // A1: Nutzerdateien nie
      final name = _text(f, 'filename') ?? '';
      if (name.isEmpty || name == '.') continue; // Verzeichniseinträge
      final komponente = _text(f, 'component') ?? '';
      final dateimanager = komponente == 'mod_resource' || komponente == 'mod_folder';
      if (!dateimanager && !eingebunden.contains(name)) continue;
      liste.add((
        name: name,
        sha1: _text(f, 'contenthash') ?? '',
        dateimanager: dateimanager,
      ));
    }
    return liste;
  } on XmlException {
    return null;
  }
}

/// Die Verweise auf Dateien im Formular. Escapetes HTML wird zuerst aufgelöst. Nur der
/// Pfad zählt: Ein fremder Host wird nie angefragt. Gleiche Pfade einmal.
List<({bool entwurf, String pfad, String name})> verweiseAus(String html) {
  final text = _entschluesselt(html);
  final gesehen = <String>{};
  final liste = <({bool entwurf, String pfad, String name})>[];
  for (final m in _verweis.allMatches(text)) {
    var roh = m.group(0)!;
    final ende = roh.indexOf(RegExp(r'[?#]'));
    if (ende > 0) roh = roh.substring(0, ende);
    if (!gesehen.add(roh)) continue;
    liste.add((entwurf: m.group(1) == 'draftfile', pfad: roh, name: _dateiname(roh)));
  }
  return liste;
}

/// Liest das Formular einer Aktivität und ruft jeden Verweis ab. [fehler] nennt den
/// Grund, wenn das Formular selbst nicht lesbar ist.
Future<({String? fehler, List<ZielAbruf> abrufe})> zielLesen(MoodleZugang moodle, int cmid) async {
  final Antwort form;
  try {
    form = await moodle.lesen('/course/modedit.php?update=$cmid');
  } on MoodleFehler {
    return (fehler: 'Bearbeitungsformular nicht lesbar', abrufe: const <ZielAbruf>[]);
  }
  if (form.status != 200) {
    return (fehler: 'Bearbeitungsformular nicht lesbar (HTTP ${form.status})', abrufe: const <ZielAbruf>[]);
  }
  final haupt = hauptformular(html_parser.parse(form.text));
  if (haupt == null) {
    return (
      fehler: 'Bearbeitungsformular nicht gefunden',
      abrufe: const <ZielAbruf>[],
    );
  }
  final bereiche = dateibereiche(form.text);
  // Ein Dateibereich ohne Zielelement würde still ausgelassen und die Prüfung läse sich vollständig.
  if (bereiche.any((b) => haupt.querySelector('[id="${b['target']}"]') == null)) {
    return (
      fehler: 'Dateibereich im Formular nicht gefunden',
      abrufe: const <ZielAbruf>[],
    );
  }
  // Die Seitenhülle trägt Logos, Editorressourcen und Profilbilder, keine Inhaltsdateien.
  final inhalte = [
    for (final feld in haupt.querySelectorAll('textarea[name]'))
      if (feld.attributes['name']!.endsWith('[text]') ||
          feld.attributes['name'] == 'svgcode')
        feld.text,
    for (final bereich in bereiche)
      for (final datei
          in (bereich['list'] as List? ?? const []).whereType<Map>())
        if (datei['url'] case final String url) url,
  ];
  final abrufe = <ZielAbruf>[];
  for (final v in verweiseAus(inhalte.join('\n'))) {
    int? status;
    String? sha;
    try {
      final r = await moodle.lesen(v.pfad);
      status = r.status;
      if (r.status == 200) sha = sha1.convert(r.bytes).toString();
    } on MoodleFehler {
      status = null;
    }
    abrufe.add((name: v.name, entwurf: v.entwurf, status: status, sha1: sha));
  }
  return (fehler: null, abrufe: abrufe);
}

/// Vergleicht Quelle und Ziel einer Aktivität. [quelle] null heißt: Quellaufnahme fehlt.
AnhangPruefung vergleicheAnhaenge({required List<QuellDatei>? quelle, required List<ZielAbruf> ziel,
    String? formularFehler}) {
  final befunde = <String>[];
  var abweichend = false;
  if (formularFehler != null) befunde.add(formularFehler);
  if (quelle == null) {
    befunde.add('Quellaufnahme fehlt: Vergleich nicht möglich');
    return AnhangPruefung(befunde, vollstaendig: false);
  }

  final namen = <String, Set<String>>{};
  final imManager = <String>{for (final q in quelle) if (q.dateimanager) q.name};
  for (final q in quelle) {
    namen.putIfAbsent(q.name, () => {}).add(q.sha1);
  }
  final gelesen = <String>{};
  // Welcher Quellname zu einem Zielnamen gehört (Moodle-Zähler „ (n)“ eingeschlossen).
  final imZiel = <String>{};
  for (final z in ziel) {
    final quellname = _quellname(z.name, namen);
    if (quellname != null) imZiel.add(quellname);
    if (z.status == null) {
      befunde.add('„${z.name}": Abruf fehlgeschlagen');
      continue;
    }
    if (z.status != 200) {
      abweichend = true;
      if (z.entwurf) {
        befunde.add('„${z.name}": verwaiste Entwurfsadresse (HTTP ${z.status})');
      } else {
        befunde.add('„${z.name}": HTTP ${z.status}');
      }
      continue;
    }
    final erwartet = quellname == null ? null : namen[quellname];
    if (erwartet == null) {
      abweichend = true;
      befunde.add('„${z.name}": fremd, die Quellaufnahme kennt die Datei nicht');
      continue;
    }
    if (erwartet.length > 1) {
      abweichend = true;
      befunde.add('„${z.name}": mehrdeutig, gleicher Name mit verschiedenem Inhalt in der Quelle');
      continue;
    }
    if (z.sha1 != erwartet.single) {
      abweichend = true;
      befunde.add('„${z.name}": geändert, Inhalt weicht von der Quelle ab');
      continue;
    }
    gelesen.add(quellname!);
  }
  for (final name in namen.keys) {
    if (!gelesen.contains(name) && !imZiel.contains(name)) {
      if (!imManager.contains(name)) abweichend = true;
      befunde.add(imManager.contains(name)
          ? 'Prüflücke: „$name" liegt im Dateimanager und ist nicht lesbar'
          : '„$name": fehlend im Ziel');
    }
  }
  return AnhangPruefung(befunde, vollstaendig: befunde.isEmpty, abweichend: abweichend);
}

/// Prüft die Anhänge der eindeutig zugeordneten Aktivitäten. Liest nur Quelle und
/// Formulare; schreibt nie.
Future<AnhangPruefung> anhaengePruefen(MoodleZugang moodle, Vorgaenge vorgaenge, Vorgang vg,
    List<WiederhergestellteAktivitaet> aktivitaeten) async {
  final Uint8List mbz;
  try {
    mbz = await File(p.join(vorgaenge.ordner, vg.datei)).readAsBytes();
  } on FileSystemException {
    return AnhangPruefung(['Prüflücke: Quellaufnahme fehlt; die Sicherungsdatei ist nicht mehr vorhanden'],
        vollstaendig: false);
  }

  // Der Dateiname ist veränderlich, die vor dem Hochladen aufgenommene Quelle
  // hingegen nicht. Ein später ersetztes Archiv kann keinen Vergleich belegen.
  final startHash = vg.fingerabdruck?.split('|').first;
  if (startHash == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(startHash)) {
    return AnhangPruefung(['Prüflücke: Quellaufnahme ist nicht an den Start-Inhalt gebunden (Inhalts-Hash fehlt)'],
        vollstaendig: false);
  }
  if (sha256.convert(mbz).toString() != startHash) {
    return AnhangPruefung(['Prüflücke: Quellaufnahme hat seit dem Start einen anderen Inhalt; Anhänge nicht verglichen'],
        vollstaendig: false);
  }

  final befunde = <String>[];
  var vollstaendig = true;
  var abweichend = false;
  for (final a in aktivitaeten) {
    final quelle = quelldateienAus(mbz, modul: a.modul, titel: a.titel);
    vorgaenge.pruefeBindung(vg);
    final ziel = await zielLesen(moodle, a.cmid);
    final pruefung = vergleicheAnhaenge(quelle: quelle, ziel: ziel.abrufe, formularFehler: ziel.fehler);
    if (!pruefung.vollstaendig) {
      vollstaendig = false;
      abweichend = abweichend || pruefung.abweichend;
      befunde.add('„${a.titel}": ${pruefung.befunde.join('; ')}');
    }
  }
  return AnhangPruefung(befunde, vollstaendig: vollstaendig && aktivitaeten.isNotEmpty, abweichend: abweichend);
}
