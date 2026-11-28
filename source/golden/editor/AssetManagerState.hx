package golden.editor;

import flixel.FlxSprite;
import flixel.text.FlxText;
import haxe.io.Path;
import openfl.display.BitmapData;
import funkin.audio.FunkinSound;
import funkin.util.FileUtil;
import golden.editor.EditorUI;

using StringTools;

/**
 * Golden Engine — Mod Asset Manager: every file of the target mod in folders, with search, image
 * preview (size in pixels), audio preview, text preview and file info; import, export, rename, replace,
 * new folder and delete (to mods/.trash, asks first); scans for MISSING assets (referenced in the mod's
 * JSON/Lua/HScript/XML but not found in the game or the mod) and UNUSED images/sounds/music (in the
 * mod but referenced nowhere in its data).
 */
class AssetManagerState extends GoldenEditorState
{
  var browser:Browser;
  var inspector:Inspector;
  var inspectorDirty:Bool = true;
  var selected:Null<String> = null; // path relative to the mod
  var folder:String = '';
  var preview:Null<FlxSprite> = null;
  var previewText:Null<FlxText> = null;
  var sound:Null<FunkinSound> = null;
  var missing:Array<String> = [];
  var unused:Array<String> = [];
  var newName:String = '';

  public function new()
    super('Mod Asset Manager');

  override function buildEditor():Void
  {
    browser = ui(new Browser(0, GoldenEditorState.TOP, leftW + 60, FlxG.height - GoldenEditorState.TOP - GoldenEditorState.BOTTOM));
    leftW += 60;
    browser.onSelect = it -> selectFile(it.data.rel, it.data.kind);
    inspector = ui(new Inspector(FlxG.width - rightW, GoldenEditorState.TOP, rightW, FlxG.height - GoldenEditorState.TOP - GoldenEditorState.BOTTOM));
    addTool('Import...', importFiles, 'Copy files into the selected folder');
    addTool('Scan', scan, 'Find missing and unused assets');
    addTool('Refresh', () -> rebuildBrowser());
    rebuildBrowser();
  }

  function root():Null<String>
    return EditorFiles.target() == null ? null : EditorFiles.modPath('');

  override function onTargetChanged():Void
  {
    selected = null;
    rebuildBrowser();
  }

  function rebuildBrowser():Void
  {
    var r = root();
    var items:Array<BrowserItem> = [];
    if (r != null) for (f in EditorFiles.listFiles(r, []))
    {
      var dir = Path.directory(f);
      items.push({folder: dir == '' ? '(mod root)' : dir, label: Path.withoutDirectory(f), data: {rel: f, kind: 'file'}});
    }
    for (m in missing)
      items.push({folder: 'Scan: missing', label: m, data: {rel: m, kind: 'missing'}});
    for (u in unused)
      items.push({folder: 'Scan: unused', label: u, data: {rel: u, kind: 'file'}});
    browser.setItems(items);
    inspectorDirty = true;
    trace('[GOLDEN EDITOR] Asset Manager: ${items.length} entries in ${EditorFiles.target()}');
  }

  function abs(rel:String):String
    return Path.join([root(), rel]);

  function clearPreview():Void
  {
    if (preview != null)
    {
      remove(preview, true);
      preview.destroy();
      preview = null;
    }
    if (previewText != null)
    {
      remove(previewText, true);
      previewText.destroy();
      previewText = null;
    }
    sound?.stop();
  }

  function selectFile(rel:String, kind:String):Void
  {
    clearPreview();
    if (kind == 'missing')
    {
      selected = null;
      notify('Missing: $rel (referenced by the mod but not found).', 0xFFFFB347);
      return;
    }
    selected = rel;
    folder = Path.directory(rel);
    newName = Path.withoutDirectory(rel);
    var ext = Path.extension(rel).toLowerCase();
    #if sys
    if (ext == 'png' || ext == 'jpg')
    {
      var b = BitmapData.fromBytes(sys.io.File.getBytes(abs(rel)));
      if (b != null)
      {
        preview = new FlxSprite().loadGraphic(b);
        var sc = Math.min(1, Math.min(560 / b.width, 560 / b.height));
        preview.scale.set(sc, sc);
        preview.updateHitbox();
        preview.screenCenter();
        add(preview);
      }
    }
    else if (['json', 'xml', 'txt', 'lua', 'hxc', 'md', 'frag', 'vert'].contains(ext))
    {
      var t = sys.io.File.getContent(abs(rel));
      previewText = new FlxText(leftW + 16 - FlxG.width / 2, 0, FlxG.width - leftW - rightW - 32, t.substr(0, 1600), 12);
      previewText.setFormat(Paths.font('vcr.ttf'), 12, EditorUI.TEXT);
      add(previewText);
    }
    #end
    centerWorkspaceOn(FlxG.width / 2, FlxG.height / 2);
    camWorld.zoom = 1;
    inspectorDirty = true;
    trace('[GOLDEN EDITOR] Asset Manager: selected $rel');
  }

  function playSound():Void
  {
    if (selected == null) return;
    sound?.stop();
    #if sys
    var bytes = sys.io.File.getBytes(abs(selected));
    var s = openfl.media.Sound.fromAudioBuffer(lime.media.AudioBuffer.fromBytes(bytes));
    sound = FunkinSound.load(s, 1.0);
    sound?.play();
    trace('[GOLDEN EDITOR] Asset Manager: playing $selected (${Math.round((sound?.length ?? 0) / 100) / 10} s)');
    #end
  }

  function importFiles():Void
  {
    #if sys
    var dest = folder;
    FileUtil.browseForMultipleFiles('Import into ${dest == '' ? 'the mod root' : dest}', null, paths ->
    {
      var n = 0;
      for (p in paths)
      {
        var target = abs(Path.join([dest, Path.withoutDirectory(p)]));
        if (EditorFiles.exists(target))
        {
          notify('Skipped ${Path.withoutDirectory(p)}: already exists (use Replace).', 0xFFFFB347);
          continue;
        }
        if (EditorFiles.saveBytes(target, sys.io.File.getBytes(p)) == null) n++;
      }
      notify('Imported $n file(s) into ${dest == '' ? 'the mod root' : dest}.');
      trace('[GOLDEN EDITOR] Asset Manager: imported $n file(s) into "$dest"');
      rebuildBrowser();
    }, () -> {});
    #end
  }

  function exportFile():Void
  {
    #if sys
    if (selected == null) return;
    var src = abs(selected);
    FileUtil.browseForSaveFile('Export ${Path.withoutDirectory(selected)}', null, path ->
    {
      var err = EditorFiles.saveBytes(path, sys.io.File.getBytes(src));
      notify(err ?? 'Exported to $path', err != null ? 0xFFFF5C5C : 0xFF6BE36B);
    }, () -> {}, Path.withoutDirectory(selected));
    #end
  }

  function replaceFile():Void
  {
    #if sys
    if (selected == null) return;
    var dst = abs(selected);
    FileUtil.browseForFile('Replace ${Path.withoutDirectory(selected)}', null, file ->
    {
      var err = EditorFiles.saveBytes(dst, sys.io.File.getBytes(file.fullPath));
      notify(err ?? 'Replaced ${Path.withoutDirectory(selected)}.', err != null ? 0xFFFF5C5C : 0xFF6BE36B);
      selectFile(selected, 'file');
    }, () -> {});
    #end
  }

  function renameFile():Void
  {
    #if sys
    if (selected == null || newName.trim() == '' || newName.indexOf('/') >= 0 || newName.indexOf('\\') >= 0 || newName.startsWith('.')) return;
    var to = Path.join([folder, newName.trim()]);
    if (EditorFiles.exists(abs(to)))
    {
      notify('"$to" already exists.', 0xFFFF5C5C);
      return;
    }
    sys.FileSystem.rename(abs(selected), abs(to));
    trace('[GOLDEN EDITOR] Asset Manager: renamed $selected -> $to');
    notify('Renamed to $to');
    selected = to;
    rebuildBrowser();
    #end
  }

  function deleteFile():Void
  {
    #if sys
    if (selected == null) return;
    var rel = selected;
    openSubState(new golden.ui.GoldenDialogs.GoldenConfirmSubState('Delete "$rel" from mod "${EditorFiles.target()}"?\n(It is moved to mods/.trash and can be recovered there.)', () ->
    {
      var trash = Path.join([golden.modding.GoldenMods.modRoot(), '.trash', EditorFiles.target(), DateTools.format(Date.now(), '%Y%m%d-%H%M%S'), rel]);
      EditorFiles.ensureDir(Path.directory(trash));
      sys.FileSystem.rename(abs(rel), trash);
      trace('[GOLDEN EDITOR] Asset Manager: deleted $rel (moved to $trash)');
      notify('Deleted $rel (recoverable from mods/.trash).');
      clearPreview();
      selected = null;
      rebuildBrowser();
    }));
    #end
  }

  /** Missing = referenced keys that resolve nowhere; unused = mod images/sounds/music referenced nowhere. */
  function scan():Void
  {
    var r = root();
    if (r == null) return;
    var text = new StringBuf();
    var files = EditorFiles.listFiles(r, ['json', 'lua', 'hxc', 'xml', 'txt']);
    for (f in files)
      text.add(EditorFiles.loadText(abs(f)) ?? '');
    var all = text.toString();
    missing = [];
    var keyRe = ~/"(assetPath|image|backgroundImage|titleAsset|sound|music|musicEnd|icon)"\s*:\s*"([^"]+)"/g;
    var pos = 0;
    var seen:Map<String, Bool> = [];
    while (keyRe.matchSub(all, pos))
    {
      var field = keyRe.matched(1), key = keyRe.matched(2);
      pos = keyRe.matchedPos().pos + keyRe.matchedPos().len;
      if (key == '' || key.startsWith('#') || seen.exists(field + key)) continue;
      seen.set(field + key, true);
      var k = key.indexOf(':') >= 0 ? key.split(':').pop() : key;
      var ok = switch (field)
      {
        case 'sound': Assets.exists(Paths.sound(k)) || Assets.exists(Paths.sound(k, 'shared'));
        case 'music' | 'musicEnd': Assets.exists(Paths.music(k));
        default: Assets.exists(Paths.image(k)) || Assets.exists(Paths.image(k, 'shared')) || Assets.exists(Paths.image('characters/$k'))
          || Assets.exists(Paths.image('characters/$k', 'shared')) || Assets.exists(Paths.file('images/$k/Animation.json')) || Assets.exists(Paths.file('images/$k/Animation.json', 'shared'));
      };
      if (!ok) missing.push('$field: $key');
    }
    unused = [];
    for (f in EditorFiles.listFiles(r, ['png', 'ogg']))
    {
      if (!f.startsWith('images/') && !f.startsWith('sounds/') && !f.startsWith('music/')) continue;
      var key = Path.withoutExtension(f.substr(f.indexOf('/') + 1));
      var base = Path.withoutDirectory(key);
      if (all.indexOf(key) < 0 && all.indexOf(base) < 0) unused.push(f);
    }
    trace('[GOLDEN EDITOR] Asset Manager scan: ${missing.length} missing, ${unused.length} unused' + (missing.length > 0 ? ' (missing: ' + missing.join('; ') + ')' : ''));
    notify('Scan: ${missing.length} missing, ${unused.length} unused (see the browser).', missing.length > 0 ? 0xFFFFB347 : 0xFF6BE36B);
    rebuildBrowser();
  }

  function rebuildInspector():Void
  {
    inspectorDirty = false;
    inspector.clearRows();
    inspector.addHeader('Mod: ${EditorFiles.target() ?? "(none)"}');
    inspector.addText('Folder', () -> folder, v -> folder = v.trim().replace('\\', '/'));
    inspector.addButtons([{caption: 'New folder', fn: () ->
      {
        if (folder == '' || folder.indexOf('..') >= 0) return;
        EditorFiles.ensureDir(abs(folder));
        notify('Folder "$folder" ready (empty folders show once they contain a file).');
        trace('[GOLDEN EDITOR] Asset Manager: folder $folder created');
      }}]);
    if (selected == null)
    {
      inspector.addNote('Select a file on the left. Import copies files into the folder above.');
      return;
    }
    inspector.addHeader(Path.withoutDirectory(selected));
    #if sys
    var st = sys.FileSystem.stat(abs(selected));
    inspector.addNote('Path: $selected\nSize: ${Math.round(st.size / 102.4) / 10} KB\nModified: ${st.mtime}');
    #end
    if (preview != null) inspector.addNote('Image: ${preview.frameWidth} x ${preview.frameHeight} px');
    var ext = Path.extension(selected).toLowerCase();
    if (ext == 'ogg' || ext == 'wav') inspector.addButtons([{caption: 'Play', fn: playSound}, {caption: 'Stop', fn: () -> sound?.stop()}]);
    inspector.addText('New name', () -> newName, v -> newName = v);
    inspector.addButtons([{caption: 'Rename', fn: renameFile}, {caption: 'Replace...', fn: replaceFile}]);
    inspector.addButtons([{caption: 'Export...', fn: exportFile}, {caption: 'Delete', fn: deleteFile}]);
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (inspectorDirty) rebuildInspector();
  }

  override function destroy():Void
  {
    sound?.stop();
    super.destroy();
  }
}
