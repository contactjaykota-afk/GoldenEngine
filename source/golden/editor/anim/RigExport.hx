package golden.editor.anim;

import haxe.DynamicAccess;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import golden.editor.EditorFiles;
import golden.editor.anim.RigData;

/**
 * Golden Engine Animation Studio — export a rig project as a normal FNF character that gameplay loads:
 *   mods/<mod>/images/characters/<id>.png + .xml   (Sparrow sprite sheet, trimmed frames)
 *   mods/<mod>/data/characters/<id>.json           (FNF character data, renderType "sparrow")
 *   mods/<mod>/images/icons/icon-<id>.png          (health icon from the head, normal + losing)
 * Every frame is rendered into the same canvas (feet at the bottom centre), so no per-animation
 * offsets are needed; frames are trimmed with frameX/frameY so the sheet stays small.
 * The editable project itself is saved separately (golden/animstudio/<id>/project.json + parts/).
 */
class RigExport
{
  /** Sheet size (4096 is supported by practically every GPU). */
  public static inline var SHEET:Int = 4096;

  public static function frameName(index:Int, an:RigAnim, f:Int):String
    return 'a' + StringTools.lpad(Std.string(index), '0', 2) + ' ' + an.fnfName + StringTools.lpad(Std.string(f), '0', 4);

  public static function prefix(index:Int, an:RigAnim):String
    return 'a' + StringTools.lpad(Std.string(index), '0', 2) + ' ' + an.fnfName;

  /** Returns {error} or {files, frames, size}. */
  public static function export(p:RigProject, r:RigRenderer, mod:String):{error:Null<String>, files:Array<String>, frames:Int, sheet:String}
  {
    var id = EditorFiles.safeId(p.id);
    if (p.parts.length == 0) return {error: 'The character has no parts to export.', files: [], frames: 0, sheet: ''};
    var anims = p.anims.filter(a -> a.fnfName != null && a.fnfName != '');
    if (anims.length == 0) return {error: 'No animations to export (generate poses or add an animation).', files: [], frames: 0, sheet: ''};
    if (!anims.exists(a -> a.fnfName == 'idle')) return {error: 'An animation named "idle" is required (FNF characters start with it).', files: [], frames: 0, sheet: ''};

    // 1. Canvas: union of all frames, symmetric around x = 0, bottom at the feet.
    var minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0;
    var samples:Array<{name:String, tm:DynamicAccess<PartT>, anim:Int}> = [];
    for (i in 0...anims.length)
      for (f in 0...anims[i].length)
      {
        var tm = RigData.sample(p, anims[i], f);
        var b = r.bounds(p, tm);
        minX = Math.min(minX, b.x);
        maxX = Math.max(maxX, b.right);
        minY = Math.min(minY, b.y);
        maxY = Math.max(maxY, b.bottom);
        samples.push({name: frameName(i, anims[i], f), tm: tm, anim: i});
      }
    var half = Math.ceil(Math.max(-minX, maxX)) + 2;
    var top = Math.floor(minY) - 2;
    var bottom = Math.ceil(Math.max(0, maxY)) + 2;
    var cw = half * 2, ch = bottom - top;
    if (cw > 4096 || ch > 4096) return {error: 'The character is too large ($cw x $ch px); scale parts down.', files: [], frames: 0, sheet: ''};
    var view = new Affine(1, 0, 0, 1, half, -top);

    // 2. Render + trim each frame. Within an animation, frames with identical transforms (holds)
    //    share one image.
    var frames:Array<{name:String, bmp:BitmapData, fx:Int, fy:Int, anim:Int}> = [];
    var aliases:Array<{name:String, of:Int}> = [];
    var canvas = new BitmapData(cw, ch, true, 0);
    var bySig:Map<String, Int> = [];
    var lastAnim = -1;
    for (s in samples)
    {
      if (s.anim != lastAnim)
      {
        bySig = [];
        lastAnim = s.anim;
      }
      var sig = haxe.Json.stringify(s.tm);
      if (bySig.exists(sig))
      {
        aliases.push({name: s.name, of: bySig.get(sig)});
        continue;
      }
      bySig.set(sig, frames.length);
      canvas.fillRect(canvas.rect, 0);
      r.draw(p, s.tm, canvas, view);
      var tr = canvas.getColorBoundsRect(0xFF000000, 0, false);
      if (tr.width <= 0 || tr.height <= 0) tr = new Rectangle(0, 0, 1, 1);
      var fb = new BitmapData(Std.int(tr.width), Std.int(tr.height), true, 0);
      fb.copyPixels(canvas, tr, new Point(0, 0));
      frames.push({name: s.name, bmp: fb, fx: Std.int(tr.x), fy: Std.int(tr.y), anim: s.anim});
    }
    canvas.dispose();

    // 3. Shelf packing, one animation at a time, into sheets of at most SHEET x SHEET pixels. A big
    //    character uses several sheets (FNF "multisparrow": each animation names its sheet).
    var sheetOf:Array<Int> = [for (_ in anims) 0];
    var pos:Array<{x:Int, y:Int}> = [for (_ in frames) null];
    var sheets:Array<{h:Int}> = [{h: 0}];
    var cx = 0, cy = 0, rowH = 0;
    for (ai in 0...anims.length)
    {
      var idx = [for (i in 0...frames.length) if (frames[i].anim == ai) i];
      idx.sort((a, b) -> frames[b].bmp.height - frames[a].bmp.height);
      function tryPack(x0:Int, y0:Int, r0:Int):Null<{x:Int, y:Int, r:Int, p:Array<{x:Int, y:Int}>}>
      {
        var x = x0, y = y0, rh = r0, out = [];
        for (i in idx)
        {
          var fw = frames[i].bmp.width, fh = frames[i].bmp.height;
          if (fw + 2 > SHEET || fh + 2 > SHEET) return null;
          if (x + fw + 2 > SHEET)
          {
            x = 0;
            y += rh + 2;
            rh = 0;
          }
          if (y + fh > SHEET) return null;
          out.push({x: x, y: y});
          x += fw + 2;
          rh = Std.int(Math.max(rh, fh));
        }
        return {x: x, y: y, r: rh, p: out};
      }
      var res = tryPack(cx, cy, rowH);
      if (res == null)
      {
        sheets.push({h: 0});
        res = tryPack(0, 0, 0);
        if (res == null) return {error: 'Animation "${anims[ai].name}" alone does not fit a ${SHEET}x$SHEET sheet: shorten it or scale parts down.', files: [], frames: 0, sheet: ''};
      }
      sheetOf[ai] = sheets.length - 1;
      for (k in 0...idx.length)
        pos[idx[k]] = res.p[k];
      cx = res.x;
      cy = res.y;
      rowH = res.r;
      sheets[sheets.length - 1].h = Std.int(Math.max(sheets[sheets.length - 1].h, cy + rowH));
    }

    var files = [];
    var err:Null<String> = null;
    function sheetName(si:Int):String
      return si == 0 ? id : '$id-${si + 1}';
    for (si in 0...sheets.length)
    {
      var sheet = new BitmapData(SHEET, Std.int(Math.max(1, sheets[si].h)), true, 0);
      var xml = new StringBuf();
      xml.add('<?xml version="1.0" encoding="utf-8"?>\n<!-- Exported by Golden Engine Animation Studio from project "${p.id}" -->\n<TextureAtlas imagePath="${sheetName(si)}.png">\n');
      function sub(name:String, i:Int)
      {
        var f = frames[i];
        xml.add('  <SubTexture name="$name" x="${pos[i].x}" y="${pos[i].y}" width="${f.bmp.width}" height="${f.bmp.height}" frameX="${-f.fx}" frameY="${-f.fy}" frameWidth="$cw" frameHeight="$ch"/>\n');
      }
      for (i in 0...frames.length)
        if (sheetOf[frames[i].anim] == si)
        {
          sheet.copyPixels(frames[i].bmp, frames[i].bmp.rect, new Point(pos[i].x, pos[i].y));
          sub(frames[i].name, i);
        }
      for (al in aliases)
        if (sheetOf[frames[al.of].anim] == si) sub(al.name, al.of);
      xml.add('</TextureAtlas>\n');
      var sheetPath = EditorFiles.modPath('images/characters/${sheetName(si)}.png', mod);
      err = EditorFiles.saveBytes(sheetPath, png(sheet));
      sheet.dispose();
      if (err != null) return {error: err, files: files, frames: 0, sheet: ''};
      files.push(sheetPath);
      var xmlPath = EditorFiles.modPath('images/characters/${sheetName(si)}.xml', mod);
      err = EditorFiles.saveText(xmlPath, xml.toString());
      if (err != null) return {error: err, files: files, frames: 0, sheet: ''};
      files.push(xmlPath);
    }
    for (f in frames)
      f.bmp.dispose();
    // remove sheets left over from a previous, bigger export
    #if sys
    var extra = sheets.length + 1;
    while (EditorFiles.exists(EditorFiles.modPath('images/characters/$id-$extra.png', mod)))
    {
      for (ext in ['png', 'xml'])
      {
        var old = EditorFiles.modPath('images/characters/$id-$extra.$ext', mod);
        if (EditorFiles.exists(old)) sys.FileSystem.deleteFile(old);
      }
      extra++;
    }
    #end
    var sheetW = SHEET, sheetH = sheets[0].h;

    // 4. Health icon (150x150 normal + losing).
    var headIds = headParts(p);
    var hasIcon = headIds.length > 0;
    if (hasIcon)
    {
      var idle = RigData.sample(p, anims.find(a -> a.fnfName == 'idle'), 0);
      var icon = new BitmapData(300, 150, true, 0);
      var normal = r.thumbnail(p, idle, 150, 0, headIds);
      icon.copyPixels(normal, normal.rect, new Point(0, 0));
      var lose = RigData.fill(p, idle);
      for (k in lose.keys())
        lose.get(k).c = 0x9A8CD8;
      var eyes = p.parts.find(q -> q.role == 'eyes');
      if (eyes != null && eyes.variants.length > 0) lose.get(eyes.id).v = 1;
      var losing = r.thumbnail(p, lose, 150, 0, headIds);
      icon.copyPixels(losing, losing.rect, new Point(150, 0));
      var iconPath = EditorFiles.modPath('images/icons/icon-$id.png', mod);
      err = EditorFiles.saveBytes(iconPath, png(icon));
      if (err != null) return {error: err, files: files, frames: 0, sheet: ''};
      files.push(iconPath);
    }

    // 5. FNF character data.
    var data:Dynamic = {
      version: '1.0.0',
      name: p.name,
      renderType: sheets.length > 1 ? 'multisparrow' : 'sparrow',
      assetPath: 'characters/$id',
      scale: p.scale,
      flipX: p.flipX,
      offsets: [0, 0],
      cameraOffsets: [0, 0],
      singTime: 8.0,
      danceEvery: 1,
      startingAnimation: 'idle',
      healthIcon: {id: hasIcon ? id : 'face'},
      animations: [
        for (i in 0...anims.length)
          {
            name: anims[i].fnfName,
            prefix: prefix(i, anims[i]),
            assetPath: sheetOf[i] > 0 ? 'characters/${sheetName(sheetOf[i])}' : null,
            frameRate: anims[i].fps,
            looped: anims[i].loop,
            offsets: [0, 0]
          }
      ]
    };
    var jsonPath = EditorFiles.modPath('data/characters/$id.json', mod);
    err = EditorFiles.saveJson(jsonPath, data);
    if (err != null) return {error: err, files: files, frames: 0, sheet: ''};
    files.push(jsonPath);
    trace('[GOLDEN EDITOR] Exported character "$id": ${frames.length + aliases.length} frames (${frames.length} unique) on ${sheets.length} sheet(s), ${anims.length} animations, sheet ${sheetW}x$sheetH, canvas ${cw}x$ch');
    return {error: null, files: files, frames: frames.length + aliases.length, sheet: sheets.length > 1 ? '${sheets.length} sheets' : '${sheetW}x$sheetH'};
  }

  /** Head and everything attached to it. */
  public static function headParts(p:RigProject):Array<String>
  {
    var head = p.parts.find(q -> q.role == 'head');
    if (head == null) return [];
    var out = [head.id];
    var grew = true;
    while (grew)
    {
      grew = false;
      for (q in p.parts)
        if (q.parent != null && out.contains(q.parent) && !out.contains(q.id))
        {
          out.push(q.id);
          grew = true;
        }
    }
    return out;
  }

  public static function png(b:BitmapData):haxe.io.Bytes
  {
    var ba = b.encode(b.rect, new PNGEncoderOptions());
    return ba;
  }

  /** Save the editable project (project.json + every part image as PNG). */
  public static function saveProject(p:RigProject, r:RigRenderer, mod:String):Null<String>
  {
    var dir = EditorFiles.modPath('golden/animstudio/${EditorFiles.safeId(p.id)}', mod);
    var used:Array<String> = [];
    for (x in p.parts)
    {
      used.push(x.image);
      for (v in x.variants)
        used.push(v);
    }
    for (name in used)
    {
      var img = r.images.get(name);
      if (img == null) continue;
      var err = EditorFiles.saveBytes(Path.join([dir, 'parts', name]), png(img));
      if (err != null) return err;
    }
    return EditorFiles.saveText(Path.join([dir, 'project.json']), RigData.toJson(p));
  }

  /** Projects saved in a mod. */
  public static function listProjects(mod:String):Array<String>
  {
    var root = EditorFiles.modPath('golden/animstudio', mod);
    #if sys
    if (root == null || !sys.FileSystem.exists(root)) return [];
    return [
      for (d in sys.FileSystem.readDirectory(root))
        if (sys.FileSystem.exists(Path.join([root, d, 'project.json']))) d
    ];
    #else
    return [];
    #end
  }

  /** Load a project and its part images. */
  public static function loadProject(id:String, r:RigRenderer, mod:String):{project:Null<RigProject>, error:Null<String>}
  {
    var dir = EditorFiles.modPath('golden/animstudio/$id', mod);
    var text = EditorFiles.loadText(Path.join([dir, 'project.json']));
    if (text == null) return {project: null, error: 'Project "$id" not found in $mod.'};
    var p:RigProject;
    try
    {
      p = RigData.fromJson(text);
    }
    catch (e:Dynamic)
    {
      return {project: null, error: 'Could not read project "$id": $e'};
    }
    var missing = [];
    for (x in p.parts)
      for (name in [x.image].concat(x.variants))
      {
        var file = Path.join([dir, 'parts', name]);
        var b = loadImage(file);
        if (b == null) missing.push(name);
        else r.images.set(name, b);
      }
    return {project: p, error: missing.length > 0 ? 'Missing part images: ' + missing.join(', ') : null};
  }

  public static function loadImage(file:String):Null<BitmapData>
  {
    #if sys
    if (!sys.FileSystem.exists(file)) return null;
    try
    {
      return BitmapData.fromBytes(sys.io.File.getBytes(file));
    }
    catch (e:Dynamic)
    {
      trace('[GOLDEN EDITOR] Could not load image $file: $e');
      return null;
    }
    #else
    return null;
    #end
  }
}
