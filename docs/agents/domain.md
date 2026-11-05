# Domain-Doku

Wie Skills und Sitzungen die Fachsprache und die Entscheidungen dieses Projekts lesen.

## Vor dem Arbeiten lesen

- **`GLOSSARY.md`** im Wurzelverzeichnis: Begriffe der Arbeit an Moodle-Kursen und ihrer Sicherung. Die dortigen Wörter in Issues, Tests, Plänen und Vorschlägen verwenden; was dort unter _Vermeiden_ steht, nicht benutzen.
- **`docs/adr/`**: die Entscheidung zum betroffenen Bereich lesen, bevor etwas vorgeschlagen wird, was sie berührt. Die Nummer einer ADR ist die E-Nummer in der CLAUDE.md und in Kommentaren des Quelltexts (E21 = `0021-…`).

Ein Kontext, keine `CONTEXT-MAP.md`.

## Aufbau

```
/
├── CLAUDE.md             Regeln für die KI: Dokumentation, Anforderungen (A1–A11), Index der Entscheidungen (E1–E34), Arbeitsregeln
├── AGENTS.md             dünner Einstieg für Codex
├── GLOSSARY.md           Fachsprache
├── installer/CLAUDE.md   Regeln für den Installer
├── skills/CLAUDE.md      Regeln für die Pflege der Skills
├── docs/adr/             Entscheidungen E1–E34 (E30 entfällt), eine Datei je Entscheidung
└── docs/agents/          Arbeitsregeln: Testen, Issue-Tracker, Triage-Labels, Domain
```

## Neue Entscheidung

Neue Entscheidungen bekommen die nächste freie Nummer (`0035-…`; die Nummer 30 bleibt unbesetzt), im Aufbau der vorhandenen ADRs: Kopf mit Status, **Entscheidung**, **Verworfen**. Der Kopf enthält keine Angaben zum Verlauf (Version, Datum), nur „Status: gilt“ oder „ersetzt durch …“ und Querverweise; auch sonst gilt Regel 4 der Dokumentationsregeln in der CLAUDE.md: kein Hergang, nur was gilt und warum. In der CLAUDE.md steht dazu eine Zeile im Index, die alle Regeln trägt, nach denen die KI handeln muss (zwei bis vier Sätze, bei umfangreichen Entscheidungen mehr); Begründung, Messungen und Verworfenes stehen nur in der ADR. Eine ADR, die eine frühere ersetzt, nennt sie und setzt deren Status auf „ersetzt durch …“.

## ADR-Konflikte melden

Widerspricht ein Vorschlag einer ADR oder einer Anforderung, das offen benennen statt still zu überschreiben.
