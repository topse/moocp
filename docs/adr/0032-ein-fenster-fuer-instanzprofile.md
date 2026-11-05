# E32 Ein Fenster für mehrere Moodle-Instanzprofile

Status: gilt. Ergänzt [E27](0027-einzelstart-mac.md) und [E31](0031-mcp-server-je-instanz.md), ersetzt keine von beiden. Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md).

## Entscheidung

Mehrere Moodle-Instanzen werden in einem moocp-Fenster über einen Profilauswähler bedient. Anmeldung, gespeicherte Anmeldedaten, Freigabestufe und MCP-Server gehören jeweils zum ausgewählten Profil.

Sichtbar ist das nur ab zwei Profilen. Mit einem sieht die App aus wie ohne Profile: keine Auswahl, kein Profil- und MCP-Name in Titelzeile, Dialogen und Protokoll. Erst ab dem zweiten erscheinen die Auswahl und die Namen in der Fenstertitelzeile und in Freigabe-, Einrichtungs- und Einstellungsdialogen. Eine weitere Instanz verbindet man über die Einstellungen („Weitere Moodle-Instanz verbinden …“, ganz unten); löscht man zurück auf eines, verschwindet alles wieder. Steht ein Profil auf „keine“ (E20), zeigt die Profilauswahl es rot, auch wenn gerade ein anderes aktiv ist, und das Protokoll nennt es beim Start.

Profile lassen sich in der Oberfläche hinzufügen, bearbeiten und löschen. Das Löschen erfordert eine Bestätigung, entfernt Anmeldung und gespeicherte Anmeldedaten, stoppt den MCP-Server und trägt den Eintrag des Profils aus Claude Code, Codex und LM Studio aus. Bleibt ein Eintrag stehen, nennt die App Werkzeug und Namen, damit die Lehrkraft ihn von Hand entfernt. Die Deinstallation entfernt die Einträge aller gespeicherten Profile. Mindestens ein Profil bleibt erhalten. Ein neues Profil bekommt einen eigenen Port, einen eindeutigen MCP-Namen und einen eigenen Arbeitsordner. Claude Code und Codex werden mit dem technischen Namen und Port des gerade ausgewählten Profils eingerichtet. Skills bleiben gemeinsam, da sie keine Instanzdaten enthalten.

## Gründe

E27 sperrt einen zweiten Prozess aus, weil Einstellungen, Protokoll und Arbeitsordner gemeinsam gehören und beim Beenden geleert werden. Getrennte Fenster je Profil würden diese gemeinsam genutzten Dateien, die Einzelstartsperre und die Bereinigung voneinander entkoppeln müssen. Ein Profilwähler hält den Besitz beim einen Prozess; die schon getrennten Moodle-Zugänge und MCP-Dienste bleiben voneinander isoliert.

## Folgen

- Gespeicherte Anmeldedaten gelten je Profil. Lehnt Moodle das gespeicherte Passwort beim Start oder beim Profilwechsel ab (E7), verwirft die App es, und ein Wechsel meldet nicht noch einmal damit an, bis ein neues eingegeben ist; sonst erzeugte jeder Wechsel einen weiteren Fehlversuch. Der Testzugang des Testbetriebs schreibt und löscht keine gemeinsamen Anmeldedaten.
- Wechseln des Profils ändert die sichtbare Anmeldung und Freigabestufe. Bereits angemeldete Profile und ihre MCP-Server bleiben aktiv.
- Für ein neu angelegtes Profil wird die MCP-Verbindung separat in Claude Code und Codex eingerichtet. Der Server startet nach der Anmeldung dieses Profils.
- Das Protokoll und die Einstellungsdatei bleiben gemeinsam und werden nur von diesem Prozess beschrieben. Der Arbeitsordner bleibt ein Prozessordner; bei mehreren Profilen liegen neue Arbeitsdateien in Kennungs-Unterordnern.
- E27s Unix-Socket und Windows-Mutex bleiben pro moocp-Prozess und werden nicht nach Profil aufgeteilt.

## Verworfen

- **Ein Fenster je Profil:** kollidiert mit E27 und würde die gemeinsamen Einstellungen, das Protokoll und die Bereinigung in mehrere Prozesse teilen.
- **Ein MCP-Server für alle Profile mit Instanzparameter:** widerspricht E31 und macht eine ausgelassene Instanzangabe zur Verwechslungsquelle.
