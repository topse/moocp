// Der Text vor dem ersten Schreibschritt einer Übertragung: Quelle, Ziele,
// Inhalt und Wiederherstellungsweg. Die Freigabe zeigt ihn der Lehrkraft.
//
// Diese Datei kennt weder Moodle noch das Netz. Sie ist reine Logik, damit
// sie offline testbar ist (test/uebertragung_zusammenfassung_test.dart). Die
// Namen der Kurse liest die Aufruferseite aus Moodle und übergibt sie an
// [uebertragungsZusammenfassung]; hier wird nichts gelesen.
//
// Welcher Kurs Quelle und welche Kurse Ziel sind, nennt die Lehrkraft im Chat,
// und die KI nennt es im Plan (A5); die App speichert dazu nichts.

import 'profil.dart';

/// Ein Kurs in einer Instanz: das Profil und die Kursnummer, also die Zahl
/// hinter course/view.php?id=. Gleichheit über Kennung und Kursnummer.
class Endpunkt {
  const Endpunkt(this.profil, this.kurs);

  final Profil profil;
  final int kurs;

  @override
  bool operator ==(Object other) =>
      other is Endpunkt && other.profil.kennung == profil.kennung && other.kurs == kurs;

  @override
  int get hashCode => Object.hash(profil.kennung, kurs);
}

/// Aus [quelle] wird in jeden der [ziele] kopiert.
class Plan {
  const Plan({required this.quelle, required this.ziele});

  final Endpunkt quelle;
  final List<Endpunkt> ziele;
}

/// Der Text vor dem ersten Schreibschritt. Nennt die Quellinstanz, den
/// Quellkurs, die Inhaltsauswahl, alle Zielkurse mit Instanz und den
/// Wiederherstellungsweg.
///
/// [kursnamen] muss jeden Endpunkt des [plan] enthalten; der Name kommt aus
/// Moodle, und die Aufruferseite liest ihn dort. Fehlt einer, bricht die
/// Funktion ab, statt eine Zusammenfassung mit einer Lücke zu liefern: Ein
/// falsches „ok" ist schlimmer als ein Fehler (A3).
///
/// [inhalt] und [wiederherstellung] sind Angaben des Auftrags. Die Funktion
/// prüft sie nicht; leere Angaben bricht sie ab.
String uebertragungsZusammenfassung(
  Plan plan, {
  required Map<Endpunkt, String> kursnamen,
  required String inhalt,
  required String wiederherstellung,
}) {
  if (inhalt.trim().isEmpty) {
    throw ArgumentError.value(inhalt, 'inhalt', 'Die Inhaltsauswahl fehlt.');
  }
  if (wiederherstellung.trim().isEmpty) {
    throw ArgumentError.value(wiederherstellung, 'wiederherstellung', 'Der Wiederherstellungsweg fehlt.');
  }
  String name(Endpunkt e) {
    final n = kursnamen[e];
    if (n == null || n.trim().isEmpty) {
      throw StateError('Kein Kursname für Kurs ${e.kurs} in „${e.profil.name}" übergeben.');
    }
    return n;
  }

  String instanz(Profil p) {
    final host = Uri.tryParse(p.adresse)?.host ?? '';
    return host.isEmpty ? '„${p.name}"' : '„${p.name}" ($host)';
  }

  final q = plan.quelle;
  final zeilen = <String>[
    'Quellinstanz: ${instanz(q.profil)}',
    'Quellkurs: „${name(q)}" (Kurs ${q.kurs})',
    'Inhaltsauswahl: $inhalt',
    'Zielkurse (${plan.ziele.length}):',
    for (final z in plan.ziele) '  - „${name(z)}" (Kurs ${z.kurs}) in ${instanz(z.profil)}',
    'Wiederherstellung: $wiederherstellung',
  ];
  return zeilen.join('\n');
}
