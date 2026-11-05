// Ein Schutzdienst vor der Instanz, der schon die Anmeldung anhält, ist kein
// Fehlversuch: Das Passwort kam nie bei Moodle an. Der Zugang meldet es als
// „nicht erreichbar", damit eine Neuanmeldung die Zugangsdaten behält
// (_neuAnmelden), und das Protokoll nennt die Ray-ID, aber keine Werte (A4).
// Das gilt für alle drei Schritte der Anmeldung: Anmeldeseite, Formular und
// die Bestätigung der Sitzung (testsession), bei der das Passwort schon
// angenommen ist.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/moodle_zugang.dart';
import 'package:moocp/protokoll.dart';

void main() {
  late HttpServer server;
  late Uri basis;

  /// [pruefungBei]: bei welcher Methode die Prüfung des Schutzdienstes kommt.
  Future<void> starten(String pruefungBei) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    basis = Uri.parse('http://127.0.0.1:${server.port}');
    server.listen((req) async {
      await req.drain<void>();
      if (req.method == pruefungBei) {
        req.response
          ..statusCode = 403
          ..headers.set('cf-mitigated', 'challenge')
          ..headers.set('cf-ray', 'abc123-FRA')
          ..headers.contentType = ContentType.html
          ..write('<html>Just a moment...</html>');
      } else {
        req.response
          ..headers.contentType = ContentType.html
          ..write('<html><input name="logintoken" value="t"></html>');
      }
      await req.response.close();
    });
  }

  tearDown(() => server.close(force: true));

  for (final bei in ['GET', 'POST']) {
    test('Prüfung des Schutzdienstes bei $bei der Anmeldung: nicht erreichbar, nicht „falsches Passwort"', () async {
      await starten(bei);
      final protokoll = Protokoll();
      await expectLater(
        MoodleZugang.fuerTest(protokoll, basis, benutzer: 'e.mustermann', passwort: 'geheim'),
        throwsA(isA<MoodleNichtErreichbar>()),
      );
      final text = protokoll.eintraege.map((e) => e.text).join('\n');
      expect(text, contains('Ray-ID abc123-FRA'));
      expect(text, isNot(contains('geheim')));
      expect(text, isNot(contains('e.mustermann')));
    });
  }

  group('Schutzdienst beim letzten Schritt (testsession)', () {
    // Ein Moodle-Doppel, das Anmeldeseite und Formular durchlässt und erst
    // die Bestätigung der Sitzung dem Schutzdienst überlässt. Ob die
    // Sitzung gilt, steht in [eingeloggt]; ein Ablauf setzt es zurück.
    late HttpServer moodle;
    late Uri moodleBasis;
    var schutzBeiTestsession = false;
    var eingeloggt = false;
    var formulare = 0;

    setUp(() async {
      schutzBeiTestsession = false;
      eingeloggt = false;
      formulare = 0;
      moodle = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      moodleBasis = Uri.parse('http://127.0.0.1:${moodle.port}');
      moodle.listen((req) async {
        await req.drain<void>();
        Future<void> umleiten(String ziel) async {
          req.response.redirect(Uri.parse(ziel), status: HttpStatus.seeOther);
          await req.response.close();
        }

        if (req.uri.path == '/login/index.php' && req.method == 'POST') {
          formulare++;
          return umleiten('/login/index.php?testsession=1');
        }
        if (req.uri.path == '/login/index.php' && req.uri.queryParameters.containsKey('testsession')) {
          if (schutzBeiTestsession) {
            req.response
              ..statusCode = 403
              ..headers.set('cf-mitigated', 'challenge')
              ..headers.set('cf-ray', 'xyz789-FRA')
              ..headers.contentType = ContentType.html
              ..write('<html>Just a moment...</html>');
            return req.response.close();
          }
          eingeloggt = true;
          return umleiten('/my/');
        }
        if (req.uri.path == '/login/index.php') {
          req.response
            ..headers.contentType = ContentType.html
            ..write('<html><input name="logintoken" value="t"></html>');
          return req.response.close();
        }
        if (!eingeloggt) return umleiten('/login/index.php');
        req.response
          ..headers.contentType = ContentType.html
          ..write('<html>Kurs 12</html>');
        await req.response.close();
      });
    });

    tearDown(() => moodle.close(force: true));

    test('bei der Anmeldung: nicht erreichbar, nicht „Formular angehalten, nichts gespeichert“', () async {
      schutzBeiTestsession = true;
      final protokoll = Protokoll();
      Object? fehler;
      try {
        await MoodleZugang.fuerTest(protokoll, moodleBasis, benutzer: 'e.mustermann', passwort: 'geheim');
      } catch (e) {
        fehler = e;
      }
      expect(fehler, isA<MoodleNichtErreichbar>());
      final meldung = (fehler! as MoodleFehler).meldung;
      expect(meldung, contains('letzten Schritt der Anmeldung'));
      expect(meldung, contains('Passwort ist angenommen'),
          reason: 'anders als in den ersten beiden Schritten ist es hier schon geprüft');
      expect(meldung, isNot(contains('Nichts gespeichert')));
      final text = protokoll.eintraege.map((e) => e.text).join('\n');
      expect(text, contains('Ray-ID xyz789-FRA'));
      expect(text, isNot(contains('geheim')));
    });

    test('bei der Neuanmeldung bleiben die Zugangsdaten, und der nächste Versuch geht wieder', () async {
      final z = await MoodleZugang.fuerTest(Protokoll(), moodleBasis, benutzer: 'e.mustermann', passwort: 'geheim');
      expect(z.angemeldet, isTrue);
      expect(formulare, 1);

      // Die Sitzung läuft ab, und der Schutzdienst hält den letzten Schritt der Neuanmeldung an.
      eingeloggt = false;
      schutzBeiTestsession = true;
      await expectLater(z.lesen('/course/modedit.php?update=34'), throwsA(isA<MoodleNichtErreichbar>()));
      expect(formulare, 2, reason: 'genau eine Neuanmeldung, kein zweiter Versuch');
      expect(z.angemeldet, isTrue, reason: 'die Zugangsdaten sind nicht verworfen');

      // Der Schutzdienst lässt wieder durch: Dieselben Zugangsdaten melden neu an.
      schutzBeiTestsession = false;
      final r = await z.lesen('/course/modedit.php?update=34');
      expect(r.text, contains('Kurs 12'));
      expect(formulare, 3);
    });
  });
}
