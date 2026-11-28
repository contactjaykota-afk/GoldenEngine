package golden.editor.anim;

import haxe.DynamicAccess;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import golden.editor.anim.RigData;

using StringTools;

private typedef Leaf =
{
  key:String, // image key (symbol#frame or sprite name)
  slot:String, // part slot (Head, Face, Body, Arm, Hand, Whole body)
  m:Affine, // symbol space -> character space
  ?trp:{x:Float, y:Float}
}

/**
 * Golden Engine Animation Studio — imports an Adobe Animate texture atlas character (FNF's own
 * format, e.g. assets/shared/images/characters/bf) as an editable rig, WITHOUT redrawing anything:
 *
 *  - every body-part symbol (head, face, body, arm, hand...) becomes a part; its pixels are cut from
 *    the original sprite map, and the other drawings used in the same slot become variants;
 *  - every labelled animation (Idle, Left, Left Miss, ...) becomes an editable keyframed animation
 *    reproducing the original frame by frame, and a representative frame becomes a pose;
 *  - drawings the artist made as one piece (e.g. BF's purple miss frames, the cheer) stay one
 *    "Whole body" part — they cannot be split into limbs automatically.
 */
class AnimateAtlasImport
{
  var anim:Dynamic;
  var symbols:Map<String, Dynamic> = [];
  var sheet:BitmapData;
  var sprites:Map<String, Rectangle> = [];
  var spriteCache:Map<String, BitmapData> = [];
  var topSymbols:Map<String, Bool> = [];

  public var images(default, null):Map<String, {bmp:BitmapData, ox:Float, oy:Float}> = [];

  public function new(animationJson:String, spritemapJson:String, sheet:BitmapData)
  {
    anim = haxe.Json.parse(stripBom(animationJson));
    var sm:Dynamic = haxe.Json.parse(stripBom(spritemapJson));
    this.sheet = sheet;
    for (s in (sm.ATLAS.SPRITES : Array<Dynamic>))
    {
      var sp:Dynamic = s.SPRITE;
      if (sp.rotated == true) throw 'Rotated sprites in the sprite map are not supported yet (${sp.name}).';
      sprites.set(Std.string(sp.name), new Rectangle(sp.x, sp.y, sp.w, sp.h));
    }
    if (anim.SD != null) for (s in (anim.SD.S : Array<Dynamic>))
      symbols.set(s.SN, s);
  }

  static function stripBom(s:String):String
    return s.charCodeAt(0) == 0xFEFF ? s.substr(1) : s;

  static function mx(a:Array<Float>):Affine
    return new Affine(a[0], a[1], a[2], a[3], a[4], a[5]);

  static function symLength(tl:Dynamic):Int
  {
    var n = 1;
    for (l in (tl.L : Array<Dynamic>))
      for (fr in (l.FR : Array<Dynamic>))
        n = Std.int(Math.max(n, fr.I + fr.DU));
    return n;
  }

  /** Labels of the main timeline: name -> {start, length}. */
  public function labels():Array<{name:String, start:Int, length:Int}>
  {
    var out = [];
    for (l in (anim.AN.TL.L : Array<Dynamic>))
      for (fr in (l.FR : Array<Dynamic>))
        if (fr.N != null && fr.N != '') out.push({name: Std.string(fr.N), start: Std.int(fr.I), length: Std.int(fr.DU)});
    return out;
  }

  function spriteBmp(name:String):Null<BitmapData>
  {
    if (spriteCache.exists(name)) return spriteCache.get(name);
    var r = sprites.get(name);
    if (r == null) return null;
    var b = new BitmapData(Std.int(r.width), Std.int(r.height), true, 0);
    b.copyPixels(sheet, r, new Point(0, 0));
    spriteCache.set(name, b);
    return b;
  }

  static function slotOf(name:String):Null<String>
  {
    var n = name.toLowerCase();
    if (n.indexOf('head') >= 0) return 'Head';
    if (n.indexOf('face') >= 0) return 'Face';
    if (n.indexOf('body') >= 0) return 'Body';
    if (n.indexOf('hand') >= 0) return 'Hand';
    if (n.indexOf('arm') >= 0) return 'Arm';
    return null;
  }

  /** Frame of a symbol instance's timeline shown at `elapsed` frames after the instance started. */
  static function childFrame(si:Dynamic, elapsed:Int, len:Int):Int
  {
    var ff:Int = si.FF != null ? Std.int(si.FF) : 0;
    if (si.ST == 'MC' || si.ST == 'movieclip') return 0;
    return switch (si.LP)
    {
      case 'SF': ff;
      case 'PO': Std.int(Math.min(len - 1, ff + elapsed));
      default: (ff + elapsed) % len;
    };
  }

  /** Flatten the leaves of a symbol at a frame (draw order bottom -> top). */
  function flatten(tl:Dynamic, f:Int, parent:Affine, out:Array<Leaf>, isTop:Bool):Void
  {
    var layers:Array<Dynamic> = tl.L;
    var i = layers.length - 1;
    while (i >= 0)
    {
      var l = layers[i--];
      for (fr in (l.FR : Array<Dynamic>))
      {
        if (!(f >= fr.I && f < fr.I + fr.DU)) continue;
        var elapsed = f - Std.int(fr.I);
        for (e in (fr.E : Array<Dynamic>))
        {
          if (e.ASI != null)
          {
            out.push({key: 'sprite ' + e.ASI.N, slot: '?', m: parent.mul(mx(e.ASI.MX))});
            continue;
          }
          var si:Dynamic = e.SI;
          if (si == null) continue;
          var sym = symbols.get(si.SN);
          if (sym == null) continue;
          var m = parent.mul(mx(si.MX));
          var len = symLength(sym.TL);
          var cf = childFrame(si, elapsed, len);
          var slot = slotOf(si.SN);
          if (isTop && slot == null && topSymbols.exists(si.SN))
          {
            flatten(sym.TL, cf, m, out, true);
            continue;
          }
          var key = len > 1 ? '${si.SN}#$cf' : si.SN;
          out.push({key: key, slot: slot ?? 'Whole body', m: m, trp: si.TRP != null ? {x: si.TRP.x, y: si.TRP.y} : null});
        }
      }
    }
  }

  /** Render a leaf symbol (or sprite) into its own image; remembers its origin in symbol space. */
  function leafImage(key:String):Null<{bmp:BitmapData, ox:Float, oy:Float}>
  {
    if (images.exists(key)) return images.get(key);
    var parts:Array<{b:BitmapData, m:Affine}> = [];
    if (key.startsWith('sprite '))
    {
      var b = spriteBmp(key.substr(7));
      if (b != null) parts.push({b: b, m: new Affine()});
    }
    else
    {
      var hash = key.lastIndexOf('#');
      var sn = hash >= 0 ? key.substr(0, hash) : key;
      var f = hash >= 0 ? Std.parseInt(key.substr(hash + 1)) : 0;
      var sym = symbols.get(sn);
      if (sym == null) return null;
      collectSprites(sym.TL, f, new Affine(), parts, 0);
    }
    if (parts.length == 0) return null;
    var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
    for (p in parts)
      for (c in [[0, 0], [p.b.width, 0], [0, p.b.height], [p.b.width, p.b.height]])
      {
        var q = p.m.apply(c[0], c[1]);
        minX = Math.min(minX, q.x);
        minY = Math.min(minY, q.y);
        maxX = Math.max(maxX, q.x);
        maxY = Math.max(maxY, q.y);
      }
    var ox = Math.floor(minX), oy = Math.floor(minY);
    var bmp = new BitmapData(Std.int(Math.ceil(maxX) - ox + 1), Std.int(Math.ceil(maxY) - oy + 1), true, 0);
    for (p in parts)
    {
      var m = new Affine(1, 0, 0, 1, -ox, -oy).mul(p.m);
      bmp.draw(p.b, new Matrix(m.a, m.b, m.c, m.d, m.tx, m.ty), null, null, null, true);
    }
    var r = {bmp: bmp, ox: ox * 1.0, oy: oy * 1.0};
    images.set(key, r);
    return r;
  }

  function collectSprites(tl:Dynamic, f:Int, parent:Affine, out:Array<{b:BitmapData, m:Affine}>, depth:Int):Void
  {
    if (depth > 16) return;
    var layers:Array<Dynamic> = tl.L;
    var i = layers.length - 1;
    while (i >= 0)
    {
      var l = layers[i--];
      for (fr in (l.FR : Array<Dynamic>))
      {
        if (!(f >= fr.I && f < fr.I + fr.DU)) continue;
        for (e in (fr.E : Array<Dynamic>))
        {
          if (e.ASI != null)
          {
            var b = spriteBmp(Std.string(e.ASI.N));
            if (b != null) out.push({b: b, m: parent.mul(mx(e.ASI.MX))});
          }
          else if (e.SI != null)
          {
            var sym = symbols.get(e.SI.SN);
            if (sym != null) collectSprites(sym.TL, childFrame(e.SI, f - Std.int(fr.I), symLength(sym.TL)), parent.mul(mx(e.SI.MX)), out, depth + 1);
          }
        }
      }
    }
  }

  /** Leaves of the main timeline at an absolute frame, with sprite leaves assigned to slots. */
  function frameLeaves(f:Int):Array<Leaf>
  {
    var out:Array<Leaf> = [];
    flatten(anim.AN.TL, f, new Affine(), out, true);
    var hasFace = out.exists(l -> l.slot == 'Face');
    var hasHead = out.exists(l -> l.slot == 'Head');
    for (l in out)
      if (l.slot == '?') l.slot = (hasHead && !hasFace) ? 'Face' : 'Whole body';
    // occurrence index for repeated slots in one frame (e.g. two arms)
    var seen:Map<String, Int> = [];
    for (l in out)
    {
      var n = (seen.get(l.slot) ?? 0) + 1;
      seen.set(l.slot, n);
      if (n > 1) l.slot = '${l.slot} $n';
    }
    return out;
  }

  static final FNF_NAMES:Map<String, String> = [
    'idle' => 'idle', 'left' => 'singLEFT', 'down' => 'singDOWN', 'up' => 'singUP', 'right' => 'singRIGHT', 'left miss' => 'singLEFTmiss',
    'down miss' => 'singDOWNmiss', 'up miss' => 'singUPmiss', 'right miss' => 'singRIGHTmiss', 'hey' => 'hey', 'cheer' => 'cheer', 'scared' => 'scared'
  ];

  static final POSE_FOLDERS:Map<String, String> = [
    'idle' => 'Poses/Idle', 'left' => 'Poses/Sing LEFT', 'down' => 'Poses/Sing DOWN', 'up' => 'Poses/Sing UP', 'right' => 'Poses/Sing RIGHT'
  ];

  /** Build the editable project. */
  public function build(id:String, name:String, renderer:RigRenderer):RigProject
  {
    for (l in (anim.AN.TL.L : Array<Dynamic>))
      for (fr in (l.FR : Array<Dynamic>))
        for (e in (fr.E : Array<Dynamic>))
          if (e.SI != null) topSymbols.set(e.SI.SN, true);
    var labs = labels();
    if (labs.length == 0) throw 'The atlas has no labelled animations.';
    var idleLab = labs.find(l -> l.name.toLowerCase() == 'idle') ?? labs[0];

    // 1. Collect leaves for every frame of every label.
    var frames:Map<Int, Array<Leaf>> = [];
    for (lab in labs)
      for (f in lab.start...lab.start + lab.length)
        frames.set(f, frameLeaves(f));

    // 2. Slots -> parts, ordered by their average draw position.
    var orderSum:Map<String, Float> = [], orderN:Map<String, Int> = [];
    var slotKeys:Map<String, Array<String>> = [];
    var firstLeaf:Map<String, Leaf> = [];
    for (f => leaves in frames)
      for (i in 0...leaves.length)
      {
        var l = leaves[i];
        orderSum.set(l.slot, (orderSum.get(l.slot) ?? 0) + i / Math.max(1, leaves.length - 1));
        orderN.set(l.slot, (orderN.get(l.slot) ?? 0) + 1);
        var ks = slotKeys.get(l.slot) ?? [];
        if (!ks.contains(l.key)) ks.push(l.key);
        slotKeys.set(l.slot, ks);
      }
    for (l in frames.get(idleLab.start))
      firstLeaf.set(l.slot, l);
    var slots = [for (s in orderSum.keys()) s];
    slots.sort((a, b) -> (orderSum.get(a) / orderN.get(a)) < (orderSum.get(b) / orderN.get(b)) ? -1 : 1);

    // Base image per slot: the one used in the idle pose, else the most common.
    var p = RigData.emptyProject(id, name);
    var partOf:Map<String, RigPart> = [];
    for (s in slots)
    {
      var keys = slotKeys.get(s);
      var base = firstLeaf.exists(s) ? firstLeaf.get(s).key : keys[0];
      keys.remove(base);
      keys.unshift(base);
      var imgNames = [];
      for (k in keys)
      {
        var im = leafImage(k);
        if (im == null) continue;
        var file = EditorFiles.safeId(k) + '.png';
        renderer.images.set(file, im.bmp);
        imgNames.push(file);
      }
      if (imgNames.length == 0) continue;
      var baseImg = leafImage(base);
      // Pivot: the animator's transformation point when known, else the image centre.
      var px = baseImg.bmp.width / 2, py = baseImg.bmp.height / 2;
      var fl = firstLeaf.get(s);
      if (fl != null && fl.trp != null)
      {
        var local = fl.m.invert().apply(fl.trp.x, fl.trp.y);
        var cand = {x: local.x - baseImg.ox, y: local.y - baseImg.oy};
        if (cand.x > -baseImg.bmp.width && cand.x < baseImg.bmp.width * 2 && cand.y > -baseImg.bmp.height && cand.y < baseImg.bmp.height * 2)
        {
          px = cand.x;
          py = cand.y;
        }
      }
      var role = switch (s)
      {
        case 'Head': 'head';
        case 'Face': 'face';
        case 'Body': 'body';
        case 'Arm': 'armL';
        case 'Hand': 'armR';
        default: 'other';
      };
      var part:RigPart = {id: RigData.uniqueId(p, s), name: s == 'Hand' ? 'Mic Hand' : s, image: imgNames[0], variants: imgNames.slice(1), pivotX: px, pivotY: py, parent: null, role: role};
      p.parts.push(part);
      partOf.set(s, part);
    }

    // 3. Transform of a leaf for its part (exact: image placed where the original drew it).
    function leafT(part:RigPart, l:Leaf):PartT
    {
      var file = EditorFiles.safeId(l.key) + '.png';
      var v = part.image == file ? 0 : part.variants.indexOf(file) + 1;
      var im = leafImage(l.key);
      var m = l.m.mul(new Affine(1, 0, 0, 1, im.ox, im.oy)).mul(new Affine(1, 0, 0, 1, part.pivotX, part.pivotY));
      var sx = Math.sqrt(m.a * m.a + m.b * m.b);
      var sy = sx == 0 ? 1 : (m.a * m.d - m.b * m.c) / sx;
      return RigData.t(m.tx, m.ty, m.rotation(), sx, sy, 1, v < 0 ? 0 : v);
    }
    function tmAt(f:Int, prev:Null<DynamicAccess<PartT>>):DynamicAccess<PartT>
    {
      var tm = new DynamicAccess<PartT>();
      var leaves = frames.get(f) ?? frameLeaves(f);
      for (s => part in partOf)
      {
        var l = leaves.find(x -> x.slot == s);
        if (l != null) tm.set(part.id, leafT(part, l));
        else
        {
          var last = prev != null ? prev.get(part.id) : null;
          var t = last != null ? RigData.copyT(last) : RigData.t();
          t.a = 0;
          tm.set(part.id, t);
        }
      }
      return tm;
    }

    // 4. Rest pose = idle frame 0; parts not in it are hidden (alpha 0) at their first use.
    var rest = tmAt(idleLab.start, null);
    for (s => part in partOf)
      if (rest.get(part.id).a == 0)
      {
        for (f in frames.keys())
        {
          var l = frames.get(f).find(x -> x.slot == s);
          if (l != null)
          {
            var t = leafT(part, l);
            t.a = 0;
            rest.set(part.id, t);
            break;
          }
        }
      }
    p.rest = rest;

    // 5. Normalise: feet at (0, 0), centred, using the idle pose bounds.
    var b = renderer.bounds(p, rest);
    var dx = -(b.x + b.width / 2), dy = -b.bottom;
    function shift(tm:DynamicAccess<PartT>)
      for (k in tm.keys())
      {
        tm.get(k).x += dx;
        tm.get(k).y += dy;
      }
    shift(p.rest);

    // 6. Animations (keys where values change, plus hold keys before a change) and poses.
    for (lab in labs)
    {
      var fnf = FNF_NAMES.get(lab.name.toLowerCase()) ?? lab.name;
      var folder = lab.name.toLowerCase().indexOf('miss') >= 0 ? 'Animations/Miss' : (fnf.startsWith('sing') ? 'Animations/Sing' : 'Animations');
      var an = RigData.newAnim(lab.name, folder, fnf, lab.length, Std.int(anim.MD?.FRT ?? 24), fnf == 'idle' ? false : false);
      var seq:Array<DynamicAccess<PartT>> = [];
      var prev:Null<DynamicAccess<PartT>> = null;
      for (f in lab.start...lab.start + lab.length)
      {
        var tm = tmAt(f, prev);
        shift(tm);
        seq.push(tm);
        prev = tm;
      }
      for (part in p.parts)
        for (i in 0...seq.length)
        {
          var cur = seq[i].get(part.id);
          var changedFromPrev = i == 0 || !same(cur, seq[i - 1].get(part.id));
          var changesNext = i + 1 < seq.length && !same(cur, seq[i + 1].get(part.id));
          if (changedFromPrev || changesNext) RigData.setKey(an, part.id, i, cur);
        }
      an.length = lab.length;
      p.anims.push(an);

      var low = lab.name.toLowerCase();
      var poseFrame = Std.int(Math.min(seq.length - 1, low == 'idle' ? 0 : 2));
      var folderP = POSE_FOLDERS.get(low) ?? (low.indexOf('miss') >= 0 ? 'Poses/Miss' : 'Poses/Special');
      var poseName = low == 'idle' ? 'Idle' : (low.indexOf('miss') >= 0 ? 'Sing ' + low.replace(' miss', '').toUpperCase() + ' Miss' : (POSE_FOLDERS.exists(low) ? 'Sing ' + lab.name.toUpperCase() : lab.name));
      p.poses.push({name: poseName, folder: folderP, t: seq[poseFrame]});
      if (low == 'idle' && seq.length > 6) p.poses.push({name: 'Dance', folder: 'Poses/Dance', t: seq[Std.int(seq.length / 2)]});
    }
    return p;
  }

  static function same(a:PartT, b:PartT):Bool
    return Math.abs(a.x - b.x) < 0.01 && Math.abs(a.y - b.y) < 0.01 && Math.abs(a.r - b.r) < 0.01 && Math.abs(a.sx - b.sx) < 0.001
      && Math.abs(a.sy - b.sy) < 0.001 && a.a == b.a && a.v == b.v;

  /** Load FNF's Boyfriend from the game assets (through the asset system, so mods can override it). */
  public static function loadBoyfriend(renderer:RigRenderer):RigProject
  {
    var base = 'shared:assets/shared/images/characters/bf/';
    var a = funkin.Assets.getText(base + 'Animation.json');
    var s = funkin.Assets.getText(base + 'spritemap1.json');
    var png = openfl.utils.Assets.getBitmapData(base + 'spritemap1.png', false);
    if (a == null || s == null || png == null) throw 'Boyfriend atlas not found in the game assets.';
    var imp = new AnimateAtlasImport(a, s, png);
    var p = imp.build('bf-studio', 'Boyfriend (FNF example)', renderer);
    p.healthColor = '#31B0D1';
    p.flipX = false;
    RigData.autoRig(p);
    trace('[GOLDEN EDITOR] Boyfriend imported from the game atlas: ${p.parts.length} parts, ${p.poses.length} poses, ${p.anims.length} animations');
    return p;
  }
}
