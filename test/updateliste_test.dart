// Die Positivliste der Update-Prüfung: Was nicht ausdrücklich erlaubt ist,
// fragt die App nicht an -- auch kein Umleitungsziel.

import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/update/updateliste.dart';

void main() {
  String? sperre(String adresse, {bool download = false}) =>
      updateGesperrt(Uri.parse(adresse), download: download);

  group('Abfrage der Version', () {
    test('genau die eine Adresse ist erlaubt', () {
      expect(updateGesperrt(releaseAbfrage, download: false), isNull);
      expect(releaseAbfrage.toString(), 'https://api.github.com/repos/topse/moocp/releases/latest');
    });

    test('alles andere bei GitHub nicht', () {
      // Ein anderes Repository, eine Liste aller Releases, die Suche nach
      // Nutzern: Für die Update-Prüfung braucht es nichts davon.
      expect(sperre('https://api.github.com/repos/fremd/moocp/releases/latest'), isNotNull);
      expect(sperre('https://api.github.com/repos/topse/moocp/releases'), isNotNull);
      expect(sperre('https://api.github.com/repos/topse/moocp/releases/latest?x=1'), isNotNull);
      expect(sperre('https://api.github.com/users/topse'), isNotNull);
    });

    test('kein http, kein fremder Rechner', () {
      expect(sperre('http://api.github.com/repos/topse/moocp/releases/latest'), 'kein https');
      expect(sperre('https://beispiel.test/repos/topse/moocp/releases/latest'), isNotNull);
    });
  });

  group('Download des Installers', () {
    test('das Release dieses Repositorys', () {
      expect(
          sperre('https://github.com/topse/moocp/releases/download/v0.9.5/moocp_setup_0.9.5.exe',
              download: true),
          isNull);
    });

    test('ein fremdes Repository nicht', () {
      expect(
          sperre('https://github.com/fremd/moocp/releases/download/v1.0/setup.exe', download: true),
          isNotNull);
      // Auch nicht irgendeine andere Seite auf github.com.
      expect(sperre('https://github.com/topse/moocp/archive/main.zip', download: true), isNotNull);
    });

    test('die Speicherdienste, auf die GitHub umleitet', () {
      expect(sperre('https://objects.githubusercontent.com/x?token=abc', download: true), isNull);
      expect(sperre('https://release-assets.githubusercontent.com/x', download: true), isNull);
    });

    test('ein Rechner, der nur so heißt, nicht', () {
      expect(sperre('https://githubusercontent.com.beispiel.test/x', download: true), isNotNull);
      expect(sperre('https://boese-githubusercontent.com/x', download: true), isNotNull);
    });

    test('kein http und keine Anmeldedaten in der Adresse', () {
      expect(
          sperre('http://github.com/topse/moocp/releases/download/v1/moocp_setup_1.exe', download: true),
          'kein https');
      expect(
          sperre('https://wer:was@github.com/topse/moocp/releases/download/v1/moocp_setup_1.exe',
              download: true),
          'Adresse mit Anmeldedaten');
    });

    test('die Abfrageadresse ist kein Download und umgekehrt', () {
      expect(updateGesperrt(releaseAbfrage, download: true), isNotNull);
      expect(
          sperre('https://github.com/topse/moocp/releases/download/v1/moocp_setup_1.exe',
              download: false),
          isNotNull);
    });
  });
}
