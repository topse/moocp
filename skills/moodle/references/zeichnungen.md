# Zeichnungen erzeugen und einbetten

Eine erzeugte Zeichnung ist eine **SVG-Datei**, die du schreibst und in ein
Editorfeld einbindest. Sie braucht weder ein Zeichenprogramm noch eine
Umwandlung.

## Warum SVG

- **Du kannst es.** SVG ist Text. Ein PNG hieße: erst SVG bauen, dann
  umwandeln — eine Abhängigkeit mehr, die auf dem Rechner des Nutzers
  installiert sein muss.
- **Es bleibt änderbar.** Einen Tippfehler in einer Beschriftung korrigiert man
  mit einer Textersetzung, nicht mit einem Neuzeichnen.
- **Quelle und Auslieferung sind dieselbe Datei.** Die Regel aus
  `verzeichnisse.md` — das bearbeitbare Original gehört neben das ausgelieferte
  Bild ins Lehrermaterial — entfällt hier. Eine Datei weniger, die
  auseinanderlaufen kann.
- **Es skaliert.** Beamer und Handy, dieselbe Datei, keine Treppen.

Nicht dafür nehmen: Fotos, Bildschirmfotos, gescannte Vorlagen. Das bleibt
Sache von PNG oder JPG, die der Nutzer liefert.

## Der Weg

1. Die SVG mit dem Datei-Werkzeug nach `<ordner>\dateien\ablauf-messung.svg`
   schreiben — Dateiname aus Kleinbuchstaben, Ziffern und Bindestrichen.
2. Im Text einbinden:

   ```html
   <p><img src="@@PLUGINFILE@@/ablauf-messung.svg"
        alt="Ablauf einer Messung in drei Schritten: Vorbereiten, Messen, Auswerten"
        class="img-fluid"></p>
   ```

3. `aktivitaet_anlegen` bzw. `aendern` — die App lädt die Datei in den
   Entwurfsbereich des Felds, in dem sie vorkommt.

Drei Dinge, die man dabei wissen muss:

1. **Der Platzhalter, nicht die Adresse.** Moodle löst `@@PLUGINFILE@@` beim
   Speichern in eine `pluginfile.php`-Adresse auf. Wer selbst eine Adresse
   einträgt, baut einen Verweis, der beim nächsten Kurs-Duplikat ins Leere
   zeigt.
2. **Jedes Editorfeld hat seinen eigenen Entwurfsbereich.** Dieselbe
   Zeichnung in `page.html` und `introeditor.html` wird zweimal hochgeladen —
   das ist richtig so.
3. **Nach dem Speichern nachsehen:** `aktivitaet_lesen` nennt jedes Bild mit
   Maßen, Alternativtext und bei SVG mit Titel und Beschriftungen. Fehlt es
   dort, ist es nicht angekommen.

## Was gemessen ist

Am 10.09.2026 im Testkurs, mit einer Probe-Textseite, die danach gelöscht wurde:

| Frage | Ergebnis |
|---|---|
| Nimmt der Entwurfsbereich eine `.svg` an? | Ja. Kein Dateityp-Filter, kein Fehler. |
| Wird sie nach dem Speichern angezeigt? | Ja, über `pluginfile.php`. |
| Filtert Moodle eingebettetes SVG im Text weg? | **Nein.** `xmlns`, `role`, `aria-labelledby`, `class`, `data-*`, `<title>`, `<desc>`, `<style>`, `<defs>`, `<use>`, `<foreignObject>` standen nach dem Speichern unverändert da. |
| Hat diese Instanz einen dunklen Modus? | Nein. Keine `prefers-color-scheme`-Regel in den Stilvorlagen, kein Umschalter. |

## Trotzdem: als Datei, nicht in den Text

Dass Moodle eingebettetes SVG durchlässt, heißt nicht, dass man es tun soll.

**Der Editor räumt auf, und zwar stillschweigend.** In einem von zwei
Durchgängen fehlte nach dem Speichern das `xmlns`-Attribut — der Unterschied
war, ob der Inhalt durch TinyMCE gelaufen ist. Öffnet die Lehrkraft die Seite
später im Editor, passiert genau das. Man merkt es nicht, weil die Zeichnung
meistens trotzdem aussieht wie vorher.

Dazu kommt: Eine Datei lässt sich in einer zweiten Seite wiederverwenden,
herunterladen und weitergeben. Eingebetteter Quelltext nicht.

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

**Ohne `alt` keine Einbindung** — das ist die Stelle, an der die
Zugänglichkeitsregel oben durchgesetzt wird. Die Übersicht der App meldet
fehlende Alternativtexte als Befund.

## Wenn die Zahlen variieren sollen

Eine SVG ist statisch. Soll dieselbe Darstellung bei jedem Lernenden andere
Werte zeigen — gegen das Abschreiben —, ist sie das falsche Werkzeug: Ein
Schaltbild mit eingezeichneten 12 V neben einer Aufgabe, die 9 V nennt, ist
schlimmer als gar keine Zeichnung. Das gehört dann in eine STACK-Frage, wo
JSXGraph die Darstellung aus denselben Zufallsvariablen erzeugt wie die
Aufgabenstellung. Zuständig ist dafür der Skill `moodle-fragen`.
