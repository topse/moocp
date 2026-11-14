#!/usr/bin/env bash
# Baut den Installer für Linux: installer/moocp_setup_<Version>.run, eine
# einzelne Datei, die sich selbst entpackt und den Installer der App
# (`moocp --installieren`, lib/installer/) aus einem Temp-Ordner startet. Das
# Gegenstück zu create_installer.bat; Entscheidung und Regeln: E24, E15.
#
#   bash tool/linux_installer.sh            Release-Bau (Vorgabe)
#   bash tool/linux_installer.sh debug      aus dem Debug-Bau, nur zum Ausprobieren
#
# Das Paket enthält nie den Testbetrieb: Der Bau läuft ohne die Variablen
# MOOCP_TESTZUGANG*, und die Marke `testbetrieb` bleibt draußen. Der
# Installer ist nicht signiert (E19).
set -euo pipefail
MODUS="${1:-release}"
case "$MODUS" in release | debug) ;; *) echo "Unbekannter Modus: $MODUS (release oder debug)" >&2; exit 2 ;; esac
cd "$(dirname "$0")/.."
unset MOOCP_TESTZUGANG_PROFILE MOOCP_TESTZUGANG MOOCP_TESTZUGANG_ADRESSE
bash tool/linux_bau.sh "$MODUS"
BUNDLE="build/linux/x64/$MODUS/bundle" # wie tool/linux_bau.sh: Debian amd64 (E24)
# Die Version steht nur in pubspec.yaml (E15); die Dateiname trägt sie ohne
# Buildnummer, wie moocp_setup_<Version>.exe unter Windows.
VERSION="$(sed -n 's/^version: *\([0-9][0-9.]*\).*/\1/p' pubspec.yaml | head -1)"
[[ -n "$VERSION" ]] || { echo 'Version in pubspec.yaml nicht gefunden' >&2; exit 1; }
AUS="installer/moocp_setup_${VERSION}.run"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
cp -a "$BUNDLE/." "$T/"
rm -f "$T/testbetrieb"
cp docs/icon/icon.png "$T/moocp.png"
{
  cat <<'STUB'
#!/bin/sh
# moocp-Installer für Linux: entpackt sich in einen Temp-Ordner und startet
# von dort den Installer der App. Mit --still ohne Fenster (die App selbst
# braucht trotzdem eine grafische Sitzung: Flutters GTK-Läufer öffnet die
# Anzeige beim Start):
#   sh moocp_setup_<Version>.run --still [--ziel=<Ordner>]
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
  echo "moocp braucht eine grafische Sitzung (DISPLAY nicht gesetzt)." >&2
  exit 1
fi
ARCHIV=$(awk '/^__ARCHIV__$/ { print NR + 1; exit 0 }' "$0")
T=$(mktemp -d "${TMPDIR:-/tmp}/moocp_setup.XXXXXX") || exit 1
trap 'rm -rf "$T"' EXIT INT TERM HUP
tail -n +"$ARCHIV" "$0" | tar xz -C "$T" || { echo "Das Paket ist beschädigt." >&2; exit 1; }
"$T/moocp" --installieren --quelle="$T" "$@"
exit $?
__ARCHIV__
STUB
  tar czf - -C "$T" .
} > "$AUS"
chmod 755 "$AUS"
echo "INSTALLER-OK $AUS ($(du -h "$AUS" | cut -f1))"
