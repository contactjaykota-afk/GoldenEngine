package golden.input;

import flixel.input.keyboard.FlxKey;

/**
 * Golden Engine — shared input helpers so global shortcuts never fire while the user is typing.
 */
class GoldenInput
{
  /** True while any text field (Flixel input text, HaxeUI field, or OpenFL TextField) has keyboard focus. */
  public static function isTyping():Bool
  {
    if (flixel.text.FlxInputText.globalManager?.isTyping == true) return true;
    if (golden.dev.GoldenDevTools.consoleTyping()) return true;
    #if FEATURE_HAXEUI
    var f = haxe.ui.focus.FocusManager.instance?.focus;
    if (f != null && (Std.isOfType(f, haxe.ui.components.TextField) || Std.isOfType(f, haxe.ui.components.TextArea)
      || Std.isOfType(f, haxe.ui.components.NumberStepper))) return true;
    #end
    var stageFocus = FlxG.stage?.focus;
    if (stageFocus != null && Std.isOfType(stageFocus, openfl.text.TextField)
      && (cast stageFocus : openfl.text.TextField).type == openfl.text.TextFieldType.INPUT) return true;
    return false;
  }

  /**
   * True if `keyName` is bound to one of the player's note controls (then it must not act as a
   * shortcut during gameplay).
   */
  public static function isNoteKey(keyName:String):Bool
  {
    var key:FlxKey = FlxKey.fromString(keyName);
    var controls = funkin.PlayerSettings.player1?.controls;
    if (controls == null) return false;
    for (action in [funkin.input.Controls.Action.NOTE_LEFT, funkin.input.Controls.Action.NOTE_DOWN, funkin.input.Controls.Action.NOTE_UP,
      funkin.input.Controls.Action.NOTE_RIGHT])
      if (controls.getKeysForAction(action).contains(key)) return true;
    return false;
  }

  /** Whether the key named `keyName` (FlxKey name, e.g. "SEVEN", "TAB") was just pressed, and nobody is typing. */
  public static function shortcutPressed(keyName:String):Bool
  {
    var key:FlxKey = FlxKey.fromString(keyName);
    if (key == FlxKey.NONE) return false;
    if (!FlxG.keys.checkStatus(key, JUST_PRESSED)) return false;
    if (isTyping())
    {
      trace('[GOLDEN] Shortcut $keyName ignored: a text field has focus (${typingReason()})');
      return false;
    }
    return true;
  }

  /** Which kind of text field currently has focus (for diagnostics). */
  public static function typingReason():String
  {
    if (flixel.text.FlxInputText.globalManager?.isTyping == true) return 'Flixel input text';
    if (golden.dev.GoldenDevTools.consoleTyping()) return 'console filter';
    #if FEATURE_HAXEUI
    var f = haxe.ui.focus.FocusManager.instance?.focus;
    if (f != null) return 'HaxeUI ' + Type.getClassName(Type.getClass(f));
    #end
    var stageFocus = FlxG.stage?.focus;
    if (stageFocus != null) return 'OpenFL ' + Type.getClassName(Type.getClass(stageFocus));
    return 'none';
  }
}
