# Sichern, Wiederherstellen und Übertragen

Mit diesen Werkzeugen sicherst du Teile eines Kurses oder den ganzen Kurs als Sicherungsdatei (`.mbz`) und spielst sie wieder ein: in denselben Kurs, in einen anderen Kurs derselben Instanz, in einen neuen Kurs oder auf einer anderen Instanz. So lässt sich ein Thema oder eine Lernsituation an mehrere Klassenkurse verteilen, ein Abschnitt als Vorlage an Kolleginnen und Kollegen weitergeben oder ein Kurs als Grundlage für das nächste Schuljahr festhalten; ein anderer Einsatz mit Grund ist willkommen. Eine Sicherung enthält nie Daten von Lernenden. Was Lernende füllen, etwa Glossareinträge oder Forenbeiträge, fehlt in der Datei, und die Freigabe zeigt das.

| Wofür | Werkzeug |
|---|---|
| eine Aktivität sichern | `sichern_aktivitaet` |
| Aktivitäten, Abschnitte oder den ganzen Kurs sichern | `sichern_auswahl` |
| eine Sicherungsdatei zurückspielen | `wiederherstellen_datei` |
| eine Auswahl in mehrere Kurse derselben Instanz bringen | `uebertragen` |
| den Stand eines laufenden Vorgangs abfragen | `sicherung_status`, `wiederherstellung_status` |

## Der Plan kommt zuerst

Vor jedem Wiederherstellen und jeder Übertragung steht ein Plan im Chat (Abschnitt „Erst der Plan, dann das Schreiben“ im SKILL.md), und die Lehrkraft sagt Ja. Er nennt die Quelle mit Instanz, Kursname und Nummer, die Inhaltsauswahl oder die Datei, jeden Zielkurs mit Name, Nummer und Instanz, den Weg und die Sichtbarkeit der neuen Inhalte (unten). Fehlt ein Kursname, ist der Plan nicht vollständig: Dann frag nach, statt eine Lücke zu zeigen. Die Planung machst du mit der Lehrkraft im Chat; die App führt keine, sie führt nur das Protokoll `uebertragungen.json` im Einstellungsordner, in dem jeder Vorgang mit Stand und Zeit steht.

Jeder Schreibschritt, also das Sichern und je Ziel das Wiederherstellen, fragt danach in der App um Freigabe. Die Freigabe zeigt Kurs, Datei, Weg und was neu entsteht; wie oft sie kommt, legt die Lehrkraft mit der Freigabestufe fest (`status` nennt sie). Sag ihr vorher, dass eine Freigabe kommt.

## Sichern

Eine Sicherung (`sichern_aktivitaet`) umfasst eine einzelne Aktivität, ohne Daten von Lernenden, und liegt als Datei im Sicherungsordner der App, nicht im Arbeitsordner. Sie ändert im Kurs nichts. Die Lehrkraft gibt sie vorher frei; nenne ihr Name und Nummer genau wie in `aktivitaet_lesen`.

Mehrere Teile in einer Datei sichert `sichern_auswahl`: ausgewählte Aktivitäten, ganze Abschnitte oder den ganzen Kurs, auch nur mit den genannten Teilen, ebenfalls ohne Daten von Lernenden. Die Freigabe zeigt, was genau mitgeht; die Lehrkraft sieht dort auch, welche Inhalte fehlen, weil Lernende sie füllen. Das sag ihr auch selbst, bevor sie zustimmt. Eine Aktivität kommt nur mit, wenn ihr Abschnitt mitgeht; dieser Abschnitt ist dann ein Rahmen, und die Freigabe nennt ihn. Ob Moodle den Rahmen ohne seine übrigen Aktivitäten hält und wie Moodle den Kurs bei einer Auswahl benennt, prüft die Lehrkraft vor dem Einsatz.

## Die Antwortfrist: „läuft weiter“ ist kein Fehler

Nach einer Minute ist die normale Antwortfrist erreicht, bei `uebertragen` nach vier Minuten. Dann steht in der Antwort „läuft weiter“, und das ist kein Fehler und kein Abbruch: Die Arbeit läuft im Hintergrund. Frage mit dem Statuswerkzeug und derselben Nummer in Abständen bis zu 30 Minuten weiter: `sicherung_status` nach `sichern_aktivitaet` und `sichern_auswahl`, `wiederherstellung_status` nach `wiederherstellen_datei`, bei `uebertragen` das Werkzeug und die Nummer, die die Antwort nennt (je nach Phase Sicherung oder Wiederherstellung). Melde die Antwortfrist nicht als Timeout oder Fehlschlag, und sende den Auftrag nicht erneut, denn ein zweiter Lauf legt Dubletten an. Nach 30 Minuten ohne Abschluss berichte den zuletzt gelesenen Stand und die Nummer als offen; das ist kein Beleg für einen Fehlschlag und keine Erlaubnis zum Neustart.

Meldet der Status einen Stillstand (kein Fortschritt seit 15 Minuten), ist das weder Fehler noch Erfolg: Moodle hat keinen Fortschritt mehr gemeldet, und ob der Vorgang hängt, ist nicht belegt. Sag das so und nenne die letzte Beobachtung; starte nichts neu. Cron und Ad-hoc-Aufgaben prüft die Administration. Bei noch aktiver Abfrage nennt der Status den gespeicherten Stand mit Phase, Zeitpunkt und Fortschritt; dieser Aufruf fragt Moodle nicht zusätzlich ab. Gib diese Unterscheidung weiter. Meldet der Restore-Assistent einen Fehler oder weitere Angaben, bleibt der Ausgang unklar und der Vorgang gesperrt. Steht „fehlgeschlagen“ da, sag das so und frag die Lehrkraft, bevor du etwas erneut versuchst; die App wiederholt nie von selbst.

Frage den Status immer auf demselben Profil mit derselben Moodle-Adresse einschließlich Installationspfad ab; eine Umbenennung des Profils hebt den Schutz nicht auf. Alte Vorgänge ohne sichere Profil- und Instanzbindung prüfst du im Moodle-Kurs.

## Wiederherstellen

`wiederherstellen_datei` nimmt die Datei (Name relativ zum Sicherungsordner, so wie das Sichern ihn nennt) und den Parameter `weg`:

- `neuer_kurs`: ein neuer Kurs; braucht `neuer_kurs_name` und `kurzname`, optional `kategorie_id`.
- `aktueller_kurs_verschmelzen` und `anderer_kurs_verschmelzen`: fügen ein; nichts wird ersetzt oder gelöscht.

Welche Wege es gibt, entscheiden die Rechte des Kontos in Moodle. Ein Konto, das Aktivitäten, aber keine ganzen Kurse wiederherstellen darf, bekommt „diesen Kurs“ und die löschenden Wege gar nicht angeboten. Dann nennt das Werkzeug den gleichwertigen Weg (`anderer_kurs_verschmelzen` mit derselben Kurs-ID); sag das der Lehrkraft und ruf nach ihrem Ja damit erneut auf. Ein löschender Weg, den Moodle nicht anbietet, ist eine Lücke der Rechte, keine der App (A6).
- `aktueller_kurs_ersetzen` und `anderer_kurs_ersetzen`: löschen die vorhandenen Inhalte des Zielkurses; nur mit `loeschend: true`.

`weg` ist Pflicht. Nennt der Auftrag den Weg nicht eindeutig, frag nach, statt einen zu wählen. Die Lehrkraft nennt Kurs, Nummer und Datei genau. Biete nur die Wege an, die Moodle auf der Seite anbietet; die Fehlermeldung der App nennt sie. Die Datei wird vor dem Hochladen geprüft; eine Datei mit Daten von Lernenden wird abgelehnt.

### Sichtbarkeit der neuen Inhalte

Bei `wiederherstellen_datei` und `uebertragen` verlangt die App die Angabe `sichtbarkeit`; eine Vorgabe gibt es nicht, weil beide Wahlen etwas riskieren. Mit `wie_quelle` behalten die neuen Inhalte Sichtbarkeit und Voraussetzungen der Quelle, können also sofort für Lernende sichtbar sein. Mit `verborgen` verbirgt die App die eindeutig zugeordneten neuen Aktivitäten danach; kurzzeitig können sie noch sichtbar sein, und Verbergen schützt nicht vor Einsicht oder Änderungen durch andere. Bei `wie_quelle` sind Sichtbarkeit und Voraussetzungen nicht gegengeprüft; gib diese Grenze auch bei `verified: true` weiter, die übrigen Prüfungen bleiben maßgeblich.

Du fragst die Lehrkraft, welche Wahl gelten soll, und nennst sie im Plan. Nur wenn eine Kursseite `CLAUDE.md` des Zielkurses es festlegt, richtest du dich danach und sagst im Plan, woher die Wahl kommt. Bei `uebertragen` gilt die Wahl für alle Ziele.

### Ersetzen löscht

Die Wege `aktueller_kurs_ersetzen` und `anderer_kurs_ersetzen` löschen alle Inhalte des Zielkurses, einschließlich der Abgaben, Beiträge und Bewertungen der Lernenden darin; Einschreibungen und Gruppen bleiben erhalten. Die App sichert das ab: Die Freigabe kommt auf jeder Stufe, listet jede Aktivität, die gelöscht wird, mit Link, hebt Aktivitäten mit Daten von Lernenden und Aktivitäten hervor, die moocp nicht unterstützt, und verlangt zusätzlich eine ausdrückliche Bestätigung. Das nimmt dir die Pflicht nicht ab: Sag der Lehrkraft im Plan, dass alle Inhalte des Zielkurses gelöscht werden, einschließlich der Abgaben, Beiträge und Bewertungen der Lernenden. Schlag „verschmelzen“ (Einfügen) vor, wenn das genügt, und wähle „ersetzen“ nur auf ihren ausdrücklichen Wunsch.

### Nicht zweimal starten

Dieselbe Datei für denselben Weg wird nicht ein zweites Mal gestartet, solange dafür ein Vorgang offen ist; die Antwort nennt seine Nummer. Kläre erst den Stand mit `wiederherstellung_status`. Eine bewusste Wiederholung gibt es nur mit `wiederholung_von` und dieser Nummer, und nur auf ausdrücklichen Wunsch der Lehrkraft. Die App liest vor der neuen Freigabe den aktuellen Hintergrundstand und nennt Unsicherheiten sowie das Dublettenrisiko. Eine Einfüge-Wiederherstellung kann Inhalte doppelt anlegen, und ein Aktualisieren bestehender Inhalte gibt es nicht; das sagst du im Bericht, auch wenn die Lehrkraft eine Aktualisierung erwartet.

### Was der Bericht prüft

Die Rückleseprobe liest den Zielkurs zurück und vergleicht ihn mit der Sicherungsdatei. Sie prüft auch Bilder und Anhänge der neuen Aktivitäten gegen die Datei (Inhalt, nicht Adresse). Ein zwischenzeitlich ausgetauschtes Archiv oder ein fehlender Startbezug bleibt eine ausdrückliche Prüflücke. Steht im Bericht „nicht vollständig verifiziert“, sag das so; die App repariert nichts von allein.

Enthält die Datei einen Test, vergleicht die App außerdem Fragenzahl und Fragennamen, auch bei späteren Statusabfragen. Gleiche Sachnummern in der angegebenen Zielsammlung belegen keine eigene Quellherkunft; das bleibt eine Prüflücke. Ermittle diese Sammlung auf der Zielinstanz. Bei geteilten Sammlungen erläuterst du vor dem Start die mögliche Abhängigkeit vom Quellkurs auf derselben Instanz und die mögliche neue geteilte Sammlung zwischen Instanzen; die Herkunft bleibt dabei unbestätigt. Unauflösbare Fragenversionen sind ebenfalls Prüflücken. Gib einen solchen Test als nicht vollständig verifiziert weiter.

## Übertragen

### Quelle und Ziel

Jede Moodle-Instanz hat einen eigenen Werkzeugsatz (in Claude Code etwa `mcp__moodle__…` und `mcp__moodle-test__…`); `status` nennt das Profil, zu dem er gehört. Gibt es zwei Instanzen, nennt die Lehrkraft im Chat, welche Quelle und welche Ziel ist. Du nennst beides im Plan ausdrücklich, und ist es nicht eindeutig, fragst du nach, statt aus Kursnamen zu raten: Ein Kurs gleichen Namens kann auf beiden Instanzen liegen, und eine vertauschte Richtung legt Inhalte im falschen Kurs an oder löscht sie dort. Die Gegenrichtung, in der ein Kurs, der bisher Ziel war, zur Quelle wird, leitest du nie aus dem Zusammenhang ab; sie gilt nur, wenn die Lehrkraft sie ausdrücklich verlangt.

### Der Auftrag

`uebertragen` bringt eine Auswahl in einem Auftrag in mehrere Zielkurse derselben Instanz, mit derselben Auswahl für alle. Das Werkzeug arbeitet nur auf der Instanz, an der du es aufrufst: Ohne `datei` sichert es die Auswahl zuerst im Quellkurs, mit `datei` nimmt es die vorhandene Sicherungsdatei; danach stellt es die Datei für jedes Ziel wieder her. Jedes Ziel hat seinen eigenen Weg, seinen eigenen Vorgang und sein eigenes Ergebnis: fertig, fehlgeschlagen, unklar oder abgelehnt. Ein Fehler bei einem Ziel hält die übrigen nicht an, weil sie unabhängig sind; eine Ablehnung in der App hält sie an, weil die Lehrkraft den Auftrag damit gestoppt hat.

Die Freigabe zeigt Quelle, Inhalt und jeden Zielkurs mit Name, Nummer und Weg, einmal für den ganzen Auftrag, und danach fragt jeder Schreibschritt erneut (siehe oben). Ziele auf einer anderen Instanz bedienst du mit zwei Aufrufen statt mit `uebertragen`: auf der Quellinstanz `sichern_auswahl` (die Datei liegt dann im Sicherungsordner der App), auf der Zielinstanz `wiederherstellen_datei` je Ziel mit seinem Weg. Ob beide Instanzen denselben Sicherungsordner nutzen, ist nicht gemessen; sag das der Lehrkraft, bevor du es ihr als Weg anbietest.

### Rückfragen, bevor etwas geschieht

Fehlt ein Weg oder ein Kursname, ist ein Kurs doppelt genannt oder ist ein Ziel der Quellkurs, fragt das Werkzeug zurück und schreibt nichts. Die Rückfrage geht an die Lehrkraft, konkret genug, dass sie direkt antworten kann; du entscheidest das nicht an ihrer Stelle. Ein löschender Weg braucht `loeschend: true` im Ziel, sonst fragt das Werkzeug ebenfalls zurück. Der Weg `neuer_kurs` gehört nicht zu `uebertragen`; einen neuen Kurs legt `wiederherstellen_datei` an. Ist dieselbe Datei für ein Ziel schon übertragen worden, kommt eine Rückfrage mit der Nummer: Erst klärst du den Stand (`wiederherstellung_status`). Eine Wiederholung ist nur nach ausdrücklichem Wunsch der Lehrkraft zulässig, und zwar mit `wiederherstellen_datei` für diesen Kurs, `wiederholung_von` und der Nummer aus der Rückfrage, nicht mit `uebertragen`.

### Im Ergebnis sagen, was nicht zugesagt ist

Gib die Prüfprobleme und Prüflücken auch bei einem fertigen Ziel weiter: „fertig“ bestätigt den Abschluss, nicht jede Inhaltsprüfung. Bei fehlgeschlagenen oder unklaren Zielen nennst du die Nummer und sendest nicht erneut. Enthält die Auswahl eine Lernlandkarte, verknüpft die App ihre Orte ohne `datei` nach dem Kopieren selbst, mit `datei` und auf einer anderen Instanz nicht, und das Ergebnis nennt jede Karte getrennt als verknüpft, offen oder unklar; Näheres steht in `references/lernlandkarte.md`.
