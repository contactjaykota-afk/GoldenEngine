package golden.modding;

import golden.modding.ModScanner.ModInfo;
import funkin.modding.PolymodHandler;

/**
 * Golden Engine — connects the mod enable/disable list and validator to upstream's PolymodHandler.
 *
 * PolymodHandler stays the only mod loader; this class only decides WHICH mod folders it is given:
 * installed + valid + enabled, in load order.
 */
class GoldenMods
{
  /** Result of the last scan (all installed mods, valid or not). */
  public static var installed(default, null):Array<ModInfo> = [];

  /** Mod folders passed to Polymod on the last load. */
  public static var loadedDirs(default, null):Array<String> = [];

  /** Messages about mods that were skipped or failed (shown in the Mod Manager). */
  public static var loadErrors(default, null):Array<String> = [];

  static var list:Null<ModList> = null;

  public static function modRoot():String
  {
    return PolymodHandler.MOD_FOLDER;
  }

  public static function getList():ModList
  {
    if (list == null) list = ModList.load(ModList.pathForModRoot(modRoot()));
    return list;
  }

  /** Returns null if the mod's api_version is supported by this build, else a readable error. */
  public static function checkApiVersion(apiVersion:String):Null<String>
  {
    try
    {
      var version:thx.semver.Version = apiVersion;
      var rule:thx.semver.VersionRule = PolymodHandler.API_VERSION_RULE;
      if (!rule.isSatisfiedBy(version)) return 'Made for game version $apiVersion; this build of Golden Engine accepts ${PolymodHandler.API_VERSION_RULE}.';
      return null;
    }
    catch (e:Dynamic)
    {
      return '"api_version" "$apiVersion" is not a valid version number.';
    }
  }

  /** Re-scan the mods folder (does not load anything). */
  public static function rescan():Array<ModInfo>
  {
    installed = ModScanner.scan(modRoot(), checkApiVersion);
    return installed;
  }

  /**
   * Work out which mods to load: scan, register new folders (enabled by default), persist the list,
   * and drop enabled mods that are invalid (reporting why).
   */
  public static function resolveEnabledDirs():Array<String>
  {
    loadErrors = [];
    list = ModList.load(ModList.pathForModRoot(modRoot()));
    if (list.loadError != null) loadErrors.push(list.loadError);
    rescan();

    var installedDirs = [for (m in installed) m.dir];
    var added = list.reconcile(installedDirs);
    for (dir in added) trace('[GOLDEN] New mod found and enabled: $dir');
    try
    {
      list.save();
    }
    catch (e:Dynamic)
    {
      loadErrors.push('Could not save ${list.path}: $e');
    }

    var valid:Array<String> = [];
    for (m in installed)
    {
      if (m.errors.length == 0) valid.push(m.dir);
      else if (list.isEnabled(m.dir)) loadErrors.push('${m.dir}: not loaded — ' + m.errors.join(' '));
    }
    var candidates = list.enabledIn(valid);
    // Drop mods whose required dependencies will not be loaded (missing, disabled, invalid, or wrong
    // version). Polymod would otherwise raise an error that upstream shows as a blocking popup.
    // Repeat until stable, since dropping one mod can break another that depends on it.
    var changed = true;
    while (changed)
    {
      changed = false;
      for (dir in candidates.copy())
      {
        var m = find(dir);
        if (m == null) continue;
        for (dep => rule in m.dependencies)
        {
          var problem:Null<String> = null;
          var other = find(dep);
          if (!candidates.contains(dep)) problem = other == null ? 'requires mod "$dep", which is not installed' : 'requires mod "$dep", which is disabled or not loadable';
          else if (other != null && other.modVersion != '' && rule != '' && rule != '*')
          {
            try
            {
              var v:thx.semver.Version = other.modVersion;
              var r:thx.semver.VersionRule = rule;
              if (!r.isSatisfiedBy(v)) problem = 'requires "$dep" $rule, but ${other.modVersion} is installed';
            }
            catch (e:Dynamic)
              problem = 'has an invalid version rule "$rule" for "$dep"';
          }
          if (problem != null)
          {
            loadErrors.push('$dir: not loaded — $problem.');
            candidates.remove(dir);
            changed = true;
            break;
          }
        }
      }
    }
    for (err in loadErrors) trace('[GOLDEN] Mod problem: $err');
    loadedDirs = candidates;
    trace('[GOLDEN] Mods enabled: ${loadedDirs.length > 0 ? loadedDirs.join(', ') : '(none)'}; disabled: '
      + [for (d in installedDirs) if (!list.isEnabled(d)) d].join(', '));
    return loadedDirs;
  }

  /** Called from PolymodErrorHandler so Polymod's own load errors reach the Mod Manager. */
  public static function recordPolymodError(code:String, message:String, severity:String):Void
  {
    if (severity == 'ERROR' || severity == 'error') loadErrors.push('Polymod: $message ($code)');
  }

  /**
   * Golden Engine replacement for upstream's blocking "Mod ... Error" popups: the problem is logged
   * and listed in the Mod Manager (which shows why a mod did not load) without stopping the game.
   */
  public static function reportModError(title:String, message:String):Void
  {
    var line = '$title: $message';
    trace('[GOLDEN] Mod problem: $line');
    if (!loadErrors.contains(line)) loadErrors.push(line);
  }

  public static function find(dir:String):Null<ModInfo>
  {
    for (m in installed)
      if (m.dir == dir) return m;
    return null;
  }
}
