// Hilfe für Tests: Eine Datei im Sicherungsordner als Sicherung ausgeben, die moocp selbst
// heruntergeladen und geprüft hat. Ohne so einen Vorgang gilt eine .mbz als fremd, und die
// Wiederherstellung fragt auf jeder Stufe zurück (ADR 0029, Punkt 5).
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:moocp/moodle/sicherung.dart';
import 'package:moocp/moodle/sicherung_regeln.dart';
import 'package:path/path.dart' as p;

/// Trägt [datei] (relativ zu [ordner]) mit ihrer jetzigen Prüfsumme als fertigen, geprüften
/// Sicherungsvorgang in vorgaenge.json ein. Der Vorgang hat keine Profilbindung; Tests, die
/// `Vorgaenge(ordner, profilKennung: …)` benutzen, sehen ihn deshalb nicht.
/// Synchron, damit es in den Hilfen stehen kann, die das Archiv schreiben.
void alsEigeneSicherung(Directory ordner, String datei) {
  final liste = File(p.join(ordner.path, 'vorgaenge.json'));
  final alle = liste.existsSync()
      ? (jsonDecode(liste.readAsStringSync()) as List).cast<Map<String, Object?>>()
      : <Map<String, Object?>>[];
  final bytes = File(p.join(ordner.path, datei)).readAsBytesSync();
  final v = Vorgang(
    id: 'eigen-${datei.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}',
    kurs: 1,
    cmid: 1,
    datei: datei,
    stand: SicherungStand.fertig,
    begonnen: DateTime(2026, 1, 1),
    bytes: bytes.length,
    verified: true,
    pruefsumme: sha256.convert(bytes).toString(),
  );
  alle.removeWhere((x) => x['id'] == v.id);
  alle.add(v.zuJson());
  liste.writeAsStringSync(jsonEncode(alle));
}
