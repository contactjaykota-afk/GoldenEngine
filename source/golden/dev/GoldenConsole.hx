package golden.dev;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxInputText;
import flixel.text.FlxText;

typedef ConsoleEntry =
{
  var time:Float;
  var text:String;
  var source:String; // file:line
  var level:String; // info | warn | error | lua | mods
}

/**
 * Golden Engine runtime console.
 *
 * `install()` wraps `haxe.Log.trace` (after upstream's AnsiTrace is set) so every log line — game,
 * Polymod, Lua, Golden — is kept in a ring buffer with its file:line. The overlay (F8 in Developer
 * Mode) shows it with level tabs (All / Errors / Warnings / Lua / Mods), a text filter, mouse-wheel
 * scrolling and "Copy" to the clipboard. Capture is a cheap append; the overlay only rebuilds its text
 * when visible and something changed.
 */
class GoldenConsole
{
  public static inline var CAPACITY:Int = 2000;

  public static var entries(default, null):Array<ConsoleEntry> = [];
  public static var revision(default, null):Int = 0;

  static var installed:Bool = false;
  static final ANSI:EReg = ~/\x1b\[[0-9;]*m/g;
  static var inner:Null<(Dynamic, ?haxe.PosInfos) -> Void> = null;

  public static function install():Void
  {
    if (installed) return;
    installed = true;
    inner = haxe.Log.trace;
    haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos)
    {
      record(v, infos);
      if (inner != null) inner(v, infos);
    };
  }

  static function record(v:Dynamic, ?infos:haxe.PosInfos):Void
  {
    var text = ANSI.replace(Std.string(v), '');
    if (infos != null && infos.customParams != null) text += ' ' + infos.customParams.join(' ');
    var src = infos != null ? '${infos.fileName}:${infos.lineNumber}' : '';
    entries.push({time: haxe.Timer.stamp(), text: text, source: src, level: classify(text, src)});
    if (entries.length > CAPACITY) entries.shift();
    revision++;
  }

  public static function classify(text:String, src:String):String
  {
    var t = text.toUpperCase();
    if (t.indexOf('[LUA]') >= 0 || src.indexOf('golden/lua') >= 0) return t.indexOf('ERROR') >= 0 ? 'error' : 'lua';
    if (t.indexOf('ERROR') >= 0 || t.indexOf('FAILED') >= 0 || t.indexOf('EXCEPTION') >= 0) return 'error';
    if (t.indexOf('WARN') >= 0) return 'warn';
    if (src.indexOf('modding') >= 0 || t.indexOf('POLYMOD') >= 0 || t.indexOf('MOD ') >= 0) return 'mods';
    return 'info';
  }

  public static function count(level:String):Int
  {
    var n = 0;
    for (e in entries)
      if (e.level == level) n++;
    return n;
  }
}

/** The F8 overlay (Flixel sprites drawn by GoldenDevTools on its overlay camera). */
class GoldenConsoleOverlay extends FlxSpriteGroup
{
  static final TABS:Array<{id:String, label:String}> = [
    {id: 'all', label: 'All'},
    {id: 'error', label: 'Errors'},
    {id: 'warn', label: 'Warnings'},
    {id: 'lua', label: 'Lua'},
    {id: 'mods', label: 'Mods'}
  ];

  static inline var LINE_H:Int = 14;

  var tab:String = 'all';
  public var filter(default, null):FlxInputText;
  var body:FlxText;
  var tabFields:Array<FlxText> = [];
  var copyBtn:FlxText;
  var clearBtn:FlxText;
  var status:FlxText;
  var lastRevision:Int = -1;
  var lastKey:String = '';
  var scrollBack:Int = 0;
  var panelH:Int;

  public function new()
  {
    super(0, 0);
    var w = FlxG.width;
    panelH = Std.int(FlxG.height * 0.55);
    add(new FlxSprite().makeGraphic(w, panelH, 0xEB0E0B14));
    add(new FlxSprite(0, panelH - 2).makeGraphic(w, 2, 0xFFFFC83D));
    var x = 8.0;
    for (t in TABS)
    {
      var f = label(x, 6, '${t.label} (0000)', 0xFFF4EEDD);
      tabFields.push(f);
      add(f);
      x += f.width + 12;
    }
    var fl = label(x + 6, 6, 'Filter:', 0xFF9A93A8);
    add(fl);
    filter = new FlxInputText(fl.x + fl.width + 4, 4, 220, '', 12, 0xFFFFFFFF, 0xFF2C2436);
    filter.font = Paths.font('vcr.ttf');
    filter.fieldBorderColor = 0xFF8A6410;
    add(filter);
    copyBtn = label(filter.x + 236, 6, '[Copy]', 0xFFFFC83D);
    add(copyBtn);
    clearBtn = label(copyBtn.x + copyBtn.width + 10, 6, '[Clear]', 0xFFFFC83D);
    add(clearBtn);
    status = label(clearBtn.x + clearBtn.width + 16, 6, '', 0xFF9A93A8);
    add(status);
    body = new FlxText(8, 30, w - 16, '', 11);
    body.setFormat(Paths.font('vcr.ttf'), 11, 0xFFE6E0D0, LEFT);
    add(body);
    scrollFactor.set();
    refresh(true);
  }

  static function label(x:Float, y:Float, text:String, color:Int):FlxText
  {
    var f = new FlxText(x, y, 0, text, 12);
    f.setFormat(Paths.font('vcr.ttf'), 12, color, LEFT);
    return f;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (FlxG.mouse.justReleased)
    {
      for (i in 0...TABS.length)
        if (mouseOver(tabFields[i])) setTab(TABS[i].id);
      if (mouseOver(copyBtn)) copyVisible();
      if (mouseOver(clearBtn))
      {
        GoldenConsole.entries.resize(0);
        lastRevision = -1;
      }
    }
    if (FlxG.mouse.wheel != 0 && FlxG.mouse.getScreenPosition(camera).y < panelH)
    {
      scrollBack = Std.int(Math.max(0, scrollBack + FlxG.mouse.wheel * 3));
      lastRevision = -1;
    }
    refresh();
  }

  function mouseOver(t:FlxText):Bool
  {
    var p = FlxG.mouse.getScreenPosition(camera);
    return p.x >= t.x && p.x <= t.x + t.width && p.y >= t.y && p.y <= t.y + t.height;
  }

  function setTab(id:String):Void
  {
    tab = id;
    scrollBack = 0;
    lastRevision = -1;
    golden.audio.UISound.play(Scroll);
  }

  function matching():Array<ConsoleEntry>
  {
    var q = filter.text.toLowerCase();
    return [
      for (e in GoldenConsole.entries)
        if ((tab == 'all' || e.level == tab) && (q == '' || e.text.toLowerCase().indexOf(q) >= 0 || e.source.toLowerCase().indexOf(q) >= 0)) e
    ];
  }

  static function format(e:ConsoleEntry):String
  {
    var tag = switch (e.level)
    {
      case 'error': 'ERR ';
      case 'warn': 'WARN';
      case 'lua': 'LUA ';
      case 'mods': 'MODS';
      default: '    ';
    }
    var line = '$tag ${e.source}  ${e.text}';
    return line.length > 170 ? line.substr(0, 167) + '...' : line;
  }

  public function refresh(force:Bool = false):Void
  {
    var key = tab + '|' + filter.text + '|' + scrollBack;
    if (!force && GoldenConsole.revision == lastRevision && key == lastKey) return;
    lastRevision = GoldenConsole.revision;
    lastKey = key;
    var list = matching();
    var visibleLines = Std.int((panelH - 36) / LINE_H);
    var end = Std.int(Math.max(0, list.length - scrollBack));
    var start = Std.int(Math.max(0, end - visibleLines));
    body.text = [for (i in start...end) format(list[i])].join('\n');
    for (i in 0...TABS.length)
    {
      var t = TABS[i];
      var n = t.id == 'all' ? GoldenConsole.entries.length : GoldenConsole.count(t.id);
      tabFields[i].text = '${t.label} ($n)';
      tabFields[i].color = t.id == tab ? 0xFFFFC83D : 0xFFF4EEDD;
    }
    status.text = '${list.length} shown' + (scrollBack > 0 ? ' (scrolled up $scrollBack)' : '') + '   wheel: scroll   F8: close';
  }

  function copyVisible():Void
  {
    lime.system.Clipboard.text = [for (e in matching()) format(e)].join('\n');
    golden.audio.UISound.play(Select);
    trace('[GOLDEN] Console: copied ${matching().length} lines to the clipboard');
  }
}
