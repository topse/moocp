# Buch, Fortschrittsliste, Wiki, Board, Kanban, Bewertungsschema

Typen mit eigenen Werkzeugen, weil ihr Inhalt nicht im Bearbeitungsformular steht. Ihre Einstellungen gehen wie bei jeder Aktivität über `aktivitaet_lesen` und `aendern` (`references/bearbeiten.md`).

## Buch (mod_book)

`buch_lesen(cmid)` liest alle Kapitel — Reihenfolge mit Ebene und id, und
jedes Kapitel vollständig wie `aktivitaet_lesen` nach
`buch-<cmid>/kapitel-<id>/` (`content_editor.html`, `dateien/`). Ein Kapitel
ändern: dort bearbeiten, `aendern(ordner des Kapitels)`.

| Ziel | Werkzeug |
|---|---|
| Kapitel anlegen | `buchkapitel_anlegen(cmid, titel, nach_kapitel_id?, unterkapitel?, ordner?)` — Inhalt in `content_editor.html` |
| Hauptkapitel ordnen | `buch_ordnen(cmid, reihenfolge)` — nur Hauptkapitel, Unterkapitel wandern mit; geprüft wird Reihenfolge **und** Hierarchie |
| ein Kapitel schrittweise | `buchkapitel_verschieben(cmid, kapitel_id, titel, richtung, schritte?)` |
| löschen | `buchkapitel_loeschen(cmid, kapitel_id, titel)` — ein Hauptkapitel nimmt seine Unterkapitel mit |

**Ein Schritt bedeutet nicht bei jedem Kapitel dasselbe** (gemessen): Ein
Hauptkapitel wandert als Block mit seinen Unterkapiteln. Ein Unterkapitel
wandert um eine Position — und wechselt dabei stillschweigend den Elternteil;
an erster Stelle macht Moodle ohne Rückfrage ein Hauptkapitel daraus.
`buchkapitel_verschieben` bricht in beiden Fällen vorher ab und sagt, was
passieren würde. `elternwechsel_ok` bzw. `zu_hauptkapitel_ok` setzt du erst,
wenn der Nutzer das ausdrücklich will — die Strukturänderung sieht man dem Buch
später nicht mehr an.

Ist das Buch für Lernende sichtbar, erscheint ein neues Kapitel sofort; die App
fragt dann vorher. Moodle verlangt in jedem Kapitel Inhalt (gemessen), auch in
einem, das nur Unterkapitel gliedert — dort genügt ein Satz, was darin steht.
Am Buch selbst (`aendern` auf `cm-<cmid>`) gibt es `numbering` (keine,
Nummern, Aufzählung, Einrückung) und `customtitles`. Heißen die Kapitel schon
„Schritt 1" und so weiter, ist „Keine" richtig; mit „Nummern" stünde „2.1
Schritt 1" da.

## Fortschrittsliste (mod_checklist)

Eine Liste von Einträgen zum Abhaken. **Die Einträge sind Kursinhalt, die
Häkchen sind Personendaten** — die App liest nur die Einträge, nie, wer was
abgehakt hat.

`fortschrittsliste_lesen(cmid)` liefert je Eintrag id, Text, Zustand
(Pflicht, optional, Überschrift), Einrückung und Link.
`fortschrittsliste_aendern(cmid, name, aktionen)` führt alle Aktionen nach
**einer** Freigabe aus:

| `art` | Angaben |
|---|---|
| `neu` | `text`, `link?`, `tiefe?` (0 = Hauptebene), `zustand?` (`pflicht`, `optional`, `ueberschrift`; ohne Angabe, was Moodle vorgibt) |
| `aendern` | `eintrag`, `text`, `link?` (weggelassen = behalten, `""` = entfernen) |
| `loeschen`, `hoch`, `runter`, `einruecken`, `ausruecken` | `eintrag` |
| `pflicht`, `optional`, `ueberschrift` | `eintrag` |

**Ändern statt löschen und neu anlegen** — der Eintrag behält seine id und
damit alles, was daran hängt. **Löschen fragt in Moodle nicht nach**; die
Freigabe der App ist die einzige Rückfrage. Moodle nimmt beim Anlegen jede
Einrückung, auch einen Sprung von 0 auf 5 — mehr als eine Stufe unter dem
Vorgänger ergibt eine Liste, die niemand lesen kann.

Die Einstellungen der Aktivität (über `aktivitaet_lesen`/`aendern`) stehen in
`references/bearbeiten.md`. `autopopulate` zieht Kursaktivitäten automatisch in
die Liste — bequem, aber die Liste bildet dann den Kurs ab, nicht deine
Gliederung. Sag es, wenn du es einschaltest.

## Wiki, Board, Kanban: Inhalt, den auch Lernende schreiben

Bei diesen drei Typen stammt der Inhalt selbst zum Teil von Lernenden. Die
Grenze verläuft deshalb *innerhalb* der Aktivität, und die App zieht sie so:

| | Kursinhalt — lesen und schreiben | Personendaten — nie |
|---|---|---|
| **Wiki** | Seiten des gemeinsamen Wikis: Liste, Text, anlegen, ändern, löschen | wer welche Version schrieb, Kommentare, „Mitwirkung", jedes persönliche Wiki, jedes Wiki nach Gruppen |
| **Board** | Spalten: anlegen, umbenennen, verschieben, sperren, löschen; **eigene** Notizen | Notizen anderer — sie werden nur **gezählt**; Export, Einzelnutzer-Ansicht |
| **Kanban** | Spalten und Karten des gemeinsamen Kursboards: Titel, Beschreibung, Reihenfolge | Ersteller, Zuweisung, Diskussion, Verlauf; persönliche Boards; Export |

Fragt jemand „wer hat das geschrieben?", gilt dasselbe wie bei Noten: Das kann
die App bewusst nicht. **Löschen fragt in Moodle bei allen dreien nicht
nach** — die Freigabe der App ist die einzige Rückfrage.

### Wiki

`wiki_lesen(cmid)` legt alle Seiten nach `wiki-<cmid>/seite-<pageid>.html` und
prüft das Verweisnetz — die Frage, die Moodle selbst nicht beantwortet:

| Befund | Was er bedeutet |
|---|---|
| tote Verweise | Verweis auf eine **gelöschte** Seite. Führt zu HTTP 404. Moodles „Verwaiste Seiten" zeigt das nicht an. |
| nie angelegte Titel | Harmlos — der Link bietet das Anlegen an —, aber eine offene Baustelle. |
| verwaiste Seiten | Seite, auf die niemand verweist. Im Unterricht praktisch unsichtbar. |

`wikiseite_schreiben(cmid, titel, datei)` legt eine Seite an oder **ersetzt
ihren ganzen Inhalt** — erst lesen, dann die geänderte Fassung zurückschreiben.
Ersetzen geht nur nach Freigabe (es ersetzt auch, was Lernende schrieben).
Verweise auf andere Seiten als `[[Titel]]`; solange die Seite fehlt, meldet
`wiki_lesen` sie als nie angelegt. So entstehen weitere Seiten am besten aus
dem Text heraus.

Ein neues Wiki hat **keine Startseite**; die erste Seite muss den Titel tragen,
der in den Einstellungen als `firstpagetitle` steht. `wikiseite_loeschen(cmid,
seite, titel)` nennt die Seiten, die auf die gelöschte verweisen — die gleich
richtigstellen und dem Nutzer nennen, denn ihr Verweis führt ins Leere, bis
Moodle den Seitenaufbau neu berechnet.

Nicht eingebaut: einzelne Abschnitte einer Seite bearbeiten, Creole und NWiki
(die App schreibt HTML), Dateien im Wiki. Ein **persönliches Wiki** liest die
App nicht, ebenso wenig ein Wiki im Gruppenmodus, auch solange der Kurs keine Gruppen hat: Mit Gruppen hat jede Gruppe dort eigene Seiten, geschrieben von ihren Mitgliedern. Die Werkzeuge melden es; soll daran gearbeitet werden, muss der Gruppenmodus auf „Keine Gruppen" stehen.

### Board

`board_lesen(cmid)` liefert die Spalten mit id, Name, gesperrt, Anzahl der
Notizen und die **eigenen** Notizen mit id. `board_aendern(cmid, name,
aktionen)`, alles nach einer Freigabe:

`spalte_neu {name}` · `spalte_umbenennen {spalte, name}` ·
`spalte_verschieben {spalte, position}` · `spalte_sperren {spalte, gesperrt}` ·
`spalte_loeschen {spalte, mit_notizen?}` · `notiz_neu {spalte, titel, inhalt}` ·
`notiz_aendern {notiz, titel?, inhalt?}` · `notiz_loeschen {notiz}`

Eine Spalte mit fremden Notizen löscht die App nur mit `mit_notizen: true` —
den setzt du erst nach einem ausdrücklichen Ja. Ein Board wird meist aus einer
**Vorlage** angelegt (Exit Ticket, SWOT, Kanban …) und bringt Spalten mit, die
„Überschrift" heißen und umbenannt werden wollen; ohne Vorlage sind es drei
solche Spalten (gemessen 09.10.2026). Im **Einzelnutzermodus**
(`singleusermode` privat oder öffentlich) hat jede Person ein eigenes Board;
dort arbeitet die App nicht.

### Kanban-Board

`kanban_lesen(cmid)` liefert Spalten und Karten des Kursboards (ohne Ersteller
und Zuweisung). `kanban_aendern(cmid, name, aktionen)`:

`spalte_neu {titel, nach?}` · `spalte_umbenennen {spalte, titel}` ·
`spalte_verschieben {spalte, nach}` · `spalte_loeschen {spalte, mit_karten?}` ·
`karte_neu {spalte, titel, beschreibung?}` · `karte_aendern {karte, titel?,
beschreibung?}` · `karte_verschieben {karte, spalte, nach?}` ·
`karte_loeschen {karte}`

Ein neues Kanban-Board hat drei Spalten (Zu erledigen, In Arbeit, Erledigt);
„Erledigt" schließt Karten automatisch ab. Die Lehrkraft legt
**Vorlagenkarten** an — Arbeitsaufträge, die Lernende ziehen und sich zuweisen.
Termin, Farbe, Anhänge und Zuweisung bleiben der Oberfläche. `userboards`
entscheidet, ob es neben dem Kursboard persönliche Boards gibt oder nur solche;
bei „ausschließlich" gibt es kein Kursboard, und die App findet keines.

## Bewertungsschema einer Aufgabe

`bewertungsschema_lesen(cmid)` legt die **Definition** der Rubrik oder Bewertungsrichtlinie nach `bewertung-<cmid>.json`: Kriterien, Stufen, Punkte und unter `optionen` die Einstellungen des Schemas. Die Übersicht, die das Werkzeug zurückgibt, nennt die Kriterien mit den Punkten ihrer Stufen und die Optionen mit Beschriftung; die Texte der Stufen stehen nur in der Datei. Bei einfacher direkter Bewertung gibt es kein Raster; dann zählen die Punkte aus dem Aufgabenformular.

Ein Schema setzen:

1. Die Methode stellt `aendern` an der Aufgabe um: Einstellung `advancedgradingmethod_submissions` auf „Rubrik" oder „Bewertungsrichtlinie" (die App nennt die Möglichkeiten, falls der Text nicht passt).
2. Eine JSON-Datei im Aufbau von `bewertung-<cmid>.json` schreiben: bestehende ids behalten, neue Kriterien und Stufen **ohne** id, weggelassene Kriterien werden gelöscht. Unter `optionen` nur, was sich ändern soll – `ja`/`nein`, bei einer Auswahl ihr Text; nicht Genanntes bleibt, wie es ist.
3. `bewertungsschema_setzen(cmid, name, datei)` — nach Freigabe mit Vorher-nachher. Die Rückleseprobe vergleicht Name, Kriterien, Stufen, Punkte und Optionen; `verified: false` nennt die Abweichungen.

Die Optionen sind fachliche Entscheidungen und gehören in den Plan wie die Kriterien. Die häufigste: Sollen Lernende das Raster schon vor der Bewertung sehen („Raster sichtbar", „Kriterien vorher zeigen"), ist das `alwaysshowdefinition` – bei der Rubrik „Nutzer/innen eine Vorschau auf die Rubrik erlauben", bei der Richtlinie „Beschreibung für Teilnehmer/innen anzeigen"; ohne sie sehen Lernende das Raster erst mit ihrer Bewertung. Ein neues Schema hat alle Optionen an. Wünscht die Lehrkraft Sichtbarkeit, also erst nachsehen, bevor ein Schreibvorgang geplant wird.

**Vor dem Ändern einer Definition, die schon benutzt wird, fragen.** Eine
geänderte Rubrik verschiebt die Bedeutung bereits vergebener Bewertungen. Die
ausgefüllten Raster einzelner Personen liest die App nie.
