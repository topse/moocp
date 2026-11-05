# E9 Fragen und Tests

Status: gilt. Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md).

## Entscheidung

Die Entscheidung gilt für `moodle-fragen` und beim Portieren in die App. Fragen werden per Moodle-XML-Import angelegt und über das Bearbeitungsformular geändert (das erzeugt eine neue Version mit neuer `questionid`); die Sachnummer (`idnumber`) ist die stabile Kennung, Mehrdeutigkeit wird gemeldet, nicht aufgelöst.

Anlegbar sind die Kerntypen und die Zusatztypen, deren XML durchgemessen ist (von Hand anlegen, exportieren, eigene Frage schreiben, importieren, vergleichen, Vorschau, aufräumen): derzeit `ddmatch`, `mtf`, `gapfill`, STACK (nur mit gelaufenen Fragetests) und CodeRunner (gilt erst als angelegt, wenn einmal über das Formular gespeichert – nur dort läuft die Musterlösung durch die Sandbox). Prototypen werden nie angelegt.

Fragen löschen geht nur mit allen Versionen, nach Freigabe und mit Namensprüfung (`fragen_loeschen`); steckt eine Frage in einem Test, verbirgt Moodle sie nur, und das Werkzeug meldet es. Leere Kategorien löscht die App nicht.
