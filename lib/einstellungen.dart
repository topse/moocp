// Einstellungen, die einen Neustart überleben: Moodle-Adresse, Port,
// Zugangsschlüssel für Claude, die gewählten Skills und die Update-Prüfung.
//
// Bewusst NICHT hier: Benutzername und Passwort. Die leben im Arbeitsspeicher,
// solange die App läuft -- und nur mit Haken „Anmeldedaten speichern" auch
// dauerhaft, siehe anmeldedaten.dart (Passwort mit DPAPI verschlüsselt).
// Ebenso wenig der Arbeitsordner: Der liegt fest und lebt nur so lange wie
// die App (arbeitsordner.dart).

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

class Einstellungen {
  Einstellungen({
    required this.moodleAdresse,
    required this.port,
    required this.schluessel,
    this.wahlSkills,
    this.updatePruefen,
    this.updateZuletzt,
    this.updateErwartet,
  });

  String moodleAdresse;
  int port;
  String schluessel;

  /// Die gewählten unter den wählbaren Skills (einrichtung.dart,
  /// wahlSkills); null, solange im Dialog „Claude einrichten" noch nichts
  /// gewählt wurde -- dann gilt gewaehltVorgabe.
  Set<String>? wahlSkills;

  /// Ob die App einmal täglich bei GitHub nach einer neuen Version sehen
  /// darf; null, solange nicht gefragt wurde (update.dart). Ohne
  /// ausdrückliches Ja fragt die App niemanden -- auch GitHub nicht.
  bool? updatePruefen;

  /// Tag der letzten Prüfung (`2026-10-03`), gesetzt auch nach einem
  /// Fehlversuch: Sonst wartete jemand ohne Netz bei jedem Start erneut auf
  /// die Zeitgrenze.
  String? updateZuletzt;

  /// Die Version, deren Installer gerade gestartet wurde; der nächste Start
  /// vergleicht sie mit der eigenen und meldet Erfolg oder Fehlschlag. Die
  /// App ist währenddessen beendet und sieht sonst nichts davon.
  String? updateErwartet;

  static const int standardPort = 47811;

  static String get ordner => _ordner;

  static String get _ordner {
    final appdata = Platform.environment['APPDATA'] ?? Directory.systemTemp.path;
    return p.join(appdata, 'moocp');
  }

  static File get _datei => File(p.join(_ordner, 'einstellungen.json'));

  static String neuerSchluessel() {
    final r = Random.secure();
    return List.generate(32, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<Einstellungen> laden() async {
    final standard = Einstellungen(
      moodleAdresse: '',
      port: standardPort,
      schluessel: neuerSchluessel(),
    );
    try {
      if (await _datei.exists()) {
        final j = jsonDecode(await _datei.readAsString()) as Map<String, dynamic>;
        return Einstellungen(
          moodleAdresse: j['moodleAdresse'] as String? ?? standard.moodleAdresse,
          port: j['port'] as int? ?? standard.port,
          schluessel: j['schluessel'] as String? ?? standard.schluessel,
          wahlSkills: (j['wahlSkills'] as List?)?.whereType<String>().toSet(),
          updatePruefen: j['updatePruefen'] as bool?,
          updateZuletzt: j['updateZuletzt'] as String?,
          updateErwartet: j['updateErwartet'] as String?,
        );
      }
    } catch (_) {
      // Kaputte Datei: mit den Standardwerten weiter und beim Speichern ersetzen.
    }
    await standard.speichern();
    return standard;
  }

  Future<void> speichern() async {
    await Directory(_ordner).create(recursive: true);
    await _datei.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'moodleAdresse': moodleAdresse,
      'port': port,
      'schluessel': schluessel,
      if (wahlSkills != null) 'wahlSkills': (wahlSkills!.toList()..sort()),
      if (updatePruefen != null) 'updatePruefen': updatePruefen,
      if (updateZuletzt != null) 'updateZuletzt': updateZuletzt,
      if (updateErwartet != null) 'updateErwartet': updateErwartet,
    }));
  }
}
