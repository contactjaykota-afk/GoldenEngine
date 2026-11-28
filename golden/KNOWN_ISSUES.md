# Golden Engine — known issues

Severity: **critical** (crash/data loss) · **high** (feature unusable for some users) · **medium** · **low**.
A bug is only marked fixed after its regression test has been re-run.

## Open

### GE-010 — Camera shader/filter effects render black on software OpenGL — high (mitigated)
- Event System colour grading (openfl ColorMatrixFilter), blur, glitch and pixelate (ShaderFilter) on a
  camera made that camera black under Mesa llvmpipe (test machines and the Windows CI runner). Not
  verified on a real GPU. FNF itself uses ColorMatrixFilter camera filters (RetroCameraFade), so GPUs
  probably work, but this is unconfirmed.
- Mitigation: Options > Golden Engine > Screen Shaders (default Auto = off on software renderers;
  colour grading then uses an overlay approximation, the other three are skipped with a log line).

### GE-016 — No AI pose/art generation — blocked
- Requested: AI that draws new poses of a reference character. No image-generation model or API key exists
  in this build environment, so nothing was implemented or faked. The Studio's *Generate* is rule-based
  (transforms existing parts). A future integration needs a chosen provider and a key.

### GE-017 — Symbols, layer folders and FLA compatibility not implemented — medium
- The Studio has parts (with variants), per-part keyframes, eased tweens, onion skin and paint/erase, but no
  reusable nested symbols or layer folders, and no Adobe Animate (.fla/.xfl) import/export. It imports FNF's
  Animate *texture atlases* (Animation.json + spritemap) and exports Sparrow sheets.

### GE-014 — Event System preview has no scrolling notes — low
- The in-editor preview shows the real stage/characters/cameras/effects and characters sing on notes,
  but notes do not scroll; Bot Preview (real gameplay) shows everything.

### GE-015 — Not verified on Windows hardware — high (process)
- Every 0.2.0 feature is runtime-tested on Linux (virtual display, software GL). The Windows build is
  launched and driven on a GitHub-hosted runner (software GL, no audio, in-game input). Physical
  keyboard/GPU/speaker testing on a Windows PC has not been done by anyone yet.

### GE-004 — Windows build launched only on a CI runner — high (see GE-015)
- This environment is Linux-only. `.github/workflows/golden-build.yml` built Windows successfully on
  GitHub's `windows-2022` runner (run 45953618100, commit 8652421, artifact golden-engine-windows-x64).
  Nobody has launched that artifact on Windows yet, so Windows runtime behaviour is UNVERIFIED.
  The artifact can only be downloaded with a GitHub login (Actions tab of the repository).

### GE-005 — Linux toolchain needed local workarounds — low (build environment only)
- lib.haxe.org was blocked here; `golden/scripts/setup-deps-git.sh` installs every dependency from GitHub
  instead. lime's cairo/pixman submodules (gitlab.freedesktop.org) were blocked too and were replaced
  locally by Ubuntu's cairo 1.18.0 / pixman 0.42.2 sources (+ a `config.h` shim and empty
  `pixman-riscv.c`). CI on GitHub runners does not need this.

### GE-006 — File dialogs — mostly resolved (2026-11-27)
- Mod zip import/export and MIDI import are now tested through the real native dialogs (zenity on Linux).
  Windows dialogs (tinyfiledialogs/Win32) remain untested (see GE-004). Original note:
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

### GE-013 — Entering a song after the Event System crashed — critical (FIXED, 0.2.0)
- The editor preview used FNF's cached Stage instance and destroyed it on exit; PlayState then reused it.
  Fixed: stages are built/released exactly like PlayState (CREATE / DESTROY events). Regression: the
  Event System and Cutscene tests start real gameplay after the editor.

### GE-012 — Opening the Editors hub also opened the first editor — high (FIXED, 0.2.0)
- The Enter/click that opened the hub was read again (FNF's shared controls report stale presses).
  Fixed: frame-accurate keys, input armed after release, cards open only on press+release on the card.

### GE-011 — Crash when a Golden editor rebuilt its property panel — critical (FIXED, 0.2.0)
- Flixel 6 crashes destroying an FlxInputText inside an FlxSpriteGroup. Fixed in the editor kit (the
  field detaches its input before destroying it). Regression: Animation Studio test (pose switching).

### GE-009 — Game froze at the title screen when no audio output device exists — critical (FIXED)
- Found via the Windows CI runner (which has no audio device) and reproduced on Linux without an audio
  server: looped music "completed" instantly and Flixel restarted it in an endless synchronous loop.
  `FunkinSound.stopped()` now stops looping a sound that restarts more than 8 times in one frame and logs
  "Audio output unavailable". Retested: AutoTest "play" route completes with no audio server.
- Remaining limitation: without an audio device, songs cannot be timed (FNF syncs gameplay to the audio
  clock), so gameplay is not meaningful; menus and editors work.

### GE-007 — A mod with a missing dependency froze startup on a blocking popup — critical (FIXED)
- Upstream PolymodErrorHandler shows a native modal for every per-mod error; with zenity/message boxes
  the game waits. Golden now drops mods with unmet dependencies before loading (reason in the Mod
  Manager) and routes per-mod Polymod errors to the Mod Manager instead of popups. Script error
  popups are unchanged (upstream behaviour). Retested: mods-extra-linux.sh 29/29.

### GE-008 — MIDI import dialog showed empty track rows — high (FIXED)
- Percent widths collapse inside HaxeUI ScrollView; explicit widths now. Retested: chart-midi-linux.sh.

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
