# Golden Engine — development status

Status levels (a feature only moves up with evidence):

- **Implemented** — code exists.
- **Compiled** — the Linux release build containing it succeeded.
- **Tested** — an automated or unit test exercising it was executed.
- **Runtime verified** — exercised in the running game (automated X11 input on a virtual display).
- **Complete** — required behaviour works and relevant tests passed.

Last full run: 2026-11-27, Linux x64 release build (`haxelib run lime build linux -release`),
Mesa llvmpipe software GL under Xvfb. **No Windows build has been run by the developer (see GE-004).**


## 0.2.0-alpha checklist (2026-11-28)

Statuses: NOT STARTED · IN PROGRESS · IMPLEMENTED (code exists) · TESTED (automated test exercised it) ·
VERIFIED (end-to-end runtime test of the real workflow passed, incl. the result in real gameplay where it
applies) · BLOCKED. "VERIFIED" here means Linux automated runtime verification (real X11 input, software
GL); none of it is verified on Windows hardware (GE-015).

| Item | Status | Evidence |
|---|---|---|
| Mod template in mods/_ModTemplate | VERIFIED | golden-ui + mods-extra tests create mods from it |
| Combined / separate vocals (Voices-Player/Opponent, voices.ogg) | TESTED (11 unit) + VERIFIED for separate files in gameplay | VoiceTest; autotest log "Vocals for bopeebo: separate" |
| Editor kit + Editors hub | VERIFIED | every editor test |
| Character Animation Studio (BF from atlas, poses, timeline, import, generate, export, Test Play) | VERIFIED | animstudio-linux.sh 46/46 |
| Event System (timeline, locked tracks, notes/events editing, effects, presets, bot preview, reset) | VERIFIED | eventsystem-linux.sh 32/32 |
| Shader effects (colour grading, blur, glitch, pixelate) on a GPU | BLOCKED (no GPU here) | GE-010; fallback VERIFIED |
| Cutscene Editor | VERIFIED | cutscene-linux.sh 14/14 |
| Character Editor (+ health colours in gameplay) | VERIFIED | editors3-linux.sh |
| Mod Asset Manager | VERIFIED | editors3-linux.sh (28/28 with Character Editor) |
| Game Over Editor (default + per-song, real Game Over screen) | VERIFIED | editors2-linux.sh |
| Week Editor (registered by Story Mode, unlock rule) | VERIFIED | editors2-linux.sh (27/27 with Game Over) |
| Note Skin Editor (style + colours in gameplay) | VERIFIED | editors4-linux.sh |
| Main Menu Editor (real main menu, custom entry runs) | VERIFIED | editors4-linux.sh (24/24 with Note Skin) |
| Freeplay search / mod filter / sort | VERIFIED | freeplay-linux.sh 11/11 |
| Chart Editor sustain keys + info panel + purple menubar | VERIFIED | chart-keys-linux.sh 11/11 |
| Graphics presets + Screen Shaders option | IMPLEMENTED | settings persistence via existing settings code; preset effects not measured |
| Stage Editor | IMPLEMENTED (FNF's own editor, unchanged) | not extended in 0.2.0 |
| Text & typography | IMPLEMENTED inside the Event System (text effects, styles, layers) | eventsystem test (Horror Title text in gameplay); no separate text editor |
| Chart Editor character management / additional characters / live gameplay preview | NOT STARTED | (FNF's chart editor already selects player/opponent/GF in its metadata toolbox) |
| Live preview in every editor | IMPLEMENTED per editor (no shared preview engine) | each editor previews its own data |
| UI sound / animation polish | IN PROGRESS | editor buttons: hover/click sounds, press animation, toasts, tooltips |
| FNF visual identity pass | IN PROGRESS | purple/gold Golden theme; no new illustrated art |
| 3D foundation | NOT STARTED | ROADMAP D7 |
| Performance profiling and optimisation | NOT STARTED | presets only; no profiling numbers |

## Test commands and results (0.1.0) (2026-11-27)

| Command | Result |
|---|---|
| `haxelib run lime build linux -release` (with `HAXE_STD_PATH` set) | success (clean ~25 min on 4 cores, incremental ~1 min) |
| `golden/tests/smoke-linux.sh` | 22 passed, 0 failed (RSS 1152 MB after gameplay + Chart Editor) |
| `golden/tests/mod-enable-test.sh` | 23 passed, 0 failed |
| `golden/tests/golden-ui-linux.sh` | 45 passed, 0 failed |
| `golden/tests/unit/run-unit-tests.sh` | 30 passed, 0 failed (MIDI parser/converter) |
| `golden/tests/lua-linux.sh` | 18 passed, 0 failed (Lua in real gameplay) |
| `golden/tests/studio-linux.sh` | 26 passed, 0 failed (script editor + Play-in-Editor) |
| `golden/tests/unit/run-unit-tests.sh` (HighlightTest) | 21 passed, 0 failed |
| GitHub Actions `golden-build.yml` | Windows build + package step green for every commit since 8652421 (artifact golden-engine-windows-x64, ~841 MB). |
| GitHub Actions `golden-windows-runtime.yml` (run 46077878192, commit e150587) | **19/19 on a GitHub-hosted Windows Server 2022 runner**: packaged Funkin.exe launched with Mesa llvmpipe (no GPU), virtual audio driver installed but OpenAL found no output (game continued silently, GE-009); title, main menu, Mod Manager open/close, Bopeebo started, Lua from a mod ran, frames not black, no crash. Input generated in-game (AutoTest) — OS input does not reach games on these runners. **Not yet run on a Windows PC with a GPU and sound.** |
| `golden/tests/mods-extra-linux.sh` | 29 passed, 0 failed (Mod Manager actions, zip import/export via real file dialogs, selector, rebinding/reset) |
| `golden/tests/chart-midi-linux.sh` | 7 passed, 0 failed (7 in gameplay, File > Import MIDI via real dialog, import) |
| `golden/tests/autotest-linux.sh` | 8 passed, 0 failed (in-game AutoTest routes "play" and "mods", same as Windows CI) |

## Features

| Feature | Level | Evidence / notes |
|---|---|---|
| Upstream FNF gameplay loop (title, menus, Freeplay, song, pause, restart, game over, retry) | Runtime verified | smoke test |
| GE-001 software-GL black-screen fallback | Runtime verified (Linux) | smoke test without override |
| Enabled-only mod loading (`golden-mods.json`) | Complete (Linux) | mod-enable test |
| Mod Manager: list, icons, details, validation errors/warnings | Runtime verified | UI test screenshots 02, 04 |
| Mod Manager: enable/disable (persisted), reload applies, disabled content not registered | Runtime verified | UI test |
| Mod Manager: Enable all / Disable all | Runtime verified | mods-extra test |
| Mod Manager: duplicate, delete (moves to `mods/.trash`, Y/N confirmation) | Runtime verified | mods-extra test |
| Mod Manager: open folder | Compiled | needs a desktop file manager |
| Mod Manager: import/export `.zip` (through the native file dialog) | Runtime verified, incl. top-level-folder zips and refusal of `../` entries | mods-extra test |
| Mod Manager: dependency + conflict reporting (content files only, not READMEs) | Runtime verified | mods-extra test |
| Mods with unmet dependencies are skipped with a reason (no blocking popup) | Runtime verified | mods-extra test (previously froze startup on a native popup) |
| Create Mod wizard (typed input, slug folder, manifest with running API version, template copy, validation) | Runtime verified | UI test |
| Starter template packaged with the game (`assets/golden/mod-template`) | Runtime verified | wizard uses the packaged copy |
| Main menu: Mods and Editors entries (original Golden art) | Runtime verified | UI test |
| Main menu mouse navigation (hover selects, click accepts, wheel) | Runtime verified (hover+click opens an entry) | UI test |
| Main menu controller navigation | Upstream behaviour (FNF controls include gamepad bindings) | not tested here (no gamepad in the container) |
| Editors entry gated by Developer Mode (asks to enable) | Compiled; open path runtime verified with Dev Mode on | the "ask" dialog path not yet tested |
| Options > Golden Engine page (Developer Mode, UI volume, perf monitor, shortcut rebinding, reset) | Runtime verified (all rows) | UI test |
| Golden settings persistence (`golden-settings.json`) | Runtime verified | UI test restart check |
| UI volume applied to all UI sounds (incl. upstream menus) | Compiled | volume scaling not measured |
| UI sound de-duplication | Compiled | |
| Developer Mode badge + performance monitor overlay | Runtime verified (visible in screenshot 07: FPS, frame time, RAM, state) | first version used OpenFL TextFields, which render nothing (and blacked out the game when created at startup) on software GL; rewritten on Flixel. Numbers not validated against an external profiler |
| Runtime console (F8): all log lines with file:line, level tabs, filter, scroll, copy, clear | Runtime verified (open/close, renders with tabs and counts); filter/copy compiled only | UI test screenshot 07d |
| Tab mod selector (select ≠ enable, Space toggle, Enter apply, M manager) | Runtime verified (open/close/toggle/apply); M compiled only | UI + mods-extra tests |
| Chart Editor shortcut (default 7) in menus | Runtime verified | UI test |
| Chart Editor shortcut in gameplay (opens current chart at the current position) | Runtime verified | chart-midi test |
| MIDI parser + converter (tempo map, running status, sustains, lane modes, duplicates merge, errors) | Tested | 30 unit tests |
| Chart Editor File > Import MIDI dialog + import command | Runtime verified (native dialog, track mapping, 12 notes + BPM imported). Undo of the import: compiled only | chart-midi test; dialog layout bug (empty track rows) found and fixed |
| Lua runtime (LuaJIT via hxluajit, sandbox, 2 s timeout, error reporting) | Runtime verified | lua test: sandbox, syntax error, infinite loop |
| Lua gameplay callbacks (onCreate, onSongStart, onBeatHit, onNoteHit, onNoteMiss, onEvent, …) | Runtime verified for those listed; onStepHit/onUpdate/onPause/onResume/onGameOver/onSongEnd compiled only | lua test |
| Lua API (getSongName, getDifficulty, getBPM, cameraFlash, setVar/getVar, print) | Runtime verified for those listed; other functions compiled only | lua test |
| "Lua Script (Golden)" chart event | Runtime verified (fires at 3009 ms for a 3000 ms event) | lua test |
| Disabled mods' Lua never runs | Runtime verified | lua test |
| Release packaging in CI (README, MODDING.md, changelog, empty mods folder) | CI step green on Windows and Linux | contents not inspected (artifact download needs GitHub login) |
| Golden Studio script editor (Mod Manager > S): file list, tabs, line numbers, Haxe/Lua/JSON/XML highlighting, bracket match, auto-indent, Ctrl+N templates, Ctrl+S save with backup + validation (JSON/XML parse, Lua compile), undo/redo, Ctrl+R reload mods | Runtime verified: open, new-from-template, type, save, backup, Lua syntax error (file:line), undo, leave. Find, redo, tab switching, close-with-confirm, JSON/XML validation: compiled only | studio test |
| Play-in-Editor (F9 in the script editor: save all, reload mods, play song in practice mode; F9 returns with tabs/text restored; survives upstream F5 state reset) | Runtime verified: play from editor, edited Lua runs in the song, return restores 2 tabs. F5-reset restore: compiled only | studio test |
| Typing in Golden text fields no longer triggers volume keys (- + 0) | Runtime verified (studio test types "-", smoke audio check afterwards passes) | upstream VolumePlugin edit |
| Chart Editor Golden theme (default; View > Theme > Golden) | Runtime verified (screenshots in chart-midi test). Purple menubar of the reference not replicated | chart-midi test |
| Version 0.1.0-alpha in watermark + log | Runtime verified (log) | UI test log |
| Esc from Mod Manager / script editor no longer bounces the next screen (main menu went back to the title) | Runtime verified + regression step in AutoTest "mods" route | found by the in-game driver |
| Golden Engine menu music (default) / classic Freaky Menu option (Options > Golden Engine > Menu Music); only the selected track is permanently cached | Runtime verified on Linux (log + settings persistence); Windows check added to the runtime test | UI test |
| Freeze when no audio output device exists (GE-009) | Fixed, runtime verified on Linux (no audio server) and Windows CI | |
| Windows build | **Compiled in CI** (commit 8652421); not launched on Windows by anyone yet | GE-004 |

Everything in `golden/ROADMAP.md` marked "NOT started" has no code.
