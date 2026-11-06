# E19 Updates nur nach ausdrücklichem Ja, und nur von GitHub

Status: gilt. Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md).

## Entscheidung

Außer Moodle fragt die App genau eine Stelle: das Release von moocp bei GitHub. Beim ersten Start fragt sie in einem eigenen Dialog, ob sie einmal täglich nachsehen darf, und nennt dabei, was GitHub dadurch erfährt (IP-Adresse und Zeitpunkt); ohne Ja geht keine Anfrage hinaus, und die Antwort lässt sich in den Einstellungen ändern. Geprüft wird vor dem Einrichten: Ein Update bringt neue Skills mit, und der MCP-Server startet ohnehin zuletzt, also hängt noch keine Claude-Sitzung daran. Die Grenze liegt im Code wie überall: eigene Positivliste (`lib/update/updateliste.dart`) für jede Adresse und jedes Umleitungsziel, eigene Verbindung ohne Sitzungscookie, jede Anfrage mit Status im Protokoll; `test/update_test.dart` hält `update.dart` darauf fest. Geprüft wird nur, wer sich selbst ersetzen kann (die exe liegt im Installationsverzeichnis), und `--kein-update` schaltet es ganz ab. Der Installer läuft sichtbar; still wäre bequemer, aber wer ein Programm austauscht, soll sehen, was läuft. Kein MCP-Werkzeug dafür: Updates sind Sache der Lehrkraft, nicht Claudes.

Hinterlegt sind zwei Herkünfte in fester Reihenfolge: zuerst `Moodle-in-Niedersachsene-V/moocp`, dann `topse/moocp`. Die zweite wird nur gefragt, wenn es unter der ersten kein Release gibt. So finden installierte Versionen das Update, wo das Repository auch gerade liegt. Die Weiterleitung von GitHub reicht dafür nicht: Die API leitet ein umgezogenes Repository auf eine Adresse mit Nummer um (`/repositories/<Nummer>/…`), und die steht bewusst nicht auf der Positivliste, sodass eine Version, die nur die alte Herkunft kennt, nach dem Umzug keine Updates mehr findet.

Die zweite Herkunft ist eine Übergangslösung und verschwindet in einer späteren Version. Solange sie in einer installierten Version steht, darf `topse/moocp` nicht in fremde Hände geraten: Das Konto bleibt bestehen, und unter dem alten Namen entsteht kein neues Repository (das löschte außerdem die Weiterleitungen von GitHub).

Gibt GitHub für jede Herkunft Bescheid, dass es dort nichts mehr gibt (404, 410, 451 oder eine Umleitung innerhalb von `api.github.com`), warnt ein Dialog, dass automatische Updates anscheinend nicht mehr möglich sind; das geschieht bei jeder Prüfung, also höchstens einmal am Tag, und bei der Suche von Hand. Vorübergehendes bleibt still im Protokoll: kein Netz, Zeitüberschreitung, 403 und 429, Serverfehler und Umleitungen auf andere Rechner, wie sie ein Schulproxy auslöst. Sonst bekäme jeder im Schulnetz täglich eine falsche Warnung und lernte, sie wegzuklicken.

## Verworfen

Beide Herkünfte zu fragen und die höchste Version zu nehmen: Der Installer ist nicht signiert, und wer eine der beiden Adressen übernähme, könnte mit einer hohen Versionsnummer ein Update unterschieben. Der Abfrage über die Repository-Nummer zu folgen, die einen Umzug überdauert: Dafür müsste der Download von beliebigen Besitzern erlaubt sein, und die Liste verlöre ihren Sinn.

Eine Datei `autoupdate` im Installationsverzeichnis (die Einstellungen liegen je Benutzer unter `%APPDATA%`, werden beim Deinstallieren mitgelöscht und sind beim Start schon geladen; einen Administrator, der sie schriebe, gibt es bei einer Installation je Benutzer nicht); die Frage im Installer (wer selbst baut, läuft nie durch ihn, und die Antwort müsste trotzdem in die Einstellungen).
