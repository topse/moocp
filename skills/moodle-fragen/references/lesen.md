# Lesen: Fragen und Testaufbau

## Der Grundsatz: über XML lesen, nicht über die Tabelle

Die Fragenübersicht in Moodle ist eine Tabelle mit rund vierzehn Spalten. Zwei
davon — **„Erstellt von"** und **„Geändert von"** — enthalten Vor- und
Nachnamen. Wer die Tabelle ausliest, hat die Personendaten schon in der Hand.

Der **Moodle-XML-Export** hat dieses Problem nicht. Er enthält
konstruktionsbedingt keine Personendaten — geprüft auf der Zielinstanz: kein
`createdby`, kein `modifiedby`, kein Name, keine Nutzerkennung. Die App liest
Fragen deshalb ausschließlich über den Export. Er ist zugleich der
**vollständigere** Weg: Fragetext, alle Antworten, Bewertungsanteile,
Feedback, Toleranzen und Einheiten.

## Übersicht einer Kategorie

`fragen_lesen(sammlung)` listet zuerst die Kategorien (id, Name, Anzahl) und
exportiert dann eine davon — ohne Angabe die erste, mit `kategorie` (id oder
Name) eine bestimmte, mit `alle: true` jede nicht leere — nach
`fragen-<sammlung>/kategorie-<id>.xml`. Zurück kommt je Frage:

| Angabe | Bedeutung |
|---|---|
| questionid | die Nummer der **aktuellen Version** — zum Einfügen in einen Test |
| Sachnummer (`idnumber`) | sofern vergeben — die **stabile** Kennung |
| Typ | interner Typ, normalisiert (siehe unten) |
| Name | Fragename |
| Punkte | Vorgabe der Frage |
| Antworten | Anzahl, davon richtig |
| Text | Anfang des Fragetexts, ohne HTML |

Für den Nutzer daraus eine Liste bauen, keinen Dump. Typen auf Deutsch nennen:
„Multiple Choice", „Wahr/Falsch", „Kurzantwort", „Numerisch", „Zuordnung",
„Freitext", „Beschreibung", „Lückentext (Cloze)", „Lückentextauswahl",
„Drag&drop auf Text".

### questionid und Sachnummer

Die beiden verwechselt man leicht, und es ist teuer: Die questionid gehört zur
**Version** und ist nach jeder Änderung eine andere. Die Sachnummer gehört zum
Eintrag und bleibt. Merk dir über eine Sitzung hinaus die Sachnummer und hol
dir die questionid bei Bedarf frisch:

```
fragen_lesen(sammlung, idnummer: "et-reihenschaltung-01")
```

Das durchsucht jede nicht leere Kategorie. Passen mehrere Fragen, meldet die
App das mit der Liste und **rät nicht**.

### Zwei Typnamen, die im Export anders heißen

| Intern | Im Export |
|---|---|
| `match` | `matching` |
| `multianswer` | `cloze` |

Die App normalisiert beim Lesen. Der Import akzeptiert beide Schreibweisen;
im erzeugten XML trotzdem die Exportform verwenden — dann ist ein
Export-Import-Kreis wirklich rund.

## Eine einzelne Frage

`frage_lesen(sammlung, frage)` legt die Frage vollständig nach `frage-<id>/`:
jedes Textfeld als `<feld>.html` (Fragetext, allgemeines Feedback, Antworten,
Rückmeldungen), eingebundene Dateien in `dateien/`, alle Einstellungen in
`einstellungen.json` und das XML als `frage.xml`. Das ist zugleich der
Ausgangspunkt fürs Ändern (`aendern`).

**Gib das XML nicht ungefiltert aus.** Es kann eingebettete Bilder als
Base64-Daten enthalten. Für die Anzeige die Übersicht der App benutzen oder
gezielt einzelne Felder herausgreifen.

## Testaufbau

`test_lesen(cmid)` — Aufbau und Bedeutung in `references/tests.md`. Kurz:
Plätze mit Seite, slotid, Typ, Name, Punkten und questionid, Summe, Beste
Bewertung, ob gemischt wird, und Befunde.

## Was nie gelesen wird

Der Testinhalt ist offen zugänglich, die Ergebnisse sind es nicht: Berichte,
Versuche, Kommentare, Abweichungen für einzelne Personen, Notenbuch,
Fragenkommentare, STACK „Antworten analysieren". Die App fragt diese Seiten
gar nicht erst an.

Die Zahl der Versuche ist eine Aggregatgröße und darf als Warnung dienen („zu
diesem Test gibt es bereits Versuche"). Alles, was einer einzelnen Person
zuzuordnen ist, bleibt außen vor.

Fragt der Nutzer nach Ergebnissen, Notenspiegeln oder wer abgegeben hat: klar
sagen, dass die App das bewusst nicht kann, und darauf verweisen, dass er die
Auswertung in Moodle selbst aufruft.
