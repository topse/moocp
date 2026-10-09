# CLAUDE.md – Skill `moodle-fragen`

Entwicklungsnotizen; nicht Teil des Pakets. Allgemeines zur Pflege der
Skills: [../CLAUDE.md](../CLAUDE.md). Entscheidungen zu Fragen und Tests: E9
der [Projekt-CLAUDE.md](../../CLAUDE.md).

## Einen weiteren Fragetyp aufnehmen

Gemessen nach dem Verfahren unten, dann in `zusatzAnlegbar` (`lib/moodle/fragen_xml.dart`), in die Tabelle im SKILL.md, mit seinem XML in `references/fragetypen.md` – und mit seinem Abschnitt in `references/einsatz.md`: wofür er sich anbietet, was er prüft, wie leicht er sich erraten lässt, ob er auf Papier geht ([../CLAUDE.md](../CLAUDE.md), „Einsatz").

## Die gemessenen XML-Muster

Die XML-Muster je Fragetyp in `references/fragetypen.md`, `stack.md` und
`coderunner.md` sind nicht ausgedacht, sondern gemessen: von Hand angelegt,
exportiert, eine eigene Frage danach geschrieben, importiert, erneut
exportiert, verglichen, **in der Vorschau angesehen**. Die Beispieldateien
dieser Messungen liegen in `test/daten/fragen/`, und
`test/fragen_beispiele_test.dart` hält die Prüfung der App vor dem Import
dagegen. Ändert sich ein Muster im Skill, ändert sich die Beispieldatei mit.

Die Beschreibungen für `stack_xml` in `stack.md` und `jsxgraph.md` prüft derselbe Test direkt aus der Referenz: Jeder `json`-Block dort muss bauen und durch die Prüfung vor dem Import gehen. Ein geändertes Beispiel wird außerdem einmal im Testkurs importiert – die Testfälle laufen dabei mit und sind die eigentliche Abnahme.

**Die Vorschau ist die einzige echte Abnahme.** Eine `calculatedmulti`-Frage
importierte fehlerfrei, las sich korrekt zurück und bewertete richtig – und
zeigte in der Auswahl `230*16,0` statt `3680,00`. Für einen neuen Fragetyp
heißt das: importieren, Vorschau öffnen (`/question/bank/previewquestion/
preview.php?id=<qid>&cmid=<cmid>`), bei Rechenfragen „Richtige Lösung
eintragen" drücken und ansehen, was Moodle selbst für richtig hält. Die App
hat dafür kein Werkzeug; die Vorschau öffnet der Nutzer oder, beim Messen,
Chrome.

**Auswahlfelder im Formular sagen nichts über das XML.** Hat ein Feld Zahlen
als `value`, können im XML trotzdem Namen stehen (`ordering`:
`<selecttype>ALL</selecttype>`, nicht `0`) – was im XML steht, sagt nur der
Export einer Frage, die die Einstellung wirklich hat. Die App prüft das bei
`ordering` vor dem Import.
