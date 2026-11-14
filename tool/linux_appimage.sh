#!/usr/bin/env bash
# Baut das AppImage für Linux: installer/moocp_<Version>-x86_64.AppImage, eine
# einzelne Datei ohne Installation (E24). Entscheidung und Grenzen: ADR 0024.
#
#   bash tool/linux_appimage.sh
#
# Das AppImage enthält die gebaute App (Release, nie der Testbetrieb), aber
# nicht die Systembibliotheken: GTK 3 und libsecret müssen auf dem Rechner sein,
# wie bei der App aus dem Entwicklungsbau. Gebaut auf Debian 13, läuft es dort
# und auf Distributionen mit mindestens derselben glibc (2.38).
#
# Ohne Argumente startet es die App. Mit `--installieren` öffnet es denselben
# Assistenten wie das .run-Paket und legt die App mit Startmenü-Eintrag nach
# ~/.local/opt/moocp (der Assistent kopiert das Programm aus dem AppImage).
#
# Gebaut wird mit appimagetool 1.9.1 von GitHub; es wird beim ersten Lauf nach
# build/tools geladen und gegen die feste Prüfsumme unten geprüft. FUSE braucht
# der Bau nicht (APPIMAGE_EXTRACT_AND_RUN).
set -euo pipefail
cd "$(dirname "$0")/.."
unset MOOCP_TESTZUGANG_PROFILE MOOCP_TESTZUGANG MOOCP_TESTZUGANG_ADRESSE
TOOL_VERSION=1.9.1
TOOL_SHA256=ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0
TOOL_DIR="build/tools/appimagetool-$TOOL_VERSION"
TOOL="$TOOL_DIR/appimagetool-x86_64.AppImage"
if [[ ! -x "$TOOL" ]]; then
  mkdir -p "$TOOL_DIR"
  curl -fsSL -o "$TOOL" "https://github.com/AppImage/appimagetool/releases/download/$TOOL_VERSION/appimagetool-x86_64.AppImage"
  chmod +x "$TOOL"
fi
echo "$TOOL_SHA256  $TOOL" | sha256sum -c --quiet - || { rm -f "$TOOL"; echo 'Prüfsumme von appimagetool stimmt nicht' >&2; exit 1; }
bash tool/linux_bau.sh release
BUNDLE="build/linux/x64/release/bundle"
VERSION="$(sed -n 's/^version: *\([0-9][0-9.]*\).*/\1/p' pubspec.yaml | head -1)"
[[ -n "$VERSION" ]] || { echo 'Version in pubspec.yaml nicht gefunden' >&2; exit 1; }
AUS="installer/moocp_${VERSION}-x86_64.AppImage"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
A="$T/moocp.AppDir"
mkdir -p "$A/usr/bin"
cp -a "$BUNDLE/." "$A/usr/bin/"
rm -f "$A/usr/bin/testbetrieb"
# Das Symbol liegt neben dem Programm, weil der Assistent es von dort kopiert
# (lib/installer/installer_logik.dart).
cp docs/icon/icon.png "$A/usr/bin/moocp.png"
cp docs/icon/icon.png "$A/moocp.png"
cp docs/icon/icon.png "$A/.DirIcon"
cat > "$A/AppRun" <<'RUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/moocp" "$@"
RUN
chmod 755 "$A/AppRun"
cat > "$A/moocp.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=moocp
Comment=Moodle-Kurse mit einem KI-Werkzeug bearbeiten
Exec=moocp
Icon=moocp
Terminal=false
Categories=Education;
StartupWMClass=moocp
DESK
APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 "$TOOL" --no-appstream "$A" "$AUS" >/dev/null
chmod 755 "$AUS"
echo "APPIMAGE-OK $AUS ($(du -h "$AUS" | cut -f1))"
