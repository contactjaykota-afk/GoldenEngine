package golden.charting;

import golden.charting.MidiFile;

enum abstract MidiTarget(String) to String from String
{
  var Skip = 'skip';
  var Player = 'player';
  var Opponent = 'opponent';
}

enum abstract LaneMode(String) to String from String
{
  /** Direction = MIDI key mod 4 (C, C#, D, D# -> left, down, up, right; repeats every 4 semitones). */
  var Modulo4 = 'modulo4';

  /** The track's pitch range is split into 4 equal bands: lowest notes left ... highest notes right. */
  var PitchBands = 'bands';
}

typedef MidiTrackMapping =
{
  var target:MidiTarget;
  var lanes:LaneMode;
}

/** A converted note: FNF chart time (ms), lane 0-7 (0-3 player, 4-7 opponent), sustain length (ms). */
typedef ImportedNote =
{
  var time:Float;
  var data:Int;
  var length:Float;
}

typedef ImportedTimeChange =
{
  var time:Float;
  var bpm:Float;
  var num:Int;
  var den:Int;
}

typedef MidiImportResult =
{
  var notes:Array<ImportedNote>;
  var timeChanges:Array<ImportedTimeChange>;
  var skippedDuplicates:Int;
}

typedef MidiImportOptions =
{
  /** Sustains shorter than this (ms) become tap notes. */
  var minSustainMs:Float;

  /** Milliseconds added to every note (to line notes up with the song's audio). */
  var offsetMs:Float;
}

/**
 * Golden Engine — converts parsed MIDI tracks into FNF chart notes and BPM changes.
 * Timing comes from the MIDI tempo map (tick -> ms), so tempo changes are preserved exactly.
 * Notes landing on the same lane at the same time are merged (FNF cannot show stacked notes).
 */
class MidiImport
{
  public static function defaultOptions():MidiImportOptions
    return {minSustainMs: 120, offsetMs: 0};

  /** Suggested mapping: tracks with notes alternate opponent / player, empty tracks are skipped. */
  public static function suggestMappings(midi:MidiFile):Array<MidiTrackMapping>
  {
    var out:Array<MidiTrackMapping> = [];
    var n = 0;
    for (t in midi.tracks)
    {
      if (t.notes.length == 0) out.push({target: Skip, lanes: Modulo4});
      else
        out.push({target: (n++ % 2 == 0) ? Player : Opponent, lanes: Modulo4});
    }
    return out;
  }

  public static function convert(midi:MidiFile, mappings:Array<MidiTrackMapping>, ?options:MidiImportOptions):MidiImportResult
  {
    if (options == null) options = defaultOptions();
    var notes:Array<ImportedNote> = [];
    for (i in 0...midi.tracks.length)
    {
      var map = i < mappings.length ? mappings[i] : null;
      if (map == null || map.target == Skip) continue;
      var track = midi.tracks[i];
      if (track.notes.length == 0) continue;
      var lo = 127, hi = 0;
      for (n in track.notes)
      {
        if (n.key < lo) lo = n.key;
        if (n.key > hi) hi = n.key;
      }
      var base = map.target == Player ? 0 : 4;
      for (n in track.notes)
      {
        var dir = switch (map.lanes)
        {
          case PitchBands: hi == lo ? 0 : Std.int(Math.min(3, Math.floor((n.key - lo) / ((hi - lo + 1) / 4))));
          default: n.key % 4;
        }
        var start = midi.tickToMs(n.tick);
        var end = midi.tickToMs(n.tick + n.durationTicks);
        var len = end - start;
        notes.push({time: round3(start + options.offsetMs), data: base + dir, length: len >= options.minSustainMs ? round3(len) : 0});
      }
    }
    notes.sort((a, b) -> a.time != b.time ? (a.time < b.time ? -1 : 1) : a.data - b.data);
    // Merge duplicates (same lane, same time within 1 ms): keep the longest sustain.
    var merged:Array<ImportedNote> = [];
    var dupes = 0;
    for (n in notes)
    {
      var prev:Null<ImportedNote> = null;
      var j = merged.length - 1;
      while (j >= 0 && n.time - merged[j].time < 1)
      {
        if (merged[j].data == n.data)
        {
          prev = merged[j];
          break;
        }
        j--;
      }
      if (prev != null)
      {
        if (n.length > prev.length) prev.length = n.length;
        dupes++;
      }
      else
        merged.push(n);
    }

    var changes:Array<ImportedTimeChange> = [];
    var sigs = midi.timeSignatures;
    var ticks:Array<Int> = [for (t in midi.tempos) t.tick];
    for (s in sigs)
      if (!ticks.contains(s.tick)) ticks.push(s.tick);
    ticks.sort((a, b) -> a - b);
    for (tick in ticks)
    {
      var tempo = midi.tempos[0];
      for (t in midi.tempos)
        if (t.tick <= tick) tempo = t;
      var num = 4, den = 4;
      for (s in sigs)
        if (s.tick <= tick)
        {
          num = s.numerator;
          den = s.denominator;
        }
      var c:ImportedTimeChange = {time: round3(midi.tickToMs(tick) + (tick == 0 ? 0 : options.offsetMs)), bpm: round3(MidiFile.bpmOf(tempo.microsPerQuarter)), num: num, den: den};
      var last = changes.length > 0 ? changes[changes.length - 1] : null;
      if (last != null && last.bpm == c.bpm && last.num == c.num && last.den == c.den) continue; // redundant
      changes.push(c);
    }
    return {notes: merged, timeChanges: changes, skippedDuplicates: dupes};
  }

  static inline function round3(v:Float):Float
    return Math.round(v * 1000) / 1000;
}
