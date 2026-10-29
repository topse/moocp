# CLAUDE.md – Skill `moodle`

Entwicklungsnotizen; nicht Teil des Pakets. Allgemeines zur Pflege der
Skills: [../CLAUDE.md](../CLAUDE.md).

## Einen weiteren Aktivitätstyp aufnehmen

Anlegbar ist ein Typ erst, wenn sein Formular gemessen ist: im Testkurs
eine Probe `ZZ …` von Hand anlegen, mit `aktivitaet_lesen` lesen, die
Pflichtfelder und Dateibereiche notieren, mit der App eine eigene Probe
anlegen, zurücklesen, ändern, löschen. Danach in `schreibbareModule`
(`lib/moodle/moodle_zugang.dart`) und `typName`, in die Liste „Welche Arten
die App anlegt" im SKILL.md und – mit den wichtigen Einstellungen – in
`references/bearbeiten.md`. Auf der Instanz installiert und bisher nicht
gemessen: Forum, Glossar, H5P, `grouptool`, `collabora`, `serlo`, `margic`,
`questionnaire`.
