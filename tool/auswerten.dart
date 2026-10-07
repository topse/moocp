// Die Auswertung von aktivitaet_lesen auf einen schon gelesenen Ordner anwenden,
// ohne Moodle: dart run tool/auswerten.dart <ordner> <moodle-rechner>
//
// Zum Entwickeln der Auswertung -- die App muss dafür nicht laufen.

import 'dart:io';

import 'package:moocp/moodle/auswertung.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('Aufruf: dart run tool/auswerten.dart <ordner> <moodle-rechner>');
    exit(2);
  }
  final ordner = args[0];
  final dateien = <String, Dateiinfo>{};
  final dir = Directory(p.join(ordner, 'dateien'));
  if (dir.existsSync()) {
    for (final f in dir.listSync().whereType<File>()) {
      final name = p.basename(f.path);
      dateien[name] = dateiAuswerten(name, f.readAsBytesSync());
    }
  }
  final felder = [
    for (final f in Directory(ordner).listSync().whereType<File>())
      if (f.path.endsWith('.html'))
        feldAuswerten(p.basenameWithoutExtension(f.path), f.readAsStringSync(), host: args[1])
  ];
  stdout.write(uebersichtText(felder, dateien));
}
