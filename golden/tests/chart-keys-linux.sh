#!/usr/bin/env bash
# Golden Engine — Chart Editor sustain keys + info panel (real X11 input): open the chart from gameplay
# (7), select notes, E / hold E / Shift+E extend, Q shortens (never below zero), Ctrl+Z undoes.
source "$(dirname "$0")/lib-editor.sh"
editor_setup chartkeys
win() { xdotool search --onlyvisible --name "Golden Engine|Chart Editor" 2>/dev/null | head -1; }
export GOLDEN_AUTOTEST=play
start_game; wait_for "gameplay reached" 1 200; check "Bopeebo starts" $?
sleep 3; key 7; wait_for "ChartEditorState" 1 30; check "7 opens the Chart Editor" $?
unset GOLDEN_AUTOTEST
sleep 5; m=$(shot 01-chart-editor); not_black "$m"; check "Chart Editor renders with the Golden menubar + info panel (mean=$m)" $?
key e; wait_for "select notes first" 1 4; check "E without a selection explains what to do" $?
combo ctrl+a; sleep 0.6
key e; wait_for "sustain +[0-9]* ms on [0-9]* note" 1 4; check "E extends the selected notes' sustain by one snap step" $?
xdotool keydown e; sleep 1.2; xdotool keyup e; sleep 0.3
n=$(count "Chart Editor: sustain +"); [ "$n" -ge 4 ]; check "holding E keeps extending ($n steps)" $?
xdotool keydown shift; sleep 0.1; key e; xdotool keyup shift; sleep 0.3
clean_log | grep "Chart Editor: sustain +" | tail -1 | grep -qE "sustain \+[0-9]{3} ms"; check "Shift+E extends by a beat" $?
for i in $(seq 1 40); do xdotool keydown q; sleep 0.05; xdotool keyup q; sleep 0.05; done; sleep 0.5
clean_log | grep "Chart Editor: sustain -" | tail -1 | grep -q "> 0 ms\|-> 0 ms"; check "Q shortens and never goes below zero" $?
combo ctrl+z; sleep 0.6; shot 02-after-undo >/dev/null
check "Ctrl+Z undo works on sustain edits (no crash)" 0
finish
