# E12 Git und GitHub

Status: gilt. Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md).

## Entscheidung

Das Repository ist `topse/moocp` auf GitHub, und dort wird entwickelt. Seit mehrere Personen am Projekt arbeiten, ist GitHub der einzige Ort; ein eigenes Repository daneben gibt es nicht mehr.

main ist geschützt. Änderungen kommen über Zweige und Pull Requests, auch aus Cloud-Sitzungen; niemand pusht mit Force, und main wird nie umgeschrieben. Lokal führt die KI Git-Aktionen nur aus, wenn der Benutzer es ausdrücklich verlangt. Wer mit anderen Git-Regeln arbeitet, legt das für sich in einer nicht eingecheckten `CLAUDE.local.md` fest.

Eine Version entsteht auf main: Version in `pubspec.yaml`, Abschnitt in CHANGELOG.md, Tag `v<Version>`, dann ein Release aus diesem Tag mit dem Installer als Datei. Tag und Dateiname folgen dem Schema `v0.9.5` und `moocp_setup_0.9.5.exe`, das Release ist kein Entwurf und keine Vorabversion; sonst findet die Update-Prüfung der App die Version nicht ([E19](0019-updates.md)).

Bis 0.10.0 wurde in einem eigenen Repository entwickelt, und auf GitHub erschien je Version ein Commit mit dem Stand des Tags. Dieser Verlauf bleibt so: Die Entwicklung davor ist nicht öffentlich und wird es nicht, denn sie kann enthalten, was nach A11 nicht ins Repository gehört.

Zeilenenden LF, nur Batch-Dateien CRLF (`.gitattributes`).

## Verworfen

- Den bisherigen Verlauf nach GitHub zu bringen: Dafür müsste main überschrieben werden, und der Verlauf ist nicht auf A11 geprüft.
- Weiter in einem eigenen Repository zu entwickeln und je Version einen Commit nach GitHub zu legen: Mit mehreren Bearbeitern und Pull Requests auf GitHub musste jede Änderung von dort von Hand hereingeholt werden.
