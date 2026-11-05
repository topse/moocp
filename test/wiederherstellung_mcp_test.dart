// Öffentliche MCP-Verträge; nur Moodle wird durch einen lokalen HTTP-Server ersetzt.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/einstellungen.dart';
import 'package:moocp/freigabe.dart';
import 'package:moocp/mcp/mcp_dienst.dart';
import 'package:moocp/moodle/moodle_zugang.dart';
import 'package:moocp/moodle/sicherung.dart';
import 'package:moocp/moodle/sicherung_regeln.dart';
import 'package:moocp/moodle/wiederherstellung_regeln.dart';
import 'package:moocp/profil.dart';
import 'package:moocp/protokoll.dart';
import 'package:path/path.dart' as p;

import 'eigene_sicherung.dart';
import 'mcp_client.dart';

/// Ein .mbz aus Dateien (Pfad im Archiv -> Text), wie Moodle es packt: gzip um ein Tar.
List<int> _mbzBytes(Map<String, String> dateien) {
  final archive = Archive();
  for (final e in dateien.entries) {
    archive.addFile(ArchiveFile.bytes(e.key, utf8.encode(e.value)));
  }
  return GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive));
}

/// Eine gültige Sicherung ohne Nutzerdaten, wie der Download der Attrappe sie liefert.
const _kursArchiv = {
  'moodle_backup.xml':
      '<moodle_backup><information><format>moodle2</format><type>course</type></information></moodle_backup>',
  'files.xml': '<files/>',
};

class _Moodle {
  late HttpServer server;
  int requests = 0;
  int starts = 0;
  int backupStarts = 0;
  String modul = 'page';
  String title = 'ZZ Blatt';
  int downloads = 0;
  bool failProgress = false;
  bool linkAvailable = true;
  static final backupBytes = _mbzBytes(_kursArchiv);

  /// Was der Download liefert; die Tests tauschen es gegen Archive mit Nutzerdaten oder Code.
  List<int> downloadBytes = backupBytes;
  int writes = 0;
  int progressReads = 0;
  Object progress = <String, Object?>{'progress': 0.2};
  Completer<void>? hold;
  bool completed = false;
  bool completeOnStart = false;
  bool sichtbar = false;
  int verbergen = 0;
  bool rollenSeite = false;
  bool startFehlerseite = false;
  String? rollenSonderfall;
  bool uploadFormularFehlt = false;
  int rollenBestaetigt = 0;
  List<String> weitereQuizze = [];

  /// Aktivitäten, die vor dem Lauf im Zielkurs liegen. Moodle löscht sie beim Start eines
  /// löschenden Wegs (target 0 oder 3), außer [altBleibt].
  List<Map<String, Object?>> alt = [];
  bool altBleibt = false;
  bool altEntfernt = false;
  String? gewaehlterWeg;

  /// Wie die Einstellungsseite die Felder „Rollen und Einschreibungen behalten" und
  /// „Gruppen und Gruppierungen behalten" anbietet: beide (mit verstecktem 0 und Kontrollkästchen),
  /// nurCheckbox (nicht angekreuztes Kontrollkästchen ohne verstecktes Feld), nurRollen, gesperrt, keine.
  String keepAngebot = 'beide';

  /// Die Felder, die die Einstellungsseite zurückbekam.
  Map<String, String>? einstellungsFormular;
  static const restore = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  Uri get basis => Uri.parse('http://127.0.0.1:${server.port}');
  String page(String body) => '<script>M.cfg = {"sesskey":"sk","courseId":12,"contextid":"55"};</script>$body';
  String form(Map<String, String> fields, {String path = '/backup/restore.php', String extra = ''}) => page(
    '<form class="mform" action="$path" method="post">${{'sesskey': 'sk', ...fields}.entries.map((e) => '<input type="hidden" name="${e.key}" value="${e.value}">').join()}$extra</form>',
  );

  String get _keepFelder {
    String feld(String name, {bool gesperrt = false}) => keepAngebot == 'nurCheckbox'
        ? '<input type="checkbox" name="$name" value="1">'
        : '<input type="hidden" name="$name" value="0"><input type="checkbox" name="$name" value="1"${gesperrt ? ' disabled' : ''}>';
    const rollen = 'setting_root_keep_roles_and_enrolments';
    const gruppen = 'setting_root_keep_groups_and_groupings';
    return switch (keepAngebot) {
      'keine' => '',
      'nurRollen' => feld(rollen),
      'gesperrt' => feld(rollen) + feld(gruppen, gesperrt: true),
      _ => feld(rollen) + feld(gruppen),
    };
  }
  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      requests++;
      final path = r.uri.path;
      final body = await const Utf8Decoder(allowMalformed: true).bind(r).join();
      String answer;
      if (path == '/login/index.php') {
        if (r.method == 'POST' || r.uri.queryParameters.containsKey('testsession')) {
          r.response.redirect(Uri.parse(r.method == 'POST' ? '/login/index.php?testsession=1' : '/my/'), status: 303);
          await r.response.close();
          return;
        }
        r.response.cookies.add(Cookie('MoodleSession', 'test'));
        answer = r.cookies.isNotEmpty ? page('Angemeldet') : '<form><input name="logintoken" value="tok"></form>';
      } else if (path == '/my/' || path == '/course/view.php') {
        answer = page('<p>ZZ Kurs</p>');
      } else if (path == '/lib/ajax/service.php') {
        final call = (jsonDecode(body) as List).single as Map;
        Object? data;
        switch (call['methodname']) {
          case 'core_course_get_enrolled_courses_by_timeline_classification':
            data = {
              'courses': [
                {'id': 12, 'fullname': 'ZZ Kurs', 'shortname': 'ZZ'},
                {'id': 34, 'fullname': 'ZZ Ziel', 'shortname': 'ZZZ'},
              ],
            };
          case 'core_courseformat_get_state':
            final altDa = altEntfernt && !altBleibt ? const <Map<String, Object?>>[] : alt;
            data = {
              'cm': [
                for (final a in altDa) {'visible': 1, 'sectionid': 1, ...a},
                if (completed) {'id': 70, 'module': modul, 'name': title, 'visible': sichtbar ? 1 : 0, 'sectionid': 1},
                if (completed)
                  for (var i = 0; i < weitereQuizze.length; i++)
                    {'id': 71 + i, 'module': 'quiz', 'name': weitereQuizze[i], 'visible': 0, 'sectionid': 1},
              ],
              'section': [
                {
                  'id': 1,
                  'visible': 1,
                  'cmlist': [
                    for (final a in altDa) a['id'],
                    if (completed) 70,
                    if (completed) for (var i = 0; i < weitereQuizze.length; i++) 71 + i,
                  ],
                },
              ],
            };
          case 'core_courseformat_update_course':
            final args = call['args'] as Map;
            if (args['action'] != 'cm_hide') throw StateError('Unerwartete Kursaktion');
            verbergen++;
            sichtbar = false;
            data = {};
          case 'core_backup_get_async_backup_progress':
            progressReads++;
            final waiting = hold;
            if (waiting != null) await waiting.future;
            if (failProgress) {
              r.response.write('kein JSON');
              await r.response.close();
              return;
            }
            data = [
              {'backupid': restore, ...(progress as Map).cast<String, Object?>()},
            ];
          default:
            throw StateError('Unerwarteter Dienst: ${call['methodname']}');
        }
        answer = jsonEncode([
          {'error': false, 'data': data},
        ]);
      } else if (path == '/repository/repository_ajax.php') {
        writes++;
        answer = jsonEncode({'url': '$basis/draftfile.php/55/user/draft/9/test.mbz'});
      } else if (path == '/backup/backup.php') {
        if (r.method == 'GET') {
          // Wie auf der Testinstanz gemessen: Für eine Lehrkraft mit dem Recht, Nutzerdaten zu
          // sichern, ist „Nutzerdaten" vorab angekreuzt. Die App muss es selbst ausschalten.
          answer = form({'stage': '1', '_qf__backup_initial_form': '1', 'setting_root_users': '1'}, path: path);
        } else {
          final f = Uri.splitQueryString(body);
          if (f['stage'] == '1' && f['setting_root_users'] != '0') {
            throw StateError('Schritt 1 ohne setting_root_users=0 gesendet: ${f['setting_root_users']}');
          }
          if (f['stage'] == '1') {
            answer = form({
              'stage': '2',
              '_qf__backup_schema_form': '1',
              'setting_root_users': '0',
              'setting_section_section_1_included': '1',
            }, path: path);
          } else if (f['stage'] == '2') {
            answer = form({
              'stage': '4',
              '_qf__backup_confirmation_form': '1',
              'backup': restore,
              'setting_root_filename': 'download.mbz',
              'setting_root_users': '0',
              'setting_section_section_1_included': '1',
            }, path: path);
          } else {
            backupStarts++;
            answer = page('Gestartet');
          }
        }
      } else if (path == '/pluginfile.php/55/user/backup/1/download.mbz') {
        downloads++;
        r.response.contentLength = downloadBytes.length;
        r.response.add(downloadBytes);
        await r.response.close();
        return;
      } else if (path == '/backup/restorefile.php') {
        if (r.method == 'POST') {
          writes++;
          r.response.redirect(Uri.parse('/backup/restore.php?contextid=55&filename=abc'), status: 303);
          await r.response.close();
          return;
        }
        final upload = uploadFormularFehlt ? '' : form({'_qf__course_restore_form': '1', 'backupfile': '9'}, path: path);
        final anderesFormular = form({'anderes_feld': 'technisch'}, path: path);
        final link = linkAvailable
            ? '<a href="/pluginfile.php/55/user/backup/1/download.mbz?forcedownload=1">download.mbz</a>'
            : '';
        answer = '$anderesFormular$upload<script>var repo = {"id":4,"type":"upload"};</script>$link';
      } else if (path == '/backup/restore.php') {
        if (r.method == 'GET') {
          answer = form({'contextid': '55', 'filename': 'abc', 'stage': '2'});
        } else {
          writes++;
          final f = Uri.splitQueryString(body);
          if (f.containsKey('_qf__restore_review_form') && rollenSeite) {
            answer = form({
              'restore': restore, 'stage': '32', 'substage': 'rolemapping',
              'mapping5': rollenSonderfall == 'leer' ? '' : '5',
              if (rollenSonderfall == 'zusatzfeld') 'unerwartet': '1',
            });
          } else if (f.containsKey('substage')) {
            rollenBestaetigt++;
            starts++;
            if (gewaehlterWeg == '0' || gewaehlterWeg == '3') altEntfernt = true;
            if (completeOnStart) completed = true;
            answer = rollenSonderfall == 'erneut'
                ? form({'restore': restore, 'stage': '32', 'substage': 'rolemapping', 'mapping5': '5'})
                : page('Gestartet');
          } else if (f.containsKey('_qf__restore_review_form')) {
            starts++;
            if (gewaehlterWeg == '0' || gewaehlterWeg == '3') altEntfernt = true;
            if (completeOnStart) completed = true;
            answer = startFehlerseite
                ? '${page('<div class="alert alert-danger">Nicht protokollieren</div>')}${form({'restore': restore, 'stage': '32', 'substage': '1'})}'
                : page('Gestartet');
          } else if (f.containsKey('_qf__restore_schema_form')) {
            answer = form({'_qf__restore_review_form': '1', 'stage': '16', 'restore': restore});
          } else if (f.containsKey('_qf__restore_settings_form')) {
            einstellungsFormular = f;
            answer = form({'_qf__restore_schema_form': '1', 'stage': '8', 'restore': restore});
          } else if (f.containsKey('target')) {
            gewaehlterWeg = f['target'];
            answer = form({'_qf__restore_settings_form': '1', 'stage': '4', 'restore': restore}, extra: _keepFelder);
          } else {
            // Alle fünf Wege wie im Kurskontext (gemessen); die App nimmt das Formular mit ihrem target.
            answer = [
              for (final t in [0, 1, 2, 3, 4])
                form({'contextid': '55', 'filename': 'abc', 'stage': '4', 'target': '$t', 'targetid': '12'}),
            ].join();
          }
        }
      } else if (path == '/mod/quiz/edit.php') {
        answer = page(
          '<script>var quiz = {"quizid": 8};</script><li class="slot qtype_multichoice" id="slot-1"><span class="questionname">ZZ Frage</span></li>',
        );
      } else if (path == '/question/bank/importquestions/import.php') {
        answer = page('<select name="category"><option value="1,55">ZZ Sammlung (1)</option></select>');
      } else if (path == '/question/bank/exportquestions/export.php') {
        if (r.method == 'GET') {
          answer = form({'_qf__export_form': '1', 'format': 'xml'}, path: path);
        } else {
          answer = '<a href="/pluginfile.php/55/question/export/1/export.xml">Export</a>';
        }
      } else if (path == '/pluginfile.php/55/question/export/1/export.xml') {
        answer = '<?xml version="1.0"?><quiz><question type="multichoice"><name><text>ZZ Frage</text></name><idnumber>ZZ-1</idnumber></question></quiz>';
      } else if (path == '/course/modedit.php') {
        answer = page('<form class="mform"></form>');
      } else {
        throw StateError('Unerwartete Adresse: $path');
      }
      r.response.headers.contentType = ContentType.html;
      r.response.write(answer);
      await r.response.close();
    });
  }
}


void main() {
  late _Moodle external;
  late Directory folder;
  late McpDienst service;
  late McpTestClient client;
  late Freigaben approvals;
  late Profil profile;
  late MoodleZugang moodle;
  final arguments = <String, Object?>{
    'datei': 'test.mbz',
    'weg': 'aktueller_kurs_verschmelzen',
    'kurs': 12,
    'name': 'ZZ Kurs',
    'sichtbarkeit': 'wie_quelle',
  };
  Future<void> startService() async {
    final log = Protokoll();
    service = McpDienst(
      Einstellungen(schluessel: 'test', profile: [profile]),
      moodle,
      log,
      approvals,
      folder.path,
      profil: profile,
      sicherungsordner: folder.path,
      uebertragungsprotokollPfad: p.join(folder.path, 'uebertragungen.json'),
      // Lang genug, dass ein sofortiger Fehler auch unter Last noch in der
      // Antwort ankommt (Archivprüfung und Prüfsumme brauchen Zeit); Tests für
      // „läuft weiter" halten das Moodle-Doppel ohnehin an (external.hold).
      antwortfrist: const Duration(seconds: 3),
    );
    await service.starten();
    client = McpTestClient(profile.port);
    await client.initialize();
  }

  void writeArchive({bool quiz = false, bool image = false, bool lokal = false, bool geteilt = false}) {
    external.modul = quiz ? 'quiz' : 'page';
    external.title = quiz ? 'ZZ Quiz' : 'ZZ Blatt';
    final archive = Archive();
    for (final e in <String, String>{
      'moodle_backup.xml':
          '<moodle_backup><information><format>moodle2</format><type>activity</type></information><activities><activity><modulename>${external.modul}</modulename><title>${external.title}</title><directory>activities/${external.modul}_7</directory></activity></activities></moodle_backup>',
      'activities/${external.modul}_7/inforef.xml': image ? '<inforef><file><id>1</id></file></inforef>' : '<inforef/>',
      'files.xml': image
          ? '<files><file id="1"><component>mod_page</component><filename>bild.png</filename><contenthash>0000000000000000000000000000000000000000</contenthash></file></files>'
          : '<files/>',
      if (quiz) 'activities/quiz_7/quiz.xml': '<activity contextid="5"><quiz><question_instance><question_reference><questionbankentryid>1</questionbankentryid><version>1</version></question_reference></question_instance></quiz></activity>',
      if (quiz) 'questions.xml': '<questions>${lokal || geteilt ? '<question_category id="1"><contextid>${geteilt ? 6 : 5}</contextid></question_category>' : ''}<question_bank_entry id="1">${lokal || geteilt ? '<questioncategoryid>1</questioncategoryid>' : ''}<idnumber>ZZ-1</idnumber><question_version><question_versions><version>1</version><questions><question><name>ZZ Frage</name></question></questions></question_versions></question_version></question_bank_entry></questions>',
    }.entries) {
      archive.addFile(ArchiveFile.bytes(e.key, utf8.encode(e.value)));
    }
    File(p.join(folder.path, 'test.mbz'))
        .writeAsBytesSync(GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive)));
    alsEigeneSicherung(folder, 'test.mbz');
  }

  /// Ein Archiv mit zwei Quizzen, beide mit der einen Frage „ZZ Frage".
  void writeTwoQuizArchive() {
    external.modul = 'quiz';
    external.title = 'ZZ Quiz';
    String quizXml() =>
        '<activity contextid="5"><quiz><question_instance><question_reference><questionbankentryid>1</questionbankentryid><version>1</version></question_reference></question_instance></quiz></activity>';
    final archive = Archive();
    for (final e in <String, String>{
      'moodle_backup.xml':
          '<moodle_backup><information><format>moodle2</format><type>activity</type></information><activities>'
          '<activity><modulename>quiz</modulename><title>ZZ Quiz</title><directory>activities/quiz_7</directory></activity>'
          '<activity><modulename>quiz</modulename><title>ZZ Quiz B</title><directory>activities/quiz_8</directory></activity>'
          '</activities></moodle_backup>',
      'activities/quiz_7/inforef.xml': '<inforef/>',
      'activities/quiz_8/inforef.xml': '<inforef/>',
      'files.xml': '<files/>',
      'activities/quiz_7/quiz.xml': quizXml(),
      'activities/quiz_8/quiz.xml': quizXml(),
      'questions.xml':
          '<questions><question_category id="1"><contextid>5</contextid></question_category><question_bank_entry id="1"><questioncategoryid>1</questioncategoryid><idnumber>ZZ-1</idnumber><question_version><question_versions><version>1</version><questions><question><name>ZZ Frage</name></question></questions></question_versions></question_version></question_bank_entry></questions>',
    }.entries) {
      archive.addFile(ArchiveFile.bytes(e.key, utf8.encode(e.value)));
    }
    File(p.join(folder.path, 'test.mbz'))
        .writeAsBytesSync(GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive)));
    alsEigeneSicherung(folder, 'test.mbz');
  }

  setUp(() async {
    external = _Moodle();
    await external.start();
    folder = Directory.systemTemp.createTempSync('restore-mcp-');
    writeArchive();
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    profile = Profil(
      kennung: 'stable',
      name: 'Vorher',
      adresse: external.basis.toString(),
      port: port,
      mcpName: 'test',
      schluessel: 'test',
    );
    final log = Protokoll();
    approvals = Freigaben(log, stufe: Bestaetigungen.keine);
    moodle = await MoodleZugang.fuerTest(log, external.basis, benutzer: 'e.mustermann', passwort: 'test');
    await startService();
  });
  tearDown(() async {
    external.hold?.complete();
    await service.stoppen();
    client.http.close(force: true);
    await external.server.close(force: true);
    // Unter Windows kann ein Hintergrundlauf (Übertragung, Statusabfrage) eine
    // Datei im Ordner noch kurz offen halten, wenn der Test schon fertig ist;
    // dann scheitert das Löschen mit „wird von einem anderen Prozess verwendet“.
    for (var i = 0;; i++) {
      try {
        folder.deleteSync(recursive: true);
        break;
      } on FileSystemException {
        if (i >= 50) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });

  test('MCP veröffentlicht löschende Wiederherstellung als destruktiv', () async {
    final list = await client.call('tools/list');
    final tool = (list['tools'] as List).cast<Map>().singleWhere((t) => t['name'] == 'wiederherstellen_datei');
    expect(tool['annotations']['readOnlyHint'], false);
    expect(tool['annotations']['destructiveHint'], true);
  });

  test('Startfehler mit weiterer Unterseite wird unklar statt endlos gepollt; bleibt gesperrt', () async {
    external.startFehlerseite = true;
    final result = await client.tool('wiederherstellen_datei', arguments);
    expect(result, contains('Assistent'));
    expect(result, isNot(contains('Nicht protokollieren')));
    expect(external.progressReads, 0);
    final store = Vorgaenge(folder.path, profilKennung: profile.kennung);
    final v = (await store.alle()).single;
    expect(v.wiederherstellung, WiederherstellungStand.unklar);
    expect(v.text, contains('Assistent'));
    await client.tool('wiederherstellen_datei', arguments);
    expect(external.starts, 1);
  });

  for (final mitFortschritt in [true, false]) {
  test('aktive Abfrage nennt Phase und Stillstand, Fortschritt bekannt: $mitFortschritt', () async {
    external.hold = Completer<void>();
    final result = await client.tool('wiederherstellen_datei', arguments);
    final number = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(result)!.group(1)!;
    final store = Vorgaenge(folder.path, profilKennung: profile.kennung);
    final v = (await store.finde(number))!;
    if (mitFortschritt) {
      await store.aktualisieren(v, fortschritt: 0, fortschrittSeit: DateTime.now());
    }
    final spaeter = DateTime.now().add(const Duration(minutes: 16));
    jetzt = () => spaeter;
    addTearDown(() => jetzt = DateTime.now);
    final reads = external.progressReads;
    final status = await client.tool('wiederherstellung_status', {'id': number});
    expect(status, contains('Phase:'));
    expect(status, contains('Stillstand'));
    expect(status, contains(mitFortschritt ? '0 %' : 'unbekannt'));
    expect(status, contains('gespeichert'));
    expect(external.progressReads, reads);
    jetzt = DateTime.now;
    external.progress = {'unexpected': true};
    external.hold!.complete();
    external.hold = null;
    await client.waitStatus('wiederherstellung_status', number, (t) => t.contains('Unklar') || t.contains('unklar'));
    expect(external.starts, 1);
  });
  }

  test('fehlendes Upload-Formular wird vor dem Hochladen mit Feldnamen gemeldet', () async {
    external.uploadFormularFehlt = true;
    final result = await client.tool('wiederherstellen_datei', arguments);
    expect(result, contains('kein Formular mit dem Feld backupfile'));
    expect(result, contains('anderes_feld'));
    expect(result, isNot(contains('technisch')));
    expect(external.writes, 0);
    expect(external.starts, 0);
  });

  test('Wiederherstellung mit wie_quelle behält die Quelle und benennt die Prüfgrenze', () async {
    external.sichtbar = true;
    external.completeOnStart = true;
    external.progress = {'progress': 1, 'status': 1000};
    approvals.stufe = Bestaetigungen.mittel;
    String? freigabe;
    approvals.addListener(() {
      if (approvals.aktuell == null) return;
      freigabe = approvals.aktuell!.punkte.join(' ');
      scheduleMicrotask(() => approvals.entscheiden(true));
    });
    final result = await client.tool('wiederherstellen_datei', arguments);
    expect(external.sichtbar, isTrue, reason: result);
    expect(external.verbergen, 0);
    expect(freigabe, contains('Sichtbarkeit: wie Quelle'));
    expect(result, contains('verified: true'));
    expect(result, contains('Sichtbarkeit und Voraussetzungen nicht gegengeprüft'));
    expect(result, isNot(contains('verborgen: verified')));
    final duplicate = await client.tool('wiederherstellen_datei', {...arguments, 'sichtbarkeit': 'verborgen'});
    expect(duplicate, contains('schon im Vorgang'));
    expect(external.starts, 1);
  });

  test('Start, Zeitlimit, Profilumbenennung und Neustart behalten Wiederholungsschutz', () async {
    external.hold = Completer<void>();
    final result = await client.tool('wiederherstellen_datei', arguments);
    expect(external.starts, 1, reason: result);
    final number = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(result)!.group(1)!;
    expect(result, contains('wiederherstellung_status'));
    expect(result, contains('normale Antwortfrist'));
    expect(result, contains('kein Fehler'));
    expect(result, contains('30 Minuten'));
    expect(result, contains('nicht erneut senden'));
    external.progress = {'error': 'failed', 'progress': 0.2};
    external.hold!.complete();
    external.hold = null;
    await client.waitStatus('wiederherstellung_status', number, (t) => t.contains('Moodle meldet einen Fehler'));
    await service.stoppen();
    client.http.close(force: true);
    profile = profile.copyWith(name: 'Nachher');
    await startService();
    final duplicate = await client.tool('wiederherstellen_datei', arguments);
    expect(duplicate, contains(number));
    expect(external.starts, 1);
  });

  for (final wahl in ['wie_quelle', 'verborgen']) {
    test('Sichtbarkeitswahl $wahl bleibt bei späterer Statusabfrage nach Neustart erhalten', () async {
      external.progress = {'unexpected': true};
      external.sichtbar = true;
      final gestartet = await client.tool('wiederherstellen_datei', {...arguments, 'sichtbarkeit': wahl});
      final nummer = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(gestartet)!.group(1)!;
      await service.stoppen();
      client.http.close(force: true);
      await startService();
      external.completed = true;
      external.progress = {'progress': 1, 'status': 1000};
      final status = await client.tool('wiederherstellung_status', {'id': nummer});
      expect(external.sichtbar, wahl == 'wie_quelle', reason: status);
      expect(external.verbergen, wahl == 'verborgen' ? 1 : 0);
      expect(status, contains('verified: true'));
      final nochmal = await client.tool('wiederherstellung_status', {'id': nummer});
      expect(nochmal, contains(wahl == 'wie_quelle'
          ? 'Sichtbarkeit und Voraussetzungen nicht gegengeprüft' : 'Neu im Kurs'));
      expect(external.starts, 1);
      expect(external.verbergen, wahl == 'verborgen' ? 1 : 0);
    });
  }

  for (final wahl in ['wie_quelle', 'verborgen']) {
    test('Übertragung nennt Sichtbarkeitswahl $wahl in Gesamt- und Zielfreigabe und führt sie aus', () async {
      external.sichtbar = true;
      external.completeOnStart = true;
      external.progress = {'progress': 1, 'status': 1000};
      approvals.stufe = Bestaetigungen.mittel;
      final freigaben = <String>[];
      approvals.addListener(() {
        if (approvals.aktuell == null) return;
        freigaben.add(approvals.aktuell!.punkte.join(' '));
        scheduleMicrotask(() => approvals.entscheiden(true));
      });
      final result = await client.tool('uebertragen', {
        'datei': 'test.mbz',
        'sichtbarkeit': wahl,
        'ziele': [{'kurs': 12, 'name': 'ZZ Kurs', 'weg': 'aktueller_kurs_verschmelzen'}],
      });
      expect(result, contains('1 fertig'));
      expect(external.sichtbar, wahl == 'wie_quelle');
      expect(freigaben, hasLength(2));
      expect(freigaben.every((f) => f.contains('Sichtbarkeit: ${wahl == 'wie_quelle' ? 'wie Quelle' : wahl}')), isTrue);
    });
  }

  test('Altvorgang ohne gespeicherte Sichtbarkeitswahl bleibt beim bisherigen Verbergen', () async {
    external.progress = {'unexpected': true};
    external.sichtbar = true;
    final gestartet = await client.tool('wiederherstellen_datei', arguments);
    final nummer = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(gestartet)!.group(1)!;
    await service.stoppen();
    client.http.close(force: true);
    final datei = File(p.join(folder.path, 'vorgaenge.json'));
    final alt = (jsonDecode(await datei.readAsString()) as List).cast<Map>();
    for (final v in alt) { v.remove('sichtbarkeit'); }
    await datei.writeAsString(jsonEncode(alt));
    await startService();
    external.completed = true;
    external.progress = {'progress': 1, 'status': 1000};
    final status = await client.tool('wiederherstellung_status', {'id': nummer});
    expect(status, contains('verborgen: verified'));
    expect(external.sichtbar, isFalse);
    expect(external.verbergen, 1);
  });

  test('ungültige Sichtbarkeitswahl startet weder Wiederherstellung noch Übertragung', () async {
    final vorher = external.requests;
    for (final werkzeug in ['wiederherstellen_datei', 'uebertragen']) {
      final request = await client.http.postUrl(Uri.parse('http://127.0.0.1:${profile.port}/mcp'));
      request.headers
        ..set('Authorization', 'Bearer test')
        ..set('Accept', 'application/json, text/event-stream')
        ..set('Mcp-Session-Id', client.session!)
        ..contentType = ContentType.json;
      request.write(jsonEncode({
        'jsonrpc': '2.0', 'id': ++client.id, 'method': 'tools/call',
        'params': {'name': werkzeug, 'arguments': {
          ...arguments,
          'sichtbarkeit': 'sichtbar',
          'ziele': [{'kurs': 12, 'name': 'ZZ Kurs', 'weg': 'aktueller_kurs_verschmelzen'}],
        }},
      }));
      final result = jsonDecode(await utf8.decoder.bind(await request.close()).join()) as Map;
      expect(result['error']['code'], -32602);
      expect(result['error']['message'], contains('sichtbarkeit'));
    }
    expect(external.requests, vorher);
    expect(external.writes, 0);
  });
  String nummerAus(String text) => RegExp(r'Nummer ([a-z0-9]+)').firstMatch(text)!.group(1)!;

  group('Moodle meldet einen Fehler: der Zielkurs entscheidet, nicht das Fehlerfeld', () {
    /// Startet (Moodle antwortet zunächst nicht), lässt dann die Kursinhalte erscheinen und den
    /// Fehler melden und liefert die Nummer und den Text der abschließenden Statusabfrage.
    Future<(String, String)> fehlerLauf(Map<String, Object?> fortschritt,
        {bool imKurs = false, List<String> weitere = const []}) async {
      external.hold = Completer<void>();
      final nummer = nummerAus(await client.tool('wiederherstellen_datei', arguments));
      external.progress = fortschritt;
      external.completed = imKurs;
      external.weitereQuizze = weitere;
      external.hold!.complete();
      external.hold = null;
      final text = await client.waitStatus('wiederherstellung_status', nummer,
          (t) => !t.contains('läuft weiter') && !t.contains('läuft noch'));
      return (nummer, text);
    }

    test('a) Inhalt vollständig und gleich: verified, Vorgang abgeschlossen, Grenzen bleiben genannt', () async {
      final (number, result) = await fehlerLauf({'error': 'failed', 'progress': 0.2}, imKurs: true);
      expect(result,
          contains('Moodle meldete einen Fehler, der Inhalt ist aber vollständig und stimmt mit der Quelle überein (soweit geprüft)'));
      final store = Vorgaenge(folder.path, profilKennung: profile.kennung);
      final vg = (await store.finde(number))!;
      expect(vg.wiederherstellung, WiederherstellungStand.fertig);
      expect(vg.verified, isTrue);
      expect(external.starts, 1, reason: 'die App startet nichts neu');
    });

    test('a) mit offener Prüflücke: nicht verified, der Text nennt das Ungeprüfte', () async {
      writeArchive(quiz: true);
      final (number, result) = await fehlerLauf({'error': 'failed', 'progress': 0.2}, imKurs: true);
      expect(result, contains('Moodle meldete einen Fehler'));
      expect(result, contains('Fragenherkunft nicht bestätigt'));
      expect(result, isNot(contains('siehe Freigabe')));
      final store = Vorgaenge(folder.path, profilKennung: profile.kennung);
      final vg = (await store.finde(number))!;
      expect(vg.wiederherstellung, WiederherstellungStand.fertig);
      expect(vg.verified, isFalse);
    });

    test('b) beendet, aber unvollständig: nennt das Fehlende, Optionen, nichts wiederholt, Sperre bleibt', () async {
      final (number, result) = await fehlerLauf({'error': 'failed', 'progress': 0.2, 'status': 900},
          imKurs: true, weitere: ['ZZ Fremdes Quiz']);
      expect(result, contains('weicht ab'));
      expect(result, contains('ZZ Fremdes Quiz'));
      expect(result, contains('wiederholung_von=$number'));
      expect(result, contains('einzeln anlegen'));
      expect(result, contains('Bildern'));
      final store = Vorgaenge(folder.path, profilKennung: profile.kennung);
      expect((await store.finde(number))!.wiederherstellung, WiederherstellungStand.unklar);
      final duplicate = await client.tool('wiederherstellen_datei', arguments);
      expect(duplicate, contains(number));
      expect(external.starts, 1);
    });

    test('c) Prozess nicht als beendet belegt, nichts im Kurs: Nachfragetext, Sperre bleibt', () async {
      final (number, result) = await fehlerLauf({'error': 'backup_exception', 'progress': 0.2});
      expect(result, contains('Moodle meldet einen Fehler'));
      expect(result, contains('Hintergrundauftrag'));
      expect(result, contains('Vorgang $number'));
      expect(result, contains('backup_exception'));
      expect(result, contains('Kurs 12'));
      expect(result, contains('nicht wiederholt'));
      expect(result, isNot(contains('fehlgeschlagen')));
      expect(result, isNot(contains('ZZ Blatt')), reason: 'keine Inhalte in der Nachfrage');
      final store = Vorgaenge(folder.path, profilKennung: profile.kennung);
      expect((await store.finde(number))!.wiederherstellung, WiederherstellungStand.unklar);
      final duplicate = await client.tool('wiederherstellen_datei', arguments);
      expect(duplicate, contains(number));
      expect(external.starts, 1);
    });

    test('c) nur Teile im Kurs und Prozess nicht beendet: ebenfalls Nachfragetext statt Urteil', () async {
      final (number, result) = await fehlerLauf({'error': 'failed', 'progress': 0.5},
          imKurs: true, weitere: ['ZZ Fremdes Quiz']);
      expect(result, contains('Hintergrundauftrag'));
      expect(result, contains('weicht ab'));
      final store = Vorgaenge(folder.path, profilKennung: profile.kennung);
      expect((await store.finde(number))!.wiederherstellung, WiederherstellungStand.unklar);
    });

    test('fehlgeschlagen nur mit Beleg: Prozess beendet und nichts Neues im Kurs; Wiederholung frei', () async {
      final (number, result) = await fehlerLauf({'error': 'failed', 'progress': 0.2, 'status': 900});
      expect(result, contains('fehlgeschlagen'));
      expect(result, contains('nichts Neues'));
      final store = Vorgaenge(folder.path, profilKennung: profile.kennung);
      expect((await store.finde(number))!.wiederherstellung, WiederherstellungStand.fehlgeschlagen);
      external.hold = null;
      await client.tool('wiederherstellen_datei', arguments);
      expect(external.starts, 2, reason: 'ohne Sperre darf neu gestartet werden');
    });
  });
  test('Status-Zeitlimit nennt Werkzeug und Nummer; erneute Abfrage startet nichts', () async {
    external.progress = {'unexpected': true};
    final started = await client.tool('wiederherstellen_datei', arguments);
    final number = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(started)!.group(1)!;
    final writes = external.writes;
    external.progress = {'progress': 1, 'status': 1000};
    external.completed = true;
    external.hold = Completer<void>();
    final pending = await client.tool('wiederherstellung_status', {'id': number});
    expect(pending, contains(number));
    expect(pending, contains('wiederherstellung_status'));
    external.hold!.complete();
    external.hold = null;
    final finished = await client.waitStatus('wiederherstellung_status', number, (t) => t.contains('fertig'));
    expect(finished, contains('fertig'));
    expect(finished, contains('übereinstimmend'));
    expect(external.writes, writes);
    expect(external.starts, 1);
  });

  test('bewusste Wiederholung liest den aktuellen Altvorgang vor der Freigabe ohne zu schreiben', () async {
    external.progress = {'unexpected': true};
    final started = await client.tool('wiederherstellen_datei', arguments);
    final number = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(started)!.group(1)!;
    final writes = external.writes;
    final reads = external.progressReads;
    external.progress = {'progress': 1, 'status': 1000};
    external.completed = true;
    // Stufe bleibt „keine": Die Rückfrage vor einer Wiederholung gilt trotzdem (E29).
    String? approval;
    approvals.addListener(() {
      final current = approvals.aktuell;
      if (current == null) return;
      approval = current.punkte.join(' ');
      scheduleMicrotask(() => approvals.entscheiden(false));
    });
    await client.tool('wiederherstellen_datei', {...arguments, 'wiederholung_von': number});
    expect(external.progressReads, reads + 1);
    expect(approval, contains('beendet'));
    expect(approval, contains('Dubletten'));
    expect(external.writes, writes);
    expect(external.starts, 1);
  });

  test('zwei MCP-Sitzungen sehen dieselben Vorgänge', () async {
    final other = McpTestClient(profile.port);
    addTearDown(() => other.http.close(force: true));
    await other.initialize();
    await other.tool('sicherung_status', {});
    external.progress = {'unexpected': true};
    final started = await client.tool('wiederherstellen_datei', arguments);
    final number = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(started)!.group(1)!;
    final status = await other.tool('wiederherstellung_status', {'id': number});
    expect(status, contains(number));
    expect(status, isNot(contains('Keine Wiederherstellung')));
  });

  test('ein anderes Zielprofil darf einen fremden Vorgang weder abfragen noch gegenlesen', () async {
    external.progress = {'unexpected': true};
    final started = await client.tool('wiederherstellen_datei', arguments);
    final number = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(started)!.group(1)!;
    await service.stoppen();
    client.http.close(force: true);
    profile = Profil(
      kennung: 'anderes',
      name: 'Anderes Profil',
      adresse: external.basis.toString(),
      port: profile.port,
      mcpName: 'anderes',
      schluessel: 'test',
    );
    await startService();
    external.progress = {'progress': 1, 'status': 1000};
    external.completed = true;
    final reads = external.progressReads;
    final writes = external.writes;
    final status = await client.tool('wiederherstellung_status', {'id': number});
    expect(status, contains('Keine Wiederherstellung'));
    expect(external.progressReads, reads);
    expect(external.writes, writes);
  });

  test('Quellfragen bleiben für den Vergleich nach Neustart und erneutem Status erhalten', () async {
    writeArchive(quiz: true);
    external.progress = {'unexpected': true};
    final started = await client.tool('wiederherstellen_datei', arguments);
    final number = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(started)!.group(1)!;
    await service.stoppen();
    client.http.close(force: true);
    await startService();
    external.progress = {'progress': 1, 'status': 1000};
    external.completed = true;
    final status = await client.tool('wiederherstellung_status', {'id': number});
    expect(status, contains('Fragenzahl und Fragennamen stimmen mit der Quelle überein (1)'));
    expect(status, contains('Fragenherkunft nicht bestätigt'));
    final again = await client.tool('wiederherstellung_status', {'id': number});
    expect(again, contains('Fragenzahl und Fragennamen stimmen mit der Quelle überein (1)'));
    expect(external.starts, 1);
  });

  test('Fragen im Kontext des Quiz belegen die eigene Herkunft auch ohne angegebene Sammlung', () async {
    writeArchive(quiz: true, lokal: true);
    external.progress = {'unexpected': true};
    final started = await client.tool('wiederherstellen_datei', arguments);
    final number = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(started)!.group(1)!;
    external.progress = {'progress': 1, 'status': 1000};
    external.completed = true;
    final status = await client.tool('wiederherstellung_status', {'id': number});
    expect(status, contains('Fragenzahl und Fragennamen stimmen mit der Quelle überein (1)'));
    expect(status, isNot(contains('Fragenherkunft nicht bestätigt')));
  });

  test('mehrere Quizze im Archiv werden je zugeordnet verglichen', () async {
    writeTwoQuizArchive();
    external.progress = {'unexpected': true};
    final started = await client.tool('wiederherstellen_datei', arguments);
    final number = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(started)!.group(1)!;
    external.weitereQuizze = ['ZZ Quiz B'];
    external.progress = {'progress': 1, 'status': 1000};
    external.completed = true;
    final status = await client.tool('wiederherstellung_status', {'id': number});
    expect('stimmen mit der Quelle überein'.allMatches(status).length, 2, reason: status);
    expect(status, contains('„ZZ Quiz B"'));
    expect(status, isNot(contains('nicht eindeutig')));
    expect(status, isNot(contains('Fragenherkunft nicht bestätigt')));
  });

  test('ein Quiz ohne Gegenstück im Kurs ist eine Prüflücke, die anderen werden verglichen', () async {
    writeTwoQuizArchive();
    external.progress = {'unexpected': true};
    final started = await client.tool('wiederherstellen_datei', arguments);
    final number = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(started)!.group(1)!;
    external.progress = {'progress': 1, 'status': 1000};
    external.completed = true;
    final status = await client.tool('wiederherstellung_status', {'id': number});
    expect('stimmen mit der Quelle überein'.allMatches(status).length, 1, reason: status);
    expect(status, contains('„ZZ Quiz B"'));
    expect(status, contains('Prüflücke'));
  });

  test('geteilte Herkunft wird ohne sammlung vor dem Start gewarnt und bleibt unverifiziert', () async {
    writeArchive(quiz: true, geteilt: true);
    external.progress = {'progress': 1, 'status': 1000};
    approvals.stufe = Bestaetigungen.mittel;
    String? approval;
    approvals.addListener(() {
      final current = approvals.aktuell;
      if (current == null) return;
      expect(external.starts, 0);
      approval = current.punkte.join(' ');
      scheduleMicrotask(() {
        external.completed = true;
        approvals.entscheiden(true);
      });
    });
    final result = await client.tool('wiederherstellen_datei', arguments);
    expect(approval, contains('auf die Quellsammlung verweisen'));
    expect(approval, contains('eine neue geteilte Sammlung'));
    expect(result, contains('Fragenherkunft nicht bestätigt'));
    expect(result, isNot(contains('verborgen: verified')));
  });

  test('kollidierende Sachnummern in einer Zielsammlung bestätigen keine Quellherkunft', () async {
    writeArchive(quiz: true);
    external.progress = {'progress': 1, 'status': 1000};
    approvals.stufe = Bestaetigungen.mittel;
    String? approval;
    approvals.addListener(() {
      final current = approvals.aktuell;
      if (current == null) return;
      approval = current.punkte.join(' ');
      scheduleMicrotask(() {
        external.completed = true;
        approvals.entscheiden(true);
      });
    });
    final result = await client.tool('wiederherstellen_datei', {...arguments, 'sammlung': 90});
    expect(approval, contains('keine eigene Quellherkunft'));
    expect(result, contains('Fragenherkunft nicht bestätigt'));
    expect(result, isNot(contains('siehe Freigabe')));
    expect(result, isNot(contains('verborgen: verified')));
  });

  test('Sammelübertragung erhält Prüfprobleme eines abgeschlossenen Quiz', () async {
    writeArchive(quiz: true, geteilt: true);
    external.progress = {'progress': 1, 'status': 1000};
    external.completeOnStart = true;
    final result = await client.tool('uebertragen', {
      'sichtbarkeit': 'wie_quelle',
      'datei': 'test.mbz',
      'ziele': [{'kurs': 12, 'name': 'ZZ Kurs', 'weg': 'aktueller_kurs_verschmelzen'}],
    });
    expect(result, contains('1 fertig'));
    expect(result, contains('Fragenherkunft nicht bestätigt'));
    expect(result, isNot(contains('verborgen: verified')));
  });

  test('Moodle hält mit der Rollenzuordnung an: die Vorgabe wird einmal bestätigt, dann läuft die Wiederherstellung', () async {
    writeArchive(quiz: true, geteilt: true);
    external.progress = {'progress': 1, 'status': 1000};
    external.completeOnStart = true;
    external.rollenSeite = true;
    final result = await client.tool('uebertragen', {
      'sichtbarkeit': 'wie_quelle',
      'datei': 'test.mbz',
      'ziele': [{'kurs': 12, 'name': 'ZZ Kurs', 'weg': 'aktueller_kurs_verschmelzen'}],
    });
    expect(external.rollenBestaetigt, 1);
    expect(external.starts, 1);
    expect(result, contains('1 fertig'));
  });

  for (final fall in ['leer', 'zusatzfeld', 'erneut']) {
    test('Rollenzuordnung $fall wird nicht blind bestätigt oder wiederholt', () async {
      external.rollenSeite = true;
      external.rollenSonderfall = fall;
      external.progress = {'unexpected': true};
      final result = await client.tool('wiederherstellen_datei', arguments);
      expect(external.rollenBestaetigt, fall == 'erneut' ? 1 : 0);
      expect(result, contains(switch (fall) {
        'leer' => 'Unklar',
        'zusatzfeld' => 'Gesperrt',
        _ => 'Rollenzuordnung erneut',
      }));
      final v = (await Vorgaenge(folder.path, profilKennung: profile.kennung).alle()).single;
      expect(v.wiederherstellung, WiederherstellungStand.unklar);
      expect(v.verified, isFalse);
    });
  }

  test('Übertragungszeitlimit beim Sichern nennt Sicherungsnummer und Statuswerkzeug', () async {
    external.hold = Completer<void>();
    final result = await client.tool('uebertragen', {
      'sichtbarkeit': 'wie_quelle',
      'kurs': 12, 'name_des_kurses': 'ZZ Kurs', 'ganzer_kurs': true,
      'ziele': [{'kurs': 34, 'name': 'ZZ Ziel', 'weg': 'anderer_kurs_verschmelzen'}],
    });
    expect(external.backupStarts, 1);
    expect(external.starts, 0);
    final nummer = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(result)!.group(1)!;
    expect(result, contains('sicherung_status'));
    expect(result, isNot(contains('wiederherstellung_status')));
    final v = await Vorgaenge(folder.path, profilKennung: profile.kennung).finde(nummer);
    expect(v, isNotNull);
    expect(v!.wiederherstellung, isNull);
    external.progress = {'unexpected': true};
    external.hold!.complete();
    external.hold = null;
    await client.waitStatus('sicherung_status', nummer, (t) => t.contains('Unklar'));
  });

  test('Übertragungszeitlimit beim Wiederherstellen nennt Zielnummer und Statuswerkzeug', () async {
    external.hold = Completer<void>();
    final result = await client.tool('uebertragen', {
      'sichtbarkeit': 'wie_quelle',
      'datei': 'test.mbz',
      'ziele': [{'kurs': 12, 'name': 'ZZ Kurs', 'weg': 'aktueller_kurs_verschmelzen'}],
    });
    expect(external.starts, 1);
    final nummer = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(result)!.group(1)!;
    expect(result, contains('wiederherstellung_status'));
    final v = await Vorgaenge(folder.path, profilKennung: profile.kennung).finde(nummer);
    expect(v!.wiederherstellung, WiederherstellungStand.laufend);
    external.progress = {'progress': 1, 'status': 1000};
    external.completed = true;
    external.hold!.complete();
    external.hold = null;
    await client.waitStatus('wiederherstellung_status', nummer, (t) => t.contains('fertig'));
    // Der Sammellauf muss auch seinen abschließenden Protokolleintrag gespeichert haben.
    final log = File(p.join(folder.path, 'uebertragungen.json'));
    for (var i = 0; i < 100 && !await log.exists(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await log.exists(), isTrue);
    expect(external.starts, 1);
  });

  test('Sicherung: Zeitlimit und Neustart erlauben spätere Dateiabholung ohne neuen Start', () async {
    external.hold = Completer<void>();
    final started = await client.tool('sichern_auswahl', {
      'kurs': 12,
      'name_des_kurses': 'ZZ Kurs',
      'ganzer_kurs': true,
    });
    expect(external.backupStarts, 1, reason: started);
    final number = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(started)!.group(1)!;
    expect(started, contains('sicherung_status'));
    external.progress = {'unexpected': true};
    external.hold!.complete();
    external.hold = null;
    await client.waitStatus('sicherung_status', number, (t) => t.contains('Unklar'));
    await service.stoppen();
    client.http.close(force: true);
    await startService();
    external.progress = {'progress': 1, 'status': 1000};
    external.hold = Completer<void>();
    final waiting = await client.tool('sicherung_status', {'id': number});
    expect(waiting, contains(number));
    expect(waiting, contains('sicherung_status'));
    external.hold!.complete();
    external.hold = null;
    final result = await client.waitStatus('sicherung_status', number, (t) => t.contains('fertig'));
    expect(result, contains('fertig'));
    expect(result, contains('verified'));
    expect(external.backupStarts, 1);
    expect(external.downloads, 1);
    final downloaded = folder.listSync().whereType<File>().singleWhere((f) => p.basename(f.path).startsWith('kurs-'));
    expect(await downloaded.readAsBytes(), _Moodle.backupBytes);
    await client.tool('sicherung_status', {'id': number});
    expect(external.downloads, 1);
  });

  group('Sicherung: die heruntergeladene Datei wird geprüft, bevor verified gemeldet wird', () {
    final sichern = {'kurs': 12, 'name_des_kurses': 'ZZ Kurs', 'ganzer_kurs': true};
    List<File> sicherungen() =>
        folder.listSync().whereType<File>().where((f) => p.basename(f.path).startsWith('kurs-')).toList();

    test('eine Datei ohne Nutzerdaten: verified, Prüfsumme gemerkt, Bericht nennt Geprüftes und Ungeprüftes', () async {
      external.progress = {'progress': 1, 'status': 1000};
      final result = await client.tool('sichern_auswahl', sichern);
      expect(result, contains('verified: true'), reason: result);
      expect(result, contains('Auf Nutzerdaten geprüft:'));
      expect(result, contains('Nicht geprüft:'));
      expect(result, contains(archivAutorenHinweis));
      final v = (await Vorgaenge(folder.path, profilKennung: profile.kennung).alle()).single;
      expect(v.stand, SicherungStand.fertig);
      expect(v.verified, isTrue);
      expect(v.pruefsumme, sha256.convert(_Moodle.backupBytes).toString());
    });

    test('Nutzerdaten in der Datei: gelöscht, als Fehler gemeldet, nichts bleibt im Sicherungsordner', () async {
      external.downloadBytes = _mbzBytes({
        ..._kursArchiv,
        'comments.xml': '<comments><comment id="1"><userid>5</userid></comment></comments>',
      });
      external.progress = {'progress': 1, 'status': 1000};
      final result = await client.tool('sichern_auswahl', sichern);
      expect(result, contains('Nutzerdaten'), reason: result);
      expect(result, contains('gelöscht'));
      expect(result, isNot(contains('verified: true')));
      expect(sicherungen(), isEmpty);
      expect(folder.listSync().whereType<File>().where((f) => f.path.endsWith('.teil')), isEmpty);
      final v = (await Vorgaenge(folder.path, profilKennung: profile.kennung).alle()).single;
      expect(v.stand, SicherungStand.fehlgeschlagen);
      expect(v.verified, isFalse);
      expect(v.pruefsumme, isNull);
    });

    test('ein beschädigtes Archiv: nicht geprüft, verified false, nicht als eigene Sicherung geführt', () async {
      external.downloadBytes = List<int>.generate(1024, (i) => i % 256);
      external.progress = {'progress': 1, 'status': 1000};
      final result = await client.tool('sichern_auswahl', sichern);
      expect(result, contains('verified: false'), reason: result);
      expect(result, isNot(contains('verified: true')));
      final v = (await Vorgaenge(folder.path, profilKennung: profile.kennung).alle()).single;
      expect(v.stand, SicherungStand.fehlgeschlagen);
      expect(v.pruefsumme, isNull);
      expect(sicherungen(), hasLength(1), reason: 'sie bleibt liegen, gilt aber nicht als geprüft');
      expect(await Vorgaenge(folder.path).herkunft(v.datei, 'x'), SicherungsHerkunft.geaendert);
    });

    test('Code in der Datei: Hinweis, dass das Wiederherstellen sie abweist; verified bleibt', () async {
      external.downloadBytes = _mbzBytes({
        ..._kursArchiv,
        'activities/page_3/page.xml':
            '<activity><page><content>&lt;script&gt;alert(1)&lt;/script&gt;</content></page></activity>',
      });
      external.progress = {'progress': 1, 'status': 1000};
      final result = await client.tool('sichern_auswahl', sichern);
      expect(result, contains('verified: true'), reason: result);
      expect(result, contains('enthält Code'));
      expect(result, contains('weist'));
    });

    test('zu große Sicherung: der Download bricht ab, nichts bleibt liegen', () async {
      final ziel = File(p.join(folder.path, 'gross.mbz'));
      await expectLater(
        moodle.herunterladen('/pluginfile.php/55/user/backup/1/download.mbz?forcedownload=1', ziel, maxBytes: 50),
        throwsA(isA<DownloadZuGross>()),
      );
      expect(ziel.existsSync(), isFalse);
      expect(File('${ziel.path}.teil').existsSync(), isFalse);
    });
  });

  group('Wiederherstellung: Herkunft der Datei', () {
    final gesehen = <FreigabeAnfrage>[];
    void antworten({required bool ja}) {
      gesehen.clear();
      approvals.addListener(() {
        final a = approvals.aktuell;
        if (a == null) return;
        gesehen.add(a);
        scheduleMicrotask(() => approvals.entscheiden(ja));
      });
    }

    test('eine eigene, unveränderte Sicherung fragt auf Stufe keine nicht', () async {
      external.completeOnStart = true;
      external.progress = {'progress': 1, 'status': 1000};
      antworten(ja: true);
      final result = await client.tool('wiederherstellen_datei', arguments);
      expect(result, contains('Wiederhergestellt'), reason: result);
      expect(gesehen, isEmpty);
    });

    test('eine fremde Datei fragt auf jeder Stufe, mit Hinweis oben und Pflicht-Haken', () async {
      File(p.join(folder.path, 'vorgaenge.json')).deleteSync();
      antworten(ja: false);
      for (final stufe in Bestaetigungen.values) {
        approvals.stufe = stufe;
        gesehen.clear();
        final result = await client.tool('wiederherstellen_datei', arguments);
        expect(result, contains('Nicht wiederhergestellt'), reason: '${stufe.text}: $result');
        final a = gesehen.single;
        expect(a.ab, Bestaetigungen.keine, reason: stufe.text);
        expect(a.punkte.first, startsWith('ACHTUNG: Diese Datei hat moocp nicht selbst erzeugt.'));
        expect(a.punkte.first, contains('Nutzerdaten und Inhalte enthalten, die moocp beim Schreiben sonst abweist'));
        expect(a.abhaken.single, contains('nicht erzeugt'));
        expect(external.writes, 0, reason: 'nichts hochgeladen');
      }
    });

    test('eine Datei mit demselben Namen, aber anderem Inhalt gilt als geändert', () async {
      File(p.join(folder.path, 'test.mbz')).writeAsBytesSync(_mbzBytes({
        'moodle_backup.xml':
            '<moodle_backup><information><format>moodle2</format><type>activity</type></information><activities><activity><modulename>page</modulename><title>ZZ Anders</title></activity></activities></moodle_backup>',
      }));
      antworten(ja: false);
      await client.tool('wiederherstellen_datei', arguments);
      final a = gesehen.single;
      expect(a.ab, Bestaetigungen.keine);
      expect(a.punkte.first, contains('seit dem Sichern durch moocp geändert'));
      expect(a.abhaken.single, contains('geändert hat'));
    });

    test('Code im Archiv: abgelehnt, bevor etwas hochgeladen wird', () async {
      File(p.join(folder.path, 'test.mbz')).writeAsBytesSync(_mbzBytes({
        'moodle_backup.xml':
            '<moodle_backup><information><format>moodle2</format><type>activity</type></information><activities><activity><modulename>page</modulename><title>ZZ Blatt</title></activity></activities></moodle_backup>',
        'activities/page_7/page.xml':
            '<activity><page><content>&lt;p onclick=&quot;x()&quot;&gt;Hallo&lt;/p&gt;</content></page></activity>',
      }));
      alsEigeneSicherung(folder, 'test.mbz');
      antworten(ja: true);
      final result = await client.tool('wiederherstellen_datei', arguments);
      expect(result, contains('Archiv abgelehnt'), reason: result);
      expect(result, contains('Code'));
      expect(gesehen, isEmpty);
      expect(external.writes, 0);
    });

    test('eine .mbz geht nicht über den allgemeinen Upload an eine Aktivität', () async {
      final vorher = external.requests;
      await expectLater(
        moodle.hochladen('/repository/repository_ajax.php?action=upload', [const MapEntry('itemid', '1')],
            Anhang('repo_upload_file', 'x.mbz', [1, 2, 3], 'application/octet-stream')),
        throwsA(isA<MoodleFehler>()),
      );
      await expectLater(
        moodle.hochladen('/repository/repository_ajax.php?action=upload', [const MapEntry('itemid', '1')],
            Anhang('repo_upload_file', 'bild.png', [1, 2, 3], 'image/png'), sicherung: true),
        throwsA(isA<MoodleFehler>()),
      );
      expect(external.requests, vorher, reason: 'es wurde nichts gesendet');
    });
  });

  test('Altvorgänge sperren nach Umbenennung und dürfen ohne Profilbindung kein Moodle abfragen', () async {
    final legacy = Vorgaenge(folder.path);
    final bytes = await File(p.join(folder.path, 'test.mbz')).readAsBytes();
    final old = await legacy.neuWiederherstellung(
      kurs: 12,
      datei: 'test.mbz',
      fingerabdruck: fingerabdruck(
        bytes,
        instanz: 'Alter Anzeigename',
        kurs: 12,
        weg: Zielweg.aktuellerKursVerschmelzen,
      ),
    );
    await legacy.aktualisieren(
      old,
      wiederherstellung: WiederherstellungStand.laufend,
      backupid: _Moodle.restore,
      kontext: 55,
    );
    final reads = external.progressReads;
    final status = await client.tool('wiederherstellung_status', {'id': old.id});
    expect(status, contains('Keine Wiederherstellung'));
    final duplicate = await client.tool('wiederherstellen_datei', arguments);
    expect(duplicate, contains(old.id));
    final repeat = await client.tool('wiederherstellen_datei', {...arguments, 'wiederholung_von': old.id});
    expect(repeat, contains('keine sichere Profilbindung'));
    expect(external.progressReads, reads);
    expect(external.starts, 0);
    expect(external.writes, 0);
  });

  test('Sicherung: Fehler vor 100 Prozent und unbekannter Status werden über MCP gemeldet', () async {
    for (final progress in [
      {'progress': 0.2, 'error': 'failed'},
      {'unexpected': true},
    ]) {
      external.progress = progress;
      final started = await client.tool('sichern_auswahl', {
        'kurs': 12,
        'name_des_kurses': 'ZZ Kurs',
        'ganzer_kurs': true,
      });
      final number = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(started)!.group(1)!;
      expect(started, contains(progress.containsKey('error') ? 'fehlgeschlagen' : 'Unklar'));
      expect(started, isNot(contains('verified: true')));
      expect(external.downloads, 0);
      final result = await client.tool('sicherung_status', {'id': number});
      expect(result, contains(progress.containsKey('error') ? 'fehlgeschlagen' : 'Unklar'));
    }
  });

  test('Sicherung: fremde und ungebundene Altvorgänge bleiben ohne Moodle-Zugriff', () async {
    for (final owner in ['fremd', null, profile.kennung]) {
      final store = Vorgaenge(folder.path, profilKennung: owner);
      final old = await store.neu(kurs: 12, cmid: 1, datei: 'old.mbz');
      await store.aktualisieren(old, stand: SicherungStand.laufend, backupid: _Moodle.restore, kontext: 55);
      final result = await client.tool('sicherung_status', {'id': old.id});
      expect(result, contains('Keine Sicherung'));
    }
    final overview = await client.tool('sicherung_status', {});
    expect(overview, 'Noch keine Sicherung.');
    expect(external.progressReads, 0);
    expect(external.downloads, 0);
  });

  test('Sicherung und Wiederherstellung melden Stillstand mit Nummer statt Fehler oder Erfolg', () async {
    final now = DateTime(2026, 10, 19, 10);
    jetzt = () => now;
    addTearDown(() => jetzt = DateTime.now);
    final store = Vorgaenge(folder.path, profilKennung: profile.kennung, instanzBasis: () => external.basis);
    final backup = await store.neu(kurs: 12, cmid: 1, datei: 'old.mbz');
    final restore = await store.neuWiederherstellung(kurs: 12, datei: 'test.mbz');
    await store.aktualisieren(
      backup,
      stand: SicherungStand.laufend,
      backupid: _Moodle.restore,
      kontext: 55,
      fortschritt: 0.2,
      fortschrittSeit: now.subtract(const Duration(minutes: 16)),
    );
    await store.aktualisieren(
      restore,
      wiederherstellung: WiederherstellungStand.laufend,
      backupid: _Moodle.restore,
      kontext: 55,
      fortschritt: 0.2,
      fortschrittSeit: now.subtract(const Duration(minutes: 16)),
    );
    for (final pair in [('sicherung_status', backup.id), ('wiederherstellung_status', restore.id)]) {
      final result = await client.tool(pair.$1, {'id': pair.$2});
      expect(result, contains('Stillstand'));
      expect(result, contains(pair.$1));
      expect(result, contains(pair.$2));
      expect(result, isNot(contains('fehlgeschlagen')));
      expect(result, isNot(contains('verified')));
    }
    expect(external.starts, 0);
    expect(external.backupStarts, 0);
    expect(external.writes, 0);
  });
  test('später Abfragefehler nach MCP-Zeitlimit bleibt als unklarer Vorgang gesperrt', () async {
    external.hold = Completer<void>();
    final started = await client.tool('wiederherstellen_datei', arguments);
    final number = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(started)!.group(1)!;
    external.failProgress = true;
    external.hold!.complete();
    external.hold = null;
    var overview = '';
    for (var i = 0; i < 100; i++) {
      overview = await client.tool('sicherung_status', {});
      if (overview.contains('unklar')) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(overview, contains('unklar'));
    expect(overview, contains('wiederherstellung_status $number'));
    await service.stoppen();
    client.http.close(force: true);
    await startService();
    final duplicate = await client.tool('wiederherstellen_datei', arguments);
    expect(duplicate, contains(number));
    expect(external.starts, 1);
  });
  for (final otherInstallationPath in [false, true]) {
    test(
      'gleiche Profilkennung schützt alte Vorgänge nach Wechsel ${otherInstallationPath ? 'des Installationspfads' : 'der Moodle-Instanz'}',
      () async {
        external.progress = {'unexpected': true};
        final restored = await client.tool('wiederherstellen_datei', arguments);
        final restoreId = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(restored)!.group(1)!;
        final backed = await client.tool('sichern_auswahl', {
          'kurs': 12,
          'name_des_kurses': 'ZZ Kurs',
          'ganzer_kurs': true,
        });
        final backupId = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(backed)!.group(1)!;
        await service.stoppen();
        client.http.close(force: true);
        final target = otherInstallationPath ? external : _Moodle();
        if (!otherInstallationPath) {
          await target.start();
          addTearDown(() => target.server.close(force: true));
        }
        final newAddress = target.basis.replace(path: otherInstallationPath ? '/anderes-moodle' : '');
        profile = profile.copyWith(adresse: newAddress.toString());
        moodle = await MoodleZugang.fuerTest(Protokoll(), newAddress, benutzer: 'e.mustermann', passwort: 'test');
        await startService();
        target.progress = {'progress': 1, 'status': 1000};
        target.completed = true;
        final requests = target.requests;
        expect(await client.tool('wiederherstellung_status', {'id': restoreId}), contains('Keine Wiederherstellung'));
        expect(await client.tool('sicherung_status', {'id': backupId}), contains('Keine Sicherung'));
        expect(await client.tool('sicherung_status', {}), 'Noch keine Sicherung.');
        expect(target.requests, requests, reason: 'Die lokale Instanzbindung muss vor jeder Moodle-Anfrage greifen.');
      },
    );
  }
  for (final restart in [false, true]) {
    test(
      'ausgetauschtes Quellarchiv wird ${restart ? 'nach Neustart' : 'während des Hintergrundlaufs'} nie verifiziert',
      () async {
        writeArchive(image: true);
        external.progress = {'unexpected': true};
        if (!restart) external.hold = Completer<void>();
        final started = await client.tool('wiederherstellen_datei', arguments);
        final number = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(started)!.group(1)!;
        writeArchive();
        external.completed = true;
        external.progress = {'progress': 1, 'status': 1000};
        if (restart) {
          await service.stoppen();
          client.http.close(force: true);
          await startService();
        } else {
          external.hold!.complete();
          external.hold = null;
        }
        final status = await client.waitStatus('wiederherstellung_status', number, (text) => text.contains('fertig'));
        expect(status, contains('Prüflücke'));
        expect(status, contains('Quellaufnahme'));
        final overview = await client.tool('sicherung_status', {});
        expect(overview, contains('verified: false'));
        expect(external.starts, 1);
      },
    );
  }
  test('fehlender Start-Inhalts-Hash bleibt bei Anhangprüfung eine ausdrückliche Prüflücke', () async {
    final store = Vorgaenge(folder.path, profilKennung: profile.kennung, instanzBasis: () => external.basis);
    final old = await store.neuWiederherstellung(kurs: 12, datei: 'test.mbz');
    await store.aktualisieren(
      old,
      wiederherstellung: WiederherstellungStand.laufend,
      backupid: _Moodle.restore,
      kontext: 55,
      vorherCmids: [],
      wiederherstellungAktivitaeten: [(modul: 'page', titel: 'ZZ Blatt')],
    );
    external.completed = true;
    external.progress = {'progress': 1, 'status': 1000};
    final result = await client.tool('wiederherstellung_status', {'id': old.id});
    expect(result, contains('Inhalts-Hash fehlt'));
    expect(result, contains('Prüflücke'));
    expect(await client.tool('sicherung_status', {}), contains('verified: false'));
  });

  // ---- Sichtbarkeit ohne Vorgabe ------------------------------------------------------------

  group('sichtbarkeit ist Pflicht, eine Vorgabe gibt es nicht', () {
    test('fehlt sie, fragt das Werkzeug zurück, bevor Moodle etwas hört; die KI wählt nicht selbst', () async {
      final vorher = external.requests;
      final fragen = <FreigabeAnfrage>[];
      approvals.addListener(() {
        if (approvals.aktuell != null) fragen.add(approvals.aktuell!);
      });
      for (final aufruf in <(String, Map<String, Object?>)>[
        ('wiederherstellen_datei', {...arguments}..remove('sichtbarkeit')),
        (
          'wiederherstellen_datei',
          {...arguments, 'weg': 'aktueller_kurs_ersetzen', 'loeschend': true}..remove('sichtbarkeit'),
        ),
        (
          'uebertragen',
          {
            'datei': 'test.mbz',
            'ziele': [
              {'kurs': 12, 'name': 'ZZ Kurs', 'weg': 'aktueller_kurs_verschmelzen'},
            ],
          },
        ),
      ]) {
        final antwort = await client.tool(aufruf.$1, aufruf.$2);
        expect(antwort, contains('Frag die Lehrkraft'), reason: '${aufruf.$1}: $antwort');
        expect(antwort, contains('wie in der Quelle sichtbar bleiben oder verborgen werden'));
        expect(antwort, contains('CLAUDE.md'));
        expect(antwort, contains('Nichts geändert'));
      }
      expect(external.requests, vorher, reason: 'keine einzige Anfrage an Moodle');
      expect(external.writes, 0);
      expect(external.starts, 0);
      expect(fragen, isEmpty);
      expect(await Vorgaenge(folder.path, profilKennung: profile.kennung).alle(), isEmpty);
    });

    test('die Werkzeugbeschreibung nennt sie als Pflicht ohne Vorgabe, das Schema führt sie nicht als required', () async {
      // Stünde sie in required, wiese das Protokoll das Fehlen ab (-32602) und die Rückfrage käme nie an.
      final liste = await client.call('tools/list');
      for (final name in ['wiederherstellen_datei', 'uebertragen']) {
        final werkzeug = (liste['tools'] as List).cast<Map>().singleWhere((t) => t['name'] == name);
        expect(werkzeug['description'], contains('sichtbarkeit ist Pflicht und hat keine Vorgabe'));
        expect((werkzeug['inputSchema'] as Map)['required'], isNot(contains('sichtbarkeit')));
        final eigenschaft = (werkzeug['inputSchema'] as Map)['properties']['sichtbarkeit'] as Map;
        expect(eigenschaft['description'], contains('keine Vorgabe'));
        expect(eigenschaft['enum'], ['wie_quelle', 'verborgen']);
      }
    });
  });

  // ---- Ersetzen löscht den Zielkurs --------------------------------------------------------

  group('Ersetzen: Freigabe auf jeder Stufe, Liste, Bestätigung, Einschreibungen behalten, Rückleseprobe', () {
    final ersetzen = <String, Object?>{
      ...arguments,
      'weg': 'aktueller_kurs_ersetzen',
      'loeschend': true,
    };
    final gesehen = <FreigabeAnfrage>[];

    /// Beantwortet jede Freigabe und hält sie fest; [vorher] läuft vor der Antwort (der Moment,
    /// in dem die Lehrkraft die Liste ansieht).
    void antworten({bool ja = true, void Function(FreigabeAnfrage)? vorher}) {
      approvals.addListener(() {
        final a = approvals.aktuell;
        if (a == null) return;
        gesehen.add(a);
        scheduleMicrotask(() {
          vorher?.call(a);
          approvals.entscheiden(ja);
        });
      });
    }

    setUp(() {
      gesehen.clear();
      external.alt = [
        {'id': 5, 'module': 'page', 'name': 'ZZ Alte Seite'},
        {'id': 6, 'module': 'forum', 'name': 'ZZ Forum'},
        {'id': 7, 'module': 'assign', 'name': 'ZZ Aufgabe'},
        {'id': 8, 'module': 'zzfremd', 'name': 'ZZ Fremdes'},
      ];
      external.completeOnStart = true;
      external.progress = {'progress': 1, 'status': 1000};
    });

    for (final stufe in Bestaetigungen.values) {
      test('fragt auch auf Stufe ${stufe.text}, listet jede Aktivität mit Link und verlangt die Bestätigung', () async {
        approvals.stufe = stufe;
        antworten();
        final result = await client.tool('wiederherstellen_datei', ersetzen);
        expect(gesehen, hasLength(1), reason: result);
        expect(approvals.ausgelassen, 0, reason: 'nicht wegen der Stufe ausgelassen');
        final a = gesehen.single;
        expect(a.ab, Bestaetigungen.keine);
        expect(a.knopf, 'Löschen und wiederherstellen');
        expect(
          a.abhaken.single,
          'Ich habe die Liste geprüft. Alle Inhalte des Kurses „ZZ Kurs" werden gelöscht, '
          'auch Abgaben, Beiträge und Bewertungen der Lernenden.',
        );
        expect(a.uebergabe, isFalse, reason: 'keine Übergabe an den Browser, sondern eine Freigabe');

        // Zuerst, hervorgehoben: was Daten von Lernenden enthalten kann oder von moocp nicht gezeigt wird.
        final warnung = a.links.first;
        expect(warnung.warnung, isTrue);
        expect(warnung.links.map((l) => l.text), ['„ZZ Forum" (Forum)', '„ZZ Aufgabe" (Aufgabe)', '„ZZ Fremdes" (zzfremd)']);
        expect(warnung.links[0].warnung, allOf(contains('Daten von Lernenden'), contains('nicht unterstützt')));
        expect(warnung.links[1].warnung, allOf(contains('Daten von Lernenden'), isNot(contains('nicht unterstützt'))));
        expect(warnung.links[2].warnung, allOf(contains('Daten von Lernenden'), contains('nicht unterstützt')));
        final rest = a.links.last;
        expect(a.links, hasLength(2));
        expect(rest.warnung, isFalse);
        expect(rest.links.single.text, '„ZZ Alte Seite" (Textseite)');
        expect(rest.links.single.warnung, isNull);
        expect(rest.links.single.adresse.path, '/mod/page/view.php');
        expect(rest.links.single.adresse.queryParameters, {'id': '5'});
        expect(warnung.links[0].adresse.path, '/mod/forum/view.php');
        expect(warnung.links[0].adresse.queryParameters, {'id': '6'});
        expect(rest.links.single.adresse.host, external.basis.host, reason: 'der Link führt in die eigene Instanz');

        final punkte = a.punkte.join('\n');
        expect(punkte, contains('Aktuelle Rollen und Einschreibungen behalten'));
        expect(punkte, contains('Aktuelle Gruppen und Gruppierungen behalten'));
        expect(punkte, contains('Teilnehmende werden nicht gelesen'));
        expect(punkte, isNot(contains('Rechte und Einschreibungen bleiben unverändert')));
        // Die Freigabe sagt, was geprüft ist und was nicht -- keine Zusage „frei von Nutzerdaten".
        expect(punkte, contains('Auf Nutzerdaten geprüft:'));
        expect(punkte, contains('Nicht geprüft:'));
        expect(punkte, contains(archivAutorenHinweis));
        expect(punkte, isNot(contains('nicht enthalten (geprüft)')));

        // Einschreibungen und Gruppen behalten: beide Felder gesendet, auf 1.
        final gesendet = external.einstellungsFormular!;
        expect(gesendet['setting_root_keep_roles_and_enrolments'], '1');
        expect(gesendet['setting_root_keep_groups_and_groupings'], '1');

        // Rückleseprobe: Alle vier Aktivitäten von vorher sind weg, und das steht in der Antwort.
        expect(result, contains('Alle 4 vor dem Lauf gelisteten Aktivitäten sind aus dem Kurs verschwunden'));
        expect(result, contains('verified: true'));
        expect(result, contains('Einschreibungen und Gruppen'));
        expect(result, contains('nicht gegengeprüft'));
        expect(external.starts, 1);
        final v = (await Vorgaenge(folder.path, profilKennung: profile.kennung).alle()).single;
        expect(v.loeschend, isTrue);
        expect(v.verified, isTrue);
      });
    }

    test('lehnt die Lehrkraft ab, geschieht nichts: kein Upload, kein Start, kein Vorgang', () async {
      approvals.stufe = Bestaetigungen.keine;
      antworten(ja: false);
      final result = await client.tool('wiederherstellen_datei', ersetzen);
      expect(result, contains('Nicht wiederhergestellt'));
      expect(external.writes, 0);
      expect(external.starts, 0);
      expect(external.altEntfernt, isFalse);
      expect(await Vorgaenge(folder.path, profilKennung: profile.kennung).alle(), isEmpty);
    });

    test('ein Kurs ohne Aktivitäten zeigt keine Liste, fragt aber ebenso und bestätigt das Leere', () async {
      external.alt = [];
      approvals.stufe = Bestaetigungen.keine;
      antworten();
      final result = await client.tool('wiederherstellen_datei', ersetzen);
      expect(gesehen.single.links, isEmpty);
      expect(gesehen.single.abhaken, hasLength(1));
      expect(gesehen.single.punkte.join('\n'), contains('Die App sieht im Kurs keine Aktivitäten'));
      expect(result, contains('Vor dem Lauf gab es keine Aktivitäten im Kurs; nichts war zu löschen'));
      expect(result, contains('verified: true'), reason: result);
    });

    test('hat sich der Kurs während der Freigabe geändert, wird nichts gelöscht', () async {
      // Die Freigabe darf 30 Minuten offen sein: Was inzwischen dazukam, hat niemand gesehen.
      antworten(vorher: (_) => external.alt.add({'id': 9, 'module': 'page', 'name': 'ZZ Neu dazu'}));
      final result = await client.tool('wiederherstellen_datei', ersetzen);
      expect(result, contains('seit der Freigabe geändert'));
      expect(result, contains('dazugekommen: „ZZ Neu dazu"'));
      expect(result, contains('Nichts gelöscht'));
      expect(external.writes, 0);
      expect(external.starts, 0);
      expect(await Vorgaenge(folder.path, profilKennung: profile.kennung).alle(), isEmpty);
    });

    test('eine umbenannte oder entfernte Aktivität ändert den Stand ebenso', () async {
      antworten(vorher: (_) {
        external.alt[0] = {'id': 5, 'module': 'page', 'name': 'ZZ Umbenannt'};
        external.alt.removeAt(3);
      });
      final result = await client.tool('wiederherstellen_datei', ersetzen);
      expect(result, contains('seit der Freigabe geändert'));
      expect(result, contains('nicht mehr da: „ZZ Fremdes"'));
      expect(result, contains('geändert: „ZZ Alte Seite" ist jetzt „ZZ Umbenannt"'));
      expect(external.starts, 0);
    });

    for (final angebot in ['keine', 'nurRollen', 'gesperrt']) {
      test('bietet Moodle die Einstellungen nicht (ganz) an ($angebot), bricht das Werkzeug vor dem Löschen ab', () async {
        external.keepAngebot = angebot;
        antworten();
        final result = await client.tool('wiederherstellen_datei', ersetzen);
        expect(result, contains('nicht beide Einstellungen'), reason: result);
        expect(result, contains('Ohne sie würden Einschreibungen und Gruppen mitgelöscht'));
        expect(result, contains('Abgebrochen, bevor etwas gelöscht wurde'));
        if (angebot != 'keine') expect(result, isNot(contains('fehlt: Rollen')));
        if (angebot != 'keine') expect(result, contains('fehlt: Gruppen und Gruppierungen'));
        expect(external.starts, 0, reason: 'Schritt 16 wurde nie gesendet');
        expect(external.einstellungsFormular, isNull, reason: 'schon die Einstellungen gingen nicht ab');
        expect(external.altEntfernt, isFalse);
        final v = (await Vorgaenge(folder.path, profilKennung: profile.kennung).alle()).single;
        expect(v.wiederherstellung, WiederherstellungStand.fehlgeschlagen);
        expect(v.text, contains('im Kurs ist nichts geändert'));
      });
    }

    test('ein nicht angekreuztes Kontrollkästchen ohne verstecktes Feld zählt als angeboten und wird gesendet', () async {
      external.keepAngebot = 'nurCheckbox';
      antworten();
      final result = await client.tool('wiederherstellen_datei', ersetzen);
      expect(result, contains('verified: true'), reason: result);
      expect(external.einstellungsFormular!['setting_root_keep_roles_and_enrolments'], '1');
      expect(external.einstellungsFormular!['setting_root_keep_groups_and_groupings'], '1');
    });

    test('bleibt das Alte stehen, nennt die Antwort die Abweichung und ist nicht verifiziert', () async {
      external.altBleibt = true;
      antworten();
      final result = await client.tool('wiederherstellen_datei', ersetzen);
      expect(result, contains('Abweichung: 4 der vor dem Lauf gelisteten Aktivitäten sind noch im Kurs'));
      expect(result, contains('„ZZ Alte Seite" (page, cmid 5)'));
      expect(result, contains('verified: false'));
      expect(result, isNot(contains('verified: true')));
      final v = (await Vorgaenge(folder.path, profilKennung: profile.kennung).alle()).single;
      expect(v.verified, isFalse);
    });

    test('ohne gespeicherte Liste von vorher ist das Löschen nicht prüfbar und wird als nicht geprüft gemeldet', () async {
      external.progress = {'unexpected': true};
      antworten();
      final gestartet = await client.tool('wiederherstellen_datei', ersetzen);
      final nummer = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(gestartet)!.group(1)!;
      await service.stoppen();
      client.http.close(force: true);
      final datei = File(p.join(folder.path, 'vorgaenge.json'));
      final liste = (jsonDecode(await datei.readAsString()) as List).cast<Map>();
      for (final v in liste) {
        v.remove('vorher_cmids');
      }
      await datei.writeAsString(jsonEncode(liste));
      await startService();
      external.completed = true;
      external.progress = {'progress': 1, 'status': 1000};
      final status = await client.tool('wiederherstellung_status', {'id': nummer});
      expect(status, contains('Löschen nicht geprüft'), reason: status);
      expect(status, contains('verified: false'));
      expect(external.starts, 1);
    });

    test('auch eine Statusabfrage nach einem Neustart erkennt das Ersetzen und prüft das Löschen', () async {
      external.progress = {'unexpected': true};
      antworten();
      final gestartet = await client.tool('wiederherstellen_datei', ersetzen);
      final nummer = RegExp(r'Nummer ([a-z0-9]+)').firstMatch(gestartet)!.group(1)!;
      await service.stoppen();
      client.http.close(force: true);
      await startService();
      external.completed = true;
      external.progress = {'progress': 1, 'status': 1000};
      final status = await client.tool('wiederherstellung_status', {'id': nummer});
      expect(status, contains('Alle 4 vor dem Lauf gelisteten Aktivitäten sind aus dem Kurs verschwunden'), reason: status);
      expect(status, contains('verified: true'));
    });

    test('das Verschmelzen bleibt bei der Stufe, hat keine Liste, keine Bestätigung und keine Zusage zu Einschreibungen', () async {
      approvals.stufe = Bestaetigungen.mittel;
      antworten();
      final result = await client.tool('wiederherstellen_datei', arguments);
      expect(result, contains('Wiederhergestellt'), reason: result);
      final a = gesehen.single;
      expect(a.ab, Bestaetigungen.mittel);
      expect(a.links, isEmpty);
      expect(a.abhaken, isEmpty);
      final punkte = a.punkte.join('\n');
      expect(punkte, isNot(contains('Einschreibungen, Rollen, Gruppen und Gruppierungen bleiben')));
      expect(punkte, isNot(contains('behalten')));
      // Moodle bietet die Felder nur beim Leeren an; die Attrappe immer. Beim Verschmelzen bleiben sie, wie sie sind.
      expect(external.einstellungsFormular!['setting_root_keep_roles_and_enrolments'], '0');
      expect(external.einstellungsFormular!['setting_root_keep_groups_and_groupings'], '0');
    });

    test('Übertragung mit Ersetzen: Zusammenfassung und Zielfreigabe fragen auf Stufe keine, nur die zweite hat die Liste', () async {
      approvals.stufe = Bestaetigungen.keine;
      antworten();
      final result = await client.tool('uebertragen', {
        'datei': 'test.mbz',
        'sichtbarkeit': 'wie_quelle',
        'ziele': [
          {'kurs': 12, 'name': 'ZZ Kurs', 'weg': 'aktueller_kurs_ersetzen', 'loeschend': true},
        ],
      });
      expect(result, contains('1 fertig'), reason: result);
      expect(gesehen, hasLength(2));
      expect(gesehen.every((a) => a.ab == Bestaetigungen.keine), isTrue);
      expect(gesehen[0].punkte.join('\n'), contains('ACHTUNG, löscht'));
      expect(gesehen[0].punkte.join('\n'), contains('„ZZ Kurs" (Kurs 12)'));
      expect(gesehen[0].links, isEmpty);
      expect(gesehen[1].links, isNotEmpty);
      expect(gesehen[1].abhaken, hasLength(1));
      expect(approvals.ausgelassen, 0);
      expect(external.einstellungsFormular!['setting_root_keep_roles_and_enrolments'], '1');
    });

    test('Übertragung ohne löschende Ziele fragt auf Stufe keine nichts', () async {
      approvals.stufe = Bestaetigungen.keine;
      antworten();
      final result = await client.tool('uebertragen', {
        'datei': 'test.mbz',
        'sichtbarkeit': 'wie_quelle',
        'ziele': [
          {'kurs': 12, 'name': 'ZZ Kurs', 'weg': 'aktueller_kurs_verschmelzen'},
        ],
      });
      expect(result, contains('1 fertig'), reason: result);
      expect(gesehen, isEmpty);
    });

    test('lehnt die Lehrkraft in der Zielfreigabe ab, wird in dem Kurs nichts gelöscht', () async {
      var n = 0;
      approvals.addListener(() {
        if (approvals.aktuell == null) return;
        // Die Zusammenfassung bestätigt sie, die Zielfreigabe mit der Liste lehnt sie ab.
        final ja = n++ == 0;
        scheduleMicrotask(() => approvals.entscheiden(ja));
      });
      final result = await client.tool('uebertragen', {
        'datei': 'test.mbz',
        'sichtbarkeit': 'verborgen',
        'ziele': [
          {'kurs': 12, 'name': 'ZZ Kurs', 'weg': 'aktueller_kurs_ersetzen', 'loeschend': true},
        ],
      });
      expect(result, contains('abgelehnt'), reason: result);
      expect(external.starts, 0);
      expect(external.altEntfernt, isFalse);
    });
  });
}
