# Feature: Anonyme Bewertung von Abgaben (zuerst Packet Tracer)

Konzept und Fortschritt in einem. Ausgangspunkt sind die Projektidee (`PROJEKTIDEE_PACKET_TRACER_MCP.md` in diesem Ordner) und der Punkt „Anonyme Aufgabenbewertung" in [TODO.md](../TODO.md). Ist das Feature fertig, wandert das Gültige als Anforderungen und Entscheidungen in [CLAUDE.md](../CLAUDE.md) und als Beschreibung in die README; dieser Ordner wird dann gelöscht.

Legende: `[ ]` offen · `[~]` in Arbeit · `[x]` erledigt (umgesetzt und geprüft im Sinne von A3)

## 1. Ziel

Die KI bewertet Abgaben anhand eines Bewertungsschemas, ohne je personenbezogene Daten zu sehen. Abgaben kommen aus zwei Quellen:

- **Verzeichnis:** ein Ordner mit einem Unterordner je Person (auch das Format von „Alle Abgaben herunterladen" aus Moodle).
- **Moodle:** eine Aufgabe in einem Kurs, ausgewählt nach Gruppe oder Personen; die Ergebnisse gehen zurück in die Aufgabe.

Zuerst wird genau ein Dateityp unterstützt: Packet Tracer (`.pkt`, `.pka`). Die Architektur ist von Anfang an für weitere Typen gebaut (ODT, DOCX, PDF …), die einzeln geprüft und freigegeben werden.

## 2. Grundsätze

**G1 Nummern statt Personen.** Die KI kennt je Lauf nur die Nummern 1…n. Die Reihenfolge mischt die App für jeden Lauf neu, sodass dieselbe Person in zwei Läufen verschiedene Nummern hat und sich über Läufe hinweg kein Leistungsbild zusammensetzen lässt. Die Zuordnung Nummer → Person bleibt in der App (Laufdatei unter `%APPDATA%`, nie im Abgabeordner, nie im Arbeitsordner). Innerhalb eines Laufs bleibt sie stabil, damit ein unterbrochener Lauf fortgesetzt werden kann: `abgaben_status` nennt, welche Nummern schon bewertet sind.

**G2 Auslesen nach Positivliste, nicht Bereinigen.** An die KI geht nie eine Datei, sondern nur, was ein Leser für den Dateityp ausdrücklich herauszieht: bei PKT Geräte, Verbindungen, Konfigurationen, Adressen. Eine bereinigte Datei entfernt nur, was man kennt; ein Leser gibt nur weiter, was man kennt (wie E3). Dateitypen ohne Leser werden nicht weitergegeben, sondern als „nicht unterstützt" gemeldet.

**G3 Freitext nur durch den Namensfilter.** Jeder Freitext, den ein Leser liefert (Hostnamen, Banner, Beschreibungen, Notizen, Textfelder, Dateinamen in Konfigurationen), läuft durch den Abgleich mit der Namensliste des Laufs: im Verzeichnis die Ordnernamen, in Moodle die Teilnehmenden des Kurses. Der Abgleich ist fehlertolerant (Tippfehler, Groß- und Kleinschreibung, Umlaute ↔ ae/oe/ue, Teile von Namen). Ein Treffer wird ersetzt durch einen erkennbar erfundenen Platzhalter (`[Name 1]`), gleicher Name gleicher Platzhalter. Im Zweifel ersetzen: Ein durchgerutschter Name ist der schlimmste Fehler.

**G4 Keine Metadaten.** Ordnernamen, Dateinamen, Zeitstempel, Dateigrößen, Moodle-IDs, Abgabezeitpunkte, Gruppen gehen nie an die KI. Hat eine Abgabe mehrere Dateien, heißen sie für die KI `datei-1.pkt`, `datei-2.pkt`.

**G5 Kein Pfad, nirgends.** Der Pfad des Abgabeordners und der Ort der Berichte erscheinen in keiner Werkzeugantwort, keinem Protokolleintrag, keiner Fehlermeldung und keiner Datei, die die KI lesen kann. Der Skill beschreibt den Zugriff ausschließlich über die Werkzeuge. Die Oberfläche weist darauf hin, eine Claude-Sitzung nie im Abgabeordner oder darüber zu starten. Eine `deny`-Regel in den KI-Werkzeugen ist damit nicht nötig.

**G6 Die App rechnet, die KI urteilt.** Alles Algorithmische macht die App: Auslesen, Vergleich mit Vorlage und Musterlösung, prüfbare Kriterien, Summen, Prozent (eine Nachkommastelle), Grenzen der Punkte, Berichte, Rückschreiben. Die KI bekommt nur, was ein Urteil braucht, und liefert nur Urteile (Punkte und Text je Kriterium).

**G7 Auch Protokolle und Fehler sind anonym, auch beim Entwickeln.** Was die KI lesen kann (Werkzeugantworten, `protokoll.log`, Fehlermeldungen, Ausgaben von `tool/mcp_aufruf.sh`, Testausgaben), enthält keine Namen, keine Moodle-Nutzer-IDs, keine Pfade zu Abgaben – auch nicht im Testkurs. Adressen mit personenbezogenen Parametern (`userid`, `user`, `rownum` …) erscheinen im Protokoll ohne Parameterwerte, wie heute bei gesperrten Adressen (A4). Fehler in einem Bewertungslauf nennen die Nummer, nie die Person. Testdaten im Repository sind erfunden (A11).

**G8 Die Lehrkraft gibt frei, nicht die KI.** In Moodle werden nur Aufgaben mit aktiviertem Bewertungsworkflow bewertet. Die App setzt den Status höchstens auf „Bereit zur Freigabe"; „Freigegeben" (die Lernenden sehen die Bewertung) setzt nur die Lehrkraft in Moodle, nach eigener Prüfung. Ohne Workflow lehnt das Werkzeug ab und sagt, warum.

## 3. Entscheidungen (getroffen)

- **D1 Teil von moocp, keine eigene App.** Einrichtung der KI-Werkzeuge, Updates, Installer, Brücke, Protokoll und Freigaben gibt es schon; eine zweite App brächte zwei MCP-Einträge, zwei Installer und zwei Sätze Skills. Wiederverwendbare Logik liegt in Paketen unter `packages/` (wie `zwischenablage_html`).
- **D2 A1 wird bewusst geändert.** Abgaben und Teilnehmerliste dürfen gelesen werden – nur durch die App, nur für einen Bewertungslauf, nie an die KI. Der genaue neue Wortlaut von A1 und die Ausnahmen in Sperrliste und Positivliste entstehen in Phase 0.
- **D3 E13 wird geändert.** Der MCP-Server startet auch ohne Moodle-Anmeldung; die Moodle-Werkzeuge melden dann „nicht angemeldet". Die Bewertung aus dem Verzeichnis braucht keine Anmeldung.
- **D4 Kein Modus beim Start.** Eine *Bewertungsvorlage* (Projektdatei) beschreibt die Aufgabe unabhängig von der Quelle; ein *Lauf* ist Vorlage plus Quelle.
- **D5 Rückmeldung wählbar:** eine Sammeldatei zum Drucken (je Person eigene Seiten) oder eine Datei je Person; Vorgabe ist die Sammeldatei.
- **D6 Berichte als ODT aus einer OTT-Vorlage**, die in den Einstellungen gewählt wird (Corporate Design: Kopf- und Fußzeile, Logo, Absatz- und Tabellenvorlagen). Ohne Vorlage nimmt die App eine eingebaute. PDF entsteht bei Bedarf über LibreOffice, wenn es installiert ist.
- **D7 Ergebnisse zurück nach Moodle**, in die Bewertung der Aufgabe (Rubrik bzw. Bewertungsrichtlinie mit Kommentar je Kriterium, sonst Punkte und Feedbacktext), mit Workflow nach G8.
- **D8 PKT statisch lesen, eigene Umsetzung in Dart.** `packet-tracer-pkt-format` steht unter GPL-3.0 und ist mit E14 unvereinbar; es dient nur als Formatbeschreibung, Code wird nicht übernommen. Ob `pktctl` (MIT, Rust) einen eigenen Codec enthält, der als Vorlage taugt, wird in Phase 1 geprüft.
- **D9 Verhaltensprüfung über Packet Tracer kommt später** (Abschnitt 9).

## 4. Architektur

| Schicht | Ort | Aufgabe |
|---|---|---|
| `pkt` | `packages/pkt` (reines Dart) | Entschlüsseln, XML lesen, Datenmodell (Geräte, Interfaces, VLANs, ACLs, Routen, Dienste, Notizen), Vergleich zweier Dateien, Liste aller Freitextfelder |
| `bewertung` | `packages/bewertung` (reines Dart) | Quelle (Verzeichnis, Moodle über Schnittstelle), Nummernvergabe, Lauf und Laufdatei, Leser je Dateityp, Namensfilter, Schema, prüfbare Regeln, Ergebnisse, Berichte (ODT) |
| App | `lib/bewertung/` | Oberfläche (Vorlage bearbeiten, Lauf starten, Teilnehmerauswahl), MCP-Werkzeuge, Moodle-Anbindung (Abgaben lesen, Bewertung schreiben) |
| Skill | `skills/bewertung/` | Ablauf, Umgang mit offenen Kriterien, Formulierung der Rückmeldung |

`pkt` ist auch außerhalb der Bewertung nützlich: In Lernsituationen und beim Erstellen von Klausuren kann die KI lesen, was in einer PKT-Datei eines Kurses passiert (später auch erzeugen). Dort gilt G3 nicht, weil keine Abgaben im Spiel sind; die Leser liefern dasselbe Modell.

**Leser je Dateityp** haben eine gemeinsame Schnittstelle: Datei → strukturierter Auszug + Liste der Freitextstellen. Ein Typ gilt erst als unterstützt, wenn für ihn gemessen ist, wo Personendaten stehen können, und der Leser genau diese Stellen filtert oder weglässt. Reihenfolge: PKT, dann ODT/DOCX/PDF (Text), Bilder erst mit zuverlässiger Handschrifterkennung.

## 5. Bewertungsvorlage (Projektdatei)

JSON-Datei, die die Lehrkraft speichert und für die nächste Klasse wieder lädt. Inhalt:

1. Aufgabentext – oder der Vermerk „steht in der Vorlage", dann liest die App die Textfelder der Vorlage.
2. Vorlage (die Datei, die die Lernenden bekommen haben), eingebettet oder als Pfad.
3. Musterlösung, ebenso.
4. Bewertungsschema: Zeilen mit Kriterium, erreichbaren Punkten und, falls prüfbar, der Regel (Beispiel: `interface(R1, Gi0/0).ip == 10.0.0.1/30`).
5. Wahl der Rückmeldung (D5) und OTT-Vorlage, falls abweichend von den Einstellungen.

Ablauf: Nach 1–3 zeigt die Oberfläche das leere Schema. Auf Wunsch schlägt die KI eines vor – aus Aufgabentext und dem Unterschied Vorlage → Musterlösung – und markiert dabei, welche Kriterien sich als Regel prüfen lassen. Die Lehrkraft bearbeitet Zeilen, Punkte und Regeln. Die Regeln liegen in der Vorlage, der nächste Lauf kostet für sie keine Tokens.

In Moodle kommen Aufgabentext, Anhänge und Schema aus der Aktivität (`bewertungsschema_lesen` gibt es schon); die Regeln liegen dann in einer Bewertungsvorlage, die der Aufgabe zugeordnet ist.

## 6. Ablauf eines Laufs

1. Lehrkraft wählt in der App Vorlage und Quelle (Ordner oder Moodle-Aufgabe mit Auswahl nach Gruppe, Gruppierung oder Personen, jeweils mit Suchfeld; bereits Bewertete: neu bewerten oder streichen).
2. App mischt, vergibt Nummern, liest alle Abgaben, filtert (G2–G4), führt die Regeln aus.
3. KI fragt `lauf_info` (Aufgabe, Schema, Anzahl, Status je Nummer) und je Nummer `abgabe_lesen(nr)`: Ergebnisse der Regeln, Unterschied zur Vorlage und zur Musterlösung als Fakten, nur offene Kriterien.
4. KI liefert je Nummer `bewertung_speichern(nr, [{kriterium, punkte, text}])`. Die App prüft Grenzen und Vollständigkeit.
5. Abschluss: Übersicht für die Lehrkraft (Tabelle Person × Kriterium, erreichbar/erreicht, Summe, Prozent), Rückmeldung je Person mit den Spalten „Erwartete Leistung", „Erreichtes Ergebnis", „Punkte (erreichbar / erreicht)". Im Verzeichnis liegen die Dateien im Wurzelordner der Abgaben; in Moodle gehen die Ergebnisse in die Aufgabe (D7, G8). Namen setzt erst die App ein.

Werkzeuge (Entwurf): `vorlage_lesen`, `schema_vorschlagen` (liefert die Daten für den Vorschlag), `schema_setzen`, `lauf_info`, `abgabe_lesen`, `bewertung_speichern`, `lauf_abschliessen`. Jede Antwort nur mit Nummern.

## 7. Phasen und Fortschritt

### Phase 0 – Entscheidungen festschreiben
- [ ] Neuer Wortlaut von A1 (D2) und Ausnahme in Sperrliste/Positivliste, mit Test in `test/sperrliste_test.dart`
- [ ] E13 ändern (D3)
- [ ] Neue Entscheidung „Anonyme Bewertung" mit G1–G8 in CLAUDE.md
- [ ] Protokoll und Fehlermeldungen nach G7 prüfen: Wo können heute schon Nutzer-IDs oder Namen in `protokoll.log` landen?
- [ ] TODO „Anonyme Aufgabenbewertung" auf diesen Plan verweisen lassen

### Phase 1 – Machbarkeit PKT
- [ ] Beispieldateien (Vorlage, Musterlösung, eine Abgabe mit erfundenen Namen) als Testdaten
- [ ] Prototyp: Entschlüsseln (Twofish-EAX, XOR, zlib) in Dart; Twofish/EAX aus freizügigem Paket oder eigene kleine Umsetzung
- [ ] Prüfen, ob `pktctl` einen Codec unter MIT enthält
- [ ] Inventar der Personendaten in PKT/PKA messen: Hostnamen, Banner, Notizen, Textfelder, Benutzerprofil in `.pka`, gespeicherte Pfade, sonstige Freitextfelder
- [ ] Größenvergleich: rohes XML vs. Auszug vs. Unterschied zur Vorlage (Tokens)

### Phase 2 – Paket `pkt`
- [ ] Datenmodell und Leser
- [ ] Konfiguration in Struktur (Interfaces, VLANs, Trunks, ACLs, Routen, DHCP, NAT …)
- [ ] Vergleich zweier Dateien
- [ ] Textfelder als Aufgabentext auslesen
- [ ] Tests mit erfundenen Dateien

### Phase 3 – Paket `bewertung`
- [ ] Quelle Verzeichnis (auch Moodle-Downloadformat), Nummernvergabe, Laufdatei, Fortsetzen
- [ ] Namensfilter (fehlertolerant) mit Tests, die gezielt Tippfehler und Teilnamen prüfen
- [ ] Schema, Regelsprache für prüfbare Kriterien, Auswertung
- [ ] Bewertungsvorlage lesen/schreiben

### Phase 4 – Berichte
- [ ] OTT-Vorlage in den Einstellungen, eingebaute Vorlage als Rückfall
- [ ] Übersicht und Rückmeldung (Sammeldatei / Einzeldateien) als ODT
- [ ] PDF über LibreOffice, falls vorhanden

### Phase 5 – Oberfläche, Werkzeuge, Skill (Quelle Verzeichnis)
- [ ] Oberfläche für Vorlage, Schema und Lauf, Hinweis aus G5
- [ ] MCP-Werkzeuge aus Abschnitt 6
- [ ] Skill `bewertung`
- [ ] README (Übersicht, Werkzeugtabellen, Sperrliste) und CHANGELOG nachziehen
- [ ] Durchspielen mit erfundenen Abgaben

### Phase 6 – Quelle Moodle
- [ ] Teilnehmerauswahl in der App (Gruppe, Gruppierung, Personen, Suchfelder)
- [ ] Abgaben lesen (Adressen messen, in die Positivliste nur mit dem Werkzeug, E3)
- [ ] Bewertungsworkflow prüfen, sonst ablehnen (G8)
- [ ] Ergebnisse zurückschreiben: Rubrik/Richtlinie, Kommentar, Status „Bereit zur Freigabe"; Rückleseprobe (A3)
- [ ] Im Testkurs mit Probepersonen messen (A10, G7)

### Phase 7 – weitere Dateitypen
- [ ] ODT/DOCX (Text, Metadaten wie Ersteller entfernen)
- [ ] PDF (Text, Metadaten)
- [ ] Bilder erst mit zuverlässiger Handschrifterkennung (offen: taugt kraken?)

## 8. Offene Fragen

- Soll die Moodle-Einstellung „Anonyme Bewertung" (blind marking) zusätzlich genutzt oder vorausgesetzt werden?
- Ähnliche oder gleiche Abgaben erkennen (algorithmisch einfach) – gewünscht?
- Regelsprache: eigene kleine Sprache oder strukturierte JSON-Bedingungen?
- Welche Namensliste in Moodle: nur Teilnehmende des Kurses oder zusätzlich eine allgemeine Liste deutscher Vornamen?

## 9. Später: Verhaltensprüfung über Packet Tracer

Manche Kriterien beschreiben Verhalten statt Konfiguration, etwa „Rechner aus VLAN 10 erreichen VLAN 20 nicht, aber beide erreichen den Drucker in VLAN 100". Statisch beurteilt die KI das aus den ausgelesenen ACLs, VLANs und Routen; das reicht meist, ist aber ein Urteil, keine Messung. Gemessen würde es, indem die App jede Abgabe in Packet Tracer öffnet und Pings oder Traceroutes ausführt, über die Schnittstelle PTMP (TCP 39000), wie es `pktctl` (MIT) tut. Nachteile: Packet Tracer muss mit Oberfläche laufen, jede Datei wird geöffnet (langsam), die App muss in Packet Tracer registriert werden, und die Schnittstelle ist auf Windows noch nicht erprobt. Bewusst verschoben; die Regeln aus Abschnitt 5 sollen aber so gebaut sein, dass später eine Regelart „erreichbar(von, nach)" dazukommen kann.

- [ ] Offen: Verhaltensprüfung über Packet Tracer
