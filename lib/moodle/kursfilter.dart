// Werkzeug kurs_filter: welche Textfilter in einem Kurs an sind -- vor allem,
// ob Moodle dort Formeln setzt (MathJax).
//
// Quelle ist die Seite „Filtereinstellungen" des Kurses (Kurs → Mehr →
// Filter, filter/manage.php?contextid=<Kurskontext>), die eine Lehrkraft mit
// Bearbeitungsrecht sehen darf. Sie nennt keine Personen, nur Filter und
// ihren Zustand. Gelesen wird nur; umschalten tut die Lehrkraft selbst.
//
// Was die Seite zeigt:
//   - nur Filter, die in der Website-Administration nicht deaktiviert sind.
//     Fehlt MathJax, ist er für die ganze Instanz aus; das kann die Lehrkraft
//     nicht ändern.
//   - je Filter eine Tabellenzeile: der Name in der ersten Zelle, dann eine
//     Auswahl, die wie die Kennung heißt (name="mathjaxloader"), mit „An",
//     „Aus" und „Standard (An|Aus)". Der Standard ist der Zustand darüber
//     (Kursbereich bzw. Website); Moodle schreibt ihn in die Beschriftung.
//     Die Beschriftungen sind übersetzt; erkannt wird deshalb am Wert (1 an,
//     -1 aus, 0 geerbt) und beim Erben am Vergleich mit den Texten von „An"
//     und „Aus", nie an einem Wort.
//   - Die Seite enthält ein Formular mit sesskey. Mit seinen Werten würde
//     dieselbe Adresse Filter umschalten; die Positivliste lässt sie deshalb
//     nur als GET mit contextid durch.
//   - Die Kontextnummer des Kurses liefert kein Dienst, den die App schon
//     nutzt; sie steht in M.cfg.contextid der Abschnittsseite.
//
// Einzelne Aktivitäten können einen Filter für sich abschalten. Das bleibt
// hier ungeprüft: selten, und es kostete eine Anfrage je Aktivität.

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'formular_lesen.dart';
import 'kurs.dart';
import 'moodle_zugang.dart';

/// Kennung des MathJax-Filters (filter/mathjaxloader).
const String mathjax = 'mathjaxloader';

class Textfilter {
  Textfilter(this.kennung, this.name, this.an, {required this.geerbt});
  final String kennung;
  final String name;

  /// null: Zustand nicht erkennbar.
  final bool? an;

  /// true: der Kurs übernimmt den Zustand von darüber („Standard").
  final bool geerbt;

  String get zustand => '${an == null ? 'unbekannt' : an! ? 'an' : 'aus'}${geerbt ? ' (Standard)' : ''}';
}

/// Die Filter einer Seite „Filtereinstellungen", in ihrer Reihenfolge.
List<Textfilter> filterAuswerten(String html) {
  final doc = html_parser.parse(html);
  final bereich = doc.querySelector('#region-main') ?? doc.documentElement!;
  final aus = <Textfilter>[];
  for (final s in bereich.querySelectorAll('form select')) {
    final kennung = s.attributes['name'];
    if (kennung == null || kennung.isEmpty) continue;
    final optionen = {for (final o in s.querySelectorAll('option')) o.attributes['value'] ?? '': _text(o)};
    final gewaehlt = s.querySelectorAll('option').where((o) => o.attributes.containsKey('selected')).firstOrNull ??
        s.querySelector('option');
    final wert = gewaehlt?.attributes['value'];
    bool? an;
    if (wert == '1') {
      an = true;
    } else if (wert == '-1') {
      an = false;
    } else if (wert == '0') {
      // „Standard (An)": der Text in der letzten Klammer ist der von „An"
      // oder „Aus" -- in jeder Sprache.
      final m = RegExp(r'\(([^()]*)\)\s*$').firstMatch(optionen['0'] ?? '');
      final standard = m?.group(1)?.trim();
      if (standard != null && standard == optionen['1']) an = true;
      if (standard != null && standard == optionen['-1']) an = false;
    }
    aus.add(Textfilter(kennung, _name(s) ?? kennung, an, geerbt: wert == '0'));
  }
  return aus;
}

String _text(Element e) => e.text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Der Anzeigename steht in der ersten Zelle der Tabellenzeile. Die
/// versteckte Beschriftung der Auswahl taugt nicht: Moodle schreibt dort „0"
/// hinein.
String? _name(Element s) {
  Element? z = s;
  while (z != null && z.localName != 'tr') {
    z = z.parent;
  }
  final zelle = z?.querySelector('td, th');
  return zelle == null || _text(zelle).isEmpty ? null : _text(zelle);
}

/// Was die Filter für Formeln bedeuten -- der Satz, nach dem sich die Skills
/// richten (references/html.md, „Formeln").
String formelBefund(List<Textfilter> filter) {
  final m = filter.where((f) => f.kennung == mathjax).firstOrNull;
  if (m == null) {
    return 'Formeln: NEIN. MathJax ist auf dieser Instanz in der Website-Administration abgeschaltet; die '
        'Lehrkraft kann das nicht ändern. Keine LaTeX-Formeln schreiben, als Lücke melden.';
  }
  if (m.an == null) {
    return 'Formeln: UNBEKANNT. Der Zustand von MathJax ist auf der Seite nicht zu erkennen. Keine '
        'LaTeX-Formeln schreiben, bevor die Lehrkraft nachgesehen hat (Kurs → Mehr → Filter).';
  }
  if (m.an == false) {
    return 'Formeln: NEIN, MathJax ist in diesem Kurs aus. Die Lehrkraft schaltet ihn selbst ein: Kurs → Mehr '
        '→ Filter → „${m.name}" auf „An", speichern. Danach kurs_filter erneut aufrufen.';
  }
  return 'Formeln: JA, MathJax ist in diesem Kurs an. LaTeX mit \\( … \\) im Text und \\[ … \\] abgesetzt '
      'wird gesetzt (references/html.md, „Formeln").';
}

Future<String> kursFilter(MoodleZugang moodle, int kurs) async {
  final k = await kursLesen(moodle, kurs);
  if (k.abschnitte.isEmpty) throw MoodleFehler('Kurs $kurs hat keinen Abschnitt.');
  final abschnitt = await moodle.lesen('/course/editsection.php?id=${k.abschnitte.first.id}');
  final kontext = Seitenangaben.aus(abschnitt.text).kontext;
  if (kontext == null) throw MoodleFehler('Die Kontextnummer von Kurs $kurs ist nicht zu lesen.');
  final seite = await moodle.lesen('/filter/manage.php?contextid=$kontext');
  final filter = filterAuswerten(seite.text);
  if (filter.isEmpty) {
    throw MoodleFehler('Die Filtereinstellungen von Kurs $kurs sind nicht lesbar (HTTP ${seite.status}). '
        'Darf diese Sitzung sie sehen (Kurs → Mehr → Filter)?');
  }
  return 'Textfilter in Kurs $kurs (Filtereinstellungen des Kurses; „Standard" = vom Kursbereich bzw. der '
      'Website übernommen):\n'
      '${[for (final f in filter) '  ${f.name} [${f.kennung}]: ${f.zustand}'].join('\n')}\n'
      '${formelBefund(filter)}';
}
