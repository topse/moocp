import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/freigabe.dart';
import 'package:moocp/main.dart' show FreigabeDialog, FreigabeDialoge, Sperrzeit;
import 'package:moocp/protokoll.dart';

FreigabeAnfrage _anfrage(String titel) =>
    FreigabeAnfrage(titel: titel, punkte: const [], vergleich: const []);

Widget _fenster(Freigaben freigaben) => MaterialApp(
  home: FreigabeDialoge(
    freigaben: freigaben,
    nachVorn: (_) async {},
    child: const Scaffold(body: Text('Hauptfenster')),
  ),
);

void main() {
  for (final ja in [true, false]) {
    testWidgets(
      'fachliche Kandidatenentscheidung bei keine: ${ja ? 'bestätigen' : 'ablehnen'}',
      (tester) async {
        final freigaben = Freigaben(Protokoll(), stufe: Bestaetigungen.keine);
        await tester.pumpWidget(_fenster(freigaben));
        final antwort = freigaben.anfragen(
          FreigabeAnfrage(
            titel: 'Lernlandkarte ändern?',
            punkte: const [
              'Ort p1: ZZ Quelle → ZZ Vertiefung (cmid 72)',
              'Begründung der KI (Vorschlag): Gleicher Lerngegenstand.',
            ],
            vergleich: const [],
            ab: Bestaetigungen.keine,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('ZZ Vertiefung'), findsOneWidget);
        expect(find.textContaining('Gleicher Lerngegenstand'), findsOneWidget);
        await tester.pump(Sperrzeit.dauerVorgabe);
        await tester.tap(find.text(ja ? 'Speichern' : 'Abbrechen'));
        await tester.pumpAndSettle();
        expect(await antwort, ja);
        expect(freigaben.ausgelassen, 0);
      },
    );
  }

  testWidgets('Bild außerhalb des erneut geprüften Testumfangs braucht persönliche Freigabe', (tester) async {
    final freigaben = Freigaben(Protokoll(), stufe: Bestaetigungen.keine);
    await tester.pumpWidget(_fenster(freigaben));
    final anfrage = FreigabeAnfrage(titel: 'ZZ Bild?', punkte: const [], vergleich: const [],
      ab: Bestaetigungen.keine,
      bilder: [base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=')]);
    final antwort = freigaben.imTest(() => freigaben.anfragen(anfrage), pruefen: () async => false);
    await tester.pumpAndSettle();
    expect(find.text('ZZ Bild?'), findsOneWidget);
    await tester.pump(Sperrzeit.dauerVorgabe);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(await antwort, isFalse);
    expect(freigaben.testfreigaben, 0);
  });

  for (final fall in ['Zustimmung', 'Ablehnung', 'Fristablauf', 'Abbruch']) {
    testWidgets('realer Dialog: $fall beendet die Anfrage korrekt', (
      tester,
    ) async {
      final freigaben = Freigaben(
        Protokoll(),
        frist: const Duration(seconds: 3),
      );
      await tester.pumpWidget(_fenster(freigaben));
      final abbruch = Completer<void>();
      final antwort = Freigaben.mitAbbruch(
        abbruch.future,
        () => freigaben.anfragen(_anfrage('ZZ Änderung?')),
      );
      await tester.pumpAndSettle();
      expect(find.text('ZZ Änderung?'), findsOneWidget);
      switch (fall) {
        case 'Zustimmung':
          await tester.pump(Sperrzeit.dauerVorgabe);
          await tester.tap(find.text('Speichern'));
        case 'Ablehnung':
          await tester.pump(Sperrzeit.dauerVorgabe);
          await tester.tap(find.text('Abbrechen'));
        case 'Fristablauf':
          await tester.pump(const Duration(seconds: 3));
        case 'Abbruch':
          abbruch.complete();
      }
      await tester.pumpAndSettle();
      expect(await antwort, fall == 'Zustimmung');
      expect(find.text('ZZ Änderung?'), findsNothing);
      expect(freigaben.aktuell, isNull);
      expect(freigaben.testfreigaben, 0);
    });
  }

  testWidgets(
    'wechselt den Listener bei Profilwechsel auch mit offenem Dialog',
    (tester) async {
      final alt = Freigaben(Protokoll());
      final neu = Freigaben(Protokoll());
      await tester.pumpWidget(_fenster(alt));
      alt.anfragen(_anfrage('Altes Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Altes Profil'), findsOneWidget);

      await tester.pumpWidget(_fenster(neu));
      await tester.pumpAndSettle();
      expect(find.text('Altes Profil'), findsNothing);
      alt.entscheiden(false);
      neu.anfragen(_anfrage('Neues Profil'));
      await tester.pumpAndSettle();

      expect(find.text('Neues Profil'), findsOneWidget);
      neu.entscheiden(false);
    },
  );

  group('Freigabe vor dem Löschen eines Kurses: Liste mit Links, Hervorhebung, Bestätigung', () {
    const knopf = 'Löschen und wiederherstellen';
    const bestaetigung =
        'Ich habe die Liste geprüft. Alle Inhalte des Kurses „ZZ Kurs" werden gelöscht, '
        'auch Abgaben, Beiträge und Bewertungen der Lernenden.';
    final forum = Uri.parse('https://moodle.schule.example/mod/forum/view.php?id=6');
    final seite = Uri.parse('https://moodle.schule.example/mod/page/view.php?id=5');

    FreigabeAnfrage loeschen({List<String> abhaken = const [bestaetigung]}) => FreigabeAnfrage(
      titel: 'Vorhandene Inhalte löschen und wiederherstellen?',
      punkte: const ['Profil: Test', 'Kurs 12 „ZZ Kurs" (bestehender Kurs)'],
      vergleich: const [],
      knopf: knopf,
      abhaken: abhaken,
      links: [
        FreigabeLinkGruppe(
          'Zuerst ansehen (1): kann Daten von Lernenden enthalten oder wird von moocp nicht unterstützt',
          [FreigabeLink('„ZZ Forum" (Forum)', forum, warnung: 'kann Daten von Lernenden enthalten')],
          warnung: true,
        ),
        FreigabeLinkGruppe('Weitere Aktivitäten, die gelöscht werden (1)', [FreigabeLink('„ZZ Seite" (Textseite)', seite)]),
      ],
      ab: Bestaetigungen.keine,
    );

    testWidgets('der Knopf geht erst nach dem Haken; Links öffnen im Browser und ersetzen den Haken nicht', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = Freigaben(Protokoll(), stufe: Bestaetigungen.keine);
      final antwort = f.anfragen(loeschen());
      expect(f.aktuell, isNotNull, reason: 'Löschen fragt auch bei „keine"');
      final geoeffnet = <Uri>[];
      for (final skala in [1.0, 1.25]) {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(skala)),
              child: Scaffold(body: FreigabeDialog(f.aktuell!, f, browser: (u) async => geoeffnet.add(u))),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'kein Überlauf bei ${(skala * 100).round()} %');
      }
      await tester.pump(Sperrzeit.dauerVorgabe);
      bool frei() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, knopf)).onPressed != null;

      // Keine Übergabe: kein orangenes Band, keine nummerierten Schritte.
      expect(find.textContaining('Jetzt sind Sie dran'), findsNothing);
      expect(find.text(bestaetigung), findsOneWidget);
      expect(frei(), isFalse, reason: 'noch nichts bestätigt');

      // Die Warngruppe steht oben, mit Warnzeichen; die übrigen darunter.
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      final warnung = tester.getTopLeft(find.textContaining('Zuerst ansehen')).dy;
      final rest = tester.getTopLeft(find.textContaining('Weitere Aktivitäten')).dy;
      expect(warnung, lessThan(rest));
      expect(find.textContaining('kann Daten von Lernenden enthalten', findRichText: true), findsWidgets);

      // Ein Link öffnet die Aktivität im Browser; das ersetzt die Bestätigung nicht.
      await tester.tap(find.textContaining('„ZZ Forum" (Forum)', findRichText: true));
      await tester.tap(find.textContaining('„ZZ Seite" (Textseite)', findRichText: true));
      expect(geoeffnet, [forum, seite]);
      expect(frei(), isFalse);

      // Haken setzen, zurücknehmen, wieder setzen.
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(frei(), isTrue);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(frei(), isFalse, reason: 'ein zurückgenommener Haken sperrt den Knopf wieder');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(frei(), isTrue);
      f.entscheiden(true);
      expect(await antwort, isTrue);
    });

    testWidgets('im echten Dialog der App: Knopf gesperrt, dann Haken, dann Klick gibt frei', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final freigaben = Freigaben(Protokoll(), stufe: Bestaetigungen.keine);
      await tester.pumpWidget(_fenster(freigaben));
      final antwort = freigaben.anfragen(loeschen());
      await tester.pumpAndSettle();
      expect(find.text('Vorhandene Inhalte löschen und wiederherstellen?'), findsOneWidget);
      await tester.pump(Sperrzeit.dauerVorgabe);
      // Gesperrt: ein Klick tut nichts.
      await tester.tap(find.text(knopf));
      await tester.pumpAndSettle();
      expect(freigaben.aktuell, isNotNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text(knopf));
      await tester.pumpAndSettle();
      expect(await antwort, isTrue);
      expect(freigaben.aktuell, isNull);
    });

    testWidgets('Ablehnen geht ohne Haken', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final freigaben = Freigaben(Protokoll(), stufe: Bestaetigungen.keine);
      await tester.pumpWidget(_fenster(freigaben));
      final antwort = freigaben.anfragen(loeschen());
      await tester.pumpAndSettle();
      await tester.pump(Sperrzeit.dauerVorgabe);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(await antwort, isFalse);
    });

    testWidgets('mit mehreren Aktivitäten scrollt die Liste für sich; die Bestätigung bleibt sichtbar', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = Freigaben(Protokoll(), stufe: Bestaetigungen.keine);
      final antwort = f.anfragen(FreigabeAnfrage(
        titel: 'Vorhandene Inhalte löschen und wiederherstellen?',
        punkte: const ['Profil: Test'],
        vergleich: const [],
        knopf: knopf,
        abhaken: const [bestaetigung],
        links: [
          FreigabeLinkGruppe('Weitere Aktivitäten, die gelöscht werden (80)', [
            for (var i = 1; i <= 80; i++)
              FreigabeLink('„ZZ Seite $i" (Textseite)', Uri.parse('https://moodle.schule.example/mod/page/view.php?id=$i')),
          ]),
        ],
        ab: Bestaetigungen.keine,
      ));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: FreigabeDialog(f.aktuell!, f))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(bestaetigung), findsOneWidget, reason: 'sichtbar, ohne zu scrollen');
      expect(find.text(knopf), findsOneWidget);
      f.entscheiden(false);
      expect(await antwort, isFalse);
    });

    testWidgets('ohne abhaken ist der Knopf bei Links nach der Sperrzeit frei', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = Freigaben(Protokoll());
      final antwort = f.anfragen(loeschen(abhaken: const []));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: FreigabeDialog(f.aktuell!, f))));
      await tester.pump(Sperrzeit.dauerVorgabe);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, knopf)).onPressed, isNotNull);
      f.entscheiden(true);
      expect(await antwort, isTrue);
    });
  });
}
