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
  var badge:Null<openfl.text.TextField> = null;

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

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    var dev = GoldenSettings.developerMode;
    updateOverlays(dev, elapsed);
    if (!dev) return;

    var state = FlxG.state;
    if (state == null || state.subState != null) return;
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

  function updateOverlays(dev:Bool, elapsed:Float):Void
  {
    var wantMonitor = dev && GoldenSettings.perfMonitor;
    if (wantMonitor && monitor == null)
    {
      monitor = new PerfMonitor();
      monitor.x = 4;
      monitor.y = 4;
      FlxG.stage.addChild(monitor);
    }
    else if (!wantMonitor && monitor != null)
    {
      FlxG.stage.removeChild(monitor);
      monitor = null;
    }
    if (monitor != null)
    {
      // Use real time so the monitor is honest when the game lags or timeScale changes.
      monitor.tick(FlxG.elapsed / Math.max(FlxG.timeScale, 0.0001));
      // Keep the overlay on top if something else was added to the stage later.
      if (FlxG.stage.getChildIndex(monitor) != FlxG.stage.numChildren - 1) FlxG.stage.setChildIndex(monitor, FlxG.stage.numChildren - 1);
    }

    if (dev && badge == null)
    {
      badge = new openfl.text.TextField();
      badge.selectable = badge.mouseEnabled = false;
      badge.defaultTextFormat = new openfl.text.TextFormat('_sans', 11, 0xFFC83D, true);
      badge.text = 'DEV MODE';
      badge.width = badge.textWidth + 8;
      badge.height = badge.textHeight + 4;
      badge.alpha = 0.7;
      FlxG.stage.addChild(badge);
    }
    else if (!dev && badge != null)
    {
      FlxG.stage.removeChild(badge);
      badge = null;
    }
    if (badge != null)
    {
      badge.x = FlxG.stage.stageWidth - badge.width - 6;
      badge.y = FlxG.stage.stageHeight - badge.height - 4;
    }
  }
}
