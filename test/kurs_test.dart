// Offline prüfbar: die Auswertung der Kursstruktur an einem erfundenen Kurs.
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/freigabe.dart';
import 'package:moocp/moodle/kurs.dart';

Map<String, Object?> cm(int id, String modul, String name, int abschnitt,
        {bool sichtbar = true, bool stealth = false, bool eingeschraenkt = false, int? delegiert}) =>
    {
      'id': '$id',
      'name': name,
      'module': modul,
      'modname': 'Anzeigename',
      'visible': sichtbar,
      'stealth': stealth,
      'hascmrestrictions': eingeschraenkt,
      'sectionid': '$abschnitt',
      'indent': 0,
      'delegatesectionid': ?delegiert,
    };

void main() {
  test('Abschnitte, Unterabschnitte, Sichtbarkeit, Schutzprüfung', () {
    final k = kursAuswerten(12, {
      'course': {
        'id': 12,
        'sectionlist': [100, 101, 102, 103]
      },
      'section': [
        {'id': '100', 'number': 0, 'title': 'Allgemeines', 'visible': true, 'cmlist': ['1']},
        {'id': '101', 'number': 1, 'title': 'LS 1: Muster &amp; Beispiel', 'visible': true, 'cmlist': ['2', '3', '4']},
        {'id': '102', 'number': 2, 'title': 'Lösungen', 'visible': false, 'cmlist': ['5']},
        // delegierter Abschnitt des Unterabschnitts 4
        {'id': '103', 'number': 3, 'title': 'Phase Planen', 'visible': true, 'component': 'mod_subsection', 'cmlist': ['6']},
      ],
      'cm': [
        cm(1, 'forum', 'Ankündigungen', 100),
        cm(2, 'page', 'Info: Der Vorwiderstand', 101),
        cm(3, 'folder', 'Musterlösung', 101, stealth: true),
        cm(4, 'subsection', 'Phase Planen', 101, delegiert: 103),
        cm(5, 'assign', 'Lösung Aufgabe 1', 102, sichtbar: false),
        cm(6, 'label', 'Hinweis', 103, eingeschraenkt: true),
      ],
    });
    expect(k.nachCmid[2]!.name, 'Info: Der Vorwiderstand');
    expect(k.nachId[101]!.titel, 'LS 1: Muster & Beispiel');
    expect(k.nachCmid[3]!.sichtbarkeit, Sichtbarkeit.ohneLink);
    expect(k.nachCmid[6]!.sichtbarkeit, Sichtbarkeit.eingeschraenkt);
    expect(k.nachCmid[4]!.unterabschnittId, 103);
    expect(k.nachId[103]!.elternId, 101);
    expect([for (final c in k.inhalt(k.nachId[101]!)) c.cmid], [2, 3, 4, 6]);
    // Verborgenes ist geschützt, auch wenn es „Lösung" heißt; Stealth nicht.
    expect([for (final (c, _) in k.schutzBefunde()) c.cmid], [3]);
    final t = k.text(kursname: 'Erfundener Kurs');
    expect(t, contains('Abschnitt 1 [id 101] „LS 1: Muster & Beispiel"'));
    expect(t, contains('    Abschnitt 3 [id 103] „Phase Planen" (Unterabschnitt)'));
    expect('Abschnitt 3 [id 103]'.allMatches(t).length, 1, reason: 'Unterabschnitt nur einmal, eingerückt');
    expect(t, contains('ACHTUNG'));
  });

  test('Unterabschnitt ohne delegatesectionid: über parentsectionid zugeordnet', () {
    final k = kursAuswerten(12, {
      'section': [
        {'id': '200', 'number': 0, 'title': 'A', 'visible': true, 'cmlist': ['7']},
        {'id': '201', 'number': 1, 'title': 'U', 'visible': true, 'component': 'mod_subsection', 'parentsectionid': 200, 'cmlist': []},
      ],
      'cm': [cm(7, 'subsection', 'U', 200)],
    });
    expect(k.nachCmid[7]!.unterabschnittId, 201);
  });

  test('Füllen fragt erst bei „alle", solange die Aktivität der Arbeitssitzung gehört', () {
    final k = kursAuswerten(12, {
      'course': {
        'id': 12,
        'sectionlist': [100]
      },
      'section': [
        {'id': '100', 'number': 0, 'title': 'Allgemeines', 'visible': true, 'cmlist': ['1', '2', '3', '4']},
      ],
      'cm': [
        cm(1, 'board', 'Neu und verborgen', 100, sichtbar: false),
        cm(2, 'kanban', 'Neu, inzwischen sichtbar', 100),
        cm(3, 'checklist', 'Von Hand angelegt, verborgen', 100, sichtbar: false),
        cm(4, 'page', 'Neu, ohne Link erreichbar', 100, stealth: true),
      ],
    });
    final selbst = {1, 2, 4};
    expect(fuellenAbIn(k, selbst, [1]), Bestaetigungen.alle);
    // Sichtbar oder erreichbar: Lernende können es sehen.
    expect(fuellenAbIn(k, selbst, [2]), Bestaetigungen.mittel);
    expect(fuellenAbIn(k, selbst, [4]), Bestaetigungen.mittel);
    // Nicht von der App angelegt: Bestehendes, wie immer ab „mittel".
    expect(fuellenAbIn(k, selbst, [3]), Bestaetigungen.mittel);
    // Mehrere zusammen nur, wenn jede dazugehört; ohne Aktivität (Abschnitt,
    // Frage) nie.
    expect(fuellenAbIn(k, selbst, [1, 3]), Bestaetigungen.mittel);
    expect(fuellenAbIn(k, selbst, [1, null]), Bestaetigungen.mittel);
    expect(fuellenAbIn(k, selbst, const []), Bestaetigungen.mittel);
  });
}
