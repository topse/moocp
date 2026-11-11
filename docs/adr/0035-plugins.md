# E35 Plugins als eigene Programme

Status: gilt. Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md). Fasst „Keine nachgeladene Logik“ aus E25 neu; der Zugang eines Plugins zu Moodle steht in E36.

## Entscheidung

Ein Plugin ist eine zusätzlich installierbare Erweiterung aus einem eigenen Projekt, die eigene Werkzeuge und Skills mitbringt. Es läuft als eigenes Programm neben der App, nie in ihrem Prozess: So erreicht es weder das Sitzungscookie noch das Passwort im Arbeitsspeicher, ein Absturz trifft nur das Plugin, und es kann in jeder Sprache geschrieben sein.

**Ort und Beschreibungsdatei.** Die App lädt nur, was im Ordner `plugins\<name>` ihres Installationsverzeichnisses liegt. Dort steht neben dem Programm eine Beschreibungsdatei mit Name, Kurzname, Version, der Version der Schnittstelle, die das Plugin braucht, seinen Update-Quellen, seinen Zusatzadressen (E36) und seinem Entwicklungsport; daneben liegen seine Skills. Alles, was die App vor dem Start über ein Plugin wissen muss, liest sie aus dieser Datei und dem Ordner, ohne Code des Plugins auszuführen.

**Zustimmung.** Die App startet ein Plugin erst, nachdem die Lehrkraft dieser Version zugestimmt hat: Die Einrichtung (E13) zeigt Name, Version, Herkunft und die Liste der Zusatzadressen mit ihren Gründen, und die Lehrkraft stimmt dem Ganzen zu oder lehnt ab. Abgelehnt, wird das Plugin nicht gestartet; die App läuft ohne es. Jede neue Version braucht eine neue Zustimmung, auch nach einem Update und auch wenn sich die Zusatzadressen nicht geändert haben. Es gibt kein Werkzeug, mit dem die KI ein Plugin installiert, annimmt oder einschaltet, und die App lädt kein Plugin von sich aus herunter.

**Verbindung.** Das Plugin ist ein MCP-Server auf `127.0.0.1`. Die App startet es, gibt ihm Port und einen bei jedem Start neu erzeugten Schlüssel mit und verbindet sich als MCP-Client. Die Werkzeuge des Plugins erscheinen im MCP-Server der App (E6, E31); ein KI-Werkzeug sieht weiter nur diesen einen Server und spricht nie direkt mit einem Plugin. In die Gegenrichtung bietet die App dem Plugin eine eigene lokale Adresse mit demselben Schlüssel: Moodle-Zugang (E36), die eingebauten Werkzeuge der App, Dialoge, Freigaben, Protokoll und Arbeitsordner. Ein eingebautes Werkzeug ruft das Plugin mit Namen und Parametern auf, zu denselben Regeln wie ein KI-Werkzeug (Freigabe, Protokoll, Rückleseprüfung); so baut kein Plugin nach, was die App schon kann. Ein Plugin läuft einmal je App; jeder Aufruf trägt das Instanzprofil, über das er kam, und Zugriffe auf Moodle gehen über genau dieses Profil.

**Werkzeuge.** Jedes Werkzeug eines Plugins beginnt mit dessen Kurznamen; eine Überschneidung mit einem vorhandenen Werkzeug lehnt die App beim Laden ab. Aufrufe laufen durch dieselbe Hülle wie die eingebauten Werkzeuge (Protokoll, Abbruch, Fehlerabbildung). Die App merkt sich die Werkzeugliste jeder angenommenen Version und gibt sie mit `--werkzeugliste` aus, ohne das Plugin zu starten; so kennt die Brücke (E21) sie auch, wenn die App nicht läuft.

**Oberfläche.** Ein Plugin öffnet keine eigenen Fenster. Es beschreibt einen Dialog (Auswahl mit Suchfeld, Eingabe, Ordner- oder Dateiwahl, Hinweis), und die App zeigt ihn an. Freigaben laufen über die eine Stelle der App (E20); die Regeln der Freigabe (E4) gelten ohne Zutun des Plugins.

**Skills.** Die Einrichtung behandelt die Skills eines angenommenen Plugins wie die eigenen: Vergleich am Inhalt, Installieren und Entfernen je KI-Werkzeug (E13). Wird ein Plugin entfernt, entfernt die Einrichtung seine Skills.

**Schnittstellenversion und Updates.** Vor dem Start vergleicht die App die Schnittstellenversion der Beschreibungsdatei mit denen, die sie selbst bietet. Passt sie nicht, sagt ein Dialog, welche Seite zu alt ist, und bietet deren Update an; ohne passendes Update bleibt das Plugin aus. Update-Quellen eines Plugins sind ausschließlich GitHub-Repositories (`Besitzer/Name`) in fester Reihenfolge, mehrere für den Fall eines Umzugs. Es gilt, was für die App selbst gilt (E19): nur nach der einmal erteilten Erlaubnis zum Nachsehen, die spätere Quelle nur, wenn die frühere kein Release hat, nie die höchste Version über mehrere, dieselbe Liste erlaubter Rechner, sichtbarer Installer nach ausdrücklichem Ja. Reihenfolge beim Start: Update der App, Prüfung je Plugin, Zustimmung, Start des Plugins, dann wie bisher Einrichtung, Anmeldung und MCP-Server.

**Installer.** Ein Plugin hat einen eigenen Installer, der es in den Plugin-Ordner legt und abbricht, wenn die App fehlt. Ein Update der App lässt den Ordner stehen; ihre Deinstallation entfernt alle Plugins und deren Skills (E15). Auf dem Mac laufen Plugins wie die App nur aus dem Entwicklungsbau (E24).

**Verantwortung.** Die Zusagen der App (A1 bis A4) gelten für die App und für alles, was durch sie zu Moodle geht. Für seine eigenen Datenwege steht das Plugin ein, und der Dialog zur Zustimmung sagt das. Als letzte Sperre prüft die App Antworten eines Plugins an die KI und seine Zeilen im Protokoll gegen Namen (E36).

**Fehler.** Ein abgestürztes Plugin startet die App einmal neu; danach melden seine Werkzeuge einen Fehler, und die Titelzeile zeigt es. Der Testbetrieb (E20) gibt für Plugins nichts automatisch frei.

**Entwickeln.** Nur in einem Debug-Bau mit eigenem Schalter verbindet sich die App ohne Schlüssel mit einem Plugin, das auf seinem Entwicklungsport schon läuft, statt es zu starten. Im Release-Bau gibt es das nicht: Ein fremdes Programm könnte sich sonst als Plugin ausgeben.

Die eingebauten Werkzeuge bleiben fester Code der App. Sie laufen nicht über die Schnittstelle der Plugins und lassen sich nicht abschalten.

## Verworfen

Eine DLL im Prozess der App (über eine C-Schnittstelle, weil eine fertig übersetzte Flutter-App keinen Dart-Code nachlädt): Sie hätte Zugriff auf Sitzungscookie und Passwort, risse die App bei einem Absturz mit und ließe sich schlecht debuggen. Plugins als Dart-Pakete zur Bauzeit: nicht zusätzlich installierbar, und jede Zusammenstellung wäre ein eigener Installer (E13). Die eingebauten Werkzeuge als „interne Plugins“ über dieselbe Schnittstelle: eine Prozessgrenze mit Serialisieren und Parsen ohne Gegenwert.

Eigene Fenster der Plugins (zwei Oberflächen, und die Regeln der Freigabe hingen am Plugin). Eine Funktion des Plugins, die seine Skills meldet (die App müsste fremden Code ausführen, bevor die Lehrkraft zugestimmt hat). Update-Quellen als beliebige Adressen (die App lüde einen unsignierten Installer von dort, wohin eine Beschreibungsdatei zeigt). Ein schon laufendes Plugin im Release-Bau zu übernehmen. Nur signierte Plugins des Vereins zuzulassen (eine Signaturprüfung gibt es nicht einmal für den Installer der App, E19).
