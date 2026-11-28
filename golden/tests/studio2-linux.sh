#!/usr/bin/env bash
# Golden Engine — Animation Studio additions: tween easing, paint/erase + undo, add to an existing sprite
# sheet (backup + XML kept), Character Editor -> "Open in Animation Studio" (Animate-atlas import).
source "$(dirname "$0")/lib-editor.sh"
editor_setup studio2
PARTS="$OUT/parts"; mkdir -p "$PARTS"
mk() { convert -size 200x300 xc:none -fill "$2" -stroke '#101010' -strokewidth 3 -draw "$3" "$PARTS/$1.png"; }
mk Body '#3060c0' 'roundrectangle 70,120 130,230 20,20'; mk Head '#f0c8a0' 'circle 100,80 100,40'
mk LeftArm '#3060c0' 'roundrectangle 48,125 68,200 8,8'; mk RightArm '#3060c0' 'roundrectangle 132,125 152,200 8,8'
mk LeftLeg '#202030' 'roundrectangle 78,225 96,295 8,8'; mk RightLeg '#202030' 'roundrectangle 104,225 122,295 8,8'
# a small existing Sparrow sheet with 2 frames
SHEET="$OUT/sheet"; mkdir -p "$SHEET"
convert -size 120x60 xc:none -fill red -draw 'rectangle 0,0 59,59' -fill blue -draw 'rectangle 60,0 119,59' "$SHEET/oldchar.png"
cat > "$SHEET/oldchar.xml" <<'X'
<?xml version="1.0" encoding="utf-8"?>
<TextureAtlas imagePath="oldchar.png">
  <SubTexture name="old idle0000" x="0" y="0" width="60" height="60"/>
  <SubTexture name="old idle0001" x="60" y="0" width="60" height="60"/>
</TextureAtlas>
X
start_game; check "game boots" $?
to_hub; check "hub" $?
open_editor "Animation Studio"; check "Studio opens" $?
pick "Projects" "New empty character" "empty"; sleep 0.8; key y 2>/dev/null; sleep 0.5
pick "Import" "Import PNG folder..." "folder"; dialog_path "Folder with body-part PNGs" "$PARTS/"
wait_for "Animation Studio import:" 1 15; check "parts imported" $?
click "button:Generate"; wait_for "Generated [0-9]* poses/animations" 1 10; check "poses generated" $?
pick "Character/Animations" "Idle (12f)" "12f"; sleep 0.6
read hx hy <<<"$(where part:head)"; click_at "$hx" "$hy"; sleep 0.4
iclick "button:Tween (key at frame) >"; sleep 0.3; iclick "button:Tween (key at frame) >"; sleep 0.3
wait_for "tween quadIn on 1 key(s) at frame 0" 1 4; check "tween easing set on the selected part's key" $?
key b; read hx hy <<<"$(where part:head)"; drag $((hx - 10)) "$hy" $((hx + 10)) $((hy + 4))
wait_for "paint stroke on Head ([1-9][0-9]* px)" 1 5; check "Paint tool draws on the part image" $?
iclick "button:Undo stroke"; wait_for "paint stroke undone" 1 4; check "Undo stroke restores the image" $?
key v
iclick "button:Add to existing sheet..."; dialog_path "Existing sprite sheet" "$SHEET/oldchar.png"
wait_for "Sprite sheet extended:" 1 30; check "Add to existing sheet extends the sheet" $?
X2="$SHEET/oldchar-golden.xml"
[ -f "$X2" ] && grep -q 'name="old idle0001"' "$X2" && grep -q 'name="golden idle0000"' "$X2"; check "new XML keeps the old frames and adds the new animations" $?
[ "$(md5sum < "$SHEET/oldchar.png")" = "$(md5sum < "$SHEET/oldchar.png")" ] && grep -q "old idle0000" "$SHEET/oldchar.xml"; check "original sheet untouched (not in replace mode)" $?
iclick "toggle:Replace original"; sleep 0.3
iclick "button:Add to existing sheet..."; dialog_path "Existing sprite sheet" "$SHEET/oldchar.png"
wait_for "Sprite sheet extended:" 2 30; ls "$SHEET"/oldchar.png.*.bak >/dev/null 2>&1 && ls "$SHEET"/oldchar.xml.*.bak >/dev/null 2>&1; check "replace mode backs up the original first" $?
grep -q 'name="golden idle0000"' "$SHEET/oldchar.xml"; check "replace mode updates the original XML" $?
key Escape; sleep 1; key y; wait_for "Editors hub ready for input" 2 20; sleep 1.5
open_editor "Character Editor"; check "Character Editor opens" $?
pick "Characters" "dad" "dad"; wait_for 'Character Editor: opened "dad"' 1 10
click "button:Open in Animation Studio"; wait_for 'Imported "shared:characters/dad" from its Animate atlas' 1 30; check "Open in Animation Studio imports dad as editable parts" $?
sleep 2; m=$(shot 01-dad-in-studio); not_black "$m"; check "dad renders in the Studio (mean=$m)" $?
finish
