// Die Auswertung der STACK-Testseite (stackTestBericht in
// lib/moodle/stack.dart): Eine Testeingabe gilt nur als verworfen, wenn im
// selben Testfall kein Baum etwas geliefert hat.
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/stack.dart';

/// Ein Testfall, wie questiontestrun.php ihn zeigt: Überschrift, Tabelle der
/// Eingaben (sechs Spalten), Tabelle der Bäume (sieben Spalten).
String fall(String titel, {required String uebernommen, required String punkte, required String hinweis}) => '''
<h3>$titel</h3>
<table class="stacktestsuite"><thead><tr><th>1</th><th>2</th><th>3</th><th>4</th><th>5</th><th>6</th></tr></thead>
<tbody><tr><td>ans1</td><td>matrix([1,2],[3,4])</td><td>$uebernommen</td><td></td><td></td><td></td></tr></tbody></table>
<table class="stacktestsuite"><thead><tr><th>1</th><th>2</th><th>3</th><th>4</th><th>5</th><th>6</th><th>7</th></tr></thead>
<tbody><tr class="${punkte == '1' ? 'pass' : 'fail'}"><td>prt1</td><td>$punkte</td><td>1</td><td></td><td></td><td>$hinweis</td><td>prt1-1-T</td></tr></tbody></table>
''';

String seite(List<String> faelle) =>
    '<div id="region-main">${faelle.join()}<div class="overallresult pass">ok</div></div>';

void main() {
  test('Wert nicht als Text angezeigt, aber der Baum hat gerechnet: kein Fehlalarm', () {
    final b = stackTestBericht(seite([fall('Testfall 1', uebernommen: '', punkte: '1', hinweis: 'prt1-1-T')]), frage: 7);
    expect(b, contains('alle 1 Testfälle bestanden'));
    expect(b, isNot(contains('nicht übernommen')));
  });

  test('Eingabe verworfen und kein Baum gerechnet: gemeldet', () {
    final b = stackTestBericht(
        seite([
          fall('Testfall 1', uebernommen: 'matrix([1,2],[3,4])', punkte: '1', hinweis: 'prt1-1-T'),
          fall('Testfall 2', uebernommen: '', punkte: '', hinweis: ''),
        ]),
        frage: 7);
    expect(b, contains('Mindestens eine Testeingabe hat STACK nicht übernommen'));
    expect(RegExp('nicht übernommen').allMatches(b).length, 2, reason: 'der Hinweis oben und Testfall 2');
    expect(b.indexOf('! Eingabe ans1'), greaterThan(b.indexOf('Testfall 2:')));
  });
}
