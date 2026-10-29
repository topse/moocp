// Der Dialog „Claude einrichten": zeigt, was an Verbindung und Skills nicht
// zu dieser App passt, und schreibt erst nach dem Klick auf „Installieren".
//
// Die App läuft nur eingerichtet. Wer nicht einrichten kann oder will,
// beendet sie hier; einen Zustand „die App läuft, aber Claude kann nicht mit
// ihr arbeiten" gibt es nicht. Darum kein „Abbrechen", und nach einem Fehler
// „Nochmal versuchen" statt weiter. Ein Skill, der nicht zur App passt, ruft
// Werkzeuge falsch auf. Haken gibt es nur bei den wählbaren Skills
// (wahlSkills in einrichtung.dart); was gewählt ist, wird genauso streng
// geprüft wie der Rest, was abgewählt ist, entfernt „Installieren".
//
// Die App öffnet den Dialog beim Start, wenn etwas nicht passt, und jederzeit
// über den Knopf „Claude einrichten" in der Titelzeile.
//
// Rückgabe: true, wenn alles eingerichtet ist; sonst beendet der Aufrufer
// die App.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'einrichtung.dart';
import 'einstellungen.dart';
import 'log.dart';
import 'protokoll.dart';

class EinrichtungDialog extends StatefulWidget {
  const EinrichtungDialog({
    required this.stand,
    required this.pruefen,
    required this.einstellungen,
    required this.protokoll,
    required this.orte,
    super.key,
  });

  /// Stand der Prüfung beim Start; null, wenn sie fehlgeschlagen ist.
  final Einrichtungsstand? stand;

  /// Dieselbe Prüfung wie beim Start, für „Nochmal prüfen" und nach dem
  /// Installieren.
  final Future<Einrichtungsstand> Function() pruefen;

  final Einstellungen einstellungen;
  final Protokoll protokoll;
  final ClaudeOrte orte;

  @override
  State<EinrichtungDialog> createState() => _EinrichtungDialogState();
}

class _EinrichtungDialogState extends State<EinrichtungDialog> {
  late Einrichtungsstand? _s = widget.stand;
  bool _laeuft = false;

  /// Ob in diesem Dialog etwas installiert wurde: Dann braucht es eine neue
  /// Claude-Sitzung.
  bool _installiert = false;

  /// Ergebnis je Zeile nach dem letzten Installieren; steht dort statt des
  /// Stands. Schlüssel: „verbindung" oder der Name des Skills.
  Map<String, String> _ergebnis = {};

  bool get _bereit => _s != null && !_s!.brauchtEtwas;

  Future<Einrichtungsstand?> _neuPruefen() async {
    try {
      return await widget.pruefen();
    } catch (x, st) {
      widget.protokoll.eintrag(Art.fehler, 'Claude einrichten: Prüfung fehlgeschlagen: ${fehlerBeschreibung(x, st)}');
      return null;
    }
  }

  Future<void> _nochmalPruefen() async {
    setState(() => _laeuft = true);
    final neu = await _neuPruefen();
    if (!mounted) return;
    setState(() {
      _s = neu;
      _ergebnis = {};
      _laeuft = false;
    });
  }

  /// Haken bei einem wählbaren Skill: gleich speichern und neu prüfen, damit
  /// die Zeilen zeigen, was „Installieren" jetzt tun würde.
  Future<void> _waehlen(String name, bool an) async {
    final e = widget.einstellungen;
    final neu = {...?_s?.gewaehlt};
    an ? neu.add(name) : neu.remove(name);
    e.wahlSkills = neu;
    try {
      await e.speichern();
    } catch (x, st) {
      widget.protokoll.eintrag(Art.fehler, 'Claude einrichten: Wahl nicht gespeichert: ${fehlerBeschreibung(x, st)}');
    }
    await _nochmalPruefen();
  }

  Future<void> _installieren() async {
    final s = _s!;
    setState(() => _laeuft = true);
    final e = widget.einstellungen;
    final fehler = <String, String>{};
    final geblieben = <String, List<String>>{};
    if (s.verbindung != Verbindung.aktuell) {
      try {
        final f = await verbindungEintragen(s.claude!, e.port, e.schluessel);
        if (f != null) fehler['verbindung'] = f;
      } catch (x, st) {
        fehler['verbindung'] = 'Fehler (${x.runtimeType})';
        widget.protokoll.eintrag(Art.fehler, 'Claude einrichten: Verbindung: ${fehlerBeschreibung(x, st)}');
      }
    }
    for (final paket in s.gewollt) {
      if (s.stand[paket.name]!.aktuell) continue;
      try {
        geblieben[paket.name] = skillInstallieren(paket, Directory(p.join(widget.orte.skills.path, paket.name)));
      } catch (x, st) {
        fehler[paket.name] = 'Fehler (${x.runtimeType})';
        widget.protokoll.eintrag(Art.fehler, 'Claude einrichten: Skill ${paket.name}: ${fehlerBeschreibung(x, st)}');
      }
    }
    for (final name in s.entfernen) {
      try {
        geblieben[name] = skillEntfernen(Directory(p.join(widget.orte.skills.path, name)));
      } catch (x, st) {
        fehler[name] = 'Fehler (${x.runtimeType})';
        widget.protokoll.eintrag(Art.fehler, 'Claude einrichten: Skill $name entfernen: ${fehlerBeschreibung(x, st)}');
      }
    }

    // Ob es angekommen ist, sagt dieselbe Prüfung wie beim Start, nicht der
    // Rückgabewert von claude mcp add.
    final neu = await _neuPruefen();
    final ergebnis = <String, String>{};
    if (neu != null) {
      if (s.verbindung != Verbindung.aktuell) {
        if (neu.verbindung == Verbindung.aktuell) {
          ergebnis['verbindung'] = 'erledigt';
          widget.protokoll.eintrag(Art.info, 'Claude einrichten: Verbindung eingetragen');
        } else {
          final f = fehler['verbindung'];
          ergebnis['verbindung'] = 'nicht angekommen${f == null ? '' : ' ($f)'}';
          widget.protokoll.eintrag(Art.fehler, 'Claude einrichten: Verbindung ${ergebnis['verbindung']}');
        }
      }
      for (final name in s.entfernen) {
        if (!neu.entfernen.contains(name)) {
          ergebnis[name] = 'entfernt';
          widget.protokoll.eintrag(Art.info, 'Claude einrichten: Skill $name entfernt');
        } else {
          final weg = geblieben[name] ?? const <String>[];
          ergebnis[name] = fehler[name] ?? 'nicht entfernt${weg.isEmpty ? '' : ': ${weg.join(', ')}'}';
          widget.protokoll.eintrag(Art.fehler, 'Claude einrichten: Skill $name ${ergebnis[name]}');
        }
      }
      for (final paket in s.gewollt) {
        if (s.stand[paket.name]!.aktuell) continue;
        final jetzt = neu.stand[paket.name]!;
        if (jetzt.aktuell) {
          ergebnis[paket.name] = 'erledigt';
          widget.protokoll.eintrag(Art.info, 'Claude einrichten: Skill ${paket.name} installiert');
        } else if (fehler[paket.name] != null) {
          ergebnis[paket.name] = fehler[paket.name]!;
        } else {
          final weg = geblieben[paket.name] ?? const <String>[];
          final rest = weg.isEmpty ? '' : ', nicht entfernbar: ${weg.join(', ')}';
          ergebnis[paket.name] = 'weicht noch ab: ${jetzt.text}$rest';
          widget.protokoll.eintrag(Art.fehler, 'Claude einrichten: Skill ${paket.name} ${ergebnis[paket.name]}');
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _s = neu;
      _ergebnis = ergebnis;
      _installiert = true;
      _laeuft = false;
    });
  }

  String _verbindungText(Einrichtungsstand s) {
    if (s.verbindung == Verbindung.aktuell) return 'aktuell';
    if (s.claude == null) return 'nicht möglich: Claude Code nicht gefunden';
    return switch (s.verbindung) {
      Verbindung.aktuell => 'aktuell',
      Verbindung.fehlt => 'nicht eingetragen',
      Verbindung.veraltet => 'Schlüssel muss aktualisiert werden',
      Verbindung.unlesbar => 'muss neu eingetragen werden',
    };
  }

  Widget _zeile(String titel, String schluessel, bool aktuell, String stand) {
    final gescheitert = !aktuell && _ergebnis.containsKey(schluessel);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        aktuell
            ? Icons.check_circle
            : gescheitert
                ? Icons.error_outline
                : Icons.radio_button_unchecked,
        color: aktuell
            ? Colors.green
            : gescheitert
                ? Theme.of(context).colorScheme.error
                : null,
      ),
      title: Text(titel),
      subtitle: Text(_ergebnis[schluessel] ?? stand),
    );
  }

  /// Ein wählbarer Skill: Haken statt Statussymbol, darunter wofür er ist und
  /// was mit ihm geschieht.
  Widget _wahlZeile(Einrichtungsstand s, SkillPaket paket) {
    final name = paket.name;
    final an = s.gewaehlt.contains(name);
    final stand = s.stand[name]!;
    final was = _ergebnis[name] ??
        (an
            ? stand.text
            : s.entfernen.contains(name)
                ? 'nicht gewählt, wird entfernt'
                : 'nicht gewählt');
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: an,
      onChanged: _laeuft ? null : (v) => _waehlen(name, v ?? false),
      title: Text('Skill $name'),
      subtitle: Text('${wahlSkills[name]}\n$was'),
    );
  }

  Widget _hinweis(String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final List<Widget> knoepfe;
    if (_bereit) {
      knoepfe = [FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Weiter'))];
    } else {
      final einrichtbar = s != null && s.einrichtbar;
      knoepfe = [
        TextButton(onPressed: _laeuft ? null : () => Navigator.pop(context, false), child: const Text('Beenden')),
        FilledButton(
          onPressed: _laeuft ? null : (einrichtbar ? _installieren : _nochmalPruefen),
          child: Text(!einrichtbar
              ? 'Nochmal prüfen'
              : _ergebnis.isEmpty
                  ? 'Installieren'
                  : 'Nochmal versuchen'),
        ),
      ];
    }
    return AlertDialog(
      title: const Text('Claude einrichten'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Damit Claude mit dieser App arbeiten kann, braucht Claude Code die Verbindung '
                'zur App und die Skills in der Fassung, die zu dieser App gehört. Wählbare Skills '
                'installiert die App nur mit Haken.'),
            const SizedBox(height: 8),
            if (s != null) ...[
              _zeile('Verbindung zu Claude Code', 'verbindung', s.verbindung == Verbindung.aktuell,
                  _verbindungText(s)),
              for (final paket in s.skills)
                if (!wahlSkills.containsKey(paket.name))
                  _zeile('Skill ${paket.name}', paket.name, s.stand[paket.name]!.aktuell, s.stand[paket.name]!.text),
              // Das Wählbare für sich, damit es nicht wie ein Pflichtteil aussieht.
              if (s.skills.any((x) => wahlSkills.containsKey(x.name))) ...[
                const Divider(height: 24),
                Text('Wählbar', style: Theme.of(context).textTheme.titleSmall),
                for (final paket in s.skills)
                  if (wahlSkills.containsKey(paket.name)) _wahlZeile(s, paket),
              ],
            ],
            if (s == null) _hinweis('Die Prüfung ist fehlgeschlagen; Einzelheiten stehen im Protokoll.'),
            if (s != null && !s.einrichtbar)
              _hinweis('Claude Code nicht gefunden. Claude Desktop installieren und dort einmal den '
                  'Bereich „Code" öffnen, danach „Nochmal prüfen".'),
            if (s != null && !s.python && s.gewaehlt.contains('lernsituation'))
              _hinweis('Python nicht gefunden. Die Selbstprüfung des Skills lernsituation läuft ohne '
                  'Python nicht; alles andere schon.'),
            if (_laeuft) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                  !_bereit
                      ? 'Ohne Verbindung und Skills kann Claude nicht mit dieser App arbeiten. '
                          '„Beenden" schließt die App.'
                      : _installiert
                          ? 'Eingerichtet. Neue Claude-Sitzung starten, damit die Änderungen wirken.'
                          : 'Verbindung und Skills sind aktuell.',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
          ]),
        ),
      ),
      actions: knoepfe,
    );
  }
}
