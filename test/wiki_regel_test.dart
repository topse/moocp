import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:moocp/moodle/formular.dart';
import 'package:moocp/moodle/formular_lesen.dart';
import 'package:moocp/moodle/formular_schreiben.dart';
import 'package:moocp/moodle/moodle_zugang.dart';
import 'package:moocp/moodle/wiki.dart';
import 'package:moocp/protokoll.dart';

/// Das Einstellungsformular eines Wikis, wie Moodle es nach dem Anlegen
/// zeigt: der Typ als gesperrte Auswahl, der Gruppenmodus als Auswahl oder,
/// wenn der Kurs ihn erzwingt, als verstecktes Feld.
Formular einstellungen(String typ, {String modul = 'wiki', String? gruppen, bool erzwungen = false}) {
  String option(String wert, String text) => '<option value="$wert"${gruppen == wert ? ' selected="selected"' : ''}>$text</option>';
  final form = html_parser.parse('<form><input type="hidden" name="modulename" value="$modul">'
          '<select name="wikimode" disabled="disabled">'
          '<option value="collaborative"${typ == 'collaborative' ? ' selected="selected"' : ''}>Gemeinsam</option>'
          '<option value="individual"${typ == 'individual' ? ' selected="selected"' : ''}>Persönlich</option>'
          '</select>'
          '${gruppen == null ? '' : erzwungen ? '<input type="hidden" name="groupmode" value="$gruppen">' : '<select name="groupmode">${option('0', 'Keine Gruppen')}${option('1', 'Getrennte Gruppen')}${option('2', 'Sichtbare Gruppen')}</select>'}'
          '</form>')
      .querySelector('form')!;
  return Formular(form, formularFelder(form), '/course/modedit.php', Seitenangaben.aus(''), const {});
}

/// Die Auswahl über dem Wiki (mod/wiki/renderer.php, wiki_print_subwiki_selector).
String? sperre(String auswahl) =>
    wikiAnsichtSperre(html_parser.parse('<div id="region-main">$auswahl<div class="generalbox">x</div></div>'));

void main() {
  test('Wiki ohne erste Seite: Umleitung auf das Anlegeformular', () {
    final z = MoodleZugang(Protokoll());
    bool get(String a) => z.erlaubt('GET', Uri.parse('https://m.example$a'));
    expect(get('/mod/wiki/create.php?wid=22&group=0&uid=0&title=ZZ%20Startseite'), isTrue);
    expect(get('/mod/wiki/create.php?wid=22&group=&uid=0&title=ZZ%20Startseite'), isTrue, reason: 'ohne Gruppen: group leer');
    expect(get('/mod/wiki/create.php?wid=22&group=0&uid=7&title=x'), isFalse, reason: 'persönliches Wiki');
  });

  test('Typ aus den Einstellungen: nur ein gemeinsames Wiki', () {
    wikiTypPruefen(einstellungen('collaborative'), 15397);
    expect(() => wikiTypPruefen(einstellungen('individual'), 15397),
        throwsA(isA<MoodleFehler>().having((f) => f.meldung, 'meldung', contains('persönliches Wiki'))));
    expect(() => wikiTypPruefen(einstellungen(''), 15397), throwsA(isA<MoodleFehler>()), reason: 'Typ unbekannt');
    expect(() => wikiTypPruefen(einstellungen('collaborative', modul: 'page'), 15397), throwsA(isA<MoodleFehler>()));
  });

  test('Gruppenmodus aus den Einstellungen sperrt, auch ohne Gruppen im Kurs und vor der ersten Seite', () {
    wikiTypPruefen(einstellungen('collaborative', gruppen: '0'), 15397);
    for (final g in ['1', '2']) {
      expect(() => wikiTypPruefen(einstellungen('collaborative', gruppen: g), 15397),
          throwsA(isA<MoodleFehler>().having((f) => f.meldung, 'meldung', contains('Gruppenmodus'))),
          reason: 'groupmode $g');
    }
    expect(() => wikiTypPruefen(einstellungen('collaborative', gruppen: '1', erzwungen: true), 15397),
        throwsA(isA<MoodleFehler>()), reason: 'vom Kurs erzwungen');
    wikiTypPruefen(einstellungen('collaborative', gruppen: '0', erzwungen: true), 15397);
  });

  test('Ansicht: Auswahl einer Person oder Gruppe sperrt', () {
    expect(sperre(''), isNull);
    // Gruppenmodus ohne Gruppen: nur ein Text, keine Auswahl.
    expect(sperre('<div class="groupselector">Gruppenmodus: Alle Teilnehmer/innen</div>'), isNull);
    expect(sperre('<select name="uid"><option value="45">Erika Mustermann</option></select>'), contains('persönliches'));
    expect(sperre('<select name="groupanduser"><option value="3-45">Erika Mustermann</option></select>'),
        contains('persönliches'), reason: 'persönlich mit Gruppen');
    expect(sperre('<div class="groupselector"><select name="group"><option value="3">Gruppe A</option></select></div>'),
        contains('Gruppen'));
  });
}
