import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/arbeitsordner.dart';
import 'package:moocp/moodle/formular_schreiben.dart';
import 'package:moocp/moodle/moodle_zugang.dart';
import 'package:path/path.dart' as p;

/// Derselbe Pfad, gleich in welcher Schreibweise von Laufwerksbuchstabe und
/// Groß- und Kleinschreibung (Windows unterscheidet sie nicht).
Matcher gleicherPfad(String erwartet) => predicate<String>((s) => p.equals(s, erwartet), 'Pfad $erwartet');

void main() {
  test('Editorfelder: Zeilenenden werden LF, wie sie zurückgelesen werden', () {
    final ordner = Directory.systemTemp.createTempSync('zz_felder_');
    addTearDown(() => ordner.deleteSync(recursive: true));
    File(p.join(ordner.path, 'page.html')).writeAsStringSync('<h3>Ä</h3>\r\n<p>a</p>\r<p>b</p>\n');
    File(p.join(ordner.path, 'page.vorschau.html')).writeAsStringSync('x');
    expect(felderIn(ordner.path), {'page': '<h3>Ä</h3>\n<p>a</p>\n<p>b</p>\n'});
  });

  test('Ordner: absolut oder relativ zum Arbeitsordner, nie außerhalb', () {
    final ao = p.join(p.current, 'zz-arbeitsordner');
    expect(imArbeitsordner(p.join(ao, 'cm-815'), ao), gleicherPfad(p.join(ao, 'cm-815')));
    expect(imArbeitsordner('cm-815', ao), gleicherPfad(p.join(ao, 'cm-815')), reason: 'relativ zum Arbeitsordner');
    expect(imArbeitsordner('ls3/fragen.xml', ao), gleicherPfad(p.join(ao, 'ls3', 'fragen.xml')));
    expect(() => imArbeitsordner('../geheim', ao), throwsA(isA<MoodleFehler>()));
    expect(() => imArbeitsordner(p.join(p.current, 'anderswo'), ao), throwsA(isA<MoodleFehler>()));
  });

  group('Arbeitsordner auf der Platte', () {
    late Directory basis;
    late String kurz, lang;
    setUp(() {
      // %TEMP% steht auf manchen Rechnern mit Kurznamen (C:\Users\LEHRKR~1\…);
      // dann sind kurz und lang verschieden, sonst gleich.
      basis = Directory.systemTemp.createTempSync('zz_arbeitsordner_');
      kurz = p.join(basis.path, 'ao');
      Directory(p.join(kurz, 'cm-815')).createSync(recursive: true);
      lang = Directory(kurz).resolveSymbolicLinksSync();
    });
    tearDown(() => basis.deleteSync(recursive: true));

    test('Kurz- und Langform desselben Ordners gelten beide', () {
      expect(imArbeitsordner(p.join(lang, 'cm-815'), kurz), gleicherPfad(p.join(lang, 'cm-815')));
      expect(imArbeitsordner(p.join(kurz, 'cm-815'), lang), gleicherPfad(p.join(lang, 'cm-815')));
      expect(imArbeitsordner(p.join(kurz, 'neu', 'fragen.xml'), lang), gleicherPfad(p.join(lang, 'neu', 'fragen.xml')),
          reason: 'was es noch nicht gibt, bleibt als Text hinter dem aufgelösten Anfang');
    });

    test('Eine Junction im Arbeitsordner führt nicht hinaus', () {
      final draussen = Directory(p.join(basis.path, 'draussen'))..createSync();
      File(p.join(draussen.path, 'geheim.txt')).writeAsStringSync('x');
      Link(p.join(kurz, 'verweis')).createSync(draussen.path);
      expect(() => imArbeitsordner(p.join(kurz, 'verweis', 'geheim.txt'), kurz), throwsA(isA<MoodleFehler>()));
      expect(() => imArbeitsordner('verweis/geheim.txt', kurz), throwsA(isA<MoodleFehler>()));
    });

    test('Leeren löscht alles darin, aber nie das Ziel einer Junction', () {
      final draussen = Directory(p.join(basis.path, 'draussen'))..createSync();
      final wichtig = File(p.join(draussen.path, 'wichtig.txt'))..writeAsStringSync('bleibt');
      File(p.join(kurz, 'cm-815', 'page.html')).writeAsStringSync('x');
      File(p.join(kurz, 'kurs-12.json')).writeAsStringSync('{}');
      Link(p.join(kurz, 'oben')).createSync(draussen.path);
      Link(p.join(kurz, 'cm-815', 'tief')).createSync(draussen.path);

      expect(Arbeitsordner(lang).leeren(), 0);
      expect(Directory(lang).listSync(), isEmpty);
      expect(Directory(lang).existsSync(), isTrue, reason: 'der Ordner selbst bleibt');
      expect(wichtig.existsSync(), isTrue);
    });
  });
}
