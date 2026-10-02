# Zeichnungen: als SVG-Datei beim Blatt

Eine Netzwerktopologie, ein Schaltplan, ein Prozessablauf, ein Aufbau: Wo ein
Bild mehr sagt als ein Absatz, wird gezeichnet — als **SVG-Datei** in
`dateien/` des Blatts, eingebunden mit

```html
<p><img src="@@PLUGINFILE@@/Z-01-netz-vorher.svg" alt="Netz der Muster GmbH: drei Abteilungen an einem Switch" class="img-fluid"></p>
<p><em>Abb. 1: Das Netz vor der Umstellung — alle Abteilungen in einem Segment.</em></p>
```

Der Alternativtext (`alt`) sagt, was zu sehen ist, für den
Fall, dass das Bild fehlt oder vorgelesen wird. Die Bildunterschrift darunter
sagt, was man daraus lernen soll. Beides gehört dazu; die Zeichnung wird im
Text erwähnt („siehe Abb. 1").

## Warum SVG

- Der Skill kann es ohne Werkzeug: SVG ist Text.
- Es bleibt änderbar — eine Beschriftung korrigiert man mit einer
  Textersetzung.
- Es skaliert: Beamer, Handy, Drucker, dieselbe Datei.
- Der Skill `moodle` nimmt dieselbe Datei unverändert in den Kurs.

Nicht dafür: Fotos, Bildschirmfotos, gescannte Vorlagen. Die kommen als
PNG/JPG von der Lehrkraft, mit Herkunft (Abschnitt „Fremde Inhalte" in SKILL.md).

## Die Blätter werden schwarz-weiß kopiert

Das ist der Unterschied zum Kurs: Was auf dem Kopierer landet, verliert die
Farbe. Der Hausstil unten verlangt ohnehin, dass Farbe nie allein die Aussage
trägt — hier ist das keine Zugänglichkeitsregel, sondern Alltag. Vor der
Übergabe die Zeichnung im Kopf in Graustufen sehen: Sind die zwei Reihen noch
unterscheidbar (Strichstärke, Strichart, Beschriftung)? Ist die Hilfslinie noch
von der Kontur zu unterscheiden? Wenn nicht, nachbessern, nicht hoffen.

Breite: Eine Zeichnung im Format `480×240` füllt auf A4 hochkant die
Textbreite; `360×360` nimmt eine halbe Seite. Mehr als zwei Zeichnungen je
Blatt sind selten sinnvoll.

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

## Zeichnung als Aufgabe

Das Beschriftungsbild aus den sechs Mustern ist auch das Muster für eine
Aufgabe: Auf dem Arbeitsblatt steht die Zeichnung mit Ziffern und **leerer**
Legende, auf der Lösung dieselbe Zeichnung mit gefüllter Legende. Dafür zwei
Dateien (`Z-02-aufbau-leer.svg`, `Z-02-aufbau.svg`), damit die Lösung nicht
aus Versehen ausgeteilt wird.
