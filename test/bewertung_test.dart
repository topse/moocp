// Offline prüfbar: Optionen eines Bewertungsschemas lesen und setzen, und die
// Rückleseprobe der Kriterien -- an einem nachgebauten Definitionsformular.
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:moocp/moodle/bewertung.dart';
import 'package:moocp/moodle/formular.dart';
import 'package:moocp/moodle/moodle_zugang.dart';

String kaestchen(String name, String label, {bool an = false}) =>
    '<div class="option $name"><input type="checkbox" name="rubric[options][$name]" id="rubric-options-$name" '
    'value="1"${an ? ' checked="checked"' : ''}><label for="rubric-options-$name">$label</label></div>';

final formular = '''<form class="mform">
<input type="hidden" name="areaid" value="424">
<input type="text" name="name" value="ZZ Raster">
<textarea name="rubric[criteria][12][description]">Aufbau</textarea>
<input type="hidden" name="rubric[criteria][12][sortorder]" value="1">
<textarea name="rubric[criteria][12][levels][30][definition]">fehlt</textarea>
<input type="text" name="rubric[criteria][12][levels][30][score]" value="0,00">
<div class="options">
<div class="option sortlevelsasc"><label for="rubric-options-sortlevelsasc">Sortierfolge für Level:</label>
<select name="rubric[options][sortlevelsasc]" id="rubric-options-sortlevelsasc">
<option value="0">Absteigend (Punkte)</option><option value="1" selected="selected">Aufsteigend (Punkte)</option>
</select></div>
${kaestchen('alwaysshowdefinition', 'Nutzer/innen eine Vorschau auf die Rubrik erlauben', an: true)}
${kaestchen('enableremarks', 'Erläuterungen zu jedem Kriterium für Bewerter/in zulassen')}
<input type="checkbox" name="rubric[options][lockzeropoints]" value="1" disabled>
</div>
</form>''';

void main() {
  test('Optionen: Kästchen und Auswahl, ohne deaktivierte', () {
    final form = html_parser.parse(formular).querySelector('form')!;
    final o = schemaOptionen(form);
    expect(o.keys, ['sortlevelsasc', 'alwaysshowdefinition', 'enableremarks']);
    expect({for (final e in o.entries) e.key: steuerWert(e.value)},
        {'sortlevelsasc': 'Aufsteigend (Punkte)', 'alwaysshowdefinition': 'ja', 'enableremarks': 'nein'});
    final s = Schema('rubric', 424, '', form, formularFelder(form), {}, 'ZZ Raster', '');
    expect(s.optionenLabels['alwaysshowdefinition'], 'Nutzer/innen eine Vorschau auf die Rubrik erlauben');
    expect(s.optionenLabels['sortlevelsasc'], 'Sortierfolge für Level');
  });

  test('Optionen setzen: wie ein Browser, Ungenanntes bleibt', () {
    final form = html_parser.parse(formular).querySelector('form')!;
    final f = formularFelder(form);
    final werte = optionenSetzen(form, f, {'alwaysshowdefinition': 'nein', 'enableremarks': true, 'sortlevelsasc': '0'});
    expect(werte, {'sortlevelsasc': 'Absteigend (Punkte)', 'alwaysshowdefinition': 'nein', 'enableremarks': 'ja'});
    // Ein nicht angehaktes Kästchen schickt der Browser gar nicht.
    expect(f.any((e) => e.key == 'rubric[options][alwaysshowdefinition]'), isFalse);
    expect(wertIn(f, 'rubric[options][enableremarks]'), '1');
    expect(wertIn(f, 'rubric[options][sortlevelsasc]'), '0');
    expect(f.any((e) => e.key == 'rubric[options][lockzeropoints]'), isFalse);

    final g = formularFelder(form);
    expect(optionenSetzen(form, g, {})['alwaysshowdefinition'], 'ja');
    expect(wertIn(g, 'rubric[options][alwaysshowdefinition]'), '1');
  });

  test('Optionen setzen: Unbekanntes bricht ab, mit den möglichen', () {
    final form = html_parser.parse(formular).querySelector('form')!;
    final f = formularFelder(form);
    expect(() => optionenSetzen(form, f, {'showremarks': 'ja'}),
        throwsA(predicate((e) => e is MoodleFehler && e.meldung.contains('alwaysshowdefinition'))));
    expect(() => optionenSetzen(form, f, {'enableremarks': 'vielleicht'}), throwsA(isA<MoodleFehler>()));
    expect(() => optionenSetzen(form, f, {'sortlevelsasc': 'Zufällig'}), throwsA(isA<MoodleFehler>()));
  });

  test('Rückleseprobe: Punkte als Zahl, Stufen in beliebiger Reihenfolge', () {
    final soll = [
      {
        'description': 'Aufbau',
        'level': [
          {'definition': 'vollständig', 'punkte': 2},
          {'definition': 'fehlt', 'punkte': '0'},
        ]
      },
      {'shortname': 'Form', 'description': 'Gliederung  klar', 'maxscore': '5'},
    ];
    final ist = [
      {
        'id': '12',
        'description': 'Aufbau',
        'level': [
          {'id': '30', 'definition': 'fehlt', 'punkte': '0,00'},
          {'id': '31', 'definition': 'vollständig', 'punkte': '2,00'},
        ]
      },
      {'id': '13', 'shortname': 'Form', 'description': 'Gliederung klar', 'maxscore': '5.00'},
    ];
    expect(kriterienAbweichungen(soll, ist), isEmpty);

    final falsch = [
      {
        'id': '12',
        'description': 'Aufbau',
        'level': [
          {'id': '30', 'definition': 'fehlt', 'punkte': '0,00'},
          {'id': '31', 'definition': 'vollständig', 'punkte': '1,00'},
        ]
      },
    ];
    expect(kriterienAbweichungen(soll, falsch), [
      '1 Kriterien statt 2',
      'Kriterium 1, Stufen: 0.0 P.: fehlt | 1.0 P.: vollständig statt 0.0 P.: fehlt | 2.0 P.: vollständig',
    ]);
  });
}
