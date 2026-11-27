#!/usr/bin/env bash
# Golden Engine — runtime test of the Golden menus in the real Linux build, driven with real X11
# keyboard input on a virtual display:
#   main menu Mods entry -> Mod Manager -> Create Mod wizard (typed input) -> generated mod validates
#   -> toggle enabled (persisted) -> Reload registers only enabled content -> Esc back
#   -> Options > Golden Engine: Developer Mode + UI volume persist -> Tab mod selector
#   -> Chart Editor shortcut (7) -> main menu Editors entry -> restart: settings survive
# User mods/settings next to the executable are backed up and restored.
#
# Requirements: xvfb openbox xdotool imagemagick python3   Usage: golden/tests/golden-ui-linux.sh [bin]
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="${1:-$ROOT/export/release/linux/bin}"
OUT="$ROOT/golden/tests/results/ui"
mkdir -p "$OUT"
export DISPLAY="${GOLDEN_TEST_DISPLAY:-:95}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/golden-xdg}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
LOG="$OUT/game.log"
PASS=0; FAIL=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; PASS=$((PASS+1)); else echo "FAIL  $1 ${3:-}"; FAIL=$((FAIL+1)); fi; }
clean_log() { sed 's/\x1b\[[0-9;]*m//g' "$LOG"; }
count() { clean_log | grep -c -- "$1"; }
wait_for() { local end=$((SECONDS + $3)); while [ $SECONDS -lt $end ]; do [ "$(count "$1")" -ge "$2" ] && return 0; sleep 0.5; done; return 1; }
win() { xdotool search --name "Golden Engine" | head -1; }
key() { xdotool windowactivate --sync "$(win)" 2>/dev/null; sleep 0.2
  for k in "$@"; do xdotool keydown "$k"; sleep 0.08; xdotool keyup "$k"; sleep 0.35; done; }
typetext() { xdotool windowactivate --sync "$(win)" 2>/dev/null; xdotool type --delay 60 "$1"; sleep 0.3; }
shot() { import -window root "$OUT/$1.png"; convert "$OUT/$1.png" -format '%[fx:mean]' info:; }
not_black() { python3 -c "import sys; sys.exit(0 if float('$1') > 0.05 else 1)"; }
jsonget() { python3 -c "import json,sys; d=json.load(open('$1')); print(eval('d'+sys.argv[1]))" "$2" 2>/dev/null; }

Xvfb "$DISPLAY" -screen 0 1280x720x24 -nolisten tcp >/dev/null 2>&1 & XVFB=$!
sleep 1
pulseaudio --check 2>/dev/null || pulseaudio -D --exit-idle-time=-1 -n --load=module-native-protocol-unix --load="module-null-sink sink_name=golden_test" >/dev/null 2>&1  # FNF timing follows the music clock
openbox >/dev/null 2>&1 & WM=$!

BACKUP="$OUT/user-backup"; rm -rf "$BACKUP"; mkdir -p "$BACKUP"
for f in mods golden-mods.json golden-settings.json; do [ -e "$BIN/$f" ] && mv "$BIN/$f" "$BACKUP/$f"; done
restore() {
  pkill -9 -x Funkin 2>/dev/null
  rm -rf "$BIN/mods" "$BIN/golden-mods.json" "$BIN/golden-settings.json"
  for f in mods golden-mods.json golden-settings.json; do [ -e "$BACKUP/$f" ] && mv "$BACKUP/$f" "$BIN/$f"; done
  kill $WM $XVFB 2>/dev/null
}
trap restore EXIT

start_game() {
  pkill -9 -x Funkin 2>/dev/null; sleep 0.5
  RUN=$(( ${RUN:-0} + 1 )); [ -f "$LOG" ] && mv "$LOG" "$OUT/game-run$((RUN-1)).log"
  (cd "$BIN" && ./Funkin > "$LOG" 2>&1 &)
  wait_for "TitleState" 1 60
}

# ---- 1. boot, main menu, Mods entry -------------------------------------------------------------
start_game; check "game boots" $?
sleep 16; key Return
wait_for "Idle -> EnteringMainMenu" 1 20; check "main menu reached" $?
sleep 2; m=$(shot 01-main-menu); not_black "$m"; check "main menu renders with Golden entries (mean=$m)" $?
wait_for "Menu music: goldenMenu" 1 3; check "Golden Engine menu music plays by default" $?
key Down Down Return
wait_for "Mod Manager opened: 0 installed" 1 20; check "Mods entry opens the Mod Manager (empty)" $?
sleep 1.5; m=$(shot 02-mod-manager-empty); not_black "$m"; check "Mod Manager renders (mean=$m)" $?

# ---- 2. Create Mod wizard -----------------------------------------------------------------------
key n; sleep 1
m=$(shot 03-create-wizard); not_black "$m"; check "Create Mod wizard renders (mean=$m)" $?
xdotool key --clearmodifiers ctrl+a 2>/dev/null; typetext "Test Mod"
key Tab Tab; typetext "Golden Tests"
key Return
wait_for "Created mod \"test-mod\"" 1 10; check "wizard creates mod folder 'test-mod' from typed title" $?
META="$BIN/mods/test-mod/_polymod_meta.json"
[ "$(jsonget "$META" "['title']")" = "Test Mod" ]; check "manifest title = typed title" $?
api=$(jsonget "$META" "['api_version']"); [[ "$api" =~ ^0\.8\.[0-9]+$ ]]; check "manifest api_version is the running game version ($api)" $?
[ "$(jsonget "$META" "['contributors'][0]['name']")" = "Golden Tests" ]; check "manifest author recorded" $?
[ -f "$BIN/mods/test-mod/scripts/events/TestModScreenFlashEvent.hxc" ]; check "template script renamed (.tmpl stripped, class substituted)" $?
grep -q "test-mod-screen-flash" "$BIN/mods/test-mod/scripts/events/TestModScreenFlashEvent.hxc"; check "template placeholders substituted" $?
! grep -rq "__MOD" "$BIN/mods/test-mod"; check "no unsubstituted placeholders left" $?
sleep 1; m=$(shot 04-mod-manager-created); not_black "$m"; check "Mod Manager shows the new mod (mean=$m)" $?

# ---- 3. enable/disable + reload -----------------------------------------------------------------
key space; sleep 0.5
[ "$(jsonget "$BIN/golden-mods.json" "['mods']['test-mod']['enabled']")" = "False" ]; check "Space disables the mod (golden-mods.json)" $?
key r
wait_for "Mod Manager: applying mod changes (reload)" 1 10
wait_for "Mods enabled: (none)" 1 15; check "reload with mod disabled loads no mods" $?
[ "$(count 'Loaded scripted song event: test-mod-screen-flash')" = 0 ]; check "disabled mod's scripted event NOT registered" $?
key space; sleep 0.5
[ "$(jsonget "$BIN/golden-mods.json" "['mods']['test-mod']['enabled']")" = "True" ]; check "Space re-enables the mod" $?
key r
wait_for "Mods enabled: test-mod" 1 15; check "reload with mod enabled loads it" $?
wait_for "Loaded scripted song event: test-mod-screen-flash" 1 10; check "enabled mod's scripted event registered after reload" $?
key Escape
wait_for "Idle -> EnteringMainMenu" 2 20; check "Esc returns to the main menu" $?

# ---- 4. Options > Golden Engine -----------------------------------------------------------------
sleep 1.5; key Down Down Down Return   # menu remembers "mods" (2); options is 3 further down (editors, merch, options)
sleep 2; key Down Return       # PREFERENCES -> GOLDEN ENGINE
sleep 1; m=$(shot 05-golden-options); not_black "$m"; check "Golden Engine options page renders (mean=$m)" $?
key Return; sleep 0.5          # Developer Mode ON
[ "$(jsonget "$BIN/golden-settings.json" "['developerMode']")" = "True" ]; check "Developer Mode toggled on and saved" $?
key Down Left Left Left; sleep 0.5
[ "$(jsonget "$BIN/golden-settings.json" "['uiVolume']")" = "0.7" ]; check "UI volume lowered to 70% and saved" $?
key Down Return; sleep 0.8     # Menu Music -> classic
[ "$(jsonget "$BIN/golden-settings.json" "['menuMusic']")" = "classic" ]; check "Menu Music switched to classic and saved" $?
key Return; sleep 0.8          # Menu Music -> golden again
[ "$(jsonget "$BIN/golden-settings.json" "['menuMusic']")" = "golden" ]; check "Menu Music switched back to Golden" $?
key Down Return; sleep 0.5     # Performance Monitor ON
[ "$(jsonget "$BIN/golden-settings.json" "['perfMonitor']")" = "True" ]; check "Performance monitor enabled and saved" $?
sleep 1; m=$(shot 06-dev-mode-monitor); check "screenshot with performance monitor taken" 0
key Escape; sleep 1; key Escape
wait_for "Idle -> EnteringMainMenu" 3 20; check "back to main menu from options" $?

# ---- 5. Developer Mode shortcuts ----------------------------------------------------------------
sleep 1.5; key Tab
wait_for "Mod selector shortcut" 1 5; check "Tab opens the mod selector in Developer Mode" $?
sleep 1; m=$(shot 07-mod-selector); not_black "$m"; check "mod selector renders (mean=$m)" $?
before=$(count "Idle -> Exiting")
key Escape; sleep 3
[ "$(count "Idle -> Exiting")" = "$before" ]; check "Esc closes the selector without leaving the main menu" $?
m=$(shot 07b-after-selector); not_black "$m"; check "main menu still shown after closing selector (mean=$m)" $?
key F8
wait_for "Console opened" 1 5; check "F8 opens the runtime console in Developer Mode" $?
sleep 1; m=$(shot 07d-console); not_black "$m"; check "console renders (mean=$m)" $?
key F8
wait_for "Console closed" 1 5; check "F8 closes the console" $?

# ---- 6. persistence across restart --------------------------------------------------------------
start_game; check "game restarts" $?
wait_for "Settings: developerMode=true uiVolume=0.7 perfMonitor=true" 1 10; check "Golden settings survive a restart" $?
wait_for "Mods enabled: test-mod" 1 10; check "enabled mod still loads after restart" $?

# ---- 7. Chart Editor shortcut + Editors entry (Developer Mode on) --------------------------------
sleep 16; key Return
wait_for "Idle -> EnteringMainMenu" 1 20
sleep 3; key 7
wait_for "Chart Editor shortcut" 1 5; check "7 opens the Chart Editor in Developer Mode" $?
wait_for "ChartEditorState" 1 30; check "Chart Editor state reached" $?
sleep 4; m=$(shot 07c-chart-editor); not_black "$m"; check "Chart Editor renders (mean=$m)" $?
start_game; sleep 16; key Return
wait_for "Idle -> EnteringMainMenu" 1 20
sleep 2; key Down Down Down Return
sleep 2; m=$(shot 08-editors); not_black "$m"; check "Editors entry opens the editors menu (mean=$m)" $?

# ---- 8. Mouse navigation on a fresh main menu ---------------------------------------------------
start_game; sleep 16; key Return
wait_for "Idle -> EnteringMainMenu" 1 20; sleep 2.5
W=$(win); eval "$(xdotool getwindowgeometry --shell "$W")"
xdotool mousemove --window "$W" 640 300; sleep 0.12; xdotool click 1
wait_for "Idle -> EnteringFreeplay" 1 15; check "mouse: hovering + clicking FREEPLAY opens Freeplay" $?
sleep 2; m=$(shot 09-freeplay-by-mouse); not_black "$m"; check "Freeplay renders after mouse click (mean=$m)" $?

pgrep -x Funkin >/dev/null; check "game still running (no crash)" $?
crashes=$(clean_log | grep -v "Enabling" | grep -ciE "uncaught|null object reference|segmentation|CRITICAL ERROR"); [ "$crashes" = 0 ]; check "no uncaught errors in log ($crashes)" $?

echo; echo "$PASS passed, $FAIL failed — screenshots and logs in $OUT"
[ "$FAIL" = 0 ]
