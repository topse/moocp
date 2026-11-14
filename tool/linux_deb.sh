#!/usr/bin/env bash
# Baut das Debian-Paket: installer/moocp_<Version>_amd64.deb (E24, ADR 0024).
#
#   bash tool/linux_deb.sh
#
# Das Paket installiert systemweit (nach /opt/moocp, mit /usr/bin/moocp, Menü-
# eintrag und Symbol) und braucht dafür Administratorrechte:
#   sudo apt install ./moocp_<Version>_amd64.deb
# Eine Installation je Benutzer geht damit nicht; dafür sind das .run-Paket
# und das AppImage da. Einstellungen und gespeicherte Anmeldedaten liegen im
# Benutzerordner und bleiben beim Entfernen des Pakets (apt fasst keine
# Benutzerordner an); sie lassen sich mit `moocp --daten-entfernen`... nicht
# löschen -- siehe README, Teil 3.
#
# Menü und Symbolzwischenspeicher aktualisiert dpkg über seine Trigger, ein
# eigenes Skript gibt es nicht. Das Paket enthält nie den Testbetrieb.
set -euo pipefail
cd "$(dirname "$0")/.."
unset MOOCP_TESTZUGANG_PROFILE MOOCP_TESTZUGANG MOOCP_TESTZUGANG_ADRESSE
bash tool/linux_bau.sh release
BUNDLE="build/linux/x64/release/bundle"
VERSION="$(sed -n 's/^version: *\([0-9][0-9.]*\).*/\1/p' pubspec.yaml | head -1)"
[[ -n "$VERSION" ]] || { echo 'Version in pubspec.yaml nicht gefunden' >&2; exit 1; }
AUS="installer/moocp_${VERSION}_amd64.deb"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
R="$T/root"
mkdir -p "$R/opt/moocp" "$R/usr/bin" "$R/usr/share/applications" \
  "$R/usr/share/icons/hicolor/256x256/apps" "$R/usr/share/doc/moocp" "$R/DEBIAN"
cp -a "$BUNDLE/." "$R/opt/moocp/"
rm -f "$R/opt/moocp/testbetrieb"
ln -s ../../opt/moocp/moocp "$R/usr/bin/moocp"
cp docs/icon/icon.png "$R/usr/share/icons/hicolor/256x256/apps/moocp.png"
sed 's/^\xEF\xBB\xBF//' LICENSE.md > "$R/usr/share/doc/moocp/copyright"
cat > "$R/usr/share/applications/moocp.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Version=1.0
Name=moocp
Comment=Moodle-Kurse mit einem KI-Werkzeug bearbeiten
Exec=/opt/moocp/moocp
Icon=moocp
Terminal=false
Categories=Education;
StartupWMClass=moocp
DESK
# Rechte unabhängig von der umask des Baurechners: Verzeichnisse 755, Dateien 644,
# ausführbare 755.
find "$R" -type d -exec chmod 755 {} +
find "$R" -type f ! -perm -u+x -exec chmod 644 {} +
find "$R" -type f -perm -u+x -exec chmod 755 {} +
SIZE="$(du -sk "$R" | cut -f1)"
cat > "$R/DEBIAN/control" <<CTRL
Package: moocp
Version: $VERSION
Architecture: amd64
Maintainer: moocp <noreply@users.noreply.github.com>
Installed-Size: $SIZE
Section: education
Priority: optional
Homepage: https://github.com/topse/moocp
Depends: libc6 (>= 2.38), libgtk-3-0t64 | libgtk-3-0, libsecret-1-0, libglib2.0-0t64 | libglib2.0-0, libstdc++6
Recommends: libglib2.0-bin, libsecret-tools, gnome-keyring | keepassxc, xdg-utils, chromium | google-chrome-stable | microsoft-edge-stable
Description: Moodle-Kurse mit einem KI-Werkzeug bearbeiten
 moocp ist die lokale App, über die Claude Code oder Codex CLI Moodle-Kurse
 lesen und bearbeiten, mit Sperrliste für personenbezogene Daten, Freigaben
 in der App und einem Protokoll. Dieses Paket installiert systemweit und
 braucht Administratorrechte; eine Installation je Benutzer bietet das
 .run-Paket oder das AppImage.
CTRL
fakeroot dpkg-deb --root-owner-group --build "$R" "$AUS" >/dev/null
echo "DEB-OK $AUS ($(du -h "$AUS" | cut -f1))"
