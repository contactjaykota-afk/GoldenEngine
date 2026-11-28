package golden.editor;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.data.song.SongRegistry;
import funkin.data.story.level.LevelRegistry;
import golden.editor.EditorUI;

using StringTools;

/**
 * Golden Engine — Week Editor. Edits FNF story weeks (data/levels/<id>.json, the format Story Mode
 * reads) with a live story-menu preview: name, title graphic, background colour, menu characters
 * (props), songs (add/remove/reorder), visibility, and an unlock requirement (Golden:
 * data/golden/weeks.json, checked by Level.isUnlocked). Saved into the target mod.
 */
class WeekEditorState extends GoldenEditorState
{
  static var rulesCache:Null<Dynamic> = null;

  /** Golden unlock rules: { "<level id>": { "requires": "<level id>" } } merged from enabled mods. */
  public static function isLevelUnlocked(levelId:String):Bool
  {
    if (rulesCache == null)
    {
      rulesCache = {};
      var path = Paths.json('golden/weeks');
      if (Assets.exists(path))
      {
        try
          rulesCache = haxe.Json.parse(Assets.getText(path))
        catch (e:Dynamic)
          trace('[GOLDEN] Invalid $path: $e');
      }
    }
    var r:Dynamic = Reflect.field(rulesCache, levelId);
    if (r == null || r.requires == null || r.requires == '') return true;
    // Checked against the saved scores directly: FNF builds define UNLOCK_EVERYTHING, which makes
    // Save.hasBeatenLevel() always true.
    for (d in ['easy', 'normal', 'hard', 'erect', 'nightmare'])
    {
      var sc = funkin.save.Save.instance.getLevelScore(r.requires, d);
      if (sc != null && sc.score > 0) return true;
    }
    return false;
  }

  public static function clearRules():Void
    rulesCache = null;

  var levelId:String = 'new-week';
  var level:Dynamic;
  var requires:String = '';
  var preview:FlxSpriteGroup;
  var browser:Browser;
  var inspector:Inspector;
  var addSongChoice:String = 'bopeebo';
  var inspectorDirty:Bool = true;

  static final PROPS:Array<String> = ['(none)', 'bf', 'dad', 'gf', 'mom', 'darnell'];

  public function new()
  {
    super('Week Editor');
  }

  override function buildEditor():Void
  {
    preview = new FlxSpriteGroup();
    add(preview);
    browser = ui(new Browser(0, GoldenEditorState.TOP, leftW, FlxG.height - GoldenEditorState.TOP - GoldenEditorState.BOTTOM));
    browser.onSelect = it -> confirmDiscard(() -> it.data.id == '' ? newWeek() : loadWeek(it.data.id));
    inspector = ui(new Inspector(FlxG.width - rightW, GoldenEditorState.TOP, rightW, FlxG.height - GoldenEditorState.TOP - GoldenEditorState.BOTTOM));
    addTool('New Week', () -> confirmDiscard(newWeek));
    addTool('Open Story Mode', openStory, 'Save, reload and open Story Mode');
    camWorld.zoom = (FlxG.width - leftW - rightW) / FlxG.width;
    camWorld.scroll.set(0, 0);
    centerWorkspaceOn(FlxG.width / 2, FlxG.height / 2);
    rebuildBrowser();
    newWeek();
  }

  function rebuildBrowser():Void
  {
    var items:Array<BrowserItem> = [{folder: 'Weeks', label: '+ New week', data: {id: ''}}];
    for (id in LevelRegistry.instance.listEntryIds())
      items.push({folder: 'Weeks', label: id, data: {id: id}});
    browser.setItems(items);
  }

  function confirmDiscard(fn:Void->Void):Void
  {
    if (!dirty) fn();
    else
      openSubState(new golden.ui.GoldenDialogs.GoldenConfirmSubState('Discard unsaved changes to "$levelId"?', fn));
  }

  function newWeek():Void
  {
    var n = 1;
    while (LevelRegistry.instance.hasEntry('custom-week$n'))
      n++;
    levelId = 'custom-week$n';
    level = {
      version: '1.0.0',
      name: 'CUSTOM WEEK $n',
      titleAsset: 'storymenu/titles/week1',
      props: [prop('dad', 100, 60), prop('bf', 150, 80), prop('gf', 200, 80)],
      background: '#F9CF51',
      visible: true,
      songs: ['bopeebo']
    };
    requires = '';
    resetHistory();
    inspectorDirty = true;
    refreshPreview();
    trace('[GOLDEN EDITOR] Week Editor: new week "$levelId"');
  }

  function loadWeek(id:String):Void
  {
    var path = Paths.json('levels/$id');
    try
    {
      level = haxe.Json.parse(Assets.getText(path));
    }
    catch (e:Dynamic)
    {
      notify('Could not read $path: $e', 0xFFFF5C5C);
      return;
    }
    levelId = id;
    if (level.visible == null) level.visible = true;
    clearRules();
    isLevelUnlocked(id);
    var r:Dynamic = Reflect.field(rulesCache, id);
    requires = r != null && r.requires != null ? r.requires : '';
    resetHistory();
    inspectorDirty = true;
    refreshPreview();
    trace('[GOLDEN EDITOR] Week Editor: opened "$id" (${level.songs.length} songs)');
  }

  static function prop(name:String, ox:Float, oy:Float):Dynamic
  {
    var anims:Array<Dynamic> = name == 'gf' ? [
      {name: 'danceLeft', prefix: 'idle0', frameIndices: [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]},
      {name: 'danceRight', prefix: 'idle0', frameIndices: [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29]}
    ] : [{name: 'idle', prefix: 'idle0', frameRate: 24}];
    if (name == 'bf') anims.push({name: 'confirm', prefix: 'confirm0', frameRate: 24});
    return {assetPath: 'storymenu/props/$name', scale: 1.0, offsets: [ox, oy], animations: anims};
  }

  override function serialize():String
    return haxe.Json.stringify({id: levelId, level: level, requires: requires});

  override function deserialize(s:String):Void
  {
    var d:Dynamic = haxe.Json.parse(s);
    levelId = d.id;
    level = d.level;
    requires = d.requires;
    inspectorDirty = true;
  }

  override function refreshPanels():Void
    inspectorDirty = true;

  override function save():Null<String>
  {
    var songs:Array<String> = level.songs;
    if (songs.length == 0) return 'A week needs at least one song.';
    for (s in songs)
      if (SongRegistry.instance.fetchEntry(s) == null) return 'Song "$s" does not exist.';
    var mod = EditorFiles.target();
    var err = EditorFiles.saveJson(EditorFiles.modPath('data/levels/$levelId.json', mod), level);
    if (err != null) return err;
    // unlock rules (merged with the mod's existing file)
    var rp = EditorFiles.modPath('data/golden/weeks.json', mod);
    var rules:Dynamic = EditorFiles.exists(rp) ? (EditorFiles.loadJson(rp) ?? {}) : {};
    if (requires == '') Reflect.deleteField(rules, levelId) else Reflect.setField(rules, levelId, {requires: requires});
    err = EditorFiles.saveJson(rp, rules);
    if (err != null) return err;
    clearRules();
    EditorFiles.reloadGameContent();
    rebuildBrowser();
    trace('[GOLDEN EDITOR] Week Editor: saved "$levelId" (registered: ${LevelRegistry.instance.hasEntry(levelId)}, unlocked: ${isLevelUnlocked(levelId)})');
    return null;
  }

  function openStory():Void
  {
    if (dirty) doSave();
    trace('[GOLDEN EDITOR] Week Editor: opening Story Mode');
    leaving = true;
    FlxG.switchState(() -> new funkin.ui.story.StoryMenuState());
  }

  override function rebuildPreview():Void
  {
    if (preview == null || level == null) return;
    preview.forEach(s -> s.destroy());
    preview.clear();
    preview.add(EditorUI.rect(0, 0, FlxG.width, FlxG.height, 0xFF000000));
    var bg = Std.string(level.background ?? '#F9CF51');
    var band = new FlxSprite(0, 56);
    var imagePath = bg.startsWith('#') ? null : Paths.image(bg);
    if (imagePath != null && Assets.exists(imagePath)) band.loadGraphic(imagePath);
    else
    {
      band.makeGraphic(FlxG.width, 400, FlxColor.WHITE);
      band.color = FlxColor.fromString(bg) ?? 0xFFF9CF51;
    }
    preview.add(band);
    var props:Array<Dynamic> = level.props ?? [];
    for (i in 0...props.length)
    {
      var pd = props[i];
      var path:String = pd.assetPath;
      if (path == null || !Assets.exists(Paths.image(path))) continue;
      var s = new FlxSprite();
      var xml = Paths.file('images/$path.xml');
      if (Assets.exists(xml))
      {
        s.frames = Paths.getSparrowAtlas(path);
        var a:Array<Dynamic> = pd.animations;
        if (a != null && a.length > 0)
        {
          s.animation.addByPrefix('preview', a[0].prefix, 24, true);
          s.animation.play('preview');
        }
      }
      else
        s.loadGraphic(Paths.image(path));
      s.scale.set(pd.scale ?? 1, pd.scale ?? 1);
      s.updateHitbox();
      var off:Array<Float> = pd.offsets ?? [0.0, 0.0];
      s.x = (FlxG.width * 0.25) * (1 + i) - 150 + off[0];
      s.y = 56 + off[1];
      preview.add(s);
    }
    var title = Std.string(level.titleAsset ?? '');
    if (title != '' && Assets.exists(Paths.image(title)))
    {
      var t = new FlxSprite().loadGraphic(Paths.image(title));
      t.x = (FlxG.width - t.width) / 2;
      t.y = 480;
      preview.add(t);
    }
    var name = new FlxText(FlxG.width - 600, 10, 590, Std.string(level.name ?? '').toUpperCase(), 32);
    name.setFormat(Paths.font('vcr.ttf'), 32, 0xFFB3B3B3, RIGHT);
    preview.add(name);
    var tracks = new FlxText(40, 500, 400, 'TRACKS\n\n' + (level.songs : Array<String>).map(s -> s.toUpperCase()).join('\n'), 32);
    tracks.setFormat(Paths.font('vcr.ttf'), 32, 0xFFE55777, CENTER);
    preview.add(tracks);
    if (requires != '')
    {
      var lock = new FlxText(0, 440, FlxG.width, 'LOCKED UNTIL "${requires.toUpperCase()}" IS BEATEN', 24);
      lock.setFormat(Paths.font('vcr.ttf'), 24, 0xFFFFC83D, CENTER);
      preview.add(lock);
    }
  }

  function rebuildInspector():Void
  {
    inspectorDirty = false;
    inspector.clearRows();
    inspector.addHeader('Week');
    inspector.addText('Week ID', () -> levelId, v ->
    {
      levelId = EditorFiles.safeId(v);
      changed();
    });
    inspector.addText('Name', () -> level.name, v ->
    {
      level.name = v;
      changed();
    });
    inspector.addText('Title graphic', () -> level.titleAsset, v ->
    {
      level.titleAsset = v;
      changed();
    });
    inspector.addText('Background', () -> level.background, v ->
    {
      level.background = v;
      changed();
    });
    inspector.addNote('Background: a colour (#RRGGBB) or an image key (e.g. storymenu/myweek-bg).');
    inspector.addToggle('Visible in menu', () -> level.visible == true, v ->
    {
      level.visible = v;
      changed();
    });
    inspector.addChoice('Requires beating', () -> ['(none)'].concat(LevelRegistry.instance.listEntryIds().filter(x -> x != levelId)), () -> requires == '' ? '(none)' : requires,
      v ->
      {
        requires = v == '(none)' ? '' : v;
        changed();
      });
    inspector.addHeader('Songs (story order)');
    var songs:Array<String> = level.songs;
    for (i in 0...songs.length)
    {
      var idx = i;
      inspector.addNote('${idx + 1}. ${songs[idx]}', EditorUI.TEXT);
      inspector.addButtons([
        {caption: 'Up', fn: () -> moveSong(idx, -1)}, {caption: 'Down', fn: () -> moveSong(idx, 1)}, {caption: 'Remove ${songs[idx]}', fn: () ->
          {
            songs.splice(idx, 1);
            changed();
            inspectorDirty = true;
          }}
      ]);
    }
    inspector.addChoice('Song to add', () -> SongRegistry.instance.listEntryIds(), () -> addSongChoice, v -> addSongChoice = v);
    inspector.addButtons([{caption: 'Add song', fn: () ->
      {
        songs.push(addSongChoice);
        changed();
        inspectorDirty = true;
      }}]);
    inspector.addHeader('Menu characters');
    var props:Array<Dynamic> = level.props;
    for (slot in 0...3)
    {
      var s = slot;
      inspector.addChoice(['Opponent', 'Player', 'Girlfriend'][s], () -> PROPS, () ->
      {
        var p = props[s];
        return p == null ? '(none)' : Std.string(p.assetPath).split('/').pop();
      }, v ->
      {
        while (props.length <= s)
          props.push(null);
        props[s] = v == '(none)' ? null : prop(v, [100, 150, 200][s], [60, 80, 80][s]);
        level.props = props.filter(x -> x != null);
        changed();
      });
    }
    inspector.addNote('Difficulties come from each song (set in the Chart Editor).');
  }

  function moveSong(i:Int, d:Int):Void
  {
    var songs:Array<String> = level.songs;
    var j = i + d;
    if (j < 0 || j >= songs.length) return;
    var t = songs[i];
    songs[i] = songs[j];
    songs[j] = t;
    changed();
    inspectorDirty = true;
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
