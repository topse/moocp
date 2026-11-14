import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Zustand des Standard-Schlüsselbunds (Secret Service, etwa GNOME Keyring
/// oder KeePassXC) der Sitzung.
enum Schluesselbund {
  /// Da und entsperrt: Lesen und Schreiben gehen ohne Rückfrage durch.
  bereit,

  /// Da, aber gesperrt: Der Zugriff öffnet einen Dialog der Sitzung.
  gesperrt,

  /// Kein Standard-Schlüsselbund angelegt, oder kein Secret Service in der
  /// Sitzung: Der Zugriff legte einen an und fragte dafür nach einem Passwort.
  fehlt,

  /// Nicht festzustellen, weil `gdbus` fehlt. Die App benutzt den Bund dann
  /// nicht: Ohne Prüfung bliebe es bei der Gefahr, dass libsecret die ganze
  /// App anhält.
  unbekannt,
}

/// Der Schlüsselbund ist nicht benutzbar. Die Meldung ist fester Text ohne
/// Inhalte (E11) und sagt der Lehrkraft, was sie tun kann.
class SchluesselbundFehler implements Exception {
  const SchluesselbundFehler(this.zustand);

  final Schluesselbund zustand;

  String get meldung => switch (zustand) {
    Schluesselbund.gesperrt =>
      'Der Schlüsselbund ist gesperrt und wurde nicht entsperrt. Entsperren Sie ihn (die Abfrage '
          'erscheint von selbst, sobald die App ihn braucht; sie braucht dafür das Paket libsecret-tools) '
          'oder geben Sie das Passwort von Hand ein.',
    Schluesselbund.fehlt =>
      'In dieser Sitzung gibt es keinen Schlüsselbund. Legen Sie einen an (etwa mit „Passwörter und '
          'Schlüssel“ bzw. Seahorse) oder geben Sie das Passwort von Hand ein.',
    Schluesselbund.unbekannt =>
      'Der Zustand des Schlüsselbunds lässt sich nicht prüfen, weil gdbus fehlt (Paket libglib2.0-bin). '
          'Die App benutzt ihn dann nicht; das Passwort bleibt ungespeichert.',
    Schluesselbund.bereit => 'Der Schlüsselbund ist bereit.',
  };

  @override
  String toString() => 'SchluesselbundFehler(${zustand.name})';
}

const _dienst = 'org.freedesktop.secrets';
const _wurzel = '/org/freedesktop/secrets';

/// Ruft `gdbus call` auf der Sitzung auf, als eigener Prozess, der sich nach
/// [frist] abbrechen lässt. Liefert Ausgabe und Exitcode, oder null, wenn
/// `gdbus` fehlt; bei Fristablauf (-1, '').
Future<(int, String)?> _gdbus(List<String> aufruf, {Duration frist = const Duration(seconds: 5)}) async {
  final Process p;
  try {
    p = await Process.start('gdbus', ['call', '--session', '--dest', _dienst, ...aufruf]);
  } on ProcessException {
    return null;
  }
  final aus = p.stdout.transform(utf8.decoder).join();
  unawaited(p.stderr.drain<void>());
  try {
    final code = await p.exitCode.timeout(frist);
    return (code, await aus);
  } on TimeoutException {
    p.kill();
    return (-1, '');
  }
}

/// Fragt den Secret Service, ohne ein Geheimnis zu berühren, ob der
/// Standard-Schlüsselbund benutzbar ist.
///
/// Der Grund: libsecret (flutter_secure_storage) wartet bei einem gesperrten
/// oder fehlenden Bund auf einen Dialog und blockiert dabei den Hauptfaden der
/// App, also auch ihre Oberfläche. Sitzt niemand davor (xrdp-Sitzung ohne
/// entsperrten Bund, Autostart), stünde die App für immer. Eine Frist auf der
/// Dart-Seite hilft dagegen nicht, der blockierte Aufruf bleibt. Darum wird
/// vorher gefragt, und zwar über `gdbus` (Paket `libglib2.0-bin`): Der Aufruf
/// liest nur die Eigenschaft `Locked` des Standard-Bunds und ist als eigener
/// Prozess abbrechbar.
Future<Schluesselbund> schluesselbundPruefen() async {
  final r = await _gdbus(const [
    '--object-path',
    '$_wurzel/aliases/default',
    '--method',
    'org.freedesktop.DBus.Properties.Get',
    'org.freedesktop.Secret.Collection',
    'Locked',
  ]);
  if (r == null) return Schluesselbund.unbekannt;
  final (code, text) = r;
  // Der Secret Service antwortet nicht: wie gesperrt behandeln, nicht warten.
  if (code == -1) return Schluesselbund.gesperrt;
  if (code != 0) return Schluesselbund.fehlt;
  if (text.contains('<true>')) return Schluesselbund.gesperrt;
  if (text.contains('<false>')) return Schluesselbund.bereit;
  return Schluesselbund.unbekannt;
}

/// Bittet den Secret Service, den gesperrten Standard-Bund zu entsperren, und
/// wartet, bis die Lehrkraft die Abfrage beantwortet hat (höchstens [frist]).
/// Liefert den Zustand danach.
///
/// Dafür läuft `secret-tool store` (Paket `libsecret-tools`) als eigener
/// Prozess und legt einen Platzhalter ohne Inhalt an, den `secret-tool clear`
/// gleich wieder entfernt: Zum Schreiben entsperrt libsecret den Bund, und die
/// Abfrage zeigt der Dienst selbst. Ein `lookup` entsperrt nur, wenn es einen
/// Treffer gibt, und ein einfacher `gdbus`-Aufruf von `Unlock` und `Prompt`
/// taugt nicht: Der Dienst schließt die Abfrage, sobald der Prozess endet, der
/// sie angefordert hat, und `gdbus call` endet sofort. Die App bleibt
/// bedienbar, weil das Warten in einem eigenen Prozess läuft. Fehlt
/// `secret-tool`, bleibt der Bund gesperrt (die Meldung sagt der Lehrkraft, dass
/// sie ihn selbst entsperren soll).
Future<Schluesselbund> schluesselbundEntsperren({Duration frist = const Duration(seconds: 90)}) async {
  final vorher = await schluesselbundPruefen();
  if (vorher != Schluesselbund.gesperrt) return vorher;
  const attribute = ['moocp', 'entsperren'];
  final Process p;
  try {
    p = await Process.start('secret-tool', const ['store', '--label=moocp entsperren', ...attribute]);
  } on ProcessException {
    return Schluesselbund.gesperrt;
  }
  unawaited(p.stdout.drain<void>());
  unawaited(p.stderr.drain<void>());
  p.stdin.write('x');
  unawaited(p.stdin.close().catchError((_) {}));
  try {
    await p.exitCode.timeout(frist);
  } on TimeoutException {
    p.kill();
  }
  final danach = await schluesselbundPruefen();
  if (danach == Schluesselbund.bereit) {
    try {
      await Process.run('secret-tool', const ['clear', ...attribute]).timeout(const Duration(seconds: 5));
    } on Exception {
      // Der Platzhalter bleibt höchstens liegen; er enthält nichts.
    }
  }
  return danach;
}
