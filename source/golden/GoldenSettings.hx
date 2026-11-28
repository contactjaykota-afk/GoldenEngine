package golden;

#if sys
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Golden Engine — settings that belong to the engine rather than to FNF's save file.
 *
 * Stored as `golden-settings.json` next to the `mods` folder (same place as `golden-mods.json`),
 * so upstream's save format and its migrations stay untouched. A corrupted file is backed up as
 * `.bak` and defaults are used; the problem is logged, never swallowed silently.
 */
class GoldenSettings
{
  public static inline var FILE_NAME:String = 'golden-settings.json';

  /** Developer Mode: unlocks editors, debug tools, the Tab mod selector and the performance monitor. Off by default. */
  public static var developerMode(default, set):Bool = false;

  /** Volume of menu/UI sounds (0..1), multiplied with the master volume. Separate from music and gameplay. */
  public static var uiVolume(default, set):Float = 1.0;

  /** Show the Golden performance monitor overlay (only while Developer Mode is on). */
  public static var perfMonitor(default, set):Bool = false;

  /** Menu music: "golden" (Golden Engine theme, default) or "classic" (FNF's Freaky Menu). */
  public static var menuMusic(default, set):String = 'golden';

  /** Key (FlxKey name) that opens the Chart Editor from gameplay/menus in Developer Mode. */
  public static var chartEditorKey(default, set):String = 'SEVEN';

  /** Key (FlxKey name) that opens the mod selector in Developer Mode. */
  public static var modSelectorKey(default, set):String = 'TAB';

  /** Mod folder the Golden editors save into (see golden.editor.EditorFiles). */
  public static var editorTarget(default, set):Null<String> = null;

  /** Graphics preset: low, medium, high, ultra or custom (see golden.GoldenGraphics). */
  public static var graphicsPreset(default, set):String = 'high';

  /** Screen shader effects (Event System colour grading, blur, glitch...): auto | on | off. */
  public static var screenShaders(default, set):String = 'auto';

  /** Ghost tapping: pressing a key with no note nearby is not a miss. On by default. */
  public static var ghostTapping(default, set):Bool = true;

  static function set_ghostTapping(v:Bool):Bool
  {
    ghostTapping = v;
    save();
    return v;
  }

  /** Recently played song ids, newest first (Freeplay "Recently played" sort). */
  public static var recentSongs:Array<String> = [];

  public static function addRecentSong(id:String):Void
  {
    recentSongs.remove(id);
    recentSongs.unshift(id);
    if (recentSongs.length > 40) recentSongs.pop();
    save();
  }

  static var loaded:Bool = false;
  static var suspendSave:Bool = false;

  /** Last load problem, if any (shown in the Golden options page). */
  public static var loadError(default, null):Null<String> = null;

  public static function path():String
  {
    return haxe.io.Path.normalize(haxe.io.Path.join([funkin.modding.PolymodHandler.MOD_FOLDER, '..', FILE_NAME]));
  }

  public static function load():Void
  {
    loaded = true;
    #if sys
    var p = path();
    if (!FileSystem.exists(p)) return;
    suspendSave = true;
    try
    {
      var data:Dynamic = Json.parse(File.getContent(p));
      if (Reflect.hasField(data, 'developerMode')) developerMode = Reflect.field(data, 'developerMode') == true;
      if (Reflect.hasField(data, 'uiVolume')) uiVolume = Std.parseFloat(Std.string(Reflect.field(data, 'uiVolume')));
      if (Reflect.hasField(data, 'perfMonitor')) perfMonitor = Reflect.field(data, 'perfMonitor') == true;
      if (Reflect.hasField(data, 'menuMusic')) menuMusic = Std.string(Reflect.field(data, 'menuMusic'));
      if (Reflect.hasField(data, 'chartEditorKey')) chartEditorKey = Std.string(Reflect.field(data, 'chartEditorKey'));
      if (Reflect.hasField(data, 'editorTarget')) editorTarget = Reflect.field(data, 'editorTarget');
      if (Reflect.hasField(data, 'recentSongs') && Std.isOfType(Reflect.field(data, 'recentSongs'), Array)) recentSongs = [for (x in (Reflect.field(data, 'recentSongs') : Array<Dynamic>)) Std.string(x)];
      if (Reflect.hasField(data, 'ghostTapping')) ghostTapping = Reflect.field(data, 'ghostTapping') != false;
      if (Reflect.hasField(data, 'screenShaders')) screenShaders = Std.string(Reflect.field(data, 'screenShaders'));
      if (Reflect.hasField(data, 'graphicsPreset')) graphicsPreset = Std.string(Reflect.field(data, 'graphicsPreset'));
      if (Reflect.hasField(data, 'modSelectorKey')) modSelectorKey = Std.string(Reflect.field(data, 'modSelectorKey'));
    }
    catch (e:Dynamic)
    {
      loadError = 'Could not read $p ($e); defaults are used and the file was backed up as $p.bak.';
      trace('[GOLDEN] $loadError');
      try
      {
        File.copy(p, p + '.bak');
      }
      catch (e2:Dynamic)
      {
        trace('[GOLDEN] Could not back up $p: $e2');
      }
    }
    suspendSave = false;
    #end
    trace('[GOLDEN] Settings: developerMode=$developerMode uiVolume=$uiVolume perfMonitor=$perfMonitor');
  }

  public static function save():Void
  {
    if (suspendSave || !loaded) return;
    #if sys
    var p = path();
    try
    {
      var text = Json.stringify({
        version: 1,
        developerMode: developerMode,
        uiVolume: uiVolume,
        perfMonitor: perfMonitor,
        menuMusic: menuMusic,
        chartEditorKey: chartEditorKey,
        modSelectorKey: modSelectorKey,
        editorTarget: editorTarget,
        graphicsPreset: graphicsPreset,
        screenShaders: screenShaders,
        recentSongs: recentSongs,
        ghostTapping: ghostTapping
      }, null, '  ');
      File.saveContent(p + '.tmp', text);
      if (FileSystem.exists(p)) FileSystem.deleteFile(p);
      FileSystem.rename(p + '.tmp', p);
    }
    catch (e:Dynamic)
    {
      trace('[GOLDEN] Could not save settings to $p: $e');
    }
    #end
  }

  /** Reset every developer setting (Developer Mode itself, monitor, shortcuts) to defaults. UI volume is kept. */
  public static function resetDeveloperSettings():Void
  {
    suspendSave = true;
    developerMode = false;
    perfMonitor = false;
    chartEditorKey = 'SEVEN';
    modSelectorKey = 'TAB';
    suspendSave = false;
    save();
    trace('[GOLDEN] Developer settings reset to defaults.');
  }

  static function set_developerMode(v:Bool):Bool
  {
    developerMode = v;
    save();
    return v;
  }

  static function set_uiVolume(v:Float):Float
  {
    if (Math.isNaN(v)) v = 1.0;
    uiVolume = Math.max(0, Math.min(1, v));
    save();
    return uiVolume;
  }

  static function set_perfMonitor(v:Bool):Bool
  {
    perfMonitor = v;
    save();
    return v;
  }

  static function set_menuMusic(v:String):String
  {
    menuMusic = v == 'classic' ? 'classic' : 'golden';
    save();
    return menuMusic;
  }

  /** The music key to use for upstream's "freakyMenu". */
  public static function menuMusicKey():String
    return menuMusic == 'classic' ? 'freakyMenu' : 'goldenMenu';

  static function set_editorTarget(v:Null<String>):Null<String>
  {
    editorTarget = v;
    save();
    return v;
  }

  static function set_graphicsPreset(v:String):String
  {
    graphicsPreset = ['low', 'medium', 'high', 'ultra', 'custom'].contains(v) ? v : 'high';
    save();
    return graphicsPreset;
  }

  static function set_screenShaders(v:String):String
  {
    screenShaders = ['auto', 'on', 'off'].contains(v) ? v : 'auto';
    save();
    return screenShaders;
  }

  /** Whether camera shader/filter effects should be used now. */
  public static function shaderEffectsEnabled():Bool
  {
    if (screenShaders == 'on') return true;
    if (screenShaders == 'off') return false;
    var r = (golden.render.RendererGuard.rendererName ?? '').toLowerCase();
    return !(r.indexOf('llvmpipe') >= 0 || r.indexOf('softpipe') >= 0 || r.indexOf('software') >= 0 || r.indexOf('swrast') >= 0);
  }

  static function set_chartEditorKey(v:String):String
  {
    chartEditorKey = (v == null || v == '') ? 'SEVEN' : v.toUpperCase();
    save();
    return chartEditorKey;
  }

  static function set_modSelectorKey(v:String):String
  {
    modSelectorKey = (v == null || v == '') ? 'TAB' : v.toUpperCase();
    save();
    return modSelectorKey;
  }
}
