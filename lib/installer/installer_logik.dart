// Installieren und Deinstallieren unter Linux, ohne Oberfläche (E24, E15).
//
// Das Gegenstück zu installer/moocp.nsi: je Benutzer, ohne Administratorrechte,
// in einen Ordner im Benutzerverzeichnis. Die Oberfläche dazu steht in
// installer_seiten.dart; hier liegt, was sich ohne Fenster prüfen lässt.
//
// Linux-spezifisch: Pfade nach der XDG-Spezifikation, `.desktop`-Dateien für
// Startmenü und Schreibtisch, Laufprüfung über /proc.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../arbeitsordner.dart';
import '../einstellungen_ort.dart';

const programmName = 'moocp';

/// Was der Installer in den Zielordner legt, und nur das -- nie den Ordner als
/// Ganzes (wie `ProgrammEntfernen` im NSIS-Skript): Der Zielordner ist frei
/// wählbar, und ein Ordner mit fremden Dateien darf nie ausgeräumt werden.
const programmDateien = [programmName, 'moocp.png', 'moocp-deinstallieren'];
const programmOrdner = ['lib', 'data'];

/// Die Marke, an der ein Ordner als Installation von moocp gilt. Steht die
/// Version darin, und fehlt in einem Ordner, der nicht leer ist: Dann wird nicht
/// installiert.
const markeDatei = '.moocp-installiert';

/// Ein Fehler, den die Lehrkraft lesen soll (kein Absturz).
class InstallerFehler implements Exception {
  InstallerFehler(this.text);
  final String text;
  @override
  String toString() => text;
}

/// Orte einer Installation für eine gegebene Umgebung. Getrennt von
/// `Platform.environment`, damit Tests in einem eigenen Heimatordner laufen und
/// nie an die echten Einstellungen kommen.
class InstallerOrte {
  InstallerOrte(this.umgebung);
  final Map<String, String> umgebung;

  String get heim {
    final h = umgebung['HOME'];
    if (h == null || h.isEmpty) {
      throw InstallerFehler('Der Benutzerordner (HOME) ist nicht gesetzt.');
    }
    return h;
  }

  String get _datenOrdner {
    final x = umgebung['XDG_DATA_HOME'];
    return x != null && p.isAbsolute(x) ? x : p.join(heim, '.local', 'share');
  }

  /// Vorschlag für den Zielordner, wie `%LOCALAPPDATA%\Programs\moocp` unter
  /// Windows: `~/.local/opt/moocp`.
  String get standardZiel => p.join(heim, '.local', 'opt', programmName);

  /// Das Startmenü (Anwendungsmenü des Benutzers).
  String get menueOrdner => p.join(_datenOrdner, 'applications');

  String get menueDatei => p.join(menueOrdner, 'moocp.desktop');

  /// Das Symbol im Symbolthema des Benutzers; Menüeinträge finden es über den
  /// Namen `moocp`.
  String get symbolDatei => p.join(_datenOrdner, 'icons', 'hicolor', '256x256', 'apps', 'moocp.png');

  /// Der Schreibtisch: `XDG_DESKTOP_DIR` aus `user-dirs.dirs`, sonst `~/Desktop`.
  String get desktopOrdner {
    final env = umgebung['XDG_DESKTOP_DIR'];
    if (env != null && p.isAbsolute(env)) return env;
    final cfg = umgebung['XDG_CONFIG_HOME'];
    final dirs = File(
      p.join(cfg != null && p.isAbsolute(cfg) ? cfg : p.join(heim, '.config'), 'user-dirs.dirs'),
    );
    try {
      for (final z in dirs.readAsLinesSync()) {
        final m = RegExp(r'^XDG_DESKTOP_DIR="?([^"]*)"?\s*$').firstMatch(z.trim());
        if (m != null) return m.group(1)!.replaceFirst(r'$HOME', heim);
      }
    } catch (_) {
      // Keine Datei: Vorgabe.
    }
    return p.join(heim, 'Desktop');
  }

  String get desktopDatei => p.join(desktopOrdner, 'moocp.desktop');

  /// Die Daten der App wie in `lib/einstellungen_ort.dart`.
  String get einstellungen => einstellungenOrdnerFuer(umgebung, macos: false, linux: true);

  /// Wo `shared_preferences` unter Linux liegt (Haken und Benutzername;
  /// `path_provider`, Kennung aus linux/CMakeLists.txt).
  String get prefsOrdner => p.join(_datenOrdner, 'com.example.moocp');

  /// Der Arbeitsordner im Temp-Verzeichnis (lib/arbeitsordner.dart).
  String get arbeitsordner => p.join(
    umgebung['TMPDIR'] ?? Directory.systemTemp.path,
    Arbeitsordner.ordnername(umgebung, linux: true),
  );
}

/// Der Inhalt der `.desktop`-Datei für Startmenü und Schreibtisch. [exe] und
/// [symbol] stehen in Anführungszeichen, weil der Zielordner Leerzeichen
/// enthalten darf (Desktop Entry Specification, „Exec").
String desktopInhalt({required String exe, required String deinstallieren}) {
  // Zwei Schichten der Desktop-Entry-Spezifikation: Anführungszeichen im
  // Exec-Wert (\ " ` $ mit Backslash), dann das Escaping der Zeichenkette
  // (jeder Backslash doppelt); `%` ist ein Feldcode und wird verdoppelt.
  String q(String s) {
    final e = s.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll(r'$', r'\$').replaceAll('`', r'\`');
    return '"${e.replaceAll(r'\', r'\\').replaceAll('%', '%%')}"';
  }
  return '[Desktop Entry]\n'
      'Type=Application\n'
      'Version=1.0\n'
      'Name=moocp\n'
      'Comment=Moodle-Kurse mit einem KI-Werkzeug bearbeiten\n'
      'Exec=${q(exe)}\n'
      'Icon=moocp\n'
      'Terminal=false\n'
      'Categories=Education;\n'
      'StartupWMClass=moocp\n'
      'Actions=deinstallieren;\n'
      '\n'
      '[Desktop Action deinstallieren]\n'
      'Name=moocp deinstallieren\n'
      'Exec=${q(deinstallieren)}\n';
}

/// Das Skript `moocp-deinstallieren`: ruft das installierte Programm mit dem
/// Schalter auf. Ein Skript statt eines zweiten Programms, damit der Ordner
/// nur eine Datei mehr hat.
String deinstallierenSkript() =>
    '#!/bin/sh\n'
    '# Entfernt moocp mit Einstellungen, gespeicherten Anmeldedaten und der\n'
    '# Einrichtung in den KI-Werkzeugen.\n'
    'exec "\$(dirname "\$(readlink -f "\$0")")/moocp" --deinstallieren "\$@"\n';

/// Ob [exe] gerade als Programm läuft (nicht als dieser Prozess). Über /proc:
/// Die Brücke gibt es unter Linux nicht, nur die App selbst sperrt nichts --
/// ein laufendes Programm ließe sich löschen, aber E15 verlangt, nie eine
/// laufende App zu beenden: Die App leert ihren Arbeitsordner nur beim
/// regulären Schließen.
bool programmLaeuft(String exe, {String proc = '/proc'}) {
  // /proc/<pid>/exe liefert den aufgelösten Pfad; ein Zielordner über einen
  // Symlink oder mit `..` würde sonst nie erkannt.
  exe = _aufgeloest(exe);
  try {
    for (final e in Directory(proc).listSync(followLinks: false)) {
      final nr = int.tryParse(p.basename(e.path));
      if (nr == null || nr == pid) continue;
      try {
        final ziel = Link(p.join(e.path, 'exe')).targetSync();
        if (ziel == exe || ziel == '$exe (deleted)') return true;
      } catch (_) {
        // Fremder Prozess oder schon beendet: nicht unser Programm.
      }
    }
  } catch (_) {
    // Kein /proc: nicht prüfbar, also nicht blockieren.
  }
  return false;
}

String _aufgeloest(String pfad) {
  final c = p.canonicalize(pfad);
  try {
    return File(c).resolveSymbolicLinksSync();
  } catch (_) {
    // Noch nicht vorhanden: den vorhandenen Teil auflösen.
    final eltern = p.dirname(c);
    if (eltern == c) return c;
    return p.join(_aufgeloest(eltern), p.basename(c));
  }
}

/// Prüft den Zielordner; wirft [InstallerFehler] mit einem Satz für die
/// Lehrkraft. Leer oder nicht vorhanden geht, eine frühere Installation (Marke)
/// geht, alles andere nicht.
void zielPruefen(String ziel) {
  if (ziel.trim().isEmpty || !p.isAbsolute(ziel)) {
    throw InstallerFehler('Bitte einen vollständigen Ordnerpfad angeben.');
  }
  final d = Directory(ziel);
  final f = File(ziel);
  if (f.existsSync()) throw InstallerFehler('Der Pfad ist eine Datei, kein Ordner.');
  if (!d.existsSync()) return;
  if (File(p.join(ziel, markeDatei)).existsSync()) return;
  if (d.listSync().isNotEmpty) {
    throw InstallerFehler(
      'Der Ordner ist nicht leer und enthält keine frühere Installation von moocp. '
      'Bitte einen leeren oder neuen Ordner wählen.',
    );
  }
}

/// Der Ordner, in dem die gebaute App liegt (`moocp`, `lib/`, `data/`): der
/// Ordner der laufenden exe, wenn der Installer als Programm aus dem
/// entpackten Paket läuft.
String quelleDerApp() => p.dirname(Platform.resolvedExecutable);

/// Ob [quelle] eine gebaute App ist.
bool istAppOrdner(String quelle) =>
    File(p.join(quelle, programmName)).existsSync() &&
    Directory(p.join(quelle, 'lib')).existsSync() &&
    Directory(p.join(quelle, 'data')).existsSync();

/// Schritte für die Anzeige: Text, den die Seite „Installieren" zeigt.
typedef Meldung = void Function(String text);

void _kopieren(Directory von, Directory nach) {
  nach.createSync(recursive: true);
  for (final e in von.listSync(followLinks: false)) {
    final ziel = p.join(nach.path, p.basename(e.path));
    if (e is Directory) {
      _kopieren(e, Directory(ziel));
    } else if (e is Link) {
      Link(ziel).createSync(e.targetSync());
    } else if (e is File) {
      e.copySync(ziel);
    }
  }
}

void _entfernen(String ziel) {
  for (final f in programmDateien) {
    final d = File(p.join(ziel, f));
    if (d.existsSync() || FileSystemEntity.isLinkSync(d.path)) d.deleteSync();
  }
  for (final o in programmOrdner) {
    final d = Directory(p.join(ziel, o));
    if (d.existsSync()) d.deleteSync(recursive: true);
  }
}

/// Installiert die App aus [quelle] nach [ziel]. Über einer älteren Version:
/// Deren Programmdateien werden ersetzt; Einstellungen, Anmeldedaten und die
/// Einrichtung der KI-Werkzeuge bleiben (die App prüft beim Start, ob die
/// Skills zur Version passen).
///
/// [symbol] ist das Bild für Menü und Schreibtisch (docs/icon/icon.png), das
/// der Paketbau als `moocp.png` neben die App legt; fehlt es, geht es auch
/// ohne.
void installieren({
  required String quelle,
  required String ziel,
  required InstallerOrte orte,
  required String version,
  Meldung? meldung,
}) {
  void sag(String t) => meldung?.call(t);
  if (!istAppOrdner(quelle)) {
    throw InstallerFehler('Im Installationspaket fehlt das Programm.');
  }
  zielPruefen(ziel);
  if (p.equals(quelle, ziel) || p.isWithin(quelle, ziel) || p.isWithin(ziel, quelle)) {
    throw InstallerFehler('Das Ziel darf nicht der Ordner des Installationspakets sein.');
  }
  final exe = p.join(ziel, programmName);
  if (programmLaeuft(exe)) {
    throw InstallerFehler('moocp läuft noch. Bitte die App schließen und es noch einmal versuchen.');
  }
  sag('Entferne die ältere Version …');
  if (Directory(ziel).existsSync()) _entfernen(ziel);
  Directory(ziel).createSync(recursive: true);
  // Die Marke zuerst: Bricht das Kopieren ab, gilt der Ordner weiter als
  // Installation von moocp, und Wiederholen und Deinstallieren gehen.
  File(p.join(ziel, markeDatei)).writeAsStringSync('$version\n');
  sag('Kopiere die Programmdateien …');
  for (final e in Directory(quelle).listSync(followLinks: false)) {
    final name = p.basename(e.path);
    if (name == markeDatei || name == 'testbetrieb') continue;
    final z = p.join(ziel, name);
    if (e is Directory) {
      _kopieren(e, Directory(z));
    } else if (e is Link) {
      Link(z).createSync(e.targetSync());
    } else if (e is File) {
      e.copySync(z);
    }
  }
  // Das Programm ausführbar machen: Ein Paket, das ohne Rechte entpackt
  // wurde, verlöre sie sonst.
  _ausfuehrbar(exe);
  final skript = File(p.join(ziel, 'moocp-deinstallieren'))..writeAsStringSync(deinstallierenSkript());
  _ausfuehrbar(skript.path);

  sag('Lege Startmenü und Schreibtisch an …');
  final inhalt = desktopInhalt(exe: exe, deinstallieren: skript.path);
  final symbol = File(p.join(ziel, 'moocp.png'));
  if (symbol.existsSync()) {
    Directory(p.dirname(orte.symbolDatei)).createSync(recursive: true);
    symbol.copySync(orte.symbolDatei);
  }
  Directory(orte.menueOrdner).createSync(recursive: true);
  File(orte.menueDatei).writeAsStringSync(inhalt);
  _ausfuehrbar(orte.menueDatei);
  // Der Schreibtisch wie unter Windows; fehlt der Ordner (kein Schreibtisch
  // eingerichtet), bleibt es beim Menü.
  if (Directory(orte.desktopOrdner).existsSync()) {
    File(orte.desktopDatei).writeAsStringSync(inhalt);
    _ausfuehrbar(orte.desktopDatei);
  }
  _menueAktualisieren(orte);
  sag('Fertig.');
}

void _ausfuehrbar(String pfad) {
  try {
    Process.runSync('chmod', ['755', pfad]);
  } catch (_) {
    // Ohne chmod (kein Linux): nichts zu tun.
  }
}

/// Meldet das Menü bei der Sitzung an, soweit die Werkzeuge da sind; ohne sie
/// findet das Menü die Datei beim nächsten Anmelden. Ein Fehler ist nicht
/// schlimm.
void _menueAktualisieren(InstallerOrte orte) {
  for (final befehl in [
    ['update-desktop-database', orte.menueOrdner],
    ['gtk-update-icon-cache', '-f', '-t', p.join(p.dirname(p.dirname(p.dirname(orte.symbolDatei))))],
  ]) {
    try {
      Process.runSync(befehl.first, befehl.sublist(1));
    } catch (_) {
      // Werkzeug fehlt.
    }
  }
}

/// Die Ergebnisbits von `moocp --claude-entfernen`: 1 ein Eintrag „moodle"
/// steht noch, 2 Dateien der Skills sind noch da (lib/einrichtung.dart).
class EntfernenErgebnis {
  EntfernenErgebnis(this.einrichtungsCode);
  final int einrichtungsCode;
  bool get eintragBlieb => einrichtungsCode & 1 != 0;
  bool get skillsBlieben => einrichtungsCode & 2 != 0;

  /// Der Hinweis für die Lehrkraft, was sich nicht entfernen ließ; leer, wenn
  /// alles weg ist.
  String get hinweis {
    final z = <String>[];
    if (eintragBlieb) {
      z.add(
        '• Die Verbindung „moodle“ in einem KI-Werkzeug. Claude Code: im Terminal '
        '„claude mcp remove moodle --scope user“. Codex CLI: den Abschnitt [mcp_servers.moodle] '
        'in ~/.codex/config.toml löschen.',
      );
    }
    if (skillsBlieben) {
      z.add(
        '• Dateien der Skills: unter ~/.claude/skills und ~/.codex/skills die Ordner '
        'moodle, moodle-fragen und lernsituation löschen.',
      );
    }
    return z.isEmpty ? '' : 'Nicht alles ließ sich entfernen:\n${z.join('\n')}';
  }
}

/// Entfernt moocp: erst die Einrichtung in den KI-Werkzeugen (das macht die
/// installierte App selbst, sie weiß, wo die Einträge stehen), dann Programm,
/// Menü- und Schreibtischeinträge und die Daten der App (Einstellungen mit
/// Zugangsschlüssel, Protokoll, Sicherungen, Haken und Benutzername, Arbeitsordner).
/// Das gespeicherte Passwort im Schlüsselbund räumt [anmeldedatenLoeschen] ab
/// (die Oberfläche übergibt `Anmeldedaten.loeschen` je Profil); es braucht die
/// Profile aus den Einstellungen und läuft deshalb davor.
Future<EntfernenErgebnis> deinstallieren({
  required String ziel,
  required InstallerOrte orte,
  Future<void> Function()? anmeldedatenLoeschen,
  Meldung? meldung,
}) async {
  void sag(String t) => meldung?.call(t);
  final exe = p.join(ziel, programmName);
  if (!File(p.join(ziel, markeDatei)).existsSync()) {
    throw InstallerFehler('Im Ordner liegt keine Installation von moocp.');
  }
  if (programmLaeuft(exe)) {
    throw InstallerFehler('moocp läuft noch. Bitte die App schließen und es noch einmal versuchen.');
  }
  sag('Entferne die Einrichtung in den KI-Werkzeugen …');
  var code = 3; // unbekannt, was geblieben ist: beides melden
  try {
    final r = await Process.run(exe, ['--claude-entfernen'], environment: orte.umgebung);
    code = r.exitCode;
  } catch (_) {
    // code bleibt 3
  }
  sag('Entferne gespeicherte Anmeldedaten …');
  try {
    // Ein gesperrter Schlüsselbund fragt nach dem Entsperren (bis 90 s je
    // Zugriff); die Deinstallation wartet nicht länger als einen Augenblick.
    await anmeldedatenLoeschen?.call().timeout(const Duration(seconds: 20));
  } catch (_) {
    // Kein Schlüsselbund oder nichts gespeichert: nichts zu löschen.
  }
  sag('Entferne das Programm …');
  _entfernen(ziel);
  for (final f in [markeDatei]) {
    final d = File(p.join(ziel, f));
    if (d.existsSync()) d.deleteSync();
  }
  try {
    Directory(ziel).deleteSync(); // nur, wenn leer
  } catch (_) {
    // Fremde Dateien darin: bleiben.
  }
  for (final d in [orte.menueDatei, orte.desktopDatei, orte.symbolDatei]) {
    final f = File(d);
    if (f.existsSync()) f.deleteSync();
  }
  _menueAktualisieren(orte);
  sag('Entferne Einstellungen, Protokoll und Arbeitsordner …');
  for (final o in [orte.einstellungen, orte.prefsOrdner, orte.arbeitsordner]) {
    final d = Directory(o);
    if (d.existsSync() && !FileSystemEntity.isLinkSync(o)) d.deleteSync(recursive: true);
  }
  return EntfernenErgebnis(code);
}
