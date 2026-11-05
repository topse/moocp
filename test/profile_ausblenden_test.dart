// Instanzprofile sind ein Sonderfall für wenige: Wer nur eine Moodle-Instanz
// hat -- fast jeder --, sieht von Profilen nichts (E32). Erst ab zwei Profilen
// erscheinen die Auswahl und die Namen in Titelzeile und Dialogen; eine weitere
// Instanz verbindet man über die Einstellungen. Dazu: die Stufe „keine" eines
// Profils im Hintergrund bleibt sichtbar (E20), und ein veraltetes
// gespeichertes Passwort erzeugt genau einen Fehlversuch (E7).
//
// Die Einstellungen schreiben hier nichts: Eine Unterklasse ersetzt `speichern`,
// denn sonst überschriebe der Test die echte Einstellungsdatei der App.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/arbeitsordner.dart';
import 'package:moocp/einrichtung.dart';
import 'package:moocp/einrichtung_dialog.dart';
import 'package:moocp/einstellungen.dart';
import 'package:moocp/freigabe.dart';
import 'package:moocp/main.dart';
import 'package:moocp/mcp/mcp_dienst.dart';
import 'package:moocp/moodle/moodle_zugang.dart';
import 'package:moocp/profil.dart';
import 'package:moocp/protokoll.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _EinstellungenOhneDatei extends Einstellungen {
  _EinstellungenOhneDatei({super.profile, required super.schluessel});
  int gespeichert = 0;

  @override
  Future<void> speichern() async => gespeichert++;
}

/// Ein Zugang, der sich nicht ins Netz wagt: zählt die Versuche und lehnt auf
/// Wunsch ausdrücklich ab, wie Moodle bei einem falschen Passwort.
class _Zugang extends MoodleZugang {
  _Zugang(super.protokoll, {this.ablehnen = false});
  final bool ablehnen;
  int versuche = 0;

  @override
  Future<void> anmelden(String adresse, String benutzer, String passwort) async {
    versuche++;
    if (ablehnen) {
      throw MoodleAnmeldungAbgelehnt('Anmeldung fehlgeschlagen. Benutzername oder Passwort prüfen.');
    }
  }
}

Profil _profil(String kennung, String name, String mcp, int port, {Bestaetigungen stufe = Bestaetigungen.mittel}) =>
    Profil(
      kennung: kennung,
      name: name,
      adresse: 'https://$mcp.schule.example',
      port: port,
      mcpName: mcp,
      bestaetigungen: stufe,
      schluessel: kennung == Profil.standardKennung ? '' : 'schluessel-$kennung',
    );

Instanz _instanz(Einstellungen e, Protokoll protokoll, Profil profil, {bool ablehnen = false}) {
  final ansicht = protokoll.fuer(profil.name);
  final zugang = _Zugang(ansicht, ablehnen: ablehnen);
  final freigaben = Freigaben(ansicht, stufe: profil.bestaetigungen);
  return Instanz(zugang, freigaben, McpDienst(e, zugang, ansicht, freigaben, 'arbeitsordner', profil: profil));
}

/// Alles eingerichtet: Die echte Prüfung sähe auf dem Rechner nach.
Future<Einrichtungsstand> _eingerichtet() async => Einrichtungsstand(
      werkzeuge: [
        Werkzeugstand(
          werkzeug: ClaudeCode(const {}),
          gewaehlt: true,
          verbindung: Verbindung.aktuell,
          skills: const [],
          stand: const {},
          entfernen: const {},
        ),
      ],
      skills: const [],
      python: true,
    );

class _Aufbau {
  _Aufbau(this.einstellungen, this.protokoll, this.instanzen);
  final _EinstellungenOhneDatei einstellungen;
  final Protokoll protokoll;
  final List<Instanz> instanzen;
}

void main() {
  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    // ignore: invalid_use_of_visible_for_testing_member
    FlutterSecureStorage.setMockInitialValues({});
    // ignore: invalid_use_of_visible_for_testing_member
    PackageInfo.setMockInitialValues(
        appName: 'moocp', packageName: 'moocp', version: '0.9.4', buildNumber: '1', buildSignature: '');
  });

  /// Startet die App wie `main`: das erste Profil ist das Hauptprofil, die
  /// übrigen kommen als `weitere`, und `instanzErstellen` gibt es immer.
  Future<_Aufbau> starten(
    WidgetTester tester,
    List<Profil> profile, {
    List<bool> ablehnen = const [],
  }) async {
    tester.view.physicalSize = const Size(2000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final einstellungen = _EinstellungenOhneDatei(profile: profile, schluessel: 'global');
    final protokoll = Protokoll();
    final instanzen = [
      for (var i = 0; i < einstellungen.profile.length; i++)
        _instanz(einstellungen, protokoll, einstellungen.profile[i], ablehnen: i < ablehnen.length && ablehnen[i]),
    ];
    await tester.pumpWidget(MoocpApp(
      einstellungen,
      protokoll,
      instanzen.first.moodle,
      instanzen.first.dienst,
      instanzen.first.freigaben,
      const Arbeitsordner('arbeitsordner'),
      weitere: instanzen.sublist(1),
      instanzErstellen: (neu) => _instanz(einstellungen, protokoll, neu),
      einrichtungsstand: _eingerichtet,
    ));
    await tester.pumpAndSettle();
    return _Aufbau(einstellungen, protokoll, instanzen);
  }

  final standard = _profil(Profil.standardKennung, 'Moodle', 'moodle', 47811);
  final test = _profil('k2', 'Moodle Test', 'moodle-test', 47812);

  group('Ein Profil: die App sieht aus wie vor den Profilen', () {
    testWidgets('keine Profilkarte, kein Profilname in der Titelzeile, keine Auswahl', (tester) async {
      await starten(tester, [standard]);

      expect(find.text('moocp'), findsOneWidget, reason: 'die Titelzeile heißt nur moocp');
      expect(find.textContaining('Moodle-Profil'), findsNothing);
      expect(find.text('Profil hinzufügen'), findsNothing);
      expect(find.text('Profil bearbeiten'), findsNothing);
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      expect(find.textContaining('(moodle)'), findsNothing);
      expect(find.text('MCP startet nach der Anmeldung'), findsOneWidget);
      expect(find.text('Moodle-Anmeldung'), findsOneWidget);
    });

    testWidgets('die Hilfe zu den Stufen nennt kein Profil', (tester) async {
      await starten(tester, [standard]);
      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();
      expect(find.text('Bestätigungen vor Änderungen'), findsOneWidget);
    });

    testWidgets('Einstellungen und KI-Werkzeuge einrichten nennen kein Profil', (tester) async {
      await starten(tester, [standard]);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Einstellungen'), findsOneWidget);
      expect(find.byKey(const Key('delete-profile')), findsNothing, reason: 'eines bleibt immer');

      await tester.tap(find.text('Verbindung und Skills prüfen'));
      await tester.pumpAndSettle();
      expect(find.text('KI-Werkzeuge einrichten'), findsOneWidget);
      expect(find.textContaining('(moodle)'), findsNothing);
    });

    testWidgets('die Einstellungen bieten unten eine weitere Instanz an; sie führt zum Profil-Dialog', (tester) async {
      final a = await starten(tester, [standard]);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Weitere Moodle-Instanz verbinden …'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Moodle-Profil hinzufügen'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('profile-name')), 'Moodle Test');
      await tester.enterText(find.byKey(const Key('profile-address')), 'https://test.schule.example');
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();

      // Das neue Profil richtet die KI-Werkzeuge mit seinem Namen ein; erst jetzt steht er im Titel.
      expect(find.textContaining('Moodle Test (moodle-test)'), findsWidgets);
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();

      expect(find.text('Moodle-Profil'), findsOneWidget, reason: 'ab zwei Profilen die Auswahl');
      expect(find.text('moocp — Moodle Test (moodle-test)'), findsOneWidget);
      expect(a.einstellungen.profile, hasLength(2));
      final neu = a.einstellungen.profile.last;
      expect(neu.schluessel, hasLength(64), reason: 'jedes neue Profil bekommt einen eigenen Schlüssel');
      expect(neu.schluessel, isNot(a.einstellungen.schluessel));
      expect(a.einstellungen.gespeichert, greaterThan(0));
    });
  });

  group('Ab zwei Profilen erscheinen Auswahl und Namen', () {
    testWidgets('Karte „Moodle-Profil", Profilname in der Titelzeile, Löschen in den Einstellungen', (tester) async {
      await starten(tester, [standard, test]);

      expect(find.text('Moodle-Profil'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
      expect(find.text('Profil bearbeiten'), findsOneWidget);
      expect(find.text('moocp — Moodle (moodle)'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Einstellungen — Moodle (moodle)'), findsOneWidget);
      expect(find.byKey(const Key('delete-profile')), findsNothing,
          reason: 'das Standardprofil bleibt: Brücke und Eintrag „moodle" hängen daran');
    });

    testWidgets('die Auswahl wechselt den Titel', (tester) async {
      await starten(tester, [standard, test]);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moodle Test (moodle-test)').last);
      await tester.pumpAndSettle();
      expect(find.text('moocp — Moodle Test (moodle-test)'), findsOneWidget);
    });

    testWidgets('ein weiteres Profil lässt sich löschen', (tester) async {
      await starten(tester, [standard, test]);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moodle Test (moodle-test)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delete-profile')), findsOneWidget);
    });
  });

  group('Stufe „keine" bleibt sichtbar (E20)', () {
    final testOhneRueckfrage = _profil('k2', 'Moodle Test', 'moodle-test', 47812, stufe: Bestaetigungen.keine);

    testWidgets('beim Start steht jedes Profil mit „keine" im Protokoll, auch das nicht angezeigte', (tester) async {
      final a = await starten(tester, [standard, testOhneRueckfrage]);
      final texte = a.protokoll.eintraege.map((e) => e.text).toList();
      expect(texte.where((t) => t.contains('[Moodle Test] Bestätigungen: keine')), hasLength(1));
      expect(texte.where((t) => t.contains('[Moodle] Bestätigungen')), isEmpty, reason: 'mittel: kein Eintrag');
    });

    testWidgets('mit zwei Profilen auf „keine" stehen beide im Protokoll', (tester) async {
      final beide = _profil(Profil.standardKennung, 'Moodle', 'moodle', 47811, stufe: Bestaetigungen.keine);
      final a = await starten(tester, [beide, testOhneRueckfrage]);
      final texte = a.protokoll.eintraege.map((e) => e.text).toList();
      expect(texte.where((t) => t.contains('Bestätigungen: keine')), hasLength(2));
    });

    testWidgets('die Auswahl zeigt das Profil mit „keine" rot, während ein anderes aktiv ist', (tester) async {
      await starten(tester, [standard, testOhneRueckfrage]);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();

      final eintrag = find.text('Moodle Test (moodle-test) – Bestätigungen: keine');
      expect(eintrag, findsWidgets);
      final farbe = Theme.of(tester.element(eintrag.last)).colorScheme.error;
      expect(tester.widget<Text>(eintrag.last).style?.color, farbe);
      // Das aktive Profil steht auf „mittel" und ist nicht rot.
      final normal = find.text('Moodle (moodle)');
      expect(tester.widget<Text>(normal.first).style?.color, isNull);
    });

    testWidgets('die Stufe eines weiteren Profils überschreibt das alte globale Feld nicht, die des Standardprofils schon',
        (tester) async {
      final a = await starten(tester, [standard, test]);
      expect(a.einstellungen.bestaetigungen, Bestaetigungen.mittel);

      // Weiteres Profil wählen und auf „keine" stellen.
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moodle Test (moodle-test)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<Bestaetigungen>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('keine').last);
      await tester.pumpAndSettle();

      expect(a.einstellungen.profile[1].bestaetigungen, Bestaetigungen.keine);
      expect(a.einstellungen.bestaetigungen, Bestaetigungen.mittel,
          reason: 'ein älterer Stand läse sonst die Stufe des Testprofils als die der Instanz');

      // Das Standardprofil dagegen führt das alte Feld weiter.
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moodle (moodle)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<Bestaetigungen>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('alle').last);
      await tester.pumpAndSettle();

      expect(a.einstellungen.profile[0].bestaetigungen, Bestaetigungen.alle);
      expect(a.einstellungen.bestaetigungen, Bestaetigungen.alle);
    });
  });

  group('Ein abgelehntes gespeichertes Passwort erzeugt genau einen Fehlversuch (E7)', () {
    const sicher = FlutterSecureStorage();

    void gespeichert(String kennung, {String passwort = 'altes-passwort'}) {
      final suffix = kennung == Profil.standardKennung ? '' : '.$kennung';
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({
        'anmeldung.merken$suffix': true,
        'anmeldung.benutzer$suffix': 'e.mustermann',
      });
      // ignore: invalid_use_of_visible_for_testing_member
      FlutterSecureStorage.setMockInitialValues({'moodle.passwort$suffix': passwort});
    }

    testWidgets('der Start versucht es einmal, verwirft das Passwort, und Profilwechsel melden nicht wieder an', (tester) async {
      gespeichert(Profil.standardKennung);
      final a = await starten(tester, [standard, test], ablehnen: [true, false]);

      expect((a.instanzen[0].moodle as _Zugang).versuche, 1, reason: 'der Start meldet mit dem gespeicherten Passwort an');
      expect(await sicher.read(key: 'moodle.passwort'), isNull, reason: 'abgelehnt: verworfen');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('anmeldung.merken'), isTrue, reason: 'Haken und Benutzername bleiben');
      expect(prefs.getString('anmeldung.benutzer'), 'e.mustermann');
      final texte = a.protokoll.eintraege.map((e) => e.text).join('\n');
      expect(texte, contains('Gespeichertes Passwort verworfen'));
      expect(texte, isNot(contains('altes-passwort')));

      // Wechsel zum anderen Profil und zurück: kein zweiter Fehlversuch.
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moodle Test (moodle-test)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moodle (moodle)').last);
      await tester.pumpAndSettle();
      expect((a.instanzen[0].moodle as _Zugang).versuche, 1, reason: 'ohne neues Passwort meldet der Wechsel nicht an');
    });

    testWidgets('ein Profilwechsel meldet mit dem gespeicherten Passwort an und verwirft es, wenn Moodle es ablehnt', (tester) async {
      gespeichert('k2', passwort: 'veraltet');
      final a = await starten(tester, [standard, test], ablehnen: [false, true]);
      expect((a.instanzen[1].moodle as _Zugang).versuche, 0, reason: 'der Start betrifft nur das sichtbare Profil');

      Future<void> wechseln(String eintrag) async {
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(eintrag).last);
        await tester.pumpAndSettle();
      }

      await wechseln('Moodle Test (moodle-test)');
      expect((a.instanzen[1].moodle as _Zugang).versuche, 1);
      expect(await sicher.read(key: 'moodle.passwort.k2'), isNull);

      await wechseln('Moodle (moodle)');
      await wechseln('Moodle Test (moodle-test)');
      expect((a.instanzen[1].moodle as _Zugang).versuche, 1, reason: 'jeder weitere Wechsel wäre ein weiterer Fehlversuch');
    });
  });

  group('Der Dialog „KI-Werkzeuge einrichten" schreibt den Schlüssel des Profils', () {
    late Directory heim;
    setUp(() => heim = Directory.systemTemp.createTempSync('moocp_einrichtung_'));
    tearDown(() => heim.deleteSync(recursive: true));

    testWidgets('ein Eintrag mit dem Schlüssel eines anderen Profils ist veraltet, „Installieren" erneuert ihn', (tester) async {
      // USERPROFILE gilt unter Windows, HOME auf dem Mac.
      final env = {'USERPROFILE': heim.path, 'HOME': heim.path};
      final codex = CodexCli(env);
      // Ein Eintrag aus der Zeit, als alle Profile den globalen Schlüssel teilten.
      expect(await codex.eintragen(47812, 'global', name: 'moodle-test'), isNull);

      Future<Einrichtungsstand> pruefen() => einrichtungPruefen(
            umgebung: env,
            port: 47812,
            schluessel: 'eigener',
            name: 'moodle-test',
            skills: const [],
            gefunden: [codex],
            python: () async => true,
          );
      final stand = await pruefen();
      expect(stand.werkzeuge.single.verbindung, Verbindung.veraltet);

      await tester.pumpWidget(MaterialApp(
        home: EinrichtungDialog(
          stand: stand,
          pruefen: pruefen,
          einstellungen: Einstellungen(schluessel: 'global'),
          protokoll: Protokoll(),
          port: 47812,
          schluessel: 'eigener',
          servername: 'moodle-test',
          profilname: 'Moodle Test',
        ),
      ));
      expect(find.text('Moodle Test (moodle-test) — KI-Werkzeuge einrichten'), findsOneWidget);
      await tester.tap(find.text('Installieren'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();

      final toml = File(p.join(heim.path, '.codex', 'config.toml')).readAsStringSync();
      expect(toml, contains('[mcp_servers.moodle-test]'));
      expect(toml, contains('Bearer eigener'));
      expect(toml, isNot(contains('Bearer global')));
      expect((await pruefen()).werkzeuge.single.verbindung, Verbindung.aktuell);
    });
  });

  group('Freigabedialog', () {
    testWidgets('nennt das Profil nur, wenn es mehrere gibt', (tester) async {
      final f = Freigaben(Protokoll());
      unawaited(f.anfragen(FreigabeAnfrage(titel: 'Änderung speichern?', punkte: const [], vergleich: const [])));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: FreigabeDialog(f.aktuell!, f))));
      expect(find.text('Änderung speichern?'), findsOneWidget);
      expect(find.textContaining('(moodle'), findsNothing);

      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: FreigabeDialog(f.aktuell!, f, profilname: 'Moodle Test', mcpName: 'moodle-test'))));
      expect(find.text('Moodle Test (moodle-test)'), findsOneWidget);

      // Die Frist läuft sonst weiter und hielte den Test an.
      f.entscheiden(false);
      await tester.pumpAndSettle();
    });
  });
}
