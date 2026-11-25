package golden.modding;

#if sys
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Golden Engine — persistent enabled/disabled state for mods.
 *
 * Stored as `golden-mods.json` next to the `mods` folder (not inside any mod, and not in the save
 * file, because upstream loads mods before the save is read). Format:
 *
 * ```json
 * { "version": 1, "order": ["modA", "modB"], "mods": { "modA": { "enabled": true }, "modB": { "enabled": false } } }
 * ```
 *
 * Rules:
 * - A mod folder seen for the first time is enabled (keeps upstream's "drop a mod in the folder" behaviour).
 * - A mod that disappears keeps its entry, so its state comes back if the folder is restored.
 * - Load order is `order`; new mods are appended.
 */
class ModList
{
  public static inline var FILE_NAME:String = 'golden-mods.json';
  public static inline var FORMAT_VERSION:Int = 1;

  public var path(default, null):String;
  public var order(default, null):Array<String> = [];

  var states:Map<String, Bool> = [];

  /** Problem reading the file, if any (the list then starts empty; the bad file is kept as `.bak`). */
  public var loadError(default, null):Null<String> = null;

  public function new(path:String)
  {
    this.path = path;
  }

  /** Path of the list file for a given mods root folder. */
  public static function pathForModRoot(modRoot:String):String
  {
    return haxe.io.Path.normalize(haxe.io.Path.join([modRoot, '..', FILE_NAME]));
  }

  public static function load(path:String):ModList
  {
    var list = new ModList(path);
    #if sys
    if (!FileSystem.exists(path)) return list;
    try
    {
      var data:Dynamic = Json.parse(File.getContent(path));
      var mods:Dynamic = Reflect.field(data, 'mods');
      if (mods != null)
      {
        for (dir in Reflect.fields(mods))
        {
          var entry:Dynamic = Reflect.field(mods, dir);
          list.states.set(dir, entry != null && Reflect.field(entry, 'enabled') != false);
        }
      }
      var order:Dynamic = Reflect.field(data, 'order');
      if (Std.isOfType(order, Array))
      {
        for (dir in (order : Array<Dynamic>))
          if (Std.isOfType(dir, String) && !list.order.contains(dir)) list.order.push(dir);
      }
      for (dir in list.states.keys())
        if (!list.order.contains(dir)) list.order.push(dir);
    }
    catch (e:Dynamic)
    {
      // Never crash on a corrupted list: keep a copy for the user and start fresh.
      list.loadError = 'Could not read $path ($e). A backup was saved as $path.bak and mod states were reset.';
      try
      {
        File.copy(path, path + '.bak');
      }
      catch (_:Dynamic) {}
      list.states = [];
      list.order = [];
    }
    #end
    return list;
  }

  public function save():Void
  {
    #if sys
    var mods:Dynamic = {};
    for (dir in order)
      if (states.exists(dir)) Reflect.setField(mods, dir, {enabled: states.get(dir)});
    var text = Json.stringify({version: FORMAT_VERSION, order: order, mods: mods}, null, '  ');
    // Write to a temp file then replace, so a crash mid-write can't corrupt the list.
    var tmp = path + '.tmp';
    File.saveContent(tmp, text);
    if (FileSystem.exists(path)) FileSystem.deleteFile(path);
    FileSystem.rename(tmp, path);
    #end
  }

  /**
   * Register the mod folders currently installed. New folders are enabled and appended.
   * @return the folders that were seen for the first time
   */
  public function reconcile(installedDirs:Array<String>):Array<String>
  {
    var added:Array<String> = [];
    for (dir in installedDirs)
    {
      if (!states.exists(dir))
      {
        states.set(dir, true);
        added.push(dir);
      }
      if (!order.contains(dir)) order.push(dir);
    }
    return added;
  }

  public function isKnown(dir:String):Bool
  {
    return states.exists(dir);
  }

  public function isEnabled(dir:String):Bool
  {
    return states.exists(dir) && states.get(dir) == true;
  }

  public function setEnabled(dir:String, enabled:Bool):Void
  {
    states.set(dir, enabled);
    if (!order.contains(dir)) order.push(dir);
  }

  public function remove(dir:String):Void
  {
    states.remove(dir);
    order.remove(dir);
  }

  /** Enabled folders, in load order, restricted to `candidates` (e.g. installed + valid mods). */
  public function enabledIn(candidates:Array<String>):Array<String>
  {
    return [for (dir in order) if (isEnabled(dir) && candidates.contains(dir)) dir];
  }
}
