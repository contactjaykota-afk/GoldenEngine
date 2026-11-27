package golden.modding;

#if sys
import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.zip.Entry;
import sys.FileSystem;
import sys.io.File;
#end

/** Data entered in the Create Mod wizard. */
typedef NewModInfo =
{
  var title:String;
  var folder:String;
  var description:String;
  var author:String;
  var modVersion:String;
}

/**
 * Golden Engine — file operations behind the Mod Manager. Every function returns `null` on success
 * or a readable error message; nothing is swallowed. Destructive operations never touch anything
 * outside the mods folder.
 */
class ModOps
{
  /** Text files in the template where placeholders are substituted. */
  static final TEXT_EXT:Array<String> = ['json', 'xml', 'hxc', 'hx', 'md', 'txt', 'lua', 'frag', 'vert'];

  /** Folder deleted mods are moved to (inside the mods folder; ignored by the scanner). */
  public static inline var TRASH_DIR:String = '.trash';

  /** Where the packaged starter template lives in a built game. */
  public static function templateDir():String
  {
    var candidates = [
      'assets/golden/mod-template/starter', // packaged build (see project.hxp)
      '../../../../golden/mod-template/starter', // REDIRECT_ASSETS_FOLDER dev builds
      'golden/mod-template/starter'
    ];
    #if sys
    for (c in candidates)
      if (FileSystem.exists(c) && FileSystem.isDirectory(c)) return c;
    #end
    return candidates[0];
  }

  /** Mod API version written into new manifests: the running game version, which satisfies API_VERSION_RULE. */
  public static function currentApiVersion():String
  {
    var v:String = lime.app.Application.current?.meta?.get('version') ?? '0.8.0';
    // Strip anything that is not plain semver (e.g. build suffixes).
    var r = ~/^(\d+\.\d+\.\d+)/;
    return r.match(v) ? r.matched(1) : '0.8.0';
  }

  /** Turn a title into a safe folder name: lowercase, a-z0-9 and dashes. */
  public static function slugify(title:String):String
  {
    var s = title.toLowerCase();
    s = ~/[^a-z0-9]+/g.replace(s, '-');
    s = ~/^-+|-+$/g.replace(s, '');
    return s.length > 48 ? s.substr(0, 48) : s;
  }

  /** Class-name form of a folder id for script templates (e.g. "my-mod" -> "MyMod"). */
  public static function modClass(folder:String):String
  {
    var parts = ~/[^A-Za-z0-9]+/g.split(folder);
    var s = '';
    for (p in parts)
      if (p.length > 0) s += p.charAt(0).toUpperCase() + p.substr(1);
    return (s.length > 0 && ~/^[A-Za-z]/.match(s)) ? s : 'Mod' + s;
  }

  public static function validateNewMod(info:NewModInfo):Null<String>
  {
    if (info.title == null || StringTools.trim(info.title) == '') return 'Please enter a mod title.';
    if (info.folder == null || !~/^[a-z0-9][a-z0-9_-]*$/.match(info.folder)) return 'Folder name may only use a-z, 0-9, - and _ and must not be empty.';
    if (info.modVersion != null && info.modVersion != '' && !ModScanner.isSemver(info.modVersion)) return 'Version must look like 1.0.0.';
    #if sys
    if (FileSystem.exists(Path.join([GoldenMods.modRoot(), info.folder]))) return 'A mod folder named "${info.folder}" already exists.';
    #end
    return null;
  }

  /** Build the manifest object for a new mod. */
  public static function makeManifest(info:NewModInfo):Dynamic
  {
    return {
      title: StringTools.trim(info.title),
      description: info.description ?? '',
      contributors: (info.author != null && StringTools.trim(info.author) != '') ? [{name: StringTools.trim(info.author)}] : [],
      api_version: currentApiVersion(),
      mod_version: (info.modVersion == null || info.modVersion == '') ? '1.0.0' : info.modVersion,
      license: 'All rights reserved',
      dependencies: {},
      optionalDependencies: {}
    };
  }

  /** Create a new mod from the packaged starter template. */
  public static function createMod(info:NewModInfo):Null<String>
  {
    var err = validateNewMod(info);
    if (err != null) return err;
    #if sys
    var template = templateDir();
    if (!FileSystem.exists(template)) return 'The starter template is missing from this installation ($template).';
    var dest = Path.join([GoldenMods.modRoot(), info.folder]);
    var rep:Map<String, String> = ['__MODID__' => info.folder, '__MODCLASS__' => modClass(info.folder), '__MODNAME__' => StringTools.trim(info.title)];
    try
    {
      ensureDir(GoldenMods.modRoot());
      copyTree(template, dest, rep);
      File.saveContent(Path.join([dest, ModScanner.META_FILE]), Json.stringify(makeManifest(info), null, '  '));
    }
    catch (e:Dynamic)
    {
      return 'Could not create the mod: $e';
    }
    // Validate what we produced, so a broken template is reported instead of shipped.
    var check = ModScanner.inspect(info.folder, dest, GoldenMods.checkApiVersion);
    if (check.errors.length > 0) return 'Mod created, but it does not validate: ' + check.errors.join(' ');
    return null;
    #else
    return 'Creating mods is only supported on desktop.';
    #end
  }

  /** Copy a mod to a new folder (with " (Copy)" appended to its title). */
  public static function duplicateMod(dir:String):{error:Null<String>, newDir:Null<String>}
  {
    #if sys
    var root = GoldenMods.modRoot();
    var src = Path.join([root, dir]);
    if (!FileSystem.exists(src)) return {error: 'Mod folder "$dir" does not exist.', newDir: null};
    var n = 2;
    var target = '$dir-copy';
    while (FileSystem.exists(Path.join([root, target])))
      target = '$dir-copy${n++}';
    try
    {
      copyTree(src, Path.join([root, target]), null);
      var metaPath = Path.join([root, target, ModScanner.META_FILE]);
      if (FileSystem.exists(metaPath))
      {
        var meta:Dynamic = Json.parse(File.getContent(metaPath));
        var title:Dynamic = Reflect.field(meta, 'title');
        Reflect.setField(meta, 'title', (title == null ? dir : Std.string(title)) + ' (Copy)');
        File.saveContent(metaPath, Json.stringify(meta, null, '  '));
      }
    }
    catch (e:Dynamic)
    {
      return {error: 'Could not duplicate "$dir": $e', newDir: null};
    }
    return {error: null, newDir: target};
    #else
    return {error: 'Not supported on this platform.', newDir: null};
    #end
  }

  /**
   * "Delete" a mod: moved to mods/.trash/<dir>-<timestamp> so an accidental delete can be recovered
   * by hand. The scanner ignores the trash folder.
   */
  public static function deleteMod(dir:String):Null<String>
  {
    #if sys
    if (dir == null || dir == '' || dir.indexOf('/') >= 0 || dir.indexOf('\\') >= 0 || dir.startsWith('.')) return 'Invalid mod folder "$dir".';
    var root = GoldenMods.modRoot();
    var src = Path.join([root, dir]);
    if (!FileSystem.exists(src)) return 'Mod folder "$dir" does not exist.';
    try
    {
      ensureDir(Path.join([root, TRASH_DIR]));
      var dest = Path.join([root, TRASH_DIR, dir + '-' + DateTools.format(Date.now(), '%Y%m%d-%H%M%S')]);
      FileSystem.rename(src, dest);
      GoldenMods.getList().remove(dir);
      GoldenMods.getList().save();
    }
    catch (e:Dynamic)
    {
      return 'Could not delete "$dir": $e';
    }
    return null;
    #else
    return 'Not supported on this platform.';
    #end
  }

  #if sys
  /** Zip a mod folder (paths inside the zip are relative to the mod folder). */
  public static function exportModBytes(dir:String):Bytes
  {
    var src = Path.join([GoldenMods.modRoot(), dir]);
    var entries:Array<Entry> = [];
    collectEntries(src, '', entries);
    return funkin.util.FileUtil.createZIPFromEntries(entries);
  }

  static function collectEntries(base:String, rel:String, out:Array<Entry>):Void
  {
    var full = rel == '' ? base : Path.join([base, rel]);
    for (name in FileSystem.readDirectory(full))
    {
      var r = rel == '' ? name : '$rel/$name';
      var p = Path.join([base, r]);
      if (FileSystem.isDirectory(p)) collectEntries(base, r, out);
      else
        out.push(funkin.util.FileUtil.makeZIPEntryFromBytes(r, File.getBytes(p)));
    }
  }

  /**
   * Install a mod from a .zip. The manifest may be at the zip root or inside a single top-level folder.
   * The zip is validated first; nothing is written if the manifest is missing or the target exists.
   */
  public static function importModZip(zipPath:String):{error:Null<String>, newDir:Null<String>}
  {
    var entries:Array<Entry>;
    try
    {
      entries = funkin.util.FileUtil.readZIPFromBytes(File.getBytes(zipPath));
    }
    catch (e:Dynamic)
    {
      return {error: 'Could not read "$zipPath" as a zip file: $e', newDir: null};
    }
    var prefix:Null<String> = null;
    for (e in entries)
    {
      var name = e.fileName.replace('\\', '/');
      if (name == ModScanner.META_FILE) { prefix = ''; break; }
      var parts = name.split('/');
      if (parts.length == 2 && parts[1] == ModScanner.META_FILE && prefix == null) prefix = parts[0] + '/';
    }
    if (prefix == null) return {error: 'This zip does not contain a ${ModScanner.META_FILE} (at its root or in one top-level folder), so it is not a mod.', newDir: null};
    var base = prefix == '' ? Path.withoutExtension(Path.withoutDirectory(zipPath)) : prefix.substr(0, prefix.length - 1);
    var dir = slugify(base);
    if (dir == '') dir = 'imported-mod';
    var root = GoldenMods.modRoot();
    if (FileSystem.exists(Path.join([root, dir]))) return {error: 'A mod folder named "$dir" already exists. Delete or rename it first.', newDir: null};
    try
    {
      for (e in entries)
      {
        var name = e.fileName.replace('\\', '/');
        if (!name.startsWith(prefix) || name.endsWith('/')) continue;
        var rel = name.substr(prefix.length);
        if (rel == '' || rel.indexOf('..') >= 0 || rel.startsWith('/')) continue; // refuse path traversal
        var out = Path.join([root, dir, rel]);
        ensureDir(Path.directory(out));
        var data = e.data;
        if (e.compressed) haxe.zip.Tools.uncompress(e);
        File.saveBytes(out, e.data);
      }
    }
    catch (e:Dynamic)
    {
      return {error: 'Import failed while extracting: $e', newDir: null};
    }
    return {error: null, newDir: dir};
  }

  static function ensureDir(p:String):Void
  {
    if (!FileSystem.exists(p)) FileSystem.createDirectory(p);
  }

  /** Recursive copy; when `rep` is given, placeholders are replaced in file names and text files. */
  static function copyTree(src:String, dest:String, rep:Null<Map<String, String>>):Void
  {
    ensureDir(dest);
    for (name in FileSystem.readDirectory(src))
    {
      var s = Path.join([src, name]);
      var outName = name;
      if (rep != null) for (k => v in rep)
        outName = outName.replace(k, v);
      // Packaged template scripts are stored as *.hxc.tmpl so Polymod does not run them (see project.hxp).
      if (rep != null && outName.endsWith('.tmpl')) outName = outName.substr(0, outName.length - 5);
      var d = Path.join([dest, outName]);
      if (FileSystem.isDirectory(s)) copyTree(s, d, rep);
      else if (rep != null && TEXT_EXT.contains(Path.extension(outName).toLowerCase()))
      {
        var t = File.getContent(s);
        for (k => v in rep)
          t = t.replace(k, v);
        File.saveContent(d, t);
      }
      else
        File.copy(s, d);
    }
  }
  #end

  /**
   * Dependency check for the Mod Manager: for each mod, which required dependencies are not installed,
   * or installed but disabled.
   */
  public static function dependencyProblems(mod:ModScanner.ModInfo):Array<String>
  {
    var out:Array<String> = [];
    for (dep => rule in mod.dependencies)
    {
      var other = GoldenMods.find(dep);
      if (other == null) out.push('Requires mod "$dep" ($rule), which is not installed.');
      else if (!GoldenMods.getList().isEnabled(dep)) out.push('Requires mod "$dep", which is disabled.');
      else if (other.modVersion != '' && rule != '' && rule != '*')
      {
        try
        {
          var v:thx.semver.Version = other.modVersion;
          var r:thx.semver.VersionRule = rule;
          if (!r.isSatisfiedBy(v)) out.push('Requires "$dep" $rule, but ${other.modVersion} is installed.');
        }
        catch (e:Dynamic)
        {
          out.push('Dependency rule "$rule" for "$dep" is not valid.');
        }
      }
    }
    return out;
  }

  /**
   * Conflict check: data files that two or more enabled mods both replace (not via _append/_merge).
   * Polymod lets the later mod win; the Mod Manager reports it so the user can reorder or disable.
   * @return map of mod dir -> messages
   */
  public static function findConflicts(enabledDirs:Array<String>):Map<String, Array<String>>
  {
    var result:Map<String, Array<String>> = [];
    #if sys
    var owner:Map<String, String> = [];
    for (dir in enabledDirs)
    {
      var files:Array<String> = [];
      listFiles(Path.join([GoldenMods.modRoot(), dir]), '', files);
      for (f in files)
      {
        if (!f.startsWith('data/') || f.startsWith('_append') || f.startsWith('_merge')) continue;
        var prev = owner.get(f);
        if (prev != null && prev != dir)
        {
          if (!result.exists(dir)) result.set(dir, []);
          result.get(dir).push('Replaces $f, which "$prev" also replaces ("$dir" wins: it loads later).');
          if (!result.exists(prev)) result.set(prev, []);
          result.get(prev).push('$f is overridden by "$dir".');
        }
        owner.set(f, dir);
      }
    }
    #end
    return result;
  }

  #if sys
  static function listFiles(base:String, rel:String, out:Array<String>):Void
  {
    var full = rel == '' ? base : Path.join([base, rel]);
    if (!FileSystem.exists(full)) return;
    for (name in FileSystem.readDirectory(full))
    {
      var r = rel == '' ? name : '$rel/$name';
      if (FileSystem.isDirectory(Path.join([base, r]))) listFiles(base, r, out);
      else
        out.push(r);
    }
  }
  #end
}
