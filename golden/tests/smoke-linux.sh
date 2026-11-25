#!/usr/bin/env bash
# Golden Engine — end-to-end smoke test of a built Linux game.
#
# Drives the real executable with real X11 keyboard input on a virtual display and checks, at
# every step, both the game log (state reached) and the screen (frame is not black):
#   title -> main menu -> freeplay -> song plays -> pause -> restart -> game over -> retry
#   -> exit to menu -> main menu -> debug menu -> chart editor
# Also records the game's audio output to verify sound actually plays.
#
# Requirements (Debian/Ubuntu): xvfb openbox xdotool imagemagick pulseaudio pulseaudio-utils
#                               python3-numpy, a built game in export/release/linux/bin
# Usage:  golden/tests/smoke-linux.sh [path/to/bin]      (exit code 0 = all checks passed)
set -u
BIN="${1:-$(cd "$(dirname "$0")/../.." && pwd)/export/release/linux/bin}"
OUT="$(cd "$(dirname "$0")/../.." && pwd)/golden/tests/results"
mkdir -p "$OUT"
export DISPLAY="${GOLDEN_TEST_DISPLAY:-:97}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/golden-xdg}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
LOG="$OUT/game.log"
PASS=0; FAIL=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; PASS=$((PASS+1)); else echo "FAIL  $1 ${3:-}"; FAIL=$((FAIL+1)); fi; }
clean_log() { sed 's/\x1b\[[0-9;]*m//g' "$LOG"; }
count() { clean_log | grep -c -- "$1"; }
wait_for() { # pattern min_count timeout_s
  local end=$((SECONDS + $3)); while [ $SECONDS -lt $end ]; do [ "$(count "$1")" -ge "$2" ] && return 0; sleep 0.5; done; return 1; }
key() { local w; w=$(xdotool search --name "Friday Night Funkin" | head -1); xdotool windowactivate --sync "$w" 2>/dev/null; sleep 0.2
  for k in "$@"; do xdotool keydown "$k"; sleep 0.08; xdotool keyup "$k"; sleep 0.35; done; }
shot() { import -window root "$OUT/$1.png"; convert "$OUT/$1.png" -format '%[fx:mean]' info:; }
not_black() { python3 -c "import sys; sys.exit(0 if float('$1') > 0.05 else 1)"; }

# --- environment: virtual display, window manager, audio sink --------------------------------
Xvfb "$DISPLAY" -screen 0 1280x720x24 -nolisten tcp >/dev/null 2>&1 & XVFB=$!
sleep 1
openbox >/dev/null 2>&1 & WM=$!
pulseaudio --check 2>/dev/null || pulseaudio -D --exit-idle-time=-1 -n --load=module-native-protocol-unix \
  --load="module-null-sink sink_name=golden_test" >/dev/null 2>&1
sleep 1
pactl set-default-sink golden_test 2>/dev/null || pactl load-module module-null-sink sink_name=golden_test >/dev/null
pactl set-default-sink golden_test
cleanup() { pkill -9 -f "$BIN/Funkin" 2>/dev/null; kill $WM $XVFB 2>/dev/null; }
trap cleanup EXIT

# Software OpenGL (Mesa llvmpipe) renders black with OpenFL's advanced-blend path; see
# golden/KNOWN_ISSUES.md (GE-001). Hide the extension only when running on llvmpipe.
EXTRA_ENV=()
if glxinfo -B 2>/dev/null | grep -q llvmpipe; then
  EXTRA_ENV=(MESA_EXTENSION_OVERRIDE="-GL_KHR_blend_equation_advanced -GL_KHR_blend_equation_advanced_coherent")
  echo "note: software OpenGL detected, applying GE-001 workaround"
fi

# --- run ---------------------------------------------------------------------------------------
(cd "$BIN" && env "${EXTRA_ENV[@]}" ./Funkin > "$LOG" 2>&1 &)
wait_for "TitleState" 1 60; check "game boots to the title screen" $?
# The intro (credits text on black, timed to the music) lasts ~13s; the title appears after it.
sleep 16; m=$(shot 01-title); not_black "$m"; check "title screen renders after the intro (mean=$m)" $?

key Return
wait_for "Idle -> EnteringMainMenu" 1 20; check "Enter goes to the main menu" $?
sleep 2; m=$(shot 02-main-menu); not_black "$m"; check "main menu renders (mean=$m)" $?

key Down Return
wait_for "Idle -> EnteringFreeplay" 1 20; check "Freeplay opens" $?
sleep 3; m=$(shot 03-freeplay); not_black "$m"; check "Freeplay renders (mean=$m)" $?

pactl list short sinks >/dev/null
( timeout 15 parec -d golden_test.monitor --format=s16le --rate=44100 --channels=2 > "$OUT/gameplay-audio.raw" ) &
key Down Return
wait_for "started song at" 1 40; check "selecting Bopeebo starts the song" $?
sleep 6; m=$(shot 04-gameplay); not_black "$m"; check "gameplay renders (mean=$m)" $?
wait_for "Focusing camera" 1 20; check "chart events execute (FocusCamera)" $?
sleep 9
python3 - "$OUT/gameplay-audio.raw" <<'PY'
import sys, numpy as np
a = np.fromfile(sys.argv[1], dtype=np.int16).astype(float)
rms = float(np.sqrt((a ** 2).mean())) if len(a) else 0.0
print(f"      gameplay audio: {len(a)/2/44100:.1f}s rms={rms:.0f}")
sys.exit(0 if rms > 500 else 1)
PY
check "song audio is audible on the output device" $?

key Return; sleep 1.5
m=$(shot 05-pause); not_black "$m"; check "pause menu renders (mean=$m)" $?
key Down Return
wait_for "started song at" 2 30; check "Restart Song restarts the song" $?

wait_for "GameOverSubState" 1 120; check "no input leads to Game Over" $?
sleep 3; m=$(shot 06-game-over); not_black "$m"; check "game over renders (mean=$m)" $?
key Return
wait_for "started song at" 3 40; check "Retry from Game Over restarts the song" $?

sleep 3; key Return; sleep 1.5; key Up Return
wait_for "Idle -> EnteringFreeplay" 2 30; check "Exit to Menu returns to Freeplay" $?
sleep 3; key Escape
wait_for "Idle -> EnteringMainMenu" 2 20; check "Escape returns to the main menu" $?
sleep 2; key grave; sleep 1.5
m=$(shot 07-debug-menu); not_black "$m"; check "debug menu opens (mean=$m)" $?
key Return
wait_for "ChartEditorState" 1 40; check "Chart Editor opens" $?
sleep 4; m=$(shot 08-chart-editor); not_black "$m"; check "Chart Editor renders (mean=$m)" $?

pgrep -f "$BIN/Funkin" >/dev/null || pgrep -x Funkin >/dev/null; check "game still running (no crash)" $?
RSS=$(ps -C Funkin -o rss= | sort -n | tail -1); echo "      memory: $((RSS/1024)) MB RSS"
crashes=$(clean_log | grep -v "Enabling" | grep -ciE "uncaught|null object reference|segmentation|CRITICAL ERROR"); [ "$crashes" = 0 ]; check "no uncaught errors in log ($crashes)" $?

echo; echo "$PASS passed, $FAIL failed — screenshots and log in $OUT"
[ "$FAIL" = 0 ]
