# Fragensammlungen, Kategorien, Fragenpools

## Was sich mit Moodle 5 geändert hat

Bis Moodle 4 hatte jeder Kurs **eine** Fragensammlung, verankert im
Kurskontext, erreichbar über `/question/edit.php?courseid=43`. Die Kategorien
darin waren die einzige Gliederung.

Ab Moodle 5 sind Fragensammlungen **Aktivitäten** — Plugin `mod_qbank`. Ein
Kurs kann beliebig viele haben. Die alte Kurssammlung wird beim Upgrade in eine
Aktivität umgewandelt; sie heißt dann typischerweise „<Kursname> geteilte
Fragensammlung" mit dem Hinweis „Diese Fragensammlung wurde automatisch
erstellt, als die Website aktualisiert wurde". Die alte Adresse leitet auf
`/question/banks.php?courseid=…` um.

## Die zwei Sorten Sammlung

`fragensammlungen(kurs)`:

```
2384 „Testkurs geteilte Fragensammlung" (geteilt)
15449 „ZZ Probetest" (eigene Sammlung eines Tests)
```

**Geteilt** — echte `mod_qbank`-Aktivitäten. Ihre Fragen sind in beliebigen
Tests dieses Kurses (und je nach Freigabe darüber hinaus) verwendbar. Das ist
der Ort für alles, was länger leben soll.

**Eigene Sammlung eines Tests** — Tests, die eine private Sammlung mitbringen.
Moodle sagt es selbst: *„Fragen in den Fragensammlungen dieser Aktivitäten
können nicht an anderer Stelle verwendet werden."*

Die praktische Folge: Wer eine Frage in der privaten Sammlung eines Tests
anlegt und sie ein halbes Jahr später im Nachschreibtest braucht, muss sie neu
anlegen. Deshalb **im Zweifel in die geteilte Sammlung**, und dem Nutzer sagen,
wohin du es gelegt hast.

## Eine neue Fragensammlung anlegen

Eine Sammlung ist eine gewöhnliche Aktivität: `aktivitaet_anlegen(kurs, abschnitt_id, typ: "qbank", name)`. Das Werkzeug gehört zum Skill `moodle`, der Auftrag aber hierher — du rufst es selbst auf, statt den Nutzer weiterzuschicken.

**Erst nachsehen, dann anlegen.** `fragensammlungen(kurs)` zeigt, was es gibt. Sinnvoll ist eine eigene Sammlung je Fach, Lernfeld oder Jahrgang; mehr als eine Handvoll wird unübersichtlich, und die Feingliederung gehört ohnehin in Kategorien. Für ein einzelnes Thema reicht fast immer eine **Kategorie in der geteilten Sammlung** des Kurses.

**Der Name gehört in den Plan, der Abschnitt nicht:** Moodle legt jede Fragensammlung im allgemeinen Abschnitt ab, einerlei welche `abschnitt_id` du mitgibst (das Werkzeug verlangt sie trotzdem, weil jede andere Aktivität sie braucht). Ein Name, der die Reichweite nennt („Fragen LF 3"), ist besser als einer, der an eine Lernsituation gebunden ist: Die Sammlung soll länger leben als der Anlass.

**Was mit einer Sammlung nicht geht:** Sie steht nicht in der Kursstruktur, also zeigt `kurs_uebersicht` sie nicht, und verbergen, verschieben und duplizieren gibt es für sie nicht. `loeschen(kurs, cmid, name)` geht — mit Freigabe, mit Namensprüfung und mit allen Kategorien und Fragen darin.

**Nicht verwechseln mit der Kategorie.** Sagt der Nutzer „Fragensammlung", „Fragenpool" oder „Fragenkatalog", meint er diese Aktivität. Eine Kategorie anzulegen und das als erledigt zu melden, ist kein Ersatz: Er sucht die Sammlung später in der Liste seiner Fragensammlungen und findet sie nicht. Hältst du die Kategorie für den besseren Weg, schlag sie vor und begründe es — entscheiden tut er.

## Kategorien: die Gliederung innerhalb einer Sammlung

Kategorien sind der Ort für die thematische Ordnung. Sie sind **beliebig
schachtelbar**. `fragen_lesen(sammlung)` nennt sie mit id, Name und Anzahl —
die Anzahl ist nützlich, um nach einem Import nachzuzählen (die App tut das
ohnehin).

```
kategorie_anlegen(sammlung, name: "Lernfeld 3 – Schutzmaßnahmen",
                  eltern: <Kategorie-id oder Name, optional>,
                  beschreibung: "<p>Fragen zu LF 3.</p>" (optional))
```

Ohne `eltern` kommt sie auf die oberste Ebene der Sammlung. Die Antwort nennt
die neue id — die brauchst du für den Import und für Zufallsfragen.

## Fragen thematisch sortieren

Der saubere Weg ist, **Fragen gleich in der richtigen Kategorie anzulegen**.
Beim Import gibst du die Zielkategorie mit; es entsteht kein Zwischenzustand,
der später aufgeräumt werden müsste.

Für eine Neuordnung von Grund auf: Kategorien anlegen, dann die Fragen je
Kategorie als eigenes XML importieren. Das hat den Vorteil, dass du die
Struktur vorher mit dem Nutzer abstimmen kannst.

### Nachträgliches Verschieben: nicht über die App

In Moodle geht es so: Fragen ankreuzen → „Mit Auswahl" → „Verschieben
nach …". Auf der Testinstanz **öffnete sich dieser Dialog nicht**: Das
JavaScript-Modul `qbank_bulkmove/bulk_move` ließ sich nicht laden („No define
call"), während andere Module einwandfrei luden. Geht der Dialog auch bei der
Lehrkraft nicht auf, ist das etwas für die Administration — meist genügt ein
Leeren der Caches.

Die App kann Fragen nicht verschieben; ein Umweg über
Formularparameter trägt nicht (sechs Varianten geprüft), und das
Bearbeitungsformular einer **bestehenden** Frage hat kein Kategoriefeld. Sag
dem Nutzer offen, dass das Verschieben in Moodle von Hand erfolgen muss, und
biete bei vielen Fragen den Weg über
Kategorie-anlegen-und-neu-importieren an.

**Kein Ausweg ist Export-und-Neuimport für bestehende Fragen**, die schon in
Tests stecken: Dabei entstehen neue Fragen mit neuen ids. Tests, die auf die
alten verweisen, zeigen weiter die alten — und am Ende hat man alles doppelt.

## Fragen-Versionen

Ab Moodle 4 sind Fragen **versioniert**. Beim Bearbeiten entsteht eine neue
Version; die alte bleibt erhalten. Ein Testplatz verweist entweder auf „Immer
die neueste" (die Vorgabe) oder auf eine feste Version.

Das ist der Grund, warum das Ändern einer benutzten Frage weniger gefährlich
ist als früher: Bereits abgelegte Versuche behalten die Version, mit der sie
gerechnet wurden. Trotzdem gilt: Ist ein Test schon gelaufen, vorher fragen.

Der Verlauf einer Frage zeigt auch, **wer** eine Version angelegt hat — die
App liest ihn deshalb nicht.

## Status „Bereit" und „Entwurf"

Jede Frage hat einen Status. Entwürfe erscheinen nicht in Zufallsauswahlen.
Für halbfertige Fragen ist das der richtige Platz — besser, als sie fertig
aussehen zu lassen. Den Status setzt die Lehrkraft in Moodle.
