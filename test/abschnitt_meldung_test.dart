// Meldungen, wenn Moodle ein Formular abweist: formularAbgelehnt
// (lib/moodle/formular_schreiben.dart) und halbAngelegt für einen Abschnitt,
// der angelegt, aber nicht gefüllt ist (lib/moodle/kurs_aendern.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/formular_schreiben.dart';
import 'package:moocp/moodle/kurs_aendern.dart';

void main() {
  test('HTTP 403 ohne Hinweise: wer abgelehnt haben kann', () {
    final m = formularAbgelehnt(403, const []);
    expect(m, contains('HTTP 403'));
    expect(m, contains('Recht'));
    expect(m, contains('Filter vor der Instanz'));
  });

  test('Hinweise aus dem Formular gehen vor, andere Fehler bleiben knapp', () {
    expect(formularAbgelehnt(403, ['„Name": Erforderlich']), allOf(contains('Erforderlich'), isNot(contains('Filter'))));
    expect(formularAbgelehnt(200, const []), 'Moodle hat das Formular nicht angenommen (HTTP 200)');
  });

  test('Abschnitt angelegt, aber nicht gefüllt: id, Zustand und was jetzt zu tun ist', () {
    final m = halbAngelegt(4883, 43, formularAbgelehnt(403, const []), verborgen: true);
    expect(m, startsWith('Abschnitt angelegt (id 4883, verborgen)'));
    expect(m, contains('HTTP 403'));
    expect(m, contains('Nicht noch einmal anlegen'));
    expect(m, contains('abschnitt_lesen(4883)'));
    expect(m, contains('loeschen(kurs: 43, abschnitt_id: 4883)'));
    expect(halbAngelegt(7, 43, 'x', verborgen: false), contains('SICHTBAR'));
  });
}
