# __MODNAME__

Created with Golden Engine's **Create New Mod** wizard. Everything in this folder is loaded by the
game while the mod is **enabled** in the Mod Manager. After changing files, use **Reload** in the
Mod Manager or restart the game.

This mod starts empty: add your own songs, characters, stages and weeks. Each folder has a
`README.txt` describing exactly what goes in it.

## Folders (these are the folders the FNF runtime reads)

| Folder | Put here |
|---|---|
| `data/songs/<song-id>/` | `<song-id>-metadata.json` and `<song-id>-chart.json` (made by the Chart Editor) |
| `songs/<song-id>/` | `Inst.ogg`, `Voices-<character-id>.ogg` |
| `data/characters/` | Character JSON (animations, offsets, health icon, camera offsets) |
| `images/characters/` | Character sprite sheets (`.png` + Sparrow `.xml`) |
| `images/icons/` | Health icons `icon-<character-id>.png` (300×150) |
| `data/stages/` | Stage JSON; stage images go anywhere under `images/` |
| `data/levels/` | Weeks for Story Mode. A song must be in a week to appear in Freeplay. |
| `scripts/` | HScript (`.hxc`): custom events, song/stage/module scripts |
| `music/`, `sounds/`, `videos/`, `shaders/` | Extra music, sound effects, cutscene videos, shaders |

You can also replace any base-game file by putting a file at the same path inside this mod.

**Use unique ids** (for example prefix them with `__MODID__-`) so your songs and characters don't
clash with the base game or other mods.

## Included example

`scripts/events/__MODCLASS__ScreenFlashEvent.hxc` — a working custom song event
(id `__MODID__-screen-flash`). Place it in a chart from the Chart Editor's event list; it flashes the
screen with the colour and duration you choose.

## Not available yet

* **Lua scripts** — planned (Milestone 3). Use HScript `.hxc` files for now.
* **3D stages and cutscenes** — planned (Milestones 10 and 12); no `stages3D/` or `cutscenes/`
  folders are created because the runtime cannot read them yet.

## Mod metadata

`_polymod_meta.json` is the official FNF/Polymod mod manifest. `api_version` must be within the
game-version range this build accepts (the Mod Manager tells you if it isn't).
