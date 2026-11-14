// Die Linux-Zweige: Einstellungsordner nach XDG (auf jedem Rechner prüfbar),
// die Suche nach den KI-Werkzeugen und nach dem Browser (nur unter Linux, dort
// gilt POSIX-Pfadrecht), die Richtlinien des Browsers.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/anmeldedaten.dart';
import 'package:moocp/arbeitsordner.dart';
import 'package:moocp/einrichtung.dart';
import 'package:moocp/einstellungen_ort.dart';
import 'package:moocp/plattform/linux.dart';
import 'package:moocp/plattform/linux_schluesselbund.dart';
import 'package:moocp/plattform/plattform.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  arbeitsordnerTests();
  schluesselbundTests();
  group('Einstellungsordner unter Linux', () {
    test('~/.config/moocp, wenn XDG_CONFIG_HOME fehlt', () {
      expect(
        einstellungenOrdnerFuer({'HOME': '/home/x'}, macos: false, linux: true),
        p.join('/home/x', '.config', 'moocp'),
      );
    });

    test('XDG_CONFIG_HOME gilt, wenn es absolut ist', () {
      expect(
        einstellungenOrdnerFuer({'HOME': '/home/x', 'XDG_CONFIG_HOME': '/srv/konfig'}, macos: false, linux: true),
        p.join('/srv/konfig', 'moocp'),
      );
    });

    test('ein relatives XDG_CONFIG_HOME wird ignoriert, wie die Spezifikation es verlangt', () {
      expect(
        einstellungenOrdnerFuer({'HOME': '/home/x', 'XDG_CONFIG_HOME': 'konfig'}, macos: false, linux: true),
        p.join('/home/x', '.config', 'moocp'),
      );
    });

    test('ohne HOME ein klarer Fehler statt Temp-Ordner', () {
      expect(() => einstellungenOrdnerFuer({}, macos: false, linux: true), throwsA(isA<StateError>()));
    });

    test('Sicherungen liegen im Einstellungsordner', () {
      expect(
        sicherungenOrdnerFuer({'HOME': '/home/x'}, macos: false, linux: true),
        p.join('/home/x', '.config', 'moocp', 'sicherungen'),
      );
    });
  });

  group('Browser unter Linux', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('linuxbrowser'));
    tearDown(() => tmp.deleteSync(recursive: true));

    void programm(String name) => File(p.join(tmp.path, 'bin', name))
      ..createSync(recursive: true)
      ..writeAsStringSync('#!/bin/sh\n');

    test('Chromium und Chrome werden im Suchpfad gefunden, Edge fehlt', () async {
      programm('chromium');
      programm('google-chrome-stable');
      final b = LinuxBrowser(pfad: [p.join(tmp.path, 'bin')]);
      expect(await b.programm(BrowserArt.chromium), p.join(tmp.path, 'bin', 'chromium'));
      expect(await b.programm(BrowserArt.chrome), p.join(tmp.path, 'bin', 'google-chrome-stable'));
      expect(await b.programm(BrowserArt.edge), isNull);
    });

    test('Richtlinie RemoteDebuggingAllowed=false verbietet die Fernsteuerung', () async {
      final ordner = Directory(p.join(tmp.path, 'managed'))..createSync();
      File(p.join(ordner.path, 'a.json')).writeAsStringSync(jsonEncode({'RemoteDebuggingAllowed': false}));
      final b = LinuxBrowser(pfad: const [], richtlinien: [ordner.path]);
      expect(await b.fernsteuerungVerboten(BrowserArt.chrome), isTrue);
    });

    test('ohne Richtlinie, mit anderer Richtlinie oder kaputtem JSON ist sie erlaubt', () async {
      final ordner = Directory(p.join(tmp.path, 'managed'))..createSync();
      File(p.join(ordner.path, 'a.json')).writeAsStringSync(jsonEncode({'HomepageLocation': 'x'}));
      File(p.join(ordner.path, 'b.json')).writeAsStringSync('{kaputt');
      expect(await LinuxBrowser(pfad: const [], richtlinien: [ordner.path]).fernsteuerungVerboten(BrowserArt.chrome), isFalse);
      expect(await LinuxBrowser(pfad: const [], richtlinien: [p.join(tmp.path, 'fehlt')]).fernsteuerungVerboten(BrowserArt.chrome), isFalse);
    });

    test('prozesseBeenden lässt fremde Prozesse in Ruhe', () async {
      final profil = Directory(p.join(tmp.path, 'profil-ohne-prozess'));
      expect(await LinuxBrowser(pfad: const []).prozesseBeenden(profil, 'chromium'), 0);
    });
  }, skip: Platform.isWindows ? 'ps und kill gibt es unter Windows nicht' : null);

  group('KI-Werkzeuge unter Linux', () {
    late Directory tmp;
    late String heim;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('kiwerklinux');
      heim = p.join(tmp.path, 'heim');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    void programm(String pfad) => File(pfad)
      ..createSync(recursive: true)
      ..writeAsStringSync('#!/bin/sh\n');

    test('claude unter ~/.local/bin, auch wenn PATH leer ist (Sitzung über xrdp)', () {
      programm(p.join(heim, '.local', 'bin', 'claude'));
      expect(claudeFinden({'HOME': heim, 'PATH': ''}), p.join(heim, '.local', 'bin', 'claude'));
    });

    test('codex im PATH ohne Endung', () {
      programm(p.join(tmp.path, 'bin', 'codex'));
      final codex = CodexCli({'HOME': heim, 'PATH': p.join(tmp.path, 'bin')});
      expect(codex.exe, p.join(tmp.path, 'bin', 'codex'));
      expect(codex.heim.path, p.join(heim, '.codex'));
    });

    test('codex unter ~/.npm-global/bin, auch ohne PATH', () {
      programm(p.join(heim, '.npm-global', 'bin', 'codex'));
      expect(CodexCli({'HOME': heim, 'PATH': ''}).exe, p.join(heim, '.npm-global', 'bin', 'codex'));
    });

    test('Claude Code liest die Konfiguration unter HOME', () {
      expect(ClaudeCode({'HOME': heim}).konfiguration.path, p.join(heim, '.claude.json'));
    });

    test('LM Studio wird unter Linux nicht angeboten', () {
      Directory(p.join(heim, '.lmstudio', 'apps', 'bionic')).createSync(recursive: true);
      expect(LmStudio({'HOME': heim}, bruecke: p.join(tmp.path, 'x')).gefunden, isFalse);
    });
  }, skip: Platform.isLinux ? null : 'Suche nach Programmen unter Linux nur auf Linux');
}

// Der Arbeitsordner unter Linux: je Benutzer, nur für ihn lesbar, nie über
// eine fremde Verknüpfung.
void arbeitsordnerTests() {
  group('Arbeitsordner unter Linux', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('aolinux'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('der Name trägt den Benutzer, unzulässige Zeichen fallen weg', () {
      expect(Arbeitsordner.ordnername({'USER': 'e.mustermann'}, linux: true), 'moocp_arbeitsordner_e.mustermann');
      expect(Arbeitsordner.ordnername({'USER': '../x y'}, linux: true), 'moocp_arbeitsordner_..xy');
      expect(Arbeitsordner.ordnername({'LOGNAME': 'a'}, linux: true), 'moocp_arbeitsordner_a');
      expect(Arbeitsordner.ordnername({}, linux: true), 'moocp_arbeitsordner_benutzer');
      expect(Arbeitsordner.ordnername({'USER': 'x'}, linux: false), 'moocp_arbeitsordner');
    });

    test('der Ordner gehört nur dem Benutzer (Rechte 700)', () {
      final (a, _) = Arbeitsordner.einrichten(temp: tmp.path, linux: true, umgebung: {'USER': 'x'});
      expect(a.pfad, endsWith('moocp_arbeitsordner_x'));
      expect(FileStat.statSync(a.pfad).mode & 0x1ff, 0x1c0);
    }, skip: Platform.isWindows ? 'Dateirechte nach POSIX' : null);

    test('eine Verknüpfung an der Stelle des Ordners wird nicht benutzt', () {
      final fremd = Directory(p.join(tmp.path, 'fremd'))..createSync();
      Link(p.join(tmp.path, 'moocp_arbeitsordner_x')).createSync(fremd.path);
      expect(
        () => Arbeitsordner.einrichten(temp: tmp.path, linux: true, umgebung: {'USER': 'x'}),
        throwsStateError,
      );
    }, skip: Platform.isWindows ? 'Verknüpfungen nach POSIX' : null);
  });
}

// Der Zugriff auf den Schlüsselbund unter Linux: Ohne benutzbaren Bund wird gar
// nicht erst libsecret gerufen, das die App anhielte (anmeldedaten.dart).
void schluesselbundTests() {
  group('Passwort im Schlüsselbund unter Linux', () {
    final aufrufe = <String>[];
    setUp(() {
      aufrufe.clear();
      SharedPreferences.setMockInitialValues({'anmeldung.merken': true, 'anmeldung.benutzer': 'e.mustermann'});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async {
          aufrufe.add(call.method);
          return call.method == 'read' ? 'geheim' : null;
        },
      );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      );
      Anmeldedaten.schluesselbundPruefer = () async => Schluesselbund.bereit;
      Anmeldedaten.schluesselbundEntsperrer = () async => Schluesselbund.bereit;
    });

    test('bereit: lesen und speichern gehen durch', () async {
      Anmeldedaten.schluesselbundPruefer = () async => Schluesselbund.bereit;
      expect((await Anmeldedaten.laden()).passwort, 'geheim');
      await Anmeldedaten.speichern('e.mustermann', 'pw');
      expect(aufrufe, containsAll(['read', 'write']));
    });

    for (final zustand in [Schluesselbund.gesperrt, Schluesselbund.fehlt, Schluesselbund.unbekannt]) {
      test('$zustand: libsecret wird nicht gerufen, Laden nennt den Grund, Speichern scheitert sichtbar', () async {
        Anmeldedaten.schluesselbundPruefer = () async => zustand;
        // Bleibt der Bund nach dem Entsperrversuch gesperrt, ist er nicht benutzbar.
        Anmeldedaten.schluesselbundEntsperrer = () async => zustand;
        final daten = await Anmeldedaten.laden();
        expect(daten.passwort, isNull);
        expect(daten.benutzer, 'e.mustermann');
        expect(daten.speicherProblem, SchluesselbundFehler(zustand).meldung, reason: 'kein stilles Scheitern');
        await expectLater(Anmeldedaten.speichern('e.mustermann', 'pw'), throwsA(isA<SchluesselbundFehler>()));
        expect(aufrufe, isEmpty, reason: 'kein Aufruf an den Schlüsselbund');
      });
    }

    test('gesperrt, dann von der Lehrkraft entsperrt: der Zugriff geht durch', () async {
      var entsperrt = false;
      Anmeldedaten.schluesselbundPruefer = () async => entsperrt ? Schluesselbund.bereit : Schluesselbund.gesperrt;
      Anmeldedaten.schluesselbundEntsperrer = () async {
        entsperrt = true;
        return Schluesselbund.bereit;
      };
      final daten = await Anmeldedaten.laden();
      expect(daten.passwort, 'geheim');
      expect(daten.speicherProblem, isNull);
    });

    test('Löschen: ohne Bund nichts zu tun, bei gesperrtem Bund ein Fehler', () async {
      Anmeldedaten.schluesselbundPruefer = () async => Schluesselbund.fehlt;
      await Anmeldedaten.loeschen();
      expect(aufrufe, isEmpty);
      Anmeldedaten.schluesselbundPruefer = () async => Schluesselbund.gesperrt;
      Anmeldedaten.schluesselbundEntsperrer = () async => Schluesselbund.gesperrt;
      await expectLater(Anmeldedaten.loeschen(), throwsA(isA<SchluesselbundFehler>()));
      expect(aufrufe, isEmpty);
    });

    test('Meldungen sind fester Text und nennen, was zu tun ist', () {
      for (final z in Schluesselbund.values) {
        expect(SchluesselbundFehler(z).meldung, isNotEmpty);
      }
      expect(SchluesselbundFehler(Schluesselbund.unbekannt).meldung, contains('libglib2.0-bin'));
      expect(Anmeldedaten.schutz, contains('Secret Service'));
    });
  }, skip: Platform.isLinux ? null : 'Zugriff auf den Schlüsselbund unter Linux nur auf Linux');
}
