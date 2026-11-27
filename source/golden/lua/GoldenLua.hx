package golden.lua;

/**
 * Golden Engine — Lua script manager.
 *
 * While a song is playing, these scripts run (only from the base game and ENABLED mods, because they
 * are found through the game's asset system, which Polymod restricts to loaded mods):
 * - `scripts/lua/*.lua`              global gameplay scripts (every song)
 * - `data/songs/<songId>/*.lua`      scripts for one song
 * - `scripts/events/<name>.lua`      run by the "Lua Script" chart event (see GoldenLuaSongEvent)
 *
 * Callbacks a script may define: onCreate, onSongStart, onBeatHit(beat), onStepHit(step),
 * onUpdate(elapsed), onNoteHit(direction, isPlayer, kind), onNoteMiss(direction), onEvent(name, value),
 * onPause, onResume, onGameOver, onSongEnd, onDestroy.
 */
class GoldenLua
{
  /** Shared variables (setVar/getVar) between scripts of the current song. */
  public static var vars:Map<String, Dynamic> = [];

  /** Recent errors (script name + message), newest last; shown by debug tools. */
  public static var errors(default, null):Array<String> = [];

  /** Recent print() output. */
  public static var output(default, null):Array<String> = [];

  #if FEATURE_LUA
  public static var scripts(default, null):Array<LuaScript> = [];
  static var eventScripts:Map<String, LuaScript> = [];
  #end

  public static function reportError(script:String, message:String):Void
  {
    errors.push('$script: $message');
    if (errors.length > 100) errors.shift();
  }

  public static function log(script:String, message:String):Void
  {
    output.push('$script: $message');
    if (output.length > 200) output.shift();
  }

  public static var available(get, never):Bool;

  static function get_available():Bool
    return #if FEATURE_LUA true #else false #end;

  /** Load the global and per-song scripts for `songId` (closes any previous ones). */
  public static function startSong(songId:String):Void
  {
    #if FEATURE_LUA
    stopAll();
    vars = [];
    var paths = listLua('assets/scripts/lua/').concat(listLua('assets/data/songs/$songId/'));
    for (p in paths)
    {
      var s = loadScript(p);
      if (s != null) scripts.push(s);
    }
    if (paths.length > 0) trace('[LUA] Song "$songId": ${scripts.length} script(s) loaded: ${paths.join(', ')}');
    callAll('onCreate');
    #end
  }

  /** Close every running script (song ended / left gameplay / mods reloaded). */
  public static function stopAll():Void
  {
    #if FEATURE_LUA
    if (scripts.length > 0) callAll('onDestroy');
    for (s in scripts)
      s.close();
    scripts = [];
    for (s in eventScripts)
      s.close();
    eventScripts = [];
    #end
  }

  public static function callAll(fn:String, ?args:Array<Dynamic>):Void
  {
    #if FEATURE_LUA
    for (s in scripts)
      s.call(fn, args);
    #end
  }

  /** Run `scripts/events/<name>.lua`'s onEvent(value) (script is loaded once per song and kept). */
  public static function runEventScript(name:String, value:Dynamic):Bool
  {
    #if FEATURE_LUA
    var s = eventScripts.get(name);
    if (s == null)
    {
      var path = 'assets/scripts/events/$name.lua';
      if (!Assets.exists(path))
      {
        reportError(name, 'Lua event script not found: $path');
        trace('[LUA] ERROR Lua event script not found: $path');
        return false;
      }
      s = loadScript(path);
      if (s == null) return false;
      eventScripts.set(name, s);
    }
    s.call('onEvent', [name, value]);
    return true;
    #else
    reportError(name, 'Lua is not available in this build.');
    return false;
    #end
  }

  #if FEATURE_LUA
  static function loadScript(path:String):Null<LuaScript>
  {
    var src:String;
    try
    {
      src = Assets.getText(path);
    }
    catch (e:Dynamic)
    {
      reportError(path, 'could not read: $e');
      return null;
    }
    if (src == null) return null;
    var s = new LuaScript(path, src);
    return s;
  }

  static function listLua(prefix:String):Array<String>
  {
    // Asset IDs look like "assets/scripts/lua/x.lua" (Polymod only lists files of loaded mods).
    var out:Array<String> = [];
    for (p in Assets.list())
      if (p.startsWith(prefix) && p.endsWith('.lua') && p.substr(prefix.length).indexOf('/') < 0 && !out.contains(p)) out.push(p);
    out.sort(Reflect.compare);
    return out;
  }
  #end
}
