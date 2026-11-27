package golden.ui;

import flixel.input.gamepad.FlxGamepadInputID;
import funkin.ui.MusicBeatSubState;

/**
 * Base for Golden overlays opened on top of upstream states. `close()` is deferred until every key,
 * mouse button and gamepad button is released: FNF's controls report a press to the parent state the
 * next time it checks, so closing on Esc/Enter "press" would otherwise also trigger the parent's
 * Back/Accept (e.g. the main menu jumping back to the title screen).
 * Input is also ignored on the overlay's first frame, so the key that opened it (e.g. Tab) is not
 * read again as "close".
 * Subclasses must `if (inputBlocked()) return;` right after `super.update(elapsed)`.
 */
class GoldenSubState extends MusicBeatSubState
{
  var closing:Bool = false;
  var framesAlive:Int = 0;
  var parentPersistentUpdate:Null<Bool> = null;

  override function create():Void
  {
    super.create();
    // Some upstream states (e.g. MainMenuState) keep updating under substates; they must not react to
    // input meant for this overlay. Restored when the overlay closes.
    @:privateAccess var parent = this._parentState;
    if (parent != null)
    {
      parentPersistentUpdate = parent.persistentUpdate;
      parent.persistentUpdate = false;
    }
  }

  function restoreParent():Void
  {
    @:privateAccess var parent = this._parentState;
    if (parent != null && parentPersistentUpdate != null) parent.persistentUpdate = parentPersistentUpdate;
    parentPersistentUpdate = null;
  }

  /** True while closing, and on the first frame (the opening key press must not act again). */
  function inputBlocked():Bool
    return closing || framesAlive <= 1;

  public static function anyInputHeld():Bool
  {
    return FlxG.keys.pressed.ANY || FlxG.mouse.pressed || FlxG.gamepads.anyPressed(FlxGamepadInputID.ANY);
  }

  override function close():Void
  {
    if (anyInputHeld())
    {
      closing = true;
      return;
    }
    closing = false;
    restoreParent();
    super.close();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    framesAlive++;
    // FNF's FunkinActions only advance their pressed/released state when polled and the control set is
    // shared with the parent state, so keep polling while waiting; otherwise the parent later reads a
    // stale "just pressed".
    if (closing) for (_ in [controls.BACK_P, controls.ACCEPT_P, controls.UI_UP_P, controls.UI_DOWN_P, controls.UI_LEFT_P, controls.UI_RIGHT_P]) {}
    if (closing && !anyInputHeld())
    {
      closing = false;
      restoreParent();
      super.close();
    }
  }
}
