Scripts run by Golden Engine (only while this mod is ENABLED):

HScript (.hxc) — FNF's Polymod scripting:
  scripts/events/   custom song events (see the example *ScreenFlashEvent.hxc)
  scripts/songs/    per-song scripts, scripts/stages/ per-stage scripts, scripts/modules/ always-on modules

Lua (.lua) — Golden Engine Lua (LuaJIT, sandboxed):
  scripts/lua/*.lua            run during every song
  data/songs/<song>/*.lua      run during that song only
  scripts/events/<name>.lua    run by the "Lua Script (Golden)" chart event (script = <name>)
  See MODDING.md next to the game for the callback and function list.
