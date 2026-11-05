// Tests der Zusammenfassung vor dem ersten Schreibschritt einer Übertragung.
// Nur erfundene Daten (A11): Adressen mit .example, Kursnummern 12 und 34.

import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/profil.dart';
import 'package:moocp/uebertragung_zusammenfassung.dart';

Profil _p(String kennung, String name) => Profil(
      kennung: kennung,
      name: name,
      adresse: 'https://$kennung.schule-a.example',
      port: 47811,
      mcpName: kennung,
    );

void main() {
  final quelle = _p('quelle', 'Quelle');
  final ziel = _p('ziel', 'Ziel');
  final plan = Plan(quelle: Endpunkt(quelle, 12), ziele: [Endpunkt(ziel, 34)]);
  final namen = {
    Endpunkt(quelle, 12): 'Biologie Quelle',
    Endpunkt(ziel, 34): 'Biologie Ziel',
  };

  group('uebertragungsZusammenfassung', () {
    test('nennt Instanzen, Kurse, Inhalt und Wiederherstellung', () {
      final text = uebertragungsZusammenfassung(
        plan,
        kursnamen: namen,
        inhalt: 'Alle Aufgaben',
        wiederherstellung: 'Sicherung im Arbeitsordner',
      );
      expect(text, contains('Quellinstanz: „Quelle" (quelle.schule-a.example)'));
      expect(text, contains('Quellkurs: „Biologie Quelle" (Kurs 12)'));
      expect(text, contains('Inhaltsauswahl: Alle Aufgaben'));
      expect(text, contains('„Biologie Ziel" (Kurs 34) in „Ziel" (ziel.schule-a.example)'));
      expect(text, contains('Wiederherstellung: Sicherung im Arbeitsordner'));
    });

    test('mehrere Ziele stehen alle im Text, in der Reihenfolge des Plans', () {
      final dritt = _p('dritt', 'Dritt');
      final text = uebertragungsZusammenfassung(
        Plan(quelle: Endpunkt(quelle, 12), ziele: [Endpunkt(ziel, 34), Endpunkt(dritt, 56)]),
        kursnamen: {...namen, Endpunkt(dritt, 56): 'Biologie Dritt'},
        inhalt: 'Alle',
        wiederherstellung: 'Sicherung',
      );
      expect(text, contains('Zielkurse (2):'));
      expect(text.indexOf('Kurs 34'), lessThan(text.indexOf('Kurs 56')));
    });

    test('dieselbe Kursnummer in einer anderen Instanz ist ein anderer Endpunkt', () {
      expect(Endpunkt(quelle, 12), Endpunkt(quelle, 12));
      expect(Endpunkt(quelle, 12), isNot(Endpunkt(ziel, 12)));
      expect(Endpunkt(quelle, 12), isNot(Endpunkt(quelle, 34)));
    });

    test('fehlender Kursname bricht ab, statt eine Lücke zu zeigen', () {
      expect(
        () => uebertragungsZusammenfassung(
          plan,
          kursnamen: {Endpunkt(quelle, 12): 'Biologie Quelle'},
          inhalt: 'Alle',
          wiederherstellung: 'Sicherung',
        ),
        throwsStateError,
      );
    });

    test('leerer Inhalt oder Wiederherstellungsweg bricht ab', () {
      expect(
        () => uebertragungsZusammenfassung(plan, kursnamen: namen, inhalt: ' ', wiederherstellung: 'Sicherung'),
        throwsArgumentError,
      );
      expect(
        () => uebertragungsZusammenfassung(plan, kursnamen: namen, inhalt: 'Alle', wiederherstellung: ''),
        throwsArgumentError,
      );
    });
  });
}
