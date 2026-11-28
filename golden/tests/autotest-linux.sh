#!/usr/bin/env bash
# Golden Engine — runs the in-game AutoTest routes (the same ones the Windows CI uses) on Linux.
#   play: title -> main menu -> Bopeebo plays 15 s (+ a Lua script from a test mod)
#   mods: title -> main menu -> Mod Manager -> Esc -> still on the main menu 5 s later
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="${1:-$ROOT/export/release/linux/bin}"
OUT="$ROOT/golden/tests/results/autotest"; mkdir -p "$OUT"
export DISPLAY="${GOLDEN_TEST_DISPLAY:-:85}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/golden-xdg}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
PASS=0; FAIL=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; PASS=$((PASS+1)); else echo "FAIL  $1 ${3:-}"; FAIL=$((FAIL+1)); fi; }
Xvfb "$DISPLAY" -screen 0 1280x720x24 -nolisten tcp >/dev/null 2>&1 & XVFB=$!
sleep 1
pulseaudio --check 2>/dev/null || pulseaudio -D --exit-idle-time=-1 -n --load=module-native-protocol-unix --load="module-null-sink sink_name=golden_test" >/dev/null 2>&1
BACKUP="$OUT/user-backup"; rm -rf "$BACKUP"; mkdir -p "$BACKUP"
for f in mods golden-mods.json; do [ -e "$BIN/$f" ] && mv "$BIN/$f" "$BACKUP/$f"; done
restore() { pkill -9 -x Funkin 2>/dev/null; rm -rf "$BIN/mods" "$BIN/golden-mods.json"
  for f in mods golden-mods.json; do [ -e "$BACKUP/$f" ] && mv "$BACKUP/$f" "$BIN/$f"; done; kill $XVFB 2>/dev/null; }
trap restore EXIT
mkdir -p "$BIN/mods/zz-autotest/scripts/lua"
echo '{"title":"AutoTest","api_version":"0.8.7","mod_version":"1.0.0"}' > "$BIN/mods/zz-autotest/_polymod_meta.json"
echo 'function onCreate() print("LUAT autotest lua ok song=" .. tostring(getSongName())) end' > "$BIN/mods/zz-autotest/scripts/lua/t.lua"
for route in play mods editors; do
  log="$OUT/$route.log"
  (cd "$BIN" && GOLDEN_AUTOTEST=$route timeout 150 ./Funkin > "$log" 2>&1)
  sed -i 's/\x1b\[[0-9;]*m//g' "$log"
  grep -q "GOLDEN AUTOTEST  done" "$log"; check "$route route completes" $?
  ! grep -q "AUTOTEST  FAILED" "$log"; check "$route route has no failed step" $? "$(grep -m1 'AUTOTEST  FAILED' "$log")"
done
grep -q "started song at" "$OUT/play.log"; check "play: Bopeebo started" $?
grep -q "LUAT autotest lua ok song=bopeebo" "$OUT/play.log"; check "play: Lua script from a mod ran" $?
grep -q "Mod Manager opened" "$OUT/mods.log"; check "mods: Mod Manager opened" $?
grep -q "still in MainMenuState (ok)" "$OUT/mods.log"; check "mods: Esc from the Mod Manager stays on the main menu (regression)" $?
for e in "editors hub reached" "animation studio reached" "event system reached" "week editor reached" "game over editor reached"; do
  grep -q "AUTOTEST  $e" "$OUT/editors.log"; check "editors: $e" $?; done
grep -q "Boyfriend imported from the game atlas" "$OUT/editors.log"; check "editors: Boyfriend imported in the Animation Studio" $?
echo; echo "$PASS passed, $FAIL failed — logs in $OUT"
[ "$FAIL" = 0 ]
