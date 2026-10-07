// moocp-bruecke.exe, die Brücke für KI-Werkzeuge, die MCP nur über stdio
// sprechen (lib/mcp/bruecke.dart). Bei jedem Bau der App mit `dart compile
// exe` übersetzt und neben moocp.exe gelegt (windows/bruecke.cmake).
import 'dart:io';

import 'package:moocp/mcp/bruecke.dart';

Future<void> main() async => exit(await brueckeStarten());
