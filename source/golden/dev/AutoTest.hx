package golden.dev;

import flixel.FlxBasic;
import openfl.events.KeyboardEvent;
import openfl.ui.Keyboard;

private enum Step
{
  WaitState(name:String, timeout:Float);
  WaitStateOptional(name:String, timeout:Float); // like WaitState, but timing out is not a failure
  Delay(seconds:Float);
  Press(keyCode:Int);
  PressIf(state:String, keyCode:Int); // only if the current state is `state`
  Log(message:String);
  PlaySong(songId:String, difficulty:String);
  ExpectState(name:String); // fail if the current state is not `name`
}

/**
 * Golden Engine — scripted smoke test driven from INSIDE the game, for CI machines that cannot inject
 * OS keyboard input (e.g. GitHub-hosted Windows runners). Only active when the environment variable
 * `GOLDEN_AUTOTEST=play` or `=mods` is set; normal players never run it.
 *
 * It dispatches real OpenFL KeyboardEvents to the stage, so the game's own input handling (Flixel
 * keyboard, FNF controls, menus) processes them exactly like key presses; only the operating-system
 * keyboard layer is bypassed. Every step is logged as "[GOLDEN AUTOTEST] ...".
 *
 * Routes (GOLDEN_AUTOTEST=...): "play" = title -> main menu -> Bopeebo (started through the Golden song
 *   launcher used by Play-in-Editor, practice mode) plays for 15 s;
 * "mods" = title -> main menu -> Mod Manager -> Esc back to the main menu.
 */
class AutoTest extends FlxBasic
{
  var steps:Array<Step> = [];
  var timer:Float = 0;
  var waited:Float = 0;
  var pendingUp:Array<{code:Int, frames:Int}> = [];

  public static function initIfRequested():Void
  {
    #if sys
    var route = Sys.getEnv('GOLDEN_AUTOTEST');
    if (route != 'play' && route != 'mods') return;
    FlxG.plugins.addPlugin(new AutoTest(route));
    trace('[GOLDEN AUTOTEST] enabled (route: $route)');
    #end
  }

  function new(route:String)
  {
    super();
    steps = [
      WaitState('TitleState', 180), Delay(20),
      // One Enter normally leaves the title; on slow machines the state switch can take seconds, so only
      // press again if the title is still there after waiting.
      Press(Keyboard.ENTER), WaitStateOptional('MainMenuState', 8), PressIf('TitleState', Keyboard.ENTER),
      WaitState('MainMenuState', 30), Log('main menu reached'), Delay(7)
    ];
    if (route == 'mods') steps = steps.concat([
      Press(Keyboard.DOWN), Delay(0.5), Press(Keyboard.DOWN), Delay(0.5), Press(Keyboard.ENTER),
      WaitState('ModManagerState', 30), Log('mod manager reached'), Delay(3),
      Press(Keyboard.ESCAPE),
      WaitState('MainMenuState', 30), Log('back at main menu'), Delay(5),
      ExpectState('MainMenuState'), // regression: Esc from the Mod Manager must not continue to the title screen
      Log('done')
    ]);
    else steps = steps.concat([
      PlaySong('bopeebo', 'normal'),
      WaitState('PlayState', 90), Log('gameplay reached'), Delay(15),
      Log('done')
    ]);
  }

  function stateName():String
  {
    var s = FlxG.state;
    return s == null ? '' : Type.getClassName(Type.getClass(s)).split('.').pop();
  }

  function key(type:String, code:Int):Void
  {
    FlxG.stage.dispatchEvent(new KeyboardEvent(type, true, false, 0, code));
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    // Release keys a few frames after pressing them, so "just pressed" is seen for one frame.
    for (p in pendingUp.copy())
      if (--p.frames <= 0)
      {
        key(KeyboardEvent.KEY_UP, p.code);
        pendingUp.remove(p);
      }
    if (steps.length == 0) return;
    var dt = FlxG.elapsed / Math.max(FlxG.timeScale, 0.0001);
    switch (steps[0])
    {
      case WaitState(name, timeout):
        waited += dt;
        if (stateName() == name)
        {
          trace('[GOLDEN AUTOTEST] state $name reached after ${Math.round(waited * 10) / 10}s');
          next();
        }
        else if (waited > timeout)
        {
          trace('[GOLDEN AUTOTEST] FAILED waiting for $name (current: ${stateName()})');
          steps = [];
        }
      case WaitStateOptional(name, timeout):
        waited += dt;
        if (stateName() == name || waited > timeout) next();
      case Delay(seconds):
        timer += dt;
        if (timer >= seconds) next();
      case Press(code):
        key(KeyboardEvent.KEY_DOWN, code);
        pendingUp.push({code: code, frames: 4});
        trace('[GOLDEN AUTOTEST] key $code in ${stateName()}');
        next();
      case PressIf(state, code):
        if (stateName() == state)
        {
          key(KeyboardEvent.KEY_DOWN, code);
          pendingUp.push({code: code, frames: 4});
          trace('[GOLDEN AUTOTEST] key $code in ${stateName()}');
        }
        next();
      case PlaySong(songId, difficulty):
        trace('[GOLDEN AUTOTEST] starting $songId ($difficulty)');
        var err = golden.studio.GoldenStudio.playSong(songId, difficulty);
        if (err != null)
        {
          trace('[GOLDEN AUTOTEST] FAILED: $err');
          steps = [];
          return;
        }
        next();
      case ExpectState(name):
        if (stateName() != name)
        {
          trace('[GOLDEN AUTOTEST] FAILED: expected $name, but the game is in ${stateName()}');
          steps = [];
          return;
        }
        trace('[GOLDEN AUTOTEST] still in $name (ok)');
        next();
      case Log(message):
        trace('[GOLDEN AUTOTEST] $message');
        next();
    }
  }

  function next():Void
  {
    steps.shift();
    timer = 0;
    waited = 0;
  }
}
