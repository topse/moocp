// Freigaben: Die App fragt die Lehrkraft, bevor sie Bestehendes ändert.
//
// Ein Werkzeug stellt eine Anfrage und wartet. Die Oberfläche zeigt sie als
// Dialog mit der Änderungsübersicht; die Lehrkraft entscheidet per Klick.
// Ohne Antwort innerhalb der Frist gilt die Anfrage als abgelehnt -- im
// Zweifel wird nichts geschrieben.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'moodle/zeilenvergleich.dart';
import 'protokoll.dart';

class FreigabeAnfrage {
  FreigabeAnfrage({
    required this.titel,
    required this.punkte,
    required this.vergleich,
    this.knopf = 'Speichern',
    this.ablehnen = 'Abbrechen',
    this.ohneEntscheidung = 'wird nichts gespeichert',
    this.bilder = const [],
    this.grund,
  });

  final String titel;

  /// Wozu Claude das braucht, in Claudes eigenen Worten -- steht oben im
  /// Dialog (Bildschirmfotos).
  final String? grund;

  /// Beschriftung des Knopfs, der freigibt: „Speichern", „Löschen" …
  final String knopf;

  /// Beschriftung des Knopfs, der ablehnt.
  final String ablehnen;

  /// Was ohne Entscheidung geschieht, als Satzende: „Ohne Entscheidung
  /// innerhalb von 30 Minuten …".
  final String ohneEntscheidung;

  /// Kurze Zeilen: was, wo, welche Dateien.
  final List<String> punkte;

  /// Zeilenvergleich des Quelltexts, vorher gegen nachher; leer, wenn es
  /// keinen Text zu vergleichen gibt (Sichtbarkeit, Löschen).
  final List<Zeile> vergleich;

  /// Bilder (PNG), die nach der Freigabe weitergehen -- die Lehrkraft sieht
  /// genau sie (Bildschirmfotos).
  final List<Uint8List> bilder;

  final Completer<bool> _antwort = Completer<bool>();
  bool get offen => !_antwort.isCompleted;
}

class Freigaben extends ChangeNotifier {
  Freigaben(this.protokoll, {this.frist = const Duration(minutes: 30)});

  final Protokoll protokoll;
  final Duration frist;

  FreigabeAnfrage? _aktuell;
  FreigabeAnfrage? get aktuell => _aktuell;

  /// Stellt eine Anfrage und wartet auf die Entscheidung, höchstens [frist].
  /// Es gibt immer nur eine offene Anfrage; eine zweite wartet, bis die erste
  /// entschieden ist.
  Future<bool> anfragen(FreigabeAnfrage a) async {
    while (_aktuell != null) {
      await _aktuell!._antwort.future;
    }
    _aktuell = a;
    protokoll.eintrag(Art.info, 'Freigabe angefragt: ${a.titel} (Frist ${_dauer(frist)})');
    notifyListeners();
    // Die Frist hängt an einem eigenen Timer, nicht am Warten auf die Antwort:
    // So läuft sie sicher ab, auch wenn niemand den Dialog sieht.
    final uhr = Timer(frist, () {
      if (a.offen) {
        protokoll.eintrag(Art.info, 'Frist abgelaufen -- nicht gespeichert');
        a._antwort.complete(false);
      }
    });
    try {
      return await a._antwort.future;
    } finally {
      uhr.cancel();
      _aktuell = null;
      notifyListeners();
    }
  }

  void entscheiden(bool speichern) {
    final a = _aktuell;
    if (a != null && a.offen) {
      protokoll.eintrag(speichern ? Art.schreiben : Art.info,
          'Freigabe ${speichern ? "erteilt" : "abgelehnt"}');
      a._antwort.complete(speichern);
    }
  }

  static String _dauer(Duration d) =>
      d.inMinutes >= 1 ? '${d.inMinutes} min' : '${d.inSeconds} s';
}
