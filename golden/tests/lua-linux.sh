#!/usr/bin/env bash
# Golden Engine — runtime test of Lua scripting in real gameplay (Linux build, virtual display).
# Creates mods with Lua scripts, plays Bopeebo, and checks from the log that:
#   callbacks run (onCreate/onSongStart/onBeatHit/onNoteHit/onNoteMiss/onEvent) with correct data,
#   the API works (getSongName/getDifficulty/getBPM/cameraFlash/setVar/getVar),
#   the sandbox removes io/os.execute/require, a syntax error is reported without crashing,
#   an infinite loop is stopped by the timeout, and a DISABLED mod's Lua never runs.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="${1:-$ROOT/export/release/linux/bin}"
OUT="$ROOT/golden/tests/results/lua"; mkdir -p "$OUT"
export DISPLAY="${GOLDEN_TEST_DISPLAY:-:94}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/golden-xdg}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
LOG="$OUT/game.log"; PASS=0; FAIL=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; PASS=$((PASS+1)); else echo "FAIL  $1 ${3:-}"; FAIL=$((FAIL+1)); fi; }
clean_log() { sed 's/\x1b\[[0-9;]*m//g' "$LOG"; }
count() { clean_log | grep -c -- "$1"; }
wait_for() { local end=$((SECONDS + $3)); while [ $SECONDS -lt $end ]; do [ "$(count "$1")" -ge "$2" ] && return 0; sleep 0.5; done; return 1; }
key() { xdotool windowactivate --sync "$(xdotool search --name 'Golden Engine' | head -1)" 2>/dev/null; sleep 0.2
  for k in "$@"; do xdotool keydown "$k"; sleep 0.08; xdotool keyup "$k"; sleep 0.35; done; }

Xvfb "$DISPLAY" -screen 0 1280x720x24 -nolisten tcp >/dev/null 2>&1 & XVFB=$!
sleep 1; openbox >/dev/null 2>&1 & WM=$!
BACKUP="$OUT/user-backup"; rm -rf "$BACKUP"; mkdir -p "$BACKUP"
for f in mods golden-mods.json; do [ -e "$BIN/$f" ] && mv "$BIN/$f" "$BACKUP/$f"; done
restore() { pkill -9 -x Funkin 2>/dev/null; rm -rf "$BIN/mods" "$BIN/golden-mods.json"
  for f in mods golden-mods.json; do [ -e "$BACKUP/$f" ] && mv "$BACKUP/$f" "$BIN/$f"; done; kill $WM $XVFB 2>/dev/null; }
trap restore EXIT

mkdir -p "$BIN/mods"
python3 "$ROOT/golden/tests/make_test_mod.py" "$BIN/mods" luamod "Lua Test" >/dev/null
python3 "$ROOT/golden/tests/make_test_mod.py" "$BIN/mods" luaoff "Lua Disabled" >/dev/null
mkdir -p "$BIN/mods/luamod/scripts/lua" "$BIN/mods/luamod/data/songs/bopeebo" "$BIN/mods/luaoff/scripts/lua"
cat > "$BIN/mods/luamod/scripts/lua/main.lua" <<'LUA'
local beats = 0
function onCreate()
  print("LUAT onCreate song=" .. tostring(getSongName()) .. " diff=" .. tostring(getDifficulty()))
  print("LUAT sandbox io=" .. tostring(io) .. " exec=" .. tostring(os.execute) .. " req=" .. tostring(require) .. " clock=" .. type(os.clock))
  setVar("shared", 42)
end
function onSongStart() print("LUAT onSongStart bpm=" .. getBPM()); cameraFlash("#FF0000", 0.3) end
function onBeatHit(b) beats = beats + 1; if beats <= 2 then print("LUAT beat " .. b) end end
function onNoteHit(d, isPlayer, kind) if not hit then hit = true; print("LUAT noteHit dir=" .. d .. " player=" .. tostring(isPlayer)) end end
function onNoteMiss(d) if not missed then missed = true; print("LUAT noteMiss dir=" .. d) end end
function onEvent(name, value) if not ev then ev = true; print("LUAT event " .. tostring(name)) end end
LUA
cat > "$BIN/mods/luamod/data/songs/bopeebo/song.lua" <<'LUA'
function onSongStart() print("LUAT per-song script, shared=" .. tostring(getVar("shared"))) end
LUA
echo 'function onCreate( print("broken"' > "$BIN/mods/luamod/scripts/lua/broken.lua"
cat > "$BIN/mods/luamod/scripts/lua/zloop.lua" <<'LUA'
function onSongStart() local t = os.clock(); while true do end end
function onBeatHit(b) if b == 4 then print("LUAT still alive after timeout") end end
LUA
# Chart override with one "Lua Script" event at 3 s -> scripts/events/luatest.lua
python3 - "$ROOT" "$BIN/mods/luamod/data/songs/bopeebo/bopeebo-chart.json" <<'PY'
import json, sys, glob
src = glob.glob(sys.argv[1] + "/assets/**/songs/bopeebo/bopeebo-chart.json", recursive=True)[0]
c = json.load(open(src))
c.setdefault("events", []).append({"t": 3000, "e": "golden-lua", "v": {"script": "luatest", "value": "hello-event"}})
c["events"].sort(key=lambda e: e["t"])
json.dump(c, open(sys.argv[2], "w"))
PY
mkdir -p "$BIN/mods/luamod/scripts/events"
echo 'function onEvent(name, value) print("LUAT chart event script ran value=" .. tostring(value) .. " t=" .. math.floor(getSongPosition())) end' > "$BIN/mods/luamod/scripts/events/luatest.lua"
echo 'function onCreate() print("LUAT DISABLED MOD RAN") end' > "$BIN/mods/luaoff/scripts/lua/off.lua"
printf '{"version":1,"order":["luamod","luaoff"],"mods":{"luamod":{"enabled":true},"luaoff":{"enabled":false}}}\n' > "$BIN/golden-mods.json"

(cd "$BIN" && ./Funkin > "$LOG" 2>&1 &)
wait_for "TitleState" 1 60; check "game boots" $?
sleep 16; key Return; wait_for "Idle -> EnteringMainMenu" 1 20
sleep 2; key Down Return; wait_for "Idle -> EnteringFreeplay" 1 20
sleep 3; key Down Return
wait_for "started song at" 1 40; check "Bopeebo starts" $?
wait_for "LUAT beat" 2 30
sleep 4
wait_for "Song \"bopeebo\": 4 script(s) loaded" 1 1; check "4 Lua scripts of the enabled mod loaded (global + per-song)" $?
[ "$(count 'LUAT onCreate song=bopeebo diff=normal')" -ge 1 ]; check "onCreate runs; getSongName/getDifficulty correct" $?
[ "$(count 'LUAT sandbox io=nil exec=nil req=nil clock=function')" -ge 1 ]; check "sandbox: io/os.execute/require removed, os.clock kept" $?
[ "$(count 'LUAT onSongStart bpm=100')" -ge 1 ]; check "onSongStart runs; getBPM = 100" $?
[ "$(count 'LUAT per-song script, shared=42')" -ge 1 ]; check "per-song script runs; setVar/getVar shared between scripts" $?
[ "$(count 'LUAT beat')" -ge 2 ]; check "onBeatHit receives beats" $?
[ "$(count 'LUAT noteHit dir=')" -ge 1 ]; check "onNoteHit runs (opponent notes)" $?
wait_for "LUAT noteMiss dir=" 1 30; check "onNoteMiss runs (no input)" $?
[ "$(count 'LUAT event ')" -ge 1 ]; check "onEvent receives chart events" $?
[ "$(count 'broken.lua.*(in load)')" -ge 1 ]; check "syntax error reported with script name" $?
[ "$(count 'timed out')" -ge 1 ]; check "infinite loop stopped by the timeout" $?
wait_for "LUAT still alive after timeout" 1 10; check "game keeps running after a timed-out script" $?
wait_for "LUAT chart event script ran value=hello-event" 1 20; check "\"Lua Script\" chart event runs scripts/events/luatest.lua with its value" $?
t=$(clean_log | grep -o "LUAT chart event script ran value=hello-event t=[0-9]*" | head -1 | grep -o "[0-9]*$")
[ -n "$t" ] && [ "$t" -ge 2900 ] && [ "$t" -le 3300 ]; check "chart event fired on time (song position ${t:-?} ms, expected ~3000)" $?
[ "$(count 'DISABLED MOD RAN')" = 0 ]; check "disabled mod's Lua never runs" $?
pgrep -x Funkin >/dev/null; check "no crash" $?
echo; echo "$PASS passed, $FAIL failed — log in $LOG"
[ "$FAIL" = 0 ]
