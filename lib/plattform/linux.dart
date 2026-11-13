import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'plattform.dart';

/// Linux: Browser im Suchpfad und in den üblichen Programmordnern;
/// Richtlinien als JSON-Dateien unter /etc; Prozesse über `ps` und `kill`.
///
/// Gebaut für Debian und Ubuntu. Ein Chromium aus Snap oder Flatpak ist
/// absichtlich nicht dabei: Er läuft in einer Sandbox, die das Profil im
/// Temp-Ordner der App nicht lesen darf und die Fernsteuerung verweigert.
class LinuxBrowser implements PlattformBrowser {
  /// [pfad] und [richtlinien] sind für Tests austauschbar.
  LinuxBrowser({List<String>? pfad, this._richtlinien}) : _pfad = pfad ?? _suchpfad();

  final List<String> _pfad;
  final List<String>? _richtlinien;

  static List<String> _suchpfad() => [
    for (final d in (Platform.environment['PATH'] ?? '').split(':'))
      if (d.trim().isNotEmpty) d.trim(),
    '/usr/local/bin',
    '/usr/bin',
    '/opt/google/chrome',
    '/opt/microsoft/msedge',
  ];

  /// Die Namen, unter denen die Pakete der Distributionen das Programm
  /// ablegen; `microsoft-edge` und `google-chrome` sind Verweise auf die
  /// `-stable`-Namen.
  static const _namen = {
    BrowserArt.edge: ['microsoft-edge', 'microsoft-edge-stable', 'msedge'],
    BrowserArt.chrome: ['google-chrome', 'google-chrome-stable', 'chrome'],
    BrowserArt.chromium: ['chromium', 'chromium-browser'],
  };

  @override
  List<BrowserArt> get arten => BrowserArt.values;

  @override
  Future<String?> programm(BrowserArt art) async {
    for (final d in _pfad) {
      for (final n in _namen[art]!) {
        final pfad = p.join(d, n);
        if (File(pfad).existsSync()) return pfad;
      }
    }
    return null;
  }

  /// Die Richtlinien liegen als JSON im Ordner `managed` des Browsers; jede
  /// Datei darin gilt. `RemoteDebuggingAllowed: false` verbietet die
  /// Fernsteuerung. Fehlt der Ordner, ist sie erlaubt, wie unter Windows ohne
  /// Schlüssel.
  @override
  Future<bool> fernsteuerungVerboten(BrowserArt art) async {
    final ordner =
        _richtlinien ??
        switch (art) {
          BrowserArt.edge => const ['/etc/opt/edge/policies/managed'],
          BrowserArt.chrome => const ['/etc/opt/chrome/policies/managed'],
          BrowserArt.chromium => const ['/etc/chromium/policies/managed'],
        };
    for (final o in ordner) {
      final d = Directory(o);
      if (!d.existsSync()) continue;
      try {
        for (final datei in d.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.json'),
        )) {
          final inhalt = jsonDecode(await datei.readAsString());
          if (inhalt is Map && inhalt['RemoteDebuggingAllowed'] == false) {
            return true;
          }
        }
      } on FileSystemException {
        // Nicht lesbar: dann gibt es für uns keine Richtlinie zu sehen.
      } on FormatException {
        // Kein gültiges JSON: Der Browser liest sie auch nicht.
      }
    }
    return false;
  }

  @override
  Future<int> prozesseBeenden(Directory profil, String programm) =>
      unixProzesseBeenden(profil);
}
