// Offline prüfbar: die Auswertung beim Lesen, an erfundenen Seiten.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/auswertung.dart';

const host = 'moodle.example';

Uint8List png(int b, int h) {
  final d = Uint8List(33);
  d.setAll(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52]);
  ByteData.view(d.buffer)
    ..setUint32(16, b)
    ..setUint32(20, h);
  return d;
}

void main() {
  test('Gliederung mit Zeitangaben, Tabellen, Bildern und Verweisen', () {
    const html = '''
<p class="lead">Eine erfundene Übungsseite zum Testen.</p>
<div class="d-flex"><h3 class="my-0">Aufgabe 1: Erste Übung</h3>
<div class="c4l-inline-group"><div class="c4lv-estimatedtime"><span>10</span> Minuten</div></div></div>
<p><img class="img-fluid" src="https://moodle.example/draftfile.php/5/user/draft/77/zz-probe.svg" alt="Probezeichnung" width="360"></p>
<h4>1a) Tabelle</h4>
<table class="table table-bordered"><thead><tr><th>A</th><th>B</th></tr></thead>
<tbody><tr><td>x</td><td> </td></tr><tr><td>y</td><td>&nbsp;</td></tr></tbody></table>
<p>Siehe <a href="https://moodle.example/mod/page/view.php?id=900">Info: Erfundene Hilfeseite</a>.</p>
<div class="d-flex"><h3>Aufgabe 2: Zweite Übung</h3><div class="c4lv-estimatedtime"><span>5</span> Minuten</div></div>
<ol><li>eins</li><li>zwei</li></ol>''';
    final a = feldAuswerten('page', html, host: host);
    expect(a.einleitung, 'Eine erfundene Übungsseite zum Testen.');
    expect(a.minuten, 15);
    expect([for (final p in a.gliederung) '${p.ebene} ${p.titel} ${p.minuten} ${p.inhalt}'], [
      '3 Aufgabe 1: Erste Übung 10 [Bild zz-probe.svg]',
      '4 1a) Tabelle null [Tabelle 3×2 (2 Zellen leer), Verweis auf cm 900]',
      '3 Aufgabe 2: Zweite Übung 5 [nummerierte Liste (2)]',
    ]);
    expect(a.bilder.single.quelle, 'zz-probe.svg');
    expect(a.bilder.single.unter, 'Aufgabe 1: Erste Übung');
    expect(a.verweise.single.cmid, 900);
    expect(a.befunde.isEmpty, isTrue, reason: a.befunde.zeilen.join('\n'));
  });

  test('Befunde nach den Regeln der Skills', () {
    const html = '''
<h2>Zu hoch</h2>
<h4>Übersprungen?</h4>
<h3>Aufgabe</h3>
<p style="color:red">Rot</p>
<p></p><p>&nbsp;</p>
<p><img src="https://moodle.example/pluginfile.php/1/mod_page/content/1/a.png"></p>
<p><img class="img-fluid" src="https://moodle.example/pluginfile.php/1/mod_page/content/1/b.png" alt="b.png"></p>
<p><img class="img-fluid" src="https://fremd.example/c.png" alt="Fremdes Bild"></p>
<p>Mehr dazu <a href="https://example.org/x">hier</a> und <a href="//example.org/y">https://example.org/y</a>
und <a href="http://example.org/z">http://example.org/z</a>.</p>
<table><tr><td>ohne Klasse</td></tr></table>
<b>fett</b>''';
    final z = feldAuswerten('page', html, host: host).befunde.zeilen;
    expect(z, containsAll([
      '[Überschrift] <h2> „Zu hoch": h1 und h2 sind Moodle vorbehalten, Inhalt beginnt bei h3',
      '[Überschrift] <h4> „Übersprungen?" folgt auf h2: Ebene übersprungen',
      '[Stil] style-Attribut an <p> unter „Aufgabe"',
      '[Leerer Absatz] leerer Absatz unter „Aufgabe" (2×)',
      '[Alternativtext] fehlt: a.png',
      '[Bild] ohne class="img-fluid" (skaliert nicht mit): a.png',
      '[Alternativtext] ist ein Dateiname: b.png',
      '[Hotlink] Bild von fremdem Server fremd.example unter „Aufgabe" -- lokale Kopie ablegen',
      '[Linktext] „hier" sagt auf Papier nichts unter „Aufgabe"',
      '[Adresse] protokollrelativ (//…): //example.org/y',
      '[Adresse] unverschlüsselt (http://): http://example.org/z',
      '[Tabelle] Tabelle ohne class="table" unter „Aufgabe"',
      '[Altlast] <b> unter „Aufgabe" -- <strong>/<em> oder nichts',
    ]));
  });

  test('SchuCu-Tabelle: style und &nbsp; sind dort Absicht', () {
    const html = '''
<table class="lernsituation" style="width: 100%;"><tbody>
<tr><td class="lshead" style="width: 20%;">Titel</td><td>&nbsp;&nbsp;</td></tr>
</tbody></table>
<h3>Einstieg</h3><p>Los geht es.</p>''';
    final a = feldAuswerten('page', html, host: host);
    expect(a.schucu, isTrue);
    expect(a.befunde.isEmpty, isTrue, reason: a.befunde.zeilen.join('\n'));
    expect(a.einleitung, isNull, reason: 'Text der SchuCu-Tabelle ist keine Einleitung');
  });

  test('SchuCu-Tabelle: die Absätze der Vorlage darunter gehören dazu, spätere nicht', () {
    const html = '''
<table class="lernsituation"><tbody><tr><td class="lsdata">A B</td></tr></tbody></table>
<p style="font-size: 8pt;">A: Kommunizieren; B: Algorithmisieren</p>
<p>Inhalte können teilweise mit KI generiert sein.</p>
<h3>Danach</h3>
<p style="font-size: 8pt;">Kein Teil der Vorlage</p>''';
    final a = feldAuswerten('page', html, host: host);
    expect(a.schucu, isTrue);
    expect(a.einleitung, isNull, reason: 'Absätze der Vorlage sind keine Einleitung');
    expect(a.befunde.zeilen, ['[Stil] style-Attribut an <p> unter „Danach"']);
  });

  test('Rahmenlinien an Tabellenelementen sind erlaubt, Farbe und alles andere nicht', () {
    const html = '''
<h3>T-Konto</h3>
<table class="table border-0"><tbody>
<tr><th style="border-bottom: 2px solid">Soll</th><th style="border-bottom:2px solid; border-left: 2px solid;">Haben</th></tr>
<tr><td style="border: 0">Anfangsbestand</td><td style="border-left-width: thick; border-left-style: solid">Abgang</td></tr>
<tr><td style="border-top: 2px double #000">Summe</td><td style="background: yellow; width: 50%">Summe</td></tr>
</tbody></table>
<p style="border-bottom: 1px solid">Kein Tabellenelement</p>''';
    expect(feldAuswerten('page', html, host: host).befunde.zeilen, [
      '[Stil] style-Attribut an <td> mit mehr als Rahmenlinien (border-top: 2px double #000) unter „T-Konto"',
      '[Stil] style-Attribut an <td> mit mehr als Rahmenlinien (background, width) unter „T-Konto"',
      '[Stil] style-Attribut an <p> unter „T-Konto"',
    ]);
  });

  test('Linktext gegen den Titel der Aktivität', () {
    final a = feldAuswerten(
        'page',
        '<p><a href="https://moodle.example/mod/page/view.php?id=900">Hilfeseite</a> '
            '<a href="https://moodle.example/mod/page/view.php?id=901">ZZ Richtig benannt</a> '
            '<a href="https://moodle.example/mod/page/view.php?id=902">Infoblatt 1</a> '
            '<a href="https://moodle.example/mod/page/view.php?id=903">Infoblatt</a></p>',
        host: host);
    verweiseAbgleichen(a, {
      900: ('ZZ Erfundene Hilfeseite', 'page'),
      901: ('ZZ Richtig benannt', 'page'),
      902: ('Infoblatt 1: VLAN-Grundlagen', 'page'),
      903: ('Infoblatt 1: VLAN-Grundlagen', 'page'),
    });
    expect(a.verweise.first.zielTitel, 'ZZ Erfundene Hilfeseite');
    // Die Kennung vor dem Doppelpunkt ist richtig, ein Teil davon nicht.
    expect(a.befunde.zeilen, [
      '[Linktext] Verweis auf cm 900 lautet „Hilfeseite", die Aktivität heißt „ZZ Erfundene Hilfeseite" '
          '-- Linktext = exakter Titel oder seine Kennung vor dem Doppelpunkt',
      '[Linktext] Verweis auf cm 903 lautet „Infoblatt", die Aktivität heißt „Infoblatt 1: VLAN-Grundlagen" '
          '-- Linktext = exakter Titel oder seine Kennung vor dem Doppelpunkt',
    ]);
  });

  test('Dateien: Maße und SVG-Inhalt', () {
    expect(dateiAuswerten('blatt.odt', Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0])).format, 'ODT');
    expect(dateiAuswerten('paket.circ', Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0])).format, 'ZIP');
    final p = dateiAuswerten('a.png', png(2559, 1229));
    expect('${p.format} ${p.breite}×${p.hoehe}', 'PNG 2559×1229');

    final gut = dateiAuswerten(
        'gut.svg',
        Uint8List.fromList(utf8.encode('<?xml version="1.0"?>\n'
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 240" width="480" height="240" '
            'role="img" aria-labelledby="t d"><title id="t">Probe</title><desc id="d">Zwei Kästen</desc>'
            '<text x="10" y="20">A1</text><text>A2</text><text>A1</text></svg>')));
    expect('${gut.format} ${gut.breite}×${gut.hoehe}', 'SVG 480×240');
    expect(gut.titel, 'Probe');
    expect(gut.beschreibung, 'Zwei Kästen');
    expect(gut.beschriftungen, ['A1', 'A2']);
    expect(gut.befunde.isEmpty, isTrue, reason: gut.befunde.zeilen.join('\n'));

    final schlecht = dateiAuswerten(
        'schlecht.svg',
        Uint8List.fromList(utf8.encode('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 50">'
            '<style>@import url("https://fonts.example/x.css");</style>'
            '<image href="data:image/png;base64,AAAA"/><path d="M0 0"/></svg>')));
    expect('${schlecht.breite}×${schlecht.hoehe}', '100×50');
    expect(schlecht.befunde.zeilen, containsAll([
      '[Zeichnung] schlecht.svg: kein role="img" am <svg>',
      '[Zeichnung] schlecht.svg: kein <title>',
      '[Zeichnung] schlecht.svg: kein <desc>',
      '[Zeichnung] schlecht.svg: eingebettetes Rasterbild (data:) -- dann gleich das Bild einbinden',
      '[Zeichnung] schlecht.svg: verweist auf externe Adressen (Schrift, Bild, Stil)',
      '[Zeichnung] schlecht.svg: keine <text>-Beschriftung -- Schrift in Pfade umgewandelt?',
    ]));
  });

  test('Dateiname: genau einmal entschlüsselt, kaputte %-Folgen bleiben stehen', () {
    const basis = 'https://$host/pluginfile.php/7/mod_page/content/3';
    expect(dateiname('$basis/Rabatt%2010%25.png?forcedownload=1'), 'Rabatt 10%.png');
    expect(dateiname('$basis/Gr%C3%B6%C3%9Fe.svg#oben'), 'Größe.svg');
    expect(dateiname('$basis/L%C3%B6sung_Selbsthaltung.m4v'), 'Lösung_Selbsthaltung.m4v');
    expect(dateiname('@@PLUGINFILE@@/Lösung.png'), 'Lösung.png');
    expect(dateiname('$basis/50%.png'), '50%.png');
    expect(dateiname('$basis/a%FF.png'), 'a%FF.png');
    expect(dateiname('@@PLUGINFILE@@/Rabatt%2010%25.png'), 'Rabatt 10%.png');
  });
}
