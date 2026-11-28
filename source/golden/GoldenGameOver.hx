package golden;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/**
 * Golden Engine — Game Over setups (made in the Game Over Editor), read from
 * `data/golden/gameover.json` of the enabled mods:
 *
 *   { "version": 1, "perSong": false,
 *     "default": { "character": "", "music": "", "musicEnd": "", "sound": "", "background": "#000000",
 *                  "backgroundImage": "", "backgroundAlpha": 1, "cameraZoom": 1, "text": "", "textColor": "#FFFFFF" },
 *     "setups": { "spooky": { ...same fields... } },
 *     "songs": { "bopeebo": "spooky" } }
 *
 * Empty fields keep FNF's behaviour. `music` is a key in the music folder (music/<key>.ogg).
 * With "perSong": false every song uses "default".
 */
class GoldenGameOver
{
  public static final FIELDS:Array<String> = ['character', 'music', 'musicEnd', 'sound', 'background', 'backgroundImage', 'backgroundAlpha', 'cameraZoom', 'text', 'textColor'];

  public static function defaultSetup():Dynamic
    return {
      character: '',
      music: '',
      musicEnd: '',
      sound: '',
      background: '#000000',
      backgroundImage: '',
      backgroundAlpha: 1,
      cameraZoom: 1,
      text: '',
      textColor: '#FFFFFF'
    };

  public static function defaultConfig():Dynamic
    return {version: 1, perSong: false, 'default': defaultSetup(), setups: {}, songs: {}};

  /** The setup for a song, or null if no config exists. */
  public static function setupFor(songId:Null<String>):Null<Dynamic>
  {
    var path = Paths.json('golden/gameover');
    if (!Assets.exists(path)) return null;
    var cfg:Dynamic = null;
    try
    {
      cfg = haxe.Json.parse(Assets.getText(path));
    }
    catch (e:Dynamic)
    {
      trace('[GOLDEN] Invalid $path: $e');
      return null;
    }
    var setup:Dynamic = Reflect.field(cfg, 'default');
    if (cfg.perSong == true && songId != null && cfg.songs != null)
    {
      var name:String = Reflect.field(cfg.songs, songId);
      if (name != null && cfg.setups != null && Reflect.field(cfg.setups, name) != null) setup = Reflect.field(cfg.setups, name);
    }
    return setup;
  }

  static function str(s:Dynamic, f:String):String
  {
    var v:Dynamic = s != null ? Reflect.field(s, f) : null;
    return v == null ? '' : Std.string(v);
  }

  /** Custom game over music (null = FNF default). */
  public static function musicPath(songId:Null<String>, ending:Bool):Null<String>
  {
    var s = setupFor(songId);
    var key = str(s, ending ? 'musicEnd' : 'music');
    if (key == '') return null;
    var p = Paths.music(key);
    if (Assets.exists(p)) return p;
    trace('[GOLDEN] Game Over music "$key" not found ($p); using the default');
    return null;
  }

  public static function soundPath(songId:Null<String>):Null<String>
  {
    var key = str(setupFor(songId), 'sound');
    if (key == '') return null;
    var p = Paths.sound(key);
    return Assets.exists(p) ? p : null;
  }

  /** Apply visuals to a GameOverSubState (called from its create()). */
  public static function applyVisuals(state:flixel.FlxState, bg:FlxSprite, songId:Null<String>):Null<Dynamic>
  {
    var s = setupFor(songId);
    if (s == null) return null;
    trace('[GOLDEN] Game Over setup for "$songId": ${haxe.Json.stringify(s)}');
    var col = str(s, 'background');
    if (col != '') bg.color = FlxColor.fromString(col) ?? FlxColor.BLACK;
    var img = str(s, 'backgroundImage');
    if (img != '' && Assets.exists(Paths.image(img)))
    {
      var spr = new FlxSprite().loadGraphic(Paths.image(img));
      spr.setGraphicSize(FlxG.width, FlxG.height);
      spr.updateHitbox();
      spr.scrollFactor.set();
      spr.alpha = Std.parseFloat(str(s, 'backgroundAlpha')) ?? 1;
      state.insert(state.members.indexOf(bg) + 1, spr);
    }
    var text = str(s, 'text');
    if (text != '')
    {
      var t = new FlxText(0, FlxG.height - 140, FlxG.width, text, 40);
      t.setFormat(Paths.font('vcr.ttf'), 40, FlxColor.fromString(str(s, 'textColor')) ?? FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
      t.scrollFactor.set();
      state.add(t);
    }
    return s;
  }

  /** Character id to use instead of the player's, or null. */
  public static function characterFor(songId:Null<String>):Null<String>
  {
    var c = str(setupFor(songId), 'character');
    return c == '' ? null : c;
  }

  public static function zoomFor(songId:Null<String>):Float
  {
    var z = Std.parseFloat(str(setupFor(songId), 'cameraZoom'));
    return Math.isNaN(z) || z <= 0 ? 1 : z;
  }
}
