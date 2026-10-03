// Zeilenenden in der Arbeitskopie: Batch-Dateien CRLF, Shell-Skripte LF.
//
// Beides bricht, wenn es kippt: cmd liest eine Batch mit LF byteweise weiter
// und setzt mitten in einer Zeile auf (aus „echo" wird „cho"), bash bricht
// bei CRLF mit „$'\r': command not found" ab.
//
// Geprüft wird hier, weil git es nicht zeigt: .gitattributes normalisiert
// beide Arten beim Ein- und Auschecken, im Repository steht also immer die
// richtige Form -- und ein Werkzeug, das die Arbeitskopie umschreibt (etwa
// `sed -i`), hinterlässt in `git status` keine Spur. Der Fehler fällt sonst
// erst beim Ausführen auf.
//
// Für alles andere (Dart, Markdown, YAML) braucht es keine Prüfung: Dort
// ändert ein falsches Zeilenende nichts, und git macht beim Commit LF
// daraus.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Ordner ohne Quelltext des Projekts.
const _ausgenommen = {'build', '.git', '.dart_tool', '__pycache__', '.idea'};

List<File> _mitEndung(String endung) {
  final gefunden = <File>[];
  void durchgehen(Directory d) {
    for (final e in d.listSync(followLinks: false)) {
      if (e is Directory) {
        if (!_ausgenommen.contains(p.basename(e.path))) durchgehen(e);
      } else if (e is File && e.path.endsWith(endung)) {
        gefunden.add(e);
      }
    }
  }

  durchgehen(Directory.current);
  return gefunden;
}

void main() {
  test('Batch-Dateien: jede Zeile endet mit CRLF', () {
    final dateien = _mitEndung('.bat');
    expect(dateien, isNotEmpty, reason: 'create_installer.bat müsste zu finden sein');
    for (final datei in dateien) {
      final bytes = datei.readAsBytesSync();
      var zeilen = 0;
      var mitCr = 0;
      for (var i = 0; i < bytes.length; i++) {
        if (bytes[i] != 0x0a) continue;
        zeilen++;
        if (i > 0 && bytes[i - 1] == 0x0d) mitCr++;
      }
      expect(mitCr, zeilen,
          reason: '${p.basename(datei.path)}: ${zeilen - mitCr} von $zeilen Zeilen ohne CR. '
              'cmd liest die Datei dann falsch -- mit CRLF neu schreiben.');
    }
  });

  test('Shell-Skripte: kein CR', () {
    for (final datei in _mitEndung('.sh')) {
      expect(datei.readAsBytesSync().contains(0x0d), isFalse,
          reason: '${p.basename(datei.path)} enthält CR; bash bricht damit ab.');
    }
  });
}
