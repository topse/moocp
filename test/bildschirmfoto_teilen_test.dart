// Bildschirmfotos langer Inhalte: wo die App sie teilt (teilen in
// lib/moodle/bildschirmfoto.dart). Geschnitten wird zwischen Zeilen und
// Elementen, nie durch eins, das ganz in ein Bild passt.
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/bildschirmfoto.dart';

/// Zeilen von [hoch] Pixeln mit [abstand] dazwischen, von [ab] bis [bis].
List<(double, double)> zeilen(double ab, double bis, {double hoch = 20, double abstand = 4}) => [
      for (var y = ab; y + hoch <= bis; y += hoch + abstand) (y, y + hoch),
    ];

/// Ob der untere Rand von [t] durch eine der [sperren] geht.
bool schneidet(Teil t, List<(double, double)> sperren) {
  final u = t.oben + t.hoehe;
  return sperren.any((s) => s.$1 < u && u < s.$2);
}

void main() {
  test('Kurzer Inhalt: ein Teil', () {
    expect(teilen(900, zeilen(0, 900)), [(oben: 0.0, hoehe: 900.0, zerschnitten: false)]);
  });

  test('Langer Text: jeder Teil endet zwischen zwei Zeilen, keiner ist zu hoch, nichts fehlt', () {
    final s = zeilen(0, 5000);
    final t = teilen(5000, s);
    expect(t.length, greaterThan(3));
    for (final x in t) {
      expect(x.hoehe, lessThanOrEqualTo(1400));
      expect(x.zerschnitten, isFalse);
      expect(schneidet(x, s), isFalse, reason: 'Schnitt bei ${x.oben + x.hoehe}');
    }
    for (var i = 1; i < t.length; i++) {
      expect(t[i].oben, t[i - 1].oben + t[i - 1].hoehe, reason: 'lückenlos, ohne Überlappung');
    }
    expect(t.last.oben + t.last.hoehe, 5000);
  });

  test('Ein Bild, das in einen Teil passt, kommt ganz in den nächsten', () {
    final s = [...zeilen(0, 1000), (1000.0, 2200.0), ...zeilen(2210, 3000)];
    final t = teilen(3000, s);
    expect(t.first.oben + t.first.hoehe, 1000, reason: 'vor dem Bild geschnitten');
    expect(t[1].oben, 1000);
    expect(t[1].hoehe, greaterThanOrEqualTo(1200), reason: 'das Bild ganz');
    expect(t.every((x) => !x.zerschnitten), isTrue);
  });

  test('Was sich überlappt, ist eine Sperre: kein Schnitt zwischen einer Formel und der Zeile daneben', () {
    // Zeile 1000..1390, daneben eine Formel 1385..1450: Bei 1385 läge der
    // Schnitt mitten in der Zeile.
    final t = teilen(2000, [(0.0, 100.0), (1000.0, 1390.0), (1385.0, 1450.0)]);
    expect(t.first.oben + t.first.hoehe, 1000);
    expect(t.every((x) => !x.zerschnitten), isTrue);
  });

  test('Ein Element höher als ein Teil: durchschnitten, mit Überlappung, und gemeldet', () {
    final t = teilen(3000, [(0.0, 3000.0)]);
    expect(t.map((x) => (x.oben, x.hoehe, x.zerschnitten)), [
      (0.0, 1400.0, true),
      (1300.0, 1400.0, true),
      (2600.0, 400.0, false),
    ]);
  });

  test('Ein zu hohes Element weiter unten im Teil: erst davor schneiden, dann hindurch', () {
    final t = teilen(3500, [...zeilen(0, 900), (900.0, 3500.0)]);
    expect(t.first.oben + t.first.hoehe, 900);
    expect(t.first.zerschnitten, isFalse);
    expect(t[1].oben, 900);
    expect(t[1].zerschnitten, isTrue);
  });
}
