// Interaktive Elemente (lib/moodle/elemente.dart): der Kopf, den die App
// setzt, die Prüfung der Elementdatei und die Grenze für Code im Text.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:moocp/moodle/auswertung.dart';
import 'package:moocp/moodle/elemente.dart';
import 'package:moocp/moodle/formular_schreiben.dart';
import 'package:moocp/moodle/fragen_xml.dart';
import 'package:moocp/moodle/moodle_zugang.dart';
import 'package:path/path.dart' as p;

final _basis = Uri.parse('https://moodle.schule.example');
final _kopf = elementKopf(_basis, stylesheet: '/theme/styles.php/boost/17_1/all');

const _element = '''<!DOCTYPE html>
<html lang="de">
<head>
<title>Würfel</title>
<style>.flaeche { display: grid; }</style>
</head>
<body>
<button type="button" class="btn btn-primary" id="w">Würfeln</button>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><circle cx="5" cy="5" r="2"/></svg>
<script>
document.getElementById('w').addEventListener('click', function () {
  var k = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
  var r = document.body.getBoundingClientRect(); if (r.top < 0) {}
});
</script>
</body>
</html>
''';

void main() {
  group('Kopf', () {
    test('sperrt alles außer dem eigenen Moodle und hält offen geöffnete Dateien an', () {
      expect(_kopf, contains("default-src 'none'"));
      expect(_kopf, contains("style-src 'unsafe-inline' https://moodle.schule.example"));
      expect(_kopf, contains("form-action 'none'"));
      expect(_kopf, contains('<plaintext hidden>'));
      expect(_kopf, contains('href="https://moodle.schule.example/theme/styles.php/boost/17_1/all"'));
      expect(elementKopf(_basis), isNot(contains('<link')));
    });

    test('kommt direkt hinter <head>, ersetzt einen alten und bleibt beim zweiten Mal gleich', () {
      final einmal = mitKopf(_element, _kopf);
      expect(einmal.indexOf(kopfAnfang), greaterThan(einmal.indexOf('<head>')));
      expect(einmal.indexOf(kopfAnfang), lessThan(einmal.indexOf('<title>')));
      expect(mitKopf(einmal, _kopf), einmal);
      final neu = elementKopf(_basis, stylesheet: '/theme/styles.php/boost/18_1/all');
      final ersetzt = mitKopf(einmal, neu);
      expect(kopfAnfang.allMatches(ersetzt).length, 1);
      expect(ersetzt, contains('18_1'));
      expect(ersetzt, isNot(contains('17_1')));
      expect(ohneKopf(ersetzt), _element);
    });

    test('ohne <head> oder mit etwas davor: abgewiesen', () {
      expect(() => mitKopf('<p>Nur ein Absatz</p>', _kopf), throwsA(isA<MoodleFehler>()));
      expect(() => mitKopf('<script>x()</script><html><head></head></html>', _kopf), throwsA(isA<MoodleFehler>()));
      expect(mitKopf('<!-- Kommentar --><!DOCTYPE html><html lang="de"><head></head></html>', _kopf),
          contains(kopfAnfang));
    });
  });

  group('Elementdatei', () {
    test('ein gewöhnliches Element: SVG-Namensraum, Koordinaten, Bootstrap -- kein Befund', () {
      expect(elementFehler(_element), isEmpty);
      expect(elementFehler(mitKopf(_element, _kopf)), isEmpty, reason: 'der Kopf der App zählt nicht');
    });

    test('Laden, Senden, Speichern, die Moodle-Seite: gemeldet', () {
      String mit(String code) => _element.replaceFirst('</script>', '$code\n</script>');
      expect(elementFehler(mit("fetch('/x');")), [contains('fetch')]);
      expect(elementFehler(mit("new XMLHttpRequest();")), [contains('XMLHttpRequest')]);
      expect(elementFehler(mit("localStorage.setItem('a', 1);")), [contains('Speichern im Browser')]);
      expect(elementFehler(mit('var c = document.cookie;')), [contains('Speichern im Browser')]);
      expect(elementFehler(mit('parent.document.title;')), [contains('Moodle-Seite')]);
      expect(elementFehler(mit("img.src = 'https://bilder.example/a.png';")), [contains('Adresse')]);
      expect(elementFehler(_element.replaceFirst('<title>', '<link rel="stylesheet" href="//cdn.example/a.css"><title>')),
          [contains('Adresse')]);
      expect(elementFehler(_element.replaceFirst('<title>', '<script src="bibliothek.js"></script><title>')),
          [contains('Nachgeladenes Skript')]);
      expect(elementFehler(_element.replaceFirst('<body>', '<body><iframe src="a.html"></iframe>')),
          [contains('Rahmen')]);
      expect(elementFehler(_element.replaceFirst('<title>', '<meta http-equiv="refresh" content="0"><title>')),
          [contains('http-equiv')]);
    });

    test('Adressen als Text auf dem Element sind kein Laden', () {
      expect(elementFehler(_element.replaceFirst('<body>', '<body><p>Quelle: https://www.destatis.example</p>')),
          isEmpty);
    });

    test('Wörter wie im Code, aber als Text: kein Befund; im Skript schon', () {
      expect(
          elementFehler(_element.replaceFirst(
              '<body>', '<body><p>We import goods. The box is on top. Ask a parent. Der Wert steht im localStorage.</p>')),
          isEmpty);
      String mit(String code) => _element.replaceFirst('</script>', '$code\n</script>');
      expect(elementFehler(mit("import('x.js');")), [contains('import')]);
      expect(elementFehler(mit('top.location;')), [contains('Moodle-Seite')]);
      expect(elementFehler(_element.replaceFirst('<button ', '<button onclick="parent.alert(1)" ')),
          [contains('Moodle-Seite')], reason: 'auch im Ereignis-Attribut');
    });
  });

  group('Code im Text eines Felds', () {
    test('Stellen: <script>, Ereignis-Attribute, javascript: und srcdoc', () {
      final s = skriptstellen('<p onclick="x()">a</p><script>y()</script><a href=" javascript:z()">b</a>'
          '<iframe srcdoc="&lt;p&gt;c&lt;/p&gt;"></iframe><p>onclick= ist hier nur Text</p>');
      expect(s, hasLength(4));
      expect(skriptstellen('<p>Ein Skript über JavaScript</p><img src="a.png" alt="">'), isEmpty);
      expect(skriptstellen('[[jsxgraph]]if (a<b && onclick=1) {}[[/jsxgraph]]'), isEmpty,
          reason: 'Code einer STACK-Zeichnung ist kein HTML');
      expect(skriptstellen('<svg><set attributeName="onmouseover" to="x()"/></svg>'), hasLength(1),
          reason: 'eine SVG-Animation, die ein Ereignis-Attribut setzt');
    });

    test('neuer Code bricht ab, was schon in Moodle stand, darf bleiben', () {
      const alt = '<p>Text</p><script src="https://moodle.schule.example/lib/h5p/js/h5p-resizer.js"></script>';
      skripteImTextPruefen({'page': '$alt<p>mehr Text</p>'}, alt: {'page': alt});
      expect(() => skripteImTextPruefen({'page': '$alt<script>neu()</script>'}, alt: {'page': alt}),
          throwsA(isA<MoodleFehler>().having((e) => e.meldung, 'meldung', contains('<script>neu()'))));
      expect(() => skripteImTextPruefen({'page': '<button onclick="los()">Los</button>'}),
          throwsA(isA<MoodleFehler>()));
      expect(() => skripteImTextPruefen({'page': '<iframe sandbox="allow-scripts" srcdoc="x"></iframe>'}),
          throwsA(isA<MoodleFehler>()));
    });

    test('Element-Rahmen: nur mit sandbox="allow-scripts", und nicht in Fragen und Wikis', () {
      const gut = '<iframe sandbox="allow-scripts" title="Würfel" src="@@PLUGINFILE@@/wuerfel.html" height="300">'
          '</iframe>';
      skripteImTextPruefen({'page': gut});
      for (final schlecht in [
        '<iframe title="Würfel" src="@@PLUGINFILE@@/wuerfel.html"></iframe>',
        '<iframe sandbox="allow-scripts allow-same-origin" src="@@PLUGINFILE@@/wuerfel.html"></iframe>',
        '<iframe sandbox="allow-scripts allow-top-navigation" src="@@PLUGINFILE@@/wuerfel.html"></iframe>',
      ]) {
        expect(() => skripteImTextPruefen({'page': schlecht}), throwsA(isA<MoodleFehler>()), reason: schlecht);
      }
      expect(() => skripteImTextPruefen({'questiontext': gut}, elementeErlaubt: false),
          throwsA(isA<MoodleFehler>()));
      // Ein Video vom fremden Rechner ist kein Element (das prüft die Auswertung als Einbettung).
      expect(elementRahmen('<iframe src="https://video.example/v/1"></iframe>'), isEmpty);
      expect(elementRahmen('<iframe sandbox="allow-scripts" src="https://moodle.schule.example/draftfile.php/5/user/'
              'draft/7/wuerfel.html"></iframe>')
          .single
          .datei, 'wuerfel.html');
    });
  });

  group('Vorbereiten im Arbeitsordner', () {
    late Directory ordner;
    setUp(() => ordner = Directory.systemTemp.createTempSync('moocp_elemente_'));
    tearDown(() => ordner.deleteSync(recursive: true));

    void datei(String pfad, String text) {
      final f = File(p.join(ordner.path, pfad));
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(text);
    }

    String lies(String pfad) => File(p.join(ordner.path, pfad)).readAsStringSync();
    const feld = {'page': '<p>Probier aus:</p><iframe sandbox="allow-scripts" src="@@PLUGINFILE@@/w.html"></iframe>'};

    test('setzt den Kopf in neue Dateien', () {
      datei('dateien/w.html', _element);
      elementeVorbereiten(ordner.path, feld, _kopf);
      expect(lies('dateien/w.html'), mitKopf(_element, _kopf));
    });

    test('lässt Dateien, die sich gegen den Stand nicht geändert haben, wie sie sind', () {
      datei('dateien/w.html', _element);
      datei('.stand/dateien/w.html', _element);
      elementeVorbereiten(ordner.path, feld, _kopf, stand: p.join(ordner.path, '.stand'));
      expect(lies('dateien/w.html'), _element);
    });

    test('bricht ab, bevor etwas geschrieben ist, wenn ein Element lädt', () {
      final schlecht = _element.replaceFirst('</script>', "fetch('/x');\n</script>");
      datei('dateien/w.html', schlecht);
      expect(() => elementeVorbereiten(ordner.path, feld, _kopf), throwsA(isA<MoodleFehler>()));
      expect(lies('dateien/w.html'), schlecht);
    });

    test('Datei mit Code, die kein Element ist: abgewiesen, ob verlinkt oder im Dateibereich', () {
      Matcher abgewiesen(String pfad) =>
          throwsA(isA<MoodleFehler>().having((e) => e.meldung, 'meldung', contains(pfad)));
      datei('dateien/x.html', _element);
      datei('page.html', '<p><a href="@@PLUGINFILE@@/x.html">Seite</a></p>');
      expect(() => quelleLesen(ordner.path, kopf: _kopf), abgewiesen('dateien/x.html'));
      // Als Element eingebunden, darf dieselbe Datei auch verlinkt sein: Der Kopf hält sie offen geöffnet an.
      datei('page.html', '${feld['page']!.replaceAll('w.html', 'x.html')}<p><a href="@@PLUGINFILE@@/x.html">x</a></p>');
      quelleLesen(ordner.path, kopf: _kopf);
      datei('bereiche/files/y.svg', '<svg xmlns="http://www.w3.org/2000/svg" onload="los()"></svg>');
      expect(() => quelleLesen(ordner.path, kopf: _kopf), abgewiesen('bereiche/files/y.svg'));
      datei('bereiche/files/y.svg', '<svg xmlns="http://www.w3.org/2000/svg"><circle r="2"/></svg>');
      datei('bereiche/files/z.html', '<!DOCTYPE html><html><head><title>Z</title></head><body><p>Nur Text</p></body></html>');
      quelleLesen(ordner.path, kopf: _kopf);
    });
  });

  test('Code in Dateien, die der Browser als Dokument öffnet', () {
    List<String> code(String name, String text) => codeInDatei(name, utf8.encode(text));
    expect(code('a.html', _element), isNotEmpty);
    expect(code('a.svg', '<svg onload="x()"></svg>'), isNotEmpty);
    expect(code('a.xml', '<html xmlns="http://www.w3.org/1999/xhtml"><script>x()</script></html>'), isNotEmpty);
    expect(codeInDatei('a.svgz', gzip.encode(utf8.encode('<svg><script>x()</script></svg>'))), isNotEmpty);
    expect(code('a.html', '<p>Nur Text</p>'), isEmpty);
    expect(code('a.txt', '<script>x()</script>'), isEmpty, reason: 'öffnet der Browser nicht als Dokument');
  });

  test('Fragen-XML: keine Datei mit Code, auch keine, die schon im XML steht', () {
    String xml(String datei) => quizXml([
          '<question type="cloze"><name><text>ZZ Frage</text></name><questiontext format="html">'
              '<text><![CDATA[<p><a href="@@PLUGINFILE@@/$datei">Blatt</a> {1:MULTICHOICE_V:=a~b}</p>]]></text>'
              '<file name="$datei" path="/" encoding="base64">${base64Encode(utf8.encode(_element))}</file>'
              '</questiontext></question>'
        ]);
    expect(() => fragenXmlPruefen(xml('blatt.html')),
        throwsA(isA<MoodleFehler>().having((e) => e.meldung, 'meldung', contains('Datei blatt.html enthält Code'))));
    fragenXmlPruefen(xml('blatt.txt'));
  });

  group('Auswertung beim Lesen', () {
    const host = 'moodle.schule.example';

    test('Element, offener Rahmen, leerer Rahmen, srcdoc und Code im Text werden genannt', () {
      final a = feldAuswerten(
          'page',
          '<p>a</p><iframe sandbox="allow-scripts" title="W" src="@@PLUGINFILE@@/w.html"></iframe>'
              '<iframe title="X" src="@@PLUGINFILE@@/x.html"></iframe>'
              '<p><iframe class="w-100" sandbox="allow-scripts"></iframe></p>'
              '<iframe srcdoc="&lt;p&gt;b&lt;/p&gt;"></iframe>'
              '<script>alt()</script>',
          host: host);
      expect(a.elemente, ['w.html', 'x.html']);
      final z = a.befunde.zeilen.join('\n');
      expect(z, contains('x.html'));
      expect(z, contains('ohne sandbox'));
      expect(z, contains('leerer Rahmen'));
      expect(z, contains('srcdoc'));
      expect(z, contains('[Skript] <script>alt()'));
      expect(z, isNot(contains('w.html')));
    });

    test('Elementdatei ohne Kopf der App: Befund nur, wenn ein Rahmen sie einbindet', () {
      final d = dateiAuswerten('w.html', Uint8List.fromList(utf8.encode(_element)));
      expect(d.format, 'HTML');
      final felder = [
        feldAuswerten('page', '<iframe sandbox="allow-scripts" src="@@PLUGINFILE@@/w.html"></iframe>', host: host)
      ];
      expect(uebersichtText(felder, {'w.html': d}), contains('ohne den Kopf der App'));
      expect(uebersichtText(felder, {'w.html': d}), contains('als interaktives Element eingebunden'));
      final verlinkt = [feldAuswerten('page', '<a href="@@PLUGINFILE@@/w.html">Seite</a>', host: host)];
      expect(uebersichtText(verlinkt, {'w.html': d}), isNot(contains('ohne den Kopf der App')));
      expect(uebersichtText(verlinkt, {'w.html': d}), contains('enthält Code und ist kein Element'),
          reason: 'verlinkt läuft sie ohne Rahmen');
      expect(uebersichtText(felder, {'w.html': d}), isNot(contains('kein Element')));
    });
  });

  test('Theme-Stylesheet von der Anmeldeseite', () {
    final doc = html_parser.parse('<html><head>'
        '<link rel="stylesheet" type="text/css" href="https://moodle.schule.example/theme/yui_combo.php?x.css">'
        '<link rel="stylesheet" type="text/css" href="https://moodle.schule.example/theme/styles.php/boost/17_1/all">'
        '</head></html>');
    expect(themeStylesheetIn(doc), '/theme/styles.php/boost/17_1/all');
    expect(themeStylesheetIn(html_parser.parse('<html><head></head></html>')), isNull);
  });
}
