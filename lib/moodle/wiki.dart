// Wiki (mod_wiki): Werkzeuge wiki_lesen, wikiseite_schreiben,
// wikiseite_loeschen, und die Ansicht für bildschirmfoto. Nur ein
// GEMEINSAMES Wiki ohne Gruppen: Die Seiten sind Kursinhalt, den alle
// schreiben. WER was schrieb, steht im Verlauf, in den Kommentaren und in
// zwei Ansichten der Wiki-Struktur (map.php option=1 und 6) -- alles
// gesperrt. Nicht angefasst werden:
//   - ein persönliches Wiki: Es besteht aus Nutzerdaten; seine Adressen
//     tragen uid=<userid> bzw. groupanduser=<groupid>-<userid>, die
//     Sperrliste greift;
//   - ein Wiki nach Gruppen: Jede Gruppe hat eigene Seiten, geschrieben von
//     ihren Mitgliedern, und welche davon view.php?id zeigt, hängt an der
//     zuletzt gewählten Gruppe -- Lesen träfe Gruppenarbeit, Schreiben eine
//     zufällige Gruppe.
// Erkannt an zwei Stellen (siehe [wikiTypPruefen], [wikiAnsichtSperre]).
//
// Gemessen in den Browser-Skills (22.09.2026): Die Webservices mod_wiki_*
// sind auf der Instanz nicht für AJAX freigeschaltet. Es bleiben die Seiten:
//   view.php?id=<cmid>       Startseite, oder das Erstellformular, wenn keine da
//   view.php?pageid=<n>      eine Seite; Inhalt in .generalbox .no-overflow
//   map.php?pageid&option=5  Seitenliste
//   create.php?swid&title&action=new -> Formular -> edit.php?pageid
//   edit.php?pageid=<n>      Bearbeitungsformular; der Speichern-Knopf heißt
//                            editoption und trägt den LOKALISIERTEN Text
//   admin.php?…&delete=<n>   löscht SOFORT, ohne Rückfrage
// edit.php setzt beim Abruf eine Bearbeitungssperre für die angemeldete
// Person, die erst beim Speichern fällt. Deshalb wird zum LESEN nie edit.php
// geholt, und zum Schreiben erst nach der Freigabe.
//
// Verweise: a.wiki_newentry ist ein nie angelegter Titel (harmlos, bietet das
// Anlegen an). a[href*=pageid=] auf eine GELÖSCHTE Seite führt zu HTTP 404,
// bis Moodle den Seitenaufbau neu berechnet (bei der Messung nach einigen
// Minuten) -- Moodles „Verwaiste Seiten" zeigt das nicht an.

import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

import '../freigabe.dart';
import 'formeln.dart';
import 'formular.dart';
import 'formular_schreiben.dart';
import 'kurs.dart';
import 'moodle_zugang.dart';
import 'zeilenvergleich.dart';

class WikiSeite {
  WikiSeite(this.id, this.titel);
  final int id;
  final String titel;
  String html = '';
  String text = '';
  List<String> fehlend = [];
  List<(int, String)> verweise = [];
}

class Wiki {
  Wiki(this.cmid, this.startId, this.swid, this.startTitel, this.seiten);
  final int cmid;
  final int? startId;
  final int? swid;

  /// Ohne Startseite: der Titel, den die erste Seite haben muss.
  final String? startTitel;
  final List<WikiSeite> seiten;
}

int? _pageid(String? href) => int.tryParse(RegExp(r'pageid=(\d+)').firstMatch(href ?? '')?.group(1) ?? '');

const String _persoenlich = 'Das ist ein persönliches Wiki: Jede Seite gehört einer Person. Die App liest und '
    'schreibt dort nichts -- nur die Einstellungen (aktivitaet_lesen).';
const String _gruppen = 'Das Wiki ist nach Gruppen getrennt: Jede Gruppe hat eigene Seiten, die ihre Mitglieder '
    'schreiben. Die App liest und schreibt dort nichts -- nur die Einstellungen (aktivitaet_lesen).';
const String _gruppenmodus = 'Das Wiki steht im Gruppenmodus: Hat der Kurs Gruppen, hat jede Gruppe eigene Seiten, '
    'die ihre Mitglieder schreiben. Die App liest und schreibt dort nichts -- nur die Einstellungen '
    '(aktivitaet_lesen). Arbeiten lässt sich daran erst, wenn der Gruppenmodus auf „Keine Gruppen" steht.';

/// Erste Stelle: Typ und Gruppenmodus aus dem Einstellungsformular (modedit).
/// Den Typ zeigt Moodle nach dem Anlegen als gesperrte Auswahl (disabled,
/// mod/wiki/mod_form.php); gesendet wird sie nicht, deshalb steht der Wert
/// nur im DOM. Gilt unabhängig von Gruppen und Rechten -- anders als die
/// Auswahl in der Ansicht. Der Gruppenmodus sperrt hier schon, auch in einem
/// Kurs ohne Gruppen: Ist das Wiki noch leer, zeigt view.php das
/// Anlegeformular statt der Auswahl über dem Wiki, [wikiAnsichtSperre] sieht
/// dann nichts, und die erste Seite landete bei einer Gruppe (gemessen).
/// Erzwingt der Kurs den Gruppenmodus, steht er als verstecktes Feld da.
void wikiTypPruefen(Formular einstellungen, int cmid) {
  if (einstellungen.modul != 'wiki') throw MoodleFehler('cmid $cmid ist kein Wiki.');
  final typ = einstellungen.form.querySelector('select[name="wikimode"] option[selected]')?.attributes['value'];
  if (typ == 'individual') throw MoodleFehler(_persoenlich);
  if (typ != 'collaborative') {
    throw MoodleFehler('Der Typ des Wikis cmid $cmid ist nicht zu erkennen -- die App fasst nur ein gemeinsames '
        'Wiki an.');
  }
  final gruppen = einstellungen.form.querySelector('select[name="groupmode"] option[selected]')?.attributes['value'] ??
      einstellungen.form.querySelector('input[name="groupmode"]')?.attributes['value'];
  if (gruppen != null && gruppen != '0') throw MoodleFehler(_gruppenmodus);
}

/// Zweite Stelle, als zweite Sicherung: die Auswahl, die Moodle über einem
/// Wiki zeigt (mod/wiki/renderer.php, wiki_print_subwiki_selector): eine
/// Person (uid, mit Gruppen groupanduser) oder eine Gruppe (group). Moodle
/// zeigt sie nur, wenn es Gruppen gibt bzw. das Konto alle Wikis verwalten
/// darf, und nicht über dem Anlegeformular eines leeren Wikis. Gibt die
/// Meldung zurück oder null.
String? wikiAnsichtSperre(dom.Document ansicht) {
  if (ansicht.querySelector('#region-main select[name="uid"], #region-main select[name="groupanduser"]') != null) {
    return _persoenlich;
  }
  if (ansicht.querySelector('#region-main select[name="group"]') != null) return _gruppen;
  return null;
}

Future<Wiki> _wiki(MoodleZugang moodle, int cmid, {bool mitInhalt = false, Formular? einstellungen}) async {
  wikiTypPruefen(einstellungen ?? await formularHolen(moodle, '/course/modedit.php?update=$cmid'), cmid);
  final r = await moodle.lesen('/mod/wiki/view.php?id=$cmid');
  final d = html_parser.parse(r.text);
  final sperre = wikiAnsichtSperre(d);
  if (sperre != null) throw MoodleFehler(sperre);
  final erstell = d.querySelectorAll('form').where((f) => f.querySelector('[name="pagetitle"]') != null).firstOrNull;
  final start = _pageid(d.querySelector('#region-main a[href*="pageid="]')?.attributes['href']);
  var swid = int.tryParse(d.querySelector('input[name="subwikiid"]')?.attributes['value'] ?? '') ??
      int.tryParse(RegExp(r'swid=(\d+)').firstMatch(r.text)?.group(1) ?? '');
  final seiten = <WikiSeite>[];
  if (start != null && erstell == null) {
    final m = html_parser.parse((await moodle.lesen('/mod/wiki/map.php?pageid=$start&option=5')).text);
    for (final a in m.querySelectorAll('#region-main a[href*="view.php?pageid="]')) {
      final id = _pageid(a.attributes['href']);
      if (id != null && !seiten.any((s) => s.id == id)) seiten.add(WikiSeite(id, a.text.trim()));
    }
  }
  if (mitInhalt) {
    for (final s in seiten) {
      final v = html_parser.parse((await moodle.lesen('/mod/wiki/view.php?pageid=${s.id}')).text);
      swid ??= int.tryParse(RegExp(r'swid=(\d+)').firstMatch(v.outerHtml)?.group(1) ?? '');
      final box = v.querySelector('#region-main .generalbox .no-overflow');
      if (box == null) continue;
      // Inhaltsverzeichnis, [Bearbeiten]-Links und Anker sind Dekoration der Ansicht.
      for (final e in box.querySelectorAll('.wiki-toc, a.wiki_edit_section, a[name^="toc-"]')) {
        e.remove();
      }
      s.fehlend = [for (final a in box.querySelectorAll('a.wiki_newentry')) a.text.trim()];
      s.verweise = [
        for (final a in box.querySelectorAll('a[href*="pageid="]'))
          if (_pageid(a.attributes['href']) != null) (_pageid(a.attributes['href'])!, a.text.trim())
      ];
      s.html = box.innerHtml.trim();
      s.text = box.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
  }
  return Wiki(cmid, erstell == null ? start : null, swid,
      erstell?.querySelector('[name="pagetitle"]')?.attributes['value'], seiten);
}

/// Für bildschirmfoto: dieselben Prüfungen wie beim Lesen, dann die Adresse
/// der Ansicht -- die Startseite oder [seite], wenn sie zu DIESEM Wiki gehört
/// (sonst ließe sich über die cmid eines gemeinsamen Wikis die Seite eines
/// anderen zeigen).
Future<String> wikiAnsicht(MoodleZugang moodle, int cmid, Formular einstellungen, {int? seite}) async {
  final w = await _wiki(moodle, cmid, einstellungen: einstellungen);
  if (w.seiten.isEmpty) throw MoodleFehler('Das Wiki cmid $cmid hat noch keine Seiten.');
  if (seite != null && !w.seiten.any((s) => s.id == seite)) {
    throw MoodleFehler('Seite $seite gehört nicht zum Wiki cmid $cmid -- seine Seiten nennt wiki_lesen.');
  }
  return '/mod/wiki/view.php?pageid=${seite ?? w.startId ?? w.seiten.first.id}';
}

Future<String> wikiLesen(MoodleZugang moodle, int cmid, String arbeitsordner) async {
  final w = await _wiki(moodle, cmid, mitInhalt: true);
  if (w.seiten.isEmpty) {
    return 'Wiki cmid $cmid hat noch keine Seiten. Die erste Seite muss „${w.startTitel ?? 'Startseite'}" heißen '
        '(Einstellung des Wikis) -- anlegen mit wikiseite_schreiben.';
  }
  final ordner = Directory(p.join(arbeitsordner, 'wiki-$cmid'));
  if (await ordner.exists()) await ordner.delete(recursive: true);
  await ordner.create(recursive: true);
  final bekannt = {for (final s in w.seiten) s.id: s.titel};
  final tot = <String>[], fehlend = <String>[];
  final eingehend = <int, int>{};
  for (final s in w.seiten) {
    await File(p.join(ordner.path, 'seite-${s.id}.html')).writeAsString(s.html, encoding: utf8);
    for (final (id, text) in s.verweise) {
      if (bekannt.containsKey(id)) {
        eingehend[id] = (eingehend[id] ?? 0) + 1;
      } else {
        tot.add('„${s.titel}" -> „$text" (Seite $id gelöscht)');
      }
    }
    fehlend.addAll([for (final t in s.fehlend) '„${s.titel}" -> „$t"']);
  }
  final verwaist = [for (final s in w.seiten) if (s.id != w.startId && !eingehend.containsKey(s.id)) '„${s.titel}"'];
  final b = StringBuffer('Wiki cmid $cmid: ${w.seiten.length} Seiten, gelesen nach ${ordner.path} '
      '(seite-<pageid>.html: die Ansicht, Verweise als Links; zum Schreiben [[Titel]] für Verweise)\n');
  for (final s in w.seiten) {
    b.writeln('  ${s.id} „${s.titel}"${s.id == w.startId ? ' (Startseite)' : ''}: ${s.text.length} Zeichen -- '
        '${s.text.length > 100 ? '${s.text.substring(0, 100)}…' : s.text}');
  }
  if (tot.isNotEmpty) b.writeln('Tote Verweise (führen zu HTTP 404): ${tot.join('; ')}');
  if (fehlend.isNotEmpty) b.writeln('Verweise auf nie angelegte Seiten: ${fehlend.join('; ')}');
  if (verwaist.isNotEmpty) b.writeln('Verwaist (niemand verweist darauf): ${verwaist.join(', ')}');
  return b.toString();
}

String _norm(String html) =>
    (html_parser.parseFragment(html.replaceAll('[[', '').replaceAll(']]', '')).text ?? '').replaceAll(RegExp(r'\s+'), '');

/// Speichert den Inhalt einer Seite über edit.php (setzt und löst die Sperre).
Future<bool> _speichern(MoodleZugang moodle, int pageid, String html) async {
  final r = await moodle.lesen('/mod/wiki/edit.php?pageid=$pageid');
  final d = html_parser.parse(r.text);
  final form = d.querySelectorAll('form').where((f) => f.querySelector('[name="version"]') != null).firstOrNull;
  if (form == null) throw MoodleFehler('Kein Bearbeitungsformular für Seite $pageid -- von jemand anderem gesperrt?');
  final f = formularFelder(form);
  setze(f, 'newcontent_editor[text]', html);
  setze(f, 'newcontent_editor[format]', '1');
  final knopf = form.querySelector('#save') ??
      form.querySelectorAll('input, button').where((e) => e.attributes['name'] == 'editoption').firstOrNull;
  f.add(MapEntry('editoption', knopf?.attributes['value'] ?? 'Speichern'));
  final ziel = r.adresse.resolve(form.attributes['action'] ?? '/mod/wiki/edit.php');
  await moodle.senden(ziel.hasQuery ? '${ziel.path}?${ziel.query}' : ziel.path, f);
  final v = html_parser.parse((await moodle.lesen('/mod/wiki/view.php?pageid=$pageid')).text);
  final box = v.querySelector('#region-main .generalbox .no-overflow');
  for (final e in box?.querySelectorAll('.wiki-toc, a.wiki_edit_section, a[name^="toc-"]') ?? const <dom.Element>[]) {
    e.remove();
  }
  return box != null && _norm(box.innerHtml) == _norm(html);
}

Future<String> wikiseiteSchreiben(MoodleZugang moodle, Freigaben freigaben,
    {required int cmid, required String titel, required String datei, required String arbeitsordner}) async {
  // Erst das Wiki prüfen, dann die Datei: Ein persönliches Wiki oder eines
  // im Gruppenmodus sperrt, ehe etwas anderes zählt.
  final f0 = await formularHolen(moodle, '/course/modedit.php?update=$cmid');
  final w = await _wiki(moodle, cmid, mitInhalt: true, einstellungen: f0);
  final html = await dateiAusArbeitsordner(datei, arbeitsordner);
  formelnPruefen({p.basenameWithoutExtension(datei): html});
  final vorhanden = w.seiten.where((s) => s.titel == titel.trim()).firstOrNull;
  final kurs = f0.kurs;
  final wo = 'Wiki „${f0.name}" (cmid $cmid${kurs == null ? '' : ', ${await kursBezeichnung(moodle, kurs)}'})';
  final sichtbar = kurs == null ? true : ((await kursLesen(moodle, kurs)).nachCmid[cmid]?.sichtbar ?? true);

  if (vorhanden != null) {
    final v = zeilenVergleich(vorhanden.text, (html_parser.parseFragment(html).text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim());
    final ja = await freigaben.anfragen(FreigabeAnfrage(
      titel: 'Wikiseite überschreiben?',
      punkte: [
        'Seite „${vorhanden.titel}" in $wo',
        'Bisher ${vorhanden.text.length} Zeichen, neu ${html.length} Zeichen HTML. Der ganze Inhalt wird ersetzt -- '
            'auch was andere geschrieben haben.',
      ],
      vergleich: v.zeilen,
    ));
    if (!ja) return 'Nicht gespeichert: in der App abgelehnt oder nicht rechtzeitig freigegeben.';
    final ok = await _speichern(moodle, vorhanden.id, html);
    return 'Wikiseite „$titel" (pageid ${vorhanden.id}) gespeichert. verified: $ok';
  }

  if (w.startId == null && w.startTitel != null && w.startTitel != titel.trim()) {
    throw MoodleFehler('Die erste Seite muss „${w.startTitel}" heißen -- der Startseitentitel aus den Einstellungen.');
  }
  // Sichtbares Wiki: Die Seite erscheint sofort, Freigabe ab „mittel". In
  // einem verborgenen Wiki sieht sie niemand -- Freigabe erst bei „alle".
  final ja = await freigaben.anfragen(FreigabeAnfrage(
    titel: 'Wikiseite anlegen?',
    punkte: [
      'Neue Seite „$titel" in $wo',
      sichtbar
          ? 'Das Wiki ist für Lernende sichtbar -- die Seite erscheint SOFORT.'
          : 'Das Wiki ist für Lernende verborgen.',
      '${html.length} Zeichen HTML.',
    ],
    vergleich: const [],
    knopf: 'Anlegen',
    ohneEntscheidung: 'wird nichts angelegt',
    ab: sichtbar ? Bestaetigungen.mittel : Bestaetigungen.alle,
  ));
  if (!ja) return 'Nicht angelegt: in der App abgelehnt oder nicht rechtzeitig freigegeben.';
  final adresse = w.startId == null
      ? '/mod/wiki/view.php?id=$cmid'
      : '/mod/wiki/create.php?swid=${w.swid}&title=${Uri.encodeQueryComponent(titel.trim())}&action=new';
  if (w.startId != null && w.swid == null) throw MoodleFehler('Die Nummer des Wikis (swid) ist nicht zu ermitteln.');
  final r = await moodle.lesen(adresse);
  final d = html_parser.parse(r.text);
  final form = d.querySelectorAll('form').where((f) => f.querySelector('[name="pagetitle"]') != null).firstOrNull;
  if (form == null) throw MoodleFehler('Kein Erstellformular -- fehlt das Recht, Seiten anzulegen?');
  final f = formularFelder(form);
  setze(f, 'pagetitle', titel.trim());
  // Bei festgelegtem Format fehlt die Auswahl; dann gilt das Standardformat.
  if (form.querySelector('[name="pageformat"]') != null) setze(f, 'pageformat', 'html');
  f.add(const MapEntry('submitbutton', '1'));
  final ziel = r.adresse.resolve(form.attributes['action'] ?? '/mod/wiki/create.php');
  final a = await moodle.senden(ziel.hasQuery ? '${ziel.path}?${ziel.query}' : ziel.path, f);
  final neu = _pageid(moodle.umleitungsziel(a)?.toString());
  if (neu == null) {
    throw MoodleFehler('Nach dem Anlegen kam kein Bearbeitungsformular -- ist das Format festgelegt und nicht HTML?');
  }
  final ok = await _speichern(moodle, neu, html);
  return 'Wikiseite „$titel" angelegt (pageid $neu). verified: $ok';
}

Future<String> wikiseiteLoeschen(MoodleZugang moodle, Freigaben freigaben,
    {required int cmid, required int pageid, required String titel}) async {
  final f0 = await formularHolen(moodle, '/course/modedit.php?update=$cmid');
  final w = await _wiki(moodle, cmid, mitInhalt: true, einstellungen: f0);
  final s = w.seiten.where((x) => x.id == pageid).firstOrNull;
  if (s == null) throw MoodleFehler('Seite $pageid gibt es in diesem Wiki nicht.');
  nameBestaetigen(titel, s.titel, 'Seite $pageid');
  if (pageid == w.startId) throw MoodleFehler('Die Startseite wird nicht gelöscht -- ohne sie ist das Wiki leer.');
  final verweisen = [for (final x in w.seiten) if (x.verweise.any((v) => v.$1 == pageid)) '„${x.titel}"'];
  final ja = await freigaben.anfragen(FreigabeAnfrage(
    titel: 'Wikiseite endgültig löschen?',
    punkte: [
      'Seite „${s.titel}" im Wiki cmid $cmid (${s.text.length} Zeichen)',
      if (verweisen.isNotEmpty)
        'Darauf verweisen ${verweisen.join(', ')} -- diese Verweise führen danach vorübergehend auf eine Fehlerseite.',
    ],
    vergleich: const [],
    knopf: 'Löschen',
  ));
  if (!ja) return 'Nicht gelöscht: in der App abgelehnt oder nicht rechtzeitig freigegeben.';
  final sk = await moodle.sesskey();
  await moodle.aufrufen('/mod/wiki/admin.php?pageid=${w.startId}&delete=$pageid&option=1&listall=1&sesskey=$sk');
  final nach = await _wiki(moodle, cmid, einstellungen: f0);
  final weg = !nach.seiten.any((x) => x.id == pageid);
  return '${weg ? 'Gelöscht' : 'NOCH DA'}: „${s.titel}". verified: $weg'
      '${verweisen.isEmpty ? '' : '\nVerweise darauf gleich richtigstellen (entfernen oder als [[Titel]] schreiben): ${verweisen.join(', ')}'}';
}
