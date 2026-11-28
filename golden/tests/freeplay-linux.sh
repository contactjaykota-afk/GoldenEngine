#!/usr/bin/env bash
# Golden Engine — Freeplay search/filter/sort test (real X11 input): search as you type, filter by mod,
# sort A-Z, then play the found song.
source "$(dirname "$0")/lib-editor.sh"
editor_setup freeplay
# a mod song ("Gold Test", a copy of Bopeebo) so the mod filter has something to find
mkdir -p "$MOD/data/songs/goldtest" "$MOD/songs/goldtest"
python3 - "$ROOT" "$MOD" <<'PY'
import json,sys,shutil,glob,os; root,mod=sys.argv[1],sys.argv[2]
m=json.load(open(root+'/assets/preload/data/songs/bopeebo/bopeebo-metadata.json')); m['songName']='Gold Test'
json.dump(m,open(mod+'/data/songs/goldtest/goldtest-metadata.json','w'))
shutil.copy(root+'/assets/preload/data/songs/bopeebo/bopeebo-chart.json', mod+'/data/songs/goldtest/goldtest-chart.json')
for f in glob.glob(root+'/assets/songs/bopeebo/*.ogg'): shutil.copy(f, mod+'/songs/goldtest/'+os.path.basename(f))
os.makedirs(mod+'/data/levels', exist_ok=True)
lv=json.load(open(root+'/assets/preload/data/levels/week1.json')); lv['name']='GOLD WEEK'; lv['songs']=['goldtest']
json.dump(lv,open(mod+'/data/levels/goldweek.json','w'))
PY
start_game; check "game boots" $?
to_main_menu; check "main menu" $?
key Down Return; wait_for "Idle -> EnteringFreeplay\|FreeplayState" 1 20; sleep 4
m=$(shot 01-freeplay); not_black "$m"; check "Freeplay renders (mean=$m)" $?
combo ctrl+f; wait_for "Freeplay search opened" 1 5; check "Ctrl+F opens the song search" $?
typetext "bop"; sleep 1
clean_log | grep 'Freeplay filter "bop"' | tail -1 | grep -qE ": [1-9][0-9]* songs"; check "search as you type filters the list" $?
clean_log | grep 'Freeplay filter "bop"' | tail -1 | grep -q ": 1 songs"; check "'bop' matches only Bopeebo" $?
shot 02-search-bop >/dev/null
combo ctrl+BackSpace; sleep 0.6
key Down; sleep 0.5; key Right; sleep 1.2; key Right; sleep 1.2
clean_log | grep 'Freeplay filter ""' | tail -1 | grep -q "mod=edit-test.*: 1 songs"; check "filter by mod shows the mod's song only" $?
key Down; key Right; sleep 0.8
clean_log | grep 'Freeplay filter' | tail -1 | grep -q "sortMode=a-z"; check "sort A-Z applies" $?
shot 03-mod-filter >/dev/null
key Escape; sleep 1
shot 04-after-close >/dev/null
key Down; sleep 0.8; key Return; sleep 2.5; shot 05-after-enter >/dev/null; key Return
wait_for "started song at" 1 90; check "the found song plays" $?
finish
