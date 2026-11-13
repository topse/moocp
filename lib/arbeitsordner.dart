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
// einmal (windows/runner/main.cpp, lib/einzelstart.dart).

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
  ///
  /// Unter Linux teilen sich alle Benutzer /tmp: Der Name trägt den Benutzer
  /// ([ordnername]), der Ordner gehört nur ihm (Rechte 700), und eine
  /// Verknüpfung an seiner Stelle, die ein anderer Benutzer dort hinterlassen
  /// hat, wird nicht benutzt. Sonst läse jeder auf dem Rechner mit, was die
  /// App aus Moodle holt.
  static (Arbeitsordner, int) einrichten({String? temp, bool? linux, Map<String, String>? umgebung}) {
    final istLinux = linux ?? Platform.isLinux;
    final pfad = p.join(
      temp ?? Directory.systemTemp.path,
      ordnername(umgebung ?? Platform.environment, linux: istLinux),
    );
    if (istLinux && FileSystemEntity.typeSync(pfad, followLinks: false) == FileSystemEntityType.link) {
      throw StateError('Der Arbeitsordner ist eine Verknüpfung und wird nicht benutzt.');
    }
    final d = Directory(pfad)..createSync(recursive: true);
    if (istLinux) Process.runSync('chmod', ['700', d.path]);
    final a = Arbeitsordner(d.resolveSymbolicLinksSync());
    return (a, a.leeren());
  }

  /// `moocp_arbeitsordner`, unter Linux mit dem Benutzer dahinter. Zeichen
  /// außerhalb von Buchstaben, Ziffern, Punkt, Strich und Unterstrich fallen
  /// weg: Der Name kommt aus der Umgebung und wird Teil eines Pfads.
  static String ordnername(Map<String, String> umgebung, {required bool linux}) {
    if (!linux) return 'moocp_arbeitsordner';
    final roh = umgebung['USER'] ?? umgebung['LOGNAME'] ?? '';
    final benutzer = roh.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
    return benutzer.isEmpty ? 'moocp_arbeitsordner_benutzer' : 'moocp_arbeitsordner_$benutzer';
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
