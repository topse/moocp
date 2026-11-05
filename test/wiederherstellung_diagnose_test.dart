import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/moodle_zugang.dart';
import 'package:moocp/moodle/wiederherstellung.dart';

Antwort _antwort(String html, {String? ort}) => Antwort(
  200,
  Uri.parse('https://moodle.schule.example/backup/restore.php'),
  Uint8List.fromList(utf8.encode(html)),
  'text/html',
  ort: ort,
);

void main() {
  test('Startdiagnose nennt nur Aufbau, nie Texte oder Werte', () {
    final text = startDiagnose(
      _antwort(
        '<html><body id="page-backup-restore">'
        '<div class="alert alert-warning">Geheimer Kursname</div>'
        '<form action="/backup/restore.php"><input name="sesskey" value="abc">'
        '<input name="restore" value="wert123"></form></body></html>',
        ort: '/course/view.php?id=12',
      ),
    );
    expect(text, contains('Umleitung /course/view.php'));
    expect(text, contains('Seite page-backup-restore'));
    expect(text, contains('alert-warning'));
    expect(text, contains('restore'));
    expect(text, isNot(contains('Geheimer Kursname')));
    expect(text, isNot(contains('wert123')));
    expect(text, isNot(contains('id=12')));
  });

  test('Fortschrittsdiagnose zeigt Zahlen und Feldnamen, sonst nichts', () {
    final id = 'a' * 32;
    expect(
      fortschrittDiagnose([
        {'backupid': id, 'status': 400, 'progress': 0, 'info': 'Text'},
      ], id),
      allOf(contains('status 400'), contains('progress 0'), isNot(contains('Text'))),
    );
    expect(fortschrittDiagnose([], id), contains('kein Eintrag'));
  });

  test('Zielseite: Optionsfelder ohne Vorwahl zählen als angebotene Zielwege', () {
    // Wie für ein Lehrkraftkonto gemessen: Einfügen (1) und Ersetzen (0) im aktuellen Kurs
    // stehen in einem Formular als Optionsfelder, keines gewählt; der andere Kurs (4) hat
    // seinen Weg als verstecktes Feld.
    final formulare = restoreFormulare(_antwort(
      '<html><body>'
      '<form action="/backup/restore.php"><input type="hidden" name="stage" value="4">'
      '<input type="radio" name="target" value="1"><input type="radio" name="target" value="0">'
      '<input type="hidden" name="targetid" value="12"></form>'
      '<form action="/backup/restore.php"><input type="hidden" name="stage" value="4">'
      '<input type="hidden" name="target" value="4"></form>'
      '</body></html>',
    ));
    expect(formulare, hasLength(2));
    expect(formulare.first.ziele, {'1', '0'});
    expect(formulare.last.ziele, {'4'});
  });
}
