#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Prüft eine Lernsituation auf das, was sich prüfen lässt -- den Entwurf
oder den Stand in Moodle.

    python pruefe-lernsituation.py <entwurf>
    python pruefe-lernsituation.py --moodle <arbeitsordner> <abschnitt_id>

Der Entwurf ist ein Ordner im Arbeitsordner der App, schon in der Form, die
die Werkzeuge nehmen (references/vorlagen.md): lernsituation.json mit dem
Abschnitt und den Aktivitäten in ihrer Reihenfolge, je Aktivität ein Ordner
mit page.html bzw. introeditor.html und dateien/, ein Buch mit kapitel.json
und kapitel-<id>/content_editor.html. Die zweite Form prüft einen Abschnitt,
den der Skill moodle gerade gelesen hat (kurs_uebersicht, aktivitaet_lesen
je Aktivität, buch_lesen je Buch) -- dieselben Prüfungen, dazu die Links
zwischen den Blättern (unten, „Entwurf und Stand in Moodle").

Geprüft wird die FORM aus references/vorlagen.md -- nicht, ob die
Lernsituation gut ist. Das kann kein Skript. Was es kann:

  - Handreichung vorhanden, ohne SchuCu-Tabelle, mit eigenen Abschnitten zu
    Lernumgebung und Leistungsbewertung (sie kommt ohne die Tabelle aus)
  - Seite „SchuCu" mit nichts als der Tabelle nach einer der CD-Vorlagen
    (references/schucu-*.html) -- Zeilen, Klassen und Kopflink unverändert,
    jede Datenzelle gefüllt, keine Platzhalter; darunter die Absätze der
    Vorlage, der KI-Hinweis wörtlich
  - jedes Arbeitsblatt (auch Hilfe und Vertiefung) hat eine Lösung
  - der Name jedes Blatts beginnt mit seiner Kennung („Arbeitsblatt 2: …")
  - jedes Blatt ausser den Lösungen steht mit seiner Kennung im Ablaufplan
    oder mit seinem Namen in der Materialübersicht; jede genannte Kennung
    gibt es
  - Zeiten im Ablaufplan: Summenzeile stimmt, Summe passt zum Zeitrichtwert
  - jede Aufgabe auf einem Arbeitsblatt trägt (n min · Sozialform · AFB x)
  - Aufgabenzeiten je Blatt gegen "Zeit gesamt" im Kopf
  - Lösung hat dieselben Aufgabennummern wie das Blatt
  - Checkliste vollständig beantwortet, mit Begründung
  - Links ausgeschrieben (kein „hier" als Linktext), keine protokollrelativen
    Adressen
  - Zeichnungen: eingebundene SVG vorhanden, mit <title> und <desc>
  - jedes Blatt steht für sich: Abschnitte „1. …", Abbildungen und Aufgaben
    zählen je Blatt ab 1 ohne Präfix; "Abb. n" ohne Blattkennung gibt es auf
    dem eigenen Blatt; Verweise auf Abschnitte, Abbildungen und Aufgaben
    anderer Blätter treffen etwas, das es dort gibt; "Lies"-Zeilen der
    Arbeitsblätter und "→ für"-Zeilen der Infoblätter stimmen in beide
    Richtungen; "Gehört zu" nennt jedes Blatt, das das Infoblatt unter
    "Dazu" oder "Lies" verwendet
  - jede weitere Aktivität (Board, Kanban, Wiki, Fortschrittsliste, Test,
    Verzeichnis, Datei, Link) trägt keine Kennung und steht mit ihrem Namen
    in Anführungszeichen im Ablaufplan oder in der Materialübersicht; was
    dort in Anführungszeichen steht, gibt es
  - nur im Entwurf: lernsituation.json vollständig, jeder Ordner darin
    genannt, jedes Bild in dateien/ seines Blatts, die HTML-Regeln
    (references/html.md), keine Formelfehler, keine Platzhalter, kein Markdown, kein Name eines Ordners oder
    einer Zeichnung im Text; jede weitere Aktivität mit dem, was ihre
    Übertragung braucht (Spalten, Einträge, Seiten, Fragen mit Sachnummer
    und Ort, Dateien, Adresse)
  - nur in Moodle: jede Nennung eines Blatts ist ein Link auf seine
    Aktivität, mit passendem Text, ebenso der Name einer weiteren Aktivität
    in Anführungszeichen, und keine für Lernende erreichbare Seite verlinkt
    eine Lösung

Rückgabe 0 = keine Befunde, 1 = Befunde, 2 = nichts zu prüfen.
"""
import gzip
import html
import io
import json
import os
import re
import shutil
import sys
import tempfile
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from urllib.parse import unquote

# Windows-Konsole: Umlaute in der Ausgabe nicht zerreissen.
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

USTD = 45

# Die CD-Vorlagen liegen im Skill; sie sind die einzige Quelle für den Aufbau
# der SchuCu-Tabelle. Das Skript liest sie, statt eine Abschrift zu führen.
VORLAGEN = {
    'Berufsschule': 'schucu-berufsschule.html',
    'Berufliches Gymnasium': 'schucu-bg.html',
}
VORLAGEN_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'references')

# Die Prüfform (unten, „Entwurf und Stand in Moodle") legt jede Aktivität als
# Textdatei ab; diese Namen trägt sie. Die Handreichung und die Seite
# „SchuCu" -- die SchuCu-Tabelle steht allein auf einer eigenen Seite, in
# Moodle der ersten Aktivität des Abschnitts, damit sie bei einer Inspektion
# sofort zu finden ist.
HAND = '00-lehrerhandreichung.md'
SCHUCU = '00-schucu.md'

# Die Tabelle samt den Absätzen, die die Vorlage darunter setzt (KI-Hinweis,
# im Beruflichen Gymnasium davor die Legende der Kompetenzbereiche).
TABELLE_RE = re.compile(r'<table class="lernsituation">.*?</table>'
                        r'(?:\s*<p\b[^>]*>.*?</p>)*', re.S)

# ---- Jedes Blatt steht für sich --------------------------------------------
# Ein Blatt wird einzeln gedruckt, ausgeteilt und Wochen später einzeln
# nachgelesen; in Moodle ist es eine eigene Seite. Deshalb zählt jedes Blatt
# ab 1, und ein Bezug auf ein anderes Blatt nennt dessen Kennung und die
# Stelle. Die Formen sind fest (references/vorlagen.md), weil sich nur feste
# Formen prüfen lassen: "Abb. 1" ohne Kennung meint das eigene Blatt, eine
# Kennung irgendwo in der Nähe zählt nicht. Alle Muster erlauben Zeilenumbrüche
# zwischen den Wörtern.
#
# Die Kennung ist der Anfang des Namens der Aktivität -- so findet man jedes
# genannte Blatt in der Kursübersicht wieder: "Arbeitsblatt 2", "Infoblatt 1",
# "Hilfe zu Arbeitsblatt 3", "Vertiefung zu Arbeitsblatt 2", "Lösung zu
# Arbeitsblatt 2", "Lösung zur Hilfe zu Arbeitsblatt 3". In Moodle wird jeder
# Verweis ein Link mit der Kennung als Text -- online zum Klicken, gedruckt
# bleibt der Text.
BLATT = r'(?:(?:Hilfe|Vertiefung)\s+zu\s+)?(?:Arbeitsblatt|Infoblatt)\s+\d+'
# Wie ein Verweis sein Ziel nennt: Kennung oder die Lösung dazu.
ZIEL = r'(?:Lösung\s+zur?\s+)?%s' % BLATT
# Ein eingebundenes Bild in der Prüfform.
BILD = re.compile(r'!\[[^\]]*\]\(([^)]+)\)')
# Nummern: "3", "1 und 4", "1 bis 3", "1–3", "1, 2 und 5".
NUMMERN = r'\d+(?:\s*(?:,|und|bis|–|-)\s*\d+)*'

ABSCHNITT_KOPF = re.compile(r'^##\s+(\d+)\.\s', re.M)
ABB_UNTERSCHRIFT = re.compile(r'^\*Abb\.\s*([^:*\n]+?)\s*:', re.M)
AUFGABE_KOPF = re.compile(r'^##\s+Aufgabe\s+(\d+)', re.M)
VERWEIS_ABSCHNITT = re.compile(r'(%s),\s*Abschnitte?\s+(%s)' % (ZIEL, NUMMERN))
VERWEIS_ABB = re.compile(r'Abb\.\s*(%s)\s+(?:auf|in(?:\s+der)?)\s+(%s)' % (NUMMERN, ZIEL))
VERWEIS_AUFGABE = re.compile(r'\bAufgaben?\s+(%s)\s+(?:auf|von)\s+(%s)|(%s),\s*Aufgaben?\s+(%s)'
                             % (NUMMERN, ZIEL, ZIEL, NUMMERN))
# "**Lies:**", "**Lest noch einmal:**", "**Lesen Sie:**" -- je Anrede; bis zur
# Leerzeile. Nennt sie ein Lehrbuch oder eine Adresse statt eines Infoblatts,
# gibt es hier nichts zu prüfen; ebenso bei "**Recherchiere:**".
LIES = re.compile(r'^\*\*(?:Lies|Lest|Lesen\s+Sie)\b[^*\n]*:\*\*(.*?)(?=\n[ \t]*\n|\Z)', re.M | re.S)
LIES_ZIEL = re.compile(r'(Infoblatt\s+\d+)(?:,\s*Abschnitte?\s+(%s))?' % NUMMERN)
# "→ für Arbeitsblatt 1, Aufgabe 2, und Hilfe zu Arbeitsblatt 1, Aufgabe 1"
# unter einem Abschnitt eines Infoblatts.
PFEIL = re.compile(r'^→\s*für\s+(.*?)(?=\n[ \t]*\n|\Z)', re.M | re.S)
PFEIL_ZIEL = re.compile(r'(%s),\s*Aufgaben?\s+(%s)' % (BLATT, NUMMERN))
# Kopfzeilen; sie dürfen umbrochen sein und enden am nächsten Feld.
DAZU = re.compile(r'\*\*Dazu:\*\*(.*?)(?=·|\*\*|\n[ \t]*\n|\Z)', re.S)
GEHOERT_ZU = re.compile(r'\*\*Gehört zu:\*\*(.*?)(?=·|\*\*|\n[ \t]*\n|\Z)', re.S)


def norm(t):
    return re.sub(r'\s+', ' ', t.replace('\xa0', ' ')).strip()


def nummern(s):
    """'1 und 4' -> [1, 4]; '1 bis 3' und '1–3' -> [1, 2, 3]."""
    raus = []
    for teil in re.split(r',|\bund\b', s):
        m = re.fullmatch(r'\s*(\d+)\s*(?:bis|–|-)\s*(\d+)\s*', teil)
        if m:
            raus.extend(range(int(m.group(1)), int(m.group(2)) + 1))
        elif teil.strip().isdigit():
            raus.append(int(teil))
    return raus


def kennung(datei):
    """Aus dem Namen in der Prüfform: AB-02-x-vertiefung.md ->
    ('Vertiefung zu Arbeitsblatt 2', False), die Lösung dazu ->
    ('Vertiefung zu Arbeitsblatt 2', True), AB-00-x.md ->
    ('Handlungssituation', False), alles, was kein Blatt ist -> (None, False)."""
    m = re.match(r'(AB|IB)-(\d+)-.*?(-hilfe|-vertiefung)?(-loesung)?\.md$', datei)
    if not m:
        return None, False
    nr = int(m.group(2))
    if m.group(1) == 'AB' and nr == 0:
        return 'Handlungssituation', False
    k = '%s %d' % ('Arbeitsblatt' if m.group(1) == 'AB' else 'Infoblatt', nr)
    if m.group(3):
        k = '%s zu %s' % ('Hilfe' if m.group(3) == '-hilfe' else 'Vertiefung', k)
    return k, bool(m.group(4))


def titel_soll(k, loesung):
    """Womit der Titel beginnt: die Kennung, bei einer Lösung mit
    "Lösung zu" / "Lösung zur" davor."""
    if not loesung:
        return k
    return ('Lösung zur ' if k.startswith(('Hilfe', 'Vertiefung')) else 'Lösung zu ') + k


def schluessel(s):
    """Ein Verweisziel so, wie es im Verzeichnis der Blätter steht."""
    return re.sub(r'^Lösung zur ', 'Lösung zu ', norm(s))


def gliederung(t):
    """Nummerierte Abschnitte, Bildunterschriften und Aufgaben eines Blatts."""
    return ([int(n) for n in ABSCHNITT_KOPF.findall(t)],
            ABB_UNTERSCHRIFT.findall(t),
            [int(n) for n in AUFGABE_KOPF.findall(t)])


class SchucuLeser(HTMLParser):
    """Zerlegt die SchuCu-Tabelle in Zeilen und Zellen.

    Je Zelle: Klasse, colspan, Text ohne <span> (das ist die Beschriftung),
    Text im <span>, Links (href, Text). Dazu die Absätze unter der Tabelle,
    je als [style, Text]."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.zeilen, self.zelle, self.span, self.a = [], None, 0, None
        self.absaetze, self.in_p = [], False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == 'tr':
            self.zeilen.append([])
        elif tag == 'td':
            self.zelle = {'klasse': a.get('class', ''), 'colspan': a.get('colspan', '1'),
                          'text': '', 'span': '', 'links': []}
            self.zeilen[-1].append(self.zelle)
        elif tag == 'span' and self.zelle is not None:
            self.span += 1
        elif tag == 'a' and self.zelle is not None:
            self.a = [a.get('href', ''), '']
            self.zelle['links'].append(self.a)
        elif tag == 'br' and self.zelle is not None:
            self.zelle['text'] += ' '
        elif tag == 'p' and self.zelle is None:
            self.in_p = True
            self.absaetze.append([a.get('style'), ''])
        elif tag == 'br' and self.in_p:
            self.absaetze[-1][1] += ' '

    def handle_endtag(self, tag):
        if tag == 'td':
            self.zelle = None
        elif tag == 'span' and self.span:
            self.span -= 1
        elif tag == 'a':
            self.a = None
        elif tag == 'p':
            self.in_p = False

    def handle_data(self, d):
        if self.zelle is not None:
            if self.span:
                self.zelle['span'] += d
            else:
                self.zelle['text'] += d
            if self.a is not None:
                self.a[1] += d
        elif self.in_p:
            self.absaetze[-1][1] += d


def lies_tabelle(roh):
    p = SchucuLeser()
    p.feed(roh)
    p.close()
    for z in p.zeilen:
        for c in z:
            c['text'], c['span'] = norm(c['text']), norm(c['span'])
            for l in c['links']:
                l[1] = norm(l[1])
    return p.zeilen, [(s, norm(t)) for s, t in p.absaetze]


def geruest(zeilen):
    """Aufbau ohne Inhalt: je Zelle Klasse, colspan und -- ausser bei
    Datenzellen -- die Beschriftung."""
    return [tuple((c['klasse'], c['colspan'], None if c['klasse'] == 'lsdata' else c['text'])
                  for c in z) for z in zeilen]


def vorlagen():
    raus = {}
    for name, datei in VORLAGEN.items():
        roh = io.open(os.path.join(VORLAGEN_DIR, datei), encoding='utf-8').read()
        zeilen, absaetze = lies_tabelle(roh)
        raus[name] = (geruest(zeilen), zeilen, absaetze)
    return raus


class Pruefung:
    def __init__(self, ordner, bilddateien=True, weitere=()):
        """`bilddateien`: ob ein eingebundenes Bild, das im Ordner fehlt, ein
        Befund ist. Am Entwurf nicht -- dort meldet lies_entwurf genauer, in
        welchem dateien/ es fehlt. `weitere`: {Name: wie ein Befund sie nennt}
        der weiteren Aktivitäten (WEITERE), die keine Blätter sind."""
        self.ordner = ordner
        self.bilddateien = bilddateien
        self.weitere = dict(weitere)
        self.zitiert = set()      # Namen in Anführungszeichen in Ablaufplan und Materialübersicht
        self.befunde = []
        self.hinweise = []

    def befund(self, datei, text):
        # Derselbe Verweis kann auf einem Blatt mehrmals stehen; ein Befund genügt.
        if (datei, text) not in self.befunde:
            self.befunde.append((datei, text))

    def hinweis(self, text):
        self.hinweise.append(text)

    def lies(self, name):
        p = os.path.join(self.ordner, name)
        return io.open(p, encoding='utf-8').read().replace('\r\n', '\n')

    # ---- Tabellen ---------------------------------------------------------
    @staticmethod
    def tabellen(text):
        """Alle Markdown-Tabellen als Liste von Zeilenlisten (Zellen getrimmt)."""
        raus, akt = [], []
        for z in text.split('\n'):
            if z.strip().startswith('|'):
                zellen = [c.strip() for c in z.strip().strip('|').split('|')]
                akt.append(zellen)
            else:
                if akt:
                    raus.append(akt)
                akt = []
        if akt:
            raus.append(akt)
        return raus

    @staticmethod
    def ist_trenner(zeile):
        return all(re.fullmatch(r':?-{2,}:?', c) for c in zeile if c)

    # ---- Handreichung ----------------------------------------------------
    CHECKLISTE = ['realistische Handlungssituation', 'konkrete Problemstellung',
                  'mehrere Lösungswege', 'Entscheidungen', 'Phasen der vollständigen Handlung',
                  'Handlungsergebnis', 'Personalkompetenzen', 'selbstständig',
                  'kooperative', 'Reflexionsphase', 'Dienen die Inhalte', 'Rahmen',
                  'schulische Entscheidungen']

    def handreichung(self, name, richt):
        """Prüft die Handreichung; `richt` ist der Zeitrichtwert aus der
        SchuCu-Tabelle in Minuten (oder None)."""
        # Eine SchuCu-Tabelle hier meldet schon, wer die Seiten liest (unten,
        # „Entwurf und Stand in Moodle") -- die Prüfform hat keine Tags mehr.
        t = self.lies(name)
        self.platzhalter(name, t)
        tabs = self.tabellen(t)

        # Ablaufplan
        plan = None
        for tab in tabs:
            kopf = [c.lower() for c in tab[0]]
            if any('zeit' in c for c in kopf) and any('material' in c for c in kopf):
                plan = tab
                break
        genannt = set()
        if not plan:
            self.befund(name, 'Ablaufplan-Tabelle (Spalten Zeit und Material) fehlt')
        else:
            kopf = [c.lower() for c in plan[0]]
            iz = next(i for i, c in enumerate(kopf) if 'zeit' in c)
            im = next(i for i, c in enumerate(kopf) if 'material' in c)
            ip = next((i for i, c in enumerate(kopf) if 'phase' in c), None)
            isf = next((i for i, c in enumerate(kopf) if 'sozialform' in c), None)
            summe, summenzeile, nr = 0, None, 0
            for z in plan[1:]:
                if self.ist_trenner(z) or len(z) <= max(iz, im):
                    continue
                zeit = re.sub(r'\*', '', z[iz]).strip()
                if 'summe' in ' '.join(z).lower():
                    summenzeile = int(zeit) if zeit.isdigit() else None
                    continue
                nr += 1
                if not zeit.isdigit():
                    self.befund(name, 'Ablaufplan Zeile %d: Zeit ist keine Zahl (%r)' % (nr, zeit))
                else:
                    summe += int(zeit)
                if ip is not None and not z[ip].strip():
                    self.befund(name, 'Ablaufplan Zeile %d: Phase fehlt' % nr)
                if isf is not None and not z[isf].strip():
                    self.befund(name, 'Ablaufplan Zeile %d: Sozialform fehlt' % nr)
                # Material: Kennungen und Namen weiterer Aktivitäten in
                # Anführungszeichen, durch Komma getrennt, oder "—".
                for k in re.findall(r'(?:Lösung\s+zur?\s+)?%s|Handlungssituation' % BLATT, z[im]):
                    genannt.add(schluessel(k))
                for q in ZITIERT.findall(z[im]):
                    self.zitiert.add(norm(q))
            if summenzeile is None:
                self.befund(name, 'Ablaufplan: Summenzeile fehlt oder nicht lesbar')
            elif summenzeile != summe:
                self.befund(name, 'Ablaufplan: Summenzeile sagt %d, die Zeilen ergeben %d'
                            % (summenzeile, summe))
            if richt is not None and summe:
                abw = summe - richt
                if abs(abw) > richt * 0.1:
                    self.befund(name, 'Ablaufplan: %d min geplant bei Zeitrichtwert %d min (%+d)'
                                % (summe, richt, abw))
                else:
                    self.hinweis('Ablaufplan: %d min bei Richtwert %d min' % (summe, richt))
            # Je Zeile ein Detailabschnitt? In der Textseite <h4>, im Buch
            # ein Unterkapitel -- beides ### in der Prüfform.
            schritte = len(re.findall(r'^###\s+Schritt\s+\d+', t, re.M))
            if schritte < nr:
                self.befund(name, 'Ablaufplan hat %d Zeilen, aber nur %d Schritte -- je Zeile eine '
                                  'Überschrift „Schritt n: …" unter „Die Schritte im Einzelnen"'
                            % (nr, schritte))

        # Materialübersicht: je Zeile der Name eines Blatts, so wie er im Titel
        # steht und in Moodle heisst -- dort wird er ein Link mit genau diesem
        # Text --, oder eine Zeichnung als "Abb. n auf <Kennung>".
        namen = []
        for tab in tabs:
            kopf = [c.lower() for c in tab[0]]
            if kopf and 'datei' in kopf[0]:
                self.befund(name, 'Materialübersicht nennt Dateien -- in Moodle gibt es nur '
                                  'Aktivitäten; erste Spalte "Blatt" mit dem Namen des Blatts')
            if kopf and kopf[0] == 'blatt':
                for z in tab[1:]:
                    if self.ist_trenner(z) or not z[0].strip() or VERWEIS_ABB.fullmatch(z[0].strip()):
                        continue
                    q = ZITIERT.fullmatch(z[0].strip())
                    if q:                 # eine weitere Aktivität
                        self.zitiert.add(norm(q.group(1)))
                        continue
                    namen.append(norm(z[0]))

        # Checkliste
        gefunden = 0
        for tab in tabs:
            kopf = ' '.join(tab[0]).lower()
            if 'frage' in kopf and 'ja/nein' in kopf:
                for z in tab[1:]:
                    if self.ist_trenner(z) or len(z) < 2:
                        continue
                    gefunden += 1
                    antwort = z[1].strip().lower()
                    if antwort not in ('ja', 'nein'):
                        self.befund(name, 'Checkliste: "%s" ohne Ja/Nein' % z[0][:50])
                    if len(z) < 3 or len(z[2].strip()) < 8:
                        self.befund(name, 'Checkliste: "%s" ohne Begründung' % z[0][:50])
        if gefunden < len(self.CHECKLISTE):
            self.befund(name, 'Checkliste: %d von %d Fragen gefunden'
                        % (gefunden, len(self.CHECKLISTE)))

        # Phasen genannt?
        if not re.search(r'^##\s+Phasen', t, re.M):
            self.befund(name, 'Abschnitt „Phasen der vollständigen Handlung" fehlt')

        # Die Handreichung kommt ohne die SchuCu-Tabelle aus: Was dort nur
        # kurz steht, steht hier ausführlich.
        for abschnitt in ('Lernumgebung', 'Leistungsfeststellung und -bewertung'):
            if not re.search(r'^##\s+%s\s*$' % re.escape(abschnitt), t, re.M):
                self.befund(name, 'Abschnitt „%s" fehlt -- die Handreichung muss ohne '
                                  'die SchuCu-Tabelle auskommen' % abschnitt)

        self.links(name, t)
        # Auch die Handreichung verweist auf Abbildungen der Blätter; ohne
        # Kennung meint "Abb. n" ihre eigene.
        self.fuer_sich(name, t)
        return genannt, namen

    # ---- SchuCu-Tabelle --------------------------------------------------
    def schucu_seite(self, dateien):
        """Prüft die SchuCu-Seite: Überschrift, nichts als die Tabelle, die
        Tabelle selbst. Gibt den Zeitrichtwert in Minuten zurück (oder None)."""
        name = SCHUCU
        if name not in dateien:
            self.befund(name, 'Seite „SchuCu" fehlt -- die Tabelle aus references/schucu-*.html '
                              'steht allein auf einer Textseite dieses Namens, als erster Aktivität')
            return None
        t = self.lies(name)
        kopf, _, rumpf = t.partition('\n')
        if kopf.strip() != '# SchuCu':
            self.befund(name, 'Die Seite mit der SchuCu-Tabelle muss „SchuCu" heißen')
        tabellen = TABELLE_RE.findall(rumpf)
        rest = TABELLE_RE.sub('', rumpf).strip()
        if tabellen and rest:
            self.befund(name, 'Auf der SchuCu-Seite steht mehr als die Tabelle: "%s"'
                        % html_text(rest)[:60])
        return self.schucu(name, tabellen)

    def schucu(self, name, tabellen):
        """Prüft die SchuCu-Tabelle gegen die CD-Vorlagen; gibt den
        Zeitrichtwert in Minuten zurück (oder None)."""
        if not tabellen:
            self.befund(name, 'SchuCu-Tabelle fehlt (<table class="lernsituation"> '
                              'aus references/schucu-*.html)')
            return None
        if len(tabellen) > 1:
            self.befund(name, 'SchuCu-Tabelle steht %d-mal da' % len(tabellen))
        roh = tabellen[0]
        if '**' in roh or re.search(r'\[[^\]]+\]\(', roh):
            self.befund(name, 'Markdown in der SchuCu-Tabelle wird nicht umgesetzt -- '
                              '<strong> und <a href> verwenden')

        zeilen, absaetze = lies_tabelle(roh)
        ger = geruest(zeilen)
        alle = vorlagen()
        art = next((n for n, (g, *_) in alle.items() if g == ger), None)
        if art is None:
            # Die nächste Vorlage suchen, um die erste Abweichung zu nennen.
            def gleich(g):
                n = 0
                while n < min(len(g), len(ger)) and g[n] == ger[n]:
                    n += 1
                return n
            art, (g, *_) = max(alle.items(), key=lambda kv: gleich(kv[1][0]))
            i = gleich(g)
            zeig = lambda zl: ' | '.join(x[2] or x[0] for x in zl)
            soll = zeig(g[i]) if i < len(g) else '(Ende)'
            ist = zeig(ger[i]) if i < len(ger) else '(Ende)'
            self.befund(name, 'SchuCu-Tabelle weicht von der Vorlage %s ab, Zeile %d: '
                              'erwartet "%s", steht da "%s"' % (art, i + 1, soll, ist))
            return None
        self.hinweis('SchuCu-Tabelle: Vorlage %s' % art)
        _, vorlage, vorlage_abs = alle[art]

        # Kopflink unverändert
        if zeilen[0][0]['links'] != vorlage[0][0]['links']:
            self.befund(name, 'SchuCu-Kopf: Link "offizielle Erläuterungen" geändert')

        # Absätze unter der Tabelle wie in der Vorlage: dieselbe Zahl und
        # dieselbe Form. Einer ohne Platzhalter (der KI-Hinweis) steht
        # wörtlich da, einer mit Platzhalter wird ausgefüllt (die Legende).
        ausgefuellt = []
        if [s for s, _ in absaetze] != [s for s, _ in vorlage_abs]:
            self.befund(name, 'SchuCu: unter der Tabelle stehen nicht die Absätze der Vorlage '
                              '%s -- erwartet %s' % (art, ' + '.join('"%s"' % v for _, v in vorlage_abs)))
        else:
            for (_, ist), (_, soll) in zip(absaetze, vorlage_abs):
                if '<' in soll:
                    ausgefuellt.append(ist)
                elif ist != soll:
                    self.befund(name, 'SchuCu: Absatz unter der Tabelle geändert -- erwartet "%s"'
                                % soll)

        # Datenzellen: gefüllt, ohne Platzhalter der Vorlage
        werte, titel = {}, None
        for z in zeilen:
            for c in z:
                if c['klasse'] in ('lshead', 'lssubhead'):
                    titel = c['text']
                elif c['klasse'] == 'lsdata':
                    werte[titel] = c['text']
                    if not re.sub(r'\.\.\.|…', '', c['text']).strip():
                        self.befund(name, 'SchuCu-Zeile leer: %s' % titel.rstrip(':'))
                    elif re.search(r'<[^>]+>', c['text']):
                        self.befund(name, 'SchuCu-Zeile mit Platzhalter der Vorlage: %s'
                                    % titel.rstrip(':'))

        # Zeitrichtwert
        richt = None
        w = werte.get('gepl. Zeitrichtwert:', '')
        mm = re.search(r'(\d+)\s*min', w)
        us = re.search(r'(\d+)\s*UStd', w)
        if mm:
            richt = int(mm.group(1))
        elif us:
            richt = int(us.group(1)) * USTD
        if richt is None:
            self.befund(name, 'Zeitrichtwert nicht lesbar (erwartet "n UStd" oder "n min")')

        if art == 'Berufliches Gymnasium':
            # Lehrplan des Fachs unter "Curricularer Bezug"
            bezug = next(c for z in zeilen for c in z
                         if c['klasse'] == 'lssubhead' and c['text'] == 'Curricularer Bezug:')
            for href, text in bezug['links']:
                if not href.startswith('http') or '<' in href + text or not text:
                    self.befund(name, 'SchuCu: Link zum Lehrplan des Fachs nicht ausgefüllt')
            if not bezug['links'] and (not bezug['span'] or '<' in bezug['span']):
                self.befund(name, 'SchuCu: Lehrplan des Fachs fehlt unter "Curricularer Bezug"')
            # Kompetenzbereiche: nur abgedeckte Buchstaben, jeder in der Legende
            legende = set()
            absatz = ausgefuellt[0] if ausgefuellt else None
            if not absatz or '<' in absatz:
                self.befund(name, 'SchuCu: Legende der Kompetenzbereiche unter der Tabelle fehlt')
            else:
                legende = set(re.findall(r'\b([A-Z]):', absatz))
            bereiche = werte.get('Abgedeckte Kompetenzbereiche', '')
            if legende and bereiche and '<' not in bereiche:
                falsch = [b for b in re.findall(r'[^\s,;]+', bereiche) if b not in legende]
                if falsch:
                    self.befund(name, 'SchuCu: Kompetenzbereich(e) %s stehen nicht in der '
                                      'Legende' % ', '.join(falsch))
        return richt

    # ---- Blätter ---------------------------------------------------------
    AUFGABE = re.compile(r'^##\s+Aufgabe\s+(\d+)\s*\(([^)]*)\)', re.M)

    def arbeitsblatt(self, name):
        """Prüft ein Arbeitsblatt, eine Hilfe oder Vertiefung; gibt die
        Nummern seiner Aufgaben zurück."""
        t = self.lies(name)
        self.titel(name, t)
        self.fuer_sich(name, t)
        aufgaben = self.AUFGABE.findall(t)
        if not aufgaben:
            self.befund(name, 'keine Aufgabe in der Form <h3>Aufgabe n (n min · Sozialform · AFB x)</h3>')
            return []
        nummern_ = [int(nr) for nr, _ in aufgaben]
        if nummern_ != list(range(1, len(nummern_) + 1)):
            self.befund(name, 'Aufgaben %s -- jedes Blatt zählt seine Aufgaben ab 1, ohne Lücke'
                        % ', '.join(map(str, nummern_)))
        summe = 0
        for nr, klammer in aufgaben:
            teile = [x.strip() for x in re.split(r'[·•]', klammer)]
            if len(teile) != 3:
                self.befund(name, 'Aufgabe %s: Klammer braucht drei Teile (Zeit · Sozialform · AFB)' % nr)
                continue
            zeit, sozial, afb = teile
            m = re.fullmatch(r'(\d+)\s*min', zeit)
            if not m:
                self.befund(name, 'Aufgabe %s: Zeit fehlt oder nicht "n min" (%r)' % (nr, zeit))
            else:
                summe += int(m.group(1))
            if not sozial:
                self.befund(name, 'Aufgabe %s: Sozialform fehlt' % nr)
            if not re.fullmatch(r'AFB\s*(I{1,3})', afb):
                self.befund(name, 'Aufgabe %s: AFB fehlt oder nicht I/II/III (%r)' % (nr, afb))
        m = re.search(r'Zeit gesamt:\*?\*?\s*(\d+)\s*min', t)
        if not m:
            self.befund(name, 'Kopf: "Zeit gesamt: n min" fehlt')
        elif int(m.group(1)) != summe:
            self.befund(name, 'Kopf sagt %s min, die Aufgaben ergeben %d' % (m.group(1), summe))
        self.platzhalter(name, t)
        self.links(name, t)
        self.bilder(name, t)
        return nummern_

    def loesung(self, name, blatt):
        """`blatt` sind die Aufgabennummern des Blatts."""
        t = self.lies(name)
        self.titel(name, t)
        self.fuer_sich(name, t)
        n = [int(x) for x in AUFGABE_KOPF.findall(t)]
        if len(n) != len(blatt):
            self.befund(name, 'Lösung hat %d Aufgabenabschnitte, das Blatt %d' % (len(n), len(blatt)))
        elif n != blatt:
            self.befund(name, 'Lösung hat die Aufgaben %s, das Blatt %s'
                        % (', '.join(map(str, n)), ', '.join(map(str, blatt))))
        self.platzhalter(name, t)
        self.links(name, t)
        self.bilder(name, t)

    def infoblatt(self, name):
        t = self.lies(name)
        self.titel(name, t)
        self.fuer_sich(name, t)
        if self.AUFGABE.search(t):
            self.befund(name, 'Informationsblatt enthält Aufgaben — die gehören auf ein Arbeitsblatt')
        self.platzhalter(name, t)
        self.links(name, t)
        self.bilder(name, t)

    # ---- Jedes Blatt steht für sich ----------------------------------------
    def titel(self, name, t):
        """Der Name beginnt mit der Kennung: Unter diesem Namen steht das
        Blatt in der Kursübersicht, und mit ihr verweisen die anderen
        Blätter hierher."""
        k, loes = kennung(name)
        soll = titel_soll(k, loes)
        erste = t.lstrip().split('\n', 1)[0]
        if not re.match(r'#\s+%s(?::|\s*$)' % re.escape(soll), erste):
            self.befund(name, 'Name muss mit „%s:" beginnen -- mit dieser Kennung verweisen '
                              'andere Blätter hierher' % soll)

    def fuer_sich(self, name, t):
        """Zählung ab 1 und "Abb. n" ohne Kennung -- was sich an einem Blatt
        allein prüfen lässt."""
        abschnitte, abb, _ = gliederung(t)
        if abschnitte != list(range(1, len(abschnitte) + 1)):
            self.befund(name, 'Abschnitte %s -- jedes Blatt zählt seine Abschnitte ab 1, ohne Lücke'
                        % ', '.join(map(str, abschnitte)))
        if abb != [str(i) for i in range(1, len(abb) + 1)]:
            self.befund(name, 'Abbildungen %s -- jedes Blatt zählt ab Abb. 1, fortlaufend, ohne '
                              'Präfix' % ', '.join('Abb. ' + a for a in abb))
        rest = VERWEIS_ABB.sub(' ', ABB_UNTERSCHRIFT.sub(' ', t))
        for m in re.finditer(r'\bAbb\.\s*([A-Za-z]?\d+)', rest):
            if m.group(1) not in abb:
                self.befund(name, '"Abb. %s" ohne Blattkennung, aber dieses Blatt hat keine Abb. %s '
                                  '-- auf einem anderen Blatt: "Abb. %s auf Infoblatt n"'
                            % ((m.group(1),) * 3))

    def querverweise(self, texte):
        """Verweise zwischen den Blättern. `texte`: Name in der Prüfform ->
        Inhalt, alle Seiten ausser der SchuCu-Seite."""
        verzeichnis = {}          # Kennung und "Lösung zu …" -> Datei
        for d in sorted(texte):
            k, loes = kennung(d)
            if k:
                schl = 'Lösung zu ' + k if loes else k
                if schl in verzeichnis:
                    self.befund(d, 'dieselbe Kennung "%s" wie %s -- ein Verweis darauf wäre '
                                   'mehrdeutig' % (schl, verzeichnis[schl]))
                verzeichnis[schl] = d
        glied = {d: gliederung(t) for d, t in texte.items()}
        gemeldet = set()          # (Datei, Kennung) schon als fehlend gemeldet

        def ziel(roh, d):
            z = verzeichnis.get(schluessel(roh))
            if z is None:
                gemeldet.add((d, schluessel(roh)))
            return z

        # Verweise auf Abschnitte, Abbildungen und Aufgaben anderer Blätter
        # treffen etwas, das es dort gibt -- nach einer Teilung oder
        # Umnummerierung zeigen sie sonst ins Leere.
        for d, t in texte.items():
            for m in VERWEIS_ABSCHNITT.finditer(t):
                z = ziel(m.group(1), d)
                if z is None:
                    self.befund(d, '"%s": dieses Blatt gibt es nicht' % norm(m.group(0)))
                    continue
                fehlt = [n for n in nummern(m.group(2)) if n not in glied[z][0]]
                if fehlt:
                    self.befund(d, '"%s": dort gibt es keinen Abschnitt %s'
                                % (norm(m.group(0)), ', '.join(map(str, fehlt))))
            for m in VERWEIS_ABB.finditer(t):
                z = ziel(m.group(2), d)
                if z is None:
                    self.befund(d, '"%s": dieses Blatt gibt es nicht' % norm(m.group(0)))
                    continue
                fehlt = [n for n in nummern(m.group(1)) if str(n) not in glied[z][1]]
                if fehlt:
                    self.befund(d, '"%s": dort gibt es keine Abb. %s'
                                % (norm(m.group(0)), ', '.join(map(str, fehlt))))
            for m in VERWEIS_AUFGABE.finditer(t):
                nrn, blatt = (m.group(1), m.group(2)) if m.group(1) else (m.group(4), m.group(3))
                z = ziel(blatt, d)
                if z is None:
                    self.befund(d, '"%s": dieses Blatt gibt es nicht' % norm(m.group(0)))
                    continue
                fehlt = [n for n in nummern(nrn) if n not in glied[z][2]]
                if fehlt:
                    self.befund(d, '"%s": dort gibt es keine Aufgabe %s'
                                % (norm(m.group(0)), ', '.join(map(str, fehlt))))
            # Jede Kennung, die irgendwo steht, gibt es -- auch im Ablaufplan
            # und in "hilft die Vertiefung zu Arbeitsblatt 3". In Moodle wird
            # daraus ein Link, und der braucht ein Ziel.
            for m in re.finditer(ZIEL, t):
                s = schluessel(m.group(0))
                if s not in verzeichnis and (d, s) not in gemeldet:
                    gemeldet.add((d, s))
                    self.befund(d, '"%s": dieses Blatt gibt es nicht' % norm(m.group(0)))

        # "Lies"-Zeilen der Arbeitsblätter, je Aufgabe:
        # (Arbeitsblatt, Aufgabe) -> {Infoblatt: Abschnitte oder None = ganz}
        lies = {}
        for d, t in texte.items():
            k, loes = kennung(d)
            if not k or loes or 'Arbeitsblatt' not in k:
                continue
            m = DAZU.search(t)
            verwendet = set(norm(x) for x in re.findall(r'Infoblatt\s+\d+', m.group(1) if m else ''))
            teile = AUFGABE_KOPF.split(t)
            for nr, stueck in [(0, teile[0])] + list(zip(teile[1::2], teile[2::2])):
                for zeile in LIES.findall(stueck):
                    verwendet.update(norm(x) for x in re.findall(r'Infoblatt\s+\d+', zeile))
                    # "Abb. 1 auf Infoblatt 2" in der Zeile heißt nicht "lies
                    # das ganze Infoblatt 2" -- sonst überdeckte es die
                    # Abschnitte, die dieselbe Zeile nennt.
                    for z in LIES_ZIEL.finditer(VERWEIS_ABB.sub(' ', zeile)):
                        ib = norm(z.group(1))
                        eintrag = lies.setdefault((k, int(nr)), {})
                        if z.group(2) is None:
                            eintrag[ib] = None
                        elif ib not in eintrag or eintrag[ib] is not None:
                            eintrag[ib] = (eintrag.get(ib) or set()) | set(nummern(z.group(2)))
            # "Gehört zu" nennt jedes Blatt, das das Infoblatt verwendet --
            # wer das Infoblatt austeilt, sieht daran, wozu.
            for ib in sorted(verwendet):
                z = verzeichnis.get(ib)
                if z is None:
                    if (d, ib) not in gemeldet:
                        self.befund(d, 'verwendet %s, das es nicht gibt' % ib)
                    continue
                g = GEHOERT_ZU.search(texte[z])
                liste = [norm(x) for x in re.findall(BLATT, g.group(1))] if g else []
                if k not in liste:
                    self.befund(z, '"Gehört zu" nennt %s nicht, obwohl es dieses Blatt unter '
                                   '"Dazu" oder "Lies" verwendet' % k)

        # "→ für" unter den Abschnitten der Infoblätter:
        # (Infoblatt, Abschnitt) -> {(Arbeitsblatt, Aufgabe)}
        pfeile = {}
        for d, t in texte.items():
            k, loes = kennung(d)
            if not k or loes or not k.startswith('Infoblatt'):
                continue
            teile = re.split(r'^##\s+(\d+)\.\s.*$', t, flags=re.M)
            for nr, stueck in zip(teile[1::2], teile[2::2]):
                ziele = pfeile.setdefault((k, int(nr)), set())
                for zeile in PFEIL.findall(stueck):
                    for z in PFEIL_ZIEL.finditer(zeile):
                        for a in nummern(z.group(2)):
                            ziele.add((norm(z.group(1)), a))

        # Beide Richtungen: Wer bei einer Aufgabe einen Abschnitt lesen lässt,
        # steht dort unter "→ für" -- und jeder Pfeil hat seine "Lies"-Zeile.
        # Sonst veraltet die eine Seite still, wenn die andere sich ändert.
        for (ab, a), ibs in sorted(lies.items()):
            if a == 0:
                continue          # vor der ersten Aufgabe: gilt dem ganzen Blatt
            for ib, abschnitte in ibs.items():
                for s in sorted(abschnitte or ()):
                    if (ib, s) in pfeile and (ab, a) not in pfeile[(ib, s)]:
                        self.befund(verzeichnis[ib], 'Abschnitt %d: "→ für %s, Aufgabe %d" fehlt -- '
                                                     'dort lässt eine "Lies"-Zeile ihn lesen' % (s, ab, a))
        for (ib, s), ziele in sorted(pfeile.items()):
            for ab, a in sorted(ziele):
                if verzeichnis.get(ab) is None or a not in glied[verzeichnis[ab]][2]:
                    continue      # als Verweis ins Leere schon gemeldet
                ibs = lies.get((ab, a), {})
                if ib not in ibs or (ibs[ib] is not None and s not in ibs[ib]):
                    self.befund(verzeichnis[ib], 'Abschnitt %d: "→ für %s, Aufgabe %d", aber dort '
                                                 'nennt keine "Lies"-Zeile diesen Abschnitt' % (s, ab, a))

    # ---- Querschnitt -----------------------------------------------------
    HTML = {'ul', '/ul', 'li', '/li', 'br', 'br/', 'br /'}

    def platzhalter(self, name, t):
        # Alles in spitzen Klammern, was kein erlaubtes HTML-Element ist,
        # ist ein Platzhalter aus der Vorlage -- auch <n> und <du / Sie>.
        for m in re.finditer(r'<([^>\n]+)>', t):
            innen = m.group(1).strip()
            if innen.lower() in self.HTML or innen.startswith('http'):
                continue
            self.befund(name, 'Platzhalter steht noch da: <%s>' % innen[:60])
            return

    def links(self, name, t):
        for m in re.finditer(r'\[([^\]]*)\]\((https?://[^)]+)\)', t):
            text, url = m.group(1).strip(), m.group(2)
            if url not in text and text.lower() in ('hier', 'link', 'video', 'dokument', 'mehr', ''):
                self.befund(name, 'Link ohne ausgeschriebene Adresse im Text: [%s](%s)' % (text, url[:40]))
        if re.search(r'\(//[a-z0-9.-]+/', t):
            self.befund(name, 'protokollrelative Adresse (//…) — auf Papier unvollständig')

    def bilder(self, name, t):
        for m in re.finditer(r'!\[([^\]]*)\]\(([^)]+)\)', t):
            alt, datei = m.group(1).strip(), m.group(2).strip()
            if not alt:
                self.befund(name, 'Bild ohne Beschreibung: %s' % datei)
            p = os.path.join(self.ordner, datei)
            if not os.path.isfile(p):
                if self.bilddateien:
                    self.befund(name, 'eingebundene Datei fehlt: %s' % datei)
            elif datei.lower().endswith('.svg'):
                svg = io.open(p, encoding='utf-8').read()
                if '<title' not in svg or '<desc' not in svg:
                    self.befund(datei, 'SVG ohne <title> und <desc>')
                if '<script' in svg or 'http' in re.sub(r'xmlns="[^"]+"', '', svg):
                    self.befund(datei, 'SVG mit Skript oder externem Verweis')

    # ---- Hauptlauf -------------------------------------------------------
    def ausgabe(self, was, anzeige=None):
        """Druckt Hinweise und Befunde; `anzeige` übersetzt die Namen der
        Prüfform in das, was der Leser kennt: die Aktivität mit ihrem Ordner
        im Entwurf oder ihrer cmid in Moodle."""
        for h in self.hinweise:
            print('  ' + h)
        if not self.befunde:
            print('OK -- %s, Form vollständig. Ob die Lernsituation trägt, '
                  'sagt die Checkliste, nicht dieses Skript.' % was)
            return 0
        print('%d Befund(e):' % len(self.befunde))
        for datei, text in self.befunde:
            if anzeige:
                datei = anzeige(datei)
                text = ENTWURF_IM_TEXT.sub(lambda m: anzeige(m.group(0)), text)
            print('  %-40s %s' % (datei, text))
        return 1

    def pruefen(self, im_text_verboten=()):
        """Alle Prüfungen an der Prüfform im Ordner; `im_text_verboten` sind
        Namen des Entwurfs, die in keinem Text stehen dürfen. Gibt die
        Dateien der Prüfform zurück, None: nichts zu prüfen."""
        dateien = sorted(d for d in os.listdir(self.ordner)
                         if not d.startswith('.') and os.path.isfile(os.path.join(self.ordner, d)))
        hand = HAND
        if hand not in dateien:
            print('Keine Lehrerhandreichung -- ohne sie ist nichts zu prüfen.')
            return None

        richt = self.schucu_seite(dateien)
        genannt, namen = self.handreichung(hand, richt)

        # AB-00 ist die Handlungssituation für sich: keine Aufgaben, keine Lösung.
        situation = [d for d in dateien if re.match(r'AB-00-.*\.md$', d)]
        abs_ = [d for d in dateien if re.match(r'AB-\d+-.*\.md$', d)
                and d not in situation and not d.endswith('-loesung.md')]
        ibs = [d for d in dateien if re.match(r'IB-\d+-.*\.md$', d)]
        if not abs_:
            self.befund('(Lernsituation)', 'kein Arbeitsblatt -- eine Aktivität „Arbeitsblatt 1: …"')
        for d in situation:
            t = self.lies(d)
            self.titel(d, t)
            self.fuer_sich(d, t)
            self.platzhalter(d, t)
            self.links(d, t)
            self.bilder(d, t)
        for ab in abs_:
            n = self.arbeitsblatt(ab)
            loes = ab[:-3] + '-loesung.md'
            if loes not in dateien:
                k, _ = kennung(ab)
                self.befund(ab, 'Lösung fehlt: „%s: …"' % titel_soll(k, True))
            elif n:
                self.loesung(loes, n)
        for ib in ibs:
            self.infoblatt(ib)
        self.querverweise({d: self.lies(d) for d in dateien
                           if d.endswith('.md') and d != SCHUCU})

        # Die Materialübersicht nennt jedes Blatt mit seinem Namen, so wie er
        # in Moodle heisst; ein veralteter Name wäre dort ein Link mit falschem
        # Text.
        titel = {}                # Kennung -> Titel des Blatts
        for d in dateien:
            k, loes = kennung(d)
            if k and d.endswith('.md'):
                erste = self.lies(d).lstrip().split('\n', 1)[0]
                titel['Lösung zu ' + k if loes else k] = norm(erste.lstrip('#'))
        for n in namen:
            m = re.match(r'%s|Handlungssituation' % ZIEL, n)
            s = schluessel(m.group(0)) if m else None
            if s is not None and titel.get(s) == n:
                genannt.add(s)
            else:
                self.befund(hand, 'Materialübersicht: "%s" ist nicht der Name eines Blatts -- '
                                  'dort steht der Titel, wie er in Moodle heisst' % n[:60])

        # Jedes Blatt kommt in der Handreichung vor.
        for d in dateien:
            if d in (hand, SCHUCU) or d.endswith('-loesung.md'):
                continue
            k, _ = kennung(d)
            if k and k not in genannt:
                self.befund(d, 'steht weder im Ablaufplan noch in der Materialübersicht')
        # Ebenso jede weitere Aktivität, mit ihrem Namen in Anführungszeichen --
        # und was dort in Anführungszeichen steht, gibt es.
        for n, wo in self.weitere.items():
            if n not in self.zitiert:
                self.befund(wo, 'steht weder im Ablaufplan noch in der Materialübersicht -- dort mit ihrem '
                                'Namen in Anführungszeichen („%s")' % n)
        for n in sorted(self.zitiert - set(self.weitere)):
            self.befund(hand, '„%s" in Ablaufplan oder Materialübersicht ist keine Aktivität dieser Lernsituation '
                              '-- in Anführungszeichen steht dort nur der Name einer weiteren Aktivität' % n)

        # Kein Name aus dem Entwurf im Text: In Moodle gibt es nur Aktivitäten,
        # und ein Blatt heißt dort nach seiner Kennung.
        muster = [(n, re.compile(r'(?<![\w.-])%s(?![\w-])' % re.escape(n))) for n in sorted(im_text_verboten)]
        for d in dateien:
            if d.endswith('.md'):
                t = BILD.sub(' ', self.lies(d))
                for n, m in muster:
                    if m.search(t):
                        self.befund(d, 'Name aus dem Entwurf im Text: %s -- in Moodle gibt es ihn nicht; '
                                       'ein Blatt mit seiner Kennung nennen („Arbeitsblatt 1")' % n)
        return dateien


# ---------------------------------------------------------------------------
# Entwurf und Stand in Moodle
# ---------------------------------------------------------------------------
# Der Entwurf hat schon die Form, die die Werkzeuge der App nehmen, und was
# der Skill moodle aus einem Abschnitt liest, liegt in derselben Form im
# Arbeitsordner: je Aktivität page.html bzw. introeditor.html und dateien/,
# ein Buch als kapitel.json mit kapitel-<id>/content_editor.html. Im Entwurf
# nennt lernsituation.json Reihenfolge, Typ und Name; in Moodle tut es
# kurs-<kurs>.json (von kurs_uebersicht, die Antwort von
# core_courseformat_get_state), und aktivitaet_lesen legt cm-<cmid>/ an,
# buch_lesen buch-<cmid>/. Beide werden deshalb gleich gelesen und gleich
# geprüft -- maßgeblich ist, was in Moodle steht, und die Lehrkraft ändert
# dort auch von Hand.
#
# Geprüft wird an einer Prüfform: je Aktivität eine Textdatei, das HTML in
# die Schreibweise gebracht, an der sich die festen Formen der Vorlagen am
# einfachsten lesen lassen (ZuMarkdown). Niemand schreibt sie; sie lebt nur
# während der Prüfung. Welche Rolle eine Aktivität hat, sagt ihr Name -- die
# Kennung, „SchuCu", „Lehrerhandreichung", „Handlungssituation" -- oder ihr
# Inhalt (SchuCu-Tabelle, Ablaufplan).
#
# Nur am Entwurf: lernsituation.json, die Ordner und die HTML-Regeln. In
# Moodle meldet die App Verstöße gegen die HTML-Regeln selbst beim Lesen, und
# was die Lehrkraft im Editor gestaltet, ist ihre Sache. Nur in Moodle: die
# Links zwischen den Blättern, die erst nach dem Anlegen entstehen können.

MANIFEST = 'lernsituation.json'
# Weitere Aktivitäten: keine Blätter und ohne Kennung. Ihr Name sagt, wozu sie
# da sind, und Blätter wie Handreichung nennen ihn in Anführungszeichen
# (references/vorlagen.md, „Weitere Aktivitäten im Entwurf"); in Moodle wird
# genau diese Nennung ein Link (links_setzen). Was im Ordner liegt, prüft
# weitere_aktivitaet.
WEITERE = {'board', 'kanban', 'checklist', 'wiki', 'quiz', 'folder', 'resource', 'url'}
ZITIERT = re.compile(r'[„“"»]([^„“”"«»\n]+?)[“”"«]')
# Der Name einer Aktivität, die ein Blatt ist: Kennung, dann Doppelpunkt.
ROLLE = re.compile(r'(Lösung\s+zur?\s+)?(?:(Hilfe|Vertiefung)\s+zu\s+)?(Arbeitsblatt|Infoblatt)\s+(\d+)\s*(?::|$)')
# Die Namen der Prüfform, wenn sie in einem Befund stehen.
ENTWURF_IM_TEXT = re.compile(r'\b(?:AB|IB)-\d+-x\d*(?:-hilfe|-vertiefung)?(?:-loesung)?\.md\b'
                             r'|\b00-(?:schucu|lehrerhandreichung)\.md\b')
AKTIVITAETSLINK = re.compile(r'/mod/\w+/view\.php\?id=\d+')
# Wo der Inhalt einer Aktivität steht, in dieser Reihenfolge; das erste Feld
# braucht der Entwurf, damit aktivitaet_anlegen einen Inhalt findet.
INHALT = {'page': ['page'], 'assign': ['introeditor', 'activityeditor'], 'label': ['introeditor']}
# Rollen ohne Kennung, am Namen erkannt.
NAME_SCHUCU, NAME_HAND, NAME_SITUATION = 'SchuCu', 'Lehrerhandreichung', 'Handlungssituation'


def html_text(s):
    return norm(html.unescape(re.sub(r'<[^>]+>', ' ', s or '')))


def wahr(x):
    return x is True or x == 1 or x == '1' or x == 'true'


def abschnitt_aus_kurs(ao, abschnitt_id):
    """Sucht im Arbeitsordner die kurs-*.json, die den Abschnitt enthält.
    Gibt (Kurs, Titel, [(cmid, modul, name, erreichbar)]) in Moodles
    Reihenfolge, Unterabschnitte eingeschlossen -- oder None."""
    for f in sorted(os.listdir(ao)):
        if not re.fullmatch(r'kurs-\d+\.json', f):
            continue
        z = json.load(io.open(os.path.join(ao, f), encoding='utf-8'))
        abschnitte = {int(s['id']): s for s in z.get('section') or [] if isinstance(s, dict) and s.get('id')}
        if abschnitt_id not in abschnitte:
            continue
        cms = {int(c['id']): c for c in z.get('cm') or [] if isinstance(c, dict) and c.get('id')}
        # Ein Unterabschnitt hängt über delegatesectionid an seiner Aktivität,
        # sonst über parentsectionid am Elternabschnitt (wie in kurs.dart).
        kinder = {}
        for s in abschnitte.values():
            if s.get('parentsectionid'):
                kinder.setdefault(int(s['parentsectionid']), []).append(int(s['id']))
        liste, gesehen = [], set()

        def sammle(sid):
            if sid in gesehen or sid not in abschnitte:
                return
            gesehen.add(sid)
            for x in abschnitte[sid].get('cmlist') or []:
                c = cms.get(int(x))
                if c is None:
                    continue
                modul = c.get('module') or re.sub(r'^mod_', '', c.get('plugin') or '') or '?'
                liste.append((int(c['id']), modul, html_text(c.get('name')), wahr(c.get('visible'))))
                if c.get('delegatesectionid'):
                    sammle(int(c['delegatesectionid']))
            for k in kinder.get(sid, []):
                sammle(k)

        sammle(abschnitt_id)
        s = abschnitte[abschnitt_id]
        return int(f[5:-5]), html_text(s.get('title') or s.get('rawtitle')), liste
    return None


class ZuMarkdown(HTMLParser):
    """HTML in die Prüfform: Überschriften als #, Tabellen mit |, <strong>
    als **, Bilder als ![alt](name). In einer Textseite steht <h3> für ##, im
    Buch ist ## das Kapitel und <h3> steht für ###. Links auf Aktivitäten
    bleiben Text -- sie prüft pruefe() eigens --, Links nach draussen werden
    [Text](Adresse), damit "hier" als Linktext auffällt."""

    def __init__(self, buch=False):
        super().__init__(convert_charrefs=True)
        tiefe = 1 if buch else 0
        self.ebene = {'h%d' % n: '#' * (n - 1 + tiefe) for n in (3, 4, 5, 6)}
        self.bloecke, self.zeile, self.kopf = [], '', ''
        self.tabelle, self.zelle, self.listen, self.href = None, None, [], None

    def text(self, t):
        if self.zelle is not None:
            self.zelle[-1] += t
        else:
            self.zeile += t

    def absatz(self):
        z = self.zeile.strip()
        if z:
            self.bloecke.append(self.kopf + z)
        self.zeile, self.kopf = '', ''

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == 'table':
            self.absatz()
            self.tabelle = []
        elif tag == 'tr' and self.tabelle is not None:
            self.tabelle.append([])
        elif tag in ('td', 'th') and self.tabelle is not None:
            if not self.tabelle:
                self.tabelle.append([])
            self.tabelle[-1].append('')
            self.zelle = self.tabelle[-1]
        elif tag in self.ebene:
            self.absatz()
            self.kopf = self.ebene[tag] + ' '
        elif tag in ('p', 'div', 'blockquote'):
            if self.zelle is None:
                self.absatz()
        elif tag in ('ul', 'ol'):
            self.absatz()
            self.listen.append(tag)
        elif tag == 'li':
            self.absatz()
            self.kopf = '1. ' if self.listen and self.listen[-1] == 'ol' else '- '
        elif tag in ('strong', 'b'):
            self.text('**')
        elif tag in ('em', 'i'):
            self.text('*')
        elif tag == 'br':
            self.text(' ' if self.zelle is not None else '\n')
        elif tag == 'img':
            src = a.get('src') or ''
            self.text('![%s](%s)' % (a.get('alt') or '', unquote(src.rsplit('/', 1)[-1])))
        elif tag == 'a':
            h = a.get('href') or ''
            self.href = h if h.startswith('http') and not AKTIVITAETSLINK.search(h) else None
            if self.href:
                self.text('[')

    def handle_endtag(self, tag):
        if tag in ('td', 'th'):
            self.zelle = None
        elif tag == 'table' and self.tabelle is not None:
            zeilen = [[norm(c) for c in z] for z in self.tabelle if z]
            if zeilen:
                md = ['| ' + ' | '.join(zeilen[0]) + ' |', '|' + '---|' * len(zeilen[0])]
                md += ['| ' + ' | '.join(z) + ' |' for z in zeilen[1:]]
                self.bloecke.append('\n'.join(md))
            self.tabelle = None
        elif tag in self.ebene or tag in ('p', 'div', 'blockquote', 'li'):
            if self.zelle is None:
                self.absatz()
        elif tag in ('ul', 'ol'):
            self.absatz()
            if self.listen:
                self.listen.pop()
        elif tag in ('strong', 'b'):
            self.text('**')
        elif tag in ('em', 'i'):
            self.text('*')
        elif tag == 'a' and self.href:
            self.text('](%s)' % self.href)
            self.href = None

    def handle_data(self, d):
        if self.zelle is None:
            if not self.zeile and not d.strip():
                return
            d = re.sub(r'[ \t\r\n]+', ' ', d)
        self.text(d)

    def ergebnis(self):
        self.absatz()
        return '\n\n'.join(self.bloecke) + '\n'


def zu_markdown(h, buch=False):
    z = ZuMarkdown(buch)
    z.feed(h)
    z.close()
    return z.ergebnis()


def pruefname(name, belegt):
    """Der Name des Blatts in der Prüfform, aus der Kennung am Anfang seines
    Namens; None: kein Blatt."""
    m = ROLLE.match(name)
    if not m:
        return None
    loes, zusatz, art, nr = m.groups()
    kern = '%s-%02d-x' % ('AB' if art == 'Arbeitsblatt' else 'IB', int(nr))
    rest = ('-hilfe' if zusatz == 'Hilfe' else '-vertiefung' if zusatz else '') + ('-loesung' if loes else '')
    # Zwei Aktivitäten mit derselben Kennung: getrennt ablegen, damit die
    # Prüfung "dieselbe Kennung" melden kann.
    n = ''
    while kern + n + rest + '.md' in belegt:
        n = str(int(n or 1) + 1)
    return kern + n + rest + '.md'


def rolle(name, h, md, belegt):
    """Der Name der Aktivität in der Prüfform; None: ohne Rolle in der
    Lernsituation."""
    if name == NAME_SCHUCU and SCHUCU not in belegt:
        return SCHUCU
    blatt = pruefname(name, belegt)
    if blatt:
        return blatt
    if name == NAME_SITUATION and 'AB-00-x.md' not in belegt:
        return 'AB-00-x.md'
    if (name == NAME_HAND or re.search(r'^##\s+Ablaufplan\s*$', md, re.M)) and HAND not in belegt:
        return HAND
    # Die Tabelle auf einer Seite mit anderem Namen: Die Prüfung sagt dann,
    # wie die Seite heißen muss.
    if '<table class="lernsituation"' in h and SCHUCU not in belegt:
        return SCHUCU
    return None


def seite(schluessel_, modul, name, erreichbar, h, md, ordner, wo):
    """Eine Aktivität, wie beide Leser sie liefern. `ordner`: wo dateien/ und
    in Moodle uebersicht.json liegen, bei einem Buch je Kapitel einer; `wo`:
    wie ein Befund sie nennt."""
    return {'id': schluessel_, 'modul': modul, 'name': name, 'erreichbar': erreichbar, 'h': h, 'md': md,
            'ordner': ordner, 'wo': wo}


def lies_feld(o, modul):
    return '\n'.join(io.open(os.path.join(o, f + '.html'), encoding='utf-8').read()
                     for f in INHALT[modul] if os.path.isfile(os.path.join(o, f + '.html')))


def lies_buch(o):
    """Ein Buch aus kapitel.json und kapitel-<id>/content_editor.html, so wie
    buch_lesen es ablegt und der Entwurf es schreibt: (HTML, Prüfform,
    [(Ordner, HTML, Eintrag aus kapitel.json)]); None ohne kapitel.json."""
    p = os.path.join(o, 'kapitel.json')
    if not os.path.isfile(p):
        return None
    teile, roh, kapitel = [], [], []
    for k in json.load(io.open(p, encoding='utf-8')):
        if not isinstance(k, dict):
            continue
        ko = os.path.join(o, 'kapitel-%s' % k.get('id'))
        f = os.path.join(ko, 'content_editor.html')
        h = io.open(f, encoding='utf-8').read() if os.path.isfile(f) else ''
        teile.append('%s %s\n\n%s' % ('###' if k.get('unterkapitel') else '##', norm(str(k.get('titel') or '')),
                                      zu_markdown(h, buch=True)))
        roh.append(h)
        kapitel.append((ko, h, k))
    return '\n'.join(roh), '\n'.join(teile), kapitel


# ---- Die HTML-Regeln am Entwurf -------------------------------------------
# Dieselben wie in references/html.md der Skills und in der Auswertung der
# App (lib/moodle/auswertung.dart), die sie beim Lesen meldet: Hier fallen
# sie auf, bevor etwas in Moodle steht. Die Grenze für Rahmenlinien ist
# dieselbe wie _mehrAlsRahmen dort -- wer die eine ändert, ändert beide.
TABELLENTEILE = {'table', 'thead', 'tbody', 'tfoot', 'tr', 'th', 'td', 'col', 'colgroup'}
RAHMEN_EIGENSCHAFT = re.compile(r'^border(-(top|right|bottom|left))?(-(width|style))?$')
RAHMEN_WERT = re.compile(r'^(0|\d*\.?\d+(px|pt|em|rem)|thin|medium|thick|none|hidden|dotted|dashed|solid|double'
                         r'|groove|ridge|inset|outset)$')
# Elemente, die in Moodle-Inhalten vorkommen. Alles andere in spitzen
# Klammern ist ein Platzhalter der Vorlagen: <Titel>, <n>, <du / Sie>.
HTML_ELEMENTE = set('''a abbr address article aside audio b bdi bdo blockquote br button caption center cite
code col colgroup data dd del details dfn div dl dt em embed figcaption figure font footer h1 h2 h3 h4 h5 h6
header hr i iframe img input ins kbd label li main mark math nav object ol optgroup option p param picture pre
q rp rt ruby s samp section select small source span strong sub summary sup svg table tbody td textarea tfoot th
thead time tr track u ul var video wbr'''.split())
BLOCK = {'p', 'div', 'li', 'td', 'th', 'tr', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'br', 'table', 'ul', 'ol',
         'blockquote', 'figure', 'figcaption', 'hr', 'dd', 'dt', 'section', 'pre'}
# Was aus Markdown hängen bleibt, wenn man HTML schreibt -- im Text ausserhalb
# von <code> und <pre>.
MARKDOWN = [
    (re.compile(r'\*\*[^*\n]+\*\*'), '<strong>'),
    (re.compile(r'(?m)^[ \t]*#{1,6}[ \t]+\S.*'), '<h3> bzw. <h4>'),
    (re.compile(r'!?\[[^\]\n]*\]\([^)\s]+\)'), '<a href> bzw. <img>'),
    (re.compile(r'```'), '<pre> oder, zum Ausfüllen, eine Tabelle'),
    (re.compile(r'`[^`\n]+`'), '<code>'),
]


# Interaktive Elemente: dieselbe Prüfung wie elementFehler in
# lib/moodle/elemente.dart, an der die App das Schreiben abbricht -- hier
# fällt es schon am Entwurf auf. Den Kopf (Content-Security-Policy, Wächter)
# setzt erst die App bei der Übertragung; im Entwurf fehlt er.
ELEMENT_KOPF = re.compile(r'<!-- moocp: Kopf des Elements, setzt die App -->[\s\S]*?<!-- /moocp -->\n?')
ELEMENT_ADRESSE = re.compile(r'(?:[=("\'`]\s*|@import\s+)((?:https?:)?//[^\s"\'`)<>]+)', re.I)
ELEMENT_NETZ = [
    (re.compile(r'(^|[;{}\s])import\b', re.M), 'import'),
    (re.compile(r'\bfetch\s*\('), 'fetch'),
    (re.compile(r'\bXMLHttpRequest\b'), 'XMLHttpRequest'),
    (re.compile(r'\bWebSocket\b'), 'WebSocket'),
    (re.compile(r'\bEventSource\b'), 'EventSource'),
    (re.compile(r'\bsendBeacon\b'), 'sendBeacon'),
    (re.compile(r'\bimportScripts\b'), 'importScripts'),
]
ELEMENT_CODE = [
    (re.compile(r'\b(?:localStorage|sessionStorage|indexedDB)\b|document\s*\.\s*cookie'),
     'Speichern im Browser: Ein Element merkt sich nichts, und der Rahmen sperrt es.'),
    (re.compile(r'(?<![\w$.])(?:window\s*\.\s*)?(?:parent|top|opener)\s*\.'),
     'Zugriff auf die Moodle-Seite (parent/top/opener): Der Rahmen sperrt ihn.'),
]
# Netz, Speicher und Moodle-Seite nur im Code: Inhalt der <script> und Werte
# der Ereignis-Attribute. „We import goods" auf einer Vokabelkarte ist Text.
ELEMENT_SKRIPT = re.compile(r'<script\b[^>]*>([\s\S]*?)</script\s*>', re.I)
ELEMENT_EREIGNIS = re.compile(r'''\son[a-z]+\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))''', re.I)
ELEMENT_SONST = [
    (re.compile(r'<script\b[^>]*\bsrc\s*=', re.I), 'Nachgeladenes Skript (<script src>): Der Code steht im Element selbst.'),
    (re.compile(r'<(?:iframe|frame|object|embed)\b', re.I), 'Rahmen oder Einbettung im Element: Ein Element bettet nichts ein.'),
    (re.compile(r'<meta\b[^>]*http-equiv', re.I), '<meta http-equiv> setzt nur die App (im Kopf).'),
    (re.compile(r'<base\b', re.I), '<base> verbiegt Adressen und ist gesperrt.'),
]


def element_fehler(text):
    """Was in einem interaktiven Element nicht geht, je als Satz
    (references/elemente.md)."""
    t = ELEMENT_KOPF.sub('', text)
    raus = []
    if not re.search(r'<head\b', t, re.I):
        raus.append('braucht ein Gerüst mit <head> (<!DOCTYPE html><html lang="de"><head>…</head><body>…)')
    for m in ELEMENT_ADRESSE.finditer(t):
        if not re.match(r'(?:https?:)?//www\.w3\.org/', m.group(1), re.I):
            raus.append('Adresse „%s": Ein Element lädt nichts und verweist nirgendwohin -- Bilder als SVG im '
                        'Element, Verweise in den Text der Seite' % m.group(1)[:60])
            break
    code = '\n'.join([m.group(1) for m in ELEMENT_SKRIPT.finditer(t)] +
                     [next(g for g in m.groups() if g is not None) for m in ELEMENT_EREIGNIS.finditer(t)])
    for muster, was in ELEMENT_NETZ:
        if muster.search(code):
            raus.append('Im Code steht %s: Ein Element lädt und sendet nichts.' % was)
    for muster, satz in ELEMENT_CODE:
        if muster.search(code):
            raus.append(satz)
    for muster, satz in ELEMENT_SONST:
        if muster.search(t):
            raus.append(satz)
    return raus


# Code in Dateien, die kein Element sind: dieselbe Grenze wie codeInDatei in
# lib/moodle/elemente.dart. Moodle liefert HTML, SVG und XML direkt aus; über
# einen Link oder in einem neuen Tab geöffnet, liefe ihr Code in der Sitzung
# des Betrachters, und die App lädt so eine Datei nicht hoch.
DOKUMENT = re.compile(r'\.(?:x?html?|xht|shtml|svgz?|xml|xslt?)$', re.I)


class Skriptstellen(HTMLParser):
    """Stellen, an denen Code läuft: <script>, Ereignis-Attribute (auch per
    SVG-Animation gesetzt), srcdoc und javascript:-Adressen."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stellen = []

    def handle_starttag(self, tag, attrs):
        if tag == 'script':
            self.stellen.append('<script>')
        for k, w in attrs:
            w = w or ''
            if k.startswith('on') or (k == 'attributename' and w.strip().lower().startswith('on')):
                self.stellen.append('%s an <%s>' % (k if k.startswith('on') else w.strip(), tag))
            elif k == 'srcdoc':
                self.stellen.append('<%s srcdoc>' % tag)
            elif re.sub(r'[\s\x00-\x1f]', '', w).lower().startswith('javascript:'):
                self.stellen.append('javascript: an <%s>' % tag)

    handle_startendtag = handle_starttag


def code_in_datei(name, daten):
    """Die Stellen mit Code in einer Datei, die der Browser als Dokument
    öffnet; bei anderen Dateien leer."""
    if not DOKUMENT.search(name):
        return []
    if name.lower().endswith('.svgz'):
        try:
            daten = gzip.decompress(daten)
        except (OSError, EOFError):
            return ['komprimierte SVG, die sich nicht entpacken lässt']
    p = Skriptstellen()
    p.feed(daten.decode('utf-8', 'replace'))
    p.close()
    return p.stellen


# Formelfehler: dieselbe Prüfung wie formelFehler in lib/moodle/formeln.dart,
# die das Schreiben in Moodle abbricht -- hier fällt der Fehler schon am
# Entwurf auf. Ein Block ist ein Absatz, eine Zelle, ein Listenpunkt; ein
# Textstück endet an jedem Tag. Anfang und Ende einer Formel stehen im selben
# Textstück, sonst ist HTML darin oder ein rohes < hat sie zerbrochen.
FORMEL_BLOECKE = {'p', 'div', 'li', 'ul', 'ol', 'dl', 'dt', 'dd', 'table', 'thead', 'tbody', 'tfoot', 'tr', 'td',
                  'th', 'caption', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote', 'figure', 'figcaption',
                  'section', 'article', 'header', 'footer', 'aside', 'details', 'summary', 'hr', 'form', 'fieldset'}
FORMEL_AUSLASSEN = {'code', 'pre', 'script', 'style', 'svg', 'math', 'textarea', 'select'}
EINFACHE_DOLLAR = re.compile(r'(?<![\\$])\$(?!\$)([^$]*?\\[A-Za-z]+[^$]*?)(?<![\\$])\$(?!\$)')


class FormelText(HTMLParser):
    """Die Textstücke je Block, ohne <code>, <pre>, <svg> und Ähnliches --
    dort setzt MathJax nichts."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.bloecke, self.aus = [[]], 0

    def handle_starttag(self, tag, attrs):
        if tag in FORMEL_AUSLASSEN:
            self.aus += 1
        elif tag in FORMEL_BLOECKE:
            self.bloecke.append([])

    def handle_endtag(self, tag):
        if tag in FORMEL_AUSLASSEN:
            self.aus = max(0, self.aus - 1)
        elif tag in FORMEL_BLOECKE:
            self.bloecke.append([])

    def handle_data(self, d):
        if not self.aus:
            self.bloecke[-1].append(d)


def _formel_block(stuecke):
    s = ''.join(stuecke)
    stueck = [i for i, t in enumerate(stuecke) for _ in t]
    raus, ohne, offen, anfang, frei, i = [], [], None, -1, 0, 0
    while i < len(s):
        if s[i] != '\\' or i + 1 >= len(s):
            i += 1
            continue
        n = s[i + 1]
        if n in '([':
            if offen:
                raus.append('Formel ohne Ende: „%s" -- vor dem nächsten Formelanfang fehlt %s'
                            % (norm(s[anfang:i])[:40], '\\)' if offen == '(' else '\\]'))
            else:
                ohne.append(s[frei:i])
            offen, anfang = n, i
        elif n in ')]':
            passt = (n == ')' and offen == '(') or (n == ']' and offen == '[')
            if not passt:
                raus.append('Formelende „\\%s" ohne Anfang: „%s"' % (n, norm(s[max(0, i - 30):i + 2])))
            elif stueck[anfang] != stueck[i + 1]:
                raus.append('HTML in der Formel „%s": Zwischen Anfang und Ende steht ein Tag -- Hervorhebung '
                            'und Zeilenumbruch macht LaTeX selbst' % norm(s[anfang:i + 2])[:40])
            if passt:
                offen, frei = None, i + 2
        i += 2  # jeder andere Befehl, auch \\ (Zeilenumbruch, \\[4pt]) und \$
    if offen:
        raus.append('Formel ohne Ende: „%s" -- %s fehlt im selben Absatz. Steht ein rohes < darin? Als &lt; '
                    'oder \\lt schreiben' % (norm(s[anfang:])[:40], '\\)' if offen == '(' else '\\]'))
    else:
        ohne.append(s[frei:])
    m = EINFACHE_DOLLAR.search(''.join(ohne))
    if m:
        raus.append('LaTeX zwischen einfachen $ wird nicht gesetzt: „%s" -- \\( … \\) schreiben'
                    % norm(m.group(0))[:40])
    return raus


def formel_fehler(h):
    """Die Formelfehler eines Felds (references/html.md, „Formeln"). Die
    SchuCu-Tabelle muss vorher heraus."""
    f = FormelText()
    f.feed(h)
    f.close()
    return [t for b in f.bloecke if b for t in _formel_block(b)]


def mehr_als_rahmen(style):
    """Was in einem style-Attribut über Rahmenlinien hinausgeht -- dieselbe
    Grenze wie _mehrAlsRahmen in lib/moodle/auswertung.dart: nur Stärke und
    Art der Linie, keine Farbe."""
    raus = []
    for d in style.split(';'):
        if ':' not in d:
            if d.strip():
                raus.append(d.strip())
            continue
        name, wert = (x.strip().lower() for x in d.split(':', 1))
        if not RAHMEN_EIGENSCHAFT.match(name):
            raus.append(name)
        elif any(not RAHMEN_WERT.match(w) for w in wert.split()):
            raus.append('%s: %s' % (name, wert))
    return raus


class HtmlRegeln(HTMLParser):
    """Prüft ein Feld des Entwurfs gegen die HTML-Regeln: keine
    style-Attribute ausser Rahmenlinien an Tabellen, Überschriften ab <h3>,
    Bilder mit Alternativtext und img-fluid aus dateien/, Tabellen mit
    Klasse, <strong>/<em> statt <b>/<i>/<u>, keine leeren Absätze, keine
    &nbsp;-Ketten, keine Word-Reste, keine übersprungene Überschriftenebene,
    https statt http, höchstens zwei Kastenarten -- dieselben Befunde wie in
    lib/moodle/auswertung.dart. Dazu Platzhalter der Vorlagen und
    Markdown-Reste. Sammelt die Dateien, auf die @@PLUGINFILE@@ zeigt. Die
    SchuCu-Tabelle folgt ihrer Vorlage und kommt vorher heraus."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.befunde, self.dateien, self.text = [], [], []
        self.elemente = set()      # Dateien, die ein Rahmen als Element einbindet
        self.svg = self.code = 0
        self.ebene, self.kaesten, self.absatz = 2, set(), None

    def befund(self, t):
        if t not in self.befunde:
            self.befunde.append(t)

    def handle_starttag(self, tag, attrs):
        self.element(tag, dict(attrs), self.get_starttag_text() or tag)
        if tag == 'svg':
            self.svg += 1
        elif tag in ('code', 'pre') and not self.svg:
            self.code += 1

    def handle_startendtag(self, tag, attrs):
        self.element(tag, dict(attrs), self.get_starttag_text() or tag)

    def handle_endtag(self, tag):
        if tag == 'svg' and self.svg:
            self.svg -= 1
        elif tag in ('code', 'pre') and self.code and not self.svg:
            self.code -= 1
        if tag == 'p' and self.absatz is not None and not self.svg:
            anfang, mit_inhalt = self.absatz
            if not mit_inhalt and not ''.join(self.text[anfang:]).replace('\xa0', ' ').strip():
                self.befund('leerer Absatz -- Abstand kommt aus den Stylesheets, nicht aus leeren Zeilen')
            self.absatz = None
        if tag in BLOCK:
            self.text.append('\n')

    def handle_data(self, d):
        if self.svg:
            return
        if '\xa0\xa0' in d:
            self.befund('&nbsp;-Kette zum Einrücken -- eine Liste oder ein neuer Absatz')
        if not self.code:
            self.text.append(d)

    def element(self, tag, a, roh):
        # Code im Text: dieselbe Grenze wie skripteImTextPruefen in
        # lib/moodle/elemente.dart -- die App schriebe das Blatt nicht. Auch in
        # einer eingebetteten Zeichnung, die sonst eigene Regeln hat.
        if tag == 'script':
            self.befund('Code im Text (<script>) -- Interaktives als Element in einen Rahmen '
                        '(references/elemente.md)')
            return
        for k, w in a.items():
            w = w or ''
            if k.startswith('on') or (k == 'attributename' and w.strip().lower().startswith('on')):
                self.befund('Code im Text (%s an <%s>) -- Interaktives als Element (references/elemente.md)'
                            % (k if k.startswith('on') else w.strip(), tag))
            elif k == 'srcdoc':
                self.befund('<%s srcdoc>: Der Moodle-Editor löscht ihn -- als Elementdatei in dateien/ einbinden' % tag)
            elif re.sub(r'[\s\x00-\x1f]', '', w).lower().startswith('javascript:'):
                self.befund('javascript:-Adresse an <%s> -- Code gehört in ein Element' % tag)
        if self.svg:
            return                # eine eingebettete Zeichnung hat eigene Elemente
        if tag in BLOCK:
            self.text.append('\n')
        if tag == 'iframe':
            src = a.get('src') or ''
            if src.startswith('@@PLUGINFILE@@/') and re.search(r'\.html?$', src, re.I):
                self.elemente.add(unquote(src[len('@@PLUGINFILE@@/'):]))
                if ' '.join(sorted(set((a.get('sandbox') or '-').split()))) != 'allow-scripts':
                    self.befund('Element %s ohne sandbox="allow-scripts" -- die App schreibt es so nicht' % src[15:])
                if not (a.get('title') or '').strip():
                    self.befund('Element %s ohne title -- er sagt Screenreadern, was es ist' % src[15:])
        if tag not in HTML_ELEMENTE:
            self.befund('Platzhalter steht noch da: %s' % norm(roh)[:60])
            return
        style = a.get('style')
        if style is not None:
            if tag not in TABELLENTEILE:
                self.befund('style-Attribut an <%s> -- das Aussehen kommt aus den Stylesheets von Moodle' % tag)
            elif mehr_als_rahmen(style):
                self.befund('style-Attribut an <%s> mit mehr als Rahmenlinien (%s)'
                            % (tag, ', '.join(mehr_als_rahmen(style))))
        klassen = (a.get('class') or '').split()
        if any(k.startswith('Mso') for k in klassen):
            self.befund('Word-Rest class="Mso…" -- das HTML neu schreiben, nicht übernehmen')
        if tag == 'p':
            self.absatz = (len(self.text), False)
        elif tag in ('img', 'iframe', 'video', 'audio', 'object') and self.absatz:
            self.absatz = (self.absatz[0], True)
        if 'alert' in klassen:
            self.kaesten.update(k for k in klassen if k.startswith('alert-'))
        if tag in ('h1', 'h2'):
            self.befund('<%s>: Überschriften beginnen bei <h3>, h1 und h2 sind Moodle vorbehalten' % tag)
        elif re.fullmatch(r'h[3-6]', tag):
            if int(tag[1]) > self.ebene + 1:
                self.befund('<%s> folgt auf <h%d>: Ebene übersprungen' % (tag, self.ebene))
            self.ebene = int(tag[1])
        elif tag in ('b', 'i', 'font', 'center'):
            self.befund('<%s> -- zur Hervorhebung <strong> oder <em>, sonst nichts' % tag)
        elif tag == 'u':
            self.befund('<u> -- Unterstrichenes hält jeder für einen Link; <strong> oder <em>')
        elif tag == 'table' and 'table' not in klassen:
            self.befund('Tabelle ohne class="table" (etwa "table table-bordered")')
        elif tag == 'img':
            src = a.get('src') or ''
            if not (a.get('alt') or '').strip():
                self.befund('Bild ohne Alternativtext: %s' % src[:60])
            if 'img-fluid' not in klassen:
                self.befund('Bild ohne class="img-fluid": %s' % src[:60])
            if not src.startswith('@@PLUGINFILE@@/'):
                self.befund('Bild „%s": src="@@PLUGINFILE@@/<name>" und die Datei in dateien/ -- '
                            'Moodle speichert sie so selbst' % src[:60])
        for attr in ('href', 'src'):
            w = a.get(attr) or ''
            if w.startswith('@@PLUGINFILE@@/'):
                self.dateien.append(unquote(w[len('@@PLUGINFILE@@/'):]))
            elif w.startswith('//'):
                self.befund('protokollrelative Adresse %s -- mit https: davor, auf Papier sonst unvollständig'
                            % w[:60])
            elif w.startswith('http://'):
                self.befund('unverschlüsselte Adresse %s -- https://' % w[:60])

    def ergebnis(self):
        if len(self.kaesten) > 2:
            self.befund('mehr als zwei Kastenarten: %s -- höchstens zwei je Seite'
                        % ', '.join(sorted(self.kaesten)))
        text = ''.join(self.text)
        for muster, ersatz in MARKDOWN:
            m = muster.search(text)
            if m:
                self.befund('Markdown im HTML: „%s" -- %s' % (norm(m.group(0))[:40], ersatz))
        return self.befunde


# ---- Die beiden Leser ------------------------------------------------------
def lies_entwurf(ordner):
    """Liest den Entwurf. Gibt (Titel, Seiten, ohne Inhalt, Befunde am
    Entwurf, Namen, die in keinem Text stehen dürfen) -- oder einen Text,
    warum nichts zu prüfen ist."""
    p = os.path.join(ordner, MANIFEST)
    if not os.path.isfile(p):
        return 'Kein Entwurf: %s fehlt in %s (references/vorlagen.md, „Der Entwurf")' % (MANIFEST, ordner)
    try:
        m = json.load(io.open(p, encoding='utf-8'))
    except ValueError as e:
        return '%s ist kein gültiges JSON: %s' % (MANIFEST, e)
    ab = m.get('abschnitt') if isinstance(m, dict) else None
    liste = m.get('aktivitaeten') if isinstance(m, dict) else None
    if not isinstance(ab, dict) or not norm(str(ab.get('name') or '')) or not isinstance(liste, list) or not liste:
        return '%s braucht "abschnitt" mit "name" und eine nicht leere Liste "aktivitaeten"' % MANIFEST
    vorab, seiten, ohne_inhalt, verboten, genutzt = [], [], [], set(), set()
    weitere = {}              # Name -> wie ein Befund sie nennt

    def befund(wo, text):
        vorab.append((wo, text))

    def rel(o):
        return os.path.relpath(o, ordner).replace(os.sep, '/')

    def html_pruefen(o, h, wo):
        """HTML-Regeln und dateien/ an einem Feld oder Kapitel: Jede Datei,
        auf die es zeigt, liegt in dateien/ desselben Ordners -- von dort lädt
        die App sie in den Entwurfsbereich dieses Felds --, und jede Datei
        dort wird gebraucht."""
        r = HtmlRegeln()
        r.feed(TABELLE_RE.sub(' ', h))
        r.close()
        for t in r.ergebnis():
            befund(wo, t)
        # Ein Formelfehler ist ein Syntaxfehler: Die App bricht das Schreiben
        # dieses Felds ab, bis er behoben ist.
        for t in formel_fehler(TABELLE_RE.sub(' ', h)):
            befund(wo, 'Formelfehler: ' + t)
        da = os.path.join(o, 'dateien')
        da_ist = sorted(f for f in os.listdir(da) if os.path.isfile(os.path.join(da, f))) if os.path.isdir(da) else []
        for n in sorted(set(r.dateien)):
            if n not in da_ist:
                befund(wo, '%s liegt nicht in %s/dateien/ -- jedes Blatt bringt seine Bilder selbst mit'
                       % (n, rel(o)))
            elif n in r.elemente:
                for t in element_fehler(io.open(os.path.join(da, n), encoding='utf-8', errors='replace').read()):
                    befund(wo, 'Element %s: %s' % (n, t))
            else:
                with open(os.path.join(da, n), 'rb') as f:
                    stellen = code_in_datei(n, f.read())
                if stellen:
                    befund(wo, 'Datei %s enthält Code (%s) und ist kein Element -- die App lädt sie so nicht hoch '
                               '(references/elemente.md)' % (n, stellen[0]))
        for f in da_ist:
            if f not in r.dateien:
                befund(wo, '%s/dateien/%s wird nicht eingebunden' % (rel(o), f))
            if re.search(r'\.(svg|png|jpe?g|gif|webp)$', f, re.I):
                verboten.add(f)

    def json_in(d, datei, wo):
        p = os.path.join(d, datei)
        if not os.path.isfile(p):
            befund(wo, '%s fehlt in %s' % (datei, rel(d)))
            return None
        try:
            return json.load(io.open(p, encoding='utf-8'))
        except ValueError as x:
            befund(wo, '%s ist kein gültiges JSON: %s' % (datei, x))
            return None

    def weitere_aktivitaet(typ, d, e, wo):
        """Was eine weitere Aktivität braucht, damit die Übertragung sie
        anlegen und füllen kann (references/vorlagen.md, „Weitere Aktivitäten
        im Entwurf"). `d`: ihr Ordner, None bei einem Link ohne Ordner."""
        einst = e.get('einstellungen') if isinstance(e.get('einstellungen'), dict) else {}
        if typ == 'url' and not str(einst.get('externalurl') or '').startswith('https://'):
            befund(wo, 'Link ohne Adresse: "einstellungen": {"externalurl": "https://…"}')
        if d is None:
            return
        texte = []
        intro = os.path.join(d, 'introeditor.html')
        if os.path.isfile(intro):
            texte.append(io.open(intro, encoding='utf-8').read())
        if typ in ('board', 'kanban'):
            j = json_in(d, typ + '.json', wo)
            if j is not None:
                spalten = j.get('spalten') if isinstance(j, dict) else None
                if not isinstance(spalten, list) or not spalten or not all(isinstance(s, str) and norm(s)
                                                                           for s in spalten):
                    befund(wo, '%s.json braucht "spalten", eine Liste von Namen' % typ)
                    spalten = []
                elif len({norm(s) for s in spalten}) != len(spalten):
                    befund(wo, '%s.json: zwei Spalten mit demselben Namen' % typ)
                was = 'notizen' if typ == 'board' else 'karten'
                for x in (j.get(was) or []) if isinstance(j, dict) else []:
                    if not isinstance(x, dict) or norm(str(x.get('spalte') or '')) not in {norm(s) for s in spalten}:
                        befund(wo, '%s.json: %s nennt keine Spalte, die es gibt'
                               % (typ, 'eine Notiz' if typ == 'board' else 'eine Karte'))
                    elif typ == 'kanban' and not norm(str(x.get('titel') or '')):
                        befund(wo, 'kanban.json: eine Karte ohne "titel"')
        elif typ == 'checklist':
            j = json_in(d, 'eintraege.json', wo)
            if j is not None and (not isinstance(j, list) or not j):
                befund(wo, 'eintraege.json braucht eine Liste von Einträgen')
            elif j is not None:
                vorher = -1
                for i, x in enumerate(j, 1):
                    if not isinstance(x, dict) or not norm(str(x.get('text') or '')):
                        befund(wo, 'eintraege.json: Eintrag %d ohne "text"' % i)
                        continue
                    tiefe = x.get('tiefe', 0)
                    if not isinstance(tiefe, int) or tiefe < 0 or tiefe > vorher + 1:
                        befund(wo, 'eintraege.json: „%s" springt in der Einrückung -- höchstens eine Stufe '
                                   'tiefer als der Eintrag davor' % norm(x['text']))
                        tiefe = vorher + 1
                    vorher = tiefe
                    if x.get('zustand') not in (None, 'pflicht', 'optional', 'ueberschrift'):
                        befund(wo, 'eintraege.json: „%s" hat "zustand" %r -- möglich sind pflicht, optional, '
                                   'ueberschrift' % (norm(x['text']), x.get('zustand')))
        elif typ == 'wiki':
            j = json_in(d, 'seiten.json', wo)
            if j is not None and (not isinstance(j, list) or not j):
                befund(wo, 'seiten.json braucht eine Liste von Seiten')
            elif j is not None:
                titel_ = []
                for i, x in enumerate(j, 1):
                    t_ = norm(str(x.get('titel') or '')) if isinstance(x, dict) else ''
                    f = x.get('datei') if isinstance(x, dict) else None
                    if not t_ or not isinstance(f, str) or not os.path.isfile(os.path.join(d, f)):
                        befund(wo, 'seiten.json: Seite %d braucht "titel" und eine "datei", die im Ordner liegt' % i)
                        continue
                    titel_.append(t_)
                    texte.append(io.open(os.path.join(d, f), encoding='utf-8').read())
                if len(set(titel_)) != len(titel_):
                    befund(wo, 'seiten.json: zwei Seiten mit demselben Titel')
                start = norm(str(einst.get('firstpagetitle') or ''))
                if titel_ and start != titel_[0]:
                    befund(wo, 'die erste Seite „%s" ist die Startseite und muss heißen wie "firstpagetitle" in den '
                               'Einstellungen%s' % (titel_[0], ' („%s")' % start if start else ' -- dort fehlt er'))
        elif typ == 'quiz':
            fr = e.get('fragen')
            if not isinstance(fr, dict) or not norm(str(fr.get('sammlung') or '')) \
                    or not norm(str(fr.get('kategorie') or '')):
                befund(wo, 'Test ohne Ort für seine Fragen: "fragen": {"sammlung": "…", "kategorie": "…"} im Eintrag')
            p = os.path.join(d, 'fragen.xml')
            wurzel = None
            if not os.path.isfile(p):
                befund(wo, 'fragen.xml fehlt -- die Fragen schreibt der Skill moodle-fragen')
            else:
                try:
                    wurzel = ET.parse(p).getroot()
                except ET.ParseError as x:
                    befund(wo, 'fragen.xml ist kein gültiges XML: %s' % x)
            if wurzel is not None:
                fragen = [q for q in wurzel.iter('question') if q.get('type') != 'category']
                if not fragen:
                    befund(wo, 'fragen.xml enthält keine Frage')
                gesehen = set()
                for q in fragen:
                    idn = norm(q.findtext('idnumber') or '')
                    if not idn:
                        befund(wo, 'Frage „%s" ohne Sachnummer (<idnumber>) -- sie ist die einzige Kennung, die '
                                   'eine Änderung überlebt' % (norm(q.findtext('name/text') or '') or '?'))
                    elif idn in gesehen:
                        befund(wo, 'Sachnummer %s steht zweimal in fragen.xml' % idn)
                    gesehen.add(idn)
        elif typ in ('folder', 'resource'):
            b = os.path.join(d, 'bereiche', 'files')
            n = sum(len(fs) for _, _, fs in os.walk(b)) if os.path.isdir(b) else 0
            if typ == 'folder' and n == 0:
                befund(wo, 'Verzeichnis ohne Dateien -- sie liegen in %s/bereiche/files/' % rel(d))
            if typ == 'resource' and n != 1:
                befund(wo, 'eine Datei braucht genau eine Datei in %s/bereiche/files/ (gefunden: %d)' % (rel(d), n))
            for wurzel, _, fs in (os.walk(b) if os.path.isdir(b) else []):
                for f in sorted(fs):
                    with open(os.path.join(wurzel, f), 'rb') as datei:
                        stellen = code_in_datei(f, datei.read())
                    if stellen:
                        befund(wo, '%s enthält Code (%s) -- die App lädt sie so nicht hoch (references/elemente.md)'
                               % (rel(os.path.join(wurzel, f)), stellen[0]))
        if texte:
            html_pruefen(d, '\n'.join(texte), wo)

    # Die Beschreibung des Abschnitts: die Kurzfassung der Handlungssituation.
    titel = norm(str(ab['name']))
    ao = ab.get('ordner')
    if not isinstance(ao, str) or not os.path.isfile(os.path.join(ordner, ao, 'summary_editor.html')):
        befund(MANIFEST, 'Beschreibung des Abschnitts fehlt: "abschnitt" braucht "ordner" mit '
                         'summary_editor.html, der Kurzfassung der Handlungssituation')
    else:
        genutzt.add(ao)
        h = io.open(os.path.join(ordner, ao, 'summary_editor.html'), encoding='utf-8').read()
        if not html_text(h):
            befund('Abschnitt (%s)' % ao, 'Beschreibung ist leer')
        html_pruefen(os.path.join(ordner, ao), h, 'Abschnitt (%s)' % ao)

    namen = set()
    for i, e in enumerate(liste, 1):
        if not isinstance(e, dict):
            befund(MANIFEST, 'Eintrag %d in "aktivitaeten" ist kein Objekt' % i)
            continue
        typ, name, o = e.get('typ'), norm(str(e.get('name') or '')), e.get('ordner')
        wo = ('„%s" (%s)' % (name, o) if isinstance(o, str) and o else '„%s"' % name) if name else 'Eintrag %d' % i
        if not name:
            befund(wo, 'ohne "name" -- er wird der Name der Aktivität')
            continue
        if name in namen:
            befund(wo, 'derselbe Name steht zweimal in %s' % MANIFEST)
        namen.add(name)
        if 'einstellungen' in e and not isinstance(e['einstellungen'], dict):
            befund(wo, '"einstellungen" muss ein Objekt sein, wie bei aktivitaet_anlegen')
        if typ == 'subsection':
            continue              # ohne Inhalt; die Einträge danach kommen hinein
        if not isinstance(typ, str) or not re.fullmatch(r'[a-z]+', typ):
            befund(wo, '"typ" fehlt oder ist kein Moodle-Typ (page, assign, label, book, subsection …)')
            continue
        if typ in WEITERE:
            weitere[name] = wo
            if ROLLE.match(name) or name in (NAME_SCHUCU, NAME_HAND, NAME_SITUATION):
                befund(wo, 'ist kein Blatt und trägt keine Kennung -- der Name sagt, wozu die Aktivität da ist')
        if typ == 'url' and not o:
            weitere_aktivitaet(typ, None, e, wo)      # ein Link braucht keinen Ordner
            continue
        if not isinstance(o, str) or not o or not os.path.isdir(os.path.join(ordner, o)):
            befund(wo, 'Ordner fehlt' if isinstance(o, str) and o else 'ohne "ordner"')
            continue
        genutzt.add(o)
        if re.search(r'[-\d]', o):
            verboten.add(o)
        d = os.path.join(ordner, o)
        if typ == 'book':
            b = lies_buch(d)
            if b is None:
                befund(wo, 'Buch ohne kapitel.json -- die Kapitel stehen in kapitel-<id>/content_editor.html')
                continue
            h, md, kapitel = b
            if not kapitel:
                befund(wo, 'Buch ohne Kapitel')
            elif kapitel[0][2].get('unterkapitel'):
                befund(wo, 'das erste Kapitel kann kein Unterkapitel sein')
            for ko, kh, k in kapitel:
                kwo = '%s, Kapitel „%s"' % (wo, norm(str(k.get('titel') or '')))
                if not norm(str(k.get('titel') or '')):
                    befund(kwo, 'Kapitel ohne "titel" in kapitel.json')
                if not os.path.isfile(os.path.join(ko, 'content_editor.html')):
                    befund(kwo, '%s/content_editor.html fehlt' % rel(ko))
                elif not html_text(kh):
                    befund(kwo, 'Kapitel ohne Inhalt -- Moodle verlangt in jedem Kapitel Text')
                else:
                    html_pruefen(ko, kh, kwo)
            seiten.append(seite(o, typ, name, False, h, md, [k[0] for k in kapitel], wo))
        elif typ in WEITERE:
            weitere_aktivitaet(typ, d, e, wo)
        elif typ in INHALT:
            erstes = INHALT[typ][0] + '.html'
            if not os.path.isfile(os.path.join(d, erstes)):
                befund(wo, '%s fehlt in %s -- dort sucht aktivitaet_anlegen den Inhalt' % (erstes, o))
                continue
            h = lies_feld(d, typ)
            html_pruefen(d, h, wo)
            seiten.append(seite(o, typ, name, False, h, zu_markdown(h), [d], wo))
        else:
            ohne_inhalt.append('„%s" (%s)' % (name, typ))

    # Was nicht in lernsituation.json steht, kommt nicht in den Kurs.
    for f in sorted(os.listdir(ordner)):
        if f.startswith('.') or f == MANIFEST or f in genutzt:
            continue
        if os.path.isdir(os.path.join(ordner, f)):
            befund(f, 'steht nicht in %s -- kommt nicht in den Kurs' % MANIFEST)
        else:
            befund(f, 'hat im Entwurf keinen Platz -- neben %s gibt es nur die Ordner der Aktivitäten'
                   % MANIFEST)
    return titel, seiten, ohne_inhalt, vorab, verboten, weitere


def lies_moodle(ao, abschnitt_id):
    """Liest den Abschnitt aus dem Arbeitsordner. Gibt (Titel, Kurs, Seiten,
    ohne Inhalt, was noch zu lesen ist, {cmid: Name} aller Aktivitäten des
    Abschnitts) -- oder None, wenn keine kurs-*.json ihn enthält."""
    gefunden = abschnitt_aus_kurs(ao, abschnitt_id) if os.path.isdir(ao) else None
    if gefunden is None:
        return None
    kurs, titel, cms = gefunden
    seiten, ohne_inhalt, fehlen, weitere = [], [], [], {}
    for cmid, modul, name, erreichbar in cms:
        wo = '„%s" (cm %d)' % (name, cmid)
        if modul == 'subsection':
            continue
        if modul in WEITERE:
            # Ihr Inhalt steht nicht im Formular; geprüft wird, dass die
            # Handreichung sie nennt und jede Nennung ein Link ist.
            weitere[name] = wo
            continue
        if modul == 'book':
            b = lies_buch(os.path.join(ao, 'buch-%d' % cmid))
            if b is None:
                fehlen.append('buch_lesen(%d) für „%s"' % (cmid, name))
                continue
            h, md, kapitel = b
            seiten.append(seite(cmid, modul, name, erreichbar, h, md, [k[0] for k in kapitel], wo))
        elif modul in INHALT:
            o = os.path.join(ao, 'cm-%d' % cmid)
            if not os.path.isfile(os.path.join(o, 'uebersicht.json')):
                fehlen.append('aktivitaet_lesen(%d) für „%s"' % (cmid, name))
                continue
            h = lies_feld(o, modul)
            seiten.append(seite(cmid, modul, name, erreichbar, h, zu_markdown(h), [o], wo))
        else:
            ohne_inhalt.append(wo)
    return titel, kurs, seiten, ohne_inhalt, fehlen, {cmid: name for cmid, _, name, _ in cms}, weitere


# ---- Die Prüfung -----------------------------------------------------------
def pruefe(kopf, seiten, ohne_inhalt, vorab=(), verboten=(), ziele=None, weitere=None):
    """Prüft die Seiten an der Prüfform und druckt das Ergebnis. `ziele`
    ({cmid: Name}) gibt es nur in Moodle; dann werden auch die Links
    geprüft. Rückgabe wie das Skript."""
    tmp = tempfile.mkdtemp(prefix='ls-pruefform-')
    try:
        return _pruefe(kopf, seiten, ohne_inhalt, vorab, verboten, ziele, weitere or {}, tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def _pruefe(kopf, seiten, ohne_inhalt, vorab, verboten, ziele, weitere, tmp):
    belegt, ohne_rolle = {}, []
    for s in seiten:
        datei = rolle(s['name'], s['h'], s['md'], belegt)
        if datei is None:
            ohne_rolle.append(s)
            continue
        belegt[datei] = s
        inhalt = s['h'].strip() if datei == SCHUCU else s['md']
        io.open(os.path.join(tmp, datei), 'w', encoding='utf-8', newline='').write('# %s\n\n%s\n' % (s['name'], inhalt))
        for o in s['ordner']:
            d = os.path.join(o, 'dateien')
            for f in os.listdir(d) if os.path.isdir(d) else []:
                if os.path.isfile(os.path.join(d, f)):
                    shutil.copyfile(os.path.join(d, f), os.path.join(tmp, f))

    print(kopf)
    if HAND not in belegt:
        print('Keine Lehrerhandreichung: keine Seite „%s" und keine mit dem Abschnitt „Ablaufplan" -- '
              'ohne sie ist nichts zu prüfen.' % NAME_HAND)
        for wo, text in vorab:
            print('  %-40s %s' % (wo, text))
        return 2
    pr = Pruefung(tmp, bilddateien=ziele is not None, weitere=weitere)
    if pr.pruefen(verboten) is None:
        return 2
    for wo, text in vorab:
        pr.befund(wo, text)
    if '<table class="lernsituation"' in belegt[HAND]['h']:
        pr.befund(HAND, 'SchuCu-Tabelle steht in der Handreichung -- sie gehört allein auf die Seite „%s"'
                  % NAME_SCHUCU)
    if ziele is not None:
        links(pr, belegt, ziele, weitere)
    for s in ohne_rolle:
        if ziele is None:
            pr.befund(s['wo'], 'Name ohne Kennung -- ein Blatt heißt „Arbeitsblatt n: …", „Infoblatt n: …", '
                               '„Hilfe zu …", „Vertiefung zu …", „Lösung zu …"; dazu gibt es nur „%s", '
                               '„%s" und „%s"' % (NAME_SCHUCU, NAME_HAND, NAME_SITUATION))
        else:
            pr.hinweis('ohne Rolle in der Lernsituation, nicht geprüft: %s' % s['wo'])
    for w in ohne_inhalt:
        pr.hinweis('ohne Rolle in der Lernsituation, nicht geprüft: %s' % w)

    def anzeige(d):
        if d in belegt:
            return belegt[d]['wo']
        k, loes = kennung(d)
        return ('Lösung zu ' + k if loes else k) if k else d

    return pr.ausgabe('%d Aktivitäten, %d davon Teil der Lernsituation'
                      % (len(seiten) + len(ohne_inhalt) + len(weitere), len(belegt) + len(weitere)), anzeige)


def links(pr, belegt, ziele, weitere=()):
    """Die Links in Moodle: Ziel im Abschnitt, Text wie der Name des Ziels
    (Kennung oder ganzer Name), keine Lösung von einer Seite aus, die
    Lernende sehen -- und jede Nennung eines Blatts ist ein Link."""
    kennungen = {schluessel(m.group(0)) for n in ziele.values() for m in [re.match(ZIEL, n)] if m}
    for datei, s in belegt.items():
        verweise = []
        for o in s['ordner']:
            u = os.path.join(o, 'uebersicht.json')
            if os.path.isfile(u):
                for feld in (json.load(io.open(u, encoding='utf-8')).get('auswertung') or {}).get('felder') or []:
                    verweise += [v for v in feld.get('verweise') or [] if v.get('art') == 'aktivitaet']
        for v in verweise:
            text, ziel = norm(v.get('text') or ''), v.get('cmid')
            if ziel not in ziele:
                if re.fullmatch(ZIEL, text):
                    pr.befund(datei, 'Link "%s" zeigt auf cm %s „%s" ausserhalb dieses Abschnitts -- nach '
                                     'einem Duplizieren auf das Gegenstück hier umstellen'
                              % (text, ziel, v.get('zielTitel') or '?'))
                continue
            zname = ziele[ziel]
            kennung_ziel = zname.split(':', 1)[0].strip() if ':' in zname else None
            if text not in (norm(zname), kennung_ziel):
                pr.befund(datei, 'Link "%s" auf „%s": Der Text passt nicht zum Namen -- Kennung oder '
                                 'ganzer Name' % (text, zname))
            if s['erreichbar'] and re.match(r'Lösung\b', zname):
                pr.befund(datei, 'für Lernende erreichbar und verlinkt die Lösung „%s"' % zname)
        # Jede Nennung eines Blatts ist ein Link -- ausser auf der SchuCu-Seite,
        # die für sich steht, und auf das eigene Blatt.
        if datei == SCHUCU:
            continue
        eigen = schluessel(re.match(ZIEL, s['name']).group(0)) if re.match(ZIEL, s['name']) else None
        # Zellen und Absätze bleiben getrennt: "Arbeitsblatt" in der Spalte Art
        # und "1–4" daneben sind keine Nennung.
        ohne_links = re.sub(r'<a\b[^>]*>.*?</a>', ' ', s['h'], flags=re.S | re.I)
        ohne_links = html_text(re.sub(r'<(?:/?(?:td|th|tr|p|li|div|h\d)\b[^>]*|br\s*/?)>', ' ¦ ', ohne_links))
        for m in re.finditer(ZIEL, ohne_links):
            k = schluessel(m.group(0))
            if k != eigen and k in kennungen:
                pr.befund(datei, 'nennt "%s" ohne Link' % norm(m.group(0)))
        # Ebenso der Name einer weiteren Aktivität in Anführungszeichen.
        for m in ZITIERT.finditer(ohne_links):
            if norm(m.group(1)) in weitere:
                pr.befund(datei, 'nennt „%s" ohne Link' % norm(m.group(1)))


def main(argv):
    if len(argv) == 4 and argv[1] == '--moodle' and argv[3].isdigit():
        ao, abschnitt_id = argv[2], int(argv[3])
        gelesen = lies_moodle(ao, abschnitt_id)
        if gelesen is None:
            print('Abschnitt %d steht in keiner kurs-*.json im Arbeitsordner %s -- zuerst '
                  'kurs_uebersicht(kurs).' % (abschnitt_id, ao))
            return 2
        titel, kurs, seiten, ohne_inhalt, fehlen, ziele, weitere = gelesen
        if fehlen:
            print('Erst lesen, dann prüfen -- es fehlt: %s' % '; '.join(fehlen))
            return 2
        return pruefe('Stand in Moodle: Abschnitt „%s" (id %d, Kurs %d)' % (titel, abschnitt_id, kurs),
                      seiten, ohne_inhalt, ziele=ziele, weitere=weitere)
    if len(argv) != 2 or argv[1].startswith('-'):
        print(__doc__)
        return 2
    gelesen = lies_entwurf(argv[1])
    if isinstance(gelesen, str):
        print(gelesen)
        return 2
    titel, seiten, ohne_inhalt, vorab, verboten, weitere = gelesen
    return pruefe('Entwurf: Abschnitt „%s" (%s)' % (titel, argv[1]), seiten, ohne_inhalt, vorab, verboten,
                  weitere=weitere)


if __name__ == '__main__':
    sys.exit(main(sys.argv))
