// Der Arbeitsordner: Hierhin schreibt die App, was sie aus Moodle liest, und
// von hier nimmt sie, was sie nach Moodle schreibt (imArbeitsordner in
// moodle/formular_schreiben.dart). Claude erfährt den Pfad über `status`.
//
// Er lebt so lange wie die App: beim Start geleert -- das fängt auch einen
// Absturz ab, nach dem das Leeren beim Beenden ausblieb -- und beim Beenden.
// So bleibt nichts aus Moodle auf dem Rechner liegen; alles darin lässt sich
// neu lesen oder steht in Claudes Verlauf.
//
// Ein fester Ort statt eines neuen je Start: Eine Claude-Sitzung kann einen
// Neustart der App überdauern und kennt den Pfad noch von `status`. Bei einem
// neuen Namen lehnte jedes Werkzeug den alten Pfad als „außerhalb des
// Arbeitsordners" ab, und das liest sich wie die Datensperre. So fehlt nach
// einem Neustart schlicht die Datei. Weil der Ort fest ist, läuft die App nur
// einmal (windows/runner/main.cpp).

import 'dart:io';

import 'package:path/path.dart' as p;

class Arbeitsordner {
  const Arbeitsordner(this.pfad);

  final String pfad;

  /// Legt den Ordner an und leert ihn. Liefert ihn mit der Zahl der Einträge,
  /// die sich nicht löschen ließen.
  ///
  /// Der Pfad in langer Form: %TEMP% steht auf manchen Rechnern mit Kurznamen
  /// (C:\Users\LEHRKR~1\…). `status` soll die Form nennen, die Windows selbst
  /// anzeigt und Claude weiterverwendet.
  static (Arbeitsordner, int) einrichten() {
    final d = Directory(p.join(Directory.systemTemp.path, 'moocp_arbeitsordner'))
      ..createSync(recursive: true);
    final a = Arbeitsordner(d.resolveSymbolicLinksSync());
    return (a, a.leeren());
  }

  /// Löscht alles im Ordner, Eintrag für Eintrag: Was gerade in Benutzung ist
  /// (etwa ein Unterordner, in dem eine Konsole steht), bleibt stehen, der
  /// Rest geht trotzdem. Verknüpfungen und Junctions löscht Dart als solche,
  /// ohne ihrem Ziel zu folgen, auch in Unterordnern -- gemessen. Liefert die
  /// Zahl der Einträge, die stehen blieben.
  int leeren() {
    final d = Directory(pfad);
    if (!d.existsSync()) return 0;
    var geblieben = 0;
    for (final e in d.listSync(followLinks: false)) {
      try {
        e.deleteSync(recursive: e is Directory);
      } on FileSystemException {
        geblieben++;
      }
    }
    return geblieben;
  }
}
