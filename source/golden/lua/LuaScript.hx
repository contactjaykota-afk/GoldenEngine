package golden.lua;

#if FEATURE_LUA
import hxluajit.Lua;
import hxluajit.LuaJIT;
import hxluajit.LuaL;
import hxluajit.Types;

/**
 * Golden Engine — one Lua script (its own LuaJIT state).
 *
 * Sandbox: only base/table/string/math/bit libraries are usable; `io`, `debug`, `package`, `require`,
 * `dofile`, `loadfile`, `ffi` and `jit` are removed and `os` only keeps clock/time/date. The JIT is
 * switched off so the instruction-count hook can stop runaway loops: any single call that runs longer
 * than `TIMEOUT_SECONDS` is aborted with a Lua error instead of freezing the game.
 *
 * Errors never throw into the game: they are logged (with the script name and line) and kept in
 * `lastError` / GoldenLua.errors for the debug tools.
 */
class LuaScript
{
  public static inline var TIMEOUT_SECONDS:Float = 2.0;

  /** Script currently executing (all Lua runs on the main thread, one call at a time). */
  public static var current(default, null):Null<LuaScript> = null;

  static var callStarted:Float = 0;

  public var name(default, null):String;
  public var lastError(default, null):Null<String> = null;
  public var closed(default, null):Bool = false;

  var L:cpp.RawPointer<Lua_State>;
  var missingFunctions:Map<String, Bool> = [];

  public function new(name:String, source:String)
  {
    this.name = name;
    L = LuaL.newstate();
    LuaL.openlibs(L);
    LuaJIT.setmode(L, 0, LuaJIT.MODE_ENGINE | LuaJIT.MODE_OFF);
    sandbox();
    LuaApi.register(L);
    Lua.sethook(L, cpp.Function.fromStaticFunction(timeoutHook), Lua.MASKCOUNT, 10000);

    var prev = current;
    current = this;
    callStarted = haxe.Timer.stamp();
    var status = LuaL.loadbuffer(L, source, source.length, '@' + name);
    if (status == Lua.OK) status = Lua.pcall(L, 0, 0, 0);
    if (status != Lua.OK) fail('load', popError());
    current = prev;
  }

  function sandbox():Void
  {
    for (g in ['io', 'debug', 'package', 'require', 'dofile', 'loadfile', 'module', 'jit', 'ffi', 'newproxy'])
    {
      Lua.pushnil(L);
      Lua.setglobal(L, g);
    }
    // os: keep only harmless time functions.
    Lua.getglobal(L, 'os');
    var hasOs = Lua.istable(L, -1) == 1;
    Lua.createtable(L, 0, 3);
    if (hasOs) for (f in ['clock', 'time', 'date'])
    {
      Lua.getfield(L, -2, f);
      Lua.setfield(L, -2, f);
    }
    Lua.setglobal(L, 'os');
    Lua.pop(L, 1);
  }

  static function timeoutHook(L:cpp.RawPointer<Lua_State>, ar:cpp.RawPointer<Lua_Debug>):Void
  {
    if (haxe.Timer.stamp() - callStarted > TIMEOUT_SECONDS) LuaL.error(L, 'script timed out (ran longer than 2 seconds without returning)');
  }

  /** True if the script defines a global function `fn` (cached). */
  public function hasFunction(fn:String):Bool
  {
    if (closed) return false;
    if (missingFunctions.exists(fn)) return !missingFunctions.get(fn);
    Lua.getglobal(L, fn);
    var isFn = Lua.isfunction(L, -1) == 1;
    Lua.pop(L, 1);
    missingFunctions.set(fn, !isFn);
    return isFn;
  }

  /**
   * Call global function `fn` with `args`. Returns its first result converted to Haxe (or null).
   * Missing functions are ignored silently (callbacks are optional); errors are logged.
   */
  public function call(fn:String, ?args:Array<Dynamic>):Dynamic
  {
    if (closed || !hasFunction(fn)) return null;
    var prev = current;
    current = this;
    callStarted = haxe.Timer.stamp();
    Lua.getglobal(L, fn);
    var n = 0;
    if (args != null) for (a in args)
    {
      pushValue(L, a);
      n++;
    }
    var result:Dynamic = null;
    if (Lua.pcall(L, n, 1, 0) != Lua.OK) fail(fn, popError());
    else
    {
      result = toHaxe(L, -1);
      Lua.pop(L, 1);
    }
    current = prev;
    return result;
  }

  /** Set a global variable in this script. */
  public function setGlobal(key:String, value:Dynamic):Void
  {
    if (closed) return;
    pushValue(L, value);
    Lua.setglobal(L, key);
  }

  function popError():String
  {
    var msg = Lua.isstring(L, -1) == 1 ? Std.string(Lua.tostring(L, -1)) : 'unknown error';
    Lua.pop(L, 1);
    return msg;
  }

  function fail(where:String, msg:String):Void
  {
    lastError = msg;
    var line = '$msg (in $where)';
    trace('[LUA] ERROR $line');
    GoldenLua.reportError(name, line);
  }

  public function close():Void
  {
    if (closed) return;
    closed = true;
    Lua.close(L);
    L = null;
  }

  // --- value conversion ---------------------------------------------------------------------

  public static function pushValue(L:cpp.RawPointer<Lua_State>, v:Dynamic):Void
  {
    if (v == null) Lua.pushnil(L);
    else if (Std.isOfType(v, Bool)) Lua.pushboolean(L, v ? 1 : 0);
    else if (Std.isOfType(v, Int) || Std.isOfType(v, Float)) Lua.pushnumber(L, v);
    else if (Std.isOfType(v, String)) Lua.pushstring(L, (v : String));
    else if (Std.isOfType(v, Array))
    {
      var arr:Array<Dynamic> = v;
      Lua.createtable(L, arr.length, 0);
      for (i in 0...arr.length)
      {
        pushValue(L, arr[i]);
        Lua.rawseti(L, -2, i + 1);
      }
    }
    else if (Reflect.isObject(v) && Type.getClass(v) == null)
    {
      var fields = Reflect.fields(v);
      Lua.createtable(L, 0, fields.length);
      for (f in fields)
      {
        pushValue(L, Reflect.field(v, f));
        Lua.setfield(L, -2, f);
      }
    }
    else
      Lua.pushstring(L, Std.string(v));
  }

  public static function toHaxe(L:cpp.RawPointer<Lua_State>, idx:Int, depth:Int = 0):Dynamic
  {
    var t = Lua.type(L, idx);
    if (t == Lua.TNIL) return null;
    if (t == Lua.TBOOLEAN) return Lua.toboolean(L, idx) == 1;
    if (t == Lua.TNUMBER)
    {
      var f:Float = Lua.tonumber(L, idx);
      return (f == Math.ffloor(f) && Math.abs(f) < 2147483647) ? Std.int(f) : f;
    }
    if (t == Lua.TSTRING) return Std.string(Lua.tostring(L, idx));
    if (t == Lua.TTABLE && depth < 8)
    {
      var absIdx = idx < 0 ? Lua.gettop(L) + idx + 1 : idx;
      var obj:Dynamic = {};
      var arr:Array<Dynamic> = [];
      var isArray = true;
      Lua.pushnil(L);
      while (Lua.next(L, absIdx) != 0)
      {
        var value = toHaxe(L, -1, depth + 1);
        if (Lua.type(L, -2) == Lua.TNUMBER)
        {
          arr[Std.int(Lua.tonumber(L, -2)) - 1] = value;
          Reflect.setField(obj, Std.string(Lua.tonumber(L, -2)), value);
        }
        else
        {
          isArray = false;
          Reflect.setField(obj, Std.string(Lua.tostring(L, -2)), value);
        }
        Lua.pop(L, 1);
      }
      return isArray ? arr : obj;
    }
    return null;
  }
}
#end
