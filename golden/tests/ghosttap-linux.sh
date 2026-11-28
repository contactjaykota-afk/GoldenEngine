#!/usr/bin/env bash
# Golden Engine — ghost tapping option with real X11 key presses: on (default) = no miss for a press with
# no note near; off = FNF's anti-spam penalty.
source "$(dirname "$0")/lib-editor.sh"
editor_setup ghosttap
export GOLDEN_AUTOTEST=play
start_game; wait_for "started song at" 1 200; check "Bopeebo starts" $?
sleep 0.3; key Left Left Left; sleep 1
clean_log | grep -q "NO PENALTY Score"; check "ghost tapping on (default): key presses without notes are not penalized" $?
[ "$(clean_log | grep -c ': PENALTY Score\|  PENALTY Score\|:[0-9]*: PENALTY')" = 0 ]; check "...and no penalty was applied" $?
python3 - "$BIN/golden-settings.json" <<'PY'
import json,sys; p=sys.argv[1]; d=json.load(open(p)); d['ghostTapping']=False; json.dump(d,open(p,'w'))
PY
start_game; wait_for "started song at" 1 200; check "restart with ghost tapping off" $?
sleep 0.3; key Left Left Left; sleep 1
clean_log | grep -v "NO PENALTY" | grep -q "PENALTY Score"; check "ghost tapping off: FNF's penalty applies" $?
unset GOLDEN_AUTOTEST
finish
