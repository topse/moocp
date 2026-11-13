#!/usr/bin/env bash
# Baut die App für Linux nach build/linux/x64/<debug|release>/bundle/.
#
#   bash tool/linux_bau.sh            Entwicklungsbau (Debug)
#   bash tool/linux_bau.sh release    Bau ohne Debugmodus
#
# Ist eine der Variablen MOOCP_TESTZUGANG_PROFILE, MOOCP_TESTZUGANG oder
# MOOCP_TESTZUGANG_ADRESSE gesetzt, entsteht ein Debug-Bau mit Testbetrieb
# (--dart-define=MOOCP_TESTBETRIEB=true, lib/testschalter.dart); neben dem Bau
# liegt dann die Marke „testbetrieb". Ohne die Variablen entsteht ein Bau ohne
# Testbetrieb, und die Marke fehlt. Ein Release-Bau hat den Testbetrieb nie.
# Die Skills werden zuerst gebaut: Die App bringt skills/dist/ als Assets mit.
set -euo pipefail
MODUS="${1:-debug}"
case "$MODUS" in
  debug | release) ;;
  *) echo "Unbekannter Modus: $MODUS (debug oder release)" >&2; exit 2 ;;
esac
cd "$(dirname "$0")/.."
TESTBETRIEB=nein
DEFINES=()
if [[ "$MODUS" == debug && -n "${MOOCP_TESTZUGANG_PROFILE:-}${MOOCP_TESTZUGANG:-}${MOOCP_TESTZUGANG_ADRESSE:-}" ]]; then
  TESTBETRIEB=ja
  DEFINES=(--dart-define=MOOCP_TESTBETRIEB=true)
fi
python3 skills/build.py
flutter build linux --"$MODUS" ${DEFINES[@]+"${DEFINES[@]}"}
BUNDLE="build/linux/x64/$MODUS/bundle"
if [[ "$TESTBETRIEB" == ja ]]; then
  : > "$BUNDLE/testbetrieb"
  echo 'Bau mit Testbetrieb (MOOCP_TESTBETRIEB)'
else
  rm -f "$BUNDLE/testbetrieb"
fi
echo BAU-OK
