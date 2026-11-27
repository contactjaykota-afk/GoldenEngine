import golden.studio.SyntaxHighlighter;

class HighlightTest
{
  static var pass = 0;
  static var fail = 0;

  static function check(name:String, ok:Bool, ?d:String)
  {
    if (ok) { pass++; Sys.println('PASS  $name'); } else { fail++; Sys.println('FAIL  $name ${d ?? ""}'); }
  }

  static function colorAt(spans:Array<Span>, pos:Int):Int
  {
    for (s in spans) if (pos >= s.start && pos < s.end) return s.color;
    return 0;
  }

  static function main()
  {
    var lua = 'local x = 10 -- note\nfunction onBeatHit(b)\n  print("hi")\nend\n--[[ block\ncomment ]] y = nil';
    var s = SyntaxHighlighter.highlight(lua, 'lua');
    check('lua keyword "local"', colorAt(s, 0) == SyntaxHighlighter.KEYWORD);
    check('lua number', colorAt(s, lua.indexOf('10')) == SyntaxHighlighter.NUMBER);
    check('lua line comment', colorAt(s, lua.indexOf('note')) == SyntaxHighlighter.COMMENT);
    check('lua string', colorAt(s, lua.indexOf('"hi"') + 1) == SyntaxHighlighter.STRING);
    check('lua block comment spans lines', colorAt(s, lua.indexOf('comment ]]')) == SyntaxHighlighter.COMMENT);
    check('lua code after block comment not comment', colorAt(s, lua.indexOf('nil')) == SyntaxHighlighter.KEYWORD);
    check('lua identifier uncoloured', colorAt(s, lua.indexOf('onBeatHit')) == 0);

    var hx = 'class Foo extends Bar {\n  // c\n  var s:String = "a\\"b"; /* x */ return 3.5;\n}';
    var h = SyntaxHighlighter.highlight(hx, 'haxe');
    check('haxe keyword class', colorAt(h, 0) == SyntaxHighlighter.KEYWORD);
    check('haxe type capitalised', colorAt(h, hx.indexOf('Foo')) == SyntaxHighlighter.TYPE);
    check('haxe escaped quote stays in string', colorAt(h, hx.indexOf('b";')) == SyntaxHighlighter.STRING);
    check('haxe block comment', colorAt(h, hx.indexOf('x */')) == SyntaxHighlighter.COMMENT);
    check('haxe float number', colorAt(h, hx.indexOf('3.5') + 2) == SyntaxHighlighter.NUMBER);

    var js = '{"a": [1, true, null], "b": "x"}';
    var j = SyntaxHighlighter.highlight(js, 'json');
    check('json key string', colorAt(j, 1) == SyntaxHighlighter.STRING);
    check('json true', colorAt(j, js.indexOf('true')) == SyntaxHighlighter.KEYWORD);

    var x = '<TextureAtlas imagePath="a.png"><!-- c --></TextureAtlas>';
    var xs = SyntaxHighlighter.highlight(x, 'xml');
    check('xml tag', colorAt(xs, 1) == SyntaxHighlighter.TAG);
    check('xml attr string', colorAt(xs, x.indexOf('a.png')) == SyntaxHighlighter.STRING);
    check('xml comment', colorAt(xs, x.indexOf(' c ')) == SyntaxHighlighter.COMMENT);

    var b = 'f(a[1], {x: (2)})';
    check('bracket match forward', SyntaxHighlighter.matchBracket(b, 1) == b.length - 1);
    check('bracket match backward', SyntaxHighlighter.matchBracket(b, b.length - 2) == b.indexOf('{'));
    check('no bracket -> -1', SyntaxHighlighter.matchBracket(b, 0) == -1);
    check('language detection', SyntaxHighlighter.languageFor('scripts/a.hxc') == 'haxe' && SyntaxHighlighter.languageFor('x.LUA') == 'lua');

    Sys.println('\n$pass passed, $fail failed');
    Sys.exit(fail == 0 ? 0 : 1);
  }
}
