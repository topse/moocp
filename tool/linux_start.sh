#!/usr/bin/env bash
# Startet die gebaute App (Debug-Bau aus tool/linux_bau.sh) neu und wartet auf
# alle gebundenen Testprofile, wie tool/mac_start.sh auf dem Mac. Nötig ist eine
# grafische Sitzung (DISPLAY oder WAYLAND_DISPLAY).
REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="$REPO/build/linux/x64/debug/bundle"
L="${XDG_CONFIG_HOME:-$HOME/.config}/moocp/protokoll.log"
testbetrieb=nein
for name in MOOCP_TESTZUGANG_PROFILE MOOCP_TESTZUGANG MOOCP_TESTZUGANG_ADRESSE; do
  # Wie in tool/mac_bau.sh: Eine leere Variable zählt nicht.
  [[ -z "${!name:-}" ]] || testbetrieb=ja
done
# Die Variablen wirken nur in einem Bau mit Testbetrieb (lib/testschalter.dart);
# tool/linux_bau.sh legt dafür neben dem Bau die Marke „testbetrieb" ab.
if [[ "$testbetrieb" == ja && ! -e "$BUNDLE/testbetrieb" ]]; then
  echo 'START-FEHLT: Der Bau hat keinen Testbetrieb. Erst mit denselben Variablen bash tool/linux_bau.sh ausführen.'
  exit 2
fi
# Nur die eigenen Prozesse beenden, nicht die anderer Benutzer.
pkill -u "$(id -u)" -x moocp; sleep 1
N=0
[[ ! -f "$L" ]] || N=$(wc -l < "$L")
erwartet=$(python3 -c 'import json,os; p=json.loads(os.environ.get("MOOCP_TESTZUGANG_PROFILE") or "{}"); print("\n".join(p))') || exit 2
nohup "$BUNDLE/moocp" --kein-update >/dev/null 2>&1 &
for i in $(seq 1 40); do
  sleep 3
  neu=$(tail -n +$((N+1)) "$L" 2>/dev/null)
  if [[ -z "$erwartet" ]]; then
    grep -q "MCP-Server läuft" <<< "$neu" && { echo START-OK; exit 0; }
  else
    bereit=true
    while IFS= read -r kennung; do
      grep -Fq "MCP-Server bereit [$kennung]" <<< "$neu" || bereit=false
    done <<< "$erwartet"
    $bereit && { echo START-OK; exit 0; }
  fi
done
echo 'START-FEHLT: Nicht alle erwarteten MCP-Server sind bereit.'; exit 1
