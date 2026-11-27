package funkin.ui.debug.charting.commands;

#if FEATURE_CHART_EDITOR
import funkin.data.song.SongData.SongNoteData;
import funkin.data.song.SongData.SongTimeChange;
import funkin.ui.debug.charting.toolboxes.ChartEditorMetadataToolbox;

/**
 * Golden Engine (new file): applies a MIDI import to the current difficulty as ONE undoable step.
 * Optionally replaces the existing notes and/or the song's BPM changes. Imported notes are normal
 * SongNoteData, editable like any other note.
 */
@:nullSafety @:access(funkin.ui.debug.charting.ChartEditorState)
class GoldenMidiImportCommand implements ChartEditorCommand
{
  var notes:Array<SongNoteData>;
  var timeChanges:Null<Array<SongTimeChange>>;
  var replaceNotes:Bool;

  var previousNotes:Array<SongNoteData> = [];
  var previousTimeChanges:Array<SongTimeChange> = [];

  public function new(notes:Array<SongNoteData>, timeChanges:Null<Array<SongTimeChange>>, replaceNotes:Bool)
  {
    this.notes = notes;
    this.timeChanges = timeChanges;
    this.replaceNotes = replaceNotes;
  }

  public function execute(state:ChartEditorState):Void
  {
    previousNotes = state.currentSongChartNoteData.copy();
    previousTimeChanges = state.currentSongMetadata.timeChanges.copy();

    var newNotes = replaceNotes ? [] : state.currentSongChartNoteData.copy();
    for (n in notes)
      newNotes.push(n);
    state.currentSongChartNoteData = newNotes;
    if (timeChanges != null && timeChanges.length > 0) applyTimeChanges(state, timeChanges);

    state.currentNoteSelection = notes.copy();
    state.currentEventSelection = [];
    markDirty(state);
  }

  public function undo(state:ChartEditorState):Void
  {
    state.currentSongChartNoteData = previousNotes.copy();
    if (timeChanges != null && timeChanges.length > 0) applyTimeChanges(state, previousTimeChanges);
    state.currentNoteSelection = [];
    state.currentEventSelection = [];
    state.playSound(Paths.sound('chartingSounds/undo'));
    markDirty(state);
  }

  static function applyTimeChanges(state:ChartEditorState, changes:Array<SongTimeChange>):Void
  {
    state.currentSongMetadata.timeChanges = changes.copy();
    Conductor.instance.mapTimeChanges(state.currentSongMetadata.timeChanges);
    var metadataToolbox:Null<ChartEditorMetadataToolbox> = cast state.getToolbox(ChartEditorState.CHART_EDITOR_TOOLBOX_METADATA_LAYOUT);
    if (metadataToolbox != null) metadataToolbox.refreshTimeChangeInputs();
    state.notePreviewViewportBoundsDirty = true;
    state.updateSongTime();
    state.updateGridHeight();
    state.updateTimeSignature();
  }

  static function markDirty(state:ChartEditorState):Void
  {
    state.saveDataDirty = true;
    state.noteDisplayDirty = true;
    state.notePreviewDirty = true;
    state.editButtonsDirty = true;
    state.sortChartData();
  }

  public function shouldAddToHistory(state:ChartEditorState):Bool
  {
    return notes.length > 0 || (timeChanges != null && timeChanges.length > 0);
  }

  public function toString():String
  {
    return 'Import ${notes.length} MIDI Notes';
  }
}
#end
