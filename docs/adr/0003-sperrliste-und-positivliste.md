# E3 Sperrliste und Positivliste, beide im Code

Status: gilt. Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md).

## Entscheidung

Die Positivliste (`lib/moodle/moodle_zugang.dart`) ist die eigentliche Grenze; die Sperrliste (`lib/moodle/sperrliste.dart`) greift davor, damit eine zu weit gefasste Positivregel nichts Personenbezogenes durchlässt. Die einzige Ausnahme der Sperrliste (Definition von Bewertungsschemata) hebt nur die Notenregel auf. Eine Adresse kommt nur zusammen mit dem Werkzeug in die Positivliste, das sie braucht – nie eine Freigabe ohne Aufrufer. `test/sperrliste_test.dart` hält beide Listen gegeneinander.

Ändert sich eine der Listen (oder `lib/moodle/browserliste.dart`), zieht die Zusammenfassung „Sperrliste und Positivliste“ in der README im selben Zug nach.
