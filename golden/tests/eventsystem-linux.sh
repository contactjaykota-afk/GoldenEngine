#!/usr/bin/env bash
# Golden Engine — Event System end-to-end test (real X11 input, real Linux build):
# open from the Editors hub -> Bopeebo loads (chart, stage, characters) -> notes start locked ->
# unlock + move a note -> add effects (click and drag-and-drop from the browser) -> edit a text effect
# -> play the in-editor preview -> save (non-destructive mod files) -> bot preview in real gameplay
# with the effects firing -> F9 back -> Reset to Original removes the mod files.
source "$(dirname "$0")/lib-editor.sh"
editor_setup eventsystem
EV="$MOD/data/golden/events/bopeebo.json"; CH="$MOD/data/songs/bopeebo/bopeebo-chart.json"

start_game; check "game boots" $?
to_hub; check "Editors hub opens" $?
open_editor "Event System"; check "Event System opens from its card" $?
wait_for 'Event System: loaded "bopeebo"' 1 20; check "Bopeebo loads (notes, chart events, BPM)" $?
sleep 2; m=$(shot 01-event-system); not_black "$m"; check "preview shows the real stage and characters (mean=$m)" $?

# --- locked notes cannot be dragged; unlock, then move one
read tx ty <<<"$(where 'track:Player notes')"
click_at 200 "$ty"; sleep 0.3
click "lock:Player notes"; wait_for 'track "Player notes" unlocked' 1 4; check "clicking the lock unlocks the Player notes track" $?
python3 - "$LOG" > "$OUT/note.txt" <<'PY'
PY
# find the first player note time from the chart and drag it one beat later (pps=80, NAME_W=150)
first=$(python3 -c "
import json; d=json.load(open('$ROOT/assets/preload/data/songs/bopeebo/bopeebo-chart.json'))
ns=[n for n in d['notes']['normal'] if n['d']<4]; ns.sort(key=lambda n:n['t']); print(int(ns[0]['t']))")
nx=$((150 + first * 80 / 1000))
drag "$nx" "$ty" $((nx + 48)) "$ty"
wait_for "Event System: notes moved/resized" 1 5; check "an unlocked note can be dragged to a new time" $?

# --- effects: click to add at the playhead, drag and drop onto the timeline
pick "Effects/Camera movement" "Camera Shake" "Shake"; wait_for "added shake at" 1 5; check "clicking an effect adds it at the playhead" $?
read fx fy <<<"$(where 'track:Flash')"
click "field:browser search"; combo ctrl+a; xdotool key BackSpace; typetext "Flash"; sleep 0.8
read ix iy <<<"$(where 'item:Effects/Screen effects/Screen Flash')"
drag "$ix" "$iy" 470 "$fy"
wait_for "added flash at 4" 1 5; check "dragging Screen Flash onto the Flash track adds it at the drop time (~4 s)" $?
click_at 640 712
pick "Text styles" "Horror Title" "Horror"; wait_for "added text at" 1 5; check "a text style preset adds an editable text effect" $?
click "field:text"; combo ctrl+a; typetext "GOLDEN TEST"; key Return; sleep 0.5
click "field:Start (ms)"; combo ctrl+a; typetext "1500"; key Return; sleep 0.5
pick "Effects/Characters & gameplay" "Note Layout" "Layout"; sleep 0.5
click "field:Start (ms)"; combo ctrl+a; typetext "2500"; key Return; sleep 0.5
pick "Presets" "Impact Zoom" "Impact"; wait_for "added zoom+zoom+shake" 1 5; check "a preset adds several editable effects" $?
shot 02-timeline >/dev/null
click_at 640 712
key space; wait_for "Event System: playing" 1 5; check "Space plays the song in the preview" $?
sleep 4; shot 03-preview-playing >/dev/null; key space
wait_for "GOLDEN FX  shake at" 1 5; check "effects fire during the in-editor preview" $?

# --- save (non-destructive)
combo ctrl+s; wait_for 'Saved to mod "edit-test"' 1 10; check "Ctrl+S saves" $?
[ -f "$EV" ]; check "effects saved to data/golden/events/bopeebo.json in the mod" $?
[ -f "$CH" ]; check "edited chart saved as a mod copy (original untouched)" $?
git -C "$ROOT" diff --quiet -- assets/preload/data/songs/bopeebo/; check "original chart file unchanged" $?
python3 - "$EV" <<'PY'; check "saved effects contain the text, flash, layout and preset effects" $?
import json,sys; p=json.load(open(sys.argv[1])); t=[e['type'] for e in p['effects']]
assert 'text' in t and 'flash' in t and 'layout' in t and t.count('zoom')>=2, t
tx=[e for e in p['effects'] if e['type']=='text'][0]; assert tx['params']['text']=='GOLDEN TEST' and abs(tx['time']-1500)<1, tx
PY
click "button:Validate"; wait_for "Event System validation:" 1 5; check "Validate reports problems/conflicts" $?

# --- bot preview: the real song with a bot, effects from the saved file
key Home; sleep 0.3
nt=$(count "GOLDEN FX  text at 1500"); nl=$(count "GOLDEN FX  layout at 2500"); nf=$(count "GOLDEN FX  flash at 4")
click "button:Bot Preview"; wait_for "Bot preview:" 1 10; check "Bot Preview starts" $?
wait_for "started song at" 1 60; check "real gameplay runs (bot play)" $?
wait_for "effects loaded for \"bopeebo\"" 1 10; check "gameplay loads the saved effects" $?
wait_for "GOLDEN FX  text at 1500" $((nt+1)) 30; check "text effect fires in gameplay at 1.5 s" $?
wait_for "GOLDEN FX  layout at 2500" $((nl+1)) 20; check "note layout effect fires in gameplay" $?
sleep 1.2; m=$(shot 04a-bot-layout); not_black "$m"; check "screenshot after the layout effect (mean=$m)" $?
wait_for "GOLDEN FX  flash at 4" $((nf+1)) 20; check "dragged flash fires in gameplay" $?
sleep 1; m=$(shot 04-bot-gameplay); not_black "$m"; check "gameplay renders with effects (mean=$m)" $?
key F9; wait_for "Event System restored after the bot preview" 1 30; check "F9 returns to the Event System" $?
sleep 2

# --- reset to original
click "button:Reset to Original"; sleep 1; key y
wait_for 'reset to the original' 1 10; check "Reset to Original (confirmed)" $?
[ ! -f "$EV" ] && [ ! -f "$CH" ]; check "mod edit files removed" $?
finish
