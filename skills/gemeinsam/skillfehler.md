## Wenn der Fehler im Skill oder in der App steckt

Stimmt etwas an diesem Skill oder an einem Werkzeug der App nicht — ein
beschriebener Ablauf, der ins Leere läuft, eine Vorlage, die sich
widerspricht, ein Werkzeug, das `verified: true` meldet und nichts bewirkt
hat —, dann **melde das dem Nutzer in weitergabefähiger Form**. Beides wird im
Projekt moocp gepflegt; der Nutzer kann den Befund nur weitergeben, wenn
er vollständig ist.

**Repariere den Skill nicht selbst.** Du arbeitest aus einer installierten
Kopie unter `~/.claude/skills/`; sie wird beim nächsten Bau überschrieben.

### Was gemeldet gehört

| Melden | Nicht melden |
|---|---|
| Ein dokumentierter Ablauf führt nicht zum Ziel | Der Nutzer hat etwas anderes gemeint |
| `verified: false`, obwohl richtig geschrieben wurde | Moodle war einmalig langsam |
| Die Sperre schlägt an, wo sie nicht sollte | Sie schlägt an, wo sie soll |
| Ein Werkzeug fehlt, das der Ablauf voraussetzt | Ein Wunsch nach einem neuen Feature (das ist ein Lückenbefund) |
| Moodle oder ein Werkzeug verhält sich anders als beschrieben | Eine Rechtefrage des angemeldeten Kontos |

### Form der Meldung

Ein Block am Ende der Antwort, den der Nutzer unverändert weiterreichen kann:

```
SKILLBEFUND
Skill:        @@NAME@@
Betroffen:    <Werkzeug der App, oder Datei des Skills, z. B. references/bearbeiten.md, Abschnitt X>
Erwartet:     <was laut Skill passieren sollte>
Beobachtet:   <was tatsächlich passiert ist, wörtliche Meldung>
Reproduzierbar: ja | nein | einmal aufgetreten
Belegt durch: <Antwort des Werkzeugs, Protokolleintrag>
Umgehung:     <wie du trotzdem weitergekommen bist, oder: keine>
Vermutete Ursache: <nur wenn du eine hast — als Vermutung kennzeichnen>
```

Drei Regeln dazu:

- **Keine personenbezogenen Daten in den Befund.** Keine Namen aus dem Kurs.
- **Trenne Gemessenes von Vermutetem.**
- **Einmal pro Befund, nicht pro Versuch.** Melde am Ende, arbeite mit der
  Umgehung weiter. Nur wenn es keine Umgehung gibt, ist der Befund selbst das
  Ergebnis.
