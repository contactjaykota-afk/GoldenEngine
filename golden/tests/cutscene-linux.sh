#!/usr/bin/env bash
# Golden Engine — Cutscene Editor end-to-end test: build a cutscene on the timeline, save it, and check
# that it plays before the song's countdown in real gameplay (then the song starts).
source "$(dirname "$0")/lib-editor.sh"
editor_setup cutscene
start_game; check "game boots" $?
to_hub; check "Editors hub opens" $?
open_editor "Cutscene Editor"; check "Cutscene Editor opens" $?
wait_for 'Event System: loaded "bopeebo"' 1 20; check "the song's stage and characters load" $?
pick "Text styles" "Cinematic Title" "Cinematic"; wait_for "added text at" 1 5; check "a title text is added" $?
iclick "field:text"; combo ctrl+a; typetext "PROLOGUE"; key Return; sleep 0.3
pick "Effects/Camera movement" "Camera Focus" "Focus"; sleep 0.3
iclick "field:Start (ms)"; combo ctrl+a; typetext "1000"; key Return; sleep 0.3
pick "Effects/Screen effects" "Screen Fade" "Fade"; sleep 0.3
iclick "field:Start (ms)"; combo ctrl+a; typetext "3500"; key Return; sleep 0.3
click_at 640 712
key space; wait_for "Cutscene Editor: playing" 1 5; check "the cutscene plays in the editor preview" $?
sleep 2; shot 01-cutscene-preview >/dev/null; key space
combo ctrl+s; wait_for 'Saved to mod "edit-test"' 1 10; check "cutscene saved" $?
python3 - "$MOD/data/golden/cutscenes/bopeebo.json" <<'PY'; check "cutscene file has the steps, a length and plays before the song" $?
import json,sys; d=json.load(open(sys.argv[1])); t=[e['type'] for e in d['effects']]
assert 'text' in t and 'focus' in t and 'fade' in t and d['beforeSong'] and d['length']>=500, d
PY
key Home; sleep 0.3
click "button:Bot Preview"; wait_for 'Cutscene for "bopeebo" started' 1 60; check "the cutscene plays before the countdown in real gameplay" $?
sleep 2; m=$(shot 02-cutscene-ingame); not_black "$m"; check "in-game cutscene renders (mean=$m)" $?
wait_for "Cutscene finished" 1 20; check "the cutscene ends after its length" $?
wait_for "started song at" 1 30; check "then the song starts" $?
finish
