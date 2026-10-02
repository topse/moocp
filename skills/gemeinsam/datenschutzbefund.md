## Ein Datenschutz-Versuch wiegt schwerer

Die App fragt Seiten und Dateien mit personenbezogenen Daten — Bewertungen,
Abgaben, Versuche, Profile, Protokolle, Beiträge einzelner Personen — gar
nicht erst an. Trifft ihre Sperre, antwortet das Werkzeug mit „Gesperrt
(Datenschutz): …". Das ist **kein** gewöhnlicher Fehler, sondern der schwerste
Befund, den dieser Skill kennt. Nicht weil etwas ausgetreten wäre — die Sperre
hält, und gelesen wird nichts —, sondern weil ein Treffer immer eine von zwei
Nachrichten bedeutet, und beide muss der Nutzer hören:

| Was der Treffer bedeutet | Was der Nutzer daraus machen muss |
|---|---|
| Der Ablauf braucht etwas, das diese App bewusst nicht tut | Ein Teil der Aufgabe bleibt offen. Er muss ihn selbst erledigen — und wissen, dass er offen ist. |
| Die Sperre trifft eine harmlose Seite | Die Liste ist zu weit und gehört nachgebessert. |

**Melde das ungefragt und am Ende der Antwort**, auch wenn du auf einem anderen
Weg weitergekommen bist:

```
DATENSCHUTZBEFUND
Skill:      @@NAME@@
Werkzeug:   <Werkzeug, bei dem es geschah>
Adresse:    <Pfad aus der Meldung, Parameter nur als Name=…>
Regel:      <Regel aus der Meldung>
Gelesen wurde nichts -- die Sperre hat gehalten.
```

Dazu **einen Satz von dir**: welche der beiden Nachrichten du vermutest.

Zwei Regeln:

- **Keine Parameterwerte.** Nur die Namen (`studentid=…`). Ein Befund, der
  Personendaten sammelt, wäre schlimmer als keiner.
- **Nicht umgehen.** Ein Treffer ist kein Hindernis, das man kreativ löst.
