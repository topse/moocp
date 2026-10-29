# Welcher Test, welcher Fragetyp: Anregungen

Hier steht, wofür sich Tests und Fragetypen bewährt haben. Das sind Anregungen für deine Vorschläge, keine Liste erlaubter Einsätze: Passt ein Typ für einen Zweck, der hier nicht steht, schlag ihn vor und sag, warum. Bindend sind nur die Fakten unter „Grenzen", also was ein Typ prüft, wie leicht er sich erraten lässt und was die App nicht kann. Was im SKILL.md schon steht, gilt daneben weiter und wird hier nicht wiederholt: welche Zuordnung, welche Typen AFB III tragen, wann die Zahlen variieren, Einheit und Rundung, Zeichnungen mit JSXGraph (`references/jsxgraph.md`).

Abwechslung ist kein Selbstzweck, aber ein Test aus acht Multiple-Choice-Fragen prüft achtmal dasselbe: Wiedererkennen. Wählt dein Plan für alle Fragen denselben Typ, sag, was ein anderer Typ an einer Stelle zusätzlich prüfen würde, und lass die Lehrkraft entscheiden.

## Wozu der Test da ist

Ein Test ist nicht nur eine Klassenarbeit. Der Zweck entscheidet über die Einstellungen, deshalb steht er im Plan vor allem anderen. Vier Zwecke kommen häufig vor:

| Zweck | wozu | Frageverhalten | Versuche | Rückmeldung |
|---|---|---|---|---|
| **Üben** | so oft, bis es sitzt | interaktiv mit mehreren Versuchen oder direkte Auswertung | unbegrenzt | sofort, je Antwort, mit Hinweis auf den Fehler |
| **Selbstkontrolle** | nach einem Blatt oder einer Phase: Sitzt es? | direkte Auswertung | wenige | sofort, mit Verweis auf die Stelle, an der es steht |
| **Diagnose** | vor einer Phase: Was ist schon da? | spätere Auswertung | einer | knapp; die Auswertung sieht die Lehrkraft in Moodle |
| **Leistungsfeststellung** | Note | spätere Auswertung | einer | erst nach dem Schließen |

Die genauen Beschriftungen und alle weiteren Einstellungen, auch was die Lernenden nach einem Versuch sehen, stehen in `einstellungen.json` des Tests (`references/tests.md`, „Testeinstellungen").

**Zum Üben trägt die Rückmeldung den Test.** Ohne Rückmeldung je Antwort erfährt niemand, was falsch war und warum; der Test ist dann eine Abfrage. Eine gute Rückmeldung nennt den typischen Fehler hinter der falschen Wahl und wo das Richtige steht. Zufallsfragen und variierende Zahlen machen jeden Versuch zu einem neuen, und eine Übung ohne Bewertung oder mit geringem Gewicht nimmt den Druck, der beim Üben stört.

**Zur Leistungsfeststellung gehören** Zeitfenster und Zeitbegrenzung, die Frage nach dem Mischen (SKILL.md, „Drei Fragen, bevor der Test steht") und die Prüfungsumgebung, etwa Safe Exam Browser. Das entscheidet die Lehrkraft; du sprichst es an.

## Wo der Test geschrieben wird

Am eigenen Gerät, im Computerraum oder auf Papier. In einem Kurs, der meist auf Papier läuft, ist ein Test im Computerraum eine Abwechslung und wertet sich obendrein selbst aus; schlag es vor, wo es passt. Ein Übungstest läuft auch auf dem Handy, im Browser oder in der Moodle-App, und damit auch zu Hause. Nicht jede Lehrkraft denkt daran; sag es konkret („Die Übung können die Lernenden am Handy machen, so oft sie wollen"). Umgekehrt braucht auch ein Test am Gerät manchmal eine Papierfassung: für den Nachschreibtermin, bei Ausfall der Technik, als Nachteilsausgleich. Die App legt keine Papierfassung an; wird eine gebraucht, steht sie im Plan als eigenes Blatt.

Auf Papier übertragen lassen sich Multiple Choice, Wahr/Falsch, Kurzantwort, Numerisch, Freitext, Lückentexte, Zuordnung und Anordnung. Schwer oder gar nicht: variierende Zahlen (jede Fassung bräuchte eigene Werte und Lösungen), STACK mit Zufallswerten, CodeRunner und Zeichnungen zum Ziehen.

## Die Fragetypen

### Multiple Choice (`multichoice`)

**Bewährt für** Begriffe, Zusammenhänge, Zuordnung einer Situation zu einer Regel, und mit Messwerten für Fehlersuche (AFB II–III, SKILL.md). Am meisten leistet er, wenn die falschen Antworten aus typischen Fehlern stammen: Dann sagt die falsche Wahl, was nicht verstanden ist, und die Rückmeldung setzt genau dort an. **Grenzen:** Er prüft Wiedererkennen, nicht Formulieren. Bei einer richtigen von vier Antworten trifft Raten jedes vierte Mal. Bei mehreren richtigen brauchen die falschen Antworten einen Abzug (negatives `fraction`), sonst lohnt es sich, alles anzukreuzen.

### Wahr/Falsch (`truefalse`)

**Bewährt für** schnelle Selbstkontrolle und dafür, eine verbreitete Fehlvorstellung sichtbar zu machen („Ein Fehlerstromschutzschalter schützt auch vor Kurzschluss."). **Grenzen:** Raten trifft jedes zweite Mal; in einem bewerteten Test trägt eine einzelne Aussage kaum. Mehrere Aussagen zu einem Gegenstand gehören in eine Frage `mtf`.

### Mehrfach Wahr/Falsch (`mtf`)

**Bewährt für** mehrere Aussagen zu einer Situation, einem Bild, einer Messung, die alle zusammen zeigen, ob der Sachverhalt verstanden ist. **Grenzen:** Mit Teilpunkten je Zeile (`subpoints`) bleibt Raten lohnend; alles oder nichts (`mtfonezero`) drückt es, ist aber hart. Welche Wertung, steht im Plan.

### Kurzantwort (`shortanswer`)

**Bewährt für** einen Begriff, eine Bezeichnung, ein Kürzel aus dem Gedächtnis: Abrufen ist schwerer und nachhaltiger als Wiedererkennen. **Grenzen:** Moodle vergleicht Text. Ein Tippfehler, ein Synonym, eine andere Schreibweise gilt als falsch, solange sie nicht als Antwort angelegt ist; für Sätze taugt der Typ nicht. Die zulässigen Schreibweisen gehören in den Plan.

### Numerisch (`numerical`)

**Bewährt für** ein Rechenergebnis, ein abgelesenes Maß, einen Wert aus dem Tabellenbuch. **Grenzen:** Mit festen Zahlen hat die ganze Lerngruppe dieselbe Lösung (SKILL.md, „Bei Rechenaufgaben: variieren die Zahlen?").

### Berechnet (`calculated`, `calculatedsimple`, `calculatedmulti`)

**Bewährt für** Rechenaufgaben, bei denen jeder eigene Zahlen bekommt, und für Übungen: Jede Wiederholung bringt neue Werte, also wird das Verfahren geübt, nicht das Ergebnis gemerkt. **Grenzen:** Bewertet wird nur das Ergebnis, nicht der Weg; wer Teilpunkte für den Weg will, nimmt STACK.

### Freitext (`essay`)

**Bewährt für** Begründen, Bewerten, Beschreiben eines Vorgehens (AFB III), mit Erwartungshorizont für die Lehrkraft. **Denkbar auch** als kurze Reflexion am Ende einer Übung ohne Punkte, oder mit Dateianhang für ein Foto einer Skizze. **Grenzen:** Die Lehrkraft bewertet von Hand, und das kostet Zeit; die App liest die Antworten nie.

### Beschreibung (`description`)

**Bewährt für** eine Situationsbeschreibung, auf die sich mehrere Fragen beziehen, wie die Handlungssituation einer Lernsituation. Sie zählt keine Punkte. **Grenzen:** Fragen, die auf sie folgen, brauchen eine feste Reihenfolge.

### Lückentext / Cloze (`multianswer`)

**Bewährt für** Aufgaben, die wie ein Dokument aus dem Beruf aussehen: ein Prüfprotokoll, ein Formular, ein Datenblatt mit Lücken, in denen gerechnet, ausgewählt und ein Begriff eingetragen wird, mit Teilpunkten je Lücke. **Grenzen:** Der Aufbau ist empfindlich (`references/fragetypen.md`, „Der Fallstrick, der die ganze Frage kostet").

### Lückentextauswahl (`gapselect`) und Drag-and-Drop auf Text (`ddwtos`)

**Bewährt für** Fachsprache im Zusammenhang: eine Regel vervollständigen, Begriffe in ein Schema oder eine Tabelle ziehen, jedes Element genau einmal (`ddwtos`). Auf einem Tablet lässt sich das Ziehen angenehm bedienen. **Grenzen:** Die Auswahl ist vorgegeben; wer den Begriff selbst finden soll, bekommt eine Kurzantwort oder `gapfill`.

### Erweiterter Lückentext (`gapfill`)

**Bewährt für** Merksätze und Definitionen, in denen die Lernenden die Lücken selbst füllen, schnell gebaut aus eckigen Klammern im Text. **Grenzen:** Beim Eintippen gilt derselbe Textvergleich wie bei der Kurzantwort.

### Zuordnung (`match`, `ddmatch`) und zufällige Zuordnung (`randomsamatch`)

**Bewährt für** Kategorien, in die mehrere Elemente gehören (SKILL.md, „Zuordnung: erst die Regel, dann der Typ"). `randomsamatch` zieht Kurzantwortfragen einer Kategorie und macht eine Zuordnung daraus, bei jedem Versuch eine andere: gut zum Üben von Begriffen und Definitionen. **Grenzen:** `randomsamatch` braucht genügend Kurzantwortfragen in derselben Kategorie.

### Anordnung (`ordering`)

**Bewährt für** Abläufe, in denen die Reihenfolge das Fachliche ist: die fünf Sicherheitsregeln, die Schritte einer Inbetriebnahme, eine Prüfreihenfolge, die Phasen eines Projekts. **Grenzen:** Ob eine fast richtige Reihenfolge Teilpunkte bekommt, entscheidet die Bewertungsart (`gradingtype`); sie steht im Plan.

### STACK (`stack`)

**Bewährt für** Rechenwege mit Teilpunkten, algebraische Eingaben und gezielte Rückmeldung auf typische Fehler (`references/stack.md`). Im Übungsmodus ist der Rückmeldebaum ein Nachhilfelehrer, der jeden Versuch kommentiert. **Grenzen:** Aufwendig zu bauen, und nur am Gerät.

### CodeRunner (`coderunner`)

**Bewährt für** Programmieraufgaben (`references/coderunner.md`). Zum Üben sehr wertvoll: Die Testfälle sagen nach jedem Versuch, welcher Fall noch scheitert. **Grenzen:** nur am Gerät, nur wo programmiert wird.
