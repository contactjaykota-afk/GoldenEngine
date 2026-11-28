package golden.audio;

/**
 * Golden Engine — decides which vocal files a song uses. Engine-independent (unit tested).
 *
 * Priority (first match wins, per side):
 *  1. Files listed explicitly in the song metadata (`playerVocals` / `opponentVocals`) — upstream FNF.
 *  2. Character-named files `Voices-<character>[-variation].ogg`, with upstream's suffix stripping
 *     (`bf-car` → `bf`) — upstream FNF.
 *  3. Generic separate files `Voices-Player[-variation].ogg` / `Voices-Opponent[-variation].ogg`
 *     (also lower case `voices-player.ogg` / `voices-opponent.ogg`) — Golden Engine.
 *  4. Only when NEITHER side found anything: one combined track `Voices[-variation].ogg` or
 *     `voices[-variation].ogg`, played as a single shared vocal track (FNF's legacy mode: it is
 *     muted when the player misses, like vanilla FNF before split vocals).
 *
 * For each step the variation-suffixed name is tried before the plain one, so an "erect" chart
 * without its own vocals falls back to the default vocals.
 */
class VoiceResolver
{
  public static function songPath(songId:String, fileName:String, ext:String = 'ogg'):String
    return 'songs:assets/songs/${songId.toLowerCase()}/$fileName.$ext';

  static function suffixes(suffix:Null<String>):Array<String>
    return (suffix == null || suffix == '') ? [''] : [suffix, ''];

  /** Step 3: generic separate vocals for "Player" or "Opponent". */
  public static function generic(songId:String, side:String, suffix:Null<String>, exists:String->Bool, ext:String = 'ogg'):Null<String>
  {
    for (s in suffixes(suffix))
      for (name in ['Voices-$side', 'voices-${side.toLowerCase()}', 'Voices-${side.toLowerCase()}'])
      {
        var p = songPath(songId, name + s, ext);
        if (exists(p)) return p;
      }
    return null;
  }

  /** Step 4: one combined vocal track. */
  public static function combined(songId:String, suffix:Null<String>, exists:String->Bool, ext:String = 'ogg'):Null<String>
  {
    for (s in suffixes(suffix))
      for (name in ['Voices', 'voices'])
      {
        var p = songPath(songId, name + s, ext);
        if (exists(p)) return p;
      }
    return null;
  }

  /**
   * Full decision, given what steps 1–2 (upstream) found for each side.
   * Returns the lists to load and a short description for the log.
   */
  public static function resolve(songId:String, suffix:Null<String>, upstreamPlayer:Array<String>, upstreamOpponent:Array<String>, exists:String->Bool,
      ext:String = 'ogg'):VoiceSelection
  {
    var player = upstreamPlayer.copy();
    var opponent = upstreamOpponent.copy();
    if (player.length == 0)
    {
      var g = generic(songId, 'Player', suffix, exists, ext);
      if (g != null) player.push(g);
    }
    if (opponent.length == 0)
    {
      var g = generic(songId, 'Opponent', suffix, exists, ext);
      if (g != null) opponent.push(g);
    }
    if (player.length > 0 || opponent.length > 0) return {player: player, opponent: opponent, combined: null, mode: 'separate'};
    var c = combined(songId, suffix, exists, ext);
    if (c != null) return {player: [], opponent: [], combined: c, mode: 'combined'};
    return {player: [], opponent: [], combined: null, mode: 'none'};
  }
}

typedef VoiceSelection =
{
  player:Array<String>,
  opponent:Array<String>,
  combined:Null<String>,
  mode:String
}
