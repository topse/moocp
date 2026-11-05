# E16 Die Druckaufbereitung wird erkannt, nicht eingestellt

Status: gilt. Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md).

## Entscheidung

Ob eine Instanz die Druckaufbereitung „Aufgabenblatt-Druck“ hat (Skript unter „Zusätzliches HTML“, CSS im Theme), sieht die App beim Anmelden am Quelltext der Anmeldeseite, ohne eigene Anfrage; `status` meldet es, und der Skill `moodle` richtet sich danach (`references/drucken.md`). Das Wissen darüber steht anonymisiert im Skill und bleibt ungenutzt, wo es die Druckaufbereitung nicht gibt.

## Verworfen

Ein Haken in der App (A9: ermitteln statt voraussetzen) und private Profile, die Dateien über die Skills legen (Doppelungen, die niemand mitpflegt).
