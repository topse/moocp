// Die Auswertung des CAS-Notizblocks (stackCasBericht in lib/moodle/stack.dart):
// das Ergebnis aus dem Kasten vor dem Formular, ohne Name und Text der Frage,
// über die der Notizblock geöffnet wurde; Fehler auch dann, wenn STACK sie ohne
// Fehlerklasse ins Formular setzt.
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/stack.dart';

/// Die Seite, wie caschat.php sie mit questionid zeigt: Name, Version und Text
/// der Frage, der Kasten mit dem Ergebnis, dann das Formular.
String seite({String ergebnis = '', String variablenFehler = '', String fehler = ''}) => '''
<div id="region-main"><div role="main">
<h2>CAS-Chat</h2>
<h3>Stack Test</h3>
<p>Version 1</p>
<details><summary>Fragetext</summary><pre class="questiontext">Differentiate (x-1)^3</pre></details>
${ergebnis.isEmpty ? '' : '<div class="box py-3 generalbox">$ergebnis</div>'}
<form method="post">
<h2>Fragevariablen</h2>
<p>$variablenFehler</p>
<p><textarea name="maximavars">y : 3*(2+;</textarea></p>
Auto-Vereinfachung <input type="checkbox" name="simp" checked>
<h2>Allgemeines Feedback</h2>
<p>${fehler.isEmpty ? '' : '<div class="error">$fehler</div>'}</p>
<p><textarea name="cas">Wert {@y@}</textarea></p>
<p><input type="submit" name="action" value="Chat"><input type="submit" name="action" value="Speichern"></p>
<p>Schrägstriche schützen <input type="checkbox" name="pslash"></p>
</form>
<p>Hier können Sie CAS-Text ausprobieren.</p>
</div></div>
''';

void main() {
  test('Ergebnis aus dem Kasten, ohne Name und Text der Frage', () {
    final b = stackCasBericht(seite(ergebnis: r'Ergebnis \({7.0}\)'));
    expect(b, startsWith(r'Ergebnis: Ergebnis \({7.0}\)'));
    expect(b, isNot(contains('Differentiate')));
    expect(b, isNot(contains('Version 1')));
    expect(b, isNot(contains('Meldungen')));
  });

  test('Fehler in den Variablen kommt an, obwohl STACK ihn ohne Fehlerklasse setzt', () {
    final b = stackCasBericht(seite(variablenFehler: 'Syntaxfehler in y : 3*(2+;'));
    expect(b, contains('Meldungen: Syntaxfehler in y : 3*(2+;'));
  });

  test('Fehler im CAS-Text einmal, nicht doppelt', () {
    final b = stackCasBericht(seite(fehler: 'Fehler: Verbotene Funktion: parse_string.'));
    expect(RegExp('Verbotene Funktion').allMatches(b).length, 1);
  });

  test('Absätze mit Eingabefeldern und Hinweise außerhalb des Formulars sind keine Meldung', () {
    final b = stackCasBericht(seite(ergebnis: 'Wert 5'));
    expect(b, isNot(contains('Schrägstriche')));
    expect(b, isNot(contains('ausprobieren')));
  });
}
