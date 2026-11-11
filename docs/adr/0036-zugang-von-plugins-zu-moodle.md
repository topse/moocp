# E36 Zugang von Plugins zu Moodle

Status: gilt. Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md). Ergänzt E3 und fasst A1 neu; was ein Plugin ist, steht in E35.

## Entscheidung

**Die Zusage.** Personenbezogene Daten erreichen nie die KI. Das gilt unverändert, für die App wie für jedes Plugin. Die eingebauten Werkzeuge lesen personenbezogene Daten weiterhin gar nicht; Positivliste und Sperrliste der App (E3) bleiben, wie sie sind, und werden für kein Plugin geweitet.

**Ein Plugin spricht Moodle nur durch die App an.** Es bekommt nie das Sitzungscookie und meldet sich nie selbst an (A2). Jede Anfrage stellt die App mit der Sitzung des Instanzprofils, über das der Aufruf kam, und jede steht im Protokoll (A4).

**Zwei Arten von Adressen.**

- Was die Positivliste der App erlaubt, darf auch ein Plugin, zu denselben Bedingungen wie die eingebauten Werkzeuge: Sperrliste, Freigabe nach Stufe (E20), Protokoll.
- Was darüber hinausgeht, sind **Zusatzadressen**. Ein Plugin nennt sie vorab in seiner Beschreibungsdatei: je ein Adressmuster, die Angabe „lesen“ oder „schreiben“ und ein Grund in einem Satz. Die Lehrkraft stimmt der Liste mit der Version des Plugins zu (E35). Zur Laufzeit lehnt die App ohne Dialog ab, was nicht auf dieser Liste oder der Positivliste steht. Zusatzadressen heben für das Plugin, das sie angemeldet hat, die Sperrliste auf – nur für dieses, nie für die eingebauten Werkzeuge oder ein anderes Plugin.

So hat jedes Plugin seine eigene Positivliste, die sich vor der Installation nachlesen lässt, und die der App bleibt eng.

**Für jedes Plugin gesperrt** bleiben der Adminbereich (A9), die Anmeldung und alle Seiten, die Passwort oder Zugangsdaten betreffen.

**Schreiben über eine Zusatzadresse** verlangt immer eine Freigabe in der App, auf jeder Stufe. Das Plugin liefert, was der Dialog zeigt. Zurücklesen und das Urteil `verified` (A3) sind dabei Sache des Plugins: Die App kann den Inhalt fremder Formulare nicht beurteilen.

**Lauf.** Eine lesende Zusatzadresse funktioniert nur innerhalb eines Laufs, den das Plugin mit der Aktivität anmeldet, um die es geht. Ob eine Zusatzadresse personenbezogene Daten liefert, gibt das Plugin nicht an: Zusatzadressen heben die Sperrliste auf, also ist hinter jeder mit Namen zu rechnen. Die App ermittelt den Kurs selbst aus der Aktivität, lehnt jede spätere Anfrage ab, deren Adresse eine andere Kurs- oder Aktivitätsnummer trägt, und liest selbst die Namen der Teilnehmenden des Kurses – zu dem einen Zweck, sie zu sperren.

**Letzte Sperre.** Die Prüfung läuft immer, nicht nur während eines Laufs: Jede Antwort eines Plugins an die KI prüft die App gegen alle Namen, die sie seit ihrem Start für dieses Plugin geladen hat. So fällt auch auf, was versehentlich oder nach dem Ende eines Laufs hinausginge. Bei einem Treffer geht die Antwort nicht hinaus, die Lehrkraft wird gewarnt, und die KI erfährt nur, dass gesperrt wurde. Die Namen bleiben im Arbeitsspeicher der App, bis sie beendet wird, und stehen in keinem Protokoll und keiner Datei. Arbeitet ein Plugin ohne Moodle mit Personen, kann es der App selbst Namen zum Sperren nennen.

Die Prüfung der App ist bewusst einfach: Vor- und Nachname, ohne Rücksicht auf Groß- und Kleinschreibung und auf die Schreibweise von Umlauten. Sie ist die letzte Sperre, nicht die erste; Tippfehler, Dateiformate und alles Weitere fängt das Plugin ab, das für seine Datenwege einsteht (E35).

## Verworfen

Die Positivliste der App um das zu erweitern, was Plugins brauchen (sie müsste für jedes denkbare Plugin passen und wäre keine Grenze mehr). Benannte Funktionen für personenbezogene Daten im Code der App, je Zweck eine (jedes neue Plugin bräuchte eine neue Version der App, und die App trüge Wissen über Seiten, die sie selbst nie nutzt). Zustimmung je Adresse beim ersten Zugriff (die Lehrkraft müsste mitten in der Arbeit eine Adresse beurteilen, die sie nicht lesen kann, und ein Plugin könnte zur Laufzeit beliebige Adressen erfragen, auch untergeschobene). Den Kurs eines Laufs aus den Adressen der Anfragen zu erraten (ein Datei-Download trägt keinen Kurs). Die Sperre der Namen allein dem Plugin zu überlassen (ein durchgerutschter Name ist der schwerste Fehler; die Prüfung in der App hängt nicht an der Qualität fremden Codes).
