package golden.events;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.filters.BitmapFilter;
import openfl.filters.ColorMatrixFilter;
import openfl.filters.ShaderFilter;
import openfl.geom.Matrix;
import golden.events.FxModel;

/** What an effect can act on. Implemented by gameplay (PlayState) and by the Event System preview. */
interface FxHost
{
  function gameCam():FlxCamera;
  function hudCam():FlxCamera;
  /** A camera drawn above the HUD (created on demand). */
  function topCam():FlxCamera;
  /** Add a world-space sprite behind the characters (background words, props). */
  function addBehindCharacters(s:FlxSprite):Void;
  function addSprite(s:FlxBasic):Void;
  function removeSprite(s:FlxBasic):Void;
  function character(target:String):Null<FlxSprite>;
  function playerStrums():Null<FlxSpriteGroup>;
  function opponentStrums():Null<FlxSpriteGroup>;
  /** Run an FNF song event (FocusCamera, ZoomCamera, ...). */
  function runNative(kind:String, value:Dynamic, time:Float):Void;
  /** Milliseconds per step (for native events that take steps). */
  function stepMs():Float;
}

/** RGB split / noise / scanlines / jitter (Golden Engine shader). */
class GoldenGlitchShader extends flixel.addons.display.FlxRuntimeShader
{
  public function new()
  {
    super('
      #pragma header
      uniform float uRgb;
      uniform float uNoise;
      uniform float uScan;
      uniform float uJitter;
      uniform float uTime;
      float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }
      void main() {
        vec2 uv = openfl_TextureCoordv;
        vec2 px = 1.0 / openfl_TextureSize;
        float line = floor(uv.y * openfl_TextureSize.y / 6.0);
        float big = step(0.92, rand(vec2(line, floor(uTime * 12.0))));
        uv.x += (rand(vec2(line, floor(uTime * 30.0))) - 0.5) * uJitter * px.x * (0.4 + big * 6.0);
        vec4 c = flixel_texture2D(bitmap, uv);
        vec4 cr = flixel_texture2D(bitmap, uv + vec2(uRgb * px.x, 0.0));
        vec4 cb = flixel_texture2D(bitmap, uv - vec2(uRgb * px.x, 0.0));
        c.r = cr.r;
        c.b = cb.b;
        float n = rand(uv * openfl_TextureSize + vec2(uTime * 60.0, 0.0)) - 0.5;
        c.rgb += n * uNoise * c.a;
        c.rgb *= 1.0 - uScan * 0.5 * (0.5 + 0.5 * sin(uv.y * openfl_TextureSize.y * 3.14159));
        gl_FragColor = c;
      }
    ');
    setFloat('uRgb', 0);
    setFloat('uNoise', 0);
    setFloat('uScan', 0);
    setFloat('uJitter', 0);
    setFloat('uTime', 0);
  }
}

/**
 * Golden Engine Event System — plays a song's effect list on an FxHost.
 * Driven by song time (`update(songMs, elapsed)`); effects fire once when their time is reached.
 * Uses its own tween manager so effects pause with the game. `reset()` removes every trace of them.
 */
class FxRuntime
{
  public var project(default, null):FxProject;
  public var host:FxHost;

  var tweens:flixel.tweens.FlxTween.FlxTweenManager;
  var fired:Map<String, Bool> = [];
  var sprites:Array<FlxBasic> = [];
  var camFilters:Map<FlxCamera, Map<String, BitmapFilter>> = [];
  var baseFilters:Map<FlxCamera, Array<BitmapFilter>> = [];
  var colorState:Map<FlxCamera, Dynamic> = [];
  var glitchShaders:Array<GoldenGlitchShader> = [];
  var strumHome:Null<{px:Float, py:Float, ox:Float, oy:Float}> = null;
  var charHome:Map<FlxSprite, {x:Float, y:Float, a:Float, sx:Float, sy:Float}> = [];
  var time:Float = 0;
  var lastSong:Float = -1;

  /** Effects that ran (for logs and tests). */
  public var log:Array<String> = [];

  public function new(project:FxProject, host:FxHost)
  {
    this.project = project;
    this.host = host;
    tweens = new flixel.tweens.FlxTween.FlxTweenManager();
  }

  /** Mark everything before `songMs` as done without running it (e.g. a song started mid-way). */
  public function skipTo(songMs:Float):Void
  {
    for (f in project.effects)
      if (f.time + Math.max(0, f.duration) < songMs) fired.set(f.id, true);
    lastSong = songMs;
  }

  public function update(songMs:Float, elapsed:Float):Void
  {
    time += elapsed;
    for (g in glitchShaders)
      g.setFloat('uTime', time);
    tweens.update(elapsed);
    for (f in project.effects)
    {
      if (f.enabled == false || fired.exists(f.id)) continue;
      if (f.time <= songMs)
      {
        fired.set(f.id, true);
        try
        {
          fire(f);
        }
        catch (e:Dynamic)
        {
          trace('[GOLDEN FX] Effect ${f.type} at ${Math.round(f.time)} ms failed: $e');
        }
      }
    }
    lastSong = songMs;
  }

  public function reset():Void
  {
    tweens.clear();
    for (s in sprites)
    {
      host.removeSprite(s);
      s.destroy();
    }
    sprites = [];
    for (cam in camFilters.keys())
    {
      if (cam != null && cam.exists && cam.flashSprite != null) cam.filters = baseFilters.get(cam);
    }
    camFilters = [];
    baseFilters = [];
    colorState = [];
    colorOverlays = [];
    glitchShaders = [];
    var g = host.gameCam(), h = host.hudCam();
    // (cameras may already be destroyed when the state is leaving)
    if (g != null && g.exists && g.flashSprite != null) g.angle = 0;
    if (h != null && h.exists && h.flashSprite != null) h.angle = 0;
    restoreStrums();
    for (c => home in charHome)
      if (c != null && c.exists)
      {
        c.x = home.x;
        c.y = home.y;
        c.alpha = home.a;
        c.scale.set(home.sx, home.sy);
      }
    charHome = [];
    fired = [];
    log = [];
  }

  // ---- helpers -------------------------------------------------------------------------------------

  static function ease(name:String):Float->Float
  {
    var e:Null<Float->Float> = Reflect.field(FlxEase, name ?? 'linear');
    return e ?? FlxEase.linear;
  }

  /** FNF event ease names: "quadOut" -> ease "quad", dir "Out". */
  static function nativeEase(name:String):{ease:String, dir:String}
  {
    var r = ~/^([a-z]+)(In|Out|InOut)$/;
    if (name == null || name == 'linear') return {ease: 'linear', dir: ''};
    if (r.match(name)) return {ease: r.matched(1), dir: r.matched(2)};
    return {ease: name, dir: 'Out'};
  }

  static inline function num(p:Dynamic, n:String, def:Float = 0):Float
  {
    var v:Dynamic = Reflect.field(p, n);
    return v == null ? def : Std.parseFloat(Std.string(v));
  }

  static inline function str(p:Dynamic, n:String, def:String = ''):String
  {
    var v:Dynamic = Reflect.field(p, n);
    return v == null ? def : Std.string(v);
  }

  function cams(which:String):Array<FlxCamera>
  {
    var out = [];
    if (which == 'game' || which == 'both') out.push(host.gameCam());
    if (which == 'hud' || which == 'both') out.push(host.hudCam());
    return out.filter(c -> c != null);
  }

  function setFilter(cam:FlxCamera, slot:String, f:Null<BitmapFilter>):Void
  {
    if (cam == null) return;
    if (!camFilters.exists(cam))
    {
      camFilters.set(cam, []);
      baseFilters.set(cam, cam.filters != null ? cam.filters.copy() : []);
    }
    var m = camFilters.get(cam);
    if (f == null) m.remove(slot) else m.set(slot, f);
    var list:Array<BitmapFilter> = baseFilters.get(cam).copy();
    for (k in ['color', 'blur', 'mosaic', 'glitch'])
      if (m.exists(k)) list.push(m.get(k));
    cam.filters = list;
  }

  function track(s:FlxBasic):FlxBasic
  {
    sprites.push(s);
    return s;
  }

  function layerCam(layer:String):FlxCamera
    return layer == 'below hud' ? host.gameCam() : host.topCam();

  public static function fontPath(f:String):String
  {
    return switch (f)
    {
      case 'vcr-bold': Paths.font('vcr-bold.ttf');
      case 'pixel': Paths.font('pixel.otf');
      case 'quantico': Paths.font('Quantico-Bold.ttf');
      case 'gone': Paths.font('YoureGone-Regular.otf');
      case 'digital': Paths.font('DS-DIGIB.TTF');
      case '5by7': Paths.font('5by7_b.ttf');
      default: Paths.font('vcr.ttf');
    };
  }

  // ---- effects -------------------------------------------------------------------------------------

  function fire(f:Fx):Void
  {
    var p = f.params;
    var dur = Math.max(0, f.duration) / 1000;
    log.push('${f.type}@${Math.round(f.time)}');
    trace('[GOLDEN FX] ${f.type} at ${Math.round(f.time)} ms (${Math.round(f.duration)} ms)');
    switch (f.type)
    {
      case 'focus':
        var tgt = str(p, 'target', 'player');
        var e = nativeEase(f.ease);
        var steps = f.duration / Math.max(1, host.stepMs());
        host.runNative('FocusCamera', {
          char: switch (tgt) { case 'player': 0; case 'opponent': 1; case 'girlfriend': 2; default: -1; },
          x: num(p, 'x'), y: num(p, 'y'), duration: steps, ease: f.duration <= 0 ? 'INSTANT' : e.ease, easeDir: e.dir
        }, f.time);
      case 'zoom':
        var e = nativeEase(f.ease);
        host.runNative('ZoomCamera', {zoom: num(p, 'zoom', 1), duration: f.duration / Math.max(1, host.stepMs()), ease: f.duration <= 0 ? 'INSTANT' : e.ease, easeDir: e.dir, mode: 'direct'}, f.time);
      case 'bop':
        host.runNative('SetCameraBop', {intensity: num(p, 'intensity', 1), rate: Std.int(num(p, 'rate', 1))}, f.time);
      case 'anim':
        host.runNative('PlayAnimation', {target: str(p, 'target', 'boyfriend'), anim: str(p, 'anim', 'hey'), force: Reflect.field(p, 'force') != false}, f.time);
      case 'speed':
        var e = nativeEase(f.ease);
        host.runNative('ScrollSpeed', {scroll: num(p, 'scroll', 1), duration: f.duration / Math.max(1, host.stepMs()), ease: e.ease, easeDir: e.dir, absolute: Reflect.field(p, 'absolute') == true}, f.time);
      case 'lua':
        host.runNative('golden-lua', {script: str(p, 'script'), value: str(p, 'value')}, f.time);
      case 'shake':
        var axis = switch (str(p, 'axis', 'xy')) { case 'x': flixel.util.FlxAxes.X; case 'y': flixel.util.FlxAxes.Y; default: flixel.util.FlxAxes.XY; };
        for (c in cams(str(p, 'camera', 'game')))
          c.shake(num(p, 'intensity', 0.02), Math.max(0.05, dur), null, true, axis);
      case 'flash':
        var col = FxModel.parseColor(Reflect.field(p, 'color'), 0xFFFFFF);
        var a = num(p, 'alpha', 1);
        if (!Preferences.flashingLights) a *= 0.25; // reduced flashing: a gentle fade instead
        for (c in cams(str(p, 'camera', 'hud')))
          c.flash(FlxColor.fromRGB((col >> 16) & 255, (col >> 8) & 255, col & 255, Std.int(255 * a)), Math.max(0.05, dur), null, true);
      case 'fade':
        var col = FxModel.parseColor(Reflect.field(p, 'color'), 0);
        var s = screenRect(col, host.topCam());
        s.alpha = 0;
        var target = num(p, 'alpha', 1);
        var back = Reflect.field(p, 'fadeBack') != false;
        var hold = num(p, 'hold', 500) / 1000;
        tweens.tween(s, {alpha: target}, Math.max(0.01, dur), {ease: ease(f.ease), onComplete: _ -> if (back) tweens.tween(s, {alpha: 0}, Math.max(0.01, dur), {startDelay: hold})});
      case 'color':
        for (c in cams(str(p, 'camera', 'game')))
          if (GoldenSettings.shaderEffectsEnabled()) tweenColor(c, p, dur, ease(f.ease)) else colorFallback(c, p, dur, ease(f.ease));
      case 'blur' | 'mosaic' | 'glitch' if (!GoldenSettings.shaderEffectsEnabled()):
        trace('[GOLDEN FX] ${f.type} skipped: screen shader effects are off (Options > Golden Engine > Screen Shaders, or a software renderer)');
      case 'blur':
        for (c in cams(str(p, 'camera', 'game')))
        {
          var sh = new funkin.graphics.shaders.GaussianBlurShader(0);
          setFilter(c, 'blur', new ShaderFilter(sh));
          var amt = num(p, 'amount', 2);
          tweens.num(0, amt, Math.min(0.3, dur / 3), {}, v -> sh.setAmount(v));
          tweens.num(amt, 0, Math.min(0.3, dur / 3), {startDelay: dur * 2 / 3, onComplete: _ -> setFilter(c, 'blur', null)}, v -> sh.setAmount(v));
        }
      case 'mosaic':
        for (c in cams(str(p, 'camera', 'game')))
        {
          var sh = new funkin.graphics.shaders.MosaicEffect();
          setFilter(c, 'mosaic', new ShaderFilter(sh));
          var size = num(p, 'size', 12);
          tweens.num(size, 1, Math.max(0.05, dur), {ease: ease(f.ease), onComplete: _ -> setFilter(c, 'mosaic', null)}, v -> sh.setBlockSize(v, v));
        }
      case 'glitch':
        for (c in cams(str(p, 'camera', 'game')))
        {
          var sh = new GoldenGlitchShader();
          glitchShaders.push(sh);
          setFilter(c, 'glitch', new ShaderFilter(sh));
          var target = {rgb: num(p, 'rgbSplit', 4), noise: num(p, 'noise', 0.15), scan: num(p, 'scanlines', 0.3), jitter: num(p, 'jitter', 2)};
          sh.setFloat('uRgb', target.rgb);
          sh.setFloat('uNoise', target.noise);
          sh.setFloat('uScan', target.scan);
          sh.setFloat('uJitter', target.jitter);
          tweens.num(0, 1, Math.max(0.05, dur), {onComplete: _ ->
          {
            setFilter(c, 'glitch', null);
            glitchShaders.remove(sh);
          }}, _ -> {});
        }
      case 'vignette':
        var col = FxModel.parseColor(Reflect.field(p, 'color'), 0);
        var s = vignette(col, num(p, 'size', 0.6));
        var strength = num(p, 'strength', 0.7);
        s.alpha = 0;
        tweens.tween(s, {alpha: strength}, Math.min(0.4, dur / 3), {ease: ease(f.ease)});
        tweens.tween(s, {alpha: 0}, Math.min(0.4, dur / 3), {startDelay: dur * 2 / 3});
      case 'bars':
        var h = Std.int(num(p, 'height', 90));
        var col = FxModel.parseColor(Reflect.field(p, 'color'), 0);
        var top = screenRect(col, host.topCam(), FlxG.width, h);
        var bot = screenRect(col, host.topCam(), FlxG.width, h);
        top.y = -h;
        bot.y = FlxG.height;
        var inT = Math.min(0.5, dur / 4);
        tweens.tween(top, {y: 0}, inT, {ease: FlxEase.quadOut});
        tweens.tween(bot, {y: FlxG.height - h}, inT, {ease: FlxEase.quadOut});
        tweens.tween(top, {y: -h}, inT, {startDelay: dur - inT, ease: FlxEase.quadIn});
        tweens.tween(bot, {y: FlxG.height}, inT, {startDelay: dur - inT, ease: FlxEase.quadIn});
      case 'rotate':
        for (c in cams(str(p, 'camera', 'game')))
        {
          var to = num(p, 'angle', 8);
          var back = Reflect.field(p, 'returnAfter') != false;
          tweens.tween(c, {angle: to}, Math.max(0.01, back ? dur / 2 : dur), {ease: ease(f.ease), onComplete: _ -> if (back) tweens.tween(c, {angle: 0}, Math.max(0.01, dur / 2), {ease: ease(f.ease)})});
        }
      case 'drift':
        var c = host.gameCam();
        if (c != null)
        {
          var o = {x: 0.0, y: 0.0};
          var dx = num(p, 'x', 60), dy = num(p, 'y', -30);
          tweens.tween(o, {x: dx, y: dy}, Math.max(0.01, dur / 2), {ease: FlxEase.sineInOut, onUpdate: _ -> c.targetOffset.set(o.x, o.y), onComplete: _ ->
            tweens.tween(o, {x: 0, y: 0}, Math.max(0.01, dur / 2), {ease: FlxEase.sineInOut, onUpdate: _ -> c.targetOffset.set(o.x, o.y)})});
        }
      case 'image':
        image(p, dur, f.ease);
      case 'jumpscare':
        var img = str(p, 'image');
        var s = img != '' ? image({image: img, x: num(p, 'x', 640), y: num(p, 'y', 360), scale: num(p, 'scale', 1.2), alpha: 1, fadeIn: 40, fadeOut: 250, layer: 'above hud', endScale: num(p, 'scale', 1.2) * 1.08}, dur, 'expoOut') : null;
        for (c in [host.gameCam(), host.hudCam()])
          if (c != null && num(p, 'shake') > 0) c.shake(num(p, 'shake', 0.04), Math.max(0.1, dur * 0.6), null, true);
        if (Reflect.field(p, 'flash') != false)
        {
          var col = FxModel.parseColor(Reflect.field(p, 'flashColor'), 0xFFFFFF);
          var c = host.topCam();
          if (c != null) c.flash(FlxColor.fromRGB((col >> 16) & 255, (col >> 8) & 255, col & 255, Preferences.flashingLights ? 255 : 64), 0.35, null, true);
        }
        playSound(str(p, 'sound'), 1);
      case 'text':
        text(p, dur, f.ease);
      case 'sound':
        playSound(str(p, 'sound'), num(p, 'volume', 1));
      case 'charMove':
        var c = host.character(str(p, 'target', 'opponent'));
        if (c != null)
        {
          if (!charHome.exists(c)) charHome.set(c, {x: c.x, y: c.y, a: c.alpha, sx: c.scale.x, sy: c.scale.y});
          var h = charHome.get(c);
          tweens.tween(c, {x: h.x + num(p, 'moveX'), y: h.y + num(p, 'moveY'), alpha: num(p, 'alpha', 1), 'scale.x': h.sx * num(p, 'scale', 1), 'scale.y': h.sy * num(p, 'scale', 1)},
            Math.max(0.01, dur), {ease: ease(f.ease)});
        }
      case 'layout':
        layout(p, dur, ease(f.ease));
      default:
        trace('[GOLDEN FX] Unknown effect type "${f.type}"');
    }
  }

  function screenRect(col:Int, cam:FlxCamera, ?w:Int, ?h:Int):FlxSprite
  {
    var s = new FlxSprite().makeGraphic(w ?? FlxG.width + 200, h ?? FlxG.height + 200, FlxColor.WHITE);
    if (w == null)
    {
      s.x = -100;
      s.y = -100;
    }
    s.color = col;
    s.scrollFactor.set();
    s.cameras = [cam];
    host.addSprite(track(s));
    return s;
  }

  function vignette(col:Int, size:Float):FlxSprite
  {
    var w = 640, h = 360;
    var bmp = new BitmapData(w, h, true, 0);
    var sh = new Shape();
    var m = new Matrix();
    m.createGradientBox(w * (1 + size), h * (1 + size), 0, -w * size / 2, -h * size / 2);
    sh.graphics.beginGradientFill(RADIAL, [col, col, col], [0, 0, 1], [0, Std.int(140 * size), 255], m);
    sh.graphics.drawRect(0, 0, w, h);
    bmp.draw(sh);
    var s = new FlxSprite().loadGraphic(bmp);
    s.setGraphicSize(FlxG.width, FlxG.height);
    s.updateHitbox();
    s.scrollFactor.set();
    s.cameras = [host.topCam()];
    host.addSprite(track(s));
    return s;
  }

  function tweenColor(c:FlxCamera, p:Dynamic, dur:Float, e:Float->Float):Void
  {
    var keys = ['brightness', 'contrast', 'saturation', 'hue', 'exposure', 'temperature', 'tintAmount', 'sepia', 'invert'];
    var from:Dynamic = colorState.get(c) ?? {};
    var to:Dynamic = {};
    for (k in keys)
      Reflect.setField(to, k, num(p, k));
    Reflect.setField(to, 'tint', Reflect.field(p, 'tint') ?? '#FFFFFF');
    var filter = new ColorMatrixFilter(FxModel.colorMatrix(from));
    setFilter(c, 'color', filter);
    tweens.num(0, 1, Math.max(0.01, dur), {ease: e}, k ->
    {
      var cur:Dynamic = {tint: to.tint};
      for (key in keys)
        Reflect.setField(cur, key, num(from, key) + (num(to, key) - num(from, key)) * k);
      colorState.set(c, cur);
      setFilter(c, 'color', new ColorMatrixFilter(FxModel.colorMatrix(cur)));
    });
  }

  var colorOverlays:Map<FlxCamera, FlxSprite> = [];

  /**
   * Without shader effects: approximate a colour grade with a full-screen overlay
   * (brightness -> black/white, tint -> colour, sepia -> brown). Saturation/hue/contrast need shaders.
   */
  function colorFallback(c:FlxCamera, p:Dynamic, dur:Float, e:Float->Float):Void
  {
    var br = num(p, 'brightness'), ta = num(p, 'tintAmount'), sp = num(p, 'sepia'), iv = num(p, 'invert');
    var col = 0x000000, a = 0.0;
    if (ta > 0)
    {
      col = FxModel.parseColor(Reflect.field(p, 'tint'));
      a = ta * 0.45;
    }
    else if (sp > 0)
    {
      col = 0x704214;
      a = sp * 0.35;
    }
    if (br < 0)
    {
      col = 0x000000;
      a = Math.max(a, -br);
    }
    else if (br > 0)
    {
      col = 0xFFFFFF;
      a = Math.max(a, br * 0.6);
    }
    var s = colorOverlays.get(c);
    if (s == null || !s.exists)
    {
      s = screenRect(col, c);
      s.alpha = 0;
      colorOverlays.set(c, s);
    }
    s.color = col;
    tweens.tween(s, {alpha: Math.min(0.9, a)}, Math.max(0.01, dur), {ease: e});
  }

  function loadImage(key:String):Null<FlxSprite>
  {
    if (key == null || key == '') return null;
    var path = Paths.image(key);
    if (!Assets.exists(path))
    {
      trace('[GOLDEN FX] Missing image "$key" ($path)');
      return null;
    }
    return new FlxSprite().loadGraphic(path);
  }

  function image(p:Dynamic, dur:Float, easeName:String):Null<FlxSprite>
  {
    var s = loadImage(str(p, 'image'));
    if (s == null) return null;
    var layer = str(p, 'layer', 'above hud');
    var sc = num(p, 'scale', 1);
    s.scale.set(sc, sc);
    s.updateHitbox();
    s.x = num(p, 'x', 640) - s.width / 2;
    s.y = num(p, 'y', 360) - s.height / 2;
    s.angle = num(p, 'angle');
    s.alpha = 0;
    s.antialiasing = true;
    if (layer == 'game world')
    {
      host.addBehindCharacters(cast track(s));
    }
    else
    {
      s.scrollFactor.set();
      s.cameras = [layerCam(layer)];
      host.addSprite(track(s));
    }
    var a = num(p, 'alpha', 1);
    var fin = num(p, 'fadeIn', 150) / 1000, fout = num(p, 'fadeOut', 300) / 1000;
    tweens.tween(s, {alpha: a}, Math.max(0.01, fin));
    var es = num(p, 'endScale', sc);
    tweens.tween(s, {x: s.x + num(p, 'moveX'), y: s.y + num(p, 'moveY'), 'scale.x': es, 'scale.y': es}, Math.max(0.01, dur), {ease: ease(easeName)});
    tweens.tween(s, {alpha: 0}, Math.max(0.01, fout), {startDelay: Math.max(0, dur - fout)});
    return s;
  }

  function text(p:Dynamic, dur:Float, easeName:String):Void
  {
    var content = str(p, 'text', 'TEXT');
    var size = Std.int(num(p, 'size', 64));
    var t = new FlxText(0, 0, 0, content, size);
    var col = FxModel.parseColor(Reflect.field(p, 'color'), 0xFFFFFF);
    var align:flixel.text.FlxText.FlxTextAlign = switch (str(p, 'align', 'center')) { case 'left': LEFT; case 'right': RIGHT; default: CENTER; };
    t.setFormat(fontPath(str(p, 'font', 'vcr')), size, FlxColor.fromRGB((col >> 16) & 255, (col >> 8) & 255, col & 255), align);
    var os = num(p, 'outlineSize', 4);
    if (os > 0)
    {
      var oc = FxModel.parseColor(Reflect.field(p, 'outline'), 0);
      t.setBorderStyle(OUTLINE, FlxColor.fromRGB((oc >> 16) & 255, (oc >> 8) & 255, oc & 255), os);
    }
    t.letterSpacing = num(p, 'spacing');
    t.antialiasing = true;
    var layer = str(p, 'layer', 'above hud');
    var x0 = num(p, 'x', 640) - t.width / 2, y0 = num(p, 'y', 360) - t.height / 2;
    t.setPosition(x0, y0);
    t.angle = num(p, 'angle');
    var a = num(p, 'alpha', 1);
    t.alpha = 0;
    if (layer == 'game world') host.addBehindCharacters(cast track(t));
    else
    {
      t.scrollFactor.set();
      t.cameras = [layerCam(layer)];
      host.addSprite(track(t));
    }
    var inT = Math.min(0.5, dur / 4);
    switch (str(p, 'animIn', 'fade'))
    {
      case 'none':
        t.alpha = a;
      case 'typing':
        t.alpha = a;
        t.text = '';
        tweens.num(0, content.length, Math.max(0.05, Math.min(dur * 0.6, content.length * 0.05)), {}, v -> t.text = content.substr(0, Std.int(v)));
      case 'bounce':
        t.y = y0 - 80;
        tweens.tween(t, {y: y0, alpha: a}, Math.max(0.05, inT * 1.5), {ease: FlxEase.bounceOut});
      case 'scale':
        t.scale.set(0.2, 0.2);
        tweens.tween(t, {alpha: a, 'scale.x': 1, 'scale.y': 1}, Math.max(0.05, inT), {ease: FlxEase.backOut});
      case 'slide':
        t.x = x0 - 300;
        tweens.tween(t, {x: x0, alpha: a}, Math.max(0.05, inT), {ease: FlxEase.expoOut});
      default:
        tweens.tween(t, {alpha: a}, Math.max(0.05, inT));
    }
    switch (str(p, 'loop', 'none'))
    {
      case 'shake':
        tweens.num(0, 1, dur, {}, _ -> t.offset.set(FlxG.random.float(-3, 3), FlxG.random.float(-3, 3)));
      case 'pulse':
        tweens.tween(t.scale, {x: 1.06, y: 1.06}, 0.25, {type: PINGPONG, ease: FlxEase.sineInOut});
      case 'float':
        tweens.tween(t, {y: y0 - 12}, 0.8, {type: PINGPONG, ease: FlxEase.sineInOut});
      case 'scroll':
        tweens.tween(t, {x: x0 - 400}, Math.max(0.05, dur), {});
      default:
    }
    switch (str(p, 'animOut', 'fade'))
    {
      case 'none':
        tweens.num(0, 1, Math.max(0.01, dur), {onComplete: _ -> t.visible = false}, _ -> {});
      case 'scale':
        tweens.tween(t, {alpha: 0, 'scale.x': 0.2, 'scale.y': 0.2}, Math.max(0.05, inT), {startDelay: Math.max(0, dur - inT), ease: FlxEase.backIn});
      default:
        tweens.tween(t, {alpha: 0}, Math.max(0.05, inT), {startDelay: Math.max(0, dur - inT)});
    }
  }

  function playSound(key:String, volume:Float):Void
  {
    if (key == null || key == '') return;
    var path = Paths.sound(key);
    if (!Assets.exists(path))
    {
      trace('[GOLDEN FX] Missing sound "$key" ($path)');
      return;
    }
    funkin.audio.FunkinSound.playOnce(path, volume);
  }

  function layout(p:Dynamic, dur:Float, e:Float->Float):Void
  {
    var pl = host.playerStrums(), op = host.opponentStrums();
    if (pl == null || op == null) return;
    if (strumHome == null) strumHome = {px: pl.x, py: pl.y, ox: op.x, oy: op.y};
    var h = strumHome;
    var mode = str(p, 'layout', 'middle');
    var tx = h.px, ty = h.py, ox = h.ox, oy = h.oy, oa = 1.0;
    switch (mode)
    {
      case 'middle':
        tx = (FlxG.width - pl.width) / 2;
        oa = num(p, 'opponentAlpha', 0.35);
      case 'swap':
        tx = h.ox;
        ox = h.px;
      case 'offset':
        tx = h.px + num(p, 'x');
        ty = h.py + num(p, 'y');
      default:
    }
    var d = Math.max(0.01, dur);
    tweens.tween(pl, {x: tx, y: ty}, d, {ease: e});
    tweens.tween(op, {x: ox, y: oy, alpha: oa}, d, {ease: e});
  }

  function restoreStrums():Void
  {
    if (strumHome == null) return;
    var pl = host.playerStrums(), op = host.opponentStrums();
    if (pl != null)
    {
      pl.x = strumHome.px;
      pl.y = strumHome.py;
    }
    if (op != null)
    {
      op.x = strumHome.ox;
      op.y = strumHome.oy;
      op.alpha = 1;
    }
    strumHome = null;
  }
}
