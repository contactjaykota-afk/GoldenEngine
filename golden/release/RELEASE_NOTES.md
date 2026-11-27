# Golden Engine 0.1.0-alpha — Windows x64

Golden Engine is a modified build of **Friday Night Funkin'** (official FunkinCrew source, FNF v0.8.7)
with a mod manager, mod creation tools, Lua scripting and developer tools. This is an **alpha**:
the core game and the features listed under "Included" work and are tested; several planned editors
are not built yet (see "Not included yet").

## Download and install

1. Download `GoldenEngine-v0.1.0-alpha-windows-x64.zip` below (and optionally the `.sha256` file to verify it).
2. Extract the whole zip to a folder you can write to (for example `Documents\GoldenEngine`).
   Do not run it from inside the zip, and avoid `Program Files` (mod list and settings are saved next to the game).
3. Run `GoldenEngine\Funkin.exe`. Windows SmartScreen may warn because the build is not code-signed:
   **More info → Run anyway**.

## Included (tested)

- The full FNF game: Story Mode, Freeplay, gameplay, pause/restart, game over, results, options, upstream Chart / Animation / Stage editors.
- **Mod Manager** (Main menu → Mods): mods are folders in `mods/` (no import needed). Enable/disable, enable/disable all,
  create a mod from a template, duplicate, delete (to a recoverable trash folder), zip import/export,
  dependency and conflict reports. Only enabled mods load.
- **Lua scripting** for mods (LuaJIT, sandboxed) and a "Lua Script" chart event.
- **Script editor** for mods (Mods → S) with syntax highlighting, validated saving with backups, and **Play-in-Editor** (F9).
- **MIDI import** in the Chart Editor (File → Import MIDI…).
- **Developer Mode** (Options → Golden Engine): performance monitor, F8 log console, Tab quick mod selector, 7 = Chart Editor.
- Golden Engine menu theme (switch back to the classic FNF menu music in Options → Golden Engine).
- Chart Editor "Golden" dark theme (View → Theme), Golden Engine app icon.
- Separate UI sound volume; mouse support in the main menu; software-OpenGL fallback for VMs/remote desktops;
  no freeze when the PC has no audio output device.

## Controls (defaults)

| Where | Key | Action |
|---|---|---|
| Menus | Arrows / Enter / Esc | Navigate / accept / back (mouse also works in the main menu) |
| Gameplay | Arrow keys or D F J K | Notes |
| Gameplay | Enter | Pause |
| Developer Mode | 7 | Chart Editor (during a song: the current chart) |
| Developer Mode | Tab | Quick mod selector |
| Developer Mode | F8 | Log console |
| Any | ` (backquote) | Debug menu (upstream) |
| Mod Manager | Space / A / D / N / I / E / C / Del / O / R / S | Toggle / enable all / disable all / new / import / export / duplicate / delete / open folder / reload / script editor |
| Script editor | F9, Ctrl+S, Ctrl+Z/Y, Ctrl+F, Ctrl+N, Ctrl+R | Play-in-Editor, save, undo/redo, find, new file, reload mods |
| Chart Editor | Ctrl+Shift+M | Import MIDI (other keys are upstream FNF's) |

All gameplay and menu keys can be rebound in Options → Controls.

## Not included yet (planned)

Freeplay search/filter/sort additions, Chart Editor Codename-style toolbar layout and extra sustain keys, Golden Event editor
improvements, Character Animation Studio, Game Over / Note Skin / Main Menu / Cutscene / Week editors,
Live Preview framework, shared Mod Asset Manager, Camera Editor, combined `voices.ogg` detection, UI sound
redesign, graphics presets / optimization pass, 3D support. See `golden/ROADMAP.md` in the repository.

## Known limitations

- Tested on Linux with automated suites (real input on a virtual display) and launched + driven on a
  GitHub-hosted Windows Server 2022 runner (software OpenGL, no audio output). **Not yet tested on a Windows PC
  with a real GPU and speakers** — please report problems.
- Without any audio output device, songs cannot be timed (FNF syncs to the audio clock); menus still work.
- Not code-signed (SmartScreen warning). Download is large (~800 MB) because it contains the full FNF assets.
- See `golden/KNOWN_ISSUES.md` in the repository for everything else.
