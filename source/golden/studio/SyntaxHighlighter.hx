package golden.studio;

/** A coloured span in a document (character offsets, end exclusive). */
typedef Span =
{
  var start:Int;
  var end:Int;
  var color:Int;
}

/**
 * Golden Engine — small tokenizer-based syntax highlighter for the script editor.
 * Languages: Haxe/HScript (.hx/.hxc), Lua, JSON, XML. Pure Haxe (unit-testable), no allocations
 * per character beyond the span list. Long documents are capped by the caller.
 */
class SyntaxHighlighter
{
  public static inline var KEYWORD:Int = 0xFFFF79C6;
  public static inline var STRING:Int = 0xFFF1FA8C;
  public static inline var COMMENT:Int = 0xFF6F7A96;
  public static inline var NUMBER:Int = 0xFFBD93F9;
  public static inline var TYPE:Int = 0xFF8BE9FD;
  public static inline var TAG:Int = 0xFFFFB86C;

  static final HAXE_KW:Array<String> = [
    'package', 'import', 'using', 'class', 'interface', 'enum', 'abstract', 'typedef', 'extends', 'implements', 'function', 'var', 'final', 'new', 'return',
    'if', 'else', 'for', 'while', 'do', 'switch', 'case', 'default', 'break', 'continue', 'try', 'catch', 'throw', 'in', 'this', 'super', 'null', 'true',
    'false', 'static', 'public', 'private', 'override', 'inline', 'dynamic', 'macro', 'cast', 'untyped'
  ];
  static final LUA_KW:Array<String> = [
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then',
    'true', 'until', 'while'
  ];

  public static function languageFor(path:String):String
  {
    var ext = haxe.io.Path.extension(path).toLowerCase();
    return switch (ext)
    {
      case 'hx' | 'hxc' | 'hscript': 'haxe';
      case 'lua': 'lua';
      case 'json': 'json';
      case 'xml': 'xml';
      default: 'text';
    }
  }

  public static function highlight(text:String, lang:String):Array<Span>
  {
    return switch (lang)
    {
      case 'haxe': code(text, HAXE_KW, '//', '/*', '*/', true);
      case 'lua': code(text, LUA_KW, '--', '--[[', ']]', false);
      case 'json': code(text, ['true', 'false', 'null'], null, null, null, false);
      case 'xml': xml(text);
      default: [];
    }
  }

  static inline function isIdentStart(c:Int):Bool
    return (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || c == '_'.code;

  static inline function isIdent(c:Int):Bool
    return isIdentStart(c) || (c >= '0'.code && c <= '9'.code);

  static inline function isDigit(c:Int):Bool
    return c >= '0'.code && c <= '9'.code;

  static function code(t:String, keywords:Array<String>, line:Null<String>, blockOpen:Null<String>, blockClose:Null<String>, typesCapitalised:Bool):Array<Span>
  {
    var out:Array<Span> = [];
    var i = 0;
    var n = t.length;
    while (i < n)
    {
      var c = StringTools.fastCodeAt(t, i);
      // block comment (checked before line comment: Lua's "--[[" starts with "--")
      if (blockOpen != null && t.substr(i, blockOpen.length) == blockOpen)
      {
        var e = t.indexOf(blockClose, i + blockOpen.length);
        e = e < 0 ? n : e + blockClose.length;
        out.push({start: i, end: e, color: COMMENT});
        i = e;
        continue;
      }
      if (line != null && t.substr(i, line.length) == line)
      {
        var e = t.indexOf('\n', i);
        if (e < 0) e = n;
        out.push({start: i, end: e, color: COMMENT});
        i = e;
        continue;
      }
      if (c == '"'.code || c == "'".code)
      {
        var j = i + 1;
        while (j < n)
        {
          var d = StringTools.fastCodeAt(t, j);
          if (d == '\\'.code) j += 2;
          else if (d == c || d == '\n'.code) break;
          else
            j++;
        }
        var e = Std.int(Math.min(n, j + 1));
        out.push({start: i, end: e, color: STRING});
        i = e;
        continue;
      }
      if (isDigit(c))
      {
        var j = i + 1;
        while (j < n && (isIdent(StringTools.fastCodeAt(t, j)) || StringTools.fastCodeAt(t, j) == '.'.code))
          j++;
        out.push({start: i, end: j, color: NUMBER});
        i = j;
        continue;
      }
      if (isIdentStart(c))
      {
        var j = i + 1;
        while (j < n && isIdent(StringTools.fastCodeAt(t, j)))
          j++;
        var word = t.substring(i, j);
        if (keywords.contains(word)) out.push({start: i, end: j, color: KEYWORD});
        else if (typesCapitalised && c >= 'A'.code && c <= 'Z'.code) out.push({start: i, end: j, color: TYPE});
        i = j;
        continue;
      }
      i++;
    }
    return out;
  }

  static function xml(t:String):Array<Span>
  {
    var out:Array<Span> = [];
    var i = 0;
    var n = t.length;
    while (i < n)
    {
      if (t.substr(i, 4) == '<!--')
      {
        var e = t.indexOf('-->', i);
        e = e < 0 ? n : e + 3;
        out.push({start: i, end: e, color: COMMENT});
        i = e;
        continue;
      }
      var c = StringTools.fastCodeAt(t, i);
      if (c == '<'.code)
      {
        var j = i + 1;
        while (j < n && StringTools.fastCodeAt(t, j) != ' '.code && StringTools.fastCodeAt(t, j) != '>'.code && StringTools.fastCodeAt(t, j) != '\n'.code)
          j++;
        out.push({start: i, end: j, color: TAG});
        i = j;
        continue;
      }
      if (c == '"'.code)
      {
        var e = t.indexOf('"', i + 1);
        e = e < 0 ? n : e + 1;
        out.push({start: i, end: e, color: STRING});
        i = e;
        continue;
      }
      i++;
    }
    return out;
  }

  /** Index of the bracket matching the one at `pos` (or -1). Ignores brackets inside nothing smarter than nesting. */
  public static function matchBracket(t:String, pos:Int):Int
  {
    if (pos < 0 || pos >= t.length) return -1;
    var open = '([{', close = ')]}';
    var c = t.charAt(pos);
    var oi = open.indexOf(c), ci = close.indexOf(c);
    if (oi < 0 && ci < 0) return -1;
    var forward = oi >= 0;
    var mine = c, other = forward ? close.charAt(oi) : open.charAt(ci);
    var depth = 0;
    var i = pos;
    while (i >= 0 && i < t.length)
    {
      var d = t.charAt(i);
      if (d == mine) depth++;
      else if (d == other)
      {
        depth--;
        if (depth == 0) return i;
      }
      i += forward ? 1 : -1;
    }
    return -1;
  }
}
