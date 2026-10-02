# Features
- "Sitzung verwerfen (Test)" Button entfernen
- Wissenspeicher STACK untersuchen und integrieren
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

# Bugs
- Einstellungen mit Optionsfeldern: Die Zeilen der Abschlussverfolgung
  lesen sich missverständlich („Keine = nein").
- Fragen zwischen Kategorien verschieben scheitert auf der Testinstanz (das
  Modul `qbank_bulkmove/bulk_move` lädt nicht); nach einem Leeren der Caches
  durch die Administration erneut prüfen, dann wäre der Weg zu messen.

# Durchspielen
Umgesetzt, aber noch nicht als Ganzes auf einer Instanz gelaufen.
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
