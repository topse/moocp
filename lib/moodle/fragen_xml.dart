// Moodle-XML für Fragen: bauen (STACK, CodeRunner) und vor dem Import
// prüfen. Reine Funktionen ohne Moodle-Zugriff (test/fragen_xml_test.dart).
//
// Warum Bauhilfen, statt das XML frei schreiben zu lassen: Eine STACK-Frage
// hat rund 35 Pflichtelemente, von denen 30 in jeder Frage gleich sind. Wer
// sie von Hand tippt, vergisst irgendwann eines -- und der Import meldet das
// nicht, sondern legt die Frage halb an; die Darstellung bricht später an
// unerwarteter Stelle. Bei CodeRunner verweigert die Bauhilfe vier Fragen,
// die sonst still danebengehen.
//
// Warum die Prüfung vor dem Import: Anlegbar sind nur Typen, deren XML
// gemessen ist (von Hand angelegt, exportiert, eine EIGENE Frage danach
// geschrieben, importiert, erneut exportiert und verglichen, Vorschau
// angesehen) -- die Kerntypen und stack, coderunner, ddmatch, mtf, gapfill.
// Ein halber Import ist schwerer aufzuräumen als keiner: Enthält das XML
// einen anderen Typ, wird gar nichts hochgeladen.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'auswertung.dart';
import 'formeln.dart';
import 'moodle_zugang.dart';

// kernAnlegbar, zusatzAnlegbar und nurLesen gibt die Übersicht „Unterstützte
// Aktivitäten und Fragetypen" in README.md (Teil 1) wieder; dort im selben Zug
// nachziehen.

/// Kern-Fragetypen, die angelegt werden können.
const Set<String> kernAnlegbar = {
  'multichoice', 'truefalse', 'shortanswer', 'numerical', 'matching', 'match', 'essay', //
  'description', 'cloze', 'multianswer', 'gapselect', 'ddwtos', 'calculated', 'calculatedsimple',
  'calculatedmulti', 'randomsamatch', 'ordering',
};

/// Zusatztypen mit gemessenem XML.
const Set<String> zusatzAnlegbar = {'stack', 'coderunner', 'ddmatch', 'mtf', 'gapfill'};

/// Nur lesbar: brauchen Hintergrundgrafik und Pixelkoordinaten.
const Set<String> nurLesen = {'ddimageortext', 'ddmarker'};

/// CodeRunner-Prototypen, deren XML durchgemessen ist (10.09.2026). Andere
/// gehen wahrscheinlich genauso, sind aber nicht nachgesehen.
const Set<String> coderunnerGemessen = {'python3', 'java_method', 'nodejs', 'sql'};

/// STACK-Eingabetypen, die auf der Zielinstanz gemessen sind.
const Set<String> stackEingabetypen = {
  'algebraic', 'numerical', 'units', 'string', 'dropdown', 'radio', 'checkbox', 'matrix', //
  'boolean', 'equiv', 'textarea', 'notes',
};

String xEsc(Object? s) =>
    '${s ?? ''}'.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String xCd(Object? s) => '<![CDATA[${'${s ?? ''}'.replaceAll(']]>', ']]&gt;')}]]>';

/// Ein HTML-Feld. Dateien stehen INNERHALB des Feldelements hinter `<text>`
/// (gemessen am 19.09.2026 für questiontext: Der Import nimmt sie an, die
/// Vorschau liefert sie byte-genau über pluginfile.php aus).
String xHtml(String tag, Object? inhalt, [List<String> dateien = const []]) =>
    '    <$tag format="html"><text>${xCd(inhalt)}</text>'
    '${dateien.isEmpty ? '' : '\n${dateien.join('\n')}\n    '}</$tag>';

String _dateiElement(String name, List<int> bytes) =>
    '<file name="${xEsc(name)}" path="/" encoding="base64">${base64Encode(bytes)}</file>';

/// Eine Zeichnung für eine Frage: SVG als Datei im Feld, im Text
/// `<img src="@@PLUGINFILE@@/name.svg">`. Nicht als eingebetteter `<svg>`-Quelltext.
String zeichnungPruefen(String name, String svg) {
  if (!RegExp(r'^[a-z0-9][a-z0-9-]*\.svg$').hasMatch(name)) {
    return '$name: Dateiname nur aus Kleinbuchstaben, Ziffern und Bindestrichen, Endung .svg';
  }
  final s = svg.trim();
  if (!s.contains('<svg')) return '$name: keine SVG';
  if (!s.contains('xmlns="http://www.w3.org/2000/svg"')) return '$name: xmlns fehlt -- ohne zeigt der Browser nichts';
  if (!s.contains('<title') || !s.contains('<desc')) return '$name: <title> und <desc> sind Pflicht';
  if (RegExp('<script', caseSensitive: false).hasMatch(s)) return '$name: kein <script> in einer Zeichnung';
  if (RegExp(r'https?://', caseSensitive: false).hasMatch(s.replaceAll(RegExp(r'xmlns(:[a-z]+)?="[^"]*"'), ''))) {
    return '$name: externer Verweis -- Webfonts und fremde Bilder fehlen irgendwann';
  }
  return '';
}

Map<String, Object?> _map(Object? o, String wo) {
  if (o == null) return const {};
  if (o is! Map) throw MoodleFehler('$wo muss ein Objekt sein.');
  return o.cast<String, Object?>();
}

List<Map<String, Object?>> _liste(Object? o, String wo) {
  if (o == null) return const [];
  if (o is! List) throw MoodleFehler('$wo muss eine Liste sein.');
  return [for (final (i, x) in o.indexed) _map(x, '$wo[$i]')];
}

String _t(Map m, String k, [String standard = '']) => m[k] == null ? standard : '${m[k]}';

// ---------------------------------------------------------------------------
// STACK
// ---------------------------------------------------------------------------

/// Anzeigeoptionen, die in JEDER STACK-Frage stehen müssen. Fehlt eines, legt
/// Moodle die Frage mit leeren Werten an.
const List<(String, String)> _stackAnzeige = [
  ('questionsimplify', '1'), ('assumepositive', '0'), ('assumereal', '0'),
  ('prtcorrect', '<p>Richtig.</p>'), ('prtpartiallycorrect', '<p>Teilweise richtig.</p>'),
  ('prtincorrect', '<p>Noch nicht richtig.</p>'), ('decimals', ','), ('scientificnotation', '*10'),
  ('multiplicationsign', 'dot'), ('sqrtsign', '1'), ('complexno', 'i'), ('inversetrig', 'cos-1'),
  ('logicsymbol', 'lang'), ('matrixparens', '['), ('variantsselectionseed', ''),
];
const Set<String> _stackAnzeigeHtml = {'prtcorrect', 'prtpartiallycorrect', 'prtincorrect'};

/// Vorgaben je Eingabefeld. forbidfloat steht bewusst auf 0: Der Standard 1
/// weist ausgerechnet die Dezimalzahl zurück, die man im Unterricht erwartet.
const List<(String, String)> _stackEingabe = [
  ('boxsize', '15'), ('strictsyntax', '1'), ('insertstars', '0'), ('syntaxhint', ''),
  ('syntaxattribute', '0'), ('forbidwords', ''), ('allowwords', ''), ('forbidfloat', '0'),
  ('requirelowestterms', '0'), ('checkanswertype', '0'), ('mustverify', '0'),
  ('showvalidation', '1'), ('options', ''),
];

/// STACK zählt Knoten an drei Stellen verschieden (gemessen): Beschriftung
/// „Knoten 1" und Antwortnotiz prt1-1-T 1-basiert, Formularindex und XML
/// `<node><name>` 0-basiert, nextnode 0-basiert mit -1 = Ende. Die Beschreibung
/// benutzt durchgehend die SICHTBARE Nummer; umgerechnet wird hier.
int _weiter(Object? w) {
  if (w == null || w == -1) return -1;
  final n = (w as num).toInt();
  if (n < 1) throw MoodleFehler('weiter ist die sichtbare Knotennummer (ab 1) oder -1 für Ende, nicht $n.');
  return n - 1;
}

/// Die Optionen einer Auswahlliste, wie sie in der Musterantwort stehen:
/// `[[kn,true],[kf,false]]` -> `[kn, kf]`. null, wenn dort keine wörtliche
/// Liste steht (ein Variablenname etwa) -- dann lässt sich nichts prüfen.
List<String>? _auswahlOptionen(String tans) {
  final s = tans.trim();
  if (!s.startsWith('[') || !s.endsWith(']')) return null;
  final aus = <String>[];
  for (final t in _obereEbene(s.substring(1, s.length - 1))) {
    final e = t.trim();
    if (!e.startsWith('[') || !e.endsWith(']')) return null;
    final felder = _obereEbene(e.substring(1, e.length - 1));
    if (felder.first.trim().isEmpty) return null;
    aus.add(felder.first.trim());
  }
  return aus.isEmpty ? null : aus;
}

/// Zerlegt an den Kommas der obersten Ebene; Klammern und Zeichenketten
/// bleiben zusammen.
List<String> _obereEbene(String s) {
  final aus = <String>[];
  var tiefe = 0, start = 0;
  String? anfuehrung;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (anfuehrung != null) {
      if (c == anfuehrung && s[i - 1] != '\\') anfuehrung = null;
    } else if (c == '"' || c == "'") {
      anfuehrung = c;
    } else if ('[({'.contains(c)) {
      tiefe++;
    } else if (']})'.contains(c)) {
      tiefe--;
    } else if (c == ',' && tiefe == 0) {
      aus.add(s.substring(start, i));
      start = i + 1;
    }
  }
  aus.add(s.substring(start));
  return aus;
}

/// Baut das XML einer STACK-Frage aus einer knappen Beschreibung (Aufbau wie
/// in der Skill-Referenz stack.md). [dateien] liefert die Bytes zu
/// zeichnungen[].name.
String stackXml(Map<String, Object?> o, {required String version, Map<String, List<int>> dateien = const {}}) {
  final name = _t(o, 'name'), fragetext = _t(o, 'fragetext');
  if (name.isEmpty) throw MoodleFehler('STACK: name fehlt.');
  if (fragetext.isEmpty) throw MoodleFehler('STACK: fragetext fehlt.');
  final eingaben = _liste(o['eingaben'], 'eingaben'), prts = _liste(o['prts'], 'prts');
  final tests = _liste(o['tests'], 'tests');
  if (eingaben.isEmpty) throw MoodleFehler('STACK: keine eingaben.');
  if (prts.isEmpty) throw MoodleFehler('STACK: keine prts.');
  // Ohne Testfälle ist die Frage zwar gültig, aber nicht überprüfbar -- und
  // dann fällt der ganze Vorteil von STACK weg.
  if (tests.isEmpty) throw MoodleFehler('STACK: keine tests. Ohne Testfälle keine STACK-Frage.');
  // Ohne [[input:name]] im Fragetext zeigt Moodle kein Eingabefeld -- der
  // häufigste Anfängerfehler, fällt sonst erst in der Vorschau auf.
  final fehlt = [for (final e in eingaben) if (!fragetext.contains('[[input:${_t(e, 'name')}]]')) _t(e, 'name')];
  if (fehlt.isNotEmpty) {
    throw MoodleFehler('STACK: Im Fragetext fehlen die Platzhalter ${fehlt.map((n) => '[[input:$n]]').join(', ')}.');
  }
  // Auswahllisten: Eine Testeingabe muss eine der Optionen sein, WIE SIE
  // DASTEHT -- STACK wertet sie nicht aus. Gemessen: Zur Option `4` fällt
  // der Testfall mit `3+1` durch, ohne dass ein Baum gerechnet wird, und ein
  // Testfall ist nachträglich nur in Moodle zu ändern. Deshalb hier, bevor
  // etwas hochgeladen ist. Geprüft wird nur gegen eine wörtliche
  // Optionsliste; `checkbox` bleibt außen vor, weil seine Testeingabe eine
  // Liste mehrerer Optionen ist (nicht gemessen).
  final auswahl = <String, List<String>>{};
  for (final e in eingaben) {
    if (!const ['dropdown', 'radio'].contains(_t(e, 'typ'))) continue;
    final o = _auswahlOptionen(_t(e, 'tans'));
    if (o != null) auswahl[_t(e, 'name')] = o;
  }
  String ohneLeer(String x) => x.replaceAll(RegExp(r'\s+'), '');
  for (final (i, t) in tests.indexed) {
    for (final e in _map(t['eingaben'], 'eingaben').entries) {
      final optionen = auswahl[e.key];
      final wert = '${e.value ?? ''}'.trim();
      if (optionen == null || wert.isEmpty) continue;
      if (optionen.any((x) => ohneLeer(x) == ohneLeer(wert))) continue;
      throw MoodleFehler('STACK „$name": Testfall ${i + 1}, Eingabe ${e.key}: „$wert" ist keine der '
          'Optionen (${optionen.join(", ")}). STACK wertet Testeingaben für Auswahllisten nicht aus -- der '
          'Wert muss dastehen wie in tans; sonst eine Hilfsvariable in den Aufgabenvariablen anlegen und '
          'die verwenden.');
    }
  }
  final spez = o['spezifischesFeedback'] != null
      ? _t(o, 'spezifischesFeedback')
      : prts.map((q) => '<p>[[feedback:${_t(q, 'name')}]]</p>').join('\n');
  final z = <String>[
    '  <question type="stack">',
    '    <name><text>${xEsc(name)}</text></name>',
    xHtml('questiontext', fragetext, _zeichnungen(o, dateien)),
    xHtml('generalfeedback', _t(o, 'allgemeinesFeedback')),
    '    <defaultgrade>${_t(o, 'punkte', '1')}</defaultgrade>',
    '    <penalty>${_t(o, 'strafe', '0.1')}</penalty>',
    '    <hidden>0</hidden>',
    '    <idnumber>${xEsc(_t(o, 'idnummer'))}</idnumber>',
    '    <stackversion><text>${xEsc(version)}</text></stackversion>',
    '    <questionvariables><text>${xEsc(_t(o, 'variablen'))}</text></questionvariables>',
    xHtml('specificfeedback', spez),
    xHtml('questionnote', _t(o, 'hinweis')),
    xHtml('questiondescription', _t(o, 'beschreibung')),
  ];
  final anzeige = _map(o['anzeige'], 'anzeige');
  for (final (k, standard) in _stackAnzeige) {
    final w = anzeige[k] == null ? standard : '${anzeige[k]}';
    z.add(_stackAnzeigeHtml.contains(k) ? xHtml(k, w) : '    <$k>${xEsc(w)}</$k>');
  }
  for (final e in eingaben) {
    final typ = _t(e, 'typ');
    if (_t(e, 'name').isEmpty || typ.isEmpty) throw MoodleFehler('STACK: Eingabe braucht name und typ.');
    if (!stackEingabetypen.contains(typ)) {
      throw MoodleFehler('STACK: Eingabetyp „$typ" unbekannt. Gemessen: ${stackEingabetypen.join(", ")}.');
    }
    z.add([
      '    <input>',
      '      <name>${xEsc(_t(e, 'name'))}</name>',
      '      <type>${xEsc(typ)}</type>',
      '      <tans>${xEsc(_t(e, 'tans'))}</tans>',
      for (final (k, standard) in _stackEingabe) '      <$k>${xEsc(e[k] == null ? standard : '${e[k]}')}</$k>',
      '    </input>',
    ].join('\n'));
  }
  final anteil = (1 / prts.length).toStringAsFixed(7);
  for (final q in prts) {
    final pn = _t(q, 'name');
    final knoten = _liste(q['knoten'], 'knoten');
    if (pn.isEmpty) throw MoodleFehler('STACK: PRT braucht einen name.');
    if (knoten.isEmpty) throw MoodleFehler('STACK: PRT $pn hat keine knoten.');
    z.addAll([
      '    <prt>',
      '      <name>${xEsc(pn)}</name>',
      '      <value>${_t(q, 'wert', anteil)}</value>',
      '      <autosimplify>${q['vereinfachen'] == false ? 0 : 1}</autosimplify>',
      '      <feedbackstyle>1</feedbackstyle>',
      '      <feedbackvariables><text>${xEsc(_t(q, 'feedbackvariablen'))}</text></feedbackvariables>',
    ]);
    for (final (i, k) in knoten.indexed) {
      final nr = (k['nr'] as num?)?.toInt() ?? i + 1;
      if (nr < 1) throw MoodleFehler('STACK: nr ist die sichtbare Knotennummer und beginnt bei 1, nicht $nr.');
      z.addAll([
        '      <node>',
        '        <name>${nr - 1}</name>',
        '        <description>${xEsc(_t(k, 'beschreibung'))}</description>',
        '        <answertest>${xEsc(_t(k, 'test', 'AlgEquiv'))}</answertest>',
        '        <sans>${xEsc(_t(k, 'sans'))}</sans>',
        '        <tans>${xEsc(_t(k, 'tans'))}</tans>',
        '        <testoptions>${xEsc(_t(k, 'optionen'))}</testoptions>',
        '        <quiet>${k['leise'] == true ? 1 : 0}</quiet>',
      ]);
      for (final (pre, v, kz) in [('true', _map(k['wahr'], 'wahr'), 'T'), ('false', _map(k['falsch'], 'falsch'), 'F')]) {
        z.addAll([
          '        <${pre}scoremode>=</${pre}scoremode>',
          '        <${pre}score>${_t(v, 'punkte', kz == 'T' ? '1' : '0')}</${pre}score>',
          '        <${pre}penalty></${pre}penalty>',
          '        <${pre}nextnode>${_weiter(v['weiter'])}</${pre}nextnode>',
          '        <${pre}answernote>${xEsc(_t(v, 'hinweis', '$pn-$nr-$kz'))}</${pre}answernote>',
          '        <${pre}feedback format="html"><text>${xCd(_t(v, 'feedback'))}</text></${pre}feedback>',
        ]);
      }
      z.add('      </node>');
    }
    z.add('    </prt>');
  }
  for (final (i, t) in tests.indexed) {
    z.addAll([
      '    <qtest>',
      '      <testcase>${i + 1}</testcase>',
      '      <description>${xEsc(_t(t, 'beschreibung'))}</description>',
      for (final e in _map(t['eingaben'], 'eingaben').entries)
        '      <testinput><name>${xEsc(e.key)}</name><value>${xEsc(e.value)}</value></testinput>',
      for (final e in _map(t['erwartet'], 'erwartet').entries)
        '      <expected><name>${xEsc(e.key)}</name>'
            '<expectedscore>${((_map(e.value, 'erwartet').cast()['punkte'] as num?) ?? 0).toStringAsFixed(7)}</expectedscore>'
            '<expectedpenalty>${((_map(e.value, 'erwartet').cast()['abzug'] as num?) ?? 0).toStringAsFixed(7)}</expectedpenalty>'
            '<expectedanswernote>${xEsc(_map(e.value, 'erwartet')['hinweis'])}</expectedanswernote></expected>',
      '    </qtest>',
    ]);
  }
  z.add('  </question>');
  return z.join('\n');
}

List<String> _zeichnungen(Map<String, Object?> o, Map<String, List<int>> dateien) {
  final aus = <String>[];
  for (final z in _liste(o['zeichnungen'], 'zeichnungen')) {
    final n = _t(z, 'name');
    final b = dateien[n];
    if (b == null) throw MoodleFehler('Zeichnung $n liegt nicht in dateien/.');
    final f = zeichnungPruefen(n, utf8.decode(b, allowMalformed: true));
    if (f.isNotEmpty) throw MoodleFehler('Zeichnung: $f');
    aus.add(_dateiElement(n, b));
  }
  return aus;
}

// ---------------------------------------------------------------------------
// CodeRunner
// ---------------------------------------------------------------------------

/// Baut das XML einer CodeRunner-Frage. Die Frage erbt fast alles vom
/// Prototyp (coderunnertype). Verweigert werden: ohne Musterlösung (dann
/// prüft auch das Formular nichts), ohne Testfall, ein Testfall ohne
/// erwartete Ausgabe, und sql ohne Datenbankdatei (jeder Lauf endet sonst mit
/// „No DB files found!"). prototypetype steht fest auf 0 -- eine Frage darf
/// nie zum Prototyp werden, der wirkte auf alle Fragen, die ihn nutzen --,
/// validateonsave fest auf 1.
String coderunnerXml(Map<String, Object?> o, {Map<String, List<int>> dateien = const {}}) {
  final name = _t(o, 'name'), typ = _t(o, 'typ');
  if (name.isEmpty) throw MoodleFehler('CodeRunner: name fehlt.');
  if (_t(o, 'fragetext').isEmpty) throw MoodleFehler('CodeRunner „$name": fragetext fehlt.');
  if (typ.isEmpty) throw MoodleFehler('CodeRunner „$name": typ (Prototyp, etwa python3) fehlt.');
  if (_t(o, 'musterloesung').isEmpty) {
    throw MoodleFehler('CodeRunner „$name": musterloesung fehlt. Ohne sie prüft auch das Formular nichts.');
  }
  final tests = _liste(o['tests'], 'tests');
  if (tests.isEmpty) throw MoodleFehler('CodeRunner „$name": keine tests.');
  final hilfsdateien = _liste(o['dateien'], 'dateien');
  if (typ.contains('sql') && !hilfsdateien.any((d) => _t(d, 'name').toLowerCase().endsWith('.db'))) {
    throw MoodleFehler('CodeRunner „$name": Der Typ $typ braucht eine SQLite-Datei als Hilfsdatei '
        '(dateien: [{"name": "….db"}], die Datei in dateien/).');
  }
  final z = <String>[
    '  <question type="coderunner">',
    '    <name><text>${xEsc(name)}</text></name>',
    xHtml('questiontext', o['fragetext'], _zeichnungen(o, dateien)),
    xHtml('generalfeedback', _t(o, 'allgemeinesFeedback')),
    '    <defaultgrade>${_t(o, 'punkte', '${tests.length}')}</defaultgrade>',
    '    <penalty>${_t(o, 'strafe', '0')}</penalty>',
    '    <hidden>0</hidden>',
    '    <idnumber>${xEsc(_t(o, 'idnummer'))}</idnumber>',
    '    <coderunnertype>${xEsc(typ)}</coderunnertype>',
    '    <prototypetype>0</prototypetype>',
    '    <allornothing>${o['allesOderNichts'] == false ? 0 : 1}</allornothing>',
    '    <penaltyregime>${xEsc(_t(o, 'strafregime', '10, 20, ...'))}</penaltyregime>',
    if (_t(o, 'vorgabe').isNotEmpty) '    <answerpreload>${xEsc(_t(o, 'vorgabe'))}</answerpreload>',
    '    <answer>${xEsc(_t(o, 'musterloesung'))}</answer>',
    '    <validateonsave>1</validateonsave>',
    '    <testcases>',
  ];
  for (final (i, t) in tests.indexed) {
    if (_t(t, 'code').isEmpty) {
      throw MoodleFehler('CodeRunner „$name": Testfall ${i + 1} hat keinen code -- das Formular verwirft leere.');
    }
    if (t['erwartet'] == null) {
      throw MoodleFehler('CodeRunner „$name": Testfall ${i + 1} hat kein erwartet -- ohne kann die Sandbox nichts bestätigen.');
    }
    z.addAll([
      '    <testcase testtype="${_t(t, 'art', '0')}" useasexample="${t['beispiel'] == true ? 1 : 0}" '
          'hiderestiffail="${t['versteckeRest'] == true ? 1 : 0}" mark="${((t['punkte'] as num?) ?? 1).toStringAsFixed(7)}" >',
      '      <testcode><text>${xEsc(_t(t, 'code'))}</text></testcode>',
      '      <stdin><text>${xEsc(_t(t, 'eingabe'))}</text></stdin>',
      '      <expected><text>${xEsc(_t(t, 'erwartet'))}</text></expected>',
      '      <extra><text>${xEsc(_t(t, 'zusatz'))}</text></extra>',
      '      <display><text>${_t(t, 'anzeige', 'SHOW')}</text></display>',
      '    </testcase>',
    ]);
  }
  // Hilfsdateien stehen INNERHALB von <testcases>, hinter dem letzten
  // </testcase> (gemessen an einem Export mit angehängter .db).
  for (final d in hilfsdateien) {
    final n = _t(d, 'name');
    final b = dateien[n];
    if (b == null) throw MoodleFehler('CodeRunner „$name": Hilfsdatei $n liegt nicht in dateien/.');
    z.add('    ${_dateiElement(n, b)}');
  }
  z.addAll(['    </testcases>', '  </question>']);
  return z.join('\n');
}

String quizXml(List<String> fragen) => '<?xml version="1.0" encoding="UTF-8"?>\n<quiz>\n${fragen.join('\n')}\n</quiz>\n';

// ---------------------------------------------------------------------------
// Prüfen vor dem Import
// ---------------------------------------------------------------------------

class FrageImXml {
  FrageImXml(this.typ, this.name, this.idnummer);
  final String typ;
  final String name;
  final String? idnummer;
}

/// Prüft ein Moodle-XML vor dem Import und bettet Dateien ein: Verweist ein
/// Textfeld auf `@@PLUGINFILE@@/<name>` und fehlt die Datei im Feld, kommt sie
/// aus [dateiordner] hinein (als `<file>` hinter `<text>`). Wirft bei allem, was
/// nicht angelegt werden soll; gibt das fertige XML und die Fragen zurück.
(String, List<FrageImXml>) fragenXmlPruefen(String xml, {String? dateiordner}) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(xml);
  } on XmlException catch (x) {
    throw MoodleFehler('Das XML ist nicht lesbar: ${x.message}');
  }
  final wurzel = doc.rootElement;
  if (wurzel.name.local != 'quiz') throw MoodleFehler('Moodle-XML beginnt mit <quiz>, nicht <${wurzel.name.local}>.');
  final fragen = <FrageImXml>[];
  final fehler = <String>[];
  for (final q in wurzel.findElements('question')) {
    final typ = q.getAttribute('type') ?? '';
    if (typ == 'category') continue;
    final name = q.getElement('name')?.getElement('text')?.innerText.trim() ?? '';
    final wer = '„$name" ($typ)';
    if (nurLesen.contains(typ)) {
      fehler.add('$wer: braucht Hintergrundgrafik und Koordinaten -- nur über die Oberfläche anlegbar');
    } else if (!kernAnlegbar.contains(typ) && !zusatzAnlegbar.contains(typ)) {
      fehler.add('$wer: Typ nicht anlegbar (XML nicht gemessen). Anlegbar: '
          '${[...kernAnlegbar, ...zusatzAnlegbar].join(", ")}');
    }
    if (name.isEmpty) fehler.add('Frage vom Typ $typ ohne <name>');
    // ordering braucht <shownumcorrect/>; fehlt es, bricht der Import mit
    // „Fehler beim Schreiben der Datenbank" ab. layouttype, selecttype,
    // gradingtype, showgrading wollen NAMEN, keine Zahlen -- sonst speichert
    // Moodle klaglos etwas anderes.
    if (typ == 'ordering') {
      if (q.getElement('shownumcorrect') == null) fehler.add('$wer: <shownumcorrect/> fehlt');
      for (final k in ['layouttype', 'selecttype', 'gradingtype', 'showgrading']) {
        final w = q.getElement(k)?.innerText.trim() ?? '';
        if (RegExp(r'^\d+$').hasMatch(w)) fehler.add('$wer: <$k> braucht einen Namen (etwa ALL, VERTICAL), keine Zahl');
      }
    }
    if (typ == 'coderunner') {
      if ((q.getElement('answer')?.innerText.trim() ?? '').isEmpty) fehler.add('$wer: Musterlösung <answer> fehlt');
      if (q.getElement('prototypetype')?.innerText.trim() != '0') fehler.add('$wer: <prototypetype> muss 0 sein');
      if (q.getElement('validateonsave')?.innerText.trim() != '1') fehler.add('$wer: <validateonsave> muss 1 sein');
      final tc = q.getElement('testcases')?.findElements('testcase').toList() ?? const [];
      if (tc.isEmpty) fehler.add('$wer: keine Testfälle');
      for (final t in tc) {
        if (t.getElement('expected') == null) fehler.add('$wer: ein Testfall ohne <expected>');
      }
    }
    if (typ == 'stack') {
      if (q.findElements('qtest').isEmpty) fehler.add('$wer: keine Testfälle (<qtest>) -- ohne keine STACK-Frage');
      final text = q.getElement('questiontext')?.getElement('text')?.innerText ?? '';
      for (final i in q.findElements('input')) {
        final n = i.getElement('name')?.innerText.trim() ?? '';
        if (!text.contains('[[input:$n]]')) fehler.add('$wer: Platzhalter [[input:$n]] fehlt im Fragetext');
      }
      for (final (k, _) in _stackAnzeige) {
        if (q.getElement(k) == null) fehler.add('$wer: Pflichtelement <$k> fehlt (stack_xml benutzen)');
      }
    }
    // Formeln in jedem HTML-Feld (formeln.dart), samt den Fallen einzelner
    // Typen. Gemessen in der Vorschau (01.10.2026); die Begründungen stehen im
    // Skill moodle-fragen, references/fragetypen.md, „Formeln in Fragen".
    for (final feld in q.descendantElements.where((e) => e.getAttribute('format') == 'html')) {
      final text = feld.getElement('text')?.innerText ?? '';
      for (final f in formelFehler(text)) {
        fehler.add('$wer, <${feld.name.local}>: $f');
      }
    }
    final fragetext = q.getElement('questiontext')?.getElement('text')?.innerText ?? '';
    if (typ == 'cloze' || typ == 'multianswer') {
      // In einer Lücke beendet „}" die Lücke und wird deshalb als „\}"
      // maskiert; ein maskiertes „\{" bleibt aber stehen und zerbricht die
      // Formel („Extra close brace or missing open brace").
      for (final m in RegExp(r'\{\d*:[A-Z_]+:((?:\\.|[^\\}])*)\}').allMatches(fragetext)) {
        if (m.group(1)!.contains(r'\{')) {
          fehler.add('$wer: In einer Lücke nur schließende Klammern maskieren (\\}), nicht \\{ -- '
              '„${m.group(0)!.length > 60 ? '${m.group(0)!.substring(0, 60)}…' : m.group(0)}"');
        }
      }
    }
    if (typ == 'gapfill') {
      // Steht auch nur ein <answer> im XML, leitet der Import keine Antworten
      // aus den Lücken ab; ohne richtige Antwort stürzt die Vorschau ab.
      final antworten = q.findElements('answer').toList();
      if (antworten.isNotEmpty &&
          !antworten.any((a) => (double.tryParse(a.getAttribute('fraction') ?? '') ?? 0) > 0)) {
        fehler.add('$wer: nur Ablenker, keine richtige Antwort. Entweder gar kein <answer> (die Lückenwörter '
            'werden dann die Antworten) oder jedes Lückenwort als <answer fraction="100">.');
      }
      // Die Lückenzeichen dürfen nichts mit LaTeX teilen: Mit [] wird
      // „\[ … \]" zur Lücke, {} sind LaTeX-Klammern.
      final zeichen = q.getElement('delimitchars')?.innerText.trim() ?? '[]';
      if (zeichen == '[]' && fragetext.contains(r'\[')) {
        fehler.add('$wer: Lückenzeichen [] und eine abgesetzte Formel \\[ … \\] -- die Formel würde zur Lücke. '
            '<delimitchars>@@</delimitchars> nehmen.');
      }
      if (zeichen == '{}' && RegExp(r'\\[(\[]').hasMatch(fragetext)) {
        fehler.add('$wer: Lückenzeichen {} und eine Formel -- LaTeX-Klammern würden zu Lücken. '
            '<delimitchars>@@</delimitchars> nehmen.');
      }
    }
    // Dateien einbetten, auf die ein Textfeld verweist.
    for (final feld in q.childElements.where((e) => e.getElement('text') != null)) {
      final text = feld.getElement('text')!.innerText;
      final vorhanden = {for (final f in feld.findElements('file')) f.getAttribute('name')};
      for (final m in RegExp(r'@@PLUGINFILE@@/([^"' "'" r'\s>?#]+)').allMatches(text)) {
        final n = entschluesselt(m.group(1)!);
        if (vorhanden.contains(n)) continue;
        final datei = dateiordner == null ? null : File(p.join(dateiordner, n));
        if (datei == null || !datei.existsSync()) {
          fehler.add('$wer: ${feld.name.local} verweist auf $n, die Datei fehlt (weder im XML noch in dateien/)');
          continue;
        }
        final bytes = datei.readAsBytesSync();
        if (n.toLowerCase().endsWith('.svg')) {
          final f = zeichnungPruefen(n, utf8.decode(bytes, allowMalformed: true));
          if (f.isNotEmpty) fehler.add('$wer: $f');
        }
        feld.children.add(XmlDocumentFragment.parse(_dateiElement(n, bytes)).firstElementChild!.copy());
        vorhanden.add(n);
      }
    }
    final idn = q.getElement('idnumber')?.innerText.trim();
    fragen.add(FrageImXml(typ, name, idn == null || idn.isEmpty ? null : idn));
  }
  if (fragen.isEmpty) fehler.add('Das XML enthält keine Frage.');
  final idns = [for (final f in fragen) if (f.idnummer != null) f.idnummer!];
  final doppelt = idns.where((i) => idns.where((x) => x == i).length > 1).toSet();
  if (doppelt.isNotEmpty) fehler.add('Sachnummer mehrfach: ${doppelt.join(", ")} (Moodle verlangt sie eindeutig je Kategorie)');
  if (fehler.isNotEmpty) {
    throw MoodleFehler('Nicht importiert, nichts hochgeladen:\n- ${fehler.join('\n- ')}');
  }
  return (doc.toXmlString(), fragen);
}

/// Eine Frage aus einem Moodle-XML-Export, knapp.
class FrageKurz {
  FrageKurz(this.id, this.idnummer, this.typ, this.name, this.punkte, this.text, this.antworten, this.richtig,
      this.verborgen);
  final int? id;
  final String? idnummer;
  final String typ;
  final String name;
  final String? punkte;
  final String text;
  final int antworten;
  final int richtig;
  final bool verborgen;

  String zeile() => '${id ?? '?'} [$typ] „$name"${idnummer == null ? '' : ' (Sachnummer $idnummer)'}'
      '${punkte == null ? '' : ', $punkte P.'}${antworten > 0 ? ', $antworten Antworten, $richtig richtig' : ''}'
      '${verborgen ? ' [verborgen]' : ''} -- $text';
}

/// Die Fragen eines Exports. Die questionid steht als Kommentar
/// <!-- question: 123 --> vor jedem Element. Der Export schreibt zwei Typen
/// anders als intern: matching (match) und cloze (multianswer).
List<FrageKurz> fragenAusXml(String xml) {
  final doc = XmlDocument.parse(xml);
  final aus = <FrageKurz>[];
  int? id;
  for (final n in doc.rootElement.children) {
    if (n is XmlComment) {
      id = int.tryParse(RegExp(r'question:\s*(\d+)').firstMatch(n.value)?.group(1) ?? '');
      continue;
    }
    if (n is! XmlElement || n.name.local != 'question') continue;
    final typ = n.getAttribute('type') ?? '';
    if (typ == 'category') {
      id = null;
      continue;
    }
    String? hol(String a, [String? b]) {
      final e = n.getElement(a);
      final t = b == null ? e?.innerText : e?.getElement(b)?.innerText;
      return t?.trim();
    }

    // Nur Antworten mit Bewertung: Bei CodeRunner heißt die Musterlösung auch <answer>.
    final antworten = n.findElements('answer').where((a) => a.getAttribute('fraction') != null).toList();
    final text = (hol('questiontext', 'text') ?? '').replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    aus.add(FrageKurz(
      id,
      (hol('idnumber') ?? '').isEmpty ? null : hol('idnumber'),
      const {'matching': 'match', 'cloze': 'multianswer'}[typ] ?? typ,
      hol('name', 'text') ?? '',
      hol('defaultgrade'),
      text.length > 120 ? '${text.substring(0, 120)}…' : text,
      antworten.length,
      antworten.where((a) => (double.tryParse(a.getAttribute('fraction') ?? '0') ?? 0) > 0).length,
      hol('hidden') == '1',
    ));
    id = null;
  }
  return aus;
}
