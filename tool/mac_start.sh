#!/usr/bin/env bash
# Startet die gebaute App neu und wartet auf alle gebundenen Testprofile.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
L="$HOME/Library/Application Support/moocp/protokoll.log"
env_args=()
testbetrieb=nein
for name in MOOCP_TESTZUGANG_PROFILE MOOCP_TESTZUGANG MOOCP_TESTZUGANG_ADRESSE; do
  if [[ "${!name+x}" == x ]]; then
    env_args+=(--env "$name=${!name}")
  fi
  # Wie in tool/mac_bau.sh: Eine leere Variable zählt nicht.
  [[ -z "${!name:-}" ]] || testbetrieb=ja
done
# Die Variablen wirken nur in einem Bau mit Testbetrieb (lib/testschalter.dart).
# tool/mac_bau.sh legt dafür neben dem Bau die Marke „testbetrieb" ab; ohne sie
# bliebe das Warten unten erfolglos, und die laufende App wäre schon beendet.
if [[ "$testbetrieb" == ja && ! -e "$REPO/build/macos/Build/Products/Debug/testbetrieb" ]]; then
  echo 'START-FEHLT: Der Bau hat keinen Testbetrieb. Erst mit denselben Variablen bash tool/mac_bau.sh ausführen.'
  exit 2
fi
pkill -x moocp; sleep 1
N=0
[[ ! -f "$L" ]] || N=$(wc -l < "$L")
erwartet=$(python3 -c 'import json,os; p=json.loads(os.environ.get("MOOCP_TESTZUGANG_PROFILE") or "{}"); print("\n".join(p))') || exit 2
open -n "$REPO/build/macos/Build/Products/Debug/moocp.app" "${env_args[@]}"
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
