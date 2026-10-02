#!/usr/bin/env python3
"""Meldet zurueckgekehrte ae/ue/oe-Transliterationen im Fliesstext.

Deutsche Texte in Doku, Kommentaren und Meldungen sollen echte Umlaute
verwenden -- UTF-8 funktioniert ueberall, auch im Frontmatter von SKILL.md
(nachgemessen: eine description mit Umlauten wird einwandfrei geladen).

ASCII bleibt nur an zwei Stellen richtig:
  - Bezeichner (pruefeSitzung, verfuegbareTypen, HELFER_SCHLUESSEL, ...)
  - der Block VERDACHTSMUSTER, wo beide Schreibweisen absichtlich stehen
  - Datei- und Ordnernamen (pruefung/, pruefe-api.py, ...)

Das Skript kennt dieselbe Wortliste wie umlaute.py. Findet es einen Treffer
ausserhalb der Schutzzonen, ist beim Schreiben jemand in die alte Gewohnheit
zurueckgefallen -- dann `python umlaute.py` laufen lassen.
"""
import io
import os
import re
import sys

HIER = os.path.dirname(os.path.abspath(__file__))
WURZEL = os.path.dirname(HIER)

sys.path.insert(0, WURZEL)
try:
    from umlaute import WORTE, BEZEICHNER, PFADE, VERDACHT_BLOCK
except ImportError:
    print('FEHLER: umlaute.py nicht gefunden - es haelt die Wortliste.')
    sys.exit(1)


def entschaerft(text):
    """Schutzzonen entfernen, damit sie keine Treffer erzeugen."""
    # Inline-Code ist Zitat, nicht Prosa: In `Lueckentext` steht das Wort
    # absichtlich als Gegenbeispiel, und Bezeichner stehen ohnehin in Backticks.
    text = re.sub(r'`[^`\n]*`', ' ', text)
    text = VERDACHT_BLOCK.sub(' ', text)
    text = PFADE.sub(' ', text)
    for name in sorted(BEZEICHNER, key=len, reverse=True):
        text = re.sub(r'\b' + re.escape(name) + r'\b', ' ', text)
    return text


def main():
    treffer = []
    for w, verz, namen in os.walk(WURZEL):
        verz[:] = [d for d in verz if d not in ('__pycache__',)]
        for n in sorted(namen):
            if not n.endswith(('.md', '.js')):
                continue
            p = os.path.join(w, n)
            roh = io.open(p, encoding='utf-8', newline='').read()
            text = entschaerft(roh.replace('\r\n', '\n'))
            for zeilennr, zeile in enumerate(text.split('\n'), 1):
                for wort in WORTE:
                    if re.search(r'\b' + wort + r'\b', zeile):
                        treffer.append((os.path.relpath(p, WURZEL), zeilennr, wort))

    # Die Gegenrichtung: ein Dateiname, der faelschlich Umlaute bekommen hat.
    #
    # umlaute.py parkt Pfade, bevor die Wortliste greift -- aber das Muster hat
    # schon zweimal eine Luecke gehabt. Beim ersten Mal wurde aus
    # "pruefung/pruefe-api.py" ein "pruefung/pruefe-api.py" mit Umlauten, beim
    # zweiten Mal traf es "pruefe-*.cjs", weil das Sternchen nicht im
    # Zeichenvorrat stand. Beide Male waren es Namen, die es auf der Platte
    # nicht gibt -- und beide Male ist es erst spaeter aufgefallen.
    # Genau diese Stellen zitieren die kaputte Form absichtlich, weil sie davor
    # warnen. Exakter Wortlaut -- aendert sich der Satz, meldet sich der Test,
    # und das ist richtig so.
    ZITATE = ('`prüfung/prüfe-api.py`',)

    kaputt = []
    for w, verz, namen in os.walk(WURZEL):
        verz[:] = [d for d in verz if d not in ('__pycache__',)]
        for n in sorted(namen):
            if not n.endswith(('.md', '.js', '.py', '.cjs')):
                continue
            p2 = os.path.join(w, n)
            for zeilennr, zeile in enumerate(
                    io.open(p2, encoding='utf-8', newline='').read().split('\n'), 1):
                if n in ('umlaute.py', 'pruefe-umlaute.py'):
                    continue    # dort stehen die kaputten Formen absichtlich
                rein = zeile
                for zitat in ZITATE:
                    rein = rein.replace(zitat, '')
                for muster in ('prüfung/', 'prüfe-', 'prüfe_'):
                    if muster in rein:
                        kaputt.append((os.path.relpath(p2, WURZEL), zeilennr, muster))

    if kaputt:
        print('%d falsch umlautete(r) Dateiname(n) -- diese Pfade gibt es nicht:'
              % len(kaputt))
        for datei, nr, m in kaputt:
            print('  %-46s Zeile %-4d %s' % (datei, nr, m))
        print('\nVon Hand zurueckschreiben und den Pfadschutz in umlaute.py pruefen.')
        return 1

    if not treffer:
        print('OK -- keine Transliterationen im Fliesstext (%d Woerter geprueft), '
              'keine umlauteten Dateinamen.' % len(WORTE))
        return 0

    print('%d Transliteration(en) gefunden:' % len(treffer))
    for datei, nr, wort in treffer[:40]:
        print('  %-46s Zeile %-4d %s' % (datei, nr, wort))
    if len(treffer) > 40:
        print('  ... und %d weitere' % (len(treffer) - 40))
    print('\nBeheben mit: python umlaute.py')
    return 1


if __name__ == '__main__':
    sys.exit(main())
