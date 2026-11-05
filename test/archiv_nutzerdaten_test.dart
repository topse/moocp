// Offline prüfbar: die erweiterte Archivprüfung (A1, E22) und die Formularregeln der Sicherung.
// Die Archive sind nachgebaut (gzip + Tar mit dem archive-Paket); die Elementnamen folgen dem
// Quelltext von Moodle und sind nicht an echten Sicherungen gemessen (UNGEMESSEN).
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/elemente.dart';
import 'package:moocp/moodle/moodle_zugang.dart';
import 'package:moocp/moodle/sicherung_regeln.dart';
import 'package:moocp/moodle/wiederherstellung_regeln.dart';
import 'package:moocp/protokoll.dart';

Uint8List _mbz(Map<String, String> dateien, {List<ArchiveFile> binaer = const []}) {
  final archive = Archive();
  for (final e in dateien.entries) {
    archive.addFile(ArchiveFile.bytes(e.key, utf8.encode(e.value)));
  }
  binaer.forEach(archive.addFile);
  return Uint8List.fromList(GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive)));
}

String _backup({String aktivitaeten = '<activity><modulename>page</modulename><title>ZZ Seite</title></activity>', String einstellungen = ''}) =>
    '<moodle_backup><information><format>moodle2</format><type>activity</type>'
    '<activities>$aktivitaeten</activities><settings>$einstellungen</settings></information></moodle_backup>';

String _hash(String zeichen) => List.filled(40, zeichen).join();

/// files.xml mit einer Datei und die Datei selbst, so wie Moodle sie ablegt: unter ihrem Hash, ohne Endung.
({Map<String, String> xml, List<ArchiveFile> datei}) _datei(String name, String inhalt, {String hash = 'a'}) {
  final h = _hash(hash);
  return (
    xml: {
      'files.xml': '<files><file id="1"><contenthash>$h</contenthash><filename>$name</filename>'
          '<component>mod_page</component><userid>2</userid><author>E. Mustermann</author></file></files>',
    },
    datei: [ArchiveFile.bytes('files/${h.substring(0, 2)}/$h', utf8.encode(inhalt))],
  );
}

String _esc(String html) => html.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String _seite(String html) => '<activity><page><content>${_esc(html)}</content></page></activity>';

void main() {
  group('Einträge zu Personen', () {
    for (final (datei, eintrag) in const [
      ('comments.xml', '<comments><comment id="1"><userid>5</userid></comment></comments>'),
      ('logs.xml', '<logs><log id="1"><userid>5</userid></log></logs>'),
      ('course/enrolments.xml', '<enrolments><enrols><enrol id="1"><user_enrolments><enrolment id="1"><userid>5</userid></enrolment></user_enrolments></enrol></enrols></enrolments>'),
      ('gradebook.xml', '<gradebook><grade_grades><grade_grade id="1"><userid>5</userid></grade_grade></grade_grades></gradebook>'),
      ('activities/page_1/grades.xml', '<activity_gradebook><grade_grades><grade_grade id="1"/></grade_grades></activity_gradebook>'),
      ('activities/page_1/roles.xml', '<roles><role_assignments><assignment id="1"><userid>5</userid></assignment></role_assignments></roles>'),
      ('activities/page_1/completion.xml', '<completions><completion id="1"><userid>5</userid></completion></completions>'),
      ('groups.xml', '<groups><group id="1"><members><member id="1"><userid>5</userid></member></members></group></groups>'),
      ('badges.xml', '<badges><badge id="1"><userid>5</userid></badge></badges>'),
    ]) {
      test('$datei mit Einträgen: Nutzerdaten, abgelehnt', () async {
        final b = await archivPruefen(_mbz({'moodle_backup.xml': _backup(), datei: eintrag}));
        expect(b.ok, isFalse);
        expect(b.nutzerdaten, isTrue, reason: 'nur dann löscht die Sicherung die Datei');
        expect(b.grund, isNot(contains('5')), reason: 'keine Inhalte in der Meldung');
      });
    }

    test('leere Dateien derselben Namen (Platzhalter) werden angenommen', () async {
      final b = await archivPruefen(_mbz({
        'moodle_backup.xml': _backup(),
        'comments.xml': '<comments></comments>',
        'logs.xml': '<logs></logs>',
        'course/enrolments.xml': '<enrolments><enrols><enrol id="1"><user_enrolments></user_enrolments></enrol></enrols></enrolments>',
        'gradebook.xml': '<gradebook><grade_items></grade_items><grade_grades></grade_grades></gradebook>',
        'activities/page_1/grades.xml': '<activity_gradebook><grade_grades></grade_grades></activity_gradebook>',
        'activities/page_1/roles.xml': '<roles><role_assignments></role_assignments></roles>',
        'activities/page_1/completion.xml': '<completions></completions>',
      }));
      expect(b.ok, isTrue, reason: b.grund);
    });

    test('files.xml und questions.xml mit Kennungen der Lehrkraft sind keine Nutzerdaten von Lernenden', () async {
      final b = await archivPruefen(_mbz({
        'moodle_backup.xml': _backup(),
        'files.xml': '<files><file id="1"><userid>2</userid><author>E. Mustermann</author></file></files>',
        'questions.xml':
            '<questions><question_bank_entry id="1"><question_version><question_versions><questions><question><createdby>2</createdby><modifiedby>2</modifiedby></question></questions></question_versions></question_version></question_bank_entry></questions>',
        'calendar.xml': '<events><event id="1"><userid>2</userid></event></events>',
      }));
      expect(b.ok, isTrue, reason: b.grund);
      expect(b.nutzerdaten, isFalse);
      // Die App liest die Kennungen nicht und sagt das (archivAutorenHinweis).
      expect(archivPruefbericht(b.ungeprueft), contains(archivAutorenHinweis));
    });

    for (final (art, datei, inhalt) in const [
      ('forum', 'forum.xml', '<activity><forum id="1"><discussions><discussion id="1"><posts><post id="1"><message>x</message></post></posts></discussion></discussions></forum></activity>'),
      ('glossary', 'glossary.xml', '<activity><glossary id="1"><entries><entry id="1"><concept>x</concept></entry></entries></glossary></activity>'),
      ('data', 'data.xml', '<activity><data id="1"><records><record id="1"/></records></data></activity>'),
      ('wiki', 'wiki.xml', '<activity><wiki id="1"><subwikis><subwiki id="1"><userid>5</userid></subwiki></subwikis></wiki></activity>'),
      ('assign', 'assign.xml', '<activity><assign id="1"><submissions><submission id="1"/></submissions></assign></activity>'),
      ('quiz', 'quiz.xml', '<activity><quiz id="1"><attempts><attempt id="1"/></attempts></quiz></activity>'),
    ]) {
      test('$art mit Beiträgen oder Einträgen von Lernenden: abgelehnt', () async {
        final b = await archivPruefen(_mbz({
          'moodle_backup.xml': _backup(aktivitaeten: '<activity><modulename>$art</modulename><title>ZZ</title></activity>'),
          'activities/${art}_1/$datei': inhalt,
        }));
        expect(b.ok, isFalse);
        expect(b.nutzerdaten, isTrue);
        expect(b.grund, contains(art));
      });

      test('$art ohne Beiträge (leere Hüllen): angenommen', () async {
        final leer = inhalt.replaceAll(RegExp(r'<(discussion|post|entry|record|subwiki|submission|attempt)\b.*?(/>|</\1>)'), '');
        final b = await archivPruefen(_mbz({
          'moodle_backup.xml': _backup(aktivitaeten: '<activity><modulename>$art</modulename><title>ZZ</title></activity>'),
          'activities/${art}_1/$datei': leer,
        }));
        expect(b.ok, isTrue, reason: b.grund);
      });
    }

    test('ein Beitrag in einer Aktivitätsdatei, die sich nicht als XML lesen lässt, wird am Rohtext erkannt', () async {
      final b = await archivPruefen(_mbz({
        'moodle_backup.xml': _backup(aktivitaeten: '<activity><modulename>forum</modulename><title>ZZ</title></activity>'),
        'activities/forum_1/forum.xml': '<activity><forum><discussions><discussion id="1"><posts><post id="1">',
      }));
      expect(b.ok, isFalse);
      expect(b.nutzerdaten, isTrue);
    });

    test('Arten ohne eigenen Dateiaufbau erscheinen als nicht geprüft, reine Inhaltsarten nicht', () async {
      final b = await archivPruefen(_mbz({
        'moodle_backup.xml': _backup(
            aktivitaeten: '<activity><modulename>page</modulename><title>A</title></activity>'
                '<activity><modulename>board</modulename><title>B</title></activity>'
                '<activity><modulename>forum</modulename><title>C</title></activity>'),
      }));
      expect(b.ok, isTrue, reason: b.grund);
      expect(b.ungeprueft, ['board']);
      final bericht = archivPruefbericht(b.ungeprueft);
      expect(bericht, contains('Eingaben von Lernenden in board'));
      expect(bericht, contains('Nicht geprüft:'));
      expect(bericht, isNot(contains('nicht enthalten (geprüft)')));
    });

    test('die erweiterten Optionen in moodle_backup.xml zählen als Nutzerdaten', () async {
      for (final name in ['comments', 'role_assignments', 'calendarevents', 'anonymize']) {
        final b = await archivPruefen(_mbz({
          'moodle_backup.xml': _backup(
              einstellungen: '<setting><level>root</level><name>$name</name><value>1</value></setting>'),
        }));
        expect(b.ok, isFalse, reason: name);
        expect(b.nutzerdaten, isTrue, reason: name);
      }
    });
  });

  group('Code im Archiv (E22)', () {
    Future<ArchivBefund> pruefe(Map<String, String> dateien, {List<ArchiveFile> binaer = const [], bool ablehnen = true}) =>
        archivPruefen(_mbz({'moodle_backup.xml': _backup(), ...dateien}, binaer: binaer), codeAblehnen: ablehnen);

    test('<script>, Ereignis-Attribute, javascript: und srcdoc im Text eines Felds: abgelehnt, ohne Inhalt in der Meldung', () async {
      for (final html in [
        '<p>Hallo</p><script>alert(1)</script>',
        '<p onclick="tuWas()">Hallo</p>',
        '<a href="javascript:tuWas()">Hallo</a>',
        '<iframe srcdoc="<p>x</p>"></iframe>',
      ]) {
        final b = await pruefe({'activities/page_1/page.xml': _seite(html)});
        expect(b.ok, isFalse, reason: html);
        expect(b.nutzerdaten, isFalse, reason: 'Code ist kein Grund, die Sicherung zu löschen');
        expect(b.grund, contains('activities/page_1/page.xml'));
        expect(b.grund, isNot(contains('tuWas')));
        expect(b.grund, isNot(contains('alert')));
        expect(b.code, isNotEmpty);
      }
    });

    test('mit codeAblehnen: false bleibt das Archiv gültig, der Befund steht in code', () async {
      final b = await pruefe({'activities/page_1/page.xml': _seite('<script>x()</script>')}, ablehnen: false);
      expect(b.ok, isTrue, reason: b.grund);
      expect(b.code, hasLength(1));
    });

    test('ein Rahmen ohne genau die Abschottung wird abgelehnt, ein abgeschotteter nicht', () async {
      final offen = await pruefe({
        'activities/page_1/page.xml':
            _seite('<iframe sandbox="allow-scripts allow-same-origin" src="@@PLUGINFILE@@/spiel.html"></iframe>'),
      });
      expect(offen.ok, isFalse);
      expect(offen.grund, contains('Rahmen ohne Abschottung'));
      final zu = await pruefe({
        'activities/page_1/page.xml': _seite('<iframe sandbox="allow-scripts" src="@@PLUGINFILE@@/spiel.html"></iframe>'),
      });
      expect(zu.ok, isTrue, reason: zu.grund);
    });

    test('ein Element in einer Frage ist nicht vorgesehen', () async {
      final b = await pruefe({
        'questions.xml':
            '<questions><question><questiontext>${_esc('<iframe sandbox="allow-scripts" src="@@PLUGINFILE@@/spiel.html"></iframe>')}</questiontext></question></questions>',
      });
      expect(b.ok, isFalse);
      expect(b.grund, contains('Element in einer Frage'));
    });

    test('HTML-Datei mit Code, die kein Element ist: abgelehnt', () async {
      final d = _datei('infoblatt.html', '<html><body><script>x()</script></body></html>');
      final b = await pruefe(d.xml, binaer: d.datei);
      expect(b.ok, isFalse);
      expect(b.grund, contains('.html-Datei mit Code'));
      expect(b.grund, isNot(contains('infoblatt')), reason: 'der Dateiname steht nicht in der Meldung');
    });

    test('SVG und XML mit Code: abgelehnt; SVG ohne Code: angenommen', () async {
      final svg = _datei('bild.svg', '<svg xmlns="http://www.w3.org/2000/svg"><script>x()</script></svg>', hash: 'b');
      expect((await pruefe(svg.xml, binaer: svg.datei)).ok, isFalse);
      final ohne = _datei('bild.svg', '<svg xmlns="http://www.w3.org/2000/svg"><circle r="3"/></svg>', hash: 'c');
      expect((await pruefe(ohne.xml, binaer: ohne.datei)).ok, isTrue);
    });

    test('Skriptdateien (.js) werden abgelehnt', () async {
      final d = _datei('hilfe.js', 'var x = 1;', hash: 'd');
      final b = await pruefe(d.xml, binaer: d.datei);
      expect(b.ok, isFalse);
      expect(b.grund, contains('Skriptdatei'));
    });

    test('ein Element der App (Kopf, abgeschotteter Rahmen, Regeln eingehalten) darf Code haben', () async {
      final kopf = elementKopf(Uri.parse('https://moodle.schule.example'));
      final html = '<!DOCTYPE html><html lang="de"><head>\n$kopf\n</head><body><button id="b">Los</button>'
          '<script>document.getElementById("b").onclick = function () { this.textContent = "Fertig"; };</script></body></html>';
      final d = _datei('uebung.html', html, hash: 'e');
      final ok = await pruefe({
        ...d.xml,
        'activities/page_1/page.xml': _seite('<iframe sandbox="allow-scripts" src="@@PLUGINFILE@@/uebung.html"></iframe>'),
      }, binaer: d.datei);
      expect(ok.ok, isTrue, reason: ok.grund);

      // Dieselbe Datei ohne Rahmen, der sie einbindet, ist kein Element.
      final ohneRahmen = await pruefe(d.xml, binaer: d.datei);
      expect(ohneRahmen.ok, isFalse);

      // Ohne den Kopf der App ebenso, auch mit Rahmen.
      final ohneKopf = _datei('uebung.html', '<html><head></head><body><script>x()</script></body></html>', hash: 'f');
      final b = await pruefe({
        ...ohneKopf.xml,
        'activities/page_1/page.xml': _seite('<iframe sandbox="allow-scripts" src="@@PLUGINFILE@@/uebung.html"></iframe>'),
      }, binaer: ohneKopf.datei);
      expect(b.ok, isFalse);
    });

    test('Text ohne Code und eine HTML-Datei ohne Code bleiben unberührt', () async {
      final d = _datei('blatt.html', '<html><body><p>Hallo</p></body></html>', hash: '1');
      final b = await pruefe({
        ...d.xml,
        'activities/page_1/page.xml': _seite('<p>Ein <b>Text</b> mit On = Off und Manuskript.</p>'),
      }, binaer: d.datei);
      expect(b.ok, isTrue, reason: b.grund);
      expect(b.code, isEmpty);
    });
  });

  group('Formularfelder der Sicherung', () {
    MapEntry<String, String> e(String k, String v) => MapEntry(k, v);

    test('setting_root_users muss da sein und 0 sein, fehlt es, ist der Grund ein Abbruch', () {
      expect(nutzerdatenPflichtFehler([e('stage', '1')]), contains('setting_root_users'));
      expect(nutzerdatenPflichtFehler([e('setting_root_users', '1')]), isNotNull);
      expect(nutzerdatenPflichtFehler([e('setting_root_users', '0')]), isNull);
      // Der letzte Wert zählt (Moodle setzt vor das Kontrollkästchen ein verstecktes Feld).
      expect(nutzerdatenPflichtFehler([e('setting_root_users', '0'), e('setting_root_users', '1')]), isNotNull);
      expect(nutzerdatenAusdruecklichAus([e('stage', '1')]), isFalse);
      expect(nutzerdatenAusdruecklichAus([e('setting_root_users', '0')]), isTrue);
    });

    test('die Bestätigung einer Sicherung ohne setting_root_users besteht nicht mehr', () {
      Felder seite({String? users}) => [
            e('stage', '4'),
            e('setting_activity_page_7_included', '1'),
            if (users != null) e('setting_root_users', users),
          ];
      expect(bestaetigungFehler(seite(users: '0'), cmid: 7), isNull);
      expect(bestaetigungFehler(seite(), cmid: 7), contains('setting_root_users'));
      expect(bestaetigungFehler(seite(users: '1'), cmid: 7), contains('setting_root_users'));
    });

    test('weitere Optionen mit Personenbezug werden auf 0 gesetzt und von der Bestätigung geprüft', () {
      const optionen = ['role_assignments', 'comments', 'calendarevents', 'anonymize'];
      for (final o in optionen) {
        expect(nutzerdatenOptionen, contains(o));
      }
      final vorher = [for (final o in optionen) e('setting_root_$o', '1'), e('setting_root_users', '1')];
      final nachher = nutzerdatenAus(vorher);
      for (final o in optionen) {
        expect(letzteWerte(nachher)['setting_root_$o'], '0', reason: o);
      }
      expect(nutzerdatenEingeschaltet(vorher), isNotNull);
      expect(nutzerdatenEingeschaltet(nachher), isNull);
      // Fehlt eine dieser Optionen, zählt sie als aus (sie hängen an users); nur users selbst ist Pflicht.
      expect(ohneNutzerdaten([e('setting_root_users', '0')]), isTrue);
    });

    test('competencies, permissions und contentbankcontent sind bewusst keine Nutzerdaten-Optionen', () {
      for (final o in ['competencies', 'permissions', 'contentbankcontent']) {
        expect(nutzerdatenOptionen, isNot(contains(o)), reason: o);
      }
    });

    test('die Positivliste lässt ein Formular der Sicherung ohne setting_root_users nicht durch', () {
      final z = MoodleZugang(Protokoll());
      bool post(List<MapEntry<String, String>> f) =>
          z.erlaubt('POST', Uri.parse('https://m.example/backup/backup.php'), f);
      final voll = [
        e('stage', '2'),
        e('_qf__backup_schema_form', '1'),
        e('sesskey', 'abc'),
        e('setting_root_users', '0'),
      ];
      expect(post(voll), isTrue);
      expect(post([for (final x in voll) if (x.key != 'setting_root_users') x]), isFalse);
      expect(post([for (final x in voll) x.key == 'setting_root_users' ? e(x.key, '1') : x]), isFalse);
    });
  });

  group('Herkunft einer Sicherungsdatei', () {
    Iterable<({String datei, String? pruefsumme})> eigene() => [
          (datei: 'kurs-k12-2026-11-05_090000.mbz', pruefsumme: 'abc'),
          (datei: 'unterordner/seite.mbz', pruefsumme: null),
        ];

    test('gleicher Name und gleiche Prüfsumme: eigen, auch mit anderem Trennzeichen', () {
      expect(sicherungsHerkunft(eigene(), 'kurs-k12-2026-11-05_090000.mbz', 'abc'), SicherungsHerkunft.eigen);
      expect(sicherungsHerkunft([(datei: r'unter\ordner.mbz', pruefsumme: 'x')], 'unter/ordner.mbz', 'x'),
          SicherungsHerkunft.eigen);
    });

    test('gleicher Name, andere Prüfsumme oder nicht geprüfter Vorgang: geändert', () {
      expect(sicherungsHerkunft(eigene(), 'kurs-k12-2026-11-05_090000.mbz', 'xyz'), SicherungsHerkunft.geaendert);
      expect(sicherungsHerkunft(eigene(), 'unterordner/seite.mbz', 'abc'), SicherungsHerkunft.geaendert);
    });

    test('kein Vorgang mit diesem Namen: fremd', () {
      expect(sicherungsHerkunft(eigene(), 'woanders.mbz', 'abc'), SicherungsHerkunft.fremd);
      expect(sicherungsHerkunft(const [], 'a.mbz', 'abc'), SicherungsHerkunft.fremd);
    });
  });
}
