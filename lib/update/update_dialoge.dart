// Die Oberfläche der Update-Prüfung: die Frage beim ersten Start, die
// Anzeige während der Prüfung und das Angebot mit dem Download.
//
// Beim Start läuft das vor allem anderen (main.dart, _starten): Ein Update
// ersetzt auch die Skills, und würde die App vorher einrichten, installierte
// sie die Version, die gleich überschrieben wird (E13). Weil der MCP-Server
// zuletzt startet, reißt ein Update zu diesem Zeitpunkt auch keiner
// Sitzung eines KI-Werkzeugs die Verbindung ab.
//
// Die Anzeige „Prüfe auf Updates" erscheint erst nach einer kurzen Weile:
// Bei flottem Netz ist die Prüfung vorher durch, und niemand soll bei jedem
// Start ein Fenster aufblitzen sehen.

import 'dart:async';

import 'package:flutter/material.dart';

import '../einstellungen.dart';
import '../protokoll.dart';
import 'update.dart';

/// Wie lange die Prüfung dauern darf, bevor die App sie anzeigt.
const Duration _anzeigeAb = Duration(milliseconds: 800);

/// Fragen (einmalig), prüfen und anbieten. Rückgabe: true, wenn ein
/// Installer gestartet wurde -- dann beendet der Aufrufer die App.
///
/// [manuell] ist der Weg über „Jetzt nach Updates suchen" in den
/// Einstellungen: Dann sagt die App auch, wenn es nichts Neues gibt oder
/// die Abfrage scheitert. Beim Start bleibt beides still im Protokoll --
/// wer die App öffnet, will arbeiten, nicht von GitHub hören.
Future<bool> updateSchritt(
  BuildContext context, {
  required Einstellungen einstellungen,
  required Protokoll protokoll,
  required String eigene,
  bool manuell = false,
  bool sitzungLaeuft = false,
}) async {
  if (einstellungen.updatePruefen == null) {
    final ja = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UpdateFrageDialog(),
    );
    einstellungen.updatePruefen = ja == true;
    await _speichern(einstellungen, protokoll);
    protokoll.eintrag(
        Art.info,
        ja == true
            ? 'Update-Prüfung eingeschaltet: einmal täglich bei GitHub'
            : 'Update-Prüfung ausgeschaltet: keine Anfrage an GitHub');
  }
  // „Jetzt nach Updates suchen" ist für sich eine Zustimmung: Es sucht
  // auch, wenn die tägliche Suche aus ist, aber nur dieses eine Mal.
  if (!manuell && einstellungen.updatePruefen != true) return false;
  final jetzt = DateTime.now();
  if (!manuell && heuteSchonGeprueft(einstellungen, jetzt)) return false;
  einstellungen.updateZuletzt = tagesdatum(jetzt);
  await _speichern(einstellungen, protokoll);

  final update = Update(protokoll);
  NeueVersion? neu;
  String? fehler;
  var abgebrochen = false;
  BuildContext? anzeige;
  final uhr = Timer(_anzeigeAb, () {
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        anzeige = c;
        return _PruefAnzeige(update.abbrechen);
      },
    );
  });
  try {
    neu = await update.pruefen(eigene);
  } on UpdateAbgebrochen {
    abgebrochen = true;
    protokoll.eintrag(Art.info, 'Update: Prüfung abgebrochen');
  } on UpdateFehler catch (e) {
    fehler = e.meldung;
    protokoll.eintrag(Art.info, 'Update: Prüfung nicht möglich -- ${e.meldung}');
  } finally {
    uhr.cancel();
    final offen = anzeige;
    if (offen != null && offen.mounted) Navigator.of(offen).pop();
  }
  if (!context.mounted || abgebrochen) return false;

  if (neu == null) {
    if (manuell) {
      await _melden(context, fehler ?? 'moocp $eigene ist die neueste Version.');
    }
    return false;
  }
  final los = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AngebotDialog(
      neu: neu!,
      eigene: eigene,
      update: update,
      einstellungen: einstellungen,
      protokoll: protokoll,
      sitzungLaeuft: sitzungLaeuft,
    ),
  );
  // „Jetzt nicht" schreibt die App nicht weiter auf -- ins Protokoll gehört
  // es trotzdem: Es war ein Angebot da, und es wurde abgelehnt. Morgen
  // kommt es wieder.
  if (los != true) {
    protokoll.eintrag(Art.info, 'Update: Version ${neu.version} jetzt nicht installiert');
  }
  return los == true;
}

Future<void> _speichern(Einstellungen e, Protokoll protokoll) async {
  try {
    await e.speichern();
  } catch (x) {
    protokoll.eintrag(Art.fehler, 'Einstellungen nicht gespeichert (${x.runtimeType})');
  }
}

Future<void> _melden(BuildContext context, String text) => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nach Updates gesucht'),
        content: SizedBox(width: 420, child: Text(text)),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Schließen'))],
      ),
    );

/// Die Frage beim ersten Start. Sie steht vor jeder Anfrage: Ohne
/// ausdrückliches Ja nimmt die App keinen Kontakt zu GitHub auf.
class UpdateFrageDialog extends StatelessWidget {
  const UpdateFrageDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Automatisch nach Updates suchen?'),
      content: SizedBox(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('moocp kann einmal täglich bei GitHub nachsehen, ob es eine neue Version '
              'gibt, und sie auf Wunsch gleich installieren.'),
          const SizedBox(height: 12),
          const Text('Dazu fragt die App eine einzige Adresse bei GitHub ab. GitHub erfährt '
              'dabei Ihre IP-Adresse und den Zeitpunkt. Nichts aus Moodle wird übertragen, '
              'kein Benutzername, kein Passwort: Die Prüfung hat ihre eigene Verbindung, ohne '
              'Ihre Moodle-Sitzung.'),
          const SizedBox(height: 12),
          Text(
              'Ohne Prüfung bleibt alles, wie es ist; neue Versionen finden Sie dann selbst '
              'unter „Releases" im Repository. Ändern können Sie das jederzeit in den '
              'Einstellungen.',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nicht suchen')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Täglich suchen')),
      ],
    );
  }
}

class _PruefAnzeige extends StatelessWidget {
  const _PruefAnzeige(this.abbrechen);
  final void Function() abbrechen;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Prüfe auf Updates'),
      content: const SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('moocp fragt bei GitHub nach der neuesten Version.'),
          SizedBox(height: 16),
          LinearProgressIndicator(),
        ]),
      ),
      actions: [TextButton(onPressed: abbrechen, child: const Text('Abbrechen'))],
    );
  }
}

/// Das Angebot und, nach dem Ja, der Download. Beides in einem Dialog: Wer
/// „Herunterladen und installieren" wählt, soll nicht noch einmal gefragt
/// werden.
class _AngebotDialog extends StatefulWidget {
  const _AngebotDialog({
    required this.neu,
    required this.eigene,
    required this.update,
    required this.einstellungen,
    required this.protokoll,
    required this.sitzungLaeuft,
  });

  final NeueVersion neu;
  final String eigene;
  final Update update;
  final Einstellungen einstellungen;
  final Protokoll protokoll;
  final bool sitzungLaeuft;

  @override
  State<_AngebotDialog> createState() => _AngebotDialogState();
}

class _AngebotDialogState extends State<_AngebotDialog> {
  bool _laedt = false;
  int _geladen = 0;
  int? _gesamt;
  String? _fehler;

  /// Für den Kasten mit den Änderungen: Der Text eines Releases kann lang
  /// sein, und ohne sichtbaren Balken sieht niemand, dass darunter noch
  /// etwas steht.
  final _rollen = ScrollController();

  @override
  void dispose() {
    _rollen.dispose();
    super.dispose();
  }

  double? get _anteil {
    final g = _gesamt;
    if (g == null || g <= 0) return null;
    return (_geladen / g).clamp(0.0, 1.0);
  }

  Future<void> _holenUndStarten() async {
    setState(() {
      _laedt = true;
      _fehler = null;
    });
    try {
      final datei = await widget.update.herunterladen(widget.neu, (geladen, gesamt) {
        if (!mounted) return;
        setState(() {
          _geladen = geladen;
          _gesamt = gesamt;
        });
      });
      await installerStarten(datei, widget.neu.version, widget.einstellungen, widget.protokoll);
      if (mounted) Navigator.pop(context, true);
    } on UpdateAbgebrochen {
      widget.protokoll.eintrag(Art.info, 'Update: Download abgebrochen');
      if (mounted) Navigator.pop(context, false);
    } on UpdateFehler catch (e) {
      if (mounted) {
        setState(() {
          _laedt = false;
          _fehler = e.meldung;
        });
      }
    } catch (e) {
      widget.protokoll.eintrag(Art.fehler, 'Update: Installer nicht gestartet (${e.runtimeType})');
      if (mounted) {
        setState(() {
          _laedt = false;
          _fehler = 'Der Installer ließ sich nicht starten (${e.runtimeType}).';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final klein = Theme.of(context).textTheme.bodySmall;
    final text = widget.neu.beschreibung;
    return AlertDialog(
      title: Text('Version ${widget.neu.version} ist verfügbar'),
      content: SizedBox(
        width: 560,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sie verwenden moocp ${widget.eigene}.'),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Was sich ändert:', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: Scrollbar(
                controller: _rollen,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _rollen,
                  // Platz für den Balken, sonst liegt er auf dem Text.
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(text, style: klein),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
              'Der Installer wird von GitHub geladen und läuft sichtbar ab. moocp schließt '
              'sich dafür und startet danach wieder. Einstellungen, gespeicherte Anmeldedaten '
              'und die Einrichtung der KI-Werkzeuge bleiben erhalten.',
              style: klein),
          if (widget.sitzungLaeuft) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Eine laufende Sitzung im KI-Werkzeug verliert dabei die Verbindung zur App und '
                      'muss neu gestartet werden.',
                      style: klein)),
            ]),
          ],
          if (_fehler != null) ...[
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.error_outline, size: 18, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Expanded(child: Text(_fehler!)),
            ]),
          ],
          if (_laedt) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _anteil),
            const SizedBox(height: 4),
            Text(
                _anteil == null
                    ? 'Lädt … ${(_geladen / (1024 * 1024)).toStringAsFixed(1)} MB'
                    : 'Lädt … ${(_anteil! * 100).round()} %',
                style: klein),
          ],
        ]),
      ),
      actions: _laedt
          ? [TextButton(onPressed: widget.update.abbrechen, child: const Text('Abbrechen'))]
          : [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Jetzt nicht')),
              FilledButton(
                onPressed: _holenUndStarten,
                child: Text(_fehler == null ? 'Herunterladen und installieren' : 'Nochmal versuchen'),
              ),
            ],
    );
  }
}
