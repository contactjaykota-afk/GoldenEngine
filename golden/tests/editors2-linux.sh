#!/usr/bin/env bash
# Golden Engine — Week Editor + Game Over Editor end-to-end test (real X11 input, real build).
source "$(dirname "$0")/lib-editor.sh"
editor_setup editors2

start_game; check "game boots" $?
to_hub; check "Editors hub opens" $?

# ---------------- Week Editor ----------------
open_editor "Week Editor"; check "Week Editor opens" $?
wait_for 'Week Editor: new week "custom-week1"' 1 10; check "a new week is ready to edit" $?
click "field:Name"; combo ctrl+a; typetext "GOLDEN WEEK"; key Return; sleep 0.4
iclick "button:Add song"; sleep 0.4; iclick "button:Song to add >"; sleep 0.3; iclick "button:Add song"; sleep 0.4
click "button:Requires beating <"; sleep 0.4
sleep 1; m=$(shot 01-week-editor); not_black "$m"; check "story-menu preview renders (mean=$m)" $?
combo ctrl+s; wait_for 'Week Editor: saved "custom-week1" (registered: true' 1 15; check "saved week is registered by Story Mode's level registry" $?
clean_log | grep 'Week Editor: saved "custom-week1"' | tail -1 | grep -q "unlocked: false"; check "unlock requirement applies (locked until the required week is beaten)" $?
W="$MOD/data/levels/custom-week1.json"
python3 - "$W" <<'PY'; check "week JSON is valid FNF level data with 3 songs and props" $?
import json,sys; d=json.load(open(sys.argv[1])); assert d['name']=='GOLDEN WEEK' and len(d['songs'])==3 and len(d['props'])==3 and d['version'].startswith('1.0'), d
PY
[ -f "$MOD/data/golden/weeks.json" ]; check "unlock rule saved in data/golden/weeks.json" $?
click "button:Open Story Mode"; wait_for "Week Editor: opening Story Mode" 1 20; check "Open Story Mode switches to Story Mode" $?
sleep 3; m=$(shot 02-story-mode); not_black "$m"; check "Story Mode renders (mean=$m)" $?
key Escape; wait_for "Idle -> EnteringMainMenu\|MainMenuState" 1 20; sleep 2
key Down Down Down Return; wait_for "Editors hub ready for input" 2 25

# ---------------- Game Over Editor ----------------
open_editor "Game Over Editor"; check "Game Over Editor opens" $?
wait_for "Game Over Editor: default setup loaded" 1 5; check "default setup is ready to customise" $?
iclick "field:Text"; combo ctrl+a; typetext "TRY AGAIN GOLDEN"; key Return; sleep 0.4
click "field:Music"; combo ctrl+a; typetext "freakyMenu/freakyMenu"; key Return; sleep 0.4
click "button:Play Death"; wait_for "Game Over preview: death" 1 5; check "Play Death previews the animation and the chosen music" $?
sleep 1; m=$(shot 03-gameover-default); not_black "$m"; check "default setup preview renders (mean=$m)" $?
iclick "button:Remove Music"; sleep 0.4
python3 -c "print()" >/dev/null
click "button:New Setup"; wait_for 'Setup "setup1" created' 1 5; check "a second setup can be created" $?
iclick "field:Text"; combo ctrl+a; typetext "SPOOKY OVER"; key Return; sleep 0.4
iclick "button:Camera zoom +"; sleep 0.3
iclick "toggle:Per-song setups"; sleep 0.4
iclick "button:Setup >"; sleep 0.5; wait_for "Setup = setup1" 1 4; check "setup choice switched to setup1" $?
iclick "button:Assign"; wait_for "Game Over Editor: bopeebo -> setup1" 1 5; check "setup1 assigned to bopeebo" $?
combo ctrl+s; wait_for 'Saved to mod "edit-test"' 1 10; check "Game Over config saved" $?
G="$MOD/data/golden/gameover.json"
python3 - "$G" <<'PY'; check "gameover.json has the default + setup1, per-song on, bopeebo -> setup1, music removed from default" $?
import json,sys; d=json.load(open(sys.argv[1]))
assert d['perSong'] and d['songs']['bopeebo']=='setup1' and d['setups']['setup1']['text']=='SPOOKY OVER', d
assert d['default']['text']=='TRY AGAIN GOLDEN' and d['default']['music']=='', d['default']
PY

# ---------------- restart: the setup is used by the real Game Over screen ----------------
export GOLDEN_AUTOTEST=gameover
start_game; check "game restarts" $?
wait_for "gameplay reached" 1 200; check "Bopeebo starts (not practice)" $?
wait_for "health set to 0" 1 30
wait_for 'Game Over setup for "bopeebo"' 1 20; check "Game Over screen loads the bopeebo setup" $?
clean_log | grep 'Game Over setup for "bopeebo"' | tail -1 | grep -q "SPOOKY OVER"; check "bopeebo uses its own setup (setup1)" $?
sleep 3; m=$(shot 04-real-gameover); not_black "$m"; check "real Game Over screen renders with the setup (mean=$m)" $?
unset GOLDEN_AUTOTEST
finish
