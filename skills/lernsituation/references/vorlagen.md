# Vorlagen: so sieht der Entwurf aus

Die Form ist verbindlich, weil `scripts/pruefe-lernsituation.py` sie liest. Was in den Vorlagen in spitzen Klammern steht — `<Titel>`, `<n>` —, wird ersetzt, und das Skript meldet jeden Platzhalter, der stehen bleibt, ob als `<Titel>` oder als `&lt;Titel&gt;`. In den HTML-Vorlagen der SchuCu-Tabelle heißen die Platzhalter `&lt;…&gt;` und `...`; auch die meldet es.

Die Blätter sind HTML. Es gelten die Regeln in `references/html.md` — keine `style`-Attribute, Überschriften ab `<h3>`, Tabellen mit Klasse, Bilder aus `dateien/` —, und das Skript prüft sie am Entwurf. Hier stehen die festen Formen, die dazukommen.

## Der Entwurf

Ein Ordner im Arbeitsordner der App ist der Entwurf einer Lernsituation. Er hat schon die Form, in der die Werkzeuge der App ihn nehmen: `lernsituation.json` nennt den Abschnitt und die Aktivitäten in ihrer Reihenfolge, und je Aktivität gibt es einen Ordner mit ihrem Inhalt als HTML. Übertragen heißt deshalb nur noch anlegen, Eintrag für Eintrag; nichts wird umgewandelt oder neu geschrieben.

```
LS-<kurztitel>/
├── lernsituation.json
├── abschnitt/summary_editor.html           Beschreibung des Abschnitts
├── schucu/page.html
├── lehrerhandreichung/page.html            als Buch: kapitel.json, kapitel-1/content_editor.html …
├── handlungssituation/introeditor.html     optional, sonst steht sie auf Arbeitsblatt 1
├── ab-01-<kurztitel>/page.html
│   └── dateien/Z-01-<kurztitel>.svg
├── ab-01-<kurztitel>-loesung/page.html
├── ib-01-<kurztitel>/page.html
│   └── dateien/Z-01-<kurztitel>.svg
├── ab-01-<kurztitel>-vertiefung/page.html
├── ab-01-<kurztitel>-vertiefung-loesung/page.html
├── ab-02-<kurztitel>/introeditor.html      als Aufgabe
├── ab-02-<kurztitel>-loesung/page.html
├── ab-02-<kurztitel>-hilfe/page.html
└── ab-02-<kurztitel>-hilfe-loesung/page.html
```

`lernsituation.json`:

```json
{
  "abschnitt": {"name": "<Titel der Lernsituation>", "ordner": "abschnitt"},
  "aktivitaeten": [
    {"ordner": "schucu", "typ": "page", "name": "SchuCu"},
    {"ordner": "lehrerhandreichung", "typ": "page", "name": "Lehrerhandreichung"},
    {"ordner": "handlungssituation", "typ": "label", "name": "Handlungssituation"},
    {"ordner": "ab-01-<kurztitel>", "typ": "page", "name": "Arbeitsblatt 1: <Titel>"},
    {"ordner": "ab-01-<kurztitel>-loesung", "typ": "page", "name": "Lösung zu Arbeitsblatt 1: <Titel>"},
    {"ordner": "ib-01-<kurztitel>", "typ": "page", "name": "Infoblatt 1: <Titel>"},
    {"ordner": "ab-02-<kurztitel>", "typ": "assign", "name": "Arbeitsblatt 2: <Titel>",
     "einstellungen": {"submissionplugins": {"Texteingabe online": "nein", "Dateiabgabe": "ja"}}}
  ]
}
```

Regeln:

- **Die Reihenfolge ist die im Abschnitt** (SKILL.md, „Die Brücke"): SchuCu, Handreichung, Handlungssituation, dann die Blätter in der Reihenfolge ihres ersten Einsatzes im Ablaufplan, jede Lösung direkt hinter ihrem Blatt.
- **`typ`** wie bei `aktivitaet_anlegen`: `page` (Textseite, Inhalt in `page.html`), `assign` (Aufgabe, das Blatt in `introeditor.html`), `label` (Textfeld, `introeditor.html`), `book` (Buch, unten bei der Handreichung). Welcher Typ, steht im Plan (SKILL.md, Schritt 2).
- **`name`** wird der Name der Aktivität: bei einem Blatt sein Titel samt Kennung (unten), sonst „SchuCu", „Lehrerhandreichung", „Handlungssituation". Der Name steht nicht noch einmal im Inhalt — Moodle zeigt ihn darüber.
- **`einstellungen`** nur, wenn der Plan welche nennt: Frist und Abgabetypen einer Aufgabe, beim Buch die Kapitelgliederung. Schlüssel wie bei `aktivitaet_anlegen`.
- **Ein Unterabschnitt** ist ein Eintrag ohne Ordner, `{"typ": "subsection", "name": "<Phase>"}`; die Einträge danach kommen hinein, bis zum nächsten. Nur bei Bedarf (Brücke).
- **Die Ordnernamen** sind kurz, klein, mit Bindestrichen und ohne Umlaute. Sie sind nur für dich und die Übertragung da: In Moodle gibt es sie nicht, und im Text steht keiner — ein Blatt wird immer mit seiner Kennung genannt. `ab-01-…`, `ib-01-…` sortiert sie nach dem ersten Einsatz. Wird später ein Blatt geteilt, bekommt der neue Teil die nächste freie Nummer; alle übrigen umzunummerieren, riefe nur Verwechslungen hervor.
- **Jede Datei, die ein Blatt einbindet, liegt in `dateien/` seines Ordners** und steht im Text als `@@PLUGINFILE@@/<name>`. Dieselbe Zeichnung auf zwei Blättern liegt in beiden `dateien/`, unter demselben Namen.
- **Sonst liegt nichts im Entwurf** — keine Notizen, keine Kopien, kein Ordner, der nicht in `lernsituation.json` steht. Was dort fehlt, käme nicht in den Kurs.

## Weitere Aktivitäten im Entwurf

Neben den Blättern kann eine Lernsituation jede Aktivität enthalten, die die App anlegt; wofür sich welche anbietet, steht in `references/einsatz.md`. Jede steht wie ein Blatt in `lernsituation.json`, an der Stelle ihres ersten Einsatzes im Ablaufplan, mit `typ`, `name` und `ordner`, und im Ordner liegt, was sie braucht:

| `typ` | im Ordner | so sieht es aus |
|---|---|---|
| `board` | `board.json`; `introeditor.html` für den Auftrag, optional | `{"spalten": ["Unsere Aufteilung", "Offene Fragen"], "notizen": [{"spalte": "Offene Fragen", "titel": "Beispiel", "inhalt": "Wer darf ins Gäste-WLAN?"}]}` — Notizen nur als Beispiel oder Anstoß, die übrigen schreiben die Lernenden |
| `kanban` | `kanban.json`; `introeditor.html` optional | `{"spalten": ["Zu erledigen", "In Arbeit", "Erledigt"], "karten": [{"spalte": "Zu erledigen", "titel": "Abteilungen erfassen", "beschreibung": "Wer braucht welches Netz?"}]}` — die Karten sind Vorlagen, die die Lernenden ziehen |
| `checklist` | `eintraege.json`; `introeditor.html` optional | `[{"text": "Planung", "zustand": "ueberschrift"}, {"text": "Jede Abteilung hat ein VLAN", "tiefe": 1}, {"text": "Gäste-WLAN getrennt", "tiefe": 1, "zustand": "optional"}]` |
| `wiki` | `seiten.json` und je Seite eine HTML-Datei; `introeditor.html` optional | `[{"titel": "Begriffe", "datei": "begriffe.html"}, {"titel": "Tagging", "datei": "tagging.html"}]` — die erste ist die Startseite und heißt wie `einstellungen.firstpagetitle`; Verweise zwischen Seiten als `[[Titel]]` |
| `quiz` | `fragen.xml` mit `dateien/`; `introeditor.html` optional | die Fragen nach dem Skill `moodle-fragen`, jede mit Sachnummer; im Eintrag `"fragen": {"sammlung": "<Name>", "kategorie": "<Name>"}` und die `einstellungen`, die aus dem Testzweck folgen |
| `folder` | `bereiche/files/`, Unterordner erlaubt; `introeditor.html` optional | Vorlagen zum Weiterarbeiten, Datenblätter |
| `resource` | `bereiche/files/` mit genau einer Datei; `introeditor.html` optional | eine Vorlage, eine Projektdatei |
| `url` | `introeditor.html` optional; die Adresse als `einstellungen.externalurl` | `"einstellungen": {"externalurl": "https://…"}` |

**Weitere Aktivitäten tragen keine Kennung.** Ihr Name sagt, wozu sie da sind („Unsere VLAN-Aufteilung", „Prüfliste zum VLAN-Konzept"), und Blätter, Ablaufplan und Handreichung nennen sie mit genau diesem Namen in Anführungszeichen — „Heftet eure Entscheidung an die Pinnwand „Unsere VLAN-Aufteilung"." —, damit man sie auf Papier wiederfindet und die App die Nennung in Moodle zum Link machen kann. Jede steht im Ablaufplan; eine Aktivität, die kein Schritt benutzt, benutzt im Unterricht niemand.

**Die Fragen eines Tests** kommen in eine Fragensammlung der Lernsituation oder ihres Themas, nicht in die Sammlung, die Moodle für den ganzen Kurs angelegt hat (Skill `moodle-fragen`, „Sammlung oder Kategorie?"). Welche Sammlung und welche Kategorie, steht im Plan (SKILL.md, Schritt 2); gibt es sie noch nicht, legt die Übertragung sie an.

Zu **jedem** Arbeitsblatt — auch Hilfe und Vertiefung — gibt es eine Lösung. Infoblätter und die Handlungssituation haben keine.

**Der Titel eines Blatts beginnt mit seiner Kennung**, ohne führende Null: „Arbeitsblatt 2: …", „Infoblatt 1: …", „Hilfe zu Arbeitsblatt 3: …", „Vertiefung zu Arbeitsblatt 2: …", „Lösung zu Arbeitsblatt 2: …", „Lösung zur Hilfe zu Arbeitsblatt 3: …". Der Titel wird der Name in der Kursübersicht, und mit derselben Kennung verweisen die Blätter aufeinander — so findet man jedes genannte Blatt dort wieder, auf Papier wie in Moodle.

## Jedes Blatt steht für sich

Jedes Blatt — Arbeitsblatt, Infoblatt, Hilfe, Vertiefung, Lösung — wird einzeln gedruckt, einzeln ausgeteilt und Wochen später einzeln nachgelesen; in Moodle ist es eine eigene Seite. Wer es in der Hand hat, hat die anderen Blätter nicht unbedingt dabei. Daraus folgen sechs Regeln. Die Formen der Verweise sind fest, weil das Skript sie liest.

1. **Die Zählung beginnt auf jedem Blatt neu:** Abschnitte bei `<h3>1. …</h3>`, Abbildungen bei „Abb. 1", Aufgaben bei 1. Keine Zählung über Blätter hinweg und keine Präfixe wie „Abb. L3" — sonst beginnt ein Blatt bei Abb. 5, und wer es allein liest, sucht Abb. 1 bis 4.
2. **Ein Bezug auf ein anderes Blatt nennt dessen Kennung und die Stelle,** in genau diesen Formen: „Infoblatt 1, Abschnitt 4" (auch „Abschnitte 1 bis 3", „Abschnitte 2 und 4"), „Abb. 1 auf Infoblatt 2", „Abb. 1 in der Lösung zu Arbeitsblatt 3", „Aufgabe 3 auf Arbeitsblatt 1" oder „Arbeitsblatt 1, Aufgabe 3". „Abb. 1" ohne Kennung meint immer das eigene Blatt. Im Entwurf ist der Verweis Text; in Moodle wird die Kennung ein Link auf ihr Blatt: online führt er mit einem Klick hin, gedruckt bleibt der Text — und der trägt allein, weil jedes Blatt mit seiner Kennung beginnt.
3. **Braucht ein Abschnitt eine Zeichnung zum Verständnis, steht sie auf demselben Blatt** — dieselbe SVG-Datei darf auf mehreren Blättern eingebunden sein, je mit der Abbildungsnummer des Blatts. Sonst sagt der Text, wo sie ist und worauf dort zu achten ist. Nie stillschweigend voraussetzen, dass die Zeichnung eines anderen Blatts noch vor Augen ist.
4. **Baut ein Blatt auf einem anderen auf, sagt die Einleitung das in einem Satz:** „Auf Infoblatt 1 hast du … kennengelernt. Dieses Blatt …". „Gehört zu" auf einem Infoblatt nennt jedes Blatt, das es unter „Dazu" oder in einer „Lies"-Zeile verwendet — wer das Infoblatt austeilt, sieht daran, wozu.
5. **Setzt eine Aufgabe Wissen voraus, das in dieser Lernsituation neu ist, sagt sie, woher es kommt.** Ein eigenes Infoblatt ist dafür kein Muss; es gibt drei gleichwertige Wege, und welcher es wird, entscheidet die Lehrkraft (SKILL.md, Schritt 2):
   - **ein Infoblatt der Lernsituation:** Die „Lies"-Zeile nennt Blatt und Abschnitt („**Lies:** Infoblatt 1, Abschnitt 2"), und unter dem Abschnitt steht umgekehrt „→ für Arbeitsblatt 1, Aufgabe 3" — wer nur das Infoblatt in der Hand hat, sieht, wofür er einen Abschnitt liest;
   - **etwas, das es schon gibt:** Lehrbuch oder Tabellenbuch mit Titel und Kapitel oder Seite, die Hilfe eines Programms mit Stichwort, eine Seite im Netz mit ausgeschriebener Adresse — in der „Lies"-Zeile so genannt, dass man es findet. Titel und Seiten nennt die Lehrkraft; erfunden wird keine;
   - **Recherche als Teil der Aufgabe:** ausdrücklich verlangt, gern auch ausführlich, in einer Zeile „**Recherchiere:**" mit einem Hinweis, wo man anfängt, und was dabei herauskommen soll.

   Vorwissen aus früheren Lernsituationen gehört in die Handreichung („Vorwissen, Anschluss und Anrede"), nicht in eine „Lies"-Zeile. Was nirgends steht und nicht recherchiert werden soll, setzt keine Aufgabe voraus.
6. **Nach jeder Teilung oder Umnummerierung werden alle Verweise nachgezogen:** „Lies"-Zeilen und „Dazu" der Arbeitsblätter, „→ für" und „Gehört zu" der Infoblätter, die Lösungen und die Handreichung (Ablaufplan, Schritte, Materialübersicht). Das Skript meldet jeden Verweis, der ins Leere zeigt, und jede „Lies"-Zeile ohne ihr „→ für" und umgekehrt.

**Ist ein Blatt zu lang,** prüfe erst, ob es zusammengehört. Geteilt wird nur an einer inhaltlichen Grenze, nicht nach Länge. Die Prüffrage: Lässt sich jeder Teil unter einem eigenen Titel erklären, und gehören zu jedem Teil ganze Aufgaben eines Arbeitsblatts? Gibt es keine solche Grenze, bleibt es ein Blatt und wird gekürzt, nicht zerschnitten — ein nach Länge geteiltes Blatt beginnt mitten im Gedanken und erklärt mit Zeichnungen, die auf dem ersten stehen. Das neue Blatt bekommt einen eigenen Titel, eine eigene Einleitung, eine eigene Zählung ab 1 und die nächste freie Nummer.

## `abschnitt/summary_editor.html` — Beschreibung des Abschnitts

```html
<p><Kurzfassung der Handlungssituation, zwei bis drei Sätze — dieselbe wie in der SchuCu-Tabelle></p>
```

Sie steht in der Kursübersicht über dem Abschnitt, für Lernende sichtbar.

## `schucu/page.html` — Seite „SchuCu"

Nichts als die SchuCu-Tabelle: der Inhalt von `references/schucu-berufsschule.html` — im Beruflichen Gymnasium `schucu-bg.html` —, Zeichen für Zeichen samt den Absätzen darunter, nur die Datenzellen (und im BG die Legende) ausgefüllt. Keine Einleitung, kein Abschnitt dahinter, keine Überschrift. Regeln im Abschnitt „Die SchuCu-Tabelle" unten.

## `lehrerhandreichung/page.html` — Lehrerhandreichung

```html
<h3>Thematische Einführung für die Lehrkraft</h3>
<p><Der Stoff, so erklärt, dass eine fachfremd vertretende Lehrkraft Rückfragen beantworten kann. Fünf bis fünfzehn Absätze. Fachbegriffe beim ersten Auftreten erklärt. Quellen nach `references/urheberrecht.md`, im Text mit [1], [2], Liste am Ende dieses Abschnitts.></p>
<h4>Quellen</h4>
<ol>
<li><Angabe in der Form, die die Quelle vorgibt; Adresse ausgeschrieben als Linktext></li>
</ol>
<h3>Vorwissen, Anschluss und Anrede</h3>
<p><Was vorausgesetzt wird und woher es kommt; woran die Lernsituation anschließt — andere Lernfelder, Fächer, Praxis, die nächste Lernsituation. Anrede der Lernenden auf den Blättern: „du" / „Sie".></p>
<h3>Lernumgebung</h3>
<p><Welcher Schritt wo läuft — auf Papier, am Gerät, im Computerraum — und was dafür gebraucht wird: Raum, Geräte, Software mit Version, Netz ja/nein, die Lehr- und Tabellenbücher der Klasse, auf die die Blätter verweisen; was vorher vorzubereiten ist (Dateien, Aufbau) und was geht, wenn etwas davon fehlt.></p>
<h3>Ablaufplan</h3>
<table class="table table-bordered">
<thead>
<tr><th>Nr.</th><th>Phase</th><th>Zeit (min)</th><th>Was passiert</th><th>Sozialform</th><th>Material</th></tr>
</thead>
<tbody>
<tr><td>1</td><td>Informieren</td><td>15</td><td>Einstieg: Handlungssituation vorlesen, Auftrag klären</td><td>Plenum</td><td>Handlungssituation</td></tr>
<tr><td>2</td><td>Informieren</td><td>15</td><td>Infoblatt lesen, Verständnisfragen</td><td>Einzel</td><td>Infoblatt 1</td></tr>
<tr><td>n</td><td>—</td><td>30</td><td>Puffer</td><td>—</td><td>—</td></tr>
<tr><td></td><td></td><td><strong>360</strong></td><td><strong>Summe</strong></td><td></td><td></td></tr>
</tbody>
</table>
<h3>Die Schritte im Einzelnen</h3>
<h4>Schritt 1: <Überschrift wie „Was passiert" in der Tabelle></h4>
<ul>
<li><strong>Ziel:</strong> <ein Satz></li>
<li><strong>Ablauf:</strong> <was die Lehrkraft tut und sagt, was die Lernenden tun></li>
<li><strong>Material:</strong> <Kennung, bei Bedarf mit Stelle („Arbeitsblatt 1, Aufgabe 3") — wann ausgeteilt, wann eingesammelt></li>
<li><strong>Worauf achten:</strong> <typische Fehler, Stolperstellen, Zeitfresser></li>
<li><strong>Differenzierung:</strong> <wann Hilfe oder Vertiefung, wenn vorgesehen></li>
</ul>
<h3>Materialübersicht</h3>
<table class="table table-bordered">
<thead>
<tr><th>Blatt</th><th>Art</th><th>Einsatz in Schritt</th><th>Zweck</th></tr>
</thead>
<tbody>
<tr><td>Arbeitsblatt 1: <Titel></td><td>Arbeitsblatt</td><td>3</td><td><Zweck></td></tr>
<tr><td>Lösung zu Arbeitsblatt 1: <Titel></td><td>Lösung</td><td>— (Lehrkraft)</td><td><Zweck></td></tr>
<tr><td>Infoblatt 1: <Titel></td><td>Infoblatt</td><td>2</td><td><Zweck></td></tr>
<tr><td>Abb. 1 auf Infoblatt 1</td><td>Zeichnung</td><td>2</td><td><Zweck></td></tr>
</tbody>
</table>
<h3>Leistungsfeststellung und -bewertung</h3>
<p><Was bewertet wird (Handlungsprodukt, Präsentation, Test, Arbeitsverhalten), mit welcher Gewichtung fachlich zu personal, nach welchen Kriterien — mit Verweis auf das Blatt, auf dem die Lernenden sie sehen —, wann. Nach den Grundsätzen der Schule; was der Skill nicht kennt: „vom Nutzer zu ergänzen".></p>
<h3>Phasen der vollständigen Handlung</h3>
<p><Welche Phasen enthalten sind und wo der Schwerpunkt liegt; welche fehlt und warum — der didaktisch-methodische Kommentar.></p>
<h3>Checkliste</h3>
<table class="table table-bordered">
<thead>
<tr><th>Frage</th><th>Ja/Nein</th><th>Woran man es sieht</th></tr>
</thead>
<tbody>
<tr><td>Gibt es eine realistische Handlungssituation?</td><td>Ja</td><td><Halbsatz></td></tr>
<tr><td>Gibt es eine konkrete Problemstellung?</td><td>Ja</td><td>…</td></tr>
<tr><td>Gibt es mehrere Lösungswege?</td><td>Ja</td><td>…</td></tr>
<tr><td>Müssen Entscheidungen getroffen werden?</td><td>Ja</td><td>…</td></tr>
<tr><td>Werden alle Phasen der vollständigen Handlung durchlaufen?</td><td>Nein</td><td>Reflektieren entfällt, weil …</td></tr>
<tr><td>Entsteht ein Handlungsergebnis?</td><td>Ja</td><td>…</td></tr>
<tr><td>Werden Fach- und Personalkompetenzen gefördert?</td><td>Ja</td><td>…</td></tr>
<tr><td>Arbeiten die Lernenden selbstständig?</td><td>Ja</td><td>…</td></tr>
<tr><td>Gibt es kooperative Lernanteile?</td><td>Ja</td><td>…</td></tr>
<tr><td>Gibt es eine Reflexionsphase?</td><td>Nein</td><td>siehe oben</td></tr>
<tr><td>Dienen die Inhalte der Handlung?</td><td>Ja</td><td>…</td></tr>
<tr><td>Benennt die Handlungssituation den Rahmen?</td><td>Ja</td><td>Betrieb, Einrichtung oder Fall, …</td></tr>
<tr><td>Sind schulische Entscheidungen berücksichtigt?</td><td>Ja</td><td>Lernumgebung mit Papier, Geräten und Räumen, Bewertungsgrundsätze, Lernortkooperation: …</td></tr>
</tbody>
</table>
```

Dazu, was die Vorlage nur andeutet:

- **Ablaufplan:** Die Summenzeile ist Pflicht; das Skript vergleicht sie mit dem Zeitrichtwert und rechnet die Zeilen nach. Material sind die Kennungen der Blätter („Arbeitsblatt 1", „Hilfe zu Arbeitsblatt 1") und die Namen weiterer Aktivitäten in Anführungszeichen („Unsere VLAN-Aufteilung"), durch Komma getrennt, oder „—".
- **Die Schritte im Einzelnen:** je Zeile des Ablaufplans ein `<h4>Schritt n: …</h4>` mit seiner Liste. Keine Zeile ohne Schritt.
- **Materialübersicht:** erste Spalte der Name des Blatts oder der weiteren Aktivität, genau wie er in `lernsituation.json` steht — in Moodle heißt die Aktivität so, und der Eintrag wird ein Link mit diesem Text. Zeichnungen sind keine Aktivitäten; sie stehen als „Abb. n auf <Kennung>" da.
- **Quellen und fremde Inhalte:** Kommen fremde Inhalte vor, endet die Handreichung mit `<h3>Quellen und fremde Inhalte</h3>` und einer Tabelle „Wo verwendet · Was · Herkunft · Lizenz · Angabe" (unten). Die Lehrkraft sieht so auf einen Blick, was sie verteilt.

**Als Buch** (wenn der Plan es sagt, Richtwert in SKILL.md, Schritt 2): derselbe Inhalt, in Kapitel geteilt. Jedes `<h3>` wird ein Kapitel, unter „Die Schritte im Einzelnen" jeder Schritt ein Unterkapitel; der Titel steht in `kapitel.json`, nicht im Inhalt, und weitere `<h4>` im Kapitel werden `<h3>`. Das Kapitel „Die Schritte im Einzelnen" trägt einen Satz, was in den Unterkapiteln steht — Moodle verlangt in jedem Kapitel Inhalt. In `lernsituation.json` `"typ": "book"` mit `"einstellungen": {"numbering": "Keine"}`, weil die Unterkapitel schon „Schritt n" heißen. Gedruckt wird das Buch als Ganzes mit „Buch drucken".

```
lehrerhandreichung/
├── kapitel.json               [{"id": 1, "titel": "Thematische Einführung für die Lehrkraft", "unterkapitel": false},
│                               …, {"id": 5, "titel": "Die Schritte im Einzelnen", "unterkapitel": false},
│                               {"id": 6, "titel": "Schritt 1: <…>", "unterkapitel": true}, …]
├── kapitel-1/content_editor.html
├── kapitel-2/content_editor.html
…
```

## Die SchuCu-Tabelle

Die Tabelle steht allein auf der Seite „SchuCu", Zeichen für Zeichen nach der Vorlage — nur so kommt das Corporate Design unverändert in Moodle an. Daraus folgt:

- **Nichts an der Vorlage ändern außer dem Zelleninhalt**: keine Zeile dazu oder weg, keine Reihenfolge, keine Klasse, kein `colspan`, kein `style`, nicht den Kopflink „offizielle Erläuterungen", nicht die `&nbsp;` in den Abstandszellen. Auch die Absätze unter der Tabelle gehören zur Vorlage: „Inhalte können teilweise mit KI generiert sein." bleibt wörtlich stehen, im Beruflichen Gymnasium unter der Legende. Das Skript vergleicht den Aufbau mit der Vorlagedatei.
- **In den Zellen einfaches HTML**: `<strong>`, `<em>`, `<code>`, `<a href>`, `<br>`, `<ul><li>`.
- Die Tabelle ist eine der zwei Ausnahmen von „keine `style`-Attribute" (die andere: Rahmenlinien in Tabellen, `references/html.md`); die übrigen Regeln in `references/html.md` gelten für die Tabelle nicht, für alles andere auf der Seite schon.

### Eine Kurzform, die für sich steht

Die Tabelle fasst zusammen, sie verweist nicht. Jede Zelle sagt in wenigen Sätzen selbst, was gilt — kein „siehe Arbeitsblatt 2" —, damit die SchuCu-Seite bei einer Inspektion ohne ein anderes Dokument lesbar ist. Wer mehr wissen will, schaut in die Handreichung: Dort steht alles ausführlich, und dort dürfen im Rahmen der Anleitung Verweise auf die Blätter stehen, auch Sozialform oder Kompetenzen noch einmal im Zusammenhang. Umgekehrt braucht der Rest der Lernsituation die Tabelle nicht: Was in ihr kurz steht, steht ausführlich dort, wo die Spalte „ausführlich" unten es nennt. Nur Autor, curricularer Bezug und die Kompetenzbereiche des Beruflichen Gymnasiums stehen allein in der Tabelle.

### Welche Vorlage

`references/schucu-berufsschule.html` gilt immer. `references/schucu-bg.html` gilt für das Berufliche Gymnasium. Weitere Ausnahmen stehen in `SKILL.md`, Abschnitt „Die SchuCu-Tabelle", und nirgends sonst.

### Was in die Zellen kommt

Die Anforderungen stammen aus der Leitlinie SchuCu-BBS („Grundlegende Anforderungen an Lernsituationen", Stand 09/2018 — der Kopflink der Tabelle führt dorthin). Kurz gefasst in `references/didaktik.md`.

| Zelle | Inhalt | ausführlich | Vorlage |
|---|---|---|---|
| **Titel** | kurz, prägnant, beschreibt die Handlung — in der Regel Substantiv und Verb: „Firmennetz in VLANs trennen" | Name des Abschnitts | beide |
| **gepl. Zeitrichtwert** | `<n> UStd (<n·45> min)` — aus dem erwarteten Arbeitsaufwand, Bezug sind die Zeitrichtwerte des Ordnungsmittels. Das Skript liest den Wert. | Handreichung: Summenzeile des Ablaufplans | beide |
| **Autor\*(en)** | Name der Lehrkraft — nie erfinden; fehlt er: „vom Nutzer zu ergänzen" | — nur hier | beide |
| **Curricularer Bezug** | Vorgaben aus dem Ordnungsmittel — Rahmenlehrplan mit Lernfeld, Rahmenrichtlinie mit Lerngebiet, Modul, Qualifizierungsbaustein, im Beruflichen Gymnasium das Kerncurriculum —, wörtlich oder mit Fundstelle; fehlt er: „vom Nutzer zu ergänzen" | — nur hier | beide |
| **Handlungssituation** | die **Kurzfassung**, zwei bis drei Sätze für Kolleginnen und Kollegen; mit dem Rahmen (Modellunternehmen, Einrichtung, Fall). Dieselbe steht als Beschreibung des Abschnitts. | Handreichung: erster Schritt; für die Lernenden auf dem ersten Arbeitsblatt oder im Textfeld „Handlungssituation" | beide |
| **Handlungsergebnis / Handlungsprodukte** | was am Ende vorliegt und wem es gezeigt wird — auch Nicht-Greifbares: Stellungnahme, Beratungsgespräch, Pro-und-Kontra-Diskussion | Handreichung: Ziele der Schritte; der Auftrag auf dem Arbeitsblatt | beide |
| **personale Kompetenzen** | Sozialkompetenz und Selbstständigkeit, als beobachtbare Handlung formuliert, `<ul><li>` | Handreichung: Ziele der Schritte | beide |
| **fachliche Kompetenz Wissen / Fertigkeit** | getrennt: was gewusst, was gekonnt wird, `<ul><li>` | Handreichung: Ziele der Schritte | Berufsschule |
| **fachliche Kompetenz** | beides in einer Liste, `<ul><li>` | Handreichung: Ziele der Schritte | Berufl. Gymnasium |
| **Vereinbarungen zur Umsetzung** | Verknüpfung mit anderen Lernfeldern, Fächern, Praxis und Lernortkooperation, dann `<br>` und der didaktisch-methodische Kommentar: Schwerpunkt, welche Phasen, warum | Handreichung: „Vorwissen, Anschluss und Anrede", „Phasen der vollständigen Handlung" | Berufsschule |
| **Lernumgebung** | welcher Schritt auf Papier, welcher am Gerät; Raum, Geräte, Software mit Version, Netz ja/nein | Handreichung: „Lernumgebung" | Berufsschule |
| **Leistungsfeststellung und -bewertung** | Gewichtung personale/fachliche Kompetenzen, Kriterien, Format, Zeitpunkt — nach den Grundsätzen der Leistungsbewertung der Schule, die der Skill nicht kennt: nicht erfinden, sondern fragen oder „vom Nutzer zu ergänzen" | Handreichung: „Leistungsfeststellung und -bewertung" | Berufsschule |
| **Abgedeckte Kompetenzbereiche** | **nur die abgedeckten** Buchstaben, durch Leerzeichen getrennt: `A C` | — nur hier | Berufl. Gymnasium |

### Nur im Beruflichen Gymnasium: Lehrplan und Kompetenzbereiche

Die Vorlage hat zwei Stellen, die vom **Fach** abhängen:

- **Unter „Curricularer Bezug"** steht klein der Verweis auf den Lehrplan bzw. das Kerncurriculum des Fachs: Linktext = sein Titel, Adresse ausgeschrieben im `href`. Ist er nicht bekannt, steht im `<span>` statt des Links „Lehrplan vom Nutzer zu ergänzen".
- **Unter der Tabelle** steht in `<p style="font-size: 8pt;">` die Legende: **alle** Kompetenzbereiche des Kerncurriculums mit Buchstaben. In der Tabellenzelle darüber bleiben nur die abgedeckten stehen. Das Skript prüft, dass jeder Buchstabe in der Zelle in der Legende vorkommt.

Beides kommt aus dem Kerncurriculum des Fachs — **nie erfinden**. Liefert die Lehrkraft es nicht, fragst du in Schritt 1 danach. Bekannt ist:

| Fach | Lehrplan (Linktext und Adresse) | Legende |
|---|---|---|
| Informatik | „Lehrplan berufliche Informatik" — `https://bildungsportal-niedersachsen.de/index.php?eID=dumpFile&amp;t=f&amp;f=12491&amp;token=e4b30f8cbc2433cb9cd08302a10e9a966f5a3719` | `A: Kommunizieren, argumentieren und kooperieren; B: Algorithmisieren und implementieren<br>C: Strukturieren, modellieren und darstellen, D: Analysieren, bewerten und testen` |

Ein weiteres Fach kommt in diese Tabelle, sobald die Lehrkraft Lehrplan und Kompetenzbereiche geliefert hat.

## `handlungssituation/` — Handlungssituation (optional)

Steht die Handlungssituation nicht auf Arbeitsblatt 1, ist sie eine eigene Aktivität mit dem Namen „Handlungssituation", für Lernende die erste im Abschnitt: ein Textfeld (`"typ": "label"`, Inhalt in `introeditor.html`), wenn sie ein Absatz ist, sonst eine Textseite (`page.html`). Drei bis acht Sätze, dann der Auftrag in einem Satz. Keine Aufgaben, keine Lösung; im Ablaufplan steht sie als Material „Handlungssituation".

## `ab-nn-<kurztitel>/page.html` — Arbeitsblatt

```html
<p><strong>Lernsituation:</strong> <Titel der Lernsituation> · <strong>Zeit gesamt:</strong> <n> min · <strong>Sozialform:</strong> <Einzel / Partner / Gruppe> · <strong>Dazu:</strong> Infoblatt 1</p>
<p><Wenn die Handlungssituation hier steht: drei bis acht Sätze, dann der Auftrag in einem Satz.></p>
<h3>Aufgabe 1 (10 min · Einzel · AFB I)</h3>
<p><strong>Lies:</strong> Infoblatt 1, Abschnitte 1 und 2.</p>
<p><Aufgabenstellung mit Operator.></p>
<h3>Aufgabe 2 (20 min · Partner · AFB II)</h3>
<p>…</p>
<h3>Aufgabe 3 (15 min · Gruppe · AFB III)</h3>
<p>…</p>
```

Regeln:

- Die Aufgabenüberschrift trägt **immer** `(<n> min · <Sozialform> · AFB <I|II|III>)` in genau dieser Reihenfolge. Das Skript liest sie.
- Die Summe der Aufgabenzeiten ist die „Zeit gesamt" im Kopf.
- Anrede durchgehend, wie in Schritt 1 erfragt.
- Kein Inhalt, der auf ein Infoblatt gehört. Wenn die Aufgabe eine Erklärung braucht, ist das ein Infoblatt.
- **„Dazu"** im Kopf nennt jedes Blatt und jede andere Quelle, die das Arbeitsblatt braucht. **Die „Lies"-Zeile** steht direkt unter dem Aufgabenkopf, wenn die Aufgabe neues Wissen braucht, als eigener Absatz: `<p><strong>Lies:</strong> …</p>`, `<strong>Lest:</strong>` oder `<strong>Lesen Sie:</strong>` je nach Anrede, auch „Lies noch einmal:". Sie nennt ein Infoblatt mit Abschnitt — ohne Abschnitt ist das ganze Infoblatt gemeint — oder eine andere Quelle so, dass man sie findet. Soll recherchiert werden, steht dort `<strong>Recherchiere:</strong>`, `<strong>Recherchiert:</strong>` oder `<strong>Recherchieren Sie:</strong>` mit dem Hinweis, wo man anfängt. Regeln 4 und 5 unter „Jedes Blatt steht für sich".
- **Wo etwas eingetragen wird**, braucht es Platz zum Ausfüllen — oder keinen, wenn in Moodle abgegeben wird: `references/html.md`, „Platz zum Ausfüllen". Meldet `status` die Druckaufbereitung, ist es ihr Karofeld, sonst eine Tabelle mit leeren Zeilen. Die Größe steht im Plan.
- **Zeichnungen** mit Bildunterschrift darunter:

  ```html
  <p><img src="@@PLUGINFILE@@/Z-01-<kurztitel>.svg" alt="<was zu sehen ist>" class="img-fluid"></p>
  <p><em>Abb. 1: <was man daraus lernen soll></em></p>
  ```

  Die Datei liegt in `dateien/` des Blatts. Gebraucht wird eine Zeichnung eines anderen Blatts: Regel 3.

**Als Aufgabe** (`"typ": "assign"`, wenn etwas abgegeben wird): dasselbe Blatt in `introeditor.html`. Frist und Abgabetypen stehen als `einstellungen` in `lernsituation.json`, so wie der Plan sie nennt.

## `ab-nn-<kurztitel>-loesung/page.html` — Lösung

```html
<h3>Aufgabe 1</h3>
<p><Erwartete Lösung. Bei offenen Aufgaben: Erwartungshorizont — was mindestens enthalten sein muss, was ein gutes Ergebnis zusätzlich hat. Bei Rechnungen: Rechenweg. Bei Entscheidungen: mögliche Wege mit Bewertung.></p>
<p><strong>Bewertungshinweis:</strong> <was Punkte bringt, was ein häufiger Fehler ist></p>
<h3>Aufgabe 2</h3>
<p>…</p>
```

Eine Lösung hat dieselben Aufgabennummern wie ihr Blatt. Sie wird wie jedes Blatt allein gelesen: Ihre Abbildungen zählen ab Abb. 1, und eine Zeichnung des Arbeitsblatts heißt hier „Abb. 1 auf Arbeitsblatt 1", nicht „Abb. 1".

## `ab-nn-<kurztitel>-hilfe/`, `-vertiefung/` — Zusatzblätter

Gleicher Aufbau wie ein Arbeitsblatt, Name „Hilfe zu Arbeitsblatt 1: <Titel>" bzw. „Vertiefung zu Arbeitsblatt 1: <Titel>". Im Kopf zusätzlich, nach einem Zeilenumbruch:

```html
<p><strong>Lernsituation:</strong> … · <strong>Dazu:</strong> Infoblatt 1, Arbeitsblatt 1<br>
<strong>Für:</strong> <wer bei Aufgabe 2 auf Arbeitsblatt 1 nicht weiterkommt (Hilfe) / Gruppen, die Arbeitsblatt 1 abgeschlossen haben (Vertiefung)></p>
```

Eine Hilfe gibt Geländer — einen Zwischenschritt, ein Beispiel, eine vorstrukturierte Tabelle — und führt zum **selben** Ziel wie das Arbeitsblatt. Eine Vertiefung führt weiter (Transfer, Störung, Erweiterung), AFB III. Die Namen sagen den Lernenden, was sie in der Hand haben: Eine Hilfe nimmt, wer festhängt, eine Vertiefung, wer weiter will — keiner von beiden sortiert in Stärkere und Schwächere.

## `ib-nn-<kurztitel>/page.html` — Infoblatt

```html
<p><strong>Lernsituation:</strong> <Titel> · <strong>Gehört zu:</strong> Arbeitsblatt 1, Hilfe zu Arbeitsblatt 1 · <strong>Lesezeit:</strong> <n> min</p>
<p><Einleitung in ein bis zwei Sätzen: wozu das Blatt da ist. Baut es auf einem anderen Blatt auf, sagt sie das: „Auf Infoblatt 1 hast du … kennengelernt. Dieses Blatt …"></p>
<h3>1. <Zwischenüberschrift></h3>
<p>→ für Arbeitsblatt 1, Aufgabe 1</p>
<p><Der Stoff, den die Lernenden für den nächsten Schritt brauchen. Kompakt, Zeichnung wo sie hilft. Keine Aufgaben.></p>
<h3>2. <Zwischenüberschrift></h3>
<p>→ für Arbeitsblatt 1, Aufgaben 2 und 3, und Hilfe zu Arbeitsblatt 1, Aufgabe 1</p>
<p>…</p>
<h3>Zum Nachschlagen</h3>
<ul>
<li><Titel des Dokuments oder Videos> — <a href="https://…">https://…</a> — <wofür></li>
</ul>
```

Ein Infoblatt erklärt, es fragt nicht. Verständnisfragen dazu stehen auf einem Arbeitsblatt.

Die Abschnitte sind nummeriert, damit eine „Lies"-Zeile genau einen nennen kann; „Zum Nachschlagen" bleibt ohne Nummer. „→ für" steht als eigener Absatz direkt unter dem Abschnittskopf und nennt jede Aufgabe, deren „Lies"-Zeile den Abschnitt nennt — nicht mehr und nicht weniger. Wird ein Infoblatt nur als Ganzes gelesen („**Lies:** Infoblatt 1."), entfällt „→ für".

## `dateien/Z-nn-<kurztitel>.svg` — Zeichnung

Eine Datei in `dateien/` jedes Blatts, das sie einbindet. Hausstil, Muster und Maße: `references/zeichnungen.md`. Jede Zeichnung hat eine Bildunterschrift im Blatt („Abb. 1: Netz der Muster GmbH vor der Umstellung") und wird im Text erwähnt.

„Abb. n" zählt je Blatt, nicht je Lernsituation: Dieselbe Datei `Z-03-….svg` kann auf Infoblatt 2 „Abb. 1" sein und auf Arbeitsblatt 4 wieder „Abb. 1". Die Nummer im Dateinamen zählt die Zeichnungen der Lernsituation und erscheint nie im Text eines Blatts.

## Quellen und fremde Inhalte — am Ende der Handreichung

```html
<h3>Quellen und fremde Inhalte</h3>
<table class="table table-bordered">
<thead>
<tr><th>Wo verwendet</th><th>Was</th><th>Herkunft</th><th>Lizenz</th><th>Angabe</th></tr>
</thead>
<tbody>
<tr><td>Infoblatt 1</td><td>Abbildung Schaltzeichen</td><td>Wikimedia Commons</td><td>Public Domain</td><td><die Angabe in der Form der Quelle, Adresse ausgeschrieben></td></tr>
</tbody>
</table>
```

Nur, wenn fremde Inhalte vorkommen. Fehlt der Abschnitt, gilt: alles selbst geschrieben und gezeichnet.

## Bericht zu einem bestehenden Abschnitt

Für den Auftrag „beurteile Abschnitt X". Er steht als Antwort im Chat, in dieser Gliederung; er geht nicht nach Moodle, und es entsteht keine Datei. Eine Seite; kein Abschnitt länger als nötig.

```
# Bericht: <Kurs>, Abschnitt <n> „<Titel>"

**Einordnung:** <Lernsituation | Arbeitsauftrag | Aufgabensammlung |
Materialsammlung> — <Halbsatz, woran man es sieht>.

## Was da ist

| Aktivität | Art | Rolle in einer Lernsituation |
|---|---|---|
| <Name> | Textseite | Information (wird Infoblatt) |
| <Name> | Aufgabe | Übung, AFB II — passt in die Phase Durchführen |
| <Name> | Verzeichnis (3 PDFs, nicht gelesen) | unklar |

## Befunde nach Priorität

**Muss** — ohne das ist es keine Lernsituation
- <Befund>. Beleg: <Stelle oder Zitat>. Vorschlag: <konkret, ein Satz>.

**Soll** — es trägt, aber schwach
- <Befund>. Beleg: … Vorschlag: …

**Kann** — Feinschliff
- <Befund>. Beleg: … Vorschlag: …

## Der Weg zur Lernsituation

| Stufe | Was passiert | Mit dem Vorhandenen |
|---|---|---|
| klein | <Handlungssituation davor, eine Entscheidung, Zeiten und Sozialformen> | <alle Aufgaben bleiben; Textseite X wird Infoblatt 1> |
| mittel | <Aufgaben um ein Produkt neu geordnet, Kontrolle durch Lernende, Reflexion> | <Aufgabe 3 und 5 werden Kontrolle; Aufgabe 7 entfällt> |
| Neubau | <neue Lernsituation, vorhandene Aufgaben als Übungs- und Kontrollmaterial> | <zwei bis drei Vorschläge folgen auf Wunsch> |

## Nächster Schritt

<Ein Satz: welche Entscheidung die Lehrkraft jetzt trifft, damit es weitergeht.>

---
Nicht gelesen: <was der Skill `moodle` nicht lesen konnte, oder „—">.
```

Regeln:

- Jeder Befund hat einen **Beleg** und einen **Vorschlag**. Ein Befund ohne Beleg ist ein Eindruck; ein Befund ohne Vorschlag ist ein Vorwurf.
- **Muss** ist leer, wenn es eine Lernsituation ist. Dann steht das da.
- Der Weg nennt, was mit **jedem** vorhandenen Objekt passiert — bleibt, wird umgewidmet, entfällt. Nichts wird stillschweigend ersetzt.
- Keine Punkte, keine Note, keine Prozentwerte.
