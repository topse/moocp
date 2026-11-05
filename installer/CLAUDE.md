# CLAUDE.md – Installer

Gilt für alles unter `installer/` und für `create_installer.bat`. Überblick und Regeln des Projekts: [../CLAUDE.md](../CLAUDE.md).

Die Entscheidung zum Installer (je Benutzer, Deinstallieren räumt alles ab, Umgang mit der Brücke) steht in [ADR 0015](../docs/adr/0015-installer.md).

- **Den Installer auf dem Entwicklungsrechner nicht deinstallieren, ohne zu fragen:** Er teilt die Datenordner mit der Entwicklerversion.
- **`create_installer.bat` nie mit `sed -i` oder einem anderen Werkzeug bearbeiten, das Zeilenenden normalisiert.** Sie braucht CRLF (cmd liest Sprungmarken in Dateien mit LF nicht zuverlässig und setzt mitten in Zeilen auf). Weil `.gitattributes` Batch-Dateien normalisiert, zeigt `git status` den Schaden nicht an – er fällt erst beim Ausführen auf. Nach jeder Änderung daran prüfen: `tr -cd '\r' < create_installer.bat | wc -c` muss so viele CR zählen, wie die Datei Zeilen hat. Sie ist aus einer echten Eingabeaufforderung zu starten (PowerShell), nicht aus Git Bash: Dort erbt sie den Unix-`find` und bricht ab.
- **Der Hinweis zur Nutzung** steht am Anfang der README und auf der ersten Seite des Installers (`HinweisSeite` in `moocp.nsi`); die Regel, ihn an beiden Stellen gleichzuziehen, steht in der [CLAUDE.md des Projekts](../CLAUDE.md) (Arbeitsregeln).
