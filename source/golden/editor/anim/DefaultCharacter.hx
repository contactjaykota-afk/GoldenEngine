package golden.editor.anim;

import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.geom.Matrix;
import golden.editor.anim.RigData;

/**
 * Golden Engine Animation Studio — the built-in example character ("Goldie"), drawn in code (original
 * art, no external assets). It is an ordinary editable project: every part can be changed, replaced or
 * deleted, and a new empty project can be started instead.
 */
class DefaultCharacter
{
  static function bmp(w:Int, h:Int, draw:Shape->Void):BitmapData
  {
    var s = new Shape();
    draw(s);
    var b = new BitmapData(w, h, true, 0);
    b.draw(s, new Matrix(), null, null, null, true);
    return b;
  }

  static inline var OUT:Int = 0x1A1424;
  static inline var SKIN:Int = 0xF2C9A0;
  static inline var GOLD:Int = 0xFFC83D;
  static inline var HOOD:Int = 0x6A3FB5;
  static inline var PANTS:Int = 0x2B2540;

  public static function build(r:RigRenderer):RigProject
  {
    var p = RigData.emptyProject('goldie', 'Goldie (example)');
    var imgs:Map<String, BitmapData> = [];
    imgs.set('leg_l.png', bmp(40, 120, s ->
    {
      s.graphics.lineStyle(4, OUT);
      s.graphics.beginFill(PANTS);
      s.graphics.drawRoundRect(4, 2, 32, 114, 16, 16);
    }));
    imgs.set('leg_r.png', imgs.get('leg_l.png').clone());
    imgs.set('shoe_l.png', bmp(70, 38, s ->
    {
      s.graphics.lineStyle(4, OUT);
      s.graphics.beginFill(0xFFFFFF);
      s.graphics.drawRoundRect(3, 3, 64, 32, 22, 22);
      s.graphics.beginFill(GOLD);
      s.graphics.drawRect(8, 24, 54, 8);
    }));
    imgs.set('shoe_r.png', imgs.get('shoe_l.png').clone());
    imgs.set('body.png', bmp(124, 150, s ->
    {
      s.graphics.lineStyle(4, OUT);
      s.graphics.beginFill(HOOD);
      s.graphics.drawRoundRect(4, 4, 116, 142, 40, 40);
      s.graphics.lineStyle(0, 0, 0);
      s.graphics.beginFill(GOLD);
      s.graphics.drawRect(10, 80, 104, 14);
      s.graphics.beginFill(0xFFFFFF);
      s.graphics.drawCircle(62, 40, 9);
    }));
    imgs.set('arm_l.png', bmp(38, 110, s ->
    {
      s.graphics.lineStyle(4, OUT);
      s.graphics.beginFill(HOOD);
      s.graphics.drawRoundRect(4, 2, 30, 104, 22, 22);
    }));
    imgs.set('arm_r.png', imgs.get('arm_l.png').clone());
    imgs.set('hand_l.png', bmp(40, 40, s ->
    {
      s.graphics.lineStyle(4, OUT);
      s.graphics.beginFill(SKIN);
      s.graphics.drawCircle(20, 20, 16);
    }));
    imgs.set('hand_r.png', imgs.get('hand_l.png').clone());
    imgs.set('head.png', bmp(150, 140, s ->
    {
      s.graphics.lineStyle(4, OUT);
      s.graphics.beginFill(SKIN);
      s.graphics.drawEllipse(5, 5, 140, 130);
    }));
    imgs.set('hair.png', bmp(170, 90, s ->
    {
      s.graphics.lineStyle(4, OUT);
      s.graphics.beginFill(GOLD);
      s.graphics.moveTo(6, 84);
      s.graphics.lineTo(20, 30);
      s.graphics.lineTo(38, 52);
      s.graphics.lineTo(55, 6);
      s.graphics.lineTo(80, 44);
      s.graphics.lineTo(102, 4);
      s.graphics.lineTo(120, 46);
      s.graphics.lineTo(146, 18);
      s.graphics.lineTo(150, 58);
      s.graphics.lineTo(166, 84);
      s.graphics.curveTo(86, 50, 6, 84);
    }));
    imgs.set('eyes_open.png', bmp(90, 40, s ->
    {
      s.graphics.lineStyle(3, OUT);
      s.graphics.beginFill(0xFFFFFF);
      s.graphics.drawEllipse(4, 4, 32, 32);
      s.graphics.drawEllipse(54, 4, 32, 32);
      s.graphics.lineStyle(0, 0, 0);
      s.graphics.beginFill(OUT);
      s.graphics.drawCircle(24, 22, 8);
      s.graphics.drawCircle(74, 22, 8);
    }));
    imgs.set('eyes_closed.png', bmp(90, 40, s ->
    {
      s.graphics.lineStyle(5, OUT);
      s.graphics.moveTo(6, 22);
      s.graphics.curveTo(20, 30, 34, 22);
      s.graphics.moveTo(56, 22);
      s.graphics.curveTo(70, 30, 84, 22);
    }));
    imgs.set('mouth_closed.png', bmp(50, 30, s ->
    {
      s.graphics.lineStyle(5, OUT);
      s.graphics.moveTo(6, 10);
      s.graphics.curveTo(25, 26, 44, 10);
    }));
    imgs.set('mouth_open.png', bmp(50, 30, s ->
    {
      s.graphics.lineStyle(4, OUT);
      s.graphics.beginFill(0x8C1E3C);
      s.graphics.drawEllipse(6, 2, 38, 26);
    }));
    for (k in imgs.keys())
      r.images.set(k, imgs.get(k));

    // Parts in draw order (bottom to top), positions = pivot in character space (feet at y = 0).
    function add(id:String, name:String, image:String, px:Float, py:Float, x:Float, y:Float, ?variants:Array<String>)
    {
      p.parts.push({id: id, name: name, image: image, variants: variants ?? [], pivotX: px, pivotY: py, parent: null, role: RigData.guessRole(name)});
      p.rest.set(id, RigData.t(x, y));
    }
    add('arm_r', 'Right Arm', 'arm_r.png', 19, 12, 50, -252);
    add('hand_r', 'Right Hand', 'hand_r.png', 20, 20, 50, -160);
    add('leg_l', 'Left Leg', 'leg_l.png', 20, 8, -24, -150);
    add('leg_r', 'Right Leg', 'leg_r.png', 20, 8, 24, -150);
    add('shoe_l', 'Left Shoe', 'shoe_l.png', 45, 30, -30, -4);
    add('shoe_r', 'Right Shoe', 'shoe_r.png', 25, 30, 30, -4);
    add('body', 'Body', 'body.png', 62, 140, 0, -140);
    add('head', 'Head', 'head.png', 75, 128, 0, -262);
    add('hair', 'Hair', 'hair.png', 85, 60, 0, -360);
    add('eyes', 'Eyes', 'eyes_open.png', 45, 20, 4, -330, ['eyes_closed.png']);
    add('mouth', 'Mouth', 'mouth_closed.png', 25, 15, 4, -290, ['mouth_open.png']);
    add('arm_l', 'Left Arm', 'arm_l.png', 19, 12, -50, -252);
    add('hand_l', 'Left Hand', 'hand_l.png', 20, 20, -50, -160);
    RigData.autoRig(p);
    RigData.generate(p);
    return p;
  }
}
