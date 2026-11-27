#!/usr/bin/env bash
# Golden Engine — runtime tests for Mod Manager actions not covered by golden-ui-linux.sh:
# enable all / disable all, duplicate, delete (to trash, with confirmation), dependency and conflict
# reports, zip export and import through the REAL native file dialogs (driven via zenity), the Tab
# mod selector toggle + apply, and Options shortcut rebinding + reset.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="${1:-$ROOT/export/release/linux/bin}"
OUT="$ROOT/golden/tests/results/mods-extra"; mkdir -p "$OUT"
export DISPLAY="${GOLDEN_TEST_DISPLAY:-:91}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/golden-xdg}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
LOG="$OUT/game.log"; PASS=0; FAIL=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; PASS=$((PASS+1)); else echo "FAIL  $1 ${3:-}"; FAIL=$((FAIL+1)); fi; }
clean_log() { sed 's/\x1b\[[0-9;]*m//g' "$LOG"; }
count() { clean_log | grep -c -- "$1"; }
wait_for() { local end=$((SECONDS + $3)); while [ $SECONDS -lt $end ]; do [ "$(count "$1")" -ge "$2" ] && return 0; sleep 0.5; done; return 1; }
win() { xdotool search --name "Golden Engine" | head -1; }
key() { xdotool windowactivate --sync "$(win)" 2>/dev/null; sleep 0.2
  for k in "$@"; do xdotool keydown "$k"; sleep 0.08; xdotool keyup "$k"; sleep 0.35; done; }
jsonget() { python3 -c "import json,sys; d=json.load(open('$1')); print(eval('d'+sys.argv[1]))" "$2" 2>/dev/null; }
shot() { import -window root "$OUT/$1.png"; }
# Wait for a zenity file dialog with the given title, then type a path into it and confirm.
dialog_path() { # title path open|save
  local w="" end=$((SECONDS + 15))
  while [ $SECONDS -lt $end ]; do w=$(xdotool search --name "$1" 2>/dev/null | head -1); [ -n "$w" ] && break; sleep 0.3; done
  [ -z "$w" ] && return 1
  sleep 1; xdotool windowactivate --sync "$w" 2>/dev/null; sleep 0.3
  [ "$3" = save ] && { xdotool key ctrl+a; sleep 0.2; }
  xdotool type --delay 60 -- "$2"; sleep 1; xdotool key shift+End Delete; sleep 0.5; shot "dialog-${1// /-}"; xdotool key Return; sleep 1
  return 0
}

Xvfb "$DISPLAY" -screen 0 1280x720x24 -nolisten tcp >/dev/null 2>&1 & XVFB=$!
sleep 1; openbox >/dev/null 2>&1 & WM=$!
# An audio sink is required: FNF's title/menu timing follows the music clock.
pulseaudio --check 2>/dev/null || pulseaudio -D --exit-idle-time=-1 -n --load=module-native-protocol-unix --load="module-null-sink sink_name=golden_test" >/dev/null 2>&1
BACKUP="$OUT/user-backup"; rm -rf "$BACKUP"; mkdir -p "$BACKUP"
for f in mods golden-mods.json golden-settings.json; do [ -e "$BIN/$f" ] && mv "$BIN/$f" "$BACKUP/$f"; done
restore() { pkill -9 -x Funkin 2>/dev/null; pkill -9 zenity 2>/dev/null; rm -rf "$BIN/mods" "$BIN/golden-mods.json" "$BIN/golden-settings.json"
  for f in mods golden-mods.json golden-settings.json; do [ -e "$BACKUP/$f" ] && mv "$BACKUP/$f" "$BIN/$f"; done; kill $WM $XVFB 2>/dev/null; }
trap restore EXIT
EXP="$OUT/exported"; rm -rf "$EXP"; mkdir -p "$EXP"

mkdir -p "$BIN/mods"
for m in alpha beta; do python3 "$ROOT/golden/tests/make_test_mod.py" "$BIN/mods" $m "Mod ${m^}" >/dev/null; done
# beta requires a missing mod and replaces the same data file as alpha -> dependency + conflict reports
python3 - "$BIN/mods" <<'PY'
import json, sys, os
m = sys.argv[1]
p = os.path.join(m, "beta", "_polymod_meta.json"); d = json.load(open(p)); d["dependencies"] = {"missing-lib": ">=1.0.0"}; json.dump(d, open(p, "w"))
for mod in ("alpha", "beta"):
    os.makedirs(os.path.join(m, mod, "data", "stages"), exist_ok=True)
    json.dump({"version": "1.0.1", "name": mod, "props": [], "characters": {}}, open(os.path.join(m, mod, "data", "stages", "shared-stage.json"), "w"))
PY
echo '{"developerMode":true}' > "$BIN/golden-settings.json"

(cd "$BIN" && ./Funkin > "$LOG" 2>&1 &)
wait_for "TitleState" 1 60; check "game boots" $?
sleep 16; key Return; wait_for "Idle -> EnteringMainMenu" 1 20
sleep 2; key Down Down Return
wait_for "Mod Manager opened: 2 installed" 1 20; check "Mod Manager opens with 2 mods" $?
wait_for 'beta: DEPENDENCY: Requires mod "missing-lib"' 1 3; check "missing dependency reported for beta" $?
wait_for 'CONFLICT: Replaces data/stages/shared-stage.json' 1 3; check "data-file conflict between alpha and beta reported" $?
[ "$(count 'CONFLICT: .*README')" = 0 ]; check "README files are not reported as conflicts" $?

sleep 1.5; key d; sleep 0.5
[ "$(jsonget "$BIN/golden-mods.json" "['mods']['alpha']['enabled']")$(jsonget "$BIN/golden-mods.json" "['mods']['beta']['enabled']")" = "FalseFalse" ]; check "D disables all mods (persisted)" $?
key a; sleep 0.5
[ "$(jsonget "$BIN/golden-mods.json" "['mods']['alpha']['enabled']")$(jsonget "$BIN/golden-mods.json" "['mods']['beta']['enabled']")" = "TrueTrue" ]; check "A enables all mods (persisted)" $?

key c   # duplicate alpha (selected first)
wait_for 'duplicated to "alpha-copy"' 1 5; check "C duplicates the selected mod" $?
[ "$(jsonget "$BIN/mods/alpha-copy/_polymod_meta.json" "['title']")" = "Mod Alpha (Copy)" ]; check "duplicate gets ' (Copy)' title" $?

key Delete; sleep 1; shot 01-delete-confirm; key y
wait_for 'deleted "alpha-copy"' 1 5; check "Delete + Y deletes the selected mod (the copy)" $?
[ ! -d "$BIN/mods/alpha-copy" ] && ls -d "$BIN/mods/.trash/alpha-copy-"* >/dev/null 2>&1; check "deleted mod moved to mods/.trash" $?
key Delete; sleep 1; key n; sleep 1
[ -d "$BIN/mods/alpha" ] && [ "$(count 'deleted "alpha"')" = 0 ]; check "Delete + N cancels (mod kept)" $?

key Up; sleep 0.3   # back to alpha if selection moved
key e
dialog_path "Export mod" "$EXP/alpha-export.zip" save; check "export opens the native save dialog" $?
wait_for 'exported "' 1 10; check "E exports the mod" $?
python3 -c "import zipfile,sys; z=zipfile.ZipFile(sys.argv[1]); n=z.namelist(); sys.exit(0 if '_polymod_meta.json' in n and any(x.startswith('scripts/') for x in n) else 1)" "$(ls "$EXP"/*.zip | head -1)" 2>/dev/null; check "exported zip contains manifest + scripts at the zip root" $?

# Import: a zip whose files sit in one top-level folder
python3 - "$EXP/imported-pack.zip" <<'PY'
import zipfile, json, sys
z = zipfile.ZipFile(sys.argv[1], "w")
z.writestr("Cool Pack/_polymod_meta.json", json.dumps({"title": "Cool Pack", "api_version": "0.8.7", "mod_version": "2.0.0"}))
z.writestr("Cool Pack/data/levels/readme.txt", "x")
z.writestr("../evil.txt", "should never be written")
z.close()
PY
key i
dialog_path "Import mod" "$EXP/imported-pack.zip" open; check "import opens the native open dialog" $?
wait_for 'imported "cool-pack"' 1 10; check "I imports a zip (top-level folder -> mods/cool-pack)" $?
[ "$(jsonget "$BIN/mods/cool-pack/_polymod_meta.json" "['mod_version']")" = "2.0.0" ]; check "imported manifest intact" $?
[ ! -e "$BIN/evil.txt" ] && [ ! -e "$BIN/mods/evil.txt" ]; check "path-traversal entry in the zip is refused" $?

key Escape; wait_for "Idle -> EnteringMainMenu" 2 20

# --- Tab mod selector toggle + apply ----------------------------------------------------------
sleep 2; key Tab; wait_for "Mod selector shortcut" 1 5
sleep 0.5; key space
wait_for 'Mod selector: disabled "alpha"' 1 5; check "selector: Space toggles the selected mod" $?
[ "$(jsonget "$BIN/golden-mods.json" "['mods']['alpha']['enabled']")" = "False" ]; check "selector toggle persisted" $?
key Return
wait_for "Mod selector: applying changes (reload)" 1 5; check "selector: Enter applies (reload)" $?
wait_for "Mods enabled: cool-pack; disabled: alpha" 1 15; check "after apply, alpha is no longer loaded (beta stays out: missing dependency)" $?

# --- Options: rebind Chart Editor key, then reset developer settings ----------------------------
sleep 3; key Down Down Down Return; sleep 2   # main menu remembers "mods" (2); options is index 5
key Down Return; sleep 1                          # GOLDEN ENGINE page
key Down Down Down Down Return; sleep 0.6; key f; sleep 0.6
wait_for "Options: Chart Editor key -> F" 1 5; check "Chart Editor key rebound to F" $?
[ "$(jsonget "$BIN/golden-settings.json" "['chartEditorKey']")" = "F" ]; check "rebinding persisted" $?
key Down Down Return Return; sleep 0.6
wait_for "Options: developer settings reset" 1 5; check "Reset (press twice) resets developer settings" $?
[ "$(jsonget "$BIN/golden-settings.json" "['developerMode']")$(jsonget "$BIN/golden-settings.json" "['chartEditorKey']")" = "FalseSEVEN" ]; check "reset: Developer Mode off, key back to SEVEN" $?

pgrep -x Funkin >/dev/null; check "no crash" $?
crashes=$(clean_log | grep -v "Enabling" | grep -ciE "uncaught|null object reference|segmentation|CRITICAL ERROR"); [ "$crashes" = 0 ]; check "no uncaught errors ($crashes)" $?
echo; echo "$PASS passed, $FAIL failed — log and screenshots in $OUT"
[ "$FAIL" = 0 ]
