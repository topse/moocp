import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/anmeldedaten.dart';
import 'package:moocp/profil.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'Testzugang gilt nur für die zugeordnete Profilkennung und Moodle-Adresse',
    () {
      const zuordnung = <String, ({String datei, String adresse})>{
        'testprofil': (
          datei: 'testzugang.env',
          adresse: 'HTTPS://MOODLE.SCHULE.EXAMPLE/',
        ),
      };
      final testprofil = Profil(
        kennung: 'testprofil',
        name: 'Test',
        adresse: 'https://moodle.schule.example',
        port: 47811,
        mcpName: 'test',
      );
      final produktivprofil = testprofil.copyWith(
        adresse: 'https://produktiv.schule.example',
      );
      final anderesMoodleUnterverzeichnis = testprofil.copyWith(
        adresse: 'https://moodle.schule.example/Moodle',
      );
      final testpfad = testprofil.copyWith(
        adresse: 'https://moodle.schule.example/test',
      );
      final query = testprofil.copyWith(
        adresse: 'https://moodle.schule.example/?next=/test',
      );
      final anderesProfil = Profil(
        kennung: 'anderes-profil',
        name: 'Anderes Profil',
        adresse: testprofil.adresse,
        port: 47812,
        mcpName: 'anderes',
      );

      expect(
        Anmeldedaten.testzugangZuordnungPasst(testprofil, zuordnung),
        isTrue,
      );
      expect(
        Anmeldedaten.testzugangZuordnungPasst(produktivprofil, zuordnung),
        isFalse,
      );
      expect(
        Anmeldedaten.testzugangZuordnungPasst(
          anderesMoodleUnterverzeichnis,
          zuordnung,
        ),
        isFalse,
      );
      expect(
        Anmeldedaten.testzugangZuordnungPasst(testpfad, zuordnung),
        isFalse,
      );
      expect(Anmeldedaten.testzugangZuordnungPasst(query, zuordnung), isFalse);
      expect(
        Anmeldedaten.testzugangZuordnungPasst(
          testprofil.copyWith(adresse: 'https://moodle.schule.example/test'),
          const {
            'testprofil': (
              datei: 'testzugang.env',
              adresse: 'https://moodle.schule.example/test',
            ),
          },
        ),
        isFalse,
      );
      expect(
        Anmeldedaten.testzugangZuordnungPasst(anderesProfil, zuordnung),
        isFalse,
      );
    },
  );

  group('Testzugang schreibt und löscht nichts Gemeinsames', () {
    // Das Testprofil trägt die Kennung des Standardprofils und liest seine
    // Zugangsdaten aus einer Datei. Haken, Benutzername und Passwort der echten
    // Anmeldung lägen unter denselben Schlüsseln: Der Testbetrieb darf sie
    // weder überschreiben noch löschen.
    const adresse = 'https://test.schule.example';
    const sicher = FlutterSecureStorage();

    setUp(() {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({
        'anmeldung.merken': true,
        'anmeldung.benutzer': 'e.mustermann',
      });
      // ignore: invalid_use_of_visible_for_testing_member
      FlutterSecureStorage.setMockInitialValues({'moodle.passwort': 'echtes-passwort'});
    });

    tearDown(() => Anmeldedaten.testprofileErsatz = null);

    void testzugangBinden() => Anmeldedaten.testprofileErsatz = {
          Profil.standardKennung: (datei: 'testzugang.env', adresse: adresse),
        };

    Future<void> gemeinsamUnveraendert() async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('anmeldung.merken'), isTrue);
      expect(prefs.getString('anmeldung.benutzer'), 'e.mustermann');
      expect(await sicher.read(key: 'moodle.passwort'), 'echtes-passwort');
    }

    test('speichern im Testzugang schreibt weder Haken und Benutzername noch Passwort', () async {
      testzugangBinden();
      await Anmeldedaten.speichern('testlehrkraft', 'test-passwort', adresse: adresse);
      await gemeinsamUnveraendert();
    });

    test('loeschen im Testzugang löscht nichts, auch nicht das vorhandene Passwort', () async {
      testzugangBinden();
      await Anmeldedaten.loeschen(adresse: adresse);
      await gemeinsamUnveraendert();
    });

    test('merkenSetzen im Testzugang (auch „aus") und das Verwerfen des Passworts lassen alles stehen', () async {
      testzugangBinden();
      await Anmeldedaten.merkenSetzen(false, adresse: adresse);
      await Anmeldedaten.passwortVerwerfen(adresse: adresse);
      await gemeinsamUnveraendert();
    });

    test('ohne Testzugang (andere Adresse) gilt alles wie gewohnt', () async {
      testzugangBinden();
      const echt = 'https://moodle.schule.example';
      await Anmeldedaten.speichern('e.mustermann', 'neues-passwort', adresse: echt);
      expect(await sicher.read(key: 'moodle.passwort'), 'neues-passwort');
      await Anmeldedaten.passwortVerwerfen(adresse: echt);
      expect(await sicher.read(key: 'moodle.passwort'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('anmeldung.merken'), isTrue, reason: 'Haken und Benutzername bleiben');
      expect(prefs.getString('anmeldung.benutzer'), 'e.mustermann');
      await Anmeldedaten.loeschen(adresse: echt);
      expect(prefs.getBool('anmeldung.merken'), isFalse);
      expect(prefs.getString('anmeldung.benutzer'), isNull);
    });
  });
}
