// sichtbarkeit_setzen erhält „verfügbar ohne Link auf der Kursseite" (stealth): Die App merkt sich,
// was sie aus diesem Zustand verbirgt, stellt ihn beim Sichtbarmachen mit cm_stealth wieder her
// und meldet jede Abweichung als verified: false. Moodle ist hier ein Doppel, das die Zustände so
// führt, wie der Quelltext von Moodle es tut: Verbergen und Zeigen setzen den Zustand ohne Link zurück.
// Der Ablauf gegen eine echte Instanz ist nicht geprüft (cm_stealth ist ungemessen).
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/freigabe.dart';
import 'package:moocp/moodle/kurs_aendern.dart';
import 'package:moocp/moodle/moodle_zugang.dart';
import 'package:moocp/protokoll.dart';

typedef _Cm = ({bool visible, bool stealth});

class _Kurs extends MoodleZugang {
  _Kurs() : super(Protokoll());

  /// cmid -> Zustand. Aktivität 11 liegt im Abschnitt 1, 12 ebenfalls.
  final Map<int, _Cm> cms = {
    11: (visible: true, stealth: false),
    12: (visible: true, stealth: false),
  };
  final Map<int, String> namen = {11: 'ZZ Lösung', 12: 'ZZ Blatt'};
  var abschnittSichtbar = true;

  /// Moodle behält den Zustand ohne Link beim Zeigen eines Abschnitts (false: setzt ihn zurück).
  var abschnittBehaeltStealth = false;
  var stealthErlaubt = true;

  /// Wert von `allowstealth` im Kursstatus; null: der Status nennt es nicht.
  bool? allowstealth;
  final aktionen = <String>[];
  final _vorher = <int, _Cm>{};

  @override
  Future<Object?> dienst(String name, Map<String, Object?> args) async {
    switch (name) {
      case 'core_course_get_enrolled_courses_by_timeline_classification':
        return {'courses': <Object?>[]};
      case 'core_courseformat_get_state':
        return {
          'cm': [
            for (final e in cms.entries)
              {
                'id': e.key,
                'module': 'page',
                'name': namen[e.key],
                'visible': e.value.visible ? 1 : 0,
                'stealth': e.value.stealth,
                if (allowstealth != null) 'allowstealth': allowstealth,
                'sectionid': 1,
              },
          ],
          'section': [
            {'id': 1, 'number': 1, 'title': 'ZZ Abschnitt', 'visible': abschnittSichtbar, 'cmlist': cms.keys.toList()},
          ],
        };
      case 'core_courseformat_update_course':
        final aktion = args['action'] as String;
        final ids = (args['ids'] as List).cast<int>();
        aktionen.add('$aktion ${ids.join(',')}');
        switch (aktion) {
          case 'cm_hide':
            for (final i in ids) {
              cms[i] = (visible: false, stealth: false);
            }
          case 'cm_show':
            for (final i in ids) {
              cms[i] = (visible: true, stealth: false);
            }
          case 'cm_stealth':
            if (!stealthErlaubt) throw MoodleFehler('Diese Aktion ist auf der Instanz ausgeschaltet.');
            for (final i in ids) {
              cms[i] = (visible: true, stealth: true);
            }
          case 'section_hide':
            abschnittSichtbar = false;
            for (final i in cms.keys.toList()) {
              _vorher[i] = cms[i]!;
              cms[i] = (visible: false, stealth: false);
            }
          case 'section_show':
            abschnittSichtbar = true;
            for (final i in cms.keys.toList()) {
              final davor = _vorher[i] ?? (visible: true, stealth: false);
              cms[i] = (visible: davor.visible, stealth: abschnittBehaeltStealth && davor.stealth);
            }
          default:
            throw StateError('Unerwartete Aktion $aktion');
        }
        return <String, Object?>{};
    }
    throw StateError('Unerwarteter Dienst $name');
  }
}

void main() {
  late _Kurs moodle;
  late Freigaben freigaben;
  late List<FreigabeAnfrage> gefragt;

  setUp(() {
    moodle = _Kurs();
    freigaben = Freigaben(Protokoll(), stufe: Bestaetigungen.mittel);
    gefragt = [];
    // Die Lehrkraft gibt jede Anfrage frei; was sie gesehen hat, bleibt in [gefragt].
    freigaben.addListener(() {
      final a = freigaben.aktuell;
      if (a == null) return;
      gefragt.add(a);
      Future.microtask(() => freigaben.entscheiden(true));
    });
  });

  Future<String> setzen({int? cmid = 11, int? abschnitt, String? name, required bool sichtbar, bool? ohneLink}) =>
      sichtbarkeitSetzen(moodle, freigaben,
          kurs: 5,
          cmid: abschnitt == null ? cmid : null,
          abschnittId: abschnitt,
          name: name ?? (abschnitt != null ? 'ZZ Abschnitt' : moodle.namen[cmid]!),
          sichtbar: sichtbar,
          ohneLink: ohneLink);

  group('einzelne Aktivität', () {
    test('bietet die Instanz „ohne Link" nicht an (allowstealth false), bricht das Werkzeug vor der Freigabe ab',
        () async {
      // Gemessen: Ohne die Website-Einstellung nimmt Moodle cm_stealth an und macht die
      // Aktivität ganz sichtbar.
      moodle.allowstealth = false;
      moodle.cms[11] = (visible: false, stealth: false);
      await expectLater(setzen(sichtbar: true, ohneLink: true),
          throwsA(isA<MoodleFehler>().having((f) => f.meldung, 'meldung', contains('bietet'))));
      expect(gefragt, isEmpty);
      expect(moodle.aktionen, isEmpty);
      expect(moodle.cms[11], (visible: false, stealth: false));
    });

    test('verbergen und wieder zeigen: „ohne Link" kommt zurück, ohne Zwischenschritt auf der Kursseite', () async {
      moodle.cms[11] = (visible: true, stealth: true);

      final weg = await setzen(sichtbar: false);
      expect(weg, contains('verborgen'));
      expect(weg, contains('verified: true'));
      expect(weg, contains('aufgehoben'), reason: 'die Antwort sagt, dass der Zustand mit dem Verbergen endet');
      expect(moodle.ohneLinkVorherVerborgen, {11});
      expect(gefragt.single.punkte.join(' '), contains('Verbergen hebt das auf'));

      gefragt.clear();
      final da = await setzen(sichtbar: true);
      expect(da, contains('VERFÜGBAR OHNE LINK'));
      expect(da, contains('verified: true'));
      expect(da, contains('wiederhergestellt'));
      expect(moodle.cms[11], (visible: true, stealth: true));
      expect(moodle.aktionen, ['cm_hide 11', 'cm_stealth 11'], reason: 'kein cm_show: Es gab nie einen Moment ganz sichtbar');
      expect(gefragt.single.titel, contains('ohne Link'));
      expect(gefragt.single.punkte.join(' '), contains('So war es vor dem Verbergen'));
      expect(moodle.ohneLinkVorherVerborgen, isEmpty);
    });

    test('war sie nicht „ohne Link", wird sie ganz sichtbar, und nichts wird gemerkt', () async {
      await setzen(sichtbar: false);
      expect(moodle.ohneLinkVorherVerborgen, isEmpty);
      final da = await setzen(sichtbar: true);
      expect(da, contains('SICHTBAR'));
      expect(da, isNot(contains('OHNE LINK')));
      expect(da, contains('verified: true'));
      expect(moodle.aktionen, ['cm_hide 11', 'cm_show 11']);
    });

    test('ohne Merker (Neustart, von Hand verborgen) sagt die Freigabe, dass die App den Zustand nicht kennt', () async {
      moodle.cms[11] = (visible: false, stealth: false);
      final da = await setzen(sichtbar: true);
      expect(da, contains('SICHTBAR'));
      expect(gefragt.single.punkte.join(' '), contains('weiß die App nicht'));
    });

    test('ohne_link: true setzt den Zustand ausdrücklich, auch ohne Merker', () async {
      moodle.cms[11] = (visible: false, stealth: false);
      final da = await setzen(sichtbar: true, ohneLink: true);
      expect(da, contains('VERFÜGBAR OHNE LINK'));
      expect(da, contains('verified: true'));
      expect(da, isNot(contains('frühere Zustand')), reason: 'ausdrücklich gewählt, nicht wiederhergestellt');
      expect(moodle.aktionen, ['cm_stealth 11']);
    });

    test('ohne_link: false macht ganz sichtbar, auch wenn die App den früheren Zustand kennt', () async {
      moodle.cms[11] = (visible: true, stealth: true);
      await setzen(sichtbar: false);
      final da = await setzen(sichtbar: true, ohneLink: false);
      expect(da, contains('SICHTBAR'));
      expect(moodle.cms[11], (visible: true, stealth: false));
      expect(moodle.ohneLinkVorherVerborgen, isEmpty);
    });

    test('sichtbar mit Link auf der Kursseite holt eine Aktivität ohne Link nur mit ohne_link: false dorthin', () async {
      moodle.cms[11] = (visible: true, stealth: true);
      final schon = await setzen(sichtbar: true);
      expect(schon, contains('nichts geändert'));
      expect(schon, contains('ohne_link: false'));
      expect(moodle.aktionen, isEmpty);
      expect(gefragt, isEmpty);

      final holt = await setzen(sichtbar: true, ohneLink: false);
      expect(holt, contains('SICHTBAR'));
      expect(moodle.aktionen, ['cm_show 11']);
    });

    test('geht cm_stealth nicht, bleibt die Aktivität verborgen, und die Antwort sagt es: verified: false', () async {
      moodle.cms[11] = (visible: true, stealth: true);
      await setzen(sichtbar: false);
      moodle.stealthErlaubt = false;
      final da = await setzen(sichtbar: true);
      expect(da, contains('verified: false'));
      expect(da, contains('Abweichung'));
      expect(da, contains('nicht gesetzt'));
      expect(moodle.cms[11], (visible: false, stealth: false), reason: 'nichts wurde ganz sichtbar gemacht');
      expect(moodle.ohneLinkVorherVerborgen, {11}, reason: 'der Merker bleibt für einen neuen Versuch');
    });

    test('ohne_link gilt nur zu sichtbar: true und nur für eine Aktivität', () async {
      await expectLater(setzen(sichtbar: false, ohneLink: true), throwsA(isA<MoodleFehler>()));
      await expectLater(setzen(abschnitt: 1, sichtbar: true, ohneLink: true), throwsA(isA<MoodleFehler>()));
      expect(moodle.aktionen, isEmpty);
      expect(gefragt, isEmpty);
    });

    test('ohne Freigabe geschieht nichts und nichts wird gemerkt', () async {
      moodle.cms[11] = (visible: true, stealth: true);
      final lehnt = Freigaben(Protokoll(), stufe: Bestaetigungen.mittel);
      lehnt.addListener(() {
        if (lehnt.aktuell != null) Future.microtask(() => lehnt.entscheiden(false));
      });
      final r = await sichtbarkeitSetzen(moodle, lehnt, kurs: 5, cmid: 11, name: 'ZZ Lösung', sichtbar: false);
      expect(r, contains('Nicht geändert'));
      expect(moodle.aktionen, isEmpty);
      expect(moodle.ohneLinkVorherVerborgen, isEmpty);
    });
  });

  group('Abschnitt', () {
    test('Moodle setzt den Zustand beim Zeigen zurück: die App stellt ihn für die gemerkten Aktivitäten her', () async {
      moodle.cms[11] = (visible: true, stealth: true);
      final weg = await setzen(abschnitt: 1, sichtbar: false);
      expect(weg, contains('verified: true'));
      expect(weg, contains('„ZZ Lösung"'));
      expect(weg, contains('aufgehoben'));
      expect(moodle.ohneLinkVorherVerborgen, {11});

      gefragt.clear();
      final da = await setzen(abschnitt: 1, sichtbar: true);
      expect(da, contains('SICHTBAR'));
      expect(da, contains('verified: true'));
      expect(da, contains('Wieder „verfügbar ohne Link auf der Kursseite": „ZZ Lösung"'));
      expect(moodle.cms[11], (visible: true, stealth: true));
      expect(moodle.cms[12], (visible: true, stealth: false));
      expect(moodle.aktionen, ['section_hide 1', 'section_show 1', 'cm_stealth 11']);
      expect(gefragt.single.punkte.join(' '), contains('„ZZ Lösung"'));
      expect(moodle.ohneLinkVorherVerborgen, isEmpty);
    });

    test('behält Moodle den Zustand selbst, setzt die App nichts nach', () async {
      moodle.abschnittBehaeltStealth = true;
      moodle.cms[11] = (visible: true, stealth: true);
      await setzen(abschnitt: 1, sichtbar: false);
      final da = await setzen(abschnitt: 1, sichtbar: true);
      expect(da, contains('verified: true'));
      expect(moodle.cms[11], (visible: true, stealth: true));
      expect(moodle.aktionen, ['section_hide 1', 'section_show 1'], reason: 'nichts nachzustellen');
    });

    test('geht cm_stealth nicht, steht die Aktivität auf der Kursseite, und die Antwort sagt es', () async {
      moodle.cms[11] = (visible: true, stealth: true);
      await setzen(abschnitt: 1, sichtbar: false);
      moodle.stealthErlaubt = false;
      final da = await setzen(abschnitt: 1, sichtbar: true);
      expect(da, contains('verified: false'));
      expect(da, contains('Abweichung'));
      expect(da, contains('„ZZ Lösung"'));
      expect(moodle.ohneLinkVorherVerborgen, isEmpty, reason: 'sie steht jetzt auf der Kursseite; kein Merker mehr');
    });

    test('eine einzeln verborgene gemerkte Aktivität bleibt verborgen und gemerkt', () async {
      moodle.cms[11] = (visible: true, stealth: true);
      await setzen(sichtbar: false);
      // Der Abschnitt wird nun verborgen und wieder gezeigt: Die einzeln verborgene bleibt verborgen.
      await setzen(abschnitt: 1, sichtbar: false);
      moodle.aktionen.clear();
      moodle.cms[11] = (visible: false, stealth: false);
      final da = await setzen(abschnitt: 1, sichtbar: true);
      expect(da, contains('verified: true'));
      expect(moodle.aktionen, ['section_show 1'], reason: 'sie bleibt verborgen, also nichts herzustellen');
      expect(moodle.ohneLinkVorherVerborgen, {11}, reason: 'der Merker bleibt für das spätere Sichtbarmachen');
    });
  });
}
