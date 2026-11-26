#!/usr/bin/env bash
# Golden Engine — startup regression test for a built Linux game.
#
# Verifies, on a virtual display with no GPU (so Mesa uses software OpenGL, i.e. the GE-001 setup):
#   1. the game boots and reaches the title screen,
#   2. NORMAL startup never loads a song / PlayState on its own (no debug autostart),
#   3. the window title is "Golden Engine",
#   4. the screen is not black (GE-001 fallback works),
#   5. pressing Enter on the title leads to the main menu, still without a song,
#   6. memory (RSS) is measured and printed.
# It also runs a CONTROL pass with the fallback disabled (GOLDEN_ADVANCED_BLEND=1) purely to show
# whether the black-screen bug reproduces on this machine; the control never fails the test.
#
# Requirements (Debian/Ubuntu): xvfb openbox xdotool ffmpeg, a built game in export/release/linux/bin
# Usage: golden/tests/startup-linux.sh [path/to/bin]     (exit code 0 = all checks passed)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="${1:-$ROOT/export/release/linux/bin}"
OUT="$ROOT/golden/tests/results"
mkdir -p "$OUT"
export DISPLAY="${GOLDEN_TEST_DISPLAY:-:98}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/golden-xdg}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
PASS=0; FAIL=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; PASS=$((PASS+1)); else echo "FAIL  $1 ${3:-}"; FAIL=$((FAIL+1)); fi; }

Xvfb "$DISPLAY" -screen 0 1280x720x24 -nolisten tcp >/dev/null 2>&1 & XVFB=$!
sleep 1
openbox >/dev/null 2>&1 & WM=$!
sleep 1
# Headless machines have no sound card; give OpenAL a null sink so audio init does not abort the game.
if command -v pulseaudio >/dev/null 2>&1; then
  pulseaudio --check 2>/dev/null || pulseaudio -D --exit-idle-time=-1 -n --load=module-native-protocol-unix \
    --load="module-null-sink sink_name=golden_test" >/dev/null 2>&1
  sleep 1; pactl set-default-sink golden_test 2>/dev/null
  echo "audio sinks: $(pactl list short sinks 2>&1 | tr '\n' ';')"
else
  echo "note: pulseaudio not installed; the game may abort on audio init"
fi
cleanup() { pkill -9 -x Funkin 2>/dev/null; kill $WM $XVFB 2>/dev/null; }
trap cleanup EXIT

clean_log() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }
count() { clean_log "$1" | grep -c -- "$2"; }
wait_for() { # log pattern min_count timeout_s  (gives up early if the game process died)
  local start=$SECONDS end=$((SECONDS + $4))
  while [ $SECONDS -lt $end ]; do
    [ "$(count "$1" "$2")" -ge "$3" ] && return 0
    if [ $((SECONDS - start)) -gt 8 ] && ! pgrep -x Funkin >/dev/null; then echo "      (game process exited while waiting for \"$2\")"; return 1; fi
    sleep 0.5
  done; return 1; }
# Average luma (0-255) of the current screen, via ffmpeg.
luma() {
  ffmpeg -loglevel error -y -f x11grab -video_size 1280x720 -i "$DISPLAY" -frames:v 1 "$OUT/$1.png" 2>/dev/null
  ffmpeg -loglevel info -i "$OUT/$1.png" -vf "signalstats,metadata=print:key=lavfi.signalstats.YAVG" -f null - 2>&1 \
    | sed -n 's/.*YAVG=\([0-9.]*\).*/\1/p' | tail -1
}
# A frame only counts as rendered if the game is actually running (an empty X screen is not a pass).
lit() { pgrep -x Funkin >/dev/null || { echo "      (game process is not running)"; return 1; }; not_black "$1"; }
not_black() { python3 -c "import sys; sys.exit(0 if float('${1:-0}') > 12 else 1)"; }
rss_mb() { ps -C Funkin -o rss= | sort -n | tail -1 | awk '{printf "%d", $1/1024}'; }

run_game() { # label envassignments...  -> sets LOG
  local label="$1"; shift
  LOG="$OUT/$label.log"
  pkill -9 -x Funkin 2>/dev/null; sleep 1
  (cd "$BIN" && env ${GOLDEN_TEST_ENV:-} "$@" stdbuf -o0 -e0 ./Funkin > "$LOG" 2>&1 &)
  sleep 2
}

echo "== Pass 1: normal startup (GE-001 fallback active) =="
run_game normal -u GOLDEN_ADVANCED_BLEND -u GOLDEN_SAFE_BLEND
wait_for "$LOG" "TitleState" 1 90; check "game boots to the title screen" $?
sleep 3
W=$(xdotool search --name "Golden Engine" 2>/dev/null | head -1)
[ -n "$W" ] && pgrep -x Funkin >/dev/null; check "window title is \"Golden Engine\"" $?
grep -a "GL renderer" "$LOG" | sed 's/\x1b\[[0-9;]*m//g' | head -1 | sed 's/^/      /'
# The intro (credits on black, timed to music) takes ~13s before the title screen is drawn.
sleep 16
m=$(luma 01-title); echo "      title luma=$m"; lit "$m"; check "title screen renders, not black (GE-001)" $?
[ "$(count "$LOG" "started song at")" = 0 ]; check "normal startup did not auto-start a song" $?
[ "$(count "$LOG" "PlayState")" = 0 ]; check "normal startup did not enter PlayState" $?

xdotool windowactivate --sync "$W" 2>/dev/null; sleep 0.3
xdotool keydown Return; sleep 0.1; xdotool keyup Return
wait_for "$LOG" "Idle -> EnteringMainMenu" 1 30; check "Enter on the title goes to the main menu" $?
sleep 3
m=$(luma 02-main-menu); echo "      main menu luma=$m"; lit "$m"; check "main menu renders, not black" $?
[ "$(count "$LOG" "started song at")" = 0 ]; check "main menu reached without starting a song" $?
pgrep -x Funkin >/dev/null; check "game still running (no crash)" $?
echo "      memory: $(rss_mb) MB RSS at main menu"
bad=$(clean_log "$LOG" | grep -ciE "uncaught|null object reference|segmentation|CRITICAL ERROR"); [ "$bad" = 0 ]; check "no uncaught errors in log ($bad)" $?

echo; echo "== Pass 2: LibVLC unavailable (must degrade gracefully, not abort the game) =="
# libvlc cannot start without its plugins; hxvlc's Handle.init() then throws. Golden Engine catches it.
run_game novlc VLC_PLUGIN_PATH=/nonexistent
wait_for "$LOG" "TitleState" 1 90; check "game reaches the title screen without LibVLC" $?
sleep 6
pgrep -x Funkin >/dev/null; check "game keeps running without LibVLC (no abort)" $?
[ "$(count "$LOG" "could not be initialized\|failed to initialize")" -ge 1 ]; check "missing LibVLC is reported in the log" $?

echo; echo "== Control: fallback disabled (informational — shows whether GE-001 reproduces here) =="
run_game control GOLDEN_ADVANCED_BLEND=1
if wait_for "$LOG" "TitleState" 1 90; then
  sleep 19; m=$(luma 03-control-title)
  if lit "$m"; then echo "INFO  control title luma=$m: NOT black — GE-001 does not reproduce on this machine, so pass 1 proves nothing about the fix here"
  else echo "INFO  control title luma=$m: BLACK — GE-001 reproduces without the fallback, so pass 1 above is a real test of the fix"; fi
else echo "INFO  control run did not reach the title screen"; fi

if [ "$FAIL" != 0 ]; then echo; echo "--- last 25 log lines (normal run) ---"; clean_log "$OUT/normal.log" | tail -25; fi
echo; echo "$PASS passed, $FAIL failed — screenshots and logs in $OUT"
[ "$FAIL" = 0 ]
