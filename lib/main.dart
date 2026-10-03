// moocp -- lokale App, über die Claude mit Moodle-Kursen arbeitet: ohne
// Längengrenze, mit Sperr- und Positivliste im Code und einem Protokoll, das
// die Lehrkraft sieht.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import 'anmeldedaten.dart';
import 'arbeitsordner.dart';
import 'einrichtung.dart';
import 'einrichtung_dialog.dart';
import 'einstellungen.dart';
import 'einstellungen_dialog.dart';
import 'freigabe.dart';
import 'log.dart';
import 'mcp/mcp_dienst.dart';
import 'moodle/moodle_zugang.dart';
import 'moodle/zeilenvergleich.dart';
import 'protokoll.dart';
import 'ueber.dart';
import 'update/update.dart';
import 'update/update_dialoge.dart';

Future<void> main(List<String> argumente) async {
  // Keine Ausgabe auf die Konsole, von niemandem: debugPrint schweigt -- auch
  // in Paketen, deren Fehlertexte Inhalte enthalten können (etwa der sichere
  // Speicher beim Entschlüsseln). Fehler gehen nur mit ihrem TYP ins
  // Protokoll, nie mit ihrem Text. So gerät das Passwort in keine Ausgabe.
  debugPrint = (String? message, {int? wrapWidth}) {};
  if (argumente.contains(claudeEntfernenSchalter)) exit(await _claudeEntfernen());
  lizenzAnmelden();
  // Die fertige Windows-App hat keine Konsole; print ginge dort ins Leere und
  // Windows meldet „Das Handle ist ungültig". Ausgabe also nur mit Konsole
  // (flutter run). Das Protokoll der App gibt es in beiden Fällen.
  if (!kReleaseMode) loggingEinrichten(stufe: Level.ALL);
  mcpLogsUmleiten();
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  final einstellungen = await Einstellungen.laden();
  final protokoll = Protokoll(datei: File(p.join(Einstellungen.ordner, 'protokoll.log')));
  FlutterError.onError = (d) =>
      protokoll.eintrag(Art.fehler, 'Fehler in der Oberfläche: ${fehlerBeschreibung(d.exception, d.stack)}');
  WidgetsBinding.instance.platformDispatcher.onError = (e, st) {
    protokoll.eintrag(Art.fehler, 'Unerwarteter Fehler: ${fehlerBeschreibung(e, st)}');
    return true;
  };
  protokoll.eintrag(Art.info, 'App gestartet');
  final (arbeitsordner, geblieben) = Arbeitsordner.einrichten();
  protokoll.eintrag(
      Art.info,
      geblieben == 0
          ? 'Arbeitsordner geleert: ${arbeitsordner.pfad}'
          : 'Arbeitsordner: ${arbeitsordner.pfad} -- $geblieben Einträge in Benutzung, nicht gelöscht');
  // Schließen läuft über _beenden, damit der Arbeitsordner geleert wird.
  await windowManager.setPreventClose(true);
  final moodle = MoodleZugang(protokoll);
  final freigaben = Freigaben(protokoll);
  // Reste früherer Updates im Temp-Verzeichnis; der Installer, der die App
  // gerade neu gestartet hat, läuft noch und bleibt bis zum nächsten Start.
  resteWegraeumen();
  // Gestartet wird der MCP-Server erst, wenn die App eingerichtet und
  // angemeldet ist (_HauptseiteState._starten).
  final dienst = McpDienst(einstellungen, moodle, protokoll, freigaben, arbeitsordner.pfad);
  runApp(MoocpApp(einstellungen, protokoll, moodle, dienst, freigaben, arbeitsordner,
      updatefaehig: updateMoeglich(argumente, Platform.environment)));
}

/// Aufruf durch die Deinstallation (installer/moocp.nsi): die
/// Einrichtung in Claude Code entfernen und mit dem Code aus [Entfernt]
/// enden. Ohne Fenster: Es erscheint erst mit dem ersten Bild
/// (windows/runner/flutter_window.cpp), und ohne runApp gibt es keins. Kein
/// MCP-Server, kein Protokoll -- die Deinstallation löscht dessen Ordner
/// ohnehin.
Future<int> _claudeEntfernen() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final skills = [
      for (final a in manifest.listAssets().where((a) => a.startsWith(skillAssets) && a.endsWith('.skill')))
        p.basenameWithoutExtension(a),
    ];
    return (await einrichtungEntfernen(umgebung: Platform.environment, skills: skills)).code;
  } catch (_) {
    return 3; // unbekannt, was geblieben ist: beides melden
  }
}

class MoocpApp extends StatelessWidget {
  const MoocpApp(
    this.einstellungen,
    this.protokoll,
    this.moodle,
    this.dienst,
    this.freigaben,
    this.arbeitsordner, {
    this.einrichtungsstand,
    this.updatefaehig = false,
    super.key,
  });
  final Einstellungen einstellungen;
  final Protokoll protokoll;
  final MoodleZugang moodle;
  final McpDienst dienst;
  final Freigaben freigaben;
  final Arbeitsordner arbeitsordner;

  /// Ob diese App sich selbst aktualisieren kann (update.dart,
  /// updateMoeglich). Nur dann wird geprüft und überhaupt gefragt.
  final bool updatefaehig;

  /// Ersatz für die Prüfung der Einrichtung, nur für die README-Bilder
  /// (tool/bilder_test.dart): Die echte Prüfung sähe auf dem Rechner nach,
  /// und ihr Dialog zeigte den echten Pfad zur claude.exe im Bild.
  final Future<Einrichtungsstand> Function()? einrichtungsstand;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF0851A0), useMaterial3: true),
      // Deutsch auch in den eingebauten Texten: Lizenzseite, Kontextmenü.
      locale: const Locale('de'),
      supportedLocales: const [Locale('de')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Hauptseite(einstellungen, protokoll, moodle, dienst, freigaben, arbeitsordner,
          einrichtungsstand: einrichtungsstand, updatefaehig: updatefaehig),
    );
  }
}

class Hauptseite extends StatefulWidget {
  const Hauptseite(this.einstellungen, this.protokoll, this.moodle, this.dienst, this.freigaben, this.arbeitsordner,
      {this.einrichtungsstand, this.updatefaehig = false, super.key});
  final Einstellungen einstellungen;
  final Protokoll protokoll;
  final MoodleZugang moodle;
  final McpDienst dienst;
  final Freigaben freigaben;
  final Arbeitsordner arbeitsordner;
  final Future<Einrichtungsstand> Function()? einrichtungsstand;
  final bool updatefaehig;

  @override
  State<Hauptseite> createState() => _HauptseiteState();
}

class _HauptseiteState extends State<Hauptseite> with WindowListener {
  late final TextEditingController _adresse = TextEditingController(text: widget.einstellungen.moodleAdresse);
  final _benutzer = TextEditingController();
  final _passwort = TextEditingController();
  bool _beschaeftigt = false;
  String? _meldung;

  /// Haken „Anmeldedaten speichern" (anmeldedaten.dart).
  bool _merken = false;

  /// Ob „Claude einrichten" beim Start durch ist; vorher gibt es keine
  /// Anmeldung und keinen MCP-Server (_starten).
  bool _eingerichtet = false;

  /// Ob der MCP-Server schon zu starten versucht wurde. Bis dahin zeigt die
  /// Kopfzeile, dass er auf die Anmeldung wartet, danach, ob er läuft.
  bool _mcpVersucht = false;

  /// Gesetzt, sobald _beenden läuft.
  bool _beendet = false;

  /// Die laufende Version („0.9.4"), für die Update-Prüfung und die
  /// Einstellungen; leer, wenn sie sich nicht lesen lässt.
  String _version = '';

  // Anmeldestatus und Kopfzeile folgen dem Protokoll: Jede Neuanmeldung oder
  // jedes Verwerfen der Zugangsdaten schreibt dort einen Eintrag.
  void _aktualisieren() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    widget.protokoll.addListener(_aktualisieren);
    widget.freigaben.addListener(_freigabeZeigen);
    WidgetsBinding.instance.addPostFrameCallback((_) => _starten());
  }

  /// Der Start in fester Reihenfolge: Updates, Claude einrichten, anmelden,
  /// dann der MCP-Server (_mcpStarten). Eine Anmeldung, während der Dialog
  /// „Claude einrichten" offen ist, wäre umsonst, wenn die Lehrkraft
  /// „Beenden" wählt. Und Claude erreicht die Werkzeuge erst, wenn die
  /// Skills zur App passen (E13) und die Sitzung bei Moodle steht -- dann
  /// findet schon der erste Aufruf alles bereit.
  ///
  /// Die Update-Prüfung steht davor: Ein Update bringt auch neue Skills;
  /// würde die App vorher einrichten, installierte sie die Version, die
  /// gleich ersetzt wird. Und weil der MCP-Server zuletzt startet, hängt zu
  /// diesem Zeitpunkt noch keine Claude-Sitzung an der App.
  Future<void> _starten() async {
    _version = await _eigeneVersion();
    if (_version.isNotEmpty) {
      await updateStandMelden(widget.einstellungen, _version, widget.protokoll);
      if (!mounted) return;
      if (widget.updatefaehig) {
        final beenden = await updateSchritt(
          context,
          einstellungen: widget.einstellungen,
          protokoll: widget.protokoll,
          eigene: _version,
        );
        if (beenden) {
          await _beenden();
          return;
        }
        if (!mounted) return;
      }
    }
    if (!await _einrichtungPruefen()) return;
    if (!mounted) return;
    setState(() => _eingerichtet = true);
    await _gespeichertAnmelden();
  }

  /// Ohne Version keine Update-Prüfung: Was sich mit nichts vergleichen
  /// lässt, wird nicht angeboten.
  Future<String> _eigeneVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (e) {
      widget.protokoll.eintrag(Art.fehler, 'Version nicht lesbar (${e.runtimeType})');
      return '';
    }
  }

  /// Der Dialog „Einstellungen" über das Zahnrad in der Titelzeile.
  Future<void> _einstellungenZeigen() async {
    final ergebnis = await showDialog<EinstellungenErgebnis>(
      context: context,
      builder: (_) => EinstellungenDialog(
        einstellungen: widget.einstellungen,
        protokoll: widget.protokoll,
        eigene: _version,
        updateMoeglich: widget.updatefaehig,
        sitzungLaeuft: widget.dienst.laeuft,
      ),
    );
    if (!mounted) return;
    switch (ergebnis) {
      case EinstellungenErgebnis.beenden:
        await _beenden();
      case EinstellungenErgebnis.einrichten:
        await _einrichtungPruefen(immer: true);
      case EinstellungenErgebnis.fertig:
      case null:
        break;
    }
  }

  /// Gespeichert heißt: gleich anmelden. Wer den Haken setzt, will sich
  /// nicht bei jedem Start erneut anmelden.
  Future<void> _gespeichertAnmelden() async {
    final Anmeldedaten d;
    try {
      d = await Anmeldedaten.laden();
    } catch (e) {
      widget.protokoll.eintrag(Art.fehler, 'Anmeldedaten: Speicher nicht erreichbar (${e.runtimeType})');
      return;
    }
    if (!mounted) return;
    setState(() {
      _merken = d.merken;
      if (d.benutzer != null) _benutzer.text = d.benutzer!;
      if (d.passwort != null) _passwort.text = d.passwort!;
    });
    if (!d.merken || d.benutzer == null || widget.moodle.angemeldet) return;
    if (d.passwort == null) {
      // Etwa unter einem anderen Windows-Konto: DPAPI entschlüsselt nicht.
      // Ohne Eintrag bliebe die App still abgemeldet.
      widget.protokoll.eintrag(Art.anmeldung, 'Gespeichertes Passwort nicht lesbar -- bitte in der App anmelden');
      return;
    }
    widget.protokoll.eintrag(Art.anmeldung, 'Melde mit gespeicherten Anmeldedaten an');
    await _anmelden();
  }

  /// Startet den MCP-Server, sobald die App eingerichtet und angemeldet ist.
  /// Danach bleibt er an, auch nach „Abmelden": Ein Stopp risse laufenden
  /// Claude-Sitzungen die Verbindung ab; die Werkzeuge melden dann „Nicht
  /// angemeldet".
  Future<void> _mcpStarten() async {
    if (!_eingerichtet || !widget.moodle.angemeldet || widget.dienst.laeuft) return;
    try {
      await widget.dienst.starten();
    } catch (e) {
      widget.protokoll.eintrag(Art.fehler, 'MCP-Server startet nicht auf Port ${widget.einstellungen.port}: $e');
    }
    if (mounted) setState(() => _mcpVersucht = true);
  }

  /// Prüft Verbindung und Skills (einrichtung.dart). Beim Start erscheint der
  /// Dialog nur, wenn etwas nicht passt, über den Knopf in der Titelzeile
  /// immer ([immer]); ohne Einrichtung läuft die App nicht
  /// (einrichtung_dialog.dart). Liefert, ob die App eingerichtet ist.
  Future<bool> _einrichtungPruefen({bool immer = false}) async {
    Einrichtungsstand? stand;
    try {
      stand = await _einrichtungsstand();
    } catch (e, st) {
      widget.protokoll.eintrag(Art.fehler, 'Claude einrichten: Prüfung fehlgeschlagen: ${fehlerBeschreibung(e, st)}');
    }
    if (!mounted) return false;
    if (stand != null && !stand.python && stand.gewaehlt.contains('lernsituation')) {
      widget.protokoll.eintrag(Art.info, 'Python nicht gefunden: Die Selbstprüfung des Skills lernsituation läuft nicht');
    }
    if (!immer && stand != null && !stand.brauchtEtwas) {
      widget.protokoll.eintrag(Art.info, 'Claude einrichten: Verbindung und Skills aktuell');
      return true;
    }
    final bereit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EinrichtungDialog(
        stand: stand,
        pruefen: _einrichtungsstand,
        einstellungen: widget.einstellungen,
        protokoll: widget.protokoll,
        orte: ClaudeOrte(Platform.environment),
      ),
    );
    if (bereit != true) await _beenden();
    return bereit == true;
  }

  Future<Einrichtungsstand> _einrichtungsstand() async {
    if (widget.einrichtungsstand != null) return widget.einrichtungsstand!();
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final pakete = <SkillPaket>[
      for (final a in manifest.listAssets().where((a) => a.startsWith(skillAssets) && a.endsWith('.skill')))
        SkillPaket.ausZip(p.basenameWithoutExtension(a), (await rootBundle.load(a)).buffer.asUint8List()),
    ];
    return einrichtungPruefen(
      umgebung: Platform.environment,
      port: widget.einstellungen.port,
      schluessel: widget.einstellungen.schluessel,
      skills: pakete,
      gewaehlt: widget.einstellungen.wahlSkills ?? gewaehltVorgabe(ClaudeOrte(Platform.environment)),
    );
  }

  @override
  void onWindowClose() => unawaited(_beenden());

  /// Der einzige Weg aus der App, über das Fenster wie über den Dialog
  /// „Claude einrichten": Arbeitsordner leeren, dann schließen. Was sich
  /// nicht löschen lässt, weil es in Benutzung ist, leert der nächste Start.
  ///
  /// Geschlossen wird auf dem Weg, den Windows selbst nimmt (WM_CLOSE, dann
  /// WM_DESTROY): Die Engine baut sich ab, solange die Nachrichtenschleife
  /// noch läuft. windowManager.destroy() beendet dagegen nur die Schleife;
  /// windows/runner/main.cpp ruft dann CoUninitialize, und erst danach baut
  /// sich die Engine ab. Das endet mit einer Zugriffsverletzung in
  /// flutter_windows.dll, und für den Fehlerbericht hält Windows das Fenster
  /// gut fünf Sekunden stehen. Auf dem Weg über WM_CLOSE ist die App nach
  /// einer halben Sekunde zu, ohne Absturz (gemessen).
  Future<void> _beenden() async {
    // close() unten meldet das Schließen noch einmal (onWindowClose).
    if (_beendet) return;
    _beendet = true;
    try {
      final geblieben = widget.arbeitsordner.leeren();
      widget.protokoll.eintrag(
          Art.info,
          geblieben == 0
              ? 'App beendet, Arbeitsordner geleert'
              : 'App beendet, $geblieben Einträge im Arbeitsordner in Benutzung, der nächste Start leert sie');
    } catch (e, st) {
      widget.protokoll.eintrag(Art.fehler, 'Arbeitsordner leeren: ${fehlerBeschreibung(e, st)}');
    } finally {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
  }

  Future<void> _merkenAendern(bool an) async {
    setState(() => _merken = an);
    try {
      await Anmeldedaten.merkenSetzen(an);
      widget.protokoll.eintrag(
        Art.anmeldung,
        an
            ? 'Anmeldedaten werden bei der nächsten erfolgreichen Anmeldung gespeichert'
            : 'Gespeicherte Anmeldedaten gelöscht',
      );
    } catch (e) {
      widget.protokoll.eintrag(Art.fehler, 'Anmeldedaten: Speicher nicht erreichbar (${e.runtimeType})');
    }
  }

  // Eine neue Freigabeanfrage erscheint als Dialog. Die Entscheidung geht an
  // das wartende Werkzeug; schliesst die Frist den Dialog, zählt das als Nein.
  FreigabeAnfrage? _gezeigt;
  void _freigabeZeigen() {
    final a = widget.freigaben.aktuell;
    if (a == null) {
      if (_gezeigt != null && mounted) Navigator.of(context, rootNavigator: true).maybePop();
      _gezeigt = null;
      return;
    }
    if (identical(a, _gezeigt) || !mounted) return;
    _gezeigt = a;
    // Nach vorn und dort bleiben, bis entschieden ist -- ein Dialog hinter
    // anderen Fenstern wird übersehen, und dann läuft nur die Frist ab.
    _nachVorn(true);
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FreigabeDialog(a, widget.freigaben.frist),
    ).then((ja) {
      if (identical(widget.freigaben.aktuell, a)) widget.freigaben.entscheiden(ja ?? false);
      _gezeigt = null;
      _nachVorn(false);
    });
  }

  Future<void> _nachVorn(bool an) async {
    try {
      if (an) {
        await windowManager.show();
        await windowManager.setAlwaysOnTop(true);
        await windowManager.focus();
      } else {
        await windowManager.setAlwaysOnTop(false);
      }
    } catch (_) {
      // Ohne Fensterzugriff bleibt der Dialog trotzdem offen.
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    widget.freigaben.removeListener(_freigabeZeigen);
    widget.protokoll.removeListener(_aktualisieren);
    _adresse.dispose();
    _benutzer.dispose();
    _passwort.dispose();
    super.dispose();
  }

  Future<void> _anmelden() async {
    setState(() {
      _beschaeftigt = true;
      _meldung = null;
    });
    final benutzer = _benutzer.text.trim();
    final passwort = _passwort.text;
    var feldLeeren = true;
    try {
      widget.einstellungen.moodleAdresse = _adresse.text.trim();
      await widget.einstellungen.speichern();
      await widget.moodle.anmelden(_adresse.text, benutzer, passwort);
      _meldung = 'Angemeldet.';
      if (_merken) {
        try {
          await Anmeldedaten.speichern(benutzer, passwort);
          widget.protokoll.eintrag(
            Art.anmeldung,
            'Anmeldedaten gespeichert (Passwort verschlüsselt, Windows-DPAPI)',
          );
        } catch (e) {
          _meldung =
              'Angemeldet. Die Anmeldedaten konnten nicht gespeichert werden '
              '(${e.runtimeType}).';
        }
      }
    } on MoodleNichtErreichbar catch (e) {
      // Das Passwort ist nicht bei Moodle angekommen; es bleibt im Feld, und
      // „Anmelden" versucht es erneut. Sonst wäre nach einer gescheiterten
      // automatischen Anmeldung das gespeicherte Passwort neu zu tippen.
      _meldung = '${e.meldung} „Anmelden" versucht es erneut.';
      feldLeeren = false;
    } on MoodleFehler catch (e) {
      _meldung = e.meldung;
    } catch (e) {
      // Nur der Typ: Ein Fehlertext könnte Eingaben enthalten.
      _meldung = 'Anmeldung fehlgeschlagen (${e.runtimeType}).';
    } finally {
      // Sonst bleibt das Passwort nicht im Eingabefeld stehen; die App hält es
      // nur intern im Arbeitsspeicher, für die automatische Neuanmeldung.
      if (feldLeeren) _passwort.clear();
      if (mounted) setState(() => _beschaeftigt = false);
    }
    await _mcpStarten();
  }

  void _abmelden() {
    widget.moodle.abmelden();
    setState(() => _meldung = 'Abgemeldet.');
  }

  @override
  Widget build(BuildContext context) {
    final angemeldet = widget.moodle.angemeldet;
    final klein = Theme.of(context).textTheme.bodySmall;
    return Scaffold(
      appBar: AppBar(
        title: const Text(appName),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Chip(
              avatar: Icon(
                widget.dienst.laeuft
                    ? Icons.lan
                    : _mcpVersucht
                        ? Icons.error_outline
                        : Icons.hourglass_empty,
                size: 18,
              ),
              label: Text(
                widget.dienst.laeuft
                    ? 'MCP auf 127.0.0.1:${widget.einstellungen.port}'
                    : _mcpVersucht
                        ? 'MCP-Server läuft nicht'
                        : 'MCP startet nach der Anmeldung',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              avatar: Icon(
                angemeldet ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: angemeldet ? Colors.green : Colors.red,
              ),
              label: Text(angemeldet ? 'bei Moodle angemeldet' : 'nicht angemeldet'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Einstellungen: Updates, Claude einrichten',
            onPressed: _einstellungenZeigen,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Über $appName',
              onPressed: () => ueberZeigen(context),
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 460,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _karte('Moodle-Anmeldung', [
                  TextField(
                    controller: _adresse,
                    decoration: const InputDecoration(labelText: 'Moodle-Adresse', hintText: 'https://…'),
                  ),
                  TextField(
                    controller: _benutzer,
                    decoration: const InputDecoration(labelText: 'Benutzername'),
                  ),
                  TextField(
                    controller: _passwort,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Passwort'),
                    onSubmitted: (_) {
                      if (_eingerichtet && !_beschaeftigt && !widget.moodle.angemeldet) _anmelden();
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => _merkenAendern(!_merken),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(value: _merken, onChanged: (v) => _merkenAendern(v ?? false)),
                            const Text('Anmeldedaten speichern'),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                      FilledButton(
                        // Erst nach „Claude einrichten" (_starten).
                        onPressed: !_eingerichtet || _beschaeftigt || angemeldet ? null : _anmelden,
                        child: Text(_beschaeftigt ? 'Melde an …' : 'Anmelden'),
                      ),
                      OutlinedButton(onPressed: angemeldet ? _abmelden : null, child: const Text('Abmelden')),
                      TextButton(
                        onPressed: angemeldet ? widget.moodle.sitzungVerwerfen : null,
                        child: const Text('Sitzung verwerfen (Test)'),
                      ),
                    ],
                  ),
                  if (_meldung != null)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text(_meldung!)),
                  const SizedBox(height: 8),
                  Text(
                    'Ohne Haken bleiben Benutzername und Passwort nur im Arbeitsspeicher, solange '
                    'die App läuft -- für die automatische Neuanmeldung, wenn die Sitzung abläuft. '
                    'Mit Haken speichert die App sie nach einer erfolgreichen Anmeldung -- den '
                    'Benutzernamen in ihren Einstellungen, das Passwort verschlüsselt mit Windows '
                    '(DPAPI, nur mit Ihrem Windows-Konto lesbar) -- und meldet sich beim Start '
                    'selbst an. Haken weg: beides wird sofort gelöscht. Das Passwort geht nie an '
                    'Claude und in kein Protokoll.',
                    style: klein,
                  ),
                ]),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: ProtokollAnsicht(widget.protokoll)),
        ],
      ),
    );
  }

  Widget _karte(String titel, List<Widget> inhalt) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titel, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...inhalt,
        ],
      ),
    ),
  );
}

class FreigabeDialog extends StatelessWidget {
  const FreigabeDialog(this.anfrage, this.frist, {super.key});
  final FreigabeAnfrage anfrage;
  final Duration frist;

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(fontFamily: 'Consolas', fontSize: 12);
    Widget zeile(Zeile z) {
      final (zeichen, farbe) = switch (z.art) {
        ZeilenArt.weg => ('− ', const Color(0x33E53935)),
        ZeilenArt.neu => ('+ ', const Color(0x3343A047)),
        ZeilenArt.gleich => ('  ', Colors.transparent),
        ZeilenArt.ausgelassen => ('  ', Colors.transparent),
      };
      return Container(
        color: farbe,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          '$zeichen${z.text}',
          style: z.art == ZeilenArt.ausgelassen
              ? mono.copyWith(fontStyle: FontStyle.italic, color: Colors.grey)
              : mono,
        ),
      );
    }

    final gross = anfrage.vergleich.isNotEmpty || anfrage.bilder.isNotEmpty;
    return AlertDialog(
      title: Text(anfrage.titel),
      content: SizedBox(
        width: gross ? 900 : 620,
        height: anfrage.bilder.isNotEmpty ? 680 : gross ? 560 : 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (anfrage.grund != null) ...[
              Text.rich(TextSpan(children: [
                const TextSpan(text: 'Wozu: ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: anfrage.grund),
              ])),
              const SizedBox(height: 8),
            ],
            // Bei einer Sammelfreigabe viele Punkte: Sie scrollen für sich,
            // damit der Zeilenvergleich darunter sichtbar bleibt.
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: gross ? 200 : 180),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final p in anfrage.punkte) Text('•  $p')],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (anfrage.vergleich.isNotEmpty) ...[
              Text('Quelltext, vorher (−) und nachher (+):', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
                  child: SelectionArea(
                    child: ListView(children: [for (final z in anfrage.vergleich) zeile(z)]),
                  ),
                ),
              ),
            ] else if (anfrage.bilder.isNotEmpty) ...[
              Text('Genau diese Bilder gehen weiter:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
                  child: ListView(children: [
                    for (final b in anfrage.bilder)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Image.memory(b, fit: BoxFit.fitWidth),
                      ),
                  ]),
                ),
              ),
            ] else
              const Spacer(),
            const SizedBox(height: 8),
            Text(
              'Ohne Entscheidung innerhalb von ${frist.inMinutes} Minuten ${anfrage.ohneEntscheidung}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: Text(anfrage.ablehnen)),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(anfrage.knopf)),
      ],
    );
  }
}

/// Das Protokoll im Fenster, der neueste Eintrag unten. Steht die Liste ganz
/// unten, folgt sie neuen Einträgen; wer hochscrollt, hält sie an, bis er
/// wieder ganz unten ist.
class ProtokollAnsicht extends StatefulWidget {
  const ProtokollAnsicht(this.protokoll, {super.key});
  final Protokoll protokoll;

  @override
  State<ProtokollAnsicht> createState() => _ProtokollAnsichtState();
}

class _ProtokollAnsichtState extends State<ProtokollAnsicht> {
  static const _symbole = {
    Art.werkzeug: (Icons.smart_toy_outlined, Colors.indigo),
    Art.moodle: (Icons.public, Colors.blueGrey),
    Art.schreiben: (Icons.edit_note, Colors.deepPurple),
    Art.anmeldung: (Icons.key, Colors.teal),
    Art.gesperrt: (Icons.block, Colors.red),
    Art.fehler: (Icons.error_outline, Colors.orange),
    Art.info: (Icons.info_outline, Colors.grey),
  };

  String _zeit(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  final _scroll = ScrollController();

  // Ob die Liste folgt, ändert sich mit jeder Bewegung (Mausrad,
  // Scrollbalken, Ziehen, eigener Sprung ans Ende). Ein neuer Eintrag ist
  // keine Bewegung: Er verschiebt nur das Ende, und die Liste folgt weiter.
  bool _folgen = true;

  bool get _unten => _scroll.position.pixels >= _scroll.position.maxScrollExtent - 1;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _folgen = _unten);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Kommt nach dem Bild, in dem sich Länge oder Höhe der Liste geändert
  // haben (neuer Eintrag, Leeren, Fenstergröße). Die Länge ist nur geschätzt,
  // solange nicht alle Einträge gebaut sind; landet der Sprung zu früh, kommt
  // die nächste Meldung und springt weiter.
  bool _groesseGeaendert(ScrollMetricsNotification _) {
    if (!_scroll.hasClients) return false;
    if (_unten) {
      _folgen = true;
    } else if (_folgen) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Text('Protokoll', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(onPressed: widget.protokoll.leeren, child: const Text('Leeren')),
            ],
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: _groesseGeaendert,
            child: ListenableBuilder(
              listenable: widget.protokoll,
              builder: (context, _) {
                final e = widget.protokoll.eintraege;
                return ListView.builder(
                  controller: _scroll,
                  itemCount: e.length,
                  itemBuilder: (context, i) {
                    final x = e[i];
                    final (symbol, farbe) = _symbole[x.art]!;
                    return ListTile(
                      dense: true,
                      leading: Icon(symbol, color: farbe, size: 18),
                      title: SelectableText(x.text, style: const TextStyle(fontFamily: 'Consolas', fontSize: 12.5)),
                      trailing: Text(_zeit(x.zeit), style: Theme.of(context).textTheme.bodySmall),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
