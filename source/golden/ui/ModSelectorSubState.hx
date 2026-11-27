package golden.ui;

import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.modding.PolymodHandler;
import golden.audio.UISound;
import golden.modding.GoldenMods;
import golden.modding.ModScanner.ModInfo;
import golden.modding.ModOps;
import openfl.display.BitmapData;

/**
 * Developer Mode quick mod selector (default key: Tab), opened over menus.
 *
 * Moving the cursor only SELECTS a mod (shows its icon/description); it does not enable it.
 * Space toggles enabled state, Enter applies (reloads mod content and restarts the current menu),
 * M opens the full Mod Manager, Esc/Tab closes. Closing with unapplied changes keeps them saved in
 * golden-mods.json; they take effect on the next reload (Mod Manager, or next start).
 */
class ModSelectorSubState extends GoldenSubState
{
  static inline var W:Int = 820;
  static inline var ROW:Int = 44;
  static inline var VISIBLE:Int = 9;

  var mods:Array<ModInfo> = [];
  var selected:Int = 0;
  var scroll:Int = 0;
  var changed:Bool = false;
  var rowTexts:Array<FlxText> = [];
  var rowBgs:Array<FlxSprite> = [];
  var icon:FlxSprite;
  var desc:FlxText;
  var hint:FlxText;
  var iconGraphic:Null<FlxGraphic> = null;
  var px:Float;
  var py:Float;

  public function new()
  {
    super(0x88000000);
  }

  override function create():Void
  {
    super.create();
    mods = GoldenMods.rescan();
    GoldenMods.getList().reconcile([for (m in mods) m.dir]);

    var h = 120 + VISIBLE * ROW + 70;
    px = (FlxG.width - W) / 2;
    py = (FlxG.height - h) / 2;
    add(GoldenUI.panel(px - 2, py - 2, W + 4, h + 4, GoldenUI.GOLD));
    add(GoldenUI.panel(px, py, W, h, 0xF0161220));
    add(GoldenUI.text(px + 20, py + 14, W - 40, 'MOD SELECTOR', 26, GoldenUI.GOLD));
    for (i in 0...VISIBLE)
    {
      var bg = new FlxSprite(px + 16, py + 60 + i * ROW).makeGraphic(470, ROW - 4, FlxColor.WHITE);
      bg.scrollFactor.set();
      rowBgs.push(bg);
      add(bg);
      var t = GoldenUI.text(px + 26, py + 60 + i * ROW + 10, 450, '', 18);
      rowTexts.push(t);
      add(t);
    }
    icon = new FlxSprite(px + 510, py + 60);
    icon.scrollFactor.set();
    add(icon);
    desc = GoldenUI.text(px + 510, py + 200, W - 530, '', 15);
    add(desc);
    hint = GoldenUI.text(px + 20, py + h - 50, W - 40, 'Up/Down select   Space enable/disable   Enter apply & reload   M Mod Manager   Esc close', 14, GoldenUI.MUTED);
    add(hint);
    UISound.play(Open);
    redraw();
  }

  function redraw():Void
  {
    if (selected < scroll) scroll = selected;
    if (selected >= scroll + VISIBLE) scroll = selected - VISIBLE + 1;
    for (i in 0...VISIBLE)
    {
      var idx = scroll + i;
      var vis = idx < mods.length;
      rowBgs[i].visible = rowTexts[i].visible = vis;
      if (!vis) continue;
      var m = mods[idx];
      var on = GoldenMods.getList().isEnabled(m.dir);
      rowBgs[i].color = idx == selected ? GoldenUI.GOLD_DARK : 0xFF221C2C;
      rowTexts[i].text = (on ? '[X] ' : '[ ] ') + m.title + (m.errors.length > 0 ? '  (will not load)' : '');
      rowTexts[i].color = m.errors.length > 0 ? GoldenUI.BAD : (on ? GoldenUI.TEXT : GoldenUI.MUTED);
    }
    if (mods.length == 0)
    {
      desc.text = 'No mods installed. Press M to open the Mod Manager and create one.';
      icon.visible = false;
      return;
    }
    var m = mods[selected];
    loadIcon(m);
    var loaded = GoldenMods.loadedDirs.contains(m.dir);
    var on = GoldenMods.getList().isEnabled(m.dir);
    desc.text = '${m.title}${m.modVersion != '' ? ' v' + m.modVersion : ''}\n'
      + (on ? 'Enabled' : 'Disabled') + (on != loaded ? ' (applies on reload)' : '') + '\n\n'
      + (m.description == '' ? '(no description)' : m.description)
      + (m.errors.length > 0 ? '\n\n' + m.errors.join('\n') : '')
      + (ModOps.dependencyProblems(m).length > 0 ? '\n\n' + ModOps.dependencyProblems(m).join('\n') : '');
  }

  function loadIcon(m:ModInfo):Void
  {
    if (iconGraphic != null)
    {
      iconGraphic.persist = false;
      FlxG.bitmap.remove(iconGraphic);
      iconGraphic = null;
    }
    icon.visible = true;
    #if sys
    if (m.hasIcon)
    {
      try
      {
        var bmp = BitmapData.fromFile(haxe.io.Path.join([m.path, golden.modding.ModScanner.ICON_FILE]));
        if (bmp != null)
        {
          iconGraphic = FlxGraphic.fromBitmapData(bmp, false, 'golden-selector-icon', false);
          iconGraphic.persist = true;
        }
      }
      catch (e:Dynamic)
      {
        trace('[GOLDEN] Could not load icon for ${m.dir}: $e');
      }
    }
    #end
    if (iconGraphic != null) icon.loadGraphic(iconGraphic);
    else
      icon.makeGraphic(128, 128, 0xFF2C2436);
    icon.setGraphicSize(128, 128);
    icon.updateHitbox();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (inputBlocked()) return;
    if (mods.length > 0)
    {
      if (controls.UI_UP_P || FlxG.mouse.wheel > 0) move(-1);
      if (controls.UI_DOWN_P || FlxG.mouse.wheel < 0) move(1);
      if (FlxG.mouse.justReleased) for (i in 0...VISIBLE)
        if (rowBgs[i].visible && FlxG.mouse.overlaps(rowBgs[i]))
        {
          if (scroll + i == selected) toggle();
          else
          {
            selected = scroll + i;
            UISound.play(Scroll);
            redraw();
          }
        }
      if (FlxG.keys.justPressed.SPACE) toggle();
    }
    if (FlxG.keys.justPressed.ENTER) apply();
    else if (FlxG.keys.justPressed.M) openManager();
    else if (FlxG.keys.justPressed.ESCAPE || golden.input.GoldenInput.shortcutPressed(GoldenSettings.modSelectorKey) || (controls.BACK_P && !FlxG.keys.justPressed.ENTER))
    {
      UISound.play(Close);
      if (changed) trace('[GOLDEN] Mod selector closed with unapplied changes (saved; apply on next reload).');
      close();
    }
  }

  function move(d:Int):Void
  {
    selected = (selected + d + mods.length) % mods.length;
    UISound.play(Scroll);
    redraw();
  }

  function toggle():Void
  {
    var m = mods[selected];
    var list = GoldenMods.getList();
    list.setEnabled(m.dir, !list.isEnabled(m.dir));
    trace('[GOLDEN] Mod selector: ${list.isEnabled(m.dir) ? 'enabled' : 'disabled'} "${m.dir}" (applies on Enter/reload)');
    try
    {
      list.save();
    }
    catch (e:Dynamic)
    {
      trace('[GOLDEN] Could not save mod list: $e');
      UISound.play(Error);
    }
    changed = true;
    UISound.play(Toggle);
    redraw();
  }

  function apply():Void
  {
    UISound.play(Select);
    trace('[GOLDEN] Mod selector: applying changes (reload)');
    PolymodHandler.forceReloadAssets();
    close();
    FlxG.resetState();
  }

  function openManager():Void
  {
    UISound.play(Select);
    close();
    FlxG.switchState(() -> new ModManagerState());
  }

  override function destroy():Void
  {
    if (iconGraphic != null)
    {
      iconGraphic.persist = false;
      FlxG.bitmap.remove(iconGraphic);
      iconGraphic = null;
    }
    super.destroy();
  }
}
