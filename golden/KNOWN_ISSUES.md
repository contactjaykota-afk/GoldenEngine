# Golden Engine — known issues

Severity: **critical** (crash/data loss) · **high** (feature unusable for some users) · **medium** · **low**.
A bug is only marked fixed after its regression test has been re-run.

## Open

### GE-004 — No Windows build has been produced or launched by the developer — high
- This environment is Linux-only. The Windows build relies on `.github/workflows/golden-build.yml`
  (GitHub-hosted `windows-2022`). Until a run of that workflow succeeds AND someone launches the
  artifact on Windows, the Windows release is UNVERIFIED.

### GE-005 — Linux toolchain needed local workarounds — low (build environment only)
- lib.haxe.org was blocked here; `golden/scripts/setup-deps-git.sh` installs every dependency from GitHub
  instead. lime's cairo/pixman submodules (gitlab.freedesktop.org) were blocked too and were replaced
  locally by Ubuntu's cairo 1.18.0 / pixman 0.42.2 sources (+ a `config.h` shim and empty
  `pixman-riscv.c`). CI on GitHub runners does not need this.

### GE-006 — File dialogs (Mod import/export, MIDI import) untested in automation — medium
- They use lime's native dialogs; the automated tests cannot drive them. The underlying operations
  (zip import/export, MIDI parse/convert) are covered only partly (MIDI by unit tests; zip import/export
  not yet). Manual test needed.

### GE-002 — "Normal Conductor Update!! are you lagging?" warnings — low
- **Seen in:** upstream; Linux software-rendering test environment during gameplay.
- Logged by `PlayState` when the conductor falls back from audio-time sync. Gameplay continued normally.
  To re-measure on real Windows hardware before deciding whether action is needed.

### GE-003 — Memory usage ~1.1 GB RSS after visiting gameplay + Chart Editor — medium (to investigate)
- Measured by `golden/tests/smoke-linux.sh` (1121–1140 MB). Includes software-renderer texture copies;
  must be re-measured on a real GPU on Windows before optimizing.

## Fixed

### GE-001 — Black screen on software OpenGL (Mesa llvmpipe) — high (FIXED)
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
- **Fix:** `golden.render.RendererGuard` hides the extension before the GL context is created when
  the driver is very likely software Mesa (no GPU device node, `LIBGL_ALWAYS_SOFTWARE`, `GALLIUM_DRIVER=llvmpipe|softpipe|swrast`),
  and after context creation disables OpenFL's advanced-blend flags if `GL_RENDERER` names a software rasterizer. Overrides:
  `GOLDEN_SAFE_BLEND=1` forces it, `GOLDEN_ADVANCED_BLEND=1` disables it. Verification: `golden/tests/startup-linux.sh` in CI.
  **Retested 2026-11-27:** `golden/tests/smoke-linux.sh` (no Mesa override set) 22/22 on llvmpipe; log shows
  "Software renderer detected; advanced GL blending disabled (GE-001 fallback)" and all screenshots render.
  Windows "Microsoft Basic Render Driver" not tested (tier 2 only, no Windows machine).


### GE-000 — `-DSONG` / `-DLEVEL` debug boot did not compile (upstream) — low
- `InitState.startGame()` passed a nullable define to a non-nullable parameter (null-safety error).
- **Fix:** default to `bopeebo` / `week1` / `normal`. **Retested:** `-DSONG=bopeebo` build compiles
  and boots straight into Bopeebo.
