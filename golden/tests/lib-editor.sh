# Golden Engine — shared helpers for the editor runtime tests (sourced). Real X11 input on Xvfb.
# Widgets log their screen rectangles when GOLDEN_UI_MAP=1 ("[GOLDEN UI] <id> @ x,y,w,h"), so tests
# click buttons, fields, browser items and parts by name with the real mouse.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="${BIN:-$ROOT/export/release/linux/bin}"
export DISPLAY="${GOLDEN_TEST_DISPLAY:-:96}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/golden-xdg}" GOLDEN_UI_MAP=1
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
PASS=0; FAIL=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; PASS=$((PASS+1)); else echo "FAIL  $1 ${3:-}"; FAIL=$((FAIL+1)); fi; }
clean_log() { sed 's/\x1b\[[0-9;]*m//g' "$LOG"; }
count() { clean_log | grep -c -- "$1"; }
wait_for() { local end=$((SECONDS + $3)); while [ $SECONDS -lt $end ]; do [ "$(count "$1")" -ge "$2" ] && return 0; sleep 0.4; done; return 1; }
win() { xdotool search --onlyvisible --name "Golden Engine|Funkin" 2>/dev/null | head -1; }
key() { xdotool windowactivate --sync "$(win)" 2>/dev/null; sleep 0.15
  for k in "$@"; do xdotool keydown "$k"; sleep 0.08; xdotool keyup "$k"; sleep 0.3; done; }
# combo ctrl+s: hold the modifier(s) for a few frames so the game sees them
combo() { xdotool windowactivate --sync "$(win)" 2>/dev/null; sleep 0.1; local mods="${1%+*}" k="${1##*+}" m
  for m in ${mods//+/ }; do xdotool keydown "$m"; done; sleep 0.12; xdotool keydown "$k"; sleep 0.1; xdotool keyup "$k"; sleep 0.1
  for m in ${mods//+/ }; do xdotool keyup "$m"; done; sleep 0.35; }
typetext() { xdotool type --delay 70 -- "$1"; sleep 0.3; }
shot() { import -window root "$OUT/$1.png" 2>/dev/null; convert "$OUT/$1.png" -format '%[fx:mean]' info: 2>/dev/null; }
not_black() { python3 -c "import sys; sys.exit(0 if float('${1:-0}') > 0.03 else 1)"; }
jsonget() { python3 -c "import json,sys; d=json.load(open('$1')); print(eval('d'+sys.argv[1]))" "$2" 2>/dev/null; }
# Last logged rectangle of a UI id -> "cx cy"
where() { clean_log | grep -F "GOLDEN UI" | grep -F " $1 @ " | tail -1 | sed -E 's/.* @ ([-0-9.]+),([-0-9.]+),([0-9.]+),([0-9.]+).*/\1 \2 \3 \4/' | awk '{printf "%d %d", $1+$3/2, $2+$4/2}'; }
# Game coordinates (1280x720) -> window pixels (the window manager may resize the window)
to_win() { local W; W=$(win); eval "$(xdotool getwindowgeometry --shell "$W")"
  python3 -c "w,h=$WIDTH,$HEIGHT; s=min(w/1280,h/720); print(int($1*s), int($2*s))"; }  # FNF scales uniformly, anchored top-left
mouse_to() { local W p; W=$(win); xdotool windowactivate --sync "$W" 2>/dev/null; p=$(to_win "$1" "$2"); xdotool mousemove --window "$W" $p; sleep 0.12
  p=$(to_win $(( $1 + 1 )) $(( $2 + 1 ))); xdotool mousemove --window "$W" $p; sleep 0.15; }
click_at() { mouse_to "$1" "$2"; xdotool mousedown 1; sleep 0.12; xdotool mouseup 1; sleep 0.5; }
# click <ui id>: waits until the id was logged, then clicks its centre
click() { local p="" end=$((SECONDS + ${2:-10})); while [ $SECONDS -lt $end ]; do p=$(where "$1"); [ -n "$p" ] && break; sleep 0.3; done
  [ -z "$p" ] && { echo "  (ui id not found: $1)"; return 1; }; click_at $p; return 0; }
# iclick <ui id>: like click, but scrolls the right-hand inspector until the id is on screen
iclick() { local p="" i; for i in 1 2 3 4 5 6 7 8 9 10; do p=$(where_fresh "$1"); [ -n "$p" ] && break
  mouse_to 1100 400; xdotool click 5; sleep 0.4; done
  [ -z "$p" ] && { echo "  (ui id not found: $1)"; return 1; }; click_at $p; }
# position of an id logged after the last scroll/rebuild marker (falls back to the last one)
where_fresh() { clean_log | awk '/GOLDEN UI  inspector:layout @/{buf=""} {buf=buf"\n"$0} END{print buf}' | grep -F "GOLDEN UI" | grep -F " $1 @ " | tail -1 | sed -E 's/.* @ ([-0-9.]+),([-0-9.]+),([0-9.]+),([0-9.]+).*/\1 \2 \3 \4/' | awk '{printf "%d %d", $1+$3/2, $2+$4/2}'; }
# pick <folder> <label>: find a browser item through the search box (as a user would) and click it
pick() { click "field:browser search" && combo ctrl+a && xdotool key BackSpace && typetext "${3:-$2}" && sleep 0.8 && click "item:$1/$2"; local r=$?
  click "field:browser search"; combo ctrl+a; xdotool key BackSpace; sleep 0.3; click_at 640 712; return $r; }  # clicking the status bar ends text focus
# drag from (x1,y1) to (x2,y2) in steps with the left button held
drag() { mouse_to "$1" "$2"; xdotool mousedown 1; sleep 0.15; local i; for i in 1 2 3 4 5 6 7 8; do
  xdotool mousemove --window "$(win)" $(to_win $(( $1 + ($3-$1)*i/8 )) $(( $2 + ($4-$2)*i/8 ))); sleep 0.06; done; sleep 0.15; xdotool mouseup 1; sleep 0.5; }
# Type a path into a zenity file dialog (lime's native dialogs use zenity on Linux)
dialog_path() { local w="" end=$((SECONDS + 15))
  while [ $SECONDS -lt $end ]; do w=$(xdotool search --name "$1" 2>/dev/null | head -1); [ -n "$w" ] && break; sleep 0.3; done
  [ -z "$w" ] && return 1
  sleep 1; xdotool windowactivate --sync "$w" 2>/dev/null; sleep 0.3
  [ "${3:-open}" = save ] && { xdotool key ctrl+a; sleep 0.2; }
  xdotool key ctrl+l 2>/dev/null; sleep 0.3
  xdotool type --delay 60 -- "$2"; sleep 1; xdotool key shift+End Delete; sleep 0.5; xdotool key Return; sleep 1.2; return 0; }

editor_setup() { # $1 = results subdir; creates a valid test mod "edit-test" as the editor target with Developer Mode on
  OUT="$ROOT/golden/tests/results/$1"; rm -rf "$OUT"; mkdir -p "$OUT"; LOG="$OUT/game.log"
  Xvfb "$DISPLAY" -screen 0 1280x720x24 -nolisten tcp >/dev/null 2>&1 & XVFB=$!
  sleep 1; openbox >/dev/null 2>&1 & WM=$!
  pulseaudio --check 2>/dev/null || pulseaudio -D --exit-idle-time=-1 -n --load=module-native-protocol-unix --load="module-null-sink sink_name=golden_test" >/dev/null 2>&1
  BACKUP="$OUT/user-backup"; mkdir -p "$BACKUP"
  for f in mods golden-mods.json golden-settings.json golden-animstudio-keys.json; do [ -e "$BIN/$f" ] && mv "$BIN/$f" "$BACKUP/$f"; done
  trap editor_restore EXIT
  mkdir -p "$BIN/mods/edit-test"
  echo '{"title":"Editor Test","api_version":"0.8.7","mod_version":"1.0.0","description":"editor tests"}' > "$BIN/mods/edit-test/_polymod_meta.json"
  echo '{"version":1,"developerMode":true,"uiVolume":1,"perfMonitor":false,"menuMusic":"golden","chartEditorKey":"SEVEN","modSelectorKey":"TAB","editorTarget":"edit-test","graphicsPreset":"high"}' > "$BIN/golden-settings.json"
  MOD="$BIN/mods/edit-test"
}
editor_restore() { pkill -9 -x Funkin 2>/dev/null; pkill -9 zenity 2>/dev/null
  [ -d "$BIN/mods/edit-test" ] && cp -r "$BIN/mods/edit-test" "$OUT/edit-test-mod" 2>/dev/null
  rm -rf "$BIN/mods" "$BIN/golden-mods.json" "$BIN/golden-settings.json" "$BIN/golden-animstudio-keys.json"
  for f in mods golden-mods.json golden-settings.json golden-animstudio-keys.json; do [ -e "$BACKUP/$f" ] && mv "$BACKUP/$f" "$BIN/$f"; done
  kill $WM $XVFB 2>/dev/null; }
start_game() { pkill -9 -x Funkin 2>/dev/null; sleep 0.5
  RUN=$(( ${RUN:-0} + 1 )); [ -f "$LOG" ] && mv "$LOG" "$OUT/game-run$((RUN-1)).log"
  (cd "$BIN" && ./Funkin > "$LOG" 2>&1 &); wait_for "TitleState" 1 60; }
to_main_menu() { sleep 14; key Return; wait_for "Idle -> EnteringMainMenu" 1 25; local r=$?; sleep 2; return $r; }
# main menu -> Editors hub (Developer Mode on). Menu: story, freeplay, mods, editors, ...
to_hub() { to_main_menu && key Down Down Down Return && wait_for "Editors hub ready for input" 1 25; }
open_editor() { click "card:$1" 15 && wait_for "$1 ready for input" 1 30 && sleep 1; }
crash_count() { local n; n=$(clean_log | grep -v "Enabling" | grep -ciE "uncaught|null object reference|segmentation|CRITICAL ERROR|Invalid field access|Called from"); [ -n "$(xdotool search --name "Fatal|Critical Error|Uncaught" 2>/dev/null)" ] && n=$((n+1)); echo "$n"; }
# Fail fast when the game shows a fatal error dialog
fatal_dialog() { [ -n "$(xdotool search --name "Fatal|Critical Error|Uncaught" 2>/dev/null)" ] || ls "$BIN/logs" 2>/dev/null | grep -q crash; }
finish() { pgrep -x Funkin >/dev/null; check "game still running (no crash)" $?
  local c; c=$(crash_count); [ "$c" = 0 ]; check "no uncaught errors in log ($c)" $?
  echo; echo "$PASS passed, $FAIL failed — screenshots and logs in $OUT"; [ "$FAIL" = 0 ]; }
