// Gilt für jede Testdatei unter test/. Die Tests brauchen den Testbetrieb (die
// Testdoppel für Moodle laufen über MoodleZugang.fuerTest, die Tests des
// Testbetriebs binden Testzugänge von Hand). Den Bauschalter
// `--dart-define=MOOCP_TESTBETRIEB=true` müsste sonst jeder Aufruf von
// `flutter test` mitbringen; so läuft ein einfaches `flutter test`. Tests, die
// den Normalbetrieb ohne Schalter prüfen, legen ihn selbst um
// (test/testschalter_test.dart).

import 'dart:async';

import 'package:moocp/testschalter.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  testbetriebFuerTestsSetzen(true);
  await testMain();
}
