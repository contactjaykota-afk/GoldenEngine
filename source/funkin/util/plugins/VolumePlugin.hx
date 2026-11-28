package funkin.util.plugins;

import flixel.FlxBasic;

/**
 * Handles volume control in a way that is compatible with alternate control schemes.
 */
@:nullSafety
class VolumePlugin extends FlxBasic
{
  public function new()
  {
    super();
  }

  /**
   * Initialize the plugin.
   */
  public static function initialize():Void
  {
    FlxG.plugins.addPlugin(new VolumePlugin());
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    var isHaxeUIFocused:Bool = #if FEATURE_HAXEUI haxe.ui.focus.FocusManager.instance?.focus != null #else false #end;
    // Golden Engine: also ignore volume keys (-, +, 0 by default) while typing in any text field.
    if (golden.input.GoldenInput.isTyping()) isHaxeUIFocused = true;
    // Golden Engine: no volume keys in Golden editors (digits/minus belong to their fields and Ctrl+-/= zoom),
    // and never while Ctrl is held.
    if (Std.isOfType(FlxG.state, golden.editor.GoldenEditorState) || FlxG.keys.pressed.CONTROL) isHaxeUIFocused = true;

    if (!isHaxeUIFocused)
    {
      // Rebindable volume keys.
      if (PlayerSettings.player1.controls.VOLUME_MUTE) FlxG.sound.toggleMuted();
      else if (PlayerSettings.player1.controls.VOLUME_UP) FlxG.sound.changeVolume(0.1);
      else if (PlayerSettings.player1.controls.VOLUME_DOWN) FlxG.sound.changeVolume(-0.1);
    }
  }

  override public function destroy():Void
  {
    if (FlxG.plugins.list.contains(this)) FlxG.plugins.remove(this);

    super.destroy();
  }
}
