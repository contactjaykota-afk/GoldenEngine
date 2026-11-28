# Golden Engine 0.2.0-alpha — Windows x64

Golden Engine is a modified build of **Friday Night Funkin'** (official FunkinCrew source, FNF v0.8.7)
with a mod manager, a set of visual editors for making mods, Lua scripting and developer tools.
This is an **alpha**: everything listed under "New" was tested with automated runtime tests on Linux and
the Windows build is launched on a GitHub-hosted Windows machine before publishing, but it has not been
tested on a Windows PC with a real GPU and speakers yet (see "Known limitations").

## Download and install

1. Download `GoldenEngine-v0.2.0-alpha-windows-x64.zip` below (and the `.sha256` file to verify it).
2. Extract the whole zip to a folder you can write to (for example `Documents\GoldenEngine`). Do not run
   it from inside the zip, and avoid `Program Files` (mods and settings are saved next to the game).
3. Run `GoldenEngine\Funkin.exe`. SmartScreen may warn (not code-signed): **More info → Run anyway**.

`EDITORS.md` (in the zip) explains every editor and its controls; `MODDING.md` explains the mod folder.

## New in 0.2.0-alpha

- **Editors hub** (Main menu → Editors) with Golden editors that share one layout and save into a mod:
  - **Character Animation Studio** — FNF Boyfriend as editable parts with his real poses and animations;
    import your own body-part PNGs; pose library with thumbnails; keyframe timeline with onion skin;
    face variants; eased tweens; paint/erase fixes; generated starting poses (rule-based, not AI); export to a
    playable FNF character or add to an existing sprite sheet (with backup); Test Play.
  - **Event System** (replaces the Camera Editor) — song timeline: camera, zoom, shake, flashes, colour
    grading, overlays, text, jumpscares, note layout (middle scroll…), character animation, sounds, Lua
    calls; notes and chart events editable (originals locked by default, saved as a mod copy); real stage
    preview; Bot Preview in the real game; Reset to Original.
  - **Cutscene Editor**, **Character Editor** (with health bar colours), **Game Over Editor** (per-song
    setups), **Week Editor**, **Note Skin Editor**, **Main Menu Editor**, **Mod Asset Manager**.
- **Ghost tapping** option (Options → Golden Engine), **on by default**.
- **Freeplay**: Ctrl+F search as you type, filter by mod, sort A-Z or recently played.
- **Chart Editor**: E / hold E / Shift+E extend sustains, Q shortens; info panel; purple menubar.
- **Vocals**: one combined `voices.ogg` or separate `Voices-Player.ogg` / `Voices-Opponent.ogg` work
  (plus FNF's `Voices-<character>.ogg`).
- **Options → Golden Engine**: Graphics Preset (Low/Medium/High/Ultra/Custom) and Screen Shaders.
- The starter mod template is in `mods\_ModTemplate`.

Still included from 0.1.0: the full FNF game, Mod Manager, Lua scripting, Script Editor with
Play-in-Editor, MIDI import, Developer Mode tools, Golden menu theme, app icon.

## Controls (defaults)

| Where | Key | Action |
|---|---|---|
| Menus | Arrows / Enter / Esc | Navigate / accept / back (mouse also works in the main menu and editors) |
| Gameplay | Arrow keys or D F J K | Notes · Enter = pause |
| Freeplay | Ctrl+F or F3 | Search / filter / sort |
| Developer Mode | 7 / Tab / F8 | Chart Editor / quick mod selector / log console |
| Golden editors | Ctrl+S, Ctrl+Z / Ctrl+Y, Esc | Save, undo/redo, back |
| Animation Studio | V R S P H Z, K, Enter, , . , O | Tools, keyframe, play, step frames, onion skin |
| Event System | Space, Left/Right, Delete, Ctrl+D | Play preview, step, delete, duplicate |
| Chart Editor | E, Shift+E, Q, Ctrl+Shift+M | Sustain longer / +1 beat / shorter, import MIDI |
| Bot Preview / Test Play | F9 | Back to the editor |

## Known limitations

- Tested on Linux with automated suites (real input on a virtual display, software OpenGL) and launched +
  driven on a GitHub-hosted Windows Server 2022 runner (software OpenGL, no audio output, input generated
  inside the game). **Not tested on a Windows PC with a real GPU, speakers and a physical keyboard.**
- Shader-based screen effects (colour grading, blur, glitch, pixelate) render black on the software
  renderer used for testing, so "Screen Shaders" defaults to Auto = off on software renderers (colour
  grading then uses an overlay approximation; blur/glitch/pixelate are skipped). They are **not verified
  on a real GPU** — if they look wrong, set Screen Shaders to Off.
- The Event System preview inside the editor shows the stage, characters, cameras and effects but not
  scrolling notes; Bot Preview shows the full game.
- BF's legs are part of his body drawing in the original art, so they cannot be posed separately; miss and
  cheer frames are whole-body drawings. Pose/animation generation is a starting point, not a finished
  animation.
- No 3D support yet (see ROADMAP). Not code-signed. Large download (~850 MB, contains the FNF assets).
- See `golden/KNOWN_ISSUES.md` in the repository for everything else.
