# Tests zusammenstellen und Punkte in Ordnung halten

## Einen Test anlegen

Ein Test ist eine gewöhnliche Kursaktivität (Skill `moodle`):

```
aktivitaet_anlegen(kurs, abschnitt_id, typ: "quiz", name: "Klassenarbeit LF 3",
                   einstellungen: { "timeopen": "…", "attempts": "1", … })
```

**Die App legt ihn verborgen an** — gut so, solange er noch keine Fragen hat.
Ein leerer, sichtbarer Test verwirrt die Klasse, und bei einem Test mit
Zeitfenster ist ein Versehen schnell folgenreich. Die Antwort nennt die cmid.

Einsortieren, Umbenennen, Verschieben und Sichtbarmachen: Skill `moodle`.

## Den Aufbau lesen

`test_lesen(cmid)`:

```
Test cmid 15449: 4 Plätze auf 2 Seite(n), Summe der Punkte 7, Beste Bewertung 7, 2 je Seite
Zeilen: Seite · slotid · Typ · „Name" · Punkte · questionid
  S.1 · 2911 · multichoice · „ZZ Wahl" · 2 P. · 14966
  S.1 · 2912 · truefalse · „ZZ Ja/Nein" · 1 P. · 14961
  S.2 · 2913 · random · „Zufällig (ZZ Probekategorie)" · 2 P.
  S.2 · 2914 · stack · „ZZ Ohm" · 2 P. · 14962
Fragen mischen: aus (Testabschnitt 812)
Befunde:
  - …
```

**`slotid` und `questionid` sind verschiedene Dinge.** Die slotid bezeichnet
den Platz *in diesem Test*, die questionid die Frage in der Sammlung. Punkte
setzt man am Platz, Inhalte ändert man an der Frage.

Ein **Zufallsplatz** (`random`) hat keine questionid — die Frage steht erst
beim Versuch fest. Stell solche Plätze in der Übersicht ausdrücklich als
Zufallsplatz dar, sonst wirkt der Test bestimmter, als er ist.

Die **Befunde** sind ein Verdachtsraster: Beste Bewertung ungleich Summe, Test
ohne Fragen, Fragen mit 0 Punkten, die keine Beschreibung sind, von Hand
gesetzte Seitenumbrüche, **bereits Versuche**. Findet es etwas, sag es dem
Nutzer von selbst — die Punkte-Abweichung fällt sonst erst auf, wenn die Noten
schon im Notenbuch stehen.

## Ändern: `test_aendern`

Alle Aktionen eines Auftrags in **einem** Aufruf — eine Freigabe, danach
zurückgelesen:

```json
[
  { "art": "frage_hinzufuegen", "frage": 14966 },
  { "art": "frage_hinzufuegen", "frage": 14961 },
  { "art": "zufall_hinzufuegen", "kategorie": 1642, "anzahl": 2 },
  { "art": "punkte", "platz": 2912, "wert": 2 },
  { "art": "beste_bewertung", "wert": "summe" },
  { "art": "mischen", "an": true }
]
```

`test_aendern(cmid, name, aktionen)` — `name` wie in `kurs_uebersicht`.

### Fragen einfügen

`frage_hinzufuegen {frage, seite?}` — ohne `seite` auf die letzte Seite. Die
Fragen kommen in der Reihenfolge der Aktionen in den Test; **leg sie also
gleich in der gewünschten Reihenfolge an**. Beim Einfügen übernimmt Moodle die
Punkte der Frage als Punktzahl des Platzes.

### Zufallsfragen

Ein Zufallsplatz zieht beim Start des Versuchs eine zufällige Frage aus einer
Kategorie. Damit bekommt jede Person eine andere Zusammenstellung — sinnvoll,
sobald der Pool deutlich größer ist als die Zahl der gezogenen Fragen.

`zufall_hinzufuegen {kategorie (id), anzahl, unterkategorien?, seite?}`

- **Die Kategorie muss genug Fragen enthalten.** Werden 5 Zufallsfragen aus
  einer Kategorie mit 4 Fragen gezogen, bleibt ein Platz leer.
- **Entwürfe zählen nicht mit.** Fragen im Status „Entwurf" werden nicht
  gezogen.
- Ein Zufallsplatz hat die Punktzahl, die beim Anlegen gesetzt wurde —
  unabhängig von der gezogenen Frage. Bei gemischten Punktwerten im Pool wird
  das leicht unfair; für Zufallsplätze Pools mit einheitlicher Punktzahl
  aufbauen.

### Plätze entfernen

`entfernen {platz}` nimmt den **Platz** aus dem Test, nicht die Frage aus der
Sammlung — die bleibt für andere Tests erhalten. Nenne dem Nutzer vorher, was
entfernt wird (Name aus `test_lesen`).

### Reihenfolge

`verschieben {platz, hinter, seite?}` — `hinter` ist die slotid des Vorgängers,
`0` heißt „ganz nach vorn". `reihenfolge {plaetze}` stellt eine komplette
Wunschreihenfolge her (alle slotids, jede genau einmal).

**Die Seitenaufteilung ist der Haken dabei.** Drei gemessene Tatsachen:

1. Moodle nimmt beim Verschieben nur Zielseiten, die es gibt; die Seitenzahl
   ändert sich während des Umsortierens laufend.
2. Die App sortiert deshalb erst alles auf Seite 1 um und stellt eine
   **gleichmäßige** Aufteilung danach wieder her.
3. War die Aufteilung ungleichmäßig — von Hand gesetzt —, lässt sie sich nicht
   zurückrechnen. Dann **weigert sich die App** und ändert nichts. Sag das dem
   Nutzer; ist es ihm recht, geht es mit `seiten_egal: true` und danach
   `seiten`.

### Seiten neu aufteilen

`seiten {pro_seite}` — `0` heißt alles auf eine Seite. Das ordnet nur die
vorhandenen Plätze neu; die Testeinstellung „Neue Seite" (`questionsperpage`)
bleibt unberührt — **die Einstellung und die tatsächliche Aufteilung sind zwei
verschiedene Dinge** und widersprechen sich problemlos. Wer auch die Einstellung
ändern will, nimmt `aendern` am Test.

### Fragen mischen — und was es nicht ist

Gemessen: „Fragen mischen" steht **nicht** in den Testeinstellungen, sondern
als Kästchen je Testabschnitt auf der Bearbeitungsseite des Tests. Vorgabe ist
**aus**. `test_lesen` zeigt den Stand, `mischen {an, abschnitt?}` schaltet —
`abschnitt` braucht es nur, wenn der Test mehrere Testabschnitte hat.

Nicht verwechseln:

| Einstellung | Wo | Wirkung |
|---|---|---|
| **Fragen mischen** | `test_aendern`, Aktion `mischen` | Reihenfolge der Fragen |
| **Antworten mischen** (`shuffleanswers`) | Testeinstellungen, Vorgabe Ja | Auswahl innerhalb einer Frage |

Beide zusammen ergeben für jede Person eine andere Testansicht. Wer darüber
hinaus will, dass nicht einmal dieselben Fragen erscheinen, braucht
Zufallsfragen oder Fragen mit variierenden Zahlenwerten (`calculatedsimple`,
`calculatedmulti`, STACK).

## Die drei Punktzahlen

Der häufigste Fehler in Moodle-Tests, und er fällt fast immer zu spät auf.

| Zahl | Wo sie steht | Was sie bedeutet |
|---|---|---|
| Punkte der Frage (`defaultgrade`) | an der Frage in der Sammlung | Vorgabe beim Einfügen in einen Test |
| Punkte des Platzes | am Platz im Test | Was die Frage **in diesem Test** zählt |
| „Beste Bewertung" | am Test | Was der Test **im Notenbuch** zählt |

1. **Die Punkte einer Frage nachträglich zu ändern wirkt nicht
   rückwirkend.** Tests, die die Frage schon enthalten, behalten ihre
   Platzpunkte.
2. **„Beste Bewertung" folgt der Summe nicht von selbst.** Fügt man Fragen
   hinzu, steigt die Summe, die Beste Bewertung bleibt stehen. Moodle rechnet
   dann alle Ergebnisse auf den alten Wert herunter.
3. Die Anzeige „Summe der Punkte" ist die Summe der Platzpunkte, nicht die
   Beste Bewertung. Beide Zahlen stehen dicht beieinander und werden ständig
   verwechselt.

`punkte {platz, wert}` setzt die Punkte eines Platzes; die Antwort nennt die
neue Summe gleich mit. `beste_bewertung {wert: "summe"}` gleicht an.

**Ob das Angleichen gewollt ist, entscheidet der Nutzer.** Es gibt gute Gründe
für eine abweichende Beste Bewertung — etwa einen Test über 37 Rohpunkte, der
im Notenbuch auf 100 skalieren soll. Frag, wenn die Abweichung nach Absicht
aussieht (glatte Zielzahl wie 10, 20 oder 100), und weise nur darauf hin,
statt ungefragt zu ändern.

## Vor jeder Änderung: gibt es schon Versuche?

`test_lesen` meldet es als Befund, und die Freigabe der App zeigt es mit
„ACHTUNG" an. Hat jemand den Test bereits geschrieben, verschieben Änderungen an
Punkten oder Fragen rückwirkend die Bewertungen. Dann **anhalten und
nachfragen**, auch wenn der Auftrag eindeutig klang.

Die Zahl der Versuche ist eine Aggregatgröße und als Warnung erlaubt. **Wer**
geschrieben hat und **wie** — das ist tabu; die App fragt die Ergebnisseiten
gar nicht erst an.

## Testeinstellungen

`aktivitaet_lesen(cmid)` legt alle rund 160 Einstellungen nach
`cm-<cmid>/einstellungen.json`; `aendern(ordner, einstellungen)` setzt sie.
Für Klassenarbeiten die wichtigen:

| Schlüssel | Bedeutung | Werte |
|---|---|---|
| `timeopen` | Öffnet am | `JJJJ-MM-TT SS:MM` oder `aus` |
| `timeclose` | Schließt am | dito |
| `timelimit` | Zeitbegrenzung | Zahl und Einheit, wie angezeigt |
| `overduehandling` | Wenn die Zeit abgelaufen ist | automatisch abgeben, Nachfrist, verwerfen |
| `attempts` | Erlaubte Versuche | unbegrenzt, 1–10 |
| `grademethod` | Bewertungsmethode | bester, Durchschnitt, erster, letzter Versuch |
| `gradepass` | Bestehensgrenze | Zahl |
| `questionsperpage` | Neue Seite | nie, jede Frage, … |
| `navmethod` | Navigation | frei, sequenziell |
| `shuffleanswers` | Antworten mischen | ja, nein |
| `preferredbehaviour` | Frageverhalten | spätere Auswertung (Standard bei Klausuren), direkte Auswertung, interaktiv, adaptiv … |
| `canredoquestions` | Neubearbeitung erlauben | ja, nein |
| `quizpassword` | Kennwort | Text |
| `browsersecurity` | Browsersicherheit | keine, Popup mit JavaScript-Sicherheit |

Die Werte stehen in `einstellungen.json` so, wie Moodle sie anzeigt; genau so
schreibst du sie zurück. Passt ein Wert nicht, nennt die App die
Möglichkeiten.

Ist das Plugin **Safe Exam Browser** installiert, stehen seine Einstellungen
(`seb_requiresafeexambrowser` …) in `einstellungen.json`. Für echte Klausuren
ist das die Einstellung, nach der gefragt wird — sie gehört in die Hand des
Nutzers, nicht in eine Automatik.

Zwei Einstellungen mit besonderer Wirkung:

- **Zeitfenster** (`timeopen` / `timeclose`): Ein Test mit gesetztem Fenster ist
  für Lernende außerhalb nicht erreichbar. Beim Anlegen einer Klausur immer
  ausdrücklich mit dem Nutzer klären.
- **Fragen mischen** zusammen mit Zufallsfragen ergibt sehr unterschiedliche
  Testexemplare — gewollt bei Klausuren, störend, wenn Aufgaben aufeinander
  aufbauen.
