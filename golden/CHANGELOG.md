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
- **Mod Manager** (main menu > Mods): installed mods with icon, title, version, authors, description and
  validation; enable/disable (Space/click), enable all / disable all, create, duplicate, delete (to
  `mods/.trash`), import/export zip, open folder, dependency and conflict reports, safe reload.
  Runtime verified: list, create, toggle, reload (see DEVELOPMENT_STATUS.md for per-action levels).
- **Create Mod wizard**: title / folder / author / version / description; writes a valid
  `_polymod_meta.json` for the running API version and copies the packaged starter template.
  Runtime verified.

## Batch 2 — Golden menus, Developer Mode, MIDI import (2026-11-27)

- Main menu **Mods** and **Editors** entries with original Golden artwork (`golden/scripts/gen_menu_items.py`).
- **Options > Golden Engine**: Developer Mode (off by default), UI volume, performance monitor, Chart Editor
  key (default 7) and mod selector key (default Tab) rebinding, reset developer settings. Saved in
  `golden-settings.json`.
- **Developer Mode tools** plugin: DEV MODE badge, performance monitor (FPS, frame time, RAM current/peak,
  GC heap, state/substate, song, difficulty, BPM, position), Tab mod selector, Chart Editor shortcut.
  Shortcuts are ignored while typing and outside menus; in gameplay the key is ignored if bound to a note.
- **UI sounds**: central `UISound` (hover/scroll/select/back/open/close/toggle/slider/error) with
  de-duplication; UI volume applies to every UI sound file, upstream menus included.
- **MIDI import** (Chart Editor File > Import MIDI..., Ctrl+Shift+M): SMF format 0/1 parser, tempo map,
  per-track Skip/Player/Opponent mapping, lane modes, min sustain, offset, replace/merge, BPM import,
  live preview, one undoable command. Parser/converter unit-tested (30/30); dialog compiled, not
  runtime-tested (native file picker).
- Fixed during testing: FNF `controls.ACCEPT` is "held", so one press toggled options several times
  (now `ACCEPT_P`); overlays now pause a parent that keeps updating (main menu), ignore the opening key
  on their first frame, and finish closing only after keys are released.
- GE-001 software-renderer fallback verified on llvmpipe (moved to Fixed).
- Tooling: `golden/scripts/setup-deps-git.sh` (all dependencies from GitHub), `golden/tests/golden-ui-linux.sh`,
  `golden/tests/unit/run-unit-tests.sh`.

## Batch 3 — Lua scripting (2026-11-27)

- **Lua** (LuaJIT via the `hxluajit` library, desktop builds): scripts from enabled mods in
  `scripts/lua/` (every song), `data/songs/<song>/` (one song) and `scripts/events/` (the new
  **Lua Script (Golden)** chart event). Gameplay callbacks come from FNF's own module event system.
  Sandboxed (no io/os.execute/require/ffi/debug), 2-second runaway-call timeout, errors logged with
  script name and line, never crash the game. Runtime verified by `golden/tests/lua-linux.sh` (18/18).
- Starter template: Lua event example `scripts/events/<mod>-flash.lua`; scripts README updated.
- Release packaging step in CI (README.txt, MODDING.md, GOLDEN-CHANGELOG.md, empty `mods/`).

## Batch 4 — Runtime console, overlay rendering fix (2026-11-27)

- **Runtime console** (F8, Developer Mode): every log line (game, Polymod, Lua, Golden) with file:line,
  tabs All/Errors/Warnings/Lua/Mods with counts, text filter, mouse-wheel scrollback, Copy, Clear.
- **Fixed**: the performance monitor and DEV MODE badge were OpenFL stage TextFields, which rendered no
  text on the software-GL path and blacked out the game when the monitor was enabled at startup. All
  Golden overlays now draw with Flixel on a dedicated top-most camera. (The earlier status entry
  "monitor runtime verified" was wrong and has been corrected.)

## Batch 5 — Golden Studio script editor (2026-11-27)

- **Script editor** (Mod Manager > Scripts / S): edit a mod's .hxc/.hx/.lua/.json/.xml/.txt/.md files in
  the game. Syntax highlighting (Haxe/HScript, Lua, JSON, XML), line numbers, bracket matching,
  auto-indent, Tab = 2 spaces, tabs with unsaved markers, undo/redo, find, new file from templates
  (Lua callbacks, HScript Module), Ctrl+S with validation (JSON/XML parsed, Lua compiled with
  file:line errors) and a backup of the previous version in `mods/.trash/backups/`, Ctrl+R saves all
  and reloads mods. Runtime verified by `golden/tests/studio-linux.sh` (18/18); highlighter unit-tested (21/21).

## Batch 6 — Play-in-Editor (2026-11-27)

- **Play-in-Editor** (F9 in the script editor): saves all files (validated), reloads mods, starts the
  song of the file being edited (or the last/typed one) in practice mode; F9 during the song stops it
  and returns to the editor with tabs, carets and text restored. The editor also restores itself after
  upstream's F5 asset reload. Runtime verified: a Lua script typed in the editor runs in the played song.
- **Fixed**: upstream's volume keys (- + 0) fired while typing in Flixel text fields (Create Mod wizard,
  script editor, console filter), changing or muting the saved master volume.

## Batch 7 — Main menu mouse navigation (2026-11-27)

- Main menu: hovering an entry selects it, clicking the selected entry opens it, the mouse wheel moves
  the selection (desktop). Runtime verified.
