// Die Druckaufbereitung „Aufgabenblatt-Druck" erkennt die App am Quelltext
// der Anmeldeseite (lib/moodle/moodle_zugang.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/moodle_zugang.dart';

void main() {
  test('erkannt am Skript vor dem Schließen des BODY-Tags', () {
    const mit = '<html><body><form id="login"></form>'
        '<script>(function () { var wurzel = document.getElementById("ab-print-root"); })();</script>'
        '</body></html>';
    expect(druckaufbereitungErkannt(mit), isTrue);
  });

  test('nicht erkannt auf einer gewöhnlichen Anmeldeseite', () {
    const ohne = '<html><body><form id="login"><input name="logintoken" value="x"></form>'
        '<script>M.cfg = {"sesskey":"abc"};</script></body></html>';
    expect(druckaufbereitungErkannt(ohne), isFalse);
  });
}
