package golden.render;

#if sys
import sys.FileSystem;
#end

/**
 * Golden Engine: fallback for software OpenGL renderers (GE-001, see golden/KNOWN_ISSUES.md).
 *
 * FNF's patched OpenFL compiles every fragment shader with `layout(blend_support_all_equations) out`
 * and enables `GL_BLEND_ADVANCED_COHERENT_KHR` whenever the driver advertises
 * `GL_KHR_blend_equation_advanced`. Mesa's llvmpipe advertises the extension but renders black
 * through that path, so VMs, remote desktops and CI machines show a black screen.
 *
 * Two tiers, because the GL context (and OpenFL's preloader shaders) exist before `Main` runs:
 *
 * 1. `__init__` runs at program start, before Lime creates the window. On Linux, if the driver is
 *    very likely software Mesa, it sets `MESA_EXTENSION_OVERRIDE` so the extension is never
 *    advertised and OpenFL uses its standard blend path. Only done when the user has not set the
 *    variable themselves.
 * 2. `onContextReady()` runs after the context exists (all platforms). It logs the GL renderer and,
 *    if the renderer string identifies a software rasterizer, disables OpenFL's advanced-blend flags
 *    for shaders compiled from then on.
 *
 * Environment overrides:
 * - `GOLDEN_SAFE_BLEND=1`      force the standard-blend path (even on a GPU).
 * - `GOLDEN_ADVANCED_BLEND=1`  never apply the fallback.
 */
@:access(openfl.display.OpenGLRenderer)
class RendererGuard
{
  static final MESA_OVERRIDE:String = "-GL_KHR_blend_equation_advanced -GL_KHR_blend_equation_advanced_coherent";

  /** GL_RENDERER reported by the driver, or null if it could not be read. */
  public static var rendererName(default, null):Null<String> = null;

  /** True if tier 1 set MESA_EXTENSION_OVERRIDE at startup. */
  public static var appliedEarlyOverride(default, null):Bool = false;

  /** True if tier 2 disabled OpenFL's advanced blending. */
  public static var disabledAdvancedBlend(default, null):Bool = false;

  static function __init__():Void
  {
    #if linux
    try
    {
      earlyConfigure();
    }
    catch (e:Dynamic) {}
    #end
  }

  #if linux
  static function earlyConfigure():Void
  {
    if (isEnvSet("GOLDEN_ADVANCED_BLEND")) return;
    // Respect an override the user already chose.
    if (Sys.getEnv("MESA_EXTENSION_OVERRIDE") != null) return;

    if (isEnvSet("GOLDEN_SAFE_BLEND") || likelySoftwareMesa())
    {
      Sys.putEnv("MESA_EXTENSION_OVERRIDE", MESA_OVERRIDE);
      appliedEarlyOverride = true;
    }
  }

  static function likelySoftwareMesa():Bool
  {
    if (isEnvSet("LIBGL_ALWAYS_SOFTWARE")) return true;
    var driver:Null<String> = Sys.getEnv("GALLIUM_DRIVER");
    if (driver == "llvmpipe" || driver == "softpipe" || driver == "swrast") return true;
    // No GPU device node at all (headless VM, CI, container): Mesa can only be rasterizing in software.
    // NVIDIA's proprietary driver and WSL expose GPUs without /dev/dri, so treat those as hardware.
    if (FileSystem.exists("/proc/driver/nvidia") || FileSystem.exists("/dev/nvidiactl") || FileSystem.exists("/dev/dxg")) return false;
    if (!FileSystem.exists("/dev/dri")) return true;
    return FileSystem.readDirectory("/dev/dri").length == 0;
  }
  #end

  static function isEnvSet(name:String):Bool
  {
    #if sys
    var v:Null<String> = Sys.getEnv(name);
    return v != null && v != "" && v != "0";
    #else
    return false;
    #end
  }

  /**
   * Call once the window and GL context exist, before the game draws anything.
   */
  public static function onContextReady():Void
  {
    #if (desktop && !html5)
    try
    {
      var gl = lime.app.Application.current.window.context.gl;
      if (gl != null)
      {
        rendererName = Std.string(gl.getParameter(gl.RENDERER));
      }
    }
    catch (e:Dynamic)
    {
      trace('[Golden] Could not read GL renderer: $e');
    }

    trace('[Golden] GL renderer: ${rendererName ?? "unknown"}'
      + (appliedEarlyOverride ? ' (software GL suspected: advanced blending hidden via MESA_EXTENSION_OVERRIDE)' : ''));

    if (isEnvSet("GOLDEN_ADVANCED_BLEND")) return;

    if (isEnvSet("GOLDEN_SAFE_BLEND") || isSoftwareRenderer(rendererName))
    {
      if (openfl.display.OpenGLRenderer.__complexBlendsSupported == true || openfl.display.OpenGLRenderer.__coherentBlendsSupported == true)
      {
        openfl.display.OpenGLRenderer.__complexBlendsSupported = false;
        openfl.display.OpenGLRenderer.__coherentBlendsSupported = false;
        disabledAdvancedBlend = true;
        trace('[Golden] Software renderer detected; advanced GL blending disabled (GE-001 fallback).');
      }
    }
    #end
  }

  /** True if a GL_RENDERER string identifies a software rasterizer. */
  public static function isSoftwareRenderer(name:Null<String>):Bool
  {
    if (name == null) return false;
    var n = name.toLowerCase();
    return n.indexOf("llvmpipe") >= 0 || n.indexOf("softpipe") >= 0 || n.indexOf("swrast") >= 0 || n.indexOf("software rasterizer") >= 0
      || n.indexOf("basic render driver") >= 0 || n.indexOf("gdi generic") >= 0;
  }
}
