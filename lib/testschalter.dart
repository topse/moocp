// Der Bauschalter des Testbetriebs (Entwickler-Werkzeug, docs/agents/testing.md).
//
// Der Testbetrieb liest über Umgebungsvariablen eine Datei mit Zugangsdaten und
// gibt in gebundenen Testkursen Freigaben automatisch. Das darf in keiner App
// laufen, die eine Lehrkraft benutzt. `kDebugMode` allein trennt das nicht:
// Auf dem Mac ist der Debug-Bau der normale Bau (moocp-starten.command). Darum
// kommt ein zweiter Schalter dazu, der zur Bauzeit gesetzt wird und nicht zur
// Laufzeit -- eine Umgebungsvariable kann ihn nicht umlegen:
//
//   flutter run -d macos --dart-define=MOOCP_TESTBETRIEB=true
//
// tool/mac_bau.sh (und über sie tool/neustart.sh auf dem Mac) und tool/dev.dart
// setzen ihn nur, wenn die Testzugangs-Variablen gesetzt sind;
// `moocp-starten.command` nie, und es startet auch keinen Bau, der ihn hat
// (tool/mac_bau.sh legt dafür neben dem Bau die Marke `testbetrieb` ab). Ohne
// den Schalter liest die App die Variablen nicht einmal.
//
// Eigene Datei ohne Abhängigkeiten, weil freigabe.dart, testzugang.dart und
// moodle/moodle_zugang.dart sie gemeinsam brauchen und sich sonst im Kreis
// importierten.

import 'package:flutter/foundation.dart';

const bool _testbetriebGebaut = bool.fromEnvironment('MOOCP_TESTBETRIEB');

bool _testbetriebInTests = false;

/// Schaltet den Testbetrieb für die Dauer eines Tests ein oder aus. Nur
/// Testcode ruft das auf (test/flutter_test_config.dart und Tests, die den
/// Normalbetrieb prüfen); die App selbst setzt es nie, und aus der Umgebung
/// lässt es sich nicht erreichen. Im Release-Bau ist es ohne Wirkung, weil
/// [testbetriebAktiv] dort schon an `kDebugMode` scheitert.
@visibleForTesting
void testbetriebFuerTestsSetzen(bool an) => _testbetriebInTests = an;

/// Ob der Testbetrieb in dieser App laufen darf: nur im Debug-Bau und nur,
/// wenn er mit `--dart-define=MOOCP_TESTBETRIEB=true` gebaut ist. Jede Stelle,
/// die den Testbetrieb freischaltet, fragt das hier und sonst nichts.
bool get testbetriebAktiv =>
    kDebugMode && (_testbetriebGebaut || _testbetriebInTests);
