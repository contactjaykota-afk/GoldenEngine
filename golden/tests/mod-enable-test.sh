#!/usr/bin/env bash
# Golden Engine — regression test: only ENABLED mods load.
#
# Creates two mods from the starter template (moda, modb), then for each configuration
#   A on / B off,  A off / B on,  both off,  both on
# writes golden-mods.json, starts the real game, and checks from the game log that exactly the
# enabled mods were loaded and that ONLY their content
# (a week data file and a scripted custom event) was registered. Also checks: a corrupted golden-mods.json does not crash the game, a mod with
# broken metadata is skipped and reported, and disabled mod folders are left untouched.
#
# Usage: golden/tests/mod-enable-test.sh [path/to/bin]     (needs xvfb, python3)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="${1:-$ROOT/export/release/linux/bin}"
OUT="$ROOT/golden/tests/results/mods"
mkdir -p "$OUT"
export DISPLAY="${GOLDEN_TEST_DISPLAY:-:96}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/golden-xdg}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
PASS=0; FAIL=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; PASS=$((PASS+1)); else echo "FAIL  $1 ${3:-}"; FAIL=$((FAIL+1)); fi; }

Xvfb "$DISPLAY" -screen 0 1280x720x24 -nolisten tcp >/dev/null 2>&1 & XVFB=$!
sleep 1
pulseaudio --check 2>/dev/null || pulseaudio -D --exit-idle-time=-1 -n --load=module-native-protocol-unix --load="module-null-sink sink_name=golden_test" >/dev/null 2>&1  # FNF timing follows the music clock
EXTRA_ENV=()
glxinfo -B 2>/dev/null | grep -q llvmpipe && EXTRA_ENV=(MESA_EXTENSION_OVERRIDE="-GL_KHR_blend_equation_advanced -GL_KHR_blend_equation_advanced_coherent")

# Back up any existing mods so the test never destroys user data.
BACKUP="$OUT/user-mods-backup"
rm -rf "$BACKUP"; mkdir -p "$BACKUP"
[ -d "$BIN/mods" ] && mv "$BIN/mods" "$BACKUP/mods"
[ -f "$BIN/golden-mods.json" ] && mv "$BIN/golden-mods.json" "$BACKUP/golden-mods.json"
restore() {
  pkill -9 -f "$BIN/Funkin" 2>/dev/null; pkill -9 -x Funkin 2>/dev/null
  rm -rf "$BIN/mods" "$BIN/golden-mods.json" "$BIN/golden-mods.json.bak"
  [ -d "$BACKUP/mods" ] && mv "$BACKUP/mods" "$BIN/mods"
  [ -f "$BACKUP/golden-mods.json" ] && mv "$BACKUP/golden-mods.json" "$BIN/golden-mods.json"
  kill $XVFB 2>/dev/null
}
trap restore EXIT

mkdir -p "$BIN/mods"
python3 "$ROOT/golden/tests/make_test_mod.py" "$BIN/mods" moda "Mod A" >/dev/null
python3 "$ROOT/golden/tests/make_test_mod.py" "$BIN/mods" modb "Mod B" >/dev/null
HASH_B_BEFORE=$(cd "$BIN/mods/modb" && find . -type f -exec sha1sum {} + | sort | sha1sum)

run_game() { # name -> runs the game until registries are loaded, log in $OUT/<name>.log
  local log="$OUT/$1.log"
  pkill -9 -x Funkin 2>/dev/null; sleep 0.5
  (cd "$BIN" && env "${EXTRA_ENV[@]}" ./Funkin > "$log" 2>&1 &)
  for _ in $(seq 1 60); do grep -q "TitleState" "$log" 2>/dev/null && break; sleep 0.5; done
  sleep 1
  pkill -9 -x Funkin 2>/dev/null; sleep 0.5
  sed -i 's/\x1b\[[0-9;]*m//g' "$log"
}
set_states() { # a b  (true/false)
  printf '{"version":1,"order":["moda","modb"],"mods":{"moda":{"enabled":%s},"modb":{"enabled":%s}}}\n' "$1" "$2" > "$BIN/golden-mods.json"
}
content_of() { # log mod -> number of registry/script lines mentioning that mod's content ids
  grep -cE "Level\($2-week\)|scripted song event: $2-screen-flash" "$1"
}
expect() { # name a_enabled b_enabled
  local log="$OUT/$1.log" a b
  a=$(content_of "$log" moda); b=$(content_of "$log" modb)
  if [ "$2" = true ]; then [ "$a" -ge 2 ]; check "$1: Mod A content registered ($a items)" $?; else [ "$a" = 0 ]; check "$1: Mod A content NOT registered ($a items)" $?; fi
  if [ "$3" = true ]; then [ "$b" -ge 2 ]; check "$1: Mod B content registered ($b items)" $?; else [ "$b" = 0 ]; check "$1: Mod B content NOT registered ($b items)" $?; fi
  grep -q "TitleState" "$log"; check "$1: game reached the title screen" $?
}

set_states true false;  run_game a-on-b-off; expect a-on-b-off true false
grep -q '"enabled":false' "$BIN/golden-mods.json" || grep -q '"enabled": false' "$BIN/golden-mods.json"; check "disabled state persisted across restart" $?
set_states false true;  run_game a-off-b-on; expect a-off-b-on false true
set_states false false; run_game none;       expect none false false
set_states true true;   run_game both;       expect both true true

HASH_B_AFTER=$(cd "$BIN/mods/modb" && find . -type f -exec sha1sum {} + | sort | sha1sum)
[ "$HASH_B_BEFORE" = "$HASH_B_AFTER" ]; check "disabling a mod never modified its files" $?

# New folder appears -> auto-registered and enabled; state file updated.
python3 "$ROOT/golden/tests/make_test_mod.py" "$BIN/mods" modc "Mod C" >/dev/null
run_game new-mod
[ "$(content_of "$OUT/new-mod.log" modc)" -ge 2 ]; check "a newly added mod folder is enabled and loaded" $?
grep -q '"modc"' "$BIN/golden-mods.json"; check "new mod recorded in golden-mods.json" $?

# Corrupted state file -> no crash, backup kept, mods load with defaults.
echo '{ this is not json' > "$BIN/golden-mods.json"
run_game corrupt-list
grep -q "TitleState" "$OUT/corrupt-list.log"; check "corrupted golden-mods.json does not stop the game" $?
[ -f "$BIN/golden-mods.json.bak" ]; check "corrupted state file backed up as .bak" $?

# Mod with broken metadata -> skipped, others still load, no crash.
echo '{ "title": "Broken", ' > "$BIN/mods/modc/_polymod_meta.json"
run_game broken-meta
grep -q "modc: not loaded" "$OUT/broken-meta.log"; check "mod with invalid metadata is skipped with a reason" $?
[ "$(content_of "$OUT/broken-meta.log" moda)" -ge 2 ]; check "other mods still load when one mod is broken" $?
grep -q "TitleState" "$OUT/broken-meta.log"; check "broken mod does not stop the game" $?

# Mod made for an incompatible game version -> skipped with a reason.
sed -i 's/"api_version": "0.8.7"/"api_version": "0.9.5"/' "$BIN/mods/modb/_polymod_meta.json"
set_states true true; run_game wrong-api
grep -q "modb: not loaded .*accepts" "$OUT/wrong-api.log"; check "incompatible api_version is skipped with a reason" $?
[ "$(content_of "$OUT/wrong-api.log" modb)" = 0 ]; check "incompatible mod content not registered" $?

echo; echo "$PASS passed, $FAIL failed — logs in $OUT"
[ "$FAIL" = 0 ]
