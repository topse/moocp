/* Gemeinsamer Block der Skills moodle und lernsituation: wie ein interaktives
 * Element gebaut wird. build.py setzt ihn in references/elemente.md beider
 * Skills. Wofür sich eins anbietet, steht in einsatz.md. Was die App erzwingt
 * (Rahmen, Kopf, Prüfungen) und warum, steht in lib/moodle/elemente.dart;
 * dieselben Prüfungen am Entwurf im Prüfskript des Skills lernsituation
 * (element_fehler) -- wer eine ändert, ändert alle drei.
 */
# Interaktive Elemente bauen

Wann ein Element passt, steht in `references/einsatz.md`, „Interaktive Elemente". Hier steht, wie es gebaut wird. Wie es aussieht und was es tut, ist offen — ein Element kann sein, was sich im Browser bauen lässt und an der Stelle hilft. Bindend ist nur, was hier über Rahmen, Datei und Prüfen steht: Daran hängen Abschottung und Datenschutz.

## Wie ein Element in die Seite kommt

Ein Element ist eine eigene HTML-Datei in `dateien/` des Ordners, eingebunden wie ein Bild:

```html
<p>Verschiebe die Regler und beobachte, wie sich der Strom ändert, wenn Spannung oder Widerstand steigen.</p>
<iframe sandbox="allow-scripts" src="@@PLUGINFILE@@/ohmsches-gesetz.html" title="Ohmsches Gesetz ausprobieren" class="w-100 border-0" height="220"></iframe>
```

- **`sandbox="allow-scripts"`, genau so.** Der Rahmen schottet das Element ab: kein Zugriff auf die Moodle-Seite, die Sitzung, Cookies oder den Speicher des Browsers. Ohne `sandbox` oder mit weiteren Rechten weist die App das Schreiben ab.
- **`title`** sagt Screenreadern, was das Element ist. **`height`** in Pixeln, fest: Der Rahmen passt sich nicht an. Am schmalen Bildschirm scrollt man im Element; plane es so, dass es auch schmal noch geht.
- **Der Satz davor** sagt, was man mit dem Element tut. Gedruckt bleibt nur er.
- **Kein `srcdoc`, kein `<script>` und keine `on…`-Attribute im Text der Seite.** Der Moodle-Editor löscht `srcdoc` beim nächsten Bearbeiten, und Code im Text liefe ohne Abschottung bei jedem Betrachter, auch bei der Lehrkraft. Die App weist beides ab; was schon in Moodle stand, bleibt, und die Übersicht beim Lesen nennt es.

Elemente stehen in Textseite, Buchkapitel, Textfeld und den Beschreibungen von Abschnitten und Aktivitäten. In Fragen und Wikis nicht: Für Interaktives in einer Frage gibt es STACK mit Zeichnungen (Skill `moodle-fragen`).

## Die Datei

Ein vollständiges Dokument mit `<head>`. **Den Anfang des Kopfs setzt die App**, beim Anlegen und immer, wenn sich die Datei ändert: eine Content-Security-Policy, die jedes Laden und Senden sperrt außer vom eigenen Moodle, einen Wächter, der die Datei anhält, wenn jemand sie außerhalb des Rahmens öffnet, das Stylesheet des Themes und die Meldung von Fehlern ans Bildschirmfoto. Du schreibst diesen Teil nicht und änderst ihn nicht; in einer gelesenen Datei steht er zwischen `<!-- moocp: … -->` und `<!-- /moocp -->` — lass ihn stehen.

```html
<!DOCTYPE html>
<html lang="de">
<head>
<title>Ohmsches Gesetz ausprobieren</title>
<style>
  body { margin: 0; padding: .5rem; background: transparent; }
  .zeile { display: grid; grid-template-columns: 9rem 1fr 6rem; gap: .5rem; align-items: center; }
</style>
</head>
<body>
<div class="zeile">
  <label for="u">Spannung U</label>
  <input id="u" type="range" class="form-range" min="1" max="24" step="0.5" value="12">
  <output id="u-wert" for="u"></output>
</div>
<div class="alert alert-info" id="ergebnis" role="status"></div>
<script>
(function () {
  var u = document.getElementById('u');
  function zahl(x, stellen) {
    return x.toLocaleString('de-DE', { minimumFractionDigits: stellen, maximumFractionDigits: stellen });
  }
  function rechnen() {
    var U = parseFloat(u.value), I = U / 220 * 1000;
    document.getElementById('u-wert').textContent = zahl(U, 1) + ' V';
    document.getElementById('ergebnis').textContent = 'Strom I = ' + zahl(I, 1) + ' mA';
  }
  u.addEventListener('input', rechnen);
  rechnen();
})();
</script>
</body>
</html>
```

Was darin gilt:

- **Nichts von außen.** Kein `fetch`, keine Bibliothek, keine Schrift, kein Bild und kein Video von einem anderen Rechner: Jeder Aufruf verriete die IP-Adresse der Lernenden, und die Policy im Kopf sperrt es ohnehin. Bilder zeichnest du als SVG im Element (Stil wie in `references/zeichnungen.md`), Daten stehen im Skript. Ein Verweis gehört in den Text der Seite, nicht ins Element. Die App prüft das vor dem Schreiben und bricht mit einer Meldung ab, damit kein Element still scheitert.
- **Nichts merken.** Kein `localStorage`, keine Cookies: Der Rahmen sperrt sie, und ein Element ist zum Ausprobieren da, nicht zum Sichern.
- **Aussehen vom Theme.** Das Stylesheet des Moodle liegt im Element, also gelten die Klassen der Seite: Knöpfe mit `btn btn-primary` oder `btn btn-secondary`, Felder mit `form-control`, Regler mit `form-range`, Rückmeldungen in Kästen mit `alert` (`references/html.md`). Ein `<style>`-Block im Element trägt nur die Anordnung — Raster, Zeichenfläche, Abstände —, keine Farben und Schriften. Die Regel „keine `style`-Attribute" gilt für die Seite; das Element ist ein eigenes Dokument, und ohne Gerüst ginge keine Zeichenfläche.
- **Deutsch rechnen.** Zahlen mit Komma annehmen und anzeigen: `parseFloat("1,5")` ergibt 1, also vor dem Rechnen das Komma durch einen Punkt ersetzen und zur Anzeige `toLocaleString('de-DE')` nehmen. Zahlenfelder bekommen `inputmode="decimal"`, damit das Handy die Zifferntastatur zeigt.
- **Maus, Finger, Tastatur.** Ziehen mit Pointer-Ereignissen (`pointerdown`, `pointermove`, `pointerup`), die Maus und Finger gleich behandeln; bedienbares als `<button>` oder Formularfeld, damit es auch mit der Tastatur geht.
- **Würfeln vorwärts.** Würfelt das Element Aufgaben, baue sie aus dem Ergebnis rückwärts zusammen, statt zu würfeln, bis es passt, und schließe triviale Fälle aus (Faktor 1, Ergebnis 0, ein Bruch, der schon gekürzt ist, wenn Kürzen geübt werden soll). Geh alle möglichen Würfe einmal durch, bevor das Element in den Kurs kommt; seltene Fälle fallen sonst erst im Unterricht auf.
- **Gerecht prüfen.** Antworten wertgleich annehmen (0,5 und 1/2), das Kürzen nur verlangen, wenn es Lernziel ist — dann drei Rückmeldungen: richtig, richtig aber nicht gekürzt, falsch. Wo mehrere Lösungen richtig sind, prüfe die geforderte Eigenschaft, nicht eine Musterlösung.
- **Nicht vorwegnehmen.** Was das Element live anzeigt, löst die Aufgabe nicht schon: Beim Zeichnen eines Rechtecks zeigt es die Seitenlängen, nicht die gesuchte Fläche.

## Prüfen und übergeben

Steht das Element auf einer Textseite oder in einem Buchkapitel, nimm vor dem Sichtbarschalten ein `bildschirmfoto` auf: Es zeigt das Element im Anfangszustand, prüft, dass `height` reicht, und meldet Fehler im Skript als „Fehler im Element: …". Klicken kann es nicht. Was die Lehrkraft einmal ausprobieren sollte — die Knöpfe, einen Grenzfall —, sagst du im Bericht in einem Satz. Für ein Element in einem Textfeld oder einer Beschreibung gibt es kein Bildschirmfoto; dort sieht die Lehrkraft nach, und du sagst ihr, worauf.

## Lesen und ändern

Ein Element kommt mit seiner Seite: Das Lesewerkzeug legt die Datei in `dateien/`, und die Übersicht nennt sie „als interaktives Element eingebunden". Geändert wird die Datei dort, dann `aendern`; die Freigabe zeigt ihre Zeilen wie die einer Seite. Bearbeitet die Lehrkraft die Seite im Moodle-Editor, bleibt das Element erhalten.

Nennt die Übersicht einen **leeren Rahmen** oder einen Rahmen **mit `srcdoc`**, ist ein Element verloren oder geht beim nächsten Bearbeiten im Editor verloren. Nennt sie eine Elementdatei **ohne den Kopf der App**, stammt sie von anderswo. In allen drei Fällen gehört der Neubau als Element nach dieser Anleitung in den Plan.
