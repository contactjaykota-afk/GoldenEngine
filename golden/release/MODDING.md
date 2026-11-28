# Making mods for Golden Engine

Golden Engine loads mods with FNF's own mod loader (Polymod). Mods made for vanilla FNF
(V-Slice, API version 0.8.x) work as-is.

## Installing mods (no import needed)

Put each mod's folder inside `mods/` next to the game. On start, and whenever you open the Mod Manager
or press **Reload (R)**, Golden Engine scans `mods/`:

- **Installed** = the folder exists in `mods/` and has a valid `_polymod_meta.json`.
- **Enabled** = turned on in the Mod Manager (new folders start enabled). Only enabled mods load their
  songs, characters, stages, scripts and assets.
- **Disabled** = still installed, nothing from it loads; its files are never changed or deleted.

Zip import (Mods > Import) is only a convenience; copying the folder works the same.

## Create a mod

Main menu → **Mods** → **New (N)**. Enter a title (the folder name is generated from it), author,
version and description, then **Create**. This makes `mods/<folder>/` with:

```
_polymod_meta.json      manifest (required)
_polymod_icon.png       icon shown in the Mod Manager
data/characters/        character JSON          images/characters/  character spritesheets
data/stages/            stage JSON              images/             other images
data/songs/<id>/        <id>-metadata.json, <id>-chart.json
songs/<id>/             Inst.ogg, Voices-<character>.ogg
data/levels/            story weeks (levels)
scripts/                HScript (.hxc): events/, songs/, stages/, modules/
music/ sounds/ shaders/ videos/
```

The template includes a working custom song event (`scripts/events/<Mod>ScreenFlashEvent.hxc`,
event id `<folder>-screen-flash`) that appears in the Chart Editor's event list.

Press **Reload (R)** in the Mod Manager (or leave it) to load the new mod.

## The manifest: `_polymod_meta.json`

```json
{
  "title": "My Mod",
  "description": "What it adds",
  "contributors": [{ "name": "You" }],
  "api_version": "0.8.7",
  "mod_version": "1.0.0",
  "license": "All rights reserved",
  "dependencies": { "other-mod-folder": ">=1.0.0" },
  "optionalDependencies": {}
}
```

- `api_version` must satisfy the game's rule (`>=0.8.0 <0.9.0`) or the mod is skipped with a reason.
- `dependencies` are checked by the Mod Manager (missing / disabled / wrong version are reported).

## Enabling, disabling, load order

Only **enabled** mods load; a disabled mod's songs, characters, scripts and events are not
registered at all. State is stored in `golden-mods.json`. If two enabled mods replace the same data
file, the Mod Manager reports a conflict; the mod later in the load order wins.

## Starter template

`mods/_ModTemplate` is the template "New mod" copies (placeholders like `__MODID__` are filled in). Edit it to
change what new mods start with. It has no `_polymod_meta.json`, so it is never loaded as a mod.

## Vocals: one file or two

Golden Engine looks for a song's vocals in this order (per side, first match wins):

1. files listed in the song metadata (`playerVocals` / `opponentVocals`) — FNF;
2. `songs/<song>/Voices-<character>[-variation].ogg` (e.g. `Voices-bf.ogg`) — FNF;
3. `Voices-Player.ogg` / `Voices-Opponent.ogg` (lower case works too) — Golden;
4. only if neither side found anything: one combined `Voices.ogg` or `voices.ogg`, played as a single track
   (muted while the player misses, like classic FNF).

So a mod can ship just `voices.ogg` (+ `Inst.ogg`). Variation files (`Voices-erect.ogg`) are tried before the
plain names.

## Files the Golden editors create

| File (inside your mod) | Made by | Used by |
|---|---|---|
| `data/characters/<id>.json`, `images/characters/<id>.png/.xml`, `images/icons/icon-<id>.png` | Animation Studio, Character Editor | gameplay (FNF character format) |
| `golden/animstudio/<id>/project.json` + `parts/` | Animation Studio | reopening the project |
| `data/golden/events/<song>.json` | Event System | gameplay effects |
| `data/golden/cutscenes/<song>.json` | Cutscene Editor | cutscene before the countdown |
| `data/songs/<song>/<song>-chart.json` / `-metadata.json` (copies) | Event System / Note Skin Editor | replace the original chart/metadata while the mod is enabled |
| `data/golden/gameover.json` | Game Over Editor | Game Over screen |
| `data/levels/<id>.json`, `data/golden/weeks.json` | Week Editor | Story Mode / Freeplay |
| `data/notestyles/<id>.json`, `data/golden/notecolors.json` | Note Skin Editor | gameplay notes |
| `data/golden/mainmenu.json` | Main Menu Editor | main menu |
| `data/golden/healthcolors.json` | Character Editor | health bar |

All of them are plain JSON you can also edit by hand (formats are described in `EDITORS.md` and in the
source files named there). Disable the mod to go back to the original game.

## Charts and MIDI

Chart in the Chart Editor (Editors → Chart Editor, or 7 in Developer Mode). **File → Import MIDI...**
(Ctrl+Shift+M) turns MIDI tracks into chart notes (choose Player/Opponent per track; BPM changes are
imported). MIDI files contain no audio — load the instrumental and vocals in the Audio menu.

## Lua scripting

Golden Engine runs Lua 5.1 scripts (LuaJIT, interpreter mode) from enabled mods:

| Location | Runs |
|---|---|
| `scripts/lua/*.lua` | during every song |
| `data/songs/<song>/*.lua` | during that song |
| `scripts/events/<name>.lua` | when a **Lua Script (Golden)** chart event with `script = <name>` is reached |

Callbacks (define any of them): `onCreate()`, `onSongStart()`, `onBeatHit(beat)`, `onStepHit(step)`,
`onUpdate(elapsed)`, `onNoteHit(direction, isPlayer, kind)`, `onNoteMiss(direction)`,
`onEvent(name, value)`, `onPause()`, `onResume()`, `onGameOver()`, `onSongEnd()`, `onDestroy()`.
Directions: 0 left, 1 down, 2 up, 3 right.

Functions: `print(...)`, `getSongPosition()` (ms), `getBPM()`, `getBeat()`, `getStep()`, `getSongName()`,
`getDifficulty()`, `getHealth()`, `setHealth(v)`, `addHealth(v)` (health is 0–2), `getScore()`,
`addScore(n)`, `cameraFlash(color, seconds)`, `cameraShake(intensity, seconds)`, `setCameraZoom(z)`,
`playAnimation("bf"|"dad"|"gf", anim, force)`, `playSound(path, volume)`, `setHUDVisible(bool)`,
`setVar(key, value)` / `getVar(key)` (shared between scripts of the song).

Sandbox: no `io`, `os.execute`, `require`, `dofile`, `loadfile`, `ffi`, `debug`; `os` only has
`clock`, `time`, `date`. A call that runs longer than 2 seconds is stopped with an error. Errors are
logged with the script name and line and never crash the game.

This API is Golden Engine's own; Psych Engine Lua scripts (which use `getProperty`, `makeLuaSprite`,
etc.) do not run unmodified.

## Sharing

**Export (E)** in the Mod Manager saves the mod as a `.zip`; **Import (I)** installs such a zip.

## Compatibility notes

- Vanilla FNF (V-Slice) mods: supported (same loader and formats).
- Psych Engine and Codename Engine mods use different folder layouts, chart formats and Lua/HScript
  APIs. They are NOT loaded automatically, and Psych Lua scripts need porting to the Golden Lua API.
