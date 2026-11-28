package funkin.ui.debug.charting.handlers;

#if FEATURE_CHART_EDITOR
import funkin.ui.debug.charting.dialogs.GoldenMidiImportDialog;
import funkin.ui.debug.charting.ChartEditorState.ChartEditorTheme;
import funkin.util.FileUtil;
import golden.charting.MidiFile;
import haxe.ui.containers.menus.MenuItem;
import openfl.net.FileFilter;

/**
 * Golden Engine (new file): additions to the upstream Chart Editor, kept in one place so the upstream
 * ChartEditorState only needs a single call (in setupUIListeners).
 *
 * - File > Import MIDI... (Ctrl+Shift+M)
 */
@:access(funkin.ui.debug.charting.ChartEditorState)
class GoldenChartEditorHandler
{
  public static final FILE_FILTER_MIDI:FileFilter = new FileFilter('MIDI File (.mid, .midi)', '*.mid;*.midi');

  static var infoText:Null<flixel.text.FlxText> = null;
  static var infoBg:Null<flixel.FlxSprite> = null;

  /** Golden look: purple menubar with a gold edge, and an info panel (time/step/beat/measure/BPM/snap). */
  static function setupLayout(state:ChartEditorState):Void
  {
    if (state.menubar != null) state.menubar.styleString = 'background-color: #3A2C5C; border-bottom: 2px solid #FFC83D; color: #F4EEDD;';
    infoBg = new flixel.FlxSprite().makeGraphic(250, 118, 0xE0141018);
    infoBg.scrollFactor.set();
    infoText = new flixel.text.FlxText(0, 0, 238, '', 14);
    infoText.setFormat(Paths.font('vcr.ttf'), 14, 0xFFF4EEDD);
    infoText.scrollFactor.set();
    for (s in [infoBg, infoText])
    {
      s.cameras = [state.uiCamera];
      s.zIndex = 9999;
      state.add(s);
    }
  }

  /** Called every frame from handleKeybinds. */
  static function updateInfo(state:ChartEditorState):Void
  {
    if (infoText == null || !infoText.exists) return;
    var c = Conductor.instance;
    var ms = state.scrollPositionInMs + state.playheadPositionInMs;
    var steps = ms / c.stepLengthMs;
    var beats = steps / 4;
    var measure = Math.floor(beats / c.timeSignatureNumerator) + 1;
    var s = Math.floor(ms / 1000);
    infoBg.setPosition(FlxG.width - 262, FlxG.height - 160);
    infoText.setPosition(infoBg.x + 8, infoBg.y + 6);
    infoText.text = 'TIME    ${Std.int(s / 60)}:${StringTools.lpad(Std.string(s % 60), '0', 2)}.${StringTools.lpad(Std.string(Std.int(ms % 1000)), '0', 3)}\n'
      + 'STEP    ${Math.floor(steps)}\nBEAT    ${Math.floor(beats)}\nMEASURE $measure\n'
      + 'BPM     ${Math.round(c.bpm * 100) / 100}   ${c.timeSignatureNumerator}/${c.timeSignatureDenominator}\n'
      + 'SNAP    1/${@:privateAccess state.noteSnapQuant}   E/Q: sustain';
  }

  public static function setup(state:ChartEditorState):Void
  {
    setupLayout(state);
    var fileMenu = state.menubarItemNewChart?.parentComponent;
    if (fileMenu == null)
    {
      trace('[GOLDEN] Chart Editor: File menu not found; MIDI import menu entry not added (Ctrl+Shift+M still works).');
      return;
    }
    var item = new MenuItem();
    item.id = 'menubarItemGoldenImportMidi';
    item.text = 'Import MIDI...';
    item.shortcutText = 'Ctrl+Shift+M';
    item.onClick = _ -> browseMidi(state);
    // After "Open Recent" (or after "Open Chart..." if that is not found); never above "New Chart".
    var index = -1;
    for (anchor in [state.menubarOpenRecent, state.menubarItemOpenChart])
      if (index < 0 && anchor != null && fileMenu.getComponentIndex(anchor) >= 0) index = fileMenu.getComponentIndex(anchor) + 1;
    if (index < 0) index = fileMenu.numComponents;
    fileMenu.addComponentAt(item, index);
    setupThemeMenu(state);
  }

  /** View > Theme > Golden (the Golden Engine default theme). */
  public static function setupThemeMenu(state:ChartEditorState):Void
  {
    var themeMenu = state.menuBarItemThemeDark?.parentComponent;
    if (themeMenu == null) return;
    var golden = new haxe.ui.containers.menus.MenuOptionBox();
    golden.id = 'menuBarItemThemeGolden';
    golden.text = 'Golden';
    golden.componentGroup = 'menubarItemThemeGroup';
    golden.onChange = function(event)
    {
      if (event.target.value) state.currentTheme = ChartEditorTheme.Golden;
    };
    themeMenu.addComponent(golden);
    golden.selected = state.currentTheme == ChartEditorTheme.Golden;
  }

  /** Per-frame shortcut handling (called from ChartEditorState.handleFileKeybinds). */
  static var sustainRepeat:Float = 0;

  /**
   * Sustain keys (Golden Engine): E = extend the selected notes' sustain by one snap step (hold E to keep
   * extending), Shift+E = extend by one beat, Q = shorten by one snap step (hold to repeat; never below
   * zero). Ignored while typing, in dialogs and with Ctrl (Ctrl+Q stays "quit").
   */
  static function handleSustainKeys(state:ChartEditorState):Void
  {
    var e = FlxG.keys.pressed.E, q = FlxG.keys.pressed.Q;
    if (!e && !q)
    {
      sustainRepeat = 0;
      return;
    }
    if (FlxG.keys.pressed.CONTROL || state.isHaxeUIDialogOpen || golden.input.GoldenInput.isTyping()) return;
    var first = FlxG.keys.justPressed.E || FlxG.keys.justPressed.Q;
    if (!first)
    {
      sustainRepeat += FlxG.elapsed;
      if (sustainRepeat < 0.32) return; // initial hold delay, then repeat every 80 ms
      sustainRepeat -= 0.08;
    }
    var sel = state.currentNoteSelection;
    if (sel.length == 0)
    {
      if (first) trace('[GOLDEN] Chart Editor: select notes first (E/Q change the sustain of selected notes)');
      return;
    }
    @:privateAccess var snapMs:Float = Conductor.instance.stepLengthMs * state.noteSnapRatio;
    var delta = e ? (FlxG.keys.pressed.SHIFT ? Conductor.instance.beatLengthMs : snapMs) : -snapMs;
    var cmd = new funkin.ui.debug.charting.commands.GoldenSustainCommand(sel, delta);
    if (!cmd.shouldAddToHistory(state)) return;
    state.performCommand(cmd);
    trace('[GOLDEN] Chart Editor: sustain ${delta > 0 ? "+" : ""}${Math.round(delta)} ms on ${sel.length} note(s) -> ${Math.round(sel[0].length)} ms');
  }

  public static function handleKeybinds(state:ChartEditorState):Void
  {
    updateInfo(state);
    handleSustainKeys(state);
    if (!(FlxG.keys.pressed.CONTROL && FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.M)) return;
    if (state.isHaxeUIDialogOpen || golden.input.GoldenInput.isTyping())
    {
      trace('[GOLDEN] Chart Editor: Ctrl+Shift+M ignored (dialog open: ${state.isHaxeUIDialogOpen}, focus: ${golden.input.GoldenInput.typingReason()})');
      return;
    }
    browseMidi(state);
  }

  public static function browseMidi(state:ChartEditorState):Void
  {
    trace('[GOLDEN] Chart Editor: opening MIDI file dialog');
    FileUtil.browseForFile('Import MIDI file', [FILE_FILTER_MIDI], function(file)
    {
      importMidiBytes(state, file.bytes, file.name);
    }, function() trace('[GOLDEN] MIDI import cancelled'));
  }

  public static function importMidiBytes(state:ChartEditorState, bytes:haxe.io.Bytes, name:String):Void
  {
    var midi:MidiFile;
    try
    {
      midi = MidiFile.parse(bytes);
    }
    catch (e:Dynamic)
    {
      trace('[GOLDEN] MIDI import failed for $name: $e');
      state.error('MIDI Import Failed', Std.string(e));
      return;
    }
    var noteCount = 0;
    for (t in midi.tracks)
      noteCount += t.notes.length;
    if (noteCount == 0)
    {
      state.warning('MIDI Import', '$name contains no notes.');
      return;
    }
    trace('[GOLDEN] MIDI parsed: $name, ${midi.tracks.length} tracks, $noteCount notes');
    GoldenMidiImportDialog.open(state, midi, name);
  }
}
#end
