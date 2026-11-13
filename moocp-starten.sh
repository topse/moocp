#!/usr/bin/env bash
# moocp unter Linux starten – im Terminal:
#
#   bash moocp-starten.sh
#
# Gibt es noch keinen Bau oder ist der Quelltext neuer als der Bau, wird
# zuerst gebaut (dauert einige Minuten). Sonst startet sofort die vorhandene
# App. Läuft die App schon, kommt sie nur in den Vordergrund (zweiter Start,
# lib/einzelstart.dart). Nötig ist eine grafische Sitzung.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
# Dieses Skript baut und startet nie einen Bau mit Testbetrieb (lib/testschalter.dart):
# tool/linux_bau.sh schaltet ihn bei gesetzten Testzugangs-Variablen ein, hier sind
# sie also tabu.
unset MOOCP_TESTZUGANG_PROFILE MOOCP_TESTZUGANG MOOCP_TESTZUGANG_ADRESSE
BUNDLE="build/linux/x64/release/bundle"

veraltet() {
  [ ! -x "$BUNDLE/moocp" ] && return 0
  [ -n "$(find lib skills pubspec.yaml linux -type f \
    -newer "$BUNDLE/moocp" -not -path '*/dist/*' -not -path '*/ephemeral/*' -print -quit 2>/dev/null)" ]
}

if veraltet; then
  echo "Die App wird gebaut (einige Minuten) ..."
  bash tool/linux_bau.sh release
fi
nohup "$BUNDLE/moocp" >/dev/null 2>&1 &
echo "moocp ist gestartet. Dieses Terminal darf geschlossen werden."
