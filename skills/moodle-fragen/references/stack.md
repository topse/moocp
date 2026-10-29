# STACK: berechnete Fragen mit Rückmeldebaum

## Warum STACK hier eine Sonderrolle hat

STACK gehört **nicht** zum Moodle-Kern. Trotzdem legt die App STACK-Fragen an.
Der Grund ist kein Geschmacksurteil:

**STACK hat eine eingebaute Selbstprüfung.** Zu einer STACK-Frage gehören
Testfälle, die im XML mitgeliefert werden, und STACK sagt maschinenlesbar, ob
sie bestanden sind. Bei den meisten anderen Typen muss man dem selbst
geschriebenen XML glauben. Hier kann man nachmessen — und deshalb ist das
Anlegen verantwortbar.

Die Umkehrung gilt genauso: **Eine STACK-Frage ohne bestandene Testfälle ist
nicht mehr wert als geratenes XML.** `stack_xml` verweigert eine Frage ohne
Testfälle.

## Voraussetzung: Maxima muss laufen

STACK rechnet über das Computeralgebrasystem **Maxima** auf dem Server. Läuft
das nicht, lässt sich die Frage zwar importieren, sie rendert aber nicht und
bewertet nicht. Prüfen kostet einen Aufruf:

```
stack_cas(ausdruck: "Ergebnis {@x@}", variablen: "x : 3.5*2;")
```

Gerechnet wird, was in `{@…@}` steht. Kommt `7.0` zurück, ist alles in
Ordnung. Bleibt `3.5*2` unausgewertet stehen, ist entweder die
Auto-Vereinfachung aus (`vereinfachen: false`) oder das CAS antwortet nicht.

## Der Arbeitsablauf

Fünf Schritte, und keiner davon ist optional:

1. **Rechnung im CAS prüfen** — `stack_cas`. Erst wenn die Maxima-Ausdrücke
   das Erwartete liefern, lohnt es sich, eine Frage zu bauen.
2. **Frage beschreiben und bauen** — `stack_xml(sammlung, fragen, datei)`.
3. **Importieren** — `fragen_importieren(sammlung, kategorie, datei)`. Die
   Testfälle laufen danach automatisch; das Ergebnis steht in der Antwort.
4. **Varianten einsetzen**, wenn die Aufgabenvariablen `rand()` benutzen —
   `stack_varianten(sammlung, frage, anzahl: 5)`.
5. **Aufgabenhinweise der Varianten ansehen** — `stack_varianten(sammlung,
   frage)` ohne Anzahl. Zufallszahlen erzeugen gern Brüche wie `7/2`, die im
   Unterricht unschön sind.

## Die Beschreibung für `stack_xml`

`stack_xml` nimmt eine knappe Beschreibung je Frage und setzt daraus das
vollständige XML — die rund 30 Anzeigeelemente, die Vorgaben je Eingabefeld,
das spezifische Feedback (`[[feedback:prt1]]` je Baum), die Antworthinweise
nach dem Muster `prt1-1-T`/`prt1-1-F`, die Gewichtung der Bäume zu gleichen
Teilen und die STACK-Version der Instanz.

```json
{
  "name": "Ohmsches Gesetz und Leistung",
  "idnummer": "et-ohm-leistung-01",
  "punkte": 2,
  "variablen": "I : (rand(9)+1)/2;\nR : 10*(rand(9)+2);\nU : I*R;\nP : U*I;\nPfalsch : U*R;",
  "hinweis": "U={@U@} V, R={@R@} Ohm, I={@I@} A, P={@P@} W",
  "fragetext": "<p>An einem Widerstand \\(R = {@R@}\\,\\Omega\\) liegt die Spannung \\(U = {@U@}\\,\\mathrm{V}\\).</p><p><strong>a)</strong> Wie groß ist der Strom \\(I\\) in A? [[input:ans1]] [[validation:ans1]]</p><p><strong>b)</strong> Welche Leistung \\(P\\) in W wird umgesetzt? [[input:ans2]] [[validation:ans2]]</p>",
  "allgemeinesFeedback": "<p>\\(I = U/R = {@I@}\\) A, \\(P = U \\cdot I = {@P@}\\) W</p>",
  "eingaben": [
    { "name": "ans1", "typ": "numerical", "tans": "I", "boxsize": 10 },
    { "name": "ans2", "typ": "numerical", "tans": "P", "boxsize": 10 }
  ],
  "prts": [
    { "name": "prt1", "knoten": [
      { "beschreibung": "Strom richtig?", "test": "NumRelative", "sans": "ans1", "tans": "I", "optionen": "0.001",
        "falsch": { "feedback": "<p>Nutze den Zusammenhang zwischen U, R und I.</p>" } } ] },
    { "name": "prt2", "knoten": [
      { "nr": 1, "beschreibung": "Leistung genau richtig?", "test": "NumRelative", "sans": "ans2", "tans": "P", "optionen": "0.001",
        "falsch": { "weiter": 2 } },
      { "nr": 2, "beschreibung": "U mal R statt U mal I", "test": "NumRelative", "sans": "ans2", "tans": "Pfalsch", "optionen": "0.001",
        "wahr": { "punkte": 0.25, "feedback": "<p>Hier wurde \\(U \\cdot R\\) gerechnet. Die Leistung ist \\(P = U \\cdot I\\).</p>" },
        "falsch": { "weiter": 3 } },
      { "nr": 3, "beschreibung": "Zahlenwert richtig, aber in kW", "test": "NumRelative", "sans": "1000*ans2", "tans": "P", "optionen": "0.001",
        "wahr": { "punkte": 0.5, "feedback": "<p>Der Zahlenwert passt, aber die Einheit: gefragt war W, nicht kW.</p>" },
        "falsch": { "feedback": "<p>Rechne die Leistung aus Spannung und Strom.</p>" } } ] }
  ],
  "tests": [
    { "beschreibung": "Alles richtig", "eingaben": { "ans1": "I", "ans2": "P" },
      "erwartet": { "prt1": { "punkte": 1, "hinweis": "prt1-1-T" }, "prt2": { "punkte": 1, "hinweis": "prt2-1-T" } } },
    { "beschreibung": "Leistung als U mal R", "eingaben": { "ans1": "I", "ans2": "Pfalsch" },
      "erwartet": { "prt1": { "punkte": 1, "hinweis": "prt1-1-T" }, "prt2": { "punkte": 0.25, "abzug": 0.1, "hinweis": "prt2-2-T" } } },
    { "beschreibung": "Leistung in kW statt W", "eingaben": { "ans1": "I", "ans2": "P/1000" },
      "erwartet": { "prt1": { "punkte": 1, "hinweis": "prt1-1-T" }, "prt2": { "punkte": 0.5, "abzug": 0.1, "hinweis": "prt2-3-T" } } },
    { "beschreibung": "Beides falsch", "eingaben": { "ans1": "0", "ans2": "0" },
      "erwartet": { "prt1": { "punkte": 0, "abzug": 0.1, "hinweis": "prt1-1-F" }, "prt2": { "punkte": 0, "abzug": 0.1, "hinweis": "prt2-3-F" } } }
  ]
}
```

| Angabe | Bedeutung | Vorgabe |
|---|---|---|
| `name`, `fragetext` | Pflicht | — |
| `idnummer` | Sachnummer — überlebt jede Änderung | leer |
| `punkte` | Punkte der Frage | 1 |
| `strafe` | Abzug je falschem Versuch | 0.1 |
| `variablen` | Aufgabenvariablen (Maxima) | — |
| `hinweis` | Aufgabenhinweis — unterscheidet die Varianten | — |
| `beschreibung` | interne Beschreibung der Frage | — |
| `allgemeinesFeedback`, `spezifischesFeedback` | Rückmeldungen | spezifisch: `[[feedback:…]]` je Baum |
| `anzeige` | einzelne Anzeigeoptionen überschreiben (`decimals`, `multiplicationsign` …) | Komma, Malpunkt |
| `eingaben[]` | `name`, `typ`, `tans`, dazu jede Eingabe-Option (`boxsize`, `forbidfloat`, `options` …) | — |
| `prts[]` | `name`, `knoten`, `wert?` (Anteil), `vereinfachen?`, `feedbackvariablen?` | gleiche Anteile |
| `knoten[]` | `nr`, `test`, `sans`, `tans`, `optionen`, `beschreibung`, `leise`, `wahr`, `falsch` | Test `AlgEquiv` |
| `wahr` / `falsch` | `punkte`, `weiter`, `hinweis`, `feedback` | wahr 1, falsch 0, Ende |
| `tests[]` | `beschreibung`, `eingaben {}`, `erwartet {prt: {punkte, abzug, hinweis}}` | — |
| `zeichnungen[]` | `name` einer SVG in `dateien\` | — |

## Aufgabenvariablen

Maxima-Code, Anweisungen mit `;` getrennt. Zuweisung ist `:`, nicht `=`.

```
I : (rand(9)+1)/2;      /* 0,5 · 1,0 · … · 4,5 */
R : 10*(rand(9)+2);     /* 20 … 100 */
U : I*R;
```

**Zufallszahlen so wählen, dass schöne Ergebnisse entstehen.** `rand(n)`
liefert eine ganze Zahl von 0 bis n−1. Der klassische Fehler ist, Ausgangswerte
zu würfeln und das Ergebnis rechnen zu lassen: Aus `U : 10*(rand(8)+16)` und
`R : 10*(rand(9)+2)` wird `I = 23/7` — korrekt, aber im Unterricht
unbrauchbar. **Umgekehrt vorgehen:** die Werte würfeln, die glatt sein sollen,
und den Rest daraus ausrechnen.

Ob das gelungen ist, sieht man erst an den eingesetzten Varianten (Schritt 5).

## Fragetext

| Platzhalter | Bedeutung |
|---|---|
| `[[input:ans1]]` | Hier erscheint das Eingabefeld. **Ohne diesen Platzhalter kein Feld.** |
| `[[validation:ans1]]` | Rückmeldung „so habe ich Ihre Eingabe verstanden". Bei `dropdown`, `radio` und `checkbox` weglassen. |
| `{@ausdruck@}` | Wert aus den Aufgabenvariablen, gesetzt und formatiert |
| `[[feedback:prt1]]` | Rückmeldung eines Baums — steht im spezifischen Feedback |

`stack_xml` bricht ab, wenn zu einer Eingabe der `[[input:…]]`-Platzhalter
fehlt. Das ist der häufigste Anfängerfehler und fiele sonst erst in der
Vorschau auf.

Formeln in LaTeX: `\(…\)` inline, `\[…\]` abgesetzt. In JSON den Backslash
verdoppeln.

## Eingabetypen

Auf der Zielinstanz durchgemessen sind `numerical`, `units`, `algebraic`,
`string`, `dropdown` und `radio`; `stack_xml` nimmt außerdem `checkbox`,
`matrix`, `boolean`, `equiv`, `textarea` und `notes` an, nicht nachgeprüft.

| Typ | Wofür | Musterantwort (`tans`) |
|---|---|---|
| `numerical` | reine Zahl | `P` |
| `algebraic` | Term mit Variablen | `3*(x-1)^2` |
| `units` | **Zahl mit Einheit** — für Technik der wichtigste | `ta1` mit `ta1 : stackunits_make(R*ohm);` |
| `string` | Fachbegriff als Text | `"Kurzschluss"` |
| `dropdown` | Auswahlliste | `[["Reihenschaltung",true],["Parallelschaltung",false]]` |
| `radio` | dasselbe als Optionsfelder | wie `dropdown` |
| `checkbox` | Mehrfachauswahl | wie `dropdown`, mehrere `true` |

**`forbidfloat` steht auf `0`.** Der STACK-Standard ist `1` und weist
ausgerechnet die Dezimalzahl zurück, die man im Berufsschulunterricht
erwartet. Wer eine exakte Bruchangabe erzwingen will, setzt es je Eingabe
wieder auf `1`.

### Einheiten

Einheiten sind der Grund, warum STACK für Elektrotechnik interessant ist: `47`
und `47 Ω` und `0,047 kΩ` lassen sich unterscheiden und getrennt bewerten.
Einheitennamen sind Maxima-Bezeichner: `ohm`, `V`, `A`, `W`, `Hz`, `s`, `m`,
mit SI-Vorsätzen (`kohm`, `mA`). Das Ω-Zeichen entsteht bei der Anzeige, nicht
in der Eingabe.

**Zerlegen einer Einheitenangabe** — gemessen, weil geraten falsch war:

```
n : first(args(stackunits_make(ans1)));    /* Zahlenwert  */
e : second(args(stackunits_make(ans1)));   /* Einheit     */
```

Die naheliegenden Namen `stackunits_num()` und `stackunits_units()` gibt es
**nicht**. Wer sie benutzt, bekommt keinen Fehler, sondern einen
unausgewerteten Ausdruck — und der Antworttest scheitert dann aus scheinbar
unerklärlichem Grund. Im Zweifel `stack_cas` fragen.

## Rückmeldebäume (PRT)

Ein Baum ist eine Kette von Knoten. Jeder Knoten führt **einen** Antworttest
aus und verzweigt nach wahr und falsch: Punkte vergeben und aufhören
(`weiter` weglassen oder `-1`), oder weiter zu einem anderen Knoten
(`weiter: 2` heißt „Knoten 2").

### Knoten werden gezählt — an mehreren Stellen verschieden

Das ist die unangenehmste Falle des ganzen Fragetyps, auf der Instanz
gemessen:

| Wo | Erster Knoten | Zweiter Knoten |
|---|---|---|
| Beschriftung im Formular | „Knoten 1" | „Knoten 2" |
| Antwortnotiz | `prt1-1-T` | `prt1-2-T` |
| Formularfeld-Index | `prt1answertest[0]` | `prt1answertest[1]` |
| XML `<node><name>` | `0` | `1` |
| Auswahlwert bei `truenextnode` | `0` | `1` (`-1` = Ende) |

**Die Beschreibung benutzt durchgehend die sichtbare Nummer**, also die aus der
Formularbeschriftung und den Antwortnotizen: `nr: 1` ist „Knoten 1",
`weiter: 2` heißt „weiter zu Knoten 2". `stack_xml` rechnet an einer einzigen
Stelle um. Eine `0` wird **abgewiesen** statt stillschweigend umgedeutet — eine
falsch getroffene Verzweigung fiele sonst erst auf, wenn die Frage falsch
bewertet.

Genau daraus entsteht der didaktische Wert: Man kann **typische Fehler gezielt
abfangen** und mit passender Rückmeldung teilweise bewerten, statt nur richtig
und falsch zu kennen.

```
Knoten 1: Ergebnis genau richtig?
  ja   -> 1,0  Ende
  nein -> Knoten 2
Knoten 2: der bekannte Formelfehler?
  ja   -> 0,25 "Du hast U mal R gerechnet"   Ende
  nein -> Knoten 3
Knoten 3: Zahlenwert richtig, Einheit falsch?
  ja   -> 0,5  "Zahlenwert passt, Einheit prüfen"   Ende
  nein -> 0    "Rechne P aus U und I"
```

**Reihenfolge ist Bewertung.** Der erste zutreffende Test entscheidet.
Deshalb oben das Strengste, unten das Nachsichtigste.

**Antworthinweise** (`prt2-1-T`, `prt2-2-F` …) benennen den durchlaufenen
Pfad. Der Testlauf zeigt ihn vollständig an — `prt2-1-F | prt2-2-F | prt2-3-T`
heißt: an Knoten 1 und 2 vorbei, an Knoten 3 getroffen. Beim Nachbessern ist
das die wichtigste Spalte, weil sie zeigt, **wo** der Baum anders abgebogen ist
als gedacht.

`leise: true` an einem Knoten unterdrückt dessen Standardrückmeldung. Sinnvoll
bei Zwischenknoten, die nur verzweigen.

## Antworttests

| Test | Prüft | `optionen` |
|---|---|---|
| `AlgEquiv` | algebraische Gleichwertigkeit — der Standard | — |
| `NumRelative` | Zahl mit relativer Toleranz | `0.001` |
| `NumAbsolute` | Zahl mit absoluter Toleranz | `0.5` |
| `NumSigFigs` | Zahl auf n geltende Ziffern | `3` |
| `UnitsStrictRelative` | Zahl **und** Einheit, Einheit genau so | `0.01` |
| `UnitsRelative` | Zahl und Einheit, umgerechnete Einheiten erlaubt | `0.01` |
| `String` | Zeichenkette, exakt | — |
| `StringSloppy` | Zeichenkette, Groß-/Kleinschreibung und Leerzeichen egal | — |
| `EqualComAss` | gleich bis auf Kommutativität und Assoziativität | — |
| `SameType` | nur die Bauart der Antwort (Menge, Liste, Gleichung …) | — |

Die Einheitentests liefern eigene Hinweise mit — `ATUnits_incompatible_units`,
`ATUnits_correct_numerical`. Für ein reines „Einheit falsch, Zahl richtig" muss
man deshalb nicht zwingend einen zweiten Knoten bauen; für eine **eigene
Punktzahl** dagegen schon.

## Testfälle

- Die Werte sind **Maxima-Ausdrücke**, keine Zeichenketten des Nutzers. `I`,
  `P/1000`, `Pfalsch` beziehen sich auf die Aufgabenvariablen. Texte gehören in
  Anführungszeichen: `"\"Kurzschluss\""`.
- `punkte` ist der Anteil **dieses** Baums (0 bis 1), nicht die Punktzahl der
  Frage.
- `abzug` ist `0` bei voller Punktzahl und sonst der Wert aus `strafe`
  (Vorgabe 0,1).
- `hinweis` ist der erwartete Antworthinweis. Er ist die eigentliche Prüfung:
  Punkte können zufällig stimmen, der Pfad durch den Baum nicht.
- **Bei einer Auswahlliste (`dropdown`, `radio`, `checkbox`) muss die Testeingabe eine der Optionen sein, wie sie in `tans` dasteht.** STACK setzt die Aufgabenvariablen zwar ein, vereinfacht aber nicht: Zur Option `4` kommt `3+1` als `3+1` an und zählt nicht als Option, der Testfall prüft dann nichts. Soll der Wert aus einer Rechnung kommen, gehört er als Variable in die Aufgabenvariablen (`kn : kb+1;`) und steht dann in den Optionen **und** im Testfall; `stack_testen` meldet sonst „Eingabe … nicht übernommen".

**Mindestens drei Fälle**: alles richtig, der eingeplante typische Fehler,
alles falsch. Ohne den mittleren ist der Zweig für den typischen Fehler
ungeprüft.

Später erneut laufen lassen: `stack_testen(sammlung, frage, seed?)`.

## Varianten einsetzen

Bei `rand()` in den Aufgabenvariablen prüft ein Testlauf nur **eine**
Variante. Erst das Einsetzen rechnet weitere durch und lässt die Testfälle
darauf laufen:

```
stack_varianten(sammlung, frage, anzahl: 5)    -- nach Freigabe
stack_varianten(sammlung, frage)               -- was eingesetzt ist
stack_varianten(sammlung, frage, seed: 61853556)  -- genau diese Variante
```

Danach die Aufgabenhinweise ansehen. Im Testlauf des Beispiels oben kamen
`I = 1 A` und `I = 4 A` heraus, aber auch `I = 7/2 A` mit `P = 1225/2 W` —
rechnerisch richtig, für eine Klassenarbeit unbrauchbar. **Das sieht man nur
hier**, und es ist der Hauptgrund, warum dieser Schritt nicht optional ist.

## Gemessene Fallstricke

- **Die Versionsangabe.** `stackversion` muss die aktuelle Version der
  Instanz tragen, sonst markiert STACK die Frage dauerhaft als
  nachbesserungsbedürftig. `stack_xml` liest sie aus der Instanz.
- **Auto-Vereinfachung im CAS-Notizblock.** Ohne sie wertet Maxima nichts
  aus, und man hält die stehengebliebene Formel für ein defektes CAS.
  `stack_cas` schaltet sie ein, sofern nicht `vereinfachen: false`.
- **`stackunits_num` / `stackunits_units` gibt es nicht** — siehe oben.
- **Auswahllisten brauchen kein `[[validation:…]]`.**
- **Die Anteile der Bäume summieren sich auf 1.** `wert` ist der Anteil, nicht
  die Punktzahl. Ohne Angabe wird gleichmäßig verteilt; bei ungleicher
  Gewichtung müssen die Werte zusammen 1 ergeben.

## Was die App bei STACK nicht tut

- **Struktur einer vorhandenen Frage ändern** — ein zusätzlicher Knoten, ein
  zusätzliches Eingabefeld, ein weiterer Testfall. Inhalte vorhandener Knoten
  und Eingaben lassen sich ändern (siehe unten), die Struktur nicht.
- **Einen vorhandenen Testfall ändern oder löschen.** Er steht auf einer eigenen Seite, die die App nicht aufruft; in Moodle gehen beide Wege, unter den Ergebnissen jedes Testfalls auf der Seite mit den Fragetests. Über die App bleibt nur, die Frage neu anzulegen — deshalb die Testfälle vor dem Import genau nehmen.
- **„Antworten analysieren" öffnen.** Diese Seite wertet **echte Abgaben** aus
  und ist gesperrt. Testlauf, Varianten und CAS-Notizblock arbeiten nur mit der
  Frage selbst und sind offen.

## Eine vorhandene Frage ändern

Der Import legt immer neu an — geändert wird über das Bearbeitungsformular:

1. `fragen_lesen(sammlung, idnummer: "et-ohm-leistung-01")` — die aktuelle
   questionid
2. `frage_lesen(sammlung, frage)` — `frage-<id>/` mit den Textfeldern als
   `<feld>.html` und allen rund 150 Feldern in `einstellungen.json`
   (Aufgabenvariablen, Musterantworten, Knoten)
3. Textfelder bearbeiten, Einstellungen als Parameter an
   `aendern(ordner, einstellungen)`
4. `stack_testen` auf der **neuen** questionid

Die Feldnamen sind die des Formulars, nicht die der Beschreibung: Die
Musterantwort heißt `ans1modelans`, ein Knoten wird über den
**0-basierten** Formularindex angesprochen (`prt2truescore[0]` ist Knoten 1).
Lies sie aus `einstellungen.json`, statt sie zu raten.

Drei Punkte, die dabei zählen:

- **Es entsteht eine neue Version mit neuer questionid.** Testfälle,
  Rückmeldebäume und eingesetzte Varianten überstehen die Änderung —
  nachgemessen.
- **Tests ziehen „Immer die neueste" Version.** Die Änderung wirkt sofort in
  jedem Test, der die Frage benutzt.
- **Danach die Testfälle laufen lassen.** Eine geänderte Aufgabenvariable kann
  jeden Zweig des Baums verschieben, und die Testfälle sagen als Einzige, ob es
  noch stimmt.

## XML von Hand

Nur nötig, wenn `stack_xml` etwas nicht abdeckt. Dann den Weg gehen, der bei
jedem Fragetyp gilt: **eine Frage dieser Art von Hand anlegen lassen,
`frage_lesen`, Muster in `frage.xml` ablesen.** Die Elementreihenfolge ist die
des Exports: `name`, `questiontext`, `generalfeedback`, `defaultgrade`,
`penalty`, `hidden`, `idnumber`, `stackversion`, `questionvariables`,
`specificfeedback`, `questionnote`, `questiondescription`, die
Anzeigeoptionen, dann `input`, `prt`, `qtest`.
