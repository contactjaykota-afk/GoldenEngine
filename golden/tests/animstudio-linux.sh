#!/usr/bin/env bash
# Golden Engine — Animation Studio end-to-end test in the real Linux build (real X11 mouse + keyboard):
# Editors hub -> Studio with the default character -> pick the generated "Left" pose (thumbnail browser)
# -> select + rotate a body part by dragging -> idle animation: frame, keyframe, timeline -> Save project
# -> Export character (sheet + XML + JSON + icon) -> Test Play: the exported character is the player in
# a real song -> F9 back to the Studio -> import a folder of separate PNG parts -> generate poses ->
# export the imported character -> its files load as an FNF character after restart.
source "$(dirname "$0")/lib-editor.sh"
editor_setup animstudio

# PNG body parts drawn as layers of one 300x500 canvas (aligned import)
PARTS="$OUT/parts"; mkdir -p "$PARTS"
mk() { convert -size 300x500 xc:none -fill "$2" -stroke '#101010' -strokewidth 4 -draw "$3" "$PARTS/$1.png"; }
mk LeftLeg '#303050' 'roundrectangle 105,330 140,470 12,12'
mk RightLeg '#303050' 'roundrectangle 160,330 195,470 12,12'
mk Body '#c03040' 'roundrectangle 95,200 205,345 30,30'
mk LeftArm '#c03040' 'roundrectangle 62,210 92,320 12,12'
mk RightArm '#c03040' 'roundrectangle 208,210 238,320 12,12'
mk Head '#f0c8a0' 'circle 150,140 150,75'
mk Mouth '#601020' 'ellipse 150,170 20,10 0,360'

start_game; check "game boots" $?
to_hub; check "Editors hub opens from the main menu" $?
m=$(shot 01-hub); not_black "$m"; check "Editors hub renders (mean=$m)" $?
open_editor "Animation Studio"; check "Animation Studio opens from its card" $?
wait_for "Animation Studio opened" 1 15; sleep 2
m=$(shot 02-studio-default); not_black "$m"; check "Studio renders with the default character (mean=$m)" $?
wait_for "Boyfriend imported from the game atlas" 1 5; check "default character is FNF Boyfriend, imported from the game's own atlas" $?
wait_for "part:head @" 1 5; check "default character parts are drawn in the workspace" $?

# --- pose browser
pick "Character/Poses/Sing LEFT" "Sing LEFT"; sleep 1
wait_for 'pose "Sing LEFT" opened' 1 5; check "clicking the Sing LEFT pose thumbnail loads it into the workspace" $?
shot 03-pose-left >/dev/null

# --- select a part with the mouse and rotate it with the Rotate tool
read hx hy <<<"$(where part:head)"
click_at "$hx" "$hy"; sleep 0.5
key r
drag $((hx + 60)) $((hy)) $((hx + 30)) $((hy - 70))
wait_for "Animation Studio: rotate head (pose)" 1 5; check "dragging with the Rotate tool rotates the selected part (head)" $?
shot 04-rotated-head >/dev/null
combo ctrl+z; wait_for "Undo" 1 4; check "Ctrl+Z undoes the rotation" $?
combo ctrl+y; wait_for "Redo" 1 4; check "Ctrl+Y redoes it" $?

# --- animation timeline: open idle, go to frame 6, move the body, auto-key
pick "Character/Animations" "Idle (14f)" "14f"; sleep 1
wait_for 'animation "Idle" opened' 1 5; check "Idle animation opens with its timeline" $?
key v; key period period period period period period
read bx by <<<"$(where part:body)"
drag "$bx" "$by" $((bx + 25)) "$by"
wait_for "Animation Studio: move body (anim frame 6)" 1 5; check "moving a part on frame 6 creates a keyframe (auto-key)" $?
key Return; sleep 1.5; shot 05-playing >/dev/null; key Return
shot 05-timeline >/dev/null
combo ctrl+d; wait_for "Duplicated" 1 4; check "Ctrl+D duplicates the frame's keys to the next frame" $?
key o; sleep 0.5; shot 06-onion >/dev/null; key o

# --- pose library: save edited pose as new (original kept), duplicate, export pose
pick "Character/Poses/Sing LEFT" "Sing LEFT"; sleep 0.8
read ax ay <<<"$(where part:hand)"; click_at "$ax" "$ay"; key v
drag "$ax" "$ay" $((ax - 30)) $((ay - 20))
wait_for "Animation Studio: move hand (pose)" 1 5; check "the mic hand (arm) of the Sing LEFT pose can be moved" $?
click "button:Save as new pose"; wait_for 'Saved as new pose "Sing LEFT (edited)"' 1 5; check "Save as new pose keeps the original and adds the edited copy" $?
click "button:Export pose"; wait_for "Pose exported to" 1 5; check "Export pose writes a .pose.json" $?
click "field:browser search"; typetext "miss"; sleep 1
wait_for "item:Character/Poses/Miss/Sing LEFT Miss" 1 4; check "pose search filters the browser (miss poses listed)" $?
shot 06b-search >/dev/null
click "field:browser search"; combo ctrl+a; key BackSpace; sleep 0.6

# --- save + export
combo ctrl+s; wait_for 'Saved to mod "edit-test"' 1 8; check "Ctrl+S saves the project" $?
[ -f "$MOD/golden/animstudio/bf-studio/project.json" ] && ls "$MOD/golden/animstudio/bf-studio/parts/" | grep -q png; check "project.json and part PNGs written into the mod" $?
python3 - "$MOD/golden/animstudio/bf-studio/project.json" <<'PY'; check "saved project contains the frame-6 body key and the edited Sing LEFT pose" $?
import json,sys; p=json.load(open(sys.argv[1]))
idle=[a for a in p['anims'] if a['fnfName']=='idle'][0]
assert any(k['f']==6 for k in idle['tracks']['body']), 'no key at 6'
left=[x for x in p['poses'] if x['name']=='Sing LEFT'][0]
orig=[x for x in p['poses'] if x['name']=='Idle'][0]
assert abs(left['t']['head']['r'] - 0) > 3, left['t']['head']
PY
click "button:Export"; wait_for 'Exported character "bf-studio"' 1 20; check "Export writes the FNF character" $?
for f in images/characters/bf-studio.png images/characters/bf-studio.xml data/characters/bf-studio.json images/icons/icon-bf-studio.png; do
  [ -f "$MOD/$f" ]; check "export file $f exists" $?; done
python3 - "$MOD" <<'PY'; check "character JSON is valid FNF sparrow data and every animation prefix has frames" $?
import json,sys,re,glob; m=sys.argv[1]; d=json.load(open(m+'/data/characters/bf-studio.json'))
assert d['renderType'] in ('sparrow','multisparrow') and d['assetPath']=='characters/bf-studio', d['renderType']
names=[]
for x in glob.glob(m+'/images/characters/bf-studio*.xml'): names+=re.findall(r'name="([^"]+)"',open(x).read())
need={'idle','singLEFT','singDOWN','singUP','singRIGHT','singLEFTmiss','hey'}
assert need <= {a['name'] for a in d['animations']}, d['animations']
for a in d['animations']: assert any(n.startswith(a['prefix']) and n[len(a['prefix']):].isdigit() for n in names), a
PY
convert "$MOD/images/icons/icon-bf-studio.png" -format '%w %h' info: | grep -q "300 150"; check "health icon is 300x150 (normal + losing)" $?

# --- test in gameplay with the exported character
click "button:Test Play"
wait_for 'Test override: player character "bf-studio"' 1 40; check "Test Play starts a song with the exported character as the player" $?
wait_for "started song at" 1 60; check "song is running" $?
sleep 4; m=$(shot 07-gameplay-bf-studio); not_black "$m"; check "gameplay renders with the Studio character (mean=$m)" $?
clean_log | grep -qi "Could not load\|failed to load character\|bf-studio.*not found"; [ $? -ne 0 ]; check "no character loading errors" $?
key F9; wait_for "restored after the gameplay test" 1 30; check "F9 returns to the Studio with the project restored" $?
sleep 2; shot 08-back-in-studio >/dev/null

# --- new character from separate PNG parts
pick "Projects" "New empty character" "empty"; sleep 0.8
wait_for "Empty character" 1 5 || { key y; wait_for "Empty character" 1 5; }; check "New empty character" $?
pick "Import" "Import PNG folder..." "folder"
dialog_path "Folder with body-part PNGs" "$PARTS/"; check "Import Folder opens the native folder dialog" $?
wait_for "Animation Studio import:" 1 15; check "separate PNG parts imported" $?
clean_log | grep "Animation Studio import:" | tail -1 | grep -q "alignment: layer positions"; check "same-size layers keep their drawn alignment" $?
clean_log | grep -q "auto-rigged"; check "imported parts auto-rigged by name (arms/head to body)" $?
sleep 1; shot 09-imported >/dev/null
click "button:Generate"; wait_for "Generated [0-9]* poses/animations" 1 10; check "Generate creates editable poses + animations for the imported character" $?
sleep 1; m=$(shot 10-generated); not_black "$m"; check "generated poses render (mean=$m)" $?
click "field:Character ID"; combo ctrl+a; typetext "parts-guy"; key Return; sleep 0.5
click "button:Export"; wait_for 'Exported character "parts-guy"' 1 20; check "imported character exports" $?
[ -f "$MOD/data/characters/parts-guy.json" ] && [ -f "$MOD/images/characters/parts-guy.png" ]; check "parts-guy files written" $?

# --- restart: the exported characters are registered by the game
start_game; check "game restarts" $?
wait_for "bf-studio\|parts-guy" 1 30; check "exported character data is loaded by the character registry after restart" $?
sleep 3
finish
