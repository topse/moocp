// Die Protokollansicht: der neueste Eintrag unten; sie folgt nur, solange sie
// ganz unten steht.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/main.dart';
import 'package:moocp/protokoll.dart';

void main() {
  late Protokoll prot;
  late ScrollPosition pos;
  var nr = 0;

  Future<void> ansicht(WidgetTester tester) async {
    prot = Protokoll();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(height: 400, child: ProtokollAnsicht(prot)))));
    pos = tester.widget<ListView>(find.byType(ListView)).controller!.position;
  }

  Future<void> neu(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      prot.eintrag(Art.info, 'Eintrag ${nr++}');
    }
    await tester.pumpAndSettle();
  }

  testWidgets('Protokollansicht: folgt unten, bleibt oben stehen', (tester) async {
    await ansicht(tester);
    await neu(tester, 60);
    expect(prot.eintraege.last.text, 'Eintrag ${nr - 1}');
    expect(pos.maxScrollExtent, greaterThan(0));
    expect(pos.pixels, pos.maxScrollExtent, reason: 'unten: folgt, auch wenn viele auf einmal kommen');

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    final stand = pos.pixels;
    final ende = pos.maxScrollExtent;
    expect(stand, lessThan(ende));
    // Die Zeile, die gerade gelesen wird: mitten in der Liste.
    final mitte = tester.getCenter(find.byType(ListView)).dy;
    final gelesen = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((t) => t.data!)
        .firstWhere((t) => (tester.getRect(find.text(t)).top - mitte).abs() < 24);
    final ort = tester.getTopLeft(find.text(gelesen));
    await neu(tester, 5);
    expect(pos.maxScrollExtent, greaterThan(ende));
    expect(pos.pixels, stand, reason: 'hochgescrollt: die Ansicht bleibt, wie sie ist');
    expect(tester.getTopLeft(find.text(gelesen)), ort);

    await tester.drag(find.byType(ListView), const Offset(0, -100000));
    await tester.pumpAndSettle();
    await neu(tester, 5);
    expect(pos.pixels, pos.maxScrollExtent, reason: 'wieder unten: folgt wieder');

    await tester.tap(find.text('Leeren'));
    await tester.pumpAndSettle();
    await neu(tester, 60);
    expect(pos.pixels, pos.maxScrollExtent, reason: 'nach dem Leeren: folgt');
  });

  // Fiele vorn etwas heraus, rückte die angehaltene Ansicht weiter.
  test('Protokoll: behält alles, bis geleert wird', () {
    final p = Protokoll();
    for (var i = 0; i < 2000; i++) {
      p.eintrag(Art.info, 'Eintrag $i');
    }
    expect(p.eintraege.length, 2000);
    expect(p.eintraege.first.text, 'Eintrag 0');
    p.leeren();
    expect(p.eintraege, isEmpty);
  });
}
