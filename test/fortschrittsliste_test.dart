import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/fortschrittsliste.dart';

String _eintrag(int id, String text, List<String> aktionen) => '<li><label>$text</label>'
    '<a href="/mod/checklist/edit.php?id=7&itemid=$id&action=edititem">bearbeiten</a>'
    '${aktionen.map((a) => '<a href="/mod/checklist/edit.php?id=7&sesskey=x&itemid=$id&action=$a">$a</a>').join()}</li>';

void main() {
  // Aufbau wie gemessen: das äußerste <ol> trägt checklist-extendedit, jede
  // Einrückstufe ist ein weiteres <ol class="checklist"> darin.
  final seite = '<html><body><ol class="checklist checklist-extendedit">'
      '${_eintrag(427, 'ZZ Messaufbau skizzieren', ['makeoptional', 'indentitem'])}'
      '<ol class="checklist">${_eintrag(428, 'ZZ Messwerte aufnehmen', ['makeheading', 'indentitem', 'unindentitem'])}'
      '<ol class="checklist">${_eintrag(430, 'ZZ Zweite Stufe', ['makerequired', 'unindentitem'])}</ol></ol>'
      '${_eintrag(429, 'ZZ Ergebnis vergleichen', ['makeoptional'])}'
      '</ol></body></html>';

  test('Einträge: Tiefe aus der Verschachtelung, Zustand aus den angebotenen Aktionen', () {
    final l = eintraegeAuswerten(seite);
    expect([for (final e in l) '${e.id}:${e.tiefe}:${e.zustand}:${e.text}'], [
      '427:0:pflicht:ZZ Messaufbau skizzieren',
      '428:1:optional:ZZ Messwerte aufnehmen',
      '430:2:ueberschrift:ZZ Zweite Stufe',
      '429:0:pflicht:ZZ Ergebnis vergleichen',
    ]);
  });

  test('Listenaktionen werden zurückgelesen, nicht nur abgeschickt', () {
    final l = eintraegeAuswerten(seite);
    final eingerueckt = [
      for (final e in l) e.id == 427 ? Eintrag(e.id, e.text, e.zustand, 1, e.link) : e,
    ];
    expect(listenaktionPruefen('einruecken', 427, l, eingerueckt), 'ausgeführt');
    expect(listenaktionPruefen('einruecken', 427, l, l), contains('NICHT ausgeführt (Tiefe 0 -> 0)'));
    expect(listenaktionPruefen('optional', 428, l, l), 'ausgeführt');
    expect(listenaktionPruefen('runter', 427, l, [l[1], l[0], l[2], l[3]]), 'ausgeführt');
    expect(listenaktionPruefen('loeschen', 429, l, l.sublist(0, 3)), 'gelöscht');
  });
}
