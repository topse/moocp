// Formelfehler: Stellen im HTML, an denen MathJax eine LaTeX-Formel nicht
// oder falsch setzen würde. Die Regeln stehen für die KI in
// skills/gemeinsam/html.md („Formeln"); dasselbe prüft das Prüfskript des
// Skills lernsituation am Entwurf (formel_fehler).
//
// Ein Formelfehler ist ein Syntaxfehler, kein Schönheitsfehler: Die
// Lernenden sehen kaputten Text. Deshalb bricht jedes Schreiben ab, dessen
// HTML einen enthält (formelnPruefen), auch wenn er schon vorher in Moodle
// stand -- repariert wird er im Plan, nicht übergangen. Beim Lesen erscheint
// er als Befund.
//
// Was hier zählt, gemessen auf der Testinstanz:
//   - Ein rohes „<" in einer Formel hält der Browser für den Anfang eines
//     Tags. Aus „\(x<y\)" wurde „\(x", der Rest verschwand, nichts war
//     gesetzt. Moodle speichert das Zeichen unverändert; die Rückleseprobe
//     sieht deshalb keinen Unterschied. Im geparsten HTML zeigt es sich als
//     Formel ohne Ende.
//   - Einfache Dollarzeichen setzt Moodles MathJax nicht; „$E = mc^2$" bleibt
//     so stehen. Gemeldet wird nur, wenn zwischen ihnen ein LaTeX-Befehl
//     steht -- ein Preis wie „5 $ bis 10 $" ist kein Fehler.
//   - In <code> setzt MathJax nichts; dort darf LaTeX als Beispiel stehen.
//
// Geprüft wird je Block (Absatz, Zelle, Listenpunkt …): Anfang und Ende einer
// Formel müssen im selben Block stehen, und zwar im selben Textstück. Liegt
// ein Tag dazwischen (<strong>, <br>), steht HTML in der Formel. „\\" ist ein
// Zeilenumbruch in LaTeX, auch als „\\[4pt]" -- kein Formelanfang.

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'moodle_zugang.dart';

/// Elemente, die einen neuen Block beginnen: Eine Formel darf nicht über
/// ihre Grenze reichen.
const Set<String> _bloecke = {
  'p', 'div', 'li', 'ul', 'ol', 'dl', 'dt', 'dd', 'table', 'thead', 'tbody', 'tfoot', 'tr', 'td', 'th', //
  'caption', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote', 'figure', 'figcaption', 'section',
  'article', 'header', 'footer', 'aside', 'details', 'summary', 'hr', 'form', 'fieldset',
};

/// Elemente, deren Inhalt MathJax nicht setzt oder der kein Text ist.
const Set<String> _auslassen = {'code', 'pre', 'script', 'style', 'svg', 'math', 'textarea', 'select'};

/// Die Formelfehler eines HTML-Felds, je einer als Satz. Leer: in Ordnung.
List<String> formelFehler(String html) {
  final bloecke = <List<String>>[[]];
  void besuche(dom.Node n) {
    if (n is dom.Text) {
      bloecke.last.add(n.text);
      return;
    }
    if (n is dom.Element) {
      final tag = n.localName ?? '';
      if (_auslassen.contains(tag)) return;
      // Die SchuCu-Tabelle folgt ihrer Vorlage und wird nicht geprüft.
      if (tag == 'table' && n.classes.contains('lernsituation')) return;
      final block = _bloecke.contains(tag);
      if (block) bloecke.add([]);
      for (final k in n.nodes) {
        besuche(k);
      }
      if (block) bloecke.add([]);
      return;
    }
    for (final k in n.nodes) {
      besuche(k);
    }
  }

  besuche(html_parser.parseFragment(html));
  return [for (final b in bloecke) if (b.isNotEmpty) ..._blockPruefen(b)];
}

String _kurz(String s, [int n = 40]) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length <= n ? t : '${t.substring(0, n)}…';
}

/// Prüft die Textstücke eines Blocks. Ein Textstück endet an jedem Tag.
List<String> _blockPruefen(List<String> stuecke) {
  final s = stuecke.join();
  // Zu jeder Stelle das Textstück, aus dem sie stammt.
  final stueck = <int>[];
  for (var i = 0; i < stuecke.length; i++) {
    stueck.addAll(List.filled(stuecke[i].length, i));
  }
  final aus = <String>[];
  final ohneFormeln = StringBuffer();
  String? offen; // '(' oder '['
  var anfang = -1;
  var frei = 0; // ab hier Text außerhalb von Formeln
  var i = 0;
  while (i < s.length) {
    if (s[i] != r'\' || i + 1 >= s.length) {
      i++;
      continue;
    }
    final n = s[i + 1];
    if (n == '(' || n == '[') {
      if (offen != null) {
        aus.add('Formel ohne Ende: „${_kurz(s.substring(anfang, i))}" -- vor dem nächsten Formelanfang fehlt '
            '${offen == '(' ? r'\)' : r'\]'}.');
      } else {
        ohneFormeln.write(s.substring(frei, i));
      }
      offen = n;
      anfang = i;
    } else if (n == ')' || n == ']') {
      final passt = (n == ')' && offen == '(') || (n == ']' && offen == '[');
      if (!passt) {
        aus.add('Formelende „\\$n" ohne Anfang: „${_kurz(s.substring(i - (i < 30 ? i : 30), i + 2))}".');
      } else if (stueck[anfang] != stueck[i + 1]) {
        aus.add('HTML in der Formel „${_kurz(s.substring(anfang, i + 2))}": Zwischen Anfang und Ende steht ein '
            'Tag. Hervorhebung und Zeilenumbruch macht LaTeX selbst.');
      }
      if (passt) {
        offen = null;
        frei = i + 2;
      }
    }
    // Jeder andere Befehl, auch „\\" (Zeilenumbruch, „\\[4pt]") und „\$",
    // ist hier zu Ende.
    i += 2;
  }
  if (offen != null) {
    aus.add('Formel ohne Ende: „${_kurz(s.substring(anfang))}" -- ${offen == '(' ? r'\)' : r'\]'} fehlt im selben '
        'Absatz. Steht ein rohes < darin? Als &lt; oder \\lt schreiben.');
  } else {
    ohneFormeln.write(s.substring(frei));
  }
  final dollar = RegExp(r'(?<![\\$])\$(?!\$)([^$]*?\\[A-Za-z]+[^$]*?)(?<![\\$])\$(?!\$)').firstMatch(ohneFormeln.toString());
  if (dollar != null) {
    aus.add(r'LaTeX zwischen einfachen $ wird nicht gesetzt: „' '${_kurz(dollar.group(0)!)}' r'" -- \( … \) schreiben.');
  }
  return aus;
}

/// Bricht ab, wenn eines der Felder einen Formelfehler hat -- bevor etwas an
/// Moodle geht. [felder]: Feldname -> HTML.
void formelnPruefen(Map<String, String> felder) {
  final fehler = [
    for (final e in felder.entries)
      for (final f in formelFehler(e.value)) '${e.key}.html: $f'
  ];
  if (fehler.isEmpty) return;
  throw MoodleFehler('Abgebrochen, nichts geschrieben: Formelfehler, die Lernenden sähen kaputten Text.\n'
      '${fehler.map((f) => '  - $f').join('\n')}\n'
      'Erst beheben (Skill: references/html.md, „Formeln"). Stand der Fehler schon vorher in Moodle, gehört die '
      'Reparatur in den Plan.');
}
