// Die gemessenen Beispielfragen (test/daten/fragen/): Jede davon ist in
// Moodle importiert und zurückgelesen worden. Was damit angelegt werden
// konnte, muss die Prüfung vor dem Import hier auch durchlassen.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/fragen_xml.dart';

void main() {
  for (final name in ['kerntypen-test.xml', 'zusatztypen-test.xml', 'coderunner-test.xml', 'offene-punkte.xml']) {
    test('gemessene Beispiele $name gehen durch die Prüfung', () {
      final xml = File('test/daten/fragen/$name').readAsStringSync();
      final (_, fragen) = fragenXmlPruefen(xml);
      expect(fragen, isNotEmpty);
    });
  }
}
