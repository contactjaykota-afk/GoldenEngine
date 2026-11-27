package funkin.ui.debug.charting.handlers;

#if FEATURE_CHART_EDITOR
import funkin.ui.debug.charting.dialogs.GoldenMidiImportDialog;
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

  public static function setup(state:ChartEditorState):Void
  {
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
    var anchor = state.menubarOpenRecent;
    var index = anchor != null ? fileMenu.getComponentIndex(anchor) + 1 : fileMenu.numComponents;
    fileMenu.addComponentAt(item, index);
  }

  /** Per-frame shortcut handling (called from ChartEditorState.handleFileKeybinds). */
  public static function handleKeybinds(state:ChartEditorState):Void
  {
    if (state.isHaxeUIDialogOpen || golden.input.GoldenInput.isTyping()) return;
    if (FlxG.keys.pressed.CONTROL && FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.M) browseMidi(state);
  }

  public static function browseMidi(state:ChartEditorState):Void
  {
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
