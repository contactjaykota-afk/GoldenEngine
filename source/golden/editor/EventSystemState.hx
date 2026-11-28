package golden.editor;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import haxe.DynamicAccess;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import funkin.audio.FunkinSound;
import funkin.data.event.SongEventRegistry;
import funkin.data.song.SongRegistry;
import funkin.play.character.BaseCharacter;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.play.stage.Stage;
import funkin.data.stage.StageRegistry;
import golden.audio.UISound;
import golden.editor.EditorUI;
import golden.events.FxModel;
import golden.events.FxRuntime;

using StringTools;

/** FxHost for the Event System preview (the real stage + characters, scaled into the preview area). */
class PreviewFxHost implements FxHost
{
  var s:EventSystemState;

  public function new(s:EventSystemState)
    this.s = s;

  public function gameCam():FlxCamera
    return s.camWorld;

  public function hudCam():FlxCamera
    return s.camPreviewHUD;

  public function topCam():FlxCamera
    return s.camPreviewTop;

  public function addBehindCharacters(sp:FlxSprite):Void
  {
    if (s.stage != null)
    {
      sp.zIndex = 0;
      s.stage.add(sp);
      s.stage.refresh();
    }
    else
      s.add(sp);
  }

  public function addSprite(b:FlxBasic):Void
    s.add(b);

  public function removeSprite(b:FlxBasic):Void
  {
    if (s.stage != null && s.stage.members != null && s.stage.members.contains(cast b)) s.stage.remove(cast b, true);
    else
      s.remove(b, true);
  }

  public function character(target:String):Null<FlxSprite>
    return s.characterFor(target);

  public function playerStrums():Null<FlxSpriteGroup>
    return s.prevPlayerStrums;

  public function opponentStrums():Null<FlxSpriteGroup>
    return s.prevOpponentStrums;

  public function runNative(kind:String, value:Dynamic, time:Float):Void
    s.previewNative(kind, value);

  public function stepMs():Float
    return s.stepMs();
}

/**
 * Golden Engine — Event System (formerly Camera Editor): visual song editing.
 *
 * Pick a song: its chart (notes, sustains, FNF events), characters and stage load into a timeline.
 * Original tracks (notes, chart events) start LOCKED; unlock a track to edit it. Visual effects
 * (camera, zoom, shake, flashes, colour grading, overlays, text, jumpscares, note layout, sounds, Lua
 * calls) are added from the browser (click = at the playhead, or drag onto the timeline).
 *
 * Saving is non-destructive: effects go to `mods/<mod>/data/golden/events/<song>.json`; note/event
 * edits go to a copy of the chart in the mod (`data/songs/<song>/<song>-chart.json`), which the game
 * loads instead of the original. "Reset to Original" deletes those mod files. Gameplay plays the
 * effects through golden.events.GoldenFxModule and the chart through FNF itself.
 */
class EventSystemState extends GoldenEditorState
{
  static inline var TL_H:Int = 226;
  static inline var NAME_W:Int = 150;
  static inline var ROW:Int = 13;
  static inline var HEAD:Int = 28;
  static inline var RULER:Int = 16;

  /** Kept while the bot preview runs, so the editor comes back as it was. */
  static var keep:Null<{song:String, diff:String, playhead:Float, pps:Float, scroll:Float}> = null;

  public var songId:String = 'bopeebo';
  public var difficulty:String = 'normal';
  public var fx:FxProject;
  /** Raw chart JSON (all difficulties), edited in place for notes/events. */
  var chart:Dynamic = null;
  var chartDirty:Bool = false;
  var bpm:Float = 100;
  var songLength:Float = 60000;

  public var playhead:Float = 0;
  var playing:Bool = false;
  var music:Null<FunkinSound> = null;
  var pps:Float = 80; // timeline pixels per second
  var scrollMs:Float = 0;
  var snap:String = 'beat';

  public var camPreviewHUD:FlxCamera;
  public var camPreviewTop:FlxCamera;
  public var stage:Null<Stage> = null;
  var chars:Map<String, BaseCharacter> = [];
  public var prevPlayerStrums:Null<FlxSpriteGroup> = null;
  public var prevOpponentStrums:Null<FlxSpriteGroup> = null;
  var runtime:FxRuntime;
  var host:PreviewFxHost;
  var lastBeat:Int = -1;
  var nextNote:Int = 0;

  var browser:Browser;
  var inspector:Inspector;
  var tlGrid:FlxSprite;
  var tlBmp:BitmapData;
  var tlNames:Array<FlxText> = [];
  var tlRuler:Array<FlxText> = [];
  var tlInfo:FlxText;
  var tlDirty:Bool = true;
  var rowScroll:Int = 0;
  var inspectorDirty:Bool = true;

  // selection
  var selFx:Null<Fx> = null;
  var selNotes:Array<Dynamic> = [];
  var selEvent:Null<Dynamic> = null;
  var drag:Null<{kind:String, startMs:Float, mx:Float, orig:Array<Float>, origDur:Float}> = null;
  var previewTop:Int = GoldenEditorState.TOP;
  var previewH:Int = 0;

  /** Cutscene Editor mode: same timeline, saved to data/golden/cutscenes/<song>.json, own clock. */
  public var cutsceneMode(default, null):Bool = false;
  var cutLength:Float = 6000;
  var cutBefore:Bool = true;
  var clock:Float = 0;

  public function new(cutscene:Bool = false)
  {
    super(cutscene ? 'Cutscene Editor' : 'Event System');
    cutsceneMode = cutscene;
    leftW = 270;
    rightW = 330;
  }

  // ---- layout ------------------------------------------------------------------------------------

  function tlTop():Int
    return FlxG.height - GoldenEditorState.BOTTOM - TL_H;

  function rowsList():Array<String>
  {
    var r = cutsceneMode ? [] : ['Player notes', 'Opponent notes', 'Chart events'];
    for (t in fx.tracks)
      if (!t.hidden) r.push(t.name);
    return r;
  }

  function trackInfo(name:String):FxTrack
  {
    var t = fx.tracks.find(x -> x.name == name);
    if (t == null)
    {
      t = {name: name, locked: name == 'Player notes' || name == 'Opponent notes' || name == 'Chart events', hidden: false};
      fx.tracks.push(t);
    }
    return t;
  }

  override function buildEditor():Void
  {
    if (keep != null)
    {
      songId = keep.song;
      difficulty = keep.diff;
      pps = keep.pps;
      scrollMs = keep.scroll;
    }
    var aw = FlxG.width - leftW - rightW;
    var ah = tlTop() - GoldenEditorState.TOP;
    var z = aw / FlxG.width;
    previewH = Std.int(FlxG.height * z);
    previewTop = GoldenEditorState.TOP + Std.int((ah - previewH) / 2);
    // The world camera shows the stage scaled into the preview area; HUD/top cameras too.
    // (Flixel camera width/height are screen pixels; zoom scales the world into them.)
    camWorld.setPosition(leftW, previewTop);
    camWorld.setSize(aw, previewH);
    camWorld.zoom = z;
    camWorld.bgColor = 0xFF000000;
    camPreviewHUD = new FlxCamera(leftW, previewTop, aw, previewH, z);
    camPreviewHUD.bgColor = 0;
    camPreviewTop = new FlxCamera(leftW, previewTop, aw, previewH, z);
    camPreviewTop.bgColor = 0;
    // Insert below the UI camera.
    FlxG.cameras.remove(camUI, false);
    FlxG.cameras.add(camPreviewHUD, false);
    FlxG.cameras.add(camPreviewTop, false);
    FlxG.cameras.add(camUI, false);

    addTool('Play', togglePlay, 'Play / pause the song in the preview (Space)');
    addTool('Stop', stopPlayback, 'Stop and go back to the start of the playback');
    addTool('Bot Preview', botPreview, 'Save, then play the real song with a bot from the playhead (F9 returns)');
    addTool('Validate', validate, 'Check missing images/sounds and conflicting effects');
    addTool('Reset to Original', resetOriginal, 'Delete this song\'s edits from the mod (asks first)');

    browser = ui(new Browser(0, GoldenEditorState.TOP, leftW, tlTop() - GoldenEditorState.TOP, 0));
    browser.onSelect = it -> addFromBrowser(it, playhead, null);
    browser.onDragOut = onBrowserDrop;
    browser.collapse('Color grades');
    browser.collapse('Text styles');
    inspector = ui(new Inspector(FlxG.width - rightW, GoldenEditorState.TOP, rightW, tlTop() - GoldenEditorState.TOP));

    // timeline
    var top = tlTop();
    ui(EditorUI.rect(0, top, FlxG.width, TL_H, EditorUI.PANEL));
    ui(EditorUI.rect(0, top, FlxG.width, 1, EditorUI.ACCENT));
    var bx = 6.0;
    var buttons:Array<{c:String, f:Void->Void, t:String}> = [
      {c: '|<', f: () -> setPlayhead(0), t: 'Start'}, {c: '<', f: () -> setPlayhead(playhead - stepMs()), t: 'One step back (Left)'},
      {c: '>', f: () -> setPlayhead(playhead + stepMs()), t: 'One step forward (Right)'}, {c: 'Zoom -', f: () -> zoomTimeline(1 / 1.4), t: 'Timeline zoom out'},
      {c: 'Zoom +', f: () -> zoomTimeline(1.4), t: 'Timeline zoom in'}, {c: 'Snap', f: cycleSnap, t: 'Snap: beat / step / off'},
      {c: 'Dup', f: duplicateSelection, t: 'Duplicate selection (Ctrl+D)'}, {c: 'Del', f: deleteSelection, t: 'Delete selection (Delete)'},
      {c: '+Event', f: addChartEvent, t: 'Add an FNF chart event at the playhead (Chart events track must be unlocked)'}
    ];
    for (b in buttons)
    {
      var w = b.c.length * 9 + 16;
      ui(new EButton(bx, top + 4, w, 20, b.c, b.f, b.t));
      bx += w + 3;
    }
    tlInfo = ui(EditorUI.text(bx + 8, top + 7, FlxG.width - bx - 16, '', 12, EditorUI.MUTED));
    tlBmp = new BitmapData(FlxG.width, TL_H - HEAD, true, 0);
    tlGrid = ui(new FlxSprite(0, top + HEAD).loadGraphic(tlBmp));
    for (i in 0...16)
    {
      var t = ui(EditorUI.text(22, top + HEAD + RULER + i * ROW - 1, NAME_W - 26, '', 10, EditorUI.TEXT));
      tlNames.push(t);
    }
    for (i in 0...30)
      tlRuler.push(ui(EditorUI.text(0, top + HEAD + 1, 60, '', 9, EditorUI.MUTED)));

    host = new PreviewFxHost(this);
    loadSong(songId, difficulty);
    if (keep != null)
    {
      setPlayhead(keep.playhead);
      keep = null;
      trace('[GOLDEN EDITOR] Event System restored after the bot preview');
    }
    golden.GoldenPlayOverrides.clear();
  }

  override public function mouseInWorkspace():Bool
    return false; // the preview is fixed (no pan/zoom); the timeline has its own zoom

  // ---- song loading ------------------------------------------------------------------------------

  public function stepMs():Float
    return 60000 / Math.max(1, bpm) / 4;

  function beatMs():Float
    return 60000 / Math.max(1, bpm);

  function chartPath(id:String):String
    return Paths.json('songs/$id/$id-chart');

  function loadSong(id:String, diff:String):Void
  {
    stopPlayback();
    var song = SongRegistry.instance.fetchEntry(id);
    if (song == null)
    {
      notify('Song "$id" not found.', 0xFFFF5C5C);
      return;
    }
    songId = id;
    var diffs = song.listDifficulties(Constants.DEFAULT_VARIATION, null, true, true);
    if (!diffs.contains(diff)) diff = diffs.contains('normal') ? 'normal' : diffs[0];
    difficulty = diff;
    var d = song.getDifficulty(diff, Constants.DEFAULT_VARIATION);
    bpm = (d != null && d.timeChanges != null && d.timeChanges.length > 0) ? d.timeChanges[0].bpm : 100;
    // raw chart (all difficulties) so other fields are preserved exactly
    chart = null;
    try
    {
      chart = haxe.Json.parse(Assets.getText(chartPath(id)));
    }
    catch (e:Dynamic)
    {
      notify('Could not read the chart of "$id": $e', 0xFFFF5C5C);
    }
    if (chart != null && Reflect.field(chart.notes, diff) == null) Reflect.setField(chart.notes, diff, []);
    chartDirty = false;
    // effects
    var p:Null<FxProject> = null;
    if (cutsceneMode)
    {
      var cp = Paths.json('golden/cutscenes/$id');
      if (Assets.exists(cp))
      {
        try
        {
          var raw:Dynamic = haxe.Json.parse(Assets.getText(cp));
          p = FxModel.fromJson(Assets.getText(cp));
          cutLength = raw.length ?? 6000;
          cutBefore = raw.beforeSong != false;
        }
        catch (e:Dynamic)
          notify('Invalid cutscene file: $e', 0xFFFF5C5C);
      }
      else
      {
        cutLength = 6000;
        cutBefore = true;
      }
    }
    else
      p = golden.events.GoldenFxModule.loadProject(id);
    fx = p ?? FxModel.emptyProject(id);
    for (n in ['Player notes', 'Opponent notes', 'Chart events'])
    {
      var t = trackInfo(n);
      if (p == null) t.locked = true;
    }
    songLength = 0;
    for (n in notes())
      songLength = Math.max(songLength, n.t + (n.l ?? 0));
    songLength = cutsceneMode ? cutLength : Math.max(songLength + 4000, 30000);
    buildPreview(d?.characters?.player ?? 'bf', d?.characters?.opponent ?? 'dad', d?.characters?.girlfriend ?? 'gf', d?.stage ?? 'mainStage');
    if (runtime != null) runtime.reset();
    runtime = new FxRuntime(fx, host);
    playhead = 0;
    selFx = null;
    selNotes = [];
    selEvent = null;
    resetHistory();
    rebuildBrowser();
    inspectorDirty = tlDirty = true;
    trace('[GOLDEN EDITOR] Event System: loaded "$id" ($diff): ${notes().length} notes, ${events().length} chart events, ${fx.effects.length} effects, ${Math.round(bpm)} BPM');
  }

  function notes():Array<Dynamic>
    return chart != null ? (Reflect.field(chart.notes, difficulty) : Array<Dynamic>) ?? [] : [];

  function events():Array<Dynamic>
    return chart != null && chart.events != null ? chart.events : [];

  function buildPreview(player:String, opponent:String, gf:String, stageId:String):Void
  {
    releaseStage();
    chars = [];
    try
    {
      stage = StageRegistry.instance.fetchEntry(stageId);
      if (stage != null)
      {
        stage.revive();
        // Build the props exactly like PlayState does.
        funkin.modding.events.ScriptEventDispatcher.callEvent(stage, new funkin.modding.events.ScriptEvent(CREATE, false));
        add(stage);
        for (pair in [[player, 'bf'], [opponent, 'dad'], [gf, 'gf']])
        {
          if (pair[0] == null || pair[0] == '') continue;
          var c = CharacterDataParser.fetchCharacter(pair[0]);
          if (c == null) continue;
          stage.addCharacter(c, pair[1] == 'bf' ? BF : (pair[1] == 'dad' ? DAD : GF));
          chars.set(pair[1], c);
        }
        stage.refresh();
        var bfp = stage.getBoyfriend();
        var dad = stage.getDad();
        if (bfp != null && dad != null)
          camWorld.focusOn(new flixel.math.FlxPoint((bfp.cameraFocusPoint.x + dad.cameraFocusPoint.x) / 2, (bfp.cameraFocusPoint.y + dad.cameraFocusPoint.y) / 2));
        camWorld.zoom = (FlxG.width - leftW - rightW) / FlxG.width * stage.camZoom;
      }
    }
    catch (e:Dynamic)
    {
      notify('Stage preview failed ($e); effects still preview on the cameras.', 0xFFFFB347);
      trace('[GOLDEN EDITOR] Event System preview: $e');
    }
    // strum receptors (static) so the note-layout effect can be previewed
    if (prevPlayerStrums == null)
    {
      prevPlayerStrums = makeStrums(FlxG.width / 2 + 50);
      prevOpponentStrums = makeStrums(50);
    }
  }

  /** Return the stage to FNF's cache the way PlayState does (DESTROY event = kill + clean up), never destroy it. */
  function releaseStage():Void
  {
    if (stage == null) return;
    remove(stage, true);
    try
    {
      funkin.modding.events.ScriptEventDispatcher.callEvent(stage, new funkin.modding.events.ScriptEvent(DESTROY, false));
    }
    catch (e:Dynamic)
    {
      trace('[GOLDEN EDITOR] Stage release: $e');
    }
    stage = null;
    chars = [];
  }

  function makeStrums(x:Float):FlxSpriteGroup
  {
    var g = new FlxSpriteGroup(x, 48);
    var cols = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
    for (i in 0...4)
    {
      var s = new FlxSprite(i * 112, 0).makeGraphic(96, 96, FlxColor.WHITE);
      s.color = cols[i];
      s.alpha = 0.55;
      g.add(s);
    }
    g.scrollFactor.set();
    g.cameras = [camPreviewHUD];
    add(g);
    return g;
  }

  public function characterFor(target:String):Null<FlxSprite>
  {
    return switch (target)
    {
      case 'player' | 'boyfriend': chars.get('bf');
      case 'opponent' | 'dad': chars.get('dad');
      case 'girlfriend': chars.get('gf');
      default: null;
    };
  }

  /** Editor version of FNF's events (the game runs the real ones). */
  public function previewNative(kind:String, v:Dynamic):Void
  {
    switch (kind)
    {
      case 'FocusCamera':
        var c:Null<BaseCharacter> = switch (Std.int(v.char)) { case 0: chars.get('bf'); case 1: chars.get('dad'); case 2: chars.get('gf'); default: null; };
        var tx:Float = c != null ? c.cameraFocusPoint.x + v.x : v.x;
        var ty:Float = c != null ? c.cameraFocusPoint.y + v.y : v.y;
        var dur = Math.max(0.01, (v.duration ?? 4) * stepMs() / 1000);
        FlxTween.tween(camWorld.scroll, {x: tx - camWorld.width / 2, y: ty - camWorld.height / 2}, dur, {ease: FlxEase.quadOut});
      case 'ZoomCamera':
        var base = (FlxG.width - leftW - rightW) / FlxG.width;
        FlxTween.tween(camWorld, {zoom: base * (v.zoom ?? 1)}, Math.max(0.01, (v.duration ?? 4) * stepMs() / 1000), {ease: FlxEase.quadOut});
      case 'PlayAnimation':
        var c:Null<BaseCharacter> = cast characterFor(v.target);
        if (c != null) c.playAnimation(v.anim, v.force == true);
      default:
        trace('[GOLDEN EDITOR] Preview: $kind runs in gameplay (${haxe.Json.stringify(v)})');
    }
  }

  // ---- browser -----------------------------------------------------------------------------------

  function rebuildBrowser():Void
  {
    var items:Array<BrowserItem> = [];
    for (t in FxModel.CATALOG)
      items.push({folder: 'Effects/' + t.category, label: t.title, data: {kind: 'fx', type: t.type}});
    for (pr in FxModel.PRESETS)
      items.push({folder: 'Presets', label: pr, data: {kind: 'preset', name: pr}});
    for (g in FxModel.GRADES.keys())
      items.push({folder: 'Color grades', label: g, data: {kind: 'grade', name: g}});
    for (t in FxModel.TEXT_STYLES.keys())
      items.push({folder: 'Text styles', label: t, data: {kind: 'textstyle', name: t}});
    var mod = EditorFiles.target();
    if (mod != null)
    {
      for (f in EditorFiles.listFiles(EditorFiles.modPath('scripts/events', mod), ['lua']))
        items.push({folder: 'Scripts', label: f, data: {kind: 'script', file: f}});
      for (f in EditorFiles.listFiles(EditorFiles.modPath('scripts', mod), ['hxc']))
        items.push({folder: 'Scripts', label: 'Haxe: ' + f, data: {kind: 'haxe', file: f}});
    }
    items.push({folder: 'Scripts', label: 'New Lua event script...', data: {kind: 'newlua'}});
    items.push({folder: 'Scripts', label: 'Open Script Editor', data: {kind: 'scripteditor'}});
    browser.setItems(items);
  }

  function snapTime(ms:Float):Float
  {
    var s = snap == 'beat' ? beatMs() : (snap == 'step' ? stepMs() : 0);
    return s <= 0 ? Math.max(0, ms) : Math.max(0, Math.round(ms / s) * s);
  }

  function onBrowserDrop(it:BrowserItem):Void
  {
    var p = FlxG.mouse.getViewPosition(camUI);
    var top = tlTop() + HEAD + RULER;
    if (p.y >= top && p.y < tlTop() + TL_H && p.x > NAME_W)
    {
      var t = snapTime(xToMs(p.x));
      var row = rowAt(p.y);
      addFromBrowser(it, t, row);
    }
    p.put();
  }

  function addFromBrowser(it:BrowserItem, at:Float, ?row:String):Void
  {
    var d:Dynamic = it.data;
    var added:Array<Fx> = [];
    switch (d.kind)
    {
      case 'fx':
        var f = FxModel.create(d.type, at);
        if (f != null) added.push(f);
      case 'preset':
        added = FxModel.preset(d.name, at);
      case 'grade':
        var f = FxModel.create('color', at);
        var g:Dynamic = FxModel.GRADES.get(d.name);
        for (k in Reflect.fields(g))
          Reflect.setField(f.params, k, Reflect.field(g, k));
        f.label = d.name;
        added.push(f);
      case 'textstyle':
        var f = FxModel.create('text', at);
        var g:Dynamic = FxModel.TEXT_STYLES.get(d.name);
        for (k in Reflect.fields(g))
          Reflect.setField(f.params, k, Reflect.field(g, k));
        f.label = d.name;
        added.push(f);
      case 'script':
        var f = FxModel.create('lua', at);
        Reflect.setField(f.params, 'script', haxe.io.Path.withoutExtension(d.file));
        added.push(f);
      case 'haxe':
        openScriptEditor();
        return;
      case 'newlua':
        newLuaScript();
        return;
      case 'scripteditor':
        openScriptEditor();
        return;
    }
    if (added.length == 0) return;
    for (f in added)
    {
      if (trackInfo(f.track).locked)
      {
        notify('Track "${f.track}" is locked: unlock it first.', 0xFFFFB347);
        return;
      }
      fx.effects.push(f);
    }
    FxModel.sortEffects(fx);
    selFx = added[0];
    selNotes = [];
    selEvent = null;
    changed();
    inspectorDirty = tlDirty = true;
    trace('[GOLDEN EDITOR] Event System: added ${added.map(f -> f.type).join("+")} at ${Math.round(at)} ms');
    notify('Added ${it.label} at ${FxModel.fmtTime(at)}');
  }

  function newLuaScript():Void
  {
    var mod = EditorFiles.target();
    if (mod == null) return;
    var n = 1;
    while (EditorFiles.exists(EditorFiles.modPath('scripts/events/event$n.lua', mod)))
      n++;
    var path = EditorFiles.modPath('scripts/events/event$n.lua', mod);
    var err = EditorFiles.saveText(path, '-- Golden Engine Lua event script (called by "Lua Call" effects and the Lua Script chart event).\n'
      + '-- value = the text set on the effect/event.\nfunction onEvent(name, value)\n  print("event$n: " .. tostring(value))\n  cameraFlash("FFFFFF", 0.3)\nend\n');
    if (err != null)
    {
      notify(err, 0xFFFF5C5C);
      return;
    }
    rebuildBrowser();
    notify('Created scripts/events/event$n.lua (drag it onto the timeline to call it).');
  }

  function openScriptEditor():Void
  {
    var mod = EditorFiles.target();
    if (mod == null) return;
    if (dirty) doSave();
    FlxG.switchState(() -> new golden.studio.ScriptEditorState(mod));
  }

  // ---- document ----------------------------------------------------------------------------------

  override function serialize():String
    return FxModel.toJson(fx) + '\n#' + haxe.Json.stringify(chart) + (cutsceneMode ? '|$cutLength|$cutBefore' : '');

  override function deserialize(s:String):Void
  {
    var i = s.lastIndexOf('\n#');
    fx = FxModel.fromJson(s.substr(0, i));
    var rest = s.substr(i + 2);
    if (cutsceneMode)
    {
      var parts = rest.split('|');
      cutBefore = parts.pop() == 'true';
      cutLength = Std.parseFloat(parts.pop());
      songLength = cutLength;
      rest = parts.join('|');
    }
    chart = haxe.Json.parse(rest);
    chartDirty = true;
    runtime.reset();
    runtime = new FxRuntime(fx, host);
    selFx = null;
    selNotes = [];
    selEvent = null;
    inspectorDirty = tlDirty = true;
  }

  override function refreshPanels():Void
    inspectorDirty = tlDirty = true;

  override function save():Null<String>
  {
    var mod = EditorFiles.target();
    if (cutsceneMode)
    {
      var raw:Dynamic = haxe.Json.parse(FxModel.toJson(fx));
      raw.length = cutLength;
      raw.beforeSong = cutBefore;
      var e2 = EditorFiles.saveJson(EditorFiles.modPath('data/golden/cutscenes/$songId.json', mod), raw);
      if (e2 != null) return e2;
      EditorFiles.reloadGameContent();
      stage = null;
      return null;
    }
    var err = EditorFiles.saveText(EditorFiles.modPath('data/golden/events/$songId.json', mod), FxModel.toJson(fx));
    if (err != null) return err;
    if (chartDirty && chart != null)
    {
      err = EditorFiles.saveText(EditorFiles.modPath('data/songs/$songId/$songId-chart.json', mod), haxe.Json.stringify(chart, null, '  '));
      if (err != null) return err;
      chartDirty = false;
    }
    stopPlayback();
    // Reloading the registries destroys their cached stages: release ours first, rebuild after.
    releaseStage();
    EditorFiles.reloadGameContent();
    var song = SongRegistry.instance.fetchEntry(songId);
    var d = song?.getDifficulty(difficulty, Constants.DEFAULT_VARIATION);
    buildPreview(d?.characters?.player ?? 'bf', d?.characters?.opponent ?? 'dad', d?.characters?.girlfriend ?? 'gf', d?.stage ?? 'mainStage');
    return null;
  }

  override public function changed(?what:String):Void
  {
    super.changed(what);
    tlDirty = true;
    inspector.refresh();
  }

  function resetOriginal():Void
  {
    var mod = EditorFiles.target();
    if (mod == null) return;
    openSubState(new golden.ui.GoldenDialogs.GoldenConfirmSubState('Reset "$songId" to the original?\nThis deletes the Event System effects and the edited chart copy from mod "$mod".', () ->
    {
      for (rel in ['data/golden/events/$songId.json', 'data/songs/$songId/$songId-chart.json'])
      {
        var p = EditorFiles.modPath(rel, mod);
        #if sys
        if (EditorFiles.exists(p)) sys.FileSystem.deleteFile(p);
        #end
      }
      EditorFiles.reloadGameContent();
      loadSong(songId, difficulty);
      notify('"$songId" reset to the original.');
    }));
  }

  function validate():Void
  {
    var problems = FxModel.conflicts(fx);
    for (f in fx.effects)
    {
      for (key in ['image', 'sound'])
      {
        var v:String = Reflect.field(f.params, key);
        if (v == null || v == '') continue;
        var path = key == 'image' ? Paths.image(v) : Paths.sound(v);
        if (!Assets.exists(path)) problems.push('Missing $key "$v" (${FxModel.typeInfo(f.type)?.title} at ${FxModel.fmtTime(f.time)})');
      }
      if (f.type == 'lua' && Reflect.field(f.params, 'script') == '') problems.push('Lua Call at ${FxModel.fmtTime(f.time)} has no script');
    }
    trace('[GOLDEN EDITOR] Event System validation: ${problems.length} problem(s)' + (problems.length > 0 ? ': ' + problems.join(' | ') : ''));
    if (problems.length == 0) notify('No problems found.', 0xFF6BE36B);
    else
      for (p in problems.slice(0, 4))
        notify(p, 0xFFFFB347);
  }

  // ---- playback ----------------------------------------------------------------------------------

  function togglePlay():Void
  {
    if (cutsceneMode)
    {
      playing = !playing;
      if (playing)
      {
        if (playhead >= songLength) playhead = 0;
        runtime.reset();
        runtime.skipTo(playhead);
        trace('[GOLDEN EDITOR] Cutscene Editor: playing "$songId" cutscene from ${Math.round(playhead)} ms');
      }
      return;
    }
    if (playing)
    {
      playing = false;
      music?.pause();
      notify('Paused at ${FxModel.fmtTime(playhead)}');
      return;
    }
    if (music == null)
    {
      var path = Paths.inst(songId);
      music = FunkinSound.load(path, 1.0, false, false, false, false, null, null, true);
    }
    if (music == null)
    {
      notify('No instrumental found for "$songId".', 0xFFFF5C5C);
      return;
    }
    music.time = playhead;
    music.play();
    playing = true;
    runtime.reset();
    runtime.skipTo(playhead);
    nextNote = 0;
    var ns = notes();
    while (nextNote < ns.length && ns[nextNote].t < playhead)
      nextNote++;
    trace('[GOLDEN EDITOR] Event System: playing "$songId" from ${Math.round(playhead)} ms');
  }

  function stopPlayback():Void
  {
    playing = false;
    if (music != null)
    {
      music.stop();
      music.destroy();
      music = null;
    }
    if (runtime != null) runtime.reset();
  }

  function setPlayhead(ms:Float):Void
  {
    playhead = Math.max(0, Math.min(songLength, ms));
    if (music != null && playing) music.time = playhead;
    else
    {
      runtime.reset();
      runtime.skipTo(playhead);
    }
    tlDirty = true;
  }

  function zoomTimeline(k:Float):Void
  {
    pps = Math.max(10, Math.min(1200, pps * k));
    tlDirty = true;
  }

  function cycleSnap():Void
  {
    snap = snap == 'beat' ? 'step' : (snap == 'step' ? 'off' : 'beat');
    notify('Snap: $snap');
    tlDirty = true;
  }

  function botPreview():Void
  {
    var mod = EditorFiles.target();
    if (mod == null)
    {
      notify('No mod to save into.', 0xFFFF5C5C);
      return;
    }
    stopPlayback();
    if (dirty || chartDirty) doSave();
    if (!EditorFiles.targetEnabled()) notify('Mod "$mod" is disabled: the preview will not include these edits.', 0xFFFFB347);
    var song = SongRegistry.instance.fetchEntry(songId);
    if (song == null) return;
    keep = {song: songId, diff: difficulty, playhead: playhead, pps: pps, scroll: scrollMs};
    var cut = cutsceneMode;
    golden.studio.GoldenStudio.editorReturn = () -> FlxG.switchState(() -> new EventSystemState(cut));
    trace('[GOLDEN EDITOR] Bot preview: "$songId" ($difficulty) from ${Math.round(playhead)} ms (bot play, practice: no scores saved)');
    leaving = true;
    funkin.ui.transition.LoadingState.loadPlayState({
      targetSong: song,
      targetDifficulty: difficulty,
      botPlayMode: true,
      practiceMode: true,
      startTimestamp: playhead
    }, true);
  }

  // ---- selection / editing -----------------------------------------------------------------------

  function duplicateSelection():Void
  {
    if (selFx != null)
    {
      if (trackInfo(selFx.track).locked) return lockedMsg(selFx.track);
      var c = FxModel.clone(selFx);
      c.time += Math.max(beatMs(), selFx.duration);
      fx.effects.push(c);
      FxModel.sortEffects(fx);
      selFx = c;
      changed();
      inspectorDirty = true;
    }
    else if (selNotes.length > 0)
    {
      if (trackInfo(noteTrack(selNotes[0])).locked) return lockedMsg(noteTrack(selNotes[0]));
      var span = beatMs();
      var copies = [for (n in selNotes) {t: n.t + span, d: n.d, l: n.l ?? 0, k: n.k}];
      for (c in copies)
        notes().push(c);
      sortNotes();
      selNotes = cast copies;
      chartDirty = true;
      changed();
      inspectorDirty = true;
    }
  }

  function deleteSelection():Void
  {
    if (selFx != null)
    {
      if (trackInfo(selFx.track).locked) return lockedMsg(selFx.track);
      fx.effects.remove(selFx);
      selFx = null;
      changed();
    }
    else if (selNotes.length > 0)
    {
      if (trackInfo(noteTrack(selNotes[0])).locked) return lockedMsg(noteTrack(selNotes[0]));
      for (n in selNotes)
        notes().remove(n);
      selNotes = [];
      chartDirty = true;
      changed();
    }
    else if (selEvent != null)
    {
      if (trackInfo('Chart events').locked) return lockedMsg('Chart events');
      events().remove(selEvent);
      selEvent = null;
      chartDirty = true;
      changed();
    }
    inspectorDirty = true;
  }

  function addChartEvent():Void
  {
    if (trackInfo('Chart events').locked) return lockedMsg('Chart events');
    if (chart == null) return;
    if (chart.events == null) chart.events = [];
    var e = {t: snapTime(playhead), e: 'FocusCamera', v: {char: 0}};
    (chart.events : Array<Dynamic>).push(e);
    selEvent = e;
    selFx = null;
    selNotes = [];
    chartDirty = true;
    changed();
    inspectorDirty = true;
    trace('[GOLDEN EDITOR] Event System: chart event FocusCamera added at ${Math.round(e.t)} ms');
  }

  function lockedMsg(track:String):Void
  {
    UISound.play(Error);
    notify('Track "$track" is locked. Click its lock (L) to edit it.', 0xFFFFB347);
  }

  function noteTrack(n:Dynamic):String
    return Std.int(n.d) < 4 ? 'Player notes' : 'Opponent notes';

  function sortNotes():Void
    notes().sort((a, b) -> a.t < b.t ? -1 : (a.t > b.t ? 1 : 0));

  // ---- inspector ---------------------------------------------------------------------------------

  function rebuildInspector():Void
  {
    inspectorDirty = false;
    inspector.clearRows();
    if (selFx != null)
    {
      var f = selFx;
      var ti = FxModel.typeInfo(f.type);
      inspector.addHeader(ti?.title ?? f.type);
      inspector.addNote(ti?.description ?? '');
      if (trackInfo(f.track).locked) inspector.addNote('Track "${f.track}" is locked (view only).', 0xFFFFB347);
      inspector.addNumber('Start (ms)', () -> f.time, v -> editFx(() -> f.time = Math.max(0, v)), 10);
      inspector.addNote('= beat ${Math.round(f.time / beatMs() * 100) / 100}, step ${Math.round(f.time / stepMs())}');
      inspector.addNumber('Duration (ms)', () -> f.duration, v -> editFx(() -> f.duration = Math.max(0, v)), 50);
      inspector.addChoice('Easing', () -> FxModel.EASES, () -> f.ease, v -> editFx(() -> f.ease = v));
      inspector.addToggle('Enabled', () -> f.enabled != false, v -> editFx(() -> f.enabled = v));
      if (ti != null) for (p in ti.params)
      {
        var name = p.name;
        switch (p.kind)
        {
          case 'number':
            inspector.addNumber(name, () -> Std.parseFloat(Std.string(Reflect.field(f.params, name))), v -> editFx(() -> Reflect.setField(f.params, name, v)), p.step ?? 1, p.min,
              p.max);
          case 'bool':
            inspector.addToggle(name, () -> Reflect.field(f.params, name) == true, v -> editFx(() -> Reflect.setField(f.params, name, v)));
          case 'choice':
            inspector.addChoice(name, () -> p.options, () -> Std.string(Reflect.field(f.params, name)), v -> editFx(() -> Reflect.setField(f.params, name, v)));
          default:
            inspector.addText(name + (p.kind == 'image' ? ' (images/...)' : (p.kind == 'sound' ? ' (sounds/...)' : '')), () -> Std.string(Reflect.field(f.params, name) ?? ''),
              v -> editFx(() -> Reflect.setField(f.params, name, v)));
        }
      }
      inspector.addButtons([
        {caption: 'Preview', fn: () -> previewOne(f), tooltip: 'Play this effect now in the preview'},
        {caption: 'Duplicate', fn: duplicateSelection}, {caption: 'Delete', fn: deleteSelection}
      ]);
      if (ti?.native != null && ti.native != 'golden-lua') inspector.addButtons([
        {caption: 'Convert to chart event', fn: () -> convertToChartEvent(f), tooltip: 'Move it into the chart as the FNF "${ti.native}" event'}
      ]);
      return;
    }
    if (selNotes.length > 0)
    {
      var n:Dynamic = selNotes[0];
      inspector.addHeader(selNotes.length > 1 ? '${selNotes.length} notes' : 'Note');
      if (trackInfo(noteTrack(n)).locked) inspector.addNote('Notes are locked (original chart). Unlock the track to edit.', 0xFFFFB347);
      inspector.addNumber('Time (ms)', () -> n.t, v -> editNotes(() ->
      {
        var dt = v - n.t;
        for (x in selNotes)
          x.t = Math.max(0, x.t + dt);
      }), 10);
      inspector.addChoice('Lane', () -> ['0 P-left', '1 P-down', '2 P-up', '3 P-right', '4 O-left', '5 O-down', '6 O-up', '7 O-right'],
        () -> ['0 P-left', '1 P-down', '2 P-up', '3 P-right', '4 O-left', '5 O-down', '6 O-up', '7 O-right'][Std.int(n.d) % 8], v -> editNotes(() -> n.d = Std.parseInt(v.split(' ')[0])));
      inspector.addNumber('Sustain (ms)', () -> n.l ?? 0, v -> editNotes(() -> n.l = Math.max(0, v)), stepMs());
      inspector.addText('Kind', () -> n.k ?? '', v -> editNotes(() -> n.k = v == '' ? null : v));
      inspector.addButtons([{caption: 'Duplicate', fn: duplicateSelection}, {caption: 'Delete', fn: deleteSelection}]);
      return;
    }
    if (selEvent != null)
    {
      var e:Dynamic = selEvent;
      inspector.addHeader('Chart event');
      if (trackInfo('Chart events').locked) inspector.addNote('Chart events are locked. Unlock the track to edit.', 0xFFFFB347);
      inspector.addChoice('Kind', () -> SongEventRegistry.listEventIds(), () -> e.e, v -> editEvent(() -> e.e = v));
      inspector.addNumber('Time (ms)', () -> e.t, v -> editEvent(() -> e.t = Math.max(0, v)), 10);
      inspector.addText('Value (JSON)', () -> haxe.Json.stringify(e.v), v -> editEvent(() ->
      {
        try
          e.v = haxe.Json.parse(v)
        catch (err:Dynamic)
          notify('Invalid JSON: $err', 0xFFFF5C5C);
      }));
      inspector.addButtons([{caption: 'Delete', fn: deleteSelection}]);
      return;
    }
    // Song panel
    inspector.addHeader('Song');
    inspector.addChoice('Song', () -> SongRegistry.instance.listEntryIds(), () -> songId, v -> confirmThen(() -> loadSong(v, difficulty)));
    inspector.addChoice('Difficulty', () ->
    {
      var s = SongRegistry.instance.fetchEntry(songId);
      return s != null ? s.listDifficulties(Constants.DEFAULT_VARIATION, null, true, true) : [difficulty];
    }, () -> difficulty, v -> confirmThen(() -> loadSong(songId, v)));
    if (cutsceneMode)
    {
      inspector.addNumber('Cutscene length (ms)', () -> cutLength, v ->
      {
        cutLength = Math.max(500, v);
        songLength = cutLength;
        changed();
      }, 500, 500, 600000);
      inspector.addToggle('Play before the song', () -> cutBefore, v ->
      {
        cutBefore = v;
        changed();
      });
      inspector.addNote('Plays before the countdown (Enter skips). Stage and characters are the song\'s.');
    }
    inspector.addNote('${notes().length} notes, ${events().length} chart events, ${fx.effects.length} effects. ${Math.round(bpm)} BPM.');
    inspector.addNote('Characters: ' + [for (k => c in chars) '$k=${c.characterId}'].join(', '));
    inspector.addHeader('Tracks');
    inspector.addNote('Original notes and chart events start locked. Click a lock in the timeline (or here) to edit them.');
    for (name in ['Player notes', 'Opponent notes', 'Chart events'].concat(FxModel.TRACKS))
    {
      var t = trackInfo(name);
      inspector.addToggle('$name locked', () -> t.locked, v ->
      {
        t.locked = v;
        tlDirty = true;
        trace('[GOLDEN EDITOR] Event System: track "$name" ${v ? "locked" : "unlocked"}');
      });
    }
    inspector.addHeader('Saved into');
    inspector.addNote('Effects: mods/<mod>/data/golden/events/$songId.json\nChart edits: mods/<mod>/data/songs/$songId/$songId-chart.json (the original is untouched).');
  }

  function confirmThen(fn:Void->Void):Void
  {
    if (!dirty && !chartDirty)
    {
      fn();
      return;
    }
    openSubState(new golden.ui.GoldenDialogs.GoldenConfirmSubState('Discard unsaved edits to "$songId"?', fn));
  }

  function editFx(fn:Void->Void):Void
  {
    if (selFx != null && trackInfo(selFx.track).locked) return lockedMsg(selFx.track);
    fn();
    FxModel.sortEffects(fx);
    changed();
  }

  function editNotes(fn:Void->Void):Void
  {
    if (selNotes.length > 0 && trackInfo(noteTrack(selNotes[0])).locked) return lockedMsg(noteTrack(selNotes[0]));
    fn();
    sortNotes();
    chartDirty = true;
    changed();
  }

  function editEvent(fn:Void->Void):Void
  {
    if (trackInfo('Chart events').locked) return lockedMsg('Chart events');
    fn();
    chartDirty = true;
    changed();
  }

  function previewOne(f:Fx):Void
  {
    var one = FxModel.emptyProject(songId);
    var c = FxModel.clone(f);
    c.time = 0;
    one.effects.push(c);
    var r = new FxRuntime(one, host);
    previewRuntimes.push(r);
    r.update(0, 0);
  }

  var previewRuntimes:Array<FxRuntime> = [];

  function convertToChartEvent(f:Fx):Void
  {
    if (trackInfo('Chart events').locked) return lockedMsg('Chart events');
    var ti = FxModel.typeInfo(f.type);
    if (chart == null || ti?.native == null) return;
    var value:Dynamic = null;
    // Reuse the runtime's translation by capturing what it would send.
    var capture = new CaptureHost(host);
    var one = FxModel.emptyProject(songId);
    var c = FxModel.clone(f);
    one.effects.push(c);
    new FxRuntime(one, capture).update(c.time, 0);
    if (capture.kind == null) return;
    if (chart.events == null) chart.events = [];
    (chart.events : Array<Dynamic>).push({t: f.time, e: capture.kind, v: capture.value});
    fx.effects.remove(f);
    selFx = null;
    chartDirty = true;
    changed();
    inspectorDirty = true;
    notify('Converted to FNF chart event "${capture.kind}" at ${FxModel.fmtTime(f.time)}.');
  }

  // ---- timeline ----------------------------------------------------------------------------------

  inline function xToMs(x:Float):Float
    return scrollMs + (x - NAME_W) / pps * 1000;

  inline function msToX(ms:Float):Float
    return NAME_W + (ms - scrollMs) / 1000 * pps;

  function rowAt(viewY:Float):Null<String>
  {
    var r = Std.int((viewY - (tlTop() + HEAD + RULER)) / ROW) + rowScroll;
    var rows = rowsList();
    return r >= 0 && r < rows.length ? rows[r] : null;
  }

  function visibleRows():Int
    return Std.int((TL_H - HEAD - RULER) / ROW);

  function redrawTimeline():Void
  {
    tlDirty = false;
    var b = tlBmp;
    b.fillRect(b.rect, 0xFF1B1820);
    var w = FlxG.width;
    // ruler: beats and bars
    b.fillRect(new Rectangle(NAME_W, 0, w - NAME_W, RULER - 1), 0xFF2A2633);
    var bm = beatMs();
    var firstBeat = Math.floor(scrollMs / bm);
    var labels = 0;
    for (t in tlRuler)
      t.text = '';
    var beat = firstBeat;
    while (true)
    {
      var x = msToX(beat * bm);
      if (x > w) break;
      if (x >= NAME_W)
      {
        var bar = beat % 4 == 0;
        b.fillRect(new Rectangle(x, bar ? 0 : RULER / 2, 1, bar ? b.height : RULER / 2), bar ? 0xFF4A4458 : 0xFF333040);
        if (bar && labels < tlRuler.length && pps * bm * 4 / 1000 > 40)
        {
          tlRuler[labels].text = FxModel.fmtTime(beat * bm).substr(0, 7);
          tlRuler[labels].x = x + 2;
          labels++;
        }
      }
      beat++;
    }
    var rows = rowsList();
    var vr = visibleRows();
    for (t in tlNames)
      t.text = '';
    for (r in 0...vr)
    {
      var idx = r + rowScroll;
      if (idx >= rows.length) break;
      var name = rows[idx];
      var t = trackInfo(name);
      var y = RULER + r * ROW;
      b.fillRect(new Rectangle(0, y, NAME_W - 2, ROW - 1), 0xFF24212B);
      // lock and visibility markers
      b.fillRect(new Rectangle(4, y + 2, 10, ROW - 5), t.locked ? 0xFFFF7A5C : 0xFF4ADE80);
      if (r < tlNames.length)
      {
        tlNames[r].text = name;
        tlNames[r].color = t.locked ? EditorUI.MUTED : EditorUI.TEXT;
      }
      if (t.locked) b.fillRect(new Rectangle(NAME_W, y, w - NAME_W, ROW - 1), 0x22FF7A5C);
      // contents
      if (name == 'Player notes' || name == 'Opponent notes')
      {
        var pl = name == 'Player notes';
        var cols = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
        for (n in notes())
        {
          var d = Std.int(n.d);
          if ((d < 4) != pl) continue;
          var x = msToX(n.t);
          if (x < NAME_W - 4 || x > w) continue;
          var sel = selNotes.contains(n);
          var lane = d % 4;
          var ny = y + 1 + lane * 3;
          var sus:Float = n.l ?? 0;
          if (sus > 0) b.fillRect(new Rectangle(x, ny + 1, Math.max(1, sus / 1000 * pps), 1), cols[lane]);
          b.fillRect(new Rectangle(x - 1, ny, 3, 3), sel ? 0xFFFFFFFF : cols[lane]);
        }
      }
      else if (name == 'Chart events')
      {
        for (e in events())
        {
          var x = msToX(e.t);
          if (x < NAME_W - 4 || x > w) continue;
          b.fillRect(new Rectangle(x - 2, y + 2, 5, ROW - 5), e == selEvent ? 0xFFFFFFFF : 0xFFB98CFF);
        }
      }
      else
      {
        for (f in fx.effects)
        {
          if (f.track != name) continue;
          var x0 = msToX(f.time), x1 = msToX(f.time + Math.max(f.duration, 0));
          if (x1 < NAME_W || x0 > w) continue;
          var wpx = Math.max(4, x1 - x0);
          var col = f == selFx ? 0xFFFFC83D : (f.enabled == false ? 0xFF4A4458 : 0xFFC9A040);
          b.fillRect(new Rectangle(Math.max(NAME_W, x0), y + 1, wpx - Math.max(0, NAME_W - x0), ROW - 3), col);
          b.fillRect(new Rectangle(Math.max(NAME_W, x0 + wpx - 2), y + 1, 2, ROW - 3), 0xFF8A6410);
        }
      }
      EditorUI.mapLog('track:$name', NAME_W, tlTop() + HEAD + y, w - NAME_W, ROW);
      EditorUI.mapLog('lock:$name', 4, tlTop() + HEAD + y, 10, ROW);
    }
    // playhead
    var px = msToX(playhead);
    if (px >= NAME_W && px < w) b.fillRect(new Rectangle(px - 1, 0, 2, b.height), 0xFFFF5C5C);
    tlInfo.text = '${songId} [$difficulty]  ${FxModel.fmtTime(playhead)}  beat ${Math.floor(playhead / beatMs())}  step ${Math.floor(playhead / stepMs())}  '
      + '${Math.round(bpm)} BPM  snap: $snap' + (playing ? '  PLAYING' : '');
    EditorUI.mapLog('timeline:ruler', NAME_W, tlTop() + HEAD, w - NAME_W, RULER);
  }

  function timelineMouse():Void
  {
    var p = FlxG.mouse.getViewPosition(camUI);
    var top = tlTop() + HEAD;
    var inTl = p.y >= top && p.y < tlTop() + TL_H;
    if (inTl && FlxG.mouse.wheel != 0)
    {
      if (FlxG.keys.pressed.CONTROL) zoomTimeline(FlxG.mouse.wheel > 0 ? 1.2 : 1 / 1.2);
      else if (FlxG.keys.pressed.SHIFT) rowScroll = Std.int(Math.max(0, Math.min(rowsList().length - visibleRows(), rowScroll - FlxG.mouse.wheel)));
      else
        scrollMs = Math.max(0, scrollMs - FlxG.mouse.wheel * 120000 / pps);
      tlDirty = true;
    }
    if (FlxG.mouse.justPressed && inTl)
    {
      var ms = xToMs(p.x);
      trace('[GOLDEN EDITOR] Event System: timeline click at ${Std.int(p.x)},${Std.int(p.y)} (${rowAt(p.y) ?? "ruler"}, ${Math.round(ms)} ms)');
      if (p.y < top + RULER && p.x >= NAME_W)
      {
        setPlayhead(snap == 'off' ? ms : snapTime(ms));
        drag = {kind: 'scrub', startMs: ms, mx: p.x, orig: [], origDur: 0};
      }
      else
      {
        var row = rowAt(p.y);
        if (row != null && p.x < 16)
        {
          var t = trackInfo(row);
          t.locked = !t.locked;
          UISound.play(Toggle);
          trace('[GOLDEN EDITOR] Event System: track "$row" ${t.locked ? "locked" : "unlocked"}');
          notify('Track "$row" ${t.locked ? "locked" : "unlocked"}');
          tlDirty = inspectorDirty = true;
        }
        else if (row != null && p.x >= NAME_W)
          pickAt(row, ms, p.x);
      }
    }
    if (drag != null && FlxG.mouse.pressed)
    {
      var dms = (p.x - drag.mx) / pps * 1000;
      switch (drag.kind)
      {
        case 'scrub':
          setPlayhead(Math.max(0, xToMs(p.x)));
        case 'fx' if (selFx != null):
          selFx.time = snapTime(drag.orig[0] + dms);
          tlDirty = true;
        case 'fxResize' if (selFx != null):
          selFx.duration = Math.max(0, snapTime(drag.orig[0] + drag.origDur + dms) - drag.orig[0]);
          tlDirty = true;
        case 'notes':
          for (i in 0...selNotes.length)
            selNotes[i].t = Math.max(0, snap == 'off' ? drag.orig[i] + dms : drag.orig[i] + Math.round(dms / stepMs()) * stepMs());
          tlDirty = true;
        case 'event' if (selEvent != null):
          selEvent.t = snapTime(drag.orig[0] + dms);
          tlDirty = true;
        default:
      }
    }
    if (drag != null && FlxG.mouse.justReleased)
    {
      var k = drag.kind;
      var movedPx = Math.abs(p.x - drag.mx);
      drag = null;
      if (k != 'scrub' && movedPx > 2)
      {
        if (k == 'notes')
        {
          sortNotes();
          chartDirty = true;
        }
        if (k == 'event') chartDirty = true;
        FxModel.sortEffects(fx);
        trace('[GOLDEN EDITOR] Event System: $k moved/resized');
        changed();
        inspectorDirty = true;
      }
    }
    p.put();
  }

  function pickAt(row:String, ms:Float, px:Float):Void
  {
    var tol = 6 / pps * 1000;
    var locked = trackInfo(row).locked;
    selFx = null;
    selEvent = null;
    if (!FlxG.keys.pressed.SHIFT) selNotes = [];
    if (row == 'Player notes' || row == 'Opponent notes')
    {
      var best:Dynamic = null, bd = tol;
      for (n in notes())
      {
        if ((Std.int(n.d) < 4) != (row == 'Player notes')) continue;
        var d = Math.abs(n.t - ms);
        if (d <= bd)
        {
          bd = d;
          best = n;
        }
      }
      if (best != null)
      {
        if (!selNotes.contains(best)) selNotes.push(best);
        if (!locked) drag = {kind: 'notes', startMs: ms, mx: px, orig: [for (n in selNotes) n.t], origDur: 0};
      }
    }
    else if (row == 'Chart events')
    {
      for (e in events())
        if (Math.abs(e.t - ms) <= tol)
        {
          selEvent = e;
          if (!locked) drag = {kind: 'event', startMs: ms, mx: px, orig: [e.t], origDur: 0};
          break;
        }
    }
    else
    {
      var i = fx.effects.length - 1;
      while (i >= 0)
      {
        var f = fx.effects[i--];
        if (f.track != row) continue;
        var end = f.time + Math.max(f.duration, tol);
        if (ms >= f.time - tol && ms <= end)
        {
          selFx = f;
          var nearEnd = f.duration > 0 && Math.abs(ms - (f.time + f.duration)) <= tol;
          if (!locked) drag = {kind: nearEnd ? 'fxResize' : 'fx', startMs: ms, mx: px, orig: [f.time], origDur: f.duration};
          break;
        }
      }
    }
    if (locked && (selFx != null || selNotes.length > 0 || selEvent != null)) setStatus('Track "$row" is locked: selected for viewing only');
    inspectorDirty = tlDirty = true;
  }

  override function editorKeys():Void
  {
    var ctrl = FlxG.keys.pressed.CONTROL;
    if (FlxG.keys.justPressed.SPACE) togglePlay();
    if (ctrl && FlxG.keys.justPressed.D) duplicateSelection();
    if (FlxG.keys.justPressed.DELETE) deleteSelection();
    if (!ctrl && FlxG.keys.justPressed.LEFT) setPlayhead(playhead - stepMs());
    if (!ctrl && FlxG.keys.justPressed.RIGHT) setPlayhead(playhead + stepMs());
    if (FlxG.keys.justPressed.HOME) setPlayhead(0);
    if (FlxG.keys.justPressed.ESCAPE) {}
    if (selNotes.length > 0 && (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN))
    {
      var dir = FlxG.keys.justPressed.UP ? -1 : 1;
      editNotes(() -> for (n in selNotes) n.d = (Std.int(n.d) - Std.int(n.d) % 4) + ((Std.int(n.d) % 4 + dir + 4) % 4));
    }
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (leaving) return;
    if (subState == null && armed) timelineMouse();
    if (playing && cutsceneMode)
    {
      playhead += elapsed * 1000;
      runtime.update(playhead, elapsed);
      tlDirty = true;
      if (playhead >= songLength) playing = false;
    }
    else if (playing && music != null)
    {
      playhead = music.time;
      runtime.update(playhead, elapsed);
      // characters: dance on beats, sing on notes (a quick in-editor bot)
      var beat = Math.floor(playhead / beatMs());
      if (beat != lastBeat)
      {
        lastBeat = beat;
        for (c in chars)
          if (!c.isSinging() || c.characterType == GF) c.dance();
      }
      var ns = notes();
      while (nextNote < ns.length && ns[nextNote].t <= playhead)
      {
        var n = ns[nextNote++];
        var c = Std.int(n.d) < 4 ? chars.get('bf') : chars.get('dad');
        if (c != null) c.playSingAnimation(funkin.play.notes.NoteDirection.fromInt(Std.int(n.d) % 4), false);
      }
      var px = msToX(playhead);
      if (px > FlxG.width - 40) scrollMs = playhead - 1000;
      tlDirty = true;
      if (playhead >= songLength) stopPlayback();
    }
    else if (runtime != null) runtime.update(playhead, elapsed);
    for (r in previewRuntimes)
      r.update(1, elapsed);
    if (inspectorDirty) rebuildInspector();
    if (tlDirty) redrawTimeline();
    var c = FxModel.conflicts(fx);
    if (c.length > 0 && statusMsg == '') setStatus('Warning: ' + c[0]);
  }

  override function destroy():Void
  {
    stopPlayback();
    for (r in previewRuntimes)
      r.reset();
    releaseStage();
    super.destroy();
  }
}

/** Captures the native event an effect would send (for "Convert to chart event"). */
class CaptureHost implements FxHost
{
  var inner:FxHost;

  public var kind:Null<String> = null;
  public var value:Dynamic = null;

  public function new(inner:FxHost)
    this.inner = inner;

  public function gameCam():FlxCamera
    return null;

  public function hudCam():FlxCamera
    return null;

  public function topCam():FlxCamera
    return null;

  public function addBehindCharacters(s:FlxSprite):Void {}

  public function addSprite(s:FlxBasic):Void {}

  public function removeSprite(s:FlxBasic):Void {}

  public function character(target:String):Null<FlxSprite>
    return null;

  public function playerStrums():Null<FlxSpriteGroup>
    return null;

  public function opponentStrums():Null<FlxSpriteGroup>
    return null;

  public function runNative(kind:String, value:Dynamic, time:Float):Void
  {
    this.kind = kind;
    this.value = value;
  }

  public function stepMs():Float
    return inner.stepMs();
}
