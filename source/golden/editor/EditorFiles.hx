package golden.editor;

#if sys
import sys.FileSystem;
import sys.io.File;
#end
import haxe.io.Path;
import golden.modding.GoldenMods;
import golden.modding.ModScanner;

/**
 * Golden Engine editor kit — where editors save, and safe file operations.
 *
 * Editors always write into ONE target mod folder (`mods/<target>/...`), never into the base game's
 * assets. The target is chosen in each editor's toolbar and remembered in golden-settings.json.
 * Saving writes a temp file and renames it; the previous version is kept as `<file>.bak`.
 * Nothing is written while previewing: editors keep their data in memory until Save.
 */
class EditorFiles
{
  /** Folders in mods/ a user can save into (valid mods, not the template/trash). */
  public static function modChoices():Array<String>
  {
    #if sys
    var root = GoldenMods.modRoot();
    if (!FileSystem.exists(root)) return [];
    return [
      for (i in ModScanner.scan(root, GoldenMods.checkApiVersion))
        if (i.errors.length == 0) i.dir
    ];
    #else
    return [];
    #end
  }

  /** Current target mod (validated; null when there is no mod at all). */
  public static function target():Null<String>
  {
    var choices = modChoices();
    var t = GoldenSettings.editorTarget;
    if (t != null && choices.contains(t)) return t;
    return choices.length > 0 ? choices[0] : null;
  }

  /** Whether the target mod is enabled (content of disabled mods is not loaded by the game). */
  public static function targetEnabled():Bool
  {
    var t = target();
    return t != null && GoldenMods.resolveEnabledDirs().contains(t);
  }

  public static function setTarget(dir:String):Void
    GoldenSettings.editorTarget = dir;

  /** Absolute-ish path of a file inside the target mod. */
  public static function modPath(rel:String, ?mod:String):Null<String>
  {
    var m = mod ?? target();
    if (m == null) return null;
    return Path.join([GoldenMods.modRoot(), m, rel]);
  }

  public static function exists(path:String):Bool
  {
    #if sys
    return FileSystem.exists(path);
    #else
    return false;
    #end
  }

  public static function ensureDir(dir:String):Void
  {
    #if sys
    if (dir == '' || FileSystem.exists(dir)) return;
    ensureDir(Path.directory(dir));
    FileSystem.createDirectory(dir);
    #end
  }

  /** Write text atomically, keeping the previous version as .bak. Returns an error message or null. */
  public static function saveText(path:String, text:String):Null<String>
  {
    #if sys
    try
    {
      ensureDir(Path.directory(path));
      File.saveContent(path + '.tmp', text);
      if (FileSystem.exists(path))
      {
        if (FileSystem.exists(path + '.bak')) FileSystem.deleteFile(path + '.bak');
        FileSystem.rename(path, path + '.bak');
      }
      FileSystem.rename(path + '.tmp', path);
      trace('[GOLDEN EDITOR] Saved $path (${text.length} bytes)');
      return null;
    }
    catch (e:Dynamic)
    {
      trace('[GOLDEN EDITOR] Could not save $path: $e');
      return 'Could not save $path: $e';
    }
    #else
    return 'Saving is only supported on desktop.';
    #end
  }

  public static function saveBytes(path:String, bytes:haxe.io.Bytes):Null<String>
  {
    #if sys
    try
    {
      ensureDir(Path.directory(path));
      File.saveBytes(path, bytes);
      trace('[GOLDEN EDITOR] Saved $path (${bytes.length} bytes)');
      return null;
    }
    catch (e:Dynamic)
    {
      return 'Could not save $path: $e';
    }
    #else
    return 'Saving is only supported on desktop.';
    #end
  }

  public static function saveJson(path:String, data:Dynamic):Null<String>
    return saveText(path, haxe.Json.stringify(data, null, '  '));

  public static function loadText(path:String):Null<String>
  {
    #if sys
    try
    {
      return FileSystem.exists(path) ? File.getContent(path) : null;
    }
    catch (e:Dynamic)
    {
      trace('[GOLDEN EDITOR] Could not read $path: $e');
      return null;
    }
    #else
    return null;
    #end
  }

  /** Parse JSON; on failure returns null and puts the reason in `lastError`. */
  public static var lastError:Null<String> = null;

  public static function loadJson(path:String):Dynamic
  {
    lastError = null;
    var t = loadText(path);
    if (t == null)
    {
      lastError = 'File not found: $path';
      return null;
    }
    try
    {
      return haxe.Json.parse(t);
    }
    catch (e:Dynamic)
    {
      lastError = 'Invalid JSON in $path: $e';
      trace('[GOLDEN EDITOR] $lastError');
      return null;
    }
  }

  /** Files (relative paths) under a folder of the target mod with one of the extensions. */
  public static function listFiles(dir:String, exts:Array<String>):Array<String>
  {
    var out = [];
    #if sys
    function walk(abs:String, rel:String)
    {
      if (!FileSystem.exists(abs) || !FileSystem.isDirectory(abs)) return;
      for (n in FileSystem.readDirectory(abs))
      {
        if (n.startsWith('.')) continue;
        var a = Path.join([abs, n]);
        var r = rel == '' ? n : '$rel/$n';
        if (FileSystem.isDirectory(a)) walk(a, r);
        else if (exts.length == 0 || exts.contains(Path.extension(n).toLowerCase())) out.push(r);
      }
    }
    walk(dir, '');
    #end
    out.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
    return out;
  }

  /** Lower-case id safe for file names. */
  public static function safeId(s:String):String
  {
    var r = ~/[^a-z0-9_-]+/g.replace(s.toLowerCase().trim(), '-');
    r = ~/^-+|-+$/g.replace(r, '');
    return r == '' ? 'untitled' : r;
  }

  /** Reload mods and every registry so saved content is used immediately (no restart). */
  public static function reloadGameContent():Void
  {
    trace('[GOLDEN EDITOR] Reloading game content');
    funkin.modding.PolymodHandler.forceReloadAssets();
  }
}
