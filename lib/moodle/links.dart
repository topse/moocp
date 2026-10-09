// Die Links zwischen den Aktivitäten eines Abschnitts setzen: Werkzeug
// links_setzen.
//
// Innerhalb einer Lernsituation ist jeder Verweis auf ein anderes Blatt ein
// Link mit der Kennung als Text („Infoblatt 1"), in der Materialübersicht mit
// dem ganzen Namen (A8 der Projekt-CLAUDE.md). Setzen lässt sich das erst,
// wenn jede Aktivität ihre Nummer hat; nach einer Kopie zeigen die Links
// weiter auf das Original. Beides ist mechanisch, deshalb macht es die App
// und nicht das Modell Seite für Seite: kein HTML durch den Kontext, keine
// übersehene Nennung. Und die App sichert zu, was beim Bearbeiten von Hand
// niemand zusichert: Der sichtbare Text jeder Seite bleibt Zeichen für
// Zeichen gleich, es kommen nur Links auf Aktivitäten dieses Abschnitts dazu
// ([nurLinksGeaendert]). Geschrieben wird über aendernMehrere: eine Freigabe
// mit Zeilenvergleich, Standprüfung, Rückleseprobe.
//
// Die Kennung ist der Namensanfang vor dem ersten Doppelpunkt, wenn er mit
// einem Buchstaben beginnt und auf eine Zahl endet („Arbeitsblatt 1", „Hilfe
// zu Arbeitsblatt 3", „Lösung zu Arbeitsblatt 2", „Station 4"). So braucht
// die App kein Vokabular der Lernsituation, und ein Name wie „Test:
// Grundlagen" macht nicht jedes Wort „Test" zum Link. Ein Textfeld hat keine
// eigene Seite (sein view.php leitet auf den Kurs) und ist kein Ziel.
//
// Gearbeitet wird am Quelltext, nicht an einem DOM: Neu serialisiert sähe
// jede Seite im Zeilenvergleich geändert aus (Anführungszeichen, Entities),
// und in der Freigabe soll genau das stehen, was sich ändert.

import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

import '../freigabe.dart';
import 'buch.dart';
import 'formeln.dart';
import 'formular_lesen.dart';
import 'formular_schreiben.dart';
import 'kurs.dart';
import 'moodle_zugang.dart';

/// Eine Aktivität des Abschnitts.
class LinkZiel {
  LinkZiel(this.cmid, this.modul, this.name);
  final int cmid;
  final String modul;
  final String name;
  late final String? kennung = kennungAus(name);

  /// Ob man hinverlinken kann: Ein Textfeld hat keine eigene Seite, ein
  /// Unterabschnitt ist ein Abschnitt.
  bool get hatSeite => modul != 'label' && modul != 'subsection';
}

final _kennungForm = RegExp(r'^\p{L}.*\d$', unicode: true);

/// „Arbeitsblatt 1: Der Auftrag" -> „Arbeitsblatt 1"; null, wenn der Name
/// keine Kennung hat.
String? kennungAus(String name) {
  final i = name.indexOf(':');
  if (i <= 0) return null;
  final k = nameNormal(name.substring(0, i));
  return _kennungForm.hasMatch(k) ? k : null;
}

/// Absolut und in dieser Form, sonst erkennt die Auswertung beim Lesen den
/// Link nicht als Verweis auf eine Aktivität (auswertung.dart).
String linkAdresse(Uri basis, LinkZiel z) =>
    basis.replace(path: '/mod/${z.modul}/view.php', query: 'id=${z.cmid}').toString();

/// Was [verlinken] an einem Feld getan hat.
class Verlinkung {
  Verlinkung(this.html);
  String html;

  /// Texte der neuen Links.
  final List<String> neu = [];

  /// Texte der Links, die jetzt auf das Gegenstück im Abschnitt zeigen.
  final List<String> umgestellt = [];

  /// Was nicht verlinkt oder nicht geändert wurde und angesehen werden sollte.
  final Set<String> hinweise = {};

  bool get geaendert => neu.isNotEmpty || umgestellt.isNotEmpty;
}

// Die SchuCu-Tabelle steht nur nach Vorlage (E10); ein Feld mit ihr bleibt,
// wie es ist.
final _schucu = RegExp(r'''<table\b[^>]*\bclass\s*=\s*["'][^"']*\blernsituation\b''', caseSensitive: false);
final _anker = RegExp(r'<a\b([^>]*)>([\s\S]*?)</a\s*>', caseSensitive: false);
final _href = RegExp(r'''\bhref\s*=\s*(["'])(.*?)\1''', caseSensitive: false, dotAll: true);
final _zelle = RegExp(r'(<t([dh])\b[^>]*>)([^<]*)(</t\2\s*>)', caseSensitive: false);
final _tag = RegExp(r'<!--[\s\S]*?-->|<[^>]*>');
final _tagName = RegExp(r'^<\s*(/?)\s*([a-zA-Z][\w-]*)');

/// Leerraum im Quelltext, auch als Entity.
const _leer = r'(?:\s|&nbsp;|&#0*160;|&#[xX]0*[aA]0;)+';

/// Anführungszeichen vor und hinter dem Namen einer Aktivität ohne Kennung,
/// wie Lehrkräfte und Editoren sie schreiben: „…“, „…", "…", »…«, auch als
/// Entity.
const _auf = r'(?:„|“|"|»|&bdquo;|&ldquo;|&quot;|&raquo;|&#0*822[02];|&#[xX]0*201[cCeE];|&#0*34;|&#0*187;)';
const _zu = r'(?:“|”|"|«|&ldquo;|&rdquo;|&quot;|&laquo;|&#0*822[01];|&#[xX]0*201[cCdD];|&#0*34;|&#0*171;)';

String _klartext(String html) => nameNormal(html_parser.parseFragment(html).text ?? '');

/// Die cmid, wenn [href] auf eine Aktivität dieser Moodle-Instanz zeigt.
int? _aktivitaetIn(String href, Uri basis) {
  try {
    final u = Uri.parse(href.replaceAll('&amp;', '&').trim());
    if (u.hasAuthority ? u.host != basis.host : !u.path.startsWith('/')) return null;
    if (!RegExp(r'^/mod/\w+/view\.php$').hasMatch(u.path)) return null;
    return int.tryParse(u.queryParameters['id'] ?? '');
  } on FormatException {
    return null;
  }
}

/// Ein Zeichen, wie es im Quelltext stehen kann: selbst oder als Entity.
String _zeichenMuster(int r) {
  final c = String.fromCharCode(r);
  if (RegExp(r'[A-Za-z0-9]').hasMatch(c)) return c;
  final hex = r.toRadixString(16);
  final benannt = switch (c) {
    '&' => '&amp;|',
    '<' => '&lt;|',
    '>' => '&gt;|',
    '"' => '&quot;|',
    "'" => '&apos;|',
    'ä' => '&auml;|',
    'ö' => '&ouml;|',
    'ü' => '&uuml;|',
    'Ä' => '&Auml;|',
    'Ö' => '&Ouml;|',
    'Ü' => '&Uuml;|',
    'ß' => '&szlig;|',
    _ => '',
  };
  // ASCII-Satzzeichen als \xHH: Im Unicode-Modus ist ein Backslash vor einem
  // Zeichen ohne Bedeutung ein Fehler.
  final selbst = r < 128 ? '\\x${hex.padLeft(2, '0')}' : c;
  return '(?:$benannt$selbst|&#0*$r;|&#[xX]0*(?:${hex.toLowerCase()}|${hex.toUpperCase()});)';
}

/// Ein Text als Muster für den Quelltext: Leerraum beliebig, auch als
/// Zeilenumbruch oder &nbsp;, Zeichen auch als Entity.
String _textMuster(String s) {
  final b = StringBuffer();
  var leer = false;
  for (final r in s.runes) {
    if (String.fromCharCode(r).trim().isEmpty) {
      if (!leer) b.write(_leer);
      leer = true;
    } else {
      leer = false;
      b.write(_zeichenMuster(r));
    }
  }
  return b.toString();
}

String gezaehlt(List<String> texte) {
  final n = <String, int>{};
  for (final t in texte) {
    n[t] = (n[t] ?? 0) + 1;
  }
  return [for (final e in n.entries) e.value > 1 ? '${e.key} (${e.value}×)' : e.key].join(', ');
}

/// Setzt in einem Feld die Links auf die Aktivitäten [ziele] des Abschnitts.
///
/// [eigen] ist die Aktivität, zu der das Feld gehört -- ihre eigene Kennung
/// bleibt Text. [fuerLernende]: Die Seite ist für Lernende erreichbar; dann
/// wird nichts verlinkt, das nach Lösung klingt.
///
/// In dieser Reihenfolge:
///   1. Links, deren Text Kennung oder Name einer Aktivität hier ist, die aber
///      auf eine Aktivität außerhalb zeigen (nach einer Kopie), zeigen danach
///      auf das Gegenstück. Zeigt ein solcher Link auf eine andere Aktivität
///      im Abschnitt, stimmt Text oder Ziel nicht -- welches, weiß nur, wer
///      die Seite kennt: ein Hinweis, keine Änderung.
///   2. Eine Tabellenzelle, die genau den ganzen Namen enthält, wird ein Link
///      mit dem ganzen Namen (Materialübersicht).
///   3. Jede Nennung einer Kennung im Text wird ein Link mit genau diesem
///      Text, außer in Links. Gesucht wird nach allen Stämmen der Kennungen
///      („Hilfe zu Arbeitsblatt") mit einer Zahl dahinter, der längste
///      zuerst: So wird „Hilfe zu Arbeitsblatt 1" nie als „Arbeitsblatt 1"
///      verlinkt, „Arbeitsblatt 1" trifft nie „Arbeitsblatt 12", und eine
///      Nennung ohne Aktivität („Arbeitsblatt 5") fällt als Hinweis auf.
///      Eine Aktivität ohne Kennung -- Board, Wiki, Test einer Lernsituation
///      -- wird mit ihrem ganzen Namen in Anführungszeichen genannt („an die
///      Pinnwand „Unsere Aufteilung""), und genau diese Nennung wird ein
///      Link; die Anführungszeichen bleiben davor und dahinter. Nur in
///      Anführungszeichen: Ein Test namens „Test" machte sonst jedes Wort
///      „Test" zum Link. Beides sucht ein Muster, damit eine Kennung in einem
///      zitierten Namen nicht noch einmal verlinkt wird.
Verlinkung verlinken(String html,
    {required List<LinkZiel> ziele, required Uri basis, int? eigen, bool fuerLernende = false}) {
  final v = Verlinkung(html);
  if (_schucu.hasMatch(html)) return v;
  final nachKennung = <String, List<LinkZiel>>{};
  final nachName = <String, List<LinkZiel>>{};
  for (final z in ziele.where((z) => z.hatSeite && z.kennung != null)) {
    nachKennung.putIfAbsent(z.kennung!, () => []).add(z);
    nachName.putIfAbsent(nameNormal(z.name), () => []).add(z);
  }
  final imAbschnitt = {for (final z in ziele) z.cmid: z};
  // Aktivitäten ohne Kennung, nach ihrem ganzen Namen.
  final vollnamen = <String, List<LinkZiel>>{};
  for (final z in ziele.where((z) => z.hatSeite && z.kennung == null && nameNormal(z.name).isNotEmpty)) {
    vollnamen.putIfAbsent(nameNormal(z.name), () => []).add(z);
  }

  // Das eine Ziel zu einem Text, oder null -- mit Hinweis, wenn es einen
  // Grund gibt, den jemand wissen muss.
  LinkZiel? waehle(String text, List<LinkZiel> liste) {
    if (liste.length > 1) {
      v.hinweise.add('„$text" ist mehrdeutig (${[for (final z in liste) 'cm ${z.cmid} „${z.name}"'].join(', ')}) '
          '-- nicht verlinkt');
      return null;
    }
    final z = liste.single;
    if (z.cmid == eigen) return null;
    if (fuerLernende && loesungVerdacht.hasMatch(z.name)) {
      v.hinweise.add('„$text": Die Seite ist für Lernende erreichbar, und „${z.name}" klingt nach Lösung '
          '-- nicht verlinkt');
      return null;
    }
    return z;
  }

  // 1. Links auf Aktivitäten außerhalb umstellen.
  v.html = v.html.replaceAllMapped(_anker, (m) {
    final s = m.group(0)!;
    final h = _href.firstMatch(m.group(1)!);
    final cmid = h == null ? null : _aktivitaetIn(h.group(2)!, basis);
    if (cmid == null) return s;
    final text = _klartext(m.group(2)!);
    final liste = nachKennung[text] ?? nachName[text] ?? vollnamen[text];
    if (liste == null) return s;
    final jetzt = imAbschnitt[cmid];
    if (jetzt != null) {
      if (!liste.any((z) => z.cmid == cmid)) {
        v.hinweise.add('Link „$text" zeigt auf „${jetzt.name}" -- Text oder Ziel stimmt nicht, nicht geändert');
      }
      return s;
    }
    final z = waehle(text, liste);
    if (z == null) return s;
    v.umgestellt.add(text);
    // Gruppe 1 beginnt direkt hinter „<a".
    return s.replaceRange(2 + h!.start, 2 + h.end, 'href="${linkAdresse(basis, z)}"');
  });

  // 2. Zellen mit dem ganzen Namen.
  v.html = v.html.replaceAllMapped(_zelle, (m) {
    final innen = m.group(3)!;
    final text = _klartext(innen);
    final liste = nachName[text];
    if (liste == null) return m.group(0)!;
    final z = waehle(text, liste);
    if (z == null) return m.group(0)!;
    final r = RegExp(r'^(\s*)([\s\S]*?)(\s*)$').firstMatch(innen)!;
    v.neu.add(text);
    return '${m.group(1)}${r.group(1)}<a href="${linkAdresse(basis, z)}">${r.group(2)}</a>${r.group(3)}${m.group(4)}';
  });

  // 3. Nennungen im Text: ein Name in Anführungszeichen (Gruppen 1 bis 3)
  // oder eine Kennung.
  if (nachKennung.isEmpty && vollnamen.isEmpty) return v;
  final staemme = {for (final k in nachKennung.keys) k.replaceFirst(RegExp(r'\s*\d+$'), '')}.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final namen = vollnamen.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  final nennung = RegExp(
      [
        if (namen.isNotEmpty) '($_auf)(${namen.map(_textMuster).join('|')})($_zu)',
        if (staemme.isNotEmpty)
          '(?<![\\p{L}\\p{N}])(?:${staemme.map(_textMuster).join('|')})(?:$_leer)?\\d+(?![\\p{L}\\p{N}])',
      ].join('|'),
      unicode: true);
  String verlinkeText(String t) => t.replaceAllMapped(nennung, (m) {
        if (namen.isNotEmpty && m.group(2) != null) {
          final text = _klartext(m.group(2)!);
          final z = waehle(text, vollnamen[text]!);
          if (z == null) return m.group(0)!;
          v.neu.add(text);
          return '${m.group(1)}<a href="${linkAdresse(basis, z)}">${m.group(2)}</a>${m.group(3)}';
        }
        final text = _klartext(m.group(0)!);
        final liste = nachKennung[text];
        if (liste == null) {
          v.hinweise.add('„$text" gibt es in diesem Abschnitt nicht -- nicht verlinkt');
          return m.group(0)!;
        }
        final z = waehle(text, liste);
        if (z == null) return m.group(0)!;
        v.neu.add(text);
        return '<a href="${linkAdresse(basis, z)}">${m.group(0)}</a>';
      });

  final aus = StringBuffer();
  var inLink = 0;
  String? roh; // script, style, textarea: kein Text zum Lesen
  var pos = 0;
  for (final t in _tag.allMatches(v.html)) {
    final text = v.html.substring(pos, t.start);
    aus.write(inLink > 0 || roh != null ? text : verlinkeText(text));
    final n = _tagName.firstMatch(t.group(0)!);
    if (n != null) {
      final zu = n.group(1) == '/', name = n.group(2)!.toLowerCase();
      if (roh != null) {
        if (zu && name == roh) roh = null;
      } else if (name == 'a') {
        inLink = zu ? (inLink > 0 ? inLink - 1 : 0) : inLink + 1;
      } else if (!zu && const {'script', 'style', 'textarea'}.contains(name)) {
        roh = name;
      }
    }
    aus.write(t.group(0));
    pos = t.end;
  }
  final rest = v.html.substring(pos);
  aus.write(inLink > 0 || roh != null ? rest : verlinkeText(rest));
  v.html = aus.toString();
  return v;
}

final _offenerAnker = RegExp(r'<a\b[^>]*>', caseSensitive: false);

/// Prüft, dass von [alt] zu [neu] nur Links dazugekommen sind oder ein neues
/// Ziel bekommen haben, und nur solche auf [erlaubt]. null, wenn ja; sonst,
/// was nicht stimmt. Das ist die Zusicherung von links_setzen an die
/// Lehrkraft: Der Text bleibt, wie er ist.
String? nurLinksGeaendert(String alt, String neu, Set<String> erlaubt) {
  final ohneLinks = RegExp(r'<a\b[^>]*>|</a\s*>', caseSensitive: false);
  if (alt.replaceAll(ohneLinks, '') != neu.replaceAll(ohneLinks, '')) {
    return 'der Text außerhalb der Links verändert';
  }
  final vorher = <String, int>{};
  for (final m in _offenerAnker.allMatches(alt)) {
    vorher[m.group(0)!] = (vorher[m.group(0)!] ?? 0) + 1;
  }
  var anzahl = 0;
  for (final m in _offenerAnker.allMatches(neu)) {
    anzahl++;
    final t = m.group(0)!;
    if ((vorher[t] ?? 0) > 0) {
      vorher[t] = vorher[t]! - 1;
      continue;
    }
    final href = _href.firstMatch(t)?.group(2);
    if (href == null || !erlaubt.contains(href)) return 'ein Link auf „$href" entstanden, das keine Aktivität dieses Abschnitts ist';
  }
  if (anzahl < _offenerAnker.allMatches(alt).length) return 'ein Link entfernt';
  return null;
}

// ---------------------------------------------------------------------------
// links_setzen
// ---------------------------------------------------------------------------

/// Typen, deren Text Links bekommt: Textseite, Textfeld, Aufgabe, Buch (je
/// Kapitel). Die übrigen haben höchstens eine Beschreibung.
const _quellen = {'page', 'label', 'assign', 'book'};

/// Liest einen Abschnitt samt Unterabschnitten frisch, setzt die Links
/// ([verlinken]) und schreibt die geänderten Seiten mit einer Freigabe
/// (aendernMehrere). [auslassen]: cmids, deren Seiten unberührt bleiben.
Future<String> linksSetzen(MoodleZugang moodle, Freigaben freigaben,
    {required int kurs,
    required int abschnittId,
    Set<int> auslassen = const {},
    required String arbeitsordner}) async {
  final basis = moodle.basis;
  if (basis == null) throw MoodleFehler('Nicht angemeldet -- bitte in der App anmelden.');
  final k = await kursLesen(moodle, kurs);
  final abschnitt = k.nachId[abschnittId];
  if (abschnitt == null) {
    throw MoodleFehler('Abschnitt id $abschnittId gibt es in Kurs $kurs nicht (kurs_uebersicht).');
  }
  if (abschnitt.istUnterabschnitt) {
    throw MoodleFehler('„${abschnitt.titel}" ist ein Unterabschnitt. Den Abschnitt nennen, in dem er '
        'liegt: Die Links gelten für einen Abschnitt samt Unterabschnitten.');
  }
  final inhalt = k.inhalt(abschnitt);
  final fremd = auslassen.difference({for (final c in inhalt) c.cmid});
  if (fremd.isNotEmpty) {
    throw MoodleFehler('auslassen: cm ${fremd.join(", ")} liegt nicht in „${abschnitt.titel}". Nichts geändert.');
  }
  final ziele = [for (final c in inhalt) LinkZiel(c.cmid, c.modul, c.name)];
  final erlaubt = {for (final z in ziele) if (z.hatSeite) linkAdresse(basis, z)};

  // Erst alles lesen und verlinken, dann schreiben: Bricht es unterwegs ab,
  // ist kein Ordner halb bearbeitet.
  final dateien = <String, String>{}; // Datei -> neuer Quelltext
  final anmerkungen = <String, String>{}; // Ordner (relativ) -> was sich ändert
  final zeilen = <String>[], hinweise = <String>[];
  // Formelfehler in einer Seite, die geschrieben würde: Wie bei aendern wird
  // dann nichts geschrieben (formeln.dart), auch wenn der Fehler schon in
  // Moodle stand.
  final formelFehlerListe = <String>[];
  var gelesen = 0;
  for (final c in inhalt) {
    if (!_quellen.contains(c.modul) || auslassen.contains(c.cmid)) continue;
    final List<Formularziel> formulare;
    if (c.modul == 'book') {
      try {
        formulare = [for (final kap in await kapitelLesen(moodle, c.cmid)) Formularziel.buchkapitel(c.cmid, kap.id)];
      } on MoodleFehler catch (x) {
        hinweise.add('„${c.name}": Kapitel nicht lesbar (${x.meldung}) -- nicht verlinkt');
        continue;
      }
    } else {
      formulare = [Formularziel.aktivitaet(c.cmid)];
    }
    for (final z in formulare) {
      final g = await formularLesen(moodle, z, arbeitsordner);
      gelesen++;
      final seite = z.art == Zielart.buchkapitel ? '„${c.name}", Kapitel „${g.name}"' : '„${c.name}"';
      final neu = <String>[], umgestellt = <String>[];
      for (final f in g.felder) {
        final v = verlinken(f.html,
            ziele: ziele, basis: basis, eigen: c.cmid, fuerLernende: c.sichtbarkeit.erreichbar);
        hinweise.addAll([for (final h in v.hinweise) '$seite: $h']);
        if (!v.geaendert) continue;
        final fehler = nurLinksGeaendert(f.html, v.html, erlaubt);
        if (fehler != null) {
          throw MoodleFehler('Abgebrochen, nichts geändert: Beim Verlinken von $seite (${f.feld}) wäre '
              '$fehler. Das ist ein Fehler der App.');
        }
        dateien[p.join(g.ordner, '${f.feld}.html')] = v.html;
        formelFehlerListe.addAll([for (final x in formelFehler(v.html)) '$seite (${f.feld}): $x']);
        neu.addAll(v.neu);
        umgestellt.addAll(v.umgestellt);
      }
      if (neu.isEmpty && umgestellt.isEmpty) continue;
      final o = p.relative(g.ordner, from: arbeitsordner);
      anmerkungen[o] = [
        if (neu.isNotEmpty) '${neu.length} Link(s) neu: ${gezaehlt(neu)}',
        if (umgestellt.isNotEmpty) '${umgestellt.length} umgestellt: ${gezaehlt(umgestellt)}',
      ].join('; ');
      zeilen.add('  $seite ($o): ${anmerkungen[o]}');
    }
  }
  if (formelFehlerListe.isNotEmpty) {
    throw MoodleFehler('Abgebrochen, nichts geändert: Seiten, die verlinkt würden, haben Formelfehler.\n'
        '${formelFehlerListe.map((f) => '  - $f').join('\n')}\n'
        'Erst mit aendern reparieren (Skill: references/html.md, „Formeln"), dann links_setzen erneut.');
  }

  final kopf = 'Links in Abschnitt „${abschnitt.titel}" (${await kursBezeichnung(moodle, kurs)}): '
      '$gelesen Seite(n) gelesen, ${anmerkungen.length} mit neuen oder umgestellten Links.';
  final nachsehen = [
    if (hinweise.isNotEmpty) 'Nicht verlinkt oder nicht geändert -- ansehen:',
    for (final h in hinweise) '  $h',
  ];
  if (anmerkungen.isEmpty) {
    return [kopf, 'Nichts zu tun, keine Freigabe.', ...nachsehen].join('\n');
  }

  for (final e in dateien.entries) {
    await File(e.key).writeAsString(e.value, encoding: utf8);
  }
  final String ergebnis;
  try {
    ergebnis = await aendernMehrere(moodle, freigaben,
        ordner: anmerkungen.keys.toList(),
        arbeitsordner: arbeitsordner,
        titel: 'Links setzen: ${anmerkungen.length} Seiten speichern?',
        vorspann: ['Nur Links: Der sichtbare Text jeder Seite bleibt Zeichen für Zeichen gleich '
            '(von der App geprüft).'],
        anmerkungen: anmerkungen,
        knapp: true);
  } finally {
    // Was nicht gespeichert ist, zeigt wieder den gelesenen Stand -- sonst
    // nähme ein späteres aendern an diesem Ordner die Links unbemerkt mit.
    // Gespeichertes ist schon neu gelesen, Ordner und .stand sind gleich.
    for (final o in anmerkungen.keys) {
      final ordner = p.join(arbeitsordner, o);
      final stand = felderIn(p.join(ordner, '.stand'));
      felderIn(ordner).forEach((feld, html) {
        if (stand[feld] != null && stand[feld] != html) {
          File(p.join(ordner, '$feld.html')).writeAsStringSync(stand[feld]!, encoding: utf8);
        }
      });
    }
  }
  return [kopf, ...zeilen, ...nachsehen, '', ergebnis].join('\n');
}
