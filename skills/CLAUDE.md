# CLAUDE.md – die Skills

Gilt zusätzlich zur [CLAUDE.md des Projekts](../CLAUDE.md), deren Regeln für
die Dokumentation auch hier gelten. Aufbau und Befehle für Menschen:
[README.md](../README.md), „Die Skills". Notizen je Skill stehen in
`<skill>/CLAUDE.md`; `build.py` lässt sie aus den Paketen heraus.

## Arbeitsteilung mit der App

- **Die App sagt, was ein Werkzeug nimmt** (Beschreibung und Parameter in
  `lib/mcp/mcp_dienst.dart`), **der Skill sagt, wann und wozu** – Abläufe,
  Reihenfolge, fachliche Regeln, Fallstricke im Zusammenhang. Parameterlisten
  nicht im Skill wiederholen, außer als Beispiel eines Ablaufs.
- **Ändert sich ein Werkzeug, zieht der Skill nach**, der es benutzt – im
  selben Arbeitsgang. Werkzeugnamen, Aktionsnamen (`art`) und Meldungstexte,
  die ein Skill zitiert, gegen den Code prüfen.
- Was ein Skill als „gemessen" nennt, ist auf der Instanz ausgeführt und
  zurückgelesen (A3 der Projekt-CLAUDE.md). Ein Messwert steht mit Datum an
  der Stelle, die er betrifft, und gilt als „auf der Testinstanz gemessen",
  nicht als „auf dieser Instanz": Der installierte Skill läuft auf fremden
  Instanzen. Was nur an der Testinstanz hängt (Versionen, installierte
  Plugins, Zahl der Fragetypen), gehört nicht ins Paket – das ermittelt die
  App zur Laufzeit (A9).

## Gleichanteile

- Was in mehreren Skills gleich steht, lebt **nur** in `gemeinsam/` und wird
  von `build.py` zwischen die Marker gesetzt; Handarbeit zwischen den Markern
  geht beim nächsten Bau verloren. Welcher Skill welchen Anteil trägt, steht in
  `SKILLS` in `build.py`.
- **Keine Abschriften.** Braucht ein Anteil je Medium andere Beispiele, füllt
  `build.py` einen Platzhalter aus einer Datei (`@@QUELLENBEISPIELE@@` aus
  `urheberrecht-beispiele-*.md`), `@@NAME@@` wird der Skillname.
- **Das HTML ist ein Gleichanteil in zwei Stufen**, weil für Aktivitäten,
  Fragen und die Blätter einer Lernsituation dieselben Regeln gelten:
  `gemeinsam/html-kurz.md` im SKILL.md, `gemeinsam/html.md` (samt den
  gemessenen Bootstrap-Klassen) als `references/html.md` jedes der drei
  Skills. Was nur ein Skill braucht, steht bei ihm hinter dem Block: bei
  Fragen die Stellen ohne HTML (`gapselect`/`ddwtos`, Cloze-Klammern), bei
  `moodle` die Druckaufbereitung, bei `lernsituation` die festen Formen der
  Vorlagen. Verworfen: je Skill eine eigene Fassung – vier Abschriften
  liefen schon auseinander, und eine fünfte wäre mit dem HTML-Entwurf der
  Lernsituation dazugekommen. Auch die Regeln für Links stehen nur dort.
- **Zwei Stufen auch für fremde Inhalte:** `gemeinsam/urheberrecht-kurz.md`
  im SKILL.md, `gemeinsam/urheberrecht.md` als `references/urheberrecht.md`.
  Allgemein gilt: Was nur bei manchen Aufträgen gebraucht wird, steht in
  `references/`, im SKILL.md ein Kern und der Satz, wann die Referenz zu
  lesen ist – das SKILL.md wird bei jedem Auftrag ganz geladen.
- **Die Regeln sind an drei Stellen geprüft:** beim Lesen in der App
  (`lib/moodle/auswertung.dart`, etwa `_mehrAlsRahmen` für die enge
  `style`-Ausnahme bei Rahmenlinien), am Entwurf im Prüfskript des Skills
  `lernsituation` (`HtmlRegeln`, `mehr_als_rahmen`) und beschrieben in
  `gemeinsam/html.md`. Wer eine Regel ändert, ändert alle drei. Die
  Formelfehler gehen denselben Weg (`lib/moodle/formeln.dart`,
  `formel_fehler`); sie sind keine Befunde, sondern brechen das Schreiben ab.
- Die Sicherheitsabschnitte am Anfang der SKILL.md von `moodle` und
  `moodle-fragen` bleiben getrennt: gleiche Regeln, eigene Beispiele. Wer sie
  ändert, ändert beide.
- Ein neuer Anteil: Datei in `gemeinsam/`, in `SKILLS` eintragen, Markerpaar in
  die Skills, bauen.

## Nach jeder Änderung

Bauen und die drei Prüfungen laufen lassen (Befehle in der README). Dabei:

- Die `description` im Frontmatter steht in Anführungszeichen (ein Doppelpunkt
  mit Leerzeichen beendet sonst in YAML den Wert) und hat höchstens 1024
  Zeichen – `moodle` und `moodle-fragen` liegen knapp darunter, beim nächsten
  Zusatz zuerst kürzen.
- **Installieren** macht die App (E13 der Projekt-CLAUDE.md): `build.py` baut
  nach `dist/`, `tool/neustart.sh` baut die App mit diesen Paketen, und beim
  Start bietet sie im Dialog „KI-Werkzeuge einrichten" an, sie zu installieren. Die
  Entscheidung trifft der Nutzer dort; einen anderen Weg gibt es nicht.
- Zeilenenden sind LF (`.gitattributes`). Skripte, die Dateien der Skills
  umschreiben, lesen und schreiben mit `io.open(…, encoding='utf-8',
  newline='')`, damit sie keine Zeilenenden umsetzen: An gemischten
  Zeilenenden ist schon einmal eine `description` verschwunden. `build.py`
  stellt `SKILL.md` vor dem Packen auf LF und prüft das im fertigen Paket.

## Schreibstil

- **Fließtext mit Begründung**, keine Stichwortlisten. Der Leser ist ein
  Modell ohne Gedächtnis an diese Sitzung; die Begründung verhindert, dass es
  einen Weg „vereinfacht" und dabei die Absicherung wegwirft.
- Deutsch mit echten Umlauten, auch in der `description`. ASCII bleibt nur
  bei Bezeichnern (Werkzeugnamen wie `aendern`, `test_aendern`), bei Datei-
  und Ordnernamen und im Block `VERDACHTSMUSTER`; `umlaute.py` schützt diese
  Stellen, `pruefung/pruefe-umlaute.py` meldet Rückfälle.
- Erfundene Namen aus der Muster-Familie, fremde Inhalte nur aus erlaubten
  Herkünften – beides Gleichanteile, hier nur als Erinnerung.
- Dateien mit dem Write-Werkzeug schreiben, nicht per Bash-Heredoc: der
  scheitert erfahrungsgemäß an deutschem Text und Anführungszeichen.
- Die Skills laufen in Claude Code, Codex CLI und LM Studio (E21 der
  Projekt-CLAUDE.md). Darum steht in ihnen nichts, was nur in einem Client
  gilt – keine Werkzeugnamen mit Präfix, kein „Write-Werkzeug", kein
  `~/.claude/skills` als einziger Ort; braucht es ein Beispiel, dann mit
  „in Claude Code" davor.

## Ein eingefügter Befund ist ein Auftrag

Die Skills geben am Ende einer Antwort Blöcke aus, die der Nutzer hier
einfügt. Jeder ist ein Auftrag – aber erst nach einem Plan (A5):

| Block | Bedeutung | Vorgehen |
|---|---|---|
| `LÜCKENBEFUND` | ein Werkzeug fehlt | lesen; **zuerst klären, ob der Weg Personendaten berührt** – dann nicht bauen, sondern dem Nutzer sagen, warum; sonst Plan vorlegen, im Testkurs messen (Probe `ZZ`, hinterher löschen), bauen wie in der README „Eine neue Funktion hinzufügen", Skill nachziehen |
| `SKILLBEFUND` | ein Skill oder Werkzeug stimmt nicht | nachstellen, Ursache messen statt vermuten, beheben, im Testkurs gegenprüfen |
| `DATENSCHUTZBEFUND` | die Sperre hat gegriffen | entscheiden, ob der Ablauf etwas Unzulässiges wollte (dann Skill so ändern, dass er es nicht mehr versucht) oder die Sperre zu weit ist (dann Sperrliste enger, mit Test beider Richtungen) |

Ein Lückenbefund „Funktion fehlt" kann auch heißen, dass Moodle es nicht kann
(Wikiseiten haben keine Reihenfolge). Dann ist das Ergebnis ein Satz im
Skill, damit die nächste Anfrage ohne Suche beantwortet wird.
