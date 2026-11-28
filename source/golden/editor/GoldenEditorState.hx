package golden.editor;

import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxBasic;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.ui.MusicBeatState;
import golden.audio.UISound;
import golden.editor.EditorUI;
import golden.input.GoldenInput;

/**
 * Golden Engine editor kit — base state of every Golden editor.
 *
 * Layout: purple toolbar (top), browser (left), property inspector (right), status bar (bottom), and the
 * workspace in the middle, drawn by its own camera that can be panned (middle/right mouse drag, or hold
 * Space + left drag) and zoomed (mouse wheel, or Ctrl + -/=). Ctrl+S saves, Ctrl+Z / Ctrl+Y undo/redo,
 * Esc leaves (asking first when there are unsaved changes). Keyboard shortcuts are ignored while a text
 * field has focus.
 *
 * Live preview: subclasses keep their document in memory and rebuild the workspace preview from it
 * (`refreshPreview`) whenever something changes, so the result is visible immediately; files are only
 * written by `save()`. A preview error is shown in the status bar instead of crashing the editor.
 *
 * Undo/redo stores whole-document snapshots (`serialize()` / `deserialize()`), taken by `changed()`.
 */
class GoldenEditorState extends MusicBeatState
{
  public static inline var TOP:Int = 40;
  public static inline var BOTTOM:Int = 24;

  public var camWorld:FlxCamera;
  public var camUI:FlxCamera;
  public var leftW:Int = 270;
  public var rightW:Int = 330;

  var editorTitle:String;
  var toolX:Float = 0;
  var toolRightX:Float = 0;
  var statusText:FlxText;
  var statusMsg:String = '';
  var toasts:Toasts;
  var targetButton:EButton;

  var undoStack:Array<String> = [];
  var redoStack:Array<String> = [];
  var committed:String = '';
  var dirty:Bool = false;
  var panning:Bool = false;
  var panLast:FlxPoint = FlxPoint.get();
  var leaving:Bool = false;
  var leavePending:Bool = false;
  var armed:Bool = false;
  public var previewError:Null<String> = null;

  public function new(title:String)
  {
    super();
    editorTitle = title;
  }

  override function create():Void
  {
    super.create();
    camWorld = new FlxCamera();
    camWorld.bgColor = EditorUI.BG;
    FlxG.cameras.reset(camWorld);
    camUI = new FlxCamera();
    camUI.bgColor = FlxColor.TRANSPARENT;
    FlxG.cameras.add(camUI, false);
    FlxG.mouse.visible = true;

    ui(EditorUI.rect(0, 0, FlxG.width, TOP, EditorUI.HEADER));
    ui(EditorUI.rect(0, TOP - 2, FlxG.width, 2, EditorUI.ACCENT));
    var t = EditorUI.text(10, 11, 260, editorTitle, 16, EditorUI.ACCENT);
    ui(t);
    toolX = Math.max(200, t.textField.textWidth + 30);
    toolRightX = FlxG.width - 6;
    ui(EditorUI.rect(0, FlxG.height - BOTTOM, FlxG.width, BOTTOM, 0xFF0E0C12));
    statusText = EditorUI.text(8, FlxG.height - BOTTOM + 4, FlxG.width - 16, '', 12, EditorUI.MUTED);
    ui(statusText);

    addToolRight('Back (Esc)', leave, 'Leave the editor');
    addToolRight('Save (Ctrl+S)', doSave, 'Save into the target mod');
    targetButton = addToolRight('Mod: ' + (EditorFiles.target() ?? '(none)'), cycleTarget, 'Mod the editor saves into (click to change)', 210);

    buildEditor();
    toasts = new Toasts();
    ui(toasts);
    committed = serialize();
    refreshPreview();
    trace('[GOLDEN EDITOR] $editorTitle opened (target mod: ${EditorFiles.target() ?? "none"})');
    if (EditorFiles.target() == null) notify('No mod to save into yet: create one in Mods > New first.', EditorUI.ACCENT);
    else if (!EditorFiles.targetEnabled()) notify('Target mod "${EditorFiles.target()}" is disabled; enable it to see saved content in-game.', 0xFFFFB347);
  }

  /** Add something to the UI camera. */
  public function ui<T:FlxBasic>(b:T):T
  {
    b.cameras = [camUI];
    add(b);
    return b;
  }

  public function addTool(caption:String, fn:Void->Void, ?tooltip:String, w:Int = 0):EButton
  {
    if (w == 0) w = Std.int(Math.max(60, caption.length * 8 + 18));
    var b = new EButton(toolX, 7, w, 26, caption, fn, tooltip);
    toolX += w + 4;
    return ui(b);
  }

  public function addToolRight(caption:String, fn:Void->Void, ?tooltip:String, w:Int = 0):EButton
  {
    if (w == 0) w = Std.int(Math.max(60, caption.length * 8 + 18));
    toolRightX -= w;
    var b = new EButton(toolRightX, 7, w, 26, caption, fn, tooltip);
    toolRightX -= 4;
    return ui(b);
  }

  // ---- for subclasses ----------------------------------------------------------------------------

  /** Create panels, tools and the workspace. */
  function buildEditor():Void {}

  /** The whole document as text (undo snapshots, dirty check). */
  function serialize():String
    return '';

  /** Restore a snapshot made by serialize(). */
  function deserialize(s:String):Void {}

  /** Write the document into the target mod. Return an error message or null. */
  function save():Null<String>
    return 'Nothing to save.';

  /** Rebuild the workspace preview from the in-memory document. */
  function rebuildPreview():Void {}

  /** Inspector/browser refresh after undo/redo/load. */
  function refreshPanels():Void {}

  /** Whether a plain left drag pans the workspace (e.g. a Pan tool is active). */
  function leftDragPans():Bool
    return false;

  /** Handle editor keys (not called while typing). */
  function editorKeys():Void {}

  // ---- document state ----------------------------------------------------------------------------

  /** Call after every modification: records undo, marks unsaved, refreshes the preview. */
  public function changed(?what:String):Void
  {
    var now = serialize();
    if (now == committed) return;
    undoStack.push(committed);
    if (undoStack.length > 200) undoStack.shift();
    redoStack = [];
    committed = now;
    dirty = true;
    refreshPreview();
  }

  public function refreshPreview():Void
  {
    try
    {
      rebuildPreview();
      previewError = null;
    }
    catch (e:Dynamic)
    {
      previewError = 'Preview error: $e';
      trace('[GOLDEN EDITOR] $previewError');
    }
  }

  public function undo():Void
  {
    if (undoStack.length == 0)
    {
      notify('Nothing to undo.');
      return;
    }
    redoStack.push(committed);
    committed = undoStack.pop();
    deserialize(committed);
    dirty = true;
    refreshPreview();
    refreshPanels();
    notify('Undo');
  }

  public function redo():Void
  {
    if (redoStack.length == 0)
    {
      notify('Nothing to redo.');
      return;
    }
    undoStack.push(committed);
    committed = redoStack.pop();
    deserialize(committed);
    dirty = true;
    refreshPreview();
    refreshPanels();
    notify('Redo');
  }

  /** Replace the document without an undo entry (e.g. after loading a file). */
  public function resetHistory():Void
  {
    committed = serialize();
    undoStack = [];
    redoStack = [];
    dirty = false;
  }

  public function doSave():Void
  {
    if (EditorFiles.target() == null)
    {
      UISound.play(Error);
      notify('No mod to save into. Create a mod first (Main menu > Mods > N).', 0xFFFF5C5C);
      return;
    }
    var err = save();
    if (err != null)
    {
      UISound.play(Error);
      notify(err, 0xFFFF5C5C);
      return;
    }
    dirty = false;
    UISound.play(Confirm);
    notify('Saved to mod "${EditorFiles.target()}".', 0xFF6BE36B);
  }

  function cycleTarget():Void
  {
    var c = EditorFiles.modChoices();
    if (c.length == 0)
    {
      notify('No mods installed. Create one in Main menu > Mods.', 0xFFFFB347);
      return;
    }
    var i = c.indexOf(EditorFiles.target() ?? '');
    EditorFiles.setTarget(c[(i + 1) % c.length]);
    targetButton.setCaption('Mod: ' + EditorFiles.target());
    notify('Saving into "${EditorFiles.target()}"' + (EditorFiles.targetEnabled() ? '' : ' (disabled: enable it in the Mod Manager)'));
    onTargetChanged();
  }

  function onTargetChanged():Void {}

  public function notify(msg:String, color:FlxColor = EditorUI.TEXT):Void
  {
    if (toasts != null) toasts.push(msg, color);
    else trace('[GOLDEN EDITOR] $msg');
  }

  public function setStatus(s:String):Void
    statusMsg = s;

  public function leave():Void
  {
    if (dirty)
    {
      openSubState(new golden.ui.GoldenDialogs.GoldenConfirmSubState('You have unsaved changes in the $editorTitle.\n\nLeave without saving?', () -> leaveNow()));
      return;
    }
    leaveNow();
  }

  function leaveNow():Void
  {
    leavePending = true;
  }

  function exitTo():Void
    FlxG.switchState(() -> new EditorHubState());

  // ---- workspace ---------------------------------------------------------------------------------

  /** Is the mouse over the workspace (not over a panel)? */
  public function mouseInWorkspace():Bool
  {
    var p = FlxG.mouse.getViewPosition(camUI);
    var r = p.x > leftW && p.x < FlxG.width - rightW && p.y > TOP && p.y < FlxG.height - BOTTOM;
    p.put();
    return r;
  }

  /** Mouse position in world coordinates of the workspace camera. */
  public function worldMouse():FlxPoint
    return FlxG.mouse.getWorldPosition(camWorld);

  /** Window pixel of a workspace (world) point. */
  public function worldToScreen(wx:Float, wy:Float):{x:Float, y:Float}
    return {x: (wx - camWorld.scroll.x - camWorld.viewMarginLeft) * camWorld.zoom + camWorld.x, y: (wy - camWorld.scroll.y - camWorld.viewMarginTop) * camWorld.zoom + camWorld.y};

  /** Screen centre of the visible workspace (subclasses with extra panels override it). */
  public function workspaceCenter():{x:Float, y:Float}
    return {x: (leftW + (FlxG.width - rightW)) / 2, y: (TOP + (FlxG.height - BOTTOM)) / 2};

  public function centerWorkspaceOn(x:Float, y:Float):Void
  {
    // Centre of the visible workspace area, not of the whole window.
    var c = workspaceCenter();
    var cx = c.x, cy = c.y;
    camWorld.scroll.set(x - FlxG.width / 2 - (cx - FlxG.width / 2) / camWorld.zoom, y - FlxG.height / 2 - (cy - FlxG.height / 2) / camWorld.zoom);
  }

  function zoomAt(factor:Float):Void
  {
    var before = worldMouse();
    camWorld.zoom = Math.max(0.1, Math.min(8, camWorld.zoom * factor));
    var after = worldMouse();
    camWorld.scroll.x += before.x - after.x;
    camWorld.scroll.y += before.y - after.y;
    before.put();
    after.put();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (leavePending && !golden.ui.GoldenSubState.anyInputHeld() && !leaving)
    {
      leaving = true;
      trace('[GOLDEN EDITOR] $editorTitle closed');
      exitTo();
      return;
    }
    if (subState != null || leaving) return;
    if (!armed)
    {
      for (_ in [controls.ACCEPT_P, controls.BACK_P]) {}
      if (!golden.ui.GoldenSubState.anyInputHeld())
      {
        armed = true;
        trace('[GOLDEN EDITOR] $editorTitle ready for input');
      }
      return;
    }

    var typing = GoldenInput.isTyping();
    // Ctrl+S also works while typing: the focused field is committed first.
    if (typing && FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S)
    {
      var f = flixel.text.FlxInputText.globalManager?.focus;
      if (f != null) f.endFocus();
      doSave();
      return;
    }
    // Workspace pan & zoom.
    var panHeld = FlxG.mouse.pressedMiddle || FlxG.mouse.pressedRight || (FlxG.mouse.pressed && (leftDragPans() || FlxG.keys.pressed.SPACE) && !typing);
    if (panHeld && (panning || mouseInWorkspace()))
    {
      var p = FlxG.mouse.getViewPosition(camUI);
      if (panning)
      {
        camWorld.scroll.x -= (p.x - panLast.x) / camWorld.zoom;
        camWorld.scroll.y -= (p.y - panLast.y) / camWorld.zoom;
      }
      panLast.set(p.x, p.y);
      p.put();
      panning = true;
    }
    else
      panning = false;
    if (FlxG.mouse.wheel != 0 && mouseInWorkspace()) zoomAt(FlxG.mouse.wheel > 0 ? 1.1 : 1 / 1.1);

    if (!typing)
    {
      var ctrl = FlxG.keys.pressed.CONTROL;
      if (ctrl && FlxG.keys.justPressed.S) doSave();
      else if (ctrl && FlxG.keys.justPressed.Z) undo();
      else if (ctrl && FlxG.keys.justPressed.Y) redo();
      else if (ctrl && (FlxG.keys.justPressed.MINUS || FlxG.keys.justPressed.NUMPADMINUS)) camWorld.zoom = Math.max(0.1, camWorld.zoom / 1.25);
      else if (ctrl && (FlxG.keys.justPressed.PLUS || FlxG.keys.justPressed.NUMPADPLUS)) camWorld.zoom = Math.min(8, camWorld.zoom * 1.25);
      else if (FlxG.keys.justPressed.ESCAPE) leave();
      else
        editorKeys();
    }

    var tip = EditorTooltip.current;
    var z = Math.round(camWorld.zoom * 100);
    statusText.text = (previewError != null ? previewError : (tip != '' ? tip : statusMsg)) + (dirty ? '   [unsaved]' : '') + '   zoom $z%';
    statusText.color = previewError != null ? 0xFFFF5C5C : EditorUI.MUTED;
  }

  override function destroy():Void
  {
    panLast.put();
    super.destroy();
  }
}
