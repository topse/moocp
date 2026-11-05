// Jeder MCP-Server prüft den Zugangsschlüssel seines Profils (E6): Wer den
// Schlüssel einer Instanz kennt, kommt nicht an die Werkzeuge einer anderen.
// Das Standardprofil behält den globalen Schlüssel, damit die Einträge in den
// KI-Werkzeugen und die Brücke für LM Studio weiter gelten.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/einstellungen.dart';
import 'package:moocp/freigabe.dart';
import 'package:moocp/mcp/mcp_dienst.dart';
import 'package:moocp/moodle/moodle_zugang.dart';
import 'package:moocp/profil.dart';
import 'package:moocp/protokoll.dart';

Future<int> _freierPort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

/// Der HTTP-Status auf ein initialize, mit dem Kopf `Authorization: [kopf]`
/// (null: ohne den Kopf).
Future<int> _status(int port, String? kopf) async {
  final http = HttpClient();
  try {
    final r = await http.postUrl(Uri.parse('http://127.0.0.1:$port/mcp'));
    r.headers
      ..set('Accept', 'application/json, text/event-stream')
      ..contentType = ContentType.json;
    if (kopf != null) r.headers.set('Authorization', kopf);
    r.write(jsonEncode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': {
        'protocolVersion': '2025-06-18',
        'capabilities': <String, Object?>{},
        'clientInfo': {'name': 'schluessel-test', 'version': '1'},
      },
    }));
    final antwort = await r.close();
    await antwort.drain<void>();
    return antwort.statusCode;
  } finally {
    http.close(force: true);
  }
}

void main() {
  late Directory ordner;
  final dienste = <McpDienst>[];

  setUp(() => ordner = Directory.systemTemp.createTempSync('moocp_schluessel_'));

  tearDown(() async {
    for (final d in dienste) {
      await d.stoppen();
    }
    dienste.clear();
    ordner.deleteSync(recursive: true);
  });

  Future<McpDienst> starten(Einstellungen e, Profil profil) async {
    final protokoll = Protokoll();
    final d = McpDienst(
      e,
      MoodleZugang(protokoll),
      protokoll,
      Freigaben(protokoll),
      ordner.path,
      profil: profil,
      sicherungsordner: ordner.path,
    );
    await d.starten();
    dienste.add(d);
    return d;
  }

  Profil standard(int port) => Profil(
        kennung: Profil.standardKennung,
        name: 'Moodle',
        adresse: 'https://moodle.schule.example',
        port: port,
        mcpName: 'moodle',
      );

  Profil zweites(int port, {String schluessel = 'schluessel-zwei'}) => Profil(
        kennung: 'k2',
        name: 'Moodle Test',
        adresse: 'https://test.schule.example',
        port: port,
        mcpName: 'moodle-test',
        schluessel: schluessel,
      );

  test('der Server des Standardprofils nimmt den globalen Schlüssel an, den eines anderen Profils nicht', () async {
    final p1 = standard(await _freierPort());
    final p2 = zweites(await _freierPort());
    final e = Einstellungen(schluessel: 'schluessel-global', profile: [p1, p2]);
    await starten(e, e.profile[0]);

    expect(await _status(p1.port, 'Bearer schluessel-global'), HttpStatus.ok);
    expect(await _status(p1.port, 'Bearer schluessel-zwei'), HttpStatus.forbidden);
    expect(await _status(p1.port, null), HttpStatus.forbidden);
  });

  test('der Server eines weiteren Profils nimmt nur seinen eigenen Schlüssel an, nicht den globalen und nicht den des Standardprofils', () async {
    final p1 = standard(await _freierPort());
    final p2 = zweites(await _freierPort());
    final e = Einstellungen(schluessel: 'schluessel-global', profile: [p1, p2]);
    await starten(e, e.profile[1]);

    expect(await _status(p2.port, 'Bearer schluessel-zwei'), HttpStatus.ok);
    expect(await _status(p2.port, 'Bearer schluessel-global'), HttpStatus.forbidden,
        reason: 'der Schlüssel des Standardprofils öffnet nicht die andere Instanz');
    expect(await _status(p2.port, null), HttpStatus.forbidden);
  });

  test('zwei Server nebeneinander: jeder lehnt den Schlüssel des anderen ab', () async {
    final p1 = standard(await _freierPort());
    final p2 = zweites(await _freierPort());
    final e = Einstellungen(schluessel: 'schluessel-global', profile: [p1, p2]);
    await starten(e, e.profile[0]);
    await starten(e, e.profile[1]);

    expect(await _status(p1.port, 'Bearer schluessel-global'), HttpStatus.ok);
    expect(await _status(p2.port, 'Bearer schluessel-zwei'), HttpStatus.ok);
    expect(await _status(p1.port, 'Bearer schluessel-zwei'), HttpStatus.forbidden);
    expect(await _status(p2.port, 'Bearer schluessel-global'), HttpStatus.forbidden);
  });

  test('ein Profil ohne Schlüssel lässt niemanden herein, auch nicht mit leerem Kopf', () async {
    final p1 = standard(await _freierPort());
    // Direkt am Dienst, ohne Einstellungen.aus: Dort bekäme es einen Schlüssel.
    final ohne = zweites(await _freierPort(), schluessel: '');
    final e = Einstellungen(schluessel: 'schluessel-global', profile: [p1]);
    await starten(e, ohne);

    expect(await _status(ohne.port, 'Bearer '), HttpStatus.forbidden);
    expect(await _status(ohne.port, 'Bearer'), HttpStatus.forbidden);
    expect(await _status(ohne.port, 'Bearer schluessel-global'), HttpStatus.forbidden);
    expect(await _status(ohne.port, null), HttpStatus.forbidden);
  });
}
