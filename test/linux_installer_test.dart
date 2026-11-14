// Installer unter Linux (lib/installer/): Logik in einem eigenen Heimatordner,
// nie in den echten Einstellungen (A10); dazu die Seiten als Widget-Test.
@TestOn('linux')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/installer/installer_logik.dart';
import 'package:moocp/installer/installer_seiten.dart';
import 'package:path/path.dart' as p;

/// Ein Heimatordner mit einer gebauten „App" (ein Skript statt des Programms).
class _Welt {
  _Welt({int claudeEntfernenCode = 0}) {
    wurzel = Directory.systemTemp.createTempSync('moocp_installer_');
    heim = Directory(p.join(wurzel.path, 'heim'))..createSync();
    quelle = Directory(p.join(wurzel.path, 'paket'))..createSync();
    File(p.join(quelle.path, 'moocp'))
      ..writeAsStringSync('#!/bin/sh\nif [ "\$1" = "--claude-entfernen" ]; then exit $claudeEntfernenCode; fi\n')
      ..createSync();
    Process.runSync('chmod', ['755', p.join(quelle.path, 'moocp')]);
    Directory(p.join(quelle.path, 'lib')).createSync();
    File(p.join(quelle.path, 'lib', 'libx.so')).writeAsStringSync('x');
    Directory(p.join(quelle.path, 'data', 'flutter_assets')).createSync(recursive: true);
    File(p.join(quelle.path, 'data', 'flutter_assets', 'a')).writeAsStringSync('a');
    File(p.join(quelle.path, 'moocp.png')).writeAsBytesSync([1, 2, 3]);
    orte = InstallerOrte({
      'HOME': heim.path,
      'USER': 'tester',
      'TMPDIR': Directory(p.join(wurzel.path, 'tmp'))..createSync(),
    }.map((k, v) => MapEntry(k, v is Directory ? v.path : v as String)));
  }
  late final Directory wurzel, heim, quelle;
  late final InstallerOrte orte;
  String get ziel => orte.standardZiel;
  void weg() => wurzel.deleteSync(recursive: true);
}

void main() {
  var hat = false;
  _Welt neu({int code = 0}) {
    hat = true;
    return _Welt(claudeEntfernenCode: code);
  }

  late _Welt w;
  tearDown(() {
    if (hat) w.weg();
    hat = false;
  });

  test('Standardziel liegt im Benutzerordner, ohne Administratorrechte', () {
    w = neu();
    expect(w.ziel, p.join(w.heim.path, '.local', 'opt', 'moocp'));
    expect(w.orte.menueDatei, p.join(w.heim.path, '.local', 'share', 'applications', 'moocp.desktop'));
  });

  test('installieren legt Programm, Marke, Skript, Menü und Schreibtisch an', () {
    w = neu();
    Directory(p.join(w.heim.path, 'Desktop')).createSync();
    installieren(quelle: w.quelle.path, ziel: w.ziel, orte: w.orte, version: '1.2.3+1');
    expect(File(p.join(w.ziel, 'lib', 'libx.so')).existsSync(), isTrue);
    expect(File(p.join(w.ziel, 'data', 'flutter_assets', 'a')).readAsStringSync(), 'a');
    // ausführbar
    expect(File(p.join(w.ziel, 'moocp')).statSync().mode & 0x40, isNot(0));
    expect(File(p.join(w.ziel, 'moocp-deinstallieren')).statSync().mode & 0x40, isNot(0));
    expect(File(p.join(w.ziel, '.moocp-installiert')).readAsStringSync().trim(), '1.2.3+1');
    final menue = File(w.orte.menueDatei).readAsStringSync();
    expect(menue, contains('Exec="${p.join(w.ziel, 'moocp')}"'));
    expect(menue, contains('Icon=moocp'));
    expect(menue, contains('Actions=deinstallieren;'));
    expect(File(w.orte.desktopDatei).existsSync(), isTrue);
    expect(File(w.orte.symbolDatei).readAsBytesSync(), [1, 2, 3]);
  });

  test('ohne Schreibtischordner bleibt es beim Menü', () {
    w = neu();
    installieren(quelle: w.quelle.path, ziel: w.ziel, orte: w.orte, version: '1');
    expect(File(w.orte.menueDatei).existsSync(), isTrue);
    expect(File(w.orte.desktopDatei).existsSync(), isFalse);
  });

  test('Update ersetzt Programmdateien und lässt Fremdes und Daten stehen', () {
    w = neu();
    installieren(quelle: w.quelle.path, ziel: w.ziel, orte: w.orte, version: '1');
    File(p.join(w.ziel, 'meine-notiz.txt')).writeAsStringSync('bleibt');
    File(p.join(w.ziel, 'lib', 'alt.so')).writeAsStringSync('alt');
    Directory(w.orte.einstellungen).createSync(recursive: true);
    File(p.join(w.orte.einstellungen, 'einstellungen.json')).writeAsStringSync('{}');
    installieren(quelle: w.quelle.path, ziel: w.ziel, orte: w.orte, version: '2');
    expect(File(p.join(w.ziel, 'meine-notiz.txt')).readAsStringSync(), 'bleibt');
    expect(File(p.join(w.ziel, 'lib', 'alt.so')).existsSync(), isFalse);
    expect(File(p.join(w.ziel, '.moocp-installiert')).readAsStringSync().trim(), '2');
    expect(File(p.join(w.orte.einstellungen, 'einstellungen.json')).existsSync(), isTrue);
  });

  test('ein nicht leerer fremder Ordner wird nie überschrieben', () {
    w = neu();
    final fremd = Directory(p.join(w.heim.path, 'fremd'))..createSync();
    File(p.join(fremd.path, 'wichtig.txt')).writeAsStringSync('x');
    expect(() => installieren(quelle: w.quelle.path, ziel: fremd.path, orte: w.orte, version: '1'), throwsA(isA<InstallerFehler>()));
    expect(File(p.join(fremd.path, 'wichtig.txt')).existsSync(), isTrue);
    expect(File(p.join(fremd.path, 'moocp')).existsSync(), isFalse);
  });

  test('zielPruefen: relativ, Datei und Paketordner werden abgelehnt', () {
    w = neu();
    expect(() => zielPruefen('relativ/pfad'), throwsA(isA<InstallerFehler>()));
    expect(() => zielPruefen(''), throwsA(isA<InstallerFehler>()));
    final datei = File(p.join(w.heim.path, 'datei'))..writeAsStringSync('x');
    expect(() => zielPruefen(datei.path), throwsA(isA<InstallerFehler>()));
    expect(
      () => installieren(quelle: w.quelle.path, ziel: p.join(w.quelle.path, 'unter'), orte: w.orte, version: '1'),
      throwsA(isA<InstallerFehler>()),
    );
    expect(() => zielPruefen(p.join(w.heim.path, 'neu')), returnsNormally);
  });

  test('Quelle ohne App wird abgelehnt', () {
    w = neu();
    final leer = Directory(p.join(w.wurzel.path, 'leer'))..createSync();
    expect(() => installieren(quelle: leer.path, ziel: w.ziel, orte: w.orte, version: '1'), throwsA(isA<InstallerFehler>()));
  });

  test('programmLaeuft erkennt ein laufendes Programm über /proc, nicht den eigenen Prozess', () {
    w = neu();
    final proc = Directory(p.join(w.wurzel.path, 'proc'))..createSync();
    Directory(p.join(proc.path, '4242')).createSync();
    Link(p.join(proc.path, '4242', 'exe')).createSync('/x/y/moocp');
    Directory(p.join(proc.path, 'self')).createSync();
    expect(programmLaeuft('/x/y/moocp', proc: proc.path), isTrue);
    expect(programmLaeuft('/x/y/anders', proc: proc.path), isFalse);
    Link(p.join(proc.path, '4242', 'exe')).updateSync('/x/y/moocp (deleted)');
    expect(programmLaeuft('/x/y/moocp', proc: proc.path), isTrue);
    // Der Installer selbst zählt nicht.
    Directory(p.join(proc.path, '$pid')).createSync();
    Link(p.join(proc.path, '$pid', 'exe')).createSync('/z/moocp');
    expect(programmLaeuft('/z/moocp', proc: proc.path), isFalse);
  });

  test('desktopInhalt setzt Pfade mit Leerzeichen in Anführungszeichen', () {
    final s = desktopInhalt(exe: '/home/a b/moocp', deinstallieren: '/home/a b/moocp-deinstallieren');
    expect(s, contains('Exec="/home/a b/moocp"\n'));
    expect(s, contains('Exec="/home/a b/moocp-deinstallieren"'));
  });

  test('desktopInhalt maskiert %, \$ und Anführungszeichen im Pfad', () {
    final s = desktopInhalt(exe: r'/home/a/100%/$x/"q"/moocp', deinstallieren: '/x');
    expect(s, contains(r'Exec="/home/a/100%%/\\$x/\\"q\\"/moocp"'));
  });

  test('eine Quelle ohne lib/ legt nichts an (kein Ordner ohne Marke)', () {
    w = neu();
    Directory(p.join(w.quelle.path, 'lib')).deleteSync(recursive: true);
    expect(() => installieren(quelle: w.quelle.path, ziel: w.ziel, orte: w.orte, version: '1'), throwsA(isA<InstallerFehler>()));
    // Kaputte Quelle ohne lib/: nichts angelegt, kein Ordner ohne Marke.
    expect(Directory(w.ziel).existsSync(), isFalse);
  });

  test('programmLaeuft erkennt die App auch über einen Symlink im Zielpfad', () {
    w = neu();
    final echt = Directory(p.join(w.wurzel.path, 'echt'))..createSync();
    final link = Link(p.join(w.wurzel.path, 'link'))..createSync(echt.path);
    final proc = Directory(p.join(w.wurzel.path, 'proc'))..createSync();
    Directory(p.join(proc.path, '7')).createSync();
    Link(p.join(proc.path, '7', 'exe')).createSync(p.join(echt.resolveSymbolicLinksSync(), 'moocp'));
    expect(programmLaeuft(p.join(link.path, 'moocp'), proc: proc.path), isTrue);
  });

  test('deinstallieren räumt alles ab, nennt Reste und lässt Fremdes stehen', () async {
    w = neu(code: 1);
    Directory(p.join(w.heim.path, 'Desktop')).createSync();
    installieren(quelle: w.quelle.path, ziel: w.ziel, orte: w.orte, version: '1');
    File(p.join(w.ziel, 'fremd.txt')).writeAsStringSync('bleibt');
    for (final d in [w.orte.einstellungen, w.orte.prefsOrdner, w.orte.arbeitsordner]) {
      Directory(d).createSync(recursive: true);
      File(p.join(d, 'x')).writeAsStringSync('x');
    }
    var anmeldedatenGeloescht = false;
    final e = await deinstallieren(
      ziel: w.ziel,
      orte: w.orte,
      anmeldedatenLoeschen: () async => anmeldedatenGeloescht = true,
    );
    expect(anmeldedatenGeloescht, isTrue);
    expect(e.eintragBlieb, isTrue);
    expect(e.hinweis, contains('claude mcp remove moodle'));
    expect(File(p.join(w.ziel, 'moocp')).existsSync(), isFalse);
    expect(File(p.join(w.ziel, '.moocp-installiert')).existsSync(), isFalse);
    expect(File(p.join(w.ziel, 'fremd.txt')).existsSync(), isTrue);
    for (final f in [w.orte.menueDatei, w.orte.desktopDatei, w.orte.symbolDatei]) {
      expect(File(f).existsSync(), isFalse, reason: f);
    }
    for (final d in [w.orte.einstellungen, w.orte.prefsOrdner, w.orte.arbeitsordner]) {
      expect(Directory(d).existsSync(), isFalse, reason: d);
    }
  });

  test('deinstallieren ohne Marke und bei laufender App bricht ab, ohne etwas zu löschen', () async {
    w = neu();
    Directory(w.orte.einstellungen).createSync(recursive: true);
    await expectLater(deinstallieren(ziel: w.ziel, orte: w.orte), throwsA(isA<InstallerFehler>()));
    expect(Directory(w.orte.einstellungen).existsSync(), isTrue);
  });

  test('ganz entfernter Ordner: das Ziel verschwindet, wenn es leer ist', () async {
    w = neu();
    installieren(quelle: w.quelle.path, ziel: w.ziel, orte: w.orte, version: '1');
    final e = await deinstallieren(ziel: w.ziel, orte: w.orte);
    expect(e.hinweis, isEmpty);
    expect(Directory(w.ziel).existsSync(), isFalse);
  });

  group('Seiten', () {
    Future<void> baue(WidgetTester t, _Welt w, {Duration wartezeit = const Duration(seconds: 2), List<int>? codes, List<String>? gestartet}) async {
      await t.binding.setSurfaceSize(const Size(640, 460));
      await t.pumpWidget(
        InstallerApp(
          modus: InstallerModus.installieren,
          orte: w.orte,
          ziel: w.ziel,
          quelle: w.quelle.path,
          version: '9.9.9',
          wartezeit: wartezeit,
          beenden: (c) => codes?.add(c),
          starten: (z) async => gestartet?.add(z),
        ),
      );
      await t.pump();
    }

    testWidgets('Hinweis: „Weiter" ist erst nach der Wartezeit aktiv', (t) async {
      w = neu();
      await baue(t, w);
      expect(find.text('Nutzung auf eigene Verantwortung'), findsOneWidget);
      expect(tester(t, 'Weiter in 2 s'), isNotNull);
      FilledButton knopf() => t.widget<FilledButton>(find.byType(FilledButton));
      expect(knopf().onPressed, isNull);
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Weiter in 1 s'), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Weiter >'), findsOneWidget);
      expect(knopf().onPressed, isNotNull);
    });

    testWidgets('Ablauf: Hinweis, Lizenz, Ziel, Installieren, Fertig stellen mit Start', (t) async {
      w = neu();
      final codes = <int>[];
      final gestartet = <String>[];
      await baue(t, w, wartezeit: Duration.zero, codes: codes, gestartet: gestartet);
      await t.tap(find.text('Weiter >'));
      await t.pump();
      expect(find.text('Lizenzvereinbarung'), findsOneWidget);
      await t.tap(find.text('Weiter >'));
      await t.pump();
      expect(find.text('Zielordner wählen'), findsOneWidget);
      // Ungültiges Ziel bleibt auf der Seite und nennt den Grund.
      await t.enterText(find.byType(TextField), 'relativ');
      await t.tap(find.text('Installieren'));
      await t.pump();
      expect(find.text('Zielordner wählen'), findsOneWidget);
      expect(find.textContaining('vollständigen Ordnerpfad'), findsOneWidget);
      await t.enterText(find.byType(TextField), w.ziel);
      await t.tap(find.text('Installieren'));
      await t.pump(const Duration(milliseconds: 100));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await t.pump();
      expect(find.text('Die Installation ist abgeschlossen'), findsOneWidget);
      expect(File(p.join(w.ziel, 'moocp')).existsSync(), isTrue);
      await t.tap(find.text('Fertig stellen'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      expect(codes, [0]);
      expect(gestartet, [w.ziel]);
    });

    testWidgets('Abbrechen fragt nach und beendet erst nach „Ja"', (t) async {
      w = neu();
      final codes = <int>[];
      await baue(t, w, codes: codes);
      await t.tap(find.text('Abbrechen'));
      await t.pumpAndSettle();
      expect(find.textContaining('wirklich abbrechen'), findsOneWidget);
      await t.tap(find.text('Nein'));
      await t.pumpAndSettle();
      expect(codes, isEmpty);
      await t.tap(find.text('Abbrechen'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ja'));
      await t.pumpAndSettle();
      expect(codes, [1]);
    });

    testWidgets('Deinstallation: Bestätigung, Entfernen, Fertig', (t) async {
      w = neu();
      installieren(quelle: w.quelle.path, ziel: w.ziel, orte: w.orte, version: '1');
      await t.binding.setSurfaceSize(const Size(640, 460));
      final codes = <int>[];
      await t.pumpWidget(
        InstallerApp(modus: InstallerModus.deinstallieren, orte: w.orte, ziel: w.ziel, beenden: (c) => codes.add(c)),
      );
      await t.pump();
      expect(find.text('moocp deinstallieren'), findsOneWidget);
      await t.tap(find.text('Deinstallieren'));
      await t.pump(const Duration(milliseconds: 100));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
      await t.pump();
      expect(find.text('Die Deinstallation ist abgeschlossen'), findsOneWidget);
      expect(File(p.join(w.ziel, 'moocp')).existsSync(), isFalse);
      await t.tap(find.text('Fertig stellen'));
      await t.pump();
      expect(codes, [0]);
    });
  });
}

Finder tester(WidgetTester t, String text) => find.text(text);
