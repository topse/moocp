# E31 Ein MCP-Server je Moodle-Instanz

Status: gilt. Ergänzt [E1](0001-werkzeugschicht-und-skills.md) und [E13](0013-ki-werkzeuge-einrichten.md) um die Trennung der Instanzen. Die Oberfläche bleibt ein gemeinsames Fenster ([E32](0032-ein-fenster-fuer-instanzprofile.md)). Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md).

## Entscheidung

Jede angebundene Moodle-Instanz ist ein Profil und bekommt einen eigenen MCP-Server mit eigenem Port, eigenem Namen und eigenem Zugangsschlüssel. Ein Server mit der Instanz als Werkzeugparameter wird nicht gebaut.

Namen: Das Standardprofil heißt „Moodle“ (technischer Name `moodle`) und steht für die Instanz, die die Lehrkraft nutzt. Weitere Profile tragen eigene Namen, etwa „Moodle Test“ (`moodle-test`). Der Anzeigename darf Leerzeichen enthalten, der technische Name nicht: Ein Werkzeug heißt `mcp__<name>__…`, und Leerzeichen sind darin nicht zulässig. Deshalb gibt es beide Namen. Der technische Name wird aus dem Anzeigenamen abgeleitet und dann gespeichert, damit ein Umbenennen die Einrichtung in den KI-Werkzeugen nicht still verstellt; er steht in der Konfiguration (Claude, Codex), der Anzeigename in der App. Beide stehen nicht im Code fest, sondern im Profil.

## Folgen

- Welcher Server zu welcher Instanz gehört, richtet jeder für sich ein; wer zwei Instanzen anbindet, gibt dem Profil der Testinstanz einen unterscheidbaren Namen. Zum Testen wird nie über einen Server geschrieben, dessen Instanz nicht der des genannten Testkurses entspricht (A10); sonst schriebe ein Test-Aufruf versehentlich in die falsche Instanz.
- Die Freigabestufe (E20) und die Positivliste (E3) gelten je Instanz, nicht global.
- Jeder Server hat seinen eigenen Zugangsschlüssel (E6): Wer den Schlüssel einer Instanz kennt, kommt nicht an die Werkzeuge einer anderen, die auf eine andere Moodle-Instanz schreiben. Ein neues Profil bekommt ihn beim Anlegen, ein vorhandenes ohne beim Laden der Einstellungen; er steht in der Einstellungsdatei beim Profil und in dessen Eintrag in Claude Code und Codex. Ein Eintrag mit dem Schlüssel eines anderen Profils gilt als veraltet, und „KI-Werkzeuge einrichten“ erneuert ihn. Das Standardprofil behält den globalen Schlüssel der Einstellungen, damit die vorhandenen Einträge und die Brücke für LM Studio (E21), die nur den einen kennt, weiter gelten. Ein Profil ohne Schlüssel lässt der Server nicht herein.
- Die Skills müssen nicht wissen, welche Domain hinter einem Server liegt.
- Die Domain einer Instanz steht nur im Instanzprofil der App, nicht im Repository (A11).

## Verworfen

- **Ein Server, Instanz als Parameter aller Werkzeuge:** Alle Werkzeugaufrufe und Skills müssten sich ändern, und ein fehlender Parameter wäre eine Verwechslungsquelle.
- **Namen aus der Domain:** Lang, ändert sich bei einem Umzug, und sagt einer Lehrkraft nicht, welche Instanz gemeint ist.
- **Namen mit Leerzeichen als technischer Name:** Nicht als Werkzeugpräfix zulässig.
