# Die Druckaufbereitung „Aufgabenblatt-Druck"

Gilt nur, wenn `status` meldet: „Druckaufbereitung „Aufgabenblatt-Druck": erkannt". Die App sieht das beim Anmelden selbst nach; meldet `status` sie nicht, gibt es sie auf dieser Instanz nicht, und nichts hier gilt.

Die Druckaufbereitung ist ein Skript (unter „Zusätzliches HTML") mit CSS im Theme. Sie bringt eine Moodle-Seite beim Drucken in das Layout eines Aufgabenblatts, statt sie wie eine Webseite aussehen zu lassen. Hier steht nur, was beim **Anlegen von Kursinhalten** zu beachten ist; die allgemeinen HTML-Regeln stehen in `references/html.md` und gelten unverändert.

## Wie sie arbeitet

Beim Drucken baut das Skript einen Container `#ab-print-root` mit echten Seiten (17 × 25 cm), jede mit eigener Kopf- und Fußzeile. Ausgelöst wird es über ein Druckersymbol in der Navigation und über jeden anderen Druck (Strg+P, „Als PDF speichern").

Gedruckt wird die **aktuelle Seite** — eine Textseite, eine Aufgabe, ein Buchkapitel, eine Wiki-Seite —, nicht der Kurs als Ganzes. **Kopf und Fuß setzt die Druckaufbereitung selbst:** oben Kurs, Titel (aus `h1`) und Logo, unten Schule, Seite x/y und Datum. Aus einem übernommenen Blatt entfallen deshalb Kopf- und Fußzeile, Schullogo, Seitenzahl und ein Feld für Name und Datum.

## Was das für erstellte Inhalte bedeutet

Der Umbruch misst die Höhe jedes Blocks und entscheidet, was auf eine Seite passt. Die Regeln aus `references/html.md` (keine Hülle um den ganzen Inhalt, echte Überschriften-Tags, keine `style`-Attribute, Bilder mit `img-fluid`) sind hier nicht nur sauber, sondern nötig: Nur echte `<h*>` hält der Umbruch mit dem folgenden Absatz zusammen, und feste Höhen machen die Messung unbrauchbar. Dazu kommt, was nur hier gilt:

- **Absätze in verdaulicher Länge.** Ein Absatz wird nie zerteilt, damit er nicht an einem `<strong>` zerreißt. Ein Absatz, der länger als eine Seite ist, wandert deshalb ganz auf die nächste Seite und hinterlässt eine Lücke.
- **Tabellen mit flachen Zeilen.** Tabellenzeilen werden ebenfalls nie zerteilt; eine Zeile, die höher als eine Seite ist, läuft über. Viel Text gehört deshalb nicht in eine Tabellenzelle, sondern in Absätze darunter.
- **Rahmenlinien** an Tabellenzellen, die `references/html.md` erlaubt, stören die Messung nicht und kommen so in den Druck, wie sie am Bildschirm stehen (gemessen 25.09.2026).
- **Formeln** (`references/html.md`, „Formeln") kommen gesetzt in den Druck. Eine abgesetzte Formel ist ein Absatz und wird umbrochen wie einer; gemessen an einer Seite mit 13 abgesetzten Formeln auf vier Druckseiten, keine stand zerschnitten am Umbruch (01.10.2026).

## Querformat für eine breite Zeichnung

Eine Zeichnung, die deutlich breiter als hoch ist, wird auf einer hochkanten Seite auf die Breite des Satzspiegels gestaucht und im Druck zu klein. Dagegen gibt es einen Marker: Steht im Inhalt einer Seite ein leeres

```html
<div class="ab-quer"></div>
```

dann baut die Druckaufbereitung die Blätter quer — 25,6 × 17 cm statt 17 × 25,6 — und dreht auch das Papier. Kopfzeile, Fußzeile und „Seite x/y" bleiben wie gewohnt (gemessen 05.10.2026).

Drei Dinge gehören dazu:

- **Der Marker gilt für die ganze Seite**, einerlei wo er steht. Hochkant und quer in einer Seite zu mischen geht nicht.
- **Gefragt wird vor dem Druck, nicht im Druckdialog.** Das Druckersymbol und Strg+P zeigen vorher eine kurze Frage „Hochkant oder Quer?"; vorgeschlagen ist, was der Marker sagt, und die Eingabetaste bleibt dabei. Im Druckdialog des Browsers lässt sich die Ausrichtung dagegen nicht mehr umstellen: Die Blattmaße stehen im CSS, nicht im Papier, und der Inhalt ist zu dem Zeitpunkt schon auf Blätter verteilt. Wer aus dem Browsermenü druckt, bekommt ohne Frage das, was der Marker sagt. Der Marker ist also die Aussage der Seite, der Dialog die Ausnahme im Einzelfall — und wenn nichts gefragt wird, hat die Instanz eine ältere Fassung, dann entscheidet allein der Marker.
- **Immer ein leeres `div`**, nie ein `span`, aus demselben Grund wie beim Karofeld: TinyMCE räumt leere `span` weg.

Eine breite Zeichnung gehört als Bild oder eingebettete SVG in die Seite; beides verkleinert die Druckaufbereitung so, dass es auf ein Blatt passt. Ein **Absatz** oder eine **Tabellenzeile**, die höher ist als ein Blatt, lässt sich dagegen nicht verkleinern und läuft über — quer ist dafür nur knapp halb so viel Höhe da wie hochkant. Lange Absätze und textreiche Tabellenzellen gehören deshalb erst recht nicht auf eine Querformatseite.

Setz den Marker, wenn eine Seite im Wesentlichen aus einer breiten Zeichnung besteht — ein Netzplan, ein Grundriss, ein Organigramm. Für Text und für Zeichnungen, die ungefähr quadratisch sind, bleibt es hochkant: Sonst steht ein Blatt der Lernsituation anders herum als alle übrigen. Tut der Marker nichts, hat die Instanz eine ältere Fassung der Druckaufbereitung; dann schadet er auch nicht, er bleibt ein leeres, unsichtbares `div`.

## Platz zum Ausfüllen: das Karofeld

Für Blätter, die ausgedruckt ausgefüllt werden, bringt die Druckaufbereitung ein Karofeld mit. Es wirkt nur im Druck.

```html
<p>Rechnen Sie 400 MBit/s in MB/s um.</p>
<div class="ab-loesungsplatz-2"></div><div class="ab-loesungsplatz-2"></div>
```

`ab-loesungsplatz-2` ist ein **Karofeld** von 2 cm Höhe (0,5-cm-Kästchen in hellem Grau, dunkler Rahmen). Mehrere direkt hintereinander werden eine durchgehende Fläche — so wählst du die Größe, ohne `style`. Der Umbruch darf zwischen zwei Feldern auf die nächste Seite gehen; jeder Teil steht dann geschlossen auf seinem Blatt.

**Das Karofeld ist der Normalfall, für jede Art von Antwort.** Die Lernenden schreiben ohnehin meist auf kariertem Papier, Text, Rechnung, Tabelle und Skizze passen in dieselbe Fläche, und ein Blatt mit nur einer Art Platz wirkt ruhig. Auch wo ein übernommenes Blatt Schreiblinien hat, wird daraus ein Karofeld: Übernommen wird, dass dort Platz für die Antwort ist, nicht, wie er aussah.

Daneben kennt die Druckaufbereitung die **Schreiblinie** `<div class="ab-loesungsplatz"></div>`, ein `div` je Zeile. Nimm sie nur, wenn die Lehrkraft ausdrücklich Linien möchte. Eine Linie belegt samt Abstand 1,7 cm, fast doppelt so viel wie eine geschriebene Zeile im Karofeld.

**Immer ein `div`, nie ein `span`.** Der Moodle-Editor (TinyMCE) entfernt leere `span` schon beim Öffnen einer Seite; speichert jemand die Seite danach von Hand, ist der Platz zum Ausfüllen weg. Ein leeres `div` lässt er stehen und füllt es nur mit `&nbsp;`, das im Druck durchsichtig ist — auf oberster Ebene wie im Listenpunkt, und die Druckvorschau zeigt danach Schreiblinie und Karofeld wie vorher (gemessen 30.09.2026).

Beide Klassen dürfen auf oberster Ebene stehen oder in einem Listenpunkt nach dem Aufgabentext. **Immer leer lassen:** Text darin ist im Druck durchsichtig, steht aber für alle lesbar in der Seite — eine Lösung darin fänden die Lernenden. Wird in Moodle abgegeben, braucht es keinen Platz zum Ausfüllen.

**Die Größe entscheidet die Lehrkraft.** Schlag im Plan für jede Aufgabe vor, wie groß der Platz zum Ausfüllen wird, begründet mit der erwarteten Antwort, etwa: „Aufgabe 3: Karofeld 4 cm, weil der Rechenweg drei Schritte hat." Als Faustregel braucht im Karofeld jede geschriebene Zeile etwa 1 cm, ob Satz, Stichpunkt oder Schritt im Rechenweg, dazu eine Zeile Reserve; eine Skizze braucht so viel Platz, wie sie groß werden soll. Aufgerundet wird auf ganze Felder zu 2 cm. Handschrift braucht mehr Platz als gedruckter Text, und ein zu knapper Platz lässt sich auf Papier nicht vergrößern. Im Zweifel deshalb eher großzügig planen.

## Nach größeren Inhalten kurz prüfen

Ob der tatsächliche Ausdruck stimmt, zeigt nur die Druckvorschau. Nach dem Anlegen umfangreicherer Inhalte der Lehrkraft empfehlen, sie einmal anzusehen — besonders bei Tabellen und langen Listen.
