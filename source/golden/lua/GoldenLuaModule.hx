package golden.lua;

#if FEATURE_LUA
import funkin.modding.events.ScriptEvent;
import funkin.modding.module.Module;
import funkin.play.PlayState;

/**
 * Golden Engine — bridges FNF's module event system to Lua. Registered by ModuleHandler alongside
 * scripted (HScript) modules, so Lua scripts receive exactly the events HScript modules receive.
 */
class GoldenLuaModule extends Module
{
  public function new()
  {
    super('golden-lua', 900);
  }

  static inline function inSong():Bool
    return PlayState.instance != null && GoldenLua.scripts.length > 0;

  override function onSongLoaded(event:SongLoadScriptEvent):Void
  {
    // Fired when PlayState (re)builds the chart: start of a song and every restart.
    GoldenLua.startSong(event.id);
  }

  override function onSongStart(event:ScriptEvent):Void
    if (inSong()) GoldenLua.callAll('onSongStart');

  override function onBeatHit(event:SongTimeScriptEvent):Void
    if (inSong()) GoldenLua.callAll('onBeatHit', [event.beat]);

  override function onStepHit(event:SongTimeScriptEvent):Void
    if (inSong()) GoldenLua.callAll('onStepHit', [event.step]);

  override function onUpdate(event:UpdateScriptEvent):Void
  {
    if (!inSong()) return;
    for (s in GoldenLua.scripts)
      if (s.hasFunction('onUpdate')) s.call('onUpdate', [event.elapsed]);
  }

  override function onNoteHit(event:HitNoteScriptEvent):Void
  {
    if (!inSong() || event.note == null) return;
    var d = event.note.noteData;
    GoldenLua.callAll('onNoteHit', [d.getDirection(), d.getMustHitNote(), d.kind ?? '']);
  }

  override function onNoteMiss(event:NoteScriptEvent):Void
  {
    if (!inSong() || event.note == null) return;
    GoldenLua.callAll('onNoteMiss', [event.note.noteData.getDirection()]);
  }

  override function onSongEvent(event:SongEventScriptEvent):Void
  {
    if (!inSong() || event.eventData == null) return;
    GoldenLua.callAll('onEvent', [event.eventData.eventKind, event.eventData.value]);
  }

  override function onPause(event:PauseScriptEvent):Void
    if (inSong()) GoldenLua.callAll('onPause');

  override function onResume(event:ScriptEvent):Void
    if (inSong()) GoldenLua.callAll('onResume');

  override function onGameOver(event:ScriptEvent):Void
    if (inSong()) GoldenLua.callAll('onGameOver');

  override function onSongEnd(event:ScriptEvent):Void
    if (inSong()) GoldenLua.callAll('onSongEnd');

  override function onStateChangeBegin(event:StateChangeScriptEvent):Void
  {
    // Leaving gameplay (to menus, editors, results): close every Lua state.
    if (Std.isOfType(FlxG.state, PlayState)) GoldenLua.stopAll();
  }
}
#end
