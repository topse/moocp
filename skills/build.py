#!/usr/bin/env python3
"""Baut die Skills aus einer Quelle.

    python skills/build.py          bauen und prüfen, Pakete nach skills/dist/

Installiert werden die Pakete von der App: Sie bringt skills/dist/ als Assets
mit, vergleicht beim Start mit ~/.claude/skills/ und bietet die Installation an
(lib/einrichtung.dart); welche der wählbaren Skills dazugehören, entscheidet
die Lehrkraft dort. So gehören App und Skills immer zur selben Version.
skills/dist/ ist Bauergebnis und nicht versioniert.

Ablauf je Skill:
  1. Gleichanteile aus gemeinsam/ in die Marker der Skill-Quellen schreiben
  2. SKILL.md auf LF normalisieren -- gemischte Zeilenenden haben schon
     einmal eine description verschluckt
  3. Paket schnüren (dist/<name>.skill)
  4. Das Ergebnis AUS DEM FERTIGEN PAKET zurückprüfen: Ein Paket gilt erst als
     fertig, wenn SKILL.md aus dem ZIP gelesen und das Frontmatter geparst
     werden konnte -- ein früheres Paket war erzeugt, aber die Beschreibung
     darin nicht lesbar, und das fiel erst nach der Installation auf.
Zum Schluss wird geprüft, dass die Gleichanteile in allen Skills wirklich
gleich sind. Sie sind es per Konstruktion, aber genau das ist schon einmal
auseinandergedriftet, als sie von Hand gepflegt wurden.

Warum Gleichanteile doppelt im Paket stehen: Ein installierter Skill muss
selbstständig sein -- eigener Ordner, einzeln installierbar; ein Verweis auf
einen gemeinsamen Ordner griffe zur Laufzeit ins Leere. Gepflegt wird trotzdem
nur eine Stelle: gemeinsam/. Alles zwischen den Markern
    <!-- <<< gemeinsam/… -->  …  <!-- >>> gemeinsam/… -->
ist erzeugt und geht beim nächsten Bau verloren.
"""
import io
import os
import re
import sys
import zipfile

HIER = os.path.dirname(os.path.abspath(__file__))
PROJEKT = os.path.dirname(HIER)
GEMEINSAM = os.path.join(HIER, 'gemeinsam')
DIST = os.path.join(HIER, 'dist')

# Welcher Skill trägt welche Blöcke. Ein Block mit Platzhalter je Medium
# (@@QUELLENBEISPIELE@@) wird aus einer Datei gefüllt, statt ihn abzuschreiben.
SKILLS = [
    {
        'name': 'moodle',
        'bloecke': ['kurshinweise.md', 'konventionen-vorschlagen.md', 'aktueller-kurs.md', 'erfundene-namen.md', 'plan.md', 'ueberarbeiten.md',
                    'luecken.md', 'protokoll.md', 'bildschirmfoto.md', 'urheberrecht-kurz.md', 'urheberrecht.md',
                    'datenschutzbefund.md', 'skillfehler.md', 'html-kurz.md', 'html.md', 'zeichnungen.md', 'bruecke.md'],
        'ersetzungen': {'@@NAME@@': 'moodle',
                        '@@QUELLENBEISPIELE@@': ('datei', 'urheberrecht-beispiele-html.md')},
    },
    {
        'name': 'moodle-fragen',
        # Fragen werden nicht gedruckt; die Brücke betrifft Kurs und Blätter.
        'bloecke': ['kurshinweise.md', 'konventionen-vorschlagen.md', 'aktueller-kurs.md', 'erfundene-namen.md', 'plan.md', 'ueberarbeiten.md',
                    'luecken.md', 'protokoll.md', 'bildschirmfoto.md', 'urheberrecht-kurz.md', 'urheberrecht.md',
                    'datenschutzbefund.md', 'skillfehler.md', 'html-kurz.md', 'html.md', 'zeichnungen.md'],
        'ersetzungen': {'@@NAME@@': 'moodle-fragen',
                        '@@QUELLENBEISPIELE@@': ('datei', 'urheberrecht-beispiele-html.md')},
    },
    {
        # Entwirft ohne Moodle: Lernsituationen als Entwurf im Arbeitsordner,
        # schon in HTML und in der Form der Werkzeuge, den der Skill moodle
        # gleich danach in den Kurs bringt. Von den Gleichanteilen braucht er
        # nur, was nichts mit dem Bedienen von Moodle zu tun hat -- dazu das
        # HTML, weil er es selbst schreibt, das Überarbeiten, weil „Das Neue
        # steht allein" schon für seinen Entwurf gilt, und die Lücken, damit
        # auch hier eine fehlende Funktion als Befund zum Nachrüsten ankommt.
        # Wählbar (lib/einrichtung.dart): gebaut für berufsbildende Schulen.
        'name': 'lernsituation',
        'bloecke': ['bruecke.md', 'konventionen-vorschlagen.md', 'erfundene-namen.md', 'plan.md', 'ueberarbeiten.md', 'html-kurz.md', 'html.md',
                    'zeichnungen.md', 'urheberrecht-kurz.md', 'urheberrecht.md', 'luecken.md', 'skillfehler.md'],
        'ersetzungen': {'@@NAME@@': 'lernsituation',
                        '@@QUELLENBEISPIELE@@': ('datei', 'urheberrecht-beispiele-lernsituation.md')},
    },
]

MARKER_AUF = re.compile(r'<!-- <<< gemeinsam/(\S+) - von build.py erzeugt')


def lies(pfad):
    return io.open(pfad, encoding='utf-8', newline='').read().replace('\r\n', '\n')


def schreib(pfad, text):
    io.open(pfad, 'w', encoding='utf-8', newline='').write(text)


def ersetzungen_von(s):
    raus = {}
    for k, v in s['ersetzungen'].items():
        if isinstance(v, tuple) and v[0] == 'datei':
            v = lies(os.path.join(GEMEINSAM, v[1])).rstrip('\n')
        raus[k] = v
    return raus


def marker(name):
    return ('<!-- <<< gemeinsam/%s - von build.py erzeugt, hier nicht bearbeiten -->' % name,
            '<!-- >>> gemeinsam/%s -->' % name)


def kopf_weg(text):
    """Führenden Dateikommentar /* … */ der gemeinsamen Quelle entfernen."""
    m = re.match(r'\s*/\*.*?\*/\s*\n', text, re.S)
    return text[m.end():] if m else text


def soll_inhalt(block, s):
    t = kopf_weg(block)
    for k, v in ersetzungen_von(s).items():
        t = t.replace(k, v)
    return t.rstrip('\n')


def fuelle(pfad, name, inhalt):
    """Ersetzt den Inhalt zwischen den Markern. True, wenn getroffen."""
    t = lies(pfad)
    auf, zu = marker(name)
    m = re.search(re.escape(auf) + r'\n.*?' + re.escape(zu), t, re.S)
    if not m:
        return False
    t = t[:m.start()] + auf + '\n' + inhalt + '\n' + zu + t[m.end():]
    schreib(pfad, t)
    return True


def md_dateien(wurzel):
    return [os.path.join(w, d) for w, _, ds in os.walk(wurzel) for d in ds if d.endswith('.md')]


def dateien(wurzel, paketname):
    raus = []
    for w, verz, namen in os.walk(wurzel):
        verz[:] = [d for d in verz if not d.startswith('.') and d != '__pycache__']
        for n in sorted(namen):
            # CLAUDE.md sind Entwicklungsnotizen zum Skill, nicht sein Inhalt.
            if n.startswith('.') or n == 'CLAUDE.md':
                continue
            voll = os.path.join(w, n)
            raus.append((voll, paketname + '/' + os.path.relpath(voll, wurzel).replace(os.sep, '/')))
    return sorted(raus, key=lambda x: x[1])


def lf(pfad):
    roh = io.open(pfad, 'rb').read()
    if roh.startswith(b'\xef\xbb\xbf'):
        roh = roh[3:]
    io.open(pfad, 'wb').write(roh.replace(b'\r\n', b'\n'))


def pruefe_frontmatter(text, name):
    m, ok = [], True
    tr = re.match(r'^---\r?\n(.*?)\r?\n---\r?\n', text, re.S)
    if not tr:
        return False, ['FEHLER: Frontmatter nicht abgrenzbar']
    feld = {}
    for z in tr.group(1).split('\n'):
        t = re.match(r'^([a-zA-Z_]+):\s*(.*)$', z.rstrip('\r'))
        if t:
            feld[t.group(1)] = t.group(2)
    if feld.get('name') != name:
        m.append('FEHLER: name ist %r, erwartet %r' % (feld.get('name'), name))
        ok = False
    d = (feld.get('description') or '').strip()
    # Anführungszeichen sind Pflicht: Ein Doppelpunkt mit Leerzeichen beendet
    # in YAML einen ungequoteten Wert, und die Beschreibung war schon einmal weg.
    # Umlaute sind erlaubt und erwünscht. Höchstens 1024 Zeichen -- so viel
    # nimmt Claude beim Hochladen an (gemessen am 18.09.2026).
    if not (d.startswith('"') and d.endswith('"')):
        m.append('FEHLER: description fehlt oder steht nicht in Anführungszeichen')
        ok = False
    elif len(d.strip('"')) > 1024:
        m.append('FEHLER: description hat %d Zeichen, erlaubt sind 1024' % len(d.strip('"')))
        ok = False
    else:
        m.append('description: %d Zeichen' % len(d.strip('"')))
    return ok, m


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    bloecke = {n: lies(os.path.join(GEMEINSAM, n)) for s in SKILLS for n in s['bloecke']}
    os.makedirs(DIST, exist_ok=True)
    fehler = 0
    for s in SKILLS:
        quelle = os.path.join(HIER, s['name'])
        print('\n=== %s ===' % s['name'])
        for n in s['bloecke']:
            treffer = [os.path.relpath(d, quelle) for d in md_dateien(quelle)
                       if fuelle(d, n, soll_inhalt(bloecke[n], s))]
            if not treffer:
                print('  FEHLER: kein Marker für gemeinsam/%s' % n)
                fehler += 1
            else:
                print('  eingesetzt: %s -> %s' % (n, ', '.join(treffer)))
        rest = [os.path.relpath(d, quelle) for d in md_dateien(quelle)
                if any(m not in s['bloecke'] for m in MARKER_AUF.findall(lies(d)))]
        if rest:
            print('  FEHLER: Marker ohne Block in %s' % ', '.join(rest))
            fehler += 1
        lf(os.path.join(quelle, 'SKILL.md'))
        paket = os.path.join(DIST, s['name'] + '.skill')
        liste = dateien(quelle, s['name'])
        with zipfile.ZipFile(paket, 'w', zipfile.ZIP_DEFLATED) as z:
            for voll, drin in liste:
                z.write(voll, drin)
        print('  Paket: %s (%d Bytes, %d Dateien)' % (os.path.relpath(paket, PROJEKT), os.path.getsize(paket), len(liste)))
        with zipfile.ZipFile(paket) as z:
            roh = z.read(s['name'] + '/SKILL.md')
        ok, meldungen = pruefe_frontmatter(roh.decode('utf-8'), s['name'])
        for m in meldungen:
            print('  ' + m)
        if not roh.startswith(b'---\n') or b'\r' in roh:
            print('  FEHLER: SKILL.md nicht LF oder mit BOM')
            ok = False
        if not ok:
            fehler += 1

    print('\n=== Gleichanteile ===')
    for n in sorted(bloecke):
        for s in [x for x in SKILLS if n in x['bloecke']]:
            soll = soll_inhalt(bloecke[n], s)
            auf, zu = marker(n)
            gefunden = False
            for d in md_dateien(os.path.join(HIER, s['name'])):
                m = re.search(re.escape(auf) + r'\n(.*?)\n' + re.escape(zu), lies(d), re.S)
                if m:
                    gefunden = True
                    if m.group(1) != soll:
                        print('  ABWEICHUNG: %s in %s' % (n, os.path.relpath(d, HIER)))
                        fehler += 1
            if not gefunden:
                fehler += 1
        print('  %-24s in %d Skill(s)' % (n, len([x for x in SKILLS if n in x['bloecke']])))

    print('\n' + ('OK -- %d Pakete gebaut und geprüft.' % len(SKILLS)
                  if fehler == 0 else 'NICHT OK: %d Problem(e)' % fehler))
    return 0 if fehler == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
