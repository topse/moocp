#!/usr/bin/env bash
# Die App nach einer Änderung sauber neu starten: Skills bauen, prüfen,
# beenden, bauen, starten. Bricht ab, wenn der Bau der Skills, die Analyse
# oder die Tests nicht sauber sind (A10).
#
#   bash tool/neustart.sh
#
# Testbetrieb (docs/agents/testing.md): Sind MOOCP_TESTZUGANG_PROFILE oder die
# MOOCP_TESTZUGANG*-Variablen gesetzt, baut tool/mac_bau.sh den Mac-Bau (unter Linux
# tool/linux_bau.sh den Linux-Bau) mit
# --dart-define=MOOCP_TESTBETRIEB=true. Der Windows-Bau unten ist ein
# Release-Bau und hat den Testbetrieb nie.
#
# Mit gespeicherten Anmeldedaten meldet sich die App selbst an und startet
# danach den MCP-Server; der Eintrag „MCP-Server läuft auf …" steht dann in
# %APPDATA%\moocp\protokoll.log (Mac: ~/Library/Application Support/moocp, Linux:
# ~/.config/moocp).
set -e
cd "$(dirname "$0")/.."
if [ "$(uname)" = Darwin ]; then
  # Mac: Entwicklungsbau (Debug) in tool/mac_bau.sh, Start in tool/mac_start.sh.
  # Kein Installer und keine Release-Fassung (E24).
  PY=python3
  # Die Skills zuerst: Die App bringt skills/dist/ als Assets mit.
  "$PY" skills/build.py
  flutter analyze
  flutter test
  pkill -x moocp >/dev/null 2>&1 || true
  sleep 2
  bash tool/mac_bau.sh
  bash tool/mac_start.sh
  exit 0
fi
if [ "$(uname)" = Linux ]; then
  # Linux: Entwicklungsbau (Debug) in tool/linux_bau.sh, Start in tool/linux_start.sh.
  # Kein Installer und keine Release-Fassung (E24).
  flutter analyze
  flutter test
  bash tool/linux_bau.sh
  bash tool/linux_start.sh
  exit 0
fi
# Die Skills zuerst: Die App bringt skills/dist/ als Assets mit und bietet
# beim Start an, genau diese Version zu installieren.
python skills/build.py
if [ -n "${MOOCP_TESTZUGANG_PROFILE:-}${MOOCP_TESTZUGANG:-}${MOOCP_TESTZUGANG_ADRESSE:-}" ]; then
  echo 'Hinweis: Der Release-Bau hat keinen Testbetrieb; die Variablen MOOCP_TESTZUGANG* bleiben wirkungslos.'
fi
flutter analyze
flutter test
# Erst regulär schließen: Dann leert die App ihren Arbeitsordner selbst.
# Hängt sie, hart -- den Rest leert der nächste Start.
taskkill //IM moocp.exe >/dev/null 2>&1 || true
sleep 2
taskkill //IM moocp.exe //F >/dev/null 2>&1 || true
sleep 1
flutter build windows --release
# Release, nicht Debug: Ausprobiert wird, was die Lehrkräfte bekommen --
# dieselbe Protokollierung (E11), dieselbe Laufzeit, dasselbe Zeitverhalten
# beim Beenden. Dass diese Version nicht im Installationsverzeichnis liegt,
# schaltet die Update-Prüfung schon von selbst ab (lib/update/update.dart);
# --kein-update sagt es noch einmal ausdrücklich.
(cd build/windows/x64/runner/Release && cmd //c start "" moocp.exe --kein-update)
