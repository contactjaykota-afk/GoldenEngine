package golden.dev;

import flixel.FlxBasic;
import funkin.play.PlayState;
import golden.input.GoldenInput;

/**
 * Golden Engine Developer Mode runtime: a Flixel plugin that is always alive but does nothing
 * unless `GoldenSettings.developerMode` is on.
 *
 * - Performance monitor overlay (when enabled in Options > Golden Engine).
 * - "DEV MODE" badge so it is always visible that Developer Mode is active.
 * - Chart Editor shortcut (default 7) outside gameplay; in gameplay PlayState handles the same key
 *   so it can open the current chart at the current position.
 * - Mod selector shortcut (default Tab) in menus.
 *
 * Shortcuts never fire while a text field has focus, while a substate (dialog/pause) is open, or
 * in states where switching away could lose work (editors, gameplay).
 */
class GoldenDevTools extends FlxBasic
{
  public static var instance(default, null):Null<GoldenDevTools> = null;

  var monitor:Null<PerfMonitor> = null;
  var badge:Null<flixel.text.FlxText> = null;
  var console:Null<GoldenConsole.GoldenConsoleOverlay> = null;

  /** Camera the overlays draw on; kept last in FlxG.cameras so it renders above every state camera. */
  var overlayCam:Null<flixel.FlxCamera> = null;

  public static function init():Void
  {
    if (instance != null) return;
    instance = new GoldenDevTools();
    FlxG.plugins.addPlugin(instance);
    trace('[GOLDEN] Developer tools plugin ready (developerMode=${GoldenSettings.developerMode})');
  }

  function new()
  {
    super();
  }

  /** True while the console's filter field has focus (other dev shortcuts must not fire). */
  public static function consoleTyping():Bool
    return instance?.console?.filter?.hasFocus == true;

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    var dev = GoldenSettings.developerMode;
    updateOverlays(dev);
    updateConsole(dev);
    golden.studio.GoldenStudio.update(); // Play-in-Editor: F9 returns to the Studio
    if (!dev) return;

    var state = FlxG.state;
    if (state == null || state.subState != null || console != null) return;
    if (!isMenuState(state)) return;

    #if FEATURE_CHART_EDITOR
    if (GoldenInput.shortcutPressed(GoldenSettings.chartEditorKey))
    {
      trace('[GOLDEN] Chart Editor shortcut (${GoldenSettings.chartEditorKey})');
      FlxG.switchState(() -> new funkin.ui.debug.charting.ChartEditorState());
      return;
    }
    #end
    if (GoldenInput.shortcutPressed(GoldenSettings.modSelectorKey))
    {
      trace('[GOLDEN] Mod selector shortcut (${GoldenSettings.modSelectorKey})');
      state.openSubState(new golden.ui.ModSelectorSubState());
    }
  }

  override function draw():Void
  {
    if (monitor == null && badge == null && console == null) return;
    var cam = ensureCamera();
    var overlays:Array<flixel.FlxSprite> = [monitor, badge, console];
    for (o in overlays)
    {
      if (o == null) continue;
      o.cameras = [cam];
      o.draw();
    }
  }

  function ensureCamera():flixel.FlxCamera
  {
    if (overlayCam == null || !overlayCam.exists || !FlxG.cameras.list.contains(overlayCam))
    {
      overlayCam = new flixel.FlxCamera();
      overlayCam.bgColor = 0x00000000;
      FlxG.cameras.add(overlayCam, false);
    }
    else if (FlxG.cameras.list[FlxG.cameras.list.length - 1] != overlayCam)
    {
      // A state added cameras after ours: move ours back on top.
      FlxG.cameras.remove(overlayCam, false);
      FlxG.cameras.add(overlayCam, false);
    }
    return overlayCam;
  }

  /** F8 toggles the runtime console (any state, Developer Mode only). */
  function updateConsole(dev:Bool):Void
  {
    if ((!dev || FlxG.keys.justPressed.F8) && console != null)
    {
      console.filter.endFocus();
      console.destroy();
      console = null;
      trace('[GOLDEN] Console closed');
      return;
    }
    if (dev && console == null && FlxG.keys.justPressed.F8)
    {
      console = new GoldenConsole.GoldenConsoleOverlay();
      trace('[GOLDEN] Console opened (${GoldenConsole.entries.length} lines)');
    }
    if (console != null)
    {
      console.cameras = [ensureCamera()];
      console.update(FlxG.elapsed);
    }
  }

  /** States where global dev shortcuts are allowed: menus, not gameplay or editors. */
  static function isMenuState(state:flixel.FlxState):Bool
  {
    if (Std.isOfType(state, PlayState)) return false;
    var name = Type.getClassName(Type.getClass(state));
    if (name.indexOf('.debug.') >= 0) return false; // chart/stage/animation editors and debug states
    if (name.indexOf('ModManagerState') >= 0) return false;
    if (name.indexOf('TitleState') >= 0 || name.indexOf('InitState') >= 0) return false;
    return true;
  }

  function updateOverlays(dev:Bool):Void
  {
    var wantMonitor = dev && GoldenSettings.perfMonitor;
    if (wantMonitor && monitor == null) monitor = new PerfMonitor();
    else if (!wantMonitor && monitor != null)
    {
      monitor.destroy();
      monitor = null;
    }
    // Real time, so the monitor is honest when timeScale changes.
    if (monitor != null) monitor.tick(FlxG.elapsed / Math.max(FlxG.timeScale, 0.0001));

    if (dev && badge == null)
    {
      badge = new flixel.text.FlxText(0, 0, 0, 'DEV MODE', 12);
      badge.setFormat(Paths.font('vcr.ttf'), 12, 0xFFFFC83D, RIGHT);
      badge.alpha = 0.75;
      badge.x = FlxG.width - badge.width - 6;
      badge.y = FlxG.height - badge.height - 4;
      badge.scrollFactor.set();
    }
    else if (!dev && badge != null)
    {
      badge.destroy();
      badge = null;
    }
  }
}
