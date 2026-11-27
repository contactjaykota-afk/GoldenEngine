package funkin.ui.debug.charting.dialogs;

#if FEATURE_CHART_EDITOR
import funkin.data.song.SongData.SongNoteData;
import funkin.data.song.SongData.SongTimeChange;
import funkin.ui.debug.charting.commands.GoldenMidiImportCommand;
import golden.charting.MidiFile;
import golden.charting.MidiImport;
import haxe.ui.components.Button;
import haxe.ui.components.CheckBox;
import haxe.ui.components.DropDown;
import haxe.ui.components.Label;
import haxe.ui.components.NumberStepper;
import haxe.ui.containers.HBox;
import haxe.ui.containers.ScrollView;
import haxe.ui.containers.VBox;
import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.data.ArrayDataSource;

/**
 * Golden Engine (new file): MIDI import dialog for the Chart Editor (File > Import MIDI...).
 *
 * Lists every MIDI track (name, note count, pitch range) with a target (Skip / Player / Opponent)
 * and a lane mapping (key mod 4, or pitch bands). Options: minimum sustain, offsetStepper, replace or merge
 * notes, import BPM/time-signature changes. A live preview line shows what will be imported.
 * Import applies everything as one undoable command; Cancel changes nothing.
 * Reminder shown in the dialog: MIDI files contain no audio — load the instrumental separately.
 */
@:access(funkin.ui.debug.charting.ChartEditorState)
class GoldenMidiImportDialog extends Dialog
{
  var editor:ChartEditorState;
  var midi:MidiFile;
  var fileName:String;
  var targets:Array<DropDown> = [];
  var laneModes:Array<DropDown> = [];
  var minSustain:NumberStepper;
  var offsetStepper:NumberStepper;
  var replaceNotes:CheckBox;
  var importTempo:CheckBox;
  var preview:Label;

  static final TARGET_VALUES:Array<MidiTarget> = [Skip, Player, Opponent];
  static final LANE_VALUES:Array<LaneMode> = [Modulo4, PitchBands];

  public static function open(editor:ChartEditorState, midi:MidiFile, fileName:String):GoldenMidiImportDialog
  {
    var d = new GoldenMidiImportDialog(editor, midi, fileName);
    d.zIndex = 1000;
    editor.isHaxeUIDialogOpen = true;
    d.showDialog(true);
    return d;
  }

  function new(editor:ChartEditorState, midi:MidiFile, fileName:String)
  {
    super();
    this.editor = editor;
    this.midi = midi;
    this.fileName = fileName;
    title = 'Import MIDI: $fileName';
    width = 760;
    destroyOnClose = true;
    closable = true;
    onDialogClosed = _ -> editor.isHaxeUIDialogOpen = false;

    var root = new VBox();
    root.percentWidth = 100;

    var info = new Label();
    info.text = 'Format ${midi.format}, ${midi.ticksPerQuarter} ticks/quarter, ${midi.tempos.length} tempo change(s). '
      + 'Importing into difficulty "${editor.selectedDifficulty}" (${editor.selectedVariation}).\n'
      + 'MIDI files contain no audio: load the instrumental/vocals separately (Audio menu).';
    info.percentWidth = 100;
    root.addComponent(info);

    var scroll = new ScrollView();
    scroll.percentWidth = 100;
    scroll.height = 260;
    var list = new VBox();
    list.percentWidth = 100;
    var suggestions = MidiImport.suggestMappings(midi);
    for (i in 0...midi.tracks.length)
    {
      var t = midi.tracks[i];
      var row = new HBox();
      row.percentWidth = 100;
      var label = new Label();
      label.width = 330;
      if (t.notes.length > 0)
      {
        var lo = 127, hi = 0;
        for (n in t.notes)
        {
          lo = Std.int(Math.min(lo, n.key));
          hi = Std.int(Math.max(hi, n.key));
        }
        label.text = '${i + 1}. ${t.name} — ${t.notes.length} notes (${noteName(lo)}–${noteName(hi)})';
      }
      else
        label.text = '${i + 1}. ${t.name} — no notes';
      row.addComponent(label);

      var target = new DropDown();
      target.width = 130;
      target.dataSource = ArrayDataSource.fromArray([{text: 'Skip'}, {text: 'Player'}, {text: 'Opponent'}]);
      target.selectedIndex = TARGET_VALUES.indexOf(suggestions[i].target);
      target.disabled = t.notes.length == 0;
      target.onChange = _ -> updatePreview();
      targets.push(target);
      row.addComponent(target);

      var lanes = new DropDown();
      lanes.width = 190;
      lanes.dataSource = ArrayDataSource.fromArray([{text: 'Lanes: key mod 4'}, {text: 'Lanes: pitch bands'}]);
      lanes.selectedIndex = 0;
      lanes.disabled = t.notes.length == 0;
      lanes.onChange = _ -> updatePreview();
      laneModes.push(lanes);
      row.addComponent(lanes);
      list.addComponent(row);
    }
    scroll.addComponent(list);
    root.addComponent(scroll);

    var opts = new HBox();
    var l1 = new Label();
    l1.text = 'Min sustain (ms)';
    opts.addComponent(l1);
    minSustain = new NumberStepper();
    minSustain.min = 0;
    minSustain.max = 5000;
    minSustain.step = 10;
    minSustain.pos = MidiImport.defaultOptions().minSustainMs;
    minSustain.onChange = _ -> updatePreview();
    opts.addComponent(minSustain);
    var l2 = new Label();
    l2.text = 'Offset (ms)';
    opts.addComponent(l2);
    offsetStepper = new NumberStepper();
    offsetStepper.min = -60000;
    offsetStepper.max = 60000;
    offsetStepper.step = 1;
    offsetStepper.pos = 0;
    offsetStepper.onChange = _ -> updatePreview();
    opts.addComponent(offsetStepper);
    root.addComponent(opts);

    var opts2 = new HBox();
    replaceNotes = new CheckBox();
    replaceNotes.text = 'Replace existing notes in this difficulty';
    replaceNotes.selected = editor.currentSongChartNoteData.length == 0;
    replaceNotes.onChange = _ -> updatePreview();
    opts2.addComponent(replaceNotes);
    importTempo = new CheckBox();
    importTempo.text = 'Import BPM / time signature changes';
    importTempo.selected = true;
    importTempo.onChange = _ -> updatePreview();
    opts2.addComponent(importTempo);
    root.addComponent(opts2);

    preview = new Label();
    preview.percentWidth = 100;
    root.addComponent(preview);

    var buttonsRow = new HBox();
    var importBtn = new Button();
    importBtn.text = 'Import';
    importBtn.onClick = _ -> doImport();
    buttonsRow.addComponent(importBtn);
    var cancelBtn = new Button();
    cancelBtn.text = 'Cancel';
    cancelBtn.onClick = _ -> hideDialog(DialogButton.CANCEL);
    buttonsRow.addComponent(cancelBtn);
    root.addComponent(buttonsRow);

    addComponent(root);
    updatePreview();
  }

  function mappings():Array<MidiTrackMapping>
  {
    return [
      for (i in 0...midi.tracks.length)
        {
          target: TARGET_VALUES[Std.int(Math.max(0, targets[i].selectedIndex))],
          lanes: LANE_VALUES[Std.int(Math.max(0, laneModes[i].selectedIndex))]
        }
    ];
  }

  function convert():MidiImportResult
  {
    return MidiImport.convert(midi, mappings(), {minSustainMs: minSustain.pos ?? 0, offsetMs: offsetStepper.pos ?? 0});
  }

  function updatePreview():Void
  {
    if (preview == null || offsetStepper == null || importTempo == null) return;
    var r = convert();
    var p = 0, o = 0, sus = 0;
    for (n in r.notes)
    {
      if (n.data < 4) p++;
      else
        o++;
      if (n.length > 0) sus++;
    }
    var last = r.notes.length > 0 ? r.notes[r.notes.length - 1].time / 1000 : 0;
    preview.text = 'Preview: ${r.notes.length} notes (player $p, opponent $o, $sus sustains), last note at ${Math.round(last * 10) / 10}s'
      + (r.skippedDuplicates > 0 ? ', ${r.skippedDuplicates} stacked duplicates merged' : '')
      + (importTempo.selected ? '; tempo: ' + [for (c in r.timeChanges) '${c.bpm} BPM ${c.num}/${c.den} @ ${Math.round(c.time)}ms'].join(', ') : '; tempo not imported')
      + (replaceNotes.selected ? '. Existing notes will be replaced.' : '. Notes are added to the existing chart.');
  }

  function doImport():Void
  {
    var r = convert();
    if (r.notes.length == 0 && !importTempo.selected)
    {
      editor.warning('MIDI Import', 'Nothing to import: choose Player or Opponent for at least one track.');
      return;
    }
    var notes = [for (n in r.notes) new SongNoteData(n.time, n.data, n.length)];
    var changes:Null<Array<SongTimeChange>> = importTempo.selected ? [for (c in r.timeChanges) new SongTimeChange(c.time, c.bpm, c.num, c.den)] : null;
    editor.performCommand(new GoldenMidiImportCommand(notes, changes, replaceNotes.selected));
    trace('[GOLDEN] MIDI import: ${notes.length} notes, ${changes?.length ?? 0} time changes from $fileName');
    editor.success('MIDI Import', 'Imported ${notes.length} notes from $fileName.');
    hideDialog(DialogButton.OK);
  }

  static function noteName(key:Int):String
  {
    var names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    return names[key % 12] + Std.string(Std.int(key / 12) - 1);
  }
}
#end
