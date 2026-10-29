/* Gemeinsamer Block aller Skills: Bestehendes überarbeiten -- direkt oder an
 * einer Kopie, und was dann dupliziert und was neu angelegt wird.
 * build.py setzt ihn hinter den Plan. Nicht in SKILL.md bearbeiten.
 */

## Bestehendes überarbeiten: direkt oder an einer Kopie

Soll etwas Bestehendes überarbeitet werden — ein Arbeitsblatt, eine Aktivität, ein Abschnitt oder eine ganze Lernsituation, ein Test —, steht **ganz vorn im Plan die Frage: direkt oder an einer Kopie?** Direkt heißt: Das Original wird geändert, der alte Stand ist danach weg. An einer Kopie heißt: Das Original bleibt unberührt stehen, bis das Neue fertig ist, und die Lehrkraft entscheidet danach, was mit ihm geschieht.

Die Frage kommt mit Empfehlung und Grund. **Kopie** bei größeren Umgestaltungen — neue Gliederung, neue Aufteilung, mehrere Blätter, eine neue Handlungssituation — und bei einem Test, für den es schon Versuche gibt: Das Alte bleibt benutzbar, solange am Neuen gearbeitet wird, und beides lässt sich nebeneinander ansehen. **Direkt** bei kleinen, umgrenzten Änderungen, bei denen eine Kopie nur Aufräumarbeit hinterließe. Nicht gefragt wird nur, wenn der Nutzer es im Auftrag schon gesagt hat („mach eine Kopie", „ändere direkt") oder die Änderung vollständig vorgibt („ändere den Titel in ‚Reihenschaltung'").

### Kopie oder neu: je Objekt, mit einer Frage

Auch an einer Kopie wird nicht alles dupliziert. Für jedes Objekt des Neuen entscheidet eine Frage: **Hat es genau einen Vorgänger, dessen Text weitgehend stehen bleibt?** Absätze werden ergänzt, umformuliert, gekürzt oder umgestellt, aber es bleibt erkennbar dasselbe Blatt.

- **Ja → duplizieren** (`duplizieren`, auf Wunsch gleich in den Zielabschnitt). Es kommt alles mit, auch was nicht im Formular steht: Einstellungen, Bilder, Anhänge, Bewertung, Abschlussverfolgung, die Kapitel eines Buchs, die Einträge einer Fortschrittsliste, die Fragen eines Tests. Und jede Änderung an der Kopie zeigt die App in der Freigabe als Zeilenvergleich zum Original — die Lehrkraft sieht, was sich ändert und was wegfällt. Den Vorgänger stattdessen neu abzuschreiben ist bequemer, weil Neues ohne Freigabe entsteht; aber dann fehlt genau dieser Vergleich, und was beim Abschreiben verloren geht, bemerkt niemand.
- **Nein → neu anlegen.** Das Objekt entsteht aus mehreren Vorgängern, aus einem Teil eines Vorgängers oder mit anderem Typ (aus einer Textseite wird eine Aufgabe — den Typ kann Duplizieren nicht ändern). Hier hilft eine Kopie nicht: Der Zeilenvergleich wäre fast nur Streichung und Zusatz, und hinterher wäre mehr zu löschen als übernommen. Welche Einstellungen des Vorgängers weiterleben sollen (Frist, Punkte, Bewertung, Abschlussverfolgung), steht im Plan; sie gingen sonst still verloren.

Dieselbe Frage eine Ebene höher entscheidet über den Abschnitt. Überlebt der größte Teil seiner Aktivitäten als Kopie, wird der ganze Abschnitt dupliziert und in der Kopie gearbeitet; was nicht mehr gebraucht wird, fliegt dort heraus. Sonst entsteht ein neuer Abschnitt, in den die Kopien einzeln hineindupliziert werden, daneben das neu Angelegte — dann muss nichts gelöscht werden.

Im Plan steht die Entscheidung bei jedem Objekt, damit die Lehrkraft sie vor dem Ja sieht und korrigieren kann: „Arbeitsblatt 1: Leitungsauswahl — Kopie von ‚Arbeitsblatt Kabel', Aufgaben 3 und 4 neu" — „Arbeitsblatt 2: Verlegearten — neu, aus Teilen von ‚Arbeitsblatt Kabel' und ‚IB Verlegung'".

Das Original ist in dieser Arbeit **Vorlage**: Es wird gelesen, aber nicht geändert, nicht verborgen, nicht gelöscht. Was am Ende mit ihm geschieht, entscheidet die Lehrkraft. Schlag es vor („das Original verbergen und die Kopie sichtbar machen?"), aber tu es erst auf ihr ausdrückliches Wort.

### Das Neue steht allein

Das Original wird sehr wahrscheinlich früher oder später gelöscht. Das Neue enthält deshalb **nichts, das auf das Original verweist** — es muss auch dann noch stimmen, wenn das Alte weg ist:

- **Keine Quellenangabe auf das alte Material** („nach Arbeitsblatt 3 der alten Lernsituation", „Quelle: eigener Kurs"). Es ist ein Werk der Lehrkraft, und eigene Werke brauchen keine Angabe.
- **Keine Änderungsvermerke** — „überarbeitet", „neu:", „geändert gegenüber …", „ersetzt Aufgabe 4", „wie bisher". Für die Lernenden gibt es kein Vorher, und für die Lehrkraft veraltet der Vermerk mit dem Löschen des Originals.
- **Keine Links auf das Original.** Ein Verweis im Neuen zeigt auf das Gegenstück im Neuen. Moodle stellt das beim Duplizieren nicht um, auch nicht innerhalb eines ganzen duplizierten Abschnitts (gemessen): Verlinkt Seite A die Seite B, zeigt die Kopie von A weiter auf das Original von B. Nach dem Duplizieren eines Abschnitts stellt `links_setzen(kurs, abschnitt_id)` an der Kopie jeden Link um, dessen Text Kennung oder Name einer Aktivität der Kopie ist („Infoblatt 1"), mit einer Freigabe für alle Seiten. Übrig bleiben Links mit anderem Text: `duplizieren` nennt die Paare Original → Kopie, und `aktivitaet_lesen` zeigt unter „Verweise" das Ziel jedes Links mit cmid; jeden, der noch auf eine cmid des Originals zeigt, stellst du auf ihr Gegenstück um. Das gehört in die Änderung, die an der Seite ohnehin ansteht; die übrigen Seiten gehen zusammen mit `aendern_mehrere` durch eine Freigabe. Im Plan steht, wie viele Seiten das betrifft.

Fremde Inhalte, die aus dem Original übernommen werden — ein Bild von Commons, ein Zitat aus der Wikipedia —, behalten ihre **ursprüngliche** Quellenangabe; die gilt weiter. Nur der Umweg über das alte Material fällt weg.

Was sich gegenüber dem Original geändert hat, gehört in die Meldung am Ende, in den Chat: Dort braucht die Lehrkraft es, um das Neue zu prüfen. Im Material selbst hat es keinen Leser.

Entsteht das Neue zuerst als Entwurf (Skill `lernsituation`), gilt „Das Neue steht allein" schon für den Entwurf, und die Frage direkt oder Kopie beantwortet der Plan für den Schritt nach Moodle.
