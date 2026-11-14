// Einstieg des Installers unter Linux (E24): `moocp --installieren` und
// `moocp --deinstallieren`, von main.dart vor allem anderen aufgerufen -- ohne
// Einzelstart-Sperre, Einstellungen, Protokoll und MCP-Server. Das Paket
// (`moocp_setup_<Version>.run`, tool/linux_installer.sh) entpackt die gebaute
// App in einen Temp-Ordner und startet sie von dort mit diesem Schalter.
//
//   --installieren [--quelle=<Ordner der gebauten App>] [--ziel=<Ordner>] [--still]
//   --deinstallieren [--ziel=<Ordner>] [--still]
//
// Mit --still gibt es kein Fenster und keine Ausgabe (E11): nur der Exit-Code
// (0 gut, 1 Fehler, 2 Aufruf falsch). Das ist der Weg für Tests und für
// Skripte. Eine grafische Sitzung braucht auch er: Flutters GTK-Läufer öffnet
// die Anzeige schon beim Start.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../anmeldedaten.dart';
import '../einstellungen.dart';
import '../profil.dart';
import '../ueber.dart';
import 'installer_logik.dart';
import 'installer_seiten.dart';

const _fenster = Size(700, 500);
const installierenSchalter = '--installieren';
const deinstallierenSchalter = '--deinstallieren';

String? _wert(List<String> a, String name) {
  for (final s in a) {
    if (s.startsWith('$name=')) return s.substring(name.length + 1);
  }
  return null;
}

/// Ob die Argumente den Installer verlangen.
bool installerVerlangt(List<String> a) => a.contains(installierenSchalter) || a.contains(deinstallierenSchalter);

/// Gespeicherte Anmeldedaten aller Profile aus den Einstellungen löschen,
/// bevor diese verschwinden. Liest die Datei nur (wie `_gespeicherteMcpNamen`
/// in main.dart): Die Deinstallation legt nichts neu an.
Future<void> alleAnmeldedatenLoeschen(InstallerOrte orte) async {
  final kennungen = <(String, String?)>{(Profil.standardKennung, null)};
  try {
    final j = jsonDecode(await File(p.join(orte.einstellungen, 'einstellungen.json')).readAsString()) as Map<String, dynamic>;
    final standard = Einstellungen(moodleAdresse: '', schluessel: '');
    for (final pr in Einstellungen.aus(j, standard).profile) {
      kennungen.add((pr.kennung, pr.adresse));
    }
  } catch (_) {
    // Keine Einstellungen: nur das Standardprofil.
  }
  for (final (k, a) in kennungen) {
    try {
      await Anmeldedaten.loeschen(kennung: k, adresse: a);
    } catch (_) {
      // Ein Profil ohne Eintrag oder ohne Schlüsselbund: weiter mit dem nächsten.
    }
  }
}

/// Führt den Installer aus. Gibt den Exit-Code zurück; im Fenstermodus kehrt
/// es nie zurück (die Seite beendet das Programm).
Future<int> linuxInstallerAusfuehren(List<String> a) async {
  final still = a.contains('--still');
  final inst = a.contains(installierenSchalter);
  if (inst && a.contains(deinstallierenSchalter)) return 2; // nicht beides
  late final InstallerOrte orte;
  try {
    orte = InstallerOrte(Platform.environment);
    orte.heim;
  } on InstallerFehler {
    return 2;
  }
  final ziel = _wert(a, '--ziel') ?? (inst ? orte.standardZiel : quelleDerApp());
  final quelle = _wert(a, '--quelle') ?? quelleDerApp();
  WidgetsFlutterBinding.ensureInitialized();
  var version = '';
  try {
    version = versionText(await PackageInfo.fromPlatform());
  } catch (_) {
    // Nur für die Marke; ohne Version geht es auch.
  }
  Future<void> loeschen() => alleAnmeldedatenLoeschen(orte);
  if (still) {
    try {
      if (inst) {
        installieren(quelle: quelle, ziel: ziel, orte: orte, version: version);
      } else {
        await deinstallieren(ziel: ziel, orte: orte, anmeldedatenLoeschen: loeschen);
      }
      return 0;
    } catch (_) {
      return 1;
    }
  }
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(size: _fenster, center: true, title: 'moocp Setup', titleBarStyle: TitleBarStyle.normal),
    () async {
      // Feste Größe wie bei einem Installer: Der GTK-Läufer startet mit
      // 1280 x 720, und setResizable allein ließe es dabei.
      await windowManager.setMinimumSize(_fenster);
      await windowManager.setMaximumSize(_fenster);
      await windowManager.setSize(_fenster);
      await windowManager.center();
      await windowManager.show();
      await windowManager.focus();
    },
  );
  runApp(
    InstallerApp(
      modus: inst ? InstallerModus.installieren : InstallerModus.deinstallieren,
      orte: orte,
      ziel: ziel,
      quelle: quelle,
      version: version,
      anmeldedatenLoeschen: loeschen,
      starten: (z) async {
        await Process.start(p.join(z, programmName), const [], mode: ProcessStartMode.detached);
      },
    ),
  );
  return Completer<int>().future; // die Seite beendet das Programm
}
