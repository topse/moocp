# E27 Einzelstart auf dem Mac und unter Linux über einen Unix-Socket

Status: gilt. Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md).

## Entscheidung

Auf dem Mac und unter Linux sperrt ein Unix-Socket `moocp.sock` im Einstellungsordner (`lib/einzelstart.dart`) gegen einen zweiten Start. Der zweite Start verbindet sich mit dem Socket, holt das laufende Fenster nach vorn und beendet sich. Eine übrig gebliebene Socket-Datei aus einem Absturz wird beim Start ersetzt. Unter Windows bleibt es beim Mutex.

Gründe nach dem Kommentar in `lib/einzelstart.dart`: Eine zweite App würde Einstellungen und Arbeitsordner mit der ersten teilen; der Arbeitsordner wird bei Start und Ende geleert ([E5](0005-ergebnisse-als-dateien.md)). Stirbt die App, bleibt die Socket-Datei liegen; der nächste Start merkt das an der abgelehnten Verbindung und legt sie neu an, so dass keine Sperrdatei den Start blockiert.

## Verworfen

Ein `flock(2)`: Es hätte dasselbe geleistet, braucht aber einen Dateideskriptor, den Dart nicht herausgibt, und damit einen FFI-Aufruf von `open(2)` mit variadischem `mode`-Argument, das auf dem Mac anders übergeben wird.
