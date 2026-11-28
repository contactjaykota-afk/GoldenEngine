package golden.editor.anim;

import flixel.FlxSprite;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.DynamicAccess;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import funkin.util.FileUtil;
import golden.audio.UISound;
import golden.editor.EditorUI;
import golden.editor.GoldenEditorState;
import golden.editor.anim.RigData;

/**
 * Golden Engine — Character Animation Studio.
 *
 * Left: browser (character setup, body parts, poses with thumbnails, animations, presets, projects,
 * import). Centre: full-body workspace (zoom/pan, click a part to select it, transform handles) with
 * the tool strip; bottom: the frame timeline (one row per part, keyframes, playhead, onion skin).
 * Right: properties of the project, the open pose/animation and the selected part.
 *
 * Everything is edited in memory (live preview) and written by Save (project) / Export (FNF character).
 */
class AnimationStudioState extends GoldenEditorState
{
  static inline var CW:Int = 1600;
  static inline var CH:Int = 1500;
  static inline var OX:Int = 800;
  static inline var OY:Int = 1300;
  static inline var TL_H:Int = 176;

  /** Kept while testing in gameplay, so the studio comes back exactly as it was. */
  static var keep:Null<{json:String, images:Map<String, BitmapData>, mode:String, pose:Int, anim:Int, frame:Int, part:Null<String>}> = null;

  public var renderer:RigRenderer;
  public var project:RigProject;

  public var mode:String = 'rest'; // rest | pose | anim
  public var poseIndex:Int = -1;
  public var animIndex:Int = -1;
  public var frame:Int = 0;
  public var selectedPart:Null<String> = null;
  public var hidden:Map<String, Bool> = [];

  var tool:String = 'move';
  var canvas:FlxSprite;
  var canvasBmp:BitmapData;
  var overlay:FlxSprite;
  var overlayBmp:BitmapData;
  var browser:Browser;
  var inspector:Inspector;
  public var timeline:Timeline;
  var toolButtons:Map<String, EButton> = [];

  public var onion:Bool = false;
  public var onionPrev:Int = 2;
  public var onionNext:Int = 1;
  public var onionAlpha:Float = 0.3;
  public var playing:Bool = false;
  var playTime:Float = 0;

  var drag:Null<{kind:String, part:String, mx:Float, my:Float, start:PartT, pivot:{x:Float, y:Float}}> = null;
  var clipboard:Null<PartT> = null;
  var needsRender:Bool = true;
  var browserDirty:Bool = true;
  var inspectorDirty:Bool = true;
  var lastZoom:Float = -1;
  var testSong:String = 'bopeebo';
  var thumbs:Array<BitmapData> = [];
  var keys:Map<String, FlxKey> = [];

  public function new()
  {
    super('Animation Studio');
    leftW = 270;
    rightW = 330;
  }

  // ---- setup -------------------------------------------------------------------------------------

  override function buildEditor():Void
  {
    loadKeymap();
    renderer = new RigRenderer();
    if (keep != null)
    {
      renderer.images = keep.images;
      project = RigData.fromJson(keep.json);
      mode = keep.mode;
      poseIndex = keep.pose;
      animIndex = keep.anim;
      frame = keep.frame;
      selectedPart = keep.part;
      keep = null;
      trace('[GOLDEN EDITOR] Animation Studio restored after the gameplay test');
    }
    else
    {
      loadDefaultCharacter();
    }
    golden.GoldenPlayOverrides.clear();

    canvasBmp = new BitmapData(CW, CH, true, 0);
    canvas = new FlxSprite(-OX, -OY).loadGraphic(canvasBmp);
    canvas.antialiasing = true;
    add(canvas);
    overlayBmp = new BitmapData(CW, CH, true, 0);
    overlay = new FlxSprite(-OX, -OY).loadGraphic(overlayBmp);
    add(overlay);
    camWorld.zoom = 0.95;
    centerWorkspaceOn(0, -212);

    addTool('New', () -> confirmDiscard(newEmpty), 'Start an empty character (no parts)');
    addTool('Import PNGs', importFiles, 'Import body-part PNG files');
    addTool('Import Folder', importFolder, 'Import every PNG in a folder (optional positions.json)');
    addTool('Generate', () -> generate(false), 'Generate the missing standard poses + FNF animations from the parts (existing ones are kept)');
    addTool('Export', () -> export(false), 'Export as an FNF character into the target mod');
    addTool('Test Play', () -> export(true), 'Export, then play a song with this character (F9 returns)');

    var tools = [
      ['move', 'V', 'Select / move tool (V)'], ['rotate', 'R', 'Rotate tool (R)'], ['scale', 'S', 'Scale tool (S)'],
      ['pivot', 'P', 'Pivot tool (P): drag the pivot point'], ['pan', 'H', 'Pan tool (H) - or middle/right drag, Space+drag'],
      ['zoom', 'Z', 'Zoom tool (Z): click = in, Alt+click = out']
    ];
    for (i in 0...tools.length)
    {
      var t = tools[i];
      var b = new EButton(leftW + 6, GoldenEditorState.TOP + 8 + i * 34, 34, 30, t[1], () -> setTool(t[0]), t[2]);
      toolButtons.set(t[0], ui(b));
    }
    setTool('move');

    browser = ui(new Browser(0, GoldenEditorState.TOP, leftW, FlxG.height - GoldenEditorState.TOP - GoldenEditorState.BOTTOM, 52));
    browser.onSelect = onBrowserSelect;
    browser.collapse('Character/Body Parts');
    browser.collapse('Import');
    browser.collapse('Projects');
    inspector = ui(new Inspector(FlxG.width - rightW, GoldenEditorState.TOP, rightW, FlxG.height - GoldenEditorState.TOP - GoldenEditorState.BOTTOM));
    timeline = ui(new Timeline(this, leftW, FlxG.height - GoldenEditorState.BOTTOM - TL_H, FlxG.width - leftW - rightW, TL_H));
    resetHistory();
  }

  /** Boyfriend from the game's own atlas (the example character); the drawn example if that fails. */
  function loadDefaultCharacter():Void
  {
    renderer = new RigRenderer();
    try
    {
      project = AnimateAtlasImport.loadBoyfriend(renderer);
    }
    catch (e:Dynamic)
    {
      trace('[GOLDEN EDITOR] Could not import Boyfriend: $e');
      renderer = new RigRenderer();
      project = DefaultCharacter.build(renderer);
      notify('Boyfriend could not be loaded ($e); using the drawn example.', 0xFFFFB347);
    }
    selectedPart = null;
    hidden = [];
    var idle = animByName('idle');
    var pose = project.poses.findIndex(x -> x.name == 'Idle');
    if (pose >= 0) openPose(pose) else if (idle >= 0) openAnim(idle, false) else openRest();
  }

  function loadKeymap():Void
  {
    var defaults:Map<String, String> = [
      'move' => 'V', 'rotate' => 'R', 'scale' => 'S', 'pivot' => 'P', 'pan' => 'H', 'zoom' => 'Z', 'play' => 'ENTER',
      'prevFrame' => 'COMMA', 'nextFrame' => 'PERIOD', 'firstFrame' => 'HOME', 'lastFrame' => 'END', 'key' => 'K',
      'deleteKey' => 'DELETE', 'onion' => 'O', 'layerUp' => 'PAGEUP', 'layerDown' => 'PAGEDOWN', 'rotLeft' => 'LBRACKET',
      'rotRight' => 'RBRACKET', 'focus' => 'F'
    ];
    var path = Path.normalize(Path.join([golden.modding.GoldenMods.modRoot(), '..', 'golden-animstudio-keys.json']));
    var custom:Dynamic = EditorFiles.exists(path) ? EditorFiles.loadJson(path) : null;
    if (EditorFiles.exists(path) && custom == null) notify('Key map file is invalid: ${EditorFiles.lastError}', 0xFFFFB347);
    for (action in defaults.keys())
    {
      var name = defaults.get(action);
      if (custom != null && Reflect.hasField(custom, action)) name = Std.string(Reflect.field(custom, action)).toUpperCase();
      var k:FlxKey = FlxKey.fromString(name);
      if (k == FlxKey.NONE) k = FlxKey.fromString(defaults.get(action));
      keys.set(action, k);
    }
  }

  inline function pressed(action:String):Bool
    return FlxG.keys.anyJustPressed([keys.get(action)]);

  function setTool(t:String):Void
  {
    tool = t;
    for (k in toolButtons.keys())
      toolButtons.get(k).toggled = k == t;
    setStatus('Tool: $t');
  }

  // ---- document ----------------------------------------------------------------------------------

  override function serialize():String
    return RigData.toJson(project) + '\n#' + mode + ':' + poseIndex + ':' + animIndex;

  override function deserialize(s:String):Void
  {
    var i = s.lastIndexOf('\n#');
    project = RigData.fromJson(s.substr(0, i));
    var m = s.substr(i + 2).split(':');
    mode = m[0];
    poseIndex = Std.parseInt(m[1]);
    animIndex = Std.parseInt(m[2]);
    if (selectedPart != null && RigData.part(project, selectedPart) == null) selectedPart = null;
    browserDirty = inspectorDirty = needsRender = true;
  }

  override function save():Null<String>
  {
    var err = RigExport.saveProject(project, renderer, EditorFiles.target());
    if (err == null) browserDirty = true;
    return err;
  }

  override function rebuildPreview():Void
    needsRender = true;

  override function refreshPanels():Void
  {
    browserDirty = true;
    inspectorDirty = true;
  }

  override public function changed(?what:String):Void
  {
    super.changed(what);
    browserDirty = true;
    inspector.refresh();
  }

  function confirmDiscard(then:Void->Void):Void
  {
    if (!dirty)
    {
      then();
      return;
    }
    openSubState(new golden.ui.GoldenDialogs.GoldenConfirmSubState('Discard unsaved changes to "${project.name}"?', then));
  }

  function newEmpty():Void
  {
    project = RigData.emptyProject('new-character', 'New Character');
    mode = 'rest';
    poseIndex = animIndex = -1;
    frame = 0;
    selectedPart = null;
    hidden = [];
    resetHistory();
    refreshPanels();
    needsRender = true;
    notify('Empty character. Import body-part PNGs to start.');
  }

  public function currentAnim():Null<RigAnim>
    return mode == 'anim' && animIndex >= 0 && animIndex < project.anims.length ? project.anims[animIndex] : null;

  function currentPose():Null<RigPose>
    return mode == 'pose' && poseIndex >= 0 && poseIndex < project.poses.length ? project.poses[poseIndex] : null;

  function animByName(n:String):Int
  {
    for (i in 0...project.anims.length)
      if (project.anims[i].fnfName == n || project.anims[i].name == n) return i;
    return -1;
  }

  /** Transforms shown in the workspace. */
  public function currentTM():DynamicAccess<PartT>
  {
    var an = currentAnim();
    if (an != null) return RigData.sample(project, an, frame);
    var pose = currentPose();
    if (pose != null) return RigData.fill(project, pose.t);
    return RigData.fill(project, project.rest);
  }

  /** Change a part's transform in the open pose / animation frame (auto-key) / setup pose. */
  public function editPart(id:String, fn:PartT->Void):Void
  {
    var an = currentAnim();
    if (an != null)
    {
      var tt = currentTM().get(id);
      fn(tt);
      RigData.setKey(an, id, frame, tt);
    }
    else if (currentPose() != null)
    {
      var pose = currentPose();
      if (!pose.t.exists(id)) pose.t.set(id, RigData.copyT(project.rest.get(id) ?? RigData.t()));
      fn(pose.t.get(id));
    }
    else
    {
      if (!project.rest.exists(id)) project.rest.set(id, RigData.t());
      fn(project.rest.get(id));
    }
    needsRender = true;
  }

  function partT(id:String):PartT
    return currentTM().get(id) ?? RigData.t();

  function openAnim(i:Int, notifyIt:Bool = true):Void
  {
    if (i < 0) return;
    mode = 'anim';
    animIndex = i;
    poseIndex = -1;
    frame = 0;
    playing = false;
    inspectorDirty = needsRender = browserDirty = true;
    if (notifyIt) setStatus('Animation "${project.anims[i].name}" (${project.anims[i].length} frames)');
    trace('[GOLDEN EDITOR] Animation Studio: animation "${project.anims[i].name}" opened');
  }

  /** The pose as it was when opened (for "Save as new pose" / "Revert"). */
  var poseOriginal:Null<String> = null;

  function openPose(i:Int):Void
  {
    poseOriginal = haxe.Json.stringify(project.poses[i].t);
    mode = 'pose';
    poseIndex = i;
    animIndex = -1;
    playing = false;
    inspectorDirty = needsRender = browserDirty = true;
    setStatus('Pose "${project.poses[i].name}": edit parts, the pose updates (Save writes it)');
    trace('[GOLDEN EDITOR] Animation Studio: pose "${project.poses[i].name}" opened');
  }

  function openRest():Void
  {
    mode = 'rest';
    poseIndex = animIndex = -1;
    playing = false;
    inspectorDirty = needsRender = browserDirty = true;
    setStatus('Setup pose: align the parts here (other poses start from it)');
  }

  // ---- browser -----------------------------------------------------------------------------------

  function rebuildBrowser():Void
  {
    browserDirty = false;
    for (t in thumbs)
      t.dispose();
    thumbs = [];
    var items:Array<BrowserItem> = [];
    function thumb(tm:DynamicAccess<PartT>):BitmapData
    {
      var b = renderer.thumbnail(project, tm, 52);
      thumbs.push(b);
      return b;
    }
    items.push({folder: 'Character', label: 'Setup pose (${project.parts.length} parts)', thumb: thumb(project.rest), data: {kind: 'rest'}});
    for (x in project.parts)
      items.push({folder: 'Character/Body Parts', label: x.name + (x.variants.length > 0 ? ' (+${x.variants.length})' : ''), thumb: renderer.images.get(x.image), data: {kind: 'part', id: x.id}});
    for (i in 0...project.poses.length)
    {
      var p = project.poses[i];
      items.push({folder: 'Character/' + p.folder, label: p.name, thumb: thumb(RigData.fill(project, p.t)), data: {kind: 'pose', index: i}});
    }
    for (i in 0...project.anims.length)
    {
      var a = project.anims[i];
      items.push({folder: 'Character/' + a.folder, label: a.name + ' (${a.length}f)', thumb: thumb(RigData.sample(project, a, 0)), data: {kind: 'anim', index: i}});
    }
    for (pr in [
      ['Generate missing poses + anims', 'generate'], ['Regenerate all (replace)', 'regenerate'], ['New pose from view', 'newpose'], ['New empty animation', 'newanim'],
      ['Blink animation', 'blink'], ['Talk animation', 'talk']
    ])
      items.push({folder: 'Presets', label: pr[0], data: {kind: 'preset', id: pr[1]}});
    items.push({folder: 'Import', label: 'Import PNG files...', data: {kind: 'action', id: 'importFiles'}});
    items.push({folder: 'Import', label: 'Import PNG folder...', data: {kind: 'action', id: 'importFolder'}});
    var mod = EditorFiles.target();
    items.push({folder: 'Projects', label: 'Restore default Boyfriend', data: {kind: 'action', id: 'bf'}});
    items.push({folder: 'Projects', label: 'Goldie (drawn example)', data: {kind: 'action', id: 'example'}});
    items.push({folder: 'Projects', label: 'New empty character', data: {kind: 'action', id: 'new'}});
    if (mod != null) for (id in RigExport.listProjects(mod))
      items.push({folder: 'Projects', label: 'Open: $id', data: {kind: 'project', id: id}});
    browser.setItems(items);
    // keep the open item highlighted
    var sel = items.find(it -> switch (it.data.kind)
    {
      case 'rest': mode == 'rest' && selectedPart == null;
      case 'pose': mode == 'pose' && it.data.index == poseIndex;
      case 'anim': mode == 'anim' && it.data.index == animIndex;
      default: false;
    });
    browser.select(sel, false);
  }

  function onBrowserSelect(it:BrowserItem):Void
  {
    var d:Dynamic = it.data;
    switch (d.kind)
    {
      case 'rest':
        openRest();
      case 'part':
        selectedPart = d.id;
        inspectorDirty = needsRender = true;
      case 'pose':
        openPose(d.index);
      case 'anim':
        openAnim(d.index);
      case 'preset':
        preset(d.id);
      case 'action':
        switch (d.id)
        {
          case 'importFiles': importFiles();
          case 'importFolder': importFolder();
          case 'new': confirmDiscard(newEmpty);
          case 'bf': confirmDiscard(() ->
            {
              loadDefaultCharacter();
              resetHistory();
              refreshPanels();
              notify('Boyfriend restored with his original poses and animations.');
            });
          case 'example': confirmDiscard(() ->
            {
              renderer = new RigRenderer();
              project = DefaultCharacter.build(renderer);
              openAnim(animByName('idle'), false);
              resetHistory();
              refreshPanels();
              notify('Example character loaded.');
            });
        }
      case 'project':
        var id:String = d.id;
        confirmDiscard(() -> loadProjectById(id));
    }
  }

  function loadProjectById(id:String):Void
  {
    var r = new RigRenderer();
    var res = RigExport.loadProject(id, r, EditorFiles.target());
    if (res.project == null)
    {
      UISound.play(Error);
      notify(res.error, 0xFFFF5C5C);
      return;
    }
    renderer = r;
    project = res.project;
    selectedPart = null;
    hidden = [];
    var idle = animByName('idle');
    if (idle >= 0) openAnim(idle, false) else openRest();
    resetHistory();
    refreshPanels();
    notify('Opened "$id"' + (res.error != null ? ' - ${res.error}' : ''), res.error != null ? 0xFFFFB347 : EditorUI.TEXT);
  }

  // ---- presets / generation ----------------------------------------------------------------------

  function generate(replace:Bool = false):Void
  {
    if (project.parts.length == 0)
    {
      notify('Import body parts first.', 0xFFFFB347);
      return;
    }
    var linked = RigData.autoRig(project);
    var made = RigData.generate(project, replace);
    if (made.length == 0)
    {
      notify('Nothing missing: all standard poses and animations exist (use "Regenerate all" to replace them).');
      return;
    }
    changed('generate');
    var idle = animByName('idle');
    if (idle >= 0) openAnim(idle, false);
    notify('Generated ${made.length} poses/animations' + (linked > 0 ? ' (auto-rigged $linked parts)' : '') + '. They are starting points: adjust them.');
  }

  function preset(id:String):Void
  {
    switch (id)
    {
      case 'generate':
        generate(false);
      case 'regenerate':
        openSubState(new golden.ui.GoldenDialogs.GoldenConfirmSubState('Replace all standard poses and animations with freshly generated ones?\n(Custom ones are kept.)', () -> generate(true)));
      case 'newpose':
        var tm = currentTM();
        project.poses.push({name: 'Pose ${project.poses.length + 1}', folder: 'Poses/Custom', t: tm});
        changed();
        openPose(project.poses.length - 1);
        notify('New pose created from the current view.');
      case 'newanim':
        var an = RigData.newAnim('anim${project.anims.length + 1}', 'Animations/Custom', 'anim${project.anims.length + 1}', 12);
        RigData.poseToKeys(project, an, {name: '', folder: '', t: currentTM()}, 0);
        project.anims.push(an);
        changed();
        openAnim(project.anims.length - 1);
        notify('New animation: set its FNF name in the properties.');
      case 'blink', 'talk':
        var role = id == 'blink' ? 'eyes' : 'mouth';
        var part = project.parts.find(x -> x.role == role);
        if (part == null)
        {
          notify('No part with role "$role" (set a part\'s role in its properties).', 0xFFFFB347);
          return;
        }
        var an = RigData.newAnim(id, 'Animations/Face', id, 12);
        var rest = RigData.fill(project, project.rest);
        for (x in project.parts)
          RigData.setKey(an, x.id, 0, rest.get(x.id));
        var shut = RigData.copyT(rest.get(part.id));
        if (part.variants.length > 0) shut.v = 1 else shut.sy *= (id == 'blink' ? 0.2 : 1.6);
        if (id == 'blink')
        {
          RigData.setKey(an, part.id, 5, shut);
          RigData.setKey(an, part.id, 7, rest.get(part.id));
        }
        else
        {
          RigData.setKey(an, part.id, 2, shut);
          RigData.setKey(an, part.id, 5, rest.get(part.id));
          RigData.setKey(an, part.id, 8, shut);
        }
        RigData.setKey(an, part.id, 11, rest.get(part.id));
        project.anims.push(an);
        changed();
        openAnim(project.anims.length - 1);
        notify('"$id" animation created (face part swap).');
    }
  }

  // ---- import ------------------------------------------------------------------------------------

  function importFiles():Void
  {
    #if sys
    UISound.play(Open);
    FileUtil.browseForMultipleFiles('Import body-part PNGs', [FileUtil.FILE_FILTER_PNG], paths -> importPaths(paths, null), () -> notify('Import cancelled.'));
    #end
  }

  function importFolder():Void
  {
    #if sys
    UISound.play(Open);
    FileUtil.browseForDirectory('Folder with body-part PNGs', dir ->
    {
      var files = [for (f in sys.FileSystem.readDirectory(dir)) if (Path.extension(f).toLowerCase() == 'png') Path.join([dir, f])];
      files.sort((a, b) -> a < b ? -1 : 1);
      var pos:Dynamic = EditorFiles.exists(Path.join([dir, 'positions.json'])) ? EditorFiles.loadJson(Path.join([dir, 'positions.json'])) : null;
      importPaths(files, pos);
    }, () -> notify('Import cancelled.'));
    #end
  }

  /** Name used as image key, unique within the project. */
  function uniqueImageName(base:String):String
  {
    var b = EditorFiles.safeId(base);
    var n = b + '.png', i = 2;
    while (renderer.images.exists(n))
      n = b + '_' + (i++) + '.png';
    return n;
  }

  /**
   * Add parts from PNG files. Alignment: (1) positions.json {"File.png": [x, y]} (top-left in a shared
   * canvas) when present; (2) when all images have the same size they are treated as layers of one
   * canvas and keep their drawn positions; (3) otherwise parts are placed by their role (head above
   * body, arms at the sides...) and should be dragged into place in the Setup pose.
   */
  public function importPaths(paths:Array<String>, positions:Dynamic):Void
  {
    var loaded:Array<{name:String, file:String, bmp:BitmapData}> = [];
    var failed = [];
    for (f in paths)
    {
      var b = RigExport.loadImage(f);
      if (b == null) failed.push(Path.withoutDirectory(f));
      else loaded.push({name: Path.withoutExtension(Path.withoutDirectory(f)), file: Path.withoutDirectory(f), bmp: b});
    }
    if (loaded.length == 0)
    {
      UISound.play(Error);
      notify('No PNG could be loaded' + (failed.length > 0 ? ' (${failed.join(', ')})' : '') + '.', 0xFFFF5C5C);
      return;
    }
    var sameSize = loaded.length > 1 && loaded.foreach(l -> l.bmp.width == loaded[0].bmp.width && l.bmp.height == loaded[0].bmp.height);
    // canvas origin for aligned layers: bottom of all opaque pixels, horizontal centre
    var unionBottom = 0.0, unionMinX = 1e9, unionMaxX = -1e9;
    for (l in loaded)
    {
      var ob = RigRenderer.opaqueBounds(l.bmp);
      var p = positions != null ? Reflect.field(positions, l.file) : null;
      var ox = p != null ? p[0] : 0.0, oy = p != null ? p[1] : 0.0;
      unionBottom = Math.max(unionBottom, oy + ob.bottom);
      unionMinX = Math.min(unionMinX, ox + ob.x);
      unionMaxX = Math.max(unionMaxX, ox + ob.right);
    }
    var cx = (unionMinX + unionMaxX) / 2;
    var mode = positions != null ? 'positions.json' : (sameSize ? 'layer positions' : 'by name');
    var stackY = -20.0;
    var added = [];
    for (l in loaded)
    {
      var key = uniqueImageName(l.name);
      renderer.images.set(key, l.bmp);
      var role = RigData.guessRole(l.name);
      var ob = RigRenderer.opaqueBounds(l.bmp);
      // pivot by role: limbs at their top, head at its bottom (neck), others at the centre
      var px = ob.x + ob.width / 2, py = ob.y + ob.height / 2;
      if (role.startsWith('arm') || role.startsWith('leg')) py = ob.y + Math.min(12, ob.height * 0.1);
      else if (role == 'head' || role == 'body') py = ob.bottom - Math.min(10, ob.height * 0.08);
      var id = RigData.uniqueId(project, l.name);
      var x = 0.0, y = 0.0;
      var pos = positions != null ? Reflect.field(positions, l.file) : null;
      if (pos != null || sameSize)
      {
        var ox = pos != null ? pos[0] : 0.0, oy = pos != null ? pos[1] : 0.0;
        x = ox + px - cx;
        y = oy + py - unionBottom;
      }
      else
      {
        var pl = placeByRole(role, l.bmp, px, py);
        if (pl == null)
        {
          x = 260;
          y = stackY - (l.bmp.height - py);
          stackY -= l.bmp.height + 10;
        }
        else
        {
          x = pl.x;
          y = pl.y;
        }
      }
      project.parts.push({id: id, name: l.name, image: key, variants: [], pivotX: px, pivotY: py, parent: null, role: role});
      project.rest.set(id, RigData.t(x, y));
      added.push(id);
    }
    var linked = RigData.autoRig(project);
    selectedPart = added[0];
    openRest();
    changed('import');
    notify('Imported ${added.length} parts (aligned ${mode}' + (linked > 0 ? ', auto-rigged $linked' : '') + ')' + (failed.length > 0 ? '; failed: ${failed.join(', ')}' : '')
      + (mode == 'by name' ? '. Drag parts into place in the Setup pose.' : '.'));
    trace('[GOLDEN EDITOR] Animation Studio import: ${added.join(", ")} (alignment: $mode)');
  }

  /** Rough placement for unaligned parts (character about 420 px tall, feet at 0). */
  function placeByRole(role:String, b:BitmapData, px:Float, py:Float):Null<{x:Float, y:Float}>
  {
    return switch (role)
    {
      case 'legL': {x: -25, y: -150};
      case 'legR': {x: 25, y: -150};
      case 'shoeL': {x: -30, y: -(b.height - py)};
      case 'shoeR': {x: 30, y: -(b.height - py)};
      case 'body': {x: 0, y: -140};
      case 'armL': {x: -55, y: -260};
      case 'armR': {x: 55, y: -260};
      case 'handL': {x: -55, y: -160};
      case 'handR': {x: 55, y: -160};
      case 'head': {x: 0, y: -262};
      case 'hair': {x: 0, y: -360};
      case 'face': {x: 0, y: -320};
      case 'eyes': {x: 0, y: -330};
      case 'mouth': {x: 0, y: -290};
      default: null;
    }
  }

  function importVariant():Void
  {
    #if sys
    if (selectedPart == null) return;
    var id = selectedPart;
    FileUtil.browseForFile('Variant image for ${RigData.part(project, id).name}', [FileUtil.FILE_FILTER_PNG], file ->
    {
      var b = RigExport.loadImage(file.fullPath);
      if (b == null)
      {
        notify('Could not load ${file.fullPath}', 0xFFFF5C5C);
        return;
      }
      var key = uniqueImageName(Path.withoutExtension(Path.withoutDirectory(file.fullPath)));
      renderer.images.set(key, b);
      RigData.part(project, id).variants.push(key);
      changed();
      inspectorDirty = true;
      notify('Variant added (${RigData.part(project, id).variants.length} variants). Pick it with "Variant".');
    }, () -> {});
    #end
  }

  function replaceImage():Void
  {
    #if sys
    if (selectedPart == null) return;
    var id = selectedPart;
    FileUtil.browseForFile('Replace image', [FileUtil.FILE_FILTER_PNG], file ->
    {
      var b = RigExport.loadImage(file.fullPath);
      if (b == null) return;
      var key = uniqueImageName(Path.withoutExtension(Path.withoutDirectory(file.fullPath)));
      renderer.images.set(key, b);
      RigData.part(project, id).image = key;
      changed();
      notify('Image replaced (pivot kept).');
    }, () -> {});
    #end
  }

  // ---- export ------------------------------------------------------------------------------------

  function export(thenPlay:Bool):Void
  {
    var mod = EditorFiles.target();
    if (mod == null)
    {
      UISound.play(Error);
      notify('No mod to export into: create a mod first (Main menu > Mods > N).', 0xFFFF5C5C);
      return;
    }
    var saveErr = RigExport.saveProject(project, renderer, mod);
    if (saveErr != null)
    {
      notify(saveErr, 0xFFFF5C5C);
      return;
    }
    dirty = false;
    if (!project.anims.exists(a -> a.fnfName == 'firstDeath')) notify('Note: no Game Over animations (firstDeath/deathLoop/deathConfirm). "Generate missing" adds simple ones.', 0xFFFFB347);
    var r = RigExport.export(project, renderer, mod);
    if (r.error != null)
    {
      UISound.play(Error);
      notify('Export failed: ${r.error}', 0xFFFF5C5C);
      return;
    }
    UISound.play(Confirm);
    var id = EditorFiles.safeId(project.id);
    notify('Exported character "$id" (${r.frames} frames, sheet ${r.sheet}) into "$mod".', 0xFF6BE36B);
    if (!EditorFiles.targetEnabled())
    {
      notify('Mod "$mod" is disabled: enable it to use the character in-game.', 0xFFFFB347);
      if (thenPlay) return;
    }
    if (!thenPlay) return;
    EditorFiles.reloadGameContent();
    keep = {
      json: RigData.toJson(project),
      images: renderer.images,
      mode: mode,
      pose: poseIndex,
      anim: animIndex,
      frame: frame,
      part: selectedPart
    };
    golden.GoldenPlayOverrides.player = id;
    golden.studio.GoldenStudio.editorReturn = () -> FlxG.switchState(() -> new AnimationStudioState());
    trace('[GOLDEN EDITOR] Test in gameplay: "$id" as the player in $testSong');
    var err = golden.studio.GoldenStudio.playSong(testSong, 'normal');
    if (err != null)
    {
      keep = null;
      golden.GoldenPlayOverrides.clear();
      golden.studio.GoldenStudio.editorReturn = null;
      notify(err, 0xFFFF5C5C);
    }
    else
      leaving = true;
  }

  // ---- inspector ---------------------------------------------------------------------------------

  function rebuildInspector():Void
  {
    inspectorDirty = false;
    inspector.clearRows();
    inspector.addHeader('Character');
    inspector.addText('Name', () -> project.name, v ->
    {
      project.name = v;
      changed();
    });
    inspector.addText('Character ID', () -> project.id, v ->
    {
      project.id = EditorFiles.safeId(v);
      changed();
    });
    inspector.addToggle('Flip X', () -> project.flipX, v ->
    {
      project.flipX = v;
      changed();
    });
    inspector.addNumber('Game scale', () -> project.scale, v ->
    {
      project.scale = v;
      changed();
    }, 0.05, 0.05, 10);

    var an = currentAnim();
    var pose = currentPose();
    if (an != null)
    {
      inspector.addHeader('Animation');
      inspector.addText('Name', () -> an.name, v ->
      {
        an.name = v;
        changed();
      });
      inspector.addText('Folder', () -> an.folder, v ->
      {
        an.folder = v.trim() == '' ? 'Animations' : v.trim();
        changed();
      });
      inspector.addText('FNF name', () -> an.fnfName, v ->
      {
        an.fnfName = v.trim();
        changed();
      });
      inspector.addNote('FNF names: idle, singLEFT, singDOWN, singUP, singRIGHT, singLEFTmiss..., hey, firstDeath, deathLoop, deathConfirm');
      inspector.addNumber('FPS', () -> an.fps, v ->
      {
        an.fps = Std.int(v);
        changed();
      }, 1, 1, 120);
      inspector.addNumber('Length (frames)', () -> an.length, v ->
      {
        an.length = Std.int(Math.max(1, v));
        if (frame >= an.length) frame = an.length - 1;
        changed();
      }, 1, 1, 600);
      inspector.addNote('Frame duration: ${Math.round(1000 / an.fps)} ms');
      inspector.addToggle('Loop', () -> an.loop, v ->
      {
        an.loop = v;
        changed();
      });
      var poseNames = () -> [for (p in project.poses) p.folder + '/' + p.name];
      var chosen = project.poses.length > 0 ? poseNames()[0] : '';
      inspector.addChoice('Pose', poseNames, () -> chosen, v -> chosen = v);
      inspector.addButtons([
        {caption: 'Pose -> frame', fn: () ->
          {
            var p = project.poses.find(x -> x.folder + '/' + x.name == chosen);
            if (p == null) return;
            RigData.poseToKeys(project, an, p, frame);
            changed();
            notify('Pose "${p.name}" keyed at frame $frame.');
          }, tooltip: 'Key the chosen pose (all parts) at the current frame'},
        {caption: 'Frame -> pose', fn: () -> preset('newpose'), tooltip: 'Save the current frame as a new pose'}
      ]);
      inspector.addButtons([
        {caption: 'Duplicate anim', fn: () ->
          {
            var c:RigAnim = haxe.Json.parse(haxe.Json.stringify(an));
            c.name += ' copy';
            project.anims.push(c);
            changed();
            openAnim(project.anims.length - 1);
          }},
        {caption: 'Delete anim', fn: () -> openSubState(new golden.ui.GoldenDialogs.GoldenConfirmSubState('Delete animation "${an.name}"?', () ->
          {
            project.anims.remove(an);
            changed();
            openRest();
          }))}
      ]);
    }
    else if (pose != null)
    {
      inspector.addHeader('Pose');
      inspector.addText('Name', () -> pose.name, v ->
      {
        pose.name = v;
        changed();
      });
      inspector.addText('Folder', () -> pose.folder, v ->
      {
        pose.folder = v.trim() == '' ? 'Poses' : v.trim();
        changed();
      });
      inspector.addButtons([
        {caption: 'Duplicate pose', fn: () ->
          {
            project.poses.push({name: pose.name + ' copy', folder: pose.folder, t: RigData.fill(project, pose.t)});
            changed();
            openPose(project.poses.length - 1);
          }},
        {caption: 'Delete pose', fn: () -> openSubState(new golden.ui.GoldenDialogs.GoldenConfirmSubState('Delete pose "${pose.name}"?', () ->
          {
            project.poses.remove(pose);
            changed();
            openRest();
          }))}
      ]);
      inspector.addButtons([
        {caption: 'Save as new pose', fn: () -> saveAsNewPose(pose), tooltip: 'Keep your edits as a new pose and restore this one'},
        {caption: 'Revert', fn: () -> revertPose(pose), tooltip: 'Undo all edits since the pose was opened'}
      ]);
      inspector.addButtons([
        {caption: 'New folder', fn: () ->
          {
            var n = 1;
            while (project.poses.exists(x -> x.folder == 'Poses/New Folder $n'))
              n++;
            pose.folder = 'Poses/New Folder $n';
            changed();
            inspectorDirty = true;
            notify('Moved "${pose.name}" to Poses/New Folder $n (rename it in "Folder").');
          }, tooltip: 'Move this pose into a new folder'},
        {caption: 'Export pose', fn: () -> exportPose(pose)},
        {caption: 'Import pose', fn: importPose}
      ]);
    }
    else
    {
      inspector.addHeader('Setup pose');
      inspector.addNote('Align imported parts here. Poses and generated animations start from this pose.');
      inspector.addButtons([
        {caption: 'Auto-rig', fn: () ->
          {
            var n = RigData.autoRig(project);
            changed();
            notify('Auto-rig linked $n parts (by role).');
          }, tooltip: 'Parent parts by role: head/arms to body, hands to arms...'}
      ]);
    }

    var part = selectedPart != null ? RigData.part(project, selectedPart) : null;
    if (part != null)
    {
      var id = part.id;
      inspector.addHeader('Part: ${part.name}');
      inspector.addText('Part name', () -> part.name, v ->
      {
        part.name = v;
        changed();
      });
      inspector.addChoice('Role', () -> ['body', 'head', 'hair', 'face', 'eyes', 'mouth', 'armL', 'armR', 'handL', 'handR', 'legL', 'legR', 'shoeL', 'shoeR', 'other'],
        () -> part.role, v ->
        {
          part.role = v;
          changed();
        });
      inspector.addChoice('Parent', () -> ['(none)'].concat([for (x in project.parts) if (x.id != id) x.id]), () -> part.parent ?? '(none)', v ->
      {
        RigData.setParent(project, id, v == '(none)' ? null : v);
        changed();
        inspector.refresh();
      });
      inspector.addNumber('X', () -> partT(id).x, v -> editT(id, t -> t.x = v), 1);
      inspector.addNumber('Y', () -> partT(id).y, v -> editT(id, t -> t.y = v), 1);
      inspector.addNumber('Rotation', () -> partT(id).r, v -> editT(id, t -> t.r = v), 1);
      inspector.addNumber('Scale X', () -> partT(id).sx, v -> editT(id, t -> t.sx = v), 0.05);
      inspector.addNumber('Scale Y', () -> partT(id).sy, v -> editT(id, t -> t.sy = v), 0.05);
      inspector.addNumber('Alpha', () -> partT(id).a, v -> editT(id, t -> t.a = v), 0.1, 0, 1);
      inspector.addChoice('Variant', () -> ['0 base'].concat([for (i in 0...part.variants.length) '${i + 1} ${part.variants[i]}']),
        () -> partT(id).v == 0 ? '0 base' : '${partT(id).v} ${part.variants[partT(id).v - 1] ?? ""}', v -> editT(id, t -> t.v = Std.parseInt(v.split(' ')[0])));
      inspector.addText('Tint (hex)', () -> StringTools.hex(partT(id).c, 6), v ->
      {
        var c = Std.parseInt('0x' + v.replace('#', ''));
        if (c != null) editT(id, t -> t.c = c & 0xFFFFFF);
      });
      inspector.addNumber('Pivot X', () -> part.pivotX, v -> movePivot(id, v - part.pivotX, 0), 1);
      inspector.addNumber('Pivot Y', () -> part.pivotY, v -> movePivot(id, 0, v - part.pivotY), 1);
      inspector.addNote('Layer ${project.parts.indexOf(part) + 1} of ${project.parts.length} (1 = back)');
      inspector.addButtons([
        {caption: 'Layer up', fn: () -> moveLayer(1), tooltip: 'Draw in front (PageUp)'},
        {caption: 'Layer down', fn: () -> moveLayer(-1), tooltip: 'Draw behind (PageDown)'}
      ]);
      inspector.addButtons([
        {caption: 'Add variant', fn: importVariant, tooltip: 'Extra image (open mouth, closed eyes...) swapped by keyframes'},
        {caption: 'Replace image', fn: replaceImage}
      ]);
      inspector.addButtons([
        {caption: hidden.exists(id) ? 'Show layer' : 'Hide layer', fn: () ->
          {
            if (hidden.exists(id)) hidden.remove(id) else hidden.set(id, true);
            inspectorDirty = needsRender = true;
          }},
        {caption: 'Duplicate part', fn: () -> duplicatePart(id)},
        {caption: 'Delete part', fn: () -> openSubState(new golden.ui.GoldenDialogs.GoldenConfirmSubState('Delete part "${part.name}"? (Children are kept and unparented.)', () -> deletePart(id)))}
      ]);
    }

    inspector.addHeader('Onion skin');
    inspector.addToggle('Onion skin', () -> onion, v ->
    {
      onion = v;
      needsRender = true;
    });
    inspector.addNumber('Frames before', () -> onionPrev, v ->
    {
      onionPrev = Std.int(v);
      needsRender = true;
    }, 1, 0, 8);
    inspector.addNumber('Frames after', () -> onionNext, v ->
    {
      onionNext = Std.int(v);
      needsRender = true;
    }, 1, 0, 8);
    inspector.addNumber('Onion opacity', () -> onionAlpha, v ->
    {
      onionAlpha = v;
      needsRender = true;
    }, 0.05, 0.05, 1);

    inspector.addHeader('Test in gameplay');
    var songs = () -> funkin.data.song.SongRegistry.instance.listEntryIds();
    inspector.addChoice('Song', songs, () -> testSong, v -> testSong = v);
    inspector.addNote('Test Play exports, reloads mods and plays the song with this character as the player. F9 returns here.');
  }

  function saveAsNewPose(pose:RigPose):Void
  {
    var copy:RigPose = {name: pose.name + ' (edited)', folder: pose.folder, t: RigData.fill(project, pose.t)};
    var n = 2;
    while (project.poses.exists(x -> x.name == copy.name))
      copy.name = pose.name + ' (edited $n)';
    if (poseOriginal != null) pose.t = haxe.Json.parse(poseOriginal);
    project.poses.push(copy);
    changed();
    openPose(project.poses.length - 1);
    notify('Saved as new pose "${copy.name}"; "${pose.name}" is unchanged.');
  }

  function revertPose(pose:RigPose):Void
  {
    if (poseOriginal == null) return;
    pose.t = haxe.Json.parse(poseOriginal);
    changed();
    notify('Pose "${pose.name}" reverted.');
  }

  /** Pose files: { "golden": "pose", "name", "folder", "parts": { "<part name>": transform } } (matched by part name). */
  function exportPose(pose:RigPose):Void
  {
    var mod = EditorFiles.target();
    if (mod == null) return;
    var full = RigData.fill(project, pose.t);
    var parts:DynamicAccess<PartT> = new DynamicAccess();
    for (x in project.parts)
      parts.set(x.name, full.get(x.id));
    var path = EditorFiles.modPath('golden/animstudio/${EditorFiles.safeId(project.id)}/poses/${EditorFiles.safeId(pose.folder + '-' + pose.name)}.pose.json', mod);
    var err = EditorFiles.saveJson(path, {golden: 'pose', version: 1, name: pose.name, folder: pose.folder, parts: parts});
    notify(err ?? 'Pose exported to $path', err != null ? 0xFFFF5C5C : 0xFF6BE36B);
  }

  function importPose():Void
  {
    #if sys
    FileUtil.browseForFile('Import pose (.pose.json)', [FileUtil.FILE_FILTER_JSON], file ->
    {
      var d:Dynamic = EditorFiles.loadJson(file.fullPath);
      if (d == null || d.golden != 'pose' || d.parts == null)
      {
        notify('Not a Golden pose file: ${file.fullPath}', 0xFFFF5C5C);
        return;
      }
      var tm = new DynamicAccess<PartT>();
      var matched = 0;
      for (x in project.parts)
      {
        var t:Dynamic = Reflect.field(d.parts, x.name);
        if (t == null) continue;
        tm.set(x.id, RigData.t(t.x, t.y, t.r, t.sx, t.sy, t.a, t.v, t.c));
        matched++;
      }
      if (matched == 0)
      {
        notify('No part names in the pose match this character.', 0xFFFF5C5C);
        return;
      }
      project.poses.push({name: d.name ?? 'Imported pose', folder: d.folder ?? 'Poses/Imported', t: RigData.fill(project, tm)});
      changed();
      openPose(project.poses.length - 1);
      notify('Imported pose "${d.name}" ($matched parts matched).');
    }, () -> {});
    #end
  }

  function editT(id:String, fn:PartT->Void):Void
  {
    editPart(id, fn);
    changed();
  }

  function moveLayer(d:Int):Void
  {
    if (selectedPart == null) return;
    var p = RigData.part(project, selectedPart);
    var i = project.parts.indexOf(p);
    var j = Std.int(Math.max(0, Math.min(project.parts.length - 1, i + d)));
    if (i == j) return;
    project.parts.remove(p);
    project.parts.insert(j, p);
    changed();
    inspectorDirty = true;
  }

  function duplicatePart(id:String):Void
  {
    var p = RigData.part(project, id);
    var nid = RigData.uniqueId(project, p.id + '_copy');
    project.parts.insert(project.parts.indexOf(p) + 1, {id: nid, name: p.name + ' copy', image: p.image, variants: p.variants.copy(), pivotX: p.pivotX, pivotY: p.pivotY, parent: p.parent, role: p.role});
    var rt = RigData.copyT(project.rest.get(id) ?? RigData.t());
    rt.x += 20;
    project.rest.set(nid, rt);
    selectedPart = nid;
    changed();
    inspectorDirty = true;
  }

  function deletePart(id:String):Void
  {
    for (x in project.parts)
      if (x.parent == id) RigData.setParent(project, x.id, null);
    var p = RigData.part(project, id);
    project.parts.remove(p);
    project.rest.remove(id);
    for (pose in project.poses)
      pose.t.remove(id);
    for (an in project.anims)
      an.tracks.remove(id);
    hidden.remove(id);
    selectedPart = null;
    changed();
    inspectorDirty = true;
    notify('Part "${p.name}" deleted.');
  }

  /** Move a part's pivot by (dx, dy) image pixels without moving it on screen (in every pose/key). */
  function movePivot(id:String, dx:Float, dy:Float):Void
  {
    var p = RigData.part(project, id);
    if (p == null || (dx == 0 && dy == 0)) return;
    function fix(t:PartT)
    {
      var m = Affine.trs(0, 0, t.r, t.sx, t.sy).apply(dx, dy);
      t.x += m.x;
      t.y += m.y;
    }
    function fixChild(t:PartT)
    {
      t.x -= dx;
      t.y -= dy;
    }
    var all:Array<DynamicAccess<PartT>> = [project.rest].concat([for (q in project.poses) q.t]);
    for (tm in all)
    {
      if (tm.exists(id)) fix(tm.get(id));
      for (c in project.parts)
        if (c.parent == id && tm.exists(c.id)) fixChild(tm.get(c.id));
    }
    for (an in project.anims)
    {
      for (k in an.tracks.get(id) ?? [])
        fix(k.t);
      for (c in project.parts)
        if (c.parent == id) for (k in an.tracks.get(c.id) ?? [])
          fixChild(k.t);
    }
    p.pivotX += dx;
    p.pivotY += dy;
    needsRender = true;
  }

  // ---- rendering ---------------------------------------------------------------------------------

  function render():Void
  {
    needsRender = false;
    canvasBmp.fillRect(canvasBmp.rect, 0);
    var view = new Affine(1, 0, 0, 1, OX, OY);
    var an = currentAnim();
    if (an != null && onion)
    {
      for (k in 1...onionPrev + 1)
        if (frame - k >= 0) renderer.draw(project, RigData.sample(project, an, frame - k), canvasBmp, view, onionAlpha / k, hidden, null, 0xFF7070);
      for (k in 1...onionNext + 1)
        if (frame + k < an.length) renderer.draw(project, RigData.sample(project, an, frame + k), canvasBmp, view, onionAlpha / k, hidden, null, 0x70FF90);
    }
    var tm = currentTM();
    renderer.draw(project, tm, canvasBmp, view, 1, hidden);
    drawOverlay();
    // For automated tests (GOLDEN_UI_MAP=1): where each part's centre is on screen.
    var w = RigData.world(project, tm);
    for (x in project.parts)
    {
      var img = renderer.imageFor(x, tm.get(x.id).v);
      if (img == null || w.get(x.id) == null) continue;
      var c = RigData.imageMatrix(x, w.get(x.id)).apply(img.width / 2, img.height / 2);
      var sp = worldToScreen(c.x, c.y);
      EditorUI.mapLog('part:${x.id}', sp.x, sp.y, 1, 1);
    }
    timeline.needsRedraw = true;
  }

  function handleRadius():Float
    return 9 / camWorld.zoom;

  /** World positions of the selected part's pivot, rotate handle and scale handle. */
  function handles():Null<{pivot:{x:Float, y:Float}, rot:{x:Float, y:Float}, scale:{x:Float, y:Float}, corners:Array<{x:Float, y:Float}>}>
  {
    if (selectedPart == null) return null;
    var p = RigData.part(project, selectedPart);
    if (p == null) return null;
    var tm = currentTM();
    var w = RigData.world(project, tm).get(p.id);
    var img = renderer.imageFor(p, tm.get(p.id).v);
    if (w == null || img == null) return null;
    var m = RigData.imageMatrix(p, w);
    var corners = [m.apply(0, 0), m.apply(img.width, 0), m.apply(img.width, img.height), m.apply(0, img.height)];
    var top = m.apply(img.width / 2, 0);
    var up = {x: top.x - w.tx, y: top.y - w.ty};
    var len = Math.sqrt(up.x * up.x + up.y * up.y);
    if (len < 1)
    {
      up = {x: 0, y: -1};
      len = 1;
    }
    var off = 28 / camWorld.zoom;
    var rot = {x: top.x + up.x / len * off, y: top.y + up.y / len * off};
    return {pivot: {x: w.tx, y: w.ty}, rot: rot, scale: corners[2], corners: corners};
  }

  function drawOverlay():Void
  {
    overlayBmp.fillRect(overlayBmp.rect, 0);
    var s = new Shape();
    var g = s.graphics;
    var lw = Math.max(1, 1.5 / camWorld.zoom);
    // floor line and origin
    g.lineStyle(lw, 0x6A5F80, 0.8);
    g.moveTo(-500, 0);
    g.lineTo(500, 0);
    g.moveTo(0, -12);
    g.lineTo(0, 12);
    var h = handles();
    if (h != null)
    {
      g.lineStyle(lw, 0xFFC83D, 1);
      g.moveTo(h.corners[0].x, h.corners[0].y);
      for (i in 1...5)
        g.lineTo(h.corners[i % 4].x, h.corners[i % 4].y);
      var r = handleRadius();
      g.moveTo((h.corners[0].x + h.corners[1].x) / 2, (h.corners[0].y + h.corners[1].y) / 2);
      g.lineTo(h.rot.x, h.rot.y);
      g.beginFill(0x3A2C5C);
      g.drawCircle(h.rot.x, h.rot.y, r * 0.8);
      g.endFill();
      g.beginFill(0xFFC83D);
      g.drawRect(h.scale.x - r * 0.6, h.scale.y - r * 0.6, r * 1.2, r * 1.2);
      g.endFill();
      g.lineStyle(lw, 0xFF5C8A, 1);
      g.drawCircle(h.pivot.x, h.pivot.y, r * 0.7);
      g.moveTo(h.pivot.x - r * 1.4, h.pivot.y);
      g.lineTo(h.pivot.x + r * 1.4, h.pivot.y);
      g.moveTo(h.pivot.x, h.pivot.y - r * 1.4);
      g.lineTo(h.pivot.x, h.pivot.y + r * 1.4);
    }
    overlayBmp.draw(s, new Matrix(1, 0, 0, 1, OX, OY), null, null, null, true);
    lastZoom = camWorld.zoom;
  }

  // ---- workspace interaction ---------------------------------------------------------------------

  override public function workspaceCenter():{x:Float, y:Float}
    return {x: (leftW + 44 + (FlxG.width - rightW)) / 2, y: (GoldenEditorState.TOP + (FlxG.height - GoldenEditorState.BOTTOM - TL_H)) / 2};

  override function leftDragPans():Bool
    return tool == 'pan';

  override public function mouseInWorkspace():Bool
  {
    var p = FlxG.mouse.getViewPosition(camUI);
    var r = p.x > leftW + 44 && p.x < FlxG.width - rightW && p.y > GoldenEditorState.TOP && p.y < FlxG.height - GoldenEditorState.BOTTOM - TL_H;
    p.put();
    return r;
  }

  function near(a:{x:Float, y:Float}, x:Float, y:Float):Bool
  {
    var dx = a.x - x, dy = a.y - y;
    return dx * dx + dy * dy <= Math.pow(handleRadius() * 1.4, 2);
  }

  function workspaceMouse():Void
  {
    var space = FlxG.keys.pressed.SPACE;
    var wm = worldMouse();
    var mx = wm.x, my = wm.y;
    wm.put();
    if (FlxG.mouse.justPressed && mouseInWorkspace() && !space && tool != 'pan')
    {
      if (tool == 'zoom')
      {
        zoomAt(FlxG.keys.pressed.ALT ? 1 / 1.5 : 1.5);
        needsRender = true;
        return;
      }
      var h = handles();
      var kind:Null<String> = null;
      if (h != null)
      {
        if (near(h.rot, mx, my)) kind = 'rotate';
        else if (near(h.scale, mx, my)) kind = 'scale';
        else if (near(h.pivot, mx, my) && (tool == 'pivot' || FlxG.keys.pressed.ALT)) kind = 'pivot';
      }
      if (kind == null)
      {
        var hit = renderer.hitTest(project, currentTM(), mx, my, hidden);
        if (hit != selectedPart)
        {
          selectedPart = hit;
          inspectorDirty = true;
          needsRender = true;
          if (hit != null) UISound.play(Click);
        }
        if (hit != null) kind = tool;
      }
      if (kind != null && selectedPart != null)
      {
        var p = RigData.part(project, selectedPart);
        drag = {
          kind: kind,
          part: selectedPart,
          mx: mx,
          my: my,
          start: RigData.copyT(partT(selectedPart)),
          pivot: {x: p.pivotX, y: p.pivotY}
        };
      }
    }
    if (drag != null && FlxG.mouse.pressed)
    {
      var id = drag.part;
      var st = drag.start;
      var p = RigData.part(project, id);
      if (p == null)
      {
        drag = null;
        return;
      }
      var tm = currentTM();
      var w = RigData.world(project, tm);
      var parentW = p.parent != null ? w.get(p.parent) : null;
      var pivotWorld = w.get(id);
      switch (drag.kind)
      {
        case 'move':
          var dx = mx - drag.mx, dy = my - drag.my;
          if (parentW != null)
          {
            var inv = parentW.invert();
            var a = inv.apply(0, 0), b = inv.apply(dx, dy);
            dx = b.x - a.x;
            dy = b.y - a.y;
          }
          editPart(id, t ->
          {
            t.x = Math.round((st.x + dx) * 10) / 10;
            t.y = Math.round((st.y + dy) * 10) / 10;
          });
        case 'rotate':
          var a0 = Math.atan2(drag.my - pivotWorld.ty, drag.mx - pivotWorld.tx);
          var a1 = Math.atan2(my - pivotWorld.ty, mx - pivotWorld.tx);
          var r = st.r + (a1 - a0) * 180 / Math.PI;
          if (FlxG.keys.pressed.SHIFT) r = Math.round(r / 15) * 15;
          editPart(id, t -> t.r = Math.round(r * 10) / 10);
        case 'scale':
          var d0 = Math.sqrt(Math.pow(drag.mx - pivotWorld.tx, 2) + Math.pow(drag.my - pivotWorld.ty, 2));
          var d1 = Math.sqrt(Math.pow(mx - pivotWorld.tx, 2) + Math.pow(my - pivotWorld.ty, 2));
          var k = d0 < 1 ? 1 : d1 / d0;
          editPart(id, t ->
          {
            t.sx = Math.round(st.sx * k * 100) / 100;
            t.sy = Math.round(st.sy * k * 100) / 100;
          });
        case 'pivot':
          var q = RigData.imageMatrix(p, pivotWorld).invert().apply(mx, my);
          movePivot(id, Math.round(q.x) - p.pivotX, Math.round(q.y) - p.pivotY);
      }
      inspector.refresh();
    }
    if (drag != null && FlxG.mouse.justReleased)
    {
      trace('[GOLDEN EDITOR] Animation Studio: ${drag.kind} ${drag.part} (${mode}${currentAnim() != null ? " frame " + frame : ""})');
      drag = null;
      changed();
    }
  }

  function nudge(dx:Float, dy:Float):Void
  {
    if (selectedPart == null) return;
    editT(selectedPart, t ->
    {
      t.x += dx;
      t.y += dy;
    });
    inspector.refresh();
  }

  public function setFrame(f:Int):Void
  {
    var an = currentAnim();
    if (an == null) return;
    frame = Std.int(Math.max(0, Math.min(an.length - 1, f)));
    needsRender = true;
    inspector.refresh();
  }

  public function togglePlay():Void
  {
    if (currentAnim() == null) return;
    playing = !playing;
    playTime = 0;
    setStatus(playing ? 'Playing' : 'Paused at frame $frame');
  }

  public function addKey(all:Bool):Void
  {
    var an = currentAnim();
    if (an == null) return;
    var tm = currentTM();
    var ids = all || selectedPart == null ? [for (x in project.parts) x.id] : [selectedPart];
    for (id in ids)
      RigData.setKey(an, id, frame, tm.get(id));
    changed();
    notify('Keyframe at $frame (${ids.length == 1 ? RigData.part(project, ids[0]).name : "all parts"}).');
  }

  public function deleteKey(all:Bool):Void
  {
    var an = currentAnim();
    if (an == null) return;
    var ids = all || selectedPart == null ? [for (x in project.parts) x.id] : [selectedPart];
    var n = 0;
    for (id in ids)
      if (RigData.removeKey(an, id, frame)) n++;
    if (n > 0) changed();
    notify(n > 0 ? 'Deleted $n key(s) at frame $frame.' : 'No key at frame $frame.');
  }

  /** Copy the keys of the current frame to the next frame. */
  public function duplicateKeys():Void
  {
    var an = currentAnim();
    if (an == null) return;
    var n = 0;
    for (x in project.parts)
    {
      var k = RigData.keyAt(an, x.id, frame);
      if (k != null && (selectedPart == null || selectedPart == x.id || FlxG.keys.pressed.SHIFT))
      {
        RigData.setKey(an, x.id, frame + 1, k.t);
        n++;
      }
    }
    if (n == 0)
    {
      notify('No keys at frame $frame to duplicate.');
      return;
    }
    changed();
    setFrame(frame + 1);
    notify('Duplicated $n key(s) to frame $frame.');
  }

  public function moveKey(id:String, from:Int, to:Int):Void
  {
    var an = currentAnim();
    if (an == null) return;
    if (RigData.moveKey(an, id, from, to))
    {
      changed();
      setFrame(to);
    }
  }

  public function toggleOnion():Void
  {
    onion = !onion;
    needsRender = true;
    inspector.refresh();
  }

  public function toggleHidden(id:String):Void
  {
    if (hidden.exists(id)) hidden.remove(id) else hidden.set(id, true);
    needsRender = true;
    inspectorDirty = true;
  }

  public function selectPart(id:String):Void
  {
    if (selectedPart == id) return;
    selectedPart = id;
    inspectorDirty = needsRender = true;
  }

  override function editorKeys():Void
  {
    var ctrl = FlxG.keys.pressed.CONTROL;
    var shift = FlxG.keys.pressed.SHIFT;
    if (ctrl)
    {
      if (FlxG.keys.justPressed.D) duplicateKeys();
      else if (FlxG.keys.justPressed.C && selectedPart != null)
      {
        clipboard = RigData.copyT(partT(selectedPart));
        notify('Copied transform of ${RigData.part(project, selectedPart).name}.');
      }
      else if (FlxG.keys.justPressed.V && selectedPart != null && clipboard != null)
      {
        var c = clipboard;
        editT(selectedPart, t ->
        {
          t.x = c.x;
          t.y = c.y;
          t.r = c.r;
          t.sx = c.sx;
          t.sy = c.sy;
          t.a = c.a;
          t.v = c.v;
          t.c = c.c;
        });
        inspector.refresh();
      }
      return;
    }
    for (t in ['move', 'rotate', 'scale', 'pivot', 'pan', 'zoom'])
      if (pressed(t)) setTool(t);
    var step = shift ? 10 : 1;
    if (FlxG.keys.justPressed.LEFT) nudge(-step, 0);
    if (FlxG.keys.justPressed.RIGHT) nudge(step, 0);
    if (FlxG.keys.justPressed.UP) nudge(0, -step);
    if (FlxG.keys.justPressed.DOWN) nudge(0, step);
    if (selectedPart != null && pressed('rotLeft')) editT(selectedPart, t -> t.r -= shift ? 15 : 1);
    if (selectedPart != null && pressed('rotRight')) editT(selectedPart, t -> t.r += shift ? 15 : 1);
    if (pressed('play')) togglePlay();
    if (pressed('prevFrame')) setFrame(frame - 1);
    if (pressed('nextFrame')) setFrame(frame + 1);
    if (pressed('firstFrame')) setFrame(0);
    if (pressed('lastFrame') && currentAnim() != null) setFrame(currentAnim().length - 1);
    if (pressed('key')) addKey(shift);
    if (pressed('deleteKey')) deleteKey(shift);
    if (pressed('onion')) toggleOnion();
    if (pressed('layerUp')) moveLayer(1);
    if (pressed('layerDown')) moveLayer(-1);
    if (pressed('focus'))
    {
      var b = renderer.bounds(project, currentTM());
      centerWorkspaceOn(b.x + b.width / 2, b.y + b.height / 2);
    }
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (leaving) return;
    if (subState == null && armed) workspaceMouse();
    var an = currentAnim();
    if (playing && an != null)
    {
      playTime += elapsed;
      var step = 1 / Math.max(1, an.fps);
      while (playTime >= step)
      {
        playTime -= step;
        var nf = frame + 1;
        if (nf >= an.length)
        {
          nf = 0;
          if (!an.loop && FlxG.keys.pressed.SHIFT) playing = false;
        }
        frame = nf;
        needsRender = true;
      }
    }
    if (browserDirty && drag == null) rebuildBrowser();
    if (inspectorDirty) rebuildInspector();
    if (needsRender || lastZoom != camWorld.zoom) render();
    if (statusMsg == '') setStatus('Tool: $tool');
  }

  override function destroy():Void
  {
    for (t in thumbs)
      t.dispose();
    thumbs = [];
    super.destroy();
  }
}

/** Frame timeline: one row per part (eye toggle + name), key cells, ruler and playhead. */
class Timeline extends flixel.group.FlxSpriteGroup
{
  public var needsRedraw:Bool = true;

  var studio:AnimationStudioState;
  var tw:Int;
  var th:Int;
  var grid:FlxSprite;
  var gridBmp:BitmapData;
  var names:Array<FlxText> = [];
  var rulerNums:Array<FlxText> = [];
  var info:FlxText;
  var rowScroll:Int = 0;
  var frameScroll:Int = 0;
  var dragKey:Null<{id:String, from:Int}> = null;

  static inline var NAME_W:Int = 118;
  static inline var CELL:Int = 14;
  static inline var ROW:Int = 15;
  static inline var CTRL_H:Int = 28;
  static inline var RULER_H:Int = 16;

  public function new(studio:AnimationStudioState, x:Float, y:Float, w:Int, h:Int)
  {
    super(x, y);
    this.studio = studio;
    tw = w;
    th = h;
    add(EditorUI.rect(0, 0, w, h, EditorUI.PANEL));
    add(EditorUI.rect(0, 0, w, 1, EditorUI.ACCENT));
    var bx = 6.0;
    var buttons:Array<{c:String, f:Void->Void, t:String}> = [
      {c: '|<', f: () -> studio.setFrame(0), t: 'First frame (Home)'},
      {c: '<', f: () -> studio.setFrame(studio.frame - 1), t: 'Previous frame (,)'},
      {c: 'Play', f: () -> studio.togglePlay(), t: 'Play / pause (Enter)'},
      {c: '>', f: () -> studio.setFrame(studio.frame + 1), t: 'Next frame (.)'},
      {c: '>|', f: () -> studio.setFrame((studio.currentAnim()?.length ?? 1) - 1), t: 'Last frame (End)'},
      {c: '+Key', f: () -> studio.addKey(false), t: 'Keyframe selected part (K; Shift = all parts)'},
      {c: '-Key', f: () -> studio.deleteKey(false), t: 'Delete key (Delete; Shift = all parts)'},
      {c: 'Dup', f: () -> studio.duplicateKeys(), t: 'Copy keys to the next frame (Ctrl+D)'},
      {c: 'Onion', f: () -> studio.toggleOnion(), t: 'Onion skin (O)'}
    ];
    for (b in buttons)
    {
      var bw = b.c.length * 9 + 16;
      add(new EButton(bx, 4, bw, 20, b.c, b.f, b.t));
      bx += bw + 3;
    }
    info = EditorUI.text(bx + 6, 7, w - bx - 10, '', 12, EditorUI.MUTED);
    add(info);
    gridBmp = new BitmapData(w, h - CTRL_H, true, 0);
    grid = new FlxSprite(0, CTRL_H).loadGraphic(gridBmp);
    add(grid);
    for (i in 0...12)
    {
      var t = EditorUI.text(16, CTRL_H + RULER_H + i * ROW, NAME_W - 18, '', 11, EditorUI.TEXT);
      names.push(t);
      add(t);
    }
    for (i in 0...12)
    {
      var t = EditorUI.text(0, CTRL_H + 1, 30, '', 10, EditorUI.MUTED);
      rulerNums.push(t);
      add(t);
    }
    scrollFactor.set();
  }

  function visibleFrames():Int
    return Std.int((tw - NAME_W - 4) / CELL);

  function visibleRows():Int
    return Std.int((th - CTRL_H - RULER_H) / ROW);

  function redraw():Void
  {
    needsRedraw = false;
    var an = studio.currentAnim();
    var p = studio.project;
    gridBmp.fillRect(gridBmp.rect, 0xFF1B1820);
    for (t in names)
      t.text = '';
    for (t in rulerNums)
      t.text = '';
    if (an == null)
    {
      info.text = 'Open an animation (left browser) to edit its timeline.';
      return;
    }
    info.text = '${an.name}  frame ${studio.frame + 1}/${an.length}  ${an.fps} fps' + (an.loop ? '  loop' : '') + (studio.playing ? '  PLAYING' : '');
    var vf = visibleFrames();
    if (studio.frame < frameScroll) frameScroll = studio.frame;
    if (studio.frame >= frameScroll + vf) frameScroll = studio.frame - vf + 1;
    // ruler
    for (i in 0...vf)
    {
      var f = frameScroll + i;
      var cx = NAME_W + i * CELL;
      var inside = f < an.length;
      gridBmp.fillRect(new Rectangle(cx, 0, CELL - 1, RULER_H - 1), inside ? (f % 5 == 0 ? 0xFF3A3448 : 0xFF2A2633) : 0xFF16141B);
    }
    var ri = 0;
    var i = 0;
    while (i < vf && ri < rulerNums.length)
    {
      var f = frameScroll + i;
      if (f % 5 == 0 && f < an.length)
      {
        rulerNums[ri].text = Std.string(f);
        rulerNums[ri].x = x + NAME_W + i * CELL + 1;
        ri++;
      }
      i++;
    }
    // rows (top row = front-most layer)
    var order = [for (q in p.parts) q];
    order.reverse();
    var vr = visibleRows();
    if (rowScroll > Std.int(Math.max(0, order.length - vr))) rowScroll = Std.int(Math.max(0, order.length - vr));
    for (r in 0...vr)
    {
      var idx = rowScroll + r;
      if (idx >= order.length) break;
      var part = order[idx];
      var ry = RULER_H + r * ROW;
      var sel = studio.selectedPart == part.id;
      gridBmp.fillRect(new Rectangle(0, ry, NAME_W - 2, ROW - 1), sel ? 0xFF5B4A1A : 0xFF24212B);
      // eye
      gridBmp.fillRect(new Rectangle(3, ry + 3, 9, ROW - 7), studio.hidden.exists(part.id) ? 0xFF3A3645 : 0xFFFFC83D);
      if (r < names.length)
      {
        names[r].text = part.name;
        names[r].color = sel ? EditorUI.ACCENT : EditorUI.TEXT;
      }
      for (c in 0...vf)
      {
        var f = frameScroll + c;
        var cx = NAME_W + c * CELL;
        if (f >= an.length)
        {
          gridBmp.fillRect(new Rectangle(cx, ry, CELL - 1, ROW - 1), 0xFF16141B);
          continue;
        }
        gridBmp.fillRect(new Rectangle(cx, ry, CELL - 1, ROW - 1), sel ? 0xFF2E2A38 : 0xFF221F29);
        if (RigData.keyAt(an, part.id, f) != null) gridBmp.fillRect(new Rectangle(cx + 3, ry + 3, CELL - 7, ROW - 7), sel ? 0xFFFFC83D : 0xFFC9A040);
      }
    }
    // playhead
    var ph = studio.frame - frameScroll;
    if (ph >= 0 && ph < vf) gridBmp.fillRect(new Rectangle(NAME_W + ph * CELL + CELL / 2 - 1, 0, 2, gridBmp.height), 0xFFFF5C5C);
    EditorUI.mapLog('timeline:grid', x + NAME_W, y + CTRL_H + RULER_H, vf * CELL, vr * ROW);
  }

  function hit(mx:Float, my:Float):Null<{row:Int, frame:Int, part:Null<RigPart>, eye:Bool, ruler:Bool}>
  {
    var lx = mx - x, ly = my - y - CTRL_H;
    if (lx < 0 || ly < 0 || lx >= tw || ly >= th - CTRL_H) return null;
    var f = lx >= NAME_W ? frameScroll + Std.int((lx - NAME_W) / CELL) : -1;
    if (ly < RULER_H) return {row: -1, frame: f, part: null, eye: false, ruler: true};
    var r = Std.int((ly - RULER_H) / ROW);
    var order = [for (q in studio.project.parts) q];
    order.reverse();
    var idx = rowScroll + r;
    return {row: r, frame: f, part: idx < order.length ? order[idx] : null, eye: lx < 14, ruler: false};
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    var an = studio.currentAnim();
    var p = FlxG.mouse.getViewPosition(camera);
    var over = p.x >= x && p.x < x + tw && p.y >= y + CTRL_H && p.y < y + th;
    if (over && an != null)
    {
      if (FlxG.mouse.wheel != 0)
      {
        if (FlxG.keys.pressed.SHIFT) frameScroll = Std.int(Math.max(0, frameScroll - FlxG.mouse.wheel));
        else rowScroll = Std.int(Math.max(0, rowScroll - FlxG.mouse.wheel));
        needsRedraw = true;
      }
      if (FlxG.mouse.justPressed)
      {
        var h = hit(p.x, p.y);
        if (h != null)
        {
          if (h.eye && h.part != null) studio.toggleHidden(h.part.id);
          else
          {
            if (h.part != null) studio.selectPart(h.part.id);
            if (h.frame >= 0)
            {
              if (h.part != null && RigData.keyAt(an, h.part.id, h.frame) != null) dragKey = {id: h.part.id, from: h.frame};
              studio.setFrame(h.frame);
            }
          }
          needsRedraw = true;
        }
      }
      else if (FlxG.mouse.pressed && dragKey == null)
      {
        var h = hit(p.x, p.y);
        if (h != null && h.ruler && h.frame >= 0 && h.frame != studio.frame) studio.setFrame(h.frame); // scrubbing
      }
    }
    if (dragKey != null && FlxG.mouse.justReleased && an != null)
    {
      var h = hit(p.x, p.y);
      if (h != null && h.frame >= 0 && h.frame != dragKey.from) studio.moveKey(dragKey.id, dragKey.from, h.frame);
      dragKey = null;
      needsRedraw = true;
    }
    p.put();
    if (needsRedraw) redraw();
  }
}
