// Die Kursstruktur ändern: Werkzeuge abschnitt_anlegen, sichtbarkeit_setzen,
// verschieben, duplizieren und loeschen -- für Aktivitäten, Abschnitte und
// Unterabschnitte.
//
// Alles läuft über dieselbe Schnittstelle, mit der Moodle die Kursseite im
// Bearbeitungsmodus ändert (core_courseformat_update_course), mit den
// Aktionen aus MoodleZugang.kursAktionen. Eigenheiten, gemessen in den
// Browser-Skills an der Zielinstanz:
//   - Verschieben heißt „cm_move", nicht „cm_moveafter" -- letzteres fehlt in
//     manchen Kursformaten (im Kachelformat). cm_move kann beides: anderer
//     Abschnitt (targetsectionid) und Position (targetcmid = das Element,
//     VOR das eingefügt wird; ohne Angabe ans Ende).
//   - Bei einem Unterabschnitt nie cm_hide auf die Kopf-Aktivität: Moodle
//     führt es aus, meldet aber „Dieser Abschnitt existiert nicht"; ein
//     zweiter Versuch schaltet zurück. section_hide auf seinen Abschnitt
//     schaltet Abschnitt und Kopf gemeinsam.
//   - cm_delete auf einen Unterabschnitts-Kopf kann den Abschnitt als Waise
//     samt Inhalt stehen lassen; dann braucht es section_delete dazu.
//   - section_delete löscht den Abschnitt sofort, die Aktivitäten darin erst
//     im Hintergrund (course_delete_section mit async). Die Abschnitte von
//     Unterabschnitten darin stehen deshalb noch etwa eine Minute als leere
//     Abschnitte in der Kursstruktur, dann sind sie weg (gemessen im
//     Testkurs). Nachlöschen wäre überflüssig und kostete eine Freigabe.
//   - Kursformate sind Plugins; fehlt eine Aktion, antwortet Moodle mit
//     „Invalid course state action".
//
// Vorsicht, weil die App in jedem Kurs arbeiten darf, den die Lehrkraft
// bearbeiten darf: Jede Änderung nennt ihr Ziel mit Nummer UND Namen (passt
// der Name nicht, bricht sie ab, bevor gefragt wird), zeigt in der Freigabe
// Kursname und Inhalt, und prüft danach die Kursstruktur.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../freigabe.dart';
import 'elemente.dart';
import 'formular_lesen.dart';
import 'formular_schreiben.dart';
import 'kurs.dart';
import 'moodle_zugang.dart';

Future<Object?> kursAktion(MoodleZugang moodle, int kurs, String aktion, List<int> ids,
    {int? zielAbschnitt, int? zielCmid}) async {
  try {
    return await moodle.dienst('core_courseformat_update_course', {
      'action': aktion,
      'courseid': kurs,
      'ids': ids,
      'targetsectionid': ?zielAbschnitt,
      'targetcmid': ?zielCmid,
    });
  } on MoodleFehler catch (x) {
    if (x.meldung.contains('Invalid course state action')) {
      throw MoodleFehler('Das Kursformat dieses Kurses kennt die Aktion $aktion nicht. Kursformate '
          'sind Plugins und können unterschiedlich viel. Der Weg bleibt die Moodle-Oberfläche.');
    }
    rethrow;
  }
}

String _nichtGefragt(Freigaben f) =>
    'in der App abgelehnt oder nicht innerhalb von ${f.frist.inMinutes} Minuten freigegeben. Nichts geändert.';

/// Ziel einer Strukturänderung: genau eines von beiden.
({KursAktivitaet? cm, KursAbschnitt? abschnitt}) _ziel(KursStruktur k, int? cmid, int? abschnittId, String name) {
  if ((cmid == null) == (abschnittId == null)) {
    throw MoodleFehler('Genau eines angeben: cmid (Aktivität) oder abschnitt_id (Abschnitt).');
  }
  if (cmid != null) {
    final c = k.nachCmid[cmid];
    if (c == null) throw MoodleFehler('cmid $cmid gibt es in Kurs ${k.kurs} nicht (kurs_uebersicht).');
    nameBestaetigen(name, c.name, 'cmid $cmid');
    return (cm: c, abschnitt: null);
  }
  final a = k.nachId[abschnittId];
  if (a == null) throw MoodleFehler('Abschnitt id $abschnittId gibt es in Kurs ${k.kurs} nicht (kurs_uebersicht).');
  nameBestaetigen(name, a.titel, 'Abschnitt id $abschnittId');
  return (cm: null, abschnitt: a);
}

/// Nach der Freigabe noch einmal gegen Moodle. Zwischen Dialog und Handlung
/// liegt die Frist -- bis zu 30 Minuten, in denen eine zweite Sitzung oder
/// die Lehrkraft selbst umbenennen, verschieben oder löschen kann. Gehandelt
/// wird nur, wenn das Ziel noch dasteht wie in der Freigabe; sonst ist der
/// Name, den der Dialog zeigte, nicht mehr der Name in Moodle (A3). `aendern`
/// prüft an derselben Stelle seinen Stand erneut.
Future<KursStruktur> _nachFreigabe(MoodleZugang moodle, int kurs, int? cmid, int? abschnittId, String name) async {
  final k = await kursLesen(moodle, kurs);
  try {
    _ziel(k, cmid, abschnittId, name);
  } on MoodleFehler catch (x) {
    throw MoodleFehler('Seit der Freigabe hat sich in Moodle etwas geändert: ${x.meldung} '
        'Nichts geändert -- bitte neu lesen und die Freigabe auf dem neuen Stand einholen.');
  }
  return k;
}

String _inhaltText(KursStruktur k, KursAbschnitt a) {
  final inhalt = k.inhalt(a);
  if (inhalt.isEmpty) return 'Der Abschnitt ist leer.';
  final zeilen = inhalt.take(12).map((c) => '${typName(c.modul)} „${c.name}"').join(', ');
  return 'Darin ${inhalt.length} Aktivität(en): $zeilen${inhalt.length > 12 ? ' …' : ''}';
}

// ---------------------------------------------------------------------------
// sichtbarkeit_setzen
// ---------------------------------------------------------------------------

Future<String> sichtbarkeitSetzen(MoodleZugang moodle, Freigaben freigaben,
    {required int kurs, int? cmid, int? abschnittId, required String name, required bool sichtbar}) async {
  var k = await kursLesen(moodle, kurs);
  final z = _ziel(k, cmid, abschnittId, name);
  // Ein Unterabschnitt wird über seinen Abschnitt geschaltet.
  final abschnitt = z.abschnitt ?? (z.cm!.unterabschnittId == null ? null : k.nachId[z.cm!.unterabschnittId]);
  final jetzt = abschnitt?.sichtbar ?? z.cm!.sichtbar;
  final was = z.cm != null ? '${typName(z.cm!.modul)} „${z.cm!.name}"' : 'Abschnitt „${abschnitt!.titel}"';
  if (jetzt == sichtbar) return '$was ist schon ${sichtbar ? "sichtbar" : "verborgen"} -- nichts geändert.';
  if (abschnitt != null && abschnitt.nummer == 0 && !abschnitt.istUnterabschnitt) {
    throw MoodleFehler('Den allgemeinen Abschnitt (Nummer 0) verbirgt Moodle nicht.');
  }
  final ja = await freigaben.anfragen(FreigabeAnfrage(
    titel: sichtbar ? 'Für Lernende sichtbar machen?' : 'Für Lernende verbergen?',
    punkte: [
      '$was in ${await kursBezeichnung(moodle, kurs)}',
      if (abschnitt != null) _inhaltText(k, abschnitt),
      sichtbar
          ? 'Lernende sehen es danach auf der Kursseite${abschnitt != null ? ' (was darin verborgen angelegt wurde, bleibt verborgen)' : ''}.'
          : 'Lernende sehen es danach nicht mehr${abschnitt != null ? ', samt allem, was darin liegt' : ''}.',
    ],
    vergleich: const [],
    knopf: sichtbar ? 'Sichtbar machen' : 'Verbergen',
  ));
  if (!ja) return 'Nicht geändert: ${_nichtGefragt(freigaben)}';
  k = await _nachFreigabe(moodle, kurs, cmid, abschnittId, name);

  if (abschnitt != null) {
    await kursAktion(moodle, kurs, sichtbar ? 'section_show' : 'section_hide', [abschnitt.id]);
  } else {
    await kursAktion(moodle, kurs, sichtbar ? 'cm_show' : 'cm_hide', [z.cm!.cmid]);
  }
  k = await kursLesen(moodle, kurs);
  final nachher = abschnitt != null ? k.nachId[abschnitt.id]?.sichtbar : k.nachCmid[z.cm!.cmid]?.sichtbar;
  return '$was ist jetzt ${nachher == null ? "?" : nachher ? "SICHTBAR" : "verborgen"}. '
      'verified: ${nachher == sichtbar}';
}

// ---------------------------------------------------------------------------
// verschieben
// ---------------------------------------------------------------------------

Future<String> verschieben(MoodleZugang moodle, Freigaben freigaben,
    {required int kurs,
    int? cmid,
    int? abschnittId,
    required String name,
    int? zielAbschnittId,
    int? vorCmid,
    int? nachAbschnittId}) async {
  var k = await kursLesen(moodle, kurs);
  final z = _ziel(k, cmid, abschnittId, name);
  final kursText = await kursBezeichnung(moodle, kurs);

  if (z.cm != null) {
    final c = z.cm!;
    if (zielAbschnittId == null) throw MoodleFehler('ziel_abschnitt_id fehlt: In welchen Abschnitt?');
    final ziel = k.nachId[zielAbschnittId];
    if (ziel == null) throw MoodleFehler('Abschnitt id $zielAbschnittId gibt es in Kurs $kurs nicht.');
    if (c.unterabschnittId == zielAbschnittId) {
      throw MoodleFehler('Ein Unterabschnitt kann nicht in sich selbst liegen.');
    }
    KursAktivitaet? vor;
    if (vorCmid != null) {
      vor = ziel.aktivitaeten.where((x) => x.cmid == vorCmid).firstOrNull;
      if (vor == null) throw MoodleFehler('cmid $vorCmid liegt nicht im Abschnitt „${ziel.titel}".');
    }
    final ja = await freigaben.anfragen(FreigabeAnfrage(
      titel: 'Verschieben?',
      punkte: [
        '${typName(c.modul)} „${c.name}" in $kursText',
        'von „${k.nachId[c.abschnittId]?.titel ?? '?'}" nach „${ziel.titel}", '
            '${vor == null ? 'ans Ende' : 'vor „${vor.name}"'}',
      ],
      vergleich: const [],
      knopf: 'Verschieben',
    ));
    if (!ja) return 'Nicht verschoben: ${_nichtGefragt(freigaben)}';
    await _nachFreigabe(moodle, kurs, cmid, abschnittId, name);
    await kursAktion(moodle, kurs, 'cm_move', [c.cmid], zielAbschnitt: zielAbschnittId, zielCmid: vorCmid);
    k = await kursLesen(moodle, kurs);
    final liste = k.nachId[zielAbschnittId]?.aktivitaeten.map((x) => x.cmid).toList() ?? const [];
    final i = liste.indexOf(c.cmid);
    final ok = i >= 0 && (vorCmid == null ? i == liste.length - 1 : i + 1 < liste.length && liste[i + 1] == vorCmid);
    return '${typName(c.modul)} „${c.name}" liegt jetzt in „${k.nachId[zielAbschnittId]?.titel}"'
        '${i < 0 ? ' -- NICHT gefunden' : ', Position ${i + 1} von ${liste.length}'}. verified: $ok';
  }

  final a = z.abschnitt!;
  if (a.istUnterabschnitt) {
    throw MoodleFehler('Einen Unterabschnitt verschiebt man über seine Kopf-Aktivität (cmid, Typ subsection).');
  }
  if (nachAbschnittId == null) throw MoodleFehler('nach_abschnitt_id fehlt: Hinter welchen Abschnitt?');
  final hinter = k.nachId[nachAbschnittId];
  if (hinter == null || hinter.istUnterabschnitt) {
    throw MoodleFehler('Abschnitt id $nachAbschnittId gibt es in Kurs $kurs nicht als Hauptabschnitt.');
  }
  if (a.nummer == 0) throw MoodleFehler('Den allgemeinen Abschnitt (Nummer 0) verschiebt Moodle nicht.');
  final ja = await freigaben.anfragen(FreigabeAnfrage(
    titel: 'Abschnitt verschieben?',
    punkte: [
      'Abschnitt „${a.titel}" in $kursText',
      'hinter „${hinter.titel}"',
      _inhaltText(k, a),
      'Abschnitte mit Standardnamen („Thema 5") heißen danach nach ihrer neuen Position.',
    ],
    vergleich: const [],
    knopf: 'Verschieben',
  ));
  if (!ja) return 'Nicht verschoben: ${_nichtGefragt(freigaben)}';
  await _nachFreigabe(moodle, kurs, cmid, abschnittId, name);
  await kursAktion(moodle, kurs, 'section_move_after', [a.id], zielAbschnitt: nachAbschnittId);
  k = await kursLesen(moodle, kurs);
  final haupt = k.abschnitte.where((x) => !x.istUnterabschnitt).map((x) => x.id).toList();
  final i = haupt.indexOf(a.id);
  final ok = i > 0 && haupt[i - 1] == nachAbschnittId;
  return 'Abschnitt „${k.nachId[a.id]?.titel ?? a.titel}" steht jetzt an Position $i. verified: $ok';
}

// ---------------------------------------------------------------------------
// duplizieren
// ---------------------------------------------------------------------------
//
// Moodle dupliziert über dieselbe Schnittstelle (cm_duplicate,
// section_duplicate). Was dabei geschieht, laut Quelltext von Moodle 5.1
// (course/lib.php duplicate_module, course/format/classes/base.php
// duplicate_section, backup/moodle2/restore_stepslib.php):
//   - Eine Aktivität wird gesichert und sofort wiederhergestellt, im
//     Import-Modus: ohne Nutzerdaten (keine Abgaben, Beiträge, Bewertungen).
//     Die Kopie heißt „… (Kopie)" und steht unter dem Original -- oder mit
//     targetsectionid/targetcmid gleich an der Zielstelle. Sie erbt die
//     Sichtbarkeit; Rechte-Überschreibungen kommen mit. Die Kennnummer
//     (cmidnumber) bleibt leer, weil sie im Kurs eindeutig sein muss.
//   - Ein Abschnitt: neuer Abschnitt direkt hinter dem Original, Name
//     „… (Kopie)" (ohne eigenen Namen bleibt er ohne), Beschreibung samt
//     Dateien, Sichtbarkeit und Voraussetzungen übernommen; dann jede
//     Aktivität wie oben, aber ohne „(Kopie)" im Namen.
//   - Bricht das Duplizieren einer Aktivität ab (Typ ohne Sicherung), bleibt
//     beim Abschnitt stehen, was bis dahin kopiert war.
// Gemessen im Testkurs (Moodle 5.1): Ein Unterabschnitt kommt samt Inhalt
// mit, einzeln wie im duplizierten Abschnitt; Quelltext, Bilder,
// Dateibereiche und Einstellungen sind gleich; eine Textseite braucht etwa
// drei Sekunden samt Vergleich.
// Eine Freigabe erst bei Bestätigungen „alle": Am Bestehenden ändert sich
// nichts, und die Kopie wird danach verborgen wie alles neu Angelegte (A3).
// Duplizieren ist nicht idempotent -- ein zweiter Aufruf legt eine zweite
// Kopie an.

Future<String> duplizieren(MoodleZugang moodle, Freigaben freigaben,
    {required int kurs,
    int? cmid,
    int? abschnittId,
    required String name,
    required String arbeitsordner,
    int? zielAbschnittId,
    int? vorCmid}) async {
  final k = await kursLesen(moodle, kurs);
  final z = _ziel(k, cmid, abschnittId, name);
  final kursText = await kursBezeichnung(moodle, kurs);
  if (z.cm != null) {
    return _aktivitaetDuplizieren(
        moodle, freigaben, k, z.cm!, kursText, arbeitsordner, zielAbschnittId, vorCmid);
  }
  if (zielAbschnittId != null || vorCmid != null) {
    throw MoodleFehler('Ein Abschnitt kommt immer direkt hinter das Original; woandershin danach '
        'mit verschieben. ziel_abschnitt_id und vor_cmid gelten nur für Aktivitäten.');
  }
  return _abschnittDuplizieren(moodle, freigaben, k, z.abschnitt!, kursText, arbeitsordner);
}

/// Führt eine Duplizier-Aktion aus. Ein Fehler zählt erst, wenn danach auch
/// nichts Neues in der Kursstruktur steht: Beim Abschnitt bleibt stehen, was
/// bis zum Fehler kopiert war, und nach einer Zeitüberschreitung arbeitet
/// Moodle womöglich weiter.
Future<(KursStruktur, MoodleFehler?)> _duplizierAktion(
    MoodleZugang moodle, int kurs, String aktion, List<int> ids, bool Function(KursStruktur) nichtsNeues,
    {int? zielAbschnitt, int? zielCmid}) async {
  MoodleFehler? fehler;
  try {
    await kursAktion(moodle, kurs, aktion, ids, zielAbschnitt: zielAbschnitt, zielCmid: zielCmid);
  } on MoodleFehler catch (x) {
    fehler = x;
  }
  final k = await kursLesen(moodle, kurs);
  if (fehler != null && nichtsNeues(k)) {
    throw MoodleFehler('${fehler.meldung}\nIn der Kursstruktur steht keine Kopie. Moodle kann nach '
        'einer Zeitüberschreitung noch weiterarbeiten: nicht gleich erneut duplizieren, sondern in ein '
        'paar Minuten mit kurs_uebersicht nachsehen.');
  }
  return (k, fehler);
}

Future<String> _aktivitaetDuplizieren(MoodleZugang moodle, Freigaben freigaben, KursStruktur k,
    KursAktivitaet c, String kursText, String arbeitsordner, int? zielAbschnittId, int? vorCmid) async {
  final kurs = k.kurs;
  if (vorCmid != null && zielAbschnittId == null) {
    throw MoodleFehler('ziel_abschnitt_id fehlt: vor_cmid gilt nur zusammen mit dem Zielabschnitt.');
  }
  if (zielAbschnittId != null) {
    final ziel = k.nachId[zielAbschnittId];
    if (ziel == null) throw MoodleFehler('Abschnitt id $zielAbschnittId gibt es in Kurs $kurs nicht.');
    if (c.unterabschnittId == zielAbschnittId) {
      throw MoodleFehler('Ein Unterabschnitt kann nicht in sich selbst liegen.');
    }
    if (c.unterabschnittId != null && ziel.istUnterabschnitt) {
      throw MoodleFehler('Unterabschnitte lassen sich nicht ineinander schachteln.');
    }
    if (vorCmid != null && !ziel.aktivitaeten.any((x) => x.cmid == vorCmid)) {
      throw MoodleFehler('cmid $vorCmid liegt nicht im Abschnitt „${ziel.titel}".');
    }
  }
  // Erst nach den Prüfungen oben: Ein Dialog zu einem Aufruf, der ohnehin
  // abbricht, kostete die Lehrkraft eine Entscheidung für nichts.
  final ja = await freigaben.anfragen(FreigabeAnfrage(
    titel: 'Duplizieren?',
    punkte: [
      '${typName(c.modul)} „${c.name}" (cmid ${c.cmid}) in $kursText',
      'Die Kopie kommt ${zielAbschnittId == null ? 'direkt unter das Original' : 'nach „${k.nachId[zielAbschnittId]!.titel}"'}, '
          'heißt „${c.name} (Kopie)" und wird verborgen.',
      'Am Original ändert sich nichts. Ohne Daten von Lernenden.',
    ],
    vergleich: const [],
    knopf: 'Duplizieren',
    ohneEntscheidung: 'wird nichts kopiert',
    ab: Bestaetigungen.alle,
  ));
  if (!ja) return 'Nicht dupliziert: ${_nichtGefragt(freigaben)}';

  final stelle = zielAbschnittId ?? c.abschnittId;
  final vorher = k.nachCmid.keys.toSet();
  // Nur in der Zielstelle suchen: Beim Unterabschnitt kommen auch neue
  // Aktivitäten in seinem neuen Abschnitt hinzu.
  List<KursAktivitaet> neue(KursStruktur s) => [
        ...?s.nachId[stelle]?.aktivitaeten.where((x) => !vorher.contains(x.cmid) && x.modul == c.modul)
      ];
  var (s, fehler) = await _duplizierAktion(moodle, kurs, 'cm_duplicate', [c.cmid], (s) => neue(s).isEmpty,
      zielAbschnitt: zielAbschnittId, zielCmid: vorCmid);
  final neu = neue(s);
  if (neu.length != 1) {
    throw MoodleFehler('Dupliziert, aber die Kopie ist nicht eindeutig zu finden (${neu.length} neue '
        '${typName(c.modul)}-Einträge in „${s.nachId[stelle]?.titel}"). Bitte mit kurs_uebersicht prüfen.');
  }
  final kopieId = neu.single.cmid;

  // Verbergen; einen Unterabschnitt über seinen Abschnitt (siehe oben).
  final unter = neu.single.unterabschnittId == null ? null : s.nachId[neu.single.unterabschnittId];
  if (unter != null ? unter.sichtbar : neu.single.sichtbar) {
    await kursAktion(moodle, kurs, unter != null ? 'section_hide' : 'cm_hide', [unter?.id ?? kopieId]);
    s = await kursLesen(moodle, kurs);
  }
  final kopie = s.nachCmid[kopieId];
  if (kopie == null) throw MoodleFehler('Die Kopie (cmid $kopieId) steht nicht mehr in der Kursstruktur.');
  final kopieUnter = kopie.unterabschnittId == null ? null : s.nachId[kopie.unterabschnittId];

  final probe = Probe();
  probe.pruefe(nameNormal(kopie.name).startsWith(nameNormal(c.name)), 'Name (gelesen „${kopie.name}")');
  final liste = s.nachId[stelle]?.aktivitaeten.map((x) => x.cmid).toList() ?? const [];
  final i = liste.indexOf(kopieId);
  final erwartet = vorCmid != null
      ? i + 1 < liste.length && liste[i + 1] == vorCmid
      : zielAbschnittId != null
          ? i == liste.length - 1
          : i > 0 && liste[i - 1] == c.cmid;
  probe.pruefe(erwartet, 'Position (${i + 1} von ${liste.length})');
  probe.pruefe(!(kopieUnter?.sichtbar ?? kopie.sichtbar), 'verborgen');
  final origUnter = c.unterabschnittId == null ? null : s.nachId[c.unterabschnittId];
  if (origUnter != null && kopieUnter != null) _inhaltVergleichen(probe, s, origUnter, kopieUnter, vorher);

  final g = await _formulareVergleichen(moodle, probe, Formularziel.aktivitaet(c.cmid),
      Formularziel.aktivitaet(kopieId), arbeitsordner, ohne: const {'name', 'visible', 'cmidnumber'});
  return [
    'Dupliziert: ${typName(c.modul)} „${c.name}" (cmid ${c.cmid}) in $kursText. Kopie: „${kopie.name}", '
        'cmid $kopieId, in „${s.nachId[stelle]?.titel}", Position ${i + 1} von ${liste.length}, verborgen.',
    if (fehler != null) 'Moodle meldete dabei: ${fehler.meldung}',
    probe.text,
    if (origUnter != null && kopieUnter != null) _zuordnung(s, origUnter, kopieUnter),
    'Die Kopie ist gelesen, zum Bearbeiten: ${g.ordner} (Name ändern mit aendern, Einstellung name). '
        'Sichtbar machen mit sichtbarkeit_setzen, wenn sie fertig ist.',
  ].join('\n');
}

Future<String> _abschnittDuplizieren(MoodleZugang moodle, Freigaben freigaben, KursStruktur k,
    KursAbschnitt a, String kursText, String arbeitsordner) async {
  final kurs = k.kurs;
  if (a.istUnterabschnitt) {
    throw MoodleFehler('Einen Unterabschnitt dupliziert man über seine Kopf-Aktivität (cmid, Typ subsection).');
  }
  if (a.nummer == 0) {
    throw MoodleFehler('Den allgemeinen Abschnitt (Nummer 0) dupliziert die App nicht.');
  }
  final ja = await freigaben.anfragen(FreigabeAnfrage(
    titel: 'Abschnitt duplizieren?',
    punkte: [
      'Abschnitt „${a.titel}" (id ${a.id}) in $kursText',
      _inhaltText(k, a),
      'Die Kopie kommt direkt dahinter, heißt „${a.titel} (Kopie)" und wird verborgen.',
      'Am Original ändert sich nichts. Ohne Daten von Lernenden.',
    ],
    vergleich: const [],
    knopf: 'Duplizieren',
    ohneEntscheidung: 'wird nichts kopiert',
    ab: Bestaetigungen.alle,
  ));
  if (!ja) return 'Nicht dupliziert: ${_nichtGefragt(freigaben)}';
  final vorher = k.nachId.keys.toSet();
  final vorherCms = k.nachCmid.keys.toSet();
  List<KursAbschnitt> neue(KursStruktur s) =>
      s.abschnitte.where((x) => !vorher.contains(x.id) && !x.istUnterabschnitt).toList();
  var (s, fehler) =
      await _duplizierAktion(moodle, kurs, 'section_duplicate', [a.id], (s) => neue(s).isEmpty);
  final neu = neue(s);
  if (neu.length != 1) {
    throw MoodleFehler('Dupliziert, aber die Kopie ist nicht eindeutig zu finden (${neu.length} neue '
        'Abschnitte). Bitte mit kurs_uebersicht prüfen.');
  }
  final kopieId = neu.single.id;
  if (neu.single.sichtbar) {
    await kursAktion(moodle, kurs, 'section_hide', [kopieId]);
    s = await kursLesen(moodle, kurs);
  }
  final kopie = s.nachId[kopieId];
  if (kopie == null) throw MoodleFehler('Die Kopie (Abschnitt id $kopieId) steht nicht mehr in der Kursstruktur.');
  final original = s.nachId[a.id] ?? a;

  final probe = Probe();
  final haupt = s.abschnitte.where((x) => !x.istUnterabschnitt).map((x) => x.id).toList();
  final i = haupt.indexOf(kopieId);
  probe.pruefe(i > 0 && haupt[i - 1] == a.id, 'direkt hinter dem Original');
  probe.pruefe(!kopie.sichtbar, 'verborgen');
  _inhaltVergleichen(probe, s, original, kopie, vorherCms);
  // Die Beschreibung mit ihren Dateien. Nicht jede Aktivität einzeln: das
  // wären zwei Formularabrufe je Aktivität.
  final g = await _formulareVergleichen(
      moodle, probe, Formularziel.abschnitt(a.id), Formularziel.abschnitt(kopieId), arbeitsordner,
      ohne: const {'name'});
  return [
    'Dupliziert: Abschnitt „${a.titel}" (id ${a.id}) in $kursText. Kopie: „${kopie.titel}", '
        'id $kopieId, Nummer ${kopie.nummer}, direkt dahinter, verborgen.',
    if (fehler != null) 'Moodle meldete dabei: ${fehler.meldung}',
    probe.text,
    _zuordnung(s, original, kopie),
    'Beschreibung der Kopie gelesen nach: ${g.ordner}. Sichtbar machen mit sichtbarkeit_setzen, wenn '
        'die Kopie fertig ist.',
  ].join('\n');
}

/// Dieselben Aktivitäten in derselben Reihenfolge, mit Typ und Name, auch in
/// Unterabschnitten -- und in der Kopie nur neue.
void _inhaltVergleichen(Probe probe, KursStruktur s, KursAbschnitt a, KursAbschnitt b, Set<int> vorher) {
  final x = s.inhalt(a), y = s.inhalt(b);
  probe.pruefe(x.length == y.length, 'Anzahl der Aktivitäten (Original ${x.length}, Kopie ${y.length})');
  for (var i = 0; i < x.length && i < y.length; i++) {
    probe.pruefe(x[i].modul == y[i].modul && nameNormal(x[i].name) == nameNormal(y[i].name),
        'Aktivität ${i + 1}: ${typName(x[i].modul)} „${x[i].name}", Kopie ${typName(y[i].modul)} „${y[i].name}"');
  }
  final alt = y.where((c) => vorher.contains(c.cmid)).map((c) => c.cmid).toList();
  probe.pruefe(alt.isEmpty, 'in der Kopie nur neue Aktivitäten (schon vorher da: ${alt.join(", ")})');
}

String _zuordnung(KursStruktur s, KursAbschnitt a, KursAbschnitt b) {
  final x = s.inhalt(a), y = s.inhalt(b);
  if (y.isEmpty) return 'Darin keine Aktivitäten.';
  return [
    'Aktivitäten, Original -> Kopie:',
    for (var i = 0; i < y.length; i++)
      '  ${i < x.length ? x[i].cmid : '?'} -> ${y[i].cmid} ${typName(y[i].modul)} „${y[i].name}"',
  ].join('\n');
}

/// Liest das Formular der Kopie in den Arbeitsordner (zum Weiterarbeiten)
/// und das des Originals in einen Ordner außerhalb -- ein Ordner `cm-<cmid>`
/// im Arbeitsordner kann gerade bearbeitet werden und darf nicht
/// überschrieben werden. Verglichen werden Quelltext der Editorfelder,
/// eingebundene Dateien, Dateibereiche und Einstellungen außer [ohne].
Future<FormularGelesen> _formulareVergleichen(MoodleZugang moodle, Probe probe, Formularziel original,
    Formularziel kopie, String arbeitsordner,
    {required Set<String> ohne}) async {
  final tmp = await Directory.systemTemp.createTemp('moocp_');
  try {
    final a = await formularLesen(moodle, original, tmp.path);
    final b = await formularLesen(moodle, kopie, arbeitsordner);
    String text(FormularGelesen g, String feld) => g.felder.where((x) => x.feld == feld).firstOrNull?.html ?? '';
    for (final f in {...a.felder.map((x) => x.feld), ...b.felder.map((x) => x.feld)}) {
      probe.pruefe(normalisiert(text(a, f)) == normalisiert(text(b, f)), 'Quelltext $f');
    }
    for (final n in {...a.dateien.map((d) => d.name), ...b.dateien.map((d) => d.name)}) {
      final x = File(p.join(a.ordner, 'dateien', n)), y = File(p.join(b.ordner, 'dateien', n));
      probe.pruefe(
          x.existsSync() && y.existsSync() && gleicheBytes(x.readAsBytesSync(), y.readAsBytesSync()), 'Datei $n');
    }
    final ba = bereicheIn(a.ordner), bb = bereicheIn(b.ordner);
    for (final feld in {...ba.keys, ...bb.keys}) {
      final da = ba[feld] ?? const <String, List<int>>{}, db = bb[feld] ?? const <String, List<int>>{};
      for (final pfad in {...da.keys, ...db.keys}) {
        probe.pruefe(da[pfad] != null && db[pfad] != null && gleicheBytes(da[pfad]!, db[pfad]!),
            'bereiche/$feld$pfad');
      }
    }
    final eb = {for (final e in b.einstellungen) e.schluessel: e.wert};
    for (final e in a.einstellungen.where((e) => !ohne.contains(e.schluessel))) {
      probe.pruefe(eb[e.schluessel] == e.wert,
          'Einstellung ${e.label} (Original „${e.wert}", Kopie „${eb[e.schluessel] ?? "fehlt"}")');
    }
    return b;
  } finally {
    try {
      await tmp.delete(recursive: true);
    } on FileSystemException {
      // Bleibt im temporären Ordner des Systems liegen; kein Grund abzubrechen.
    }
  }
}

// ---------------------------------------------------------------------------
// loeschen
// ---------------------------------------------------------------------------

/// Eine Fragensammlung löschen. Eigener Weg, weil sie nicht in der
/// Kursstruktur steht (kurs.dart): Ohne ihn liefe jedes Aufräumen in „cmid …
/// gibt es in Kurs … nicht", und die Lehrkraft müsste in Moodle nachsehen.
Future<String> _fragensammlungLoeschen(
    MoodleZugang moodle, Freigaben freigaben, int kurs, Fragensammlung s, String name) async {
  nameBestaetigen(name, s.name, 'cmid ${s.cmid}');
  final ja = await freigaben.anfragen(FreigabeAnfrage(
    titel: 'Fragensammlung endgültig löschen?',
    punkte: [
      'Fragensammlung „${s.name}" (cmid ${s.cmid}) in ${await kursBezeichnung(moodle, kurs)}',
      'Mit allen Kategorien und Fragen darin, auch denen, die in Tests benutzt werden.',
      'Zurückholen geht nur, wenn der Papierkorb des Kurses eingeschaltet ist.',
    ],
    vergleich: const [],
    knopf: 'Löschen',
  ));
  if (!ja) return 'Nicht gelöscht: ${_nichtGefragt(freigaben)}';
  // Dieselbe Nachprüfung wie bei den Aktivitäten, nur über die Sammlungsliste.
  final jetzt = (await fragensammlungenLesen(moodle, kurs)).where((x) => x.cmid == s.cmid).toList();
  if (jetzt.length != 1 || jetzt.single.name != s.name) {
    throw MoodleFehler('Seit der Freigabe hat sich in Moodle etwas geändert: Die Fragensammlung cmid '
        '${s.cmid} heißt nicht mehr „${s.name}" oder ist weg. Nichts gelöscht.');
  }
  await kursAktion(moodle, kurs, 'cm_delete', [s.cmid]);
  final weg = !(await fragensammlungenLesen(moodle, kurs)).any((x) => x.cmid == s.cmid);
  return weg
      ? 'Gelöscht: Fragensammlung „${s.name}" (cmid ${s.cmid}) in ${await kursBezeichnung(moodle, kurs)}. '
          'verified: true'
      : 'Löschauftrag für „${s.name}" angenommen, aber die Sammlung steht noch in der Liste. verified: false';
}

Future<String> loeschen(MoodleZugang moodle, Freigaben freigaben,
    {required int kurs, int? cmid, int? abschnittId, required String name}) async {
  var k = await kursLesen(moodle, kurs);
  if (cmid != null && !k.nachCmid.containsKey(cmid)) {
    final s = (await fragensammlungenLesen(moodle, kurs)).where((x) => x.cmid == cmid && x.geteilt).toList();
    if (s.length == 1) return _fragensammlungLoeschen(moodle, freigaben, kurs, s.single, name);
  }
  final z = _ziel(k, cmid, abschnittId, name);
  final kursText = await kursBezeichnung(moodle, kurs);

  if (z.cm != null) {
    final c = z.cm!;
    final unter = c.unterabschnittId == null ? null : k.nachId[c.unterabschnittId];
    final ja = await freigaben.anfragen(FreigabeAnfrage(
      titel: 'Endgültig löschen?',
      punkte: [
        '${typName(c.modul)} „${c.name}" (cmid ${c.cmid}) in $kursText, Abschnitt „${k.nachId[c.abschnittId]?.titel ?? '?'}"',
        if (unter != null) _inhaltText(k, unter),
        'Mit allen Inhalten und Dateien. Zurückholen geht nur, wenn der Papierkorb des Kurses '
            'eingeschaltet ist.',
      ],
      vergleich: const [],
      knopf: 'Löschen',
    ));
    if (!ja) return 'Nicht gelöscht: ${_nichtGefragt(freigaben)}';
    await _nachFreigabe(moodle, kurs, cmid, abschnittId, name);
    await kursAktion(moodle, kurs, 'cm_delete', [c.cmid]);
    k = await kursLesen(moodle, kurs);
    var waise = '';
    if (unter != null && k.nachId.containsKey(unter.id)) {
      // Der Abschnitt des Unterabschnitts blieb stehen: gehört zum freigegebenen Löschen.
      await kursAktion(moodle, kurs, 'section_delete', [unter.id]);
      k = await kursLesen(moodle, kurs);
      waise = ' Sein Abschnitt blieb zunächst stehen und wurde nachgelöscht.';
    }
    final weg = !k.nachCmid.containsKey(c.cmid) && (unter == null || !k.nachId.containsKey(unter.id));
    return weg
        ? 'Gelöscht: ${typName(c.modul)} „${c.name}" (cmid ${c.cmid}) in $kursText.$waise verified: true'
        : 'Löschauftrag für „${c.name}" angenommen, aber es steht noch in der Kursstruktur -- '
            'vermutlich löscht Moodle im Hintergrund. verified: false';
  }

  final a = z.abschnitt!;
  if (a.nummer == 0 && !a.istUnterabschnitt) {
    throw MoodleFehler('Den allgemeinen Abschnitt (Nummer 0) löscht Moodle nicht.');
  }
  final ja = await freigaben.anfragen(FreigabeAnfrage(
    titel: 'Abschnitt endgültig löschen?',
    punkte: [
      'Abschnitt „${a.titel}" (id ${a.id}) in $kursText',
      _inhaltText(k, a),
      'Alles darin wird mitgelöscht, mit allen Inhalten und Dateien.',
    ],
    vergleich: const [],
    knopf: 'Löschen',
  ));
  if (!ja) return 'Nicht gelöscht: ${_nichtGefragt(freigaben)}';
  k = await _nachFreigabe(moodle, kurs, cmid, abschnittId, name);
  final unter = k.inhalt(a).where((c) => c.unterabschnittId != null).length;
  await kursAktion(moodle, kurs, 'section_delete', [a.id]);
  k = await kursLesen(moodle, kurs);
  final weg = !k.nachId.containsKey(a.id);
  return weg
      ? 'Gelöscht: Abschnitt „${a.titel}" in $kursText, samt Inhalt. verified: true'
          '${unter == 0 ? '' : '\nDie $unter Unterabschnitt(e) darin löscht Moodle im Hintergrund; etwa eine '
              'Minute lang stehen sie in kurs_uebersicht noch als leere Abschnitte. Nicht nachlöschen.'}'
      : 'Abschnitt „${a.titel}" steht noch in der Kursstruktur. verified: false';
}

// ---------------------------------------------------------------------------
// abschnitt_anlegen
// ---------------------------------------------------------------------------

/// Die Meldung, wenn der Abschnitt [id] angelegt ist, Name und Beschreibung
/// aber nicht gespeichert sind ([grund]: die Meldung des Formulars).
String halbAngelegt(int id, int kurs, String grund, {required bool verborgen}) =>
    'Abschnitt angelegt (id $id, ${verborgen ? 'verborgen' : 'SICHTBAR'}), aber Name und Beschreibung sind nicht '
    'gespeichert: $grund\n'
    'Er steht jetzt ohne Namen in Kurs $kurs. Nicht noch einmal anlegen: entweder mit abschnitt_lesen($id) lesen '
    'und mit aendern füllen, oder mit loeschen(kurs: $kurs, abschnitt_id: $id) entfernen -- beides gehört in den '
    'Plan.';

Future<String> abschnittAnlegen(MoodleZugang moodle, Freigaben freigaben,
    {required int kurs,
    required String name,
    required String arbeitsordner,
    int? nachAbschnittId,
    String? ordner,
    bool sichtbar = false,
    Map<String, Object?> einstellungen = const {}}) async {
  final quelle = ordner == null ? null : imArbeitsordner(ordner, arbeitsordner);
  final inhalt = quelleLesen(quelle, kopf: elementKopfFuer(moodle));
  var k = await kursLesen(moodle, kurs);
  if (nachAbschnittId != null && k.nachId[nachAbschnittId] == null) {
    throw MoodleFehler('Abschnitt id $nachAbschnittId gibt es in Kurs $kurs nicht.');
  }
  final kursText = await kursBezeichnung(moodle, kurs);
  // Wie bei aktivitaet_anlegen: sichtbar ab „mittel", verborgen bei „alle".
  final ja = await freigaben.anfragen(FreigabeAnfrage(
    titel: sichtbar ? 'Abschnitt sichtbar anlegen?' : 'Abschnitt verborgen anlegen?',
    punkte: [
      'Abschnitt „$name" in $kursText${nachAbschnittId == null ? ', am Ende' : ', hinter „${k.nachId[nachAbschnittId]!.titel}"'}',
      sichtbar
          ? 'Für Lernende SOFORT SICHTBAR (sonst legt die App verborgen an).'
          : 'Für Lernende verborgen; sichtbar wird er erst mit sichtbarkeit_setzen.',
    ],
    vergleich: const [],
    knopf: sichtbar ? 'Sichtbar anlegen' : 'Anlegen',
    ohneEntscheidung: 'wird nichts angelegt',
    ab: sichtbar ? Bestaetigungen.mittel : Bestaetigungen.alle,
  ));
  if (!ja) return 'Nicht angelegt: ${_nichtGefragt(freigaben)}';
  final vorher = k.nachId.keys.toSet();
  await kursAktion(moodle, kurs, 'section_add', const [], zielAbschnitt: nachAbschnittId);
  k = await kursLesen(moodle, kurs);
  final neu = k.abschnitte.where((a) => !vorher.contains(a.id)).toList();
  if (neu.length != 1) {
    throw MoodleFehler('Abschnitt angelegt, aber nicht eindeutig zu finden (${neu.length} neue). '
        'Bitte mit kurs_uebersicht prüfen.');
  }
  final id = neu.single.id;
  // Sofort verbergen, noch bevor er einen Namen hat: Lernende sollen keinen
  // leeren „Thema 7" sehen.
  if (!sichtbar) await kursAktion(moodle, kurs, 'section_hide', [id]);

  final ziel = Formularziel.abschnitt(id);
  Future<(Map<String, String>, List<dynamic>)> fuellen() async {
    final f = await formularHolen(moodle, ziel.adresse);
    final e = await formularFuellen(moodle, f,
        quelle: quelle,
        felder: inhalt.felder,
        bereiche: inhalt.bereiche,
        einstellungen: einstellungen,
        name: name,
        was: 'einem Abschnitt');
    await absenden(moodle, f);
    return e;
  }

  // Der Abschnitt steht schon im Kurs, ohne Namen. Scheitert das Füllen --
  // eine unbekannte Einstellung (das Formular gibt es erst jetzt), HTTP 403,
  // weil ein Filter vor der Instanz den Inhalt abweist --, muss die Meldung
  // das sagen; sonst hält die KI den Abschnitt für nicht angelegt und legt
  // beim nächsten Versuch einen zweiten an.
  (Map<String, String>, List<dynamic>) e;
  try {
    try {
      e = await fuellen();
    } on SitzungAbgelaufen {
      e = await fuellen();
    }
  } on MoodleFehler catch (x) {
    throw MoodleFehler(halbAngelegt(id, kurs, x.meldung, verborgen: !sichtbar));
  }
  final g = await formularLesen(moodle, ziel, arbeitsordner);
  final probe = await zuruecklesen(g,
      felder: e.$1, dateien: inhalt.dateien, bereiche: inhalt.bereiche, einstellungen: e.$2.cast(), name: name);
  k = await kursLesen(moodle, kurs);
  final a = k.nachId[id];
  probe.pruefe(a?.sichtbar == sichtbar, 'Sichtbarkeit');
  return [
    'Angelegt: Abschnitt „${a?.titel ?? name}" (Nummer ${a?.nummer}, id $id) in $kursText, '
        '${a?.sichtbar == true ? "SICHTBAR" : "verborgen"}.',
    probe.text,
    'Aktivitäten hinein mit aktivitaet_anlegen(kurs: $kurs, abschnitt_id: $id, …).',
    'Zurückgelesen nach: ${g.ordner}',
  ].join('\n');
}
