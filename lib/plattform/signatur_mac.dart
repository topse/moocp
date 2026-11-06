// Signaturprüfung einer Programmdatei, nur macOS: Ist die Signatur gültig, und
// stammt sie vom Entwicklerkonto von Anthropic? Damit entscheidet die App, ob
// sie das Claude Code aus Claude Desktop startet und ihm den Zugangsschlüssel
// gibt (lib/einrichtung.dart, claudeFinden) -- das Gegenstück zu
// signatur_windows.dart.
//
// Über das Programm `codesign`, das zu macOS gehört. Es fragt für diese Prüfung
// niemanden im Netz an (E19). Synchron und ohne Flutter.

import 'dart:io';

/// Team-Kennung im Zertifikat der Programme von Anthropic. Gemessen an
/// `claude.app/Contents/MacOS/claude` aus Claude Desktop 2.1.317:
/// `Authority=Developer ID Application: Anthropic PBC (Q6L2SF6YDW)`.
const anthropicTeamKennung = 'Q6L2SF6YDW';

/// Gültige Signatur (`--verify --strict`) und Team-Kennung von Anthropic.
/// Jeder Fehler, auch ein fehlendes `codesign`, heißt: nicht geprüft.
bool vonAnthropicMac(String exe) {
  try {
    final gueltig = Process.runSync('codesign', ['--verify', '--strict', exe]);
    if (gueltig.exitCode != 0) return false;
    final info = Process.runSync('codesign', ['-dv', '--verbose=2', exe]);
    // codesign schreibt die Angaben auf stderr.
    return info.exitCode == 0 && '${info.stderr}'.contains('TeamIdentifier=$anthropicTeamKennung');
  } on ProcessException {
    return false;
  }
}
