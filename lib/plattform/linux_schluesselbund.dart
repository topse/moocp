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

  /// Nicht festzustellen (kein `gdbus`): Die App fragt dann einfach, wie es
  /// ohne diese Prüfung auch wäre.
  unbekannt,
}

/// Fragt den Secret Service, ohne ein Geheimnis zu berühren, ob der
/// Standard-Schlüsselbund benutzbar ist.
///
/// Der Grund: libsecret (flutter_secure_storage) wartet bei einem gesperrten
/// oder fehlenden Bund auf einen Dialog und blockiert dabei den Hauptfaden der
/// App, also auch ihre Oberfläche. Sitzt niemand davor (xrdp-Sitzung ohne
/// entsperrten Bund, Autostart), stünde die App für immer. Eine Frist auf der
/// Dart-Seite hilft dagegen nicht, der blockierte Aufruf bleibt. Darum wird
/// vorher gefragt, und zwar über `gdbus` (Paket `libglib2.0-bin`, auf jedem
/// GTK-System vorhanden): Der Aufruf liest nur die Eigenschaft `Locked` des
/// Standard-Bunds und ist als eigener Prozess abbrechbar.
Future<Schluesselbund> schluesselbundPruefen() async {
  final Process p;
  try {
    p = await Process.start('gdbus', const [
      'call',
      '--session',
      '--dest',
      'org.freedesktop.secrets',
      '--object-path',
      '/org/freedesktop/secrets/aliases/default',
      '--method',
      'org.freedesktop.DBus.Properties.Get',
      'org.freedesktop.Secret.Collection',
      'Locked',
    ]);
  } on ProcessException {
    return Schluesselbund.unbekannt;
  }
  try {
    final aus = p.stdout.transform(utf8.decoder).join();
    p.stderr.drain<void>();
    final code = await p.exitCode.timeout(const Duration(seconds: 5));
    if (code != 0) return Schluesselbund.fehlt;
    final text = await aus;
    if (text.contains('<true>')) return Schluesselbund.gesperrt;
    if (text.contains('<false>')) return Schluesselbund.bereit;
    return Schluesselbund.unbekannt;
  } on TimeoutException {
    p.kill();
    // Der Secret Service antwortet nicht: wie gesperrt behandeln, nicht warten.
    return Schluesselbund.gesperrt;
  }
}
