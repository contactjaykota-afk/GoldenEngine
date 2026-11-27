-- __MODNAME__ — example Lua event script.
-- In the Chart Editor, place a "Lua Script (Golden)" event with script = "__MODID__-flash"
-- and value = a colour such as "#FFD24A". It runs when the song reaches the event.
function onEvent(name, value)
  if value == nil or value == "" then value = "#FFD24A" end
  cameraFlash(value, 0.4)
end
