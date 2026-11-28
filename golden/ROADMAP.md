# Golden Engine — roadmap

**0.2.0-alpha status:** see the checklist in DEVELOPMENT_STATUS.md. Remaining after 0.2.0: 3D foundation (D7),
profiling-based optimisation, Chart Editor character management + embedded gameplay preview, a separate
text layout editor, Stage Editor extensions, shared preview framework, illustrated FNF-style UI art,
verification on Windows hardware.

Golden Engine is the official Friday Night Funkin' source (FunkinCrew/Funkin) extended in place.
Every stage below must integrate with the real game runtime; status words follow the definitions
in `DEVELOPMENT_STATUS.md` (Implemented → Compiled → Tested → Runtime verified → Complete).

| # | Stage | Status (see DEVELOPMENT_STATUS.md for evidence) |
|---|---|---|
| 1 | Foundation & Milestone 1 verification (toolchain, Linux build, smoke test, Windows CI) | Linux: runtime verified. Windows: CI workflow exists, no verified Windows run yet |
| 2 | Main Menu (Golden identity, Mods + Editors entries, logo, effects, UI audio, UI volume) | Partly: Mods/Editors entries, UI volume, UI sounds. Logo/background art/particles/mouse support NOT done |
| 3 | Mod Manager + Create Mod wizard | Implemented (list, icons, validation, enable/disable/all, create, duplicate, delete→trash, import/export zip, open folder, dependencies, conflicts, safe reload) |
| 4 | Tab Mod Selector | Implemented |
| 5 | Freeplay (search, sort/filter, previews, artwork, metadata) | Upstream Freeplay only; Golden additions NOT started |
| 6 | Chart Editor improvements | Upstream editor already has place/move/delete/resize/select/copy/paste/undo/redo/zoom/BPM/difficulties/waveform/playback speed/offsets; Golden additions: MIDI import. Audit of remaining gaps NOT done |
| 7 | MIDI import | Implemented (parser + converter unit-tested; dialog + menu entry + undoable command) |
| 8 | Event editor (multi-event per timestamp, duplicate, parameters, built-in events) | NOT started (upstream event lane exists) |
| 9 | Lua scripting for events | Implemented & runtime verified: LuaJIT (hxluajit), gameplay callbacks, chart "Lua Script" event, sandbox, timeout. In-game script editor NOT started |
| 10 | Character Editor | NOT started (upstream animation editor exists) |
| 11 | Stage Editor | NOT started (upstream stage editor exists) |
| 12 | Note Skin Editor | NOT started |
| 13 | Main Menu Editor | NOT started |
| 14 | Cutscene Editor | NOT started |
| 15 | Story / Week Editor | NOT started |
| 16 | 3D support | NOT started — investigation only (see below) |
| 17 | Optimization (lazy loading, unloading, caching, budgets) | NOT started; baseline measurements pending |
| 18 | Full QA | Partial: automated smoke, mod-enable, Golden UI and unit tests |
| 19 | Windows & Linux release preparation | NOT started |

## Order and dependencies

- 2 (menu art) depends on original artwork; the menu entries/audio are done first so 3–4 are reachable.
- 8 (event editor) must precede 9 (Lua attached to events).
- 10–15 reuse upstream editors where they exist (animation editor, stage editor) rather than replacing them.
- 17 needs measured baselines (RAM at startup / gameplay, install size) from release builds on real hardware.

## 3D support — practical path (planning notes, nothing implemented)

FNF renders through OpenFL's OpenGL renderer (Flixel cameras draw to OpenFL bitmaps/shaders). A
practical integration path is a Flixel sprite whose pixels are rendered by a small GL pass (custom
`openfl.display3D.Context3D` program or raw `lime.graphics.opengl` calls into an offscreen
framebuffer) so 3D content composites like any other sprite inside existing cameras/stages.
Requirements before starting: model format choice (glTF 2.0 binary), a loader, depth buffer support
in the offscreen target, and a decision on WebGL/mobile support. Away3D for OpenFL is unmaintained;
re-evaluating it vs. a minimal in-house renderer is the first task of stage 16.

## Next-generation directives (received 2026-11-27) — planning status

None of the items below has code yet unless stated. Ordered by dependency.

| # | Item | Plan / constraints |
|---|---|---|
| N1 | Development environment shell ("Golden Studio" state inside the game) | A Golden state hosting panels (project browser, editor tabs, console) built with the HaxeUI stack the upstream editors already use. Runs inside the real game, not a separate app. |
| N2 | Project browser / asset management | Lists the mod being edited (mods/<id>), file tree, missing-reference check reusing `ModScanner.validateContent`. |
| N3 | Built-in script editor (.hx/.hxc/.lua/.json/.xml) | **Stage 1 done (runtime verified)**: Golden Studio script editor per mod — highlighting, line numbers, tabs, undo/redo, find, templates, validated save with backups, reload. Not yet: code folding, autocomplete, replace, find-references, formatting, editing engine source (.hx outside mods). |
| N2 | (status) | Stage 1: the script editor's file list covers the mod's editable files. Asset browser / missing-reference view not yet. |
| N4 | Haxe compile workflow | Mod `.hxc` scripts reload at runtime (Polymod, already supported by `forceReloadAssets`). Compiling engine `.hx` requires Haxe + haxelibs + a C++ compiler; Studio will detect them (haxe/haxelib on PATH, MSVC on Windows) and run `lime build` as a child process with output in the console. Never pretends source compiles without them. |
| N5 | Lua in Studio | Lua already runs (batch 3); Studio adds editing + reload of `scripts/lua` without restarting the song. |
| N6 | Play-in-Editor — **stage 1 done (runtime verified)**: F9 in the script editor saves, reloads mods, plays a song in practice mode; F9 returns with the session restored. Not yet: pause/step/console-in-editor panel, previewing non-song states, other editors. | Practical path: Play = save → validate → `forceReloadAssets()` → switch to PlayState/target state with a "return to Studio" hook that restores the Studio session (state switch inside the same process, like the upstream Chart Editor playtest). Engine `.hx` changes = controlled rebuild + relaunch of a second process. An embedded viewport inside the editor UI is not planned (same GL context/renderer constraints). |
| N7 | Runtime console | Hook `haxe.Log.trace` (already centralised in `AnsiTrace`) into a ring buffer; filter/search; Lua/Polymod/asset errors are already collected (`GoldenLua.errors`, `GoldenMods.loadErrors`). |
| N8 | Visual Main Menu Editor | Menu layout moves from code to a JSON file read by MainMenuState (entries, positions, background, logo, colours, music); editor edits that JSON with live preview. |
| N9 | State/scene templates | Templates for ScriptedMusicBeatState / ScriptedModule (.hxc) — upstream supports scripted states. |
| N10 | 3D renderer | See "3D support — practical path". Requires depth-buffer offscreen rendering through OpenFL Context3D + a glTF (GLB) loader. Must stay optional and cost nothing when unused. Not started. |
| N11 | 3D scene editor, hybrid 2D/3D stages | After N10. |
| N12 | Character Animation Studio (body parts, pose assembly, talking/directional sections, timeline, spritesheet export) | Non-AI parts are feasible: part import/categorisation, variation library, pose assembly (transform per part), keyframe timeline with tweening, onion skin, export to Sparrow atlas + character JSON. **AI image generation is not available in this engine/environment**; it can only be an optional hook to an external service the user configures — never required, never faked. |
| N13 | Performance gates & benchmarks | Measure on real Windows hardware (startup time, RSS at menu/gameplay, frame-time percentiles). Linux/llvmpipe numbers exist only as a software-render baseline (RSS 1152 MB after gameplay + Chart Editor). |

## Directives received 2026-11-27 (second session) — queued, with current status

Order of work: shared infrastructure first, then editors one at a time, each with tests.

| # | Item | Status / plan |
|---|---|---|
| D1 | **Design direction for all editors**: dark FNF/Psych/Codename-style editors (compact toolbars, animation lists, X/Y + camera offsets, FNF note lanes), not a generic engine UI | Applies to every editor below. Upstream FNF editors (chart, animation, stage) are extended, not replaced. |
| D2 | **Chart Editor dark theme** like the Codename screenshot (dark checkered grid, purple header) | Done (Golden theme, default): grid, background, ticks, dividers, selection. Purple HaxeUI menubar: not yet. |
| D3 | **Chart Editor controls** (7, Space, Left/Right sections, Shift jumps, W/S, R / Shift+R, Shift fine snap, Ctrl both sides, E / hold E / Shift+E extend sustain, Q shorten) | Audit upstream keys first; add only what is missing, configurable, never active while typing; tests per key. |
| D4 | **Universal Live Preview framework** (right-side preview, zoom/fit/reset, grid, drag with synced X/Y, undo/redo, checkerboard, unsaved marker) | Build once as shared Golden component, then integrate editor by editor. |
| D5 | **Mod Asset Manager** (shared import/placement/validation/reveal/"referenced by" for all editors; folder conventions table) | Shared infrastructure, before the editors that import assets. Paths must match what FNF/Polymod actually loads. |
| D6 | **Game Over Editor** (default FNF game over loaded, layers, per-song configurations in `data/gameovers/`, custom music from `music/`) | After D4/D5. Needs a runtime hook in GameOverSubState to read the configuration. |
| D7 | **Combined `voices.ogg` and separate vocals** with auto-detection and priority rule | Inspect upstream vocal loading first (it already has some single-file fallback); test the 9 listed cases. |
| D8 | **UI sound + animation polish** everywhere (hover/confirm/back/toggle on/off/disabled, editor sounds, notifications, mute, preview in Options) | Extend the existing `golden.audio.UISound` manager (UI volume, de-dup already there); needs an original sound set. |
| D9 | **Psych-style folder workflow** (drop folders in `mods/`, enable/disable, import optional) | Already how Golden works; documented in MODDING.md. Manifest stays `_polymod_meta.json` (FNF/Polymod convention). |
| P2 | Freeplay search/filter/sort on top of upstream Freeplay | Planned (batch B). |
| P3 | Event editor improvements + Lua event timing from the Chart Editor | Planned (batch C, with D2/D3). |
| P4 | Character Animation Studio | Planned (after D4). |

## Guiding principles (engine identity, 2026-11-27)

Golden Engine is a full FNF engine: it extends the official FNF source in place (no replacement engine),
keeps FNF/Polymod formats (`_polymod_meta.json`, V-Slice charts, character/stage JSON), stays familiar to
Psych Engine / Codename Engine users, and adds its own tools. Every feature is verified against the
actual source and tested in the running game; other engines are references only (licenses respected).

## Further directives (queued, not started unless stated)

| # | Item | Plan |
|---|---|---|
| D10 | **Camera Editor** (focus BF/opponent/GF/object/free, X/Y + offsets + zoom with drag, follow speed/smoothing, zoom events, presets, timeline; song selector loading the real stage/characters/chart; per-song camera configs with save/save-as/reset/copy; Chart/Stage/Character Editor integration) | Must drive the real FNF camera (PlayState camFollow / FocusCamera / ZoomCamera events). Needs D4 Live Preview first. Per-song configs as JSON in the mod's `data/`, read by a gameplay hook; fallback = upstream behaviour. |
| D11 | **3D game-development track** (Blender-compatible import via glTF/GLB/OBJ — `.blend` only through a Blender export step, never "native"; scene editor, cameras, lights, animation, scripting, 3D menus, cinematics, first/third person, horror tools) | Investigation first: OpenFL Context3D/GL offscreen rendering into a Flixel sprite, glTF loader, depth buffer; then the 6 phases the request lists, each tested on Linux and Windows. No code yet. |
| D12 | **Whole-engine optimization** (size, RAM, CPU/GPU, loading, graphics presets) | Profile and record baselines first (current: release folder 937 MB, Linux RSS 1152 MB after gameplay + Chart Editor on llvmpipe); then small tested batches with before/after numbers. |
