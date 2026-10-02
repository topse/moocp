// Offline prüfbar: Formelfehler im HTML und die Fallen einzelner Fragetypen.
// Die Fälle sind die der Messung auf der Testinstanz (formeln.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/auswertung.dart';
import 'package:moocp/moodle/formeln.dart';
import 'package:moocp/moodle/fragen_xml.dart';
import 'package:moocp/moodle/moodle_zugang.dart';

void main() {
  test('Was MathJax setzt, ist kein Fehler', () {
    for (final html in [
      r'<p>Der Satz \(a^2 + b^2 = c^2\) mitten im Satz.</p>',
      r'<p>\[ R_{\mathrm{ges}} = R_1 + R_2 \]</p>',
      r'<p>Bedingung: \(x &lt; y\) und \(y \gt 0\).</p>',
      r'<p>\[ \begin{aligned} P &amp;= U \cdot I \\ &amp;= 460\,\mathrm{W} \end{aligned} \]</p>',
      r'<p>\[ \begin{aligned} a &amp;= 1 \\[4pt] b &amp;= 2 \end{aligned} \]</p>',
      r'<p>\( \left( \frac{1}{2} \right) \) und \(\{1, 2\}\)</p>',
      r'<p>$$E = m c^2$$</p>',
      r'<p>Ein Preis von 5 $ bis 10 $, dazu \(\frac{a}{b}\).</p>',
      r'<p>So schreibt man einen Bruch: <code>\(\frac{a}{b}</code></p>',
      r'<pre>\[ halb</pre>',
      r'<table class="lernsituation"><tr><td>\( Vorlage</td></tr></table>',
      r'<p>Cloze: {1:MULTICHOICE_V:=\(\frac{U\}{R\}\)~\(U \cdot R\)}</p>',
      '<p>Ganz ohne Formel.</p>',
    ]) {
      expect(formelFehler(html), isEmpty, reason: html);
    }
  });

  test('Ein rohes < zerbricht die Formel: Formel ohne Ende', () {
    final f = formelFehler(r'<p>Bedingung: \(x<y\) und danach weiterer Text.</p>');
    expect(f.single, contains('Formel ohne Ende'));
    expect(f.single, contains('&lt;'));
  });

  test('Anfang und Ende in verschiedenen Absätzen, Ende ohne Anfang', () {
    final f = formelFehler(r'<p>\( a + b</p><p>c \)</p>');
    expect(f, hasLength(2));
    expect(f.first, contains('Formel ohne Ende'));
    expect(f.last, contains('ohne Anfang'));
    expect(formelFehler(r'<p>nur ein Ende \]</p>').single, contains('ohne Anfang'));
    expect(formelFehler(r'<p>\( a \]</p>'), hasLength(2));
  });

  test('HTML in der Formel', () {
    expect(formelFehler(r'<p>\( a <strong>b</strong> \)</p>').single, contains('HTML in der Formel'));
    expect(formelFehler(r'<p>\[ a \\ <br> b \]</p>').single, contains('HTML in der Formel'));
  });

  test('LaTeX zwischen einfachen Dollarzeichen', () {
    expect(formelFehler(r'<p>Die Formel $E = m c^2$ gilt.</p>'), isEmpty, reason: 'ohne Befehl kein Befund');
    expect(formelFehler(r'<p>Die Formel $\frac{a}{b}$ gilt.</p>').single, contains('einfachen'));
  });

  test('Schreiben bricht ab und nennt Feld und Stelle', () {
    expect(() => formelnPruefen({'page': r'<p>\(x<y\)</p>', 'intro': '<p>gut</p>'}),
        throwsA(isA<MoodleFehler>().having((e) => e.meldung, 'meldung',
            allOf(contains('nichts geschrieben'), contains('page.html: Formel ohne Ende'), isNot(contains('intro'))))));
    formelnPruefen({'page': r'<p>\(x &lt; y\)</p>'});
  });

  test('Beim Lesen: eigener Block vor den Befunden', () {
    final a = feldAuswerten('page', r'<p>\(x<y\)</p>', host: 'moodle.schule.example');
    expect(a.formelfehler.single, contains('Formel ohne Ende'));
    final t = uebersichtText([a], const {});
    expect(t, contains('FORMELFEHLER (1)'));
    expect(t.indexOf('FORMELFEHLER'), lessThan(t.indexOf('Befunde')));
  });

  group('Fragenimport', () {
    String frage(String typ, String text, [String rest = '']) => quizXml([
          '<question type="$typ"><name><text>ZZ Frage</text></name>'
              '<questiontext format="html"><text><![CDATA[$text]]></text></questiontext>$rest</question>'
        ]);

    test('Formelfehler in jedem HTML-Feld, auch in Antworten', () {
      expect(() => fragenXmlPruefen(frage('multichoice', '<p>gut</p>',
              r'<answer fraction="100" format="html"><text><![CDATA[\(x<y\)]]></text></answer>')),
          throwsA(predicate((e) => '$e'.contains('<answer>') && '$e'.contains('Formel ohne Ende'))));
    });

    test('Cloze: nur schließende Klammern maskieren', () {
      fragenXmlPruefen(frage('cloze', r'<p>{1:MULTICHOICE_V:=\(\frac{U\}{R\}\)~\(U \cdot R\)}</p>'));
      expect(() => fragenXmlPruefen(frage('cloze', r'<p>{1:MULTICHOICE_V:=\(\frac\{U\}\{R\}\)~\(U \cdot R\)}</p>')),
          throwsA(predicate((e) => '$e'.contains('nicht \\{'))));
    });

    test('gapfill: nur Ablenker; [] mit abgesetzter Formel; {} mit Formel', () {
      const ablenker = '<answer fraction="0" format="moodle_auto_format"><text>Ampere</text></answer>';
      const richtig = '<answer fraction="100" format="moodle_auto_format"><text>Volt</text></answer>';
      expect(() => fragenXmlPruefen(frage('gapfill', '<p>Die Spannung in [Volt].</p>', ablenker)),
          throwsA(predicate((e) => '$e'.contains('keine richtige Antwort'))));
      fragenXmlPruefen(frage('gapfill', '<p>Die Spannung in [Volt].</p>', '$richtig$ablenker'));
      fragenXmlPruefen(frage('gapfill', '<p>Die Spannung in [Volt].</p>'));
      fragenXmlPruefen(frage('gapfill', r'<p>Im Gesetz \(I = \frac{U}{R}\) ist I der [Strom].</p>'));
      expect(
          () => fragenXmlPruefen(frage('gapfill', r'<p>\[ P = U \cdot I \]</p><p>in [Watt]</p>',
              '<delimitchars>[]</delimitchars>')),
          throwsA(predicate((e) => '$e'.contains('@@'))));
      fragenXmlPruefen(frage('gapfill', r'<p>\[ P = U \cdot I \]</p><p>in @Watt@</p>',
          '<delimitchars>@@</delimitchars>'));
      expect(
          () => fragenXmlPruefen(frage('gapfill', r'<p>\(I\) ist der {Strom}.</p>', '<delimitchars>{}</delimitchars>')),
          throwsA(predicate((e) => '$e'.contains('{}'))));
    });
  });
}
