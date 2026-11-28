package golden.editor;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.audio.FunkinSound;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.data.song.SongRegistry;
import funkin.play.character.BaseCharacter;
import funkin.util.FileUtil;
import golden.editor.EditorUI;

using StringTools;

/**
 * Golden Engine — Game Over Editor. Opens with the default setup ready to customise; optional
 * per-song setups. Saved as data/golden/gameover.json in the target mod and used by FNF's Game Over
 * screen (see golden.GoldenGameOver). Custom music goes in the mod's music folder (Import music...).
 */
class GameOverEditorState extends GoldenEditorState
{
  var cfg:Dynamic;
  var current:String = 'default';
  var browser:Browser;
  var inspector:Inspector;
  var inspectorDirty:Bool = true;
  var preview:FlxSpriteGroup;
  var previewChar:Null<BaseCharacter> = null;
  var music:Null<FunkinSound> = null;
  var assignSong:String = 'bopeebo';
  var assignSetup:String = 'default';

  public function new()
    super('Game Over Editor');

  override function buildEditor():Void
  {
    preview = new FlxSpriteGroup();
    add(preview);
    var path = EditorFiles.modPath('data/golden/gameover.json');
    cfg = path != null && EditorFiles.exists(path) ? EditorFiles.loadJson(path) : null;
    if (cfg == null) cfg = golden.GoldenGameOver.defaultConfig();
    if (cfg.setups == null) cfg.setups = {};
    if (cfg.songs == null) cfg.songs = {};
    browser = ui(new Browser(0, GoldenEditorState.TOP, leftW, FlxG.height - GoldenEditorState.TOP - GoldenEditorState.BOTTOM));
    browser.onSelect = it ->
    {
      current = it.data.name;
      inspectorDirty = true;
      refreshPreview();
      trace('[GOLDEN EDITOR] Game Over Editor: setup "$current" selected');
    };
    inspector = ui(new Inspector(FlxG.width - rightW, GoldenEditorState.TOP, rightW, FlxG.height - GoldenEditorState.TOP - GoldenEditorState.BOTTOM));
    addTool('New Setup', newSetup, 'Add another Game Over setup');
    addTool('Play Death', () -> playPreview(false), 'Preview the death animation and music');
    addTool('Retry', () -> playPreview(true), 'Preview the retry (confirm) animation and end music');
    camWorld.zoom = 0.6;
    centerWorkspaceOn(FlxG.width / 2, FlxG.height / 2);
    rebuildBrowser();
    resetHistory();
    trace('[GOLDEN EDITOR] Game Over Editor: default setup loaded');
  }

  function setup():Dynamic
    return current == 'default' ? Reflect.field(cfg, 'default') : Reflect.field(cfg.setups, current);

  function setupNames():Array<String>
    return ['default'].concat(Reflect.fields(cfg.setups));

  function rebuildBrowser():Void
  {
    var items:Array<BrowserItem> = [];
    for (n in setupNames())
      items.push({folder: 'Setups', label: n == 'default' ? 'Default (all songs)' : n, data: {name: n}});
    for (song in Reflect.fields(cfg.songs))
      items.push({folder: 'Song assignments', label: '$song -> ${Reflect.field(cfg.songs, song)}', data: {name: Reflect.field(cfg.songs, song)}});
    browser.setItems(items);
  }

  function newSetup():Void
  {
    var n = 1;
    while (Reflect.field(cfg.setups, 'setup$n') != null)
      n++;
    var s = golden.GoldenGameOver.defaultSetup();
    Reflect.setField(cfg.setups, 'setup$n', s);
    current = 'setup$n';
    changed();
    rebuildBrowser();
    inspectorDirty = true;
    notify('Setup "setup$n" created. Turn on "Per-song setups" and assign it to songs.');
  }

  override function serialize():String
    return haxe.Json.stringify(cfg) + '\n#' + current;

  override function deserialize(s:String):Void
  {
    var i = s.lastIndexOf('\n#');
    cfg = haxe.Json.parse(s.substr(0, i));
    current = s.substr(i + 2);
    if (setup() == null) current = 'default';
    rebuildBrowser();
    inspectorDirty = true;
  }

  override function refreshPanels():Void
    inspectorDirty = true;

  override function save():Null<String>
  {
    var err = EditorFiles.saveJson(EditorFiles.modPath('data/golden/gameover.json'), cfg);
    if (err == null) EditorFiles.reloadGameContent();
    return err;
  }

  override function rebuildPreview():Void
  {
    if (preview == null) return;
    var s:Dynamic = setup();
    if (s == null) return;
    preview.forEach(x -> if (x != previewChar) x.destroy());
    preview.clear();
    var bg = EditorUI.rect(-200, -200, FlxG.width + 400, FlxG.height + 400, FlxColor.fromString(s.background ?? '#000000') ?? FlxColor.BLACK);
    preview.add(bg);
    var img:String = s.backgroundImage ?? '';
    if (img != '' && Assets.exists(Paths.image(img)))
    {
      var spr = new FlxSprite().loadGraphic(Paths.image(img));
      spr.setGraphicSize(FlxG.width, FlxG.height);
      spr.updateHitbox();
      spr.alpha = s.backgroundAlpha ?? 1;
      preview.add(spr);
    }
    var charId:String = (s.character ?? '') == '' ? 'bf' : s.character;
    if (previewChar == null || previewChar.characterId != charId)
    {
      if (previewChar != null) previewChar.destroy();
      previewChar = CharacterDataParser.fetchCharacter(charId);
      if (previewChar == null) notify('Character "$charId" not found.', 0xFFFF5C5C);
    }
    if (previewChar != null)
    {
      previewChar.x = FlxG.width / 2 - previewChar.width / 2;
      previewChar.y = FlxG.height - previewChar.height - 60;
      preview.add(previewChar);
      if (previewChar.hasAnimation('deathLoop')) previewChar.playAnimation('deathLoop', true);
    }
    var text:String = s.text ?? '';
    if (text != '')
    {
      var t = new FlxText(0, FlxG.height - 140, FlxG.width, text, 40);
      t.setFormat(Paths.font('vcr.ttf'), 40, FlxColor.fromString(s.textColor ?? '#FFFFFF') ?? FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
      preview.add(t);
    }
    var z:Float = s.cameraZoom ?? 1;
    camWorld.zoom = 0.6 * (z > 0 ? z : 1);
  }

  function playPreview(retry:Bool):Void
  {
    var s:Dynamic = setup();
    if (previewChar != null)
    {
      var a = retry ? 'deathConfirm' : 'firstDeath';
      if (previewChar.hasAnimation(a)) previewChar.playAnimation(a, true);
      else
        notify('"${previewChar.characterId}" has no "$a" animation.', 0xFFFFB347);
    }
    music?.stop();
    var key:String = retry ? (s.musicEnd ?? '') : (s.music ?? '');
    var path = key != '' ? Paths.music(key) : Paths.music(retry ? 'gameplay/gameover/gameOverEnd' : 'gameplay/gameover/gameOver');
    if (!Assets.exists(path))
    {
      notify('Music not found: $path', 0xFFFF5C5C);
      return;
    }
    music = FunkinSound.load(path, 0.8, !retry, false, false, false, null, null, true);
    music?.play();
    trace('[GOLDEN EDITOR] Game Over preview: ${retry ? "retry" : "death"} ($path)');
  }

  function importMusic():Void
  {
    #if sys
    var s:Dynamic = setup();
    FileUtil.browseForFile('Game Over music (.ogg)', [FileUtil.FILE_FILTER_OGG], file ->
    {
      var name = EditorFiles.safeId(haxe.io.Path.withoutExtension(haxe.io.Path.withoutDirectory(file.fullPath)));
      var dest = EditorFiles.modPath('music/$name.ogg');
      var err = EditorFiles.saveBytes(dest, sys.io.File.getBytes(file.fullPath));
      if (err != null)
      {
        notify(err, 0xFFFF5C5C);
        return;
      }
      s.music = name;
      changed();
      inspectorDirty = true;
      notify('Music imported as music/$name.ogg (reload happens on Save).');
    }, () -> {});
    #end
  }

  function rebuildInspector():Void
  {
    inspectorDirty = false;
    inspector.clearRows();
    var s:Dynamic = setup();
    if (s == null) return;
    inspector.addHeader('Setup: $current');
    if (current != 'default')
    {
      inspector.addText('Setup name', () -> current, v ->
      {
        var n = EditorFiles.safeId(v);
        if (n == current || n == 'default' || Reflect.field(cfg.setups, n) != null) return;
        Reflect.setField(cfg.setups, n, s);
        Reflect.deleteField(cfg.setups, current);
        for (song in Reflect.fields(cfg.songs))
          if (Reflect.field(cfg.songs, song) == current) Reflect.setField(cfg.songs, song, n);
        current = n;
        changed();
        rebuildBrowser();
        inspectorDirty = true;
      });
    }
    function asset(label:String, field:String, note:String)
    {
      inspector.addText(label, () -> Std.string(Reflect.field(s, field) ?? ''), v ->
      {
        Reflect.setField(s, field, v.trim());
        changed();
      });
      inspector.addButtons([{caption: 'Remove $label', fn: () ->
        {
          Reflect.setField(s, field, field == 'background' ? '#000000' : '');
          changed();
          inspector.refresh();
          notify('$label removed (FNF default used).');
        }, tooltip: note}]);
    }
    asset('Character', 'character', 'Empty = the player character');
    asset('Music', 'music', 'music/<key>.ogg; empty = FNF game over music');
    inspector.addButtons([{caption: 'Import music...', fn: importMusic}]);
    asset('Retry music', 'musicEnd', 'Played when retrying');
    asset('Death sound', 'sound', 'sounds/<key>.ogg; empty = FNF sound');
    asset('Background', 'background', 'Colour #RRGGBB');
    asset('Background image', 'backgroundImage', 'images/<key>.png');
    inspector.addNumber('Image opacity', () -> s.backgroundAlpha ?? 1, v ->
    {
      s.backgroundAlpha = v;
      changed();
    }, 0.05, 0, 1);
    inspector.addNumber('Camera zoom', () -> s.cameraZoom ?? 1, v ->
    {
      s.cameraZoom = v;
      changed();
    }, 0.05, 0.2, 4);
    asset('Text', 'text', 'Shown at the bottom');
    inspector.addText('Text colour', () -> s.textColor ?? '#FFFFFF', v ->
    {
      s.textColor = v;
      changed();
    });
    if (current != 'default') inspector.addButtons([{caption: 'Delete setup', fn: () -> openSubState(new golden.ui.GoldenDialogs.GoldenConfirmSubState('Delete setup "$current"?', () ->
      {
        Reflect.deleteField(cfg.setups, current);
        for (song in Reflect.fields(cfg.songs))
          if (Reflect.field(cfg.songs, song) == current) Reflect.deleteField(cfg.songs, song);
        current = 'default';
        changed();
        rebuildBrowser();
        inspectorDirty = true;
      }))}]);
    inspector.addHeader('Songs');
    inspector.addToggle('Per-song setups', () -> cfg.perSong == true, v ->
    {
      cfg.perSong = v;
      changed();
    });
    inspector.addNote(cfg.perSong == true ? 'Songs listed below use their setup; others use Default.' : 'Off: every song uses Default.');
    inspector.addChoice('Song', () -> SongRegistry.instance.listEntryIds(), () -> assignSong, v -> assignSong = v);
    inspector.addChoice('Setup', setupNames, () -> assignSetup, v -> assignSetup = v);
    inspector.addButtons([{caption: 'Assign', fn: () ->
      {
        Reflect.setField(cfg.songs, assignSong, assignSetup);
        changed();
        rebuildBrowser();
        notify('$assignSong uses "$assignSetup".');
        trace('[GOLDEN EDITOR] Game Over Editor: $assignSong -> $assignSetup');
      }}, {caption: 'Unassign', fn: () ->
      {
        Reflect.deleteField(cfg.songs, assignSong);
        changed();
        rebuildBrowser();
      }}]);
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

  override function destroy():Void
  {
    music?.stop();
    super.destroy();
  }
}
