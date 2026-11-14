// Gilt für jede Testdatei unter test/. Die Tests brauchen den Testbetrieb (die
// Testdoppel für Moodle laufen über MoodleZugang.fuerTest, die Tests des
// Testbetriebs binden Testzugänge von Hand). Den Bauschalter
// `--dart-define=MOOCP_TESTBETRIEB=true` müsste sonst jeder Aufruf von
// `flutter test` mitbringen; so läuft ein einfaches `flutter test`. Tests, die
// den Normalbetrieb ohne Schalter prüfen, legen ihn selbst um
// (test/testschalter_test.dart).

import 'dart:async';

import 'package:moocp/anmeldedaten.dart';
import 'package:moocp/plattform/linux_schluesselbund.dart';
import 'package:moocp/testschalter.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  testbetriebFuerTestsSetzen(true);
  // Die Tests ersetzen den sicheren Speicher durch einen Kanal; den Secret
  // Service von Linux gibt es auf dem Testrechner nicht (anmeldedaten.dart).
  Anmeldedaten.schluesselbundPruefer = () async => Schluesselbund.bereit;
  Anmeldedaten.schluesselbundEntsperrer = () async => Schluesselbund.bereit;
  await testMain();
}
