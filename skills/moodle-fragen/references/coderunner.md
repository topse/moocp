# CodeRunner

Lernende schreiben Programmcode, Moodle schickt ihn durch eine Sandbox und
vergleicht die Ausgabe mit dem, was du erwartest. Der Typ eignet sich für
alles, wo es eine ausführbare richtige Antwort gibt — eine Funktion, eine
Abfrage, eine Ausgabe — und nicht für Verständnisfragen über Code. Wer wissen
will, *warum* eine Schleife endlos läuft, fragt das mit `multichoice` oder
`essay`.

## Die eine Regel, die diesen Typ von allen anderen unterscheidet

CodeRunner prüft sich selbst — aber nur an einer Stelle.

`validateonsave` ist eingeschaltet. Beim Speichern **im Formular** schickt
Moodle die Musterlösung durch die Sandbox und vergleicht sie mit allen
Testfällen. Stimmt etwas nicht, speichert das Formular nicht, sondern zeigt
eine Tabelle „Erwartet / Erhalten".

**Der XML-Import prüft nichts.** Gemessen am 10.09.2026 mit einer absichtlich
falschen Musterlösung (`return a - b` statt `a + b`): Der Import nahm die Frage
klaglos an. Erst als dieselbe Frage geöffnet und gespeichert wurde, kam:

> 1 Test(s) fehlgeschlagen · Testfall 1 · Erwartet `5` · Erhalten `-1`

Die App zieht daraus die Konsequenz: **`fragen_importieren` speichert jede
importierte CodeRunner-Frage einmal über das Formular** und meldet je Frage
„geprueft: true" oder den Testfall, der nicht passt. Mit der App nachgemessen:
eine richtige Frage bestand, eine absichtlich falsche wurde mit „Erwartet 5,
Erhalten -1" gemeldet.

Sag dem Nutzer nie, eine CodeRunner-Frage sei fertig, solange dort nicht
`geprueft: true` steht — sie kann falsch sein, ohne dass irgendwo etwas rot
wird. Das Speichern erzeugt eine zweite Version; das ist der Preis der
Prüfung.

## Das XML ist kurz, weil der Prototyp die Arbeit macht

Ein CodeRunner-Fragetyp ist selbst eine Frage: der **Prototyp**. Er trägt die
Twig-Vorlage, die Sprache, den Bewerter und die Sandbox-Einstellungen. Deine
Frage nennt ihn in `<coderunnertype>` und lässt alles Übrige leer — dann erbt
sie es.

```xml
<question type="coderunner">
  <name><text>Summe zweier Zahlen</text></name>
  <questiontext format="html"><text><![CDATA[<p>Schreibe <code>summe(a, b)</code>.</p>]]></text></questiontext>
  <generalfeedback format="html"><text></text></generalfeedback>
  <defaultgrade>2</defaultgrade>
  <penalty>0</penalty>
  <hidden>0</hidden>
  <idnumber>py-summe</idnumber>
  <coderunnertype>python3</coderunnertype>
  <prototypetype>0</prototypetype>
  <allornothing>1</allornothing>
  <penaltyregime>10, 20, ...</penaltyregime>
  <answer>def summe(a, b):
    return a + b
</answer>
  <validateonsave>1</validateonsave>
  <testcases>
    <testcase testtype="0" useasexample="0" hiderestiffail="0" mark="1.0000000" >
      <testcode><text>print(summe(2, 3))</text></testcode>
      <stdin><text></text></stdin>
      <expected><text>5
</text></expected>
      <extra><text></text></extra>
      <display><text>SHOW</text></display>
    </testcase>
  </testcases>
</question>
```

Das ist nicht die gekürzte Fassung eines Exports, sondern genau so importiert
und danach durch das Formular bestätigt worden. Der Export schreibt zusätzlich
rund dreißig leere Elemente — leer heißt „vom Prototyp", und was leer wäre,
kann auch fehlen.

**`prototypetype` bleibt 0.** Eine 1 oder 2 macht deine Frage selbst zum
Prototyp. Sie taucht dann im Auswahlfeld auf und ändert das Verhalten aller
Fragen, die sich auf sie beziehen. Prototypen legt die App nicht an.

Von Hand tippen musst du das ohnehin nicht — `coderunner_xml(fragen, datei)`:

```json
{
  "name": "Summe zweier Zahlen",
  "idnummer": "py-summe",
  "fragetext": "<p>Schreibe <code>summe(a, b)</code>.</p>",
  "typ": "python3",
  "musterloesung": "def summe(a, b):\n    return a + b\n",
  "tests": [
    { "code": "print(summe(2, 3))", "erwartet": "5\n" },
    { "code": "print(summe(-4, 4))", "erwartet": "0\n" }
  ]
}
```

Die Bauhilfe bricht ab, wenn die Musterlösung fehlt, wenn kein Testfall da
ist, wenn ein Testfall keinen `code` oder kein `erwartet` hat — und bei `sql`
ohne Datenbankdatei. Alles Fehler, die sonst erst auffallen, wenn eine Klasse
davorsitzt.

| Angabe | Bedeutung | Vorgabe |
|---|---|---|
| `name`, `fragetext`, `typ`, `musterloesung`, `tests` | Pflicht | — |
| `idnummer` | Sachnummer | leer |
| `punkte` | Punkte der Frage | Zahl der Testfälle |
| `strafe`, `strafregime` | Abzug je Versuch | `0`, `10, 20, ...` |
| `allesOderNichts` | alle Punkte oder keine | `true` |
| `vorgabe` | Code, der im Antwortfeld vorbelegt ist | leer |
| `allgemeinesFeedback` | Rückmeldung nach dem Versuch | leer |
| `dateien[]` | Hilfsdateien aus `dateien\` (`name`) — `sql` braucht eine `.db` | — |
| `zeichnungen[]` | SVG aus `dateien\` für den Fragetext | — |

## Die vier gemessenen Prototypen

Die Instanz kennt zwanzig. Diese vier sind hin und zurück verglichen **und** in
der Sandbox gelaufen (10.09.2026):

| `typ` | Musterlösung ist … | Testfall ruft auf | Ausgabe kommt aus |
|---|---|---|---|
| `python3` | Code auf oberster Ebene | `print(summe(2, 3))` | `print` |
| `java_method` | eine Methode, ohne Klassenrumpf | `System.out.println(summe(2, 3))` | `System.out.println` |
| `nodejs` | Code auf oberster Ebene | `console.log(summe(2, 3));` | `console.log` |
| `sql` | die SQL-Abfrage selbst | meist nur ein Kommentar | sqlite3, siehe unten |

Bei `java_method` setzt die Vorlage deine Methode in eine Klasse `__tester__`
und ruft die Testfälle in einer Instanzmethode auf. Du schreibst also **keine**
Klasse und **kein** `main`, und `static` brauchst du nicht. Hinter jeden
Testfall hängt die Vorlage ein Semikolon; ob du selbst eines schreibst, ist
gleichgültig.

Die übrigen sechzehn (`c_program`, `cpp_function`, `php`, `pascal_program`,
`octave_function`, `multilanguage` …) gehen sehr wahrscheinlich genauso — nur
ist das nicht nachgesehen. `fragetypen` trennt beides zur Laufzeit. Willst du
einen davon benutzen, ist der Weg nicht Raten: eine Frage von Hand anlegen
lassen, `frage_lesen`, das Muster in `frage.xml` vergleichen.

## Testfälle

| Feld im XML | in `coderunner_xml` | Bedeutung |
|---|---|---|
| `testcode` | `code` | wird nach der Musterlösung ausgeführt |
| `stdin` | `eingabe` | Standardeingabe für diesen Lauf |
| `expected` | `erwartet` | die Ausgabe, gegen die verglichen wird |
| `extra` | `zusatz` | Zusatzcode, den manche Vorlagen einsetzen |
| `display` | `anzeige` | `SHOW`, `HIDE`, `HIDE_IF_FAIL`, `HIDE_IF_SUCCEED` |
| `mark` | `punkte` | Gewicht dieses Testfalls |
| `testtype` | `art` | 0 normal, 1 nur Vorabprüfung, 2 beides |
| `useasexample` | `beispiel` | erscheint als Beispiel in der Frage |
| `hiderestiffail` | `versteckeRest` | bricht die Anzeige nach diesem Fehler ab |

**Ein Testfall ohne `code` verschwindet** im Formular kommentarlos; die Frage
hätte dann weniger Tests als gedacht. Braucht ein Prototyp keinen Aufruf — bei
`sql` ist das der Normalfall —, schreib einen Kommentar in `code`
(`-- alle Artikel`). Der zählt als Inhalt und stört die Ausführung nicht.

`allornothing` steht auf 1: Es gibt alle Punkte oder keine. Für Übungsfragen
ist `allesOderNichts: false` oft freundlicher, dann zählt jeder Testfall mit
seinem Gewicht.

## Die erwartete Ausgabe muss genau stimmen

Verglichen wird Zeichen für Zeichen. Ein fehlender Zeilenumbruch, eine
Spaltenbreite, ein Leerzeichen zu viel — und der Test schlägt fehl, obwohl der
Code richtig ist. Bei `print`-Ausgaben ist das leicht vorherzusagen, bei
sqlite3-Tabellen praktisch nicht:

```
nummer  bezeichnung  preis
------  -----------  -----
1       Schraube     0.12
2       Mutter       0.08
3       Scheibe      0.05
```

Meldet der Nachweis „Erwartet … Erhalten …" und ist das **Erhaltene
inhaltlich richtig**, nur anders formatiert, dann ist das Erhaltene die
bessere erwartete Ausgabe: im Ordner der Frage (`frage_lesen`) übernehmen und
mit `aendern` speichern — das Formular prüft dabei erneut. Vorher lesen, ob die
Ausgabe *inhaltlich* stimmt; eine falsche Ausgabe als Erwartung übernommen
macht die Frage dauerhaft falsch.

## `sql` braucht eine Datenbank

Der `sql`-Prototyp ist in Wahrheit ein Python-Skript, das `sqlite3` aufruft. Es
sucht nach einer `.db`-Datei und bricht sonst ab:

> `Exception: No DB files found!`

Die Datei hängt als **Hilfsdatei** an der Frage; im XML steht sie
base64-kodiert **innerhalb von `<testcases>`**, hinter dem letzten
`</testcase>` — `coderunner_xml` setzt sie dorthin, wenn sie in `dateien\`
liegt und in `dateien` genannt ist:

```json
{
  "name": "Alle Artikel", "typ": "sql",
  "fragetext": "<p>Gib alle Zeilen der Tabelle <code>artikel</code> aus.</p>",
  "musterloesung": "SELECT * FROM artikel;",
  "tests": [{ "code": "-- alle Artikel", "erwartet": "…" }],
  "dateien": [{ "name": "artikel.db" }]
}
```

Gemessen: Eine 1024 Byte große SQLite-Datei (`PRAGMA page_size=512`) kommt beim
Import als Hilfsdatei an und läuft anschließend durch. Genau eine `.db` — bei
mehreren bricht die Vorlage mit „Multiple DB files not implemented yet" ab.

Die Datenbank baust du vorher selbst (drei Zeilen `sqlite3` oder Python). Für
Unterrichtsdaten gilt dasselbe wie überall: erfundene Namen, die als erfunden
erkennbar sind.

## Was die App bei CodeRunner nicht tut

- **Keine Prototypen anlegen oder ändern.** Sie wirken auf alle Fragen, die sie
  benutzen, oft kursübergreifend.
- **Keine eigenen Twig-Vorlagen.** `<template>` bleibt leer. Eine eigene
  Vorlage ist Programmierung im Fragetext; sie gehört in einen Prototyp.
- **Keine Bewerter-Vorlagen** (`TemplateGrader`) und keine Sandbox-Parameter.
- **Keine Abgaben von Lernenden lesen.** Der Reiz ist groß, sich „mal die
  Einreichungen anzusehen", um die Testfälle zu verbessern. Das ist eine
  personenbezogene Auswertung und bleibt aus.

## Der Ablauf am Stück

1. `fragetypen(sammlung)` — welche Prototypen kennt die Instanz?
2. `coderunner_xml(fragen, datei)` — baut und prüft das XML.
3. `fragen_importieren(sammlung, kategorie, datei)` — legt an, speichert jede
   Frage einmal über das Formular und meldet je Frage den Nachweis.
4. Steht irgendwo nicht `geprueft: true`: dem Nutzer sagen, welcher Testfall
   nicht passt, nachbessern (`frage_lesen`, `aendern`), bis er besteht.

Beim Aufräumen von Proben: Eine importierte und einmal gespeicherte Frage hat
zwei Versionen; `fragen_loeschen` löscht beide.
