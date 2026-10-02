/* Gemeinsamer Block: Umgang mit fremden Inhalten, ausführlich. build.py
 * setzt ihn in references/urheberrecht.md aller Skills; die Kurzfassung
 * (urheberrecht-kurz.md) steht im SKILL.md -- wie beim HTML.
 *
 * Gegenstück zu erfundene-namen.md. Dort geht es um erfundene Betriebe, hier
 * um fremdes Material -- Bilder, Texte, Datenblätter. Beide Regeln betreffen
 * nur das, was NEU in einen Kurs geschrieben wird.
 */
# Fremde Inhalte: nur aus erlaubten Quellen, immer mit Quellenangabe

Was in einen Kurs oder auf ein Blatt geschrieben wird, wird damit an eine
Lerngruppe verbreitet — und die Schule steht dahinter. Für fremdes Material gilt deshalb dieselbe
Grundhaltung wie für erfundene Namen: im Zweifel nicht.

**§ 60a UrhG** erlaubt für den Unterricht kleine Teile eines Werkes (bis zu
15 %) für die Teilnehmer eines Kurses. Das deckt ein Zitat aus einem Fachbuch —
nicht ein eingescanntes Kapitel, nicht eine Bildersammlung, nicht ein
öffentlich sichtbarer Kurs. Verlass dich nicht darauf, sondern nimm Material,
das ohnehin frei verwendbar ist.

## Erlaubte Herkünfte

| Herkunft | Bedingung |
|---|---|
| Eigene Werke des Nutzers | keine |
| Gemeinfrei / Public Domain | Schutzfrist abgelaufen oder ausdrücklich freigegeben |
| Wikimedia Commons | Lizenz der Dateiseite entnehmen und angeben |
| Wikipedia (Text und Bild) | CC BY-SA, Angabe erforderlich |
| Offen lizenzierte Datenblätter und Grafiken | CC0, CC BY, CC BY-SA |
| Von dir selbst erzeugte Inhalte | keine |

Steht eine gewünschte Quelle nicht in der Tabelle, **frag einmal nach** und
richte dich dann nach der Entscheidung des Nutzers. Frag nicht bei jedem Bild
erneut.

**`-NC`-Lizenzen** (nicht kommerziell) sind an staatlichen Schulen umstritten.
Nicht ungefragt verwenden.

## Die Quellenangabe gehört dazu — in der Form, die die Quelle vorgibt

Bei CC BY und CC BY-SA ist die Angabe **Lizenzbedingung**, nicht Höflichkeit.
Ohne sie ist die Nutzung unerlaubt. Vier Angaben gehören hinein: Titel,
Urheber, Lizenz mit Link, und ob geändert wurde.

**Aber du erfindest die Form nicht.** Die meisten Quellen schreiben vor, wie
ihre Angabe auszusehen hat, und liefern sie fertig mit. Diese Fassung
übernimmst du — nicht deine eigene Zusammenfassung davon, nicht übersetzt,
nicht gekürzt. Nur wo eine Quelle keine Vorgabe macht, greift die
Vier-Angaben-Form unten.

| Herkunft | Wo die Vorgabe steht | Was daraus unverändert bleibt |
|---|---|---|
| Wikimedia Commons | Dateiseite → „Diese Datei verwenden" → „Namensnennung" (HTML) | Urheber mit Verweis, „Eigenes Werk"/„Own work", Lizenzname, Fundstelle mit `curid` |
| Wikipedia-Bild | dieselbe Dateiseite auf Commons | wie oben |
| Wikipedia-Text | Artikelname, Abrufdatum, CC BY-SA 4.0 mit Lizenzlink | Artikelname wörtlich, Lizenz genau so |
| CC-lizenzierte Grafik oder Datenblatt | Angabe des Anbieters, sonst Titel · Urheber · Quelle · Lizenz | Lizenzkürzel samt Version |
| Gemeinfrei | „gemeinfrei" mit Fundstelle | die Fundstelle |
| Eigenes Werk des Nutzers | keine Angabe | — |

Was eine Quelle liefert, wird übernommen — bis auf genau **drei** Dinge, und
alle drei haben denselben Grund: **Der Inhalt muss auch als Ausdruck
bestehen** (Notfallbetrieb ohne Netz, Blätter auf Papier):

1. **Aus „Link" wird die Adresse selbst.** Ein Verweis, dessen Text nur „Link"
   lautet, ist auf Papier nichts. Die Fundstelle und der Lizenzlink stehen
   deshalb **ausgeschrieben** als Linktext. Der Urheberlink darf seinen Namen
   als Text behalten — der Name ist die Information, die Adresse dahinter nur
   Zugabe.
2. **`//commons.wikimedia.org/…` wird `https://commons.wikimedia.org/…`.**
   Protokollrelative Adressen sind auf Papier unvollständig und in manchen
   Umgebungen tot.
3. **Das Bild liegt bei dir, nicht auf dem fremden Server** — als Datei in
   Moodle, im Entwurf einer Lernsituation vorher in `dateien/` des Blatts. Der Skill holt nichts aus dem Netz; der Nutzer lädt die
   Datei herunter und nennt sie dir. Der Verweis auf die Dateiseite um das
   Bild herum bleibt — er ist Teil der Angabe.

Was du **nicht** anfasst: Reihenfolge, Urhebername, „Own work", den
Lizenznamen und die Sprache der Angabe. Commons liefert sie in der Sprache der
Oberfläche; ist sie englisch, bleibt sie englisch. Eine Bildbeschreibung
(`alt`) setzt du nach unserer Regel — sie beschreibt das Bild, nicht den
Dateinamen — das gehört zur Barrierefreiheit, nicht zur Quellenangabe.

@@QUELLENBEISPIELE@@

Bei gemeinfreiem Material genügt „gemeinfrei" mit ausgeschriebener Fundstelle.
Bei eigenen Werken des Nutzers ist keine Angabe nötig.

**CC BY-SA weitergeben:** Ein *bearbeitetes* Bild muss unter derselben Lizenz
stehen. Ein unverändert eingebundenes Bild löst das nicht aus — Kurs oder Blatt
werden davon nicht lizenzpflichtig.

## Was nicht hineingehört

- Scans und Abbildungen aus Schulbüchern, Verlagsmaterial, Prüfungssammlungen
- Bilder aus einer Bildersuche, ohne dass die Lizenz auf der Ursprungsseite
  geprüft wurde — Suchtreffer sagen nichts über die Rechtelage
- Pressefotos, Werbematerial, Herstellerlogos in schmückender Verwendung
- Liedtexte und Gedichte, auch auszugsweise
- Ganze fremde Aufgabensätze, Lösungen oder Klausuren

**Fremden Fließtext schreibst du nicht ab, sondern in eigenen Worten neu.** Ein
kurzes Zitat mit Fundstelle ist in Ordnung; eine übernommene Seite ist es
nicht, auch nicht leicht umgestellt.

## Dateien, die der Nutzer übergibt

Der Skill holt **keine Bilder aus dem Netz**. Jedes Bild kommt aus einer
lokalen Datei, die der Nutzer nennt — er kennt die Herkunft, du nicht.

Ist die Herkunft aus Dateiname und Zusammenhang nicht erkennbar, frag **einmal**
danach und verwende sie danach. Nenne dabei, was du in die Quellenzeile
schreiben würdest. Nicht verwenden und die Frage nachschieben.

## Bestehende Inhalte

Diese Regel gilt für **neu erzeugte** Inhalte. Vorhandenes Kursmaterial nicht
ungefragt entfernen oder umschreiben — fällt dir dort etwas Bedenkliches auf,
sag es dem Nutzer und überlass ihm die Entscheidung.

Das hier ist eine Arbeitsregel, keine Rechtsberatung. Bei einer wirklich
strittigen Frage gehört die Entscheidung zum Nutzer, nicht zu dir.
