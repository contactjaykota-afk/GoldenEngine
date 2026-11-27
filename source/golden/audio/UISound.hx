package golden.audio;

import funkin.audio.FunkinSound;

/** The kinds of interface feedback Golden Engine menus give. */
enum abstract UISoundKind(String) to String
{
  var Hover = 'hover';
  var Scroll = 'scroll';
  var Select = 'select';
  var Back = 'back';
  var Open = 'open';
  var Close = 'close';
  var Toggle = 'toggle';
  var Slider = 'slider';
  var Error = 'error';
}

/**
 * Golden Engine — central UI sound player.
 *
 * - Uses FNF's own menu sounds (scrollMenu / confirmMenu / cancelMenu / remote_click / CS_locked)
 *   played through FunkinSound, so they follow the master volume and mute.
 * - `GoldenSettings.uiVolume` is applied to every UI sound file (also upstream's menus) in FunkinSound.playOnce.
 * - De-duplicates: the same kind never plays twice within `MIN_GAP` seconds (stops double plays when
 *   both a key handler and a mouse handler fire on the same frame, and stops rapid repeats stacking).
 */
class UISound
{
  /** Seconds within which a repeat of the same kind is dropped. */
  static inline var MIN_GAP:Float = 0.045;

  static final ASSETS:Map<String, {key:String, volume:Float}> = [
    'hover' => {key: 'scrollMenu', volume: 0.35},
    'scroll' => {key: 'scrollMenu', volume: 0.7},
    'select' => {key: 'confirmMenu', volume: 0.7},
    'back' => {key: 'cancelMenu', volume: 0.7},
    'open' => {key: 'remote_click', volume: 0.8},
    'close' => {key: 'cancelMenu', volume: 0.5},
    'toggle' => {key: 'remote_click', volume: 0.9},
    'slider' => {key: 'scrollMenu', volume: 0.4},
    'error' => {key: 'CS_locked', volume: 0.6}
  ];

  /** Sound files treated as UI sounds everywhere in the game (upstream menus included). */
  static final UI_FILES:Array<String> = ['scrollMenu', 'confirmMenu', 'cancelMenu', 'remote_click', 'CS_locked'];

  /**
   * Called by FunkinSound.playOnce for every one-shot sound: returns the UI volume for UI sound
   * files and 1 for everything else (gameplay sounds are never affected).
   */
  public static function volumeScaleFor(assetPath:String):Float
  {
    if (assetPath == null) return 1.0;
    var file = haxe.io.Path.withoutExtension(haxe.io.Path.withoutDirectory(assetPath));
    return UI_FILES.contains(file) ? GoldenSettings.uiVolume : 1.0;
  }

  static var lastPlayed:Map<String, Float> = [];

  public static function play(kind:UISoundKind):Void
  {
    var now:Float = haxe.Timer.stamp();
    var k:String = kind;
    var last:Null<Float> = lastPlayed.get(k);
    if (last != null && now - last < MIN_GAP) return;
    lastPlayed.set(k, now);

    var def = ASSETS.get(k);
    if (def == null) return;
    // UI volume is applied inside FunkinSound.playOnce (volumeScaleFor), so it is not multiplied here.
    if (GoldenSettings.uiVolume <= 0) return;
    var volume:Float = def.volume;

    // (No stop-previous here: FunkinSound recycles one-shot instances, so a stored reference may
    // already belong to an unrelated sound. MIN_GAP prevents stacking instead.)
    FunkinSound.playOnce(Paths.sound(def.key), volume);
  }
}
