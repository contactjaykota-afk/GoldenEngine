import golden.charting.MidiFile;
import golden.charting.MidiImport;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;

/**
 * Unit tests for golden.charting.MidiFile / MidiImport. Builds MIDI files byte by byte, so the
 * expected timings are known exactly. Run: golden/tests/unit/run-unit-tests.sh
 */
class MidiTest
{
  static var pass = 0;
  static var fail = 0;

  static function check(name:String, ok:Bool, ?detail:String)
  {
    if (ok) { pass++; Sys.println('PASS  $name'); }
    else { fail++; Sys.println('FAIL  $name ${detail ?? ""}'); }
  }

  static function near(a:Float, b:Float, eps = 0.01) return Math.abs(a - b) <= eps;

  static function vlq(b:BytesBuffer, v:Int)
  {
    var stack = [v & 0x7F];
    v >>= 7;
    while (v > 0) { stack.unshift((v & 0x7F) | 0x80); v >>= 7; }
    for (x in stack) b.addByte(x);
  }

  static function track(events:Array<Array<Int>>):Bytes
  {
    // events: [deltaTicks, byte, byte, ...]
    var b = new BytesBuffer();
    for (e in events) { vlq(b, e[0]); for (i in 1...e.length) b.addByte(e[i]); }
    vlq(b, 0); b.addByte(0xFF); b.addByte(0x2F); b.addByte(0x00);
    return b.getBytes();
  }

  static function file(format:Int, ppq:Int, tracks:Array<Bytes>):Bytes
  {
    var b = new BytesBuffer();
    b.addString('MThd');
    for (x in [0, 0, 0, 6, 0, format, 0, tracks.length, (ppq >> 8) & 0xFF, ppq & 0xFF]) b.addByte(x);
    for (t in tracks)
    {
      b.addString('MTrk');
      var l = t.length;
      for (x in [(l >> 24) & 0xFF, (l >> 16) & 0xFF, (l >> 8) & 0xFF, l & 0xFF]) b.addByte(x);
      b.add(t);
    }
    return b.getBytes();
  }

  static function main()
  {
    // Conductor track: 120 BPM (500000 us), 4/4; at tick 1920 (one bar) -> 150 BPM (400000 us), 3/4.
    var conductor = track([
      [0, 0xFF, 0x03, 4, 'T'.code, 'e'.code, 'm'.code, 'p'.code],
      [0, 0xFF, 0x51, 3, 0x07, 0xA1, 0x20],
      [0, 0xFF, 0x58, 4, 4, 2, 24, 8],
      [1920, 0xFF, 0x51, 3, 0x06, 0x1A, 0x80],
      [0, 0xFF, 0x58, 4, 3, 2, 24, 8]
    ]);
    // Lead (player): C4 at 0 for 1 beat; D4 at beat 1 for 1/8 beat (tap); running status + vel-0 note-off;
    // E4 at tick 1920 (after tempo change) for 1 beat at 150 BPM = 400 ms.
    var lead = track([
      [0, 0xFF, 0x03, 4, 'L'.code, 'e'.code, 'a'.code, 'd'.code],
      [0, 0x90, 60, 100],
      [480, 0x80, 60, 0],
      [0, 0x90, 62, 90],
      [60, 62, 0], // running status note-on velocity 0 == note-off
      [1380, 0x90, 64, 80],
      [480, 0x80, 64, 0]
    ]);
    // Bass (opponent): two notes same tick same lane (C3 and E3 -> 48%4=0, 52%4=0) -> merged.
    var bass = track([
      [0, 0x91, 48, 100],
      [0, 0x91, 52, 100],
      [240, 0x81, 48, 0],
      [240, 0x81, 52, 0]
    ]);
    var empty = track([[0, 0xFF, 0x03, 1, 'X'.code]]);
    var midi = MidiFile.parse(file(1, 480, [conductor, lead, bass, empty]));

    check('format 1 parsed', midi.format == 1);
    check('4 tracks', midi.tracks.length == 4, '${midi.tracks.length}');
    check('ppq 480', midi.ticksPerQuarter == 480);
    check('track name read', midi.tracks[1].name == 'Lead', midi.tracks[1].name);
    check('unnamed track gets default name', midi.tracks[2].name == 'Track 3', midi.tracks[2].name);
    check('2 tempos', midi.tempos.length == 2);
    check('tick 480 = 500 ms at 120 BPM', near(midi.tickToMs(480), 500));
    check('tick 1920 = 2000 ms', near(midi.tickToMs(1920), 2000));
    check('tick 2400 = 2400 ms (150 BPM after change)', near(midi.tickToMs(2400), 2400));
    check('lead has 3 notes', midi.tracks[1].notes.length == 3, '${midi.tracks[1].notes.length}');
    check('running status / vel-0 off handled (D4 = 60 ticks)', midi.tracks[1].notes[1].durationTicks == 60, '${midi.tracks[1].notes[1].durationTicks}');

    var maps = MidiImport.suggestMappings(midi);
    check('suggest: conductor (no notes) skipped', maps[0].target == Skip);
    check('suggest: first note track -> player', maps[1].target == Player);
    check('suggest: second note track -> opponent', maps[2].target == Opponent);
    check('suggest: empty track skipped', maps[3].target == Skip);

    var r = MidiImport.convert(midi, maps);
    var player = r.notes.filter(n -> n.data < 4);
    var opp = r.notes.filter(n -> n.data >= 4);
    check('3 player notes', player.length == 3, '${player.length}');
    check('C4 -> lane 0 (60%4)', player[0].data == 0);
    check('C4 at 0 ms, sustain 500 ms', near(player[0].time, 0) && near(player[0].length, 500), '${player[0].time} ${player[0].length}');
    check('D4 -> lane 2 at 500 ms, tap (62.5 ms < min sustain)', player[1].data == 2 && near(player[1].time, 500) && player[1].length == 0);
    check('E4 at 2000 ms with 400 ms sustain (tempo change honoured)', near(player[2].time, 2000) && near(player[2].length, 400), '${player[2].time} ${player[2].length}');
    check('opponent stacked notes merged into one', opp.length == 1 && r.skippedDuplicates == 1, '${opp.length} ${r.skippedDuplicates}');
    check('opponent note on lane 4, longest sustain kept (500 ms)', opp[0].data == 4 && near(opp[0].length, 500), '${opp[0].data} ${opp[0].length}');
    check('2 time changes', r.timeChanges.length == 2, '${r.timeChanges.length}');
    check('time change 0: 120 BPM 4/4', near(r.timeChanges[0].bpm, 120) && r.timeChanges[0].num == 4 && r.timeChanges[0].den == 4);
    check('time change 1: 150 BPM 3/4 at 2000 ms', near(r.timeChanges[1].bpm, 150) && r.timeChanges[1].num == 3 && near(r.timeChanges[1].time, 2000));

    var r2 = MidiImport.convert(midi, [{target: Skip, lanes: Modulo4}, {target: Opponent, lanes: PitchBands}, {target: Skip, lanes: Modulo4}],
      {minSustainMs: 0, offsetMs: 100});
    check('pitch bands: lowest -> lane 4, highest -> lane 7', r2.notes[0].data == 4 && r2.notes[2].data == 7, [for (n in r2.notes) n.data].join(','));
    check('offset applied (+100 ms)', near(r2.notes[0].time, 100));
    check('minSustain 0 keeps short sustain', r2.notes[1].length > 0);

    var errs = 0;
    for (bad in [Bytes.ofString('RIFF....'), file(2, 480, [conductor])])
      try { MidiFile.parse(bad); } catch (e:String) { errs++; }
    check('invalid / format-2 files rejected with an error', errs == 2);
    var smpte = file(0, 0xE728, [lead]);
    try { MidiFile.parse(smpte); check('SMPTE rejected', false); } catch (e:String) { check('SMPTE division rejected', e.indexOf('SMPTE') >= 0); }

    Sys.println('\n$pass passed, $fail failed');
    Sys.exit(fail == 0 ? 0 : 1);
  }
}
