#!/usr/bin/env python3
"""Stellt Fliesstext in Doku, Kommentaren und Meldungen auf echte Umlaute um.

Warum nicht blind ersetzen: "Quelle", "neue", "zuerst", "teuer", "Konsequenzen",
"bauen" und viele weitere enthalten ae/ue/oe voellig legitim. Deshalb eine
kuratierte Wortliste statt einer Regel.

Drei Schutzzonen bleiben unberuehrt:

  1. Bezeichner (pruefeSitzung, verfuegbareTypen, HELFER_SCHLUESSEL, ...).
     Umlaute in Namen waeren zwar gueltiges JavaScript, aber der Helfer wird
     als Zeichenkette gespeichert und wieder ausgewertet -- da will man keine
     Kodierungsfragen.
  2. Der Block VERDACHTSMUSTER. Dort stehen beide Schreibweisen absichtlich
     nebeneinander (schuelerdaten|schülerdaten), damit beide erkannt werden.
  3. Das Frontmatter von SKILL.md. Die description bleibt ASCII -- siehe
     Kommentar unten.

Einmalig gedacht, aber wiederholbar: Was schon umgestellt ist, bleibt gleich.
"""
import io
import os
import re
import sys

HIER = os.path.dirname(os.path.abspath(__file__))

# Nur echte Transliterationen. Reihenfolge egal, es wird wortweise ersetzt.
WORTE = {
    'aendern': 'ändern', 'aendert': 'ändert', 'geaendert': 'geändert',
    'Geaendert': 'Geändert', 'veraendert': 'verändert', 'veraendernde': 'verändernde',
    'Abhaengigkeiten': 'Abhängigkeiten', 'angehaengter': 'angehängter',
    'eingehaengt': 'eingehängt', 'unabhaengig': 'unabhängig',
    'Sprachunabhaengig': 'Sprachunabhängig',
    'Aktivitaet': 'Aktivität', 'Aktivitaeten': 'Aktivitäten',
    'Autoritaet': 'Autorität', 'Auffaelliges': 'Auffälliges',
    'enthaelt': 'enthält', 'faellt': 'fällt', 'Faelle': 'Fälle', 'faengt': 'fängt',
    'haelt': 'hält', 'laedt': 'lädt', 'laesst': 'lässt', 'Laeuft': 'Läuft',
    'laeuft': 'läuft', 'gaebe': 'gäbe', 'saehe': 'sähe', 'waere': 'wäre',
    'waehrend': 'während', 'gewaehlt': 'gewählt', 'klaeren': 'klären',
    'erklaert': 'erklärt', 'Erklaerung': 'Erklärung',
    'eingeschraenkt': 'eingeschränkt', 'staendig': 'ständig',
    'tatsaechlich': 'tatsächlich', 'haeufigsten': 'häufigsten',
    'naechste': 'nächste', 'naechsten': 'nächsten',
    'zaehlen': 'zählen', 'zaehlt': 'zählt', 'Nachzaehlen': 'Nachzählen',
    'vollstaendig': 'vollständig', 'vollstaendigen': 'vollständigen',
    'zuverlaessig': 'zuverlässig', 'zuverlaessigste': 'zuverlässigste',
    'Verlaessliches': 'Verlässliches', 'zufaellige': 'zufällige',
    'zusaetzlich': 'zusätzlich', 'zusaetzliches': 'zusätzliches',
    'Vorgaenger': 'Vorgänger', 'Zustaende': 'Zustände',
    'Nutzerpraeferenz': 'Nutzerpräferenz', 'Bestaetigt': 'Bestätigt',
    'muessen': 'müssen', 'fuer': 'für', 'Fuer': 'Für', 'fuers': 'fürs',
    'fuehre': 'führe', 'fuehrt': 'führt', 'ausgefuehrt': 'ausgeführt',
    'einfuegen': 'einfügen', 'hinzugefuegt': 'hinzugefügt',
    'genuegend': 'genügend', 'endgueltig': 'endgültig', 'kuenftige': 'künftige',
    'frueh': 'früh', 'gewuenscht': 'gewünscht', 'wuerde': 'würde',
    'Luecken': 'Lücken', 'Lueckentext': 'Lückentext',
    'Schluessel': 'Schlüssel', 'Schuelerabgaben': 'Schülerabgaben',
    'geschuetzt': 'geschützt', 'schuetzt': 'schützt',
    'mitfuehrt': 'mitführt', 'befuellt': 'befüllt', 'Befuellen': 'Befüllen',
    'nachgeruestet': 'nachgerüstet', 'nachruesten': 'nachrüsten',
    'Zeilenumbrueche': 'Zeilenumbrüche',
    'ueber': 'über', 'ueberein': 'überein', 'uebergeben': 'übergeben',
    'uebergibt': 'übergibt', 'ueberhaupt': 'überhaupt', 'ueberlebt': 'überlebt',
    'ueberschreib': 'überschreib', 'ueberschreiben': 'überschreiben',
    'ueberschreibt': 'überschreibt', 'uebersetzte': 'übersetzte',
    'uebertragen': 'übertragen', 'Bewertungsuebersicht': 'Bewertungsübersicht',
    'zurueck': 'zurück', 'zurueckgelesene': 'zurückgelesene',
    'zurueckgenommen': 'zurückgenommen', 'Zurueckdrehen': 'Zurückdrehen',
    'Zuruecklesen': 'Zurücklesen', 'rueckgaengig': 'rückgängig',
    'Rueckfragen': 'Rückfragen', 'Rueckfragepflichten': 'Rückfragepflichten',
    'Rueckgabewert': 'Rückgabewert', 'Rueckleseprobe': 'Rückleseprobe',
    'oeffnen': 'öffnen', 'ausloesen': 'auslösen', 'unnoetig': 'unnötig',
    'geloescht': 'gelöscht', 'loesche': 'lösche', 'loescht': 'löscht',
    'Loeschen': 'Löschen', 'Loesung': 'Lösung', 'Loesungen': 'Lösungen',
    'Loesungsordner': 'Lösungsordner',
    'gehoert': 'gehört', 'gehoeren': 'gehören', 'hingehoeren': 'hingehören',
    'hoehere': 'höhere', 'koennen': 'können', 'koennte': 'könnte',
    'Moegliche': 'Mögliche', 'gewoehnliche': 'gewöhnliche',
    'ungewoehnlich': 'ungewöhnlich', 'Oberflaeche': 'Oberfläche',
    'spaeter': 'später', 'spaetere': 'spätere', 'spaeteren': 'späteren',
}

# Diese Namen bleiben ASCII und werden waehrend der Ersetzung geschuetzt.
BEZEICHNER = [
    'pruefeSitzung', 'pruefeSchutz', 'pruefeTest', 'verfuegbareTypen',
    'unterstuetzteTypen', 'modulUnterstuetzt', 'UNTERSTUETZT',
    'HELFER_SCHLUESSEL', 'zufallHinzufuegen', 'fragenHinzufuegen',
    'frageHinzufuegen', 'tatsaechlichAngelegt', 'ueberschriftenAbloesen',
    'freieHoehe', 'inhaltsBloecke', 'entschaerfe', 'unterstuetzt',
]

# "pruefe..." ist zugleich deutsches Wort und Praefix von Funktionsnamen:
# nur ersetzen, wenn KEIN Grossbuchstabe folgt.
SONDER = [
    (re.compile(r'\bpruefen\b'), 'prüfen'),
    (re.compile(r'\bpruefbar\b'), 'prüfbar'),
    (re.compile(r'\bPrueft\b'), 'Prüft'),
    (re.compile(r'\bPruefen\b'), 'Prüfen'),
    (re.compile(r'\bPruefung\b'), 'Prüfung'),
    (re.compile(r'\bPruefungen\b'), 'Prüfungen'),
    (re.compile(r'\bpruefung\b'), 'prüfung'),
    (re.compile(r'\bpruefe(?![A-Za-z])'), 'prüfe'),
]

VERDACHT_BLOCK = re.compile(r'(VERDACHTSMUSTER = \[.*?\n\s*\];)', re.S)
FRONTMATTER = re.compile(r'\A(---\r?\n.*?\r?\n---\r?\n)', re.S)

# Vierte Schutzzone: Datei- und Ordnernamen. Der erste Lauf hat aus
# "pruefung/pruefe-sperrliste.cjs" ein "prüfung/prüfe-sperrliste.cjs" gemacht --
# Namen, die es auf der Platte nicht gibt. Pfade werden deshalb geparkt, bevor
# die Wortliste greift.
PFADE = re.compile(
    r'\b[\w./-]*pruefung/[\w./-]*'      # alles unter pruefung/
    r'|\bpruefe-[\w.*-]+'               # pruefe-sperrliste.cjs, pruefe-api.py, pruefe-*.cjs
    r'|\b[\w*-]+\.(?:cjs|js|py|md|xml|skill)\b'  # sonstige Dateinamen, auch mit *
    # Werkzeuge der App, als Aufruf geschrieben: aendern(ordner, …). Die Namen
    # mit Unterstrich (test_aendern) trifft die Wortliste ohnehin nicht.
    r'|\b(?:aendern|loeschen)(?=\()'
)


def umstellen(text):
    platzhalter = {}

    def parke(m):
        k = '\x00P%d\x00' % len(platzhalter)
        platzhalter[k] = m.group(0)
        return k

    # Schutzzonen parken
    text = FRONTMATTER.sub(parke, text)
    text = VERDACHT_BLOCK.sub(parke, text)
    text = PFADE.sub(parke, text)
    for name in sorted(BEZEICHNER, key=len, reverse=True):
        text = re.sub(r'\b' + re.escape(name) + r'\b', parke, text)

    for alt, neu in WORTE.items():
        text = re.sub(r'\b' + alt + r'\b', neu, text)
    for muster, neu in SONDER:
        text = muster.sub(neu, text)

    for k, v in platzhalter.items():
        text = text.replace(k, v)
    return text


def main():
    geaendert = 0
    for w, verz, namen in os.walk(HIER):
        verz[:] = [d for d in verz if d not in ('pruefung', '__pycache__')]
        for n in sorted(namen):
            if not n.endswith(('.md', '.js')):
                continue
            p = os.path.join(w, n)
            s = io.open(p, encoding='utf-8', newline='').read()
            crlf = '\r\n' in s
            t = umstellen(s.replace('\r\n', '\n'))
            if crlf:
                t = t.replace('\n', '\r\n')
            if t != s:
                io.open(p, 'w', encoding='utf-8', newline='').write(t)
                print('  %s' % os.path.relpath(p, HIER))
                geaendert += 1
    print('%d Datei(en) umgestellt.' % geaendert)
    return 0


if __name__ == '__main__':
    sys.exit(main())
