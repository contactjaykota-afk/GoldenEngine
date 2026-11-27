GOLDEN ENGINE
=============

Golden Engine is a modified build of Friday Night Funkin' (official source by The Funkin' Crew,
Apache-2.0 code; game assets are The Funkin' Crew's, see LICENSE.md) with a mod manager, mod
creation tools and developer tools.

INSTALL
  1. Extract the whole zip into a folder you can write to (e.g. Documents\GoldenEngine).
     Do not run it from inside the zip, and avoid "Program Files" (the game writes its mod list
     and settings next to the executable).
  2. Run Funkin.exe (Windows) or ./Funkin (Linux).
  Windows may show a SmartScreen warning because the build is not code-signed: More info > Run anyway.

FIRST STEPS
  Main menu > Mods      Mod Manager: enable/disable, create, import (.zip), export, duplicate, delete.
  Main menu > Editors   Chart / animation / stage editors (turns on Developer Mode).
  Options > Golden Engine
                        Developer Mode, UI volume, performance monitor, shortcut keys.

DEVELOPER MODE SHORTCUTS (when enabled)
  7      open the Chart Editor (during a song: the current chart)
  Tab    quick mod selector
  `      debug menu (upstream)
  F8     runtime console (all logs, Lua and mod errors; filter, copy)
  Mods > S             script editor for the selected mod (F9 there = Play-in-Editor; F9 again returns)

FILES CREATED NEXT TO THE EXECUTABLE
  mods\                  your mods (one folder per mod, each with _polymod_meta.json)
  mods\.trash\           mods deleted from the Mod Manager (recoverable)
  golden-mods.json       which mods are enabled, and load order
  golden-settings.json   Golden Engine settings

MODDING
  See MODDING.md. New mods: Mods > New (N) creates a ready-to-edit mod from the starter template.

TROUBLESHOOTING
  Black screen on a virtual machine / remote desktop: the engine falls back automatically on software
  OpenGL; force it with the environment variable GOLDEN_SAFE_BLEND=1.
  Crash logs: the "logs" folder next to the executable.
