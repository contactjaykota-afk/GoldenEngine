# Golden Engine — development status

Status levels (a feature only moves up with evidence):

- **Implemented** — code exists.
- **Compiled** — the Linux release build containing it succeeded.
- **Tested** — an automated or unit test exercising it was executed.
- **Runtime verified** — exercised in the running game (automated X11 input on a virtual display).
- **Complete** — required behaviour works and relevant tests passed.

Last full run: 2026-11-27, Linux x64 release build (`haxelib run lime build linux -release`),
Mesa llvmpipe software GL under Xvfb. **No Windows build has been run by the developer (see GE-004).**

## Test commands and results (2026-11-27)

| Command | Result |
|---|---|
| `haxelib run lime build linux -release` (with `HAXE_STD_PATH` set) | success (clean ~25 min on 4 cores, incremental ~1 min) |
| `golden/tests/smoke-linux.sh` | 22 passed, 0 failed (RSS 1152 MB after gameplay + Chart Editor) |
| `golden/tests/mod-enable-test.sh` | 23 passed, 0 failed |
| `golden/tests/golden-ui-linux.sh` | 40 passed, 0 failed |
| `golden/tests/unit/run-unit-tests.sh` | 30 passed, 0 failed (MIDI parser/converter) |

## Features

| Feature | Level | Evidence / notes |
|---|---|---|
| Upstream FNF gameplay loop (title, menus, Freeplay, song, pause, restart, game over, retry) | Runtime verified | smoke test |
| GE-001 software-GL black-screen fallback | Runtime verified (Linux) | smoke test without override |
| Enabled-only mod loading (`golden-mods.json`) | Complete (Linux) | mod-enable test |
| Mod Manager: list, icons, details, validation errors/warnings | Runtime verified | UI test screenshots 02, 04 |
| Mod Manager: enable/disable (persisted), reload applies, disabled content not registered | Runtime verified | UI test |
| Mod Manager: Enable all / Disable all | Compiled | not yet exercised by a test |
| Mod Manager: duplicate, delete (moves to `mods/.trash`), open folder | Compiled | not yet exercised by a test |
| Mod Manager: import/export `.zip` | Compiled | native file dialog not automatable (GE-006) |
| Mod Manager: dependency + conflict reporting | Compiled | not yet exercised by a test |
| Create Mod wizard (typed input, slug folder, manifest with running API version, template copy, validation) | Runtime verified | UI test |
| Starter template packaged with the game (`assets/golden/mod-template`) | Runtime verified | wizard uses the packaged copy |
| Main menu: Mods and Editors entries (original Golden art) | Runtime verified | UI test |
| Editors entry gated by Developer Mode (asks to enable) | Compiled; open path runtime verified with Dev Mode on | the "ask" dialog path not yet tested |
| Options > Golden Engine page (Developer Mode, UI volume, perf monitor, shortcut rebinding, reset) | Runtime verified for Dev Mode / UI volume / monitor toggles; rebinding + reset compiled only | UI test |
| Golden settings persistence (`golden-settings.json`) | Runtime verified | UI test restart check |
| UI volume applied to all UI sounds (incl. upstream menus) | Compiled | volume scaling not measured |
| UI sound de-duplication | Compiled | |
| Developer Mode badge + performance monitor overlay | Runtime verified (enabled; screenshot) | numbers not validated against an external profiler |
| Tab mod selector (select ≠ enable, Space toggle, Enter apply, M manager) | Runtime verified (open/close); toggle/apply compiled only | UI test |
| Chart Editor shortcut (default 7) in menus | Runtime verified | UI test |
| Chart Editor shortcut in gameplay (opens current chart) | Compiled | |
| MIDI parser + converter (tempo map, running status, sustains, lane modes, duplicates merge, errors) | Tested | 30 unit tests |
| Chart Editor File > Import MIDI dialog + undoable import command | Compiled | dialog needs native file picker (GE-006) |
| Windows build | NOT verified | GE-004 |

Everything in `golden/ROADMAP.md` marked "NOT started" has no code.
