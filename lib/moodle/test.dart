// Tests (mod_quiz): Werkzeuge test_lesen und test_aendern. Einen Test legt
// aktivitaet_anlegen (typ quiz) an, seine Einstellungen ändert aendern.
//
// Gelesen wird die Zusammenstellung (/mod/quiz/edit.php), nie Ergebnisse.
// Gemessen in den Browser-Skills:
//   - li.pagenumber trägt id="page-N", li.slot id="slot-N"; in
//     Dokumentreihenfolge ergibt das die Seitenzuordnung. Die Nummer kommt
//     aus der id, nicht aus dem Text („Seite 1"/„Page 1").
//   - edit_rest.php (MIT Unterstrich; ohne gibt es 404) ist der
//     Arbeitsendpunkt: Punkte (updatemaxmark), Reihenfolge (move), Platz
//     entfernen (action DELETE). Er braucht die Instanz-ID (quizid), nicht die
//     cmid. Er lehnt jede Zielseite ab, die größer ist als die Zahl der
//     VORHANDENEN Seiten -- beim Umsortieren schrumpft die Seitenzahl
//     laufend. Deshalb erst flach auf Seite 1 umsortieren und die Aufteilung
//     danach wiederherstellen.
//   - Die Testeinstellung „Fragen pro Seite" und die tatsächliche Aufteilung
//     sind ZWEI DINGE; wiederhergestellt wird aus der gemessenen Verteilung.
//     Ungleich verteilte Seiten sind von Hand gesetzt und lassen sich nach
//     dem Umsortieren nicht wiederherstellen -- dann nur mit seiten_egal.
//   - Der Löschlink eines Platzes (&remove=N) bewirkt beim bloßen Abruf
//     nichts, und die Zahl darin ist die Platznummer, nicht die slotid.
//   - Beste Bewertung: das Dezimalkomma der deutschen Oberfläche; ein Punkt
//     wäre dort das Tausendertrennzeichen.
//   - „Fragen mischen" steht nicht in den Testeinstellungen, sondern als
//     Kästchen je Testabschnitt auf edit.php (input#shuffle-<abschnitt>,
//     data-action="shuffle_questions"); gespeichert wird über edit_rest.php
//     mit class=section, field=updateshufflequestions, newshuffle. Vorgabe aus.
// Hat der Test schon Versuche, verschiebt jede Änderung an Fragen und Punkten
// bestehende Bewertungen -- die Freigabe sagt das.

import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

import '../freigabe.dart';
import 'formular_lesen.dart';
import 'kurs.dart';
import 'moodle_zugang.dart';

class Platz {
  Platz(this.slotid, this.frage, this.typ, this.name, this.punkte, this.seite);
  final int slotid;
  final int? frage;
  final String? typ;
  final String name;
  final double? punkte;
  final int? seite;
  bool get zufall => typ == 'random';
}

/// Ein Testabschnitt (nicht der Kursabschnitt): Überschrift und ob seine
/// Fragen gemischt werden.
class TestAbschnitt {
  TestAbschnitt(this.id, this.name, this.mischen);
  final int id;
  final String name;
  final bool mischen;
}

class TestAufbau {
  TestAufbau(this.cmid, this.quizid, this.kurs, this.plaetze, this.seiten, this.summe, this.beste, this.hatVersuche,
      [this.abschnitte = const []]);
  final int cmid;
  final int? quizid;
  final int? kurs;
  final List<Platz> plaetze;
  final int seiten;
  final double? summe;
  final double? beste;
  final bool hatVersuche;
  final List<TestAbschnitt> abschnitte;

  /// Fragen je Seite, wenn gleichmäßig (jede Seite außer der letzten gleich
  /// viele, die letzte höchstens so viele); sonst null.
  int? get proSeite {
    if (plaetze.any((x) => x.seite == null) || plaetze.isEmpty) return null;
    final je = <int, int>{};
    for (final x in plaetze) {
      je[x.seite!] = (je[x.seite!] ?? 0) + 1;
    }
    final nrs = je.keys.toList()..sort();
    final k = je[nrs.first]!;
    for (final (i, n) in nrs.indexed) {
      if (i < nrs.length - 1 ? je[n] != k : je[n]! > k) return null;
    }
    return k;
  }

  List<String> befunde() => [
        if (summe != null && beste != null && (summe! - beste!).abs() >= 0.005)
          'Beste Bewertung (${_z(beste)}) weicht von der Summe der Fragen (${_z(summe)}) ab.',
        if (plaetze.isEmpty) 'Der Test enthält keine Fragen.',
        if (plaetze.any((x) => x.punkte == 0 && x.typ != 'description'))
          '${plaetze.where((x) => x.punkte == 0 && x.typ != 'description').length} Frage(n) mit 0 Punkten, die keine Beschreibung sind.',
        if (seiten > 1 && proSeite == null) 'Die Seiten sind ungleich belegt (Umbrüche von Hand gesetzt).',
        if (hatVersuche)
          'Zu diesem Test gibt es bereits Versuche: Änderungen an Fragen und Punkten wirken auf bestehende Bewertungen.',
      ];

  String text() {
    final b = StringBuffer('Test cmid $cmid: ${plaetze.length} Plätze auf $seiten Seite(n), Summe der Punkte '
        '${_z(summe)}, Beste Bewertung ${_z(beste)}${proSeite == null ? '' : ', $proSeite je Seite'}\n'
        'Zeilen: Seite · slotid · Typ · „Name" · Punkte · questionid\n');
    for (final x in plaetze) {
      b.writeln('  S.${x.seite ?? '?'} · ${x.slotid} · ${x.typ ?? '?'} · „${x.name}" · ${_z(x.punkte)} P.'
          '${x.frage == null ? '' : ' · ${x.frage}'}');
    }
    for (final a in abschnitte) {
      b.writeln('Fragen mischen: ${a.mischen ? 'an' : 'aus'} (Testabschnitt ${a.id}'
          '${a.name.isEmpty ? '' : ' „${a.name}"'})');
    }
    final f = befunde();
    if (f.isNotEmpty) b.writeln('Befunde:\n${f.map((x) => '  - $x').join('\n')}');
    return b.toString();
  }
}

String _z(double? x) => x == null ? '?' : (x == x.roundToDouble() ? x.toInt().toString() : x.toString());

double? _zahl(String? s) {
  if (s == null) return null;
  final t = s.replaceAll(RegExp(r'[^\d,.\-]'), '');
  if (t.isEmpty) return null;
  // Deutsches Format: Punkt Tausender, Komma Dezimal; sonst englisch.
  return double.tryParse(t.contains(',') ? t.replaceAll('.', '').replaceAll(',', '.') : t);
}

TestAufbau testAuswerten(int cmid, String seite) {
  final d = html_parser.parse(seite);
  final zuSeite = <int, int>{};
  var s = 0, hoechste = 0;
  for (final li in d.querySelectorAll('li.pagenumber, li.slot')) {
    if (li.classes.contains('pagenumber')) {
      s = int.tryParse(li.id.replaceFirst('page-', '')) ?? s + 1;
      if (s > hoechste) hoechste = s;
    } else {
      final id = int.tryParse(li.id.replaceFirst('slot-', ''));
      if (id != null) zuSeite[id] = s;
    }
  }
  final plaetze = <Platz>[];
  for (final li in d.querySelectorAll('li.slot')) {
    final id = int.tryParse(li.id.replaceFirst('slot-', ''));
    if (id == null) continue;
    final typ = RegExp(r'qtype_([a-z]+)').firstMatch(li.className)?.group(1);
    final link = li.querySelector('a[href*="question.php"]')?.attributes['href'];
    final frage = int.tryParse(Uri.tryParse(link ?? '')?.queryParameters['id'] ?? '');
    final name = (li.querySelector('.activityname, .questionname')?.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    plaetze.add(Platz(id, frage, typ, name, _zahl(li.querySelector('.instancemaxmark')?.text), zuSeite[id]));
  }
  final text = (d.body?.text ?? '').replaceAll(RegExp(r'\s+'), ' ');
  final summe = _zahl(RegExp(r'(Summe der Punkte|Total of marks):\s*([\d.,]+)').firstMatch(text)?.group(2));
  final beste = _zahl(d.querySelectorAll('input').where((e) => e.attributes['name'] == 'maxgrade').firstOrNull?.attributes['value']);
  final quizid = int.tryParse(RegExp(r'"quizid"\s*:\s*"?(\d+)').firstMatch(seite)?.group(1) ??
      RegExp(r'quizid=(\d+)').firstMatch(seite)?.group(1) ??
      '');
  final versuche = RegExp(r'Versuche:\s*[1-9]').hasMatch(text) || RegExp(r'Attempts:\s*[1-9]').hasMatch(text);
  // Vom Kästchen aus, nicht von li.section: Die Kursnavigation der Seite
  // hat eigene Abschnittselemente.
  final abschnitte = <TestAbschnitt>[];
  for (final k in d.querySelectorAll('input[data-action="shuffle_questions"]')) {
    final id = int.tryParse(k.id.replaceFirst('shuffle-', ''));
    if (id == null) continue;
    var li = k.parent;
    while (li != null && li.localName != 'li') {
      li = li.parent;
    }
    final name = li?.attributes['data-sectionname'] ?? li?.querySelector('.instancesection')?.text ?? '';
    abschnitte.add(TestAbschnitt(id, name.replaceAll(RegExp(r'\s+'), ' ').trim(), k.attributes.containsKey('checked')));
  }
  return TestAufbau(cmid, quizid, Seitenangaben.aus(seite).kurs, plaetze, hoechste == 0 ? 1 : hoechste, summe, beste,
      versuche, abschnitte);
}

Future<TestAufbau> testLesen(MoodleZugang moodle, int cmid) async {
  final r = await moodle.lesen('/mod/quiz/edit.php?cmid=$cmid');
  final t = testAuswerten(cmid, r.text);
  if (t.quizid == null) throw MoodleFehler('cmid $cmid ist kein Test (keine quizid in der Zusammenstellung).');
  return t;
}

// ---------------------------------------------------------------------------
// test_aendern
// ---------------------------------------------------------------------------

Future<Map> _rest(MoodleZugang moodle, TestAufbau t, Map<String, String> werte) async {
  final s = await moodle.sesskey();
  final a = await moodle.senden('/mod/quiz/edit_rest.php', [
    for (final e in werte.entries) MapEntry(e.key, e.value),
    MapEntry('sesskey', s),
    MapEntry('courseid', '${t.kurs}'),
    MapEntry('quizid', '${t.quizid}'),
  ]);
  Object? j;
  try {
    j = a.text.trim().isEmpty ? {} : jsonDecode(a.text);
  } catch (_) {
    throw MoodleFehler('edit_rest.php antwortete nicht mit JSON: ${a.text.length > 120 ? a.text.substring(0, 120) : a.text}');
  }
  if (j is Map && j['error'] != null) throw MoodleFehler('edit_rest.php: ${j['error']}');
  return j is Map ? j : {};
}

String _komma(num x) => (x == x.roundToDouble() ? x.toInt().toString() : x.toString()).replaceAll('.', ',');

String _aktionText(Map a, TestAufbau t) {
  String platz(Object? id) {
    final x = t.plaetze.where((p) => '${p.slotid}' == '$id').firstOrNull;
    return x == null ? 'Platz $id (gibt es nicht!)' : '„${x.name}" (Platz $id)';
  }

  return switch (a['art']) {
    'frage_hinzufuegen' => 'Frage ${a['frage']} einfügen${a['seite'] == null ? ' (letzte Seite)' : ' auf Seite ${a['seite']}'}',
    'zufall_hinzufuegen' => '${a['anzahl']} Zufallsfrage(n) aus Kategorie ${a['kategorie']}'
        '${a['unterkategorien'] == true ? ' samt Unterkategorien' : ''}',
    'entfernen' => '${platz(a['platz'])} aus dem Test nehmen (die Frage bleibt in der Sammlung)',
    'punkte' => '${platz(a['platz'])}: ${a['wert']} Punkte',
    'verschieben' => '${platz(a['platz'])} hinter ${a['hinter'] == 0 || a['hinter'] == null ? 'den Anfang' : platz(a['hinter'])}',
    'reihenfolge' => 'Reihenfolge: ${(a['plaetze'] as List).map(platz).join(', ')}',
    'seiten' => 'Seiten neu aufteilen: ${a['pro_seite'] == 0 ? 'alles auf eine Seite' : '${a['pro_seite']} je Seite'}',
    'beste_bewertung' => 'Beste Bewertung: ${a['wert'] == 'summe' ? 'Summe der Fragenpunkte (${_z(t.summe)})' : a['wert']}',
    'mischen' => 'Fragen mischen: ${a['an'] == true ? 'an' : 'aus'} (Testabschnitt ${_testabschnitt(a, t).id})',
    _ => throw MoodleFehler('Unbekannte Aktion „${a['art']}". Möglich: frage_hinzufuegen, zufall_hinzufuegen, '
        'entfernen, punkte, verschieben, reihenfolge, seiten, beste_bewertung, mischen.'),
  };
}

/// Der gemeinte Testabschnitt: angegeben, oder der einzige.
TestAbschnitt _testabschnitt(Map a, TestAufbau t) {
  if (a['an'] is! bool) throw MoodleFehler('mischen braucht an: true oder false.');
  if (t.abschnitte.isEmpty) throw MoodleFehler('Kein Kästchen „Fragen mischen" auf der Testseite gefunden.');
  final id = (a['abschnitt'] as num?)?.toInt();
  if (id == null) {
    if (t.abschnitte.length == 1) return t.abschnitte.single;
    throw MoodleFehler('Der Test hat ${t.abschnitte.length} Testabschnitte -- abschnitt angeben: '
        '${t.abschnitte.map((x) => '${x.id}${x.name.isEmpty ? '' : ' „${x.name}"'}').join(', ')}.');
  }
  return t.abschnitte.where((x) => x.id == id).firstOrNull ??
      (throw MoodleFehler('Testabschnitt $id gibt es nicht; vorhanden: ${t.abschnitte.map((x) => x.id).join(', ')}.'));
}

Future<String> testAendern(MoodleZugang moodle, Freigaben freigaben,
    {required int cmid, required String name, required List<Map<String, Object?>> aktionen}) async {
  var t = await testLesen(moodle, cmid);
  final kurs = t.kurs;
  final struktur = kurs == null ? null : await kursLesen(moodle, kurs);
  final c = struktur?.nachCmid[cmid];
  if (c == null) throw MoodleFehler('Test cmid $cmid nicht in der Kursstruktur gefunden.');
  if (c.name.replaceAll(RegExp(r'\s+'), ' ').trim() != name.replaceAll(RegExp(r'\s+'), ' ').trim()) {
    throw MoodleFehler('Abgebrochen, nichts geändert: cmid $cmid heißt „${c.name}", nicht „$name".');
  }
  if (aktionen.isEmpty) throw MoodleFehler('Keine aktionen angegeben.');
  final beschreibung = [for (final a in aktionen) _aktionText(a, t)];
  for (final a in aktionen.where((a) => a['art'] == 'reihenfolge')) {
    final ids = (a['plaetze'] as List).map((x) => '$x').toSet();
    if (ids.length != t.plaetze.length || !t.plaetze.every((x) => ids.contains('${x.slotid}'))) {
      throw MoodleFehler('reihenfolge muss jeden Platz des Tests genau einmal enthalten (slotids aus test_lesen).');
    }
    if (t.seiten > 1 && t.proSeite == null && a['seiten_egal'] != true) {
      throw MoodleFehler('Der Test hat ${t.seiten} ungleich belegte Seiten -- von Hand gesetzte Umbrüche. Umsortieren '
          'wirft sie weg und kann sie nicht wiederherstellen. Nur mit seiten_egal: true, danach seiten neu setzen.');
    }
  }
  final ja = await freigaben.anfragen(FreigabeAnfrage(
    titel: 'Test ändern?',
    punkte: [
      'Test „${c.name}" (cmid $cmid, ${await kursBezeichnung(moodle, kurs!)}): ${t.plaetze.length} Plätze, '
          'Summe ${_z(t.summe)}, Beste Bewertung ${_z(t.beste)}',
      ...beschreibung,
      if (t.hatVersuche) 'ACHTUNG: Es gibt bereits Versuche -- Änderungen verschieben bestehende Bewertungen.',
    ],
    vergleich: const [],
    knopf: 'Ändern',
  ));
  if (!ja) return 'Nicht geändert: in der App abgelehnt oder nicht rechtzeitig freigegeben.';

  final ergebnisse = <String>[];
  for (final a in aktionen) {
    final vorher = t;
    switch (a['art']) {
      case 'frage_hinzufuegen':
        final s = await moodle.sesskey();
        await moodle.aufrufen('/mod/quiz/edit.php?cmid=$cmid&addquestion=${(a['frage'] as num).toInt()}'
            '&addonpage=${(a['seite'] as num?)?.toInt() ?? 0}&sesskey=$s');
        t = await testLesen(moodle, cmid);
        final ok = t.plaetze.length == vorher.plaetze.length + 1;
        ergebnisse.add('Frage ${a['frage']} eingefügt: ${ok ? 'ja' : 'NEIN'}');
      case 'zufall_hinzufuegen':
        final filter = {
          'filter': {
            'category': {
              'jointype': 1,
              'values': [(a['kategorie'] as num).toInt()],
              'filteroptions': {'includesubcategories': a['unterkategorien'] == true},
            }
          }
        };
        await moodle.dienst('mod_quiz_add_random_questions', {
          'cmid': cmid,
          'addonpage': (a['seite'] as num?)?.toInt() ?? 0,
          'randomcount': (a['anzahl'] as num).toInt(),
          'filtercondition': jsonEncode(filter),
        });
        t = await testLesen(moodle, cmid);
        final dazu = t.plaetze.length - vorher.plaetze.length;
        ergebnisse.add('Zufallsfragen: $dazu Platz/Plätze dazu (erwartet ${a['anzahl']})');
      case 'entfernen':
        await _rest(moodle, t, {'class': 'resource', 'action': 'DELETE', 'id': '${a['platz']}'});
        t = await testLesen(moodle, cmid);
        ergebnisse.add('Platz ${a['platz']} entfernt: ${t.plaetze.any((x) => '${x.slotid}' == '${a['platz']}') ? 'NEIN' : 'ja'}');
      case 'punkte':
        final w = (a['wert'] as num).toDouble();
        final j = await _rest(moodle, t, {'class': 'resource', 'field': 'updatemaxmark', 'id': '${a['platz']}', 'maxmark': '$w'});
        final ist = _zahl('${j['instancemaxmark']}');
        ergebnisse.add('Platz ${a['platz']}: ${_z(ist)} Punkte (${ist != null && (ist - w).abs() < 0.005 ? 'ok' : 'ABWEICHEND'}), '
            'neue Summe ${j['newsummarks']}');
        t = await testLesen(moodle, cmid);
      case 'verschieben':
        final hinter = (a['hinter'] as num?)?.toInt() ?? 0;
        var seite = (a['seite'] as num?)?.toInt() ??
            (hinter == 0 ? 1 : t.plaetze.where((x) => x.slotid == hinter).firstOrNull?.seite ?? 1);
        if (seite > t.seiten) seite = t.seiten;
        await _rest(moodle, t, {'class': 'resource', 'field': 'move', 'id': '${a['platz']}', 'previousid': '$hinter', 'page': '$seite'});
        t = await testLesen(moodle, cmid);
        final ids = t.plaetze.map((x) => x.slotid).toList();
        final i = ids.indexOf((a['platz'] as num).toInt());
        final ok = hinter == 0 ? i == 0 : i > 0 && ids[i - 1] == hinter;
        ergebnisse.add('Platz ${a['platz']} verschoben: ${ok ? 'ja' : 'NEIN'}');
      case 'reihenfolge':
        final start = t;
        var vorige = 0;
        for (final id in (a['plaetze'] as List).map((x) => (x as num).toInt())) {
          await _rest(moodle, t, {'class': 'resource', 'field': 'move', 'id': '$id', 'previousid': '$vorige', 'page': '1'});
          vorige = id;
        }
        t = await testLesen(moodle, cmid);
        var wieder = '';
        if (start.seiten > 1 && start.proSeite != null && t.seiten < start.seiten) {
          await _seiten(moodle, cmid, start.proSeite!);
          t = await testLesen(moodle, cmid);
          wieder = ', Seitenaufteilung (${start.proSeite} je Seite) wiederhergestellt';
        }
        final ok = t.plaetze.map((x) => x.slotid).join(',') == (a['plaetze'] as List).join(',');
        ergebnisse.add('Reihenfolge: ${ok ? 'stimmt' : 'STIMMT NICHT'}$wieder; Seiten vorher ${start.seiten}, jetzt ${t.seiten}');
      case 'seiten':
        final n = (a['pro_seite'] as num).toInt();
        await _seiten(moodle, cmid, n);
        t = await testLesen(moodle, cmid);
        final erwartet = n == 0 ? 1 : (t.plaetze.length / n).ceil();
        ergebnisse.add('Seiten: ${t.seiten} (erwartet $erwartet)${t.seiten == erwartet ? '' : ' -- ABWEICHEND'}');
      case 'beste_bewertung':
        final w = a['wert'] == 'summe' ? t.summe : (a['wert'] as num).toDouble();
        if (w == null) throw MoodleFehler('Summe der Fragenpunkte nicht lesbar.');
        final s = await moodle.sesskey();
        await moodle.senden('/mod/quiz/edit.php', [
          MapEntry('cmid', '$cmid'),
          MapEntry('sesskey', s),
          MapEntry('maxgrade', _komma(w)),
          const MapEntry('savechanges', '1'),
        ]);
        t = await testLesen(moodle, cmid);
        ergebnisse.add('Beste Bewertung: ${_z(t.beste)} (${t.beste != null && (t.beste! - w).abs() < 0.005 ? 'ok' : 'ABWEICHEND'})');
      case 'mischen':
        final ab = _testabschnitt(a, t);
        final an = a['an'] == true;
        await _rest(moodle, t,
            {'class': 'section', 'field': 'updateshufflequestions', 'id': '${ab.id}', 'newshuffle': an ? '1' : '0'});
        t = await testLesen(moodle, cmid);
        final ist = t.abschnitte.where((x) => x.id == ab.id).firstOrNull?.mischen;
        ergebnisse.add('Fragen mischen (Testabschnitt ${ab.id}): ${ist == null ? '?' : ist ? 'an' : 'aus'} '
            '(${ist == an ? 'ok' : 'ABWEICHEND'})');
    }
  }
  return '${ergebnisse.join('\n')}\n\n${t.text()}';
}

/// Seitenaufteilung neu setzen -- der Dialog „Neu aufteilen" von edit.php.
/// Er ordnet nur die vorhandenen Plätze neu; die Testeinstellung „Fragen pro
/// Seite" bleibt, wie sie war.
Future<void> _seiten(MoodleZugang moodle, int cmid, int proSeite) async {
  final s = await moodle.sesskey();
  await moodle.senden('/mod/quiz/edit.php', [
    MapEntry('cmid', '$cmid'),
    MapEntry('sesskey', s),
    MapEntry('questionsperpage', '$proSeite'),
    const MapEntry('repaginate', '1'),
  ]);
}
