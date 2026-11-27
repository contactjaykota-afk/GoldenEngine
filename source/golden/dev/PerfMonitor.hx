package golden.dev;

import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;

/**
 * Golden Engine performance monitor: a small OpenFL overlay (drawn above every Flixel camera).
 * Text is rebuilt at most 4 times per second so the monitor itself costs almost nothing.
 *
 * Shows FPS, average frame time, worst frame time in the last window, current and peak process
 * memory (process RSS / working set via funkin.util.MemoryUtil.getTaskMemory, plus GC heap), current state/substate,
 * and when a song is playing: song, difficulty, BPM and position.
 */
class PerfMonitor extends Sprite
{
  static inline var REFRESH:Float = 0.25;

  var field:TextField;
  var acc:Float = 0;
  var frames:Int = 0;
  var worst:Float = 0;
  var peakMem:Float = 0;

  public function new()
  {
    super();
    mouseEnabled = mouseChildren = false;
    field = new TextField();
    field.selectable = false;
    field.mouseEnabled = false;
    field.defaultTextFormat = new TextFormat('_sans', 12, 0xFFE9B0);
    field.background = true;
    field.backgroundColor = 0x000000;
    field.width = 330;
    field.height = 150;
    field.multiline = true;
    addChild(field);
    alpha = 0.85;
  }

  /** Call once per frame with the real elapsed time in seconds. */
  public function tick(elapsed:Float):Void
  {
    acc += elapsed;
    frames++;
    if (elapsed > worst) worst = elapsed;
    if (acc < REFRESH) return;

    var fps = frames / acc;
    var avgMs = acc / frames * 1000;
    var mem:Float = funkin.util.MemoryUtil.supportsTaskMem() ? funkin.util.MemoryUtil.getTaskMemory() : 0;
    var gc:Float = funkin.util.MemoryUtil.getGCMemory();
    if (mem > peakMem) peakMem = mem;

    var state = FlxG.state;
    var stateName = state == null ? '-' : Type.getClassName(Type.getClass(state)).split('.').pop();
    var sub = state?.subState;
    while (sub?.subState != null)
      sub = sub.subState;
    if (sub != null) stateName += ' > ' + Type.getClassName(Type.getClass(sub)).split('.').pop();

    var lines = [
      'GOLDEN DEV  FPS ${Math.round(fps)}  frame ${fmt(avgMs)} ms (worst ${fmt(worst * 1000)})',
      'RAM ${mb(mem)} MB  peak ${mb(peakMem)} MB  (GC heap ${mb(gc)} MB)',
      'State: $stateName'
    ];
    var ps = funkin.play.PlayState.instance;
    if (ps != null && ps.currentSong != null)
    {
      var c = funkin.Conductor.instance;
      lines.push('Song: ${ps.currentSong.songName} [${ps.currentDifficulty}${ps.currentVariation != 'default' ? ' / ' + ps.currentVariation : ''}]');
      lines.push('BPM ${fmt(c.bpm)}  pos ${fmt(c.songPosition / 1000)} s  beat ${c.currentBeat}  step ${c.currentStep}');
    }
    field.text = lines.join('\n');
    field.height = field.textHeight + 6;
    field.width = Math.max(260, field.textWidth + 8);

    acc = 0;
    frames = 0;
    worst = 0;
  }

  static inline function fmt(v:Float):String
    return Std.string(Math.round(v * 10) / 10);

  static inline function mb(bytes:Float):String
    return Std.string(Math.round(bytes / 1024 / 1024));
}
