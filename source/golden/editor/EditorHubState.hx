package golden.editor;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.ui.MusicBeatState;
import golden.audio.UISound;
import golden.editor.EditorUI;

typedef EditorEntry =
{
  name:String,
  description:String,
  open:Void->Void
}

/**
 * Golden Engine — Editors hub (Main menu > Editors). One card per editor; arrows/Enter or the mouse.
 * Lists the Golden editors and FNF's own editors (Chart, Animation offsets, Stage).
 */
class EditorHubState extends MusicBeatState
{
  public static function entries():Array<EditorEntry>
  {
    var list:Array<EditorEntry> = [];
    #if FEATURE_CHART_EDITOR
    list.push({name: 'Chart Editor', description: 'Charts, events, MIDI import (FNF editor + Golden tools).', open: () -> FlxG.switchState(() -> new funkin.ui.debug.charting.ChartEditorState())});
    #end
    list.push({name: 'Animation Studio', description: 'Animate characters from separate body-part PNGs: poses, keyframes, export.', open: () -> FlxG.switchState(() -> new golden.editor.anim.AnimationStudioState())});
    list.push({name: 'Character Editor', description: 'Character JSON: animations, offsets, scale, flip, icon, health colours.', open: () -> FlxG.switchState(() -> new golden.editor.CharacterEditorState())});
    #if FEATURE_STAGE_EDITOR
    list.push({name: 'Stage Editor', description: 'FNF stage editor: props, layers, scroll factors, character positions.', open: () -> FlxG.switchState(() -> new funkin.ui.debug.stageeditor.StageEditorState())});
    #end
    list.push({name: 'Event System', description: 'Song timeline: camera, effects, colour, overlays, text, notes, chart events, scripts.', open: () -> FlxG.switchState(() -> new golden.editor.EventSystemState())});
    list.push({name: 'Game Over Editor', description: 'Game Over setups: character, music, sounds, timing; per-song configs.', open: () -> FlxG.switchState(() -> new golden.editor.GameOverEditorState())});
    list.push({name: 'Week Editor', description: 'Story Mode weeks: songs, characters, background, difficulties, unlocks.', open: () -> FlxG.switchState(() -> new golden.editor.WeekEditorState())});
    list.push({name: 'Note Skin Editor', description: 'Note styles: textures, receptors, holds, preview of all directions.', open: () -> FlxG.switchState(() -> new golden.editor.NoteSkinEditorState())});
    list.push({name: 'Main Menu Editor', description: 'Custom main menu: background, logo, buttons, music, layout.', open: () -> FlxG.switchState(() -> new golden.editor.MainMenuEditorState())});
    list.push({name: 'Cutscene Editor', description: 'Timeline cutscenes before a song: images, text, characters, sounds, camera.', open: () -> FlxG.switchState(() -> new golden.editor.EventSystemState(true))});
    list.push({name: 'Mod Asset Manager', description: 'Browse, preview, import, rename, delete mod files; missing/unused.', open: () -> FlxG.switchState(() -> new golden.editor.AssetManagerState())});
    list.push({name: 'Script Editor', description: 'Golden Studio: Haxe/Lua/JSON editing, Play-in-Editor (F9).', open: () -> FlxG.switchState(() -> EditorFiles.target() != null ? new golden.studio.ScriptEditorState(EditorFiles.target()) : new golden.ui.ModManagerState())});
    #if FEATURE_ANIMATION_EDITOR
    list.push({name: 'Offset Editor (FNF)', description: 'FNF animation offset editor for existing characters.', open: () -> FlxG.switchState(() -> new funkin.ui.debug.anim.DebugBoundingState())});
    #end
    return list;
  }

  var list:Array<EditorEntry>;
  var cards:Array<{bg:FlxSprite, title:FlxText, desc:FlxText}> = [];
  var selected:Int = 0;
  var leaving:Bool = false;
  var armed:Bool = false;
  var pressedCard:Int = -1;
  var pending:Null<Void->Void> = null;
  static var lastSelected:Int = 0;

  static inline var COLS:Int = 4;
  static inline var CW:Int = 296;
  static inline var CH:Int = 120;

  override function create():Void
  {
    super.create();
    FlxG.mouse.visible = true;
    add(EditorUI.rect(0, 0, FlxG.width, FlxG.height, EditorUI.BG));
    add(EditorUI.rect(0, 0, FlxG.width, 84, EditorUI.HEADER));
    add(EditorUI.rect(0, 82, FlxG.width, 2, EditorUI.ACCENT));
    // FNF's own bold lettering (the in-game Alphabet atlas) for the title.
    var title = new funkin.ui.AtlasText(20, 8, 'EDITORS', funkin.ui.AtlasText.AtlasFont.BOLD);
    title.color = EditorUI.ACCENT;
    add(title);
    var t = EditorUI.text(FlxG.width - 524, 34, 500, 'Arrows + Enter or click  -  Esc: main menu', 13, EditorUI.MUTED);
    t.alignment = RIGHT;
    add(t);
    var target = EditorFiles.target();
    add(EditorUI.text(24, FlxG.height - 30, FlxG.width - 48, 'Editors save into a mod folder (current: ' + (target ?? 'none - create a mod in Main menu > Mods first') + '). Developer Mode tools: F8 console, Tab mod selector.', 12, EditorUI.MUTED));
    list = entries();
    for (i in 0...list.length)
    {
      var cx = 24 + (i % COLS) * (CW + 12);
      var cy = 100 + Std.int(i / COLS) * (CH + 12);
      var bg = EditorUI.rect(cx, cy, CW, CH, EditorUI.PANEL);
      add(bg);
      var title = EditorUI.text(cx + 14, cy + 14, CW - 28, list[i].name, 18, EditorUI.TEXT);
      add(title);
      var desc = EditorUI.text(cx + 14, cy + 44, CW - 28, list[i].description, 12, EditorUI.MUTED);
      add(desc);
      cards.push({bg: bg, title: title, desc: desc});
      EditorUI.mapLog('card:${list[i].name}', cx, cy, CW, CH);
    }
    selected = Std.int(Math.min(lastSelected, list.length - 1));
    refreshCards();
    trace('[GOLDEN EDITOR] Editors hub opened (${list.length} editors)');
  }

  function refreshCards():Void
  {
    for (i in 0...cards.length)
    {
      var c = cards[i];
      var on = i == selected;
      c.bg.color = on ? EditorUI.SELECT : EditorUI.PANEL;
      c.title.color = on ? EditorUI.ACCENT : EditorUI.TEXT;
    }
  }

  function move(d:Int):Void
  {
    selected = (selected + d + list.length) % list.length;
    UISound.play(Scroll);
    refreshCards();
  }

  function openSelected():Void
  {
    lastSelected = selected;
    UISound.play(Confirm);
    trace('[GOLDEN EDITOR] Opening ${list[selected].name}');
    pending = list[selected].open;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (leaving) return;
    // Ignore input until the key/button that opened the hub is released (FNF controls are polled lazily,
    // so poll them while waiting or a stale "just pressed" would fire later).
    if (!armed)
    {
      if (!FlxG.keys.pressed.ENTER && !FlxG.keys.pressed.SPACE && !FlxG.mouse.pressed)
      {
        armed = true;
        trace('[GOLDEN EDITOR] Editors hub ready for input');
      }
      return;
    }
    if (pending != null)
    {
      // Switch only once the key/button is released, so it does not act in the next screen.
      if (!golden.ui.GoldenSubState.anyInputHeld())
      {
        leaving = true;
        pending();
      }
      return;
    }
    // Frame-accurate keyboard/gamepad checks (FNF's shared controls can report a stale press from the menu).
    var k = FlxG.keys.justPressed;
    var pad = FlxG.gamepads.lastActive;
    if (k.LEFT || (pad != null && pad.justPressed.DPAD_LEFT)) move(-1);
    if (k.RIGHT || (pad != null && pad.justPressed.DPAD_RIGHT)) move(1);
    if (k.UP || (pad != null && pad.justPressed.DPAD_UP)) move(-COLS);
    if (k.DOWN || (pad != null && pad.justPressed.DPAD_DOWN)) move(COLS);
    if (k.ENTER || (pad != null && pad.justPressed.A)) openSelected();
    else if (k.ESCAPE || k.BACKSPACE || (pad != null && pad.justPressed.B))
    {
      UISound.play(Back);
      pending = () -> FlxG.switchState(() -> new funkin.ui.mainmenu.MainMenuState());
    }
    var p = FlxG.mouse.getViewPosition();
    for (i in 0...cards.length)
    {
      var b = cards[i].bg;
      if (p.x >= b.x && p.x < b.x + CW && p.y >= b.y && p.y < b.y + CH)
      {
        if (selected != i && FlxG.mouse.justMoved)
        {
          selected = i;
          UISound.play(Hover);
          refreshCards();
        }
        if (FlxG.mouse.justPressed) pressedCard = i;
        // Open only when the press also started on this card (no stale releases from the previous screen).
        if (FlxG.mouse.justReleased && pressedCard == i)
        {
          selected = i;
          openSelected();
        }
      }
    }
    p.put();
  }
}
