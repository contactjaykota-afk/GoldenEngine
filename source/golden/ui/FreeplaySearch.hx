package golden.ui;

import flixel.text.FlxInputText;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.ui.freeplay.FreeplayState;
import golden.audio.UISound;
import golden.modding.GoldenMods;

using StringTools;

/**
 * Golden Engine — Freeplay search (Ctrl+F or F3 in Freeplay): search as you type (song name, id or
 * artist), filter by origin (base game or one enabled mod) and sortMode (week order, A-Z, recently
 * played). Uses Freeplay's own filter path (FilterType.GOLDEN), so selection, difficulties, scores
 * and favourites keep working. The current difficulty still applies (Freeplay only lists songs that
 * have it). Esc/Enter closes and keeps the filter; Ctrl+Backspace clears everything.
 */
class FreeplaySearch extends GoldenSubState
{
  public static var query:String = '';
  public static var modFilter:String = 'all';
  public static var sortMode:String = 'week';

  static final SORTS:Array<String> = ['week', 'a-z', 'recent'];

  var freeplay:FreeplayState;
  var input:FlxInputText;
  var row:Int = 0;
  var modText:FlxText;
  var sortText:FlxText;
  var countText:FlxText;
  var rowMarks:Array<FlxText> = [];

  public function new(fp:FreeplayState)
  {
    super(0x88000000);
    freeplay = fp;
  }

  /** Called by FreeplayState.sortSongs for FilterType.GOLDEN. */
  public static function apply(list:Array<Null<funkin.ui.freeplay.FreeplayState.FreeplaySongData>>, data:Dynamic):Array<Null<funkin.ui.freeplay.FreeplayState.FreeplaySongData>>
  {
    var q = Std.string(data?.query ?? '').toLowerCase().trim();
    var mod = Std.string(data?.mod ?? 'all');
    var srt = Std.string(data?.sortMode ?? 'week');
    var out = list.filter(s ->
    {
      if (s == null) return true; // the random capsule
      @:privateAccess var id:String = s.songId;
      var song = s.data;
      if (q != '')
      {
        var hay = (song.songName + ' ' + id + ' ' + (song.songArtist ?? '')).toLowerCase();
        if (hay.indexOf(q) < 0) return false;
      }
      if (mod != 'all')
      {
        var from = originOf(id);
        if (from != mod) return false;
      }
      return true;
    });
    if (srt == 'a-z') out.sort((a, b) -> a == null ? -1 : (b == null ? 1 : funkin.util.SortUtil.alphabetically(a.data.songName, b.data.songName)));
    else if (srt == 'recent')
    {
      var recent = GoldenSettings.recentSongs;
      inline function rank(s:Null<funkin.ui.freeplay.FreeplayState.FreeplaySongData>):Int
      {
        if (s == null) return -2;
        @:privateAccess var i = recent.indexOf(s.songId);
        return i < 0 ? 9999 : i;
      }
      out.sort((a, b) -> rank(a) - rank(b));
    }
    trace('[GOLDEN] Freeplay filter "$q" mod=$mod sortMode=$srt: ${out.filter(x -> x != null).length} songs');
    return out;
  }

  /** "base" for base-game songs, otherwise the folder of the enabled mod that provides the song. */
  public static function originOf(songId:String):String
  {
    #if sys
    for (dir in GoldenMods.resolveEnabledDirs())
      if (sys.FileSystem.exists(haxe.io.Path.join([GoldenMods.modRoot(), dir, 'data/songs', songId]))) return dir;
    #end
    return 'base';
  }

  function modChoices():Array<String>
    return ['all', 'base'].concat(GoldenMods.resolveEnabledDirs());

  override function create():Void
  {
    super.create();
    var w = 620, h = 250;
    var x = (FlxG.width - w) / 2, y = 90;
    add(GoldenUI.panel(x - 2, y - 2, w + 4, h + 4, GoldenUI.GOLD));
    add(GoldenUI.panel(x, y, w, h, 0xF01A1420));
    add(GoldenUI.text(x + 20, y + 14, w - 40, 'SEARCH SONGS', 22, GoldenUI.GOLD));
    var labels = ['Search', 'From', 'Sort'];
    for (i in 0...3)
    {
      var m = GoldenUI.text(x + 20, y + 62 + i * 46, 130, labels[i], 18);
      rowMarks.push(m);
      add(m);
    }
    input = new FlxInputText(x + 150, y + 60, w - 180, query, 18, FlxColor.WHITE, 0xFF2C2436);
    input.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE);
    input.onTextChange.add((t, _) ->
    {
      query = t;
      refilter();
    });
    add(input);
    modText = GoldenUI.text(x + 150, y + 108, w - 180, '', 18);
    sortText = GoldenUI.text(x + 150, y + 154, w - 180, '', 18);
    countText = GoldenUI.text(x + 20, y + h - 34, w - 40, '', 14, GoldenUI.MUTED);
    add(modText);
    add(sortText);
    add(countText);
    input.startFocus();
    UISound.play(Open);
    refreshView();
    trace('[GOLDEN] Freeplay search opened');
  }

  function refreshView():Void
  {
    modText.text = '< ${modFilter == 'base' ? 'Base game' : (modFilter == 'all' ? 'All songs' : modFilter)} >';
    sortText.text = '< ${sortMode == 'week' ? 'Week order' : (sortMode == 'a-z' ? 'A - Z' : 'Recently played')} >';
    for (i in 0...rowMarks.length)
      rowMarks[i].color = i == row ? GoldenUI.GOLD : GoldenUI.TEXT;
    var n = @:privateAccess freeplay.currentFilteredSongs.filter(s -> s != null).length;
    countText.text = '$n songs  -  Up/Down: field  Left/Right: change  Ctrl+Backspace: clear  Esc/Enter: close';
  }

  function refilter():Void
  {
    if (query == '' && modFilter == 'all' && sortMode == 'week') freeplay.generateSongList(null, true, false, true);
    else
      freeplay.generateSongList({filterType: GOLDEN, filterData: {query: query, mod: modFilter, sortMode: sortMode}}, true, false, true);
    refreshView();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (inputBlocked()) return;
    var k = FlxG.keys.justPressed;
    if (k.ESCAPE || k.ENTER)
    {
      input.endFocus();
      UISound.play(Back);
      close();
      return;
    }
    if (FlxG.keys.pressed.CONTROL && k.BACKSPACE)
    {
      query = '';
      modFilter = 'all';
      sortMode = 'week';
      input.text = '';
      refilter();
      return;
    }
    if (k.UP || k.DOWN)
    {
      row = (row + (k.UP ? -1 : 1) + 3) % 3;
      if (row == 0) input.startFocus() else input.endFocus();
      UISound.play(Scroll);
      refreshView();
    }
    if (row > 0 && (k.LEFT || k.RIGHT))
    {
      var d = k.LEFT ? -1 : 1;
      if (row == 1)
      {
        var c = modChoices();
        modFilter = c[(c.indexOf(modFilter) + d + c.length) % c.length];
      }
      else
        sortMode = SORTS[(SORTS.indexOf(sortMode) + d + SORTS.length) % SORTS.length];
      UISound.play(Scroll);
      refilter();
    }
  }
}
