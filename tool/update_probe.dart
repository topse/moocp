// Einmalige Probe der Update-Prüfung gegen das echte GitHub, zum
// Durchspielen. Liegt unter tool/, läuft also nicht bei `flutter test`:
//
//   flutter test tool/update_probe.dart
//
// Sie fragt das neueste Release ab, so wie die App es tut, und lädt die
// Datei einmal herunter, um Umleitung, Größe und Prüfsumme zu prüfen. Die
// Datei wird danach wieder gelöscht.

import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/protokoll.dart';
import 'package:moocp/update/update.dart';

void main() {
  test('Abfrage und Download gegen das echte Release', () async {
    final protokoll = Protokoll();
    final update = Update(protokoll);

    // Eine Fassung, die es sicher nicht mehr gibt: Dann meldet die Prüfung
    // das neueste Release als neu.
    final neu = await update.pruefen('0.0.1');
    expect(neu, isNotNull, reason: 'GitHub hat kein neueres Release gemeldet');
    // ignore: avoid_print
    print('\n--- gefunden ---\n'
        'Fassung:    ${neu!.fassung}\n'
        'Datei:      ${neu.dateiname}\n'
        'Adresse:    ${neu.datei}\n'
        'Größe:      ${neu.groesse}\n'
        'Prüfsumme:  ${neu.pruefsumme}\n'
        'Beschreibung (Anfang): ${neu.beschreibung.split("\n").first}');

    // Dieselbe Fassung darf nicht als Update gelten.
    expect(await update.pruefen(neu.fassung), isNull);
    // Eine höhere auch nicht.
    expect(await update.pruefen('99.0.0'), isNull);

    var zuletzt = -1;
    final datei = await update.herunterladen(neu, (geladen, gesamt) {
      final prozent = gesamt == null ? -1 : (geladen * 10 ~/ gesamt) * 10;
      if (prozent != zuletzt) {
        zuletzt = prozent;
        // ignore: avoid_print
        print('  geladen: $prozent %');
      }
    });
    // ignore: avoid_print
    print('--- geladen ---\n${datei.path} (${datei.lengthSync()} Byte)');
    expect(datei.existsSync(), isTrue);
    expect(datei.lengthSync(), neu.groesse);
    datei.deleteSync();

    // ignore: avoid_print
    print('\n--- Protokoll ---');
    for (final e in protokoll.eintraege) {
      // ignore: avoid_print
      print('${e.art.name}: ${e.text}');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
