// Offline prüfbar: Skriptblöcke in STACK-Fragen -- nur [[jsxgraph]] mit der
// JSXGraph-Version, die STACK mitbringt, und nichts, was nachlädt.
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/auswertung.dart';
import 'package:moocp/moodle/formeln.dart';
import 'package:moocp/moodle/moodle_zugang.dart';
import 'package:moocp/moodle/stack_skripte.dart';

String _block(String code, [String attribute = ' input-ref-ans1="ans1Ref" width="400px"']) =>
    '<p>Ziehe den Punkt.</p>[[jsxgraph$attribute]]\n$code\n[[/jsxgraph]]';

const _zeichnung = '''
var board = JXG.JSXGraph.initBoard(divid, {boundingbox: [-1, 5, 5, -1], axis: true, showCopyright: false});
// Kommentar: der Punkt wird an ans1 gebunden
var p = board.create('point', [{#x0#}, {#y0#}], {name: 'P', snapToGrid: true});
for (var i = 0; i < 3; i++) { board.create('point', [i, 0], {fixed: true}); }
board.create('text', [1, 4, '\\\\(f(x) = {@f@}\\\\)'], {useMathJax: true});
stack_jxg.bind_point(ans1Ref, p);
''';

void main() {
  test('Erlaubt: [[jsxgraph]] ohne fremde Quelle, auch mit version="local" und style', () {
    expect(stackSkriptFehler(_block(_zeichnung)), isEmpty);
    expect(stackSkriptFehler(_block(_zeichnung, ' version="local" style="empty"')), isEmpty);
    // Andere STACK-Blöcke laden nichts.
    expect(stackSkriptFehler('[[if test="a>1"]]x[[/if]] [[input:ans1]] [[validation:ans1]] [[reveal input="a"]]'),
        isEmpty);
  });

  test('Abgewiesen: Versionen von fremden Rechnern und eigene Adressen', () {
    for (final a in [
      ' version="cdn"',
      ' version="1.12.2"',
      ' Version="cdn"',
      ' overridejs="https://x.example/j.js"',
      " overrideCSS='a.css'",
    ]) {
      expect(stackSkriptFehler(_block(_zeichnung, a)), [contains('fremden Rechner')], reason: a);
    }
  });

  test('Abgewiesen: Blöcke, die laden oder ausführen', () {
    for (final b in ['iframe', 'javascript', 'script', 'style', 'geogebra', 'parsons', 'include']) {
      expect(stackSkriptFehler('<p>x</p>[[$b src="a"]]y[[/$b]]'), [contains('[[$b]]')], reason: b);
      expect(stackSkriptFehler('[[ ${b.toUpperCase()} ]]'), isNotEmpty, reason: b);
    }
  });

  test('Abgewiesen: Adressen und Netzzugriffe im Code', () {
    for (final c in [
      "board.create('image', ['https://bilder.example/a.png', [0, 0], [1, 1]]);",
      "var u = '//cdn.example/x.js';",
      "import x from 'mod.js';",
      "const m = await import('mod.js');",
      "fetch('daten.json');",
      'var r = new XMLHttpRequest();',
      "var w = new WebSocket('wss://x');",
      "navigator.sendBeacon('/x', 'y');",
    ]) {
      expect(stackSkriptFehler(_block(c)), isNotEmpty, reason: c);
    }
    // Ein Kommentar mit // ist keine Adresse, ein Wort mit „import" kein import.
    expect(stackSkriptFehler(_block('// wichtig\nvar important = 1; // https fehlt hier')), isEmpty);
  });

  test('Bindungen: die Eingaben aus input-ref-…', () {
    expect(jsxgraphEingaben(_block(_zeichnung, ' input-ref-ans1="a" input-ref-ans2=\'b\'')), {'ans1', 'ans2'});
    expect(jsxgraphEingaben('[[jsxgraph]]x[[/jsxgraph]]'), isEmpty);
    // Groß und Klein wie in STACK: input-ref-ansG bindet ansG; ein anders
    // geschriebenes Präfix bindet dort nichts.
    expect(jsxgraphEingaben(_block(_zeichnung, ' input-ref-ansG="g" Input-Ref-ans2="b"')), {'ansG'});
  });

  test('Der Code ist kein Text: keine Formelfehler, keine Befunde aus dem Code', () {
    final html = _block('$_zeichnung var s = "\\\\(a"; if (a < b) { }');
    expect(ohneJsxgraphCode(html), '<p>Ziehe den Punkt.</p>[[jsxgraph input-ref-ans1="ans1Ref" width="400px"]][[/jsxgraph]]');
    expect(formelFehler(html), isEmpty);
    // Dieselbe Zeile als Text wäre ein Fehler.
    expect(formelFehler(r'<p>var s = "\(a";</p>'), isNotEmpty);
    final a = feldAuswerten('questiontext', html, host: 'moodle.schule.example');
    expect(a.befunde.zeilen, isEmpty);
    final b = feldAuswerten('questiontext', _block(_zeichnung, ' version="cdn"'), host: 'moodle.schule.example');
    expect(b.befunde.zeilen, [contains('[Skript]')]);
  });

  test('Vor dem Schreiben: bricht mit allen Fundstellen ab', () {
    stackSkriptePruefen({'questiontext': _block(_zeichnung)});
    expect(
        () => stackSkriptePruefen({
              'questiontext': _block(_zeichnung, ' version="cdn"'),
              'generalfeedback': '[[geogebra]][[/geogebra]]',
            }),
        throwsA(predicate((e) =>
            e is MoodleFehler &&
            e.meldung.contains('questiontext.html') &&
            e.meldung.contains('generalfeedback.html') &&
            e.meldung.contains('nichts geschrieben'))));
  });
}
