# Golden Engine changelog

Only features that were built **and** tested are listed as done.

## Milestone 1 — foundation

- Architecture corrected: Golden Engine is now a branch (`golden-engine`) of the official
  FunkinCrew/Funkin source. The earlier standalone Electron prototype was archived on the
  `archive/electron-prototype` branch and is not part of the engine.
- Toolchain reproduced: Haxe 4.3.7, Funkin' Crew patched haxelib/hmm, all 37 pinned libraries
  (`golden/scripts/setup-deps.sh`, which also works around lib.haxe.org's download redirect).
- CI workflow for Windows x64 and Linux builds (`.github/workflows/golden-build.yml`).
- **Built:** the official FNF source compiles unmodified on Linux x64 (Haxe → C++ in ~14 min clean,
  ~1 min incremental), output `export/release/linux/bin/Funkin`.
- **Tested (automated, `golden/tests/smoke-linux.sh`, 22/22 pass):** boot → title → main menu →
  Freeplay → Bopeebo plays with audible audio → chart events run → pause → restart → game over →
  retry → exit to Freeplay → main menu → debug menu → Chart Editor; no crash, no uncaught errors.
- Fixed upstream `-DSONG`/`-DLEVEL` debug boot compile error (GE-000).
- Diagnosed black screen on software OpenGL (GE-001, see KNOWN_ISSUES.md).
- **Not yet done:** Windows build has not been produced or tested (needs a Windows runner — see README).

## Mod system (in progress)

- **Enabled-only mod loading** (extends upstream PolymodHandler; no second loader). Per-mod enabled
  state persists in `golden-mods.json` next to `mods/`. New mod folders are enabled automatically.
  Mods with invalid/missing metadata or an incompatible `api_version` are skipped with a reason
  instead of upstream's blocking error popups. Corrupted state file → backed up as `.bak`, no crash.
  **Tested** (`golden/tests/mod-enable-test.sh`, 23/23): A on/B off and reverse, none, both, new mod,
  corrupted state file, broken metadata, incompatible API version, disabled mod files untouched.
- **Starter mod template** (`golden/mod-template/starter`): FNF folder layout with a README per folder,
  mod icon, and a working HScript custom event (`<mod>-screen-flash`). No example song/characters/stage
  (removed at the user's request — content is created in the engine).
- Not done yet: in-game Create New Mod wizard and Mod Manager UI.
