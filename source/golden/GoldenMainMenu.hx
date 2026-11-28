package golden;

import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.display.BitmapData;

/**
 * Golden Engine — custom main menu (made in the Main Menu Editor), from `data/golden/mainmenu.json`
 * of the enabled mods:
 *
 *   { "version": 1, "background": "menuBG", "backgroundColor": "#FFFFFF", "logo": "", "logoX": 640,
 *     "logoY": 120, "logoScale": 1, "music": "", "spacing": 0, "offsetX": 0,
 *     "items": [ { "id": "storymode", "visible": true }, ... ],
 *     "custom": [ { "label": "PLAY BOPEEBO", "action": "song:bopeebo", "atlas": "" } ] }
 *
 * Built-in entries keep their behaviour; "items" sets their order and visibility. Custom entries open a
 * screen ("state:freeplay|story|options|credits|mods|editors"), start a song ("song:<id>") or open a
 * web page ("url:<address>"). Without an atlas, a button graphic is generated from the label.
 */
class GoldenMainMenu
{
  public static var config(get, never):Null<Dynamic>;
  static var cache:Null<Dynamic> = null;
  static var cacheTried:Bool = false;

  public static function clearCache():Void
  {
    cache = null;
    cacheTried = false;
  }

  static function get_config():Null<Dynamic>
  {
    if (cacheTried) return cache;
    cacheTried = true;
    var p = Paths.json('golden/mainmenu');
    if (!Assets.exists(p)) return null;
    try
    {
      cache = haxe.Json.parse(Assets.getText(p));
      trace('[GOLDEN] Main menu config loaded (${(cache.custom : Array<Dynamic>)?.length ?? 0} custom entries)');
    }
    catch (e:Dynamic)
    {
      trace('[GOLDEN] Invalid $p: $e');
      cache = null;
    }
    return cache;
  }

  public static function applyBackground(bg:FlxSprite):Void
  {
    var c = config;
    if (c == null) return;
    var key:String = c.background ?? '';
    if (key != '' && key != 'menuBG' && Assets.exists(Paths.image(key)))
    {
      bg.loadGraphic(Paths.image(key));
      bg.setGraphicSize(Std.int(FlxG.width * 1.2));
      bg.updateHitbox();
      bg.screenCenter();
    }
    var col:String = c.backgroundColor ?? '';
    if (col != '') bg.color = FlxColor.fromString(col) ?? FlxColor.WHITE;
  }

  public static function logo():Null<FlxSprite>
  {
    var c = config;
    if (c == null || c.logo == null || c.logo == '' || !Assets.exists(Paths.image(c.logo))) return null;
    var s = new FlxSprite().loadGraphic(Paths.image(c.logo));
    var sc:Float = c.logoScale ?? 1;
    s.scale.set(sc, sc);
    s.updateHitbox();
    s.x = (c.logoX ?? FlxG.width / 2) - s.width / 2;
    s.y = (c.logoY ?? 100) - s.height / 2;
    s.scrollFactor.set();
    return s;
  }

  public static function musicKey():Null<String>
  {
    var c = config;
    var k:String = c?.music ?? '';
    if (k == '') return null;
    return Assets.exists(Paths.music('$k/$k')) ? k : null;
  }

  /** Button frames ("<name> idle" / "<name> selected") generated from a label. */
  public static function labelFrames(name:String, label:String):FlxAtlasFrames
  {
    var t = new FlxText(0, 0, 0, label, 64);
    t.setFormat(Paths.font('vcr.ttf'), 64, FlxColor.WHITE, CENTER, OUTLINE, 0xFF1A1424);
    t.borderSize = 5;
    t.drawFrame(true);
    var w = Std.int(t.width) + 20, h = Std.int(t.height) + 10;
    var bmp = new BitmapData(w, h * 2, true, 0);
    bmp.copyPixels(t.pixels, t.pixels.rect, new openfl.geom.Point(10, 5));
    t.color = 0xFFFFC83D;
    t.drawFrame(true);
    var gold = t.pixels.clone();
    gold.colorTransform(gold.rect, new openfl.geom.ColorTransform(1, 0.78, 0.24, 1));
    bmp.copyPixels(gold, gold.rect, new openfl.geom.Point(10, h + 5));
    t.destroy();
    var frames = new FlxAtlasFrames(FlxGraphic.fromBitmapData(bmp, false, 'golden-menu-$name', false));
    frames.addAtlasFrame(FlxRect.get(0, 0, w, h), FlxPoint.get(w, h), FlxPoint.get(0, 0), '$name idle0000');
    frames.addAtlasFrame(FlxRect.get(0, h, w, h), FlxPoint.get(w, h), FlxPoint.get(0, 0), '$name selected0000');
    return frames;
  }

  /** Callback for a custom entry's action. */
  public static function actionFor(action:String):Void->Void
  {
    var parts = (action ?? '').split(':');
    var kind = parts.shift();
    var arg = parts.join(':');
    return () ->
    {
      trace('[GOLDEN] Custom menu entry: $action');
      switch (kind)
      {
        case 'song':
          var err = golden.studio.GoldenStudio.playSong(arg, 'normal');
          if (err != null) trace('[GOLDEN] $err');
        case 'url':
          FlxG.openURL(arg);
        case 'state':
          switch (arg)
          {
            case 'freeplay': FlxG.switchState(() -> new funkin.ui.freeplay.FreeplayState());
            case 'story': FlxG.switchState(() -> new funkin.ui.story.StoryMenuState());
            case 'options': FlxG.switchState(() -> new funkin.ui.options.OptionsState());
            case 'credits': FlxG.switchState(() -> new funkin.ui.credits.CreditsState());
            case 'mods': FlxG.switchState(() -> new golden.ui.ModManagerState());
            case 'editors': FlxG.switchState(() -> new golden.editor.EditorHubState());
            default: trace('[GOLDEN] Unknown screen "$arg"');
          }
        default:
          trace('[GOLDEN] Unknown menu action "$action"');
      }
    };
  }
}
