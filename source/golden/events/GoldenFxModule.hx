package golden.events;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import funkin.Conductor;
import funkin.data.event.SongEventRegistry;
import funkin.data.song.SongData.SongEventData;
import funkin.modding.events.ScriptEvent;
import funkin.modding.module.Module;
import funkin.play.PlayState;
import golden.events.FxModel;
import golden.events.FxRuntime;

/** FxHost for real gameplay. */
class PlayFxHost implements FxHost
{
  var ps:PlayState;
  var top:Null<FlxCamera> = null;
  var inStage:Array<FlxBasic> = [];

  public function new(ps:PlayState)
    this.ps = ps;

  public function gameCam():FlxCamera
    return ps.camGame;

  public function hudCam():FlxCamera
    return ps.camHUD;

  public function topCam():FlxCamera
  {
    if (top == null || !FlxG.cameras.list.contains(top))
    {
      top = new FlxCamera();
      top.bgColor = 0x00000000;
      FlxG.cameras.add(top, false);
    }
    return top;
  }

  public function addBehindCharacters(s:FlxSprite):Void
  {
    var st = ps.currentStage;
    if (st == null)
    {
      addSprite(s);
      return;
    }
    var z = 1000;
    for (c in [st.getBoyfriend(), st.getDad(), st.getGirlfriend()])
      if (c != null) z = Std.int(Math.min(z, c.zIndex));
    s.zIndex = z - 1;
    st.add(s);
    st.refresh();
    inStage.push(s);
  }

  public function addSprite(s:FlxBasic):Void
    ps.add(s);

  public function removeSprite(s:FlxBasic):Void
  {
    if (inStage.contains(s) && ps.currentStage != null)
    {
      ps.currentStage.remove(cast s, true);
      inStage.remove(s);
    }
    else
      ps.remove(s, true);
  }

  public function character(target:String):Null<FlxSprite>
  {
    var st = ps.currentStage;
    if (st == null) return null;
    return switch (target)
    {
      case 'player' | 'boyfriend': st.getBoyfriend();
      case 'opponent' | 'dad': st.getDad();
      case 'girlfriend': st.getGirlfriend();
      default: null;
    };
  }

  public function playerStrums():Null<FlxSpriteGroup>
    return ps.playerStrumline;

  public function opponentStrums():Null<FlxSpriteGroup>
    return ps.opponentStrumline;

  public function runNative(kind:String, value:Dynamic, time:Float):Void
    SongEventRegistry.handleEvent(new SongEventData(time, kind, value));

  public function stepMs():Float
    return Conductor.instance.stepLengthMs;

  public function dispose():Void
  {
    if (top != null && FlxG.cameras.list.contains(top)) FlxG.cameras.remove(top, true);
    top = null;
  }
}

/**
 * Golden Engine Event System — runs a song's saved effects (data/golden/events/<song>.json, from the
 * enabled mods) during gameplay. Registered by ModuleHandler like any FNF module.
 */
class GoldenFxModule extends Module
{
  public static var runtime(default, null):Null<FxRuntime> = null;

  var host:Null<PlayFxHost> = null;

  public function new()
  {
    super('golden-fx', 950);
  }

  public static function pathFor(songId:String):String
    return Paths.json('golden/events/$songId');

  /** Load a song's effects (null when the song has none or the file is invalid; problems are logged). */
  public static function loadProject(songId:String):Null<FxProject>
  {
    var path = pathFor(songId);
    if (!Assets.exists(path)) return null;
    try
    {
      var problems = [];
      var p = FxModel.fromJson(Assets.getText(path), problems);
      for (pr in problems)
        trace('[GOLDEN FX] $songId: $pr');
      return p;
    }
    catch (e:Dynamic)
    {
      trace('[GOLDEN FX] Could not read $path: $e');
      return null;
    }
  }

  function stop():Void
  {
    if (runtime != null) runtime.reset();
    runtime = null;
    if (host != null) host.dispose();
    host = null;
  }

  /** Note skin colours (Note Skin Editor) for the song's note style. */
  var noteTints:Null<Array<flixel.util.FlxColor>> = null;

  override function onSongLoaded(event:SongLoadScriptEvent):Void
  {
    stop();
    var ps = PlayState.instance;
    if (ps == null) return;
    golden.editor.NoteSkinEditorState.clearColors();
    @:privateAccess var styleId:String = ps.noteStyle?.id ?? '';
    noteTints = golden.editor.NoteSkinEditorState.tintsFor(styleId);
    if (noteTints != null) trace('[GOLDEN] Note colours for note style "$styleId"');
    var p = loadProject(event.id);
    if (p == null || p.effects.length == 0) return;
    host = new PlayFxHost(ps);
    runtime = new FxRuntime(p, host);
    runtime.skipTo(ps.startTimestamp);
    trace('[GOLDEN FX] ${p.effects.length} effects loaded for "${event.id}"');
  }

  override function onUpdate(event:UpdateScriptEvent):Void
  {
    var ps = PlayState.instance;
    if (ps != null && noteTints != null) tintNotes(ps);
    if (runtime == null || ps == null) return;
    @:privateAccess if (ps.isGamePaused) return;
    runtime.update(Conductor.instance.songPosition, event.elapsed);
  }

  function tintNotes(ps:PlayState):Void
  {
    for (sl in [ps.playerStrumline, ps.opponentStrumline])
    {
      if (sl == null) continue;
      sl.strumlineNotes.forEach(n -> n.color = noteTints[Std.int(n.direction) % 4]);
      sl.notes.forEachAlive(n -> n.color = noteTints[Std.int(n.direction) % 4]);
      sl.holdNotes.forEachAlive(n -> n.color = noteTints[Std.int(n.noteDirection) % 4]);
    }
  }

  override function onStateChangeBegin(event:StateChangeScriptEvent):Void
  {
    stop();
    noteTints = null;
  }
}
