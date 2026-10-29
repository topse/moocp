// Wo die Einstellungen liegen, ohne Flutter: Das braucht außer der App auch
// die Brücke (mcp/bruecke.dart), ein eigenes Programm ohne Flutter.
// einstellungen.dart selbst hängt über freigabe.dart an Flutter.
import 'dart:io';

import 'package:path/path.dart' as p;

const standardPort = 47811;

/// `%APPDATA%\moocp`: Einstellungen und Protokoll.
String get einstellungenOrdner => p.join(Platform.environment['APPDATA'] ?? Directory.systemTemp.path, 'moocp');

File get einstellungenDatei => File(p.join(einstellungenOrdner, 'einstellungen.json'));
