// Der Bauschalter des Testbetriebs (lib/testschalter.dart): Ohne ihn läuft die
// App im Normalbetrieb -- sie liest keine Testzugänge, gibt nichts automatisch
// frei und lässt keinen http-Zugang zu. test/flutter_test_config.dart schaltet
// den Testbetrieb für alle anderen Tests ein; hier wird er ausgeschaltet.

import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/freigabe.dart';
import 'package:moocp/moodle/moodle_zugang.dart';
import 'package:moocp/profil.dart';
import 'package:moocp/protokoll.dart';
import 'package:moocp/testschalter.dart';
import 'package:moocp/testzugang.dart';

final _profil = Profil(
  kennung: 'standard',
  name: 'Test',
  adresse: 'https://moodle.schule.example',
  port: 47811,
  mcpName: 'test',
);

const _zugang = Testzugang(
  kennung: 'standard',
  datei: 'unused.env',
  adresse: 'https://moodle.schule.example',
);

void main() {
  tearDown(() => testbetriebFuerTestsSetzen(true));

  test('mit Schalter bindet ein Testzugang das passende Profil', () {
    testbetriebFuerTestsSetzen(true);
    expect(testbetriebAktiv, isTrue);
    expect(_zugang.passt(_profil), isTrue);
  });

  test('ohne Schalter passt kein Testzugang, auch bei gleicher Kennung und Adresse', () {
    testbetriebFuerTestsSetzen(false);
    expect(testbetriebAktiv, isFalse);
    expect(_zugang.passt(_profil), isFalse);
  });

  test('ohne Schalter liest die App keine Testzugänge aus der Umgebung', () {
    testbetriebFuerTestsSetzen(false);
    expect(Testzugang.ausUmgebung(), isEmpty);
    expect(Testzugang.fuer(_profil), isNull);
  });

  test('ohne Schalter gibt es keinen http-Zugang für Tests', () async {
    testbetriebFuerTestsSetzen(false);
    await expectLater(
      MoodleZugang.fuerTest(Protokoll(), Uri.parse('http://127.0.0.1:1'), benutzer: 'e.mustermann', passwort: 'erfunden'),
      throwsStateError,
    );
  });

  test('ohne Schalter fragt auch eine Anfrage, die im Testbetrieb automatisch ginge', () async {
    testbetriebFuerTestsSetzen(false);
    final f = Freigaben(Protokoll(), stufe: Bestaetigungen.alle);
    final a = FreigabeAnfrage(titel: 'ZZ ändern?', punkte: const [], vergleich: const []);
    var geprueft = 0;
    final antwort = f.imTest(() => f.anfragen(a), pruefen: () async {
      geprueft++;
      return true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(f.aktuell, same(a));
    expect(geprueft, 0);
    f.entscheiden(false);
    expect(await antwort, isFalse);
    expect(f.testfreigaben, 0);
  });
}
