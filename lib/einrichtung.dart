// Einrichtung von Claude Code: die Verbindung zur App und die Skills.
//
// Damit Claude mit der App arbeitet, braucht Claude Code zweierlei: einen
// MCP-Eintrag „moodle" mit Adresse und Schlüssel dieser App, und die Skills in
// genau der Version, die zu dieser App gehört -- ändert sich ein Werkzeug,
// ändert sich der Skill mit. Beides prüft die App beim Start; geschrieben wird
// erst nach einem Klick im Dialog „Claude einrichten", wie bei den Freigaben.
// Beim Deinstallieren entfernt die App beides wieder ([einrichtungEntfernen]).
//
// Hier steht nur die Logik, ohne Oberfläche, damit sie sich an einem
// nachgebauten Ordnerbaum prüfen lässt (test/einrichtung_test.dart).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Die Skills, die die App mitbringt, liegen als Pakete von skills/build.py
/// unter diesem Asset-Pfad (pubspec.yaml).
const skillAssets = 'skills/dist/';

/// Skills, die die Lehrkraft im Dialog „Claude einrichten" wählt, mit dem
/// Satz, der dort dabeisteht. Alle anderen Skills der App sind immer dabei.
/// lernsituation ist für berufsbildende Schulen gebaut; anderswo stünde er
/// nur im Weg, denn seine Beschreibung zieht bei jedem „Arbeitsblatt".
const wahlSkills = {
  'lernsituation': 'Für berufsbildende Schulen: Lernsituationen mit SchuCu-Tabelle, Ablaufplan, Arbeits- '
      'und Informationsblättern entwerfen.',
};

/// Die gewählten Skills, solange die Lehrkraft noch nichts gewählt hat: die
/// wählbaren, die schon installiert sind. So entfernt ein Update nichts, was
/// jemand bisher benutzt hat; wer neu anfängt, hat keinen.
Set<String> gewaehltVorgabe(ClaudeOrte orte) => {
      for (final n in wahlSkills.keys)
        if (File(p.join(orte.skills.path, n, 'SKILL.md')).existsSync()) n,
    };

// ---------------------------------------------------------------------------
// Wo Claude Code liegt
// ---------------------------------------------------------------------------

// Claude Desktop gibt es als MSIX-Paket. Windows leitet dessen %APPDATA% in
// den Paketordner um: Was Claude Desktop unter %APPDATA%\Claude\claude-code
// ablegt, steht für jedes andere Programm unter
// %LOCALAPPDATA%\Packages\<Paket>\LocalCache\Roaming\Claude\claude-code.
// Der Paketname leitet sich aus Anthropics Signatur ab und ist auf allen
// Rechnern gleich; bewusst kein Platzhalter „Claude_*", der auch ein fremdes
// Paket träfe. Darunter liegt je Version ein Ordner (2.1.280, 2.1.281 …) --
// Claude Desktop lädt Claude Code nach und behält ältere Versionen.
const _claudeDesktopPaket = 'Claude_pzs8sxrjxfjjc';

/// Sucht die claude.exe: Claude Desktop (MSIX, dann klassischer Installer),
/// der Suchpfad, der eigenständige Installer, die VS-Code-Erweiterung --
/// jeweils die höchste Version. null, wenn nichts da ist.
String? claudeFinden(Map<String, String> umgebung) {
  String? v(String name) {
    final w = umgebung[name];
    return w == null || w.trim().isEmpty ? null : w;
  }

  final lokal = v('LOCALAPPDATA');
  final roaming = v('APPDATA');
  final heim = v('USERPROFILE');
  final kandidaten = <String?>[
    if (lokal != null)
      _neuesteVersion(p.join(lokal, 'Packages', _claudeDesktopPaket, 'LocalCache', 'Roaming', 'Claude', 'claude-code')),
    if (roaming != null) _neuesteVersion(p.join(roaming, 'Claude', 'claude-code')),
    for (final d in (v('PATH') ?? '').split(';'))
      if (d.trim().isNotEmpty) p.join(d.trim(), 'claude.exe'),
    if (heim != null) p.join(heim, '.local', 'bin', 'claude.exe'),
    if (heim != null) _vsCode(p.join(heim, '.vscode', 'extensions')),
  ];
  for (final k in kandidaten) {
    if (k != null && File(k).existsSync()) return k;
  }
  return null;
}

/// Vergleicht Versionsnummern Stelle für Stelle als Zahlen: 2.10 kommt nach
/// 2.9, anders als beim Textvergleich.
int versionVergleichen(List<int> a, List<int> b) {
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

List<int>? _version(String text) {
  final teile = text.split('.');
  final zahlen = teile.map(int.tryParse).toList();
  return zahlen.any((z) => z == null) ? null : zahlen.cast<int>();
}

String? _neuesteVersion(String ordner) {
  final d = Directory(ordner);
  if (!d.existsSync()) return null;
  (List<int>, String)? beste;
  for (final e in d.listSync().whereType<Directory>()) {
    final ver = _version(p.basename(e.path));
    final exe = p.join(e.path, 'claude.exe');
    if (ver == null || !File(exe).existsSync()) continue;
    if (beste == null || versionVergleichen(ver, beste.$1) > 0) beste = (ver, exe);
  }
  return beste?.$2;
}

// Die Erweiterung legt je Version einen Ordner
// anthropic.claude-code-<Version>-win32-x64 an, die claude.exe darin unter
// resources\native-binary.
String? _vsCode(String erweiterungen) {
  final d = Directory(erweiterungen);
  if (!d.existsSync()) return null;
  final muster = RegExp(r'^anthropic\.claude-code-([0-9.]+)-win32-');
  (List<int>, String)? beste;
  for (final e in d.listSync().whereType<Directory>()) {
    final m = muster.firstMatch(p.basename(e.path));
    final ver = m == null ? null : _version(m.group(1)!);
    final exe = p.join(e.path, 'resources', 'native-binary', 'claude.exe');
    if (ver == null || !File(exe).existsSync()) continue;
    if (beste == null || versionVergleichen(ver, beste.$1) > 0) beste = (ver, exe);
  }
  return beste?.$2;
}

/// Wo Claude Code seine Einstellungen und Skills hält. CLAUDE_CONFIG_DIR
/// verlegt beides; sonst liegen sie im Benutzerverzeichnis. MSIX leitet
/// diese Orte nicht um -- Claude Desktop und VS Code lesen dieselben.
class ClaudeOrte {
  ClaudeOrte(Map<String, String> umgebung)
      : _eigen = umgebung['CLAUDE_CONFIG_DIR'],
        _heim = umgebung['USERPROFILE'] ?? '';
  final String? _eigen;
  final String _heim;

  File get konfiguration => File(p.join(_eigen ?? _heim, '.claude.json'));
  Directory get skills => Directory(p.join(_eigen ?? p.join(_heim, '.claude'), 'skills'));
}

// ---------------------------------------------------------------------------
// Die Verbindung: der MCP-Eintrag „moodle"
// ---------------------------------------------------------------------------

enum Verbindung { aktuell, fehlt, veraltet, unlesbar }

String mcpAdresse(int port) => 'http://127.0.0.1:$port/mcp';

/// Liest den Eintrag „moodle" aus der Konfiguration von Claude Code. Nur
/// lesen: Die Datei gehört Claude Code und wird dort ständig neu geschrieben;
/// geschrieben wird nur über dessen Kommandozeile ([verbindungEintragen]).
Verbindung verbindungPruefen(File konfiguration, int port, String schluessel) {
  if (!konfiguration.existsSync()) return Verbindung.fehlt;
  try {
    final d = jsonDecode(konfiguration.readAsStringSync());
    final server = (d is Map) ? d['mcpServers'] : null;
    final e = (server is Map) ? server['moodle'] : null;
    if (e is! Map) return Verbindung.fehlt;
    final kopf = e['headers'] is Map ? (e['headers'] as Map)['Authorization'] : null;
    final passt = e['type'] == 'http' && e['url'] == mcpAdresse(port) && kopf == 'Bearer $schluessel';
    return passt ? Verbindung.aktuell : Verbindung.veraltet;
  } catch (_) {
    // Auch ein halb geschriebener Stand, wenn Claude Code gerade speichert.
    return Verbindung.unlesbar;
  }
}

/// Die Argumente für `claude mcp add`. Der Schlüssel steht darin -- sie gehen
/// an die claude.exe, nie in Protokoll oder Anzeige.
List<String> mcpAddArgumente(int port, String schluessel) => [
      'mcp', 'add', '--scope', 'user', '--transport', 'http', 'moodle', mcpAdresse(port), //
      '--header', 'Authorization: Bearer $schluessel',
    ];

/// Trägt die App in Claude Code ein: erst einen alten Eintrag „moodle"
/// entfernen (sonst scheitert `add` an „existiert schon", genau nach einem
/// neuen Schlüssel), dann neu eintragen. Liefert null bei Erfolg, sonst eine
/// Beschreibung -- nur mit Exit-Code, nie mit der Ausgabe, denn die kann den
/// Schlüssel enthalten.
Future<String?> verbindungEintragen(String claude, int port, String schluessel) async {
  // Fehlt der Eintrag, endet remove mit Fehler; das ist hier der Normalfall.
  await _ausfuehren(claude, ['mcp', 'remove', 'moodle', '--scope', 'user']);
  final code = await _ausfuehren(claude, mcpAddArgumente(port, schluessel));
  return code == 0 ? null : 'claude mcp add endete mit Code $code';
}

/// Startet ein Programm ohne Konsole und wartet höchstens eine Minute. Die
/// Ausgabe wird gelesen (sonst kann ein voller Puffer den Prozess anhalten)
/// und verworfen.
Future<int> _ausfuehren(String programm, List<String> argumente) async {
  final pr = await Process.start(programm, argumente);
  unawaited(pr.stdout.drain<void>());
  unawaited(pr.stderr.drain<void>());
  return pr.exitCode.timeout(const Duration(minutes: 1), onTimeout: () {
    pr.kill();
    return -1;
  });
}

// ---------------------------------------------------------------------------
// Die Skills
// ---------------------------------------------------------------------------

/// Ein Skill, wie ihn die App mitbringt: Name und Dateien (Pfad mit „/"
/// relativ zum Skill-Ordner, Inhalt).
class SkillPaket {
  SkillPaket(this.name, this.dateien);
  final String name;
  final Map<String, List<int>> dateien;

  /// Liest ein Paket von skills/build.py: ein ZIP mit dem Ordner `<name>/`.
  factory SkillPaket.ausZip(String name, List<int> zip) {
    final dateien = <String, List<int>>{};
    for (final f in ZipDecoder().decodeBytes(zip)) {
      if (!f.isFile || !f.name.startsWith('$name/')) continue;
      dateien[f.name.substring(name.length + 1)] = f.content;
    }
    return SkillPaket(name, dateien);
  }
}

class SkillStand {
  SkillStand({this.fehlend = 0, this.abweichend = 0, this.ueberzaehlig = 0, this.ordnerFehlt = false});
  final int fehlend;
  final int abweichend;
  final int ueberzaehlig;
  final bool ordnerFehlt;

  bool get aktuell => !ordnerFehlt && fehlend + abweichend + ueberzaehlig == 0;

  /// Für die Anzeige im Dialog, in Worten, die auch ohne Technikwissen
  /// verständlich sind -- ob eine Datei fehlt oder abweicht, ändert nichts
  /// daran, was zu tun ist.
  String get text {
    if (ordnerFehlt) return 'nicht installiert';
    if (aktuell) return 'aktuell';
    return 'muss aktualisiert werden';
  }
}

// Windows unterscheidet bei Pfaden nicht nach Groß- und Kleinschreibung.
String _schluessel(String rel) => rel.replaceAll('\\', '/').toLowerCase();

Map<String, File> _vorhandene(Directory ziel) => {
      for (final f in ziel.listSync(recursive: true).whereType<File>())
        _schluessel(p.relative(f.path, from: ziel.path)): f,
    };

bool _gleich(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Vergleicht den installierten Skill Datei für Datei mit dem Paket. Am
/// Inhalt, nicht an einer Versionsnummer: So fällt auch eine Handänderung
/// im installierten Ordner auf.
SkillStand skillVergleichen(SkillPaket paket, Directory ziel) {
  if (!ziel.existsSync()) return SkillStand(ordnerFehlt: true);
  final da = _vorhandene(ziel);
  var fehlend = 0, abweichend = 0;
  final gesehen = <String>{};
  for (final e in paket.dateien.entries) {
    final k = _schluessel(e.key);
    gesehen.add(k);
    final f = da[k];
    if (f == null) {
      fehlend++;
    } else if (!_gleich(f.readAsBytesSync(), e.value)) {
      abweichend++;
    }
  }
  return SkillStand(
      fehlend: fehlend, abweichend: abweichend, ueberzaehlig: da.keys.where((k) => !gesehen.contains(k)).length);
}

/// Installiert einen Skill so, wie ihn das Paket enthält. Datei für Datei
/// statt den Ordner zu löschen: Ein laufendes Claude Code hält den
/// Skill-Ordner offen, Löschen scheitert dann (WinError 32). Dateien, die
/// nicht zum Paket gehören (etwa aus der alten Browser-Version), werden
/// einzeln entfernt, leer gewordene Unterordner danach. Liefert die Pfade,
/// die sich nicht entfernen ließen.
List<String> skillInstallieren(SkillPaket paket, Directory ziel) {
  ziel.createSync(recursive: true);
  final gewollt = <String>{};
  for (final e in paket.dateien.entries) {
    final f = File(p.joinAll([ziel.path, ...e.key.split('/')]));
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(e.value, flush: true);
    gewollt.add(_schluessel(e.key));
  }
  return _aufraeumen(ziel, gewollt);
}

/// Entfernt einen installierten Skill: jede Datei einzeln, dann den Ordner,
/// wenn er leer ist -- ein laufendes Claude Code hält ihn offen, leer schadet
/// er nicht. Liefert die Dateien, die sich nicht löschen ließen.
List<String> skillEntfernen(Directory ziel) {
  if (!ziel.existsSync()) return const [];
  final geblieben = _aufraeumen(ziel, const {});
  try {
    if (ziel.listSync().isEmpty) ziel.deleteSync();
  } on FileSystemException {
    // bleibt leer stehen
  }
  return geblieben;
}

/// Löscht in [ziel] jede Datei, die nicht in [behalten] steht, einzeln, dann
/// die leer gewordenen Unterordner. Liefert die Dateien, die sich nicht
/// löschen ließen.
List<String> _aufraeumen(Directory ziel, Set<String> behalten) {
  final geblieben = <String>[];
  for (final e in _vorhandene(ziel).entries) {
    if (behalten.contains(e.key)) continue;
    try {
      e.value.deleteSync();
    } on FileSystemException {
      geblieben.add(e.key);
    }
  }
  final ordner = ziel.listSync(recursive: true).whereType<Directory>().toList()
    ..sort((a, b) => b.path.length.compareTo(a.path.length));
  for (final d in ordner) {
    try {
      if (d.listSync().isEmpty) d.deleteSync();
    } on FileSystemException {
      // bleibt eben stehen
    }
  }
  return geblieben;
}

// ---------------------------------------------------------------------------
// Entfernen, beim Deinstallieren
// ---------------------------------------------------------------------------

/// Der Schalter, mit dem die Deinstallation (installer/moocp.nsi) die
/// App aufruft: Einrichtung entfernen, ohne Fenster, dann enden (main.dart).
/// Steht auch in windows/runner/main.cpp: Dieser Aufruf läuft auch neben
/// einer laufenden App.
const claudeEntfernenSchalter = '--claude-entfernen';

/// Was nach dem Entfernen noch da ist.
class Entfernt {
  Entfernt({required this.eintragBleibt, required this.dateienBleiben});
  final bool eintragBleibt;
  final List<String> dateienBleiben;

  /// Der Exit-Code für die Deinstallation: 0 alles entfernt, Bit 1 der
  /// Eintrag „moodle" steht noch, Bit 2 Dateien der Skills sind noch da.
  /// Leere Skill-Ordner zählen nicht: Ohne SKILL.md lädt Claude Code nichts.
  int get code => (eintragBleibt ? 1 : 0) | (dateienBleiben.isEmpty ? 0 : 2);
}

/// Entfernt, was die App in Claude Code eingerichtet hat: den Eintrag
/// „moodle", wie beim Eintragen nur über die Kommandozeile von Claude Code,
/// und die Skills [skills]. Danach wird nachgesehen, statt dem Exit-Code zu
/// glauben. Ohne Eintrag wird claude.exe gar nicht erst gesucht.
Future<Entfernt> einrichtungEntfernen({
  required Map<String, String> umgebung,
  required List<String> skills,
  Future<int> Function(String programm, List<String> argumente) ausfuehren = _ausfuehren,
}) async {
  final orte = ClaudeOrte(umgebung);
  if (await _eintragDa(orte.konfiguration)) {
    final claude = claudeFinden(umgebung);
    if (claude != null) await ausfuehren(claude, ['mcp', 'remove', 'moodle', '--scope', 'user']);
  }
  final geblieben = <String>[
    for (final name in skills) ...skillEntfernen(Directory(p.join(orte.skills.path, name))).map((f) => '$name/$f'),
  ];
  return Entfernt(eintragBleibt: await _eintragDa(orte.konfiguration), dateienBleiben: geblieben);
}

/// Ob der Eintrag „moodle" (noch) steht, gleich mit welcher Adresse. Einen
/// halb geschriebenen Stand liest es kurz danach noch einmal; bleibt er
/// unlesbar, zählt der Eintrag als vorhanden.
Future<bool> _eintragDa(File konfiguration) async {
  for (var i = 0; i < 3; i++) {
    final v = verbindungPruefen(konfiguration, 0, '');
    if (v != Verbindung.unlesbar) return v != Verbindung.fehlt;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  return true;
}

// ---------------------------------------------------------------------------
// Python
// ---------------------------------------------------------------------------

/// Ob `python` läuft. Der Skill lernsituation ruft sein Prüfskript mit Python
/// auf; installieren kann die App Python nicht, nur darauf hinweisen. Der
/// Platzhalter „python.exe" aus dem Microsoft Store endet ohne Python mit
/// einem Fehlercode und zählt deshalb richtig als „fehlt".
Future<bool> pythonVorhanden() async {
  try {
    return await _ausfuehren('python', ['--version']) == 0;
  } catch (_) {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Alles zusammen
// ---------------------------------------------------------------------------

class Einrichtungsstand {
  Einrichtungsstand({
    required this.claude,
    required this.verbindung,
    required this.skills,
    required this.stand,
    required this.python,
    this.gewaehlt = const {},
    this.entfernen = const {},
  });

  /// Pfad der claude.exe; null, wenn Claude Code nicht gefunden wurde.
  final String? claude;
  final Verbindung verbindung;

  /// Alle Skills, die die App mitbringt, und ihr Stand im Vergleich zum
  /// installierten.
  final List<SkillPaket> skills;
  final Map<String, SkillStand> stand;
  final bool python;

  /// Die gewählten unter den [wahlSkills].
  final Set<String> gewaehlt;

  /// Wählbare Skills, die installiert, aber nicht gewählt sind; „Installieren"
  /// entfernt sie.
  final Set<String> entfernen;

  /// Was installiert sein soll: jeder Skill, der nicht wählbar ist, und die
  /// gewählten.
  List<SkillPaket> get gewollt =>
      [for (final s in skills) if (!wahlSkills.containsKey(s.name) || gewaehlt.contains(s.name)) s];

  /// Ob der Dialog erscheinen muss. Python allein zählt nicht: Das kann die
  /// App nicht beheben, der Hinweis stünde sonst bei jedem Start da. Eine
  /// nicht gefundene claude.exe ebenso wenig, solange der Eintrag schon
  /// stimmt -- gebraucht wird sie nur zum Eintragen, und ohne Einrichtung
  /// läuft die App nicht (einrichtung_dialog.dart).
  bool get brauchtEtwas =>
      verbindung != Verbindung.aktuell || gewollt.any((s) => !stand[s.name]!.aktuell) || entfernen.isNotEmpty;

  /// Ob die App beheben kann, was fehlt: Skills immer, die Verbindung nur
  /// mit claude.exe.
  bool get einrichtbar => verbindung == Verbindung.aktuell || claude != null;
}

Future<Einrichtungsstand> einrichtungPruefen({
  required Map<String, String> umgebung,
  required int port,
  required String schluessel,
  required List<SkillPaket> skills,
  Set<String> gewaehlt = const {},
  Future<bool> Function() python = pythonVorhanden,
}) async {
  final orte = ClaudeOrte(umgebung);
  // Installiert heißt: SKILL.md ist da. Ein leerer Ordner, den ein laufendes
  // Claude Code offen hält, zählt nicht -- ohne SKILL.md lädt es nichts.
  bool installiert(String name) => File(p.join(orte.skills.path, name, 'SKILL.md')).existsSync();
  return Einrichtungsstand(
    claude: claudeFinden(umgebung),
    verbindung: verbindungPruefen(orte.konfiguration, port, schluessel),
    skills: skills,
    stand: {for (final s in skills) s.name: skillVergleichen(s, Directory(p.join(orte.skills.path, s.name)))},
    python: await python(),
    gewaehlt: gewaehlt,
    entfernen: {
      for (final s in skills)
        if (wahlSkills.containsKey(s.name) && !gewaehlt.contains(s.name) && installiert(s.name)) s.name,
    },
  );
}
