package golden.editor;

import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxInputText;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.display.BitmapData;
import golden.audio.UISound;

/**
 * Golden Engine editor kit — shared widgets used by every Golden editor (one look, one behaviour).
 *
 * All widgets live on the editor's UI camera. When the environment variable `GOLDEN_UI_MAP=1` is set,
 * every widget logs its screen rectangle as `[GOLDEN UI] <id> @ x,y,w,h`, so automated tests can click
 * buttons and fields by name with real mouse input.
 */
class EditorUI
{
  public static inline var BG:FlxColor = 0xFF17151C;
  public static inline var PANEL:FlxColor = 0xFF211E28;
  public static inline var PANEL2:FlxColor = 0xFF2B2734;
  public static inline var HEADER:FlxColor = 0xFF3A2C5C; // Golden purple toolbar
  public static inline var ACCENT:FlxColor = 0xFFFFC83D;
  public static inline var TEXT:FlxColor = 0xFFF4EEDD;
  public static inline var MUTED:FlxColor = 0xFF9A93A8;
  public static inline var FIELD:FlxColor = 0xFF100E14;
  public static inline var SELECT:FlxColor = 0xFF5B4A1A;

  static var mapEnabled:Null<Bool> = null;

  public static function mapLog(id:String, x:Float, y:Float, w:Float, h:Float):Void
  {
    if (mapEnabled == null) mapEnabled = #if sys Sys.getEnv('GOLDEN_UI_MAP') == '1' #else false #end;
    if (mapEnabled) trace('[GOLDEN UI] $id @ ${Std.int(x)},${Std.int(y)},${Std.int(w)},${Std.int(h)}');
  }

  public static function text(x:Float, y:Float, w:Float, str:String, size:Int = 14, color:FlxColor = TEXT):FlxText
  {
    var t = new FlxText(x, y, w, str, size);
    t.setFormat(Paths.font('vcr.ttf'), size, color, LEFT);
    t.scrollFactor.set();
    return t;
  }

  public static function rect(x:Float, y:Float, w:Int, h:Int, color:FlxColor):FlxSprite
  {
    var s = new FlxSprite(x, y).makeGraphic(Std.int(Math.max(1, w)), Std.int(Math.max(1, h)), FlxColor.WHITE);
    s.color = color;
    s.alpha = color.alphaFloat;
    s.scrollFactor.set();
    return s;
  }

  /** Mouse position on a camera's screen (UI coordinates). */
  public static function mouseOver(cam:FlxCamera, x:Float, y:Float, w:Float, h:Float):Bool
  {
    if (!FlxG.mouse.visible) return false;
    var p = FlxG.mouse.getViewPosition(cam);
    var r = p.x >= x && p.x < x + w && p.y >= y && p.y < y + h;
    p.put();
    return r;
  }
}

/** Button with hover/press feedback, optional toggle state and tooltip. */
class EButton extends FlxSpriteGroup
{
  public var onClick:Null<Void->Void>;
  public var tooltip:String = '';
  public var toggled(default, set):Bool = false;
  public var enabled(default, set):Bool = true;
  public var caption(default, null):String;
  public var bw:Int;
  public var bh:Int;

  var bg:FlxSprite;
  var label:FlxText;
  var hovered:Bool = false;
  var pressT:Float = 0;

  public function new(x:Float, y:Float, w:Int, h:Int, caption:String, ?onClick:Void->Void, ?tooltip:String)
  {
    super(x, y);
    this.caption = caption;
    this.onClick = onClick;
    this.tooltip = tooltip ?? '';
    bw = w;
    bh = h;
    bg = EditorUI.rect(0, 0, w, h, EditorUI.PANEL2);
    add(bg);
    label = new FlxText(0, 0, w, caption, 13);
    label.setFormat(Paths.font('vcr.ttf'), 13, EditorUI.TEXT, CENTER);
    label.y = Std.int((h - label.height) / 2);
    add(label);
    scrollFactor.set();
    if (!suppressLog) EditorUI.mapLog('button:$caption', x, y, w, h);
  }

  /** Set while building rows whose positions are logged later by their container (Inspector). */
  public static var suppressLog:Bool = false;

  public function setCaption(c:String):Void
  {
    caption = c;
    label.text = c;
  }

  /** Log the current position again (after the button was moved). */
  public function relog():Void
    EditorUI.mapLog('button:$caption', x, y, bw, bh);

  function set_toggled(v:Bool):Bool
  {
    toggled = v;
    refreshColor();
    return v;
  }

  function set_enabled(v:Bool):Bool
  {
    enabled = v;
    alpha = v ? 1 : 0.4;
    return v;
  }

  function refreshColor():Void
  {
    if (bg == null) return;
    bg.color = toggled ? EditorUI.SELECT : (hovered ? 0xFF46405A : EditorUI.PANEL2);
    label.color = toggled ? EditorUI.ACCENT : EditorUI.TEXT;
  }

  public function isHovered():Bool
    return hovered;

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (!visible || !exists) return;
    if (pressT > 0)
    {
      pressT -= elapsed;
      var s = pressT > 0 ? 0.96 : 1.0;
      bg.scale.set(s, s);
    }
    var over = enabled && EditorUI.mouseOver(camera, x, y, bw, bh);
    if (over != hovered)
    {
      hovered = over;
      refreshColor();
      if (over) UISound.play(Hover);
      if (over && tooltip != '') EditorTooltip.show(tooltip);
      else if (!over) EditorTooltip.hide(tooltip);
    }
    if (over && FlxG.mouse.justReleased && onClick != null)
    {
      pressT = 0.08;
      UISound.play(Click);
      onClick();
    }
  }
}

/** Status-bar tooltip channel (the editor's status bar reads it). */
class EditorTooltip
{
  public static var current:String = '';

  public static function show(t:String):Void
    current = t;

  public static function hide(t:String):Void
    if (current == t) current = '';
}

/** Single-line text field (Golden style). `onCommit` fires on Enter and when focus is lost. */
class EField extends FlxSpriteGroup
{
  public var input:FlxInputText;
  public var onCommit:Null<String->Void>;
  public var onChange:Null<String->Void>;

  var lastCommitted:String;

  public function new(x:Float, y:Float, w:Int, value:String, ?id:String, size:Int = 14)
  {
    super(x, y);
    input = new FlxInputText(0, 0, w, value, size, EditorUI.TEXT, EditorUI.FIELD);
    input.setFormat(Paths.font('vcr.ttf'), size, EditorUI.TEXT);
    input.fieldBorderColor = 0xFF4A4458;
    input.fieldBorderThickness = 1;
    input.caretColor = EditorUI.ACCENT;
    input.scrollFactor.set();
    add(input);
    lastCommitted = value;
    input.onEnter.add(_ -> commit());
    input.onFocusChange.add(f -> if (!f) commit());
    input.onTextChange.add((t, _) -> if (onChange != null) onChange(t));
    scrollFactor.set();
    if (id != null) EditorUI.mapLog('field:$id', x, y, w, input.height);
  }

  public var text(get, set):String;

  function get_text():String
    return input?.text ?? '';

  function set_text(v:String):String
  {
    if (input != null && !input.hasFocus)
    {
      input.text = v;
      lastCommitted = v;
    }
    return v;
  }

  public function hasFocus():Bool
    return input != null && input.hasFocus;

  /**
   * Flixel 6 crashes when an FlxInputText is destroyed while inside an FlxSpriteGroup (the group moves
   * it after its background sprites are gone), so the input is detached first.
   */
  override function destroy():Void
  {
    if (input != null)
    {
      var i = input;
      input = null;
      i.endFocus();
      remove(i, true);
      i.destroy();
    }
    super.destroy();
  }

  function commit():Void
  {
    if (input == null || input.text == lastCommitted) return;
    lastCommitted = input.text;
    if (onCommit != null) onCommit(input.text);
  }
}

private typedef InspectorRow =
{
  group:FlxSpriteGroup,
  h:Float,
  ?refresh:Void->Void,
  ?id:String,
  ?rel:Array<{dx:Float, dy:Float, w:Float, h:Float, id:String}>
}

/**
 * Property inspector: a scrollable column of labelled rows (header, text, number with -/+ steps,
 * toggle, choice, buttons). Values are read through getters on `refresh()` and written through setters,
 * so the inspector never owns data.
 */
class Inspector extends FlxSpriteGroup
{
  public var pw:Int;
  public var ph:Int;

  var rows:Array<InspectorRow> = [];
  var scrollY:Float = 0;
  var contentH:Float = 0;
  var bg:FlxSprite;
  var labelW:Int;

  public function new(x:Float, y:Float, w:Int, h:Int)
  {
    super(x, y);
    pw = w;
    ph = h;
    labelW = Std.int(w * 0.42);
    bg = EditorUI.rect(0, 0, w, h, EditorUI.PANEL);
    add(bg);
    scrollFactor.set();
  }

  public static function fmt(v:Float):String
    return Std.string(Math.round(v * 1000) / 1000);

  public function clearRows():Void
  {
    EditorUI.mapLog('inspector:cleared', 0, 0, 0, 0);
    for (r in rows)
    {
      remove(r.group, true);
      r.group.destroy();
    }
    rows = [];
    contentH = 0;
    // (scroll position is kept across rebuilds; clamped in update() once the rows exist)
  }

  function addRow(g:FlxSpriteGroup, h:Float, ?refresh:Void->Void, ?rel:Array<{dx:Float, dy:Float, w:Float, h:Float, id:String}>):Void
  {
    EButton.suppressLog = false;
    g.scrollFactor.set();
    rows.push({group: g, h: h, refresh: refresh, rel: rel});
    add(g);
    g.cameras = cameras;
    contentH += h;
    layout();
  }

  public function addHeader(title:String):Void
  {
    var g = new FlxSpriteGroup();
    g.add(EditorUI.rect(0, 2, pw, 22, EditorUI.PANEL2));
    g.add(EditorUI.text(8, 5, pw - 16, title.toUpperCase(), 13, EditorUI.ACCENT));
    addRow(g, 28);
  }

  public function addNote(str:String, color:FlxColor = EditorUI.MUTED):FlxText
  {
    var g = new FlxSpriteGroup();
    var t = EditorUI.text(8, 2, pw - 16, str, 12, color);
    g.add(t);
    addRow(g, t.height + 6);
    return t;
  }

  public function addText(label:String, get:Void->String, set:String->Void):EField
  {
    var g = new FlxSpriteGroup();
    g.add(EditorUI.text(8, 4, labelW - 8, label, 13, EditorUI.MUTED));
    var f = new EField(labelW, 1, pw - labelW - 8, get());
    f.onCommit = v -> set(v);
    g.add(f);
    addRow(g, 26, () -> f.text = get(), [{dx: labelW, dy: 1, w: pw - labelW - 8, h: 20, id: 'field:$label'}]);
    return f;
  }

  public function addNumber(label:String, get:Void->Float, set:Float->Void, step:Float = 1, ?min:Float, ?max:Float):EField
  {
    EButton.suppressLog = true;
    var g = new FlxSpriteGroup();
    g.add(EditorUI.text(8, 4, labelW - 8, label, 13, EditorUI.MUTED));
    var fw = pw - labelW - 8 - 52;
    var f = new EField(labelW, 1, fw, fmt(get()));
    function apply(v:Float)
    {
      if (Math.isNaN(v)) return;
      if (min != null && v < min) v = min;
      if (max != null && v > max) v = max;
      set(v);
      f.text = fmt(get());
    }
    f.onCommit = s -> apply(Std.parseFloat(s));
    var mult = () -> FlxG.keys.pressed.SHIFT ? 10.0 : 1.0;
    var minus = new EButton(labelW + fw + 4, 1, 22, 20, '-', () -> apply(get() - step * mult()));
    var plus = new EButton(labelW + fw + 28, 1, 22, 20, '+', () -> apply(get() + step * mult()));
    g.add(f);
    g.add(minus);
    g.add(plus);
    addRow(g, 26, () -> f.text = fmt(get()), [
      {dx: labelW, dy: 1, w: fw, h: 20, id: 'field:$label'},
      {dx: labelW + fw + 4, dy: 1, w: 22, h: 20, id: 'button:$label -'},
      {dx: labelW + fw + 28, dy: 1, w: 22, h: 20, id: 'button:$label +'}
    ]);
    return f;
  }

  public function addToggle(label:String, get:Void->Bool, set:Bool->Void):EButton
  {
    EButton.suppressLog = true;
    var g = new FlxSpriteGroup();
    g.add(EditorUI.text(8, 4, labelW - 8, label, 13, EditorUI.MUTED));
    var b:EButton = null;
    b = new EButton(labelW, 1, 70, 20, get() ? 'ON' : 'OFF', () ->
    {
      set(!get());
      b.setCaption(get() ? 'ON' : 'OFF');
      b.toggled = get();
    });
    b.toggled = get();
    g.add(b);
    addRow(g, 26, () ->
    {
      b.setCaption(get() ? 'ON' : 'OFF');
      b.toggled = get();
    }, [{dx: labelW, dy: 1, w: 70, h: 20, id: 'toggle:$label'}]);
    return b;
  }

  /** A value picked from a list: < and > step through `options()`; the middle shows the value. */
  public function addChoice(label:String, options:Void->Array<String>, get:Void->String, set:String->Void):Void
  {
    EButton.suppressLog = true;
    var g = new FlxSpriteGroup();
    g.add(EditorUI.text(8, 4, labelW - 8, label, 13, EditorUI.MUTED));
    var vw = pw - labelW - 8 - 48;
    var valueText = EditorUI.text(labelW + 24, 4, vw, get(), 13, EditorUI.TEXT);
    valueText.alignment = CENTER;
    function step(d:Int)
    {
      var o = options();
      if (o.length == 0) return;
      var i = o.indexOf(get());
      i = (i + d + o.length) % o.length;
      set(o[i]);
      valueText.text = get();
      trace('[GOLDEN EDITOR] $label = ${get()}');
    }
    g.add(EditorUI.rect(labelW + 24, 1, vw, 20, EditorUI.FIELD));
    g.add(valueText);
    g.add(new EButton(labelW, 1, 22, 20, '<', () -> step(-1)));
    g.add(new EButton(labelW + 26 + vw, 1, 22, 20, '>', () -> step(1)));
    addRow(g, 26, () -> valueText.text = get(), [
      {dx: labelW, dy: 1, w: 22, h: 20, id: 'button:$label <'},
      {dx: labelW + 26 + vw, dy: 1, w: 22, h: 20, id: 'button:$label >'}
    ]);
  }

  /** One or more buttons on a row, sharing the width. */
  public function addButtons(buttons:Array<{caption:String, fn:Void->Void, ?tooltip:String}>):Array<EButton>
  {
    EButton.suppressLog = true;
    var g = new FlxSpriteGroup();
    var n = buttons.length;
    var bw = Std.int((pw - 16 - (n - 1) * 4) / n);
    var made = [];
    var rel = [];
    for (i in 0...n)
    {
      var b = new EButton(8 + i * (bw + 4), 1, bw, 22, buttons[i].caption, buttons[i].fn, buttons[i].tooltip);
      made.push(b);
      g.add(b);
      rel.push({dx: 8.0 + i * (bw + 4), dy: 1.0, w: bw * 1.0, h: 22.0, id: 'button:${buttons[i].caption}'});
    }
    addRow(g, 28, null, rel);
    return made;
  }

  public function refresh():Void
  {
    for (r in rows)
      if (r.refresh != null) r.refresh();
  }

  function layout():Void
  {
    var yy = 4 - scrollY;
    for (r in rows)
    {
      r.group.x = x;
      r.group.y = y + yy;
      var inside = yy >= -2 && yy + r.h <= ph + 2;
      r.group.visible = inside;
      r.group.active = inside;
      if (inside && r.rel != null) for (e in r.rel)
        EditorUI.mapLog(e.id, x + e.dx, y + yy + e.dy, e.w, e.h);
      yy += r.h;
    }
  }

  override function update(elapsed:Float):Void
  {
    var maxScroll = Math.max(0, contentH - ph + 8);
    if (scrollY > maxScroll)
    {
      scrollY = maxScroll;
      EditorUI.mapLog('inspector:layout', 0, 0, 0, 0);
      layout();
    }
    if (FlxG.mouse.wheel != 0 && EditorUI.mouseOver(camera, x, y, pw, ph) && contentH > ph)
    {
      scrollY = Math.max(0, Math.min(contentH - ph + 8, scrollY - FlxG.mouse.wheel * 30));
      EditorUI.mapLog('inspector:layout', 0, 0, 0, 0); // positions logged after this marker are current
      layout();
    }
    super.update(elapsed);
  }
}

typedef BrowserItem =
{
  /** Folder path, e.g. "Poses" or "Animations/Sing". Items with the same path are listed together. */
  folder:String,
  label:String,
  ?thumb:BitmapData,
  ?data:Dynamic
}

/**
 * Browser panel: search box + expandable folders of items, optionally with thumbnails.
 * Click a folder header to expand/collapse it, click an item to select it.
 */
class Browser extends FlxSpriteGroup
{
  public var pw:Int;
  public var ph:Int;
  public var onSelect:Null<BrowserItem->Void>;
  /** Called when an item is pressed in the browser and released outside it (drag and drop). */
  public var onDragOut:Null<BrowserItem->Void>;
  public var selected(default, null):Null<BrowserItem>;
  var pressedItem:Null<BrowserItem> = null;
  public var search:EField;

  var items:Array<BrowserItem> = [];
  var collapsed:Map<String, Bool> = [];
  var rowsGroup:FlxSpriteGroup;
  var rowRects:Array<{y:Float, h:Float, item:Null<BrowserItem>, folder:String}> = [];
  var scrollY:Float = 0;
  var contentH:Float = 0;
  var needsRebuild:Bool = true;
  var thumbSize:Int;

  public function new(x:Float, y:Float, w:Int, h:Int, thumbSize:Int = 0)
  {
    super(x, y);
    pw = w;
    ph = h;
    this.thumbSize = thumbSize;
    add(EditorUI.rect(0, 0, w, h, EditorUI.PANEL));
    search = new EField(6, 6, w - 12, '');
    EditorUI.mapLog('field:browser search', x + 6, y + 6, w - 12, 20);
    search.onChange = _ -> needsRebuild = true;
    add(search);
    add(EditorUI.text(w - 64, 9, 60, 'search', 10, EditorUI.MUTED));
    rowsGroup = new FlxSpriteGroup();
    add(rowsGroup);
    scrollFactor.set();
  }

  /** Start a folder collapsed (until the user opens it). */
  public function collapse(folder:String):Void
    if (!collapsed.exists(folder)) collapsed.set(folder, true);

  public function setItems(list:Array<BrowserItem>):Void
  {
    items = list;
    if (selected != null) selected = list.find(i -> i.folder == selected.folder && i.label == selected.label);
    needsRebuild = true;
  }

  public function select(item:Null<BrowserItem>, fire:Bool = true):Void
  {
    selected = item;
    needsRebuild = true;
    if (fire && item != null && onSelect != null) onSelect(item);
  }

  public function selectBy(folder:String, label:String, fire:Bool = true):Void
    select(items.find(i -> i.folder == folder && i.label == label), fire);

  function rebuild():Void
  {
    needsRebuild = false;
    rowsGroup.forEach(s -> s.destroy());
    rowsGroup.clear();
    rowRects = [];
    var q = search.text.toLowerCase().trim();
    var folders:Array<String> = [];
    for (i in items)
      if (!folders.contains(i.folder)) folders.push(i.folder);
    var yy:Float = 34;
    var top = 34;
    for (f in folders)
    {
      var visibleItems = items.filter(i -> i.folder == f && (q == '' || i.label.toLowerCase().indexOf(q) >= 0 || f.toLowerCase().indexOf(q) >= 0));
      if (q != '' && visibleItems.length == 0) continue;
      var depth = f.split('/').length - 1;
      var open = !collapsed.get(f) || q != '';
      addRowSprite(yy, 22, null, f, (open ? '- ' : '+ ') + f.split('/').pop() + ' (${visibleItems.length})', depth, true);
      yy += 24;
      if (!open) continue;
      for (it in visibleItems)
      {
        var h = it.thumb != null && thumbSize > 0 ? thumbSize + 6 : 22;
        addRowSprite(yy, h, it, f, it.label, depth + 1, false);
        yy += h + 2;
      }
    }
    contentH = yy - top;
  }

  function addRowSprite(yy:Float, h:Int, item:Null<BrowserItem>, folder:String, label:String, depth:Int, isFolder:Bool):Void
  {
    var ry = yy - scrollY;
    rowRects.push({y: yy, h: h, item: item, folder: folder});
    if (ry < 30 || ry + h > ph) return;
    var isSel = item != null && selected != null && item == selected;
    var indent = 6 + depth * 10;
    rowsGroup.add(EditorUI.rect(4, ry, pw - 8, h, isSel ? EditorUI.SELECT : (isFolder ? EditorUI.PANEL2 : 0xFF1D1A23)));
    var tx = indent;
    if (item != null && item.thumb != null && thumbSize > 0)
    {
      var s = new FlxSprite(indent, ry + 3).loadGraphic(item.thumb.clone()); // own copy: the sprite's graphic disposes it
      var sc = Math.min(thumbSize / s.frameWidth, thumbSize / s.frameHeight);
      s.setGraphicSize(Std.int(s.frameWidth * sc), Std.int(s.frameHeight * sc));
      s.updateHitbox();
      s.scrollFactor.set();
      rowsGroup.add(EditorUI.rect(indent, ry + 3, thumbSize, thumbSize, 0xFF3A3645));
      rowsGroup.add(s);
      tx += thumbSize + 8;
    }
    var t = EditorUI.text(tx, ry + (h - 16) / 2, pw - tx - 8, label, 13, isFolder ? EditorUI.ACCENT : (isSel ? EditorUI.ACCENT : EditorUI.TEXT));
    rowsGroup.add(t);
    rowsGroup.cameras = cameras;
    EditorUI.mapLog(isFolder ? 'folder:$folder' : 'item:$folder/$label', x + 4, y + ry, pw - 8, h);
  }

  function itemAt(viewY:Float):Null<{y:Float, h:Float, item:Null<BrowserItem>, folder:String}>
  {
    var my = viewY - y + scrollY;
    for (r in rowRects)
      if (my >= r.y && my < r.y + r.h) return r;
    return null;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (needsRebuild) rebuild();
    var inside = EditorUI.mouseOver(camera, x, y + 30, pw, ph - 30);
    if (FlxG.mouse.justPressed && inside)
    {
      var p = FlxG.mouse.getViewPosition(camera);
      pressedItem = itemAt(p.y)?.item;
      p.put();
    }
    if (FlxG.mouse.justReleased && pressedItem != null && !inside)
    {
      var it = pressedItem;
      pressedItem = null;
      if (onDragOut != null) onDragOut(it);
      return;
    }
    if (FlxG.mouse.justReleased && !inside) pressedItem = null;
    if (!inside) return;
    if (FlxG.mouse.wheel != 0 && contentH > ph - 34)
    {
      scrollY = Math.max(0, Math.min(contentH - ph + 40, scrollY - FlxG.mouse.wheel * 40));
      needsRebuild = true;
    }
    if (FlxG.mouse.justReleased)
    {
      pressedItem = null;
      var p = FlxG.mouse.getViewPosition(camera);
      var my = p.y - y + scrollY;
      p.put();
      for (r in rowRects)
        if (my >= r.y && my < r.y + r.h)
        {
          if (r.item == null)
          {
            collapsed.set(r.folder, !collapsed.get(r.folder));
            UISound.play(Scroll);
            needsRebuild = true;
          }
          else
          {
            UISound.play(Click);
            select(r.item);
          }
          break;
        }
    }
  }
}

/** Short messages that fade out (bottom right). */
class Toasts extends FlxSpriteGroup
{
  var list:Array<{t:FlxText, bg:FlxSprite, life:Float}> = [];

  public function new()
  {
    super();
    scrollFactor.set();
  }

  public function push(msg:String, color:FlxColor):Void
  {
    var t = EditorUI.text(0, 0, 420, msg, 14, color);
    var bg = EditorUI.rect(0, 0, 432, Std.int(t.height + 10), 0xEE0E0C12);
    add(bg);
    add(t);
    list.push({t: t, bg: bg, life: 3.5});
    trace('[GOLDEN EDITOR] $msg');
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    var yy = FlxG.height - 34.0;
    var i = list.length - 1;
    while (i >= 0)
    {
      var e = list[i];
      e.life -= elapsed;
      if (e.life <= 0)
      {
        remove(e.t, true);
        remove(e.bg, true);
        e.t.destroy();
        e.bg.destroy();
        list.splice(i, 1);
      }
      else
      {
        yy -= e.bg.height + 4;
        e.bg.setPosition(FlxG.width - 440, yy);
        e.t.setPosition(FlxG.width - 434, yy + 5);
        var a = Math.min(1, e.life / 0.4);
        e.t.alpha = e.bg.alpha = a;
      }
      i--;
    }
  }
}
