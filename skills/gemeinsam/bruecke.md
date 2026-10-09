/* Gemeinsamer Block der Skills moodle und lernsituation: die Brücke zwischen
 * den Begriffen der Didaktik (Lernsituation, Phase, Arbeitsblatt) und den
 * Objekten in Moodle (Abschnitt, Unterabschnitt, Aufgabe). Sie gilt in beide
 * Richtungen: beim Anlegen von links nach rechts, beim Lesen und Beurteilen
 * von rechts nach links. Hier steht nur, was beide Skills brauchen; wie der
 * Entwurf aussieht und was in die Blätter gehört, steht im Skill
 * lernsituation, wie er angelegt wird, im Skill moodle (abschnitte.md).
 */
## Die Brücke: Eine Lernsituation ist ein Kursabschnitt

Der Skill `lernsituation` entwirft, der Skill `moodle` bringt den Entwurf in den Kurs und arbeitet dort. Damit beide dasselbe meinen, gilt ein Grundsatz: **Eine Lernsituation entspricht genau einem Kursabschnitt** — bei Bedarf mit Unterabschnitten. Kein Objekt der einen Seite ohne Entsprechung auf der anderen:

| Lernsituation (Didaktik, Entwurf) | Moodle (Kurs) | Sichtbar für Lernende |
|---|---|---|
| **Lernsituation** | **Abschnitt** (section), Titel = Titel | ja |
| Phase der vollständigen Handlung | Unterabschnitt (subsection) — **nur bei Bedarf**, wenn der Abschnitt sonst unübersichtlich wird; sonst die Reihenfolge im Abschnitt | ja |
| SchuCu-Tabelle (HTML nach CD-Vorlage) | Textseite „SchuCu", **erste Aktivität des Abschnitts**, nur die Tabelle | **verborgen** |
| Lehrerhandreichung mit Ablaufplan, Checkliste | „Lehrerhandreichung" **direkt dahinter**, ein Dokument: Textseite, bei langen ein Buch | **verborgen** |
| Handlungssituation | Textfeld (label) danach, für Lernende das erste; länger als ein Absatz: Textseite | ja |
| Kurzfassung der Handlungssituation (SchuCu) | Beschreibung des Abschnitts | ja |
| Ablaufplan (Reihenfolge der Schritte) | Reihenfolge der Aktivitäten im Abschnitt | ja |
| Arbeitsblatt, Titel „Arbeitsblatt n: …" | Aufgabe (assign), wenn etwas abgegeben wird — Aufgabentext = Blatt; sonst Textseite | ja |
| Lösung, Titel „Lösung zu Arbeitsblatt n: …" | Textseite **direkt hinter ihrem Blatt** | **verborgen — nie stealth** |
| Zusatzblatt, Titel „Hilfe zu Arbeitsblatt n: …" / „Vertiefung zu Arbeitsblatt n: …" | Textseite oder Aufgabe, ggf. mit Zugriffsvoraussetzung | ja |
| Infoblatt, Titel „Infoblatt n: …" | Textseite | ja |
| Zeichnung (SVG) | Bild im Entwurfsbereich der Seite, die es einbindet | mit der Seite |
| Handlungsprodukt | Abgabe der Aufgabe (assign) | ja |
| Leistungsfeststellung mit Test | Test (quiz) — Skill `moodle-fragen` | ja |
| Weitere Lernträger: Sammeln und Vergleichen, Planen in Arbeitspaketen, gemeinsames Produkt, Prüfliste oder Laufzettel, Üben, Material zum Weiterarbeiten | Board, Kanban-Board, Wiki, Fortschrittsliste, Test, Verzeichnis, Datei, Link — Name ohne Kennung, er sagt, wozu die Aktivität da ist | ja |
| Quellen und fremde Inhalte | Abschnitt am Ende der Lehrerhandreichung | verborgen |

**Von links nach rechts** (anlegen), in dieser Reihenfolge: die Seite „SchuCu", die Lehrerhandreichung, die Handlungssituation, dann die Aktivitäten des Ablaufplans, jede Lösung direkt hinter ihrem Blatt. SchuCu, Handreichung und Lösungen sind verborgen. Was für die Lehrkraft allein ist, steht vorn, damit sie es sofort sieht — die SchuCu-Seite zudem, damit sie bei einer Inspektion ohne Suchen zu finden ist; die Lösung steht beim Blatt, weil die Lehrkraft sie dort bei Bedarf für die Lernenden freigibt. Weil neue Aktivitäten ans Ende des Abschnitts kommen, entsteht die Reihenfolge beim Anlegen von selbst — ohne Verschieben und ohne Freigabe. Ob etwas davon später sichtbar wird, entscheidet die Lehrkraft in Moodle. Nummeriert der Kurs seine Aktivitäten, bekommen SchuCu, Handreichung und Lösungen keine Nummer; sie stehen außerhalb der Zählung, eine Lösung nennt im Namen ihr Blatt. Darüber hinaus führst du keine eigene Nummerierung ein. Vor der Übergabe `kurs_uebersicht` — es warnt, wenn etwas erreichbar ist, das nach Lösung klingt; die Lösungen sind der klassische Unfall, und „verfügbar ohne Link" (stealth) schützt sie nicht.

**Maßgeblich ist, was in Moodle steht.** Der Entwurf ist nur der Weg dorthin: Er entsteht im Arbeitsordner der App, wird geprüft und gleich danach in den Kurs gebracht; danach braucht ihn niemand mehr, und die App leert den Arbeitsordner beim Beenden. Von da an gibt es die Lernsituation nur in Moodle. Die Lehrkraft sieht sie dort an und ändert dort, auch von Hand. Jede spätere Änderung beginnt deshalb mit frischem Lesen aus Moodle und ändert den gelesenen Quelltext. Nie wird eine Seite aus dem Entwurf, einer älteren Datei oder dem Gedächtnis neu erzeugt: Ein alter Stand überschriebe, was die Lehrkraft inzwischen geändert hat, und im Zeilenvergleich der Freigabe geht das leicht unter.

**Der Name jeder Aktivität ist der Titel ihres Blatts**, samt Kennung: „Arbeitsblatt 2: Umsetzung und Prüfung", „Infoblatt 1: VLAN-Grundlagen", „Hilfe zu Arbeitsblatt 1: Die Aufteilung planen". Mit genau dieser Kennung verweisen die Blätter aufeinander („Infoblatt 1, Abschnitt 2", „Abb. 1 auf Arbeitsblatt 1") — so findet man in der Kursübersicht jedes Blatt, das ein anderes nennt. Wer ein Blatt in Moodle umbenennt oder teilt, zieht die Verweise auf den anderen Seiten nach.

**Weitere Aktivitäten tragen keine Kennung** — online zeigt das Icon, was sie sind. Ihr Name sagt, wozu sie da sind („Unsere VLAN-Aufteilung", „Prüfliste zum VLAN-Konzept"), und Blätter, Ablaufplan und Handreichung nennen sie mit diesem vollen Namen in Anführungszeichen: „Heftet eure Entscheidung an die Pinnwand „Unsere VLAN-Aufteilung"." Gedruckt findet man sie so auf der Kursseite wieder; in Moodle wird die Nennung in Anführungszeichen ein Link, wie die Kennung eines Blatts. Auch sie stehen im Ablaufplan, sonst benutzt sie im Unterricht niemand.

**In Moodle ist jeder Verweis auf ein anderes Blatt ein Link auf dessen Aktivität** — in den Blättern wie in der Handreichung. Linktext ist die Kennung, so wie sie im Satz steht (in „Lies: Infoblatt 1, Abschnitt 4" ist „Infoblatt 1" verlinkt); nur die Materialübersicht der Handreichung verlinkt mit dem ganzen Namen, weil dort die Namen der Inhalt sind. Online führt der Link mit einem Klick hin, gedruckt trägt der Text allein, weil jedes Blatt mit seiner Kennung beginnt. Eine für Lernende sichtbare Seite verlinkt keine Lösung. Im Entwurf stehen die Verweise als Text; nach dem Anlegen setzt die App die Links mit `links_setzen`, wenn jede Aktivität ihre Nummer hat.

**Die SchuCu-Tabelle bleibt Zeichen für Zeichen, wie die Vorlage sie vorgibt.** Sie steht allein auf der Seite „SchuCu" (`<table class="lernsituation">`) und ist fein abgestimmt — `style`-Angaben, `&nbsp;` in den Abstandszellen, eigene Klassen. Beim Anlegen und bei jeder späteren Änderung der Seite bleibt sie, wie sie ist, samt den Absätzen darunter: keine Klasse tauschen, kein `style` entfernen, nicht in `table table-bordered` umbauen. Was in ihre Zellen gehört, regelt der Skill `lernsituation`.

**Von rechts nach links** (lesen, beurteilen): Ein Textfeld oben ist ein Kandidat für die Handlungssituation, eine Textseite für ein Informationsblatt, eine Aufgabe für ein Arbeitsblatt, ein Unterabschnitt für eine Phase, ein Test für die Leistungsfeststellung. Ein Board, ein Kanban-Board, ein Wiki, eine Fortschrittsliste oder ein Test, die der Ablaufplan nennt, sind weitere Lernträger. Was keine Entsprechung hat — ein Forum, ein Video ohne Auftrag, ein Verzeichnis voller PDFs, eine Aktivität, die kein Schritt benutzt — steht im Bericht als „ohne Rolle" und ist oft der Hinweis, dass es eine Materialsammlung ist.

Wer im Chat „Lernsituation" sagt, meint also beides zugleich: die Didaktik und den Abschnitt. Der Skill `lernsituation` entwirft sie, der Skill `moodle` legt sie an, und ein Auftrag, der beides berührt, läuft über beide.
