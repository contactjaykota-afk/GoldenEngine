package golden.dev;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

/**
 * Golden Engine performance monitor (drawn by GoldenDevTools on its overlay camera, above the game).
 * Text is rebuilt at most 4 times per second so the monitor itself costs almost nothing.
 *
 * Shows FPS, average frame time, worst frame time in the last window, process memory (RSS / working
 * set via funkin.util.MemoryUtil.getTaskMemory) current and peak, GC heap, current state/substate, and
 * while a song is playing: song, difficulty, BPM and position.
 */
class PerfMonitor extends FlxSpriteGroup
{
  static inline var REFRESH:Float = 0.25;

  var bg:FlxSprite;
  var field:FlxText;
  var acc:Float = 0;
  var frameCount:Int = 0;
  var worst:Float = 0;
  var peakMem:Float = 0;

  public function new()
  {
    super(4, 4);
    bg = new FlxSprite().makeGraphic(1, 1, 0xD0000000);
    add(bg);
    field = new FlxText(4, 2, 0, 'GOLDEN DEV', 12);
    field.setFormat(Paths.font('vcr.ttf'), 12, 0xFFFFE9B0, LEFT);
    add(field);
    scrollFactor.set();
  }

  /** Call once per frame with the real elapsed time in seconds. */
  public function tick(elapsed:Float):Void
  {
    acc += elapsed;
    frameCount++;
    if (elapsed > worst) worst = elapsed;
    if (acc < REFRESH) return;

    var fps = frameCount / acc;
    var avgMs = acc / frameCount * 1000;
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
    bg.setGraphicSize(Std.int(field.width + 8), Std.int(field.height + 4));
    bg.updateHitbox();

    acc = 0;
    frameCount = 0;
    worst = 0;
  }

  static inline function fmt(v:Float):String
    return Std.string(Math.round(v * 10) / 10);

  static inline function mb(bytes:Float):String
    return Std.string(Math.round(bytes / 1024 / 1024));
}
