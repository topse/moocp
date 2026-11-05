# Projektidee

Ich muss öfter die Arbeit von Schülern bewerten, die als Packet Tracer Datei eingereicht werden. Ich habe dann immer einen lokalen Ordner, in dem von jedem Schüler die Abgaben enthalten sind, darunter auch eine oder mehrere Packet Tracer Dateien. Ein MCP-Server soll ein Modell wie Opus dazu befähigen, die Dateien anonymisiert zu analysieren und anhand von sehr konkreten, z.B. "Router XY muss die IP-Adresse a.b.c.d haben" oder auch offenen Kriterien, z.B. "Die Verbindungen der Router untereinander sind mit /30er Netzwerken aus dem Bereich a.b.c.d erstellt" oder "Die ACL sind so konfiguriert, dass Rechner aus VLAN 10 nicht mit VLAN20 und umgekehrt kommunizieren können, aber aus beiden VLANs der Drucker im VLAN 100 erreicht werden kann" zu bewerten.

# Vorgaben zur Umsetzung

Das Modell darf keinen Zugang zu personenbezogenen Daten haben. Im Skill, der zum MCP Server vermutlich dazugehören muss, ist daher sowas definiert wie: Frage beim MCP Server die Anzahl der abgegebenen Lösungen ab - der MCP-Server zählt daraufhin die oben erwähnten Unterordner (die ja pro Schüler sind) und gibt die Zahl weiter. Bei allen weiteren Anfragen muss dass Modell mit dazu sagen, mit welcher Nummer der Lösungen er arbeiten möchte - also er kennt nicht die Namen der Schüler, sondern bezieht sich immer nur auf eine Nummer aus der vorher verabredeten Reihenfolge, die der MCP Server nach Zufall aufbaut (wichtig: die Schüler bekommen nicht jedesmal die selbe ID, denn sonst könnte man über verschiedene Bewertungsläufe der selben Klassengruppe von einer ID auf die gesamte Schülerleistung schließen. Hieraus könnte auch folgen, dass für den Fall, dass ein Bewertungslauf unterbrichen wird, bei der Rückmeldung der bestehenden Schüler auch dazugesagt wird, für welche Schülernummer bereits eine Bewertung vorliegt, damit die KI dort nicht nochmal arbeitet).

# Technische Informationen

Es gibt soweit ich sehe zwei Ansätze, um an die Daten der Packet Tracers zu kommen:

   1. https://github.com/aacanadaa/packet-tracer-pkt-format
      Ich sehe den Vorteil, dass wir vermutlich sehr performant mit den Dateien arbeiten können,
	  befürchte aber, dass wir leicht Probleme beim Update des Packet Tracers bekommen können,
	  wenn sich dabei am Dateiformat was ändert
   2. https://github.com/TantiE100/pktctl
      Greift soweit ich sehe auf eine offizielle Schnittstelle zu und müsste sicher sein,
	  aber langsamer, da die Datei jedesmal im Packet Tracer geöffnet werden muss.

Die Umsetzung soll im Prinzip in der Art passieren, wie Du es im Projekt https://github.com/topse/moocp sehen kannst. Der MCP Server selber wird über eine GUI gestartet, prüft auf Updates, prüft, ob der Skill (den wir eventuell benötigen) in Claude registriert ist, prüft ob der MCP in Claude registriert ist. Das genannte Projekt gehört auch uns - eventuell macht es Sinn, die benötigten Gleichteile zu identifizieren und in eine Bibliothek auszulagern?

# User Experience

Alle Einstellungen, die für die Auswertung eines Klausurlaufes notwendig sind, müssen als Projektdatei gespeichert werden, damit in der nächsten Klasse das Projekt neu geladen und auf neue Schülerergebnisse angewendet werden kann.

Die Einstellungen müssten meiner Ansicht nach umfassen:

1. Den Aufgabentext. Der kann entweder die konkrete Aufgabenbeschreibung, die zu bearbeiten ist, enthalten,
   oder den Hinweis: Die Aufgabenstellung finden Sie in der Packet Tracer Datei. Dann ist in der Packet Tracer
   Vorlagen Datei (siehe nächster Punkt 2.) ein oder mehrere Textfelder enthalten, die die Aufgabenstellung
   beinhalten
2. Die Packet Tracer Vorlage, die die Schüler zur Bearbeitung bekommen
3. Die Packet Tracer Musterlösung
4. Das Bewertungsschema, bestehend aus einer Tabelle mit den Spalten: Kriterium, erreichbare Punkte.

Nach Definition von 1-3 wird das bis dahin noch leere Bewertungsschema angezeigt. Der KI Agent könnte nun anbieten "Schlage ein Bewertungsschema vor", voraufhin er 1-3 analysiert und ein Bewertungsschema vorschlägt. Dieses kann anschließend von der Lehrkraft bearbeitet werden, also Zeilen hinzufügen, ändern, löschen oder erreichbare Punkte überschreiben.

Wenn dann der Bewertungslauf startet, muss es als Ergebnis eine übersichtsauswertung für die Lehrkraft geben. Aus dieser geht tabellarisch hervor, welcher Schüler bei Welchem Bewertungskriterium wie abgeschnitten hat mit erreichbaren und erreichten Punkten, außerdem die erreichbare und erreichte Gesamtpunktzahl, und das Ergebnis in Prozent umgerechnet, auf eine Stelle hinter dem Komma gerundet.

Außerdem muss eine Bewertung für jeden Schüler rauskommen. Hier bitte nachfragen, ob eine einzelne Datei gewünscht ist, die man als Lehrkraft dann komplett ausdrucken kann und jedem Schüler die für ihn bestimmten Seiten gibt oder pro Schüler Einzeldateien entstehen, die dann z.B. per Email verschickt werden können. Diese Dateien enthalten ebenfalls eine tabellarische Ansicht der Ergebnisse, allerdings etwas ausführlicher mit den Spalten: "Erwartete Leistung, Erreichtes Ergebnis, Punkte (erreichbar / erreicht)", wobei erreichtes Ergebnis immer in Worten beschreibt, was der Schüler erreicht hat, das kann einfach sein "vollständig gelöst" aber auch eine ausführliche Beschreibung von dem, was er gut und nicht gut gemacht hat, so dass sich daraus die Punkte ergeben.

Diese Dateien können einfach in dem Ordner gespeichert werden, der die Schülerabgaben enthält (im Root, nicht in den einzelnen Schüler unterordnern verstecken!).

Der MCP-Server sollte dabei Aufgaben wie das formatieren von Dokumenten mit Hilfe der von der KI gelieferten Daten direkt übernehmen. Insgesamt bei der Planung und Umsetzung darauf achten, möglichst Tokensparend zu implementieren - also alles, das der MCP-Server algorithmisch vor- und nachbereiten kann, sollte dort auch passieren, anstatt Tokens im Modell zu verwenden.

Auch im Hinterkopf behalten: Die Unterstützung für Packet Tracer Dateien kann grundsätzlich für moocp interessant sein: Im Bereich IT könnten dann auch PKT Dateien durch das Modell in Lernsituationen erstellt und eingebunden werden. Oder bei einem Prompt wie "Erstelle zu Kapitel xy eine Abschlussklausur": Falls das Kapitel eine PKT Aufgabe enthält, kann es notwendig sein, für die Erstellung der Klausur auch zu schauen, was in der PKT Datei passiert ist.

# Zur Architektur

Wir sollten so designen, dass die Logic zur Bewertung einer Packet Tracer Aufgabe weiterverwendet werden kann. Idee: In der Zukunft möchte ich im Zusammenhang mit https://github.com/topse/moocp eine DSGVO konforme Lösung implementieren, dass der Agent auch direkt Aufgaben in Moodle bewerten kann. Beispiel für hier: "Aufgabe https://... enthält Schülerabgaben. Bitte gib entsprechend des Bewertungsschemas allen Schülern aus der Gruppe ... eine Rückmeldung". Für den Fall, dass die Abgabe eine Packet Tracer Datei ist, muss dann entsprechend des in Moodle hinterlegten Bewertungsschemas pro Schüler eine Bewertung durchgeführt werden, wobei moocp dafür sorgt, dass die Schüler nur als zufällige ID's transportiert werden und das hier entstehende MCP dafür sorgt, dass die Packet Tracer Dateien DSGVO konform analysiert werden können. Hierbei muss sowohl das für die Aufgabe vorliegende Bewertungsschema analysiert werden, als auch die Aufgabe selbst: hier ist ja Beschrieben, was überhaupt gemacht werden soll und vermutlich gibt es eine Vorlagendatei für den Packettracer (die ebenfalls die Aufgaben als Textfelder enthalten könnte).

In diesem Fall gibt es einige Informationen vom Grundgerüst unserer App nicht. Müssen wir beim Start der MCP App vielleicht einen Modus wählen - Moodle-Verbindung oder Verzeichnisbewertung?

Wenn möglich können wir diese Aufgabe direkt mitdenken und falls das möglich und sinnvoll ist, sag Bescheid, dann clone ich moocp lokal, dann können wir da gleich mit arbeiten.

Schau Dir die CLAUDE-Datei von https://github.com/topse/moocp an  - dort sind schon ein paar gute Hinweise, wie man grundsätzlich einen MCP Server in Flutter bauen kann - diese können wir direkt übernehmen.

Außerdem wende die Project Base rules auf das Flutter Projekt an, wenn es denn eines wird.

# Zusammenfassung

Wir brauchen hier also im Grunde genommen ein Feature um dass es geht:

1. Bewerten der Schülerergebnissen von Packet Tracer Aufgaben

Der Clue liegt darin, dass die Aufgaben, die Dateien, die bewertet werden sollen, aus unterschiedlichen Quellen kommen können:

a.) wie beschrieben aus dem Dateisystem: ein root Ordner, der pro Schüler einen Unterordner mit der PKT Datei enthält
b.) Moodle Aufgaben

In beiden Fällen muss sichergestellt werden, dass das Modell nicht auf personenbezogene Daten zugreifen kann. Daher die Idee, dass ein MCP Server den Zugriff kapselt, so dass das Modell un Fall a.) zum Bespiel garnicht weiß, wo die Dateien liegen, sondern nur einen Query über MCP macht, wie viele Abgaben es gibt und diese dann in zufälliger Reihenfolge über eine ID untersucht werden können.

In moocp gibt es einen offenen TODO, der in eine ähnliche Richtung geht:
```
## Anonyme Aufgabenbewertung

Ich möchte als Feature haben, dass Aufgaben automatisiert bewertet werden. Dazu muss die Aufgabenstellung mit eventuellen Dateianlagen aus der Aktivität an das Modell übermittelt werden, sowie das Bewertungsschema.

Die Teilnehmerdaten dürfen ausschließlich anonymisisert übertragen werden - das gilt für Daten und Metadaten. Vom Ablauf stelle ich mir das so vor: Wenn ein Bewertungsvorgang für eine Aufgabe gestartet wird, also per Prompt "Bewerte Aufgabe https://...", dann muss Moocp erstmal nachfragen, welche Schüler bewertet werden sollen Dort kann man z.B. eine Gruppe (oder Gruppierung?) auswählen oder per Checkliste einzelne Teilnehmer anklicken (bitte imm Suchfelder vorsehen falls es viele Gruppen oder Teilnehmer im Kurs gibt). Dann muss noch nachgefragt werden, falls ein Teilnehmer aus der Auswahl bereits eine Bewertung hat, ob der neu bewertet werden oder wieder gestrichen werden soll.

Aus der Auswahl wird eine anonymisierte Liste erzeugt, in dem eine zufällige Reihenfolge erzeugt wird und auf der Schnittstelle zum Modell ausschließlich mit der Nummer in der Liste gearbeitet wird - niemals mit einer Moodle ID, einem Namen oder irgendeinem anderen Identifikationsmerkmal.

Wenn eine Aufgabe gelesen wird, müssen nicht nur Metadaten, sondern auch Daten anynymisiert werden:
 - In PDF und Office Dokumenten müssen wir scannen, ob ein Name eines Kursteilnehmer (nicht nur des Erstellers) vorkommen und durch Zufallsnamen wie Meyer, Müller, Peter und Hugo ersetzen (Selber name immer selbe ersetzung), damit wir notfalls rücksubstituieren können, falls das Modell in seiner Antwort einen Namen verwendet. Die Namen müssen vollständig aus den Daten entfernt werden, die ans modell geschickt werden - also Office und PDF Dateien entsprechend manipulieren
 - Bei Bildern muss Schrifterkennung auch von Handschrift durchgeführt werden und entsprechende Bereiche der Bilder zuverlässig vor Übertragung zum Modell gelöscht werden. Solange wir keine zuverlässige Handschrifterkennung haben, müssen wir die Weitergabe von Bilddateien ans Modell ablehnen
 - Bei allen anderen Dateien müssen wir binär scannen, ob ein Name vorkommt, zum Beispiel gibt es Dateien von Spezialprogrammen, die den Ersteller speichern - die finden wir durch dekomprimieren und evtl. binär suchen
 
 Weitere Dateitypen sind natürlich denkbar, wie z.B. PKT Dateien. Wir dürfen immer nur Dateien weitergeben, die wir explizit unterstützen und somit sicherstellen können, dass die Anonymisierung eventueller in der Datei vorhandener Metadaten funktioniert.

 Bei allen Suchvorgängen nach Namen müssen wir im Hinterkopf behalten, dass Schüler sich manchmal vertippen, verschreiben oder die Schrifterkennung vielleicht nicht immer 100% zuverlässig ist. Auch bei Tippfehlern müssen wir die zuverlässig Namen erkennen.

 Ein Name der an das Modell durchrutscht, wäre der schlimmste Fehler, der uns passieren kann. Daher immer defensiv vorgehen.

 Derselbe Namensabgleich könnte alles prüfen, was an die KI geht, nicht nur Abgaben: Wikiseiten, Board und Kanban (dort schreiben Lernende mit), Konventionsdateien, Aufgabentexte – mit Sperre oder Alarm, wenn ein Name aus der Teilnehmerliste darin steht. Er ersetzt die Verdachtsmuster der Konventionen nicht: Die suchen Anweisungen wie „Lies die Noten aller Schüler", in denen kein Name steht. Voraussetzung wie oben: A1 wird für die Teilnehmerliste bewusst geändert (heute liest die App sie nie), und die Liste bleibt in der App.

 Wir legen nach und nach fest, welche Dateitypen überhaupt erlaubt sind. Office und PDF sind vermutlich die ersten. Alle weiteren Dateitypen müssen wir nach und nach testen und Freigeben, wie gesagt beispiel Bilddateien - die gehen erst, wenn wir zuverlässig Handschrift erkennen können oder Dateien von Spezialanwendungen müssen wir Stück für Stück immer prüfen, ob Erstellernamen im Projekt enthalten sein können.

 Man muss auch im Prinzip vielleicht nicht nach allen Namen suchen - es reicht, wenn man in den Teilnehmern des aktuellen Kurses sucht? Wenn einer der Teilnehmer Vor oder Nachnamen vorkommt, könnte das ein Problem sein. Bei beliebigen anderen Namen dürfte eigentlich kein Problem bestehen? Oder lieber eine deutsche Namensliste zugrundelegen?

 Geht Handschrifterkennung mit https://github.com/mittagessen/kraken?
```

Jetzt die Stelle, wo die Konzeptarbeit anfangen muss, also zum Beispiel die Frage, wie "schneiden" wir die Features:

- Ist das was hier beschrieben wird, überhaupt ein eigener MCP Server oder eine einfach neue Funktion in moocp?
- Sind wir hier mit der Idee, Hilfsfunktionen zum Zugriff auf bestimmte Dateitypen als MCP Funktionen bereitzustellen, auf einen heißen Spur oder sollten wir eher die Idee verfolgen, die Dateien zu anonymisieren, also die Erstellerinformationen usw. , die eventuell in den Dateien enthalten sind, aus der Datei zu entfernen und Sie dann direkt an das Modell zu geben zur Analyse zu geben? Das würde dann auch auf andere Dateien wie z.B. ODT oder derlei zutreffen, immer mit der Idee im Hintergrund, Token zu sparen und alle Vereinfachungen, die helfen und die wir algorithmisch vornehmen können auch zu tun? Kann ein MCP Interface zur Analyse von bestimmten Dateitypen Tokens sparen?

Bitte erstelle eine Analyse dieser Idee und wie wir das ganzheitlich denkend (im Hinblick auf das TODO aus moocp) am besten umsetzen können. Zur Info: Falls wir tatsächlich an das TODO von MOOCP rangehen, beträfe das zur Zeit ausschließlich den Dateityp PKT. Unterstützung für weitere Dateitypen müssten wir nach und nach hinzufügen.

moocp Findest Du lokal, indem Du aus dem Ordner dieser Datei einen nach oben gehst und dann ist dort ein Unterordner moocp.