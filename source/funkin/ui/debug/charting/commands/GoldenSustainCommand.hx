package funkin.ui.debug.charting.commands;

#if FEATURE_CHART_EDITOR
import funkin.data.song.SongData.SongNoteData;

/**
 * Golden Engine: change the sustain (hold) length of several notes at once (E / Q keys), as one undo
 * step. Lengths never go below zero.
 */
@:access(funkin.ui.debug.charting.ChartEditorState)
class GoldenSustainCommand implements ChartEditorCommand
{
  var notes:Array<SongNoteData>;
  var oldLengths:Array<Float>;
  var delta:Float;

  public function new(notes:Array<SongNoteData>, delta:Float)
  {
    this.notes = notes.copy();
    this.oldLengths = [for (n in notes) n.length];
    this.delta = delta;
  }

  public function execute(state:ChartEditorState):Void
  {
    for (i in 0...notes.length)
      notes[i].length = Math.max(0, oldLengths[i] + delta);
    dirty(state);
  }

  public function undo(state:ChartEditorState):Void
  {
    state.playSound(Paths.sound('chartingSounds/undo'));
    for (i in 0...notes.length)
      notes[i].length = oldLengths[i];
    dirty(state);
  }

  static function dirty(state:ChartEditorState):Void
  {
    state.saveDataDirty = true;
    state.noteDisplayDirty = true;
    state.notePreviewDirty = true;
    state.sortChartData();
  }

  public function shouldAddToHistory(state:ChartEditorState):Bool
  {
    for (i in 0...notes.length)
      if (Math.max(0, oldLengths[i] + delta) != oldLengths[i]) return true;
    return false;
  }

  public function toString():String
    return delta >= 0 ? 'Extend Sustain (${notes.length} notes)' : 'Shorten Sustain (${notes.length} notes)';
}
#end
