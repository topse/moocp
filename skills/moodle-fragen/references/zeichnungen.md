# Zeichnungen in Fragen: SVG als Datei im XML

Ein Schaltbild, eine Netzskizze, ein Diagramm in einer Frage: Du zeichnest es
selbst, als SVG, und legst es als **Datei** in die Frage — nicht als
eingebetteten `<svg>`-Quelltext im Fragetext. Der Weg ist der XML-Import:

```
<Arbeitsordner>\ls3-test\fragen.xml
<Arbeitsordner>\ls3-test\dateien\reihenschaltung.svg
```

```xml
<questiontext format="html">
  <text><![CDATA[<p>Die Zeichnung zeigt eine Reihenschaltung. …</p>
  <p><img src="@@PLUGINFILE@@/reihenschaltung.svg" alt="Reihenschaltung: Spannungsquelle U, R1 und R2 in Reihe" class="img-fluid"></p>]]></text>
</questiontext>
```

`fragen_importieren` findet den Verweis, holt die Datei aus `dateien\` und
bettet sie als `<file>` hinter `<text>` ein. Vorher prüft die App die
Zeichnung und lädt sonst nichts hoch:

- Dateiname nur aus Kleinbuchstaben, Ziffern und Bindestrichen, Endung `.svg`
- `xmlns="http://www.w3.org/2000/svg"` — ohne zeigt der Browser nichts
- `<title>` und `<desc>` vorhanden
- kein `<script>`, kein externer Verweis (Webfonts und fremde Bilder fehlen
  irgendwann)

Bei `stack_xml` und `coderunner_xml` genügt `zeichnungen: [{ "name":
"reihenschaltung.svg" }]` — die Datei liegt in `dateien\` neben der
Zieldatei; das `<img>` gehört trotzdem in den `fragetext`, weil nur du weißt,
wo das Bild im Text stehen soll.

## Was gemessen ist

Am 19.09.2026 in der geteilten Sammlung des Testkurses, Multiple-Choice-Frage
`ZZ SVG-Probe` per Import, danach gelöscht:

| Frage | Ergebnis |
|---|---|
| Nimmt der Import `<file>` in `<questiontext>` an? | Ja, keine Meldung. |
| Zeigt die Vorschau das Bild? | Ja, über `pluginfile.php/…/question/questiontext/<id>/…`. |
| Kommt die Datei unverändert an? | Ja: `image/svg+xml`, Byte für Byte; `xmlns`, `<title>`, `<desc>`, `<style>` stehen da. |
| Ist ein Editor beteiligt? | Nein — deshalb bleibt hier alles, was TinyMCE im Kurs stillschweigend aufräumt. |

**Die Datei überlebt das Bearbeitungsformular** (gemessen 19.09.2026, mit der
App nachgemessen): Frage geändert, neue Version, das Bild kam unverändert mit. Nach dem Ändern einer Frage mit Zeichnung trotzdem
`frage_lesen` ansehen; fehlt das Bild in `dateien\`, ist das ein SKILLBEFUND.

## Die Regel aus dem AFB-Abschnitt gilt auch für Bilder

Ein Bild in einer Frage zeigt eine **neue Situation** — eine andere Schaltung,
andere Werte, ein anderer Aufbau als im Kurs. „Der Schaltplan aus Abschnitt 1"
als Bild in einer Testfrage prüft Erinnerung an den Kurs, nicht Können; siehe
„Test aus einem Abschnitt" in `SKILL.md`. Eine Zeichnung, die als Aufgabe
dient (Beschriftungsbild mit leerer Legende), gehört mit der Legende in die
Antworten, nicht in die Zeichnung.

## Wenn die Werte variieren sollen

Eine SVG ist statisch. Soll dieselbe Darstellung bei jedem Lernenden andere
Werte zeigen, ist sie das falsche Werkzeug: Ein Schaltbild mit eingezeichneten
12 V neben einer STACK-Aufgabe, die 9 V zieht, ist schlimmer als gar keine
Zeichnung. Dann gehört die Darstellung nach JSXGraph in die STACK-Frage, wo sie
aus denselben Zufallsvariablen entsteht wie die Aufgabenstellung
(`references/jsxgraph.md`).

<!-- <<< gemeinsam/zeichnungen.md - von build.py erzeugt, hier nicht bearbeiten -->
## Der Hausstil

Er gilt fachunabhängig. Fachvokabular — Schaltzeichen, Strukturformeln,
Kartensymbole — kommt darüber, nicht hinein, und wird einzeln gemessen und
zugelassen, so wie die Zusatzfragetypen im anderen Skill.

Dieser Block gehört an den Anfang jeder Zeichnung. Die Palette steht an
**einer** Stelle; wer Schulfarben hat, tauscht die vier Werte und rührt sonst
nichts an.

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 240"
     width="480" height="240" role="img" aria-labelledby="titel beschreibung">
  <title id="titel">Kurzer Titel</title>
  <desc id="beschreibung">Ein Satz, der sagt, was zu sehen ist.</desc>
  <style>
    :root, svg {
      --grund:    #ffffff;   /* Grundfläche */
      --tinte:    #1f2933;   /* Kontur und Schrift */
      --ruhig:    #e4e7eb;   /* Füllung ohne Aussage */
      --betont:   #14618f;   /* Hervorhebung, erste Reihe */
      --gegen:    #a8420a;   /* Hervorhebung, zweite Reihe */
    }
    .flaeche { fill: var(--grund); }
    .kontur  { fill: none; stroke: var(--tinte); stroke-width: 2;
               stroke-linejoin: round; stroke-linecap: round; }
    .hilfe   { fill: none; stroke: var(--tinte); stroke-width: 1;
               stroke-dasharray: 4 3; opacity: .6; }
    .stark   { fill: none; stroke: var(--betont); stroke-width: 3;
               stroke-linejoin: round; stroke-linecap: round; }
    .fuell   { fill: var(--ruhig); }
    text     { font-family: system-ui, "Segoe UI", Roboto, sans-serif;
               font-size: 15px; fill: var(--tinte); }
    .titel   { font-size: 18px; font-weight: 600; }
    .klein   { font-size: 13px; }
  </style>
  <rect class="flaeche" x="0" y="0" width="480" height="240"/>
  <!-- ab hier die Zeichnung -->
</svg>
```

| Festlegung | Regel |
|---|---|
| **Fläche** | Drei Formate: breit `480×240`, quadratisch `360×360`, hoch `360×480`. `viewBox` und `width`/`height` immer in denselben Zahlen. |
| **Raster** | Alles rastet auf 10 Einheiten ein. Krumme Koordinaten sind fast immer ein Versehen. |
| **Grundfläche** | Jede Zeichnung bekommt ihre eigene helle Fläche. Ein transparenter Grund erbt das Theme des Umfelds — im Browser wie beim Kopieren in ein anderes System. |
| **Strich** | Drei Stärken mit fester Bedeutung: 2 Kontur, 1 Hilfslinie (gestrichelt), 3 Hervorhebung. Mehr nicht. |
| **Schrift** | Generische Familie, **niemals ein Webfont** — der lädt bei einer per `<img>` eingebundenen SVG nicht, und die Zeichnung fällt auf eine unbekannte Ersatzschrift zurück. Nichts unter 13 px. |
| **Farbe** | Fünf Werte, keiner mehr. **Farbe trägt nie allein die Aussage** — was farbig unterschieden ist, muss auch über Form, Beschriftung oder Strichart unterscheidbar sein. Kein Rot-Grün-Paar. |
| **Beschriftung** | Immer `<text>`, nie in Pfade umgewandelt. Sonst weder durchsuchbar noch übersetzbar noch für Screenreader vorhanden. |
| **Zugänglichkeit** | `role="img"`, `<title>`, `<desc>` in der Datei, dazu ein `alt` bei jeder Einbindung. |

## Sechs Muster

Mehr Zeichnungen als diese sechs braucht der Unterricht selten, und sie kommen
in jedem Fach vor.

**Ablauf und Fluss.** Kästen in einer Reihe, Pfeile dazwischen. Höchstens
fünf Stationen; ab sechs wird der Text zu klein oder die Zeichnung zu breit.
Verzweigungen als Raute, und dann beide Ausgänge beschriften — ein unbeschrifteter
Zweig ist eine Frage, keine Antwort.

**Zeitachse.** Eine waagerechte Linie, Marken darauf, Beschriftungen
abwechselnd oben und unten, wenn es eng wird. Abstände maßstäblich, sonst ist
es keine Zeitachse, sondern eine Aufzählung mit Linie.

**Achsendiagramm.** Beide Achsen beschriftet, **mit Einheit**. Nullpunkt zeigen
oder das Fehlen kennzeichnen. Gitternetz als Hilfslinie, nie als Kontur.

**Struktur und Hierarchie.** Von oben nach unten, gleiche Ebenen auf gleicher
Höhe. Maximal drei Ebenen — was tiefer geht, gehört in eine Liste, nicht in
eine Zeichnung.

**Beschriftungsbild.** Eine Darstellung, dazu Ziffern und eine Legende
daneben. Die Ziffern gehören ins Bild, die Wörter in die Legende — so bleibt
die Zeichnung lesbar und lässt sich als Aufgabe verwenden, indem man die
Legende leert.

**Mengen und Zuordnung.** Überlappende Flächen oder zwei Spalten mit
Verbindungslinien. Flächen nur mit `--ruhig` füllen und die Zugehörigkeit
zusätzlich beschriften; wer sie über Farbe allein zeigt, verliert einen Teil
der Klasse.

## Was nicht hineingehört

- **Skripte.** `<script>` in einer per `<img>` eingebundenen SVG läuft ohnehin
  nicht — es steht dann nur unnütz und verdächtig darin.
- **Externe Verweise.** Keine Webfonts, keine Bild-Adressen, kein `<image
  href="http…">`. Was extern liegt, fehlt irgendwann.
- **Eingebettete Rasterbilder.** Ein base64-PNG in einer SVG ist ein PNG mit
  Umweg. Dann gleich das PNG selbst einbinden.
- **`<foreignObject>`.** Wird zwar gespeichert, aber nicht überall gleich
  dargestellt. Text gehört in `<text>`.
- **Dekoration ohne Aussage.** Schatten, Verläufe, Symbolbildchen. Jedes
  Element muss etwas behaupten.
<!-- >>> gemeinsam/zeichnungen.md -->
