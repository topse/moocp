// Wo die Einstellungen liegen, ohne Flutter: Das braucht außer der App auch
// die Brücke (mcp/bruecke.dart), ein eigenes Programm ohne Flutter.
// einstellungen.dart selbst hängt über freigabe.dart an Flutter.
import 'dart:io';

import 'package:path/path.dart' as p;

const standardPort = 47811;

/// `%APPDATA%\moocp` unter Windows, `~/Library/Application Support/moocp` auf
/// dem Mac, `~/.config/moocp` unter Linux: Einstellungen und Protokoll.
String get einstellungenOrdner => einstellungenOrdnerFuer(
  Platform.environment,
  macos: Platform.isMacOS,
  linux: Platform.isLinux,
);

/// Der Ordner für eine gegebene Umgebung; getrennt, damit sich der Pfad auch
/// ohne den Rechner prüfen lässt, auf dem er gebraucht wird.
String einstellungenOrdnerFuer(
  Map<String, String> umgebung, {
  required bool macos,
  bool linux = false,
}) {
  // Ohne Benutzerordner gäbe es nur den Temp-Ordner, und Einstellungen wie
  // Sicherungen lägen dann dort, wo der Rechner sie jederzeit löscht. Also
  // lieber ein klarer Fehler (E29).
  if (macos) {
    final heim = umgebung['HOME'];
    if (heim == null || heim.isEmpty) {
      throw StateError('Der Benutzerordner (HOME) ist nicht gesetzt; die Einstellungen können nicht gespeichert werden.');
    }
    return p.join(heim, 'Library', 'Application Support', 'moocp');
  }
  if (linux) {
    // XDG Base Directory: $XDG_CONFIG_HOME, wenn gesetzt und absolut (die
    // Spezifikation verlangt, ein relativer Wert wird ignoriert), sonst
    // ~/.config.
    final xdg = umgebung['XDG_CONFIG_HOME'];
    if (xdg != null && p.isAbsolute(xdg)) return p.join(xdg, 'moocp');
    final heim = umgebung['HOME'];
    if (heim == null || heim.isEmpty) {
      throw StateError('Der Benutzerordner (HOME) ist nicht gesetzt; die Einstellungen können nicht gespeichert werden.');
    }
    return p.join(heim, '.config', 'moocp');
  }
  final appdata = umgebung['APPDATA'];
  if (appdata == null || appdata.isEmpty) {
    throw StateError('Der Ordner %APPDATA% ist nicht gesetzt; die Einstellungen können nicht gespeichert werden.');
  }
  return p.join(appdata, 'moocp');
}

File get einstellungenDatei => File(p.join(einstellungenOrdner, 'einstellungen.json'));

/// Der Ordner für Sicherungen einer Aktivität (E29): außerhalb des Arbeitsordners,
/// der beim Start und Beenden geleert wird. Unter Windows `%APPDATA%\moocp\sicherungen`,
/// auf dem Mac `~/Library/Application Support/moocp/sicherungen`, unter Linux
/// `~/.config/moocp/sicherungen`.
String get sicherungenOrdner =>
    sicherungenOrdnerFuer(Platform.environment, macos: Platform.isMacOS, linux: Platform.isLinux);

String sicherungenOrdnerFuer(Map<String, String> umgebung, {required bool macos, bool linux = false}) =>
    p.join(einstellungenOrdnerFuer(umgebung, macos: macos, linux: linux), 'sicherungen');
