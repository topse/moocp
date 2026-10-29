# Features
- Wissenspeicher STACK untersuchen und integrieren
- "Sitzung verwerfen (Test)" Button entfernen
- Fragensammlung verbergen, verschieben und duplizieren: geht nicht, weil `qbank` nicht in der Kursstruktur steht. Löschen hat einen eigenen Weg über die Sammlungsliste; die drei bräuchten denselben.
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
  vieler Lehrkräfte fehlt; der Dialog „Claude einrichten" weist nur darauf
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

 Bei allen Suchvorgängen nach Namen müssen wir im Hinterkopf behalten, dass Schüler sich manchmal vertippen. Auch bei Tippfehlern müssen wir die zuverlässig Namen erkennen.

 Ein Name der an das Modell durchrutscht, wäre der schlimmste Fehler, der uns passieren kann. Daher immer defensiv vorgehen.

 Wir legen nach und nach fest, welche Dateitypen überhaupt erlaubt sind. Office und PDF sind vermutlich die ersten. Alle weiteren Dateitypen müssen wir nach und nach testen und Freigeben, wie gesagt beispiel Bilddateien - die gehen erst, wenn wir zuverlässig Handschrift erkennen können oder Dateien von Spezialanwendungen müssen wir Stück für Stück immer prüfen, ob Erstellernamen im Projekt enthalten sein können.

# Bugs
- Einstellungen mit Optionsfeldern: Die Zeilen der Abschlussverfolgung
  lesen sich missverständlich („Keine = nein").
- Fragen zwischen Kategorien verschieben scheitert auf der Testinstanz (das
  Modul `qbank_bulkmove/bulk_move` lädt nicht); nach einem Leeren der Caches
  durch die Administration erneut prüfen, dann wäre der Weg zu messen.

# Durchspielen
Umgesetzt, aber noch nicht als Ganzes auf einer Instanz gelaufen.
- Updates: Voraussetzung ist ein echtes Release (Tag `v0.9.4`, Datei
  `moocp_setup_0.9.4.exe`). Dann eine 0.9.3 bauen, installieren und
  durchspielen: Frage beim ersten Start (beide Antworten), Angebot,
  „Jetzt nicht" und am nächsten Tag wieder, Download mit Fortschritt,
  Abbrechen mittendrin, sichtbarer Installer, Neustart der App, Meldung
  „auf Fassung … aktualisiert" im Protokoll. Dazu die Wege ohne Netz
  (Start wartet höchstens zehn Sekunden und läuft weiter) und die Suche
  aus den Einstellungen heraus.
- Updates, Wettlauf mit dem Installer: Der Installer wartet mit `/UPDATE`
  bis zu 30 Sekunden still darauf, dass die App ihre exe freigibt. Dass das
  Fenster in dieser Zeit nicht wie hängengeblieben aussieht und die Frage
  „moocp läuft noch" wirklich erst danach kommt, ist nur am laufenden
  System zu sehen.
- Updates auf einem verwalteten Schulrechner: Schlägt der Virenschutz an,
  wenn die App ein unsigniertes Setup lädt und startet? Dieselbe Sorge wie
  bei der Fernsteuerung des Browsers.
- Installer: Installieren, Update über eine ältere Fassung, Deinstallieren
  samt Einrichtung in Claude Code, auf einem frischen Windows ohne Visual
  Studio – dort zeigt sich auch, ob die mitgelieferte VC++-Laufzeit reicht.
  Gebaut und übersetzt ist er; das Entfernen der Einrichtung
  (`--claude-entfernen`) lief gegen eine Attrappe mit `CLAUDE_CONFIG_DIR`.
- Wählbare Skills: im Dialog „Claude einrichten" `lernsituation` anhaken
  und installieren, später über das Puzzlestück in der Titelzeile abwählen
  und prüfen, dass der Ordner unter `~/.claude/skills` verschwindet; ein
  Update über eine Fassung, in der `lernsituation` schon installiert war,
  darf ihn nicht entfernen.
- Druckaufbereitung: Karofeld auf echtem Papier (Grauwert `#c0c0c0`,
  0,4 pt hell genug und trotzdem sichtbar?); ob erzeugte Inhalte sauber
  umbrechen, besonders Tabellen und lange Listen.
- Anlegen von Link (`url`) und Datei (`resource`).
- Übernahme eines echten Blatts (PDF, ODT, DOCX) nach
  `skills/moodle/references/uebernehmen.md`.
- Fragen: `calculated` (die geteilte Variante, Aufbau wie
  `calculatedsimple` mit `<status>shared</status>`); die STACK-Eingabetypen
  `checkbox`, `matrix`, `equiv`, `boolean`, `textarea`, `notes` – bauen,
  Testfälle mitgeben, Testlauf ansehen.
- Skill `lernsituation`: eine Handlungssituation als eigenes Textfeld
  (`label`) übertragen, `links_setzen` laufen lassen und mit `--moodle`
  prüfen; Buch, Aufgabe und Unterabschnitt sind so gelaufen, das Textfeld
  noch nicht.
- Skill `lernsituation`: Die Prosa ist nicht geprüft. Das Skript prüft die
  Form; ob der Agent wirklich erst fragt und dann Vorschläge macht, zeigt
  nur die Anwendung. Nach den ersten echten Lernsituationen festhalten, was
  schiefging.
- Überarbeiten (`skills/gemeinsam/ueberarbeiten.md`): Fragt der Agent vorn im Plan „direkt oder an einer Kopie", entscheidet er je Objekt nach „genau ein Vorgänger" zwischen Duplizieren und Neuanlegen, stellt er die Links der Kopie auf die Kopie um, und bleibt das Neue frei von Verweisen auf das Original?
- Arbeitsbereich (`skills/gemeinsam/aktueller-kurs.md`, `plan.md`): Bleibt der Agent in der genannten Lernsituation, wenn ein Auftrag „im Kurs" oder „überall" sagt, und fragt er vorn im Plan nach den übrigen Abschnitten, statt sie zu lesen? In einer echten Sitzung mit mehreren Lernsituationen im Kurs beobachten.
- Claude einrichten auf einem frischen Rechner: Legt Claude Desktop Claude Code erst an, wenn man einmal den Bereich „Code" öffnet? Davon geht der Hinweis im Dialog aus. Dabei die Wege des Dialogs durchspielen, die bisher nicht gelaufen sind: „Claude Code nicht gefunden" mit „Nochmal prüfen", ein gescheitertes Installieren mit „Nochmal versuchen", „Beenden" (App schließt, Arbeitsordner geleert).
- Bildschirmfotos auf einem verwalteten Schulrechner: Schlägt der
  Virenschutz an, wenn die App einen Browser mit Fernsteuerung
  (`--remote-debugging-port`) startet? Dieselbe Technik nutzt Schadsoftware,
  die Cookies stiehlt. Dabei die Wege, die hier nicht laufen können: Chrome
  statt Edge (nur ohne Edge), die Meldung bei abgeschalteter Fernsteuerung
  (Richtlinie `RemoteDebuggingAllowed`).
- Wiki nach Gruppen: Die Erkennung (`wikiAnsichtSperre` in
  `lib/moodle/wiki.dart`, Auswahl `group` bzw. `groupanduser` über dem Wiki)
  ist nach dem Moodle-Quelltext gebaut und offline getestet; der Testkurs
  hatte keine Gruppen. In einem Kurs mit Gruppen ein gemeinsames und ein
  persönliches ZZ-Wiki im Gruppenmodus anlegen: `wiki_lesen`,
  `wikiseite_schreiben` und `bildschirmfoto` müssen abbrechen.
- Bildschirmfoto: Beim Beenden kam einmal ein „Unerwarteter Fehler:
  StateError" (eine Anfrage des Browsers lief noch, als die Verbindung schon
  zu war). Abgefangen, aber das Rennen lässt sich nicht gezielt auslösen –
  nach den nächsten Bildschirmfotos im Protokoll nachsehen.
