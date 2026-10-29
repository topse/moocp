# JSXGraph: Zeichnungen in STACK-Fragen

STACK bringt die Bibliothek JSXGraph mit. Der Block `[[jsxgraph]]` im Fragetext zeichnet ein Koordinatensystem mit Kurven, Punkten, Zeigern und Schiebereglern, und zwar aus den Aufgabenvariablen: Jede Variante der Frage bekommt ihre eigene Zeichnung. Punkte und Regler lassen sich an ein Eingabefeld binden; dann ist das Ziehen selbst die Antwort, und der Rückmeldebaum bewertet die Lage wie jede andere Eingabe. Diese Referenz baut auf `stack.md` auf – Aufgabenvariablen, Rückmeldebaum und Testfälle funktionieren hier genauso.

## Wann eine Zeichnung – und wann nicht

Eine Zeichnung kostet beim Bauen, bei der Bedienung und bei der Barrierefreiheit. Sie lohnt sich, wo sie etwas leistet, was Text und Eingabefeld nicht können. Drei Zwecke tragen:

| Zweck | Was die Zeichnung leistet | Beispiele | AFB |
|---|---|---|---|
| **Darstellung aus den Zufallswerten** | Jede Variante hat ihr eigenes Bild, und das Bild passt immer zur Aufgabe – eine feste SVG mit 12 V neben einer Aufgabe mit 9 V ist schlimmer als keine. Gegen Abschreiben wirkt das wie variierende Zahlen. | Kennlinie eines Widerstands mit zufälligem R, Sinusverlauf mit zufälliger Amplitude und Periode, Ladekurve eines Kondensators | wie die Aufgabe |
| **Ablesen und Deuten als Ziel** | Diagramme lesen ist eine eigene Kompetenz, und der Wechsel zwischen Graph, Gleichung und Zahlenwert ist es, der Verständnis zeigt. Die Zeichnung ist hier der Gegenstand, nicht die Illustration. | Arbeitspunkt ablesen, Steigung bestimmen und als Widerstand deuten, Periodendauer und Frequenz ablesen | I–II |
| **Antworten durch Handeln** | Die Antwort ist eine Lage, keine vorformulierte Zahl. Wer einen Punkt setzen soll, muss wissen, wo er hingehört; Raten zwischen vier Optionen gibt es nicht. | Arbeitspunkt einzeichnen, Gerade durch Messpunkte legen, Regler so stellen, dass die Kurve zu den Messwerten passt (Parameter bestimmen), Zeiger einzeichnen | II–III |

Keine Zeichnung, sondern etwas anderes:

- **Gleiche Werte für alle und nichts zu bewegen:** eine SVG (`zeichnungen.md`). Sie ist einfacher, druckbar und braucht kein Skript.
- **Ziehen als Spielerei:** Prüft eine Zahl im Eingabefeld dasselbe, ist das Eingabefeld ehrlicher. Das Ziehen ist dann eine zusätzliche Hürde, die mit dem Fach nichts zu tun hat.
- **Genauigkeit, die die Hand nicht liefert:** Wer einen Punkt auf 0,01 genau setzen muss, scheitert an der Maus, nicht am Wissen. Entweder rastet der Punkt auf das Raster der Aufgabe ein, oder die Toleranz entspricht dem, was man auf Papier ablesen könnte – sonst eine Zahl eingeben lassen.
- **Ein Test, der auch auf Papier laufen muss** (Nachschreibtermin, Ausfall der Technik): Eine Zeichnung zum Ziehen hat keine Papierfassung. Dann gehört eine zweite Frage mit Bild und Eingabefeld in den Plan, oder die Frage bleibt ohne Ziehen.

Schlag eine Zeichnung vor, wo einer der drei Zwecke passt, und sag, welcher es ist. Schlägt die Lehrkraft eine vor, wo keiner passt, sag das einmal mit dem Grund und bau dann, was sie entscheidet.

## Was die Lernenden brauchen

**Erst bedienen, dann bewertet werden.** Die erste Begegnung mit einer Zeichnung zum Ziehen soll keine bewertete sein. Wer zum ersten Mal einen Punkt einrasten lassen muss, verliert in einer Klassenarbeit Zeit und Punkte an die Bedienung. Schlag deshalb vor einer bewerteten Frage eine Übungsfrage mit derselben Bedienung vor, etwa in einem Übungstest mit beliebig vielen Versuchen.

**Die Handlung steht im Fragetext, samt dem, was zählt.** „Ziehe den Punkt P auf den Arbeitspunkt" sagt, was zu tun ist; dazu gehört, was gewertet wird: die Lage beim Absenden. Ein Element, das niemand bewegt hat, schreibt nichts ins Eingabefeld. Ohne Vorkehrung bekäme dieser Teil dann weder Punkte noch Rückmeldung (gemessen 08.10.2026); deshalb lässt `stack_xml` gebundene Eingaben leer zu, und der Baum meldet als Erstes „nicht bearbeitet – 0 Punkte" (`stack.md`, „Teile ohne Antwort"). Das steht auch im Text, damit niemand die Ausgangslage für eine Antwort hält. Die Ausgangslage liegt deshalb sichtbar daneben, nie zufällig schon richtig.

**Fair bewerten: Raster und Toleranz passen zusammen.** Rastet der Punkt auf eine Schrittweite ein (`snapToGrid`), wählst du die Werte der Aufgabe auf diesem Raster – wie in `stack.md`, „Zufallszahlen so wählen, dass schöne Ergebnisse entstehen" – und die Toleranz im Knoten klein. Ohne Raster ist die Toleranz die Ablesegenauigkeit: etwa die halbe kleinste Teilung der Achse, so viel, wie man auf Papier auch zugestehen würde – und der Text nennt sie („auf 0,05 A genau"). Für Zahlen, die aus der Zeichnung abgelesen und weitergerechnet werden, gilt die Regel zu Einheit und Rundung im SKILL.md („Zahlenergebnisse").

**Typische Fehler bekommen einen eigenen Knoten.** Die Lage verrät viel: richtige Spannung, aber neben der Kennlinie; auf der falschen von zwei Kennlinien; Ablesefehler um eine Teilung. Jeder solche Fall bekommt seinen Knoten, eine Rückmeldung, die sagt, was zu prüfen ist, und wo es angemessen ist, Teilpunkte – genau wie bei Rechenfragen.

**Die Zeichnung ist lesbar wie eine auf Papier.** Achsen mit Größe und Einheit beschriftet („U in V"), ein Regler mit Größe, Wert und Einheit („R = 47 Ω"), eine Teilung, die man ablesen kann, ein Punkt, der groß genug ist, um ihn mit dem Finger zu treffen. Beim Regler setzt `name: 'R'` das „R = " vor den Wert und `unitLabel: ' Ω'` die Einheit dahinter; `suffixLabel` ersetzt dagegen das „R = " und taugt nicht für die Einheit. Farben aus dem Hausstil (`zeichnungen.md`): `#14618f` für das Gegebene, `#a8420a` für das, was die Lernenden bewegen, `#1f2933` für Achsen und Schrift.

**Barrierefreiheit gehört in den Plan.** Ziehen verlangt Maus, Finger oder Stift und den Blick aufs Bild. Die Tastatur ersetzt die Hand: Jedes Element zum Ziehen bekommt `tabindex: 0` (siehe „Der Block"), dann erreicht man es mit der Tabulatortaste und bewegt es mit den Pfeiltasten. Den Blick aufs Bild ersetzt nichts. Für Lernende, die das Bild nicht sehen können, ist ein Nachteilsausgleich nötig: dieselbe Aufgabe als zweite Frage mit Eingabefeld statt Ziehen, in einer eigenen Fassung des Tests für diese Lernenden. Frag die Lehrkraft, ob das in der Lerngruppe gebraucht wird; die App sieht keine Teilnehmenden und kann es nicht wissen.

## Was die Lehrkraft organisieren muss

**Die Bedienung prüft die Lehrkraft, die Bewertung prüfen die Testfälle.** Die App kann nicht ziehen: `bildschirmfoto` zeigt die Zeichnung im Ausgangszustand, und damit, ob sie überhaupt erscheint und lesbar ist. Ob der Punkt einrastet, das Absenden die Lage überträgt und die Rückmeldung passt, sieht nur, wer in der Vorschau selbst zieht. Nach dem Anlegen sagst du der Lehrkraft genau, was sie dort tun soll: welchen Punkt wohin ziehen, absenden, welche Rückmeldung zu erwarten ist – einmal richtig, einmal mit dem eingeplanten typischen Fehler, einmal ohne zu ziehen und einmal nur mit Tabulator- und Pfeiltasten. Die Vorschau öffnet sie unter `/question/bank/previewquestion/preview.php?id=<questionid>&cmid=<sammlung>`.

**Auf den Geräten der Klasse ausprobieren.** Die Zeichnung läuft im Browser auf Rechner, Tablet und Telefon; Ziehen auf einem kleinen Bildschirm ist aber mühsam. Wird mit einer Prüfungsumgebung gearbeitet (etwa Safe Exam Browser), gehört ein Durchlauf darin vor den ersten bewerteten Einsatz.

**Wer die Frage in Moodle selbst ändert, schaltet den Editor ab.** Der Texteditor TinyMCE kann den Code im Block zerlegen. Vor einer Änderung in der Moodle-Oberfläche stellt die Lehrkraft deshalb in ihren persönlichen Einstellungen unter den Editor-Einstellungen den einfachen Textbereich ohne Formatierung ein und danach wieder ihren gewohnten Editor. Über die App geändert (`frage_lesen`, `aendern`) ist kein Editor beteiligt; Code mit `<` und `&&` kam dabei unverändert an (gemessen 08.10.2026).

## Was im Plan steht

Vor dem Bauen nennt der Plan (Abschnitt „Erst der Plan, dann das Schreiben" im SKILL.md) zu jeder Frage mit Zeichnung, zusätzlich zu Typ, Punkten und AFB:

- den **Zweck** aus der Tabelle oben und was die Lernenden tun: nur ablesen, oder ziehen – was, wohin;
- **Raster und Toleranz**, und woraus die Werte gewählt werden, damit sie auf dem Raster liegen;
- die **typischen Fehler** mit Teilpunkten und Rückmeldung;
- ob eine **Übungsfrage** vorausgeht, ob eine **Papierfassung** nötig ist und ob eine Variante **ohne Ziehen** gebraucht wird.

## Was die App abweist – und warum

Die Zeichnung läuft im Browser jeder und jedes Lernenden. Lädt sie etwas von einem fremden Rechner, erfährt der bei jedem Aufruf, dass gerade jemand die Frage bearbeitet (IP-Adresse, Zeitpunkt); was dort liegt, ist nicht geprüft und irgendwann weg. Deshalb nimmt die App nur, was vom eigenen Moodle kommt: JSXGraph, wie STACK es mitbringt. Beim Bauen, vor dem Import und vor jedem Ändern einer Frage bricht sie sonst ab, beim Lesen meldet sie es als Befund `[Skript]`:

- an `[[jsxgraph]]` die Attribute `version` (außer `"local"`), `overridejs`, `overridecss` – sie holen JSXGraph von jsdelivr, cdnjs oder einer beliebigen Adresse;
- die Blöcke `[[iframe]]`, `[[javascript]]`, `[[script]]`, `[[style]]`, `[[geogebra]]`, `[[parsons]]`, `[[include]]`;
- im Code eine Adresse oder ein Nachladen: `http://`, `https://`, `"//rechner"`, `import`, `fetch`, `XMLHttpRequest`, `WebSocket`, `EventSource`, `sendBeacon`.

Ein Bild gehört deshalb nicht in die Zeichnung, sondern als SVG daneben (`zeichnungen.md`). Steht so etwas in einer bestehenden Frage, die du ändern sollst, gehört die Reparatur in den Plan; Geogebra-Applets und Ähnliches aus fremder Hand kann die App nicht übernehmen – das ist ein Fall für den Abschnitt „Was der Skill nicht kann" im SKILL.md. Formeln in der Zeichnung setzt MathJax von derselben Adresse, die jede Moodle-Seite der Instanz benutzt; das ist keine zusätzliche Quelle.

## Der Block

```
[[jsxgraph input-ref-ans2="ans2Ref" width="480px" height="320px"]]
var board = JXG.JSXGraph.initBoard(divid, {
  boundingbox: [-2, 0.55, 26, -0.06], axis: true, showCopyright: false, showNavigation: false,
  intl: {enabled: true, locale: 'de-DE'}
});
board.create('functiongraph', [function (u) { return u / {#R#}; }, 0, 25],
  {strokeColor: '#14618f', strokeWidth: 3, fixed: true});
var p = board.create('point', [3, 0.45],
  {name: 'P', snapToGrid: true, snapSizeX: 1, snapSizeY: 0.05, strokeColor: '#a8420a', fillColor: '#a8420a', tabindex: 0});
stack_jxg.bind_point(ans2Ref, p);
[[/jsxgraph]]
```

| Teil | Bedeutung |
|---|---|
| `width`, `height` | Größe der Zeichnung; mit `aspect-ratio` genügt eine der beiden |
| `input-ref-ans2="ans2Ref"` | bindet die Eingabe `ans2`; im Code heißt sie dann `ans2Ref` |
| `style="empty"` | ohne Rahmen; nur Stile, die STACK mitbringt |
| `divid` | der Ort der Zeichnung – immer `initBoard(divid, …)` |
| `intl: {enabled: true, locale: 'de-DE'}` | Zahlen an den Achsen mit Komma, wie STACK sie im Text setzt; ohne steht dort 0.45 neben 0,1 im Text (gemessen 08.10.2026) |
| `tabindex: 0` | an jedem Element zum Ziehen: erreichbar mit der Tabulatortaste, bewegt mit den Pfeiltasten, eingerastet und gewertet wie beim Ziehen (gemessen 08.10.2026); ohne geht es nur mit Maus oder Finger |
| `{#R#}` | der Wert einer Aufgabenvariablen im Code |
| `{@R@}` | derselbe Wert gesetzt, für den Text um die Zeichnung |

**Der Block steht für sich**, nicht in einem `<p>`: davor und danach Absätze nach `html.md`. Der Code ist kein HTML; die App prüft ihn nicht auf Formeln und HTML-Regeln, wohl aber auf fremde Quellen.

**Gerechnet wird in den Aufgabenvariablen, nicht im Code.** `{#…#}` setzt den Wert ein, wie Maxima ihn schreibt. Ganze Zahlen und Brüche wie `3/20` rechnet JavaScript selbst aus; `sqrt(2)`, `%pi` oder ein Term nicht. Solche Werte vorher in den Aufgabenvariablen mit `float(…)` zur Zahl machen. Eine Funktion, die die Lernenden nicht sehen sollen, schreibst du als JavaScript-Funktion mit eingesetzten Werten, wie oben.

**Bindungen**, aus der STACK-Dokumentation (`stack_jxg`):

| Funktion | Wert in der Eingabe | wofür |
|---|---|---|
| `bind_point(ref, p)` | `[x, y]` | ein Punkt |
| `bind_slider(ref, s)` | `x` | ein Schieberegler |
| `bind_point_dual(ref, p1, p2)` | `[[x1, y1], [x2, y2]]` | zwei Punkte, etwa eine Gerade |
| `bind_point_relative(ref, p1, p2)` | `[[x1, y1], [dx, dy]]` | Anfang und Richtung, etwa ein Zeiger |
| `bind_point_direction(ref, p1, p2)` | `[[x1, y1], [Winkel, Länge]]` | ein Zeiger in Polarform |
| `bind_list_of(ref, [p1, p2, s])` | Liste der Werte | mehrere Elemente in einer Eingabe |

`stack_jxg.starts_moved(p)` lässt ein Element als bewegt gelten, schon bevor jemand es anfasst – nur, wenn die Ausgangslage eine gültige Antwort sein darf. `stack_jxg.define_group([p1, p2])` sorgt dafür, dass mit einem Element alle übertragen werden.

## Die Eingabe und der Rückmeldebaum

Eine Eingabe, die nur die Lage hält, bekommt in `stack_xml` die Angabe `gebunden: true`, Typ `algebraic`. Dann setzt `stack_xml` ihre Platzhalter selbst, verborgen ans Ende des Fragetexts; im `fragetext` stehen sie nicht. Es stellt außerdem die Prüfanzeige und die Bestätigung ab und blendet die Musterantwort in der Rückmeldung aus, denn eine rohe Liste wie `[12, 0.3]` sagt den Lernenden nichts. Gemessen am 08.10.2026: Das Feld ist in der Vorschau unsichtbar, und die Liste erscheint in keiner Rückmeldung. `stack_xml` bricht ab, wenn eine gebundene Eingabe in keinem `[[jsxgraph input-ref-…]]` vorkommt oder ein Block eine Eingabe bindet, die es nicht gibt.

Eine gebundene Eingabe darf außerdem leer bleiben (`allowempty`), denn „nicht gezogen" ist der häufigste Weg, einen Teil auszulassen. Knoten 1 jedes Baums, der sie benutzt, prüft deshalb `EMPTYANSWER` und meldet „nicht bearbeitet – 0 Punkte" mit Abzug 0; ohne diesen Knoten bricht `stack_xml` ab (`stack.md`, „Teile ohne Antwort").

Im Rückmeldebaum ist die Eingabe eine Maxima-Liste, gezählt ab 1: `ans2[1]` ist x, `ans2[2]` ist y. Jede Koordinate prüft ein eigener Knoten mit `NumAbsolute`, die Toleranz aus dem Plan. Die Testfälle geben die Lage als Liste an, `[U0, I0]` oder `[U0, I0+0.1]` – wie bei jeder STACK-Frage mindestens richtig, der eingeplante typische Fehler und falsch, dazu „nicht bearbeitet" mit `""`.

## Ein Beispiel

Kennlinie eines Widerstands, aus den Zufallswerten gezeichnet: Die Lernenden ziehen den Arbeitspunkt bei gegebener Spannung (a) und bestimmen den Widerstand aus dem Diagramm (b). Die Werte sind so gewürfelt, dass der Arbeitspunkt auf dem Raster liegt: R in Zehnerschritten, I in Zehntelampere, U ganzzahlig. `I0` bleibt zum Rechnen ein Bruch; im Text steht `{@float(I0)@}`, sonst setzt STACK einen Bruch statt 0,1.

```json
{
  "name": "Arbeitspunkt auf der Kennlinie",
  "idnummer": "et-kennlinie-arbeitspunkt-01",
  "punkte": 2,
  "variablen": "R : 10*(rand(5)+2);\nI0 : (rand(4)+1)/10;\nU0 : R*I0;",
  "hinweis": "R={@R@} Ohm, U0={@U0@} V, I0={@float(I0)@} A",
  "fragetext": "<p>Das Diagramm zeigt die Kennlinie eines Widerstands.</p>\n[[jsxgraph input-ref-ans2=\"ans2Ref\" width=\"480px\" height=\"320px\"]]\nvar board = JXG.JSXGraph.initBoard(divid, {boundingbox: [-2, 0.55, 26, -0.06], axis: true, showCopyright: false, showNavigation: false, intl: {enabled: true, locale: 'de-DE'}});\nboard.create('functiongraph', [function (u) { return u / {#R#}; }, 0, 25], {strokeColor: '#14618f', strokeWidth: 3, fixed: true});\nboard.create('text', [22, 0.03, 'U in V'], {fixed: true});\nboard.create('text', [0.4, 0.52, 'I in A'], {fixed: true});\nvar p = board.create('point', [3, 0.45], {name: 'P', snapToGrid: true, snapSizeX: 1, snapSizeY: 0.05, strokeColor: '#a8420a', fillColor: '#a8420a', tabindex: 0});\nstack_jxg.bind_point(ans2Ref, p);\n[[/jsxgraph]]\n<p><strong>a)</strong> Am Widerstand liegt die Spannung \\(U = {@U0@}\\,\\mathrm{V}\\). Ziehe den Punkt P auf den Arbeitspunkt. Gewertet wird die Lage von P beim Absenden; bewegst du P nicht, gibt es für a) keine Punkte.</p>\n<p><strong>b)</strong> Wie groß ist der Widerstand? \\(R =\\) [[input:ans1]] Ω [[validation:ans1]]</p>",
  "allgemeinesFeedback": "<p>Der Arbeitspunkt liegt auf der Kennlinie bei \\(U = {@U0@}\\,\\mathrm{V}\\), also bei \\(I = {@float(I0)@}\\,\\mathrm{A}\\). Aus jedem Punkt der Kennlinie folgt \\(R = U / I = {@R@}\\,\\Omega\\).</p>",
  "eingaben": [
    { "name": "ans1", "typ": "numerical", "tans": "R", "boxsize": 8, "options": "allowempty" },
    { "name": "ans2", "typ": "algebraic", "tans": "[U0, I0]", "gebunden": true }
  ],
  "prts": [
    { "name": "prt1", "knoten": [
      { "nr": 1, "beschreibung": "b) bearbeitet?", "test": "AlgEquiv", "sans": "ans1", "tans": "EMPTYANSWER", "leise": true,
        "wahr": { "punkte": 0, "abzug": 0, "feedback": "<p>b) wurde nicht bearbeitet – 0 Punkte.</p>" },
        "falsch": { "weiter": 2 } },
      { "nr": 2, "beschreibung": "Widerstand richtig?", "test": "NumRelative", "sans": "ans1", "tans": "R", "optionen": "0.02",
        "falsch": { "weiter": 3 } },
      { "nr": 3, "beschreibung": "I durch U statt U durch I", "test": "NumRelative", "sans": "ans1", "tans": "1/R", "optionen": "0.02",
        "wahr": { "punkte": 0, "feedback": "<p>Hier wurde \\(I / U\\) gerechnet. Der Widerstand ist \\(R = U / I\\).</p>" },
        "falsch": { "feedback": "<p>Lies an einem Punkt der Kennlinie U und I ab und rechne \\(R = U / I\\).</p>" } } ] },
    { "name": "prt2", "knoten": [
      { "nr": 1, "beschreibung": "a) bearbeitet?", "test": "AlgEquiv", "sans": "ans2", "tans": "EMPTYANSWER", "leise": true,
        "wahr": { "punkte": 0, "abzug": 0, "feedback": "<p>a) wurde nicht bearbeitet: P steht noch dort, wo er am Anfang stand – 0 Punkte.</p>" },
        "falsch": { "weiter": 2 } },
      { "nr": 2, "beschreibung": "Spannung von P richtig?", "test": "NumAbsolute", "sans": "ans2[1]", "tans": "U0", "optionen": "0.1",
        "wahr": { "weiter": 3 },
        "falsch": { "feedback": "<p>Die Spannung steht auf der waagerechten Achse: P gehört über \\(U = {@U0@}\\,\\mathrm{V}\\).</p>" } },
      { "nr": 3, "beschreibung": "P auf der Kennlinie?", "test": "NumAbsolute", "sans": "ans2[2]", "tans": "I0", "optionen": "0.01",
        "falsch": { "punkte": 0.5, "feedback": "<p>Die Spannung stimmt, aber P liegt nicht auf der Kennlinie. Der Arbeitspunkt ist der Punkt der Kennlinie bei dieser Spannung.</p>" } } ] }
  ],
  "tests": [
    { "beschreibung": "Alles richtig", "eingaben": { "ans1": "R", "ans2": "[U0, I0]" },
      "erwartet": { "prt1": { "punkte": 1, "hinweis": "prt1-2-T" }, "prt2": { "punkte": 1, "hinweis": "prt2-3-T" } } },
    { "beschreibung": "I durch U, P neben der Kennlinie", "eingaben": { "ans1": "1/R", "ans2": "[U0, I0+0.1]" },
      "erwartet": { "prt1": { "punkte": 0, "abzug": 0.1, "hinweis": "prt1-3-T" }, "prt2": { "punkte": 0.5, "abzug": 0.1, "hinweis": "prt2-3-F" } } },
    { "beschreibung": "Beides falsch", "eingaben": { "ans1": "0", "ans2": "[U0+3, 0]" },
      "erwartet": { "prt1": { "punkte": 0, "abzug": 0.1, "hinweis": "prt1-3-F" }, "prt2": { "punkte": 0, "abzug": 0.1, "hinweis": "prt2-2-F" } } },
    { "beschreibung": "Nichts bearbeitet", "eingaben": { "ans1": "", "ans2": "" },
      "erwartet": { "prt1": { "punkte": 0, "abzug": 0, "hinweis": "prt1-1-T" }, "prt2": { "punkte": 0, "abzug": 0, "hinweis": "prt2-1-T" } } }
  ]
}
```

Danach wie bei jeder STACK-Frage: importieren, Testlauf ansehen, Varianten einsetzen, Aufgabenhinweise prüfen. Dazu ein `bildschirmfoto` der Vorschau, ob die Zeichnung erscheint und lesbar ist, und die Bitte an die Lehrkraft, P einmal richtig und einmal neben die Kennlinie zu ziehen und die Rückmeldungen zu lesen.
