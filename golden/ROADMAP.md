# Golden Engine — roadmap

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
