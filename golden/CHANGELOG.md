# Golden Engine changelog

Only features that were built **and** tested are listed as done.

## Milestone 1 — foundation (in progress)

- Architecture corrected: Golden Engine is now a branch (`golden-engine`) of the official
  FunkinCrew/Funkin source. The earlier standalone Electron prototype was archived on the
  `archive/electron-prototype` branch and is not part of the engine.
- Toolchain reproduced: Haxe 4.3.7, Funkin' Crew patched haxelib/hmm, all 37 pinned libraries
  (`golden/scripts/setup-deps.sh`, which also works around lib.haxe.org's download redirect).
- CI workflow for Windows x64 and Linux builds (`.github/workflows/golden-build.yml`).
