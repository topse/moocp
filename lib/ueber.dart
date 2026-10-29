// Der Dialog „Über moocp": Version, Lizenz der App und die Lizenzen
// aller eingebundenen Pakete. MIT, BSD und Apache 2.0 verlangen, dass ihre
// Hinweise mit der fertigen App weitergegeben werden. Die Lizenzseite von
// Flutter zeigt sie alle; Flutter sammelt sie beim Bauen selbst ein (die
// Datei NOTICES in den Assets), auch die der Engine.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

const appName = 'moocp';

/// Die eigene Lizenz als Asset (pubspec.yaml). Flutter nimmt nur Dateien, die
/// genau LICENSE heißen, von selbst in die Lizenzseite auf.
const lizenzAsset = 'LICENSE.md';

/// Meldet die Lizenz der App bei der Lizenzseite an. Vor
/// `WidgetsFlutterBinding.ensureInitialized()` aufrufen: Die Lizenzseite
/// stellt das zuerst gemeldete Paket an den Anfang, und die Bindung meldet
/// beim Start die gesammelten Lizenzen der Pakete.
void lizenzAnmelden() {
  LicenseRegistry.addLicense(() async* {
    // Ohne das BOM, mit dem die Datei beginnt (es steht dort für den
    // Installer, siehe installer/moocp.nsi).
    final text = await rootBundle.loadString(lizenzAsset);
    yield LicenseEntryWithLineBreaks([appName], text.replaceFirst('\uFEFF', ''));
  });
}

/// Die Version, wie sie in pubspec.yaml steht („1.0.0+1"). Unter Windows liest
/// package_info_plus sie aus der exe, in die Flutter sie beim Bauen schreibt;
/// der Installer nimmt sie von dort (installer/moocp.nsi).
String versionText(PackageInfo info) => info.buildNumber.isEmpty ? info.version : '${info.version}+${info.buildNumber}';

/// Zeigt den Dialog; „Lizenzen anzeigen" darin öffnet die Lizenzseite.
Future<void> ueberZeigen(BuildContext context) async {
  String? version;
  try {
    version = versionText(await PackageInfo.fromPlatform());
  } catch (_) {
    // Ohne Versionsangabe öffnet der Dialog trotzdem.
  }
  if (!context.mounted) return;
  showAboutDialog(
    context: context,
    applicationName: appName,
    applicationVersion: version == null ? null : 'Version $version',
    applicationLegalese: '© 2026 Tobias Steinmann\nMIT-Lizenz',
  );
}
