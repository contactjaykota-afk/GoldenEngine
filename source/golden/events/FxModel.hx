package golden.events;

using StringTools;
using Lambda;

/**
 * Golden Engine Event System — effect model, catalogue and presets (engine-independent; unit tested).
 *
 * A song's visual edits are a list of timed effects saved in the mod as
 * `data/golden/events/<song id>.json`; gameplay (golden.events.GoldenFxModule) plays them.
 * Times are milliseconds of song time. Camera focus / zoom / bop / character animation / scroll speed
 * effects run through FNF's own song events, so they behave exactly like chart events.
 */
typedef Fx =
{
  id:String,
  type:String,
  track:String,
  time:Float,
  duration:Float,
  ease:String,
  params:Dynamic,
  ?enabled:Bool,
  ?label:String
}

typedef FxTrack =
{
  name:String,
  locked:Bool,
  hidden:Bool
}

typedef FxProject =
{
  version:Int,
  song:String,
  effects:Array<Fx>,
  tracks:Array<FxTrack>
}

typedef FxParam =
{
  name:String,
  kind:String, // number | color | text | choice | bool | image | sound | code
  def:Dynamic,
  ?min:Float,
  ?max:Float,
  ?step:Float,
  ?options:Array<String>
}

typedef FxType =
{
  type:String,
  title:String,
  category:String,
  track:String,
  description:String,
  duration:Float,
  params:Array<FxParam>,
  ?native:String // FNF song event kind used at runtime
}

class FxModel
{
  public static inline var VERSION:Int = 1;

  public static final TRACKS:Array<String> = [
    'Camera', 'Zoom', 'Shake', 'Flash', 'Color', 'Screen FX', 'Overlays', 'Text', 'Characters', 'Note Layout', 'Audio', 'Scripts'
  ];

  public static final EASES:Array<String> = [
    'linear', 'quadOut', 'quadIn', 'quadInOut', 'cubeOut', 'cubeIn', 'cubeInOut', 'sineOut', 'sineIn', 'sineInOut', 'expoOut', 'expoIn', 'backOut',
    'elasticOut', 'bounceOut'
  ];

  static function n(name:String, def:Float, min:Float, max:Float, step:Float = 0.1):FxParam
    return {name: name, kind: 'number', def: def, min: min, max: max, step: step};

  static function c(name:String, def:String):FxParam
    return {name: name, kind: 'color', def: def};

  static function ch(name:String, def:String, options:Array<String>):FxParam
    return {name: name, kind: 'choice', def: def, options: options};

  static function t(name:String, def:String, kind:String = 'text'):FxParam
    return {name: name, kind: kind, def: def};

  static function b(name:String, def:Bool):FxParam
    return {name: name, kind: 'bool', def: def};

  static final CAMS = ['game', 'hud', 'both'];
  static final LAYERS = ['above hud', 'below hud', 'game world'];

  public static final CATALOG:Array<FxType> = [
    // Camera movement
    {type: 'focus', title: 'Camera Focus', category: 'Camera movement', track: 'Camera', description: 'Move the camera to a character or a point (FNF FocusCamera).', duration: 1000,
      params: [ch('target', 'player', ['player', 'opponent', 'girlfriend', 'point']), n('x', 0, -5000, 5000, 10), n('y', 0, -5000, 5000, 10)], native: 'FocusCamera'},
    {type: 'zoom', title: 'Camera Zoom', category: 'Camera movement', track: 'Zoom', description: 'Zoom the game camera in or out (FNF ZoomCamera).', duration: 1000,
      params: [n('zoom', 1.2, 0.1, 5, 0.05)], native: 'ZoomCamera'},
    {type: 'bop', title: 'Camera Bop', category: 'Camera movement', track: 'Zoom', description: 'Camera bop strength/rate (FNF SetCameraBop).', duration: 0,
      params: [n('intensity', 1.5, 0, 10, 0.1), n('rate', 1, 0, 8, 1)], native: 'SetCameraBop'},
    {type: 'rotate', title: 'Camera Rotation / Tilt', category: 'Camera movement', track: 'Camera', description: 'Rotate (tilt) a camera to an angle.', duration: 800,
      params: [n('angle', 8, -180, 180, 1), ch('camera', 'game', CAMS), b('returnAfter', true)]},
    {type: 'drift', title: 'Camera Drift', category: 'Camera movement', track: 'Camera', description: 'Slowly move the camera by an offset and back.', duration: 4000,
      params: [n('x', 60, -1000, 1000, 5), n('y', -30, -1000, 1000, 5)]},
    {type: 'shake', title: 'Camera Shake', category: 'Camera movement', track: 'Shake', description: 'Shake a camera (both axes, horizontal or vertical).', duration: 400,
      params: [n('intensity', 0.02, 0, 0.2, 0.005), ch('axis', 'xy', ['xy', 'x', 'y']), ch('camera', 'game', CAMS)]},
    // Screen effects
    {type: 'flash', title: 'Screen Flash', category: 'Screen effects', track: 'Flash', description: 'Flash the screen (respects the reduced-flashing option).', duration: 500,
      params: [c('color', '#FFFFFF'), n('alpha', 1, 0, 1, 0.05), ch('camera', 'hud', CAMS)]},
    {type: 'fade', title: 'Screen Fade', category: 'Screen effects', track: 'Flash', description: 'Fade to a colour (and optionally back).', duration: 1000,
      params: [c('color', '#000000'), n('alpha', 1, 0, 1, 0.05), b('fadeBack', true), n('hold', 500, 0, 20000, 50)]},
    {type: 'color', title: 'Color Adjust / Grading', category: 'Screen effects', track: 'Color', description: 'Brightness, contrast, saturation, hue, temperature, tint, sepia, invert (tweened).', duration: 1000,
      params: [
        n('brightness', 0, -1, 1, 0.05), n('contrast', 0, -1, 1, 0.05), n('saturation', 0, -1, 1, 0.05), n('hue', 0, -180, 180, 5), n('exposure', 0, -2, 2, 0.1),
        n('temperature', 0, -1, 1, 0.05), c('tint', '#FFFFFF'), n('tintAmount', 0, 0, 1, 0.05), n('sepia', 0, 0, 1, 0.05), n('invert', 0, 0, 1, 0.05),
        ch('camera', 'game', CAMS)
      ]},
    {type: 'vignette', title: 'Vignette / Darkness', category: 'Screen effects', track: 'Screen FX', description: 'Darken the screen edges (or all of it).', duration: 1500,
      params: [n('strength', 0.7, 0, 1, 0.05), c('color', '#000000'), n('size', 0.6, 0.1, 1.5, 0.05)]},
    {type: 'bars', title: 'Cinematic Bars', category: 'Screen effects', track: 'Screen FX', description: 'Letterbox bars slide in for the duration.', duration: 4000,
      params: [n('height', 90, 10, 300, 5), c('color', '#000000')]},
    {type: 'blur', title: 'Blur', category: 'Screen effects', track: 'Screen FX', description: 'Gaussian blur on a camera.', duration: 1500,
      params: [n('amount', 2, 0, 10, 0.25), ch('camera', 'game', CAMS)]},
    {type: 'glitch', title: 'Glitch / RGB Split / VHS', category: 'Screen effects', track: 'Screen FX', description: 'RGB split, scanlines, noise and jitter (Golden shader).', duration: 1000,
      params: [n('rgbSplit', 4, 0, 30, 0.5), n('noise', 0.15, 0, 1, 0.05), n('scanlines', 0.3, 0, 1, 0.05), n('jitter', 2, 0, 30, 0.5), ch('camera', 'game', CAMS)]},
    {type: 'mosaic', title: 'Pixelate / Distortion', category: 'Screen effects', track: 'Screen FX', description: 'Mosaic pixelation on a camera.', duration: 800,
      params: [n('size', 12, 1, 80, 1), ch('camera', 'game', CAMS)]},
    // Overlays and text
    {type: 'image', title: 'Image Overlay', category: 'Images & text', track: 'Overlays', description: 'Show an image (PNG from the mod images folder) with fade, scale and motion.', duration: 2000,
      params: [
        t('image', '', 'image'), n('x', 640, -2000, 4000, 10), n('y', 360, -2000, 4000, 10), n('scale', 1, 0.05, 10, 0.05), n('angle', 0, -360, 360, 5),
        n('alpha', 1, 0, 1, 0.05), n('fadeIn', 150, 0, 5000, 50), n('fadeOut', 300, 0, 5000, 50), n('moveX', 0, -2000, 2000, 10), n('moveY', 0, -2000, 2000, 10),
        n('endScale', 1, 0.05, 10, 0.05), ch('layer', 'above hud', LAYERS)
      ]},
    {type: 'text', title: 'Text', category: 'Images & text', track: 'Text', description: 'Titles, subtitles, background words; fonts, outline, animations.', duration: 3000,
      params: [
        t('text', 'GOLDEN ENGINE'), ch('font', 'vcr', ['vcr', 'vcr-bold', 'pixel', 'quantico', 'gone', 'digital', '5by7']), n('size', 64, 8, 400, 2), c('color', '#FFFFFF'), c('outline', '#000000'),
        n('outlineSize', 4, 0, 20, 1), ch('align', 'center', ['left', 'center', 'right']), n('x', 640, -2000, 4000, 10), n('y', 360, -2000, 4000, 10),
        n('angle', 0, -360, 360, 5), n('alpha', 1, 0, 1, 0.05), n('spacing', 0, -20, 60, 1),
        ch('animIn', 'fade', ['none', 'fade', 'typing', 'bounce', 'scale', 'slide']), ch('animOut', 'fade', ['none', 'fade', 'scale']),
        ch('loop', 'none', ['none', 'shake', 'pulse', 'float', 'scroll']), ch('layer', 'above hud', LAYERS)
      ]},
    {type: 'jumpscare', title: 'Jumpscare', category: 'Images & text', track: 'Overlays', description: 'Image that pops in big with a shake, flash and sound (each part editable).', duration: 900,
      params: [
        t('image', '', 'image'), t('sound', '', 'sound'), n('scale', 1.2, 0.1, 10, 0.05), n('shake', 0.04, 0, 0.2, 0.005), b('flash', true), c('flashColor', '#FFFFFF'),
        n('x', 640, -2000, 4000, 10), n('y', 360, -2000, 4000, 10)
      ]},
    // Characters / gameplay
    {type: 'anim', title: 'Character Animation', category: 'Characters & gameplay', track: 'Characters', description: 'Play an animation on a character (FNF PlayAnimation).', duration: 0,
      params: [ch('target', 'boyfriend', ['boyfriend', 'dad', 'girlfriend']), t('anim', 'hey'), b('force', true)], native: 'PlayAnimation'},
    {type: 'charMove', title: 'Character Move / Fade', category: 'Characters & gameplay', track: 'Characters', description: 'Move, scale or fade a character over time.', duration: 1000,
      params: [ch('target', 'opponent', ['player', 'opponent', 'girlfriend']), n('moveX', 0, -3000, 3000, 10), n('moveY', 0, -3000, 3000, 10), n('alpha', 1, 0, 1, 0.05), n('scale', 1, 0.05, 5, 0.05)]},
    {type: 'layout', title: 'Note Layout', category: 'Characters & gameplay', track: 'Note Layout', description: 'Middle scroll, swap sides, or move the note lanes (notes follow).', duration: 1000,
      params: [ch('layout', 'middle', ['normal', 'middle', 'swap', 'offset']), n('x', 0, -1000, 1000, 10), n('y', 0, -600, 600, 10), n('opponentAlpha', 0.35, 0, 1, 0.05)]},
    {type: 'speed', title: 'Scroll Speed', category: 'Characters & gameplay', track: 'Note Layout', description: 'Change note scroll speed (FNF ScrollSpeed).', duration: 500,
      params: [n('scroll', 1.5, 0.1, 6, 0.1), b('absolute', false)], native: 'ScrollSpeed'},
    // Audio / scripts
    {type: 'sound', title: 'Sound Effect', category: 'Audio & scripts', track: 'Audio', description: 'Play a sound (game sound name or a mod sounds/ file).', duration: 0,
      params: [t('sound', 'confirmMenu', 'sound'), n('volume', 1, 0, 1, 0.05)]},
    {type: 'lua', title: 'Lua Call', category: 'Audio & scripts', track: 'Scripts', description: 'Run a Lua event script (scripts/events/<name>.lua, onEvent) at this time.', duration: 0,
      params: [t('script', ''), t('value', '')], native: 'golden-lua'}
  ];

  public static function typeInfo(type:String):Null<FxType>
    return CATALOG.find(x -> x.type == type);

  public static function emptyProject(song:String):FxProject
    return {version: VERSION, song: song, effects: [], tracks: [for (t in TRACKS) {name: t, locked: false, hidden: false}]};

  static var counter:Int = 0;

  public static function newId():String
    return 'fx' + StringTools.hex(Std.int(Math.random() * 0xFFFFFF), 6) + (counter++);

  /** A new effect of `type` at `time` with default parameters. */
  public static function create(type:String, time:Float):Null<Fx>
  {
    var ti = typeInfo(type);
    if (ti == null) return null;
    var params:Dynamic = {};
    for (p in ti.params)
      Reflect.setField(params, p.name, p.def);
    return {id: newId(), type: type, track: ti.track, time: Math.max(0, time), duration: ti.duration, ease: 'quadOut', params: params, enabled: true};
  }

  public static function clone(f:Fx):Fx
  {
    var c:Fx = haxe.Json.parse(haxe.Json.stringify(f));
    c.id = newId();
    return c;
  }

  public static function toJson(p:FxProject):String
    return haxe.Json.stringify(p, null, '  ');

  /** Parse + validate. Unknown effect types are kept but reported in `problems`. */
  public static function fromJson(s:String, ?problems:Array<String>):FxProject
  {
    var d:Dynamic = haxe.Json.parse(s);
    if (d == null || !Std.isOfType(d.effects, Array)) throw 'Not a Golden events file (no "effects" list).';
    var p:FxProject = d;
    if (p.tracks == null) p.tracks = [];
    for (t in TRACKS)
      if (!p.tracks.exists(x -> x.name == t)) p.tracks.push({name: t, locked: false, hidden: false});
    for (f in p.effects)
    {
      if (f.id == null) f.id = newId();
      if (f.params == null) f.params = {};
      if (f.ease == null) f.ease = 'linear';
      if (f.enabled == null) f.enabled = true;
      var ti = typeInfo(f.type);
      if (ti == null)
      {
        if (problems != null) problems.push('Unknown effect type "${f.type}" at ${Math.round(f.time)} ms');
        continue;
      }
      if (f.track == null) f.track = ti.track;
      for (pp in ti.params)
        if (!Reflect.hasField(f.params, pp.name)) Reflect.setField(f.params, pp.name, pp.def);
    }
    sortEffects(p);
    return p;
  }

  public static function sortEffects(p:FxProject):Void
    p.effects.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));

  /** Effects of the same kind that overlap in time on the same target (would fight over a property). */
  public static function conflicts(p:FxProject):Array<String>
  {
    var out = [];
    var exclusive = ['zoom', 'color', 'rotate', 'layout', 'focus', 'drift', 'blur', 'mosaic', 'glitch'];
    var list = p.effects.filter(f -> f.enabled != false && exclusive.contains(f.type));
    for (i in 0...list.length)
      for (j in i + 1...list.length)
      {
        var a = list[i], b = list[j];
        if (a.type != b.type) continue;
        var camA = Reflect.field(a.params, 'camera'), camB = Reflect.field(b.params, 'camera');
        if (camA != null && camB != null && camA != camB && camA != 'both' && camB != 'both') continue;
        var aEnd = a.time + Math.max(1, a.duration), bEnd = b.time + Math.max(1, b.duration);
        if (a.time < bEnd && b.time < aEnd) out.push('${typeInfo(a.type)?.title ?? a.type} at ${fmtTime(a.time)} overlaps another at ${fmtTime(b.time)}');
      }
    return out;
  }

  public static function fmtTime(ms:Float):String
  {
    var s = Math.floor(ms / 1000);
    var m = Math.floor(s / 60);
    var rest = ms - s * 1000;
    return '$m:' + StringTools.lpad(Std.string(s % 60), '0', 2) + '.' + StringTools.lpad(Std.string(Math.floor(rest)), '0', 3);
  }

  public static function parseColor(s:Dynamic, def:Int = 0xFFFFFF):Int
  {
    if (s == null) return def;
    var str = Std.string(s).trim().replace('#', '').replace('0x', '');
    var v = Std.parseInt('0x' + str);
    return v == null ? def : (v & 0xFFFFFF);
  }

  // ---- colour grading ------------------------------------------------------------------------------

  static function mul(a:Array<Float>, b:Array<Float>):Array<Float>
  {
    // 4x5 colour matrices (row-major, offsets in column 4), result = a * b
    var r = [for (_ in 0...20) 0.0];
    for (row in 0...4)
    {
      for (col in 0...4)
      {
        var sum = 0.0;
        for (k in 0...4)
          sum += a[row * 5 + k] * b[k * 5 + col];
        r[row * 5 + col] = sum;
      }
      var off = a[row * 5 + 4];
      for (k in 0...4)
        off += a[row * 5 + k] * b[k * 5 + 4];
      r[row * 5 + 4] = off;
    }
    return r;
  }

  public static function identity():Array<Float>
    return [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];

  /**
   * openfl ColorMatrixFilter matrix for the colour parameters (offsets in 0..255).
   * brightness -1..1, contrast -1..1, saturation -1..1, hue degrees, exposure stops, temperature -1..1,
   * tint colour + amount, sepia 0..1, invert 0..1.
   */
  public static function colorMatrix(p:Dynamic):Array<Float>
  {
    inline function f(name:String, def:Float = 0):Float
    {
      var v:Dynamic = Reflect.field(p, name);
      return v == null ? def : Std.parseFloat(Std.string(v));
    }
    var m = identity();
    // exposure
    var e = Math.pow(2, f('exposure'));
    if (e != 1) m = mul([e, 0, 0, 0, 0, 0, e, 0, 0, 0, 0, 0, e, 0, 0, 0, 0, 0, 1, 0], m);
    // brightness (offset)
    var br = f('brightness') * 255;
    if (br != 0) m = mul([1, 0, 0, 0, br, 0, 1, 0, 0, br, 0, 0, 1, 0, br, 0, 0, 0, 1, 0], m);
    // contrast around mid grey
    var ct = 1 + f('contrast');
    if (ct != 1)
    {
      var o = 128 * (1 - ct);
      m = mul([ct, 0, 0, 0, o, 0, ct, 0, 0, o, 0, 0, ct, 0, o, 0, 0, 0, 1, 0], m);
    }
    // saturation
    var s = 1 + f('saturation');
    if (s != 1)
    {
      var lr = 0.2126 * (1 - s), lg = 0.7152 * (1 - s), lb = 0.0722 * (1 - s);
      m = mul([lr + s, lg, lb, 0, 0, lr, lg + s, lb, 0, 0, lr, lg, lb + s, 0, 0, 0, 0, 0, 1, 0], m);
    }
    // hue rotation
    var h = f('hue') * Math.PI / 180;
    if (h != 0)
    {
      var cs = Math.cos(h), sn = Math.sin(h);
      var lr = 0.213, lg = 0.715, lb = 0.072;
      m = mul([
        lr + cs * (1 - lr) + sn * (-lr), lg + cs * (-lg) + sn * (-lg), lb + cs * (-lb) + sn * (1 - lb), 0, 0,
        lr + cs * (-lr) + sn * 0.143, lg + cs * (1 - lg) + sn * 0.14, lb + cs * (-lb) + sn * (-0.283), 0, 0,
        lr + cs * (-lr) + sn * (-(1 - lr)), lg + cs * (-lg) + sn * lg, lb + cs * (1 - lb) + sn * lb, 0, 0,
        0, 0, 0, 1, 0
      ], m);
    }
    // temperature: warm = more red, less blue
    var tp = f('temperature');
    if (tp != 0) m = mul([1 + tp * 0.2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1 - tp * 0.2, 0, 0, 0, 0, 0, 1, 0], m);
    // sepia blend
    var sp = f('sepia');
    if (sp > 0)
    {
      var sep = [0.393, 0.769, 0.189, 0, 0, 0.349, 0.686, 0.168, 0, 0, 0.272, 0.534, 0.131, 0, 0, 0, 0, 0, 1, 0];
      var id = identity();
      m = mul([for (i in 0...20) id[i] + (sep[i] - id[i]) * sp], m);
    }
    // tint (multiply toward colour)
    var ta = f('tintAmount');
    if (ta > 0)
    {
      var tc = parseColor(Reflect.field(p, 'tint'));
      var tr = 1 - ta + ta * ((tc >> 16) & 255) / 255, tg = 1 - ta + ta * ((tc >> 8) & 255) / 255, tb = 1 - ta + ta * (tc & 255) / 255;
      m = mul([tr, 0, 0, 0, 0, 0, tg, 0, 0, 0, 0, 0, tb, 0, 0, 0, 0, 0, 1, 0], m);
    }
    // invert blend
    var iv = f('invert');
    if (iv > 0)
    {
      var k = 1 - 2 * iv;
      var o = 255 * iv;
      m = mul([k, 0, 0, 0, o, 0, k, 0, 0, o, 0, 0, k, 0, o, 0, 0, 0, 1, 0], m);
    }
    return m;
  }

  public static function applyMatrix(m:Array<Float>, r:Float, g:Float, b:Float):Array<Float>
    return [
      m[0] * r + m[1] * g + m[2] * b + m[4],
      m[5] * r + m[6] * g + m[7] * b + m[9],
      m[10] * r + m[11] * g + m[12] * b + m[14]
    ];

  /** Colour-grading presets (params for the "color" effect). */
  public static final GRADES:Map<String, Dynamic> = [
    'Dark Horror' => {brightness: -0.25, contrast: 0.3, saturation: -0.5, tint: '#6A2030', tintAmount: 0.25},
    'Cinematic' => {contrast: 0.15, saturation: -0.15, temperature: -0.2, tint: '#2A6070', tintAmount: 0.12},
    'Dreamlike' => {brightness: 0.1, contrast: -0.25, saturation: -0.2, tint: '#F0C0FF', tintAmount: 0.25},
    'VHS' => {contrast: 0.1, saturation: -0.35, hue: -8, tint: '#C0E0FF', tintAmount: 0.15},
    'Retro' => {sepia: 0.7, contrast: 0.1},
    'High Contrast' => {contrast: 0.6, saturation: 0.2},
    'Nighttime' => {brightness: -0.3, saturation: -0.3, temperature: -0.6, tint: '#4060C0', tintAmount: 0.3},
    'Underwater' => {saturation: -0.2, tint: '#30A0C0', tintAmount: 0.45, brightness: -0.05},
    'Black and White' => {saturation: -1},
    'Warm Sunset' => {temperature: 0.7, tint: '#FFB070', tintAmount: 0.25, saturation: 0.1}
  ];

  /**
   * Effect presets: combinations of ordinary (individually editable) effects, times relative to the
   * insertion point.
   */
  public static function preset(name:String, at:Float):Array<Fx>
  {
    var out:Array<Fx> = [];
    function add(type:String, dt:Float, dur:Float, params:Dynamic, ?ease:String)
    {
      var f = create(type, at + dt);
      if (f == null) return;
      f.duration = dur;
      for (k in Reflect.fields(params))
        Reflect.setField(f.params, k, Reflect.field(params, k));
      if (ease != null) f.ease = ease;
      f.label = name;
      out.push(f);
    }
    switch (name)
    {
      case 'Horror Shake':
        add('shake', 0, 1200, {intensity: 0.035, axis: 'xy'});
        add('color', 0, 300, {brightness: -0.2, saturation: -0.6, contrast: 0.3});
        add('vignette', 0, 1500, {strength: 0.8});
      case 'Cinematic Zoom':
        add('bars', 0, 3000, {height: 90});
        add('zoom', 0, 1500, {zoom: 1.25}, 'sineInOut');
      case 'Dramatic Flash':
        add('flash', 0, 700, {color: '#FFFFFF'});
        add('zoom', 0, 300, {zoom: 1.15}, 'expoOut');
        add('shake', 0, 300, {intensity: 0.015});
      case 'Glitch Transition':
        add('glitch', 0, 600, {rgbSplit: 10, noise: 0.4, jitter: 8});
        add('mosaic', 200, 300, {size: 18});
        add('shake', 0, 600, {intensity: 0.01, axis: 'x'});
      case 'VHS Effect':
        add('glitch', 0, 6000, {rgbSplit: 2, noise: 0.25, scanlines: 0.5, jitter: 1});
        add('color', 0, 500, GRADES.get('VHS'));
      case 'Impact Zoom':
        add('zoom', 0, 150, {zoom: 1.35}, 'expoOut');
        add('zoom', 150, 600, {zoom: 1.05}, 'quadOut');
        add('shake', 0, 250, {intensity: 0.03});
      case 'Smooth Camera Focus':
        add('focus', 0, 1500, {target: 'opponent'}, 'sineInOut');
      case 'Sudden Camera Movement':
        add('focus', 0, 120, {target: 'player'}, 'expoOut');
        add('rotate', 0, 200, {angle: -4, returnAfter: true}, 'expoOut');
      case 'Dream Sequence':
        add('color', 0, 1500, GRADES.get('Dreamlike'));
        add('blur', 0, 1500, {amount: 1.5});
        add('vignette', 0, 1500, {strength: 0.4, color: '#FFFFFF'});
      case 'Retro Screen Effect':
        add('color', 0, 500, GRADES.get('Retro'));
        add('mosaic', 0, 500, {size: 3});
      case 'Jumpscare':
        add('jumpscare', 0, 900, {});
      default:
    }
    return out;
  }

  public static final PRESETS:Array<String> = [
    'Horror Shake', 'Cinematic Zoom', 'Dramatic Flash', 'Glitch Transition', 'VHS Effect', 'Impact Zoom', 'Smooth Camera Focus', 'Sudden Camera Movement',
    'Dream Sequence', 'Retro Screen Effect', 'Jumpscare'
  ];

  /** Text style presets (params for the "text" effect). */
  public static final TEXT_STYLES:Map<String, Dynamic> = [
    'Horror Title' => {font: 'vcr', size: 96, color: '#C01020', outline: '#000000', outlineSize: 6, animIn: 'fade', loop: 'shake'},
    'Glowing Neon' => {font: 'vcr', size: 72, color: '#60FFF0', outline: '#FF30C0', outlineSize: 5, animIn: 'scale', loop: 'pulse'},
    'Retro Arcade' => {font: 'pixel', size: 48, color: '#FFE040', outline: '#401060', outlineSize: 4, animIn: 'typing'},
    'Graffiti' => {font: 'gone', size: 120, color: '#FF7AD0', outline: '#1A1030', outlineSize: 8, angle: -8, animIn: 'bounce'},
    'VHS Text' => {font: 'vcr', size: 40, color: '#E0E0E0', outline: '#203080', outlineSize: 2, animIn: 'typing', loop: 'shake'},
    'Cinematic Title' => {font: 'quantico', size: 64, color: '#FFFFFF', outline: '#000000', outlineSize: 0, spacing: 12, animIn: 'fade', animOut: 'fade'},
    'Warning Message' => {font: 'vcr', size: 56, color: '#FFD000', outline: '#000000', outlineSize: 5, animIn: 'slide', loop: 'pulse'},
    'Bold Comic' => {font: 'gone', size: 90, color: '#FFFFFF', outline: '#000000', outlineSize: 8, animIn: 'bounce'},
    'Minimal Subtitles' => {font: 'vcr', size: 28, color: '#FFFFFF', outline: '#000000', outlineSize: 2, y: 640, animIn: 'fade', animOut: 'fade'},
    'Background Word' => {font: 'gone', size: 260, color: '#FFFFFF', alpha: 0.18, outlineSize: 0, layer: 'game world', loop: 'scroll'}
  ];
}
