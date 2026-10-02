// Offline prüfbar: die Einrichtung von Claude Code an einem nachgebauten
// Ordnerbaum -- claude.exe finden, den MCP-Eintrag prüfen, Skills
// vergleichen und installieren.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/einrichtung.dart';
import 'package:path/path.dart' as p;

late Directory tmp;

File datei(String rel, [String inhalt = 'x']) {
  final f = File(p.joinAll([tmp.path, ...rel.split('/')]));
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(inhalt);
  return f;
}

List<int> zip(Map<String, String> dateien) {
  final a = Archive();
  dateien.forEach((name, inhalt) => a.addFile(ArchiveFile.bytes(name, utf8.encode(inhalt))));
  return ZipEncoder().encodeBytes(a);
}

void main() {
  setUp(() => tmp = Directory.systemTemp.createTempSync('einrichtung_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('claude.exe finden', () {
    const desktop = 'lokal/Packages/Claude_pzs8sxrjxfjjc/LocalCache/Roaming/Claude/claude-code';

    test('Claude Desktop (MSIX): höchste Version, als Zahl verglichen', () {
      datei('$desktop/2.1.9/claude.exe');
      datei('$desktop/2.1.10/claude.exe');
      datei('$desktop/2.1.11/anderes.txt'); // Ordner ohne claude.exe zählt nicht
      datei('$desktop/neu/claude.exe'); // keine Versionsnummer
      datei('lokal/Packages/Claude_fremd/LocalCache/Roaming/Claude/claude-code/9.9.9/claude.exe');
      final gefunden = claudeFinden({'LOCALAPPDATA': p.join(tmp.path, 'lokal')});
      expect(gefunden, p.join(tmp.path, 'lokal', 'Packages', 'Claude_pzs8sxrjxfjjc', 'LocalCache', 'Roaming',
          'Claude', 'claude-code', '2.1.10', 'claude.exe'));
    });

    test('Reihenfolge: Claude Desktop vor klassischem Installer vor VS Code', () {
      datei('roaming/Claude/claude-code/3.0.0/claude.exe');
      datei('heim/.vscode/extensions/anthropic.claude-code-2.1.282-win32-x64/resources/native-binary/claude.exe');
      final u = {
        'LOCALAPPDATA': p.join(tmp.path, 'lokal'),
        'APPDATA': p.join(tmp.path, 'roaming'),
        'USERPROFILE': p.join(tmp.path, 'heim'),
      };
      expect(claudeFinden(u), endsWith(p.join('3.0.0', 'claude.exe')));
      datei('$desktop/2.1.281/claude.exe');
      expect(claudeFinden(u), endsWith(p.join('2.1.281', 'claude.exe')));
    });

    test('VS-Code-Erweiterung und Suchpfad', () {
      datei('heim/.vscode/extensions/anthropic.claude-code-2.1.9-win32-x64/resources/native-binary/claude.exe');
      datei('heim/.vscode/extensions/anthropic.claude-code-2.1.10-win32-x64/resources/native-binary/claude.exe');
      expect(claudeFinden({'USERPROFILE': p.join(tmp.path, 'heim')}), contains('2.1.10'));
      datei('bin/claude.exe');
      expect(claudeFinden({'USERPROFILE': p.join(tmp.path, 'heim'), 'PATH': 'C:\\gibtsnicht;${p.join(tmp.path, 'bin')}'}),
          p.join(tmp.path, 'bin', 'claude.exe'));
    });

    test('nichts da, leere Umgebung', () {
      expect(claudeFinden({'LOCALAPPDATA': p.join(tmp.path, 'lokal')}), isNull);
      expect(claudeFinden({}), isNull);
    });
  });

  test('Versionen vergleichen', () {
    expect(versionVergleichen([2, 10], [2, 9]), greaterThan(0));
    expect(versionVergleichen([2, 1, 281], [2, 1, 280]), greaterThan(0));
    expect(versionVergleichen([2, 1], [2, 1, 0]), 0);
  });

  group('MCP-Eintrag prüfen', () {
    File konfig(Object inhalt) => datei('.claude.json', inhalt is String ? inhalt : jsonEncode(inhalt));
    Map eintrag(String url, String schluessel) => {
          'mcpServers': {
            'moodle': {
              'type': 'http',
              'url': url,
              'headers': {'Authorization': 'Bearer $schluessel'},
            },
          },
        };

    test('aktuell, veraltet, fehlt, unlesbar', () {
      expect(verbindungPruefen(File(p.join(tmp.path, 'fehlt.json')), 47811, 'abc'), Verbindung.fehlt);
      expect(verbindungPruefen(konfig({'mcpServers': {}}), 47811, 'abc'), Verbindung.fehlt);
      expect(verbindungPruefen(konfig(eintrag('http://127.0.0.1:47811/mcp', 'abc')), 47811, 'abc'), Verbindung.aktuell);
      expect(verbindungPruefen(konfig(eintrag('http://127.0.0.1:47811/mcp', 'alt')), 47811, 'abc'), Verbindung.veraltet);
      expect(verbindungPruefen(konfig(eintrag('http://127.0.0.1:47812/mcp', 'abc')), 47811, 'abc'), Verbindung.veraltet);
      expect(verbindungPruefen(konfig('{"mcpServers": {"moodle": '), 47811, 'abc'), Verbindung.unlesbar);
    });

    test('der Header geht als ein Argument an claude mcp add', () {
      final a = mcpAddArgumente(47811, 'abc');
      expect(a, containsAllInOrder(['mcp', 'add', '--scope', 'user', 'moodle', 'http://127.0.0.1:47811/mcp']));
      expect(a.last, 'Authorization: Bearer abc');
    });
  });

  group('Skills', () {
    final paket = SkillPaket.ausZip(
        'moodle',
        zip({
          'moodle/SKILL.md': 'Skill',
          'moodle/references/lesen.md': 'Lesen',
          'anderes/SKILL.md': 'gehört nicht dazu',
        }));

    test('Paket liest nur den eigenen Ordner', () {
      expect(paket.dateien.keys, unorderedEquals(['SKILL.md', 'references/lesen.md']));
    });

    test('vergleichen, installieren, Verwaistes entfernen', () {
      final ziel = Directory(p.join(tmp.path, 'skills', 'moodle'));
      expect(skillVergleichen(paket, ziel).text, 'nicht installiert');

      expect(skillInstallieren(paket, ziel), isEmpty);
      expect(skillVergleichen(paket, ziel).aktuell, isTrue);
      expect(File(p.join(ziel.path, 'references', 'lesen.md')).readAsStringSync(), 'Lesen');

      // Handänderung, überzählige Datei, fehlende Datei
      File(p.join(ziel.path, 'SKILL.md')).writeAsStringSync('von Hand geändert');
      datei('skills/moodle/scripts/page-helpers.js');
      File(p.join(ziel.path, 'references', 'lesen.md')).deleteSync();
      final s = skillVergleichen(paket, ziel);
      expect((s.abweichend, s.ueberzaehlig, s.fehlend), (1, 1, 1));
      expect(s.text, 'muss aktualisiert werden');

      expect(skillInstallieren(paket, ziel), isEmpty);
      expect(skillVergleichen(paket, ziel).aktuell, isTrue);
      expect(Directory(p.join(ziel.path, 'scripts')).existsSync(), isFalse, reason: 'leer gewordener Ordner');
    });
  });

  test('Dialog nur, wenn etwas zu tun ist -- fehlendes Python allein zählt nicht', () async {
    final heim = p.join(tmp.path, 'heim');
    datei('heim/.claude.json', jsonEncode({
      'mcpServers': {
        'moodle': {
          'type': 'http',
          'url': 'http://127.0.0.1:47811/mcp',
          'headers': {'Authorization': 'Bearer abc'},
        },
      },
    }));
    datei('lokal/Packages/Claude_pzs8sxrjxfjjc/LocalCache/Roaming/Claude/claude-code/2.1.281/claude.exe');
    final paket = SkillPaket('moodle', {'SKILL.md': utf8.encode('Skill')});
    final u = {'USERPROFILE': heim, 'LOCALAPPDATA': p.join(tmp.path, 'lokal')};
    Future<Einrichtungsstand> pruefen() => einrichtungPruefen(
        umgebung: u, port: 47811, schluessel: 'abc', skills: [paket], python: () async => false);

    var s = await pruefen();
    expect(s.brauchtEtwas, isTrue, reason: 'Skill fehlt');
    skillInstallieren(paket, Directory(p.join(heim, '.claude', 'skills', 'moodle')));
    s = await pruefen();
    expect(s.brauchtEtwas, isFalse);
    expect(s.python, isFalse);

    Directory(p.join(tmp.path, 'lokal')).deleteSync(recursive: true);
    s = await pruefen();
    expect(s.claude, isNull);
    expect(s.brauchtEtwas, isFalse, reason: 'Eintrag stimmt schon, claude.exe braucht es nur zum Eintragen');
  });

  test('Ohne claude.exe einrichtbar sind nur die Skills', () async {
    final heim = p.join(tmp.path, 'heim');
    final paket = SkillPaket('moodle', {'SKILL.md': utf8.encode('Skill')});
    final s = await einrichtungPruefen(
        umgebung: {'USERPROFILE': heim}, port: 47811, schluessel: 'abc', skills: [paket], python: () async => true);
    expect(s.claude, isNull);
    expect(s.verbindung, Verbindung.fehlt);
    expect(s.einrichtbar, isFalse);

    datei('heim/.claude.json', jsonEncode({
      'mcpServers': {
        'moodle': {
          'type': 'http',
          'url': 'http://127.0.0.1:47811/mcp',
          'headers': {'Authorization': 'Bearer abc'},
        },
      },
    }));
    final t = await einrichtungPruefen(
        umgebung: {'USERPROFILE': heim}, port: 47811, schluessel: 'abc', skills: [paket], python: () async => true);
    expect(t.brauchtEtwas, isTrue, reason: 'Skill fehlt');
    expect(t.einrichtbar, isTrue, reason: 'Skills gehen ohne claude.exe');
  });

  test('Wählbare Skills: nur gewählt installiert, abgewählt entfernt, Vorgabe aus dem Bestand', () async {
    final heim = p.join(tmp.path, 'heim');
    datei('heim/.claude.json', jsonEncode({
      'mcpServers': {
        'moodle': {
          'type': 'http',
          'url': 'http://127.0.0.1:47811/mcp',
          'headers': {'Authorization': 'Bearer abc'},
        },
      },
    }));
    final u = {'USERPROFILE': heim};
    final orte = ClaudeOrte(u);
    final moodle = SkillPaket('moodle', {'SKILL.md': utf8.encode('Kurs')});
    final ls = SkillPaket('lernsituation', {'SKILL.md': utf8.encode('Lernsituation')});
    Directory ziel(String n) => Directory(p.join(orte.skills.path, n));
    Future<Einrichtungsstand> pruefen(Set<String> gewaehlt) => einrichtungPruefen(
        umgebung: u, port: 47811, schluessel: 'abc', skills: [moodle, ls], gewaehlt: gewaehlt, python: () async => true);

    // Neu angefangen: nichts gewählt, lernsituation gehört nicht dazu.
    expect(gewaehltVorgabe(orte), isEmpty);
    skillInstallieren(moodle, ziel('moodle'));
    var s = await pruefen(gewaehltVorgabe(orte));
    expect(s.gewollt.map((x) => x.name), ['moodle']);
    expect(s.brauchtEtwas, isFalse, reason: 'nicht gewählt und nicht installiert: nichts zu tun');

    // Gewählt, aber nicht installiert.
    s = await pruefen({'lernsituation'});
    expect(s.brauchtEtwas, isTrue);
    skillInstallieren(ls, ziel('lernsituation'));
    expect((await pruefen({'lernsituation'})).brauchtEtwas, isFalse);

    // Wer ihn schon hat und noch nichts gewählt hat, behält ihn.
    expect(gewaehltVorgabe(orte), {'lernsituation'});

    // Abgewählt: installiert, also entfernen.
    s = await pruefen({});
    expect(s.entfernen, {'lernsituation'});
    expect(s.brauchtEtwas, isTrue);
    expect(skillEntfernen(ziel('lernsituation')), isEmpty);
    s = await pruefen({});
    expect(s.entfernen, isEmpty);
    expect(s.brauchtEtwas, isFalse);
    expect(ziel('lernsituation').existsSync(), isFalse);
  });

  test('CLAUDE_CONFIG_DIR verlegt Einstellungen und Skills', () {
    final o = ClaudeOrte({'USERPROFILE': 'C:\\Users\\x', 'CLAUDE_CONFIG_DIR': 'D:\\claude'});
    expect(o.konfiguration.path, p.join('D:\\claude', '.claude.json'));
    expect(o.skills.path, p.join('D:\\claude', 'skills'));
    final n = ClaudeOrte({'USERPROFILE': 'C:\\Users\\x'});
    expect(n.konfiguration.path, p.join('C:\\Users\\x', '.claude.json'));
    expect(n.skills.path, p.join('C:\\Users\\x', '.claude', 'skills'));
  });

  group('Entfernen beim Deinstallieren', () {
    const desktop = 'lokal/Packages/Claude_pzs8sxrjxfjjc/LocalCache/Roaming/Claude/claude-code';
    const eintrag = {
      'mcpServers': {
        'moodle': {'type': 'http', 'url': 'http://127.0.0.1:1/mcp'},
        'anderer': {'type': 'http', 'url': 'http://127.0.0.1:2/mcp'},
      },
    };
    late Map<String, String> umgebung;
    late File konfig;
    setUp(() {
      umgebung = {'CLAUDE_CONFIG_DIR': p.join(tmp.path, 'cfg'), 'LOCALAPPDATA': p.join(tmp.path, 'lokal')};
      konfig = datei('cfg/.claude.json', jsonEncode(eintrag));
      datei('cfg/skills/moodle/SKILL.md');
      datei('cfg/skills/moodle/references/a.md');
      datei('cfg/skills/lernsituation/SKILL.md');
      datei('cfg/skills/fremd/SKILL.md');
    });

    // Tut, was `claude mcp remove moodle` tut, und merkt sich den Aufruf.
    final aufrufe = <List<String>>[];
    Future<int> claudeAttrappe(String programm, List<String> argumente) async {
      aufrufe.add([programm, ...argumente]);
      konfig.writeAsStringSync(jsonEncode({'mcpServers': {'anderer': eintrag['mcpServers']!['anderer']}}));
      return 0;
    }

    setUp(aufrufe.clear);

    test('Eintrag über claude.exe, Skills der App gelöscht, fremde bleiben', () async {
      final exe = datei('$desktop/2.1.9/claude.exe').path;
      final e = await einrichtungEntfernen(
          umgebung: umgebung, skills: ['moodle', 'lernsituation'], ausfuehren: claudeAttrappe);
      expect(aufrufe, [
        [exe, 'mcp', 'remove', 'moodle', '--scope', 'user'],
      ]);
      expect(e.code, 0);
      expect(Directory(p.join(tmp.path, 'cfg/skills/moodle')).existsSync(), isFalse);
      expect(Directory(p.join(tmp.path, 'cfg/skills/lernsituation')).existsSync(), isFalse);
      expect(File(p.join(tmp.path, 'cfg/skills/fremd/SKILL.md')).existsSync(), isTrue);
    });

    test('ohne claude.exe: Eintrag bleibt und wird gemeldet, Skills trotzdem weg', () async {
      final e = await einrichtungEntfernen(umgebung: umgebung, skills: ['moodle'], ausfuehren: claudeAttrappe);
      expect(aufrufe, isEmpty);
      expect(e.eintragBleibt, isTrue);
      expect(e.code, 1);
      expect(Directory(p.join(tmp.path, 'cfg/skills/moodle')).existsSync(), isFalse);
    });

    test('Exit-Code 0 von claude.exe zählt nicht, nur der Eintrag danach', () async {
      datei('$desktop/2.1.9/claude.exe');
      final e = await einrichtungEntfernen(
          umgebung: umgebung, skills: const [], ausfuehren: (_, _) async => 0);
      expect(e.code, 1);
    });

    test('ohne Eintrag wird claude.exe gar nicht gesucht', () async {
      konfig.writeAsStringSync(jsonEncode({'mcpServers': {}}));
      final e = await einrichtungEntfernen(umgebung: umgebung, skills: ['nicht-da'], ausfuehren: claudeAttrappe);
      expect(aufrufe, isEmpty);
      expect(e.code, 0);
    });
  });
}
