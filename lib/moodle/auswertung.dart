// Auswertung beim Lesen: was auf der Seite steht, kurz gefasst.
//
// aktivitaet_lesen legt Quelltext und Dateien vollständig ab. Um zu wissen, WAS
// darauf steht, müsste das Modell trotzdem jede Datei öffnen -- auch für
// einen Auftrag, der nur eine Stelle betrifft. Die App liest deshalb, was
// ohnehin im Quelltext und in den Dateien steht, und fasst es zusammen:
//
//   - Gliederung: Überschriften mit Zeitangaben, darunter Tabellen, Bilder,
//     Verweise, Listen und Bausteine;
//   - je Datei: Format und Maße, wo und wie sie eingebunden ist, der
//     Alternativtext, bei SVG Titel, Beschreibung und Beschriftungen;
//   - Befunde nach den Regeln der Skills (style, h1/h2, Alternativtext,
//     „hier"-Links, leere Absätze …).
//
// Hier wird nichts geändert. Die Übersicht ist ein Wegweiser; maßgeblich
// bleibt der Quelltext im Ordner.

import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'formeln.dart';

String kurz(String s, [int max = 160]) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length <= max ? t : '${t.substring(0, max - 1)}…';
}

// ---------------------------------------------------------------------------
// Befunde
// ---------------------------------------------------------------------------

/// Sammelt Befunde; gleiche Befunde werden gezählt statt wiederholt.
class Befunde {
  final Map<String, int> _anzahl = {};

  void add(String regel, String text) {
    final k = '$regel\t$text';
    _anzahl[k] = (_anzahl[k] ?? 0) + 1;
  }

  void addAll(Befunde andere) => andere._anzahl.forEach((k, n) => _anzahl[k] = (_anzahl[k] ?? 0) + n);

  bool get isEmpty => _anzahl.isEmpty;
  int get length => _anzahl.length;

  List<String> get zeilen => [
        for (final e in _anzahl.entries)
          '[${e.key.split('\t').first}] ${e.key.split('\t').last}${e.value > 1 ? ' (${e.value}×)' : ''}'
      ];
}

// ---------------------------------------------------------------------------
// Dateien: Format, Maße, bei SVG der Inhalt
// ---------------------------------------------------------------------------

class Dateiinfo {
  Dateiinfo(this.name, this.bytes);
  final String name;
  final int bytes;
  String? format;
  int? breite;
  int? hoehe;
  // SVG
  String? titel;
  String? beschreibung;
  List<String> beschriftungen = [];
  final Befunde befunde = Befunde();

  Map<String, Object?> toJson() => {
        'name': name,
        'bytes': bytes,
        'format': format,
        'breite': breite,
        'hoehe': hoehe,
        if (format == 'SVG') ...{
          'titel': titel,
          'beschreibung': beschreibung,
          'beschriftungen': beschriftungen,
        },
      };
}

int _be16(Uint8List b, int i) => (b[i] << 8) | b[i + 1];
int _le16(Uint8List b, int i) => b[i] | (b[i + 1] << 8);
int _be32(Uint8List b, int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
bool _beginnt(Uint8List b, List<int> kopf) {
  if (b.length < kopf.length) return false;
  for (var i = 0; i < kopf.length; i++) {
    if (b[i] != kopf[i]) return false;
  }
  return true;
}

Dateiinfo dateiAuswerten(String name, Uint8List b) {
  final d = Dateiinfo(name, b.length);
  if (_beginnt(b, const [0x89, 0x50, 0x4E, 0x47]) && b.length >= 24) {
    d
      ..format = 'PNG'
      ..breite = _be32(b, 16)
      ..hoehe = _be32(b, 20);
  } else if (_beginnt(b, ascii.encode('GIF8')) && b.length >= 10) {
    d
      ..format = 'GIF'
      ..breite = _le16(b, 6)
      ..hoehe = _le16(b, 8);
  } else if (_beginnt(b, const [0xFF, 0xD8])) {
    d.format = 'JPEG';
    var i = 2;
    while (i + 9 < b.length) {
      if (b[i] != 0xFF) break;
      final m = b[i + 1];
      final laenge = _be16(b, i + 2);
      final sof = m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC;
      if (sof) {
        d
          ..hoehe = _be16(b, i + 5)
          ..breite = _be16(b, i + 7);
        break;
      }
      i += 2 + laenge;
    }
  } else if (_beginnt(b, ascii.encode('RIFF')) && b.length >= 30 &&
      ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    d.format = 'WebP';
    final art = ascii.decode(b.sublist(12, 16), allowInvalid: true);
    if (art == 'VP8X') {
      d
        ..breite = 1 + (b[24] | (b[25] << 8) | (b[26] << 16))
        ..hoehe = 1 + (b[27] | (b[28] << 8) | (b[29] << 16));
    } else if (art == 'VP8L' && b.length >= 25) {
      final bits = b[21] | (b[22] << 8) | (b[23] << 16) | (b[24] << 24);
      d
        ..breite = 1 + (bits & 0x3FFF)
        ..hoehe = 1 + ((bits >> 14) & 0x3FFF);
    } else if (art == 'VP8 ') {
      d
        ..breite = _le16(b, 26) & 0x3FFF
        ..hoehe = _le16(b, 28) & 0x3FFF;
    }
  } else if (_beginnt(b, ascii.encode('%PDF'))) {
    d.format = 'PDF';
  } else if (_beginnt(b, const [0x50, 0x4B, 0x03, 0x04])) {
    // ZIP-Container: Office-Dateien sind welche; was drin ist, sagt die Endung.
    final endung = name.contains('.') ? name.split('.').last.toUpperCase() : '';
    d.format = const {'ODT', 'ODS', 'ODP', 'ODG', 'DOCX', 'XLSX', 'PPTX', 'EPUB'}.contains(endung)
        ? endung
        : 'ZIP';
  } else {
    final anfang = utf8.decode(b.length > 4096 ? b.sublist(0, 4096) : b, allowMalformed: true);
    if (anfang.contains('<svg')) _svgAuswerten(d, utf8.decode(b, allowMalformed: true));
  }
  return d;
}

int? _zahl(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^\s*([\d.]+)\s*(px)?\s*$').firstMatch(s);
  return m == null ? null : double.tryParse(m.group(1)!)?.round();
}

void _svgAuswerten(Dateiinfo d, String text) {
  d.format = 'SVG';
  final svg = html_parser.parse(text).querySelector('svg');
  if (svg == null) return;
  String? attr(String n) => svg.attributes[n] ?? svg.attributes[n.toLowerCase()];
  d.breite = _zahl(attr('width'));
  d.hoehe = _zahl(attr('height'));
  final vb = attr('viewBox')?.trim().split(RegExp(r'[\s,]+'));
  if (vb != null && vb.length == 4) {
    d.breite ??= double.tryParse(vb[2])?.round();
    d.hoehe ??= double.tryParse(vb[3])?.round();
  }
  dom.Element? kind(String n) => svg.children.where((e) => e.localName == n).firstOrNull;
  final t = kind('title');
  final ds = kind('desc');
  d.titel = t == null ? null : kurz(t.text, 200);
  d.beschreibung = ds == null ? null : kurz(ds.text, 400);
  final gesehen = <String>{};
  for (final e in svg.querySelectorAll('text')) {
    final s = kurz(e.text, 60);
    if (s.isNotEmpty && gesehen.add(s)) d.beschriftungen.add(s);
  }

  // Regeln aus dem Hausstil der Zeichnungen (Skill moodle, zeichnungen.md).
  final b = d.befunde;
  if (attr('role') != 'img') b.add('Zeichnung', '${d.name}: kein role="img" am <svg>');
  if (t == null) b.add('Zeichnung', '${d.name}: kein <title>');
  if (ds == null) b.add('Zeichnung', '${d.name}: kein <desc>');
  if (svg.querySelector('script') != null) b.add('Zeichnung', '${d.name}: enthält <script>');
  if (svg.querySelectorAll('*').any((e) => e.localName?.toLowerCase() == 'foreignobject')) {
    b.add('Zeichnung', '${d.name}: enthält <foreignObject> -- Text gehört in <text>');
  }
  if (RegExp(r'''<image\b[^>]*href\s*=\s*["']data:''', caseSensitive: false).hasMatch(text)) {
    b.add('Zeichnung', '${d.name}: eingebettetes Rasterbild (data:) -- dann gleich das Bild einbinden');
  }
  if (RegExp(r'''(?:href\s*=\s*["']|url\(\s*["']?|@import\s+["']?)(?:https?:)?//''', caseSensitive: false)
      .hasMatch(text)) {
    b.add('Zeichnung', '${d.name}: verweist auf externe Adressen (Schrift, Bild, Stil)');
  }
  if (d.beschriftungen.isEmpty) {
    b.add('Zeichnung', '${d.name}: keine <text>-Beschriftung -- Schrift in Pfade umgewandelt?');
  }
}

// ---------------------------------------------------------------------------
// Quelltext eines Editorfelds
// ---------------------------------------------------------------------------

class Punkt {
  Punkt(this.ebene, this.titel);
  final int ebene; // 0 = vor der ersten Überschrift
  final String titel;
  int? minuten;
  final List<String> inhalt = [];

  Map<String, Object?> toJson() =>
      {'ebene': ebene, 'titel': titel, 'minuten': minuten, 'inhalt': inhalt};
}

/// Ein <img> im Quelltext.
class Einbindung {
  Einbindung(this.quelle, this.lokal, this.klassen,
      {this.alt, this.breite, this.hoehe, required this.unter, this.daneben});
  final String quelle; // lokaler Dateiname bei Moodle-Dateien, sonst die Adresse
  final bool lokal;
  final Set<String> klassen;
  final String? alt;
  final String? breite;
  final String? hoehe;
  final String unter;
  final String? daneben; // Text im selben Absatz, oft die Quellenangabe

  Map<String, Object?> toJson() => {
        'quelle': quelle,
        'lokal': lokal,
        'alt': alt,
        'breite': breite,
        'hoehe': hoehe,
        'unter': unter,
        'daneben': daneben,
      };
}

enum VerweisArt { aktivitaet, kurs, datei, intern, extern, anker, mail }

class Verweis {
  Verweis(this.art, this.adresse, this.text, this.unter, {this.cmid, this.datei});
  final VerweisArt art;
  final String adresse;
  final String text;
  final String unter;
  final int? cmid;
  final String? datei;

  /// Titel und Typ des Ziels, von aktivitaet_lesen nachgetragen (nur Aktivitäten).
  String? zielTitel;
  String? zielModul;

  Map<String, Object?> toJson() => {
        'art': art.name,
        'adresse': adresse,
        'text': text,
        'unter': unter,
        if (cmid != null) 'cmid': cmid,
        if (datei != null) 'datei': datei,
        if (zielTitel != null) 'zielTitel': zielTitel,
        if (zielModul != null) 'zielModul': zielModul,
      };
}

class Feldauswertung {
  Feldauswertung(this.feld, this.zeichen);
  final String feld;
  final int zeichen;
  String? einleitung;
  bool schucu = false;
  final List<Punkt> gliederung = [];
  final List<Einbindung> bilder = [];
  final List<Verweis> verweise = [];
  final Befunde befunde = Befunde();

  /// Fehler, keine Hinweise: Die Lernenden sehen kaputten Text (formeln.dart).
  final List<String> formelfehler = [];

  int get minuten => gliederung.fold(0, (s, p) => s + (p.minuten ?? 0));

  Map<String, Object?> toJson() => {
        'feld': feld,
        'zeichen': zeichen,
        'einleitung': einleitung,
        'schucuTabelle': schucu,
        'minuten': minuten,
        'gliederung': [for (final p in gliederung) p.toJson()],
        'bilder': [for (final b in bilder) b.toJson()],
        'verweise': [for (final v in verweise) v.toJson()],
        'formelfehler': formelfehler,
        'befunde': befunde.zeilen,
      };
}

final _nichtssagend = RegExp(
    r'^(hier|link|mehr|klick|klicken|hier klicken|bitte hier klicken|video|weiter|weiterlesen|'
    r'download|herunterladen|seite|datei|diese seite|dieser link|here|click here|more|read more)$',
    caseSensitive: false);

bool _istDateiadresse(Uri u, String host) =>
    u.host == host && (u.path.startsWith('/draftfile.php/') || u.path.startsWith('/pluginfile.php/'));

/// Entschlüsselt %-Folgen genau einmal. Uri.decodeComponent wirft
/// ArgumentError bei jedem Zeichen außerhalb von ASCII, also schon bei einem
/// Umlaut, der bereits entschlüsselt ist, außerdem bei einem nackten „%";
/// kaputtes UTF-8 wie %FF gibt eine FormatException. In all diesen Fällen
/// bleibt der Text stehen, wie er ist, statt das Werkzeug abzubrechen.
String entschluesselt(String s) {
  try {
    return Uri.decodeComponent(s);
  } on ArgumentError {
    return s;
  } on FormatException {
    return s;
  }
}

/// Dateiname am Ende einer Datei-Adresse. Lesen, Auswertung und Schreiben
/// müssen denselben Namen für dateien/ bilden, darum nur diese Funktion.
String dateiname(String adresse) =>
    entschluesselt(adresse.split('?').first.split('#').first.split('/').last);

// Rahmenlinien an Tabellenelementen sind neben der SchuCu-Tabelle die zweite
// Ausnahme von „keine style-Attribute": Bei T-Konto, Summenstrich oder
// Gruppentrenner trägt die Linie die Bedeutung, und die Bootstrap-Randklassen
// reichen nicht immer. Erlaubt sind nur Stärke und Art der Linie. Eine Farbe
// nicht -- ohne Farbangabe folgt die Linie der Textfarbe, im Theme wie im
// Druck. Breite, Schrift, Hintergrund und alles andere bleiben ein Befund.
const _tabellenteile = {'table', 'thead', 'tbody', 'tfoot', 'tr', 'th', 'td', 'col', 'colgroup'};
final _rahmenEigenschaft = RegExp(r'^border(-(top|right|bottom|left))?(-(width|style))?$');
final _rahmenWert = RegExp(
    r'^(0|\d*\.?\d+(px|pt|em|rem)|thin|medium|thick|none|hidden|dotted|dashed|solid|double|groove|ridge|inset|outset)$');

/// Was in einem style-Attribut über Rahmenlinien hinausgeht; leer, wenn nichts.
List<String> _mehrAlsRahmen(String style) {
  final raus = <String>[];
  for (final d in style.split(';')) {
    final i = d.indexOf(':');
    if (i < 0) {
      if (d.trim().isNotEmpty) raus.add(d.trim());
      continue;
    }
    final name = d.substring(0, i).trim().toLowerCase();
    final wert = d.substring(i + 1).trim().toLowerCase();
    if (!_rahmenEigenschaft.hasMatch(name)) {
      raus.add(name);
    } else if (wert.split(RegExp(r'\s+')).any((w) => !_rahmenWert.hasMatch(w))) {
      raus.add('$name: $wert');
    }
  }
  return raus;
}

/// Wertet den Quelltext eines Editorfelds aus.
///
/// [host] ist der Rechner der Moodle-Instanz (für intern/extern),
/// [lokalerName] ordnet Datei-Adressen dem Namen in dateien/ zu.
Feldauswertung feldAuswerten(String feld, String html,
    {required String host, Map<String, String> lokalerName = const {}}) {
  final a = Feldauswertung(feld, html.length);
  a.formelfehler.addAll(formelFehler(html));
  var punkt = Punkt(0, '');
  a.gliederung.add(punkt);
  var letzteEbene = 2;
  final vorspann = StringBuffer();
  final kastenarten = <String>{};
  final b = a.befunde;
  String unter() => punkt.ebene == 0 ? 'vor der ersten Überschrift' : 'unter „${kurz(punkt.titel, 60)}"';

  String? lokal(String adresse) {
    if (adresse.startsWith('@@PLUGINFILE@@/')) return dateiname(adresse);
    final u = Uri.tryParse(adresse);
    if (u == null || !_istDateiadresse(u, host)) return null;
    return lokalerName[adresse] ?? dateiname(adresse);
  }

  void besuche(dom.Node n, bool inSchucu) {
    if (n is dom.Text) {
      if (inSchucu) return;
      if (punkt.ebene == 0) vorspann.write(' ${n.text}');
      if (n.text.contains('  ')) b.add('Altlast', '&nbsp;-Kette zum Einrücken ${unter()}');
      return;
    }
    if (n is! dom.Element) {
      final vorlagenAbsaetze = _unterSchucu(n);
      for (final k in n.nodes.toList()) {
        besuche(k, inSchucu || vorlagenAbsaetze.contains(k));
      }
      return;
    }
    final e = n;
    final tag = e.localName ?? '';
    final klassen = e.classes;
    final schucu = inSchucu || (tag == 'table' && klassen.contains('lernsituation'));
    if (schucu && !inSchucu) {
      a.schucu = true;
      punkt.inhalt.add('SchuCu-Tabelle');
    }
    if (!schucu) {
      final style = e.attributes['style'];
      if (style != null) {
        if (!_tabellenteile.contains(tag)) {
          b.add('Stil', 'style-Attribut an <$tag> ${unter()}');
        } else {
          final mehr = _mehrAlsRahmen(style);
          if (mehr.isNotEmpty) {
            b.add('Stil', 'style-Attribut an <$tag> mit mehr als Rahmenlinien (${mehr.join(', ')}) ${unter()}');
          }
        }
      }
      if (klassen.any((k) => k.startsWith('Mso'))) b.add('Altlast', 'Word-Rest class="Mso…" ${unter()}');
    }

    switch (tag) {
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        final ebene = int.parse(tag.substring(1));
        final titel = kurz(e.text, 100);
        if (ebene <= 2) {
          b.add('Überschrift', '<$tag> „$titel": h1 und h2 sind Moodle vorbehalten, Inhalt beginnt bei h3');
        } else if (ebene > letzteEbene + 1) {
          b.add('Überschrift', '<$tag> „$titel" folgt auf h$letzteEbene: Ebene übersprungen');
        }
        letzteEbene = ebene < 2 ? 2 : ebene;
        punkt = Punkt(ebene, titel);
        a.gliederung.add(punkt);
        return;

      case 'font' || 'center' || 'b' || 'i':
        if (!schucu) b.add('Altlast', '<$tag> ${unter()} -- <strong>/<em> oder nichts');

      case 'p':
        if (!schucu && e.text.replaceAll(' ', ' ').trim().isEmpty && e.querySelector('img, iframe, video, audio, object') == null) {
          b.add('Leerer Absatz', 'leerer Absatz ${unter()}');
        }

      case 'table':
        if (!schucu) {
          final zeilen = e.querySelectorAll('tr');
          var spalten = 0;
          var leer = 0;
          for (final z in zeilen) {
            final zellen = z.children.where((c) => c.localName == 'td' || c.localName == 'th').toList();
            if (zellen.length > spalten) spalten = zellen.length;
            for (final c in zellen) {
              if (c.localName == 'td' &&
                  c.text.replaceAll(' ', ' ').trim().isEmpty &&
                  c.querySelector('img, input, textarea, select') == null) {
                leer++;
              }
            }
          }
          punkt.inhalt.add('Tabelle ${zeilen.length}×$spalten${leer > 0 ? ' ($leer Zellen leer)' : ''}');
          if (!klassen.contains('table')) b.add('Tabelle', 'Tabelle ohne class="table" ${unter()}');
        }

      case 'ul' || 'ol':
        final li = e.children.where((c) => c.localName == 'li').length;
        punkt.inhalt.add('${tag == 'ol' ? 'nummerierte ' : ''}Liste ($li)');

      case 'img':
        final src = e.attributes['src'] ?? '';
        final name = lokal(src);
        final block = _block(e);
        String? daneben = block == null ? null : kurz(block.text, 240);
        if (daneben != null && daneben.isEmpty) {
          final folgend = block!.nextElementSibling;
          daneben = folgend != null &&
                  (folgend.classes.contains('small') ||
                      folgend.classes.contains('text-muted') ||
                      folgend.localName == 'figcaption')
              ? kurz(folgend.text, 240)
              : null;
        }
        final bild = Einbindung(name ?? src, name != null, klassen.toSet(),
            alt: e.attributes['alt'],
            breite: e.attributes['width'],
            hoehe: e.attributes['height'],
            unter: punkt.ebene == 0 ? '' : punkt.titel,
            daneben: daneben);
        a.bilder.add(bild);
        punkt.inhalt.add('Bild ${name ?? kurz(src, 60)}');
        final wer = name ?? kurz(src, 60);
        final alt = bild.alt;
        if (alt == null) {
          b.add('Alternativtext', 'fehlt: $wer');
        } else if (alt.trim().isEmpty) {
          b.add('Alternativtext', 'leer: $wer (richtig nur bei reiner Dekoration)');
        } else if (alt.trim() == name ||
            RegExp(r'\.(png|jpe?g|gif|svg|webp)$', caseSensitive: false).hasMatch(alt.trim())) {
          b.add('Alternativtext', 'ist ein Dateiname: $wer');
        }
        if (!klassen.contains('img-fluid') && !schucu) {
          b.add('Bild', 'ohne class="img-fluid" (skaliert nicht mit): $wer');
        }
        if (name == null) {
          if (src.startsWith('data:')) {
            b.add('Bild', 'als data:-Adresse im Quelltext ${unter()} -- als Datei ablegen');
          } else if (src.isNotEmpty) {
            final h = Uri.tryParse(src.startsWith('//') ? 'https:$src' : src)?.host ?? '';
            b.add('Hotlink', 'Bild von fremdem Server $h ${unter()} -- lokale Kopie ablegen');
          }
        }

      case 'a':
        final href = e.attributes['href'];
        if (href == null) break;
        final text = kurz(e.text, 140);
        final mitBild = e.querySelector('img') != null;
        final wo = punkt.ebene == 0 ? '' : punkt.titel;
        Verweis v;
        final u = Uri.tryParse(href.startsWith('//') ? 'https:$href' : href);
        if (href.startsWith('#')) {
          v = Verweis(VerweisArt.anker, href, text, wo);
        } else if (href.startsWith('mailto:')) {
          v = Verweis(VerweisArt.mail, href, text, wo);
        } else if (lokal(href) != null) {
          v = Verweis(VerweisArt.datei, href, text, wo, datei: lokal(href));
        } else if (u != null && u.host == host) {
          final m = RegExp(r'^/mod/(\w+)/view\.php$').firstMatch(u.path);
          final id = int.tryParse(u.queryParameters['id'] ?? '');
          if (m != null && id != null) {
            v = Verweis(VerweisArt.aktivitaet, href, text, wo, cmid: id);
          } else if (u.path == '/course/view.php' || u.path == '/course/section.php') {
            v = Verweis(VerweisArt.kurs, href, text, wo);
          } else {
            v = Verweis(VerweisArt.intern, href, text, wo);
          }
        } else {
          v = Verweis(VerweisArt.extern, href, text, wo);
        }
        a.verweise.add(v);
        punkt.inhalt.add(switch (v.art) {
          VerweisArt.aktivitaet => 'Verweis auf cm ${v.cmid}',
          VerweisArt.datei => 'Verweis auf Datei ${v.datei}',
          VerweisArt.extern => 'Verweis extern',
          _ => 'Verweis',
        });
        if (href.startsWith('//')) b.add('Adresse', 'protokollrelativ (//…): ${kurz(href, 80)}');
        if (href.startsWith('http://')) b.add('Adresse', 'unverschlüsselt (http://): ${kurz(href, 80)}');
        if (text.isEmpty && !mitBild) {
          b.add('Linktext', 'Verweis ohne Text ${unter()}: ${kurz(href, 80)}');
        } else if (_nichtssagend.hasMatch(text.replaceAll(RegExp(r'[.:!»«„“"]'), '').trim())) {
          b.add('Linktext', '„$text" sagt auf Papier nichts ${unter()}');
        }

      case 'iframe':
        punkt.inhalt.add('Einbettung ${kurz(Uri.tryParse(e.attributes['src'] ?? '')?.host ?? '', 40)}');

      default:
        final c4l = klassen.where((k) => k.startsWith('c4lv-')).firstOrNull;
        if (c4l == 'c4lv-estimatedtime') {
          final m = RegExp(r'\d+').firstMatch(e.text);
          if (m != null) punkt.minuten = (punkt.minuten ?? 0) + int.parse(m.group(0)!);
          return;
        }
        if (c4l != null) punkt.inhalt.add('Baustein ${c4l.substring(5)}');
        if (klassen.contains('alert')) {
          final art = klassen.where((k) => k.startsWith('alert-') && k != 'alert-dismissible').firstOrNull;
          if (art != null) {
            kastenarten.add(art);
            punkt.inhalt.add('Kasten $art');
          }
        }
    }
    final vorlagenAbsaetze = _unterSchucu(e);
    for (final k in e.nodes.toList()) {
      besuche(k, schucu || vorlagenAbsaetze.contains(k));
    }
  }

  besuche(html_parser.parseFragment(html), false);

  final v = kurz(vorspann.toString(), 200);
  a.einleitung = v.isEmpty ? null : v;
  if (a.gliederung.first.inhalt.isEmpty && a.gliederung.first.minuten == null) a.gliederung.removeAt(0);
  if (kastenarten.length > 2) {
    b.add('Kästen', 'mehr als zwei Kastenarten auf der Seite: ${kastenarten.join(", ")}');
  }
  return a;
}

/// Die Absätze direkt unter einer SchuCu-Tabelle, ohne anderes dazwischen.
///
/// Die Vorlagen (skills/lernsituation/references/schucu-*.html) setzen sie
/// dorthin: den KI-Hinweis und im Beruflichen Gymnasium davor die Legende der
/// Kompetenzbereiche mit eigener Schriftgröße. Sie gehören zum Corporate
/// Design wie die Tabelle -- ihr style ist Absicht, ihr Text keine Einleitung.
Set<dom.Node> _unterSchucu(dom.Node eltern) {
  final raus = <dom.Node>{};
  var kette = false;
  for (final k in eltern.nodes) {
    if (k is dom.Text && k.text.trim().isEmpty) continue;
    if (k is dom.Element && k.localName == 'table' && k.classes.contains('lernsituation')) {
      kette = true;
    } else if (kette && k is dom.Element && k.localName == 'p') {
      raus.add(k);
    } else {
      kette = false;
    }
  }
  return raus;
}

dom.Element? _block(dom.Element e) {
  dom.Element? x = e.parent;
  while (x != null) {
    if (const {'p', 'figure', 'li', 'td', 'th', 'div', 'blockquote'}.contains(x.localName)) return x;
    x = x.parent;
  }
  return null;
}

/// Trägt die Titel verlinkter Aktivitäten nach und prüft den Linktext:
/// Linktext = exakter Seitentitel, damit der Verweis auch auf Papier stimmt.
/// Ebenso richtig ist die Kennung vor dem Doppelpunkt („Infoblatt 1" für
/// „Infoblatt 1: VLAN-Grundlagen"): So verweisen die Blätter einer
/// Lernsituation aufeinander, und weil jedes gedruckt mit seiner Kennung
/// beginnt, findet man es auch auf Papier.
void verweiseAbgleichen(Feldauswertung a, Map<int, (String, String)> titel) {
  for (final v in a.verweise) {
    if (v.art != VerweisArt.aktivitaet) continue;
    final t = titel[v.cmid];
    if (t == null) continue;
    v
      ..zielTitel = t.$1
      ..zielModul = t.$2;
    final text = kurz(v.text, 1000), ziel = kurz(t.$1, 1000);
    final doppelpunkt = ziel.indexOf(':');
    final kennung = doppelpunkt > 0 ? ziel.substring(0, doppelpunkt).trim() : null;
    if (text != ziel && text != kennung && v.text.isNotEmpty) {
      a.befunde.add('Linktext', 'Verweis auf cm ${v.cmid} lautet „${v.text}", '
          'die Aktivität heißt „${t.$1}" -- Linktext = exakter Titel oder seine Kennung vor dem Doppelpunkt');
    }
  }
}

// ---------------------------------------------------------------------------
// Text für das Modell
// ---------------------------------------------------------------------------

String _masse(int? b, int? h) => b == null ? "" : " $b×${h ?? "?"}";

/// Die Übersicht, wie sie aktivitaet_lesen zurückgibt.
String uebersichtText(List<Feldauswertung> felder, Map<String, Dateiinfo> dateien,
    {Befunde? weitere}) {
  final t = StringBuffer();
  for (final f in felder) {
    if (f.zeichen == 0) {
      t.writeln('\nFeld ${f.feld}: leer');
      continue;
    }
    t.writeln('\nFeld ${f.feld}: ${f.zeichen} Zeichen -> ${f.feld}.html'
        '${f.minuten > 0 ? ', Zeitangaben zusammen ${f.minuten} min' : ''}');
    if (f.einleitung != null) t.writeln('  Einleitung: „${f.einleitung}"');
    for (final p in f.gliederung) {
      final einzug = '  ' * (p.ebene <= 3 ? 1 : p.ebene - 2);
      final kopf = p.ebene == 0 ? '(vor der ersten Überschrift)' : 'h${p.ebene} ${p.titel}';
      final teile = [kopf, if (p.minuten != null) '${p.minuten} min', ..._verdichtet(p.inhalt)];
      t.writeln('$einzug${teile.join(' · ')}');
    }
  }

  final eingebunden = <String, List<Einbindung>>{};
  final extern = <Einbindung>[];
  for (final f in felder) {
    for (final b in f.bilder) {
      if (b.lokal) {
        eingebunden.putIfAbsent(b.quelle, () => []).add(b);
      } else {
        extern.add(b);
      }
    }
  }
  if (dateien.isNotEmpty) {
    t.writeln('\nDateien in dateien/ (${dateien.length}):');
    for (final d in dateien.values) {
      t.writeln('  ${d.name} · ${d.bytes} Bytes · ${d.format ?? "?"}${_masse(d.breite, d.hoehe)}');
      for (final b in eingebunden[d.name] ?? const <Einbindung>[]) {
        final angezeigt = b.breite == null ? '' : ', angezeigt ${b.breite}${b.hoehe == null ? '' : '×${b.hoehe}'}';
        t.writeln('    eingebunden${b.unter.isEmpty ? '' : ' unter „${kurz(b.unter, 60)}"'}$angezeigt');
        t.writeln('    alt: ${b.alt == null ? '(fehlt)' : '„${b.alt}"'}');
        if (b.daneben != null) t.writeln('    daneben: „${b.daneben}"');
      }
      final verlinkt = [
        for (final f in felder)
          for (final v in f.verweise)
            if (v.datei == d.name) '„${v.text}"'
      ];
      if (verlinkt.isNotEmpty) t.writeln('    verlinkt als ${verlinkt.join(', ')}');
      if (d.format == 'SVG') {
        if (d.titel != null) t.writeln('    SVG-Titel: „${d.titel}"');
        if (d.beschreibung != null) t.writeln('    SVG-Beschreibung: „${d.beschreibung}"');
        if (d.beschriftungen.isNotEmpty) {
          final zeigen = d.beschriftungen.take(60).join(', ');
          final rest = d.beschriftungen.length - 60;
          t.writeln('    Beschriftungen (${d.beschriftungen.length}): $zeigen${rest > 0 ? ' … ($rest weitere)' : ''}');
        }
      }
      if (!eingebunden.containsKey(d.name) && verlinkt.isEmpty) {
        t.writeln('    (nur in einem anderen Feld oder als Adresse ohne <img>/<a> referenziert)');
      }
    }
  }
  if (extern.isNotEmpty) {
    t.writeln('\nBilder von fremden Adressen (${extern.length}):');
    for (final b in extern) {
      t.writeln('  ${kurz(b.quelle, 100)} · alt: ${b.alt == null ? '(fehlt)' : '„${b.alt}"'}');
    }
  }

  final verweise = [for (final f in felder) ...f.verweise.where((v) => v.art != VerweisArt.datei)];
  if (verweise.isNotEmpty) {
    t.writeln('\nVerweise (${verweise.length}):');
    for (final v in verweise) {
      final ziel = switch (v.art) {
        VerweisArt.aktivitaet => 'cm ${v.cmid}${v.zielModul == null ? '' : ' (${v.zielModul})'}'
            '${v.zielTitel == null ? '' : v.zielTitel == v.text ? ', Titel stimmt' : ', heißt „${v.zielTitel}"'}',
        _ => kurz(v.adresse, 100),
      };
      final text = v.text == v.adresse ? '(Adresse als Text)' : '„${v.text}"';
      t.writeln('  ${v.art.name} $text → $ziel');
    }
  }

  final alle = Befunde();
  for (final f in felder) {
    alle.addAll(f.befunde);
  }
  for (final d in dateien.values) {
    alle.addAll(d.befunde);
  }
  if (weitere != null) alle.addAll(weitere);
  final formelfehler = [for (final f in felder) for (final x in f.formelfehler) '${f.feld}.html: $x'];
  if (formelfehler.isNotEmpty) {
    t.writeln('\nFORMELFEHLER (${formelfehler.length}) -- die Lernenden sehen hier kaputten Text. Jedes Schreiben '
        'dieses Felds bricht ab, bis sie repariert sind; die Reparatur gehört in den Plan:');
    for (final z in formelfehler) {
      t.writeln('  - $z');
    }
  }
  if (alle.isEmpty) {
    t.writeln('\nBefunde: keine (geprüft: style, Überschriften, Alternativtexte, Linktexte, '
        'Adressen, leere Absätze, Altlasten, Tabellen, Zeichnungen, Formeln).');
  } else {
    t.writeln('\nBefunde nach den Regeln der Skills (${alle.length}), nur Hinweise, nichts geändert:');
    for (final z in alle.zeilen) {
      t.writeln('  - $z');
    }
  }
  return t.toString();
}

/// Fasst gleiche Einträge zusammen: „Bild a.svg, Bild b.svg" bleibt,
/// „Verweis extern ×3" statt dreimal.
List<String> _verdichtet(List<String> inhalt) {
  final zahl = <String, int>{};
  for (final s in inhalt) {
    zahl[s] = (zahl[s] ?? 0) + 1;
  }
  return [for (final e in zahl.entries) e.value > 1 ? '${e.key} ×${e.value}' : e.key];
}
