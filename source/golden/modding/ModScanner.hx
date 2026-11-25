package golden.modding;

#if sys
import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#end

/** Everything the Mod Manager needs to know about one installed mod folder. */
typedef ModInfo =
{
  var dir:String;
  var path:String;
  var title:String;
  var description:String;
  var modVersion:String;
  var apiVersion:String;
  var authors:Array<String>;
  var license:String;
  var hasIcon:Bool;

  /** Problems that stop the mod from loading (it is skipped, never half-loaded). */
  var errors:Array<String>;

  /** Problems that do not stop loading but will break some content (missing files, bad JSON...). */
  var warnings:Array<String>;
}

/**
 * Golden Engine — scans the mods folder and validates each mod without going through Polymod,
 * so a broken mod is reported in the Mod Manager instead of producing blocking popups or partial loads.
 */
class ModScanner
{
  public static inline var META_FILE:String = '_polymod_meta.json';
  public static inline var ICON_FILE:String = '_polymod_icon.png';

  /** Folders inside the mods root that are never treated as mods. */
  static final IGNORED_DIRS:Array<String> = ['.git', '.trash', '__MACOSX'];

  /**
   * @param modRoot the mods folder
   * @param apiCheck returns null if an api_version string is acceptable, else an error message
   */
  public static function scan(modRoot:String, apiCheck:String->Null<String>):Array<ModInfo>
  {
    var result:Array<ModInfo> = [];
    #if sys
    if (!FileSystem.exists(modRoot) || !FileSystem.isDirectory(modRoot)) return result;
    var dirs = FileSystem.readDirectory(modRoot);
    dirs.sort((a, b) -> Reflect.compare(a.toLowerCase(), b.toLowerCase()));
    for (dir in dirs)
    {
      if (IGNORED_DIRS.contains(dir) || StringTools.startsWith(dir, '.')) continue;
      var path = Path.join([modRoot, dir]);
      if (!FileSystem.isDirectory(path)) continue;
      result.push(inspect(dir, path, apiCheck));
    }
    #end
    return result;
  }

  public static function inspect(dir:String, path:String, apiCheck:String->Null<String>):ModInfo
  {
    var info:ModInfo = {
      dir: dir,
      path: path,
      title: dir,
      description: '',
      modVersion: '',
      apiVersion: '',
      authors: [],
      license: '',
      hasIcon: false,
      errors: [],
      warnings: []
    };
    #if sys
    var metaPath = Path.join([path, META_FILE]);
    info.hasIcon = FileSystem.exists(Path.join([path, ICON_FILE]));
    if (!FileSystem.exists(metaPath))
    {
      info.errors.push('Missing $META_FILE (every mod needs one; use "Create New Mod" to get a valid template).');
      return info;
    }
    var meta:Dynamic = null;
    try
    {
      meta = Json.parse(File.getContent(metaPath));
    }
    catch (e:Dynamic)
    {
      info.errors.push('$META_FILE is not valid JSON: $e');
      return info;
    }
    if (meta == null || Type.typeof(meta) != TObject)
    {
      info.errors.push('$META_FILE must contain a JSON object.');
      return info;
    }
    inline function str(field:String):String
    {
      var v:Dynamic = Reflect.field(meta, field);
      return v == null ? '' : Std.string(v);
    }
    info.title = str('title') != '' ? str('title') : dir;
    info.description = str('description');
    info.modVersion = str('mod_version');
    info.apiVersion = str('api_version');
    info.license = str('license');
    var contributors:Dynamic = Reflect.field(meta, 'contributors');
    if (Std.isOfType(contributors, Array))
    {
      for (c in (contributors : Array<Dynamic>))
      {
        var name:Dynamic = c == null ? null : Reflect.field(c, 'name');
        if (name != null) info.authors.push(Std.string(name));
      }
    }
    if (str('title') == '') info.warnings.push('$META_FILE has no "title".');
    if (info.apiVersion == '') info.errors.push('$META_FILE has no "api_version".');
    else
    {
      var apiError = apiCheck(info.apiVersion);
      if (apiError != null) info.errors.push(apiError);
    }
    if (info.modVersion != '' && !isSemver(info.modVersion)) info.errors.push('"mod_version" must look like 1.0.0 (got "${info.modVersion}").');
    if (!info.hasIcon) info.warnings.push('No $ICON_FILE (optional).');

    validateContent(path, info.warnings);
    #end
    return info;
  }

  public static function isSemver(v:String):Bool
  {
    return ~/^\d+\.\d+\.\d+([-+][0-9A-Za-z.-]+)?$/.match(v);
  }

  #if sys
  /**
   * Cross-check the content the runtime will try to load: songs have charts and an instrumental,
   * characters' atlases exist, weeks reference existing songs. Reports problems as warnings.
   */
  public static function validateContent(path:String, out:Array<String>):Void
  {
    function json(rel:String):Dynamic
    {
      var p = Path.join([path, rel]);
      try
      {
        return Json.parse(File.getContent(p));
      }
      catch (e:Dynamic)
      {
        out.push('$rel: invalid JSON ($e)');
        return null;
      }
    }
    function exists(rel:String):Bool
      return FileSystem.exists(Path.join([path, rel]));
    function list(rel:String):Array<String>
    {
      var p = Path.join([path, rel]);
      return FileSystem.exists(p) && FileSystem.isDirectory(p) ? FileSystem.readDirectory(p) : [];
    }

    var modSongs:Array<String> = [];
    for (songId in list('data/songs'))
    {
      if (!FileSystem.isDirectory(Path.join([path, 'data/songs', songId]))) continue;
      modSongs.push(songId);
      var metaRel = 'data/songs/$songId/$songId-metadata.json';
      if (!exists(metaRel))
      {
        out.push('Song "$songId": missing $metaRel');
        continue;
      }
      var meta = json(metaRel);
      if (!exists('data/songs/$songId/$songId-chart.json')) out.push('Song "$songId": missing data/songs/$songId/$songId-chart.json');
      else
        json('data/songs/$songId/$songId-chart.json');
      if (!exists('songs/$songId/Inst.ogg')) out.push('Song "$songId": missing songs/$songId/Inst.ogg');
      if (meta != null)
      {
        var chars:Dynamic = Reflect.field(Reflect.field(meta, 'playData') ?? {}, 'characters');
        if (chars != null)
        {
          for (field in ['playerVocals', 'opponentVocals'])
          {
            var ids:Dynamic = Reflect.field(chars, field);
            if (Std.isOfType(ids, Array)) for (id in (ids : Array<Dynamic>))
              if (!exists('songs/$songId/Voices-$id.ogg')) out.push('Song "$songId": missing vocals songs/$songId/Voices-$id.ogg (song will play without them)');
          }
        }
      }
    }
    for (file in list('data/characters'))
    {
      if (!StringTools.endsWith(file, '.json')) continue;
      var c = json('data/characters/$file');
      if (c == null) continue;
      var asset:Dynamic = Reflect.field(c, 'assetPath');
      var render:Dynamic = Reflect.field(c, 'renderType');
      if (asset == null) out.push('Character "$file": no "assetPath"');
      else if (render == null || render == 'sparrow')
      {
        var a = Std.string(asset);
        if (a.indexOf(':') < 0 && !exists('images/$a.png')) out.push('Character "$file": missing images/$a.png');
        if (a.indexOf(':') < 0 && !exists('images/$a.xml')) out.push('Character "$file": missing images/$a.xml');
      }
    }
    for (file in list('data/levels'))
    {
      if (!StringTools.endsWith(file, '.json')) continue;
      var l = json('data/levels/$file');
      if (l == null) continue;
      var songs:Dynamic = Reflect.field(l, 'songs');
      if (Std.isOfType(songs, Array))
        for (s in (songs : Array<Dynamic>))
          if (!modSongs.contains(Std.string(s))) out.push('Week "$file" lists song "$s", which is not in this mod (fine only if another mod or the base game provides it).');
    }
    for (file in list('data/stages'))
      if (StringTools.endsWith(file, '.json')) json('data/stages/$file');
  }
  #end
}
