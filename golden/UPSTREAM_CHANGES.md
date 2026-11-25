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
