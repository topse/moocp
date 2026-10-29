// Die gemessenen Beispielfragen (test/daten/fragen/): Jede davon ist in
// Moodle importiert und zurückgelesen worden. Was damit angelegt werden
// konnte, muss die Prüfung vor dem Import hier auch durchlassen.
import 'dart:convert';
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

  // Die Beschreibungen für stack_xml in den Skill-Referenzen: Was dort als
  // Beispiel steht, muss stack_xml bauen und die Prüfung durchlassen.
  for (final name in ['stack.md', 'jsxgraph.md']) {
    test('stack_xml-Beispiel in $name baut und geht durch die Prüfung', () {
      final md = File('skills/moodle-fragen/references/$name').readAsStringSync();
      final bloecke = RegExp(r'```json\n([\s\S]*?)\n```').allMatches(md).toList();
      expect(bloecke, isNotEmpty);
      for (final b in bloecke) {
        final f = (jsonDecode(b.group(1)!) as Map).cast<String, Object?>();
        fragenXmlPruefen(quizXml([stackXml(f, version: '1')]));
      }
    });
  }
}
