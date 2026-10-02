// Die Einstellungen eines abgelegten Formulars ausgeben, ohne Moodle:
//   dart run tool/formular.dart <ordner>/.stand/formular.html
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:moocp/moodle/formular.dart';

void main(List<String> args) {
  final form = html_parser.parse(File(args.single).readAsStringSync()).querySelector('form')!;
  for (final e in einstellungenLesen(form)) {
    stdout.writeln('${e.schluessel.padRight(40)} ${e.label} = ${e.wert}${e.verborgen ? ' (verborgen)' : ''}');
  }
}
