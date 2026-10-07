// Offline prüfbar: die Brücke für stdio-Clients (lib/mcp/bruecke.dart)
// gegen einen nachgebauten MCP-Server -- Sitzung und Kopfzeilen, Nachrichten
// nebeneinander, falscher Schlüssel, Neustart der App, SSE; initialize und
// tools/list aus der Werkzeugliste, ob die App läuft oder nicht; Start der
// App erst beim Werkzeugaufruf, und kein Aufruf, den der Client abgebrochen
// hat, während die Brücke auf die App wartete.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/mcp/bruecke.dart';

/// Ein MCP-Server, wie ihn die App über HTTP anbietet, so weit die Brücke ihn
/// braucht. Merkt sich jede Anfrage.
class Attrappe {
  late HttpServer _server;
  final anfragen = <(String methode, String? rpc, Map<String, String?> kopf)>[];
  final sitzungen = <String>{};
  var _naechste = 0;

  Uri get adresse => Uri.parse('http://127.0.0.1:${_server.port}/mcp');

  Future<void> starten({int port = 0}) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server.listen(_antworten);
  }

  Future<void> stoppen() => _server.close(force: true);

  Future<void> _antworten(HttpRequest req) async {
    final r = req.response;
    final kopf = {
      'sitzung': req.headers.value('mcp-session-id'),
      'version': req.headers.value('mcp-protocol-version'),
      'schluessel': req.headers.value(HttpHeaders.authorizationHeader),
    };
    if (req.method == 'DELETE') {
      anfragen.add(('DELETE', null, kopf));
      sitzungen.remove(kopf['sitzung']);
      r.statusCode = 200;
      return r.close();
    }
    final n = jsonDecode(await utf8.decodeStream(req)) as Map;
    anfragen.add(('POST', n['method'] as String?, kopf));
    if (kopf['schluessel'] != 'Bearer abc') {
      r.statusCode = 401;
      return r.close();
    }
    final id = n['id'];
    if (n['method'] == 'initialize') {
      final s = 's${_naechste++}';
      sitzungen.add(s);
      r.headers.set('mcp-session-id', s);
      return _json(r, {
        'jsonrpc': '2.0',
        'id': id,
        'result': {'protocolVersion': '2025-06-18'},
      });
    }
    if (!sitzungen.contains(kopf['sitzung'])) {
      r.statusCode = 404;
      return _json(r, {
        'jsonrpc': '2.0',
        'id': id,
        'error': {'code': -32000, 'message': 'Session not found'},
      });
    }
    if (id == null) {
      r.statusCode = 202;
      return r.close();
    }
    if (n['method'] == 'langsam') await Future<void>.delayed(const Duration(milliseconds: 300));
    if (n['method'] == 'sse') {
      r.headers.contentType = ContentType('text', 'event-stream');
      r.write('event: message\ndata: ${jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': 'per SSE'})}\n\n');
      return r.close();
    }
    // Mit Zeilenumbrüchen, wie ein Server sie schicken dürfte: Die Brücke
    // muss sie für stdio entfernen.
    return _json(r, {'jsonrpc': '2.0', 'id': id, 'result': n['method']}, eingerueckt: true);
  }

  Future<void> _json(HttpResponse r, Object daten, {bool eingerueckt = false}) {
    r.headers.contentType = ContentType.json;
    r.write(eingerueckt ? const JsonEncoder.withIndent('  ').convert(daten) : jsonEncode(daten));
    return r.close();
  }
}

String zeile(Object n) => '${jsonEncode(n)}\n';
Map anfrage(Object id, String methode, [Map<String, Object?>? params]) => {
  'jsonrpc': '2.0',
  'id': id,
  'method': methode,
  'params': ?params,
};
Map anmelden(Object id, {String version = '2025-06-18'}) => anfrage(id, 'initialize', {
  'protocolVersion': version,
  'capabilities': <String, Object?>{},
  'clientInfo': {'name': 'test', 'version': '1'},
});
const initialisiert = {'jsonrpc': '2.0', 'method': 'notifications/initialized'};

/// Eine Werkzeugliste, wie `moocp.exe --werkzeugliste` sie liefert.
Werkzeugliste werkzeugliste([List<Map<String, Object?>>? tools]) => Werkzeugliste(
  versionen: ['2025-11-25', '2025-06-18', '2025-03-26'],
  initialize: {
    'protocolVersion': '2025-11-25',
    'capabilities': {'tools': <String, Object?>{}},
    'serverInfo': {'name': 'moocp', 'version': '0.3.0'},
  },
  tools: {
    'tools':
        tools ??
        [
          {'name': 'status'},
        ],
  },
);

void main() {
  late Attrappe app;
  setUp(() async {
    app = Attrappe();
    await app.starten();
  });
  tearDown(() => app.stoppen());

  /// Lässt die Brücke über [eingaben] laufen; wartet zwischen zwei Eingaben
  /// kurz, damit ihre Reihenfolge feststeht. Eine Funktion unter den Eingaben
  /// wird an ihrer Stelle ausgeführt. Liefert, was der Client bekommt.
  Future<List<Map>> laufen(
    List<Object> eingaben, {
    String? schluessel = 'abc',
    Uri? adresse,
    Future<Werkzeugliste?> Function()? listeHolen,
    Future<bool> Function()? appStarten,
    Duration aufAppWarten = const Duration(seconds: 5),
  }) async {
    final aus = <Map>[];
    final ein = StreamController<List<int>>();
    final b = Bruecke(
      adresse: adresse ?? app.adresse,
      schluessel: schluessel,
      listeHolen: listeHolen ?? () async => werkzeugliste(),
      appStarten: appStarten ?? () async => fail('die App darf hier nicht starten'),
      aufAppWarten: aufAppWarten,
      ausgabe: (z) {
        expect(z, isNot(contains('\n')), reason: 'über stdio eine Nachricht je Zeile');
        aus.add(jsonDecode(z) as Map);
      },
    );
    final fertig = b.laufen(ein.stream);
    for (final e in eingaben) {
      if (e is void Function()) {
        e();
      } else {
        ein.add(utf8.encode(e is String ? e : zeile(e)));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
    }
    await ein.close();
    await fertig;
    return aus;
  }

  group('App läuft', () {
    test(
      'initialize und tools/list aus der Liste, der Werkzeugaufruf mit Sitzung und Version, am Ende DELETE',
      () async {
        final aus = await laufen([anmelden(1), initialisiert, anfrage(2, 'tools/list'), anfrage(3, 'tools/call')]);
        expect(aus.map((n) => n['id']), [1, 2, 3]);
        expect(aus[1]['result'], werkzeugliste().tools);
        expect(aus[2]['result'], 'tools/call');
        expect(app.anfragen.map((a) => a.$2), [
          'initialize',
          'notifications/initialized',
          'tools/call',
          null,
        ], reason: 'die App nur für den Werkzeugaufruf, angemeldet von der Brücke');
        final aufruf = app.anfragen.firstWhere((a) => a.$2 == 'tools/call');
        expect(aufruf.$3['sitzung'], 's0');
        expect(aufruf.$3['version'], '2025-06-18');
        expect(app.anfragen.last.$1, 'DELETE');
        expect(app.anfragen.last.$3['sitzung'], 's0');
      },
    );

    test('Nachrichten laufen nebeneinander: eine lange hält keine kurze auf', () async {
      final aus = await laufen([anmelden(1), anfrage(2, 'langsam'), anfrage(3, 'schnell')]);
      expect(aus.map((n) => n['id']), [1, 3, 2]);
    });

    test('ping beantwortet die Brücke selbst', () async {
      final aus = await laufen([anmelden(1), anfrage(2, 'ping')]);
      expect(aus.last, {'jsonrpc': '2.0', 'id': 2, 'result': {}});
      expect(app.anfragen.where((a) => a.$2 == 'ping'), isEmpty);
    });

    test('falscher Schlüssel: das sagt das Ergebnis des Werkzeugs', () async {
      final aus = await laufen([anmelden(1), anfrage(7, 'tools/call')], schluessel: 'falsch');
      expect(aus.last['id'], 7);
      expect(aus.last['result']['isError'], isTrue);
      expect(aus.last['result']['content'].single['text'], contains('lehnt den Schlüssel ab'));
    });

    test('nicht eingerichtet: Fehler, ohne die App anzufragen', () async {
      final aus = await laufen([anmelden(1)], schluessel: null);
      expect(aus.single['error']['message'], contains('nicht eingerichtet'));
      expect(app.anfragen, isEmpty);
    });

    test('App neu gestartet: neu anmelden und wiederholen, der Client merkt nichts', () async {
      final aus = await laufen([
        anmelden(1),
        initialisiert,
        anfrage(2, 'tools/call'),
        // Neustart: Die App kennt keine Sitzung mehr.
        () => app.sitzungen.clear(),
        anfrage(3, 'tools/call'),
      ]);
      expect(aus.map((n) => n['id']), [1, 2, 3]);
      expect(aus.last['result'], 'tools/call');
      expect(app.anfragen.where((a) => a.$2 == 'initialize'), hasLength(2));
      final dritte = app.anfragen.lastWhere((a) => a.$2 == 'tools/call');
      expect(dritte.$3['sitzung'], 's1');
    });

    test('Antwort als SSE wird weitergegeben', () async {
      final aus = await laufen([anmelden(1), anfrage(2, 'sse')]);
      expect(aus.last, {'jsonrpc': '2.0', 'id': 2, 'result': 'per SSE'});
    });

    test('kaputte Zeile: Parse-Fehler ohne id', () async {
      final aus = await laufen(['{kein json\n']);
      expect(aus.single['id'], isNull);
      expect(aus.single['error']['code'], -32700);
    });
  });

  group('App läuft nicht', () {
    late Uri aus;
    setUp(() async {
      aus = app.adresse;
      await app.stoppen();
    });

    test('initialize, tools/list und ping kommen von der Brücke, ohne die App zu starten', () async {
      var geholt = 0;
      final r = await laufen(
        [anmelden(1), initialisiert, anfrage(2, 'ping'), anfrage(3, 'tools/list')],
        adresse: aus,
        listeHolen: () async {
          geholt++;
          return werkzeugliste();
        },
      );
      // ping wartet auf nichts, auch nicht auf initialize.
      expect(r.map((n) => n['id']).where((id) => id != 2), [1, 3]);
      expect(r.firstWhere((n) => n['id'] == 2)['result'], {});
      expect(r.firstWhere((n) => n['id'] == 1)['result'], {
        'protocolVersion': '2025-06-18',
        'capabilities': {'tools': {}},
        'serverInfo': {'name': 'moocp', 'version': '0.3.0'},
      }, reason: 'die Version, die der Client verlangt, wenn die App sie kann');
      expect(r.firstWhere((n) => n['id'] == 3)['result'], werkzeugliste().tools);
      expect(geholt, 2, reason: 'je Anfrage frisch von der exe, durchgereicht');
    });

    test('eine Version, die die App nicht kann: ihre erste', () async {
      final r = await laufen([anmelden(1, version: '2099-01-01')], adresse: aus);
      expect(r.single['result']['protocolVersion'], '2025-11-25');
    });

    test('ohne Werkzeugliste (moocp.exe fehlt): Fehler statt Schweigen', () async {
      final r = await laufen([anmelden(1)], adresse: aus, listeHolen: () async => null);
      expect(r.single['error']['message'], contains('gibt seine Werkzeuge nicht heraus'));
    });

    test('Werkzeugaufruf: startet die App, wartet auf sie und reicht weiter', () async {
      var gestartet = 0;
      final r = await laufen(
        [anmelden(1), initialisiert, anfrage(2, 'tools/list'), anfrage(3, 'tools/call')],
        adresse: aus,
        appStarten: () async {
          gestartet++;
          Timer(const Duration(milliseconds: 300), () => app.starten(port: aus.port));
          return true;
        },
      );
      expect(gestartet, 1);
      expect(r.last, {'jsonrpc': '2.0', 'id': 3, 'result': 'tools/call'});
      expect(app.anfragen.map((a) => a.$2), containsAllInOrder(['initialize', 'notifications/initialized']));
    });

    test('Werkzeugaufruf, den der Client abbricht, während die Brücke auf die App wartet: geht nicht hinaus',
        () async {
      final r = await laufen(
        [
          anmelden(1),
          anfrage(2, 'tools/call'),
          {
            'jsonrpc': '2.0',
            'method': 'notifications/cancelled',
            'params': {'requestId': 2, 'reason': 'Zeitlimit'},
          },
        ],
        adresse: aus,
        appStarten: () async {
          Timer(const Duration(milliseconds: 300), () => app.starten(port: aus.port));
          return true;
        },
      );
      expect(r.map((n) => n['id']), [1], reason: 'keine Antwort auf den abgebrochenen Aufruf');
      expect(app.anfragen.map((a) => a.$2), contains('initialize'), reason: 'die App ist gestartet und verbunden');
      expect(app.anfragen.map((a) => a.$2), isNot(contains('tools/call')), reason: 'der Aufruf ging nicht hinaus');
    });

    test('Werkzeugaufruf, die App wird nicht bereit: der Grund als Ergebnis des Werkzeugs', () async {
      final r = await laufen(
        [anmelden(1), anfrage(2, 'tools/call')],
        adresse: aus,
        appStarten: () async => true,
        aufAppWarten: const Duration(milliseconds: 400),
      );
      expect(r.last['id'], 2);
      expect(r.last['result']['isError'], isTrue);
      expect(r.last['result']['content'].single['text'], contains('noch nicht bereit'));
    });

    test('Werkzeugaufruf, moocp lässt sich nicht starten: das sagt das Ergebnis', () async {
      final r = await laufen([anmelden(1), anfrage(2, 'tools/call')], adresse: aus, appStarten: () async => false);
      expect(r.last['result']['isError'], isTrue);
      expect(r.last['result']['content'].single['text'], contains('ließ sich nicht starten'));
    });

    test('andere Anfragen starten die App nicht', () async {
      final r = await laufen([anmelden(1), anfrage(2, 'resources/list')], adresse: aus);
      expect(r.last['error']['message'], contains('läuft nicht'));
    });

    test('die Werkzeugliste aus JSON, wie main.dart sie schreibt', () {
      final l = werkzeugliste();
      expect(Werkzeugliste.ausJson(jsonDecode(jsonEncode(l.toJson())))!.toJson(), l.toJson());
      expect(Werkzeugliste.ausJson({'versionen': []}), isNull);
      expect(Werkzeugliste.ausJson('kaputt'), isNull);
    });
  });
}
