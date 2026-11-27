# Changes to upstream Friday Night Funkin' files

Golden Engine is a modified version of Friday Night Funkin' (Apache-2.0, Copyright The Funkin' Crew Inc.).
Per section 4(b) of the Apache License, every upstream file that Golden Engine modifies is listed
here with a summary of the change. New Golden Engine files live under `source/golden/` and `golden/`.

Upstream base commit: `94ee0f2a9386d80e445be39ee2ed4b4a630cfbac` (FunkinCrew/Funkin `main`, 2026-11-02).

| File | Change | Milestone |
|---|---|---|
| `.github/workflows/golden-build.yml` | **Added** (new file): Windows/Linux builds on GitHub-hosted runners. | 1 |

| `source/funkin/InitState.hx` | `startGame()`: `-DSONG`/`-DLEVEL` debug boot paths now default their nullable defines (`?? 'bopeebo'`, `?? 'week1'`, `?? 'normal'`), fixing an upstream null-safety compile error (GE-000). | 1 |
| `source/Main.hx` | Startup loads `PolymodHandler.loadEnabledMods()` instead of `loadAllMods()` (upstream TODO). | Mods |
| `source/funkin/modding/PolymodHandler.hx` | `MOD_FOLDER` made public; `loadEnabledMods()` and `getEnabledMods()` use `golden.modding.GoldenMods` (installed + valid + enabled, from `golden-mods.json`) instead of the unused save field; `forceReloadAssets()` clears Polymod's asset cache and reloads enabled mods only. | Mods |
| `source/funkin/modding/PolymodErrorHandler.hx` | `onPolymodError()` forwards errors to `GoldenMods` for the Mod Manager. | Mods |
| `.github/workflows/build-game.yml` | Upstream nightly-build jobs guarded with `if: github.repository == 'FunkinCrew/Funkin'` so they do not queue forever on forks (they need FunkinCrew self-hosted runners). | CI |
| `project.hxp` | Window title "Golden Engine"; packages `golden/assets` into the default library and the Create Mod starter template (`golden/mod-template`, scripts renamed `*.hxc.tmpl` so Polymod never runs them) next to the executable (`addGoldenModTemplate`); `FEATURE_LUA` flag (desktop) adding the `hxluajit` haxelib; desktop application/executable icons from `golden/icons` (mobile icons unchanged). | 2–3, 9 |
| `source/Main.hx` | Loads `golden.GoldenSettings` before mods. | 2 |
| `source/funkin/InitState.hx` | Registers the `golden.dev.GoldenDevTools` Flixel plugin (Developer Mode shortcuts, mod selector, performance monitor). | 4 |
| `source/funkin/ui/mainmenu/MainMenuState.hx` | Adds **Mods** (→ `golden.ui.ModManagerState`) and **Editors** (→ upstream `DebugMenuSubState`, asks to enable Developer Mode if it is off) entries; tighter spacing when more than 5 entries; desktop mouse navigation (`handleMouse`). | 2 |
| `source/funkin/ui/options/OptionsState.hx` | New page `Golden` ("GOLDEN ENGINE" item) → `golden.ui.GoldenOptionsPage`. | 2 |
| `source/funkin/audio/FunkinSound.hx` | `playOnce()` scales UI sound files (scrollMenu, confirmMenu, cancelMenu, remote_click, CS_locked) by the Golden UI volume; gameplay sounds unaffected. | 2 |
| `source/funkin/play/PlayState.hx` | The chart-editor redirect also fires on the configurable Developer Mode key (default 7), never while typing and never if that key is bound to a note. | 4 |
| `source/funkin/util/plugins/VolumePlugin.hx` | Volume keys ignored while any text field has focus (`golden.input.GoldenInput.isTyping()`); upstream only ignored HaxeUI fields, so typing "-" or "0" in Flixel text inputs changed/muted the volume. | Studio |
| `hmm.json` | Adds `hxluajit` (MIT, pinned commit; prebuilt LuaJIT static libraries for Windows/Linux/macOS). | 9 |
| `source/funkin/modding/module/ModuleHandler.hx` | With `FEATURE_LUA`, registers the built-in `golden.lua.GoldenLuaModule` so Lua scripts receive module events. New file in an upstream package: `source/funkin/play/event/GoldenLuaSongEvent.hx` ("Lua Script (Golden)" chart event). | 9 |
| `source/funkin/ui/debug/charting/ChartEditorState.hx` | Two calls into `handlers/GoldenChartEditorHandler` (File > Import MIDI... menu entry, Ctrl+Shift+M). New Golden files in the same package: `commands/GoldenMidiImportCommand.hx`, `dialogs/GoldenMidiImportDialog.hx`, `handlers/GoldenChartEditorHandler.hx`. | 7 |
| `templates/haxe/ApplicationMain.hx` | Linux window icon embedded from `golden/icons/icon256.png` instead of `art/icons/iconOG.png`. | Identity |
| `source/funkin/ui/debug/charting/ChartEditorState.hx` (enum) | `ChartEditorTheme.Golden` added. | Theme |
| `source/funkin/ui/debug/charting/handlers/ChartEditorThemeHandler.hx`, `components/ChartEditorMeasureTicks.hx` | Golden theme colours (dark checkered grid, light dividers, gold selection) as an extra case in each existing theme switch. | Theme |
| `source/funkin/save/Save.hx`, `save/migrator/SaveDataMigrator.hx` | Default Chart Editor theme = Golden (existing saves keep their chosen theme). | Theme |
| `source/Main.hx`, `MainMenuState.hx` | Golden version logged at start and shown in the main-menu watermark. | Release |
| `source/funkin/audio/FunkinSound.hx` | `stopped()` override: breaks the endless looped-restart cycle when no audio device exists (GE-009). | Release QA |
| `source/funkin/audio/FunkinSound.hx` (`playMusic`) | Upstream's `freakyMenu` key is mapped to the selected menu theme (Golden Engine theme by default, classic Freaky Menu as an option). | Identity |
| `source/funkin/FunkinMemory.hx` | Permanently caches the selected menu theme instead of always `freakyMenu`. | Identity |
