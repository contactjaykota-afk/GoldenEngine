#!/usr/bin/env bash
# Golden Engine — Character Editor + Mod Asset Manager end-to-end test (real X11 input, real build).
source "$(dirname "$0")/lib-editor.sh"
editor_setup editors3
mkdir -p "$MOD/images/test" "$MOD/sounds" "$MOD/data/golden/events"
convert -size 64x48 xc:'#ff8800' "$MOD/images/test/orange.png"
cp "$ROOT/assets/preload/sounds/scrollMenu.ogg" "$MOD/sounds/blip.ogg" 2>/dev/null || cp "$(find "$ROOT/assets" -name 'scrollMenu.ogg' | head -1)" "$MOD/sounds/blip.ogg"
echo '{"version":1,"song":"x","tracks":[],"effects":[{"id":"a","type":"image","track":"Overlays","time":0,"duration":1,"ease":"linear","params":{"image":"does/not/exist"}}]}' > "$MOD/data/golden/events/x.json"
convert -size 32x32 xc:'#00aaff' "$OUT/import-me.png"

start_game; check "game boots" $?
to_hub; check "Editors hub opens" $?

# ---------------- Character Editor ----------------
open_editor "Character Editor"; check "Character Editor opens" $?
wait_for 'Character Editor: opened "bf"' 1 10; check "opens with Boyfriend (real game character)" $?
pick "Characters" "dad" "dad"; wait_for 'Character Editor: opened "dad"' 1 10; check "another character opens from the browser" $?
sleep 1; m=$(shot 01-char-dad); not_black "$m"; check "character preview renders (mean=$m)" $?
pick "Animations" "singLEFT" "singLEFT"; sleep 0.5; click_at 640 712
key Left Left Left; wait_for "singLEFT offset" 1 4; check "arrow keys nudge the selected animation's offset" $?
iclick "field:Scale"; combo ctrl+a; typetext "1.1"; key Return; sleep 0.3
iclick "field:Health colour"; combo ctrl+a; typetext "#00FF66"; key Return; sleep 0.3
combo ctrl+s; wait_for 'Saved to mod "edit-test"' 1 10; check "Ctrl+S saves the character" $?
python3 - "$MOD/data/characters/dad.json" <<'PY'; check "character JSON saved to the mod with the new scale and offsets" $?
import json,sys; d=json.load(open(sys.argv[1])); a=[x for x in d['animations'] if x['name']=='singLEFT'][0]
assert abs(d['scale']-1.1)<1e-6 and a['offsets'][0]!=0, (d['scale'], a)
PY
grep -q '"dad"' "$MOD/data/golden/healthcolors.json"; check "health colour saved" $?
git -C "$ROOT" diff --quiet -- assets/preload/data/characters/dad.json; check "original character file unchanged" $?
click "button:Test Play"; wait_for 'Test override: player character "dad"' 1 40; check "Test Play uses the edited character in a real song" $?
wait_for "Health colour for dad" 1 30; check "health bar uses the character's colour" $?
sleep 3; shot 02-char-gameplay >/dev/null
key F9; wait_for "Character Editor ready for input" 2 30; check "F9 returns to the Character Editor" $?
key Escape; wait_for "Editors hub ready for input" 2 20; sleep 1.5

# ---------------- Mod Asset Manager ----------------
open_editor "Mod Asset Manager"; check "Asset Manager opens" $?
wait_for "Asset Manager: .* entries in edit-test" 1 10; check "lists the mod's files" $?
click "button:Scan"; wait_for "Asset Manager scan: 1 missing" 1 10; check "scan finds the missing image referenced by the mod" $?
clean_log | grep "Asset Manager scan:" | tail -1 | grep -qE "[1-9][0-9]* unused"; check "scan lists unused assets" $?
pick "images/test" "orange.png" "orange"; wait_for "Asset Manager: selected images/test/orange.png" 1 5; check "selecting an image previews it" $?
sleep 0.5; m=$(shot 03-asset-image); not_black "$m"; check "image preview renders (mean=$m)" $?
iclick "field:New name"; combo ctrl+a; typetext "renamed.png"; key Return; sleep 0.3
iclick "button:Rename"; sleep 0.8
[ -f "$MOD/images/test/renamed.png" ] && [ ! -f "$MOD/images/test/orange.png" ]; check "Rename renames the file" $?
pick "sounds" "blip.ogg" "blip"; sleep 0.5; iclick "button:Play"; wait_for "Asset Manager: playing sounds/blip.ogg" 1 5; check "audio preview plays" $?
pick "images/test" "renamed.png" "renamed"; sleep 0.5
iclick "button:Delete"; sleep 1; key y; sleep 1
[ ! -f "$MOD/images/test/renamed.png" ] && ls "$BIN"/mods/.trash/edit-test/*/images/test/renamed.png >/dev/null 2>&1; check "Delete (confirmed) moves the file to mods/.trash" $?
pick "sounds" "blip.ogg" "blip"; sleep 0.3
click "button:Import..."; dialog_path "Import into" "$OUT/import-me.png"; check "Import opens the native file dialog" $?
wait_for "Asset Manager: imported 1 file" 1 10; check "a file is imported into the selected folder" $?
[ -f "$MOD/sounds/import-me.png" ]; check "imported file is in the mod folder" $?
finish
