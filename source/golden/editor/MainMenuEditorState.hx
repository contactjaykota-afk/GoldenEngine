package golden.editor;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;
import funkin.data.song.SongRegistry;
import golden.editor.EditorUI;

using StringTools;

/**
 * Golden Engine — Main Menu Editor: background (image + tint), logo, entry order and visibility,
 * custom entries (open a screen, play a song, open a web page), spacing/offset and menu music, with a
 * live preview using the real menu art. Saved as data/golden/mainmenu.json (see golden.GoldenMainMenu)
 * and applied by FNF's main menu.
 */
class MainMenuEditorState extends GoldenEditorState
{
  static final BUILTIN:Array<String> = ['storymode', 'freeplay', 'mods', 'editors', 'options', 'credits'];
  static final ACTIONS:Array<String> = ['song:bopeebo', 'state:freeplay', 'state:story', 'state:options', 'state:credits', 'state:mods', 'state:editors', 'url:https://'];

  var cfg:Dynamic;
  var preview:FlxSpriteGroup;
  var inspector:Inspector;
  var browser:Browser;
  var inspectorDirty:Bool = true;
  var selItem:Int = -1;
  var selCustom:Int = -1;

  public function new()
    super('Main Menu Editor');

  override function buildEditor():Void
  {
    preview = new FlxSpriteGroup();
    add(preview);
    var path = EditorFiles.modPath('data/golden/mainmenu.json');
    cfg = path != null && EditorFiles.exists(path) ? EditorFiles.loadJson(path) : null;
    if (cfg == null) cfg = {
      version: 1,
      background: 'menuBG',
      backgroundColor: '#FFFFFF',
      logo: '',
      logoX: 640,
      logoY: 110,
      logoScale: 1,
      music: '',
      spacing: 0,
      offsetX: 0,
      items: [for (b in BUILTIN) {id: b, visible: true}],
      custom: []
    };
    browser = ui(new Browser(0, GoldenEditorState.TOP, leftW, FlxG.height - GoldenEditorState.TOP - GoldenEditorState.BOTTOM));
    browser.onSelect = it ->
    {
      var d:Dynamic = it.data;
      selItem = d.kind == 'item' ? d.index : -1;
      selCustom = d.kind == 'custom' ? d.index : -1;
      inspectorDirty = true;
    };
    inspector = ui(new Inspector(FlxG.width - rightW, GoldenEditorState.TOP, rightW, FlxG.height - GoldenEditorState.TOP - GoldenEditorState.BOTTOM));
    addTool('Add Entry', addCustom, 'Add a custom menu entry');
    addTool('Open Main Menu', () ->
    {
      if (dirty) doSave();
      leaving = true;
      FlxG.switchState(() -> new funkin.ui.mainmenu.MainMenuState());
    }, 'Save and open the real main menu');
    camWorld.zoom = (FlxG.width - leftW - rightW) / FlxG.width;
    centerWorkspaceOn(FlxG.width / 2, FlxG.height / 2);
    rebuildBrowser();
    resetHistory();
    trace('[GOLDEN EDITOR] Main Menu Editor: ${(cfg.items : Array<Dynamic>).length} entries, ${(cfg.custom : Array<Dynamic>).length} custom');
  }

  function rebuildBrowser():Void
  {
    var items:Array<BrowserItem> = [];
    var list:Array<Dynamic> = cfg.items;
    for (i in 0...list.length)
      items.push({folder: 'Entries (order)', label: '${i + 1}. ${list[i].id}' + (list[i].visible == false ? ' (hidden)' : ''), data: {kind: 'item', index: i}});
    var cus:Array<Dynamic> = cfg.custom;
    for (i in 0...cus.length)
      items.push({folder: 'Custom entries', label: '${cus[i].label} -> ${cus[i].action}', data: {kind: 'custom', index: i}});
    browser.setItems(items);
  }

  function addCustom():Void
  {
    (cfg.custom : Array<Dynamic>).push({label: 'NEW ENTRY', action: 'song:bopeebo', atlas: ''});
    selCustom = (cfg.custom : Array<Dynamic>).length - 1;
    selItem = -1;
    changed();
    rebuildBrowser();
    inspectorDirty = true;
    trace('[GOLDEN EDITOR] Main Menu Editor: custom entry added');
  }

  override function serialize():String
    return haxe.Json.stringify(cfg);

  override function deserialize(s:String):Void
  {
    cfg = haxe.Json.parse(s);
    rebuildBrowser();
    inspectorDirty = true;
  }

  override function refreshPanels():Void
    inspectorDirty = true;

  override function save():Null<String>
  {
    var err = EditorFiles.saveJson(EditorFiles.modPath('data/golden/mainmenu.json'), cfg);
    if (err == null)
    {
      golden.GoldenMainMenu.clearCache();
      EditorFiles.reloadGameContent();
    }
    return err;
  }

  override function rebuildPreview():Void
  {
    if (preview == null) return;
    preview.forEach(s -> s.destroy());
    preview.clear();
    var bgKey:String = cfg.background ?? 'menuBG';
    var bg = new FlxSprite().loadGraphic(Paths.image(Assets.exists(Paths.image(bgKey)) ? bgKey : 'menuBG'));
    bg.setGraphicSize(Std.int(FlxG.width * 1.2));
    bg.updateHitbox();
    bg.screenCenter();
    bg.color = FlxColor.fromString(cfg.backgroundColor ?? '#FFFFFF') ?? FlxColor.WHITE;
    preview.add(bg);
    var entries:Array<{name:String, frames:flixel.graphics.frames.FlxAtlasFrames}> = [];
    for (it in (cfg.items : Array<Dynamic>))
      if (it.visible != false && Assets.exists(Paths.file('images/mainmenu/${it.id}.xml'))) entries.push({name: it.id, frames: Paths.getSparrowAtlas('mainmenu/${it.id}')});
    var cus:Array<Dynamic> = cfg.custom;
    for (i in 0...cus.length)
      entries.push({name: 'golden-custom$i', frames: golden.GoldenMainMenu.labelFrames('golden-custom$i', Std.string(cus[i].label))});
    var spacing:Float = (cfg.spacing ?? 0) > 0 ? cfg.spacing : (entries.length > 5 ? 140 : 160);
    var top = (FlxG.height - spacing * (entries.length - 1)) / 2;
    for (i in 0...entries.length)
    {
      var s = new FlxSprite();
      s.frames = entries[i].frames;
      s.animation.addByPrefix('idle', '${entries[i].name} idle', 24);
      s.animation.addByPrefix('selected', '${entries[i].name} selected', 24);
      s.animation.play(i == 0 ? 'selected' : 'idle');
      s.updateHitbox();
      s.x = FlxG.width / 2 + (cfg.offsetX ?? 0) - s.width / 2;
      s.y = top + spacing * i - s.height / 2;
      preview.add(s);
    }
    var logoKey:String = cfg.logo ?? '';
    if (logoKey != '' && Assets.exists(Paths.image(logoKey)))
    {
      var l = new FlxSprite().loadGraphic(Paths.image(logoKey));
      var sc:Float = cfg.logoScale ?? 1;
      l.scale.set(sc, sc);
      l.updateHitbox();
      l.x = (cfg.logoX ?? 640) - l.width / 2;
      l.y = (cfg.logoY ?? 110) - l.height / 2;
      preview.add(l);
    }
  }

  function rebuildInspector():Void
  {
    inspectorDirty = false;
    inspector.clearRows();
    inspector.addHeader('Menu');
    inspector.addText('Background image', () -> cfg.background ?? '', v -> edit(() -> cfg.background = v.trim()));
    inspector.addText('Background tint', () -> cfg.backgroundColor ?? '', v -> edit(() -> cfg.backgroundColor = v.trim()));
    inspector.addText('Logo image', () -> cfg.logo ?? '', v -> edit(() -> cfg.logo = v.trim()));
    inspector.addNumber('Logo X', () -> cfg.logoX ?? 640, v -> edit(() -> cfg.logoX = v), 10);
    inspector.addNumber('Logo Y', () -> cfg.logoY ?? 110, v -> edit(() -> cfg.logoY = v), 10);
    inspector.addNumber('Logo scale', () -> cfg.logoScale ?? 1, v -> edit(() -> cfg.logoScale = v), 0.05, 0.05, 10);
    inspector.addNumber('Spacing (0 = auto)', () -> cfg.spacing ?? 0, v -> edit(() -> cfg.spacing = v), 5, 0, 400);
    inspector.addNumber('Offset X', () -> cfg.offsetX ?? 0, v -> edit(() -> cfg.offsetX = v), 10);
    inspector.addText('Music (music/<key>/)', () -> cfg.music ?? '', v -> edit(() -> cfg.music = v.trim()));
    var list:Array<Dynamic> = cfg.items;
    if (selItem >= 0 && selItem < list.length)
    {
      var it:Dynamic = list[selItem];
      inspector.addHeader('Entry: ${it.id}');
      inspector.addToggle('Visible', () -> it.visible != false, v -> edit(() -> it.visible = v));
      inspector.addButtons([{caption: 'Move up', fn: () -> move(-1)}, {caption: 'Move down', fn: () -> move(1)}]);
    }
    var cus:Array<Dynamic> = cfg.custom;
    if (selCustom >= 0 && selCustom < cus.length)
    {
      var e:Dynamic = cus[selCustom];
      inspector.addHeader('Custom entry');
      inspector.addText('Label', () -> e.label, v -> edit(() -> e.label = v));
      inspector.addChoice('Action', () -> ACTIONS.concat([for (s in SongRegistry.instance.listEntryIds()) 'song:$s']), () -> e.action, v -> edit(() -> e.action = v));
      inspector.addText('Action (custom)', () -> e.action, v -> edit(() -> e.action = v.trim()));
      inspector.addText('Atlas (optional)', () -> e.atlas ?? '', v -> edit(() -> e.atlas = v.trim()));
      inspector.addNote('Atlas: a sparrow sheet in images/ with "<name> idle" and "<name> selected" frames; empty = generated from the label.');
      inspector.addButtons([{caption: 'Delete entry', fn: () ->
        {
          cus.splice(selCustom, 1);
          selCustom = -1;
          changed();
          rebuildBrowser();
          inspectorDirty = true;
        }}]);
    }
  }

  function move(d:Int):Void
  {
    var list:Array<Dynamic> = cfg.items;
    var j = selItem + d;
    if (j < 0 || j >= list.length) return;
    var t = list[selItem];
    list[selItem] = list[j];
    list[j] = t;
    selItem = j;
    changed();
    rebuildBrowser();
    inspectorDirty = true;
  }

  function edit(fn:Void->Void):Void
  {
    fn();
    changed();
    rebuildBrowser();
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
