// Interaktive Elemente: kleine HTML-Anwendungen in einer Seite, zum
// Ausprobieren und Üben, ohne Bewertung und ohne Gedächtnis. Wofür und wie
// steht für die KI im Skill moodle (references/elemente.md).
//
// Ein Element ist eine eigene HTML-Datei im Dateibereich des Editorfelds,
// eingebunden wie ein Bild:
//   <iframe sandbox="allow-scripts" src="@@PLUGINFILE@@/name.html" title="…" height="…"></iframe>
// Warum so, gemessen auf der Testinstanz (09.10.2026):
//   - Ein Skript direkt im Text läuft in der Sitzung jedes Betrachters, auch
//     der Lehrkraft, und könnte mit deren Rechten lesen und senden -- an der
//     Sperrliste vorbei (A1). Deshalb weist die App neue Skripte im Text ab
//     (skripteImTextPruefen); was schon in Moodle stand, bleibt (E17).
//   - Im Rahmen ohne allow-same-origin hat das Element keine Herkunft:
//     Cookie, localStorage und die Moodle-Seite sperrt der Browser
//     (SecurityError).
//   - Der Inhalt im Text selbst (<iframe srcdoc>) geht nicht: Der
//     Moodle-Editor streicht srcdoc beim nächsten Speichern ersatzlos, und
//     ein Filter vor manchen Instanzen weist Formulare mit srcdoc oder
//     <script> ab (HTTP 403, auf der Testinstanz bei Abschnitt und
//     Buchkapitel, nicht bei Textseite und Textfeld). src und sandbox lässt
//     der Editor stehen, die Datei bleibt Byte für Byte; hochgeladene
//     Dateien lässt der Filter durch.
//   - Den Kopf der Datei setzt die App ([elementKopf]): eine
//     Content-Security-Policy, die jedes Laden und Senden sperrt außer
//     Stylesheets, Schriften und Bildern des eigenen Moodle, und einen
//     Wächter. Die Datei hat eine eigene Adresse; direkt geöffnet liefe sie
//     mit der Herkunft von Moodle und könnte etwa Cookies lesen, die die
//     Policy nicht schützt. Kann der Wächter Cookies lesen, ist das so, und
//     er schaltet den Rest der Datei zu Text um (<plaintext>): Kein weiteres
//     Skript läuft. Das hängt nicht daran, was im Code steht, sondern nur
//     daran, ob der Browser abschottet -- verschleierter Code kommt daran
//     nicht vorbei. Die Prüfung am Text ([elementFehler]) meldet früh, was
//     Policy und Rahmen ohnehin sperren würden, damit kein Element still
//     scheitert.
//   - Fehler im Element meldet der Kopf mit postMessage an die Seite; dort
//     hört nur das Bildschirmfoto zu (bildschirmfoto.dart), in Moodle
//     niemand.
//   - Das Stylesheet des Themes kommt von der Anmeldeseite
//     (MoodleZugang.themeStylesheet): Knöpfe und Felder sehen aus wie im Kurs.
//     Eine veraltete Revision liefert Moodle weiter aus, das Element behält
//     sein Aussehen also, wenn die Administration die Caches leert. Bindet
//     das Theme fremde Schriften ein (auf der Testinstanz Google Fonts per
//     @import), sperrt die Policy sie im Element: keine Anfrage.
//   - Gedruckt ersetzt die Druckaufbereitung „Aufgabenblatt-Druck" den Rahmen
//     durch „[Eingebetteter Inhalt – nur online verfügbar]".
//
// Nicht in Fragen und Wikis: In einer Frage gibt es STACK mit JSXGraph, und
// beide Wege schreiben keine eingebundenen Dateien.

import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

import 'auswertung.dart' show dateiname, kurz;
import 'moodle_zugang.dart';
import 'stack_skripte.dart';

const String kopfAnfang = '<!-- moocp: Kopf des Elements, setzt die App -->';
const String kopfEnde = '<!-- /moocp -->';

/// Ob eine eingebundene Datei ein Element sein kann.
bool istElementdatei(String name) => RegExp(r'\.html?$', caseSensitive: false).hasMatch(name);

/// Der Kopf, den die App an den Anfang jeder Elementdatei setzt. [basis]:
/// die Moodle-Instanz; [stylesheet]: Pfad des Theme-Stylesheets oder null.
String elementKopf(Uri basis, {String? stylesheet}) {
  final h = basis.origin;
  return [
    kopfAnfang,
    '<meta charset="utf-8">',
    '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; script-src \'unsafe-inline\'; '
        'style-src \'unsafe-inline\' $h; font-src data: $h; img-src data: $h; form-action \'none\'; '
        'base-uri \'none\'">',
    '<script>',
    // Nicht abgeschottet heißt: Cookies lesbar. Dann wird der Rest der Datei
    // Text, und kein Skript darin läuft.
    "try { document.cookie; document.write('<p>Dieses Element läuft nur eingebettet in Moodle.</p>"
        "<plaintext hidden>'); } catch (e) {}",
    "addEventListener('error', function (e) { parent.postMessage({ moocpFehler: e.message + ' (Zeile ' + "
        "e.lineno + ')' }, '*'); });",
    "addEventListener('unhandledrejection', function (e) { parent.postMessage({ moocpFehler: "
        "'Unbehandelt: ' + e.reason }, '*'); });",
    '</script>',
    if (stylesheet != null) '<link rel="stylesheet" href="$h$stylesheet">',
    kopfEnde,
  ].join('\n');
}

/// Der Kopf für die Sitzung von [moodle].
String elementKopfFuer(MoodleZugang moodle) {
  final b = moodle.basis;
  if (b == null) throw MoodleFehler('Nicht angemeldet. Bitte in der App anmelden.');
  return elementKopf(b, stylesheet: moodle.themeStylesheet);
}

final RegExp _kopf = RegExp('${RegExp.escape(kopfAnfang)}[\\s\\S]*?${RegExp.escape(kopfEnde)}\\n?');

/// Ob die Datei einen Kopf der App trägt (in welcher Fassung auch immer).
bool hatKopf(String text) => _kopf.hasMatch(text);

/// Der Text ohne den Kopf der App.
String ohneKopf(String text) => text.replaceAll(_kopf, '');

/// Setzt [kopf] direkt hinter `<head>`; ein alter Kopf der App fällt weg.
/// Davor darf nur Doctype, `<html>` und Kommentar stehen -- sonst liefe etwas
/// vor dem Wächter.
String mitKopf(String text, String kopf) {
  final t = ohneKopf(text);
  final m = RegExp(r'<head\b[^>]*>', caseSensitive: false).firstMatch(t);
  if (m == null) {
    throw MoodleFehler('braucht ein Gerüst mit <head> (<!DOCTYPE html><html lang="de"><head>…</head><body>…)');
  }
  final davor = t
      .substring(0, m.start)
      .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
      .replaceAll(RegExp(r'<!doctype[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<html\b[^>]*>', caseSensitive: false), '')
      .trim();
  if (davor.isNotEmpty) throw MoodleFehler('vor <head> steht etwas: „${kurz(davor, 40)}"');
  return '${t.substring(0, m.end)}\n$kopf${t.substring(m.end)}';
}

/// Was in einem Element nicht geht, je als Satz -- geprüft ohne den Kopf der
/// App. Leer: in Ordnung.
List<String> elementFehler(String text) {
  final t = ohneKopf(text);
  final aus = <String>[];
  void wenn(String muster, String satz, {bool gross = false}) {
    if (RegExp(muster, caseSensitive: gross).hasMatch(t)) aus.add(satz);
  }

  // Adressen in Attributen, CSS und Zeichenketten. Namensräume des W3C
  // (SVG, XLink, MathML) sind keine Quelle, createElementNS braucht sie.
  for (final m in RegExp('''(?:[=("'`]\\s*|@import\\s+)((?:https?:)?//[^\\s"'`)<>]+)''', caseSensitive: false)
      .allMatches(t)) {
    final adresse = m.group(1)!;
    if (RegExp(r'^(?:https?:)?//www\.w3\.org/', caseSensitive: false).hasMatch(adresse)) continue;
    aus.add('Adresse „${kurz(adresse, 60)}": Ein Element lädt nichts und verweist nirgendwohin -- Bilder als SVG '
        'im Element, Verweise in den Text der Seite.');
    break;
  }
  for (final (muster, was) in netzSchnittstellen) {
    if (muster.hasMatch(t)) aus.add('Im Code steht $was: Ein Element lädt und sendet nichts.');
  }
  wenn(r'\b(?:localStorage|sessionStorage|indexedDB)\b|document\s*\.\s*cookie',
      'Speichern im Browser: Ein Element merkt sich nichts, und der Rahmen sperrt es.', gross: true);
  wenn(r'(?<![\w$.])(?:window\s*\.\s*)?(?:parent|top|opener)\s*\.',
      'Zugriff auf die Moodle-Seite (parent/top/opener): Der Rahmen sperrt ihn.', gross: true);
  wenn(r'<script\b[^>]*\bsrc\s*=', 'Nachgeladenes Skript (<script src>): Der Code steht im Element selbst.');
  wenn(r'<(?:iframe|frame|object|embed)\b', 'Rahmen oder Einbettung im Element: Ein Element bettet nichts ein.');
  wenn(r'<meta\b[^>]*http-equiv', '<meta http-equiv> setzt nur die App (im Kopf).');
  wenn(r'<base\b', '<base> verbiegt Adressen und ist gesperrt.');
  return aus;
}

/// Stellen im Text eines Editorfelds, an denen Code läuft: `<script>`,
/// Ereignis-Attribute (onclick …), `javascript:`-Adressen und `srcdoc`. Jede
/// Stelle als voller Text, damit [skripteImTextPruefen] alte von neuen
/// unterscheiden kann.
List<String> skriptstellen(String html) {
  if (!RegExp(r'script|\bon[a-z]+\s*=|srcdoc', caseSensitive: false).hasMatch(html)) return const [];
  final aus = <String>[];
  // Der Code einer STACK-Zeichnung ist kein HTML; ein „a<b" darin hielte der
  // Parser für einen Tag (stack_skripte.dart prüft ihn eigens).
  for (final e in html_parser.parseFragment(ohneJsxgraphCode(html)).querySelectorAll('*')) {
    final tag = e.localName ?? '';
    if (tag == 'script') aus.add('<script>${e.text}</script>');
    for (final a in e.attributes.entries) {
      final k = '${a.key}'.toLowerCase(), w = a.value;
      if (k.startsWith('on')) {
        aus.add('<$tag $k="$w">');
      } else if (k == 'srcdoc') {
        aus.add('<$tag srcdoc="$w">');
      } else if (w.replaceAll(RegExp(r'[\s\x00-\x1f]'), '').toLowerCase().startsWith('javascript:')) {
        aus.add('<$tag $k="$w">');
      }
    }
  }
  return aus;
}

/// Ein Rahmen, der eine HTML-Datei des Felds einbindet.
typedef ElementRahmen = ({String datei, bool abgeschottet, String markup});

/// Die Rahmen im Text eines Editorfelds, die eine Elementdatei einbinden.
/// Abgeschottet heißt: `sandbox` mit genau `allow-scripts` -- jedes weitere
/// Recht (allow-same-origin, allow-top-navigation …) höbe die Abschottung
/// ganz oder teilweise auf.
List<ElementRahmen> elementRahmen(String html) {
  if (!html.toLowerCase().contains('<iframe')) return const [];
  return [
    for (final e in html_parser.parseFragment(ohneJsxgraphCode(html)).querySelectorAll('iframe'))
      if (_feldDatei(e.attributes['src'] ?? '') case final datei? when istElementdatei(datei))
        (
          datei: datei,
          abgeschottet: (e.attributes['sandbox'] ?? '-').trim().split(RegExp(r'\s+')).toSet().join(' ') ==
              'allow-scripts',
          markup: e.outerHtml,
        )
  ];
}

String? _feldDatei(String adresse) {
  final a = adresse.trim();
  if (a.startsWith('@@PLUGINFILE@@/') || a.contains('/draftfile.php/') || a.contains('/pluginfile.php/')) {
    return dateiname(a.replaceAll('&amp;', '&'));
  }
  return null;
}

Map<String, int> _zaehlen(Iterable<String> l) {
  final m = <String, int>{};
  for (final s in l) {
    m[s] = (m[s] ?? 0) + 1;
  }
  return m;
}

/// Was in [neu] dazukommt, gegen [alt] gezählt.
List<String> _dazu(List<String> neu, List<String> alt) {
  final vorher = _zaehlen(alt);
  final aus = <String>[];
  for (final s in neu) {
    final n = vorher[s] ?? 0;
    if (n > 0) {
      vorher[s] = n - 1;
    } else {
      aus.add(s);
    }
  }
  return aus;
}

/// Bricht ab, wenn ein Feld eine neue Stelle bekommt, an der Code läuft, oder
/// einen neuen Rahmen ohne Abschottung -- bevor etwas an Moodle geht.
/// [felder]: Feldname -> HTML; [alt]: der Stand beim Lesen (leer beim
/// Anlegen). Was schon in Moodle stand, darf bleiben. [elementeErlaubt]:
/// false in Fragen und Wikis.
void skripteImTextPruefen(Map<String, String> felder,
    {Map<String, String> alt = const {}, bool elementeErlaubt = true}) {
  final fehler = <String>[];
  for (final e in felder.entries) {
    for (final s in _dazu(skriptstellen(e.value), skriptstellen(alt[e.key] ?? ''))) {
      fehler.add('${e.key}.html: ${kurz(s, 80)}');
    }
    final rahmen = elementRahmen(e.value);
    if (!elementeErlaubt) {
      for (final r in rahmen) {
        fehler.add('${e.key}.html: Element ${r.datei} -- hier nicht vorgesehen (nur in Textseite, Textfeld, Buchkapitel, '
            'Abschnitt und Beschreibung einer Aktivität)');
      }
      continue;
    }
    final offen = [for (final r in rahmen) if (!r.abgeschottet) r.markup];
    final altOffen = [for (final r in elementRahmen(alt[e.key] ?? '')) if (!r.abgeschottet) r.markup];
    for (final m in _dazu(offen, altOffen)) {
      fehler.add('${e.key}.html: Rahmen ohne sandbox="allow-scripts": ${kurz(m, 80)}');
    }
  }
  if (fehler.isEmpty) return;
  throw MoodleFehler('Abgebrochen, nichts geschrieben: Code ohne Abschottung.\n'
      '${fehler.map((f) => '  - $f').join('\n')}\n'
      'Code im Text oder in einem offenen Rahmen liefe in der Sitzung jedes Betrachters, auch der Lehrkraft. '
      'Interaktives gehört als Element in einen abgeschotteten Rahmen (Skill moodle: references/elemente.md). '
      'Was schon in Moodle stand, darf bleiben.');
}

bool _gleich(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Bereitet die Elementdateien vor, die [felder] einbinden: prüft jede, die
/// neu ist oder sich gegen [stand] geändert hat, und setzt [kopf] ein. Die
/// Datei im Arbeitsordner wird dabei umgeschrieben, damit Hochladen, Freigabe
/// und Rückleseprobe dieselben Bytes sehen. Unverändertes bleibt, wie es in
/// Moodle steht. Bricht ab, bevor etwas an Moodle geht.
void elementeVorbereiten(String quelle, Map<String, String> felder, String kopf, {String? stand}) {
  final fehler = <String>[];
  final namen = {for (final h in felder.values) for (final r in elementRahmen(h)) r.datei};
  for (final n in namen) {
    final f = File(p.join(quelle, 'dateien', n));
    if (!f.existsSync()) continue; // meldet der Aufrufer als fehlend
    final bytes = f.readAsBytesSync();
    if (stand != null) {
      final s = File(p.join(stand, 'dateien', n));
      if (s.existsSync() && _gleich(bytes, s.readAsBytesSync())) continue;
    }
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      fehler.add('$n: kein Text in UTF-8');
      continue;
    }
    final probleme = elementFehler(text);
    if (probleme.isNotEmpty) {
      fehler.addAll(probleme.map((x) => '$n: $x'));
      continue;
    }
    try {
      final neu = mitKopf(text, kopf);
      if (neu != text) f.writeAsStringSync(neu, encoding: utf8);
    } on MoodleFehler catch (x) {
      fehler.add('$n: ${x.meldung}');
    }
  }
  if (fehler.isEmpty) return;
  throw MoodleFehler('Abgebrochen, nichts geschrieben: Elemente, die so nicht laufen würden.\n'
      '${fehler.map((f) => '  - $f').join('\n')}\n'
      'Wie ein Element aussieht: Skill moodle, references/elemente.md.');
}
