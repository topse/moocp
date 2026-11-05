# E7 Anmeldedaten

Status: gilt. Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md).

## Entscheidung

Standard: nur im Arbeitsspeicher, solange die App läuft. Mit Haken nach erfolgreicher Anmeldung gespeichert, das Passwort mit DPAPI verschlüsselt (auf dem Mac im Schlüsselbund, [E26](0026-schluesselbund-mac.md)), und beim Start automatisch angemeldet; Haken weg löscht beides. Bei abgelaufener Sitzung genau eine Neuanmeldung, danach Zugangsdaten verwerfen – Moodle sperrt Konten nach Fehlversuchen. War Moodle schon vor dem Senden des Passworts nicht erreichbar (auch durch einen Schutzdienst, [E34](0034-uebergabe-und-schutzdienst.md)), ist das kein Fehlversuch: Die Zugangsdaten bleiben, die nächste Anfrage versucht es wieder. Leere Zugangsdaten gehen gar nicht erst an Moodle, und solange angemeldet ist, gibt es keinen Anmeldeknopf – ein Fehlversuch würde die laufende Sitzung verwerfen.

Lehnt Moodle das gespeicherte Passwort beim Start oder beim Profilwechsel ausdrücklich ab ([E32](0032-ein-fenster-fuer-instanzprofile.md)), wird es verworfen; Haken und Benutzername bleiben, und es wird nicht noch einmal damit angemeldet.
