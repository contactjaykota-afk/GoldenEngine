# Golden Engine

Golden Engine is a modified build of **Friday Night Funkin'** (official source,
<https://github.com/FunkinCrew/Funkin>, Apache-2.0). It is the real game, built with the
upstream Haxe / HaxeFlixel / OpenFL / Lime stack and extended with creator tools.

## Repository layout

| Path | What it is |
|---|---|
| `source/funkin/**` | Upstream FNF source. Golden Engine changes are made **in place**, each listed in `golden/UPSTREAM_CHANGES.md`. |
| `source/golden/**` | New Golden Engine code (editors, Lua runtime, 3D, project manager). Kept separate from upstream packages so merges from upstream stay easy. |
| `assets/`, `art/` | Upstream git submodules (proprietary FNF assets — **not** redistributed by Golden Engine; see their LICENSE). |
| `golden/` | Golden Engine docs, scripts, original sample content. |
| `example_mods/` | Polymod mods; Golden Engine projects are exported as mods in this format. |
| `.github/workflows/golden-build.yml` | Windows x64 + Linux builds on GitHub-hosted runners. |

Branches: `golden-engine` (development), `main` (pristine upstream, for merging updates),
`archive/electron-prototype` (an earlier, superseded standalone prototype — kept for reference only).

## How Golden features map onto upstream systems

Golden Engine extends what FNF already has instead of replacing it:

| Golden feature | Upstream system it builds on |
|---|---|
| Gameplay, scoring, health, pause, results | `funkin.play.PlayState`, `play.scoring.Scoring`, `PauseSubState`, `ResultState` (unchanged rules) |
| Mod loading / Project Manager | Polymod (`funkin.modding.PolymodHandler`), `_polymod_meta.json` |
| Haxe scripting | Polymod HScript scripted classes (`ScriptedSong`, `ScriptedStage`, `ScriptedModule`, …) |
| Lua scripting | **new** — `source/golden/lua` (planned, Milestone 3) bridged to the same `ScriptEvent` dispatch HScript modules receive |
| Chart Editor (+ MIDI import, event library) | `funkin.ui.debug.charting.ChartEditorState` (V-Slice chart format) |
| Stage Editor | `funkin.ui.debug.stageeditor.StageEditorState` (`StageData` JSON) |
| Character Editor / animation alignment | `funkin.ui.debug.anim` + `CharacterData` JSON (offsets per animation) |
| Song events | `funkin.play.event.SongEvent` registry (+ scripted events) |
| Cutscenes / transitions | `funkin.play.cutscene` (VideoCutscene, dialogue, `CutsceneSequence`) |
| Story Mode Manager | `funkin.data.story.level` (`LevelData` JSON) and `StoryMenuState` |
| Main Menu Editor | `funkin.ui.mainmenu.MainMenuState` |
| Editor entry point | `funkin.ui.debug.DebugMenuSubState` (desktop builds) |

## Building

Requirements: Haxe **4.3.7**, git, and per platform: Windows → Visual Studio 2022 Build Tools
(MSVC v143 + Windows SDK); Linux → see `golden/scripts/setup-deps.sh` / the CI workflow for packages.

```bash
git clone --recurse-submodules <your Golden Engine fork>
cd GoldenEngine
golden/scripts/setup-deps.sh
haxelib run lime rebuild windows -64 -release   # or: linux
haxelib run lime build windows -release          # output: export/release/windows/bin/Funkin.exe
```

Upstream's `docs/COMPILING.md` remains the reference for platform setup.

## Milestones

1. Clone/inspect upstream, correct architecture, compile & launch the original foundation. ← **current**
2. Golden Engine identity, project structure, integrated development menu.
3. Gameplay improvements, mod loading, Lua.
4. Character Editor + animation alignment.
5. Stage Editor.
6. Note Skin Editor.
7. Main Menu Editor.
8. Chart Editor + MIDI import.
9. Event Library.
10. Cutscene Editor + cutscene→gameplay transitions.
11. Story Mode Manager.
12. 3D support.
13. Haxe extensions & source customization.
14. Testing, optimization, docs, Windows packaging.

See `golden/CHANGELOG.md` for what is actually done and tested.
