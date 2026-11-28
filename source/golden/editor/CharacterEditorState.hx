package golden.editor;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.play.character.BaseCharacter;
import golden.editor.EditorUI;

using StringTools;

/**
 * Golden Engine — Character Editor. Opens any character the game knows (base game, mods, Animation
 * Studio exports) and edits its FNF character JSON without hand-editing: animations (prefix, frame rate,
 * loop, per-animation offsets with arrow keys), position offsets, camera offsets, scale, flip, sing time,
 * health icon, pixel mode, and a health bar colour (Golden: data/golden/healthcolors.json, applied by
 * PlayState). The preview is the real game character with the edits applied live; Save writes a copy
 * into the target mod (data/characters/<id>.json), so the original stays untouched.
 */
class CharacterEditorState extends GoldenEditorState
{
  static var colorCache:Null<Dynamic> = null;

  /** Health bar colour for a character (or the default). */
  public static function healthColor(charId:Null<String>, def:FlxColor):FlxColor
  {
    if (charId == null) return def;
    if (colorCache == null)
    {
      colorCache = {};
      var p = Paths.json('golden/healthcolors');
      if (Assets.exists(p))
      {
        try
          colorCache = haxe.Json.parse(Assets.getText(p))
        catch (e:Dynamic)
          trace('[GOLDEN] Invalid $p: $e');
      }
    }
    var v:Dynamic = Reflect.field(colorCache, charId);
    if (v == null) return def;
    var c = FlxColor.fromString(Std.string(v));
    if (c != null) trace('[GOLDEN] Health colour for $charId: $v');
    return c ?? def;
  }

  public static function clearColors():Void
    colorCache = null;

  var charId:String = 'bf';
  var data:Dynamic;
  var healthCol:String = '';
  var char:Null<BaseCharacter> = null;
  var anim:String = 'idle';
  var browser:Browser;
  var inspector:Inspector;
  var inspectorDirty:Bool = true;
  var marker:FlxSprite;
  var ground:FlxSprite;

  public function new()
    super('Character Editor');

  override function buildEditor():Void
  {
    ground = EditorUI.rect(-1000, 0, 2000, 2, 0xFF6A5F80);
    add(ground);
    marker = EditorUI.rect(0, 0, 12, 12, 0xFFFF5C8A);
    marker.scrollFactor.set(1, 1);
    browser = ui(new Browser(0, GoldenEditorState.TOP, leftW, FlxG.height - GoldenEditorState.TOP - GoldenEditorState.BOTTOM));
    browser.onSelect = it ->
    {
      var d:Dynamic = it.data;
      if (d.kind == 'char') confirmDiscard(() -> loadChar(d.id));
      else
      {
        anim = d.name;
        playAnim();
        inspectorDirty = true;
      }
    };
    browser.collapse('Characters');
    inspector = ui(new Inspector(FlxG.width - rightW, GoldenEditorState.TOP, rightW, FlxG.height - GoldenEditorState.TOP - GoldenEditorState.BOTTOM));
    addTool('Play Anim (Space)', playAnim);
    addTool('Test Play', testPlay, 'Save, then play a song with this character as the player (F9 returns)');
    loadChar(keepId ?? 'bf');
    keepId = null;
  }

  static var keepId:Null<String> = null;

  function confirmDiscard(fn:Void->Void):Void
  {
    if (!dirty) fn();
    else
      openSubState(new golden.ui.GoldenDialogs.GoldenConfirmSubState('Discard unsaved changes to "$charId"?', fn));
  }

  function loadChar(id:String):Void
  {
    var path = Paths.json('characters/$id');
    try
    {
      data = haxe.Json.parse(Assets.getText(path));
    }
    catch (e:Dynamic)
    {
      notify('Could not read $path: $e', 0xFFFF5C5C);
      return;
    }
    charId = id;
    clearColors();
    var c:Dynamic = Reflect.field(colorCache ?? {}, id);
    healthColor(id, 0);
    c = Reflect.field(colorCache, id);
    healthCol = c != null ? Std.string(c) : '';
    if (data.offsets == null) data.offsets = [0, 0];
    if (data.cameraOffsets == null) data.cameraOffsets = [0, 0];
    if (data.scale == null) data.scale = 1;
    if (data.healthIcon == null) data.healthIcon = {id: id};
    var anims:Array<Dynamic> = data.animations ?? [];
    anim = anims.length > 0 ? anims[0].name : 'idle';
    if (char != null)
    {
      remove(char, true);
      char.destroy();
    }
    char = CharacterDataParser.fetchCharacter(id);
    if (char == null) notify('The game could not build "$id" (check its assets).', 0xFFFF5C5C);
    else
    {
      add(char);
      add(marker);
    }
    resetHistory();
    rebuildBrowser();
    inspectorDirty = true;
    refreshPreview();
    playAnim();
    trace('[GOLDEN EDITOR] Character Editor: opened "$id" (${anims.length} animations, ${data.renderType})');
  }

  function rebuildBrowser():Void
  {
    var items:Array<BrowserItem> = [];
    for (a in (data.animations : Array<Dynamic>))
      items.push({folder: 'Animations', label: a.name, data: {kind: 'anim', name: a.name}});
    for (id in CharacterDataParser.listCharacterIds())
      items.push({folder: 'Characters', label: id, data: {kind: 'char', id: id}});
    browser.setItems(items);
  }

  function animData():Null<Dynamic>
  {
    for (a in (data.animations : Array<Dynamic>))
      if (a.name == anim) return a;
    return null;
  }

  function playAnim():Void
  {
    if (char == null) return;
    if (char.hasAnimation(anim)) char.playAnimation(anim, true, true);
    else
      notify('Animation "$anim" has no frames (check its prefix).', 0xFFFFB347);
  }

  override function serialize():String
    return haxe.Json.stringify({d: data, c: healthCol, a: anim});

  override function deserialize(s:String):Void
  {
    var o:Dynamic = haxe.Json.parse(s);
    data = o.d;
    healthCol = o.c;
    anim = o.a;
    inspectorDirty = true;
  }

  override function refreshPanels():Void
    inspectorDirty = true;

  /** Apply the edited data to the live game character. */
  override function rebuildPreview():Void
  {
    if (char == null || data == null) return;
    char.setScale(data.scale);
    char.flipX = data.flipX == true;
    char.globalOffsets = [data.offsets[0], data.offsets[1]];
    for (a in (data.animations : Array<Dynamic>))
    {
      var o:Array<Dynamic> = a.offsets ?? [0, 0];
      char.setAnimationOffsets(a.name, o[0], o[1]);
    }
    char.resetPosition();
    char.x = -char.width / 2 + data.offsets[0];
    char.y = -char.height + data.offsets[1];
    if (char.hasAnimation(anim)) char.playAnimation(anim, false, true);
    var cam = char.cameraFocusPoint;
    marker.setPosition(char.x + char.width / 2 + data.cameraOffsets[0] - 6, char.y + char.height / 2 + data.cameraOffsets[1] - 6);
    camWorld.zoom = Math.min(1, 380 / Math.max(1, char.height));
    centerWorkspaceOn(0, -char.height / 2);
  }

  override function save():Null<String>
  {
    var mod = EditorFiles.target();
    var err = EditorFiles.saveJson(EditorFiles.modPath('data/characters/$charId.json', mod), data);
    if (err != null) return err;
    var cp = EditorFiles.modPath('data/golden/healthcolors.json', mod);
    var colors:Dynamic = EditorFiles.exists(cp) ? (EditorFiles.loadJson(cp) ?? {}) : {};
    if (healthCol == '') Reflect.deleteField(colors, charId) else Reflect.setField(colors, charId, healthCol);
    err = EditorFiles.saveJson(cp, colors);
    if (err != null) return err;
    clearColors();
    EditorFiles.reloadGameContent();
    return null;
  }

  function testPlay():Void
  {
    if (dirty) doSave();
    keepId = charId;
    golden.GoldenPlayOverrides.player = charId;
    golden.studio.GoldenStudio.editorReturn = () -> FlxG.switchState(() -> new CharacterEditorState());
    var err = golden.studio.GoldenStudio.playSong('bopeebo', 'normal');
    if (err != null)
    {
      golden.GoldenPlayOverrides.clear();
      notify(err, 0xFFFF5C5C);
    }
    else
      leaving = true;
  }

  function rebuildInspector():Void
  {
    inspectorDirty = false;
    inspector.clearRows();
    inspector.addHeader('Character: $charId');
    inspector.addNote('Render type: ${data.renderType}, asset: ${data.assetPath}');
    inspector.addText('Name', () -> data.name ?? '', v -> edit(() -> data.name = v));
    inspector.addNumber('Scale', () -> data.scale, v -> edit(() -> data.scale = v), 0.05, 0.05, 20);
    inspector.addToggle('Flip X', () -> data.flipX == true, v -> edit(() -> data.flipX = v));
    inspector.addNumber('Offset X', () -> data.offsets[0], v -> edit(() -> data.offsets[0] = v), 5);
    inspector.addNumber('Offset Y', () -> data.offsets[1], v -> edit(() -> data.offsets[1] = v), 5);
    inspector.addNumber('Camera X', () -> data.cameraOffsets[0], v -> edit(() -> data.cameraOffsets[0] = v), 10);
    inspector.addNumber('Camera Y', () -> data.cameraOffsets[1], v -> edit(() -> data.cameraOffsets[1] = v), 10);
    inspector.addNumber('Sing time', () -> data.singTime ?? 8, v -> edit(() -> data.singTime = v), 1, 1, 64);
    inspector.addToggle('Pixel', () -> data.isPixel == true, v -> edit(() -> data.isPixel = v));
    inspector.addText('Health icon', () -> data.healthIcon?.id ?? charId, v -> edit(() -> data.healthIcon = {id: v}));
    inspector.addText('Health colour', () -> healthCol, v -> edit(() -> healthCol = v.trim()));
    inspector.addNote('Health colour: #RRGGBB for this character\'s side of the health bar (empty = FNF colours).');
    var a = animData();
    if (a != null)
    {
      if (a.offsets == null) a.offsets = [0, 0];
      inspector.addHeader('Animation: ${a.name}');
      inspector.addText('Prefix', () -> a.prefix ?? '', v -> edit(() -> a.prefix = v));
      inspector.addNumber('Frame rate', () -> a.frameRate ?? 24, v -> edit(() -> a.frameRate = Std.int(v)), 1, 1, 120);
      inspector.addToggle('Looped', () -> a.looped == true, v -> edit(() -> a.looped = v));
      inspector.addNumber('Anim offset X', () -> a.offsets[0], v -> edit(() -> a.offsets[0] = v), 1);
      inspector.addNumber('Anim offset Y', () -> a.offsets[1], v -> edit(() -> a.offsets[1] = v), 1);
      inspector.addNote('Arrow keys nudge the animation offset (Shift = 10).');
    }
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

  override function editorKeys():Void
  {
    if (FlxG.keys.justPressed.SPACE) playAnim();
    var a = animData();
    if (a == null) return;
    var step = FlxG.keys.pressed.SHIFT ? 10 : 1;
    var dx = (FlxG.keys.justPressed.LEFT ? 1 : 0) - (FlxG.keys.justPressed.RIGHT ? 1 : 0);
    var dy = (FlxG.keys.justPressed.UP ? 1 : 0) - (FlxG.keys.justPressed.DOWN ? 1 : 0);
    if (dx != 0 || dy != 0)
    {
      if (a.offsets == null) a.offsets = [0, 0];
      a.offsets[0] += dx * step;
      a.offsets[1] += dy * step;
      changed();
      trace('[GOLDEN EDITOR] Character Editor: ${a.name} offset ${a.offsets[0]}, ${a.offsets[1]}');
    }
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (inspectorDirty) rebuildInspector();
  }
}
