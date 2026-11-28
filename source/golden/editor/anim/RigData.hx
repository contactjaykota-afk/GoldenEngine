package golden.editor.anim;

import haxe.DynamicAccess;

using StringTools;
using Lambda;

/**
 * Golden Engine Animation Studio — the project model (engine-independent; unit tested).
 *
 * A character is a set of PARTS (one transparent image each, plus optional VARIANT images such as an
 * open mouth or closed eyes). Each part has a pivot (in image pixels) and an optional parent part;
 * a part's transform (x, y, rotation, scale) is relative to its parent's pivot, so rotating an arm also
 * moves its hand. Character space: (0, 0) is between the feet, y grows downwards.
 *
 *  - `rest`   the setup pose (alignment of the imported parts)
 *  - POSES    named full-body transform sets (Idle, Left, Down, ...), editable, shown as thumbnails
 *  - ANIMS    per-part keyframe tracks on a frame timeline (linear interpolation; variant/visibility
 *             switch at the key). An animation exports to one FNF character animation.
 */
typedef PartT =
{
  x:Float,
  y:Float,
  r:Float,
  sx:Float,
  sy:Float,
  a:Float,
  v:Int,
  c:Int
}

typedef RigPart =
{
  id:String,
  name:String,
  image:String,
  variants:Array<String>,
  pivotX:Float,
  pivotY:Float,
  parent:Null<String>,
  role:String
}

typedef RigPose =
{
  name:String,
  folder:String,
  t:DynamicAccess<PartT>
}

typedef RigKey =
{
  f:Int,
  t:PartT,
  /** Tween to the next key: linear (default), quadIn/Out/InOut, cubeIn/Out/InOut, sineIn/Out/InOut,
      backOut, elasticOut, bounceOut, or "hold" (no tween: frame-by-frame step). */
  ?e:String
}

typedef RigAnim =
{
  name:String,
  folder:String,
  fnfName:String,
  fps:Int,
  length:Int,
  loop:Bool,
  tracks:DynamicAccess<Array<RigKey>>
}

typedef RigProject =
{
  version:Int,
  id:String,
  name:String,
  parts:Array<RigPart>,
  rest:DynamicAccess<PartT>,
  poses:Array<RigPose>,
  anims:Array<RigAnim>,
  flipX:Bool,
  scale:Float,
  healthColor:String
}

/** 2D affine matrix [a c tx; b d ty]. */
class Affine
{
  public var a:Float = 1;
  public var b:Float = 0;
  public var c:Float = 0;
  public var d:Float = 1;
  public var tx:Float = 0;
  public var ty:Float = 0;

  public function new(a = 1.0, b = 0.0, c = 0.0, d = 1.0, tx = 0.0, ty = 0.0)
  {
    this.a = a;
    this.b = b;
    this.c = c;
    this.d = d;
    this.tx = tx;
    this.ty = ty;
  }

  /** this * m (apply m first, then this). */
  public function mul(m:Affine):Affine
    return new Affine(a * m.a + c * m.b, b * m.a + d * m.b, a * m.c + c * m.d, b * m.c + d * m.d, a * m.tx + c * m.ty + tx, b * m.tx + d * m.ty + ty);

  public function invert():Affine
  {
    var det = a * d - b * c;
    if (Math.abs(det) < 1e-12) return new Affine();
    var ia = d / det, ib = -b / det, ic = -c / det, id = a / det;
    return new Affine(ia, ib, ic, id, -(ia * tx + ic * ty), -(ib * tx + id * ty));
  }

  public function apply(x:Float, y:Float):{x:Float, y:Float}
    return {x: a * x + c * y + tx, y: b * x + d * y + ty};

  /** Translate * Rotate(deg) * Scale. */
  public static function trs(x:Float, y:Float, rDeg:Float, sx:Float, sy:Float):Affine
  {
    var r = rDeg * Math.PI / 180;
    var cs = Math.cos(r), sn = Math.sin(r);
    return new Affine(cs * sx, sn * sx, -sn * sy, cs * sy, x, y);
  }

  /** Rotation of the x axis in degrees. */
  public function rotation():Float
    return Math.atan2(b, a) * 180 / Math.PI;
}

class RigData
{
  public static inline var VERSION:Int = 1;

  public static function t(x:Float = 0, y:Float = 0, r:Float = 0, sx:Float = 1, sy:Float = 1, a:Float = 1, v:Int = 0, c:Int = 0xFFFFFF):PartT
    return {x: x, y: y, r: r, sx: sx, sy: sy, a: a, v: v, c: c};

  public static function copyT(s:PartT):PartT
    return {x: s.x, y: s.y, r: s.r, sx: s.sx, sy: s.sy, a: s.a, v: s.v, c: s.c};

  public static function emptyProject(id:String, name:String):RigProject
    return {version: VERSION, id: id, name: name, parts: [], rest: new DynamicAccess(), poses: [], anims: [], flipX: false, scale: 1, healthColor: '#FFC83D'};

  public static function part(p:RigProject, id:String):Null<RigPart>
  {
    for (x in p.parts)
      if (x.id == id) return x;
    return null;
  }

  public static function uniqueId(p:RigProject, base:String):String
  {
    var b = ~/[^a-z0-9_]+/g.replace(base.toLowerCase(), '_');
    if (b == '') b = 'part';
    var id = b, n = 2;
    while (part(p, id) != null)
      id = b + '_' + n++;
    return id;
  }

  /** Guess a part's role from its name (used by auto-rig and the pose generator). */
  public static function guessRole(name:String):String
  {
    var n = name.toLowerCase();
    var side = (n.indexOf('left') >= 0 || ~/(^|[^a-z])l([^a-z]|$)/.match(n)) ? 'L' : ((n.indexOf('right') >= 0 || ~/(^|[^a-z])r([^a-z]|$)/.match(n)) ? 'R' : '');
    if (n.indexOf('mouth') >= 0 || n.indexOf('lip') >= 0) return 'mouth';
    if (n.indexOf('eye') >= 0 || n.indexOf('brow') >= 0) return 'eyes';
    if (n.indexOf('face') >= 0) return 'face';
    if (n.indexOf('hair') >= 0 || n.indexOf('hat') >= 0 || n.indexOf('cap') >= 0) return 'hair';
    if (n.indexOf('head') >= 0) return 'head';
    if (n.indexOf('hand') >= 0 || n.indexOf('fist') >= 0 || n.indexOf('mic') >= 0) return 'hand' + side;
    if (n.indexOf('arm') >= 0) return 'arm' + side;
    if (n.indexOf('shoe') >= 0 || n.indexOf('foot') >= 0 || n.indexOf('feet') >= 0 || n.indexOf('boot') >= 0) return 'shoe' + side;
    if (n.indexOf('leg') >= 0 || n.indexOf('pant') >= 0) return 'leg' + side;
    if (n.indexOf('body') >= 0 || n.indexOf('torso') >= 0 || n.indexOf('chest') >= 0 || n.indexOf('shirt') >= 0) return 'body';
    return 'other';
  }

  // ---- transforms ----------------------------------------------------------------------------------

  /** Parts in an order where parents come before children (draw order is `parts` order). */
  static function parentFirst(p:RigProject):Array<RigPart>
  {
    var out:Array<RigPart> = [];
    var seen:Map<String, Bool> = [];
    function visit(x:RigPart, depth:Int)
    {
      if (seen.exists(x.id) || depth > 64) return;
      if (x.parent != null)
      {
        var pp = part(p, x.parent);
        if (pp != null) visit(pp, depth + 1);
      }
      seen.set(x.id, true);
      out.push(x);
    }
    for (x in p.parts)
      visit(x, 0);
    return out;
  }

  /** World matrix of each part's pivot space (image drawn with world * translate(-pivot)). */
  public static function world(p:RigProject, tm:DynamicAccess<PartT>):Map<String, Affine>
  {
    var out:Map<String, Affine> = [];
    for (x in parentFirst(p))
    {
      var tt = tm.get(x.id) ?? p.rest.get(x.id) ?? t();
      var local = Affine.trs(tt.x, tt.y, tt.r, tt.sx, tt.sy);
      var par = x.parent != null ? out.get(x.parent) : null;
      out.set(x.id, par != null ? par.mul(local) : local);
    }
    return out;
  }

  /** Matrix that maps image pixels of a part to character space. */
  public static function imageMatrix(x:RigPart, w:Affine):Affine
    return w.mul(new Affine(1, 0, 0, 1, -x.pivotX, -x.pivotY));

  /** Effective alpha/colour (multiplied down the hierarchy). */
  public static function effectiveAlpha(p:RigProject, tm:DynamicAccess<PartT>, id:String):Float
  {
    var a = 1.0, cur = part(p, id), guard = 0;
    while (cur != null && guard++ < 64)
    {
      var tt = tm.get(cur.id) ?? p.rest.get(cur.id);
      if (tt != null) a *= tt.a;
      cur = cur.parent != null ? part(p, cur.parent) : null;
    }
    return a;
  }

  /**
   * Re-parent a part without moving it on screen: its local transform is recomputed from the
   * world transform in every pose, key and the rest pose.
   */
  public static function setParent(p:RigProject, id:String, parent:Null<String>):Void
  {
    var x = part(p, id);
    if (x == null || parent == id) return;
    // refuse cycles
    var cur = parent != null ? part(p, parent) : null;
    var guard = 0;
    while (cur != null && guard++ < 64)
    {
      if (cur.id == id) return;
      cur = cur.parent != null ? part(p, cur.parent) : null;
    }
    function convert(tm:DynamicAccess<PartT>)
    {
      var full = fill(p, tm);
      var before = world(p, full);
      var old = x.parent;
      x.parent = parent;
      var pw = parent != null ? world(p, full).get(parent) : null;
      x.parent = old;
      var w = before.get(id);
      var local = pw != null ? pw.invert().mul(w) : w;
      var tt = full.get(id);
      var sx = Math.sqrt(local.a * local.a + local.b * local.b);
      var det = local.a * local.d - local.b * local.c;
      var sy = sx == 0 ? 1 : det / sx;
      if (tm.exists(id)) tm.set(id, {x: local.tx, y: local.ty, r: local.rotation(), sx: sx, sy: sy, a: tt.a, v: tt.v, c: tt.c});
    }
    convert(p.rest);
    for (pose in p.poses)
      convert(pose.t);
    for (an in p.anims)
    {
      var keys = an.tracks.get(id);
      if (keys == null) continue;
      for (k in keys)
      {
        var tm = sample(p, an, k.f);
        tm.set(id, k.t);
        convert(tm);
        k.t = tm.get(id);
      }
    }
    x.parent = parent;
  }

  /** A transform map with every part present (rest values for missing ones). */
  public static function fill(p:RigProject, tm:DynamicAccess<PartT>):DynamicAccess<PartT>
  {
    var out = new DynamicAccess<PartT>();
    for (x in p.parts)
      out.set(x.id, copyT(tm.get(x.id) ?? p.rest.get(x.id) ?? t()));
    return out;
  }

  // ---- animation -----------------------------------------------------------------------------------

  static function lerp(a:Float, b:Float, k:Float):Float
    return a + (b - a) * k;

  static function lerpColor(a:Int, b:Int, k:Float):Int
  {
    var r = Std.int(lerp((a >> 16) & 255, (b >> 16) & 255, k));
    var g = Std.int(lerp((a >> 8) & 255, (b >> 8) & 255, k));
    var bl = Std.int(lerp(a & 255, b & 255, k));
    return (r << 16) | (g << 8) | bl;
  }

  public static function lerpT(a:PartT, b:PartT, k:Float):PartT
    return {
      x: lerp(a.x, b.x, k),
      y: lerp(a.y, b.y, k),
      r: lerp(a.r, b.r, k),
      sx: lerp(a.sx, b.sx, k),
      sy: lerp(a.sy, b.sy, k),
      a: lerp(a.a, b.a, k),
      v: k < 1 ? a.v : b.v,
      c: lerpColor(a.c, b.c, k)
    };

  public static final EASES:Array<String> = [
    'linear', 'hold', 'quadIn', 'quadOut', 'quadInOut', 'cubeIn', 'cubeOut', 'cubeInOut', 'sineIn', 'sineOut', 'sineInOut', 'backOut', 'elasticOut', 'bounceOut'
  ];

  /** Easing curve (0..1 -> 0..1). */
  public static function ease(name:Null<String>, t:Float):Float
  {
    return switch (name)
    {
      case 'hold': 0;
      case 'quadIn': t * t;
      case 'quadOut': 1 - (1 - t) * (1 - t);
      case 'quadInOut': t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
      case 'cubeIn': t * t * t;
      case 'cubeOut': 1 - Math.pow(1 - t, 3);
      case 'cubeInOut': t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
      case 'sineIn': 1 - Math.cos(t * Math.PI / 2);
      case 'sineOut': Math.sin(t * Math.PI / 2);
      case 'sineInOut': -(Math.cos(Math.PI * t) - 1) / 2;
      case 'backOut':
        var c1 = 1.70158, c3 = c1 + 1;
        1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
      case 'elasticOut':
        t == 0 ? 0 : (t == 1 ? 1 : Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * (2 * Math.PI / 3)) + 1);
      case 'bounceOut':
        var n1 = 7.5625, d1 = 2.75;
        if (t < 1 / d1) n1 * t * t;
        else if (t < 2 / d1) n1 * (t - 1.5 / d1) * (t - 1.5 / d1) + 0.75;
        else if (t < 2.5 / d1) n1 * (t - 2.25 / d1) * (t - 2.25 / d1) + 0.9375;
        else n1 * (t - 2.625 / d1) * (t - 2.625 / d1) + 0.984375;
      default: t;
    };
  }

  /** Set the tween easing of the key a part has at a frame. */
  public static function setKeyEase(an:RigAnim, id:String, f:Int, e:String):Bool
  {
    var k = keyAt(an, id, f);
    if (k == null) return false;
    k.e = e == 'linear' ? null : e;
    return true;
  }

  public static function sortedKeys(an:RigAnim, id:String):Array<RigKey>
  {
    var k = an.tracks.get(id);
    if (k == null) return [];
    k.sort((x, y) -> x.f - y.f);
    return k;
  }

  /** Transform of every part at a frame. */
  public static function sample(p:RigProject, an:RigAnim, frame:Float):DynamicAccess<PartT>
  {
    var out = new DynamicAccess<PartT>();
    for (x in p.parts)
    {
      var keys = sortedKeys(an, x.id);
      var rest = p.rest.get(x.id) ?? t();
      if (keys.length == 0) out.set(x.id, copyT(rest));
      else if (frame <= keys[0].f) out.set(x.id, copyT(keys[0].t));
      else if (frame >= keys[keys.length - 1].f) out.set(x.id, copyT(keys[keys.length - 1].t));
      else
      {
        var i = 0;
        while (i < keys.length - 1 && keys[i + 1].f <= frame)
          i++;
        var k0 = keys[i], k1 = keys[i + 1];
        out.set(x.id, lerpT(k0.t, k1.t, ease(k0.e, (frame - k0.f) / (k1.f - k0.f))));
      }
    }
    return out;
  }

  public static function keyAt(an:RigAnim, id:String, f:Int):Null<RigKey>
  {
    var keys = an.tracks.get(id);
    if (keys == null) return null;
    for (k in keys)
      if (k.f == f) return k;
    return null;
  }

  public static function setKey(an:RigAnim, id:String, f:Int, tt:PartT):Void
  {
    var keys = an.tracks.get(id);
    if (keys == null)
    {
      keys = [];
      an.tracks.set(id, keys);
    }
    var k = keyAt(an, id, f);
    if (k != null) k.t = copyT(tt);
    else keys.push({f: f, t: copyT(tt)});
    keys.sort((x, y) -> x.f - y.f);
    if (f >= an.length) an.length = f + 1;
  }

  public static function removeKey(an:RigAnim, id:String, f:Int):Bool
  {
    var keys = an.tracks.get(id);
    var k = keyAt(an, id, f);
    if (keys == null || k == null) return false;
    keys.remove(k);
    if (keys.length == 0) an.tracks.remove(id);
    return true;
  }

  /** Move a part's key; refuses to land on an existing key. */
  public static function moveKey(an:RigAnim, id:String, from:Int, to:Int):Bool
  {
    if (to < 0 || from == to) return false;
    var k = keyAt(an, id, from);
    if (k == null || keyAt(an, id, to) != null) return false;
    k.f = to;
    if (to >= an.length) an.length = to + 1;
    sortedKeys(an, id);
    return true;
  }

  /** Put a whole pose (all parts) as keys at a frame. */
  public static function poseToKeys(p:RigProject, an:RigAnim, pose:RigPose, f:Int):Void
  {
    var full = fill(p, pose.t);
    for (x in p.parts)
      setKey(an, x.id, f, full.get(x.id));
  }

  public static function framesWithKeys(an:RigAnim):Array<Int>
  {
    var s:Map<Int, Bool> = [];
    for (id in an.tracks.keys())
      for (k in an.tracks.get(id))
        s.set(k.f, true);
    var out = [for (f in s.keys()) f];
    out.sort((a, b) -> a - b);
    return out;
  }

  public static function newAnim(name:String, folder:String, fnfName:String, length:Int = 8, fps:Int = 24, loop:Bool = false):RigAnim
    return {name: name, folder: folder, fnfName: fnfName, fps: fps, length: length, loop: loop, tracks: new DynamicAccess()};

  public static function cloneProject(p:RigProject):RigProject
    return fromJson(toJson(p));

  public static function toJson(p:RigProject):String
    return haxe.Json.stringify(p, null, ' ');

  /** Parse and validate a project; throws a readable message on bad data. */
  public static function fromJson(s:String):RigProject
  {
    var d:Dynamic = haxe.Json.parse(s);
    if (d == null || d.parts == null || !Std.isOfType(d.parts, Array)) throw 'Not an Animation Studio project (no "parts" list).';
    if (d.version != null && d.version > VERSION) throw 'Project version ${d.version} is newer than this Golden Engine (supports $VERSION).';
    var p:RigProject = d;
    if (p.rest == null) p.rest = new DynamicAccess();
    if (p.poses == null) p.poses = [];
    if (p.anims == null) p.anims = [];
    if (!(Reflect.field(d, 'scale') is Float) || Reflect.field(d, 'scale') <= 0) p.scale = 1;
    if (p.healthColor == null) p.healthColor = '#FFC83D';
    for (x in p.parts)
    {
      if (x.variants == null) x.variants = [];
      if (x.role == null) x.role = guessRole(x.name);
      if (p.rest.get(x.id) == null) p.rest.set(x.id, t());
    }
    for (pose in p.poses)
      if (pose.t == null) pose.t = new DynamicAccess();
    for (an in p.anims)
    {
      if (an.tracks == null) an.tracks = new DynamicAccess();
      var ad:Dynamic = an;
      if (!(ad.fps is Int) || ad.fps <= 0) an.fps = 24;
      if (!(ad.length is Int) || ad.length <= 0) an.length = 1;
      if (an.fnfName == null) an.fnfName = an.name;
    }
    return p;
  }

  // ---- auto-rig and pose generation ----------------------------------------------------------------

  /** Parent rules: role -> list of candidate parent roles. */
  static final PARENTS:Map<String, Array<String>> = [
    'head' => ['body'], 'hair' => ['head'], 'face' => ['head'], 'eyes' => ['face', 'head'], 'mouth' => ['face', 'head'],
    'armL' => ['body'], 'armR' => ['body'], 'arm' => ['body'],
    'handL' => ['armL', 'arm'], 'handR' => ['armR', 'arm'], 'hand' => ['arm', 'armL', 'armR'],
    'shoeL' => ['legL', 'leg'], 'shoeR' => ['legR', 'leg'], 'shoe' => ['leg', 'legL', 'legR']
  ];

  static function byRole(p:RigProject, role:String):Null<RigPart>
  {
    for (x in p.parts)
      if (x.role == role) return x;
    return null;
  }

  /** Parent parts by role (body -> head/arms, arm -> hand, head -> face/eyes/mouth/hair, leg -> shoe). Returns how many were linked. */
  public static function autoRig(p:RigProject):Int
  {
    var n = 0;
    for (x in p.parts)
    {
      if (x.parent != null) continue;
      var cands = PARENTS.get(x.role);
      if (cands == null) continue;
      for (r in cands)
      {
        var par = byRole(p, r);
        // For sided parts without a matching sided parent, pick the nearest candidate.
        if (par != null && par.id != x.id)
        {
          setParent(p, x.id, par.id);
          n++;
          break;
        }
      }
    }
    return n;
  }

  /** World x of a part's pivot in the rest pose. */
  static function restX(p:RigProject, id:String):Float
  {
    var w = world(p, p.rest).get(id);
    return w == null ? 0 : w.tx;
  }

  /** The arm drawn on the screen-left / screen-right side (by position, not by name). */
  static function arms(p:RigProject):{left:Null<RigPart>, right:Null<RigPart>}
  {
    var list = p.parts.filter(x -> x.role.startsWith('arm'));
    if (list.length == 0) return {left: null, right: null};
    list.sort((a, b) -> restX(p, a.id) < restX(p, b.id) ? -1 : 1);
    return {left: list[0], right: list.length > 1 ? list[list.length - 1] : null};
  }

  static function mod(p:RigProject, tm:DynamicAccess<PartT>, part:Null<RigPart>, f:PartT->Void):Void
  {
    if (part == null) return;
    var tt = tm.get(part.id);
    if (tt == null) return;
    f(tt);
  }

  static function openMouth(p:RigProject, tm:DynamicAccess<PartT>):Void
  {
    var m = byRole(p, 'mouth');
    mod(p, tm, m, tt -> if (m.variants.length > 0) tt.v = 1 else tt.sy *= 1.5);
  }

  static function closeEyes(p:RigProject, tm:DynamicAccess<PartT>):Void
  {
    var e = byRole(p, 'eyes');
    mod(p, tm, e, tt -> if (e.variants.length > 0) tt.v = Std.int(Math.min(e.variants.length, 1)) else tt.sy *= 0.25);
  }

  /** Build one named generated pose from the rest pose. */
  public static function generatedPose(p:RigProject, kind:String):DynamicAccess<PartT>
  {
    var tm = fill(p, p.rest);
    var body = byRole(p, 'body');
    var head = byRole(p, 'head');
    var a = arms(p);
    var legs = p.parts.filter(x -> x.role.startsWith('leg'));
    switch (kind)
    {
      case 'idle':
      case 'dance':
        mod(p, tm, body, tt -> { tt.y += 6; tt.sy *= 0.98; });
        mod(p, tm, head, tt -> tt.r += 2);
      case 'left':
        mod(p, tm, body, tt -> { tt.x -= 10; tt.r -= 3; });
        mod(p, tm, head, tt -> { tt.r -= 9; tt.x -= 4; });
        mod(p, tm, a.left, tt -> tt.r += 75);
        mod(p, tm, a.right, tt -> tt.r += 12);
        openMouth(p, tm);
      case 'right':
        mod(p, tm, body, tt -> { tt.x += 10; tt.r += 3; });
        mod(p, tm, head, tt -> { tt.r += 9; tt.x += 4; });
        mod(p, tm, a.right, tt -> tt.r -= 75);
        mod(p, tm, a.left, tt -> tt.r -= 12);
        openMouth(p, tm);
      case 'up':
        mod(p, tm, body, tt -> { tt.y -= 8; tt.sy *= 1.04; });
        mod(p, tm, head, tt -> { tt.y -= 6; tt.r -= 4; });
        mod(p, tm, a.right ?? a.left, tt -> tt.r += (a.right != null ? -155 : 155));
        openMouth(p, tm);
      case 'down':
        mod(p, tm, body, tt -> { tt.y += 16; tt.sy *= 0.94; });
        mod(p, tm, head, tt -> { tt.y += 8; tt.r += 4; });
        mod(p, tm, a.left, tt -> tt.r += 18);
        mod(p, tm, a.right, tt -> tt.r -= 18);
        for (l in legs)
          mod(p, tm, l, tt -> tt.sy *= 0.94);
        openMouth(p, tm);
      case 'dead':
        mod(p, tm, body, tt -> { tt.y += 10; tt.r -= 6; });
        mod(p, tm, head, tt -> { tt.y += 6; tt.r -= 18; });
        mod(p, tm, a.left, tt -> tt.r += 35);
        mod(p, tm, a.right, tt -> tt.r -= 35);
        closeEyes(p, tm);
      case 'hey':
        mod(p, tm, a.left, tt -> tt.r += 150);
        mod(p, tm, a.right, tt -> tt.r -= 150);
        mod(p, tm, head, tt -> tt.y -= 4);
        openMouth(p, tm);
      default:
    }
    return tm;
  }

  /** Purple miss tint + closed eyes applied to a pose. */
  public static function missOf(p:RigProject, src:DynamicAccess<PartT>):DynamicAccess<PartT>
  {
    var tm = fill(p, src);
    for (id in tm.keys())
      tm.get(id).c = 0x8E7DE0;
    closeEyes(p, tm);
    var m = byRole(p, 'mouth');
    mod(p, tm, m, tt -> tt.v = 0);
    return tm;
  }

  static function over(p:RigProject, pose:DynamicAccess<PartT>, k:Float):DynamicAccess<PartT>
  {
    var rest = fill(p, p.rest);
    var out = new DynamicAccess<PartT>();
    for (id in pose.keys())
    {
      var a = rest.get(id) ?? pose.get(id);
      var b = pose.get(id);
      var r = lerpT(a, b, k);
      r.v = b.v;
      r.c = b.c;
      out.set(id, r);
    }
    return out;
  }

  /**
   * Generate editable starting poses and FNF animations from the parts' rest pose.
   * Existing poses/animations with the same names are replaced; others are kept.
   * Returns the names generated. This is a starting point: results depend on how the parts were
   * drawn and rigged, and are meant to be adjusted by hand.
   */
  public static function generate(p:RigProject, replace:Bool = true):Array<String>
  {
    var made = [];
    function putPose(name:String, folder:String, tm:DynamicAccess<PartT>)
    {
      if (!replace && p.poses.exists(x -> x.name == name)) return;
      p.poses = p.poses.filter(x -> !(x.name == name && x.folder == folder));
      p.poses.push({name: name, folder: folder, t: tm});
      made.push('$folder/$name');
    }
    function putAnim(an:RigAnim)
    {
      if (!replace && p.anims.exists(x -> x.fnfName == an.fnfName)) return;
      p.anims = p.anims.filter(x -> x.fnfName != an.fnfName);
      p.anims.push(an);
      made.push('${an.folder}/${an.name}');
    }
    var idle = generatedPose(p, 'idle');
    var dance = generatedPose(p, 'dance');
    putPose('Idle', 'Poses/Idle', idle);
    putPose('Dance', 'Poses/Dance', dance);
    var dirs = [['Left', 'left', 'singLEFT'], ['Down', 'down', 'singDOWN'], ['Up', 'up', 'singUP'], ['Right', 'right', 'singRIGHT']];
    var poseOf:Map<String, DynamicAccess<PartT>> = [];
    for (d in dirs)
    {
      var tm = generatedPose(p, d[1]);
      poseOf.set(d[2], tm);
      var up = d[0].toUpperCase();
      putPose('Sing $up', 'Poses/Sing $up', tm);
      putPose('Sing $up Miss', 'Poses/Miss', missOf(p, tm));
    }
    var hey = generatedPose(p, 'hey');
    putPose('Hey', 'Poses/Special', hey);

    // Animations (24 fps). Idle: bob down and back. Sing: hit with a small overshoot, then hold.
    var an = newAnim('Idle', 'Animations', 'idle', 12);
    for (id in idle.keys())
    {
      setKey(an, id, 0, idle.get(id));
      setKey(an, id, 4, dance.get(id));
      setKey(an, id, 11, idle.get(id));
    }
    putAnim(an);
    for (d in dirs)
    {
      var tm = poseOf.get(d[2]);
      var a1 = newAnim(d[2], 'Animations/Sing', d[2], 8);
      var hit = over(p, tm, 1.15);
      for (id in tm.keys())
      {
        setKey(a1, id, 0, hit.get(id));
        setKey(a1, id, 3, tm.get(id));
        setKey(a1, id, 7, tm.get(id));
      }
      putAnim(a1);
      var miss = missOf(p, tm);
      var a2 = newAnim(d[2] + 'miss', 'Animations/Miss', d[2] + 'miss', 8);
      for (id in miss.keys())
      {
        setKey(a2, id, 0, over(p, miss, 1.1).get(id));
        setKey(a2, id, 7, miss.get(id));
      }
      putAnim(a2);
    }
    var ah = newAnim('hey', 'Animations/Special', 'hey', 12);
    for (id in hey.keys())
    {
      setKey(ah, id, 0, idle.get(id));
      setKey(ah, id, 3, over(p, hey, 1.1).get(id));
      setKey(ah, id, 11, hey.get(id));
    }
    putAnim(ah);

    // Game Over animations (used when this character is the player).
    var dead = generatedPose(p, 'dead');
    putPose('Dead', 'Poses/Special', dead);
    var d1 = newAnim('firstDeath', 'Animations/Death', 'firstDeath', 24);
    var d2 = newAnim('deathLoop', 'Animations/Death', 'deathLoop', 12, 24, true);
    var d3 = newAnim('deathConfirm', 'Animations/Death', 'deathConfirm', 24);
    for (id in dead.keys())
    {
      setKey(d1, id, 0, idle.get(id));
      setKey(d1, id, 8, over(p, dead, 1.2).get(id));
      setKey(d1, id, 23, dead.get(id));
      setKey(d2, id, 0, dead.get(id));
      setKey(d2, id, 6, over(p, dead, 1.06).get(id));
      setKey(d2, id, 11, dead.get(id));
      setKey(d3, id, 0, dead.get(id));
      setKey(d3, id, 5, hey.get(id));
      setKey(d3, id, 23, hey.get(id));
    }
    putAnim(d1);
    putAnim(d2);
    putAnim(d3);
    return made;
  }
}
