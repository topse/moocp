// Werkzeug bildschirmfoto: wie eine Seite im Browser aussieht -- gesetzte
// Formeln, der Druck, eine Frage in der Vorschau. Damit prüft Claude, was es
// geschrieben hat, statt die Lehrkraft nachsehen zu lassen.
//
// Gerendert wird mit einem Browser ohne Fenster, gesteuert über das
// DevTools-Protokoll (CDP) -- kein Paket: Edge, sonst Chrome (im EWR lässt
// sich Edge deinstallieren; beide sprechen dasselbe Protokoll). Das Profil
// ist ein Wegwerf-Ordner im Arbeitsordner; nach jedem Bild wird der Browser
// beendet und der Ordner gelöscht (sonst beim nächsten Leeren des
// Arbeitsordners). Verbietet eine Richtlinie die Fernsteuerung
// (RemoteDebuggingAllowed), gibt es keine Bildschirmfotos; die App umgeht
// das nicht.
//
// Schutz (A1) im Code, die Freigabe kommt obendrauf:
//   - Jede Anfrage des Browsers hält die App an (Fetch-Domäne) und
//     entscheidet nach browserliste.dart. Anfragen an Moodle stellt sie
//     selbst (MoodleZugang.fuerBrowser, mit Protokoll); der Browser bekommt
//     nur die Antwort und nie das Sitzungscookie. Als Seite lädt er nur die
//     eine, die aufgenommen wird.
//   - Nur Ansichten, die Inhalte zeigen und keine Personen, und davon nur
//     der Inhalt selbst ([_inhalt]) -- was auch die Textwerkzeuge liefern,
//     ohne Kopf, Navigation, Blöcke, Aktivitätskopf und, in der
//     Fragenvorschau, ohne Kommentare. Ein Wiki nur, wenn es die
//     Textwerkzeuge auch lesen (wiki.dart).
//   - Der Grund steht im Dialog; die Lehrkraft sieht jedes Bild und gibt es
//     frei, erst dann geht es an Claude. Ohne Freigabe wird es verworfen.
//
// Nebenwirkungen wie beim Ansehen im Browser: Moodle protokolliert den Aufruf
// unter dem eigenen Konto und setzt eventuell den Abschluss „angesehen"; die
// Fragenvorschau legt einen eigenen Vorschauversuch an.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../freigabe.dart';
import '../protokoll.dart';
import 'browserliste.dart';
import 'formular_schreiben.dart';
import 'kurs.dart';
import 'moodle_zugang.dart';
import 'sperrliste.dart';
import 'wiki.dart';

/// Breite des Fensters in CSS-Pixeln: Moodle zeigt dabei das Layout eines
/// Bildschirms, nicht das eines Telefons.
const int _breite = 1280;

/// Höchste Höhe eines Bilds. Längere Inhalte werden geteilt: Claude
/// verkleinert hohe Bilder, und Schrift wird dann unlesbar.
const int _teilhoehe = 1400;
const int _hoechstensTeile = 12;

class _Cdp {
  _Cdp(this._ws) {
    _ws.listen(
      _empfangen,
      onDone: () {
        _zu = true;
        for (final c in _offen.values) {
          if (!c.isCompleted) c.completeError(MoodleFehler('Browser: Verbindung beendet.'));
        }
        _offen.clear();
      },
    );
  }

  final WebSocket _ws;
  var _id = 0;
  final _offen = <int, Completer<Map<String, dynamic>>>{};
  final _ereignisse = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get ereignisse => _ereignisse.stream;

  /// Geschlossen: Was danach noch gesendet wird, scheitert als MoodleFehler
  /// statt als StateError des WebSockets -- Anfragen des Browsers, die beim
  /// Beenden noch unterwegs sind, kommen so in die gewöhnliche Fehlerbehandlung.
  var _zu = false;

  Future<Map<String, dynamic>> senden(String methode, [Map<String, Object?> params = const {}]) {
    if (_zu) return Future.error(MoodleFehler('Browser: Verbindung beendet.'));
    final id = ++_id;
    final c = Completer<Map<String, dynamic>>();
    _offen[id] = c;
    try {
      _ws.add(jsonEncode({'id': id, 'method': methode, 'params': params}));
    } on StateError {
      _offen.remove(id);
      _zu = true;
      return Future.error(MoodleFehler('Browser: Verbindung beendet.'));
    }
    return c.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () => throw MoodleFehler('Browser antwortet nicht ($methode).'),
    );
  }

  void _empfangen(dynamic d) {
    final m = jsonDecode(d as String) as Map<String, dynamic>;
    final id = m['id'];
    if (id is int) {
      final c = _offen.remove(id);
      if (c == null || c.isCompleted) return;
      final fehler = m['error'];
      if (fehler is Map) {
        c.completeError(MoodleFehler('Browser: ${fehler['message']}'));
      } else {
        c.complete((m['result'] as Map?)?.cast<String, dynamic>() ?? const {});
      }
    } else if (m['method'] is String && !_ereignisse.isClosed) {
      _ereignisse.add(m);
    }
  }

  Future<void> schliessen() async {
    _zu = true;
    await _ws.close();
    await _ereignisse.close();
  }
}

Future<String> _reg(List<String> argumente) async {
  try {
    return '${(await Process.run('reg', ['query', ...argumente])).stdout}';
  } on ProcessException {
    return '';
  }
}

/// Wo ein Browser liegt: zuerst laut Registrierung (App Paths), sonst an den
/// üblichen Orten.
Future<String?> _finden(String exe, List<String> ordner) async {
  for (final wurzel in ['HKLM', 'HKCU']) {
    final m = RegExp(r'REG_SZ\s+(.+)')
        .firstMatch(await _reg(['$wurzel\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\$exe', '/ve']));
    final pfad = m?.group(1)?.trim();
    if (pfad != null && File(pfad).existsSync()) return pfad;
  }
  for (final v in ['ProgramFiles(x86)', 'ProgramFiles', 'LOCALAPPDATA']) {
    final b = Platform.environment[v];
    if (b == null) continue;
    final pfad = p.joinAll([b, ...ordner, exe]);
    if (File(pfad).existsSync()) return pfad;
  }
  return null;
}

/// Ob die Verwaltung des Rechners die Fernsteuerung per Richtlinie
/// abgeschaltet hat (RemoteDebuggingAllowed = 0). Der Browser öffnet dann
/// keinen DevTools-Port, und das Warten darauf liefe bis zur Frist.
Future<bool> _fernsteuerungVerboten(String richtlinie) async {
  for (final wurzel in ['HKLM', 'HKCU']) {
    final t = await _reg(['$wurzel\\$richtlinie', '/v', 'RemoteDebuggingAllowed']);
    if (RegExp(r'RemoteDebuggingAllowed\s+REG_DWORD\s+0x0+\s*$', multiLine: true).hasMatch(t)) return true;
  }
  return false;
}

/// Name und Pfad des Browsers: Edge, sonst Chrome.
Future<(String, String)> _browser() async {
  final verboten = <String>[];
  for (final (name, exe, ordner, richtlinie) in [
    ('Microsoft Edge', 'msedge.exe', ['Microsoft', 'Edge', 'Application'], r'SOFTWARE\Policies\Microsoft\Edge'),
    ('Google Chrome', 'chrome.exe', ['Google', 'Chrome', 'Application'], r'SOFTWARE\Policies\Google\Chrome'),
  ]) {
    final pfad = await _finden(exe, ordner);
    if (pfad == null) continue;
    if (await _fernsteuerungVerboten(richtlinie)) {
      verboten.add(name);
      continue;
    }
    return (name, pfad);
  }
  throw MoodleFehler(verboten.isNotEmpty
      ? 'Auf diesem Rechner ist die Fernsteuerung von ${verboten.join(' und ')} per Richtlinie abgeschaltet '
          '(RemoteDebuggingAllowed) -- ohne sie gibt es keine Bildschirmfotos. Das entscheidet die Verwaltung des '
          'Rechners; die App umgeht es nicht.'
      : 'Weder Microsoft Edge noch Google Chrome ist zu finden -- ohne einen von beiden gibt es keine '
          'Bildschirmfotos.');
}

/// Der Grund, den die Lehrkraft im Dialog liest: ein Satz, was das Bild
/// prüfen soll. Er ist eine Angabe für ihre Entscheidung, keine Sicherung.
String grundPruefen(String? grund) {
  final g = (grund ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (g.length < 10) {
    throw MoodleFehler('Ohne Grund kein Bildschirmfoto: in einem Satz angeben, was das Bild prüfen soll (grund).');
  }
  if (g.length > 200) throw MoodleFehler('Der Grund hat ${g.length} Zeichen, höchstens 200 -- ein Satz genügt.');
  return g;
}

/// Wartet, bis MathJax fertig ist, und zählt die Formeln: gesetzt und als
/// Text stehen geblieben (ein Formelanfang, den MathJax nicht übernommen
/// hat; `code` zählt nicht). Der Filter legt EINE Hülle
/// (`.filter_mathjaxloader_equation`) um jedes Textfeld mit Formeln, nicht
/// um jede Formel; gezählt wird deshalb darin. Gesetzt: MathJax 3 macht aus
/// jeder Formel ein `mjx-container`, MathJax 2 hinterlässt je Formel ein
/// `script type="math/tex"`. Höchstens 30 s.
const String _warteAufFormeln = r'''
(async () => {
  const warte = ms => new Promise(r => setTimeout(r, ms));
  const zaehlen = () => {
    const huellen = [...document.querySelectorAll('.filter_mathjaxloader_equation')];
    let gesetzt = 0, text = 0;
    for (const h of huellen) {
      gesetzt += h.querySelectorAll('mjx-container, script[type^="math/tex"]').length;
      const w = document.createTreeWalker(h, NodeFilter.SHOW_TEXT, {acceptNode: n =>
        n.parentElement.closest('code, pre, script, mjx-container, .MathJax_Preview, .MathJax, .MathJax_Display')
          ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT});
      while (w.nextNode()) {
        const d = w.currentNode.data;
        text += (d.match(/\\\(|\\\[/g) || []).length + Math.floor((d.match(/\$\$/g) || []).length / 2);
      }
    }
    return {huellen: huellen.length, gesetzt, text};
  };
  let z = zaehlen(), ruhig = 0;
  for (let i = 0; i < 300 && z.huellen > 0; i++) {
    await warte(100);
    const n = zaehlen();
    ruhig = (window.MathJax && n.gesetzt === z.gesetzt && n.text === z.text) ? ruhig + 1 : 0;
    z = n;
    // Fertig: 1,5 s nichts Neues und nichts mehr als Text -- oder 5 s nichts
    // Neues, dann bleibt der Rest Text (der Befund, um den es geht).
    if (ruhig >= 15 && (z.text === 0 || ruhig >= 50)) break;
  }
  await document.fonts.ready;
  return JSON.stringify(z);
})()
''';

/// Druck vortäuschen: Das Druckmedium ist vorher emuliert; hier kommt das
/// Ereignis dazu, an dem eine Druckaufbereitung hängt (references/drucken.md
/// im Skill moodle: Sie baut beim Drucken #ab-print-root mit ihren Seiten).
/// Gibt die Lage jeder Seite zurück, leer ohne Druckaufbereitung.
const String _druckAusloesen = r'''
(async () => {
  const warte = ms => new Promise(r => setTimeout(r, ms));
  window.dispatchEvent(new Event('beforeprint'));
  for (let i = 0; i < 100; i++) {
    const w = document.getElementById('ab-print-root');
    if (w && w.children.length) { await warte(1000); break; }
    await warte(100);
  }
  await document.fonts.ready;
  const w = document.getElementById('ab-print-root');
  return JSON.stringify(w ? [...w.children].map(e => {
    const r = e.getBoundingClientRect();
    return {x: r.left + scrollX, y: r.top + scrollY, w: r.width, h: r.height};
  }).filter(r => r.w > 50 && r.h > 50) : []);
})()
''';

/// Der Inhalt je Ansicht, wie Moodle ihn ausgibt: Selektor und, wo das
/// gefundene Element nur innen liegt, der Kasten darum. Was nicht passt,
/// bricht ab -- kein Ausweichen auf einen größeren Bereich.
///   page:  mod/page/view.php, box($content, 'generalbox center clearfix');
///          ohne Aktivitätskopf und „Zuletzt geändert"
///   book:  mod/book/view.php, box_start('generalbox book_content',
///          'mod_book-chapter'): Kapiteltitel und Text, ohne Navigation
///   wiki:  mod/wiki/locallib.php, wiki_print_page_content: box($html) mit
///          dem Text in .no-overflow (wie wiki_lesen)
///   frage: die Frage selbst (.que) -- ohne Vorschauoptionen, technische
///          Angaben und Kommentare unter ihr
const Map<String, (String, String?)> _inhalt = {
  'page': ('#region-main .generalbox.center', null),
  'book': ('#mod_book-chapter', null),
  'wiki': ('#region-main .generalbox .no-overflow', '.generalbox'),
  'frage': ('#region-main .que', null),
};

/// Lage des Inhalts auf der ganzen Seite, null ohne Treffer.
String _bereich((String, String?) inhalt) => '''
(() => {
  const e = document.querySelector(${jsonEncode(inhalt.$1)});
  const z = e && ${inhalt.$2 == null ? 'e' : 'e.closest(${jsonEncode(inhalt.$2)})'};
  if (!z) return JSON.stringify(null);
  const r = z.getBoundingClientRect();
  return JSON.stringify({x: r.left + scrollX, y: r.top + scrollY, w: r.width, h: r.height});
})()
''';

class _Aufnahme {
  final bilder = <Uint8List>[];
  int ueberApp = 0, direkt = 0;
  final gesperrt = <String>[];
  String browser = '';
  String ausschnitt = '';
  String formeln = '';
}

Future<_Aufnahme> _aufnehmen(
    MoodleZugang moodle, Protokoll protokoll, Uri adresse, (String, String?) inhalt, String arbeitsordner,
    {bool druck = false}) async {
  final basis = moodle.basis!;
  final (browser, programm) = await _browser();
  final profil = Directory(p.join(arbeitsordner, '.browser-${DateTime.now().millisecondsSinceEpoch}'));
  await profil.create(recursive: true);
  final proz = await Process.start(programm, [
    '--headless=new',
    '--remote-debugging-port=0',
    '--user-data-dir=${profil.path}',
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-extensions',
    '--disable-sync',
    '--disable-background-networking',
    '--disable-component-update',
    '--disable-default-apps',
    '--mute-audio',
    '--hide-scrollbars',
    '--window-size=$_breite,900',
    'about:blank',
  ]);
  // Keine Ausgabe, nirgends (E11): Was der Browser schreibt, wird verworfen.
  unawaited(proz.stdout.drain<void>());
  unawaited(proz.stderr.drain<void>());
  _Cdp? cdp;
  String? port, browserPfad;
  try {
    // Der Browser schreibt in DevToolsActivePort im Profil den gewählten Port
    // und den Pfad des Browser-Endpunkts (zum Beenden). Dass der gestartete
    // Prozess sich beendet, heißt nichts: Edge startet sich neu und läuft in
    // einem anderen Prozess weiter (gemessen; siehe _beenden).
    final portDatei = File(p.join(profil.path, 'DevToolsActivePort'));
    final bis = DateTime.now().add(const Duration(seconds: 30));
    while (port == null) {
      if (DateTime.now().isAfter(bis)) {
        throw MoodleFehler('$browser startet nicht (kein DevTools-Port nach 30 s). Möglich: Eine Richtlinie oder '
            'der Virenschutz verbietet die Fernsteuerung des Browsers.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (await portDatei.exists()) {
        final z = await portDatei.readAsLines();
        if (z.length >= 2 && RegExp(r'^\d+$').hasMatch(z[0].trim())) {
          (port, browserPfad) = (z[0].trim(), z[1].trim());
        }
      }
    }
    final http = HttpClient();
    final List ziele;
    try {
      final req = await http.getUrl(Uri.parse('http://127.0.0.1:$port/json/list'));
      ziele = jsonDecode(await (await req.close()).transform(utf8.decoder).join()) as List;
    } finally {
      http.close(force: true);
    }
    final seite = ziele.cast<Map>().firstWhere((z) => z['type'] == 'page',
        orElse: () => throw MoodleFehler('$browser zeigt keine Seite.'));
    cdp = _Cdp(await WebSocket.connect('${seite['webSocketDebuggerUrl']}'));

    final a = _Aufnahme()..browser = browser;
    // Als Seite nur die aufgenommene und ihre Umleitungen (browserliste.dart).
    final seiten = {adresse.toString()};
    String? mathjax;
    var laufend = 0;
    var zuletzt = DateTime.now();
    var fertig = false;
    final geladen = Completer<void>();

    Future<void> anfrage(Map<String, dynamic> e) async {
      laufend++;
      zuletzt = DateTime.now();
      final id = e['requestId'];
      final req = (e['request'] as Map).cast<String, dynamic>();
      final methode = '${req['method']}';
      final uri = Uri.parse('${req['url']}');
      final dokument = e['resourceType'] == 'Document';
      final rumpf = req['postData'] as String?;
      try {
        final (weg, grund) = browserPruefen(methode, uri,
            basis: basis, seiten: seiten, dokument: dokument, rumpf: rumpf, mathjax: mathjax);
        switch (weg) {
          case BrowserWeg.direkt:
            if (grund != 'eingebettet') {
              a.direkt++;
              protokoll.eintrag(Art.moodle, 'Browser direkt: $methode ${uri.host}${uri.path} ($grund)');
            }
            await cdp!.senden('Fetch.continueRequest', {'requestId': id});
          case BrowserWeg.gesperrt:
            final wo = uri.host == basis.host ? adresseOhneWerte(uri) : '${uri.host}${uri.path}';
            a.gesperrt.add('$methode $wo ($grund)');
            protokoll.eintrag(Art.gesperrt, 'Browser gesperrt: $methode $wo ($grund)');
            await cdp!.senden('Fetch.failRequest', {'requestId': id, 'errorReason': 'BlockedByClient'});
          case BrowserWeg.ueberApp:
            final r = await moodle.fuerBrowser(methode, uri, seiten: seiten, rumpf: rumpf, dokument: dokument);
            a.ueberApp++;
            if (dokument) {
              mathjax ??= mathjaxQuelle(r.text);
              // Die Fragenvorschau leitet auf sich selbst mit previewid um.
              if (r.ort != null) seiten.add(uri.resolve(r.ort!).toString());
            }
            final typ = r.inhaltstyp ?? 'application/octet-stream';
            final text = typ.startsWith('text/') || typ.contains('javascript') || typ.contains('json');
            await cdp!.senden('Fetch.fulfillRequest', {
              'requestId': id,
              'responseCode': r.status,
              'responseHeaders': [
                {'name': 'Content-Type', 'value': text ? '$typ; charset=utf-8' : typ},
                if (r.ort != null) {'name': 'Location', 'value': r.ort},
              ],
              'body': base64Encode(r.bytes),
            });
        }
      } catch (x) {
        // Jeder Fehler endet hier: Die Anfrage läuft ohne Warten (unawaited),
        // ein Fehler, der durchrutschte, wäre ein „unerwarteter Fehler" der App.
        // Nach dem Bild beendet _beenden die Verbindung; was dann noch
        // unterwegs war (etwa eine Schrift), braucht keine Antwort mehr.
        if (fertig) return;
        final grund = x is MoodleFehler ? x.meldung : '${x.runtimeType}';
        if (!a.gesperrt.any((g) => g.contains(uri.path))) {
          a.gesperrt.add('$methode ${adresseOhneWerte(uri)} ($grund)');
        }
        try {
          await cdp!.senden('Fetch.failRequest', {'requestId': id, 'errorReason': 'Failed'});
        } on MoodleFehler {
          // Die Seite ist schon weiter; nichts mehr zu tun.
        }
      } finally {
        laufend--;
        zuletzt = DateTime.now();
      }
    }

    final abo = cdp.ereignisse.listen((e) {
      final params = (e['params'] as Map?)?.cast<String, dynamic>() ?? const {};
      switch (e['method']) {
        case 'Fetch.requestPaused':
          unawaited(anfrage(params));
        case 'Page.loadEventFired':
          if (!geladen.isCompleted) geladen.complete();
      }
    });
    try {
      await cdp.senden('Page.enable');
      await cdp.senden('Emulation.setDeviceMetricsOverride',
          {'width': _breite, 'height': 900, 'deviceScaleFactor': 1, 'mobile': false});
      await cdp.senden('Fetch.enable', {
        'patterns': [
          {'urlPattern': '*', 'requestStage': 'Request'}
        ]
      });
      await cdp.senden('Page.navigate', {'url': adresse.toString()});
      await geladen.future.timeout(const Duration(seconds: 90),
          onTimeout: () => throw MoodleFehler('Die Seite lädt nicht zu Ende (90 s).'));
      // Ruhe: 1,5 s ohne neue Anfrage, höchstens 30 s.
      final ende = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(ende) &&
          (laufend > 0 || DateTime.now().difference(zuletzt) < const Duration(milliseconds: 1500))) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      final f = await _auswerten(cdp, _warteAufFormeln);
      final fz = jsonDecode(f) as Map;
      a.formeln = fz['huellen'] == 0
          ? 'keine'
          : '${fz['gesetzt']} gesetzt${fz['text'] == 0 ? '' : ', ${fz['text']} als Text stehen geblieben'}';
      if (druck) {
        // Was die Druckaufbereitung auf ihre Seiten nimmt, bestimmt sie selbst:
        // Kopf und Fuß (Kurs, Titel, Logo, Schule, Seite, Datum) und den
        // Inhaltsbereich der Seite. Deshalb gibt es den Druck nur für Ansichten,
        // deren Inhaltsbereich keine Personen zeigt (bildschirmfoto).
        await cdp.senden('Emulation.setEmulatedMedia', {'media': 'print'});
        final blaetter = (jsonDecode(await _auswerten(cdp, _druckAusloesen)) as List).cast<Map>();
        if (blaetter.isNotEmpty) {
          if (blaetter.length > _hoechstensTeile) {
            throw MoodleFehler('Der Ausdruck hat ${blaetter.length} Seiten, mehr als $_hoechstensTeile.');
          }
          for (final s in blaetter) {
            final r = await cdp.senden('Page.captureScreenshot', {
              'format': 'png',
              'captureBeyondViewport': true,
              'clip': {
                'x': (s['x'] as num).floorToDouble(),
                'y': (s['y'] as num).floorToDouble(),
                'width': (s['w'] as num).ceilToDouble(),
                'height': (s['h'] as num).ceilToDouble(),
                'scale': 1,
              },
            });
            a.bilder.add(base64Decode('${r['data']}'));
          }
          a.ausschnitt = 'wie gedruckt mit der Druckaufbereitung, ${blaetter.length} Seite(n), je Seite ein Bild';
          return a;
        }
        // Ohne Druckaufbereitung: der Inhalt mit den Druck-Stylesheets.
      }
      final b = jsonDecode(await _auswerten(cdp, _bereich(inhalt))) as Map?;
      if (b == null) throw MoodleFehler('Der Inhalt (${inhalt.$1}) ist auf der Seite nicht zu finden -- kein Bild.');
      final x = (b['x'] as num).floorToDouble(), y = (b['y'] as num).floorToDouble();
      final w = (b['w'] as num).ceilToDouble(), h = (b['h'] as num).ceilToDouble();
      if (w < 1 || h < 1) throw MoodleFehler('Der Inhalt ist leer.');
      final teile = (h / _teilhoehe).ceil();
      if (teile > _hoechstensTeile) {
        throw MoodleFehler('Die Seite ist zu lang für Bildschirmfotos (${h.toInt()} Pixel, mehr als '
            '$_hoechstensTeile Teile).');
      }
      a.ausschnitt = '${druck ? 'wie gedruckt (ohne Druckaufbereitung), ' : 'wie am Bildschirm, '}nur der Inhalt, '
          '${w.toInt()} × ${h.toInt()} Pixel${teile > 1 ? ', in $teile Teilen' : ''}';
      for (var i = 0; i < teile; i++) {
        final oben = y + i * _teilhoehe;
        final hoehe = (i == teile - 1) ? h - i * _teilhoehe : _teilhoehe.toDouble();
        final r = await cdp.senden('Page.captureScreenshot', {
          'format': 'png',
          'captureBeyondViewport': true,
          'clip': {'x': x, 'y': oben, 'width': w, 'height': hoehe, 'scale': 1},
        });
        a.bilder.add(base64Decode('${r['data']}'));
      }
      return a;
    } finally {
      fertig = true;
      await abo.cancel();
    }
  } finally {
    await _beenden(cdp, port, browserPfad, proz, profil, p.basename(programm), protokoll);
  }
}

/// Beendet hart jeden Prozess von [exe], der mit [profil] läuft, und gibt
/// ihre Zahl zurück. Gefunden werden sie am Profil im Aufruf, das jeder
/// Prozess des Browsers trägt -- nicht an der Nummer des gestarteten
/// Prozesses: Edge beendet ihn gleich nach dem Start und läuft in einem
/// neuen weiter, dessen Elternprozess es nicht mehr gibt (gemessen);
/// taskkill /T über die gestartete Nummer trifft dann nichts.
Future<int> _profilProzesseBeenden(Directory profil, String exe) async {
  String ps(String s) => s.replaceAll("'", "''");
  try {
    final r = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      "\$p = @(Get-CimInstance Win32_Process -Filter \"Name='${ps(exe)}'\" | Where-Object "
          "{ \$_.CommandLine -and \$_.CommandLine.Contains('${ps(profil.path)}') }); "
          r"$p | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; $p.Count",
    ]);
    return int.tryParse('${r.stdout}'.trim()) ?? -1;
  } on ProcessException {
    return -1;
  }
}

Future<bool> _profilLoeschen(Directory profil, int versuche) async {
  for (var i = 0; i < versuche; i++) {
    try {
      if (await profil.exists()) await profil.delete(recursive: true);
      return true;
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }
  return false;
}

/// Beendet den Browser samt Hilfsprozessen und löscht das Profil. Regulär
/// über den Browser-Endpunkt (Browser.close): Das beendet alle Prozesse und
/// gibt das Profil frei. Ging das nicht -- der Port erschien nie, der
/// Browser hängt --, hält noch ein Prozess das Profil fest; dann hart über
/// das Profil ([_profilProzesseBeenden]). Was dabei misslingt, steht im
/// Protokoll; ein Rest im Arbeitsordner verschwindet spätestens beim
/// nächsten Leeren.
Future<void> _beenden(_Cdp? cdp, String? port, String? browserPfad, Process proz, Directory profil, String exe,
    Protokoll protokoll) async {
  try {
    await cdp?.schliessen().timeout(const Duration(seconds: 5));
  } catch (_) {
    // Die Seite ist ohnehin gleich weg.
  }
  if (port != null && browserPfad != null) {
    try {
      final b = _Cdp(await WebSocket.connect('ws://127.0.0.1:$port$browserPfad').timeout(const Duration(seconds: 5)));
      await b.senden('Browser.close').timeout(const Duration(seconds: 5)).catchError((_) => <String, dynamic>{});
      await b.schliessen().timeout(const Duration(seconds: 5)).catchError((_) {});
    } catch (_) {
      // Dann eben hart, unten.
    }
  }
  if (await _profilLoeschen(profil, 10)) return;
  final n = await _profilProzesseBeenden(profil, exe);
  if (n != 0) protokoll.eintrag(Art.info, 'Browser hart beendet: ${n < 0 ? 'Zahl unbekannt' : '$n Prozess(e)'}');
  // Der gestartete Prozess selbst, falls er noch läuft.
  if (await proz.exitCode.timeout(const Duration(seconds: 2), onTimeout: () => -1) == -1) proz.kill();
  if (await _profilLoeschen(profil, 20)) return;
  protokoll.eintrag(Art.fehler, 'Browserprofil nicht gelöscht: ${profil.path} -- beim nächsten Leeren des Arbeitsordners');
}

Future<String> _auswerten(_Cdp cdp, String js) async {
  final r = await cdp.senden('Runtime.evaluate', {'expression': js, 'awaitPromise': true, 'returnByValue': true});
  if (r['exceptionDetails'] != null) throw MoodleFehler('Browser: Skript in der Seite gescheitert.');
  return '${(r['result'] as Map?)?['value']}';
}

/// Nimmt eine Ansicht auf, zeigt die Bilder mit dem [grund] der Lehrkraft
/// und gibt sie nur nach ihrer Freigabe zurück. Entweder [cmid] (Textseite,
/// Buch, Wiki) oder [frage] mit [sammlung] (Fragenvorschau).
Future<(String, List<Uint8List>)> bildschirmfoto(MoodleZugang moodle, Freigaben freigaben, Protokoll protokoll,
    {required String grund,
    int? cmid,
    int? kapitel,
    int? wikiseite,
    int? frage,
    int? sammlung,
    bool druck = false,
    required String arbeitsordner}) async {
  final wozu = grundPruefen(grund);
  final String pfad, seite, ansicht;
  final int? kurs;
  if (frage != null) {
    if (sammlung == null) throw MoodleFehler('Zur Frage gehört die Sammlung (cmid der Fragensammlung).');
    // Der Druck nimmt den ganzen Inhaltsbereich (_aufnehmen), in der
    // Vorschau also auch Kommentare unter der Frage.
    if (druck) throw MoodleFehler('Wie gedruckt gibt es Textseite, Buch und Wiki, keine Fragenvorschau.');
    final f = await formularHolen(moodle, '/course/modedit.php?update=$sammlung');
    kurs = f.kurs;
    pfad = '/question/bank/previewquestion/preview.php?id=$frage&cmid=$sammlung';
    seite = 'Fragenvorschau: Frage $frage aus „${f.name}" (cmid $sammlung)';
    ansicht = 'frage';
  } else if (cmid != null) {
    final f = await formularHolen(moodle, '/course/modedit.php?update=$cmid');
    kurs = f.kurs;
    ansicht = f.modul ?? '';
    pfad = switch (ansicht) {
      'page' => '/mod/page/view.php?id=$cmid',
      'book' => '/mod/book/view.php?id=$cmid${kapitel == null ? '' : '&chapterid=$kapitel'}',
      'wiki' => await wikiAnsicht(moodle, cmid, f, seite: wikiseite),
      _ => throw MoodleFehler('Bildschirmfotos gibt es von Textseite, Buch und Wiki, nicht von „${f.modul}".'),
    };
    seite = '${typName(ansicht)} „${f.name}" (cmid $cmid'
        '${kapitel == null ? '' : ', Kapitel $kapitel'}${wikiseite == null ? '' : ', Wikiseite $wikiseite'})';
  } else {
    throw MoodleFehler('cmid oder frage mit sammlung angeben.');
  }
  protokoll.eintrag(Art.info, 'Bildschirmfoto: $seite -- Grund: $wozu');
  final adresse = moodle.basis!.resolve(pfad);
  final a = await _aufnehmen(moodle, protokoll, adresse, _inhalt[ansicht]!, arbeitsordner, druck: druck);
  final wo = [
    if (kurs != null) 'Kurs: ${await kursBezeichnung(moodle, kurs)}',
    'Seite: $seite',
    'Adresse: $adresse',
    'Ausschnitt: ${a.ausschnitt}',
  ];
  // Die Lehrkraft entscheidet über die Bilder; was der Browser technisch
  // tat, braucht sie nur, wenn es das Bild verfälschen kann.
  final ja = await freigaben.anfragen(FreigabeAnfrage(
    titel: 'Bildschirmfoto an Claude geben?',
    grund: wozu,
    punkte: [
      ...wo,
      if (a.gesperrt.isNotEmpty)
        '${a.gesperrt.length} Anfrage(n) des Browsers gesperrt (Datenschutz oder fremde Rechner) -- die '
            'Darstellung kann deshalb abweichen',
    ],
    vergleich: const [],
    bilder: a.bilder,
    knopf: 'An Claude geben',
    ablehnen: 'Verwerfen',
    ohneEntscheidung: 'wird das Bild verworfen',
  ));
  if (!ja) {
    return ('Nicht freigegeben: Die Lehrkraft hat das Bildschirmfoto verworfen. Nichts weitergegeben.', const <Uint8List>[]);
  }
  final name = '${frage != null ? 'frage-$frage' : 'cm-$cmid'}${kapitel == null ? '' : '-kapitel-$kapitel'}'
      '${wikiseite == null ? '' : '-seite-$wikiseite'}${druck ? '-druck' : ''}';
  final dateien = <String>[];
  for (var i = 0; i < a.bilder.length; i++) {
    final d = File(p.join(arbeitsordner, 'bildschirmfoto-$name${a.bilder.length > 1 ? '-${i + 1}' : ''}.png'));
    await d.writeAsBytes(a.bilder[i]);
    dateien.add(d.path);
  }
  return (
    [
      ...wo,
      'Formeln: ${a.formeln}',
      'Browser: ${a.browser}; Anfragen: ${a.ueberApp} über die App, ${a.direkt} direkt (MathJax), '
          '${a.gesperrt.length} gesperrt',
      for (final g in a.gesperrt) 'Gesperrt: $g',
      'Gespeichert: ${dateien.join(', ')}',
    ].join('\n'),
    a.bilder
  );
}
