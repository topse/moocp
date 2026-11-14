// Die Oberfläche des Installers unter Linux (E24): derselbe Ablauf und
// dieselben Seiten wie installer/moocp.nsi unter Windows -- Hinweis mit
// Wartezeit, Lizenz zur Kenntnis, Zielordner, Installieren, Fertig stellen
// mit „moocp starten", dazu die Deinstallation mit Bestätigung. Sie läuft in
// der App selbst (`moocp --installieren`, `moocp --deinstallieren`), weil sich
// auf einem Linux-Rechner weder zenity noch Tk voraussetzen lassen; die GTK-
// Bibliotheken bringt die App ohnehin mit.
//
// Der Hinweis steht hier zum dritten Mal neben README und NSIS-Skript: Wer
// ihn ändert, zieht alle drei nach (CLAUDE.md, Arbeitsregeln).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../ueber.dart';
import 'installer_logik.dart';

/// Sekunden, die „Weiter" auf der Hinweisseite gesperrt bleibt (wie
/// HINWEIS_SEKUNDEN im NSIS-Skript): Der Hinweis soll gelesen und nicht
/// weggeklickt werden.
const hinweisSekunden = 10;

enum InstallerModus { installieren, deinstallieren }

class InstallerApp extends StatelessWidget {
  const InstallerApp({
    required this.modus,
    required this.orte,
    required this.ziel,
    this.quelle = '',
    this.version = '',
    this.wartezeit = const Duration(seconds: hinweisSekunden),
    this.anmeldedatenLoeschen,
    this.starten,
    this.beenden,
    super.key,
  });

  final InstallerModus modus;
  final InstallerOrte orte;

  /// Vorgeschlagenes (Installieren) oder festes (Deinstallieren) Ziel.
  final String ziel;
  final String quelle;
  final String version;
  final Duration wartezeit;
  final Future<void> Function()? anmeldedatenLoeschen;

  /// Startet die installierte App (Fertig stellen, Haken gesetzt).
  final Future<void> Function(String ziel)? starten;

  /// Beendet das Programm; Tests ersetzen es.
  final void Function(int code)? beenden;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'moocp Setup',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFF0851A0), useMaterial3: true),
    locale: const Locale('de'),
    supportedLocales: const [Locale('de')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: InstallerSeite(
      modus: modus,
      orte: orte,
      ziel: ziel,
      quelle: quelle,
      version: version,
      wartezeit: wartezeit,
      anmeldedatenLoeschen: anmeldedatenLoeschen,
      starten: starten,
      beenden: beenden ?? (c) => exit(c),
    ),
  );
}

enum _Seite { hinweis, lizenz, ziel, bestaetigen, arbeit, fertig }

class InstallerSeite extends StatefulWidget {
  const InstallerSeite({
    required this.modus,
    required this.orte,
    required this.ziel,
    required this.quelle,
    required this.version,
    required this.wartezeit,
    required this.beenden,
    this.anmeldedatenLoeschen,
    this.starten,
    super.key,
  });

  final InstallerModus modus;
  final InstallerOrte orte;
  final String ziel;
  final String quelle;
  final String version;
  final Duration wartezeit;
  final Future<void> Function()? anmeldedatenLoeschen;
  final Future<void> Function(String ziel)? starten;
  final void Function(int code) beenden;

  @override
  State<InstallerSeite> createState() => _InstallerSeiteState();
}

class _InstallerSeiteState extends State<InstallerSeite> {
  late _Seite _seite;
  late final TextEditingController _zielFeld;
  Timer? _timer;
  late int _rest; // Sekunden bis „Weiter" auf der Hinweisseite
  bool _hinweisGelesen = false;
  String? _fehler; // Meldung der Seite Ziel (ungültig)
  final List<String> _log = [];
  String? _arbeitsFehler;
  String _hinweisNach = ''; // Deinstallation: was sich nicht entfernen ließ
  bool _starten = true;
  String _lizenz = '';
  bool _laeuft = false;

  bool get _inst => widget.modus == InstallerModus.installieren;

  @override
  void initState() {
    super.initState();
    _zielFeld = TextEditingController(text: widget.ziel);
    _seite = _inst ? _Seite.hinweis : _Seite.bestaetigen;
    _rest = widget.wartezeit.inSeconds;
    if (_inst) {
      if (_rest <= 0) {
        _hinweisGelesen = true;
      } else {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() {
            _rest--;
            if (_rest <= 0) {
              _hinweisGelesen = true;
              _timer?.cancel();
            }
          });
        });
      }
      // Die Lizenz wie LICENSE.md in der App; das BOM steht dort für den
      // Windows-Installer.
      rootBundle
          .loadString(lizenzAsset)
          .then((t) {
            if (mounted) setState(() => _lizenz = t.replaceFirst('﻿', ''));
          })
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _zielFeld.dispose();
    super.dispose();
  }

  // ---- Ablauf

  List<_Seite> get _folge =>
      _inst
          ? [_Seite.hinweis, _Seite.lizenz, _Seite.ziel, _Seite.arbeit, _Seite.fertig]
          : [_Seite.bestaetigen, _Seite.arbeit, _Seite.fertig];

  Future<void> _weiter() async {
    if (_seite == _Seite.ziel) {
      try {
        zielPruefen(_zielFeld.text.trim());
        setState(() => _fehler = null);
      } on InstallerFehler catch (e) {
        setState(() => _fehler = e.text);
        return;
      }
    }
    final i = _folge.indexOf(_seite);
    setState(() => _seite = _folge[i + 1]);
    if (_seite == _Seite.arbeit) await _ausfuehren();
  }

  void _zurueck() {
    final i = _folge.indexOf(_seite);
    if (i > 0) setState(() => _seite = _folge[i - 1]);
  }

  Future<void> _ausfuehren() async {
    setState(() {
      _laeuft = true;
      _log.clear();
      _arbeitsFehler = null;
    });
    void meldung(String t) {
      if (mounted) setState(() => _log.add(t));
    }

    try {
      // Einen Frame lang zeigen, bevor die Arbeit den Faden belegt.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_inst) {
        installieren(
          quelle: widget.quelle,
          ziel: _zielFeld.text.trim(),
          orte: widget.orte,
          version: widget.version,
          meldung: meldung,
        );
      } else {
        final e = await deinstallieren(
          ziel: widget.ziel,
          orte: widget.orte,
          anmeldedatenLoeschen: widget.anmeldedatenLoeschen,
          meldung: meldung,
        );
        _hinweisNach = e.hinweis;
      }
      if (!mounted) return;
      setState(() {
        _laeuft = false;
        _seite = _Seite.fertig;
      });
    } on InstallerFehler catch (e) {
      if (mounted) {
        setState(() {
          _laeuft = false;
          _arbeitsFehler = e.text;
        });
      }
    } catch (e) {
      // Nur der Typ: Pfade stehen sonst in der Meldung (E11).
      if (mounted) {
        setState(() {
          _laeuft = false;
          _arbeitsFehler = 'Das Einrichten ist fehlgeschlagen (${e.runtimeType}).';
        });
      }
    }
  }

  Future<void> _abbrechen() async {
    if (_seite == _Seite.fertig) {
      await _fertig();
      return;
    }
    if (_laeuft) return;
    final ja = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(
          _inst
              ? 'Möchten Sie die Installation von moocp wirklich abbrechen?'
              : 'Möchten Sie die Deinstallation von moocp wirklich abbrechen?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nein')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ja')),
        ],
      ),
    );
    if (ja == true) widget.beenden(1);
  }

  Future<void> _fertig() async {
    if (_inst && _starten && widget.starten != null) {
      try {
        await widget.starten!(_zielFeld.text.trim());
      } catch (_) {
        // Der Start ist Beigabe; die Installation steht.
      }
    }
    widget.beenden(0);
  }

  // ---- Oberfläche

  (String, String) get _kopf => switch (_seite) {
    _Seite.hinweis => ('Wichtiger Hinweis', 'Bitte lesen Sie ihn. „Weiter“ wird nach $hinweisSekunden Sekunden aktiv.'),
    _Seite.lizenz => ('Lizenzvereinbarung', 'Bitte lesen Sie die Lizenz, bevor Sie moocp installieren.'),
    _Seite.ziel => ('Zielordner wählen', 'Wählen Sie den Ordner, in den moocp installiert wird.'),
    _Seite.bestaetigen => ('moocp deinstallieren', 'moocp wird von Ihrem Rechner entfernt.'),
    _Seite.arbeit => (
      _inst ? 'Installieren' : 'Deinstallieren',
      _inst ? 'Bitte warten Sie, während moocp installiert wird.' : 'Bitte warten Sie, während moocp entfernt wird.',
    ),
    _Seite.fertig => (
      _inst ? 'Die Installation ist abgeschlossen' : 'Die Deinstallation ist abgeschlossen',
      _inst ? 'moocp wurde auf Ihrem Rechner installiert.' : 'moocp wurde von Ihrem Rechner entfernt.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (titel, unter) = _kopf;
    final weiterAktiv = switch (_seite) {
      _Seite.hinweis => _hinweisGelesen,
      _Seite.arbeit => false,
      _Seite.fertig => false,
      _ => true,
    };
    final weiterText = switch (_seite) {
      _Seite.hinweis => _hinweisGelesen ? 'Weiter >' : 'Weiter in $_rest s',
      _Seite.ziel => 'Installieren',
      _Seite.bestaetigen => 'Deinstallieren',
      _ => 'Weiter >',
    };
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Padding(padding: const EdgeInsets.only(left: 14), child: Text(unter)),
                    ],
                  ),
                ),
                const Icon(Icons.school_outlined, size: 40, color: Color(0xFF0851A0)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: _inhalt(context)),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_seite != _Seite.fertig) ...[
                  OutlinedButton(
                    onPressed: _seite == _Seite.lizenz || _seite == _Seite.ziel ? _zurueck : null,
                    child: const Text('< Zurück'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: weiterAktiv ? _weiter : null,
                    child: Text(weiterText),
                  ),
                  const SizedBox(width: 16),
                ],
                if (_seite == _Seite.fertig)
                  FilledButton(onPressed: _fertig, child: const Text('Fertig stellen'))
                else
                  OutlinedButton(onPressed: _laeuft ? null : _abbrechen, child: const Text('Abbrechen')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inhalt(BuildContext context) {
    switch (_seite) {
      case _Seite.hinweis:
        return _hinweis();
      case _Seite.lizenz:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26)),
                padding: const EdgeInsets.all(8),
                child: SingleChildScrollView(child: SelectableText(_lizenz, style: const TextStyle(fontSize: 12))),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'moocp steht unter der MIT-Lizenz: Sie dürfen die App frei benutzen, weitergeben und verändern. '
              'Eine Zustimmung ist nicht nötig.',
            ),
          ],
        );
      case _Seite.ziel:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'moocp wird in den folgenden Ordner installiert. Das geht ohne Administratorrechte; '
              'ein anderer Ordner lässt sich eintragen.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _zielFeld,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Zielordner',
                errorText: _fehler,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Einstellungen, gespeicherte Anmeldedaten und die Einrichtung der KI-Werkzeuge bleiben '
              'bei einer neuen Version erhalten.',
            ),
          ],
        );
      case _Seite.bestaetigen:
        return const Text(
          'moocp wird entfernt, zusammen mit Einstellungen, Protokoll, Sicherungen, gespeicherten Anmeldedaten und '
          'Arbeitsordner. Auch die Verbindung in Claude Code und Codex CLI und die Skills der App werden entfernt.',
        );
      case _Seite.arbeit:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_laeuft) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26)),
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                child: SingleChildScrollView(child: Text(_log.join('\n'))),
              ),
            ),
            if (_arbeitsFehler != null) ...[
              const SizedBox(height: 8),
              Text(_arbeitsFehler!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton(onPressed: _ausfuehren, child: const Text('Wiederholen')),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: () => widget.beenden(1), child: const Text('Beenden')),
                ],
              ),
            ],
          ],
        );
      case _Seite.fertig:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_inst) ...[
              const Text('Sie finden moocp jetzt im Startmenü und auf dem Schreibtisch.'),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _starten,
                onChanged: (v) => setState(() => _starten = v ?? true),
                title: const Text('moocp starten'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ] else if (_hinweisNach.isNotEmpty)
              SingleChildScrollView(child: Text(_hinweisNach))
            else
              const Align(alignment: Alignment.centerLeft, child: Text('Alles wurde entfernt.')),
          ],
        );
    }
  }

  Widget _hinweis() {
    const fett = TextStyle(fontWeight: FontWeight.bold);
    Widget punkt(String t) => Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [const Text('•  '), Expanded(child: Text(t))],
      ),
    );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nutzung auf eigene Verantwortung', style: fett),
          const SizedBox(height: 4),
          const Text(
            'moocp ist ein privates Open-Source-Projekt, ohne Gewähr. Es wird weder von einer Schule, einem Land '
            'oder Schulträger noch von Moodle HQ oder KI-Anbietern angeboten, geprüft oder unterstützt. Die App '
            'liest und ändert Ihre Moodle-Kurse, und Fehler sind nicht ausgeschlossen: Probieren Sie sie zuerst in '
            'einem Testkurs aus.',
          ),
          const SizedBox(height: 10),
          const Text(
            'Vor dem Einsatz klären – mit Schulleitung, Datenschutzbeauftragten und dem Betreiber Ihrer Moodle-Instanz:',
            style: fett,
          ),
          const SizedBox(height: 4),
          punkt(
            'ob Sie KI-Werkzeuge dienstlich einsetzen dürfen, und mit welchem Konto. Alles, was die KI liest, '
            'geht an den Anbieter des Modells.',
          ),
          punkt('ob die Nutzungsbedingungen Ihrer Moodle-Instanz einen automatisierten Zugriff mit Ihrem Konto erlauben.'),
          punkt(
            'ob Inhalte Dritter in Ihren Kursen, etwa Verlagsmaterial, an eine KI gegeben werden dürfen; manche '
            'Lizenzen schließen das aus.',
          ),
          const SizedBox(height: 4),
          const Text(
            'moocp ist so gebaut, dass personenbezogene Daten gar nicht erst angefragt werden. Eine Garantie ist '
            'das nicht – auch darin können Fehler stecken.',
          ),
        ],
      ),
    );
  }
}
