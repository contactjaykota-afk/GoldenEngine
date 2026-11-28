import golden.editor.anim.RigData;
import golden.editor.anim.RigData.RigProject;

/** Unit tests for the Animation Studio model (golden.editor.anim.RigData). */
class RigTest
{
  static var passed = 0;
  static var failed = 0;

  static function check(name:String, ok:Bool, ?detail:Dynamic)
  {
    if (ok) passed++; else failed++;
    Sys.println((ok ? 'PASS  ' : 'FAIL  ') + name + (ok || detail == null ? '' : ' — ' + Std.string(detail)));
  }

  static function near(a:Float, b:Float, e = 0.01) return Math.abs(a - b) < e;

  static function project():RigProject
  {
    var p = RigData.emptyProject('test', 'Test');
    function add(id:String, name:String, px:Float, py:Float, x:Float, y:Float)
    {
      p.parts.push({id: id, name: name, image: '$id.png', variants: [], pivotX: px, pivotY: py, parent: null, role: RigData.guessRole(name)});
      p.rest.set(id, RigData.t(x, y));
    }
    add('legl', 'Left Leg', 10, 0, -20, -100);
    add('legr', 'Right Leg', 10, 0, 20, -100);
    add('body', 'Body', 40, 80, 0, -100);
    add('arml', 'Left Arm', 8, 0, -45, -170);
    add('handl', 'Left Hand', 8, 0, -45, -110);
    add('armr', 'Right Arm', 8, 0, 45, -170);
    add('head', 'Head', 40, 70, 0, -180);
    add('mouth', 'Mouth', 10, 5, 0, -200);
    p.parts[p.parts.length - 1].variants = ['mouth_open.png'];
    return p;
  }

  static function main()
  {
    check('role: Left Arm', RigData.guessRole('Left Arm') == 'armL');
    check('role: RightShoe.png', RigData.guessRole('RightShoe') == 'shoeR', RigData.guessRole('RightShoe'));
    check('role: Face', RigData.guessRole('Face') == 'face');
    check('role: Hair', RigData.guessRole('Hair') == 'hair');

    var p = project();
    var w0 = RigData.world(p, p.rest).get('handl');
    var n = RigData.autoRig(p);
    check('auto-rig links parts', n >= 5, n);
    check('hand parented to left arm', RigData.part(p, 'handl').parent == 'arml', RigData.part(p, 'handl').parent);
    check('arm parented to body', RigData.part(p, 'arml').parent == 'body');
    check('mouth parented to head', RigData.part(p, 'mouth').parent == 'head');
    check('legs stay unparented', RigData.part(p, 'legl').parent == null);
    var w1 = RigData.world(p, p.rest).get('handl');
    check('re-parenting keeps the hand in place', near(w0.tx, w1.tx) && near(w0.ty, w1.ty), [w0.tx, w0.ty, w1.tx, w1.ty]);

    // rotating the arm moves the hand (hierarchy)
    var tm = RigData.fill(p, p.rest);
    tm.get('arml').r += 90;
    var w2 = RigData.world(p, tm).get('handl');
    check('rotating the arm 90 deg swings the hand around the shoulder', near(w2.tx, -45 - 60) && near(w2.ty, -170), [w2.tx, w2.ty]);

    var made = RigData.generate(p);
    check('generator makes poses and animations', p.poses.length >= 10 && p.anims.length >= 10, made);
    var names = [for (a in p.anims) a.fnfName];
    for (req in ['idle', 'singLEFT', 'singDOWN', 'singUP', 'singRIGHT', 'singLEFTmiss', 'hey'])
      check('animation $req generated', names.contains(req));
    var left = p.poses.filter(x -> x.name == 'Sing LEFT')[0];
    var rest = RigData.fill(p, p.rest);
    check('Left pose raises the screen-left arm', left.t.get('arml').r > rest.get('arml').r + 45, left.t.get('arml').r);
    check('Left pose uses the open-mouth variant', left.t.get('mouth').v == 1);
    var miss = p.poses.filter(x -> x.name == 'Sing LEFT Miss')[0];
    check('miss pose is tinted', miss.t.get('body').c != 0xFFFFFF);

    // non-destructive generation keeps edited poses
    var edited = p.poses.filter(x -> x.name == 'Sing LEFT')[0];
    edited.t.get('arml').r = 123;
    var before = p.poses.length;
    RigData.generate(p, false);
    check('Generate (fill missing) keeps existing poses untouched', p.poses.filter(x -> x.name == 'Sing LEFT')[0].t.get('arml').r == 123 && p.poses.length == before);
    RigData.generate(p, true);
    check('Regenerate (replace) restores generated poses', p.poses.filter(x -> x.name == 'Sing LEFT')[0].t.get('arml').r != 123);

    // interpolation
    var an = RigData.newAnim('t', 'Animations', 't', 10);
    RigData.setKey(an, 'body', 0, RigData.t(0, 0, 0));
    RigData.setKey(an, 'body', 10, RigData.t(100, 0, 90));
    var s = RigData.sample(p, an, 5).get('body');
    check('linear interpolation halfway', near(s.x, 50) && near(s.r, 45), s);
    check('length grows to include keys', an.length == 11);
    check('move key', RigData.moveKey(an, 'body', 10, 12) && RigData.keyAt(an, 'body', 12) != null);
    check('move key refuses collisions', !RigData.moveKey(an, 'body', 0, 12));
    check('remove key', RigData.removeKey(an, 'body', 0) && RigData.keyAt(an, 'body', 0) == null);
    check('untracked part uses rest', near(RigData.sample(p, an, 3).get('head').y, rest.get('head').y));

    // JSON round trip
    var j = RigData.toJson(p);
    var q = RigData.fromJson(j);
    check('JSON round trip keeps parts/poses/anims', q.parts.length == p.parts.length && q.poses.length == p.poses.length && q.anims.length == p.anims.length);
    check('JSON round trip keeps keys', RigData.sortedKeys(q.anims[1], 'arml').length == RigData.sortedKeys(p.anims[1], 'arml').length);
    var bad = try { RigData.fromJson('{"x":1}'); false; } catch (e:Dynamic) true;
    check('invalid project rejected with a message', bad);
    var cyc = RigData.part(p, 'body');
    RigData.setParent(p, 'body', 'handl');
    check('parent cycles refused', cyc.parent == null);

    var inv = golden.editor.anim.RigData.Affine.trs(10, 20, 30, 2, 3);
    var pt = inv.apply(5, 7);
    var back = inv.invert().apply(pt.x, pt.y);
    check('matrix inverse', near(back.x, 5) && near(back.y, 7));

    Sys.println('\n$passed passed, $failed failed');
    Sys.exit(failed == 0 ? 0 : 1);
  }
}
