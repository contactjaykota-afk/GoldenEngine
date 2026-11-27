package golden.ui;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import golden.audio.UISound;

/** Golden Engine colour palette and small UI helpers shared by Golden menus. */
class GoldenUI
{
  public static inline var GOLD:FlxColor = 0xFFFFC83D;
  public static inline var GOLD_DARK:FlxColor = 0xFF8A6410;
  public static inline var PANEL:FlxColor = 0xE0141018;
  public static inline var PANEL_LIGHT:FlxColor = 0xF0262030;
  public static inline var TEXT:FlxColor = 0xFFF4EEDD;
  public static inline var MUTED:FlxColor = 0xFF9A93A8;
  public static inline var OK:FlxColor = 0xFF6BE36B;
  public static inline var WARN:FlxColor = 0xFFFFB347;
  public static inline var BAD:FlxColor = 0xFFFF5C5C;

  public static final FONT:String = 'VCR OSD Mono';

  public static function text(x:Float, y:Float, w:Float, str:String, size:Int = 16, color:FlxColor = TEXT):FlxText
  {
    var t = new FlxText(x, y, w, str, size);
    t.setFormat(Paths.font('vcr.ttf'), size, color, LEFT);
    t.scrollFactor.set();
    return t;
  }

  public static function panel(x:Float, y:Float, w:Int, h:Int, color:FlxColor = PANEL):FlxSprite
  {
    var s = new FlxSprite(x, y).makeGraphic(w, h, color);
    s.scrollFactor.set();
    return s;
  }
}

/**
 * A clickable text button with hover feedback. Fires `onClick` on mouse release over it.
 * Keyboard/controller users reach the same action through the shortcut shown in its label.
 */
class GoldenButton extends FlxSpriteGroup
{
  public var onClick:Null<Void->Void>;
  public var enabled(default, set):Bool = true;

  var bg:FlxSprite;
  var label:FlxText;
  var hovered:Bool = false;

  public function new(x:Float, y:Float, w:Int, h:Int, caption:String, ?onClick:Void->Void)
  {
    super(x, y);
    this.onClick = onClick;
    bg = new FlxSprite().makeGraphic(w, h, FlxColor.WHITE);
    bg.color = GoldenUI.PANEL_LIGHT;
    add(bg);
    label = new FlxText(0, 0, w, caption, 14);
    label.setFormat(Paths.font('vcr.ttf'), 14, GoldenUI.TEXT, CENTER);
    label.y = Std.int((h - label.height) / 2);
    add(label);
    scrollFactor.set();
  }

  function set_enabled(v:Bool):Bool
  {
    enabled = v;
    alpha = v ? 1 : 0.4;
    return v;
  }

  public function setCaption(c:String):Void
    label.text = c;

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (!visible || !enabled) return;
    var over = FlxG.mouse.visible && FlxG.mouse.overlaps(bg, camera);
    if (over != hovered)
    {
      hovered = over;
      bg.color = over ? GoldenUI.GOLD_DARK : GoldenUI.PANEL_LIGHT;
      label.color = over ? FlxColor.WHITE : GoldenUI.TEXT;
      if (over) UISound.play(Hover);
    }
    if (over && FlxG.mouse.justReleased && onClick != null) onClick();
  }
}
