# E24 Plattformen: Windows ausgeliefert, macOS und Linux aus dem Entwicklungsbau

Status: gilt. Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md).

## Entscheidung

Ausgeliefert wird moocp für **Windows**: ein Installer je Benutzer (E15), Zugangsdaten mit DPAPI (E7), die Brücke als `moocp-bruecke.exe` (E21), Einstellungen unter `%APPDATA%`. Das ist die Plattform der Schulen, für die die App gebaut ist.

Auf **macOS** läuft die App aus dem Entwicklungsbau (`flutter run -d macos`, siehe README, Teil 4). Eine Veröffentlichung für den Mac gibt es nicht. Dasselbe gilt für **Linux** (Debian 13, amd64; `flutter run -d linux`): Entwicklungsbau, keine Veröffentlichung, kein Installer, keine Selbstaktualisierung, keine Brücke, kein LM Studio. Ob und wie Linux je ausgeliefert wird (Paket, Bundle), ist offen und nicht Teil dieser Entscheidung. Wo die Windows-Lösung an Windows hängt (Ablage der Zugangsdaten, Ort von Einstellungen, Protokoll und Arbeitsordner, die Brücke für LM Studio und das Eintragen in die KI-Werkzeuge, Installation und Update), hat der Mac eine eigene Lösung; sie steht unten.

## Folgen

- Eine Änderung, die Windows-spezifisch ist (Pfade, DPAPI, Installer), nennt das im Kommentar, damit die Umsetzung für den Mac sie findet.
- Das Repository bleibt eines (Flutter, [E25](0025-flutter-desktop.md)); es gibt keinen Zweig für den Mac und keinen für Linux.
- `flutter test` muss auf beiden Plattformen laufen, soweit die Tests nicht ausdrücklich Windows voraussetzen.

## Lösungen für macOS

- **Zugangsdaten:** Das Passwort liegt im Schlüsselbund des Benutzers statt unter DPAPI. Haken und Benutzername stehen wie unter Windows in `shared_preferences`. Der Entwicklerbau hat keine Team-ID und nutzt deshalb nicht die Datenschutz-Gruppe des Schlüsselbunds. Entscheidung und Verworfenes: [E26](0026-schluesselbund-mac.md).
- **Einstellungen, Protokoll und Arbeitsordner:** Einstellungen und `protokoll.log` liegen unter `~/Library/Application Support/moocp` statt unter `%APPDATA%` (`lib/einstellungen_ort.dart`). Der Arbeitsordner liegt wie unter Windows im Temp-Verzeichnis des Systems, auf dem Mac also im benutzerbezogenen `$TMPDIR`. Dass dieser Ort und die Spec in Issue #1 auseinanderlaufen, steht in [Issue #9](https://github.com/topse/moocp/issues/9). Die Einzelstart-Sperre läuft auf dem Mac über einen Unix-Socket im Einstellungsordner: [E27](0027-einzelstart-mac.md).
- **Brücke und KI-Werkzeuge:** Auf dem Mac gibt es keine Brücke. LM Studio mit Bionic wird nicht angeboten, weil dessen Brücke ein Windows-Programm ist. Claude Code und Codex CLI sprechen HTTP-MCP und werden über ihre Kommandozeile bzw. `~/.codex/config.toml` eingetragen. Gesucht werden sie im `PATH`, unter `~/.local/bin`, `/opt/homebrew/bin` und `/usr/local/bin`. Skills liegen in `~/.claude/skills` und `~/.codex/skills`. Ob die Clients auf dem Mac diese Pfade tatsächlich lesen, ist nicht ausgeführt geprüft; das steht in [Issue #9](https://github.com/topse/moocp/issues/9).
- **Installation und Update:** Es gibt keinen Installer und keine Selbstaktualisierung. Die App läuft aus dem Entwicklungsbau (`flutter run -d macos`, README Teil 4). `updateMoeglich` gibt außerhalb von Windows `false` zurück.
- **Bildschirmfotos:** Die Browsersuche (`/Applications`, `~/Applications`; Edge, Chrome, Chromium), die Richtlinie aus den verwalteten Einstellungen (`defaults read`, fehlend heißt erlaubt) und die Prozessbereinigung nach Profil (`ps`, `kill`) stehen hinter der Schnittstelle `lib/plattform/plattform.dart`, mit je einer Umsetzung für Windows und macOS. Der Kern hat keine Plattformprüfung. Ungemessen auf dem Mac: der Wert `0` der Richtlinie, der Start des Browsers und die Bereinigung in der Praxis (siehe [Issue #9](https://github.com/topse/moocp/issues/9)). Die Entscheidung, nur den App-Browser zu nutzen, steht in [E28](0028-bildschirmfoto-app-browser.md).

## Lösungen für Linux

- **Zugangsdaten:** Das Passwort liegt im Secret Service der Sitzung (libsecret über `flutter_secure_storage`, etwa GNOME Keyring oder KeePassXC); Haken und Benutzername stehen in `shared_preferences`. Gespeichert wird nur, wenn der Standard-Schlüsselbund da und entsperrt ist. Das fragt die App vor jedem Zugriff über `gdbus` ab (`lib/plattform/linux_schluesselbund.dart`), denn libsecret öffnet bei einem gesperrten oder fehlenden Bund einen Dialog der Sitzung und blockiert dabei den Hauptfaden: Die ganze App stünde, und sitzt niemand davor (xrdp-Sitzung, Autostart), für immer, mit ihr der Start des MCP-Servers. Eine Frist auf der Dart-Seite hilft nicht, der native Aufruf bleibt blockiert. Ohne benutzbaren Bund scheitert das Speichern mit einer Meldung, die sagt, woran es liegt; die Anmeldung gilt, und das Passwort liegt nie an anderer Stelle (A2, E7, E26). Ohne `gdbus` ist der Zustand unbekannt, und die App fragt den Bund wie ohne diese Prüfung. Die Entsperrung des Bunds beim Anmelden (PAM) ist Sache des Rechners.
- **Einstellungen, Protokoll und Sicherungen:** unter `$XDG_CONFIG_HOME/moocp`, sonst `~/.config/moocp` (`lib/einstellungen_ort.dart`); ein relativer `XDG_CONFIG_HOME` gilt nach der XDG-Spezifikation nicht. Ohne `HOME` ein klarer Fehler statt des Temp-Ordners.
- **Arbeitsordner:** im Temp-Verzeichnis, aber je Benutzer (`moocp_arbeitsordner_<Benutzer>`), mit Rechten 700, und eine Verknüpfung an seiner Stelle wird abgelehnt (`lib/arbeitsordner.dart`). Unter Windows und auf dem Mac ist das Temp-Verzeichnis ohnehin das des Benutzers; unter Linux teilen sich alle `/tmp`, und ein fester Name ohne Benutzer ließe Fremde mitlesen, was aus Moodle kommt (A1).
- **Einzelstart:** wie auf dem Mac der Unix-Socket im Einstellungsordner ([E27](0027-einzelstart-mac.md)). Ein Pfad über 100 Zeichen sprengt `sun_path`; dann startet die App ohne Sperre, statt bei jedem Start vergeblich zu binden.
- **KI-Werkzeuge:** Claude Code und Codex CLI wie auf dem Mac über die Kommandozeile bzw. `config.toml`, gesucht im `PATH` und an festen Orten (`/usr/local/bin`, `/usr/bin`, `~/.local/bin`, `~/.npm-global/bin`, `~/.bun/bin`, Homebrew für Linux), weil eine Sitzung über xrdp oder ein Starter im Menü den `PATH` der Shell nicht erbt. Skills liegen in `~/.claude/skills` und `~/.codex/skills`. Keine Signaturprüfung des Programms unter Linux. LM Studio wird nicht angeboten.
- **Bildschirmfotos:** `LinuxBrowser` in `lib/plattform/linux.dart`: Browsersuche im `PATH` und in den Programmordnern von Chrome und Edge (Chromium, Chrome, Edge), Richtlinie aus den JSON-Dateien unter `/etc/opt/chrome`, `/etc/chromium` und `/etc/opt/edge` (`RemoteDebuggingAllowed: false` verbietet, fehlend heißt erlaubt), Prozessbereinigung wie auf dem Mac über `ps` und `kill` ([E28](0028-bildschirmfoto-app-browser.md)). Ein Chromium aus Snap oder Flatpak ist absichtlich nicht dabei: Seine Sandbox lässt das Profil der App nicht zu.
- **Zwischenablage, Update und Öffnen:** Die Zwischenablage nimmt unter Linux nur Text (E34), `updateMoeglich` ist `false`, Browser und Dateimanager öffnet `xdg-open`.
- **Erweiterungen (E35):** Was ein Plugin unter Linux braucht (Ordner, Start des Programms), ist nicht Teil dieser Entscheidung und kommt mit dem Plugin-System.

## Verworfen

Windows, macOS und Linux gleichzeitig auszuliefern: Es gäbe mehrere Installer, mehrere Wege für Zugangsdaten und Updates und eine Prüfung auf drei Betriebssystemen, bevor die Funktionen selbst stehen. Offen bleibt, ob eine Veröffentlichung für den Mac oder Linux je nötig wird.

Ein Servermodus für Linux (Betrieb ohne Fenster, eigener Secretstore, Verwaltung im Browser): Der Aufwand stünde in keinem Verhältnis zum Nutzen; die App bleibt eine Desktop-App, die in einer grafischen Sitzung läuft, auch einer entfernten (xrdp). Ein eigener Secretstore oder Passwort als Datei: wie in [E26](0026-schluesselbund-mac.md).

Eine Frist auf der Dart-Seite um libsecret statt der Vorprüfung: Der native Aufruf blockiert den Hauptfaden, die Frist erlöst ihn nicht.
