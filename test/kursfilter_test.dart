// Offline prüfbar: die Auswertung der Seite „Filtereinstellungen" eines
// Kurses. Der Aufbau ist der gemessene (filter/manage.php), Kurs und Werte
// sind erfunden.
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/kursfilter.dart';

/// Eine Zeile der Tabelle, wie Moodle sie baut -- samt der versteckten
/// Beschriftung „0", die nicht der Name ist.
String zeile(String name, String kennung, String gewaehlt,
        {String standard = 'Standard (An)', String an = 'An', String aus = 'Aus'}) =>
    '<tr><td class="leftalign cell c0">$name</td><td class="leftalign cell c1 lastcol">'
    '<label class="accesshide" for="menu$kennung">0</label>'
    '<select id="menu$kennung" class="select form-select" name="$kennung">'
    '<option ${gewaehlt == '0' ? 'selected="selected" ' : ''}value="0">$standard</option>'
    '<option ${gewaehlt == '-1' ? 'selected="selected" ' : ''}value="-1">$aus</option>'
    '<option ${gewaehlt == '1' ? 'selected="selected" ' : ''}value="1">$an</option>'
    '</select></td></tr>';

String seite(List<String> zeilen) => '<html><body><div id="region-main"><h2>Filtereinstellungen in Kurs: '
    'Kurs 12</h2><form action="https://moodle.schule.example/filter/manage.php" method="post"><div>'
    '<input type="hidden" name="sesskey" value="abc"><input type="hidden" name="contextid" value="2363">'
    '<table class="admintable table generaltable" id="frontpagefiltersettings"><thead><tr><th>Filter</th>'
    '<th>Aktiv?</th></tr></thead><tbody>${zeilen.join()}</tbody></table></div></form></div></body></html>';

void main() {
  test('Name aus der ersten Zelle, Zustand aus dem Wert und dem Standard', () {
    final f = filterAuswerten(seite([
      zeile('H5P anzeigen', 'displayh5p', '0'),
      zeile('MathJax', 'mathjaxloader', '0'),
      zeile('Autoverlinkung zu Aktivitäten', 'activitynames', '0', standard: 'Standard (Aus)'),
      zeile('Multimedia-Plugins', 'mediaplugin', '-1'),
      zeile('Glossar', 'glossary', '1', standard: 'Standard (Aus)'),
    ]));
    expect([for (final x in f) '${x.name}|${x.kennung}|${x.zustand}'], [
      'H5P anzeigen|displayh5p|an (Standard)',
      'MathJax|mathjaxloader|an (Standard)',
      'Autoverlinkung zu Aktivitäten|activitynames|aus (Standard)',
      'Multimedia-Plugins|mediaplugin|aus',
      'Glossar|glossary|an',
    ]);
    expect(formelBefund(f), startsWith('Formeln: JA'));
  });

  test('In jeder Sprache: verglichen wird mit den Texten von An und Aus', () {
    final f = filterAuswerten(seite([
      zeile('MathJax', 'mathjaxloader', '0', standard: 'Default (Off)', an: 'On', aus: 'Off'),
    ]));
    expect(f.single.an, isFalse);
    expect(f.single.geerbt, isTrue);
  });

  test('MathJax im Kurs aus: die Lehrkraft schaltet ihn selbst ein', () {
    final b = formelBefund(filterAuswerten(seite([zeile('MathJax', 'mathjaxloader', '-1')])));
    expect(b, startsWith('Formeln: NEIN, MathJax ist in diesem Kurs aus'));
    expect(b, contains('Kurs → Mehr → Filter → „MathJax" auf „An"'));
  });

  test('MathJax fehlt: in der Website-Administration abgeschaltet', () {
    final b = formelBefund(filterAuswerten(seite([zeile('H5P anzeigen', 'displayh5p', '0')])));
    expect(b, startsWith('Formeln: NEIN. MathJax ist auf dieser Instanz'));
  });

  test('Unbekannter Standard: nicht raten', () {
    final f = filterAuswerten(seite([zeile('MathJax', 'mathjaxloader', '0', standard: 'Standard')]));
    expect(f.single.an, isNull);
    expect(formelBefund(f), startsWith('Formeln: UNBEKANNT'));
  });

  test('Keine Filtertabelle, etwa eine Fehlerseite: leer', () {
    expect(filterAuswerten('<html><body><div id="region-main"><p>Keine Berechtigung</p></div></body></html>'),
        isEmpty);
  });
}
