# Abschnitte, Kapitel, Lernsituationen

## Was gemeint ist

„Kapitel" und „Lernsituation" meinen im Kursaufbau fast immer einen
**Kursabschnitt**: ein benannter Block auf der Kursseite, der Aktivitäten und
Material bündelt. Das ist etwas anderes als ein Kapitel im Buch (`mod_book`),
das nur innerhalb einer einzelnen Buch-Aktivität existiert.

Entscheide nach dem Kurs: Enthält er sichtbar Bücher und bezieht sich der
Auftrag darauf, geht es um Buchkapitel. Sonst um Abschnitte. Im Zweifel ein
Satz Rückfrage — ein Kapitel an der falschen Stelle ist ärgerlich aufzuräumen.

## Abschnitt anlegen

```
abschnitt_anlegen(kurs, name, nach_abschnitt_id?, ordner?, einstellungen?)
```

- Ohne `nach_abschnitt_id` kommt der Abschnitt ans Ende, sonst direkt hinter
  den genannten.
- `ordner` mit `summary_editor.html` (und Bildern in `dateien/`) setzt die
  Beschreibung gleich mit.
- Der Abschnitt ist **verborgen**, bis `sichtbarkeit_setzen` ihn freigibt.
- Die Antwort nennt die neue id — die brauchst du für alles, was hineinkommt.

Die App erledigt dabei, was sonst die Falle ist: Wo das Kursformat ein
Kästchen „Standardname verwenden" hat, ignoriert Moodle den Namen, solange es
angehakt ist. Im Kachelformat gibt es das Kästchen gar nicht; die App setzt es
nur, wo es existiert.

## Beschreibung ändern

`abschnitt_lesen(abschnitt_id)` legt Name, Beschreibung
(`summary_editor.html`, Bilder in `dateien/`) und Einstellungen nach
`abschnitt-<id>/`. Bearbeiten, dann `aendern(ordner)`; der Name als
Einstellung `name`.

## Unterabschnitte (mod_subsection)

Ab Moodle 4.5 lässt sich ein Abschnitt gliedern. Ein Unterabschnitt ist
technisch eine **Aktivität**, die einen eigenen Abschnitt mitbringt:

| Ziel | Weg |
|---|---|
| anlegen | `aktivitaet_anlegen(kurs, abschnitt_id des Elternabschnitts, typ: "subsection", name)` |
| beschreiben | `abschnitt_lesen(id des Unterabschnitts)`, `summary_editor.html`, `aendern` |
| Inhalte hineinlegen | `aktivitaet_anlegen(…, abschnitt_id: id des Unterabschnitts, …)` |
| verbergen | `sichtbarkeit_setzen(kurs, abschnitt_id: id des Unterabschnitts, name, …)` — schaltet alles darin mit |
| verschieben | `verschieben(kurs, cmid: cmid des Kopfeintrags, name, ziel_abschnitt_id, vor_cmid?)` |
| duplizieren | `duplizieren(kurs, cmid: cmid des Kopfeintrags, name, ziel_abschnitt_id?, vor_cmid?)` — mit allem darin; nicht in einen anderen Unterabschnitt |
| löschen | `loeschen(kurs, cmid des Kopfeintrags, name)` — die App löscht den Abschnitt darunter mit |

Die cmid des Kopfeintrags und die id des Abschnitts zu verwechseln ist der
wahrscheinlichste Fehler an dieser Stelle. `kurs_uebersicht` zeigt beide
untereinander.

Beim Anlegen hat ein Unterabschnitt **keine Beschreibung** — die kommt im
zweiten Schritt über seinen Abschnitt.

## Eine Lernsituation komplett anlegen

Kommt sie als Entwurf aus dem Skill `lernsituation`, liegt alles bereit: `lernsituation.json` im Entwurfsordner nennt den Abschnitt und die Aktivitäten in ihrer Reihenfolge, mit Typ, Name und Einstellungen, und jeder Ordner darin hat den Inhalt schon als HTML in der Form, die die Werkzeuge nehmen. Nichts wird umgeschrieben oder neu erzeugt — du legst an, was dort steht. Die Reihenfolge vermeidet Nacharbeit:

1. `abschnitt_anlegen(kurs, name, nach_abschnitt_id, ordner)` mit dem Namen aus `abschnitt.name` und dem Ordner aus `abschnitt.ordner` (darin `summary_editor.html`, die Kurzfassung der Handlungssituation), an der Stelle, die der Plan nennt.
2. Die Einträge von `aktivitaeten` **in ihrer Reihenfolge** — neue Aktivitäten kommen ans Ende, so entsteht die Reihenfolge der Brücke ohne Verschieben: die Seite „SchuCu", die Lehrerhandreichung, die Handlungssituation, die Blätter, jede Lösung direkt hinter ihrem Blatt. Je Eintrag `aktivitaet_anlegen(kurs, abschnitt_id, typ, name, ordner: "<Entwurf>/<ordner>", einstellungen)`, alles verborgen. Interaktive Elemente in `dateien/` kommen dabei mit wie die Zeichnungen; den Kopf setzt die App ein. Steht eins auf einem Blatt, nimm nach dem Anlegen ein `bildschirmfoto` davon auf (`references/elemente.md`, „Prüfen und übergeben"). Zwei Sonderfälle:
   - **Buch** (`typ: "book"`): `aktivitaet_anlegen` ohne `ordner`, mit den Einstellungen des Eintrags; dann je Eintrag aus `kapitel.json`, in dieser Reihenfolge, `buchkapitel_anlegen(cmid, titel, unterkapitel, ordner: "<Entwurf>/<ordner>/kapitel-<id>")`.
   - **Unterabschnitt** (`typ: "subsection"`, ohne Ordner): anlegen, seine Abschnitts-id aus `kurs_uebersicht` holen und die folgenden Einträge dort anlegen, bis zum nächsten Unterabschnitt.
   - **Weitere Aktivitäten** (`board`, `kanban`, `checklist`, `wiki`, `quiz`, `folder`, `resource`, `url`): `aktivitaet_anlegen` mit dem Ordner — er bringt die Beschreibung aus `introeditor.html` und die Dateien aus `bereiche/files/` mit — und den Einstellungen des Eintrags; ein Link ohne `ordner` ohne. Dann füllen, wie die Datei im Ordner es sagt (Aufbau: Skill `lernsituation`, `references/vorlagen.md`). Was die App gerade verborgen angelegt hat, füllt sie bei „mittel" ohne Rückfrage; bei „alle" kommt je Aufruf eine.
     - **Board** (`board.json`): Ein neues Board ohne Vorlage hat drei Spalten namens „Überschrift" (gemessen 09.10.2026). `board_lesen`, dann **ein** `board_aendern`: die vorhandenen Spalten der Reihe nach umbenennen, überzählige löschen, fehlende mit `spalte_neu` anlegen, die Notizen mit `notiz_neu` dazu.
     - **Kanban-Board** (`kanban.json`): Ein neues hat die Spalten „Zu erledigen", „In Arbeit", „Erledigt". `kanban_lesen`, dann **ein** `kanban_aendern`: Spalten angleichen wie beim Board, die Karten mit `karte_neu`.
     - **Fortschrittsliste** (`eintraege.json`): **ein** `fortschrittsliste_aendern` mit je Eintrag `neu {text, tiefe, zustand}`, in der Reihenfolge der Datei.
     - **Wiki** (`seiten.json`): Die Einstellungen des Eintrags tragen `firstpagetitle`; dann je Seite, in der Reihenfolge der Datei, `wikiseite_schreiben(cmid, titel, datei)` — die erste ist die Startseite.
     - **Test** (`fragen.xml`): nach dem Skill `moodle-fragen`. Die Fragensammlung aus `fragen.sammlung` mit `fragensammlungen` suchen, sonst anlegen (`aktivitaet_anlegen`, Typ `qbank`); darin die Kategorie aus `fragen.kategorie` anlegen, falls es sie nicht gibt; `fragen_importieren` (die Nachweise für STACK und CodeRunner laufen dabei); dann **ein** `test_aendern`: die Fragen in der Reihenfolge der Datei einfügen, Punkte, `beste_bewertung: "summe"`, Mischen nach Plan.
     - **Verzeichnis, Datei, Link**: nichts weiter.

   Ohne Entwurf gilt dieselbe Reihenfolge, und die Ordner entstehen beim Anlegen; bei Bedarf kommen `_Lehrerdateien` für Quelldateien (verborgen) und ein Verzeichnis (`folder`) mit Material für die Lernenden dazu.
3. **die Links setzen** — erst jetzt hat jede Aktivität ihre Nummer:
   `links_setzen(kurs, abschnitt_id)`. Die App liest den Abschnitt frisch und
   macht jede Nennung eines Blatts zum Link, mit der Kennung als Text, so wie
   sie im Satz steht (in „Lies"-, „Dazu"- und „Gehört zu"-Zeilen, „→ für",
   „Abb. 1 auf Arbeitsblatt 1", der Spalte Material im Ablaufplan); in der
   Materialübersicht der Handreichung mit dem ganzen Namen; eine weitere
   Aktivität, wo ihr ganzer Name in Anführungszeichen steht. Sie lässt aus,
   was nicht verlinkt wird: die Seite „SchuCu", ein Textfeld als Ziel (es hat
   keine eigene Seite, die Handlungssituation steht ohnehin oben im
   Abschnitt) und eine Lösung auf einer Seite, die Lernende schon sehen. Sie
   prüft, dass sich am sichtbaren Text nichts ändert, und schreibt mit
   **einer** Freigabe, in der die Lehrkraft jede Seite mit ihren neuen Links
   sieht — kündige sie im Chat an. Sind alle Seiten gerade verborgen angelegt,
   kommt sie erst bei „alle"; bei „mittel" setzt die App die Links ohne. Du öffnest dafür keine Seite und setzt
   keinen Link von Hand. Was die Antwort unter „Nicht verlinkt" nennt, ist
   eine Nennung ohne passende Aktivität (eine Kennung, die es nicht gibt, oder
   zwei Aktivitäten mit derselben): Das behebst du am Text oder Namen und
   rufst `links_setzen` noch einmal auf.
4. `kurs_uebersicht` — stimmt die Reihenfolge, warnt die App vor etwas
   Erreichbarem, das nach Lösung klingt? Kommt die Lernsituation aus dem Skill
   `lernsituation`, prüft dessen Skript danach den ganzen Stand in Moodle,
   Links eingeschlossen (dort Schritt 5).
5. Ergebnis zurückmelden: Abschnittsname, was angelegt wurde, was davon
   verborgen ist, und die Adresse des Abschnitts
   (`/course/view.php?id=<kurs>&section=<nummer>`).

Alles entsteht verborgen. Was für Lernende sichtbar werden soll, steht im Plan
und wird am Ende mit `sichtbarkeit_setzen` freigegeben — eine Freigabe je
Objekt; ein sichtbarer Abschnitt mit verborgenen Lösungen darin ist dabei der
Normalfall.

## Umsortieren, verbergen, löschen

| Ziel | Abschnitt | Aktivität |
|---|---|---|
| Umbenennen | `abschnitt_lesen` + `aendern` (Einstellung `name`) | `aktivitaet_lesen` + `aendern` |
| Sichtbarkeit | `sichtbarkeit_setzen(kurs, abschnitt_id, name, sichtbar)` | `sichtbarkeit_setzen(kurs, cmid, name, sichtbar)` |
| Position | `verschieben(kurs, abschnitt_id, name, nach_abschnitt_id)` | `verschieben(kurs, cmid, name, ziel_abschnitt_id, vor_cmid?)` |
| Duplizieren | `duplizieren(kurs, abschnitt_id, name)` — direkt dahinter | `duplizieren(kurs, cmid, name, ziel_abschnitt_id?, vor_cmid?)` — unter das Original oder an die Zielstelle |
| Löschen | `loeschen(kurs, abschnitt_id, name)` | `loeschen(kurs, cmid, name)` |

Alles davon außer Duplizieren läuft über das Freigabefenster; Duplizieren legt verborgen an wie `aktivitaet_anlegen`. Geprüft wird hinterher an der Kursstruktur. `vor_cmid` heißt: direkt **vor** diese Aktivität; ohne
kommt sie ans Ende des Zielabschnitts.

Ein Nebeneffekt beim Umsortieren, der überrascht: Abschnitte mit
**Standardnamen** heißen nach der Position. Verschiebt man etwas, wird aus
„Kachel 4" plötzlich „Kachel 5" — nicht weil etwas kaputt wäre, sondern weil
der Name nie vergeben, sondern immer aus der Nummer erzeugt wurde. Benannte
Abschnitte behalten ihren Titel. Deshalb für `name` immer frisch aus
`kurs_uebersicht` lesen.

**Löschen ist endgültig.** Ein Abschnitt geht mit allem darin, ein Verzeichnis
mit seinen Dateien — auch ohne Papierkorb. Sag vorher konkret, was
verschwindet: Name und Inhalt. Die Freigabe der App listet es ebenfalls auf.

Am wenigsten Ärger macht weiterhin: **Inhalte gleich in der richtigen
Reihenfolge anlegen.**

## Abschnitt verlinken

- Kursseite mit Sprungmarke: `/course/view.php?id=<kurs>&section=<nummer>`
- Eigene Abschnittsseite (Moodle 4.4+): `/course/section.php?id=<id>`

Für Rückmeldungen an den Nutzer ist die erste Form die verlässlichere.
