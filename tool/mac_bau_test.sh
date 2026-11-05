#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_ROOT="$(mktemp -d /tmp/moocp-mac-bau-test.XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT
FIXTURE="$TEST_ROOT/repo"
MOCKS="$TEST_ROOT/bin"
mkdir -p "$FIXTURE/tool" "$MOCKS"
cp "$SCRIPT_DIR/mac_bau.sh" "$FIXTURE/tool/"
chmod +x "$FIXTURE/tool/mac_bau.sh"

cat > "$MOCKS/rsync" <<'MOCK'
#!/usr/bin/env bash
source="${@: -2:1}"
destination="${@: -1}"
cp -R "$source"/. "$destination"
MOCK
cat > "$MOCKS/mktemp" <<'MOCK'
#!/usr/bin/env bash
path="$(/usr/bin/mktemp "$@")"
printf '%s\n' "$path" > "$MOOCP_TEMP_PATH_FILE"
printf '%s\n' "$path"
MOCK
cat > "$MOCKS/flutter" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOOCP_FLUTTER_ARGS_FILE"
if [[ "${MOCK_FLUTTER_FAIL:-}" == 1 ]]; then
  exit 23
fi
ziel=Debug
[[ " $* " == *" --release "* ]] && ziel=Release
mkdir -p "build/macos/Build/Products/$ziel/moocp.app"
printf 'built\n' > "build/macos/Build/Products/$ziel/moocp.app/result"
MOCK
chmod +x "$MOCKS/rsync" "$MOCKS/mktemp" "$MOCKS/flutter"

export PATH="$MOCKS:$PATH"
export MOOCP_TEMP_PATH_FILE="$TEST_ROOT/temp-path"
export MOOCP_FLUTTER_ARGS_FILE="$TEST_ROOT/flutter-args"
: > "$MOOCP_FLUTTER_ARGS_FILE"

unset MOOCP_TESTZUGANG_PROFILE MOOCP_TESTZUGANG MOOCP_TESTZUGANG_ADRESSE
"$FIXTURE/tool/mac_bau.sh" > "$TEST_ROOT/success.log"
APP="$FIXTURE/build/macos/Build/Products/Debug/moocp.app"
[[ -f "$APP/result" ]]
[[ ! -e "$(cat "$MOOCP_TEMP_PATH_FILE")" ]]
grep -q '^BAU-OK$' "$TEST_ROOT/success.log"

# Ohne Testzugangs-Variablen: kein Bauschalter für den Testbetrieb, keine Marke.
if grep -q 'MOOCP_TESTBETRIEB' "$MOOCP_FLUTTER_ARGS_FILE"; then
  echo 'Bauschalter ohne Testzugangs-Variablen gesetzt' >&2
  exit 1
fi
[[ ! -e "$FIXTURE/build/macos/Build/Products/Debug/testbetrieb" ]]

# Mit einer der Variablen: Bauschalter und Marke.
for variable in MOOCP_TESTZUGANG_PROFILE MOOCP_TESTZUGANG MOOCP_TESTZUGANG_ADRESSE; do
  : > "$MOOCP_FLUTTER_ARGS_FILE"
  rm -f "$FIXTURE/build/macos/Build/Products/Debug/testbetrieb"
  env "$variable=wert" "$FIXTURE/tool/mac_bau.sh" > "$TEST_ROOT/testbetrieb.log"
  grep -Fq -- '--dart-define=MOOCP_TESTBETRIEB=true' "$MOOCP_FLUTTER_ARGS_FILE"
  [[ -f "$FIXTURE/build/macos/Build/Products/Debug/testbetrieb" ]]
  grep -q '^BAU-OK$' "$TEST_ROOT/testbetrieb.log"
done

# Ein anschließender Bau ohne Variablen nimmt die Marke wieder weg.
"$FIXTURE/tool/mac_bau.sh" > "$TEST_ROOT/success.log"
[[ ! -e "$FIXTURE/build/macos/Build/Products/Debug/testbetrieb" ]]

# Ein Release-Bau hat den Testbetrieb nie, auch nicht mit Variablen.
: > "$MOOCP_FLUTTER_ARGS_FILE"
MOOCP_TESTZUGANG_PROFILE=wert "$FIXTURE/tool/mac_bau.sh" release > "$TEST_ROOT/release.log"
if grep -q 'MOOCP_TESTBETRIEB' "$MOOCP_FLUTTER_ARGS_FILE"; then
  echo 'Release-Bau mit Bauschalter für den Testbetrieb' >&2
  exit 1
fi

if MOCK_FLUTTER_FAIL=1 "$FIXTURE/tool/mac_bau.sh" > "$TEST_ROOT/failure.log" 2>&1; then
  echo 'Build failure unexpectedly succeeded' >&2
  exit 1
fi
[[ ! -e "$(cat "$MOOCP_TEMP_PATH_FILE")" ]]
echo 'mac_bau smoke test passed'
