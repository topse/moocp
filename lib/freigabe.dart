// Freigaben: Die App fragt die Lehrkraft, bevor sie in Moodle schreibt.
//
// Ein Werkzeug stellt eine Anfrage und wartet. Die Oberfläche zeigt sie als
// Dialog mit der Änderungsübersicht; die Lehrkraft entscheidet per Klick.
// Ohne Antwort innerhalb der Frist gilt die Anfrage als abgelehnt -- im
// Zweifel wird nichts geschrieben.
//
// WIE VIELE Anfragen kommen, stellt die Lehrkraft in der Titelzeile ein
// ([Bestaetigungen]). Entschieden wird das an einer Stelle: in [anfragen].
// Jede Anfrage nennt mit [FreigabeAnfrage.ab], ab welcher Stufe sie kommt;
// liegt die eingestellte Stufe darunter, gilt die Anfrage als erteilt, und
// das Protokoll hält fest, dass ohne Freigabe geschrieben wurde. So kann kein
// Aufrufer die Einstellung übersehen, und eine neue Freigabe ist von selbst
// dabei.
//
// Wartet der Client nicht mehr auf das Werkzeug (MCP: notifications/
// cancelled, etwa nach dem Zeitlimit von Bionic), verfällt die Anfrage wie
// nach der Frist: Der Dialog schließt sich, nichts wird geschrieben. Sonst
// schriebe eine späte Freigabe, während die KI den Vorgang für gescheitert
// hält. Den Abbruch erfährt [Freigaben.anfragen] aus der Zone des
// Werkzeugaufrufs ([Freigaben.mitAbbruch]) -- auch das an einer Stelle, kein
// Werkzeug muss ihn durchreichen.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'moodle/zeilenvergleich.dart';
import 'protokoll.dart';

/// Wie viele Bestätigungen die Lehrkraft vor Änderungen in Moodle will.
/// Die Reihenfolge ist die Mechanik: Gefragt wird, wenn die eingestellte
/// Stufe mindestens so hoch ist wie die der Anfrage ([FreigabeAnfrage.ab]).
enum Bestaetigungen {
  /// Keine Freigabe vor einer Änderung in Moodle; alles läuft sofort. Die
  /// Freigabe je Bildschirmfoto bleibt davon unberührt: Sie entscheidet
  /// nicht über eine Änderung, sondern darüber, welches Bild aus dem Kurs an
  /// Claude geht (E18).
  keine('keine'),

  /// Alles, was Bestehendes anfasst oder sofort für Lernende sichtbar wird:
  /// Ändern, Verschieben, Sichtbarkeit, Löschen, sichtbar Anlegen. Was die
  /// App selbst gerade verborgen angelegt hat, ist kein Bestehendes; es zu
  /// füllen fragt erst bei [alle] (fuellenAb in moodle/kurs.dart).
  mittel('mittel'),

  /// Dazu jeder Vorgang, der in Moodle etwas erzeugt -- auch verborgen
  /// Angelegtes und sein Füllen, Kopien, importierte Fragen.
  alle('alle');

  const Bestaetigungen(this.text);

  /// Der Name in der Oberfläche und in den Einstellungen.
  final String text;

  static const Bestaetigungen vorgabe = mittel;

  /// Unbekanntes (alte oder beschädigte Einstellungen) wird zur Vorgabe --
  /// nie zu „keine": Eine Datei, die niemand lesen kann, schaltet keine
  /// Rückfragen ab.
  static Bestaetigungen ausText(String? t) =>
      values.where((x) => x.text == t).firstOrNull ?? vorgabe;
}

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
    this.ab = Bestaetigungen.mittel,
  });

  final String titel;

  /// Ab welcher Stufe diese Anfrage gestellt wird. Vorgabe ist „mittel" --
  /// alles, was Bestehendes anfasst oder sofort sichtbar wird. Wer nur bei
  /// „alle" fragen will (Anlegen, Duplizieren, Importieren), gibt
  /// [Bestaetigungen.alle] an; [Bestaetigungen.keine] heißt „immer fragen, auch
  /// bei keine" und gilt nur für das Bildschirmfoto, das keine Änderung ist.
  final Bestaetigungen ab;

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
  Freigaben(this.protokoll, {this.frist = fristVorgabe, this.stufe = Bestaetigungen.vorgabe});

  /// Kürzer als das Zeitlimit, das die App in Bionic einträgt
  /// (`bionicZeitlimit`, einrichtung.dart).
  static const fristVorgabe = Duration(minutes: 30);

  final Protokoll protokoll;
  final Duration frist;

  /// Die eingestellte Stufe (Titelzeile, gespeichert in den Einstellungen).
  /// Bewusst ohne notifyListeners: Die Zuhörer folgen den Anfragen und dem
  /// Zähler [wartend], und die Oberfläche, die die Stufe setzt, baut sich
  /// selbst neu auf.
  Bestaetigungen stufe;

  /// Wie oft eine Freigabe wegen der Stufe ausgelassen wurde. Der MCP-Dienst
  /// vergleicht den Zähler vor und nach einem Werkzeug und sagt Claude, dass
  /// ohne Freigabe geschrieben wurde -- sonst kündigt der Skill eine
  /// Rückfrage an, die nie kommt.
  int ausgelassen = 0;

  FreigabeAnfrage? _aktuell;
  FreigabeAnfrage? get aktuell => _aktuell;

  /// Wie viele Anfragen hinter der offenen warten. Der Dialog zeigt es, damit
  /// die Lehrkraft weiß, dass nach ihrer Entscheidung noch etwas kommt;
  /// Zuhörer erfahren jede Änderung.
  int get wartend => _wartend;
  int _wartend = 0;

  static const _abbruch = #freigabenAbbruch;

  /// Führt [f] so aus, dass seine Freigaben verfallen, sobald sich [abbruch]
  /// erfüllt: Dann wartet der Client nicht mehr auf das Ergebnis.
  static Future<T> mitAbbruch<T>(Future<void> abbruch, Future<T> Function() f) =>
      runZoned(f, zoneValues: {_abbruch: abbruch});

  /// Ob [a] bei der eingestellten Stufe überhaupt gefragt wird.
  bool fragt(FreigabeAnfrage a) => stufe.index >= a.ab.index;

  /// Stellt eine Anfrage und wartet auf die Entscheidung, höchstens [frist]
  /// und nur, solange der Client wartet ([mitAbbruch]). Es gibt immer nur eine
  /// offene Anfrage; eine zweite reiht sich ein ([wartend], mit Eintrag im
  /// Protokoll) und wartet, bis die erste entschieden ist. Ihre Frist beginnt
  /// erst, wenn sie offen ist.
  ///
  /// Liegt die eingestellte Stufe unter der der Anfrage, wird nicht gefragt:
  /// Die Lehrkraft hat das so eingestellt, das Protokoll hält es fest (A4),
  /// und der Werkzeugaufruf läuft durch.
  Future<bool> anfragen(FreigabeAnfrage a) async {
    if (!fragt(a)) {
      ausgelassen++;
      protokoll.eintrag(Art.schreiben, 'Ohne Freigabe (Bestätigungen: ${stufe.text}): ${a.titel}');
      a._antwort.complete(true);
      return true;
    }
    var abgebrochen = false;
    final abbruch = (Zone.current[_abbruch] as Future<void>?)?.then((_) => abgebrochen = true);
    if (_aktuell != null) {
      // Einreihen. Die Wartenden wachen in der Reihenfolge auf, in der sie
      // kamen; wer zuerst sieht, dass keine Anfrage mehr offen ist, ist dran.
      final davor = 1 + _wartend;
      protokoll.eintrag(Art.info,
          'Freigabe wartet hinter ${davor == 1 ? 'einer anderen' : '$davor anderen'}: ${a.titel}');
      _wartend++;
      notifyListeners();
      while (_aktuell != null && !abgebrochen) {
        await Future.any([_aktuell!._antwort.future, ?abbruch]);
      }
      // Kein eigenes notifyListeners: Beide Wege unten melden sich ohnehin.
      _wartend--;
    }
    // Abgebrochen, während eine andere Anfrage offen war: gar nicht erst
    // fragen.
    if (abgebrochen) {
      protokoll.eintrag(Art.info, 'Die KI wartet nicht mehr -- nicht gefragt, nicht gespeichert: ${a.titel}');
      a._antwort.complete(false);
      notifyListeners();
      return false;
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
    abbruch?.then((_) {
      if (a.offen) {
        protokoll.eintrag(Art.info, 'Die KI wartet nicht mehr -- nicht gespeichert');
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
