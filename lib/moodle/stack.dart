// STACK: Werkzeuge stack_testen, stack_varianten, stack_cas.
//
// STACK ist der Fragetyp, der sich selbst prüfen kann: Jede Frage trägt
// Fragetests, und questiontestrun.php meldet maschinenlesbar, ob sie
// bestanden sind. Daraus folgt die Regel: Keine STACK-Frage geht raus, ohne
// dass ihre Testfälle gelaufen sind. Bei Zufallsvariablen (rand) gilt das je
// Variante -- erst beim Einsetzen (deploy.php) rechnet STACK jede Variante
// durch; vorher weiß man nur, dass EINE funktioniert.
//
// Ausgewertet wird die Klasse pass/fail an den Zeilen, nicht der deutsche
// Text -- der wechselt mit der Spracheinstellung. Tabellen mit 6 Spalten sind
// Eingaben, mit mehr Rückmeldebäume, mit 4 die Liste der Varianten. Der
// Antworthinweis steckt in einem <details>: Die Zusammenfassung IST der
// Hinweis, der Rest ist CAS-Fehlersuche und würde die Spalte unlesbar machen.
//
// „Antworten analysieren" (questiontestreport.php) wertet echte Abgaben aus
// und steht auf der Sperrliste.

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../freigabe.dart';
import 'formular.dart';
import 'moodle_zugang.dart';

const String _stack = '/question/type/stack/';

String _text(dom.Element? e) => (e?.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

List<String> _zellen(dom.Element tr) => [
      for (final td in tr.querySelectorAll('td'))
        () {
          final k = td.clone(true);
          for (final d in k.querySelectorAll('details')) {
            d.replaceWith(dom.Text(_text(d.querySelector('summary'))));
          }
          return _text(k);
        }()
    ];

/// Nächstliegende Überschrift oberhalb -- ordnet Tabellen ihrem Testfall zu,
/// ohne auf deutsche Beschriftungen zu bauen.
String _ueberschrift(dom.Element el) {
  dom.Element? n = el;
  while (n != null) {
    var s = n.previousElementSibling;
    while (s != null) {
      if (RegExp(r'^h[1-6]$').hasMatch(s.localName ?? '')) return _text(s);
      s = s.previousElementSibling;
    }
    n = n.parent;
  }
  return '';
}

bool _pass(dom.Element e) => e.classes.contains('pass');

Future<String> stackTesten(MoodleZugang moodle, {required int sammlung, required int frage, int? seed}) async {
  final r = await moodle.lesen('${_stack}questiontestrun.php?questionid=$frage&cmid=$sammlung${seed == null ? '' : '&seed=$seed'}');
  final d = html_parser.parse(r.text);
  final haupt = d.querySelector('#region-main');
  if (haupt == null) throw MoodleFehler('Testseite nicht lesbar -- ist $frage eine STACK-Frage?');
  final gesamt = d.querySelector('.overallresult');
  final faelle = <String, List<String>>{};
  final durchgefallen = <String>[];
  var anzahl = 0;
  var verworfen = false;
  for (final tab in haupt.querySelectorAll('table.stacktestsuite')) {
    final spalten = tab.querySelectorAll('thead th').length;
    final titel = _ueberschrift(tab);
    // Sechs Spalten: die Eingaben des Testfalls -- Name, Wert aus dem
    // Testfall, übernommener Wert, Anzeige, Status, Fehler. Ist der
    // übernommene Wert leer, hat STACK den Testwert verworfen und rechnet
    // die Bäume gar nicht; die Zeilen darunter bleiben dann leer, und ohne
    // diesen Hinweis sucht man den Fehler im Baum statt in der Eingabe.
    if (spalten == 6) {
      for (final tr in tab.querySelectorAll('tbody tr')) {
        final z = _zellen(tr);
        if (z.length < 6 || z[1].isEmpty || z[2].isNotEmpty) continue;
        final warum = [z[4], z[5]].where((t) => t.isNotEmpty).join(' -- ');
        faelle.putIfAbsent(titel, () => []).add('! Eingabe ${z[0]}: „${z[1]}" nicht übernommen'
            '${warum.isEmpty ? '' : ' ($warum)'}');
        verworfen = true;
      }
      continue;
    }
    if (spalten < 7) continue;
    anzahl++;
    for (final tr in tab.querySelectorAll('tbody tr')) {
      final z = _zellen(tr);
      if (z.length < 7) continue;
      final ok = _pass(tr);
      faelle.putIfAbsent(titel, () => []).add('${ok ? '✓' : '✗'} ${z[0]}: ${z[1]} P. (erwartet ${z[2]}), '
          'Hinweis „${z[5]}" (erwartet „${z[6]}")');
      if (!ok) durchgefallen.add('$titel / ${z[0]}: ${z[1]} statt ${z[2]}, „${z[5]}" statt „${z[6]}"');
    }
  }
  final meldungen = [
    for (final e in haupt.querySelectorAll('.alert-danger, .notifyproblem, .error')) _text(e)
  ].where((t) => t.isNotEmpty).toSet();
  final bestanden = gesamt != null && _pass(gesamt) && durchgefallen.isEmpty && anzahl > 0;
  final b = StringBuffer('STACK-Frage $frage${seed == null ? '' : ', Variante $seed'}: '
      '${anzahl == 0 ? 'KEINE Testfälle -- nicht überprüfbar' : bestanden ? 'alle $anzahl Testfälle bestanden' : 'NICHT bestanden'}. '
      'verified: $bestanden\n');
  if (verworfen) {
    b.writeln('Mindestens eine Testeingabe hat STACK nicht übernommen; dieser Testfall prüft dann nichts. '
        'Bei Auswahllisten (dropdown, radio) muss die Testeingabe eine der Optionen sein, wie sie dasteht.');
  }
  for (final e in faelle.entries) {
    b.writeln('${e.key}:');
    for (final z in e.value) {
      b.writeln('  $z');
    }
  }
  for (final m in meldungen) {
    b.writeln('Meldung: $m');
  }
  return b.toString();
}

/// Die eingesetzten Varianten und die nächste freie Zahl.
Future<(List<(String, String)>, String?)> _varianten(MoodleZugang moodle, int sammlung, int frage) async {
  final r = await moodle.lesen('${_stack}questiontestrun.php?questionid=$frage&cmid=$sammlung');
  final d = html_parser.parse(r.text);
  final aus = <(String, String)>[];
  for (final tab in d.querySelectorAll('table.stacktestsuite')) {
    if (tab.querySelectorAll('thead th').length != 4) continue;
    for (final tr in tab.querySelectorAll('tbody tr')) {
      final z = _zellen(tr);
      if (z.isNotEmpty && RegExp(r'^\d+$').hasMatch(z[0])) aus.add((z[0], z.length > 1 ? z[1] : ''));
    }
  }
  final frei = d.querySelectorAll('input').where((e) => e.attributes['name'] == 'seed').firstOrNull;
  return (aus, frei?.attributes['value']);
}

Future<String> stackVarianten(MoodleZugang moodle, Freigaben freigaben,
    {required int sammlung, required int frage, int? anzahl, int? seed}) async {
  final (vorher, _) = await _varianten(moodle, sammlung, frage);
  String liste(List<(String, String)> v) => v.isEmpty ? '  (keine)' : v.map((x) => '  ${x.$1}: ${x.$2}').join('\n');
  if (anzahl == null && seed == null) {
    return 'Eingesetzte Varianten von Frage $frage (${vorher.length}):\n${liste(vorher)}\n'
        '${vorher.isEmpty ? 'Bei einer Frage mit rand() ist ungeprüft, ob JEDE Variante sinnvolle Zahlen liefert. '
            'Vor dem Einsatz Varianten einsetzen (anzahl).' : ''}';
  }
  final ja = await freigaben.anfragen(FreigabeAnfrage(
    titel: 'STACK-Varianten einsetzen?',
    punkte: [
      'Frage $frage (Sammlung cmid $sammlung): ${seed != null ? 'Variante $seed' : '$anzahl zufällige Variante(n)'}',
      'Lernende bekommen danach nur noch eingesetzte Varianten; STACK rechnet jede durch und prüft sie mit den Testfällen.',
    ],
    vergleich: const [],
    knopf: 'Einsetzen',
  ));
  if (!ja) return 'Nichts eingesetzt: in der App abgelehnt oder nicht rechtzeitig freigegeben.';
  final s = await moodle.sesskey();
  if (seed != null) {
    await moodle.senden('${_stack}deploy.php', [
      MapEntry('questionid', '$frage'),
      MapEntry('cmid', '$sammlung'),
      MapEntry('deploy', '$seed'),
      MapEntry('sesskey', s),
    ]);
  } else {
    await moodle.aufrufen('${_stack}deploy.php?questionid=$frage&cmid=$sammlung&sesskey=$s&deploymany=$anzahl');
  }
  final (nachher, _) = await _varianten(moodle, sammlung, frage);
  final ok = nachher.length > vorher.length;
  return 'Varianten vorher ${vorher.length}, jetzt ${nachher.length}. verified: $ok\n${liste(nachher)}\n'
      '${ok ? 'Jetzt die Aufgabenhinweise ansehen: Zufallszahlen erzeugen gern Brüche wie 7/2, die im Unterricht unschön sind.' : 'Keine Variante dazugekommen -- sind die Aufgabenvariablen zufällig (rand)?'}';
}

/// Maxima-Code im CAS-Notizblock ausprobieren, bevor er in eine Frage kommt.
/// simp (Auto-Vereinfachung) ist Vorgabe: Ohne wertet Maxima nichts aus, und
/// man hält die unausgewertete Formel für ein kaputtes CAS.
Future<String> stackCas(MoodleZugang moodle, {required String ausdruck, String variablen = '', bool vereinfachen = true}) async {
  final adresse = '${_stack}adminui/caschat.php';
  final r = await moodle.lesen(adresse);
  final d = html_parser.parse(r.text);
  final form = d.querySelectorAll('form').where((f) => f.querySelector('textarea[name="cas"]') != null).firstOrNull;
  if (form == null) throw MoodleFehler('CAS-Notizblock nicht gefunden (erwartet unter $adresse).');
  final f = formularFelder(form);
  // Die Auto-Vereinfachung kommt angehakt; zum Abschalten muss sie ausdrücklich weg.
  f.removeWhere((e) => e.key == 'simp');
  if (vereinfachen) f.add(const MapEntry('simp', 'on'));
  setze(f, 'maximavars', variablen);
  setze(f, 'cas', ausdruck);
  setze(f, 'action', 'go');
  final a = await moodle.senden(adresse, f);
  final rd = html_parser.parse(a.text);
  final haupt = rd.querySelector('#region-main');
  // Das Ergebnis steht im selben div VOR dem Formular -- im Elternknoten des
  // Formulars suchen, nicht in #region-main.
  final formular = haupt?.querySelector('form');
  final teile = <String>[];
  for (var k = formular?.parent?.children.firstOrNull; k != null && k != formular; k = k.nextElementSibling) {
    if (!RegExp(r'^h[1-6]$').hasMatch(k.localName ?? '')) teile.add(_text(k));
  }
  final meldungen = [for (final e in rd.querySelectorAll('.alert-danger, .notifyproblem, .error')) _text(e)];
  return 'Ergebnis: ${teile.where((t) => t.isNotEmpty).join(' ')}'
      '${meldungen.isEmpty ? '' : '\nMeldungen: ${meldungen.join(' | ')}'}\n'
      '(Bleibt ein Ausdruck unausgewertet stehen, ist die Funktion unbekannt oder simp war aus.)';
}
