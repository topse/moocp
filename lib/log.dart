// Logging der App mit dem Paket logging: Der Root-Logger schreibt per print
// auf die Konsole (bei flutter run im Terminal; die fertige App hat keine).
//
// Dieselbe Regel wie im Protokoll: Nachrichten enthalten nie Passwörter,
// Formularwerte oder Cookies. Fehler erscheinen nur so, wie
// fehlerBeschreibung sie fasst -- ein beliebiger Fehlertext kann Eingaben
// enthalten.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:mcp_dart/mcp_dart.dart' as mcp show LogLevel, setMcpLogHandler;

/// Beschreibt einen Fehler, ohne Inhalte preiszugeben: den Typ, bei
/// Dateifehlern Meldung, Pfad und Windows-Fehler (Pfade, kein
/// Dateiinhalt), dazu die obersten Aufrufstellen (Funktionen und Zeilen,
/// keine Werte). Den Text anderer Fehler gibt sie nicht aus.
String fehlerBeschreibung(Object e, [StackTrace? st]) {
  final b = StringBuffer('${e.runtimeType}');
  if (e is FileSystemException) {
    b.write(': ${e.message}, Pfad ${e.path ?? "-"}'
        '${e.osError == null ? '' : ', ${e.osError!.message.trim()} (${e.osError!.errorCode})'}');
  }
  if (st != null) {
    final stellen = st
        .toString()
        .split('\n')
        .map((z) => z.trim())
        .where((z) => z.isNotEmpty && !z.contains('<asynchronous suspension>'))
        .take(5);
    b.write(' | ${stellen.join(' | ')}');
  }
  return b.toString();
}

void loggingEinrichten({Level stufe = Level.INFO}) {
  Logger.root.level = stufe;
  Logger.root.onRecord.listen((r) {
    final fehler = r.error == null ? '' : ' (${fehlerBeschreibung(r.error!, r.stackTrace)})';
    // ignore: avoid_print
    print('${r.time.toIso8601String()} ${r.level.name.padRight(7)} ${r.loggerName}: '
        '${r.message}$fehler');
  });
}

/// Das MCP-Paket schreibt seine Meldungen sonst direkt nach stderr -- in der
/// fertigen App ohne Konsole scheitert das mit „Das Handle ist ungültig".
/// Umgeleitet in den Logger `mcp.<name>`, ausgegeben wie alles andere.
void mcpLogsUmleiten() {
  mcp.setMcpLogHandler((name, stufe, text) => Logger('mcp.$name').log(
      switch (stufe) {
        mcp.LogLevel.debug => Level.FINE,
        mcp.LogLevel.info => Level.INFO,
        mcp.LogLevel.warn => Level.WARNING,
        mcp.LogLevel.error => Level.SEVERE,
      },
      text));
}
