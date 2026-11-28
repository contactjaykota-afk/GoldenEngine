#!/usr/bin/env bash
# Golden Engine — Main Menu Editor + Note Skin Editor end-to-end test (real X11 input, real build).
source "$(dirname "$0")/lib-editor.sh"
editor_setup editors4

start_game; check "game boots" $?
to_hub; check "Editors hub opens" $?

# ---------------- Main Menu Editor ----------------
open_editor "Main Menu Editor"; check "Main Menu Editor opens" $?
sleep 1; m=$(shot 01-menu-editor); not_black "$m"; check "live menu preview renders with the real menu art (mean=$m)" $?
iclick "field:Background tint"; combo ctrl+a; typetext "#80FFFF"; key Return; sleep 0.3
pick "Entries (order)" "6. credits" "credits"; sleep 0.4
for i in 1 2 3 4 5; do iclick "button:Move up"; sleep 0.25; done
click "button:Add Entry"; wait_for "Main Menu Editor: custom entry added" 1 5; check "a custom entry is added" $?
iclick "field:Label"; combo ctrl+a; typetext "PLAY BOPEEBO"; key Return; sleep 0.4
sleep 0.5; shot 02-menu-editor-edited >/dev/null
combo ctrl+s; wait_for 'Saved to mod "edit-test"' 1 10; check "menu config saved" $?
python3 - "$MOD/data/golden/mainmenu.json" <<'PY'; check "mainmenu.json: credits first, custom entry, tint" $?
import json,sys; d=json.load(open(sys.argv[1]))
assert d['items'][0]['id']=='credits' and d['custom'][0]['label']=='PLAY BOPEEBO' and d['custom'][0]['action']=='song:bopeebo' and d['backgroundColor']=='#80FFFF', d
PY
click "button:Open Main Menu"; wait_for "Main menu entries: credits" 1 20; check "the real main menu uses the new order" $?
clean_log | grep "Main menu entries:" | tail -1 | grep -q "golden-custom0"; check "the real main menu has the custom entry" $?
sleep 2; m=$(shot 03-real-menu); not_black "$m"; check "custom main menu renders (mean=$m)" $?
key Up; sleep 0.6; key Return
wait_for "Custom menu entry: song:bopeebo" 1 15; check "selecting the custom entry runs its action" $?
wait_for "started song at" 1 60; check "...which starts Bopeebo" $?
sleep 2
rm -f "$MOD/data/golden/mainmenu.json"  # back to the standard menu order for the next part
start_game; to_hub; check "Editors hub opens again" $?

# ---------------- Note Skin Editor ----------------
open_editor "Note Skin Editor"; check "Note Skin Editor opens" $?
wait_for 'Note Skin Editor: new skin from "funkin" as "golden-notes1"' 1 10; check "starts a new skin from the default notes" $?
sleep 1; m=$(shot 04-noteskin); not_black "$m"; check "four-direction preview renders (mean=$m)" $?
iclick "field:left colour"; combo ctrl+a; typetext "#FF2020"; key Return; sleep 0.3
iclick "field:right colour"; combo ctrl+a; typetext "#20A0FF"; key Return; sleep 0.3
click "button:Press / Confirm"; sleep 0.5; shot 05-noteskin-confirm >/dev/null
iclick "button:Use in song"; wait_for "Note Skin Editor: bopeebo uses golden-notes1" 1 15; check "Use in song assigns the skin to Bopeebo" $?
[ -f "$MOD/data/notestyles/golden-notes1.json" ] && [ -f "$MOD/data/songs/bopeebo/bopeebo-metadata.json" ]; check "note style + metadata copy saved in the mod" $?
grep -q golden-notes1 "$MOD/data/golden/notecolors.json"; check "note colours saved" $?
export GOLDEN_AUTOTEST=play
start_game; wait_for "gameplay reached" 1 200; check "Bopeebo starts" $?
wait_for 'Note colours for note style "golden-notes1"' 1 20; check "gameplay uses the new note skin and its colours" $?
sleep 4; m=$(shot 06-noteskin-gameplay); not_black "$m"; check "gameplay renders with the skin (mean=$m)" $?
unset GOLDEN_AUTOTEST
finish
