import golden.audio.VoiceResolver;

/** Unit tests for combined / separate vocal detection (golden.audio.VoiceResolver). */
class VoiceTest
{
  static var passed = 0;
  static var failed = 0;

  static function check(name:String, ok:Bool, ?detail:String)
  {
    if (ok) passed++; else failed++;
    Sys.println((ok ? 'PASS  ' : 'FAIL  ') + name + (ok || detail == null ? '' : ' — ' + detail));
  }

  static function files(names:Array<String>):String->Bool
  {
    var set = [for (n in names) VoiceResolver.songPath('test', n) => true];
    return (p) -> set.exists(p);
  }

  static function p(n:String) return VoiceResolver.songPath('test', n);

  static function main()
  {
    // 1. Only a combined Voices.ogg -> one shared track.
    var r = VoiceResolver.resolve('test', '', [], [], files(['Voices']));
    check('combined Voices.ogg only', r.mode == 'combined' && r.combined == p('Voices'), Std.string(r));
    // 2. Lower-case voices.ogg is accepted.
    r = VoiceResolver.resolve('test', '', [], [], files(['voices']));
    check('lower-case voices.ogg', r.mode == 'combined' && r.combined == p('voices'), Std.string(r));
    // 3. Character-named separate files found upstream -> separate, combined ignored.
    r = VoiceResolver.resolve('test', '', [p('Voices-bf')], [p('Voices-dad')], files(['Voices-bf', 'Voices-dad', 'Voices']));
    check('separate character files win over combined', r.mode == 'separate' && r.combined == null && r.player[0] == p('Voices-bf'), Std.string(r));
    // 4. Generic Voices-Player / Voices-Opponent.
    r = VoiceResolver.resolve('test', '', [], [], files(['Voices-Player', 'Voices-Opponent']));
    check('generic Voices-Player + Voices-Opponent', r.mode == 'separate' && r.player[0] == p('Voices-Player') && r.opponent[0] == p('Voices-Opponent'), Std.string(r));
    // 5. Lower-case generic names.
    r = VoiceResolver.resolve('test', '', [], [], files(['voices-player', 'voices-opponent']));
    check('lower-case voices-player / voices-opponent', r.player[0] == p('voices-player') && r.opponent[0] == p('voices-opponent'), Std.string(r));
    // 6. Only the player has a separate file -> separate (opponent silent), combined not mixed in.
    r = VoiceResolver.resolve('test', '', [p('Voices-bf')], [], files(['Voices-bf', 'Voices']));
    check('player-only separate file', r.mode == 'separate' && r.opponent.length == 0 && r.combined == null, Std.string(r));
    // 7. Character file for one side + generic for the other.
    r = VoiceResolver.resolve('test', '', [p('Voices-bf')], [], files(['Voices-bf', 'Voices-Opponent']));
    check('character + generic mix', r.player[0] == p('Voices-bf') && r.opponent[0] == p('Voices-Opponent'), Std.string(r));
    // 8. Variation-suffixed combined file preferred.
    r = VoiceResolver.resolve('test', '-erect', [], [], files(['Voices', 'Voices-erect']));
    check('variation combined Voices-erect preferred', r.combined == p('Voices-erect'), Std.string(r));
    // 9. Variation without its own vocals falls back to the default combined file.
    r = VoiceResolver.resolve('test', '-erect', [], [], files(['Voices']));
    check('variation falls back to Voices.ogg', r.combined == p('Voices'), Std.string(r));
    // 10. No vocal files at all.
    r = VoiceResolver.resolve('test', '', [], [], files([]));
    check('no vocals', r.mode == 'none' && r.combined == null && r.player.length == 0, Std.string(r));
    // 11. Song ids are lower-cased in paths like Paths.voices.
    check('song id lower-cased', VoiceResolver.songPath('Bopeebo', 'Voices') == 'songs:assets/songs/bopeebo/Voices.ogg');

    Sys.println('\n$passed passed, $failed failed');
    Sys.exit(failed == 0 ? 0 : 1);
  }
}
