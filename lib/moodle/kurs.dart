// Die Struktur eines Kurses: Werkzeuge kurs_uebersicht und meine_kurse.
//
// Quelle ist der Dienst, mit dem Moodle selbst die Kursseite im
// Bearbeitungsmodus aufbaut (core_courseformat_get_state): Abschnitte und
// Aktivitäten mit IDs, Typ, Name und Sichtbarkeit. Er liefert nur die
// Struktur -- keine Blöcke, keine Beiträge, keine Daten von Lernenden. Die
// Kursseite selbst wird dafür nicht geladen.
//
// Eigenheiten des Dienstes, die hier aufgefangen werden:
//   - Unterabschnitte (mod_subsection) stehen doppelt darin: als Aktivität
//     im Elternabschnitt UND als eigener („delegierter") Abschnitt. Ohne
//     Auswertung erschiene derselbe Inhalt zweimal und die Gliederung flach.
//   - „modname" ist der übersetzte Anzeigename („Datei"), nicht die Kennung;
//     die Kennung steht in „module" (bzw. „plugin" ohne mod_).
//   - „uservisible" beantwortet nicht, ob Lernende etwas sehen: Aus
//     Lehrersicht steht es auch bei Verborgenem auf true. Maßgeblich ist
//     „visible"; beim Verbergen eines Abschnitts setzt Moodle „visible" aller
//     enthaltenen Aktivitäten mit.
//   - „Stealth" (verfügbar, aber nicht auf der Kursseite) ist nicht
//     geschützt: Wer den Link kennt, kommt hin.
//   - Abschnitte mit Standardnamen heißen nach ihrer Position („Thema 5");
//     nach dem Verschieben heißen sie anders. Kein Fehler.

import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

import '../freigabe.dart';
import 'moodle_zugang.dart';

// Die Fragensammlungen eines Kurses. Sie stehen NICHT in der Kursstruktur
// (core_courseformat_get_state führt sie nicht), deshalb die eigene Quelle:
// die Übersichtsseite, die Moodle selbst dafür hat. Hier statt bei den
// Fragen, weil auch das Anlegen und Löschen einer Aktivität sie braucht.
class Fragensammlung {
  Fragensammlung(this.cmid, this.name, this.geteilt);
  final int cmid;
  final String name;

  /// Geteilt (mod_qbank) -- sonst die eigene Sammlung eines Tests, deren
  /// Fragen anderswo nicht verwendbar sind.
  final bool geteilt;
}

Future<List<Fragensammlung>> fragensammlungenLesen(MoodleZugang moodle, int kurs) async {
  final r = await moodle.lesen('/question/banks.php?courseid=$kurs');
  final d = html_parser.parse(r.text);
  final aus = <int, Fragensammlung>{};
  for (final a in d.querySelectorAll('#region-main a[href]')) {
    final u = Uri.tryParse(a.attributes['href'] ?? '');
    final name = a.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final id = int.tryParse(u?.queryParameters['id'] ?? '');
    if (u == null || id == null || name.isEmpty) continue;
    if (u.path.endsWith('/mod/qbank/view.php')) aus.putIfAbsent(id, () => Fragensammlung(id, name, true));
    if (u.path.endsWith('/mod/quiz/view.php')) aus.putIfAbsent(id, () => Fragensammlung(id, name, false));
  }
  return aus.values.toList();
}

/// Wie Lernende an etwas herankommen.
enum Sichtbarkeit {
  sichtbar('sichtbar'),
  verborgen('verborgen'),

  /// Nicht auf der Kursseite, aber per Link abrufbar -- schützt nichts.
  ohneLink('verfügbar ohne Link auf der Kursseite'),

  /// Sichtbar, aber mit Voraussetzungen.
  eingeschraenkt('eingeschränkt');

  const Sichtbarkeit(this.text);
  final String text;

  bool get erreichbar => this != verborgen;
}

/// Klingt nach Lösung, Erwartungshorizont oder Lehrermaterial. Nur ein
/// Verdachtsraster: Es ersetzt kein Nachdenken, fängt aber die häufigsten
/// Fälle. „intern" mit Endung, damit „interne Notizen" greift, „Internet" nicht.
final loesungVerdacht = RegExp(
    r'lösung|loesung|solution|erwartungshorizont|musterl|klausur|lehrer|\bintern(e|es|er|en)?\b|handreichung',
    caseSensitive: false);

class KursAktivitaet {
  KursAktivitaet(this.cmid, this.modul, this.name, this.sichtbarkeit, this.einzug, this.abschnittId);
  final int cmid;
  final String modul;
  final String name;
  final Sichtbarkeit sichtbarkeit;
  final int einzug;
  final int abschnittId;

  /// Bei einem Unterabschnitt (modul „subsection") die id seines Abschnitts.
  int? unterabschnittId;

  bool get sichtbar => sichtbarkeit != Sichtbarkeit.verborgen;
}

class KursAbschnitt {
  KursAbschnitt(this.id, this.nummer, this.titel, this.sichtbar, this.eingeschraenkt, this.aktivitaeten,
      {this.komponente, this.elternId});
  final int id;
  final int nummer;
  final String titel;
  final bool sichtbar;
  final bool eingeschraenkt;
  final List<KursAktivitaet> aktivitaeten;

  /// Gesetzt bei delegierten Abschnitten (mod_subsection).
  final String? komponente;

  /// Der Abschnitt, in dem der Unterabschnitt liegt.
  int? elternId;

  bool get istUnterabschnitt => komponente != null;
}

class KursStruktur {
  KursStruktur(this.kurs, this.abschnitte, this.roh);
  final int kurs;

  /// Alle Abschnitte, auch Unterabschnitte, in Moodles Reihenfolge.
  final List<KursAbschnitt> abschnitte;

  /// Die Antwort des Dienstes, unverändert.
  final Map roh;

  Map<int, KursAktivitaet> get nachCmid =>
      {for (final a in abschnitte) for (final c in a.aktivitaeten) c.cmid: c};

  Map<int, KursAbschnitt> get nachId => {for (final a in abschnitte) a.id: a};

  KursAbschnitt? abschnittNr(int nummer) => abschnitte.where((a) => a.nummer == nummer).firstOrNull;

  /// Alles, was in einem Abschnitt liegt, auch in seinen Unterabschnitten.
  List<KursAktivitaet> inhalt(KursAbschnitt a) => [
        for (final c in a.aktivitaeten) ...[
          c,
          if (c.unterabschnittId != null && nachId[c.unterabschnittId] != null)
            ...inhalt(nachId[c.unterabschnittId]!),
        ]
      ];

  /// Erreichbares, das nach Lösung, Erwartungshorizont oder Lehrermaterial
  /// klingt -- auch in einem Abschnitt mit solchem Namen.
  List<(KursAktivitaet, KursAbschnitt)> schutzBefunde() => [
        for (final a in abschnitte)
          for (final c in a.aktivitaeten)
            if (c.sichtbarkeit.erreichbar && (loesungVerdacht.hasMatch(c.name) || loesungVerdacht.hasMatch(a.titel)))
              (c, a)
      ];

  String text({String? kursname}) {
    final alle = nachCmid.values;
    final verborgen = alle.where((c) => !c.sichtbar).length;
    final t = StringBuffer()
      ..writeln('Kurs $kurs${kursname == null ? '' : ' „$kursname"'}: '
          '${abschnitte.where((a) => !a.istUnterabschnitt).length} Abschnitte, ${alle.length} Aktivitäten'
          '${verborgen > 0 ? ' ($verborgen verborgen)' : ''}')
      ..writeln('Zeilen: Abschnitt <Nummer> [id <Abschnitts-ID>] „Titel"; darunter cmid Typ „Name" '
          '[Sichtbarkeit]. Lesen mit aktivitaet_lesen(cmid) bzw. abschnitt_lesen(abschnitt_id).');
    void abschnitt(KursAbschnitt a, int tiefe) {
      final einzug = '  ' * tiefe;
      t.writeln('${einzug}Abschnitt ${a.nummer} [id ${a.id}] „${a.titel}"'
          '${a.istUnterabschnitt ? ' (Unterabschnitt)' : ''}'
          '${a.sichtbar ? '' : ' [verborgen]'}${a.eingeschraenkt ? ' [eingeschränkt]' : ''}');
      for (final c in a.aktivitaeten) {
        final zustand = c.sichtbarkeit == Sichtbarkeit.sichtbar ? '' : ' [${c.sichtbarkeit.text}]';
        t.writeln('$einzug  ${'  ' * c.einzug}${c.cmid} ${c.modul} „${c.name}"$zustand');
        final u = c.unterabschnittId == null ? null : nachId[c.unterabschnittId];
        if (u != null) abschnitt(u, tiefe + 2);
      }
    }

    final gezeigt = <int>{
      for (final c in alle)
        if (c.unterabschnittId != null) c.unterabschnittId!
    };
    for (final a in abschnitte.where((a) => !gezeigt.contains(a.id))) {
      abschnitt(a, 0);
    }
    final schutz = schutzBefunde();
    if (schutz.isNotEmpty) {
      t.writeln('\nACHTUNG, für Lernende erreichbar, obwohl es nach Lösung oder Lehrermaterial klingt:');
      for (final (c, a) in schutz) {
        t.writeln('  ${c.cmid} ${c.modul} „${c.name}" in „${a.titel}" [${c.sichtbarkeit.text}]'
            '${c.sichtbarkeit == Sichtbarkeit.ohneLink ? ' -- nicht auf der Kursseite, aber per Link abrufbar' : ''}');
      }
    }
    return t.toString();
  }
}

String _klartext(Object? s) => html_parser.parseFragment('${s ?? ''}').text ?? '';
int? _ganz(Object? x) => x is int ? x : int.tryParse('${x ?? ''}');
bool _wahr(Object? x) => x == true || x == 1 || x == '1' || x == 'true';

/// Wertet die Antwort von core_courseformat_get_state aus. Ohne Netz
/// prüfbar (test/kurs_test.dart).
KursStruktur kursAuswerten(int kurs, Map zustand) {
  final cms = <int, KursAktivitaet>{};
  final delegiert = <int, int>{}; // cmid des Unterabschnitts -> id seines Abschnitts
  for (final c in (zustand['cm'] as List? ?? const [])) {
    if (c is! Map) continue;
    final id = _ganz(c['id']);
    if (id == null) continue;
    final sb = !_wahr(c['visible'])
        ? Sichtbarkeit.verborgen
        : _wahr(c['stealth'])
            ? Sichtbarkeit.ohneLink
            : _wahr(c['hascmrestrictions'])
                ? Sichtbarkeit.eingeschraenkt
                : Sichtbarkeit.sichtbar;
    final plugin = '${c['plugin'] ?? ''}';
    final modul = '${c['module'] ?? (plugin.startsWith('mod_') ? plugin.substring(4) : c['modname']) ?? '?'}';
    cms[id] = KursAktivitaet(id, modul, _klartext(c['name']), sb, _ganz(c['indent']) ?? 0,
        _ganz(c['sectionid']) ?? 0);
    final d = _ganz(c['delegatesectionid']);
    if (d != null && d > 0) delegiert[id] = d;
  }
  final abschnitte = <KursAbschnitt>[];
  for (final s in (zustand['section'] as List? ?? const [])) {
    if (s is! Map) continue;
    final id = _ganz(s['id']);
    if (id == null) continue;
    final liste = [
      for (final c in (s['cmlist'] as List? ?? const []))
        if (cms[_ganz(c)] != null) cms[_ganz(c)]!
    ];
    final komponente = '${s['component'] ?? ''}';
    final eltern = _ganz(s['parentsectionid']);
    abschnitte.add(KursAbschnitt(id, _ganz(s['number'] ?? s['section']) ?? abschnitte.length,
        _klartext(s['title'] ?? s['rawtitle']), _wahr(s['visible']), _wahr(s['hasrestrictions']), liste,
        komponente: komponente.isEmpty || komponente == 'null' ? null : komponente,
        elternId: eltern != null && eltern > 0 ? eltern : null));
  }
  final kursInfo = zustand['course'];
  final reihenfolge = [
    for (final i in (kursInfo is Map ? kursInfo['sectionlist'] as List? : null) ?? const []) _ganz(i)
  ];
  if (reihenfolge.isNotEmpty) {
    int stelle(KursAbschnitt a) {
      final x = reihenfolge.indexOf(a.id);
      return x < 0 ? 1 << 30 : x;
    }

    abschnitte.sort((a, b) => stelle(a) == stelle(b) ? a.nummer.compareTo(b.nummer) : stelle(a).compareTo(stelle(b)));
  } else {
    abschnitte.sort((a, b) => a.nummer.compareTo(b.nummer));
  }

  // Unterabschnitte zuordnen: über delegatesectionid der Aktivität, sonst
  // über parentsectionid des Abschnitts in Reihenfolge (die n-te
  // Unterabschnitt-Aktivität eines Abschnitts gehört zum n-ten delegierten
  // Abschnitt mit diesem Elternabschnitt).
  final nachId = {for (final a in abschnitte) a.id: a};
  for (final e in delegiert.entries) {
    final c = cms[e.key]!;
    c.unterabschnittId = e.value;
    nachId[e.value]?.elternId ??= c.abschnittId;
  }
  for (final a in abschnitte) {
    final offen = a.aktivitaeten.where((c) => c.modul == 'subsection' && c.unterabschnittId == null).toList();
    final frei = abschnitte
        .where((k) => k.istUnterabschnitt && k.elternId == a.id && !cms.values.any((c) => c.unterabschnittId == k.id))
        .toList();
    for (var i = 0; i < offen.length && i < frei.length; i++) {
      offen[i].unterabschnittId = frei[i].id;
    }
  }
  return KursStruktur(kurs, abschnitte, zustand);
}

Future<KursStruktur> kursLesen(MoodleZugang moodle, int kurs) async {
  final roh = await moodle.dienst('core_courseformat_get_state', {'courseid': kurs});
  final Map zustand;
  try {
    zustand = (roh is String ? jsonDecode(roh) : roh) as Map;
  } catch (_) {
    throw MoodleFehler('Kursstruktur von Kurs $kurs: unerwartete Antwort.');
  }
  return kursAuswerten(kurs, zustand);
}

/// Ab welcher Stufe das Füllen oder Ändern von [cmids] gefragt wird: „alle",
/// wenn die App jede davon seit der Anmeldung selbst verborgen angelegt hat
/// ([MoodleZugang.selbstAngelegt]) und sie noch verborgen ist. Dann gehört
/// sie der Arbeitssitzung, Lernende haben sie nie gesehen, und sie zu füllen
/// ist Teil des Anlegens -- „mittel" fragt nur, was Bestehendes anfasst oder
/// sofort sichtbar wird (E20). Sonst „mittel". Löschen, Sichtbarkeit und
/// Verschieben fragen nicht hierüber, sondern immer.
Future<Bestaetigungen> fuellenAb(MoodleZugang moodle, int? kurs, Iterable<int?> cmids) async {
  // Die Kursstruktur nur lesen, wenn es darauf ankommt: Meist ist es eine
  // Aktivität, die die App nicht selbst angelegt hat.
  if (kurs == null || cmids.isEmpty || !cmids.every((c) => c != null && moodle.selbstAngelegt.contains(c))) {
    return Bestaetigungen.mittel;
  }
  return fuellenAbIn(await kursLesen(moodle, kurs), moodle.selbstAngelegt, cmids);
}

/// [fuellenAb] an einer gelesenen Kursstruktur.
Bestaetigungen fuellenAbIn(KursStruktur s, Set<int> selbstAngelegt, Iterable<int?> cmids) =>
    cmids.isNotEmpty && cmids.every((c) => c != null && selbstAngelegt.contains(c) && s.nachCmid[c]?.sichtbar == false)
        ? Bestaetigungen.alle
        : Bestaetigungen.mittel;

/// Ein Kurs der eigenen Kursliste.
class MeinKurs {
  MeinKurs(this.id, this.name, this.kurzname, this.sichtbar);
  final int id;
  final String name;
  final String kurzname;
  final bool sichtbar;
}

final Map<int, String> _kursnamen = {};

/// Die eigenen Kurse, wie im Block „Meine Kurse": nur Nummer und Namen.
Future<List<MeinKurs>> meineKurse(MoodleZugang moodle) async {
  final roh = await moodle.dienst('core_course_get_enrolled_courses_by_timeline_classification',
      {'classification': 'all', 'limit': 0, 'offset': 0, 'sort': 'fullname'});
  final liste = (roh is Map ? roh['courses'] : null) as List? ?? const [];
  final aus = [
    for (final k in liste)
      if (k is Map && _ganz(k['id']) != null)
        MeinKurs(_ganz(k['id'])!, _klartext(k['fullname']), _klartext(k['shortname']), !_wahr(k['hidden']))
  ];
  for (final k in aus) {
    _kursnamen[k.id] = k.name;
  }
  return aus;
}

/// Die zuletzt besuchten eigenen Kurse, neueste zuerst.
Future<List<MeinKurs>> zuletztBesucht(MoodleZugang moodle, {int anzahl = 5}) async {
  if (moodle.eigeneId == null) {
    await moodle.eigeneIdErmitteln();
  }
  final roh = await moodle.dienst('core_course_get_recent_courses',
      {'userid': moodle.eigeneId, 'limit': anzahl.clamp(1, 20), 'offset': 0, 'sort': 'timeaccess desc'});
  return [
    for (final k in (roh as List? ?? const []))
      if (k is Map && _ganz(k['id']) != null)
        MeinKurs(_ganz(k['id'])!, _klartext(k['fullname']), _klartext(k['shortname']), _wahr(k['visible']))
  ];
}

/// Voller Name eines Kurses aus der eigenen Kursliste, sonst null.
Future<String?> kursname(MoodleZugang moodle, int kurs) async {
  if (!_kursnamen.containsKey(kurs)) {
    try {
      await meineKurse(moodle);
    } on MoodleFehler {
      return null;
    }
  }
  return _kursnamen[kurs];
}

/// „Kurs 12 „Beispielkurs"" -- für Meldungen und die Freigabe.
Future<String> kursBezeichnung(MoodleZugang moodle, int kurs) async {
  final n = await kursname(moodle, kurs);
  return n == null ? 'Kurs $kurs' : 'Kurs $kurs „$n"';
}
