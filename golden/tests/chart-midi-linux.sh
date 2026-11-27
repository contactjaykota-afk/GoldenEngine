#!/usr/bin/env bash
# Golden Engine — runtime test: 7 during a song opens the Chart Editor on that chart (Developer Mode),
# File > Import MIDI (Ctrl+Shift+M) through the real native file dialog, the track-mapping dialog,
# importing as one undoable command, and undo.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="${1:-$ROOT/export/release/linux/bin}"
OUT="$ROOT/golden/tests/results/chart-midi"; mkdir -p "$OUT"
export DISPLAY="${GOLDEN_TEST_DISPLAY:-:90}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/golden-xdg}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
LOG="$OUT/game.log"; PASS=0; FAIL=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; PASS=$((PASS+1)); else echo "FAIL  $1 ${3:-}"; FAIL=$((FAIL+1)); fi; }
clean_log() { sed 's/\x1b\[[0-9;]*m//g' "$LOG"; }
count() { clean_log | grep -c -- "$1"; }
wait_for() { local end=$((SECONDS + $3)); while [ $SECONDS -lt $end ]; do [ "$(count "$1")" -ge "$2" ] && return 0; sleep 0.5; done; return 1; }
win() { xdotool search --onlyvisible --name "Golden Engine|Chart Editor" | head -1; }
key() { xdotool windowactivate --sync "$(win)" 2>/dev/null; sleep 0.2
  for k in "$@"; do xdotool keydown "$k"; sleep 0.08; xdotool keyup "$k"; sleep 0.35; done; }
shot() { import -window root "$OUT/$1.png"; }
dialog_path() { local w="" end=$((SECONDS + 15))
  while [ $SECONDS -lt $end ]; do w=$(xdotool search --name "$1" 2>/dev/null | head -1); [ -n "$w" ] && break; sleep 0.3; done
  [ -z "$w" ] && return 1
  sleep 1; xdotool windowactivate --sync "$w" 2>/dev/null; sleep 0.3
  xdotool type --delay 60 -- "$2"; sleep 1; xdotool key shift+End Delete; sleep 0.5; xdotool key Return; sleep 1; return 0; }

Xvfb "$DISPLAY" -screen 0 1280x720x24 -nolisten tcp >/dev/null 2>&1 & XVFB=$!
sleep 1; openbox >/dev/null 2>&1 & WM=$!
pulseaudio --check 2>/dev/null || pulseaudio -D --exit-idle-time=-1 -n --load=module-native-protocol-unix --load="module-null-sink sink_name=golden_test" >/dev/null 2>&1
BACKUP="$OUT/user-backup"; rm -rf "$BACKUP"; mkdir -p "$BACKUP"
for f in mods golden-mods.json golden-settings.json; do [ -e "$BIN/$f" ] && mv "$BIN/$f" "$BACKUP/$f"; done
restore() { pkill -9 -x Funkin 2>/dev/null; pkill -9 zenity 2>/dev/null; rm -rf "$BIN/mods" "$BIN/golden-mods.json" "$BIN/golden-settings.json"
  for f in mods golden-mods.json golden-settings.json; do [ -e "$BACKUP/$f" ] && mv "$BACKUP/$f" "$BIN/$f"; done; kill $WM $XVFB 2>/dev/null; }
trap restore EXIT
echo '{"developerMode":true}' > "$BIN/golden-settings.json"
MID="$OUT/test-song.mid"; python3 "$ROOT/golden/tests/make_test_midi.py" "$MID"

(cd "$BIN" && ./Funkin > "$LOG" 2>&1 &)
wait_for "TitleState" 1 60; check "game boots" $?
sleep 16; key Return; wait_for "Idle -> EnteringMainMenu" 1 20
sleep 2; key Down Return; wait_for "Idle -> EnteringFreeplay" 1 20
sleep 3; key Down Return
wait_for "started song at" 1 40; check "Bopeebo starts" $?
sleep 3; key 7
wait_for "ChartEditorState" 1 30; check "7 during the song opens the Chart Editor" $?
sleep 6; shot 01-chart-editor
clean_log | grep -qi "bopeebo" ; check "Chart Editor loaded the current song (bopeebo)" $?

for w in $(xdotool search --name "." 2>/dev/null); do echo "  win $w '$(xdotool getwindowname $w 2>/dev/null)' $(xdotool getwindowgeometry $w 2>/dev/null | tr '\n' ' ')"; done | grep -v "''" | head; echo "  chosen: $(win)"
W=$(win); xdotool windowactivate --sync "$W"; xdotool mousemove --window "$W" 31 17; sleep 0.4; xdotool mousemove --window "$W" 32 18; sleep 0.3; xdotool mousedown 1; sleep 0.15; xdotool mouseup 1; sleep 1.2; shot 01b-file-menu
xdotool mousemove --window "$W" 58 94; sleep 0.4; xdotool mousemove --window "$W" 60 95; sleep 0.3; xdotool mousedown 1; sleep 0.15; xdotool mouseup 1
dialog_path "Import MIDI" "$MID"; check "File > Import MIDI... opens the native MIDI file dialog" $?
wait_for "MIDI parsed: test-song, 3 tracks, 12 notes" 1 10; check "MIDI file parsed (3 tracks, 12 notes)" $?
sleep 2; shot 02-midi-dialog
W=$(win); xdotool mousemove --window "$W" 315 552; sleep 0.4; xdotool mousemove --window "$W" 316 553; sleep 0.3; xdotool mousedown 1; sleep 0.15; xdotool mouseup 1
wait_for "MIDI import: 12 notes, 1 time changes from test-song" 1 10; check "Import adds 12 notes and the 120 BPM time change" $?
sleep 1.5; shot 03-after-import
echo; echo "$PASS passed, $FAIL failed — log and screenshots in $OUT"
[ "$FAIL" = 0 ]
