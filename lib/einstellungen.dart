// Einstellungen, die einen Neustart überleben: Moodle-Adresse, Port,
// Zugangsschlüssel für Claude, die gewählten Skills und die Update-Prüfung.
// Die Freigabestufe liegt je Moodle-Instanz im Profil; `bestaetigungen` bleibt
// für ältere Einstellungsdateien erhalten.
//
// Bewusst NICHT hier: Benutzername und Passwort. Die leben im Arbeitsspeicher,
// solange die App läuft -- und nur mit Haken „Anmeldedaten speichern" auch
// dauerhaft, siehe anmeldedaten.dart (Passwort mit DPAPI verschlüsselt).
// Ebenso wenig der Arbeitsordner: Der liegt fest und lebt nur so lange wie
// die App (arbeitsordner.dart).

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'einstellungen_ort.dart';
import 'freigabe.dart';
import 'profil.dart';

class Einstellungen {
  /// [moodleAdresse] ist der Altbestand eines einzelnen Moodle und wird zum
  /// ersten Profil ([profile]). Mit [profile] gewinnt die Liste.
  Einstellungen({
    String moodleAdresse = '',
    List<Profil>? profile,
    required this.schluessel,
    this.bestaetigungen = Bestaetigungen.vorgabe,
    this.wahlSkills,
    this.werkzeugeAbgewaehlt = const {},
    this.updatePruefen,
    this.updateZuletzt,
    this.updateErwartet,
  }) : profile = _verteilt(profile ?? (moodleAdresse.isEmpty ? [] : [Profil.migriert(moodleAdresse)]));

  /// Die Moodle-Instanzen, mit denen die App angemeldet sein kann. Das erste
  /// Profil hat die Kennung `standard` (profil.dart), wenn es aus dem
  /// Altbestand stammt oder als erstes angelegt wurde.
  List<Profil> profile;

  /// Port des MCP-Servers des ersten Profils, also des Altbestands (E31). Die
  /// weiteren Profile haben ihren Port in [profile].
  int get port => profile.isEmpty ? standardPort : profile.first.port;

  /// Vergibt fehlende Ports und Servernamen und macht beide eindeutig. Das
  /// erste Profil behält seinen Port; jedes weitere bekommt den nächsten freien
  /// Port ab [standardPort]. Doppelte Servernamen bekommen eine Zählnummer.
  /// Jedes Profil außer dem Standardprofil bekommt, wenn es noch keinen hat,
  /// einen eigenen Zugangsschlüssel (E6); [laden] schreibt ihn gleich in die
  /// Datei, damit er einen Neustart überlebt. Vollständige, eindeutige Profile
  /// bleiben unverändert.
  static List<Profil> _verteilt(List<Profil> liste) {
    final vergeben = <int>{for (final p in liste) if (p.port > 0) p.port};
    final namen = <String>{};
    int freierPort() {
      var n = standardPort;
      while (vergeben.contains(n)) {
        n++;
      }
      vergeben.add(n);
      return n;
    }

    final ergebnis = <Profil>[];
    for (final p in liste) {
      final port = p.port > 0 && !ergebnis.any((q) => q.port == p.port) ? p.port : freierPort();
      var mcp = p.mcpName;
      var zaehler = 2;
      final basis = mcp;
      while (namen.contains(mcp)) {
        mcp = '$basis-${zaehler++}';
      }
      namen.add(mcp);
      ergebnis.add(Profil(
        kennung: p.kennung,
        name: p.name,
        adresse: p.adresse,
        port: port,
        mcpName: mcp,
        bestaetigungen: p.bestaetigungen,
        schluessel: p.istStandard
            ? ''
            : p.schluessel.isNotEmpty
            ? p.schluessel
            : neuerSchluessel(),
      ));
    }
    return ergebnis;
  }

  /// Die Adresse des ersten Profils. Der Dialog und die Titelzeile arbeiten
  /// noch mit einer Adresse; ein zweites Profil kommt über [profile].
  String get moodleAdresse => profile.isEmpty ? '' : profile.first.adresse;

  set moodleAdresse(String a) {
    if (profile.isEmpty) {
      if (a.isNotEmpty) profile = [Profil.migriert(a)];
      return;
    }
    profile[0] = profile[0].copyWith(adresse: a);
  }

  /// Der globale Zugangsschlüssel (E6): der des Standardprofils und der Brücke
  /// für LM Studio. Jedes weitere Profil hat seinen eigenen ([Profil.schluessel]);
  /// welcher für ein Profil gilt, sagt [schluesselFuer].
  String schluessel;

  /// Der Zugangsschlüssel des MCP-Servers dieses Profils (E6). Das
  /// Standardprofil behält den globalen Schlüssel, damit die vorhandenen
  /// Einträge in Claude Code, Codex und Bionic weiter gelten; jedes andere hat
  /// einen eigenen. Leer, solange ein Profil noch keinen hat -- der Server
  /// lässt dann niemanden herein (mcp_dienst.dart).
  String schluesselFuer(Profil p) => p.istStandard ? schluessel : p.schluessel;

  /// Alte globale Freigabestufe, nur zur Migration und für ältere Versionen.
  Bestaetigungen bestaetigungen;

  /// Die gewählten unter den wählbaren Skills (einrichtung.dart,
  /// wahlSkills); null, solange im Dialog „KI-Werkzeuge einrichten" noch
  /// nichts gewählt wurde -- dann gilt gewaehltVorgabe.
  Set<String>? wahlSkills;

  /// Die KI-Werkzeuge, die die Lehrkraft im Dialog abgewählt hat
  /// (einrichtung.dart, KiWerkzeug.id). Gespeichert wird, was abgewählt
  /// ist, nicht was gewählt: So erscheint ein Werkzeug, das erst nach der
  /// App installiert wurde, von selbst im Dialog.
  Set<String> werkzeugeAbgewaehlt;

  /// Ob die App einmal täglich bei GitHub nach einer neuen Version sehen
  /// darf; null, solange nicht gefragt wurde (update.dart). Ohne
  /// ausdrückliches Ja fragt die App niemanden -- auch GitHub nicht.
  bool? updatePruefen;

  /// Tag der letzten Prüfung (`2026-10-03`), gesetzt auch nach einem
  /// Fehlversuch: Sonst wartete jemand ohne Netz bei jedem Start erneut auf
  /// die Zeitgrenze.
  String? updateZuletzt;

  /// Die Version, deren Installer gerade gestartet wurde; der nächste Start
  /// vergleicht sie mit der eigenen und meldet Erfolg oder Fehlschlag. Die
  /// App ist währenddessen beendet und sieht sonst nichts davon.
  String? updateErwartet;

  static File get _datei => einstellungenDatei;

  static String neuerSchluessel() {
    final r = Random.secure();
    return List.generate(32, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<Einstellungen> laden() async {
    final standard = Einstellungen(
      moodleAdresse: '',
      schluessel: neuerSchluessel(),
    );
    try {
      if (await _datei.exists()) {
        final j = jsonDecode(await _datei.readAsString()) as Map<String, dynamic>;
        final e = Einstellungen.aus(j, standard);
        // Frisch vergebene Schlüssel gleich festhalten: Sonst bekäme das
        // Profil bei jedem Start einen neuen, und die Einträge in den
        // KI-Werkzeugen wären jedes Mal veraltet.
        if (schluesselFehlen(j)) {
          try {
            await e.speichern();
          } catch (_) {
            // Nicht schreibbar: Die Schlüssel gelten für diesen Lauf; der
            // Fall nach dem catch unten (Standardwerte schreiben) ist es nicht.
          }
        }
        return e;
      }
    } catch (_) {
      // Kaputte Datei: mit den Standardwerten weiter und beim Speichern ersetzen.
    }
    await standard.speichern();
    return standard;
  }

  /// Ob in der Datei ein Profil ohne eigenen Schlüssel steht, das einen
  /// braucht (alle außer dem Standardprofil).
  static bool schluesselFehlen(Map<String, dynamic> j) {
    final liste = j['profile'];
    if (liste is! List) return false;
    return liste.any((e) {
      if (e is! Map) return false;
      final kennung = e['kennung'];
      if (kennung is! String || kennung.isEmpty || kennung == Profil.standardKennung) return false;
      final k = e['schluessel'];
      return k is! String || k.isEmpty;
    });
  }

  /// Liest den Inhalt der Datei. Ohne `profile` (Stand vor den Profilen) wird die
  /// Adresse `moodleAdresse` mit dem alten Port `port` zum ersten Profil; beim
  /// nächsten Speichern kommt `profile` dazu, `moodleAdresse` und `port`
  /// bleiben für ältere Versionen stehen.
  static Einstellungen aus(Map<String, dynamic> j, Einstellungen standard) {
    final liste = (j['profile'] as List?)?.map(Profil.ausJson).whereType<Profil>().toList();
    final altAdresse = j['moodleAdresse'] as String? ?? standard.moodleAdresse;
    final altPort = j['port'] as int?;
    final alteStufe = Bestaetigungen.ausText(j['bestaetigungen'] as String?);
    final profile = liste ??
        (altAdresse.isEmpty ? <Profil>[] : [Profil.migriert(altAdresse, port: altPort ?? standardPort)]);
    final gespeicherteProfile = j['profile'] as List?;
    for (var i = 0; i < profile.length; i++) {
      final gespeichertesProfil = gespeicherteProfile != null && i < gespeicherteProfile.length
          ? gespeicherteProfile[i]
          : null;
      if ((gespeichertesProfil is! Map || !gespeichertesProfil.containsKey('bestaetigungen')) &&
          alteStufe != Bestaetigungen.vorgabe) {
        profile[i] = profile[i].mitBestaetigungen(alteStufe);
      }
    }
    return Einstellungen(
      moodleAdresse: altAdresse,
      profile: profile,
      schluessel: j['schluessel'] as String? ?? standard.schluessel,
      bestaetigungen: alteStufe,
      wahlSkills: (j['wahlSkills'] as List?)?.whereType<String>().toSet(),
      werkzeugeAbgewaehlt: (j['werkzeugeAbgewaehlt'] as List?)?.whereType<String>().toSet() ?? const {},
      updatePruefen: j['updatePruefen'] as bool?,
      updateZuletzt: j['updateZuletzt'] as String?,
      updateErwartet: j['updateErwartet'] as String?,
    );
  }

  /// Der Inhalt der Datei, wie ihn [speichern] schreibt.
  Map<String, Object?> zuJson() => {
        'moodleAdresse': moodleAdresse,
        'profile': [for (final p in profile) p.toJson()],
        'port': port,
        'schluessel': schluessel,
        'bestaetigungen': bestaetigungen.text,
        if (wahlSkills != null) 'wahlSkills': (wahlSkills!.toList()..sort()),
        if (werkzeugeAbgewaehlt.isNotEmpty) 'werkzeugeAbgewaehlt': (werkzeugeAbgewaehlt.toList()..sort()),
        if (updatePruefen != null) 'updatePruefen': updatePruefen,
        if (updateZuletzt != null) 'updateZuletzt': updateZuletzt,
        if (updateErwartet != null) 'updateErwartet': updateErwartet,
      };

  Future<void> speichern() async {
    await Directory(einstellungenOrdner).create(recursive: true);
    await _datei.writeAsString(const JsonEncoder.withIndent('  ').convert(zuJson()));
  }
}
