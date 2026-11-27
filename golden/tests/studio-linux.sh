#!/usr/bin/env bash
# Golden Engine — runtime test of the Golden Studio script editor (Linux build, virtual display).
# Mods > S opens the editor on a mod; Ctrl+N creates a Lua file from the template; typing + Ctrl+S
# saves (backup kept, Lua syntax validated); a syntax error is reported; Ctrl+Z undoes; Esc returns.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="${1:-$ROOT/export/release/linux/bin}"
OUT="$ROOT/golden/tests/results/studio"; mkdir -p "$OUT"
export DISPLAY="${GOLDEN_TEST_DISPLAY:-:92}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/golden-xdg}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
LOG="$OUT/game.log"; PASS=0; FAIL=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; PASS=$((PASS+1)); else echo "FAIL  $1 ${3:-}"; FAIL=$((FAIL+1)); fi; }
clean_log() { sed 's/\x1b\[[0-9;]*m//g' "$LOG"; }
count() { clean_log | grep -c -- "$1"; }
wait_for() { local end=$((SECONDS + $3)); while [ $SECONDS -lt $end ]; do [ "$(count "$1")" -ge "$2" ] && return 0; sleep 0.5; done; return 1; }
win() { xdotool search --name "Golden Engine" | head -1; }
key() { xdotool windowactivate --sync "$(win)" 2>/dev/null; sleep 0.2
  for k in "$@"; do xdotool keydown "$k"; sleep 0.08; xdotool keyup "$k"; sleep 0.35; done; }
combo() { xdotool windowactivate --sync "$(win)" 2>/dev/null; sleep 0.2; xdotool keydown ctrl; sleep 0.05; xdotool keydown "$1"; sleep 0.08; xdotool keyup "$1"; sleep 0.05; xdotool keyup ctrl; sleep 0.5; }
typetext() { xdotool windowactivate --sync "$(win)" 2>/dev/null; xdotool type --delay 50 -- "$1"; sleep 0.3; }
shot() { import -window root "$OUT/$1.png"; convert "$OUT/$1.png" -format '%[fx:mean]' info:; }
not_black() { python3 -c "import sys; sys.exit(0 if float('$1') > 0.03 else 1)"; }

Xvfb "$DISPLAY" -screen 0 1280x720x24 -nolisten tcp >/dev/null 2>&1 & XVFB=$!
sleep 1; openbox >/dev/null 2>&1 & WM=$!
pulseaudio --check 2>/dev/null || pulseaudio -D --exit-idle-time=-1 -n --load=module-native-protocol-unix --load="module-null-sink sink_name=golden_test" >/dev/null 2>&1  # FNF timing follows the music clock
BACKUP="$OUT/user-backup"; rm -rf "$BACKUP"; mkdir -p "$BACKUP"
for f in mods golden-mods.json; do [ -e "$BIN/$f" ] && mv "$BIN/$f" "$BACKUP/$f"; done
restore() { pkill -9 -x Funkin 2>/dev/null; rm -rf "$BIN/mods" "$BIN/golden-mods.json"
  for f in mods golden-mods.json; do [ -e "$BACKUP/$f" ] && mv "$BACKUP/$f" "$BIN/$f"; done; kill $WM $XVFB 2>/dev/null; }
trap restore EXIT
mkdir -p "$BIN/mods"; python3 "$ROOT/golden/tests/make_test_mod.py" "$BIN/mods" studiomod "Studio Test" >/dev/null
F="$BIN/mods/studiomod/scripts/lua/hello.lua"

(cd "$BIN" && ./Funkin > "$LOG" 2>&1 &)
wait_for "TitleState" 1 60; check "game boots" $?
sleep 16; key Return; wait_for "Idle -> EnteringMainMenu" 1 20
sleep 2; key Down Down Return
wait_for "Mod Manager opened: 1 installed" 1 20; check "Mod Manager opens with the test mod" $?
sleep 1; key s
wait_for 'Script editor opened for "studiomod"' 1 10; check "S opens the script editor on the selected mod" $?
sleep 1.5; m=$(shot 01-editor); not_black "$m"; check "editor renders (mean=$m)" $?

combo n; sleep 1
typetext "scripts/lua/hello.lua"; key Return
wait_for "Script editor: created scripts/lua/hello.lua" 1 5; check "Ctrl+N creates a file from the Lua template" $?
grep -q "function onCreate" "$F" 2>/dev/null; check "new file has the Lua template content" $?
sleep 1; m=$(shot 02-new-file); not_black "$m"; check "new file shown with highlighting (mean=$m)" $?

typetext 'print("edited by test")'; key Return
combo s
wait_for "Script editor: saved scripts/lua/hello.lua (valid)" 1 5; check "Ctrl+S saves a valid Lua file" $?
grep -q 'print("edited by test")' "$F"; check "typed text is in the saved file" $?
ls "$BIN/mods/.trash/backups/studiomod/scripts/lua/"hello.lua.*.bak >/dev/null 2>&1; check "previous version backed up in mods/.trash/backups" $?

sleep 0.8; typetext 'function ('; combo s
wait_for "saved scripts/lua/hello.lua with problem" 1 5; check "Lua syntax error detected on save" $?
clean_log | grep "with problem" | tail -1 | grep -qE "hello.lua:[0-9]+:"; check "error message names the file and line" $?
sleep 0.8; combo z; combo s
wait_for "Script editor: saved scripts/lua/hello.lua (valid)" 2 5; check "Ctrl+Z undoes the bad edit (file valid again)" $?
! grep -q 'function (' "$F"; check "undone text not in the file" $?
sleep 1; m=$(shot 03-after-undo); check "screenshot after undo" 0

# --- Play-in-Editor ---
typetext '-- unsaved edit before play'
key F9; sleep 1
m=$(shot 04-play-prompt); check "Play prompt shown" 0
key Return
wait_for "Play-in-Editor: starting \"bopeebo\" (normal)" 1 10; check "F9 > Enter starts the default song from the editor" $?
grep -q -- '-- unsaved edit before play' "$F"; check "Play saved the unsaved edit first" $?
wait_for "started song at" 1 40; check "song is playing" $?
sleep 4; m=$(shot 05-playing); not_black "$m"; check "gameplay renders during Play-in-Editor (mean=$m)" $?
wait_for "hello.lua: loaded bopeebo" 1 10; check "the Lua file written in the editor runs in the played song" $?
key F9
wait_for "Play-in-Editor: Studio session restored (2 tab(s))" 1 20; check "F9 stops the song and restores the editor session (2 tabs)" $?
sleep 1.5; m=$(shot 06-restored); not_black "$m"; check "editor renders after returning (mean=$m)" $?

key Escape
wait_for "Mod Manager opened: 1 installed" 2 10; check "Esc returns to the Mod Manager (no unsaved changes)" $?
pgrep -x Funkin >/dev/null; check "no crash" $?
crashes=$(clean_log | grep -v "Enabling" | grep -ciE "uncaught|null object reference|segmentation|CRITICAL ERROR"); [ "$crashes" = 0 ]; check "no uncaught errors ($crashes)" $?
echo; echo "$PASS passed, $FAIL failed — screenshots and log in $OUT"
[ "$FAIL" = 0 ]
