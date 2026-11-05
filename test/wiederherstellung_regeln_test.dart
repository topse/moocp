// Offline prüfbar: die Archivprüfung der Wiederherstellung (moodle/wiederherstellung_regeln.dart),
// die Positivliste für Upload, Kurs und Assistenten und die erlaubten Übergänge.
// Die Archive sind hier nachgebaut (gzip + ustar); der Ablauf gegen Moodle ist nicht geprüft.
import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/moodle_zugang.dart';
import 'package:moocp/moodle/wiederherstellung.dart' show behaltenFelder, loeschGruppenBauen;
import 'package:moocp/moodle/wiederherstellung_regeln.dart';
import 'package:moocp/protokoll.dart';

/// Ein Tar-Eintrag mit 512-Byte-Kopf (ustar), Daten auf 512 Byte aufgefüllt.
List<int> _eintrag(String name, List<int> inhalt, {int typ = 0x30, bool falscheSumme = false}) {
  final kopf = Uint8List(512);
  void schreibe(int von, String s) {
    final b = latin1.encode(s);
    kopf.setRange(von, von + b.length, b);
  }

  schreibe(0, name);
  schreibe(100, '0000644\u0000');
  schreibe(108, '0000000\u0000');
  schreibe(116, '0000000\u0000');
  schreibe(124, '${inhalt.length.toRadixString(8).padLeft(11, '0')}\u0000');
  schreibe(136, '00000000000\u0000');
  kopf[156] = typ;
  schreibe(257, 'ustar\u000000');
  // Prüfsumme: mit Leerzeichen im Feld berechnen, dann eintragen.
  kopf.fillRange(148, 156, 0x20);
  var summe = 0;
  for (final b in kopf) {
    summe += b;
  }
  if (falscheSumme) summe += 1;
  schreibe(148, '${summe.toRadixString(8).padLeft(6, '0')}\u0000 ');
  final daten = [...inhalt, ...List<int>.filled((512 - inhalt.length % 512) % 512, 0)];
  return [...kopf, ...daten];
}

/// Ein Tar-Archiv aus Einträgen, mit dem üblichen Abschluss aus Nullblöcken.
Uint8List _tar(List<List<int>> eintraege) =>
    Uint8List.fromList([...eintraege.expand((e) => e), ...List<int>.filled(1024, 0)]);

String _sicherungXml({String typ = 'activity', String nutzer = '0', String titel = 'ZZ Testseite'}) => '''
<?xml version="1.0" encoding="UTF-8"?>
<moodle_backup>
  <information>
    <moodle_version>2024100700</moodle_version>
    <format>moodle2</format>
    <type>$typ</type>
    <activities>
      <activity>
        <modulename>page</modulename>
        <title>$titel</title>
      </activity>
    </activities>
    <settings>
      <setting><name>users</name><value>$nutzer</value></setting>
    </settings>
  </information>
</moodle_backup>
''';

List<int> _xml(String s) => utf8.encode(s);

Uint8List _mbz(List<List<int>> eintraege) => Uint8List.fromList(gzip.encode(_tar(eintraege)));

Uint8List _gueltig({String nutzer = '0', String titel = 'ZZ Testseite'}) => _mbz([
      _eintrag('moodle_backup.xml', _xml(_sicherungXml(nutzer: nutzer, titel: titel))),
      _eintrag('activities/page_1/page.xml', _xml('<activity/>')),
    ]);

void main() {
  group('Archivprüfung', () {
    test('gültige Aktivitätssicherung wird angenommen und nennt Art und Titel', () async {
      final b = await archivPruefen(_gueltig());
      expect(b.ok, isTrue, reason: b.grund);
      expect(b.typ, 'activity');
      expect(b.moodleVersion, '2024100700');
      expect(b.aktivitaeten.single.modul, 'page');
      expect(b.aktivitaeten.single.titel, 'ZZ Testseite');
    });

    test('Kennungen in den Einstellungen sind keine Aktivitäten des Archivs', () async {
      final xml = _sicherungXml().replaceFirst('</moodle_backup>',
          '<settings><setting><level>activity</level><activity>page_1</activity><name>page_1_included</name><value>1</value></setting></settings></moodle_backup>');
      final b = await archivPruefen(_mbz([
        _eintrag('moodle_backup.xml', _xml(xml)),
        _eintrag('activities/page_1/page.xml', _xml('<activity/>')),
      ]));
      expect(b.ok, isTrue, reason: b.grund);
      expect(b.aktivitaeten, hasLength(1));
      expect(b.aktivitaeten.single.titel, 'ZZ Testseite');
    });

    test('gültiger Kurs ohne Nutzerdaten wird angenommen', () async {
      final b = await archivPruefen(_mbz([
        _eintrag('moodle_backup.xml', _xml(_sicherungXml(typ: 'course'))),
      ]));
      expect(b.ok, isTrue, reason: b.grund);
      expect(b.typ, 'course');
    });

    test('keine gepackte Datei: abgelehnt, ohne zu entpacken', () async {
      final b = await archivPruefen(Uint8List.fromList(List.filled(64, 7)));
      expect(b.ok, isFalse);
    });

    test('beschädigte gzip-Datei wird abgelehnt', () async {
      final b = await archivPruefen(Uint8List.fromList([0x1f, 0x8b, 8, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]));
      expect(b.ok, isFalse);
    });

    test('abgeschnittene Sicherung wird abgelehnt', () async {
      final voll = _gueltig();
      final b = await archivPruefen(Uint8List.sublistView(voll, 0, voll.length ~/ 2));
      expect(b.ok, isFalse);
    });

    test('Pfad mit „..“ im Archiv wird abgelehnt', () async {
      final b = await archivPruefen(_mbz([
        _eintrag('moodle_backup.xml', _xml(_sicherungXml())),
        _eintrag('../../etc/evil.txt', _xml('x')),
      ]));
      expect(b.ok, isFalse);
      expect(b.grund, contains('Pfad'));
    });

    test('absoluter Pfad im Archiv wird abgelehnt', () async {
      final b = await archivPruefen(_mbz([
        _eintrag('moodle_backup.xml', _xml(_sicherungXml())),
        _eintrag('/tmp/x.txt', _xml('x')),
      ]));
      expect(b.ok, isFalse);
    });

    test('Link im Archiv wird abgelehnt', () async {
      final b = await archivPruefen(_mbz([
        _eintrag('moodle_backup.xml', _xml(_sicherungXml())),
        _eintrag('link', const [], typ: 0x32),
      ]));
      expect(b.ok, isFalse);
    });

    test('falsche Prüfsumme im Tar-Kopf wird abgelehnt', () async {
      final b = await archivPruefen(_mbz([
        _eintrag('moodle_backup.xml', _xml(_sicherungXml()), falscheSumme: true),
      ]));
      expect(b.ok, isFalse);
    });

    test('Nutzerdaten im Archiv (Einstellung users = 1) werden abgelehnt', () async {
      final b = await archivPruefen(_gueltig(nutzer: '1'));
      expect(b.ok, isFalse);
      expect(b.grund, contains('Nutzerdaten'));
    });

    test('Nutzerdatei im Archiv (users.xml) wird abgelehnt', () async {
      final b = await archivPruefen(_mbz([
        _eintrag('moodle_backup.xml', _xml(_sicherungXml())),
        _eintrag('users.xml', _xml('<users/>')),
      ]));
      expect(b.ok, isFalse);
      expect(b.grund, contains('Nutzerdaten'));
    });

    test('Bewertungen einer Person in grades.xml werden abgelehnt', () async {
      final b = await archivPruefen(_mbz([
        _eintrag('moodle_backup.xml', _xml(_sicherungXml())),
        _eintrag('grades.xml', _xml('<grade_grades><grade_grade><userid>5</userid></grade_grade></grade_grades>')),
      ]));
      expect(b.ok, isFalse);
    });

    test('Archiv ohne moodle_backup.xml wird abgelehnt', () async {
      final b = await archivPruefen(_mbz([_eintrag('andere.xml', _xml('<x/>'))]));
      expect(b.ok, isFalse);
    });

    test('Sicherung über der Größe (gepackt) wird vor dem Lesen abgelehnt', () async {
      final b = await archivPruefen(_gueltig(), maxBytes: 50);
      expect(b.ok, isFalse);
      expect(b.grund, contains('größer'));
    });

    test('entpackter Inhalt über der Grenze wird abgelehnt', () async {
      final b = await archivPruefen(_gueltig(), maxEntpackt: 100);
      expect(b.ok, isFalse);
    });

    test('zu viele Einträge werden abgelehnt', () async {
      final b = await archivPruefen(_gueltig(), maxEintraege: 1);
      expect(b.ok, isFalse);
    });

    test('leere Bewertungs- und Rollendateien einer Sicherung ohne Nutzerdaten werden angenommen (Regression Live-Messung)', () async {
      // Form wie in der gemessenen Sicherung: das Wurzelelement grade_history ist kein Eintrag zu einer Person.
      final b = await archivPruefen(_mbz([
        _eintrag('moodle_backup.xml', _xml(_sicherungXml())),
        _eintrag('grades.xml', _xml('<grade_grades>\n</grade_grades>\n')),
        _eintrag('grade_history.xml', _xml('<grade_history>\n  <grade_grades>\n  </grade_grades>\n</grade_history>\n')),
        _eintrag('roles.xml', _xml('<roles>\n  <role_assignments>\n  </role_assignments>\n</roles>\n')),
        _eintrag('activities/page_1/page.xml', _xml('<activity/>')),
      ]));
      expect(b.ok, isTrue, reason: b.grund);
    });

    test('Format, das kein Moodle-2-Archiv ist, wird abgelehnt', () async {
      final xml = _sicherungXml().replaceAll('moodle2', 'moodle1');
      final b = await archivPruefen(_mbz([_eintrag('moodle_backup.xml', _xml(xml))]));
      expect(b.ok, isFalse);
    });
  });

  group('Pfade und Nutzerdaten', () {
    test('pfadFehler', () {
      expect(pfadFehler('a/b.txt'), isNull);
      expect(pfadFehler('../x'), isNotNull);
      expect(pfadFehler('a/../../x'), isNotNull);
      expect(pfadFehler('/etc/x'), isNotNull);
      expect(pfadFehler(r'C:\x'), isNotNull);
      expect(pfadFehler(''), isNotNull);
    });

    test('nutzerdatenPfad', () {
      expect(nutzerdatenPfad('users.xml'), isTrue);
      expect(nutzerdatenPfad('activities/page_1/userdata/x.xml'), isTrue);
      expect(nutzerdatenPfad('user/files.xml'), isTrue);
      expect(nutzerdatenPfad('activities/page_1/page.xml'), isFalse);
    });

  });

  group('Archividentität beim Gegenlesen', () {
    const erwartet = [(modul: 'page', titel: 'Infoblatt')];

    test('ordnet die einzelne passende neue Aktivität zu', () {
      expect(importierteCmidsEindeutig(erwartet: erwartet, vorher: {4}, aktuell: const [
        (cmid: 4, modul: 'page', titel: 'Alt'),
        (cmid: 9, modul: 'page', titel: 'Infoblatt'),
      ]), [9]);
    });

    test('lässt parallele und mehrdeutige Neuanlagen unzugeordnet', () {
      expect(importierteCmidsEindeutig(erwartet: erwartet, vorher: {4}, aktuell: const [
        (cmid: 9, modul: 'page', titel: 'Infoblatt'),
        (cmid: 10, modul: 'forum', titel: 'Lehrkraft-Beitrag'),
      ]), isNull);
      expect(importierteCmidsEindeutig(erwartet: erwartet, vorher: {}, aktuell: const [
        (cmid: 9, modul: 'page', titel: 'Infoblatt'),
        (cmid: 10, modul: 'page', titel: 'Infoblatt'),
      ]), isNull);
      expect(importierteCmidsEindeutig(erwartet: const [
        (modul: 'page', titel: 'Infoblatt'), (modul: 'page', titel: 'Infoblatt')
      ], vorher: {}, aktuell: const [
        (cmid: 9, modul: 'page', titel: 'Infoblatt'),
        (cmid: 10, modul: 'page', titel: 'Infoblatt'),
      ]), isNull);
    });
  });

  group('Zustandsfolge', () {
    test('der gemessene Weg ist erlaubt', () {
      const folge = [
        WiederherstellungStand.anstehend,
        WiederherstellungStand.hochgeladen,
        WiederherstellungStand.laufend,
        WiederherstellungStand.fertig,
      ];
      for (var i = 0; i < folge.length - 1; i++) {
        expect(erlaubterUebergang(folge[i], folge[i + 1]), isTrue, reason: '${folge[i]} -> ${folge[i + 1]}');
      }
    });

    test('vor dem Start abbrechen ist erlaubt, nach dem Start nicht stillschweigend', () {
      expect(erlaubterUebergang(WiederherstellungStand.anstehend, WiederherstellungStand.fehlgeschlagen), isTrue);
      expect(erlaubterUebergang(WiederherstellungStand.hochgeladen, WiederherstellungStand.fehlgeschlagen), isTrue);
      expect(erlaubterUebergang(WiederherstellungStand.laufend, WiederherstellungStand.unklar), isTrue);
      expect(erlaubterUebergang(WiederherstellungStand.unklar, WiederherstellungStand.fertig), isTrue);
    });

    test('ohne Start nie laufend, und nie direkt von anstehend nach fertig', () {
      expect(erlaubterUebergang(WiederherstellungStand.anstehend, WiederherstellungStand.laufend), isFalse);
      expect(erlaubterUebergang(WiederherstellungStand.anstehend, WiederherstellungStand.fertig), isFalse);
      expect(erlaubterUebergang(WiederherstellungStand.hochgeladen, WiederherstellungStand.fertig), isFalse);
    });

    test('fertig und fehlgeschlagen bewegen sich nicht mehr', () {
      for (final nach in WiederherstellungStand.values) {
        expect(erlaubterUebergang(WiederherstellungStand.fertig, nach), isFalse);
        expect(erlaubterUebergang(WiederherstellungStand.fehlgeschlagen, nach), isFalse);
      }
    });

    test('unklar löst sich nie zurück nach anstehend oder hochgeladen', () {
      expect(erlaubterUebergang(WiederherstellungStand.unklar, WiederherstellungStand.anstehend), isFalse);
      expect(erlaubterUebergang(WiederherstellungStand.unklar, WiederherstellungStand.laufend), isFalse);
    });

    test('Stand aus Text: unbekannt wird null', () {
      expect(WiederherstellungStand.aus('laufend'), WiederherstellungStand.laufend);
      expect(WiederherstellungStand.aus('quatsch'), isNull);
      expect(WiederherstellungStand.aus(null), isNull);
    });
  });

  group('Positivliste für die Wiederherstellung', () {
    final z = MoodleZugang(Protokoll());
    bool post(String a, [List<MapEntry<String, String>>? f, Anhang? anhang]) =>
        z.erlaubt('POST', Uri.parse(a), f, null, anhang);
    bool get(String a) => z.erlaubt('GET', Uri.parse(a));
    const kurs = <MapEntry<String, String>>[];

    Anhang mbz({String mime = 'application/octet-stream', String name = 'kurs-12.mbz'}) =>
        Anhang('repo_upload_file', name, [1, 2, 3], mime);

    test('Kursseite nur mit id', () {
      expect(get('https://m.example/course/view.php?id=42'), isTrue);
      expect(get('https://m.example/course/view.php?id=42&edit=on'), isFalse);
      expect(kurs, isEmpty);
    });

    test('Upload einer .mbz nur mit Entwurfsbereich, Sitzung und passendem Namen und MIME', () {
      const formular = [MapEntry('itemid', '7'), MapEntry('sesskey', 'abc')];
      const up = 'https://m.example/repository/repository_ajax.php?action=upload';
      expect(post(up, formular, mbz()), isTrue);
      expect(post(up, formular, mbz(mime: 'text/plain')), isFalse);
      expect(post(up, formular, mbz(name: '../evil.mbz')), isFalse);
      expect(post(up, const [MapEntry('sesskey', 'abc')], mbz()), isFalse);
    });

    test('andere Dateien laufen nicht über den .mbz-Pfad, und ohne Datei gibt es keinen Upload', () {
      const up = 'https://m.example/repository/repository_ajax.php?action=upload';
      expect(post(up, null, Anhang('repo_upload_file', 'bild.png', [1], 'image/png')), isTrue);
      expect(post(up, null, mbz()), isFalse);
      expect(post(up), isFalse);
    });

    test('Formular „Wiederherstellen" nur mit der Marke und Kurs-ID', () {
      const ziel = 'https://m.example/backup/restorefile.php?contextid=5';
      const gut = [
        MapEntry('_qf__course_restore_form', '1'),
        MapEntry('sesskey', 'abc'),
        MapEntry('backupfile', '99'),
      ];
      expect(post(ziel, gut), isTrue);
      expect(post(ziel, [...gut, const MapEntry('submitbutton', 'Weiter')]), isTrue);
      expect(post(ziel, [...gut, const MapEntry('contextid', '5')]), isTrue);
      expect(post('https://m.example/backup/restorefile.php?contextid=5&x=1', gut), isFalse);
      expect(post(ziel, const [MapEntry('sesskey', 'abc'), MapEntry('backupfile', '99')]), isFalse);
      // Jedes weitere Feld lehnt die Regel ab, auch wenn Marke, Sitzung und Itemid stimmen.
      expect(post(ziel, [...gut, const MapEntry('name', 'x')]), isFalse);
      expect(post(ziel, [...gut, const MapEntry('contextid', 'abc')]), isFalse);
      expect(post(ziel, [...gut]..[2] = const MapEntry('backupfile', 'abc')), isFalse);
    });

    test('Weiterleitung nach dem Hochladen nur mit Dateiablagen-Hash und den erlaubten Schlüsseln', () {
      const hash = 'da39a3ee5e6b4b0d3255bfef95601890afd80709';
      expect(get('https://m.example/backup/restore.php?contextid=5&pathnamehash=$hash'), isTrue);
      expect(get('https://m.example/backup/restore.php?contextid=5&pathnamehash=$hash&component=backup&filearea=draft'),
          isTrue);
      expect(get('https://m.example/backup/restore.php?contextid=5&pathnamehash=xyz'), isFalse);
      expect(get('https://m.example/backup/restore.php?contextid=5&pathnamehash=$hash&extra=1'), isFalse);
      expect(get('https://m.example/backup/restore.php?contextid=5'), isFalse);
    });

    test('Sicherungsdetails (stage 2) nur mit den gemessenen Feldern', () {
      const ziel = 'https://m.example/backup/restore.php?contextid=5&filename=kurs.mbz';
      const gut = [
        MapEntry('contextid', '5'),
        MapEntry('filepath', '/'),
        MapEntry('filename', 'kurs.mbz'),
        MapEntry('stage', '2'),
        MapEntry('sesskey', 'abc'),
      ];
      expect(post(ziel, gut), isTrue);
      expect(post(ziel, [...gut, const MapEntry('name', 'x')]), isFalse);
      expect(post(ziel, [...gut]..[3] = const MapEntry('stage', '4')), isFalse);
      expect(post(ziel, [...gut, const MapEntry('_qf__restore_target_form', '1')]), isFalse);
    });

    test('Zielwahl (Formular mit stage 4) nur mit target 4, Kurs-ID und den gemessenen Feldern', () {
      const ziel = 'https://m.example/backup/restore.php?contextid=5&filename=kurs.mbz';
      const gut = [
        MapEntry('contextid', '5'),
        MapEntry('filepath', '/'),
        MapEntry('filename', 'kurs.mbz'),
        MapEntry('stage', '4'),
        MapEntry('target', '4'),
        MapEntry('targetid', '42'),
        MapEntry('search', ''),
        MapEntry('sesskey', 'abc'),
      ];
      expect(post(ziel, gut), isTrue);
      expect(post(ziel, [...gut]..[4] = const MapEntry('target', '2')), isFalse);
      expect(post(ziel, [...gut]..[5] = const MapEntry('targetid', 'x')), isFalse);
      expect(post(ziel, [...gut, const MapEntry('_qf__restore_target_form', '1')]), isFalse);
      expect(post(ziel, [...gut, const MapEntry('setting_root_users', '1')]), isFalse);
    });

    test('Schritte 4, 8, 16 nur ohne Nutzerdaten und mit dem Schalter restore', () {
      const ziel = 'https://m.example/backup/restore.php?contextid=5&filename=kurs.mbz';
      const schritte = [('4', 'settings'), ('8', 'schema'), ('16', 'review')];
      for (final (schritt, form) in schritte) {
        final gut = [
          MapEntry('stage', schritt),
          MapEntry('_qf__restore_${form}_form', '1'),
          const MapEntry('restore', 'Weiter'),
          const MapEntry('sesskey', 'abc'),
        ];
        expect(post(ziel, gut), isTrue, reason: 'Schritt $schritt');
        expect(post(ziel, gut.where((e) => e.key != 'restore').toList()), isFalse, reason: 'ohne restore, $schritt');
        expect(post(ziel, [...gut, const MapEntry('setting_root_users', '1')]), isFalse, reason: 'Nutzer, $schritt');
      }
    });

    test('der Assistent-Aufruf nimmt nur contextid und filename, mit sicheren Zeichen', () {
      expect(get('https://m.example/backup/restore.php?contextid=5&filename=kurs-12.mbz'), isTrue);
      expect(get('https://m.example/backup/restore.php?contextid=5&filename=../x'), isFalse);
      expect(get('https://m.example/backup/restore.php?contextid=5&filename=k.mbz&extra=1'), isFalse);
    });
  });

  // Befund 8: ein nicht schreibbarer Typ darf nie verifiziert werden.
  group('nichtSchreibbarePruefluecke', () {
    test('nur schreibbare Typen: keine Prüflücke', () {
      expect(nichtSchreibbarePruefluecke(['page', 'quiz', 'resource']), isNull);
    });

    test('nicht schreibbarer Typ: Prüflücke nennt den Typ', () {
      final t = nichtSchreibbarePruefluecke(['page', 'lernlandkarte']);
      expect(t, isNotNull);
      expect(t, contains('lernlandkarte'));
    });
  });

  group('Sichtbarkeit der wiederhergestellten Inhalte: keine Vorgabe', () {
    test('beide Werte werden erkannt', () {
      expect(WiederherstellungsSichtbarkeit.aus('wie_quelle'), WiederherstellungsSichtbarkeit.wieQuelle);
      expect(WiederherstellungsSichtbarkeit.aus('verborgen'), WiederherstellungsSichtbarkeit.verborgen);
    });

    test('ohne Angabe kommt die Rückfrage an die Lehrkraft, kein Wert wird eingesetzt', () {
      expect(
        () => WiederherstellungsSichtbarkeit.aus(null),
        throwsA(
          isA<MoodleFehler>().having(
            (e) => e.meldung,
            'meldung',
            allOf(
              contains('Frag die Lehrkraft'),
              contains('wie in der Quelle sichtbar bleiben oder verborgen werden'),
              contains('CLAUDE.md'),
              contains('Nichts geändert'),
            ),
          ),
        ),
      );
    });

    test('ein unbekannter Wert ist keine Rückfrage, sondern ein Fehler mit den beiden Werten', () {
      expect(
        () => WiederherstellungsSichtbarkeit.aus('sichtbar'),
        throwsA(isA<MoodleFehler>().having((e) => e.meldung, 'meldung', contains('wie_quelle oder verborgen'))),
      );
    });
  });

  group('Löschliste vor dem Ersetzen', () {
    test('die reinen Inhaltsarten sind genau diese neun', () {
      expect(inhaltsModule, {'page', 'label', 'url', 'resource', 'folder', 'book', 'subsection', 'qbank', 'learningmap'});
    });

    test('Inhaltsarten fallen nicht auf', () {
      for (final m in inhaltsModule) {
        expect(loeschHinweis(m).auffaellig, isFalse, reason: m);
        expect(loeschHinweis(m).text, isEmpty, reason: m);
      }
    });

    test('alles andere kann Daten von Lernenden enthalten', () {
      for (final m in ['assign', 'quiz', 'forum', 'wiki', 'board', 'kanban', 'checklist', 'choice', 'glossary', 'data', 'h5pactivity', 'zzfremd']) {
        expect(loeschHinweis(m).lernendendaten, isTrue, reason: m);
        expect(loeschHinweis(m).auffaellig, isTrue, reason: m);
      }
    });

    test('nicht unterstützt ist, was moocp weder anlegen noch ändern kann', () {
      for (final m in ['forum', 'glossary', 'choice', 'data', 'collabora', 'choicegroup', 'zzfremd']) {
        expect(loeschHinweis(m).nichtUnterstuetzt, isTrue, reason: m);
      }
      for (final m in [...MoodleZugang.schreibbareModule, 'learningmap']) {
        expect(loeschHinweis(m).nichtUnterstuetzt, isFalse, reason: m);
      }
    });

    test('die Begründung nennt beide Gründe, wo beide zutreffen', () {
      expect(
        loeschHinweis('forum').text,
        'kann Daten von Lernenden enthalten; von moocp nicht unterstützt, Inhalt dort nicht einsehbar',
      );
      expect(loeschHinweis('assign').text, 'kann Daten von Lernenden enthalten');
      expect(loeschHinweis('page').text, '');
    });

    test('die Adresse führt zur Aktivität in der eigenen Instanz', () {
      final basis = Uri.parse('https://moodle.schule.example');
      final adresse = aktivitaetsAdresse(basis, (cmid: 42, modul: 'assign', name: 'ZZ'), 12);
      expect(adresse.toString(), 'https://moodle.schule.example/mod/assign/view.php?id=42');
    });

    test('ein Modulname, der keiner ist, führt auf die Kursseite, nie in eine fremde Adresse', () {
      final basis = Uri.parse('https://moodle.schule.example');
      for (final modul in ['../admin', 'a/b', 'a b', 'x?y=1', '', 'https://boese.example']) {
        final adresse = aktivitaetsAdresse(basis, (cmid: 42, modul: modul, name: 'ZZ'), 12);
        expect(adresse.toString(), 'https://moodle.schule.example/course/view.php?id=12', reason: modul);
      }
    });

    LoeschAktivitaet akt(int cmid, String name, [String modul = 'page']) => (cmid: cmid, modul: modul, name: name);

    test('listeWeichtAb: gleiche Liste in anderer Reihenfolge ist gleich', () {
      expect(listeWeichtAb([akt(1, 'A'), akt(2, 'B')], [akt(2, 'B'), akt(1, 'A')]), isNull);
      expect(listeWeichtAb([], []), isNull);
    });

    test('listeWeichtAb: dazugekommen, entfernt, umbenannt, andere Art', () {
      final alt = [akt(1, 'A'), akt(2, 'B'), akt(3, 'C')];
      expect(listeWeichtAb(alt, [...alt, akt(4, 'D')]), 'dazugekommen: „D"');
      expect(listeWeichtAb(alt, [akt(1, 'A'), akt(3, 'C')]), 'nicht mehr da: „B"');
      expect(listeWeichtAb(alt, [akt(1, 'A'), akt(2, 'B2'), akt(3, 'C')]), 'geändert: „B" ist jetzt „B2"');
      expect(listeWeichtAb(alt, [akt(1, 'A'), akt(2, 'B', 'forum'), akt(3, 'C')]), 'geändert: „B" ist jetzt „B"');
      expect(
        listeWeichtAb(alt, [akt(1, 'A'), akt(4, 'D')]),
        'dazugekommen: „D"; nicht mehr da: „B", „C"',
      );
    });

    test('listeWeichtAb nennt höchstens fünf Namen und zählt den Rest', () {
      final viele = [for (var i = 0; i < 8; i++) akt(100 + i, 'N$i')];
      expect(listeWeichtAb([], viele), 'dazugekommen: „N0", „N1", „N2", „N3", „N4" und 3 weitere');
    });

    test('loeschGruppenBauen: auffällige zuerst und hervorgehoben, der Rest danach; Namen mit Art und Link', () {
      final basis = Uri.parse('https://moodle.schule.example');
      final gruppen = loeschGruppenBauen(basis, [
        (cmid: 1, modul: 'page', name: 'Seite'),
        (cmid: 2, modul: 'forum', name: 'Forum'),
        (cmid: 3, modul: 'label', name: 'Text'),
        (cmid: 4, modul: 'quiz', name: 'Test'),
      ], 12);
      expect(gruppen, hasLength(2));
      expect(gruppen[0].warnung, isTrue);
      expect(gruppen[0].titel, startsWith('Zuerst ansehen (2)'));
      expect(gruppen[0].links.map((l) => l.text), ['„Forum" (Forum)', '„Test" (Test)']);
      expect(gruppen[0].links.every((l) => l.warnung != null), isTrue);
      expect(gruppen[1].warnung, isFalse);
      expect(gruppen[1].titel, 'Weitere Aktivitäten, die gelöscht werden (2)');
      expect(gruppen[1].links.map((l) => l.text), ['„Seite" (Textseite)', '„Text" (Textfeld)']);
      expect(gruppen[1].links.map((l) => l.adresse.toString()), [
        'https://moodle.schule.example/mod/page/view.php?id=1',
        'https://moodle.schule.example/mod/label/view.php?id=3',
      ]);
    });

    test('loeschGruppenBauen: nur eine der beiden Gruppen, wenn die andere leer wäre; leerer Kurs ohne Gruppe', () {
      final basis = Uri.parse('https://moodle.schule.example');
      expect(loeschGruppenBauen(basis, [(cmid: 1, modul: 'page', name: 'S')], 12).map((g) => g.warnung), [false]);
      expect(loeschGruppenBauen(basis, [(cmid: 1, modul: 'forum', name: 'F')], 12).map((g) => g.warnung), [true]);
      expect(loeschGruppenBauen(basis, [], 12), isEmpty);
    });
  });

  group('behaltenFelder: die Einstellungen zu Einschreibungen und Gruppen im Formular', () {
    Antwort seite(String formular, {String aktion = '/backup/restore.php?contextid=5&filename=x'}) => Antwort(
      200,
      Uri.parse('https://moodle.schule.example/backup/restore.php'),
      Uint8List.fromList(utf8.encode('<form action="$aktion" method="post">$formular</form>')),
      'text/html',
    );
    const rollen = 'setting_root_keep_roles_and_enrolments';
    const gruppen = 'setting_root_keep_groups_and_groupings';

    test('beide angeboten (verstecktes Feld und Kontrollkästchen)', () {
      final f = behaltenFelder(seite(
        '<input type="hidden" name="$rollen" value="0"><input type="checkbox" name="$rollen" value="1">'
        '<input type="hidden" name="$gruppen" value="0"><input type="checkbox" name="$gruppen" value="1" checked>',
      ));
      expect((rollen: f.rollen, gruppen: f.gruppen), (rollen: rollen, gruppen: gruppen));
    });

    test('ein nicht angekreuztes Kontrollkästchen allein zählt als angeboten', () {
      final f = behaltenFelder(seite('<input type="checkbox" name="$rollen" value="1"><input type="checkbox" name="$gruppen" value="1">'));
      expect(f.rollen, rollen);
      expect(f.gruppen, gruppen);
    });

    test('fehlt eines, ist es null; das andere bleibt gefunden', () {
      final f = behaltenFelder(seite('<input type="checkbox" name="$rollen" value="1">'));
      expect(f.rollen, rollen);
      expect(f.gruppen, isNull);
      final g = behaltenFelder(seite('<input type="text" name="setting_root_users" value="0">'));
      expect(g.rollen, isNull);
      expect(g.gruppen, isNull);
    });

    test('ein gesperrtes Feld gilt als nicht angeboten, auch wenn ein verstecktes danebensteht', () {
      final f = behaltenFelder(seite(
        '<input type="hidden" name="$rollen" value="0"><input type="checkbox" name="$rollen" value="1" disabled>'
        '<input type="checkbox" name="$gruppen" value="1">',
      ));
      expect(f.rollen, isNull);
      expect(f.gruppen, gruppen);
    });

    test('nur im Formular des Assistenten, nicht in einem fremden Formular der Seite', () {
      final f = behaltenFelder(seite('<input type="checkbox" name="$rollen" value="1">', aktion: '/course/edit.php'));
      expect(f.rollen, isNull);
    });
  });
}
