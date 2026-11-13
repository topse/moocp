import 'dart:io';

import 'package:path/path.dart' as p;

import 'plattform.dart';

/// macOS: Browser im Programmbündel in /Applications oder im Benutzerordner;
/// Richtlinien über die verwalteten Einstellungen; Prozesse über `ps` und
/// `kill`.
class MacBrowser implements PlattformBrowser {
  @override
  List<BrowserArt> get arten => BrowserArt.values;

  @override
  Future<String?> programm(BrowserArt art) async {
    final (app, programm) = switch (art) {
      BrowserArt.edge => ('Microsoft Edge', 'Microsoft Edge'),
      BrowserArt.chrome => ('Google Chrome', 'Google Chrome'),
      BrowserArt.chromium => ('Chromium', 'Chromium'),
    };
    final home = Platform.environment['HOME'] ?? '';
    for (final ordner in ['/Applications', p.join(home, 'Applications')]) {
      final pfad = p.join(ordner, '$app.app', 'Contents', 'MacOS', programm);
      if (File(pfad).existsSync()) return pfad;
    }
    return null;
  }

  /// Die Richtlinie kommt als verwaltete Einstellung der Domäne des Browsers
  /// (Profil oder MDM), in /Library/Managed Preferences. Fehlt sie, ist die
  /// Fernsteuerung erlaubt, wie unter Windows ohne Schlüssel.
  @override
  Future<bool> fernsteuerungVerboten(BrowserArt art) async {
    final domaene = switch (art) {
      BrowserArt.edge => 'com.microsoft.Edge',
      BrowserArt.chrome => 'com.google.Chrome',
      BrowserArt.chromium => 'org.chromium.Chromium',
    };
    final benutzer = Platform.environment['USER'];
    final orte = [
      p.join('/Library/Managed Preferences', domaene),
      if (benutzer != null && benutzer.isNotEmpty)
        p.join('/Library/Managed Preferences', benutzer, domaene),
    ];
    for (final ort in orte) {
      try {
        final r = await Process.run('defaults', [
          'read',
          ort,
          'RemoteDebuggingAllowed',
        ]);
        if (r.exitCode == 0 && '${r.stdout}'.trim() == '0') return true;
      } on ProcessException {
        // Ohne defaults gibt es keine Richtlinie zu lesen.
      }
    }
    return false;
  }

  /// Die Prozesse mit dem Profil im Aufruf bekommen ein `kill -9`
  /// ([unixProzesseBeenden]).
  @override
  Future<int> prozesseBeenden(Directory profil, String programm) =>
      unixProzesseBeenden(profil);
}
