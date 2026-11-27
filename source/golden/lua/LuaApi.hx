package golden.lua;

#if FEATURE_LUA
import funkin.play.PlayState;
import hxluajit.Lua;
import hxluajit.Types;

/**
 * Golden Engine — functions Lua scripts can call. A deliberately small, documented API (see
 * golden/release/MODDING.md); no reflection into arbitrary game objects and no file/system access.
 *
 * Every function catches Haxe errors and returns nil instead of unwinding through the Lua VM; the
 * problem is logged against the calling script.
 */
class LuaApi
{
  public static final FUNCTIONS:Array<String> = [
    'print', 'getSongPosition', 'getBPM', 'getBeat', 'getStep', 'getSongName', 'getDifficulty', 'getHealth', 'setHealth', 'addHealth',
    'getScore', 'addScore', 'cameraFlash', 'cameraShake', 'setCameraZoom', 'playAnimation', 'playSound', 'setHUDVisible', 'setVar', 'getVar'
  ];

  public static function register(L:cpp.RawPointer<Lua_State>):Void
  {
    reg(L, 'print', cpp.Function.fromStaticFunction(l_print));
    reg(L, 'getSongPosition', cpp.Function.fromStaticFunction(l_getSongPosition));
    reg(L, 'getBPM', cpp.Function.fromStaticFunction(l_getBPM));
    reg(L, 'getBeat', cpp.Function.fromStaticFunction(l_getBeat));
    reg(L, 'getStep', cpp.Function.fromStaticFunction(l_getStep));
    reg(L, 'getSongName', cpp.Function.fromStaticFunction(l_getSongName));
    reg(L, 'getDifficulty', cpp.Function.fromStaticFunction(l_getDifficulty));
    reg(L, 'getHealth', cpp.Function.fromStaticFunction(l_getHealth));
    reg(L, 'setHealth', cpp.Function.fromStaticFunction(l_setHealth));
    reg(L, 'addHealth', cpp.Function.fromStaticFunction(l_addHealth));
    reg(L, 'getScore', cpp.Function.fromStaticFunction(l_getScore));
    reg(L, 'addScore', cpp.Function.fromStaticFunction(l_addScore));
    reg(L, 'cameraFlash', cpp.Function.fromStaticFunction(l_cameraFlash));
    reg(L, 'cameraShake', cpp.Function.fromStaticFunction(l_cameraShake));
    reg(L, 'setCameraZoom', cpp.Function.fromStaticFunction(l_setCameraZoom));
    reg(L, 'playAnimation', cpp.Function.fromStaticFunction(l_playAnimation));
    reg(L, 'playSound', cpp.Function.fromStaticFunction(l_playSound));
    reg(L, 'setHUDVisible', cpp.Function.fromStaticFunction(l_setHUDVisible));
    reg(L, 'setVar', cpp.Function.fromStaticFunction(l_setVar));
    reg(L, 'getVar', cpp.Function.fromStaticFunction(l_getVar));
  }

  static inline function reg(L:cpp.RawPointer<Lua_State>, name:String, f:Lua_CFunction):Void
  {
    Lua.pushcfunction(L, f);
    Lua.setglobal(L, name);
  }

  static function scriptName():String
    return LuaScript.current?.name ?? '?';

  static function apiError(fn:String, e:Dynamic):Int
  {
    var msg = '$fn(): $e';
    trace('[LUA] ERROR ${scriptName()}: $msg');
    GoldenLua.reportError(scriptName(), msg);
    return 0;
  }

  static inline function num(L:cpp.RawPointer<Lua_State>, i:Int, def:Float):Float
    return Lua.isnumber(L, i) == 1 ? Lua.tonumber(L, i) : def;

  static inline function str(L:cpp.RawPointer<Lua_State>, i:Int, def:String):String
    return Lua.isstring(L, i) == 1 ? Std.string(Lua.tostring(L, i)) : def;

  static inline function play():Null<PlayState>
    return PlayState.instance;

  // --- functions ------------------------------------------------------------------------------

  static function l_print(L:cpp.RawPointer<Lua_State>):Int
  {
    var parts = [for (i in 1...Lua.gettop(L) + 1) Std.string(LuaScript.toHaxe(L, i))];
    var line = parts.join(' ');
    trace('[LUA] ${scriptName()}: $line');
    GoldenLua.log(scriptName(), line);
    return 0;
  }

  static function l_getSongPosition(L:cpp.RawPointer<Lua_State>):Int
  {
    Lua.pushnumber(L, funkin.Conductor.instance.songPosition);
    return 1;
  }

  static function l_getBPM(L:cpp.RawPointer<Lua_State>):Int
  {
    Lua.pushnumber(L, funkin.Conductor.instance.bpm);
    return 1;
  }

  static function l_getBeat(L:cpp.RawPointer<Lua_State>):Int
  {
    Lua.pushnumber(L, funkin.Conductor.instance.currentBeat);
    return 1;
  }

  static function l_getStep(L:cpp.RawPointer<Lua_State>):Int
  {
    Lua.pushnumber(L, funkin.Conductor.instance.currentStep);
    return 1;
  }

  static function l_getSongName(L:cpp.RawPointer<Lua_State>):Int
  {
    var p = play();
    if (p == null || p.currentSong == null) Lua.pushnil(L);
    else
      Lua.pushstring(L, p.currentSong.id);
    return 1;
  }

  static function l_getDifficulty(L:cpp.RawPointer<Lua_State>):Int
  {
    var p = play();
    if (p == null) Lua.pushnil(L);
    else
      Lua.pushstring(L, p.currentDifficulty);
    return 1;
  }

  static function l_getHealth(L:cpp.RawPointer<Lua_State>):Int
  {
    var p = play();
    if (p == null) Lua.pushnil(L);
    else
      Lua.pushnumber(L, p.health);
    return 1;
  }

  static function l_setHealth(L:cpp.RawPointer<Lua_State>):Int
  {
    var p = play();
    if (p != null) p.health = Math.max(0, Math.min(Constants.HEALTH_MAX, num(L, 1, p.health)));
    return 0;
  }

  static function l_addHealth(L:cpp.RawPointer<Lua_State>):Int
  {
    var p = play();
    if (p != null) p.health = Math.max(0, Math.min(Constants.HEALTH_MAX, p.health + num(L, 1, 0)));
    return 0;
  }

  static function l_getScore(L:cpp.RawPointer<Lua_State>):Int
  {
    var p = play();
    if (p == null) Lua.pushnil(L);
    else
      Lua.pushnumber(L, p.songScore);
    return 1;
  }

  static function l_addScore(L:cpp.RawPointer<Lua_State>):Int
  {
    var p = play();
    if (p != null) p.songScore += Std.int(num(L, 1, 0));
    return 0;
  }

  static function l_cameraFlash(L:cpp.RawPointer<Lua_State>):Int
  {
    try
    {
      var p = play();
      if (p != null) p.camGame.flash(flixel.util.FlxColor.fromString(str(L, 1, '#FFFFFF')) ?? flixel.util.FlxColor.WHITE, num(L, 2, 0.5), null, true);
    }
    catch (e:Dynamic)
      return apiError('cameraFlash', e);
    return 0;
  }

  static function l_cameraShake(L:cpp.RawPointer<Lua_State>):Int
  {
    try
    {
      var p = play();
      if (p != null) p.camGame.shake(num(L, 1, 0.01), num(L, 2, 0.25));
    }
    catch (e:Dynamic)
      return apiError('cameraShake', e);
    return 0;
  }

  static function l_setCameraZoom(L:cpp.RawPointer<Lua_State>):Int
  {
    try
    {
      var p = play();
      if (p != null) p.currentCameraZoom = num(L, 1, p.currentCameraZoom);
    }
    catch (e:Dynamic)
      return apiError('setCameraZoom', e);
    return 0;
  }

  static function l_playAnimation(L:cpp.RawPointer<Lua_State>):Int
  {
    try
    {
      var p = play();
      var stage = p?.currentStage;
      if (stage == null) return 0;
      var who = str(L, 1, 'bf');
      var ch = switch (who)
      {
        case 'dad' | 'opponent': stage.getDad();
        case 'gf' | 'girlfriend': stage.getGirlfriend();
        default: stage.getBoyfriend();
      }
      if (ch != null) ch.playAnimation(str(L, 2, 'idle'), Lua.toboolean(L, 3) == 1);
    }
    catch (e:Dynamic)
      return apiError('playAnimation', e);
    return 0;
  }

  static function l_playSound(L:cpp.RawPointer<Lua_State>):Int
  {
    try
    {
      var key = str(L, 1, '');
      if (key != '') funkin.audio.FunkinSound.playOnce(Paths.sound(key), num(L, 2, 1));
    }
    catch (e:Dynamic)
      return apiError('playSound', e);
    return 0;
  }

  static function l_setHUDVisible(L:cpp.RawPointer<Lua_State>):Int
  {
    var p = play();
    if (p != null) p.camHUD.visible = Lua.toboolean(L, 1) == 1;
    return 0;
  }

  static function l_setVar(L:cpp.RawPointer<Lua_State>):Int
  {
    GoldenLua.vars.set(str(L, 1, ''), LuaScript.toHaxe(L, 2));
    return 0;
  }

  static function l_getVar(L:cpp.RawPointer<Lua_State>):Int
  {
    LuaScript.pushValue(L, GoldenLua.vars.get(str(L, 1, '')));
    return 1;
  }
}
#end
