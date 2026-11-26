# Golden Engine — known issues

Severity: **critical** (crash/data loss) · **high** (feature unusable for some users) · **medium** · **low**.
A bug is only marked fixed after its regression test has been re-run.

## Open

### GE-001 — Black screen on software OpenGL (Mesa llvmpipe) — high
- **Seen in:** upstream FNF itself (not a Golden change); Linux build under Xvfb + Mesa llvmpipe.
- **Symptom:** game runs normally (audio, input, logic, ~56 FPS) but every frame is black, including
  the in-game F3 screenshot. No GL errors are reported.
- **Cause (confirmed with apitrace):** FNF's patched OpenFL compiles every fragment shader with
  `layout(blend_support_all_equations) out` and enables `GL_BLEND_ADVANCED_COHERENT_KHR` when the
  driver advertises `GL_KHR_blend_equation_advanced`. llvmpipe advertises the extension but outputs
  nothing through that path.
- **Who is affected:** software renderers — VMs, remote desktop sessions, CI machines, and possibly
  Windows' "Microsoft Basic Render Driver". Real GPU drivers are not affected.
- **Repro:** run the build with `LIBGL_ALWAYS_SOFTWARE=1` (or on llvmpipe) → black frames.
- **Workaround:** `MESA_EXTENSION_OVERRIDE="-GL_KHR_blend_equation_advanced -GL_KHR_blend_equation_advanced_coherent"`.
  Verified: title, menus, Freeplay, gameplay, pause, game over and Chart Editor all render.
- **Fix (implemented, NOT yet verified):** `golden.render.RendererGuard` hides the extension before the GL context is created when
  the driver is very likely software Mesa (no GPU device node, `LIBGL_ALWAYS_SOFTWARE`, `GALLIUM_DRIVER=llvmpipe|softpipe|swrast`),
  and after context creation disables OpenFL's advanced-blend flags if `GL_RENDERER` names a software rasterizer. Overrides:
  `GOLDEN_SAFE_BLEND=1` forces it, `GOLDEN_ADVANCED_BLEND=1` disables it. Verification: `golden/tests/startup-linux.sh` in CI.
  This stays open until that test has passed on a real build.

### GE-002 — "Normal Conductor Update!! are you lagging?" warnings — low
- **Seen in:** upstream; Linux software-rendering test environment during gameplay.
- Logged by `PlayState` when the conductor falls back from audio-time sync. Gameplay continued normally.
  To re-measure on real Windows hardware before deciding whether action is needed.

### GE-003 — Memory usage ~1.1 GB RSS after visiting gameplay + Chart Editor — medium (to investigate)
- Measured by `golden/tests/smoke-linux.sh` (1121–1140 MB). Includes software-renderer texture copies;
  must be re-measured on a real GPU on Windows before optimizing.

## Fixed

### GE-000 — `-DSONG` / `-DLEVEL` debug boot did not compile (upstream) — low
- `InitState.startGame()` passed a nullable define to a non-nullable parameter (null-safety error).
- **Fix:** default to `bopeebo` / `week1` / `normal`. **Retested:** `-DSONG=bopeebo` build compiles
  and boots straight into Bopeebo.
