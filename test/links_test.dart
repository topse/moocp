import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/links.dart';

final basis = Uri.parse('https://moodle.schule.example');

final ziele = [
  LinkZiel(10, 'page', 'SchuCu'),
  LinkZiel(11, 'page', 'Lehrerhandreichung'),
  LinkZiel(12, 'label', 'Handlungssituation'),
  LinkZiel(13, 'page', 'Arbeitsblatt 1: Der Auftrag'),
  LinkZiel(14, 'page', 'Lösung zu Arbeitsblatt 1: Der Auftrag'),
  LinkZiel(15, 'page', 'Hilfe zu Arbeitsblatt 1: Planen'),
  LinkZiel(16, 'page', 'Infoblatt 1: VLAN-Grundlagen'),
  LinkZiel(17, 'assign', 'Arbeitsblatt 12: Abgabe'),
];

String link(int cmid, String text, [String modul = 'page']) =>
    '<a href="https://moodle.schule.example/mod/$modul/view.php?id=$cmid">$text</a>';

Verlinkung auf(String html, {int? eigen = 13, bool fuerLernende = false, List<LinkZiel>? mit}) =>
    verlinken(html, ziele: mit ?? ziele, basis: basis, eigen: eigen, fuerLernende: fuerLernende);

void main() {
  test('Kennung: vor dem Doppelpunkt, mit Buchstaben vorn und Zahl hinten', () {
    expect(kennungAus('Arbeitsblatt 1: Der Auftrag'), 'Arbeitsblatt 1');
    expect(kennungAus('Lösung zur Hilfe zu Arbeitsblatt 3: X'), 'Lösung zur Hilfe zu Arbeitsblatt 3');
    expect(kennungAus('Station  4 : Messen'), 'Station 4');
    expect(kennungAus('Test: Grundlagen'), isNull);
    expect(kennungAus('2024: Rückblick'), isNull);
    expect(kennungAus('Lehrerhandreichung'), isNull);
  });

  test('jede Nennung wird ein Link mit genau diesem Text, die eigene nicht', () {
    final v = auf('<h3>Aufgabe 1</h3>\n<p>Lies Infoblatt 1, Abschnitt 2. Das ist Arbeitsblatt 1.</p>');
    expect(v.html, '<h3>Aufgabe 1</h3>\n<p>Lies ${link(16, 'Infoblatt 1')}, Abschnitt 2. Das ist Arbeitsblatt 1.</p>');
    expect(v.neu, ['Infoblatt 1']);
  });

  test('der längste Stamm zuerst, keine Zahl in einer längeren', () {
    final v = auf('<p>Hilfe zu Arbeitsblatt 1 und Arbeitsblatt 12, dann Arbeitsblatt 1.</p>', eigen: 16);
    expect(
        v.html,
        '<p>${link(15, 'Hilfe zu Arbeitsblatt 1')} und ${link(17, 'Arbeitsblatt 12', 'assign')}, '
        'dann ${link(13, 'Arbeitsblatt 1')}.</p>');
  });

  test('Zeilenumbruch, &nbsp; und Umlaut als Entity bleiben, wie sie sind', () {
    final v = auf('<p>siehe Infoblatt\n1 und L&ouml;sung zu Arbeitsblatt&nbsp;1</p>', eigen: 11);
    expect(v.html,
        '<p>siehe ${link(16, 'Infoblatt\n1')} und ${link(14, 'L&ouml;sung zu Arbeitsblatt&nbsp;1')}</p>');
  });

  test('nicht in Links, Attributen, script', () {
    const html = '<p><a href="https://example.org/x">Infoblatt 1</a> '
        '<img src="@@PLUGINFILE@@/a.svg" alt="Infoblatt 1" class="img-fluid"></p>'
        '<script>var s = "Infoblatt 1";</script>';
    expect(auf(html).geaendert, isFalse);
  });

  test('Materialübersicht: Zelle mit ganzem Namen, Leerraum bleibt draußen', () {
    final v = auf('<table class="table"><tr><td> Infoblatt 1: VLAN-Grundlagen </td><td>Infoblatt</td></tr>'
        '<tr><td>Lehrerhandreichung</td></tr></table>', eigen: 11);
    expect(
        v.html,
        '<table class="table"><tr><td> ${link(16, 'Infoblatt 1: VLAN-Grundlagen')} </td><td>Infoblatt</td></tr>'
        '<tr><td>Lehrerhandreichung</td></tr></table>');
  });

  test('ein Textfeld ist kein Ziel', () {
    final mit = [...ziele, LinkZiel(20, 'label', 'Station 1: Einstieg')];
    expect(auf('<p>Station 1</p>', mit: mit).geaendert, isFalse);
  });

  test('Link auf das Original wird auf das Gegenstück umgestellt', () {
    final v = auf('<p><a class="x" href="https://moodle.schule.example/mod/page/view.php?id=999">Infoblatt 1</a></p>');
    expect(v.html, '<p><a class="x" href="https://moodle.schule.example/mod/page/view.php?id=16">Infoblatt 1</a></p>');
    expect(v.umgestellt, ['Infoblatt 1']);
  });

  test('Link im Abschnitt mit falschem Text: Hinweis, keine Änderung', () {
    final v = auf('<p>${link(15, 'Infoblatt 1')}</p>');
    expect(v.geaendert, isFalse);
    expect(v.hinweise.single, contains('zeigt auf „Hilfe zu Arbeitsblatt 1: Planen"'));
  });

  test('mehrdeutig, nicht im Abschnitt, Lösung von Lernendenseite: nicht verlinkt, mit Hinweis', () {
    final doppelt = [...ziele, LinkZiel(21, 'page', 'Infoblatt 1: Kopie')];
    final a = auf('<p>Infoblatt 1</p>', mit: doppelt);
    expect(a.geaendert, isFalse);
    expect(a.hinweise.single, contains('mehrdeutig'));

    final b = auf('<p>Arbeitsblatt 5 und Hilfe zu Arbeitsblatt 2</p>');
    expect(b.geaendert, isFalse);
    expect(b.hinweise, hasLength(2));

    final c = auf('<p>Lösung zu Arbeitsblatt 1</p>', fuerLernende: true);
    expect(c.geaendert, isFalse);
    expect(c.hinweise.single, contains('klingt nach Lösung'));
  });

  test('ein Feld mit SchuCu-Tabelle bleibt unberührt', () {
    expect(auf('<table class="lernsituation"><tr><td>Arbeitsblatt 1</td></tr></table>', eigen: 10).geaendert,
        isFalse);
  });

  test('ein zweiter Durchgang ändert nichts', () {
    final einmal = auf('<p>Infoblatt 1, Hilfe zu Arbeitsblatt 1</p><table class="table"><tr>'
        '<td>Infoblatt 1: VLAN-Grundlagen</td></tr></table>');
    expect(einmal.neu, hasLength(3));
    expect(auf(einmal.html).geaendert, isFalse);
  });

  test('Zusicherung: nur Links auf Aktivitäten des Abschnitts kommen dazu', () {
    const erlaubt = {'https://moodle.schule.example/mod/page/view.php?id=16'};
    const alt = '<p>Infoblatt 1</p>';
    expect(nurLinksGeaendert(alt, '<p>${link(16, 'Infoblatt 1')}</p>', erlaubt), isNull);
    expect(nurLinksGeaendert(alt, '<p>${link(16, 'Infoblatt 2')}</p>', erlaubt), contains('Text'));
    expect(nurLinksGeaendert(alt, '<p>${link(99, 'Infoblatt 1')}</p>', erlaubt), contains('keine Aktivität'));
    expect(nurLinksGeaendert('<p>${link(16, 'Infoblatt 1')}</p>', alt, erlaubt), contains('entfernt'));
    final v = auf('<p>Infoblatt 1, Hilfe zu Arbeitsblatt 1</p>');
    expect(
        nurLinksGeaendert('<p>Infoblatt 1, Hilfe zu Arbeitsblatt 1</p>', v.html,
            {for (final z in ziele) if (z.hatSeite) linkAdresse(basis, z)}),
        isNull);
  });
}
