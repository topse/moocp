# CLAUDE.md – Installer

Gilt für alles unter `installer/` und für `create_installer.bat`. Überblick und Regeln des Projekts: [../CLAUDE.md](../CLAUDE.md).

Die Entscheidung zum Installer (je Benutzer, Deinstallieren räumt alles ab, Umgang mit der Brücke) steht in [ADR 0015](../docs/adr/0015-installer.md).

- **Den Installer auf dem Entwicklungsrechner nicht deinstallieren, ohne zu fragen:** Er teilt die Datenordner mit der Entwicklerversion.
- **`create_installer.bat` nie mit `sed -i` oder einem anderen Werkzeug bearbeiten, das Zeilenenden normalisiert.** Sie braucht CRLF (cmd liest Sprungmarken in Dateien mit LF nicht zuverlässig und setzt mitten in Zeilen auf). Weil `.gitattributes` Batch-Dateien normalisiert, zeigt `git status` den Schaden nicht an – er fällt erst beim Ausführen auf. Nach jeder Änderung daran prüfen: `tr -cd '\r' < create_installer.bat | wc -c` muss so viele CR zählen, wie die Datei Zeilen hat. Sie ist aus einer echten Eingabeaufforderung zu starten (PowerShell), nicht aus Git Bash: Dort erbt sie den Unix-`find` und bricht ab.
- **Der Hinweis zur Nutzung** steht am Anfang der README und auf der ersten Seite des Installers (`HinweisSeite` in `moocp.nsi`); die Regel, ihn an beiden Stellen gleichzuziehen, steht in der [CLAUDE.md des Projekts](../CLAUDE.md) (Arbeitsregeln).

## Linux

Der Installer für Linux liegt nicht in diesem Ordner, sondern in der App (`lib/installer/`, Schalter `--installieren` und `--deinstallieren`); `tool/linux_installer.sh` paketiert ihn zu `installer/moocp_setup_<Version>.run` (Entscheidung: [ADR 0024](../docs/adr/0024-plattformen.md), Abschnitt Linux).

- **Gleich halten mit Windows:** Seiten, Texte und Wartezeit des Hinweises, Ziel ohne Administratorrechte, nur die eigenen Dateien hinlegen und wegnehmen, nie eine laufende App beenden, Deinstallation räumt alles ab (E15). Eine Änderung an einem der beiden Installer prüfen auf den anderen.
- **Tests:** `test/linux_installer_test.dart` (Logik in einem eigenen Heimatordner, Seiten als Widget-Test). Die Deinstallation löscht gespeicherte Passwörter im echten Schlüsselbund: Ein Durchlauf auf dem Entwicklungsrechner gehört deshalb in einen eigenen `HOME` und ohne `DBUS_SESSION_BUS_ADDRESS` (`env -i`).
- **AppImage und .deb:** `tool/linux_appimage.sh` und `tool/linux_deb.sh` packen dieselbe Release-App. Das .deb ist nur systemweit (Rechte 755/644, Besitzer root, Abhängigkeiten in `control`); im AppImage kopiert `--installieren` die App aus dem Einhängeort, deshalb liegt `moocp.png` neben dem Programm. Die Prüfsumme von appimagetool steht im Skript; wer die Version hebt, trägt die neue ein.
- **Nicht** mit `--still` ohne Anzeige aufrufen: Flutters GTK-Läufer öffnet die Anzeige beim Start.
