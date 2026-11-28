package golden;

/**
 * Golden Engine — temporary gameplay overrides set by editors' "Test in gameplay" buttons
 * (e.g. play a song with the character you just exported). They apply to the next songs started
 * from that editor and are cleared with `clear()` when the editor is opened again.
 */
class GoldenPlayOverrides
{
  public static var player:Null<String> = null;
  public static var opponent:Null<String> = null;

  public static function playerOr(id:String):String
  {
    if (player == null) return id;
    trace('[GOLDEN] Test override: player character "$player" (chart has "$id")');
    return player;
  }

  public static function opponentOr(id:String):String
  {
    if (opponent == null) return id;
    trace('[GOLDEN] Test override: opponent character "$opponent" (chart has "$id")');
    return opponent;
  }

  public static function clear():Void
  {
    player = null;
    opponent = null;
  }
}
