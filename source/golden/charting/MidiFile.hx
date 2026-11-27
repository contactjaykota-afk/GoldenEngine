package golden.charting;

import haxe.io.Bytes;

/** One note with absolute timing in ticks (note-on to matching note-off). */
typedef MidiNote =
{
  var tick:Int;
  var durationTicks:Int;
  var key:Int; // 0..127
  var velocity:Int;
  var channel:Int;
}

typedef MidiTempo =
{
  var tick:Int;
  var microsPerQuarter:Int;
}

typedef MidiTimeSignature =
{
  var tick:Int;
  var numerator:Int;
  var denominator:Int;
}

typedef MidiTrack =
{
  var index:Int;
  var name:String;
  var notes:Array<MidiNote>;
}

/**
 * Golden Engine — Standard MIDI File (SMF) reader, formats 0 and 1, PPQ timing.
 *
 * Reads note on/off pairs (velocity-0 note-on counts as note-off, overlapping same-key notes are
 * matched first-in-first-out), tempo changes, time signatures and track names. SMPTE time division
 * and format 2 (independent sequences) are rejected with a clear error. A MIDI file contains no
 * audio; only note timing is imported.
 */
class MidiFile
{
  public var format(default, null):Int = 0;
  public var ticksPerQuarter(default, null):Int = 480;
  public var tracks(default, null):Array<MidiTrack> = [];
  public var tempos(default, null):Array<MidiTempo> = [];
  public var timeSignatures(default, null):Array<MidiTimeSignature> = [];

  var data:Bytes;
  var pos:Int = 0;

  function new(data:Bytes)
  {
    this.data = data;
  }

  /** Parse a MIDI file. Throws a String describing the problem if the file is not usable. */
  public static function parse(data:Bytes):MidiFile
  {
    var m = new MidiFile(data);
    m.read();
    return m;
  }

  function read():Void
  {
    if (data.length < 14 || data.getString(0, 4) != 'MThd') throw 'Not a MIDI file (missing MThd header).';
    pos = 4;
    var headerLen = u32();
    format = u16();
    var trackCount = u16();
    var division = u16();
    pos = 8 + headerLen;
    if (format > 1) throw 'MIDI format $format (independent sequences) is not supported; save as format 0 or 1.';
    if ((division & 0x8000) != 0) throw 'SMPTE-timed MIDI files are not supported; export with PPQ (ticks per quarter note) timing.';
    ticksPerQuarter = division;
    if (ticksPerQuarter <= 0) throw 'Invalid MIDI time division.';

    for (t in 0...trackCount)
    {
      if (pos + 8 > data.length) break; // tolerate files that declare more tracks than they contain
      var id = data.getString(pos, 4);
      pos += 4;
      var len = u32();
      var end = pos + len;
      if (end > data.length) end = data.length;
      if (id != 'MTrk')
      {
        pos = end; // skip unknown chunks
        continue;
      }
      tracks.push(readTrack(t, end));
      pos = end;
    }
    if (tempos.length == 0 || tempos[0].tick > 0) tempos.unshift({tick: 0, microsPerQuarter: 500000}); // MIDI default: 120 BPM
    tempos.sort((a, b) -> a.tick - b.tick);
    timeSignatures.sort((a, b) -> a.tick - b.tick);
  }

  function readTrack(index:Int, end:Int):MidiTrack
  {
    var track:MidiTrack = {index: index, name: '', notes: []};
    var tick = 0;
    var running = 0;
    var open:Map<Int, Array<MidiNote>> = []; // (channel << 8 | key) -> FIFO of open notes
    while (pos < end)
    {
      tick += vlq();
      if (pos >= end) break;
      var status = data.get(pos);
      if (status < 0x80)
      {
        if (running == 0) throw 'Corrupt MIDI track ${index}: data byte without a status byte.';
        status = running; // running status: reuse previous status, do not consume
      }
      else
      {
        pos++;
        if (status < 0xF0) running = status;
      }

      if (status == 0xFF)
      {
        var type = data.get(pos++);
        var len = vlq();
        switch (type)
        {
          case 0x03: // track name
            if (track.name == '') track.name = data.getString(pos, len);
          case 0x51: // tempo
            if (len >= 3) tempos.push({tick: tick, microsPerQuarter: (data.get(pos) << 16) | (data.get(pos + 1) << 8) | data.get(pos + 2)});
          case 0x58: // time signature
            if (len >= 2) timeSignatures.push({tick: tick, numerator: data.get(pos), denominator: Std.int(Math.pow(2, data.get(pos + 1)))});
          case 0x2F: // end of track
            pos += len;
            break;
          default:
        }
        pos += len;
        continue;
      }
      if (status == 0xF0 || status == 0xF7)
      {
        pos += vlq(); // sysex
        continue;
      }

      var kind = status & 0xF0;
      var channel = status & 0x0F;
      switch (kind)
      {
        case 0x80, 0x90:
          var key = data.get(pos++);
          var vel = data.get(pos++);
          var slot = (channel << 8) | key;
          if (kind == 0x90 && vel > 0)
          {
            var n:MidiNote = {tick: tick, durationTicks: 0, key: key, velocity: vel, channel: channel};
            if (!open.exists(slot)) open.set(slot, []);
            open.get(slot).push(n);
            track.notes.push(n);
          }
          else
          {
            var q = open.get(slot);
            if (q != null && q.length > 0)
            {
              var n = q.shift();
              n.durationTicks = tick - n.tick;
            }
          }
        case 0xA0, 0xB0, 0xE0:
          pos += 2;
        case 0xC0, 0xD0:
          pos += 1;
        default:
          throw 'Corrupt MIDI track ${index}: unknown status byte 0x${StringTools.hex(status, 2)}.';
      }
    }
    // Notes never switched off end at the track's last tick.
    for (q in open)
      for (n in q)
        n.durationTicks = Std.int(Math.max(0, tick - n.tick));
    track.notes.sort((a, b) -> a.tick != b.tick ? a.tick - b.tick : a.key - b.key);
    if (track.name == '') track.name = 'Track ${index + 1}';
    return track;
  }

  /** Convert an absolute tick to milliseconds using the tempo map. */
  public function tickToMs(tick:Int):Float
  {
    var ms = 0.0;
    var lastTick = 0;
    var uspq = tempos[0].microsPerQuarter;
    for (t in tempos)
    {
      if (t.tick >= tick) break;
      ms += (t.tick - lastTick) * uspq / ticksPerQuarter / 1000;
      lastTick = t.tick;
      uspq = t.microsPerQuarter;
    }
    ms += (tick - lastTick) * uspq / ticksPerQuarter / 1000;
    return ms;
  }

  public static inline function bpmOf(microsPerQuarter:Int):Float
    return 60000000 / microsPerQuarter;

  inline function u16():Int
  {
    var v = (data.get(pos) << 8) | data.get(pos + 1);
    pos += 2;
    return v;
  }

  inline function u32():Int
  {
    var v = (data.get(pos) << 24) | (data.get(pos + 1) << 16) | (data.get(pos + 2) << 8) | data.get(pos + 3);
    pos += 4;
    return v;
  }

  function vlq():Int
  {
    var v = 0;
    for (_ in 0...4)
    {
      if (pos >= data.length) throw 'Corrupt MIDI file: truncated variable-length value.';
      var b = data.get(pos++);
      v = (v << 7) | (b & 0x7F);
      if (b & 0x80 == 0) return v;
    }
    throw 'Corrupt MIDI file: variable-length value too long.';
  }
}
