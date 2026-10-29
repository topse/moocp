// Offline prüfbar: Einstellungen aus einem Moodle-Formular lesen und setzen,
// an einem nachgebauten Formular im Aufbau von Moodle 4.
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:moocp/moodle/formular.dart';
import 'package:moocp/moodle/moodle_zugang.dart';

String optionen(int von, int bis, int gewaehlt) =>
    [for (var i = von; i <= bis; i++) '<option value="$i"${i == gewaehlt ? ' selected' : ''}>$i</option>'].join();

final formular = '''<form class="mform">
<input type="hidden" name="sesskey" value="x">
<div id="fitem_id_name" class="mb-3 row fitem"><div class="col-md-3 col-form-label"><label for="id_name">Name der Aufgabe</label></div>
<div class="col-md-9 felement" data-fieldtype="text"><input type="text" name="name" id="id_name" value="ZZ Probe"></div></div>
<div id="fitem_id_duedate" class="mb-3 row fitem" data-groupname="duedate"><div class="col-md-3 col-form-label"><p>Fälligkeitsdatum</p></div>
<div class="col-md-9 felement" data-fieldtype="date_time_selector"><fieldset>
<label class="form-check fitem"><input type="checkbox" name="duedate[enabled]" id="id_duedate_enabled" value="1"> Aktivieren</label>
<select name="duedate[day]">${optionen(1, 31, 1)}</select><select name="duedate[month]">${optionen(1, 12, 10)}</select>
<select name="duedate[year]">${optionen(2025, 2030, 2026)}</select><select name="duedate[hour]">${optionen(0, 23, 0)}</select>
<select name="duedate[minute]">${optionen(0, 59, 0)}</select></fieldset></div></div>
<div id="fgroup_id_submissionplugins" class="mb-3 row fitem" data-groupname="submissionplugins"><div class="col-md-3 col-form-label"><p>Abgabetypen</p></div>
<div class="col-md-9 felement" data-fieldtype="group"><fieldset>
<input type="hidden" name="assignsubmission_onlinetext_enabled" value="0">
<label class="form-check"><input type="checkbox" name="assignsubmission_onlinetext_enabled" id="id_ot" value="1"> Texteingabe online</label>
<input type="hidden" name="assignsubmission_file_enabled" value="0">
<label class="form-check"><input type="checkbox" name="assignsubmission_file_enabled" id="id_fi" value="1" checked> Dateiabgabe</label>
</fieldset></div></div>
<div id="fitem_id_teamsubmission" class="mb-3 row fitem"><div class="col-md-3 col-form-label"><label for="id_team">Gruppenabgabe</label></div>
<div class="col-md-9 felement" data-fieldtype="selectyesno"><select name="teamsubmission" id="id_team"><option value="0" selected>Nein</option><option value="1">Ja</option></select></div></div>
</form>''';

void main() {
  test('Einstellungen lesen: Datum, Gruppe, Auswahl', () {
    final form = html_parser.parse(formular).querySelector('form')!;
    expect({for (final e in einstellungenLesen(form)) e.schluessel: e.wert}, {
      'name': 'ZZ Probe',
      'duedate': 'aus',
      'submissionplugins': 'Texteingabe online: nein · Dateiabgabe: ja',
      'teamsubmission': 'Nein',
    });
  });

  test('Einstellungen setzen: wie ein Browser, mit Rückleseangaben', () {
    final form = html_parser.parse(formular).querySelector('form')!;
    final f = formularFelder(form);
    final g = einstellungenSetzen(form, f, {
      'duedate': '2026-10-05 08:30',
      'submissionplugins': {'Texteingabe online': 'ja', 'Dateiabgabe': 'nein'},
      'teamsubmission': 'Ja',
      'name': 'ZZ Neu',
    });
    expect(g.map((s) => '$s').toList(), [
      'Fälligkeitsdatum: aus → 2026-10-05 08:30',
      'Abgabetypen: Texteingabe online: nein · Dateiabgabe: ja → Texteingabe online: ja · Dateiabgabe: nein',
      'Gruppenabgabe: Nein → Ja',
      'Name der Aufgabe: ZZ Probe → ZZ Neu',
    ]);
    expect(wertIn(f, 'duedate[enabled]'), '1');
    expect(wertIn(f, 'duedate[day]'), '5');
    expect(wertIn(f, 'duedate[month]'), '10');
    expect(wertIn(f, 'duedate[hour]'), '8');
    expect(wertIn(f, 'duedate[minute]'), '30');
    // PHP nimmt den letzten gleichnamigen Wert.
    expect(f.where((e) => e.key == 'assignsubmission_onlinetext_enabled').last.value, '1');
    expect(f.where((e) => e.key == 'assignsubmission_file_enabled').last.value, '0');
    expect(wertIn(f, 'teamsubmission'), '1');

    final aus = formularFelder(form);
    einstellungenSetzen(form, aus, {'duedate': '2026-10-05 08:30'});
    einstellungenSetzen(form, aus, {'duedate': 'aus'});
    expect(aus.any((e) => e.key == 'duedate[enabled]'), isFalse);
  });

  test('Einstellungen setzen: ein leerer Wert steht in der Freigabe als (leer)', () {
    final form = html_parser.parse(formular).querySelector('form')!;
    final g = einstellungenSetzen(form, formularFelder(form), {'name': ''});
    expect('${g.single}', 'Name der Aufgabe: ZZ Probe → (leer)');
  });

  test('Einstellungen setzen: Unbekanntes bricht ab, mit Hinweis', () {
    final form = html_parser.parse(formular).querySelector('form')!;
    final f = formularFelder(form);
    expect(() => einstellungenSetzen(form, f, {'gibtsnicht': '1'}), throwsA(isA<MoodleFehler>()));
    expect(
        () => einstellungenSetzen(form, f, {'teamsubmission': 'Vielleicht'}),
        throwsA(predicate((e) => e is MoodleFehler && e.meldung.contains('Nein | Ja'))));
    expect(() => einstellungenSetzen(form, f, {'duedate': '5.10.2026'}), throwsA(isA<MoodleFehler>()));
    expect(() => einstellungenSetzen(form, f, {'submissionplugins': 'ja'}), throwsA(isA<MoodleFehler>()));
  });
}
