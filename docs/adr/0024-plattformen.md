# E24 Plattformen: Windows ausgeliefert, macOS aus dem Entwicklungsbau

Status: gilt. Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md).

## Entscheidung

Ausgeliefert wird moocp für **Windows**: ein Installer je Benutzer (E15), Zugangsdaten mit DPAPI (E7), die Brücke als `moocp-bruecke.exe` (E21), Einstellungen unter `%APPDATA%`. Das ist die Plattform der Schulen, für die die App gebaut ist.

Auf **macOS** läuft die App aus dem Entwicklungsbau (`flutter run -d macos`, siehe README, Teil 4). Eine Veröffentlichung für den Mac gibt es nicht. Wo die Windows-Lösung an Windows hängt (Ablage der Zugangsdaten, Ort von Einstellungen, Protokoll und Arbeitsordner, die Brücke für LM Studio und das Eintragen in die KI-Werkzeuge, Installation und Update), hat der Mac eine eigene Lösung; sie steht unten.

## Folgen

- Eine Änderung, die Windows-spezifisch ist (Pfade, DPAPI, Installer), nennt das im Kommentar, damit die Umsetzung für den Mac sie findet.
- Das Repository bleibt eines (Flutter, [E25](0025-flutter-desktop.md)); es gibt keinen Zweig für den Mac.
- `flutter test` muss auf beiden Plattformen laufen, soweit die Tests nicht ausdrücklich Windows voraussetzen.

## Lösungen für macOS

- **Zugangsdaten:** Das Passwort liegt im Schlüsselbund des Benutzers statt unter DPAPI. Haken und Benutzername stehen wie unter Windows in `shared_preferences`. Der Entwicklerbau hat keine Team-ID und nutzt deshalb nicht die Datenschutz-Gruppe des Schlüsselbunds. Entscheidung und Verworfenes: [E26](0026-schluesselbund-mac.md).
- **Einstellungen, Protokoll und Arbeitsordner:** Einstellungen und `protokoll.log` liegen unter `~/Library/Application Support/moocp` statt unter `%APPDATA%` (`lib/einstellungen_ort.dart`). Der Arbeitsordner liegt wie unter Windows im Temp-Verzeichnis des Systems, auf dem Mac also im benutzerbezogenen `$TMPDIR`. Dass dieser Ort und die Spec in Issue #1 auseinanderlaufen, steht in [TODO.md](../../TODO.md). Die Einzelstart-Sperre läuft auf dem Mac über einen Unix-Socket im Einstellungsordner: [E27](0027-einzelstart-mac.md).
- **Brücke und KI-Werkzeuge:** Auf dem Mac gibt es keine Brücke. LM Studio mit Bionic wird nicht angeboten, weil dessen Brücke ein Windows-Programm ist. Claude Code und Codex CLI sprechen HTTP-MCP und werden über ihre Kommandozeile bzw. `~/.codex/config.toml` eingetragen. Gesucht werden sie im `PATH`, unter `~/.local/bin`, `/opt/homebrew/bin` und `/usr/local/bin`. Skills liegen in `~/.claude/skills` und `~/.codex/skills`. Ob die Clients auf dem Mac diese Pfade tatsächlich lesen, ist nicht ausgeführt geprüft; das steht in [TODO.md](../../TODO.md).
- **Installation und Update:** Es gibt keinen Installer und keine Selbstaktualisierung. Die App läuft aus dem Entwicklungsbau (`flutter run -d macos`, README Teil 4). `updateMoeglich` gibt außerhalb von Windows `false` zurück.
- **Bildschirmfotos:** Die Browsersuche (`/Applications`, `~/Applications`; Edge, Chrome, Chromium), die Richtlinie aus den verwalteten Einstellungen (`defaults read`, fehlend heißt erlaubt) und die Prozessbereinigung nach Profil (`ps`, `kill`) stehen hinter der Schnittstelle `lib/plattform/plattform.dart`, mit je einer Umsetzung für Windows und macOS. Der Kern hat keine Plattformprüfung. Ungemessen auf dem Mac: der Wert `0` der Richtlinie, der Start des Browsers und die Bereinigung in der Praxis (siehe [TODO.md](../../TODO.md)). Die Entscheidung, nur den App-Browser zu nutzen, steht in [E28](0028-bildschirmfoto-app-browser.md).

## Verworfen

Windows und macOS gleichzeitig auszuliefern: Es gäbe zwei Installer, zwei Wege für Zugangsdaten und Updates und eine Prüfung auf zwei Betriebssystemen, bevor die Funktionen selbst stehen. Offen bleibt, ob eine Veröffentlichung für den Mac je nötig wird.
