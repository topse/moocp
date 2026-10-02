# CLAUDE.md – Skill `lernsituation`

Entwicklungsnotizen; nicht Teil des Pakets. Allgemeines zur Pflege der
Skills: [../CLAUDE.md](../CLAUDE.md).

Der Skill entwirft ohne Moodle – Prosa, Vorlagen und ein Prüfskript –,
schreibt den Entwurf aber als HTML in den Arbeitsordner der App und gibt ihn
gleich nach der Prüfung an den Skill `moodle`. `references/beispiel/` ist zugleich Muster für den Agenten und
Fixture für `pruefung/pruefe-lernsituation-skript.py` – wer das Beispiel
ändert, lässt die Prüfung laufen.

## Nicht verhandelbar

- **Kein erfundener curricularer Bezug.** Der Rahmenlehrplan ist je Beruf,
  Schulform und Fach ein anderer; der Skill hat ihn nicht. Was nicht geliefert
  wird, steht als „vom Nutzer zu ergänzen" in der SchuCu-Tabelle – eine
  erfundene Lernfeldnummer wird abgeschrieben und fällt erst in der Konferenz
  auf.
- **Die Anrede wird jedes Mal abgefragt**; sie wechselt zwischen
  Berufsschule, Beruflichem Gymnasium und Erwachsenenklassen.
- **Erst zwei bis drei Vorschläge, dann die Ausarbeitung** – der Plan (A5) in
  seiner natürlichen Form.
- **Jedes Blatt eine Aktivität, jede in der Handreichung genannt, jedes
  Arbeitsblatt mit Lösung.** Das prüft das Skript.

## Entscheidungen

- **Sechs Phasen** der vollständigen Handlung (Informieren, Planen,
  Entscheiden, Durchführen, Kontrollieren, Reflektieren); nicht alle müssen
  vorkommen, aber welche fehlt und warum, steht in der Handreichung.
  Stillschweigend weglassen gilt nicht.
- **Binnendifferenzierung als Zusatzblatt** („Vertiefung" führt weiter, „Hilfe" stützt zum selben Ziel), nicht als drei Fassungen desselben Blatts – dreifache Pflege und eine Schublade für die Lernenden. Die Namen sagen, was das Blatt tut, nicht, für wen es ist. Verworfen: „Plus"/„Basis" (erklären sich nicht, sortieren in Stärkere und Schwächere, „Basis" liest sich als das Grundlegende für alle); „Zusatzaufgabe" (stößt sich mit den Aufgaben darauf).
- **Der Entwurf ist HTML in der Form der Werkzeuge** (Festlegung des Nutzers): `lernsituation.json` mit Abschnitt und Aktivitäten (Reihenfolge, Typ, Name, Einstellungen), je Aktivität ein Ordner mit `page.html` bzw. `introeditor.html` und `dateien/`, ein Buch mit `kapitel.json` und `kapitel-<id>/content_editor.html` wie bei `buch_lesen`. Jedes Blatt wird einmal geschrieben, so wie es in Moodle steht; die Übertragung legt nur an. Verworfen: der Entwurf in Markdown mit Umwandlung beim Anlegen – er stammte aus der Zeit, als der Ordner ein bleibendes, lesbares Ergebnis sein sollte; seit Moodle maßgeblich ist (E17), liest ihn niemand, jedes Blatt wurde zweimal geschrieben, die Umwandlung war eine Fehlerquelle, und SchuCu-Tabelle, Kästen und Platz zum Ausfüllen standen ohnehin als HTML im Markdown.
- **Ein Leser für Entwurf und Moodle:** Das Prüfskript liest beide in dieselbe Liste von Aktivitäten (Name, HTML) und prüft an einer Prüfform, in die `ZuMarkdown` das HTML bringt – die festen Formen lassen sich an Text einfacher lesen als an HTML. Die Prüfform lebt nur während der Prüfung. Nur am Entwurf: `lernsituation.json`, Ordner, HTML-Regeln (in Moodle meldet sie die App selbst); nur in Moodle: die Links.
- **Die Links setzt die App** (`links_setzen`, `lib/moodle/links.dart`), geprüft werden sie im Skript (`links`). Die App kennt die Kennung nur allgemein – Namensanfang vor dem Doppelpunkt, mit Buchstaben vorn und Zahl hinten –, das Skript die festen Formen (`BLATT`, `ZIEL`). Für jede Kennung nach diesen Formen setzt die App genau die Links, die das Skript verlangt; wer eine Form ändert oder hinzufügt, prüft das an beiden Stellen, am einfachsten mit einer echten Übertragung und `--moodle` danach.
- **Kennung im Namen** (Festlegung des Nutzers): „Arbeitsblatt n", „Infoblatt n", „Hilfe/Vertiefung zu Arbeitsblatt n", „Lösung zu …", ohne führende Null. Der Name ist der in der Kursübersicht, darum dieselbe Kennung in jedem Verweis; das Skript erkennt die Rolle einer Aktivität an ihm (dazu „SchuCu", „Lehrerhandreichung", „Handlungssituation"), nicht am Ordner. Die Ordner heißen `ab-nn-…`, `ib-nn-…` nur, damit sie sortieren; im Text steht keiner. „Blatt" passt auch digital – das Wort ist in der Schule vom Papier gelöst, Moodle selbst sagt Textseite und Verzeichnis. Verworfen: „AB-03"/„IB-01" im Titel (Insiderkürzel); „Aufgabe n" (stößt sich mit den Aufgaben auf dem Blatt, dem Moodle-Typ Aufgabe und „Lösung zu Aufgabe 3"); „Gut zu wissen n" (klingt freiwillig, obwohl die „Lies"-Zeile es verlangt, und passt in keinen Satz); „Info n" (so heißt ein Kasten); Auftrag, Arbeitsauftrag, Schritt, Lernaufgabe (alle schon belegt: Handlungssituation, Einordnung beim Beurteilen, Ablaufplan, Aufgaben darauf).
- **Jedes Blatt steht für sich** (Festlegung des Nutzers): Zählung je Blatt ab 1, Verweise mit Kennung und Stelle, Teilen nur an einer inhaltlichen Grenze – jedes Blatt wird einzeln gedruckt, ausgeteilt und nachgelesen. Die Verweise haben feste Formen, weil das Skript nur feste Formen prüfen kann. „→ für" im Infoblatt ist der Rückverweis auf die „Lies"-Zeile und wird in beide Richtungen geprüft, sonst veraltet eine Seite still. Ein unvollständiges „Gehört zu" ist ein Befund, kein Hinweis.
- **Infoblätter sind kein Muss** (Festlegung des Nutzers): Neues Wissen kommt aus einem eigenen Infoblatt, aus Vorhandenem (Lehrbuch, Tabellenbuch, Programmhilfe, Netz) oder aus einer Recherche, die die Aufgabe ausdrücklich verlangt – die Klasse hat mehr Quellen als unsere Blätter, und Recherchieren ist selbst ein Lernziel. Welcher Weg, entscheidet die Lehrkraft im Vorschlag (Zeile „Information"); im Zweifel wird gefragt, statt vorsorglich ein Infoblatt anzulegen. Titel und Seiten von Büchern nennt die Lehrkraft, nie der Skill. Das Skript prüft nur Verweise auf eigene Infoblätter; ob eine Lehrbuchseite stimmt, kann es nicht wissen. Vorwissen aus früheren Lernsituationen steht in der Handreichung, nicht in einer „Lies"-Zeile.
- **Die Form ist Vertrag, nicht Stil**, weil das Skript sie liest:
  Aufgabenkopf `<h3>Aufgabe n (n min · Sozialform · AFB x)</h3>`, Ablaufplan
  mit den Spalten „Zeit" und „Material" und einer Summenzeile, Checkliste mit
  dritter Spalte „Woran man es sieht", Name mit Kennung, Abschnitte
  `<h3>n. …</h3>`, Bildunterschrift `<p><em>Abb. n: …</em></p>`, „Lies"-Zeile,
  „→ für", „Dazu" und „Gehört zu" als eigene Absätze und die Verweisformen. Wer die Vorlagen in `references/vorlagen.md`
  ändert, ändert das Skript mit.
- **Zeitrichtwert in UStd, Ablaufplan in Minuten**, 1 UStd = 45 min; das
  Skript lässt 10 % Abweichung zu.
- **Beurteilen heißt Hilfestellung, nicht Urteil:** keine Punkte, sondern ein
  kurzer Bericht nach Priorität (Muss/Soll/Kann, je mit Beleg und Vorschlag);
  ist keine Lernsituation erkennbar, erklärt er, woran man das sieht und was
  aus dem Vorhandenen werden kann. Gelesen wird über den Skill `moodle`,
  geschrieben nichts.
- **Lernsituation = Kursabschnitt, und Moodle ist maßgeblich** (Gleichanteil `bruecke.md`, in beide Richtungen; E17 der Projekt-CLAUDE.md, Festlegung des Nutzers). Der Entwurf lebt nur im Arbeitsordner, bis er im Kurs steht; danach liest und ändert jeder in Moodle. Darum gehört der Ort im Kurs schon in den Plan von Schritt 2: Ausarbeitung, Prüfung und Übertragung laufen in einem Zug, weil der Arbeitsordner ein Beenden der App nicht übersteht.
- **Blätter werden schwarz-weiß kopiert.** Der Hausstil für Zeichnungen
  verlangt ohnehin, dass Farbe nie allein trägt – hier ist das Alltag.

## SchuCu-Tabelle

- Die Vorlagen sind Dateien, das Skript liest sie:
  `references/schucu-berufsschule.html` ist die Vorlage des Nutzers wörtlich;
  `schucu-bg.html` ist seine Vorlage mit drei von ihm festgelegten Änderungen
  (Titel und geplanter Zeitrichtwert über den Autoren, der Block „Situation"
  darüber entfernt, Lehrplan-Link und Legende als Platzhalter statt der
  Informatik-Werte, die in `vorlagen.md` stehen). In den Abstandszellen steht
  `&nbsp;&nbsp;` wie in `..\html_Vorlagen`. Unter beiden Tabellen steht nach
  Festlegung des Nutzers `<p>Inhalte können teilweise mit KI generiert
  sein.</p>`, im BG unter der Legende.
- **Eigene Seite „SchuCu"**, vom Nutzer so festgelegt: in Moodle die erste
  Aktivität des Abschnitts, verborgen, damit sie bei einer Inspektion sofort
  zu finden ist; ob sie sichtbar wird, entscheidet die Lehrkraft. Im Entwurf
  `schucu/page.html`, damit die Brücke eins zu eins bleibt.
- **Kurzform, die für sich steht** (Festlegung des Nutzers): keine Verweise
  auf Blätter in der Tabelle; wer mehr wissen will, liest die Handreichung,
  und die kommt ohne die Tabelle aus – daher dort die Abschnitte Lernumgebung
  und Leistungsbewertung. Nur Autor, curricularer Bezug und die
  BG-Kompetenzbereiche stehen allein in der Tabelle. Verweise in der Tabelle
  prüft das Skript bewusst nicht, auf Wunsch des Nutzers vorerst.
- **Reihenfolge im Abschnitt** (Festlegung des Nutzers): SchuCu,
  Handreichung, dann die Handlungssituation und der Ablaufplan; die
  Lehrkraft soll ihre Informationen sofort sehen. Lösungen verborgen direkt
  hinter ihrem Blatt, weil die Lehrkraft sie dort freigibt. Die Einträge für
  die Lehrkraft stehen außerhalb einer Nummerierung des Kurses.
- **Handreichung als ein Dokument**, Textseite oder bei langen ein Buch
  (Richtwert: mehr als etwa zehn Schritte oder 20 000 Zeichen – nicht die
  Stunden, auf Einwand des Nutzers; das Beispiel mit 8 Schritten und rund
  12 000 Zeichen ist eine Textseite). Ob „Buch drucken" mit der eigenen
  Druckaufbereitung der Instanz sauber druckt, ist nicht gemessen; der Nutzer
  geht davon aus.
- Das Skript vergleicht das **Gerüst** – je Zelle Klasse, `colspan` und
  Beschriftung, dazu die Absätze darunter –, nicht eine Feldliste.
- **Das Design außerhalb von Moodle** steht hier und nicht im Paket, weil kein
  Ablauf des Skills ODT oder DOCX erzeugt; gedruckt wird aus Moodle. Gebraucht
  wird es für die ODT-Ausgabe und für Instanzen ohne CSS für die Klassen
  (beides in `TODO.md`). Nachgebaut wird dieselbe Tabelle, nicht ersetzt –
  drei Spalten, dieselben Zeilen und Beschriftungen wie in der Vorlagedatei;
  Umwandler von HTML nach DOCX oder ODT verlieren die Klassen und damit das
  Aussehen.

  | Element | Aussehen |
  |---|---|
  | Kopfzeile (`lshead`, über alle drei Spalten) | fett, Schrift `#0851A0`, Hintergrund `#0851A0` mit 25 % Deckung (auf Weiß `#C1D3E7`), Innenabstand 10 px |
  | Beschriftung (`lssubhead`) | Schrift `#0851A0`, Hintergrund 12,5 % Deckung (auf Weiß `#E0E9F3`), so schmal wie möglich, oben ausgerichtet |
  | Datenzelle (`lsdata`) | ohne Hintergrund, Innenabstand 10 px, oben ausgerichtet |
  | Abstandsspalte (`lsspacer`) | leer, 10 % der Breite |
  | Linien | 1 pt, `#0851A0` mit 25 % Deckung (`#C1D3E7`), um Tabelle und jede Zelle |
  | Kopflink „offizielle Erläuterungen hier!" | 6 pt; Lehrplan-Link im BG ebenso; Legende der Kompetenzbereiche 8 pt |
- Inhaltliche Grundlage ist die Leitlinie SchuCu-BBS „Grundlegende
  Anforderungen an Lernsituationen" (Stand 09/2018), selbst gelesen und in
  `didaktik.md` übernommen – nicht die Zusammenfassung eines Abrufwerkzeugs,
  die war erfunden allgemein.
- **Darstellung in Moodle:** Die Instanz bringt die Regeln der Vorlage als
  Baustein des Editor-Plugins „Elements" mit (`tiny_elements_styles.css`), mit
  den Werten aus `..\html_Vorlagen\style.css`. Einzige Abweichung: Die
  Zellrahmen sind grau, weil eine Theme-Regel für Tabellen ohne Klasse `table`
  spezifischer ist als `table.lernsituation td.lsdata`. Das trifft jede von
  Hand eingefügte Vorlage genauso; an der Vorlage wird dafür nichts geändert.
