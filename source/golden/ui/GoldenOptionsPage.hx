package golden.ui;

import flixel.FlxSprite;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.ui.Page;
import funkin.ui.options.OptionsState.OptionsMenuPageName;
import golden.audio.UISound;

/**
 * Options > Golden Engine. Every row changes a real setting in `GoldenSettings` (saved immediately).
 *
 * Up/Down select · Left/Right change · Accept toggles / starts rebinding / runs the action · Back leaves.
 * Mouse: click a row to select it, click again (or wheel) to change it.
 */
class GoldenOptionsPage extends Page<OptionsMenuPageName>
{
  var rows:Array<{label:String, desc:String, value:Void->String, change:Int->Void, accept:Void->Void}> = [];
  var texts:Array<FlxText> = [];
  var valueTexts:Array<FlxText> = [];
  var cursor:FlxSprite;
  var descText:FlxText;
  var selected:Int = 0;
  var rebinding:Null<String> = null; // 'chart' | 'mods'
  var confirmReset:Bool = false;

  public function new()
  {
    super();

    rows.push({
      label: 'Developer Mode',
      desc: 'Unlocks the editors, debug shortcuts (Chart Editor key, Tab mod selector) and the performance monitor. Off by default.',
      value: () -> GoldenSettings.developerMode ? 'ON' : 'OFF',
      change: (_) -> toggleDev(),
      accept: toggleDev
    });
    rows.push({
      label: 'UI Volume',
      desc: 'Volume of menu sounds (hover, scroll, select, back...). Separate from music and gameplay volume.',
      value: () -> Math.round(GoldenSettings.uiVolume * 100) + '%',
      change: (d) -> {
        GoldenSettings.uiVolume = Math.round((GoldenSettings.uiVolume + d * 0.1) * 10) / 10;
        UISound.play(Slider);
      },
      accept: () -> {}
    });
    rows.push({
      label: 'Performance Monitor',
      desc: 'Shows FPS, frame time, RAM (current/peak), state, song, difficulty, BPM and position. Needs Developer Mode.',
      value: () -> GoldenSettings.perfMonitor ? 'ON' : 'OFF',
      change: (_) -> togglePerf(),
      accept: togglePerf
    });
    rows.push({
      label: 'Chart Editor Key',
      desc: 'Developer Mode shortcut that opens the Chart Editor (during a song it opens the current chart). Accept, then press a key.',
      value: () -> rebinding == 'chart' ? '[press a key]' : GoldenSettings.chartEditorKey,
      change: (_) -> {},
      accept: () -> startRebind('chart')
    });
    rows.push({
      label: 'Mod Selector Key',
      desc: 'Developer Mode shortcut that opens the quick mod selector. Accept, then press a key.',
      value: () -> rebinding == 'mods' ? '[press a key]' : GoldenSettings.modSelectorKey,
      change: (_) -> {},
      accept: () -> startRebind('mods')
    });
    rows.push({
      label: 'Reset Developer Settings',
      desc: 'Turns Developer Mode and the monitor off and restores the default shortcuts (7 and Tab).',
      value: () -> confirmReset ? 'press again to confirm' : '',
      change: (_) -> {},
      accept: resetDev
    });

    var top = 120;
    add(GoldenUI.text(80, 40, 800, 'GOLDEN ENGINE', 40, GoldenUI.GOLD));
    cursor = new FlxSprite(60, top).makeGraphic(FlxG.width - 120, 52, GoldenUI.GOLD_DARK);
    cursor.scrollFactor.set();
    add(cursor);
    for (i in 0...rows.length)
    {
      var t = GoldenUI.text(80, top + i * 64 + 12, 600, rows[i].label, 26);
      var v = GoldenUI.text(FlxG.width - 580, top + i * 64 + 12, 500, '', 26, GoldenUI.GOLD);
      v.alignment = RIGHT;
      texts.push(t);
      valueTexts.push(v);
      add(t);
      add(v);
    }
    descText = GoldenUI.text(80, FlxG.height - 120, FlxG.width - 160, '', 18, GoldenUI.TEXT);
    add(descText);
    if (GoldenSettings.loadError != null) descText.text = GoldenSettings.loadError;
    refresh();
  }

  function toggleDev():Void
  {
    GoldenSettings.developerMode = !GoldenSettings.developerMode;
    trace('[GOLDEN] Options: Developer Mode -> ${GoldenSettings.developerMode} (frame ${FlxG.game.ticks})');
    UISound.play(Toggle);
  }

  function togglePerf():Void
  {
    GoldenSettings.perfMonitor = !GoldenSettings.perfMonitor;
    trace('[GOLDEN] Options: Performance Monitor -> ${GoldenSettings.perfMonitor} (frame ${FlxG.game.ticks})');
    UISound.play(Toggle);
    if (GoldenSettings.perfMonitor && !GoldenSettings.developerMode) descText.text = 'Enabled — it becomes visible when Developer Mode is ON.';
  }

  function startRebind(which:String):Void
  {
    rebinding = which;
    UISound.play(Open);
  }

  function resetDev():Void
  {
    if (!confirmReset)
    {
      confirmReset = true;
      UISound.play(Select);
      return;
    }
    confirmReset = false;
    GoldenSettings.resetDeveloperSettings();
    UISound.play(Toggle);
  }

  function refresh():Void
  {
    for (i in 0...rows.length)
    {
      valueTexts[i].text = rows[i].value();
      texts[i].color = i == selected ? FlxColor.WHITE : GoldenUI.TEXT;
    }
    cursor.y = 120 + selected * 64;
    if (descText.text == '' || descText.text.indexOf('Enabled —') < 0) descText.text = rows[selected].desc;
  }

  override function updateEnabled(elapsed:Float):Void
  {
    if (rebinding != null)
    {
      var key:FlxKey = FlxG.keys.firstJustPressed();
      if (key != FlxKey.NONE)
      {
        if (key == FlxKey.ESCAPE) UISound.play(Back);
        else
        {
          var name = key.toString();
          if (rebinding == 'chart') GoldenSettings.chartEditorKey = name;
          else
            GoldenSettings.modSelectorKey = name;
          UISound.play(Select);
        }
        rebinding = null;
        refresh();
      }
      return; // do not let Back/Accept act while rebinding
    }

    var moved = 0;
    if (controls.UI_UP_P) moved = -1;
    if (controls.UI_DOWN_P) moved = 1;
    if (moved != 0)
    {
      selected = (selected + moved + rows.length) % rows.length;
      confirmReset = false;
      descText.text = '';
      UISound.play(Scroll);
    }
    if (controls.UI_LEFT_P) rows[selected].change(-1);
    if (controls.UI_RIGHT_P) rows[selected].change(1);
    if (controls.ACCEPT_P) rows[selected].accept();

    if (FlxG.mouse.justReleased) for (i in 0...rows.length)
    {
      if (FlxG.mouse.screenY >= 120 + i * 64 && FlxG.mouse.screenY < 120 + i * 64 + 52)
      {
        if (i == selected) rows[i].accept();
        else
        {
          selected = i;
          descText.text = '';
          UISound.play(Scroll);
        }
      }
    }
    if (FlxG.mouse.wheel != 0) rows[selected].change(FlxG.mouse.wheel > 0 ? 1 : -1);

    refresh();
    super.updateEnabled(elapsed); // Back exits the page
  }
}
