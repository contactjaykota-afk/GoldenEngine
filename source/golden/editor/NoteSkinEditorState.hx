package golden.editor;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;
import funkin.data.song.SongRegistry;
import funkin.util.FileUtil;
import golden.editor.EditorUI;

using StringTools;

/**
 * Golden Engine — Note Skin Editor. Creates FNF note styles (data/notestyles/<id>.json, the format
 * gameplay loads) from an existing one, with imported textures (a Sparrow PNG + XML per part: notes,
 * receptors, hold notes), editable animation prefixes and scales, per-direction colours (Golden:
 * data/golden/notecolors.json, applied in gameplay), a live preview of all four directions, and
 * "Use in song" (writes a copy of the song's metadata in the mod with this note style).
 */
class NoteSkinEditorState extends GoldenEditorState
{
  static var colorCache:Null<Dynamic> = null;

  /** Per-direction tints for a note style (or null). */
  public static function tintsFor(styleId:String):Null<Array<FlxColor>>
  {
    if (colorCache == null)
    {
      colorCache = {};
      var p = Paths.json('golden/notecolors');
      if (Assets.exists(p))
      {
        try
          colorCache = haxe.Json.parse(Assets.getText(p))
        catch (e:Dynamic)
          trace('[GOLDEN] Invalid $p: $e');
      }
    }
    var v:Array<Dynamic> = Reflect.field(colorCache, styleId);
    if (v == null || v.length < 4) return null;
    return [for (c in v) FlxColor.fromString(Std.string(c)) ?? FlxColor.WHITE];
  }

  public static function clearColors():Void
    colorCache = null;

  static final DIRS:Array<String> = ['left', 'down', 'up', 'right'];

  var styleId:String = 'golden-notes';
  var style:Dynamic;
  var tints:Array<String> = ['#FFFFFF', '#FFFFFF', '#FFFFFF', '#FFFFFF'];
  var browser:Browser;
  var inspector:Inspector;
  var inspectorDirty:Bool = true;
  var preview:FlxSpriteGroup;
  var songChoice:String = 'bopeebo';
  var pressed:Bool = false;

  public function new()
    super('Note Skin Editor');

  override function buildEditor():Void
  {
    preview = new FlxSpriteGroup();
    add(preview);
    browser = ui(new Browser(0, GoldenEditorState.TOP, leftW, FlxG.height - GoldenEditorState.TOP - GoldenEditorState.BOTTOM));
    browser.onSelect = it -> loadStyle(it.data.id, it.data.copy == true);
    inspector = ui(new Inspector(FlxG.width - rightW, GoldenEditorState.TOP, rightW, FlxG.height - GoldenEditorState.TOP - GoldenEditorState.BOTTOM));
    addTool('Press / Confirm', () ->
    {
      pressed = !pressed;
      refreshPreview();
    }, 'Toggle receptor confirm animation in the preview');
    camWorld.zoom = 0.8;
    centerWorkspaceOn(FlxG.width / 2, FlxG.height / 2);
    var items:Array<BrowserItem> = [];
    for (id in funkin.data.notestyle.NoteStyleRegistry.instance.listEntryIds())
    {
      items.push({folder: 'Edit', label: id, data: {id: id, copy: false}});
      items.push({folder: 'New skin based on', label: id, data: {id: id, copy: true}});
    }
    browser.setItems(items);
    loadStyle('funkin', true);
  }

  function loadStyle(id:String, copy:Bool):Void
  {
    try
    {
      style = haxe.Json.parse(Assets.getText(Paths.json('notestyles/$id')));
    }
    catch (e:Dynamic)
    {
      notify('Could not read note style "$id": $e', 0xFFFF5C5C);
      return;
    }
    if (copy)
    {
      var n = 1;
      while (funkin.data.notestyle.NoteStyleRegistry.instance.hasEntry('golden-notes$n'))
        n++;
      styleId = 'golden-notes$n';
      style.name = 'Golden Notes $n';
      if (id != 'funkin') style.fallback = style.fallback ?? 'funkin';
    }
    else
      styleId = id;
    clearColors();
    var t = tintsFor(styleId);
    tints = t != null ? [for (c in t) '#' + c.toHexString(false, false)] : ['#FFFFFF', '#FFFFFF', '#FFFFFF', '#FFFFFF'];
    resetHistory();
    inspectorDirty = true;
    refreshPreview();
    trace('[GOLDEN EDITOR] Note Skin Editor: ${copy ? "new skin from" : "editing"} "$id" as "$styleId"');
  }

  function part(name:String):Dynamic
    return Reflect.field(style.assets, name);

  override function serialize():String
    return haxe.Json.stringify({id: styleId, s: style, t: tints});

  override function deserialize(s:String):Void
  {
    var o:Dynamic = haxe.Json.parse(s);
    styleId = o.id;
    style = o.s;
    tints = o.t;
    inspectorDirty = true;
  }

  override function refreshPanels():Void
    inspectorDirty = true;

  override function save():Null<String>
  {
    var mod = EditorFiles.target();
    var err = EditorFiles.saveJson(EditorFiles.modPath('data/notestyles/$styleId.json', mod), style);
    if (err != null) return err;
    var cp = EditorFiles.modPath('data/golden/notecolors.json', mod);
    var colors:Dynamic = EditorFiles.exists(cp) ? (EditorFiles.loadJson(cp) ?? {}) : {};
    if (tints.foreach(t -> t.toUpperCase() == '#FFFFFF')) Reflect.deleteField(colors, styleId) else Reflect.setField(colors, styleId, tints);
    err = EditorFiles.saveJson(cp, colors);
    if (err != null) return err;
    clearColors();
    EditorFiles.reloadGameContent();
    return null;
  }

  /** Write a copy of the song's metadata into the mod with this note style. */
  function useInSong():Void
  {
    if (dirty) doSave();
    var path = Paths.json('songs/$songChoice/$songChoice-metadata');
    var meta:Dynamic = null;
    try
      meta = haxe.Json.parse(Assets.getText(path))
    catch (e:Dynamic)
    {
      notify('Could not read $path: $e', 0xFFFF5C5C);
      return;
    }
    meta.playData.noteStyle = styleId;
    var err = EditorFiles.saveJson(EditorFiles.modPath('data/songs/$songChoice/$songChoice-metadata.json'), meta);
    if (err != null)
    {
      notify(err, 0xFFFF5C5C);
      return;
    }
    EditorFiles.reloadGameContent();
    notify('"$songChoice" now uses "$styleId" (copy of its metadata in the mod).', 0xFF6BE36B);
    trace('[GOLDEN EDITOR] Note Skin Editor: $songChoice uses $styleId');
  }

  function importPart(partName:String):Void
  {
    #if sys
    FileUtil.browseForFile('Import $partName texture (PNG with a matching XML next to it)', [FileUtil.FILE_FILTER_PNG], file ->
    {
      var png = file.fullPath;
      var xml = haxe.io.Path.withoutExtension(png) + '.xml';
      if (!sys.FileSystem.exists(xml))
      {
        notify('No XML next to the PNG (${haxe.io.Path.withoutDirectory(xml)}): note textures must be Sparrow sheets.', 0xFFFF5C5C);
        return;
      }
      var key = 'notestyles/$styleId/$partName';
      EditorFiles.saveBytes(EditorFiles.modPath('images/$key.png'), sys.io.File.getBytes(png));
      EditorFiles.saveText(EditorFiles.modPath('images/$key.xml'), sys.io.File.getContent(xml));
      part(partName).assetPath = key;
      changed();
      notify('Imported $partName texture as images/$key.png (save to reload it in the preview).');
    }, () -> {});
    #end
  }

  static function atlasOf(path:String):Null<flixel.graphics.frames.FlxAtlasFrames>
  {
    var lib:Null<String> = null;
    var key = path;
    if (path.indexOf(':') >= 0)
    {
      lib = path.split(':')[0];
      key = path.split(':')[1];
    }
    if (!Assets.exists(Paths.image(key, lib))) return null;
    return Paths.getSparrowAtlas(key, lib);
  }

  override function rebuildPreview():Void
  {
    if (preview == null || style == null) return;
    preview.forEach(s -> s.destroy());
    preview.clear();
    var strum:Dynamic = part("noteStrumline");
    var note:Dynamic = part("note");
    var sf = strum != null ? atlasOf(strum.assetPath) : null;
    var nf = note != null ? atlasOf(note.assetPath) : null;
    for (i in 0...4)
    {
      var d = DIRS[i];
      var col = FlxColor.fromString(tints[i]) ?? FlxColor.WHITE;
      var x = 280 + i * 180;
      if (sf != null)
      {
        var s = new FlxSprite(x, 120);
        s.frames = sf;
        var key = d + (pressed ? 'Confirm' : 'Static');
        var pf:Dynamic = Reflect.field(strum.data, key);
        if (pf != null) s.animation.addByPrefix('a', pf.prefix, 24, true);
        s.animation.play('a');
        s.scale.set(strum.scale ?? 0.7, strum.scale ?? 0.7);
        s.updateHitbox();
        s.color = col;
        preview.add(s);
      }
      if (nf != null)
      {
        var n = new FlxSprite(x, 420);
        n.frames = nf;
        var pf:Dynamic = Reflect.field(note.data, d);
        if (pf != null) n.animation.addByPrefix('a', pf.prefix, 24, true);
        n.animation.play('a');
        n.scale.set(note.scale ?? 0.7, note.scale ?? 0.7);
        n.updateHitbox();
        n.color = col;
        preview.add(n);
      }
    }
    if (sf == null || nf == null) notify('Some textures could not be loaded (check the asset paths).', 0xFFFFB347);
  }

  function rebuildInspector():Void
  {
    inspectorDirty = false;
    inspector.clearRows();
    inspector.addHeader('Note skin');
    inspector.addText('Skin ID', () -> styleId, v ->
    {
      styleId = EditorFiles.safeId(v);
      changed();
    });
    inspector.addText('Name', () -> style.name ?? '', v -> edit(() -> style.name = v));
    inspector.addText('Author', () -> style.author ?? '', v -> edit(() -> style.author = v));
    inspector.addText('Fallback', () -> style.fallback ?? '', v -> edit(() -> style.fallback = v.trim() == '' ? null : v.trim()));
    inspector.addHeader('Colours');
    for (i in 0...4)
    {
      var idx = i;
      inspector.addText('${DIRS[idx]} colour', () -> tints[idx], v -> edit(() -> tints[idx] = v.trim()));
    }
    for (pn in ['note', 'noteStrumline', 'holdNote'])
    {
      var p:Dynamic = part(pn);
      if (p == null) continue;
      inspector.addHeader(pn == 'note' ? 'Notes' : (pn == 'noteStrumline' ? 'Receptors' : 'Hold notes / ends'));
      inspector.addText('$pn asset', () -> p.assetPath, v -> edit(() -> p.assetPath = v.trim()));
      inspector.addNumber('$pn scale', () -> p.scale ?? 1, v -> edit(() -> p.scale = v), 0.05, 0.05, 5);
      inspector.addButtons([{caption: 'Import $pn texture...', fn: () -> importPart(pn)}]);
      if (pn == 'note') for (d in DIRS)
      {
        var dd:Dynamic = Reflect.field(p.data, d);
        if (dd != null) inspector.addText('$d prefix', () -> dd.prefix, v -> edit(() -> dd.prefix = v));
      }
    }
    inspector.addHeader('Use in a song');
    inspector.addChoice('Song', () -> SongRegistry.instance.listEntryIds(), () -> songChoice, v -> songChoice = v);
    inspector.addButtons([{caption: 'Use in song', fn: useInSong, tooltip: 'Copy the song metadata into the mod with this note style'}]);
  }

  function edit(fn:Void->Void):Void
  {
    fn();
    changed();
  }

  override public function changed(?what:String):Void
  {
    super.changed(what);
    inspector.refresh();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (inspectorDirty) rebuildInspector();
  }
}
