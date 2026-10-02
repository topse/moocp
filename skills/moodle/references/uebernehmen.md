# Bestehende Blätter nach Moodle übernehmen

Immer wieder kommt der Auftrag, vorhandenes Material nach Moodle zu bringen:
ein Arbeits- oder Informationsblatt als PDF, ODT oder DOCX, vom Nutzer
übergeben oder aus einem Verzeichnis im Kurs (`aktivitaet_lesen`, dann
`bereiche/files/`). Dafür gilt ein Grundsatz, und alles Weitere folgt aus ihm.

## Der Grundsatz: What you see is what you mean

Übernommen wird die **Bedeutung**, nicht das Aussehen. Das Original sagt mit
seiner Gestaltung etwas aus — das ist eine Überschrift, das ist ein Merksatz,
das gehört als Tabelle zusammen —, und genau das schreibst du als HTML auf.
Wie es aussieht, bestimmen danach die Stylesheets der Instanz, am Bildschirm
wie im Druck; ein übernommenes Blatt sieht danach aus wie jede andere Seite im
Kurs, und so soll es sein. Hat die Instanz die Druckaufbereitung
„Aufgabenblatt-Druck" (`status` meldet sie), gilt zusätzlich
`references/drucken.md`.

Wer das Original nachbaut — Schriftgröße, Farbe, Einzug, Abstand —, baut es
gegen das Theme: Der Kurs wirkt zusammengewürfelt, und beim nächsten
Theme-Wechsel stimmt nichts mehr. Deshalb auch nicht das HTML übernehmen, das ein Umwandler (LibreOffice,
Word, pandoc) aus der Datei erzeugt: Es steckt voller `style`-Attribute,
`<span>`-Hüllen und `Mso`-Klassen. Die Datei liefert Text und Struktur; das
HTML schreibst du neu.

## Lesen: als Text und als Bild

Den Text liest du mit den lokalen Werkzeugen aus (für PDF, DOCX und ODT gibt
es eigene Skills, falls installiert). Das allein reicht nicht: **Sieh jede
Seite zusätzlich als Bild an.** Beim Auslesen verschwinden Kästen, Rahmen,
Tabellenlinien und Einrückungen — und gerade sie sagen, was ein Merksatz ist,
was eine Überschrift und was nur fett gesetzt. Ohne das Bild rätst du.

Bilder holst du **aus der Datei selbst**, in ihrer Originalauflösung: DOCX
und ODT sind ZIP-Archive mit den Bildern darin (`word/media/`, `Pictures/`),
ein PDF enthält sie eingebettet. Ein Bildschirmfoto der Seite ist kein Ersatz
— unscharf, mit Rand und Text daneben.

Ist das PDF ein **Scan** ohne Textebene, sag das dem Nutzer, bevor du
anfängst: Texterkennung macht Fehler, die man erst beim Gegenlesen findet.
Frag nach dem Original als ODT oder DOCX; gibt es keins, lies selbst gegen
und nenne die unsicheren Stellen im Plan.

## Zuordnen: was woraus wird

Was etwas ist und wie es als HTML dasteht — Überschrift, Hervorhebung, Liste, Kasten, Tabelle, Bild, Link —, steht in der Tabelle „Was etwas ist — und wie es geschrieben wird" in `references/html.md`; dort auch, warum. Beim Übernehmen kommt dazu:

| Im Original | In Moodle |
|---|---|
| Titel des Blatts | Name der Aktivität — nicht in den Inhalt, `h1` setzt Moodle |
| eine nur fett gesetzte Zeile, die als Überschrift dient | `<h3>` bzw. `<h4>` wie jede Überschrift |
| unterstrichen | `<strong>` oder `<em>`, nie `<u>` |
| Lösung zum Blatt (Lösungsblatt, Lösungsteil) | eigene Textseite, **verborgen** — nie auf das Blatt der Lernenden, auch nicht in einem Kasten |
| Zeichnung aus Formen (Kästen, Pfeile, Linien) | neu als SVG im Hausstil (`references/zeichnungen.md`) — Formen lassen sich nicht herauslösen |
| Quellenangabe | bleibt, in der Form, die die Quelle vorgibt |
| Schriftart, -größe, Farbe, Einzug, Zeilenabstand, Seitenumbruch | entfällt |
| Kopf- und Fußzeile, Schullogo, Seitenzahl, Feld für Name/Klasse/Datum | entfällt — Kopf, Fuß und Seitenzahl sind Sache der Instanz; mit der Druckaufbereitung setzt sie sie beim Drucken selbst (`references/drucken.md`) |
| Formel, auch als Bild oder aus einem Formeleditor | LaTeX nach `references/html.md`, „Formeln" — übernommen wird die Formel, nicht ihr Bild; vorher `kurs_filter(kurs)` |

**Höchstens zwei Kastenarten je Seite**, auch wenn das Original mehr hat: Ordne sie nach ihrer Bedeutung zu und fasse zusammen, was dasselbe meint. Welche Stelle welcher Kasten wird, steht im Plan.

## Wohin in Moodle

Nach der Brücke (Abschnitt „Die Brücke" im SKILL.md): Ein **Arbeitsblatt**
wird eine Aufgabe (`assign`), wenn etwas abgegeben wird — der Blatttext
wird der Aufgabentext —, sonst eine Textseite. Ein **Informationsblatt** wird
eine Textseite. Angelegt wird wie immer verborgen.

Das **Original** lädst du nicht zusätzlich hoch, außer der Nutzer will es:
Zwei Fassungen desselben Blatts laufen auseinander, und niemand weiß später,
welche gilt. Will er es behalten, gehört es verborgen in ein Verzeichnis für
Lehrermaterial.

## Platz zum Ausfüllen

Schreiblinien, leere Kästen und leere Tabellenzeilen im Original sind Platz für die Antwort. Übernommen wird, dass dort Platz ist, nicht, wie er aussah; was daraus wird — nichts, wenn in Moodle abgegeben wird, sonst Karofeld oder Tabelle —, steht in `references/html.md`, „Platz zum Ausfüllen". Wo geantwortet wird, ist eine Entscheidung für den Plan, wenn der Auftrag sie nicht schon trifft.

## Was nicht einfach mitkommt

- **Fremde Bilder und Texte** im Material: Es gelten die Regeln unter „Fremde
  Inhalte". Dass die Lehrkraft das Blatt gemacht hat, heißt nicht, dass jedes
  Bild darin frei ist. Ist die Herkunft nicht erkennbar, frag einmal.
- **Echte Namen** von Personen oder Firmen: nennen, einen Ersatz aus der
  Muster-Familie vorschlagen, nicht still tauschen — es ist das Material der
  Lehrkraft.
- **Personenbezogenes** — ein Blatt mit Namen der Klasse, Noten, eine
  ausgefüllte Liste: nicht übernehmen, dem Nutzer sagen, warum.

## Der Plan vor dem Anlegen

Bevor etwas angelegt wird, steht im Chat, mit Grund zu jeder Entscheidung:

- **Zielobjekt**: Typ, Abschnitt, Name;
- **Gliederung**: die Überschriften in ihrer Ebene;
- **Kästen**: welche Stelle welcher Kasten wird;
- **Tabellen**, die eigene Linien brauchen;
- **Bilder**: übernommen, neu gezeichnet oder weggelassen;
- **Platz zum Ausfüllen**: entfällt, Karofeld oder Tabelle, und wie groß;
- **was entfällt** und **was offen ist** (Herkunft eines Bildes, ein echter
  Name, eine Formel, unsichere Stellen eines Scans).

Dann auf das Ja warten.

## Nach dem Anlegen

Die Übersicht der Rückleseprobe sollte keine Befunde zeigen; steht dort einer,
ist er ein Fehler der Übernahme, kein Stil. Dann bitte die Lehrkraft, die
Seite neben dem Original anzusehen, am Bildschirm und in der Druckvorschau —
mit der Frage, ob **alles da** ist und **dasselbe bedeutet**, nicht, ob es
gleich aussieht.
