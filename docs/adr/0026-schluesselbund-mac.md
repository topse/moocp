# E26 Zugangsdaten auf dem Mac und unter Linux im Schlüsselbund des Benutzers

Status: gilt. Ergänzt [E7](0007-anmeldedaten.md) für macOS und Linux; unter Windows gilt E7 unverändert. Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md).

## Entscheidung

Auf dem Mac liegt das Passwort im Schlüsselbund des Benutzers, über `flutter_secure_storage` mit `usesDataProtectionKeychain: false` (`lib/anmeldedaten.dart`). Der Haken und der Benutzername liegen wie unter Windows in `shared_preferences`. Es gelten dieselben Grenzen wie in E7: gespeichert wird nur nach einer erfolgreichen Anmeldung, und das Passwort geht nie über MCP hinaus und nie ins Protokoll (A2).

Gründe nach dem Kommentar in `lib/anmeldedaten.dart`: Die Datenschutz-Schlüsselbundgruppe verlangt eine Team-ID zum Signieren, und ein Entwicklerbau ohne Konto hat keine. Die Entscheidung gilt für den Entwicklerbau; ob sie für eine Veröffentlichung hält, ist nicht geprüft.

Unter Linux liegt es im Secret Service der Sitzung (libsecret, etwa GNOME Keyring oder KeePassXC), ebenfalls über `flutter_secure_storage`. Gespeichert und gelesen wird nur, wenn der Standard-Schlüsselbund da und entsperrt ist; das fragt die App vorher über `gdbus` ab, weil libsecret sonst bei einem gesperrten Bund einen Dialog öffnet und die ganze App anhält. Ohne benutzbaren Bund wird das Passwort nicht gespeichert, die Anmeldung gilt, und das Passwort liegt nie an anderer Stelle (Einzelheiten in [E24](0024-plattformen.md)).

## Folgen

- Ein Release-Bau für den Mac braucht eine Prüfung, ob der alte Schlüsselbund dort ebenso gilt. Das steht in [Issue #9](https://github.com/topse/moocp/issues/9).

## Verworfen

Das Passwort als Datei im Einstellungsordner: Das wäre Klartext auf dem Datenträger, und die DPAPI-Schutzwirkung gäbe es dort nicht. Die Datenschutz-Schlüsselbundgruppe: Sie braucht eine Team-ID, die der Entwicklerbau nicht hat. Unter Linux ein eigener Secretstore oder eine Datei mit dem Passwort, falls kein Schlüsselbund läuft: Das wäre derselbe Klartext auf dem Datenträger.
