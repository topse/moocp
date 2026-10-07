# Features
- Kompatiblität zu MacOS und Linux herstellen. Müssen einzelne Features wie auto update umgestaltet oder gar entfernt werden? Die Pfade für die Konfiguration und ablage der Skills - sind die gleich?
- automatisches bauen und erstellen eines releases in github, mit Windows, linux und MacOS Executables (windows sogar installer) und changelog message als Release message
- Wissenspeicher STACK untersuchen und integrieren
- Codex CLI absichern und testen, in einer eigenen Sitzung: Eingerichtet wird es bisher nur nach Dokumentation, gelaufen ist es mit einer echten Version nie. Zu klären: Nach „Installieren" steht der Block `[mcp_servers.moodle]` in `~/.codex/config.toml` – sieht Codex die Werkzeuge, lädt es die Skills aus `~/.codex/skills` (sonst nur aus `~/.agents/skills`, dann den Ort in `CodexCli` ändern), und ab welcher Version geht HTTP ohne den alten Schalter `experimental_use_rmcp_client` (README nennt 0.77)? Öffnet Codex die Bilder von `bildschirmfoto` (PNG im Arbeitsordner) und sieht sie? Fragt Codex vor einem Werkzeugaufruf (README, „Worauf es ankommt")? Bricht Codex einen Werkzeugaufruf nach seinem Zeitlimit ab (`tool_timeout_sec`, Vorgabe wohl 60 Sekunden), auch während eine Freigabe offen ist? Dann schließt sich der Dialog nach einer Minute (E4); wie bei Bionic 35 Minuten eintragen (`tool_timeout_sec = 2100`, `bionicZeitlimit`) und in `CodexCli` mitprüfen.
- "Sitzung verwerfen (Test)" Button entfernen
- Aktivität "Befragung" (questionnaire) unterstützen
- Regel: Prüfen dass "Aktivität unterstützen" oder "Fragetyp unterstützen" nicht nur technisch bedeutet, sondern dass es auch Hinweise gibt, wie man die jeweils pädagogisch und didaktisch sinnvoll einsetzen kann
- Fragensammlung verbergen, verschieben und duplizieren: geht nicht, weil `qbank` nicht in der Kursstruktur steht. Löschen hat einen eigenen Weg über die Sammlungsliste; die drei bräuchten denselben.
- Verdachtsmuster schärfen: „note" und „bewertung" greifen ohne Wortgrenze, also auch in „Bewertungsraster", „Bewertungsfelder", „Fußnote". Eine echte Konventionsdatei löst `VERDACHT: zielt auf Personendaten` damit fast immer aus (gemessen 05.10.2026 an Kurs 74) – und eine Warnung, die immer kommt, wird nicht gelesen. Das ist dasselbe Argument, mit dem die Muster nicht über die Zusatzdateien laufen. Zu prüfen: Wortgrenzen und Kombinationen, die wirklich auf Personendaten zielen, statt einzelner Wortstämme.
- Konventionen beim Arbeiten an Fragen: Sie reiten an `kurs_uebersicht` und `abschnitt_lesen` mit, aber der Skill `moodle-fragen` beginnt oft mit `fragensammlungen` und `fragen_lesen` — dort hängt sie bisher nur der Satz im Skilltext an. Prüfen, ob eines dieser Werkzeuge sie mitliefern sollte.
- Wartende Freigabe sichtbar machen: Zähler im Dialog („1 weitere Anfrage wartet") und eine Protokollzeile, wenn eine Anfrage sich einreiht.
- Aktivität "Lernpfad" vollständig unterstützen inkl. didaktischer und pädagogischer Ideen, Hilfestellungen und Regeln, wie die gut einzusetzen sind, auch unter Regeln der Gamification
- Badges vollumfänglich unterstützen, inkl. didaktischer und pädagogischer Ideen, Hilfestellungen und Regeln, wie die gut einzusetzen sind, auch unter Regeln der Gamification
- Optimierungsphase: MCP-Server und Skill prüfen, ob wir tokenoptimiert arbeiten, z.B. ist das MCP Interface so gestaltet, dass kein balast durchgeleitet und nur nutzdaten (werden also z.B. alle nicht benötigten HTML-Tags von der Moodle Seite rausgefiltert?)
- Inwieweit brauchen wir python zur Laufzeit? Ersetzbar durch flutter, damit wir nicht noch eine zusätzliche runtime benötigen?
- Board und Kanban: Rückleseprobe je Aktion mit `verified` (A3); bisher
  zeigen sie nur den Stand danach.
- Kleine Funktionen, die fehlen: Farbe eines Eintrags der Fortschrittsliste
  (`nextcolour`), häufig gebrauchte Kommentare der Bewertungsrichtlinie.
- Selbstprüfung des Skills `lernsituation` ohne Python: Das Prüfskript
  (`scripts/pruefe-lernsituation.py`) braucht Python, das auf den Rechnern
  vieler Lehrkräfte fehlt; der Dialog „KI-Werkzeuge einrichten" weist nur darauf
  hin. Etwa als Werkzeug der App.
- Skill `lernsituation`: ODT-Ausgabe für den Druck (Skill `odt`); die
  SchuCu-Tabelle müsste dabei nach „Das Design außerhalb von Moodle"
  (`skills/lernsituation/CLAUDE.md`) entstehen, weil Umwandler HTML-Blöcke
  meist weglassen.
- Skill `lernsituation`: SchuCu-Tabelle auf anderen Instanzen. Die Klassen
  der Vorlagen (`lernsituation`, `lshead`, `lssubhead`, `lsdata`,
  `lsspacer`) haben dort kein CSS, die Tabelle erscheint ohne Farben – für
  beide Vorlagen (Berufsschule, Berufliches Gymnasium). Entweder die Stile
  in die Vorlagen (die SchuCu-Tabelle darf `style` tragen, A8) oder CSS für
  das Theme mitliefern.
- Skill `lernsituation`: weitere Fachvokabulare in Zeichnungen
  (Schaltzeichen nach DIN EN 60617, Netzsymbole) – einzeln messen und
  zulassen.
- Fragen: weitere Zusatz-Fragetypen (Formulas, GeoGebra, Kprim …) nur nach
  dem Messverfahren in `skills/moodle-fragen/CLAUDE.md`, etwa eine halbe
  Stunde je Typ; dann in `zusatzAnlegbar` (`lib/moodle/fragen_xml.dart`) und
  in die Tabelle im SKILL.md.
- Fragen: `ddimageortext`, `ddmarker` sind bewusst nur lesend; wenn sie
  gebraucht werden, eine Frage von Hand anlegen und das Koordinatenformat
  abschauen.
- Fragen: Struktur vorhandener Fragen ändern (weitere Antwort, weiterer
  Knoten) ist nicht eingebaut; das Formular baut sich dafür über eigene
  Knöpfe neu auf.
- STACK: einen vorhandenen Fragetest ändern, löschen oder ergänzen. Er steht auf einer eigenen Seite (`questiontestedit.php`, nicht auf der Positivliste); bisher hilft nur, die Frage neu anzulegen.

## Anonyme Aufgabenbewertung

Im Kurs die Teilnehmerliste lesen und substitutionen aufbauen und als Tabelle merken, die Schüler S1, S2, S3, usw. nennen. Auf der MCP-Seite werden nur die ersetzten Kürzel übertragen - in beide Richtungen.

Die Tabelle wird pro Kurs aufgebaut, wenn ein Schüler in zwei Kursen vorkommt, die im laufe einer Session bearbeitet wurden, bekommt er korrespondierent zu seinen posititionen in der Teilnehmerliste pro Kurs unterschiedliche Abkürzungen.

Wenn eine Aufgabe gelesen wird, müssen nicht nur Metadaten, sondern auch Daten anynymisiert werden:
 - In PDF und Office Dokumenten müssen wir scannen, ob ein Name eines Kursteilnehmer (nicht nur des Erstellers) vorkommen und durch Zufallsnamen wie Meyer, Müller, Peter und Hugo ersetzen (Selber name immer selbe ersetzung), damit wir notfalls rücksubstituieren können, falls das Modell in seiner Antwort einen Namen verwendet. Die Namen müssen vollständig aus den Daten entfernt werden, die ans modell geschickt werden - also Office und PDF Dateien entsprechend manipulieren
 - Bei Bildern muss Schrifterkennung auch von Handschrift durchgeführt werden und entsprechende Bereiche der Bilder zuverlässig vor Übertragung zum Modell gelöscht werden. Solange wir keine zuverlässige Handschrifterkennung haben, müssen wir die Weitergabe von Bilddateien ans Modell ablehnen
 - Bei allen anderen Dateien müssen wir binär scannen, ob ein Name vorkommt, zum Beispiel gibt es Dateien von Spezialprogrammen, die den Ersteller speichern - die finden wir durch dekomprimieren und evtl. binär suchen

 Bei allen Suchvorgängen nach Namen müssen wir im Hinterkopf behalten, dass Schüler sich manchmal vertippen, verschreiben oder die Schrifterkennung vielleicht nicht immer 100% zuverlässig ist. Auch bei Tippfehlern müssen wir die zuverlässig Namen erkennen.

 Ein Name der an das Modell durchrutscht, wäre der schlimmste Fehler, der uns passieren kann. Daher immer defensiv vorgehen.

 Wir legen nach und nach fest, welche Dateitypen überhaupt erlaubt sind. Office und PDF sind vermutlich die ersten. Alle weiteren Dateitypen müssen wir nach und nach testen und Freigeben, wie gesagt beispiel Bilddateien - die gehen erst, wenn wir zuverlässig Handschrift erkennen können oder Dateien von Spezialanwendungen müssen wir Stück für Stück immer prüfen, ob Erstellernamen im Projekt enthalten sein können.

 Man muss auch im Prinzip vielleicht nicht nach allen Namen suchen - es reicht, wenn man in den Teilnehmern des aktuellen Kurses sucht? Wenn einer der Teilnehmer Vor oder Nachnamen vorkommt, könnte das ein Problem sein. Bei beliebigen anderen Namen dürfte eigentlich kein Problem bestehen? Oder lieber eine deutsche Namensliste zugrundelegen?

 Geht Handschrifterkennung mit https://github.com/mittagessen/kraken?

# Bugs
- Schmales Fenster: Unter etwa 900 px Breite läuft der Kopf der Protokollspalte über („Protokoll" und „Leeren"), weil die linke Spalte fest 460 px breit ist. Die Titelzeile hält bis dahin. Entweder die linke Spalte schrumpfen lassen oder den Kopf kürzen.
- Einstellungen mit Optionsfeldern: Die Zeilen der Abschlussverfolgung
  lesen sich missverständlich („Keine = nein").
- Fragen zwischen Kategorien verschieben scheitert auf der Testinstanz (das
  Modul `qbank_bulkmove/bulk_move` lädt nicht); nach einem Leeren der Caches
  durch die Administration erneut prüfen, dann wäre der Weg zu messen.
