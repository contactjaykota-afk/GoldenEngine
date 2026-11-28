package golden.editor.anim;

import haxe.DynamicAccess;
import openfl.display.BitmapData;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import golden.editor.anim.RigData;

/**
 * Golden Engine Animation Studio — draws a rig with real image transforms (the same code path is used
 * for the workspace, thumbnails and the exported sprite sheet, so what you see is what you export).
 */
class RigRenderer
{
  /** Part images by file name (as referenced by RigPart.image / variants). */
  public var images:Map<String, BitmapData> = [];

  public function new() {}

  public function imageFor(x:RigPart, v:Int):Null<BitmapData>
  {
    if (v > 0 && v <= x.variants.length)
    {
      var b = images.get(x.variants[v - 1]);
      if (b != null) return b;
    }
    return images.get(x.image);
  }

  static function toMatrix(a:Affine):Matrix
    return new Matrix(a.a, a.b, a.c, a.d, a.tx, a.ty);

  /**
   * Draw the character into `target`. `view` maps character space to target pixels.
   * `only`: draw just these parts (and nothing else); `alpha`: overall opacity (onion skin);
   * `hidden`: parts not drawn (layer visibility in the editor).
   */
  public function draw(p:RigProject, tm:DynamicAccess<PartT>, target:BitmapData, view:Affine, alpha:Float = 1, ?hidden:Map<String, Bool>,
      ?only:Array<String>, ?tint:Null<Int>):Void
  {
    var full = RigData.fill(p, tm);
    var w = RigData.world(p, full);
    for (x in p.parts)
    {
      if (hidden != null && hidden.exists(x.id)) continue;
      if (only != null && !only.contains(x.id)) continue;
      var tt = full.get(x.id);
      var a = RigData.effectiveAlpha(p, full, x.id) * alpha;
      if (a <= 0.001) continue;
      var img = imageFor(x, tt.v);
      if (img == null) continue;
      var m = view.mul(RigData.imageMatrix(x, w.get(x.id)));
      var c = tint ?? tt.c;
      var ct = new ColorTransform(((c >> 16) & 255) / 255, ((c >> 8) & 255) / 255, (c & 255) / 255, a);
      target.draw(img, toMatrix(m), ct, null, null, true);
    }
  }

  /** Bounding box (character space) of the drawn parts. */
  public function bounds(p:RigProject, tm:DynamicAccess<PartT>, ?only:Array<String>):Rectangle
  {
    var full = RigData.fill(p, tm);
    var w = RigData.world(p, full);
    var minX = Math.POSITIVE_INFINITY, minY = Math.POSITIVE_INFINITY, maxX = Math.NEGATIVE_INFINITY, maxY = Math.NEGATIVE_INFINITY;
    for (x in p.parts)
    {
      if (only != null && !only.contains(x.id)) continue;
      var tt = full.get(x.id);
      if (RigData.effectiveAlpha(p, full, x.id) <= 0.001) continue;
      var img = imageFor(x, tt.v);
      if (img == null) continue;
      var m = RigData.imageMatrix(x, w.get(x.id));
      for (c in [[0, 0], [img.width, 0], [0, img.height], [img.width, img.height]])
      {
        var q = m.apply(c[0], c[1]);
        minX = Math.min(minX, q.x);
        minY = Math.min(minY, q.y);
        maxX = Math.max(maxX, q.x);
        maxY = Math.max(maxY, q.y);
      }
    }
    if (minX == Math.POSITIVE_INFINITY) return new Rectangle(-50, -100, 100, 100);
    return new Rectangle(minX, minY, maxX - minX, maxY - minY);
  }

  /** A square thumbnail of a pose. */
  public function thumbnail(p:RigProject, tm:DynamicAccess<PartT>, size:Int, bg:Int = 0xFF2A2633, ?only:Array<String>):BitmapData
  {
    var b = bounds(p, tm, only);
    var bmp = new BitmapData(size, size, true, bg);
    var s = Math.min((size - 6) / Math.max(1, b.width), (size - 6) / Math.max(1, b.height));
    var view = new Affine(s, 0, 0, s, size / 2 - (b.x + b.width / 2) * s, size / 2 - (b.y + b.height / 2) * s);
    draw(p, tm, bmp, view, 1, null, only);
    return bmp;
  }

  /** Topmost part under a character-space point (transparent pixels do not count). */
  public function hitTest(p:RigProject, tm:DynamicAccess<PartT>, cx:Float, cy:Float, ?hidden:Map<String, Bool>):Null<String>
  {
    var full = RigData.fill(p, tm);
    var w = RigData.world(p, full);
    var i = p.parts.length - 1;
    while (i >= 0)
    {
      var x = p.parts[i--];
      if (hidden != null && hidden.exists(x.id)) continue;
      var tt = full.get(x.id);
      if (RigData.effectiveAlpha(p, full, x.id) <= 0.05) continue;
      var img = imageFor(x, tt.v);
      if (img == null) continue;
      var q = RigData.imageMatrix(x, w.get(x.id)).invert().apply(cx, cy);
      var px = Std.int(q.x), py = Std.int(q.y);
      if (px < 0 || py < 0 || px >= img.width || py >= img.height) continue;
      if (((img.getPixel32(px, py) >> 24) & 255) > 24) return x.id;
    }
    return null;
  }

  /** Opaque bounds of an image (for default pivots). */
  public static function opaqueBounds(img:BitmapData):Rectangle
  {
    var r = img.getColorBoundsRect(0xFF000000, 0x00000000, false);
    if (r.width <= 0 || r.height <= 0) return new Rectangle(0, 0, img.width, img.height);
    return r;
  }
}
