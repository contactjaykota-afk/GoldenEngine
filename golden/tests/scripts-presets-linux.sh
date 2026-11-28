#!/usr/bin/env bash
# Golden Engine — Event System: Haxe (HScript) module created for a song runs in real gameplay; custom
# effect presets are saved and reused.
source "$(dirname "$0")/lib-editor.sh"
editor_setup scriptspresets
start_game; check "game boots" $?
to_hub; check "Editors hub opens" $?
sleep 1; m=$(shot 01-hub-fnf-title); not_black "$m"; check "hub renders with FNF lettering (mean=$m)" $?
open_editor "Event System"; check "Event System opens" $?
pick "Scripts" "New Haxe module for this song..." "Haxe"; wait_for "Haxe module scripts/modules/GoldenBopeeboModule.hxc created" 1 5
check "a Haxe module for the song is created" $?
grep -q "class GoldenBopeeboModule extends Module" "$MOD/scripts/modules/GoldenBopeeboModule.hxc"; check "module file is an FNF HScript module" $?
pick "Presets" "Impact Zoom" "Impact"; wait_for "added zoom+zoom+shake" 1 5; check "preset added" $?
iclick "field:Preset name"; combo ctrl+a; typetext "Quake"; key Return; sleep 0.3
iclick "button:Save as preset"; wait_for 'preset "Quake" saved (3 effects)' 1 5; check "Save as preset stores the whole group" $?
grep -q '"Quake"' "$MOD/data/golden/fxpresets.json"; check "preset saved in data/golden/fxpresets.json" $?
click_at 640 712
pick "My presets" "Quake" "Quake"; wait_for "added zoom+zoom+shake at" 2 5; check "the custom preset can be added again" $?
combo ctrl+s; wait_for 'Saved to mod "edit-test"' 1 10; check "saved (content reloaded)" $?
wait_for "Loaded module: GoldenBopeeboModule" 1 15; check "FNF loads the Haxe module" $?
key Home; click "button:Bot Preview"; wait_for "started song at" 1 60; check "song plays" $?
wait_for "HAXE MODULE] GoldenBopeeboModule: song started\|HAXE MODULE  GoldenBopeeboModule: song started\|GoldenBopeeboModule: song started" 1 20; check "the Haxe module runs in gameplay" $?
finish
