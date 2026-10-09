#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Prüft das Prüfskript des Skills lernsituation.

Das Beispiel in lernsituation/references/beispiel/ muss ohne Befund
durchgehen. Dann wird es kopiert und gezielt beschädigt -- und jede
Beschädigung muss als Befund erscheinen. Ein Prüfskript, das nur das Gute
durchwinkt, ist nicht geprüft. Dasselbe am Stand in Moodle: das Beispiel so
abgelegt, wie die App einen Abschnitt nach dem Lesen hinterlässt.
"""
import html
import importlib.util
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True    # kein __pycache__ im Skill
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
HIER = os.path.dirname(os.path.abspath(__file__))
WURZEL = os.path.dirname(HIER)
SKRIPT = os.path.join(WURZEL, 'lernsituation', 'scripts', 'pruefe-lernsituation.py')
BEISPIEL = os.path.join(WURZEL, 'lernsituation', 'references', 'beispiel')
VORLAGE_BG = os.path.join(WURZEL, 'lernsituation', 'references', 'schucu-bg.html')
MANIFEST = 'lernsituation.json'
HAND = 'lehrerhandreichung/page.html'
SCHUCU = 'schucu/page.html'
AB1 = 'ab-01-auftrag/page.html'
AB1L = 'ab-01-auftrag-loesung/page.html'
HILFE1 = 'ab-01-auftrag-hilfe/page.html'
AB2 = 'ab-02-umsetzung/page.html'
AB2L = 'ab-02-umsetzung-loesung/page.html'
VERT2 = 'ab-02-umsetzung-vertiefung/page.html'
IB1 = 'ib-01-vlan-grundlagen/page.html'
SVG = 'Z-01-netz-vorher.svg'
KI = '\n<p>Inhalte können teilweise mit KI generiert sein.</p>'


def lauf(ordner):
    r = subprocess.run([sys.executable, '-B', SKRIPT, ordner], capture_output=True,
                       text=True, encoding='utf-8', errors='replace')
    return r.returncode, r.stdout + r.stderr


def ersetze(ordner, datei, alt, neu):
    p = os.path.join(ordner, datei)
    t = io.open(p, encoding='utf-8').read()
    assert alt in t, 'Anker fehlt in %s: %r' % (datei, alt[:40])
    io.open(p, 'w', encoding='utf-8', newline='').write(t.replace(alt, neu, 1))


def manifest(ordner, f):
    p = os.path.join(ordner, MANIFEST)
    m = json.load(io.open(p, encoding='utf-8'))
    f(m)
    io.open(p, 'w', encoding='utf-8', newline='').write(json.dumps(m, ensure_ascii=False, indent=2))


def eintrag(m, ordner):
    return next(e for e in m['aktivitaeten'] if e.get('ordner') == ordner)


def setze(entwurf, welcher, **werte):
    manifest(entwurf, lambda m: eintrag(m, welcher).update(werte))


def weg(ordner, welcher):
    """Nimmt eine Aktivität aus dem Entwurf: Eintrag und Ordner."""
    manifest(ordner, lambda m: m['aktivitaeten'].remove(eintrag(m, welcher)))
    shutil.rmtree(os.path.join(ordner, welcher))


def dazu(ordner, neu, nach=None):
    """Nimmt einen Eintrag in lernsituation.json auf, hinter `nach` oder ans Ende."""
    def f(m):
        a = m['aktivitaeten']
        a.insert(a.index(eintrag(m, nach)) + 1 if nach else len(a), neu)
    manifest(ordner, f)


def schreib(ordner, datei, text):
    p = os.path.join(ordner, datei)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    io.open(p, 'w', encoding='utf-8', newline='').write(text)


def tausche_tabelle(ordner, neu):
    """Ersetzt die SchuCu-Tabelle samt Absätzen darunter durch `neu` -- auf
    der SchuCu-Seite steht nichts anderes."""
    schreib(ordner, SCHUCU, neu + '\n')


def zurueck_in_handreichung(ordner):
    """Der alte Aufbau: Tabelle oben in der Handreichung, keine Seite SchuCu."""
    t = io.open(os.path.join(ordner, SCHUCU), encoding='utf-8').read()
    weg(ordner, 'schucu')
    ersetze(ordner, HAND, '<h3>Thematische Einführung', t + '<h3>Thematische Einführung')


def als_buch(ordner):
    """Die Handreichung als Buch, so wie der Entwurf es schreibt: je <h3> ein
    Kapitel, unter „Die Schritte im Einzelnen" je Schritt ein Unterkapitel,
    weitere <h4> werden <h3> im Kapitel."""
    d = os.path.join(ordner, 'lehrerhandreichung')
    h = io.open(os.path.join(d, 'page.html'), encoding='utf-8').read()
    os.remove(os.path.join(d, 'page.html'))
    kapitel, oben = [], None
    for teil in re.split(r'(<h[34]>.*?</h[34]>)', h):
        m = re.fullmatch(r'<h([34])>(.*?)</h\1>', teil)
        if m and m.group(1) == '3':
            oben = m.group(2)
            kapitel.append([oben, False, ''])
        elif m and oben == 'Die Schritte im Einzelnen':
            kapitel.append([m.group(2), True, ''])
        elif m:
            kapitel[-1][2] += '<h3>%s</h3>' % m.group(2)
        elif teil.strip():
            kapitel[-1][2] += teil
    for k in kapitel:
        if not k[2].strip():
            k[2] = '<p>Je Schritt ein Unterkapitel: was genau passiert und worauf zu achten ist.</p>\n'
    schreib(ordner, 'lehrerhandreichung/kapitel.json', json.dumps(
        [{'id': i, 'titel': t, 'unterkapitel': u} for i, (t, u, _) in enumerate(kapitel, 1)],
        ensure_ascii=False, indent=2))
    for i, (_, _, x) in enumerate(kapitel, 1):
        schreib(ordner, 'lehrerhandreichung/kapitel-%d/content_editor.html' % i, x.strip() + '\n')
    setze(ordner, 'lehrerhandreichung', typ='book', einstellungen={'numbering': 'Keine'})


def als_aufgabe(ordner, welcher):
    """Ein Blatt als Aufgabe: der Inhalt in introeditor.html."""
    d = os.path.join(ordner, welcher)
    os.rename(os.path.join(d, 'page.html'), os.path.join(d, 'introeditor.html'))
    setze(ordner, welcher, typ='assign')


# Die BG-Vorlage, so ausgefüllt, wie der Skill es tun soll -- Werte für
# Informatik, weil die Vorlage von dort kam.
BG_WERTE = [
    ('<td class="lssubhead">Titel:</td>\n      <td class="lsdata">&nbsp;</td>',
     '<td class="lssubhead">Titel:</td>\n      <td class="lsdata">Firmennetz in VLANs trennen</td>'),
    ('<td class="lssubhead">gepl. Zeitrichtwert:</td>\n      <td class="lsdata">&nbsp;</td>',
     '<td class="lssubhead">gepl. Zeitrichtwert:</td>\n      <td class="lsdata">4 UStd (180 min)</td>'),
    ('<td class="lssubhead">Autor*(en):</td>\n      <td class="lsdata">&nbsp;</td>',
     '<td class="lssubhead">Autor*(en):</td>\n      <td class="lsdata">vom Nutzer zu ergänzen</td>'),
    ('href="&lt;Adresse des Lehrplans&gt;">&lt;Lehrplan des Fachs&gt;</a>',
     'href="https://bildungsportal-niedersachsen.de/index.php?eID=dumpFile&amp;t=f&amp;f=12491'
     '&amp;token=e4b30f8cbc2433cb9cd08302a10e9a966f5a3719">Lehrplan\n            berufliche Informatik</a>'),
    ('<td class="lsdata">&lt;Vorgaben aus RRL, Modulen, Lernfelder, ...&gt;</td>',
     '<td class="lsdata">vom Nutzer zu ergänzen</td>'),
    ('<td class="lsdata">&lt;verkürzt - für KuK als\n        Zusammenfassung&gt;<br>&lt;Kern der '
     'Lernsituation, bildet den Rahmen des\n        Unterrichts&gt;</td>',
     '<td class="lsdata">Die Muster GmbH trennt ihr Netz in Abteilungsnetze.</td>'),
    ('<td class="lsdata" colspan="2">...</td>',
     '<td class="lsdata" colspan="2">VLAN-Konzept mit Zeichnung</td>'),
    ('<li>...</li>', '<li>im Team entscheiden</li>'),
    ('<li>...</li>', '<li>VLANs konfigurieren</li>'),
    ('&lt;nur die abgedeckten Buchstaben&gt;', 'A B'),
    ('&lt;alle Kompetenzbereiche des Kerncurriculums mit Buchstaben&gt;',
     'A: Kommunizieren, argumentieren und kooperieren; B:\n  Algorithmisieren und implementieren'
     '<br>\n  C: Strukturieren, modellieren und\n  darstellen, D: Analysieren, bewerten und testen'),
]


def bg(ordner, *aenderungen):
    t = io.open(VORLAGE_BG, encoding='utf-8').read()
    for alt, neu in BG_WERTE + list(aenderungen):
        assert alt in t, 'BG-Anker fehlt: %r' % alt[:50]
        t = t.replace(alt, neu, 1)
    tausche_tabelle(ordner, t.rstrip('\n'))


LIES4 = '<strong>Lies:</strong> Infoblatt 1, Abschnitt 4.'
BILD_ALT = 'alt="Netz der Muster GmbH vor der Umstellung: zwei Switches, alle Geräte in einem Segment" class="img-fluid"'

PINNWAND = 'Unsere VLAN-Aufteilung'
REFLEXION = '<td>Plenum</td><td>—</td>'


def weitere(ordner, eintraege):
    """Weitere Aktivitäten in den Entwurf: je (ordner, typ, name, {datei: inhalt},
    extra) ein Ordner mit seinen Dateien und ein Eintrag hinter der Pinnwand;
    im Ablaufplan stehen sie bei Schritt 7 als Material."""
    nach = 'pinnwand-aufteilung'
    for o, typ, name, dateien, extra in eintraege:
        for d, inhalt in dateien.items():
            schreib(ordner, '%s/%s' % (o, d), inhalt)
        # Ein Link ohne Beschreibung braucht keinen Ordner.
        e = dict({'ordner': o} if dateien else {}, typ=typ, name=name)
        e.update(extra)
        dazu(ordner, e, nach=nach)
        nach = o if dateien else nach
    ersetze(ordner, HAND, REFLEXION, '<td>Plenum</td><td>%s</td>'
            % ', '.join('„%s"' % e[2] for e in eintraege))


INTRO = {'introeditor.html': '<p>Für die Reflexion.</p>\n'}
ALLE_WEITEREN = [
    ('kanban-plan', 'kanban', 'Unser Arbeitsplan', dict(INTRO, **{'kanban.json':
        '{"spalten": ["Zu erledigen", "Erledigt"], "karten": [{"spalte": "Zu erledigen", "titel": "Ports"}]}'}), {}),
    ('liste-pruefen', 'checklist', 'Prüfliste zum VLAN-Konzept', {'eintraege.json':
        '[{"text": "Planung", "zustand": "ueberschrift"}, {"text": "Jede Abteilung hat ein VLAN", "tiefe": 1}, '
        '{"text": "Gäste getrennt", "tiefe": 1, "zustand": "optional"}]'}, {}),
    ('wiki-begriffe', 'wiki', 'Begriffe der Klasse', {'seiten.json':
        '[{"titel": "Begriffe", "datei": "begriffe.html"}, {"titel": "Tagging", "datei": "tagging.html"}]',
        'begriffe.html': '<p>Siehe [[Tagging]].</p>\n', 'tagging.html': '<p>Ein Tag kennzeichnet den Rahmen.</p>\n'},
     {'einstellungen': {'firstpagetitle': 'Begriffe'}}),
    ('test-uebung', 'quiz', 'Übung zu VLANs', {'fragen.xml':
        '<?xml version="1.0" encoding="UTF-8"?>\n<quiz><question type="truefalse"><name><text>Tag</text></name>'
        '<idnumber>vlan-01</idnumber></question></quiz>\n'},
     {'fragen': {'sammlung': 'VLAN-Segmentierung', 'kategorie': 'Übung'}}),
    ('material', 'folder', 'Vorlagen für die Konfiguration', {'bereiche/files/plan.ods': 'x'}, {}),
    ('vorlage', 'resource', 'Netzplan zum Weiterarbeiten', {'bereiche/files/netz.pkt': 'x'}, {}),
    ('hersteller', 'url', 'Herstellerdokumentation', {}, {'einstellungen': {'externalurl': 'https://example.org/vlan'}}),
]


def eine_weitere(nr, **aenderung):
    """Eine der weiteren Aktivitäten aus ALLE_WEITEREN, verändert."""
    o, typ, name, dateien, extra = ALLE_WEITEREN[nr]
    dateien, extra = dict(dateien), dict(extra)
    dateien.update(aenderung.get('dateien', {}))
    extra.update(aenderung.get('extra', {}))
    return lambda ordner: weitere(ordner, [(o, typ, aenderung.get('name', name), dateien, extra)])


FAELLE = [
    ('Lösung gelöscht', lambda o: weg(o, 'ab-02-umsetzung-vertiefung-loesung'),
     r'Lösung fehlt: „Lösung zur Vertiefung zu Arbeitsblatt 2: …"'),
    ('Summenzeile falsch', lambda o: ersetze(o, HAND, '<strong>180</strong>', '<strong>170</strong>'),
     r'Summenzeile sagt 170'),
    ('Zeitrichtwert überzogen', lambda o: ersetze(o, HAND, '<td>Durchführen</td><td>50</td>',
                                                  '<td>Durchführen</td><td>100</td>'),
     r'geplant bei Zeitrichtwert'),
    ('Platzhalter vergessen', lambda o: ersetze(o, HAND, 'Anrede der Lernenden auf den Blättern: <strong>du</strong>.',
                                                'Anrede der Lernenden auf den Blättern: &lt;du / Sie&gt;.'),
     r'Platzhalter steht noch da: <du / Sie>'),
    ('Platzhalter als Element', lambda o: ersetze(o, AB1, '<p>Erkläre in je einem Satz',
                                                  '<p><Aufgabenstellung mit Operator> Erkläre in je einem Satz'),
     r'Platzhalter steht noch da: <Aufgabenstellung mit Operator>'),
    ('Aufgabe ohne AFB', lambda o: ersetze(o, AB1, '<h3>Aufgabe 2 (10 min · Einzel · AFB II)</h3>',
                                           '<h3>Aufgabe 2 (10 min · Einzel)</h3>'),
     r'Aufgabe 2: Klammer'),
    ('Kopfzeit stimmt nicht', lambda o: ersetze(o, AB1, '<strong>Zeit gesamt:</strong> 65 min',
                                                '<strong>Zeit gesamt:</strong> 60 min'),
     r'Kopf sagt 60'),
    ('Blatt nicht in der Handreichung', lambda o: (
        shutil.copytree(os.path.join(o, 'ib-01-vlan-grundlagen'), os.path.join(o, 'ib-02-verwaist')),
        dazu(o, {'ordner': 'ib-02-verwaist', 'typ': 'page', 'name': 'Infoblatt 2: Verwaist'})),
     r'„Infoblatt 2: Verwaist" \(ib-02-verwaist\)\s+steht weder im Ablaufplan'),
    ('Zeichnung fehlt ganz', lambda o: (os.remove(os.path.join(o, 'ab-01-auftrag', 'dateien', SVG)),
                                        os.remove(os.path.join(o, 'ib-01-vlan-grundlagen', 'dateien', SVG))),
     r'Z-01-netz-vorher.svg liegt nicht in ab-01-auftrag/dateien/'),
    ('Zeichnung nur auf dem anderen Blatt', lambda o: shutil.rmtree(os.path.join(o, 'ib-01-vlan-grundlagen', 'dateien')),
     r'ib-01-vlan-grundlagen\)\s+Z-01-netz-vorher.svg liegt nicht in ib-01-vlan-grundlagen/dateien/'),
    ('Zeichnung nicht eingebunden', lambda o: shutil.copy(os.path.join(o, 'ab-01-auftrag', 'dateien', SVG),
                                                          os.path.join(o, 'ab-01-auftrag', 'dateien', 'Z-02-extra.svg')),
     r'ab-01-auftrag/dateien/Z-02-extra.svg wird nicht eingebunden'),
    # ---- Namen des Entwurfs gibt es in Moodle nicht ----
    ('Ordnername im Text', lambda o: ersetze(o, HAND, '<strong>Material:</strong> Arbeitsblatt 1, ab Beginn.',
                                             '<strong>Material:</strong> ab-01-auftrag, ab Beginn.'),
     r'Name aus dem Entwurf im Text: ab-01-auftrag --'),
    ('Zeichnung im Text', lambda o: ersetze(o, IB1, '<p>Sobald Geräte', '<p>Siehe Z-01-netz-vorher.svg. Sobald Geräte'),
     r'Name aus dem Entwurf im Text: Z-01-netz-vorher.svg'),
    ('Materialübersicht mit Dateien', lambda o: ersetze(o, HAND, '<th>Blatt</th><th>Art</th>',
                                                        '<th>Datei</th><th>Art</th>'),
     r'Materialübersicht nennt Dateien'),
    ('Name in Materialübersicht alt', lambda o: ersetze(o, HAND, '<td>Infoblatt 1: VLAN-Grundlagen</td>',
                                                        '<td>Infoblatt 1: VLAN-Basics</td>'),
     r'"Infoblatt 1: VLAN-Basics" ist nicht der Name eines Blatts'),
    ('Kennung ohne Blatt', lambda o: ersetze(o, HAND, '<td>Einzel</td><td>Infoblatt 1</td>',
                                             '<td>Einzel</td><td>Infoblatt 1, Infoblatt 3</td>'),
     r'"Infoblatt 3": dieses Blatt gibt es nicht'),
    # ---- lernsituation.json und die Ordner ----
    ('Fremde Datei im Entwurf', lambda o: schreib(o, 'notizen.txt', 'x'),
     r'notizen.txt\s+hat im Entwurf keinen Platz'),
    ('Ordner nicht genannt', lambda o: shutil.copytree(os.path.join(o, 'ab-02-umsetzung'), os.path.join(o, 'ab-03-rest')),
     r'ab-03-rest\s+steht nicht in lernsituation.json'),
    ('Name ohne Kennung', lambda o: setze(o, 'ab-02-umsetzung', name='AB-02: Umsetzung und Prüfung'),
     r'„AB-02: Umsetzung und Prüfung" \(ab-02-umsetzung\)\s+Name ohne Kennung'),
    ('Ordner fehlt', lambda o: setze(o, 'ab-01-auftrag-hilfe', ordner='ab-01-hilfe'),
     r'\(ab-01-hilfe\)\s+Ordner fehlt(.|\n)*ab-01-auftrag-hilfe\s+steht nicht in'),
    ('Inhalt im falschen Feld', lambda o: os.rename(os.path.join(o, HILFE1),
                                                    os.path.join(o, 'ab-01-auftrag-hilfe', 'introeditor.html')),
     r'page.html fehlt in ab-01-auftrag-hilfe'),
    ('Beschreibung des Abschnitts fehlt', lambda o: shutil.rmtree(os.path.join(o, 'abschnitt')),
     r'Beschreibung des Abschnitts fehlt'),
    ('Kennung doppelt', lambda o: (
        shutil.copytree(os.path.join(o, 'ab-02-umsetzung'), os.path.join(o, 'ab-02-zweites')),
        dazu(o, {'ordner': 'ab-02-zweites', 'typ': 'page', 'name': 'Arbeitsblatt 2: Zweites'})),
     r'dieselbe Kennung "Arbeitsblatt 2"'),
    ('Name doppelt', lambda o: dazu(o, {'ordner': 'ab-02-umsetzung', 'typ': 'page',
                                        'name': 'Arbeitsblatt 2: Umsetzung und Prüfung'}),
     r'derselbe Name steht zweimal'),
    # ---- HTML-Regeln ----
    ('style-Attribut', lambda o: ersetze(o, AB1, '<h3>Die Situation</h3>', '<h3 style="color: red">Die Situation</h3>'),
     r'style-Attribut an <h3>'),
    ('Rahmenlinie mit Farbe', lambda o: ersetze(o, AB1L, '<tr><td>Trunk</td>', '<tr><td style="border-top: 2px solid red">Trunk</td>'),
     r'mit mehr als Rahmenlinien \(border-top: 2px solid red\)'),
    ('Überschrift h2', lambda o: ersetze(o, IB1, '<h3>4. Was ein VLAN nicht ist</h3>', '<h2>4. Was ein VLAN nicht ist</h2>'),
     r'<h2>: Überschriften beginnen bei <h3>'),
    ('Bild ohne alt und img-fluid', lambda o: ersetze(o, AB1, BILD_ALT, ''),
     r'Bild ohne Alternativtext(.|\n)*Bild ohne class="img-fluid"'),
    ('Bild vom fremden Server', lambda o: ersetze(o, IB1, 'src="@@PLUGINFILE@@/Z-01-netz-vorher.svg"',
                                                  'src="https://example.org/netz.svg"'),
     r'Bild „https://example.org/netz.svg": src="@@PLUGINFILE@@/<name>"'),
    ('Tabelle ohne Klasse', lambda o: ersetze(o, AB2, '<table class="table table-bordered">', '<table>'),
     r'Tabelle ohne class="table"'),
    ('<b> statt <strong>', lambda o: ersetze(o, AB2L, '<strong>auf beiden Switches</strong>', '<b>auf beiden Switches</b>'),
     r'<b> -- zur Hervorhebung <strong>'),
    ('<u> und Word-Rest', lambda o: ersetze(o, AB2L, '<strong>auf beiden Switches</strong>',
                                            '<u class="MsoNormal">auf beiden Switches</u>'),
     r'Word-Rest class="Mso…"(.|\n)*<u> -- Unterstrichenes'),
    ('Leerer Absatz', lambda o: ersetze(o, IB1, '<h3>Zum Nachschlagen</h3>', '<p>&nbsp;</p>\n<h3>Zum Nachschlagen</h3>'),
     r'leerer Absatz'),
    ('&nbsp;-Kette', lambda o: ersetze(o, VERT2, '<p>Nennt drei', '<p>&nbsp;&nbsp;&nbsp;Nennt drei'),
     r'&nbsp;-Kette zum Einrücken'),
    ('Ebene übersprungen', lambda o: ersetze(o, HAND, '<h4>Quellen</h4>', '<h5>Quellen</h5>'),
     r'<h5> folgt auf <h3>: Ebene übersprungen'),
    ('http statt https', lambda o: ersetze(o, IB1, 'href="https://standards', 'href="http://standards'),
     r'unverschlüsselte Adresse http://standards'),
    ('Drei Kastenarten', lambda o: ersetze(o, IB1, '<h3>Zum Nachschlagen</h3>',
                                           '<div class="alert alert-info"><p>Merke: a</p></div>\n'
                                           '<div class="alert alert-warning"><p>Achtung: b</p></div>\n'
                                           '<div class="alert alert-danger"><p>Gefahr: c</p></div>\n'
                                           '<h3>Zum Nachschlagen</h3>'),
     r'mehr als zwei Kastenarten: alert-danger, alert-info, alert-warning'),
    ('Markdown im HTML', lambda o: ersetze(o, VERT2, '<p>Nennt drei', '<p>**Nennt** drei'),
     r'Markdown im HTML: „\*\*Nennt\*\*"'),
    ('Markdown-Codeblock', lambda o: ersetze(o, AB2, '<p>Beurteilt zum Schluss', '<p>```\nshow vlan\n```</p>\n<p>Beurteilt zum Schluss'),
     r'Markdown im HTML: „```"'),
    ('Formel mit rohem <', lambda o: ersetze(o, AB2, '<p>Beurteilt zum Schluss',
                                             '<p>Es gilt \\(x<y\\) für alle.</p>\n<p>Beurteilt zum Schluss'),
     r'Formelfehler: Formel ohne Ende'),
    ('Formel über zwei Absätze', lambda o: ersetze(o, AB2, '<p>Beurteilt zum Schluss',
                                                   '<p>\\( a + b</p>\n<p>c \\)</p>\n<p>Beurteilt zum Schluss'),
     r'Formelfehler: Formelende „\\\)" ohne Anfang'),
    ('LaTeX zwischen $', lambda o: ersetze(o, AB2, '<p>Beurteilt zum Schluss',
                                           '<p>Es gilt $\\frac{a}{b}$.</p>\n<p>Beurteilt zum Schluss'),
     r'Formelfehler: LaTeX zwischen einfachen \$'),
    ('Checkliste ohne Begründung', lambda o: ersetze(o, HAND,
        '<td>Gibt es eine Reflexionsphase?</td><td>Ja</td><td>Schritt 7, Frage nach der schwersten Entscheidung</td>',
        '<td>Gibt es eine Reflexionsphase?</td><td>Ja</td><td></td>'),
     r'ohne Begründung'),
    ('Link "hier"', lambda o: ersetze(o, IB1, '>https://standards.ieee.org/ieee/802.1Q/10323/</a>', '>hier</a>'),
     r'Link ohne ausgeschriebene Adresse'),
    ('Lösung mit weniger Aufgaben', lambda o: ersetze(o, AB2L, '<h3>Aufgabe 4</h3>', '<h3>Aufgabe vier</h3>'),
     r'Lösung hat 3 Aufgabenabschnitte'),
    ('Aufgabe auf dem IB', lambda o: ersetze(o, IB1, '<h3>Zum Nachschlagen</h3>',
                                             '<h3>Aufgabe 1 (5 min · Einzel · AFB I)</h3>\n<p>x</p>\n<h3>Zum Nachschlagen</h3>'),
     r'Informationsblatt enthält Aufgaben'),
    ('Handreichung ohne Lernumgebung', lambda o: ersetze(o, HAND, '<h3>Lernumgebung</h3>', '<h3>Raum</h3>'),
     r'Abschnitt „Lernumgebung" fehlt'),
    ('Handreichung ohne Bewertung', lambda o: ersetze(o, HAND, '<h3>Leistungsfeststellung und -bewertung</h3>',
                                                      '<h3>Bewertung</h3>'),
     r'Abschnitt „Leistungsfeststellung und -bewertung" fehlt'),
    ('Schritt ohne Überschrift', lambda o: ersetze(o, HAND, '<h4>Schritt 8: Puffer</h4>', '<p>Schritt 8: Puffer</p>'),
     r'Ablaufplan hat 8 Zeilen, aber nur 7 Schritte'),
    ('Buch: Kapitel leer', lambda o: (als_buch(o), schreib(o, 'lehrerhandreichung/kapitel-3/content_editor.html', '')),
     r'Kapitel „Lernumgebung"\s+Kapitel ohne Inhalt'),
    # ---- SchuCu-Seite ----
    ('SchuCu: noch in der Handreichung', zurueck_in_handreichung,
     r'Seite „SchuCu" fehlt(.|\n)*SchuCu-Tabelle steht in der Handreichung'),
    ('SchuCu: mehr auf der Seite', lambda o: ersetze(o, SCHUCU, KI, KI + '\n<h3>Thematische Einführung</h3>\n<p>Text</p>'),
     r'mehr als die Tabelle'),
    ('SchuCu: anderer Name', lambda o: setze(o, 'schucu', name='Lernsituation: Abteilungsnetze'),
     r'Die Seite mit der SchuCu-Tabelle muss „SchuCu" heißen'),
    ('SchuCu: Tabelle ohne Vorlage', lambda o: tausche_tabelle(
        o, '<table class="table"><tbody><tr><td>Titel</td><td>x</td></tr></tbody></table>'),
     r'SchuCu-Tabelle fehlt'),
    ('SchuCu: KI-Hinweis fehlt', lambda o: ersetze(o, SCHUCU, KI, ''),
     r'nicht die Absätze der Vorlage Berufsschule'),
    ('SchuCu: KI-Hinweis geändert', lambda o: ersetze(o, SCHUCU, 'teilweise mit KI generiert', 'mit KI erstellt'),
     r'Absatz unter der Tabelle geändert'),
    # ---- SchuCu-Tabelle nach CD-Vorlage ----
    ('SchuCu: Titel leer', lambda o: ersetze(o, SCHUCU,
        '<td class="lsdata">Abteilungsnetze für die Muster GmbH — ein Firmennetz in VLANs trennen</td>',
        '<td class="lsdata">&nbsp;</td>'),
     r'SchuCu-Zeile leer: Titel'),
    ('SchuCu: Platzhalter stehen gelassen', lambda o: ersetze(o, SCHUCU,
        '<td class="lsdata">vom Nutzer zu ergänzen</td>', '<td class="lsdata">&lt;Name&gt;</td>'),
     r'Platzhalter der Vorlage: Autor'),
    ('SchuCu: Zeile entfernt', lambda o: ersetze(o, SCHUCU,
        '<td class="lshead" colspan="3">Lernumgebung</td>', '<td class="lshead" colspan="3">Raum</td>'),
     r'weicht von der Vorlage Berufsschule ab, Zeile 15'),
    ('SchuCu: Klasse getauscht', lambda o: ersetze(o, SCHUCU,
        '<td class="lssubhead">Titel:</td>', '<td class="table">Titel:</td>'),
     r'weicht von der Vorlage'),
    ('SchuCu: Kopflink geändert', lambda o: ersetze(o, SCHUCU, '201809_g-A_Lernsituationen_BBS.pdf', 'anderes.pdf'),
     r'Link "offizielle Erläuterungen" geändert'),
    ('SchuCu: Markdown in der Tabelle', lambda o: ersetze(o, SCHUCU,
        '<strong>Planen und Entscheiden</strong>', '**Planen und Entscheiden**'),
     r'Markdown in der SchuCu-Tabelle'),
    ('SchuCu: Zeitrichtwert fehlt', lambda o: ersetze(o, SCHUCU,
        '<td class="lsdata">4 UStd (180 min)</td>', '<td class="lsdata">ein Vormittag</td>'),
     r'Zeitrichtwert nicht lesbar'),
    ('BG: Bereich nicht in der Legende', lambda o: bg(o, ('>A B</td>', '>A E</td>')),
     r'Kompetenzbereich\(e\) E stehen nicht'),
    ('BG: Lehrplan-Link offen', lambda o: bg(o, ('href="https://bildungsportal', 'href="&lt;x&gt;')),
     r'Link zum Lehrplan'),
    ('BG: Legende fehlt', lambda o: bg(o, ('A: Kommunizieren', '&lt;y&gt; A: Kommunizieren')),
     r'Legende der Kompetenzbereiche'),
    ('BG: KI-Hinweis fehlt', lambda o: bg(o, (KI, '')),
     r'nicht die Absätze der Vorlage Berufliches Gymnasium'),
    ('BG: Vereinbarungen aus der BS-Vorlage', lambda o: bg(o, (
        '<td class="lshead" colspan="3">Abgedeckte Kompetenzbereiche</td>',
        '<td class="lshead" colspan="3">Vereinbarungen zur Umsetzung der Lernsituation</td>')),
     r'weicht von der Vorlage'),
    # ---- Jedes Blatt steht für sich ----
    ('Abschnitte beginnen nicht bei 1', lambda o: ersetze(o, IB1, '<h3>1. Was ein VLAN ist</h3>',
                                                          '<h3>5. Was ein VLAN ist</h3>'),
     r'\(ib-01-vlan-grundlagen\)\s+Abschnitte 5, 2, 3, 4'),
    ('Abbildung zählt über Blätter', lambda o: ersetze(o, IB1, '<em>Abb. 1: Zwei Switches', '<em>Abb. 2: Zwei Switches'),
     r'\(ib-01-vlan-grundlagen\)\s+Abbildungen Abb. 2 --'),
    ('Abbildung mit Präfix', lambda o: ersetze(o, AB1, '<em>Abb. 1: Das Netz vor', '<em>Abb. L1: Das Netz vor'),
     r'\(ab-01-auftrag\)\s+Abbildungen Abb. L1 --'),
    ('Abb. ohne Kennung', lambda o: ersetze(o, HILFE1, 'Kreist sie in Abb. 1 auf Arbeitsblatt 1 ein.',
                                            'Kreist sie in Abb. 1 ein.'),
     r'\(ab-01-auftrag-hilfe\)\s+"Abb. 1" ohne Blattkennung'),
    ('Abb. ohne Kennung (Handreichung)', lambda o: ersetze(o, HAND, 'Abb. 1 auf Arbeitsblatt 1 —', 'Abb. 1 —'),
     r'„Lehrerhandreichung" \(lehrerhandreichung\)\s+"Abb. 1" ohne Blattkennung'),
    ('Verweis auf fehlenden Abschnitt', lambda o: ersetze(o, AB1, LIES4, LIES4.replace('4.', '5.')),
     r'\(ab-01-auftrag\)\s+"Infoblatt 1, Abschnitt 5": dort gibt es keinen Abschnitt 5'),
    ('Verweis auf fehlende Abbildung', lambda o: ersetze(o, AB2, 'aus Abb. 1 auf Arbeitsblatt 1.',
                                                         'aus Abb. 2 auf Arbeitsblatt 1.'),
     r'dort gibt es keine Abb. 2'),
    ('Verweis auf fehlende Aufgabe', lambda o: ersetze(o, HAND, 'Aufgabe 4 auf Arbeitsblatt 2 (Prüfliste)',
                                                       'Aufgabe 5 auf Arbeitsblatt 2 (Prüfliste)'),
     r'\(lehrerhandreichung\)\s+"Aufgabe 5 auf Arbeitsblatt 2": dort gibt es keine Aufgabe 5'),
    ('Verweis auf fehlendes Blatt', lambda o: ersetze(o, AB1, LIES4,
                                                      '<strong>Lies:</strong> Infoblatt 2, Abschnitt 1.'),
     r'"Infoblatt 2, Abschnitt 1": dieses Blatt gibt es nicht'),
    ('Aufgaben beginnen nicht bei 1', lambda o: ersetze(o, VERT2, '<h3>Aufgabe 1 (15 min', '<h3>Aufgabe 2 (15 min'),
     r'\(ab-02-umsetzung-vertiefung\)\s+Aufgaben 2 --'),
    ('Lösung mit anderen Nummern', lambda o: ersetze(o, AB2L, '<h3>Aufgabe 4</h3>', '<h3>Aufgabe 5</h3>'),
     r'Lösung hat die Aufgaben 1, 2, 3, 5, das Blatt 1, 2, 3, 4'),
    ('"Gehört zu" unvollständig', lambda o: ersetze(o, IB1, ', Hilfe zu Arbeitsblatt 1, Arbeitsblatt 2 ·',
                                                    ', Arbeitsblatt 2 ·'),
     r'\(ib-01-vlan-grundlagen\)\s+"Gehört zu" nennt Hilfe zu Arbeitsblatt 1 nicht'),
    ('"→ für" fehlt', lambda o: ersetze(o, IB1, '<p>→ für Arbeitsblatt 1, Aufgabe 2</p>\n', ''),
     r'Abschnitt 4: "→ für Arbeitsblatt 1, Aufgabe 2" fehlt'),
    ('"→ für" fehlt, Zeile nennt auch Abb.', lambda o: (
        ersetze(o, AB1, LIES4, '<strong>Lies:</strong> Infoblatt 1, Abschnitt 4, und Abb. 1 auf Infoblatt 1.'),
        ersetze(o, IB1, '<p>→ für Arbeitsblatt 1, Aufgabe 2</p>\n', '')),
     r'Abschnitt 4: "→ für Arbeitsblatt 1, Aufgabe 2" fehlt'),
    ('"Lest"-Zeile ohne "→ für"', lambda o: ersetze(o, IB1, '→ für Arbeitsblatt 1, Aufgaben 1 und 3, und Hilfe',
                                                    '→ für Arbeitsblatt 1, Aufgabe 1, und Hilfe'),
     r'Abschnitt 3: "→ für Arbeitsblatt 1, Aufgabe 3" fehlt'),
    ('"→ für" ohne "Lies"-Zeile', lambda o: ersetze(o, IB1, '<p>→ für Arbeitsblatt 1, Aufgabe 1</p>',
                                                    '<p>→ für Arbeitsblatt 1, Aufgaben 1 und 4</p>'),
     r'Abschnitt 1: "→ für Arbeitsblatt 1, Aufgabe 4", aber dort'),
    # ---- Weitere Aktivitäten ----
    ('Pinnwand nicht im Ablaufplan', lambda o: (
        ersetze(o, HAND, 'Arbeitsblatt 1, „Unsere VLAN-Aufteilung"</td>', 'Arbeitsblatt 1</td>'),
        ersetze(o, HAND, '<tr><td>„Unsere VLAN-Aufteilung"</td>', '<tr><td>Unsere VLAN-Aufteilung</td>')),
     r'„Unsere VLAN-Aufteilung" \(pinnwand-aufteilung\)\s+steht weder im Ablaufplan'),
    ('Name in Anführungszeichen ohne Aktivität', lambda o: ersetze(o, HAND, REFLEXION,
                                                                   '<td>Plenum</td><td>„Unsere Pinnwand"</td>'),
     r'„Unsere Pinnwand" in Ablaufplan oder Materialübersicht ist keine Aktivität'),
    ('Weitere Aktivität mit Kennung', lambda o: setze(o, 'pinnwand-aufteilung', name='Arbeitsblatt 3: Pinnwand'),
     r'ist kein Blatt und trägt keine Kennung'),
    ('Board ohne Spalten', lambda o: schreib(o, 'pinnwand-aufteilung/board.json', '{"spalten": []}'),
     r'board.json braucht "spalten"'),
    ('Board ohne board.json', lambda o: os.remove(os.path.join(o, 'pinnwand-aufteilung', 'board.json')),
     r'board.json fehlt in pinnwand-aufteilung'),
    ('Kanban: Karte ohne Spalte', eine_weitere(0, dateien={'kanban.json':
        '{"spalten": ["Zu erledigen"], "karten": [{"spalte": "Später", "titel": "Ports"}]}'}),
     r'kanban.json: eine Karte nennt keine Spalte'),
    ('Fortschrittsliste springt', eine_weitere(1, dateien={'eintraege.json': '[{"text": "A"}, {"text": "B", "tiefe": 2}]'}),
     r'„B" springt in der Einrückung'),
    ('Fortschrittsliste: Zustand', eine_weitere(1, dateien={'eintraege.json': '[{"text": "A", "zustand": "kür"}]'}),
     r'"zustand" .kür.'),
    ('Wiki: Startseite heißt anders', eine_weitere(2, extra={'einstellungen': {'firstpagetitle': 'Start'}}),
     r'die erste Seite „Begriffe" ist die Startseite'),
    ('Wiki: Seite fehlt', eine_weitere(2, dateien={'seiten.json': '[{"titel": "Begriffe", "datei": "fehlt.html"}]'}),
     r'Seite 1 braucht "titel" und eine "datei"'),
    ('Test ohne Sachnummer', eine_weitere(3, dateien={'fragen.xml':
        '<quiz><question type="truefalse"><name><text>Tag</text></name></question></quiz>'}),
     r'Frage „Tag" ohne Sachnummer'),
    ('Test ohne Ort der Fragen', eine_weitere(3, extra={'fragen': {}}), r'Test ohne Ort für seine Fragen'),
    ('Test: kaputtes XML', eine_weitere(3, dateien={'fragen.xml': '<quiz><question>'}), r'fragen.xml ist kein gültiges XML'),
    ('Verzeichnis leer', lambda o: (eine_weitere(4)(o), os.remove(os.path.join(o, 'material', 'bereiche', 'files', 'plan.ods'))),
     r'Verzeichnis ohne Dateien'),
    ('Datei: zwei Dateien', eine_weitere(5, dateien={'bereiche/files/zweite.pkt': 'y'}), r'genau eine Datei .*gefunden: 2'),
    ('Link ohne https', eine_weitere(6, extra={'einstellungen': {'externalurl': 'http://example.org'}}),
     r'Link ohne Adresse'),
]


def mit_situation(ordner):
    """Die Handlungssituation als Textfeld hinter der Handreichung, im
    Ablaufplan als Material genannt."""
    schreib(ordner, 'handlungssituation/introeditor.html', '<p>Die Muster GmbH zieht um.</p>\n')
    dazu(ordner, {'ordner': 'handlungssituation', 'typ': 'label', 'name': 'Handlungssituation'},
         nach='lehrerhandreichung')
    ersetze(ordner, HAND, '<td>Plenum</td><td>Arbeitsblatt 1</td>', '<td>Plenum</td><td>Handlungssituation, Arbeitsblatt 1</td>')


def mit_download(ordner):
    """Eine Datei zum Herunterladen: Ihr Name darf im Text stehen."""
    schreib(ordner, 'ab-02-umsetzung/dateien/netz-vorher.pkt', 'x')
    ersetze(ordner, AB2, 'die Datei <code>netz-vorher.pkt</code>.',
            'die Datei <a href="@@PLUGINFILE@@/netz-vorher.pkt">netz-vorher.pkt</a>.')


# Muss ohne Befund durchgehen: dieselbe Lernsituation in zulässigen Varianten.
GUTE = [
    ('BG-Vorlage ausgefüllt', lambda o: bg(o), r'Vorlage Berufliches Gymnasium'),
    ('"Lies"-Zeile in der Sie-Form', lambda o: ersetze(o, AB1, LIES4, LIES4.replace('Lies:', 'Lesen Sie:')), r'OK --'),
    ('Verweis über einen Zeilenumbruch', lambda o: ersetze(o, HILFE1, 'Kreist sie in Abb. 1 auf Arbeitsblatt 1 ein.',
                                                           'Kreist sie in Abb. 1 auf\nArbeitsblatt 1 ein.'), r'OK --'),
    ('Handlungssituation als Textfeld', mit_situation, r'OK -- 13 Aktivitäten, 13 davon'),
    ('"Lies"-Zeile mit Lehrbuch', lambda o: ersetze(o, AB1, LIES4, '<strong>Lies:</strong> Infoblatt 1, Abschnitt 4, '
                                                    'und im Lehrbuch der Klasse das Kapitel „Netzsicherheit".'), r'OK --'),
    ('Rahmenlinie ohne Farbe', lambda o: ersetze(o, AB1L, '<tr><td>Trunk</td>',
                                                 '<tr><td style="border-top: 2px solid">Trunk</td>'), r'OK --'),
    ('Arbeitsblatt als Aufgabe', lambda o: als_aufgabe(o, 'ab-02-umsetzung'), r'OK --'),
    ('Handreichung als Buch', als_buch, r'OK --'),
    ('Datei zum Herunterladen', mit_download, r'OK --'),
    ('Unterabschnitt', lambda o: dazu(o, {'typ': 'subsection', 'name': 'Durchführen'}, nach='ab-01-auftrag-hilfe-loesung'),
     r'OK --'),
    ('alle weiteren Aktivitäten', lambda o: weitere(o, ALLE_WEITEREN), r'OK -- 19 Aktivitäten, 19 davon'),
]

# ---- Der Stand in Moodle ---------------------------------------------------
# Das Beispiel, übertragen, wie der Skill moodle es tut -- ohne Moodle: jede
# Aktivität mit dem Inhalt ihres Ordners, die Nennungen der Blätter als Links,
# abgelegt so, wie die App liest (kurs-<kurs>.json, cm-<cmid>/ mit
# uebersicht.json samt Verweisen, ein Buch als buch-<cmid>/). Das muss ohne
# Befund durchgehen; dann wird es beschädigt.


def _lade_skript():
    spec = importlib.util.spec_from_file_location('pruefe_lernsituation', SKRIPT)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


LS = _lade_skript()
KURS, ABSCHNITT, HOST = 99, 500, 'https://moodle.schule.example'
ORDNER = [e['ordner'] for e in json.load(io.open(os.path.join(BEISPIEL, MANIFEST), encoding='utf-8'))['aktivitaeten']]


def cm_von(ordner):
    return 1000 + ORDNER.index(ordner)


def _url(cmid, typ='page'):
    return '%s/mod/%s/view.php?id=%d' % (HOST, typ, cmid)


def verlinke(h, eigen, namen, kennungen, weitere=None):
    """Jede Nennung eines anderen Blatts wird ein Link, wie der Skill moodle es
    nach dem Anlegen tut: in der Materialübersicht mit dem ganzen Namen, sonst
    mit der Kennung; eine weitere Aktivität mit ihrem Namen in
    Anführungszeichen. `namen`/`kennungen`/`weitere` zeigen auf (cmid, typ).
    Gibt HTML und [(cmid, Linktext)]."""
    links, weitere = [], weitere or {}
    for name, (cmid, typ) in sorted(namen.items(), key=lambda x: -len(x[0])):
        e = html.escape(name, quote=False)
        if '<td>%s</td>' % e in h:
            h = h.replace('<td>%s</td>' % e, '<td><a href="%s">%s</a></td>' % (_url(cmid, typ), e))
            links.append((cmid, name))

    def zitat(m):
        cmid, typ = weitere[m.group(2)]
        links.append((cmid, m.group(2)))
        return '%s<a href="%s">%s</a>%s' % (m.group(1), _url(cmid, typ), m.group(2), m.group(3))

    def kennung(m):
        s = LS.schluessel(m.group(0))
        if s == eigen or s not in kennungen:
            return m.group(0)
        links.append((kennungen[s][0], LS.norm(m.group(0))))
        return '<a href="%s">%s</a>' % (_url(*kennungen[s]), m.group(0))

    zitiert = re.compile(r'([„“"])(%s)([“”"])' % '|'.join(re.escape(n) for n in sorted(weitere, key=len, reverse=True))) \
        if weitere else None
    raus, in_a = [], 0
    for t in re.split(r'(<[^>]+>)', h):
        if t.startswith('<'):
            in_a += 1 if re.match(r'<a\b', t) else -1 if t.startswith('</a') else 0
        elif not in_a:
            # Erst die Namen in Anführungszeichen, dann die Kennungen -- nur
            # ausserhalb der eben gesetzten Links.
            teile = re.split(r'(<a\b[^>]*>.*?</a>)', zitiert.sub(zitat, t) if zitiert else t)
            t = ''.join(x if x.startswith('<a') else re.sub(LS.ZIEL, kennung, x) for x in teile)
        raus.append(t)
    return ''.join(raus), links


def nach_moodle(entwurf, ao):
    """Überträgt den Entwurf in einen Arbeitsordner, wie ihn die App nach
    kurs_uebersicht, aktivitaet_lesen und buch_lesen hinterlässt."""
    os.makedirs(ao, exist_ok=True)
    eintraege = [e for e in json.load(io.open(os.path.join(entwurf, MANIFEST), encoding='utf-8'))['aktivitaeten']
                 if e.get('ordner')]
    seiten = [(cm_von(e['ordner']), e) for e in eintraege]
    namen = {e['name']: (cmid, e['typ']) for cmid, e in seiten if e['typ'] not in LS.WEITERE}
    weitere = {e['name']: (cmid, e['typ']) for cmid, e in seiten if e['typ'] in LS.WEITERE}
    kennungen = {LS.schluessel(m.group(0)): (cmid, e['typ']) for cmid, e in seiten
                 for m in [re.match(LS.ZIEL, e['name'])] if m}
    ziele = {cmid: e['name'] for cmid, e in seiten}

    def verlinkt(o, feld, e):
        """Setzt die Links in einem Feld und legt uebersicht.json daneben."""
        p = os.path.join(o, feld + '.html')
        h, links = io.open(p, encoding='utf-8').read(), []
        if e['name'] != 'SchuCu':
            m = re.match(LS.ZIEL, e['name'])
            h, links = verlinke(h, LS.schluessel(m.group(0)) if m else None, namen, kennungen, weitere)
        io.open(p, 'w', encoding='utf-8', newline='').write(h)
        json.dump({'name': e['name'], 'auswertung': {'felder': [{'feld': feld, 'verweise': [
            {'art': 'aktivitaet', 'cmid': c, 'text': text, 'zielTitel': ziele[c]} for c, text in links]}]}},
            io.open(os.path.join(o, 'uebersicht.json'), 'w', encoding='utf-8'), ensure_ascii=False)

    cms = []
    for cmid, e in seiten:
        quelle = os.path.join(entwurf, e['ordner'])
        if e['typ'] in LS.WEITERE:
            # Ihr Inhalt steht nicht im Formular; kurs_uebersicht nennt sie.
            pass
        elif e['typ'] == 'book':
            o = os.path.join(ao, 'buch-%d' % cmid)
            shutil.copytree(quelle, o)
            for k in json.load(io.open(os.path.join(o, 'kapitel.json'), encoding='utf-8')):
                verlinkt(os.path.join(o, 'kapitel-%d' % k['id']), 'content_editor', e)
        else:
            o = os.path.join(ao, 'cm-%d' % cmid)
            shutil.copytree(quelle, o)
            verlinkt(o, LS.INHALT[e['typ']][0], e)
        cms.append({'id': cmid, 'name': e['name'], 'module': e['typ'], 'visible': 0})
    json.dump({'section': [{'id': ABSCHNITT, 'title': 'ZZ Abteilungsnetze', 'cmlist': [c['id'] for c in cms]}],
               'cm': cms}, io.open(os.path.join(ao, 'kurs-%d.json' % KURS), 'w', encoding='utf-8'),
              ensure_ascii=False)


def lauf_moodle(ao):
    r = subprocess.run([sys.executable, '-B', SKRIPT, '--moodle', ao, str(ABSCHNITT)], capture_output=True,
                       text=True, encoding='utf-8', errors='replace')
    return r.returncode, r.stdout + r.stderr


def seite_aendern(ao, ordner, alt, neu):
    ersetze(os.path.join(ao, 'cm-%d' % cm_von(ordner)), 'page.html', alt, neu)


def json_aendern(ao, datei, f):
    p = os.path.join(ao, datei)
    j = json.load(io.open(p, encoding='utf-8'))
    f(j)
    json.dump(j, io.open(p, 'w', encoding='utf-8'), ensure_ascii=False)


def _cm(ao, ordner, **werte):
    def f(j):
        for c in j['cm']:
            if c['id'] == cm_von(ordner):
                c.update(werte)
    json_aendern(ao, 'kurs-%d.json' % KURS, f)


def _loesung_sichtbar_verlinkt(ao):
    loes = cm_von('ab-01-auftrag-loesung')
    seite_aendern(ao, 'ab-01-auftrag', '</h3>', '</h3>\n<p><a href="%s">Lösung zu Arbeitsblatt 1</a></p>' % _url(loes))
    _cm(ao, 'ab-01-auftrag', visible=1)

    def verweis(j):
        j['auswertung']['felder'][0]['verweise'].append(
            {'art': 'aktivitaet', 'cmid': loes, 'text': 'Lösung zu Arbeitsblatt 1', 'zielTitel': '?'})
    json_aendern(ao, 'cm-%d/uebersicht.json' % cm_von('ab-01-auftrag'), verweis)


def _link_hinaus(ao):
    def f(j):
        j['auswertung']['felder'][0]['verweise'][0]['cmid'] = 777
    json_aendern(ao, 'cm-%d/uebersicht.json' % cm_von('ab-02-umsetzung'), f)


IB1_LINK = '<a href="%s">Infoblatt 1</a>' % _url(cm_von('ib-01-vlan-grundlagen'))
# (Name, Änderung am Entwurf vor der Übertragung, Änderung danach, Rückgabe, Muster)
FAELLE_MOODLE = [
    ('Moodle: Beispiel übertragen', None, None, 0, r'OK --'),
    ('Moodle: Handreichung als Buch', als_buch, None, 0, r'OK --'),
    ('Moodle: Nennung ohne Link', None, lambda o: seite_aendern(o, 'ab-01-auftrag', IB1_LINK, 'Infoblatt 1'), 1,
     r'nennt "Infoblatt 1" ohne Link'),
    ('Moodle: Blatt umbenannt', None, lambda o: _cm(o, 'ib-01-vlan-grundlagen', name='Infoblatt 1: VLAN-Basics'), 1,
     r'"Infoblatt 1: VLAN-Grundlagen" ist nicht der Name(.|\n)*Der Text passt nicht zum Namen'),
    ('Moodle: sichtbar verlinkt Lösung', None, _loesung_sichtbar_verlinkt, 1,
     r'für Lernende erreichbar und verlinkt die Lösung „Lösung zu Arbeitsblatt 1'),
    ('Moodle: Link aus dem Abschnitt', None, _link_hinaus, 1, r'ausserhalb dieses Abschnitts'),
    ('Moodle: Aufgabe ohne AFB', None, lambda o: seite_aendern(o, 'ab-01-auftrag', '(10 min · Einzel · AFB II)',
                                                               '(10 min · Einzel)'), 1, r'Aufgabe 2: Klammer'),
    ('Moodle: Pinnwand ohne Link', None, lambda o: seite_aendern(
        o, 'ab-01-auftrag', '<a href="%s">%s</a>' % (_url(cm_von('pinnwand-aufteilung'), 'board'), PINNWAND), PINNWAND),
     1, r'nennt „Unsere VLAN-Aufteilung" ohne Link'),
    ('Moodle: nicht gelesen', None, lambda o: shutil.rmtree(os.path.join(o, 'cm-%d' % cm_von('ab-02-umsetzung'))),
     2, r'Erst lesen, dann prüfen'),
]


def main():
    fehler = 0
    rc, out = lauf(BEISPIEL)
    if rc != 0:
        print('FEHLER: das Beispiel selbst hat Befunde:\n' + out)
        return 1
    print('Beispiel ohne Befund: OK')

    def am_entwurf(name, aendern, rc_soll, erwartet):
        tmp = tempfile.mkdtemp(prefix='ls-')
        ziel = os.path.join(tmp, 'entwurf')
        shutil.copytree(BEISPIEL, ziel)
        try:
            aendern(ziel)
            rc, out = lauf(ziel)
            if rc == rc_soll and re.search(erwartet, out):
                print('  %-38s %s' % (name, 'erkannt' if rc else 'ohne Befund'))
                return 0
            print('  %-38s FEHLER (rc=%d)\n%s' % (name, rc, out))
            return 1
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    for name, kaputt, erwartet in FAELLE:
        fehler += am_entwurf(name, kaputt, 1, erwartet)
    for name, bau, erwartet in GUTE:
        fehler += am_entwurf(name, bau, 0, erwartet)

    # Der Stand in Moodle: das übertragene Beispiel ohne Befund, dann beschädigt.
    for name, vorher, kaputt, rc_soll, erwartet in FAELLE_MOODLE:
        tmp = tempfile.mkdtemp(prefix='ls-')
        entwurf, ao = os.path.join(tmp, 'entwurf'), os.path.join(tmp, 'arbeitsordner')
        shutil.copytree(BEISPIEL, entwurf)
        try:
            if vorher:
                vorher(entwurf)
            nach_moodle(entwurf, ao)
            if kaputt:
                kaputt(ao)
            rc, out = lauf_moodle(ao)
            if rc == rc_soll and re.search(erwartet, out):
                print('  %-38s %s' % (name, 'erkannt' if rc else 'ohne Befund'))
            else:
                print('  %-38s FEHLER (rc=%d)\n%s' % (name, rc, out))
                fehler += 1
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    print('OK -- das Prüfskript findet, was es finden soll.' if not fehler
          else 'NICHT OK: %d Fall/Fälle nicht erkannt' % fehler)
    return 1 if fehler else 0


if __name__ == '__main__':
    sys.exit(main())
