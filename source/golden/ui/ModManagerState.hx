package golden.ui;

import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.modding.PolymodHandler;
import funkin.ui.MusicBeatState;
import funkin.ui.mainmenu.MainMenuState;
import funkin.util.FileUtil;
import golden.audio.UISound;
import golden.modding.GoldenMods;
import golden.modding.ModOps;
import golden.modding.ModScanner.ModInfo;
import golden.ui.GoldenDialogs;
import golden.ui.GoldenUI.GoldenButton;
import openfl.display.BitmapData;

/**
 * Golden Engine Mod Manager.
 *
 * Lists every folder in `mods/`, with icon, title, version, authors, description and validation
 * results (errors stop a mod from loading; warnings do not). Enabled state is written to
 * `golden-mods.json` immediately; the game reloads mod content (PolymodHandler.forceReloadAssets)
 * when you leave the manager or press Reload, so disabled mods never register content.
 *
 * Keyboard / controller: Up/Down select · Accept/Space toggle · A enable all · D disable all ·
 * N new · I import · E export · C duplicate · Delete delete · O open folder · R reload · S script editor · Esc/Back leave.
 * Mouse: click a row to select, click its checkbox to toggle, wheel to scroll, buttons for actions.
 */
class ModManagerState extends MusicBeatState
{
  static inline var ROW_H:Int = 64;
  static inline var LIST_X:Int = 32;
  static inline var LIST_Y:Int = 96;
  static inline var LIST_W:Int = 560;
  static inline var VISIBLE_ROWS:Int = 8;

  var mods:Array<ModInfo> = [];
  var conflicts:Map<String, Array<String>> = [];
  var selected:Int = 0;
  var scroll:Int = 0;
  var dirty:Bool = false;

  var rows:FlxTypedGroup<ModRow>;
  var detailIcon:FlxSprite;
  var detailTitle:FlxText;
  var detailMeta:FlxText;
  var detailDesc:FlxText;
  var detailIssues:FlxText;
  var statusText:FlxText;
  var emptyText:FlxText;
  var iconCache:Map<String, FlxGraphic> = [];
  var buttons:Array<GoldenButton> = [];

  /** Folder to select after the next refresh (e.g. a mod that was just created). */
  var pendingSelect:Null<String> = null;

  override function create():Void
  {
    super.create();
    FlxG.mouse.visible = true;

    var bg = new FlxSprite(Paths.image('menuDesat'));
    bg.setGraphicSize(Std.int(FlxG.width * 1.05));
    bg.updateHitbox();
    bg.screenCenter();
    bg.color = 0xFF3A2C14;
    bg.scrollFactor.set();
    add(bg);

    add(GoldenUI.text(LIST_X, 24, 600, 'MOD MANAGER', 36, GoldenUI.GOLD));
    add(GoldenUI.text(LIST_X + 330, 38, 600, 'mods folder: ${GoldenMods.modRoot()}', 14, GoldenUI.MUTED));

    add(GoldenUI.panel(LIST_X - 8, LIST_Y - 8, LIST_W + 16, ROW_H * VISIBLE_ROWS + 16));
    rows = new FlxTypedGroup<ModRow>();
    add(rows);
    for (i in 0...VISIBLE_ROWS)
      rows.add(new ModRow(LIST_X, LIST_Y + i * ROW_H, LIST_W, ROW_H - 6));

    emptyText = GoldenUI.text(LIST_X + 16, LIST_Y + 24, LIST_W - 32, 'No mods installed.\n\nPress N to create one, I to import a .zip,\nor O to open the mods folder.', 18, GoldenUI.MUTED);
    add(emptyText);

    var dx = LIST_X + LIST_W + 32;
    var dw = FlxG.width - dx - 32;
    add(GoldenUI.panel(dx - 8, LIST_Y - 8, dw + 16, ROW_H * VISIBLE_ROWS + 16));
    detailIcon = new FlxSprite(dx, LIST_Y);
    detailIcon.scrollFactor.set();
    add(detailIcon);
    detailTitle = GoldenUI.text(dx + 140, LIST_Y, dw - 140, '', 24, GoldenUI.GOLD);
    add(detailTitle);
    detailMeta = GoldenUI.text(dx + 140, LIST_Y + 34, dw - 140, '', 14, GoldenUI.MUTED);
    add(detailMeta);
    detailDesc = GoldenUI.text(dx, LIST_Y + 140, dw, '', 16);
    add(detailDesc);
    detailIssues = GoldenUI.text(dx, LIST_Y + 250, dw, '', 14, GoldenUI.WARN);
    add(detailIssues);

    statusText = GoldenUI.text(LIST_X, FlxG.height - 118, FlxG.width - 64, '', 16, GoldenUI.TEXT);
    add(statusText);

    var labels:Array<{t:String, f:Void->Void}> = [
      {t: 'Toggle (Space)', f: toggleSelected},
      {t: 'Enable all (A)', f: setAll.bind(true)},
      {t: 'Disable all (D)', f: setAll.bind(false)},
      {t: 'New (N)', f: openCreate},
      {t: 'Import (I)', f: importMod},
      {t: 'Export (E)', f: exportSelected},
      {t: 'Duplicate (C)', f: duplicateSelected},
      {t: 'Delete (Del)', f: deleteSelected},
      {t: 'Open folder (O)', f: openFolder},
      {t: 'Reload (R)', f: applyAndReload},
      {t: 'Scripts (S)', f: openScripts},
      {t: 'Back (Esc)', f: leave}
    ];
    var bw = 146, bh = 36, gap = 8;
    var perRow = 6;
    for (i in 0...labels.length)
    {
      var bx = LIST_X + (i % perRow) * (bw + gap);
      var by = FlxG.height - 88 + Std.int(i / perRow) * (bh + 6);
      var b = new GoldenButton(bx, by, bw, bh, labels[i].t, labels[i].f);
      buttons.push(b);
      add(b);
    }

    rescanMods();
    trace('[GOLDEN] Mod Manager opened: ${mods.length} installed, ${GoldenMods.loadedDirs.length} loaded');
    for (e in GoldenMods.loadErrors)
      trace('[GOLDEN] (Mod Manager) load problem: $e');
    if (GoldenMods.loadErrors.length > 0) setStatus('${GoldenMods.loadErrors.length} mod problem(s) at last load — see the red/orange details.', GoldenUI.WARN);
    else
      setStatus('${mods.length} mod(s) installed, ${GoldenMods.loadedDirs.length} loaded.', GoldenUI.MUTED);
  }

  function setStatus(msg:String, color:FlxColor):Void
  {
    statusText.text = msg;
    statusText.color = color;
  }

  /** Rescan the folder and rebuild the list (keeps the selection by folder name). */
  function rescanMods():Void
  {
    var keep = pendingSelect ?? (mods.length > 0 ? mods[selected].dir : null);
    pendingSelect = null;
    mods = GoldenMods.rescan();
    GoldenMods.getList().reconcile([for (m in mods) m.dir]);
    saveList();
    conflicts = ModOps.findConflicts(GoldenMods.getList().enabledIn([for (m in mods) if (m.errors.length == 0) m.dir]));
    selected = 0;
    if (keep != null) for (i in 0...mods.length)
      if (mods[i].dir == keep) selected = i;
    clampScroll();
    redraw();
    // Report problems once per rescan (also visible in the F8 console).
    for (m in mods)
    {
      for (d in ModOps.dependencyProblems(m))
        trace('[GOLDEN] Mod Manager: ${m.dir}: DEPENDENCY: $d');
      for (c in conflicts.get(m.dir) ?? [])
        trace('[GOLDEN] Mod Manager: ${m.dir}: CONFLICT: $c');
    }
  }

  function saveList():Void
  {
    try
    {
      GoldenMods.getList().save();
    }
    catch (e:Dynamic)
    {
      setStatus('Could not save mod list: $e', GoldenUI.BAD);
      trace('[GOLDEN] Could not save mod list: $e');
    }
  }

  function clampScroll():Void
  {
    if (selected < scroll) scroll = selected;
    if (selected >= scroll + VISIBLE_ROWS) scroll = selected - VISIBLE_ROWS + 1;
    var maxScroll = Std.int(Math.max(0, mods.length - VISIBLE_ROWS));
    if (scroll > maxScroll) scroll = maxScroll;
    if (scroll < 0) scroll = 0;
  }

  function redraw():Void
  {
    emptyText.visible = mods.length == 0;
    for (i in 0...VISIBLE_ROWS)
    {
      var row = rows.members[i];
      var idx = scroll + i;
      if (idx >= mods.length)
      {
        row.visible = false;
        continue;
      }
      var m = mods[idx];
      row.visible = true;
      row.setMod(m, GoldenMods.getList().isEnabled(m.dir), idx == selected, iconFor(m), problemLevel(m));
    }
    drawDetails();
    for (b in [buttons[0], buttons[5], buttons[6], buttons[7]])
      b.enabled = mods.length > 0;
  }

  /** 0 = fine, 1 = warnings, 2 = will not load. */
  function problemLevel(m:ModInfo):Int
  {
    if (m.errors.length > 0) return 2;
    if (GoldenMods.getList().isEnabled(m.dir) && ModOps.dependencyProblems(m).length > 0) return 2;
    if (conflicts.exists(m.dir)) return 1;
    return 0;
  }

  function drawDetails():Void
  {
    if (mods.length == 0)
    {
      detailTitle.text = '';
      detailMeta.text = '';
      detailDesc.text = '';
      detailIssues.text = '';
      detailIcon.visible = false;
      return;
    }
    var m = mods[selected];
    var enabled = GoldenMods.getList().isEnabled(m.dir);
    var loaded = GoldenMods.loadedDirs.contains(m.dir);
    detailIcon.visible = true;
    var g = iconFor(m);
    if (g != null) detailIcon.loadGraphic(g);
    else
      detailIcon.makeGraphic(128, 128, 0xFF2C2436);
    detailIcon.setGraphicSize(128, 128);
    detailIcon.updateHitbox();
    detailTitle.text = m.title;
    var meta = ['Folder: ${m.dir}'];
    if (m.modVersion != '') meta.push('Version: ${m.modVersion}');
    if (m.apiVersion != '') meta.push('Game API: ${m.apiVersion}');
    if (m.authors.length > 0) meta.push('By: ${m.authors.join(', ')}');
    if (m.license != '') meta.push('License: ${m.license}');
    meta.push((enabled ? 'ENABLED' : 'DISABLED') + (enabled != loaded ? (loaded ? ' (still loaded until reload)' : ' (loads after reload)') : ''));
    detailMeta.text = meta.join('\n');
    detailDesc.text = m.description == '' ? '(no description)' : m.description;

    var lines:Array<String> = [];
    for (e in m.errors)
      lines.push('ERROR: $e');
    for (d in ModOps.dependencyProblems(m))
      lines.push('DEPENDENCY: $d');
    for (dep => rule in m.optionalDependencies)
      if (GoldenMods.find(dep) == null) lines.push('Optional: works better with "$dep" ($rule).');
    for (c in conflicts.get(m.dir) ?? [])
      lines.push('CONFLICT: $c');
    var warnCount = 0;
    for (w in m.warnings)
    {
      if (warnCount++ >= 6)
      {
        lines.push('... and ${m.warnings.length - 6} more warning(s).');
        break;
      }
      lines.push('Warning: $w');
    }
    if (lines.length == 0) lines.push('Validation passed: no problems found.');
    detailIssues.text = lines.join('\n');
    detailIssues.color = m.errors.length > 0 ? GoldenUI.BAD : (lines.length == 1 && m.warnings.length == 0 ? GoldenUI.OK : GoldenUI.WARN);
  }

  function iconFor(m:ModInfo):Null<FlxGraphic>
  {
    if (!m.hasIcon) return null;
    if (iconCache.exists(m.path)) return iconCache.get(m.path);
    var g:Null<FlxGraphic> = null;
    #if sys
    try
    {
      var bmp = BitmapData.fromFile(haxe.io.Path.join([m.path, golden.modding.ModScanner.ICON_FILE]));
      if (bmp != null)
      {
        g = FlxGraphic.fromBitmapData(bmp, false, 'golden-modicon:' + m.path, false);
        g.persist = true; // owned by this state; destroyed in destroy()
      }
    }
    catch (e:Dynamic)
    {
      trace('[GOLDEN] Could not load icon for ${m.dir}: $e');
    }
    #end
    iconCache.set(m.path, g);
    return g;
  }

  function select(i:Int, sound:Bool = true):Void
  {
    if (mods.length == 0) return;
    var n = (i + mods.length) % mods.length;
    if (n == selected) return;
    selected = n;
    clampScroll();
    redraw();
    if (sound) UISound.play(Scroll);
  }

  function toggleSelected():Void
  {
    if (mods.length == 0) { UISound.play(Error); return; }
    var m = mods[selected];
    var list = GoldenMods.getList();
    var now = !list.isEnabled(m.dir);
    list.setEnabled(m.dir, now);
    saveList();
    dirty = true;
    UISound.play(Toggle);
    conflicts = ModOps.findConflicts(list.enabledIn([for (x in mods) if (x.errors.length == 0) x.dir]));
    trace('[GOLDEN] Mod Manager: ${now ? 'enabled' : 'disabled'} "${m.dir}"');
    if (now && m.errors.length > 0) setStatus('"${m.title}" is enabled but will NOT load until its errors are fixed.', GoldenUI.BAD);
    else
      setStatus('"${m.title}" ${now ? 'enabled' : 'disabled'}. Changes apply when you leave or press Reload.', GoldenUI.TEXT);
    redraw();
  }

  function setAll(v:Bool):Void
  {
    if (mods.length == 0) { UISound.play(Error); return; }
    for (m in mods)
      GoldenMods.getList().setEnabled(m.dir, v);
    saveList();
    dirty = true;
    UISound.play(Toggle);
    conflicts = ModOps.findConflicts(GoldenMods.getList().enabledIn([for (x in mods) if (x.errors.length == 0) x.dir]));
    trace('[GOLDEN] Mod Manager: ${v ? 'enabled' : 'disabled'} all ${mods.length} mods');
    setStatus((v ? 'All mods enabled.' : 'All mods disabled.') + ' Changes apply when you leave or press Reload.', GoldenUI.TEXT);
    redraw();
  }

  function openCreate():Void
  {
    UISound.play(Open);
    openSubState(new GoldenCreateModSubState(function(dir:String)
    {
      pendingSelect = dir;
      dirty = true;
      rescanMods();
      setStatus('Created mod "$dir" from the starter template. It is enabled and loads after Reload.', GoldenUI.OK);
    }));
  }

  function duplicateSelected():Void
  {
    if (mods.length == 0) { UISound.play(Error); return; }
    var r = ModOps.duplicateMod(mods[selected].dir);
    if (r.error != null) { showError('Duplicate failed', r.error); return; }
    pendingSelect = r.newDir;
    dirty = true;
    rescanMods();
    UISound.play(Select);
    trace('[GOLDEN] Mod Manager: duplicated to "${r.newDir}"');
    setStatus('Duplicated to "${r.newDir}".', GoldenUI.OK);
  }

  function deleteSelected():Void
  {
    if (mods.length == 0) { UISound.play(Error); return; }
    var m = mods[selected];
    openSubState(new GoldenConfirmSubState('Delete "${m.title}" (${m.dir})?\n\nThe folder is moved to mods/${ModOps.TRASH_DIR}/ so it can still be recovered by hand.', function()
    {
      var err = ModOps.deleteMod(m.dir);
      if (err != null) { showError('Delete failed', err); return; }
      dirty = true;
      if (selected >= mods.length - 1) selected = Std.int(Math.max(0, mods.length - 2));
      pendingSelect = null;
      rescanMods();
      trace('[GOLDEN] Mod Manager: deleted "${m.dir}" (moved to trash)');
      setStatus('Deleted "${m.title}".', GoldenUI.TEXT);
    }));
  }

  function exportSelected():Void
  {
    if (mods.length == 0) { UISound.play(Error); return; }
    #if sys
    var m = mods[selected];
    var bytes;
    try
    {
      bytes = ModOps.exportModBytes(m.dir);
    }
    catch (e:Dynamic)
    {
      { showError('Export failed', Std.string(e)); return; }
    }
    UISound.play(Open);
    FileUtil.saveFile('Export mod as .zip', bytes, [FileUtil.FILE_FILTER_ZIP], function(path:String)
    {
      trace('[GOLDEN] Mod Manager: exported "${m.dir}" to $path');
      setStatus('Exported "${m.title}" to $path', GoldenUI.OK);
      UISound.play(Select);
    }, function() setStatus('Export cancelled.', GoldenUI.MUTED), '${m.dir}-${m.modVersion == '' ? '1.0.0' : m.modVersion}.zip');
    #end
  }

  function importMod():Void
  {
    #if sys
    UISound.play(Open);
    FileUtil.browseForFile('Import mod (.zip)', [FileUtil.FILE_FILTER_ZIP], function(file)
    {
      var r = ModOps.importModZip(file.fullPath);
      if (r.error != null) { showError('Import failed', r.error); return; }
      pendingSelect = r.newDir;
      dirty = true;
      rescanMods();
      var m = GoldenMods.find(r.newDir);
      trace('[GOLDEN] Mod Manager: imported "${r.newDir}" from ${file.fullPath}');
      if (m != null && m.errors.length > 0) setStatus('Imported "${r.newDir}", but it has errors and will not load (see details).', GoldenUI.BAD);
      else
        setStatus('Imported "${r.newDir}". It is enabled and loads after Reload.', GoldenUI.OK);
    }, function() setStatus('Import cancelled.', GoldenUI.MUTED));
    #end
  }

  function openFolder():Void
  {
    try
    {
      var path = mods.length > 0 ? mods[selected].path : GoldenMods.modRoot();
      #if sys path = sys.FileSystem.fullPath(path); #end
      FileUtil.openFolder(path);
      UISound.play(Open);
    }
    catch (e:Dynamic)
    {
      showError('Could not open folder', Std.string(e));
    }
  }

  /** Open the Golden Studio script editor on the selected mod. */
  function openScripts():Void
  {
    if (mods.length == 0) { UISound.play(Error); return; }
    UISound.play(Select);
    FlxG.switchState(() -> new golden.studio.ScriptEditorState(mods[selected].dir));
  }

  function showError(title:String, msg:String):Void
  {
    trace('[GOLDEN] $title: $msg');
    setStatus('$title: $msg', GoldenUI.BAD);
    openSubState(new GoldenMessageSubState(title, msg, true));
  }

  /** Apply the enabled list: reload Polymod with only enabled mods, then rebuild this screen. */
  function applyAndReload():Void
  {
    UISound.play(Select);
    trace('[GOLDEN] Mod Manager: applying mod changes (reload)');
    PolymodHandler.forceReloadAssets();
    dirty = false;
    rescanMods();
    var errs = GoldenMods.loadErrors.length;
    setStatus('Reloaded. ${GoldenMods.loadedDirs.length} mod(s) loaded' + (errs > 0 ? ', $errs problem(s).' : '.'), errs > 0 ? GoldenUI.WARN : GoldenUI.OK);
  }

  function leave():Void
  {
    UISound.play(Back);
    if (dirty)
    {
      trace('[GOLDEN] Mod Manager: applying mod changes before leaving');
      PolymodHandler.forceReloadAssets();
      dirty = false;
    }
    FlxG.switchState(() -> new MainMenuState());
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (subState != null) return;

    if (controls.UI_UP_P) select(selected - 1);
    if (controls.UI_DOWN_P) select(selected + 1);
    if (FlxG.mouse.wheel != 0 && mods.length > 0) select(selected - FlxG.mouse.wheel);

    // Mouse: click a row to select; click its checkbox (or double use) to toggle.
    if (FlxG.mouse.justReleased) for (i in 0...VISIBLE_ROWS)
    {
      var row = rows.members[i];
      if (!row.visible || !FlxG.mouse.overlaps(row.bg)) continue;
      var idx = scroll + i;
      if (FlxG.mouse.overlaps(row.check) || idx == selected) toggleSelected();
      else
        select(idx);
      break;
    }

    if (controls.ACCEPT_P || FlxG.keys.justPressed.SPACE) toggleSelected();
    else if (FlxG.keys.justPressed.A) setAll(true);
    else if (FlxG.keys.justPressed.D) setAll(false);
    else if (FlxG.keys.justPressed.N) openCreate();
    else if (FlxG.keys.justPressed.I) importMod();
    else if (FlxG.keys.justPressed.E) exportSelected();
    else if (FlxG.keys.justPressed.C) duplicateSelected();
    else if (FlxG.keys.justPressed.DELETE) deleteSelected();
    else if (FlxG.keys.justPressed.O) openFolder();
    else if (FlxG.keys.justPressed.R) applyAndReload();
    else if (FlxG.keys.justPressed.S) openScripts();
    else if (controls.BACK_P) leave();
  }

  override function destroy():Void
  {
    for (g in iconCache)
      if (g != null)
      {
        g.persist = false;
        FlxG.bitmap.remove(g);
      }
    iconCache.clear();
    super.destroy();
  }
}

/** One row of the mod list: background, enabled checkbox, icon, title and status. */
class ModRow extends flixel.group.FlxSpriteGroup
{
  public var bg:FlxSprite;
  public var check:FlxSprite;

  var checkMark:FlxText;
  var icon:FlxSprite;
  var title:FlxText;
  var sub:FlxText;

  public function new(x:Float, y:Float, w:Int, h:Int)
  {
    super(x, y);
    bg = new FlxSprite().makeGraphic(w, h, FlxColor.WHITE);
    add(bg);
    check = new FlxSprite(12, Std.int((h - 28) / 2)).makeGraphic(28, 28, FlxColor.WHITE);
    add(check);
    checkMark = new FlxText(12, Std.int((h - 28) / 2) + 2, 28, '', 20);
    checkMark.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.BLACK, CENTER);
    add(checkMark);
    icon = new FlxSprite(52, 3);
    add(icon);
    title = new FlxText(52 + h + 6, 6, w - h - 70, '', 20);
    title.setFormat(Paths.font('vcr.ttf'), 20, GoldenUI.TEXT, LEFT);
    add(title);
    sub = new FlxText(52 + h + 6, 32, w - h - 70, '', 14);
    sub.setFormat(Paths.font('vcr.ttf'), 14, GoldenUI.MUTED, LEFT);
    add(sub);
    scrollFactor.set();
  }

  public function setMod(m:ModInfo, enabled:Bool, isSelected:Bool, iconGraphic:Null<FlxGraphic>, problem:Int):Void
  {
    bg.color = isSelected ? GoldenUI.GOLD_DARK : 0xFF201A28;
    check.color = enabled ? GoldenUI.GOLD : 0xFF4A4458;
    checkMark.text = enabled ? 'X' : '';
    if (iconGraphic != null) icon.loadGraphic(iconGraphic);
    else
      icon.makeGraphic(52, 52, 0xFF2C2436);
    icon.setGraphicSize(52, 52);
    icon.updateHitbox();
    title.text = m.title;
    title.alpha = enabled ? 1 : 0.6;
    var s = m.dir + (m.modVersion != '' ? '  v${m.modVersion}' : '');
    switch (problem)
    {
      case 2:
        sub.text = s + '  -  WILL NOT LOAD';
        sub.color = GoldenUI.BAD;
      case 1:
        sub.text = s + '  -  conflicts';
        sub.color = GoldenUI.WARN;
      default:
        sub.text = s;
        sub.color = GoldenUI.MUTED;
    }
  }
}
