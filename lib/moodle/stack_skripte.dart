// STACK-Skriptblöcke in Fragetexten: was erlaubt ist und was nicht.
//
// STACK führt JavaScript in Fragen in abgeschotteten Rahmen aus (STACK-JS,
// seit STACK 4.4.3: <iframe sandbox="allow-scripts allow-downloads" srcdoc>);
// ein Skript darin kommt nur an die Eingabefelder der eigenen Frage. Laden
// können die Blöcke aber von überall her, und das darf nicht sein: Was auf
// einem fremden Rechner liegt, ist weder geprüft noch dauerhaft da, und jeder
// Aufruf verrät dem fremden Rechner, dass gerade jemand die Frage bearbeitet
// (IP-Adresse, Zeitpunkt).
//
// Erlaubt ist deshalb nur [[jsxgraph]] mit der JSXGraph-Version, die STACK
// mitbringt. Ohne version lädt der Block corsscripts/jsxgraphcore.min.js vom
// eigenen Moodle, über corsscripts/cors.php (jsxgraph.block.php in STACK).
// Abgewiesen wird:
//   - an [[jsxgraph]]: version (jede benannte Version außer „local" kommt von
//     jsdelivr oder cdnjs), overridejs, overridecss (beliebige Adresse);
//   - die übrigen Blöcke, die Skripte, Stile, Rahmen oder Text laden: iframe,
//     javascript, script, style, geogebra (die GeoGebra-App), parsons (mit
//     version lädt er Sortable von cdnjs), include (der Server holt src von
//     außen);
//   - im Code eines [[jsxgraph]] eine Adresse (http://, https://, ein
//     „//rechner" in Anführungszeichen) oder ein Netzzugriff (import, fetch,
//     XMLHttpRequest, WebSocket, EventSource, sendBeacon, importScripts).
// Das hält auf, was jemand -- auch Claude -- ohne Hintergedanken
// hineinschreibt; verschleierten Code erkennt keine Prüfung am Text. Die
// zweite Grenze ist die Sandbox selbst.
//
// Geprüft wird beim Bauen (stack_xml), vor jedem Import und vor jedem
// Ändern einer Frage über das Formular; beim Lesen erscheint ein Verstoß als
// Befund (auswertung.dart).

import 'moodle_zugang.dart';

/// Blöcke, die etwas laden oder ausführen und deshalb abgewiesen werden.
const Set<String> stackBloeckeGesperrt = {'iframe', 'javascript', 'script', 'style', 'geogebra', 'parsons', 'include'};

/// Attribute von [[jsxgraph]], die eine Bibliothek von anderswo holen.
const Set<String> _jsxgraphLaedt = {'version', 'overridejs', 'overridecss'};

final RegExp _jsxgraphBlock = RegExp(r'\[\[\s*jsxgraph\b([^\]]*)\]\]([\s\S]*?)\[\[\s*/\s*jsxgraph\s*\]\]');
final RegExp _attribut = RegExp(r'''([A-Za-z][\w-]*)\s*=\s*(?:"([^"]*)"|'([^']*)')''');

/// Netzzugriffe im Code, je mit dem Wort für die Meldung.
final List<(RegExp, String)> _netz = [
  (RegExp(r'https?://', caseSensitive: false), 'eine Adresse (http…)'),
  (RegExp('''["'`]\\s*//[A-Za-z0-9]'''), 'eine Adresse („//…")'),
  (RegExp(r'(^|[;{}\s])import\b', multiLine: true), 'import'),
  (RegExp(r'\bfetch\s*\('), 'fetch'),
  (RegExp(r'\bXMLHttpRequest\b'), 'XMLHttpRequest'),
  (RegExp(r'\bWebSocket\b'), 'WebSocket'),
  (RegExp(r'\bEventSource\b'), 'EventSource'),
  (RegExp(r'\bsendBeacon\b'), 'sendBeacon'),
  (RegExp(r'\bimportScripts\b'), 'importScripts'),
];

/// Ein [[jsxgraph]]-Block: Attribute und Code.
typedef JsxgraphBlock = ({Map<String, String> attribute, String code});

/// Die [[jsxgraph]]-Blöcke eines Textfelds.
List<JsxgraphBlock> jsxgraphBloecke(String text) => [
      for (final m in _jsxgraphBlock.allMatches(text))
        (
          attribute: {
            for (final a in _attribut.allMatches(m.group(1)!)) a.group(1)!.toLowerCase(): a.group(2) ?? a.group(3)!,
          },
          code: m.group(2)!,
        )
    ];

/// Die Eingaben, die ein [[jsxgraph]] über `input-ref-<name>` bindet.
Set<String> jsxgraphEingaben(String text) => {
      for (final b in jsxgraphBloecke(text))
        for (final k in b.attribute.keys)
          if (k.startsWith('input-ref-') && k.length > 'input-ref-'.length) k.substring('input-ref-'.length),
    };

/// Der Text ohne den Code der [[jsxgraph]]-Blöcke (die Blockklammern
/// bleiben). Für Prüfungen, die HTML und Formeln lesen: Code ist kein Text,
/// ein „i < n" darin wäre für einen HTML-Parser der Anfang eines Tags.
String ohneJsxgraphCode(String text) =>
    text.replaceAllMapped(_jsxgraphBlock, (m) => '[[jsxgraph${m.group(1)}]][[/jsxgraph]]');

/// Was in einem Textfeld von außen lädt, je als Satz. Leer: in Ordnung.
List<String> stackSkriptFehler(String text) {
  final aus = <String>[];
  for (final m in RegExp(r'\[\[\s*([a-z]+)\b', caseSensitive: false).allMatches(text)) {
    final name = m.group(1)!.toLowerCase();
    if (stackBloeckeGesperrt.contains(name)) {
      aus.add('Block [[$name]]: lädt oder führt Fremdes aus. Erlaubt ist nur [[jsxgraph]].');
    }
  }
  for (final (i, b) in jsxgraphBloecke(text).indexed) {
    final wo = '[[jsxgraph]] Nr. ${i + 1}';
    for (final a in _jsxgraphLaedt) {
      final w = b.attribute[a];
      if (w == null || (a == 'version' && w.trim().toLowerCase() == 'local')) continue;
      aus.add('$wo: $a="$w" lädt JSXGraph von einem fremden Rechner. Ohne $a nimmt STACK die mitgebrachte '
          'Version vom eigenen Moodle.');
    }
    for (final (muster, was) in _netz) {
      if (muster.hasMatch(b.code)) {
        aus.add('$wo: Im Code steht $was. Die Zeichnung darf nichts nachladen -- Bilder und Daten gehören in '
            'die Aufgabenvariablen ({#…#}) oder als SVG neben die Zeichnung.');
      }
    }
  }
  return aus;
}

/// Bricht ab, wenn eines der Felder einen gesperrten Block oder eine fremde
/// Quelle enthält -- bevor etwas an Moodle geht. [felder]: Feldname -> HTML.
void stackSkriptePruefen(Map<String, String> felder) {
  final fehler = [
    for (final e in felder.entries)
      for (final f in stackSkriptFehler(e.value)) '${e.key}.html: $f'
  ];
  if (fehler.isEmpty) return;
  throw MoodleFehler('Abgebrochen, nichts geschrieben: Die Frage würde von außen laden.\n'
      '${fehler.map((f) => '  - $f').join('\n')}\n'
      'Erst entfernen (Skill moodle-fragen: references/jsxgraph.md). Stand es schon vorher in Moodle, gehört das '
      'in den Plan.');
}
