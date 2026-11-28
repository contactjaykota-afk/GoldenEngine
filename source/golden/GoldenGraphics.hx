package golden;

/**
 * Golden Engine — graphics presets (Options > Golden Engine > Graphics Preset).
 *
 * What a preset changes (and nothing else):
 *  - FNF's frame rate cap (Preferences.framerate): low/medium 60, high 120, ultra 240;
 *  - Golden screen shader effects (colour grading, blur, glitch, pixelate in the Event System):
 *    low = off, medium/high = auto (off on software renderers), ultra = on;
 *  - default antialiasing for sprites that do not choose it themselves (FlxSprite.defaultAntialiasing):
 *    off on low;
 *  - the Chart Editor's fancy preview: off on low.
 * "custom" changes nothing, so individual settings stay as the player set them.
 */
class GoldenGraphics
{
  public static final PRESETS:Array<String> = ['low', 'medium', 'high', 'ultra', 'custom'];

  public static function apply(preset:String):Void
  {
    switch (preset)
    {
      case 'low':
        set(60, 'off', false, false);
      case 'medium':
        set(60, 'auto', true, true);
      case 'high':
        set(120, 'auto', true, true);
      case 'ultra':
        set(240, 'on', true, true);
      default:
        trace('[GOLDEN] Graphics preset: custom (individual settings kept)');
        return;
    }
    trace('[GOLDEN] Graphics preset: $preset (fps ${Preferences.framerate}, shaders ${GoldenSettings.screenShaders}, antialiasing ${flixel.FlxSprite.defaultAntialiasing})');
  }

  static function set(fps:Int, shaders:String, aa:Bool, fancy:Bool):Void
  {
    Preferences.framerate = fps;
    GoldenSettings.screenShaders = shaders;
    flixel.FlxSprite.defaultAntialiasing = aa;
    Preferences.fancyPreview = fancy;
  }

  /** At startup: re-apply the antialiasing part of the saved preset (the rest is saved by FNF/Golden). */
  public static function applyAtStartup():Void
  {
    flixel.FlxSprite.defaultAntialiasing = GoldenSettings.graphicsPreset != 'low';
  }
}
