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
// cancelled, etwa nach dem Zeitlimit des Clients), verfällt die Anfrage wie
// nach der Frist: Der Dialog schließt sich, nichts wird geschrieben. Sonst
// schriebe eine späte Freigabe, während die KI den Vorgang für gescheitert
// hält. Den Abbruch erfährt [Freigaben.anfragen] aus der Zone des
// Werkzeugaufrufs ([Freigaben.mitAbbruch]) -- auch das an einer Stelle, kein
// Werkzeug muss ihn durchreichen.

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'moodle/zeilenvergleich.dart';
import 'protokoll.dart';
import 'testschalter.dart';

/// Wie viele Bestätigungen die Lehrkraft vor Änderungen in Moodle will.
/// Die Reihenfolge ist die Mechanik: Gefragt wird, wenn die eingestellte
/// Stufe mindestens so hoch ist wie die der Anfrage ([FreigabeAnfrage.ab]).
enum Bestaetigungen {
  /// Schreibfreigaben entfallen; fachliche Karten-Zuordnungen und das Ersetzen
  /// eines Kurses (Wiederherstellung, die alle Inhalte löscht) fragen weiter. Die
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

/// Ein Verweis in einer Freigabe: Die Lehrkraft öffnet das Ziel im Browser, um
/// vor ihrer Entscheidung nachzusehen (Moodle-Aktivität, die gelöscht wird).
class FreigabeLink {
  const FreigabeLink(this.text, this.adresse, {this.warnung});

  final String text;
  final Uri adresse;

  /// Warum die Zeile Aufmerksamkeit verlangt; null, wenn nicht.
  final String? warnung;
}

/// Eine Gruppe von Verweisen unter einer Überschrift. Eine Gruppe mit
/// [warnung] zeigt der Dialog hervorgehoben (Warnzeichen, Farbe).
class FreigabeLinkGruppe {
  const FreigabeLinkGruppe(this.titel, this.links, {this.warnung = false});

  final String titel;
  final List<FreigabeLink> links;
  final bool warnung;
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
    this.kopieren = const [],
    this.abhaken = const [],
    this.schritteVerlangt = true,
    this.ordner,
    this.oeffnen,
    this.links = const [],
    this.ab = Bestaetigungen.mittel,
    this.bildschirmfoto = false,
  });

  final String titel;

  /// Ab welcher Stufe diese Anfrage gestellt wird. Vorgabe ist „mittel" --
  /// alles, was Bestehendes anfasst oder sofort sichtbar wird. Wer nur bei
  /// „alle" fragen will (Anlegen, Duplizieren, Importieren), gibt
  /// [Bestaetigungen.alle] an; [Bestaetigungen.keine] heißt „immer fragen, auch
  /// bei keine" gilt für Bildschirmfotos, fachliche Karten-Zuordnungen, das
  /// Ersetzen eines Kurses (E20: Löschen fragt immer) und die
  /// Übergabe an die Lehrkraft, wenn ein Schutzdienst das Speichern anhält
  /// ([kopieren]; E34).
  final Bestaetigungen ab;

  /// Ob dies die Freigabe je Bildschirmfoto ist (E18). Nur im Testbetrieb
  /// ([testbetriebAktiv]) von Bedeutung: Dort wird automatisch freigegeben, was
  /// nicht „immer fragen" ist ([ab] über [Bestaetigungen.keine]) -- das
  /// Bildschirmfoto ist die einzige ausdrücklich benannte Ausnahme, weil es nur
  /// ein Bild des eigenen Testkurses betrifft. Übergabe-Bitten, fachliche
  /// Karten-Zuordnungen und die Rückfrage vor einer Wiederholung gehen im
  /// Testbetrieb wie sonst an die Lehrkraft.
  final bool bildschirmfoto;

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

  /// Texte, die die Lehrkraft mit je einem Knopf in die Zwischenablage legt:
  /// (Beschriftung, Text). Für die Übergabe, wenn die App nicht selbst
  /// speichern kann (SchutzPruefung) -- die Lehrkraft fügt sie im Browser ein.
  /// Erst auf ihren Klick, damit nichts verloren geht, was sie gerade selbst
  /// kopiert hat.
  final List<(String, String)> kopieren;

  /// Schritte, die die Lehrkraft in der App abhakt. Bei der Übergabe sind es
  /// Schritte, die sie im Browser von Hand tut, etwa eine Einstellung setzen;
  /// ohne Übergabe eine ausdrückliche Bestätigung (etwa vor dem Löschen eines
  /// ganzen Kurses). Erst wenn jeder abgehakt und alles kopiert ist, geht der
  /// Abschlussknopf.
  final List<String> abhaken;

  /// Ob der Abschlussknopf erst nach allen Schritten geht. Nein beim zweiten
  /// Blick („Noch einmal prüfen"): Dann sind sie meist schon getan.
  final bool schritteVerlangt;

  /// Ein Ordner mit neuen Dateien, den der Dialog im Dateimanager öffnet: Die
  /// Lehrkraft zieht sie von dort in den Editor im Browser.
  final String? ordner;

  /// Eine Seite in Moodle, die der Dialog im Standardbrowser öffnet.
  final Uri? oeffnen;

  /// Verweise, die der Dialog anklickbar zeigt und im Standardbrowser öffnet:
  /// bei einer löschenden Wiederherstellung jede Aktivität, die verschwindet.
  /// Sie machen den Dialog nicht zur Übergabe ([uebergabe]): Die Lehrkraft
  /// sieht nach und entscheidet dann hier.
  final List<FreigabeLinkGruppe> links;

  /// Eine Übergabe an die Lehrkraft statt einer Freigabe: Sie arbeitet dabei
  /// im Browser, die App darf ihr Fenster also nicht oben halten.
  bool get uebergabe => kopieren.isNotEmpty || oeffnen != null;

  /// Bilder (PNG), die nach der Freigabe weitergehen -- die Lehrkraft sieht
  /// genau sie (Bildschirmfotos).
  final List<Uint8List> bilder;

  /// Wann die Frist endet; gesetzt von [Freigaben.anfragen]. Sie läuft ab der
  /// Anfrage, auch solange sie hinter einer anderen wartet -- der Dialog nennt
  /// deshalb, was davon noch bleibt.
  DateTime? get ablauf => _ablauf;
  DateTime? _ablauf;

  final Completer<bool> _antwort = Completer<bool>();
  bool get offen => !_antwort.isCompleted;
}

/// Was während eines Werkzeugaufrufs ohne persönliche Freigabe geschah. Der
/// MCP-Dienst legt einen an ([Freigaben.mitAbbruch]) und sagt Claude danach,
/// dass ohne Freigabe geschrieben wurde. Je Aufruf statt über die Zähler der
/// [Freigaben]: Liefen zwei Aufrufe gleichzeitig, bekäme sonst einer die
/// Auslassung des anderen gemeldet.
class AufrufZaehler {
  /// Freigaben, die die eingestellte Stufe ausgelassen hat.
  int ausgelassen = 0;

  /// Freigaben, die der Testbetrieb automatisch erteilt hat.
  int testfreigaben = 0;
}

class _AbbruchStand {
  _AbbruchStand(this.signal, this.zaehler) {
    signal.then((_) => abgebrochen = true);
  }
  final Future<void> signal;
  final AufrufZaehler? zaehler;
  bool abgebrochen = false;
}

class Freigaben extends ChangeNotifier {
  Freigaben(this.protokoll,
      {this.frist = fristVorgabe, this.stufe = Bestaetigungen.vorgabe});

  static const _testfreigabe = #begrenzteTestfreigabe;
  int testfreigaben = 0;

  /// Nur der gebundene Testablauf darf seine eigenen Anfragen automatisch freigeben,
  /// und nur im Testbetrieb ([testbetriebAktiv]); sonst läuft [f] unverändert.
  Future<T> imTest<T>(Future<T> Function() f, {required Future<bool> Function() pruefen}) =>
      runZoned(f, zoneValues: {_testfreigabe: testbetriebAktiv ? (freigaben: this, pruefen: pruefen) : null});

  /// Kürzer als das Zeitlimit, das die App in ein KI-Werkzeug einträgt
  /// (`clientZeitlimit`, einrichtung.dart).
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

  /// Die Anfragen hinter der offenen, in der Reihenfolge, in der sie kamen.
  final _warteschlange = Queue<FreigabeAnfrage>();

  /// Wie viele Anfragen hinter der offenen warten. Der Dialog zeigt es, damit
  /// die Lehrkraft weiß, dass nach ihrer Entscheidung noch etwas kommt;
  /// Zuhörer erfahren jede Änderung.
  int get wartend => _warteschlange.length;

  static const _abbruch = #freigabenAbbruch;

  /// Führt [f] so aus, dass seine Freigaben verfallen, sobald sich [abbruch]
  /// erfüllt: Dann wartet der Client nicht mehr auf das Ergebnis. Mit [zaehler]
  /// zählt [anfragen] mit, was in diesem Aufruf ohne persönliche Freigabe lief.
  static Future<T> mitAbbruch<T>(Future<void> abbruch, Future<T> Function() f,
          {AufrufZaehler? zaehler}) =>
      runZoned(f, zoneValues: {_abbruch: _AbbruchStand(abbruch, zaehler)});

  /// Ob [a] bei der eingestellten Stufe überhaupt gefragt wird.
  bool fragt(FreigabeAnfrage a) => stufe.index >= a.ab.index;

  /// Stellt eine Anfrage und wartet auf die Entscheidung, höchstens [frist]
  /// und nur, solange der Client wartet ([mitAbbruch]). Es gibt immer nur eine
  /// offene Anfrage; eine zweite reiht sich ein ([wartend], mit Eintrag im
  /// Protokoll) und ist dran, sobald die erste beantwortet ist.
  ///
  /// Die Frist läuft ab der Anfrage, auch während sie wartet. Sie soll vor dem
  /// Zeitlimit des Clients enden (`clientZeitlimit`, einrichtung.dart), und
  /// das läuft ab dem Werkzeugaufruf; begänne sie erst mit dem Dialog, könnte
  /// eine lange wartende Anfrage noch freigegeben werden, wenn der Client
  /// schon aufgibt, und Moodle würde geändert, während die KI den Vorgang für
  /// gescheitert hält.
  ///
  /// Liegt die eingestellte Stufe unter der der Anfrage, wird nicht gefragt:
  /// Die Lehrkraft hat das so eingestellt, das Protokoll hält es fest (A4),
  /// und der Werkzeugaufruf läuft durch. Entschieden wird das beim Anfragen;
  /// für Wartende ändert sich daran nichts mehr, und das muss es auch nicht:
  /// Solange ein Freigabedialog offen ist, sperrt er die Titelzeile mit dem
  /// Feld für die Stufe, und ohne offenen Dialog wartet keine Anfrage.
  Future<bool> anfragen(FreigabeAnfrage a) async {
    final abbruch = Zone.current[_abbruch] as _AbbruchStand?;
    bool abgebrochen() {
      if (abbruch?.abgebrochen != true) return false;
      protokoll.eintrag(Art.info, 'Die KI wartet nicht mehr -- nicht gespeichert');
      a._antwort.complete(false);
      return true;
    }
    if (abgebrochen()) return false;
    // Testbetrieb: Automatisch freigegeben wird nur, was nicht „immer fragen"
    // ist. Eine Anfrage mit `ab: keine` (Übergabe-Bitte, fachliche Zuordnung,
    // Wiederholung) geht wie im Normalbetrieb an die Lehrkraft; einzige
    // Ausnahme ist das Bildschirmfoto (FreigabeAnfrage.bildschirmfoto).
    final test = Zone.current[_testfreigabe] as ({Freigaben freigaben, Future<bool> Function() pruefen})?;
    if (testbetriebAktiv &&
        test != null &&
        identical(test.freigaben, this) &&
        (a.ab != Bestaetigungen.keine || a.bildschirmfoto)) {
      final erlaubt = await test.pruefen();
      if (abgebrochen()) return false;
      if (erlaubt) {
        testfreigaben++;
        abbruch?.zaehler?.testfreigaben++;
        protokoll.eintrag(Art.schreiben, 'Testmodus, automatisch freigegeben: ${a.titel}');
        a._antwort.complete(true);
        return true;
      }
    }
    if (!fragt(a)) {
      ausgelassen++;
      abbruch?.zaehler?.ausgelassen++;
      protokoll.eintrag(Art.schreiben, 'Ohne Freigabe (Bestätigungen: ${stufe.text}): ${a.titel}');
      a._antwort.complete(true);
      return true;
    }
    a._ablauf = DateTime.now().add(frist);
    // Die Frist hängt an einem eigenen Timer, nicht am Warten auf die Antwort:
    // So läuft sie sicher ab, auch wenn niemand den Dialog sieht.
    final uhr = Timer(frist, () => _verfallen(a, 'Frist abgelaufen'));
    abbruch?.signal.then((_) => _verfallen(a, 'Die KI wartet nicht mehr'));
    if (_aktuell == null) {
      _oeffnen(a);
    } else {
      final davor = 1 + _warteschlange.length;
      protokoll.eintrag(Art.info,
          'Freigabe wartet hinter ${davor == 1 ? 'einer anderen' : '$davor anderen'}: ${a.titel}');
      _warteschlange.add(a);
    }
    notifyListeners();
    try {
      return await a._antwort.future;
    } finally {
      uhr.cancel();
    }
  }

  void _oeffnen(FreigabeAnfrage a) {
    _aktuell = a;
    protokoll.eintrag(Art.info, 'Freigabe angefragt: ${a.titel} (Frist ${_dauer(a._ablauf!.difference(DateTime.now()))})');
  }

  /// Beantwortet [a], ob offen oder wartend; ist sie die offene, ist die
  /// nächste wartende dran. Im selben Zug, damit die Oberfläche nie „keine
  /// Anfrage offen" sieht, während noch eine wartet.
  void _beantworten(FreigabeAnfrage a, bool speichern) {
    a._antwort.complete(speichern);
    if (identical(a, _aktuell)) {
      _aktuell = null;
      if (_warteschlange.isNotEmpty) _oeffnen(_warteschlange.removeFirst());
    } else {
      _warteschlange.remove(a);
    }
    notifyListeners();
  }

  /// Frist oder Abbruch: Eine wartende Anfrage wird gar nicht erst gefragt.
  void _verfallen(FreigabeAnfrage a, String grund) {
    if (!a.offen) return;
    protokoll.eintrag(
        Art.info,
        identical(a, _aktuell)
            ? '$grund -- nicht gespeichert'
            : '$grund -- nicht gefragt, nicht gespeichert: ${a.titel}');
    _beantworten(a, false);
  }

  void entscheiden(bool speichern) {
    final a = _aktuell;
    if (a != null && a.offen) {
      protokoll.eintrag(speichern ? Art.schreiben : Art.info,
          'Freigabe ${speichern ? "erteilt" : "abgelehnt"}');
      _beantworten(a, speichern);
    }
  }

  /// Gerundet: Die Restfrist einer Anfrage, die gerade drankommt, ist um
  /// Bruchteile kürzer als [frist] und soll trotzdem „30 min" heißen.
  static String _dauer(Duration d) {
    final s = (d.inMilliseconds / 1000).round();
    return s >= 60 ? '${(s / 60).round()} min' : '$s s';
  }
}
