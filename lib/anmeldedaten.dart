// Gespeicherte Anmeldedaten -- nur, wenn die Lehrkraft den Haken setzt.
//
// Wo was liegt:
//   - Haken und Benutzername: shared_preferences (Klartext-JSON im
//     Einstellungsordner, unter Windows %APPDATA%\moocp\moocp\). Kein Geheimnis.
//   - Passwort: flutter_secure_storage. Unter Windows mit DPAPI verschlüsselt
//     (flutter_secure_storage.dat im selben Ordner), auf dem Mac im
//     Schlüsselbund (E26). Entschlüsseln kann nur das Benutzerkonto des
//     Rechners; eine Kopie der Datei, ein Backup oder ein anderes Konto sieht
//     Datensalat.
//
// Grenze: Ein Programm, das unter demselben Benutzerkonto läuft, kann das
// Passwort gezielt entschlüsseln -- das gilt für jede Speicherung, die ohne
// Rückfrage auskommt. Das Passwort geht nie über MCP hinaus und nie ins
// Protokoll.
//
// Gespeichert wird nur nach einer ERFOLGREICHEN Anmeldung, damit sich kein
// Tippfehler festsetzt. Nimmt die Lehrkraft den Haken weg, werden
// Benutzername und Passwort sofort entfernt.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'plattform/linux_schluesselbund.dart';
import 'profil.dart';
import 'testzugang.dart';

class Anmeldedaten {
  static const _merken = 'anmeldung.merken';
  static const _benutzer = 'anmeldung.benutzer';
  static const _passwort = 'moodle.passwort';

  /// Schlüssel je Instanzprofil (profil.dart). Das Standardprofil behält die
  /// alten Schlüssel, damit gespeicherte Zugangsdaten nach dem Umstieg gelten;
  /// jedes weitere Profil bekommt die Kennung angehängt.
  static String _schluessel(String basis, String kennung) =>
      kennung == Profil.standardKennung ? basis : '$basis.$kennung';

  /// Wo das Passwort verschlüsselt liegt, für Protokoll und Hinweise. Auf dem
  /// Mac ist es der Schlüsselbund, unter Windows DPAPI.
  static String get schutz => Platform.isMacOS
      ? 'verschlüsselt im macOS-Schlüsselbund'
      : Platform.isLinux
      ? 'verschlüsselt im Schlüsselbund (Secret Service)'
      : 'verschlüsselt mit Windows-DPAPI';

  /// Wer das Passwort wieder lesen kann.
  static String get lesbarFuer => Platform.isMacOS || Platform.isLinux
      ? 'nur mit Ihrem Benutzerkonto lesbar'
      : 'nur mit Ihrem Windows-Konto lesbar';

  // Ohne Rückgriff auf die Windows-Anmeldeinformationsverwaltung älterer
  // Paketversionen: nur die DPAPI-verschlüsselte Datei. Auf dem Mac der alte
  // Schlüsselbund statt der Datenschutz-Schlüsselbundgruppe: Die verlangt eine
  // Team-ID zum Signieren, die ein Entwicklerbau ohne Konto nicht hat.
  static const _sicher = FlutterSecureStorage(
    wOptions: WindowsOptions(useBackwardCompatibility: false),
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  /// Unter Linux wartet libsecret bei einem gesperrten oder fehlenden
  /// Schlüsselbund auf einen Dialog und blockiert dabei die ganze App
  /// (plattform/linux_schluesselbund.dart). Darum wird vor jedem Zugriff
  /// gefragt, ob der Bund benutzbar ist; ein gesperrter wird über einen
  /// eigenen Prozess zum Entsperren aufgefordert, ohne die App anzuhalten.
  /// Bleibt er unbenutzbar, scheitert der Zugriff mit einem
  /// [SchluesselbundFehler], und es geht ohne gespeichertes Passwort weiter;
  /// die App legt das Passwort nie auf eine andere Art ab (A2). Unter Windows
  /// und auf dem Mac gibt es keinen solchen Dialog.
  /// [fehltIstEgal]: Zum Löschen genügt es, wenn es gar keinen Bund gibt;
  /// dann liegt auch kein Passwort darin.
  static Future<T?> _zugriff<T>(Future<T> Function() zugriff, {bool fehltIstEgal = false}) async {
    if (Platform.isLinux) {
      var zustand = await schluesselbundPruefer();
      if (zustand == Schluesselbund.gesperrt) zustand = await schluesselbundEntsperrer();
      switch (zustand) {
        case Schluesselbund.bereit:
          break;
        case Schluesselbund.fehlt when fehltIstEgal:
          return null;
        default:
          throw SchluesselbundFehler(zustand);
      }
    }
    return zugriff();
  }

  /// Nur für Tests: ersetzt die Abfrage des Secret Service, die es auf dem
  /// Testrechner nicht gibt (test/flutter_test_config.dart setzt „bereit").
  @visibleForTesting
  static Future<Schluesselbund> Function() schluesselbundPruefer = schluesselbundPruefen;

  /// Nur für Tests, wie [schluesselbundPruefer].
  @visibleForTesting
  static Future<Schluesselbund> Function() schluesselbundEntsperrer = schluesselbundEntsperren;

  final bool merken;
  final String? benutzer;
  final String? passwort;

  /// [speicherProblem]: Warum das gespeicherte Passwort nicht gelesen wurde,
  /// wenn es an einem unbenutzbaren Schlüsselbund liegt (nur Linux); fester
  /// Text für die Lehrkraft, ohne Inhalte (E11).
  const Anmeldedaten(this.merken, this.benutzer, this.passwort, {this.speicherProblem});

  final String? speicherProblem;

  /// Nur für Tests: ersetzt die Testzugänge aus der Umgebung (die ein Test
  /// nicht setzen kann). Ohne Wert gilt die Umgebung (Testzugang.ausUmgebung).
  @visibleForTesting
  static Map<String, ({String datei, String adresse})>? testprofileErsatz;

  static Map<String, ({String datei, String adresse})> get _testprofile =>
      testprofileErsatz ??
      {
        for (final t in Testzugang.ausUmgebung().values)
          t.kennung: (datei: t.datei, adresse: t.adresse),
      };

  static bool testzugangZuordnungPasst(Profil profil, Map<String, ({String datei, String adresse})> testprofile) =>
      _testprofilPasst(profil.kennung, profil.adresse, testprofile);

  static bool _testprofilPasst(String kennung, String adresse, Map<String, ({String datei, String adresse})> testprofile) {
    final test = testprofile[kennung];
    if (test == null) return false;
    final testAdresse = Testzugang.adresseSchluessel(test.adresse);
    final profilAdresse = Testzugang.adresseSchluessel(adresse);
    return testAdresse != null && profilAdresse != null && testAdresse == profilAdresse;
  }

  static bool testzugangAktivFuer(Profil profil) => testzugangZuordnungPasst(profil, _testprofile);

  static bool _testprofil(String kennung, String? adresse) =>
      adresse != null && _testprofilPasst(kennung, adresse, _testprofile);

  /// Liest ausschließlich den ausdrücklich gebundenen Zugang dieses Profils.
  static Future<(String, String)?> _testzugang(String kennung, String? adresse) async {
    final test = _testprofile[kennung];
    if (test == null ||
        adresse == null ||
        !_testprofilPasst(kennung, adresse, _testprofile)) {
      return null;
    }
    final pfad = test.datei;
    // Nur die Namen stehen in Fehlermeldungen, nie die Werte.
    final werte = <String, String>{};
    for (final zeile in await File(pfad).readAsLines()) {
      final t = zeile.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final gleich = t.indexOf('=');
      if (gleich < 0) continue;
      final wert = t.substring(gleich + 1).trim();
      werte[t.substring(0, gleich).trim()] = wert.replaceAll(RegExp(r'''^["']|["']$'''), '');
    }
    final benutzer = werte['TEACHER_USERNAME'];
    final passwort = werte['TEACHER_PASSWORD'];
    if (benutzer == null || passwort == null) {
      throw StateError('Testzugang: TEACHER_USERNAME oder TEACHER_PASSWORD fehlt in $pfad');
    }
    return (benutzer, passwort);
  }

  static Future<Anmeldedaten> laden({String kennung = Profil.standardKennung, String? adresse}) async {
    final test = await _testzugang(kennung, adresse);
    if (test != null) return Anmeldedaten(true, test.$1, test.$2);
    final prefs = await SharedPreferences.getInstance();
    final merken = prefs.getBool(_schluessel(_merken, kennung)) ?? false;
    if (!merken) return const Anmeldedaten(false, null, null);
    String? passwort;
    String? problem;
    try {
      passwort = await _zugriff<String?>(() => _sicher.read(key: _schluessel(_passwort, kennung)));
    } on SchluesselbundFehler catch (e) {
      // Unter Linux: Der Bund ist gesperrt oder fehlt. Die Lehrkraft erfährt
      // den Grund, statt vor einem leeren Passwortfeld zu stehen.
      problem = e.meldung;
    } catch (_) {
      // Nicht zu entschlüsseln (etwa anderes Windows-Konto): dann eben eintippen.
    }
    return Anmeldedaten(true, prefs.getString(_schluessel(_benutzer, kennung)), passwort, speicherProblem: problem);
  }

  // Im Testbetrieb mit Testzugang (testzugang.dart) kommen die Zugangsdaten
  // aus der Datei, nicht aus dem Speicher, und das Testprofil trägt oft die
  // Kennung des Standardprofils: Haken, Benutzername und Passwort lägen unter
  // denselben Schlüsseln wie die der echten Anmeldung. Darum schreiben und
  // löschen die drei Methoden unten dort nichts -- weder in die gemeinsamen
  // shared_preferences noch in den sicheren Speicher.

  /// Merkt sich den Haken.
  static Future<void> merkenSetzen(bool an, {String kennung = Profil.standardKennung, String? adresse}) async {
    if (_testprofil(kennung, adresse)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_schluessel(_merken, kennung), an);
    if (!an) await loeschen(kennung: kennung, adresse: adresse);
  }

  /// Nach erfolgreicher Anmeldung, nur mit gesetztem Haken.
  static Future<void> speichern(String benutzer, String passwort,
      {String kennung = Profil.standardKennung, String? adresse}) async {
    if (_testprofil(kennung, adresse)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_schluessel(_merken, kennung), true);
    await prefs.setString(_schluessel(_benutzer, kennung), benutzer);
    await _zugriff(() => _sicher.write(key: _schluessel(_passwort, kennung), value: passwort));
  }

  /// Entfernt Benutzername und Passwort ausdrücklich -- shared_preferences
  /// kennt kein „auf null setzen", remove ist genau das.
  static Future<void> loeschen({String kennung = Profil.standardKennung, String? adresse}) async {
    if (_testprofil(kennung, adresse)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_schluessel(_merken, kennung), false);
    await prefs.remove(_schluessel(_benutzer, kennung));
    await _zugriff(() => _sicher.delete(key: _schluessel(_passwort, kennung)), fehltIstEgal: true);
  }

  /// Verwirft nur das Passwort, nachdem Moodle es abgelehnt hat (E7). Haken
  /// und Benutzername bleiben: Die Lehrkraft muss nur das Passwort neu
  /// eingeben, und eine Anmeldung mit Haken speichert es wieder. Ohne
  /// Passwort meldet weder der Start noch ein Profilwechsel von selbst an --
  /// sonst erzeugte jeder weitere Versuch mit dem veralteten Passwort einen
  /// Fehlversuch mehr, bis Moodle das Konto sperrt.
  static Future<void> passwortVerwerfen({String kennung = Profil.standardKennung, String? adresse}) async {
    if (_testprofil(kennung, adresse)) return;
    await _zugriff(() => _sicher.delete(key: _schluessel(_passwort, kennung)), fehltIstEgal: true);
  }
}
