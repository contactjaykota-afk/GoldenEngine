package golden.studio;

import flixel.FlxSprite;
import flixel.text.FlxInputText;
import flixel.text.FlxInputText.FlxInputTextChange;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextFormat;
import flixel.util.FlxColor;
import funkin.modding.PolymodHandler;
import funkin.ui.MusicBeatState;
import golden.audio.UISound;
import golden.studio.SyntaxHighlighter;
import golden.ui.GoldenDialogs;
import golden.ui.GoldenUI;
import golden.ui.GoldenUI.GoldenButton;
#if sys
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#end

typedef OpenDoc =
{
  var path:String; // relative to the mod root
  var text:String;
  var saved:String;
  var undo:Array<{text:String, caret:Int}>;
  var redo:Array<{text:String, caret:Int}>;
  var caret:Int;
  var scroll:Int;
}

/**
 * Golden Studio — Script Editor for one mod (opened from the Mod Manager with S).
 *
 * Left: the mod's files (scripts, data, text). Top: open tabs (`*` = unsaved). Centre: editor with
 * line numbers, syntax highlighting (Haxe/HScript, Lua, JSON, XML), bracket matching, auto-indent,
 * Tab = 2 spaces. Ctrl+S save (previous version kept in mods/.trash/backups/), Ctrl+Z / Ctrl+Y undo /
 * redo, Ctrl+F find (Enter = next), Ctrl+N new file (with templates), Ctrl+W close tab,
 * Ctrl+Tab next tab, Ctrl+R save all + reload mods, Esc back to the Mod Manager.
 * Saving validates: JSON and XML are parsed; Lua is compiled (syntax only); HScript is not validated
 * here (Polymod reports script errors when the mod reloads — see the F8 console).
 */
class ScriptEditorState extends MusicBeatState
{
  static final EDITABLE:Array<String> = ['hx', 'hxc', 'lua', 'json', 'xml', 'txt', 'md', 'frag', 'vert', 'csv'];
  static inline var MAX_HIGHLIGHT_CHARS:Int = 60000;
  static inline var TREE_W:Int = 300;
  static inline var TOP:Int = 70;
  static inline var LINE_H:Float = 16.6;

  public var modDir(default, null):String;

  var root:String;
  var files:Array<String> = [];
  var treeText:FlxText;
  var treeSel:Int = 0;
  var treeScroll:Int = 0;
  var docs:Array<OpenDoc> = [];
  var current:Int = -1;
  var tabsText:FlxText;
  var editor:FlxInputText;
  var gutter:FlxText;
  var status:FlxText;
  var findField:FlxInputText;
  var findLabel:FlxText;
  var highlightDirty:Bool = false;
  var highlightTimer:Float = 0;
  var lastUndoPush:Float = 0;
  var suppressChange:Bool = false;
  var bracketFormat:FlxTextFormat;

  public function new(modDir:String)
  {
    super();
    this.modDir = modDir;
    root = Path.join([golden.modding.GoldenMods.modRoot(), modDir]);
  }

  override function create():Void
  {
    super.create();
    FlxG.mouse.visible = true;
    add(GoldenUI.panel(0, 0, FlxG.width, FlxG.height, 0xFF120E18));
    add(GoldenUI.text(12, 8, 600, 'GOLDEN STUDIO  -  Script Editor  -  $modDir', 20, GoldenUI.GOLD));
    add(GoldenUI.text(12, 34, FlxG.width - 24,
      'Ctrl+S save  Ctrl+Z/Y undo/redo  Ctrl+F find  Ctrl+N new  Ctrl+W close  Ctrl+Tab next  Ctrl+R reload mods  Esc back', 12, GoldenUI.MUTED));

    add(GoldenUI.panel(0, TOP - 4, TREE_W, FlxG.height - TOP - 24, 0xFF1A1522));
    treeText = GoldenUI.text(8, TOP, TREE_W - 12, '', 13);
    treeText.wordWrap = false;
    treeText.clipRect = new flixel.math.FlxRect(0, 0, TREE_W - 12, FlxG.height);
    add(treeText);

    tabsText = GoldenUI.text(TREE_W + 8, TOP - 2, FlxG.width - TREE_W - 16, '', 13, GoldenUI.TEXT);
    add(tabsText);

    var ex = TREE_W + 56;
    gutter = new FlxText(TREE_W + 4, TOP + 22, 48, '', 14);
    gutter.setFormat(Paths.font('vcr.ttf'), 14, 0xFF6F7A96, RIGHT);
    add(gutter);
    editor = new FlxInputText(ex, TOP + 22, FlxG.width - ex - 10, '', 14, 0xFFE6E0D0, 0xFF0E0B14);
    editor.font = Paths.font('vcr.ttf');
    editor.multiline = true;
    editor.wordWrap = false;
    editor.fieldHeight = FlxG.height - TOP - 22 - 30;
    editor.fieldBorderThickness = 0;
    editor.caretColor = GoldenUI.GOLD;
    editor.onTextChange.add(onEdited);
    editor.onScrollChange.add((_, _) -> updateGutter());
    add(editor);

    status = GoldenUI.text(8, FlxG.height - 22, FlxG.width - 16, '', 13, GoldenUI.MUTED);
    add(status);
    findLabel = GoldenUI.text(FlxG.width - 330, 8, 50, 'Find:', 14, GoldenUI.MUTED);
    findField = new FlxInputText(FlxG.width - 280, 6, 270, '', 14, FlxColor.WHITE, 0xFF2C2436);
    findField.font = Paths.font('vcr.ttf');
    findLabel.visible = findField.visible = false;
    add(findLabel);
    add(findField);
    bracketFormat = new FlxTextFormat(0xFF000000, false, false, 0xFFFFC83D);

    scanFiles();
    trace('[GOLDEN] Script editor opened for "$modDir" (${files.length} files)');
    if (files.length > 0) openFile(files[0]);
    else
      setStatus('This mod has no editable files yet. Ctrl+N creates one.', GoldenUI.MUTED);
    redrawTree();
  }

  function setStatus(msg:String, color:FlxColor):Void
  {
    status.text = msg;
    status.color = color;
  }

  // --- files ----------------------------------------------------------------------------------

  function scanFiles():Void
  {
    files = [];
    #if sys
    function walk(rel:String)
    {
      var full = rel == '' ? root : Path.join([root, rel]);
      if (!FileSystem.exists(full)) return;
      var names = FileSystem.readDirectory(full);
      names.sort((a, b) -> Reflect.compare(a.toLowerCase(), b.toLowerCase()));
      for (n in names)
      {
        if (n.startsWith('.')) continue;
        var r = rel == '' ? n : '$rel/$n';
        if (FileSystem.isDirectory(Path.join([root, r]))) walk(r);
        else if (EDITABLE.contains(Path.extension(n).toLowerCase())) files.push(r);
      }
    }
    walk('');
    #end
  }

  function redrawTree():Void
  {
    var visible = Std.int((FlxG.height - TOP - 30) / 16);
    if (treeSel < treeScroll) treeScroll = treeSel;
    if (treeSel >= treeScroll + visible) treeScroll = treeSel - visible + 1;
    var lines = [];
    for (i in treeScroll...Std.int(Math.min(files.length, treeScroll + visible)))
    {
      var f = files[i];
      var open = docIndex(f) >= 0;
      var dirty = open && docs[docIndex(f)].text != docs[docIndex(f)].saved;
      lines.push((i == treeSel ? '> ' : '  ') + f + (dirty ? ' *' : '') + (open && !dirty ? ' o' : ''));
    }
    treeText.text = lines.join('\n');
  }

  function docIndex(path:String):Int
  {
    for (i in 0...docs.length)
      if (docs[i].path == path) return i;
    return -1;
  }

  function openFile(rel:String):Void
  {
    var i = docIndex(rel);
    if (i < 0)
    {
      var text = '';
      #if sys
      try
      {
        text = File.getContent(Path.join([root, rel]));
      }
      catch (e:Dynamic)
      {
        setStatus('Could not open $rel: $e', GoldenUI.BAD);
        UISound.play(Error);
        return;
      }
      #end
      text = text.replace('\r\n', '\n').replace('\t', '  ');
      docs.push({path: rel, text: text, saved: text, undo: [], redo: [], caret: 0, scroll: 1});
      i = docs.length - 1;
    }
    switchTo(i);
  }

  function switchTo(i:Int):Void
  {
    storeCurrent();
    current = i;
    var d = docs[i];
    suppressChange = true;
    editor.text = d.text;
    suppressChange = false;
    editor.caretIndex = Std.int(Math.min(d.caret, d.text.length));
    editor.scrollV = d.scroll;
    editor.startFocus();
    highlightNow();
    updateGutter();
    redrawTabs();
    redrawTree();
    setStatus('${d.path}  (${SyntaxHighlighter.languageFor(d.path)})', GoldenUI.MUTED);
  }

  function storeCurrent():Void
  {
    if (current < 0 || current >= docs.length) return;
    docs[current].caret = editor.caretIndex;
    docs[current].scroll = editor.scrollV;
    docs[current].text = editor.text;
  }

  function redrawTabs():Void
  {
    tabsText.text = [
      for (i in 0...docs.length)
        (i == current ? '[' : ' ') + Path.withoutDirectory(docs[i].path) + (docs[i].text != docs[i].saved ? '*' : '') + (i == current ? ']' : ' ')
    ].join(' ');
  }

  // --- editing --------------------------------------------------------------------------------

  function onEdited(text:String, change:FlxInputTextChange):Void
  {
    if (suppressChange || current < 0) return;
    var d = docs[current];
    var now = haxe.Timer.stamp();
    // Coalesce typing into undo steps of ~0.6 s; any pause starts a new step.
    if (now - lastUndoPush > 0.6 || d.undo.length == 0)
    {
      d.undo.push({text: d.text, caret: d.caret});
      if (d.undo.length > 200) d.undo.shift();
      d.redo = [];
    }
    lastUndoPush = now;
    // Auto-indent: a newline copies the previous line's indentation.
    if (change == INPUT_ACTION && editor.caretIndex > 0 && text.charAt(editor.caretIndex - 1) == '\n')
    {
      var prevStart = text.lastIndexOf('\n', editor.caretIndex - 2) + 1;
      var indent = '';
      while (prevStart + indent.length < text.length && text.charAt(prevStart + indent.length) == ' ')
        indent += ' ';
      if (indent.length > 0)
      {
        suppressChange = true;
        editor.replaceSelectedText(indent);
        suppressChange = false;
        text = editor.text;
      }
    }
    d.text = text;
    d.caret = editor.caretIndex;
    highlightDirty = true;
    highlightTimer = 0.15; // debounce: re-highlight after a short pause
    updateGutter();
    redrawTabs();
  }

  function applyUndo(redo:Bool):Void
  {
    if (current < 0) return;
    var d = docs[current];
    var from = redo ? d.redo : d.undo;
    var to = redo ? d.undo : d.redo;
    if (from.length == 0)
    {
      UISound.play(Error);
      return;
    }
    to.push({text: editor.text, caret: editor.caretIndex});
    var s = from.pop();
    suppressChange = true;
    editor.text = s.text;
    suppressChange = false;
    editor.caretIndex = Std.int(Math.min(s.caret, s.text.length));
    d.text = s.text;
    lastUndoPush = 0;
    highlightNow();
    updateGutter();
    redrawTabs();
  }

  function highlightNow():Void
  {
    highlightDirty = false;
    editor.clearFormats();
    if (current < 0) return;
    var t = editor.text;
    if (t.length > MAX_HIGHLIGHT_CHARS) return; // very large files: plain text keeps typing fast
    for (s in SyntaxHighlighter.highlight(t, SyntaxHighlighter.languageFor(docs[current].path)))
      editor.addFormat(new FlxTextFormat(s.color), s.start, s.end);
    var caret = editor.caretIndex;
    for (p in [caret, caret - 1])
    {
      var m = SyntaxHighlighter.matchBracket(t, p);
      if (m >= 0)
      {
        editor.addFormat(bracketFormat, p, p + 1);
        editor.addFormat(bracketFormat, m, m + 1);
        break;
      }
    }
  }

  function updateGutter():Void
  {
    var first = editor.scrollV;
    var lines = editor.text.split('\n').length;
    var visible = Std.int(editor.fieldHeight / LINE_H) + 1;
    gutter.text = [for (l in first...Std.int(Math.min(lines, first + visible - 1) + 1)) Std.string(l)].join('\n');
    if (current >= 0)
    {
      var before = editor.text.substr(0, editor.caretIndex);
      var line = before.split('\n').length;
      var col = editor.caretIndex - before.lastIndexOf('\n');
      var d = docs[current];
      status.text = '${d.path}   Ln $line, Col $col   ${lines} lines   ${SyntaxHighlighter.languageFor(d.path)}' + (d.text != d.saved ? '   UNSAVED' : '');
    }
  }

  // --- commands -------------------------------------------------------------------------------

  /** Validate and save the current document. Returns false if it was not saved. */
  function saveCurrent():Bool
  {
    if (current < 0) return false;
    storeCurrent();
    var d = docs[current];
    var problem = validate(d.path, d.text);
    #if sys
    var full = Path.join([root, d.path]);
    try
    {
      if (FileSystem.exists(full))
      {
        var backupDir = Path.join([golden.modding.GoldenMods.modRoot(), golden.modding.ModOps.TRASH_DIR, 'backups', modDir, Path.directory(d.path)]);
        createDirs(backupDir);
        File.copy(full, Path.join([backupDir, Path.withoutDirectory(d.path) + '.' + DateTools.format(Date.now(), '%Y%m%d-%H%M%S') + '.bak']));
      }
      createDirs(Path.directory(full));
      File.saveContent(full, d.text);
    }
    catch (e:Dynamic)
    {
      setStatus('Save failed: $e', GoldenUI.BAD);
      UISound.play(Error);
      trace('[GOLDEN] Script editor: save failed for ${d.path}: $e');
      return false;
    }
    #end
    d.saved = d.text;
    redrawTabs();
    redrawTree();
    if (problem != null)
    {
      setStatus('Saved ${d.path}, but: $problem', GoldenUI.WARN);
      trace('[GOLDEN] Script editor: saved ${d.path} with problem: $problem');
      UISound.play(Error);
    }
    else
    {
      setStatus('Saved ${d.path}' + (SyntaxHighlighter.languageFor(d.path) == 'haxe' ? ' (HScript is checked when mods reload: Ctrl+R, errors in F8)' : ' (valid)'), GoldenUI.OK);
      trace('[GOLDEN] Script editor: saved ${d.path} (valid)');
      UISound.play(Select);
    }
    return true;
  }

  public static function validate(path:String, text:String):Null<String>
  {
    switch (SyntaxHighlighter.languageFor(path))
    {
      case 'json':
        try
          haxe.Json.parse(text)
        catch (e:Dynamic)
          return 'invalid JSON: $e';
      case 'xml':
        try
          Xml.parse(text)
        catch (e:Dynamic)
          return 'invalid XML: $e';
      case 'lua':
        #if FEATURE_LUA
        return golden.lua.LuaScript.checkSyntax(text, path);
        #end
      default:
    }
    return null;
  }

  #if sys
  static function createDirs(dir:String):Void
  {
    if (dir == '' || FileSystem.exists(dir)) return;
    createDirs(Path.directory(dir));
    FileSystem.createDirectory(dir);
  }
  #end

  function anyDirty():Bool
  {
    storeCurrent();
    for (d in docs)
      if (d.text != d.saved) return true;
    return false;
  }

  function closeCurrent():Void
  {
    if (current < 0) return;
    var close = function()
    {
      docs.splice(current, 1);
      current = -1;
      if (docs.length > 0) switchTo(0);
      else
      {
        suppressChange = true;
        editor.text = '';
        suppressChange = false;
        redrawTabs();
        redrawTree();
        updateGutter();
      }
    };
    storeCurrent();
    var d = docs[current];
    if (d.text != d.saved) openSubState(new GoldenConfirmSubState('Close ${d.path} without saving?', close));
    else
      close();
  }

  function newFile():Void
  {
    editor.endFocus();
    openSubState(new GoldenPromptSubState('New file (path inside the mod), e.g. scripts/lua/myscript.lua', 'scripts/lua/new-script.lua', function(rel:String)
    {
      rel = rel.trim().replace('\\', '/');
      if (rel == '' || rel.indexOf('..') >= 0 || rel.startsWith('/') || !EDITABLE.contains(Path.extension(rel).toLowerCase()))
      {
        setStatus('Invalid file name "$rel" (allowed: ${EDITABLE.join(', ')})', GoldenUI.BAD);
        UISound.play(Error);
        return;
      }
      #if sys
      var full = Path.join([root, rel]);
      if (FileSystem.exists(full))
      {
        setStatus('$rel already exists; opened it.', GoldenUI.WARN);
      }
      else
      {
        try
        {
          createDirs(Path.directory(full));
          File.saveContent(full, templateFor(rel));
        }
        catch (e:Dynamic)
        {
          setStatus('Could not create $rel: $e', GoldenUI.BAD);
          return;
        }
        trace('[GOLDEN] Script editor: created $rel');
      }
      #end
      scanFiles();
      treeSel = Std.int(Math.max(0, files.indexOf(rel)));
      openFile(rel);
    }));
  }

  static function templateFor(rel:String):String
  {
    return switch (SyntaxHighlighter.languageFor(rel))
    {
      case 'lua': '-- Golden Engine Lua script. Callbacks: onCreate, onSongStart, onBeatHit(beat), onStepHit(step),\n'
        + '-- onUpdate(elapsed), onNoteHit(direction, isPlayer, kind), onNoteMiss(direction), onEvent(name, value), onSongEnd.\n\n'
        + 'function onCreate()\n  print("loaded " .. tostring(getSongName()))\nend\n\nfunction onBeatHit(beat)\nend\n';
      case 'haxe': 'import funkin.modding.module.Module;\nimport funkin.modding.events.ScriptEvent;\n\n'
        + 'class ' + ~/[^A-Za-z0-9]/g.replace(Path.withoutExtension(Path.withoutDirectory(rel)), '') + ' extends Module\n{\n'
        + '  public function new()\n  {\n    super("' + Path.withoutExtension(Path.withoutDirectory(rel)) + '");\n  }\n\n'
        + '  override function onBeatHit(event:SongTimeScriptEvent):Void\n  {\n    super.onBeatHit(event);\n  }\n}\n';
      case 'json': '{\n}\n';
      case 'xml': '<?xml version="1.0" encoding="utf-8"?>\n';
      default: '';
    }
  }

  function findNext():Void
  {
    var q = findField.text;
    if (q == '' || current < 0) return;
    var t = editor.text;
    var from = editor.selectionEndIndex;
    var i = t.indexOf(q, from);
    if (i < 0) i = t.indexOf(q); // wrap
    if (i < 0)
    {
      setStatus('"$q" not found', GoldenUI.WARN);
      UISound.play(Error);
      return;
    }
    editor.startFocus();
    editor.setSelection(i, i + q.length);
    editor.scrollV = Std.int(Math.max(1, t.substr(0, i).split('\n').length - 5));
    updateGutter();
    setStatus('Found "$q" at line ${t.substr(0, i).split('\n').length}', GoldenUI.TEXT);
  }

  function reloadMods():Void
  {
    for (i in 0...docs.length)
      if (docs[i].text != docs[i].saved)
      {
        switchTo(i);
        if (!saveCurrent()) return;
      }
    trace('[GOLDEN] Script editor: reloading mods');
    PolymodHandler.forceReloadAssets();
    var errs = golden.modding.GoldenMods.loadErrors.length;
    setStatus('Mods reloaded' + (errs > 0 ? ' with $errs problem(s) (see F8 console)' : ' - scripts are live for the next song/menu'), errs > 0 ? GoldenUI.WARN : GoldenUI.OK);
  }

  function leave():Void
  {
    var go = function() FlxG.switchState(() -> new golden.ui.ModManagerState());
    if (anyDirty())
    {
      editor.endFocus();
      openSubState(new GoldenConfirmSubState('You have unsaved changes. Leave without saving?', go));
    }
    else
      go();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (subState != null) return;
    var ctrl = FlxG.keys.pressed.CONTROL;

    if (highlightDirty)
    {
      highlightTimer -= elapsed;
      if (highlightTimer <= 0) highlightNow();
    }

    if (ctrl && FlxG.keys.justPressed.S) saveCurrent();
    else if (ctrl && FlxG.keys.justPressed.Z) applyUndo(false);
    else if (ctrl && FlxG.keys.justPressed.Y) applyUndo(true);
    else if (ctrl && FlxG.keys.justPressed.N) newFile();
    else if (ctrl && FlxG.keys.justPressed.W) closeCurrent();
    else if (ctrl && FlxG.keys.justPressed.R) reloadMods();
    else if (ctrl && FlxG.keys.justPressed.TAB && docs.length > 1) switchTo((current + 1) % docs.length);
    else if (ctrl && FlxG.keys.justPressed.F)
    {
      findLabel.visible = findField.visible = true;
      findField.startFocus();
      findField.setSelection(0, findField.text.length);
    }
    else if (findField.hasFocus && FlxG.keys.justPressed.ENTER) findNext();
    else if (findField.hasFocus && FlxG.keys.justPressed.ESCAPE)
    {
      findLabel.visible = findField.visible = false;
      findField.endFocus();
      editor.startFocus();
    }
    else if (editor.hasFocus && FlxG.keys.justPressed.TAB && !ctrl)
    {
      editor.replaceSelectedText('  ');
    }
    else if (FlxG.keys.justPressed.ESCAPE) leave();
    else if (!editor.hasFocus && !findField.hasFocus)
    {
      // File list navigation when the editor does not have focus (click the list, or Esc focus).
      if (controls.UI_UP_P && files.length > 0)
      {
        treeSel = (treeSel - 1 + files.length) % files.length;
        redrawTree();
      }
      if (controls.UI_DOWN_P && files.length > 0)
      {
        treeSel = (treeSel + 1) % files.length;
        redrawTree();
      }
      if (FlxG.keys.justPressed.ENTER && files.length > 0) openFile(files[treeSel]);
    }

    // Mouse: click a file in the list.
    if (FlxG.mouse.justReleased && FlxG.mouse.screenX < TREE_W && FlxG.mouse.screenY > TOP)
    {
      var idx = treeScroll + Std.int((FlxG.mouse.screenY - TOP) / 16);
      if (idx >= 0 && idx < files.length)
      {
        treeSel = idx;
        openFile(files[idx]);
      }
    }
    if (editor.hasFocus && (FlxG.keys.justPressed.ANY || FlxG.mouse.justReleased)) updateGutter();
  }
}
