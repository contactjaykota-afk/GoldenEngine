# Golden Engine 0.2.0-alpha — Editors guide

Open them from **Main menu → Editors** (Developer Mode; you are asked to turn it on). Every Golden editor
has the same layout: **toolbar** (top), **browser** (left, with search), **preview / workspace**
(middle), **properties** (right), status bar (bottom).

Common controls in all Golden editors:

| Key / mouse | Action |
|---|---|
| Ctrl+S | Save into the target mod (also works while typing in a field) |
| Ctrl+Z / Ctrl+Y | Undo / redo |
| Esc | Back to the Editors hub (asks first if there are unsaved changes) |
| Mouse wheel over the workspace | Zoom · middle/right drag (or Space + drag) = pan |
| Ctrl + - / Ctrl + = | Zoom out / in |
| "Mod:" button (toolbar) | Choose which mod folder the editor saves into |

Editors never change the base game files. They save into the **target mod** (shown in the toolbar);
the mod must be enabled (Main menu → Mods) for the game to load what you made.

## Character Animation Studio
Animate characters from separate body-part PNGs, without Adobe Animate.

- Opens with **Boyfriend**, imported from the game's own Animate atlas (his real pieces: head, face,
  body, arm, mic hand, plus the drawings swapped per frame) with his real poses and animations.
  "Restore default Boyfriend" (Projects) brings him back; "Goldie" is a drawn example; "New empty
  character" starts from nothing.
- **Import PNG folder…** / **Import PNGs…**: same-size PNGs are treated as layers of one drawing and keep
  their positions; a `positions.json` (`{"Head.png": [x, y]}`) is used when present; otherwise parts are
  placed by name (Head, Body, LeftArm…) and you drag them into place in the *Setup pose*.
  Parts are auto-rigged by name (arms/head to body, hands to arms, face/eyes/mouth to head).
- **Browser**: Setup pose, Body Parts, Poses (Idle, Dance, Sing LEFT/DOWN/UP/RIGHT, Miss, Special,
  custom folders) and Animations, all with thumbnails; Presets; Projects; Import.
- **Workspace**: click a part to select it. Handles: circle = rotate, square = scale, pink cross = pivot
  (drag with the Pivot tool or Alt). Tools: V select/move, R rotate, S scale, P pivot, H pan, Z zoom.
  Arrow keys nudge (Shift = 10), [ / ] rotate, PageUp/PageDown change layer order, F frames the
  character, Ctrl+C / Ctrl+V copy/paste a part's transform.
- **Poses**: click a thumbnail to load it, edit any part. *Save as new pose* keeps the original;
  *Revert*, *Duplicate*, *Delete*, *New folder*, *Export pose* (`.pose.json`) / *Import pose*.
- **Timeline** (bottom): one row per part (yellow square = visible), keyframes per part, playhead.
  Editing a part on a frame creates a key (auto-key). K = key (Shift = all parts), Delete = remove key,
  Ctrl+D = copy keys to the next frame, drag a key to move it, click/drag the ruler to scrub,
  `,` / `.` step frames, Enter play/pause, O onion skin (frames before/after and opacity in the
  properties). Keyframes interpolate linearly; image swaps (variants) switch at the key.
- **Tweens**: select a part (or none = all parts) on a keyed frame and choose *Tween (key at frame)*:
  linear, quad/cube/sine in/out/in-out, back, elastic, bounce, or *hold* (no tween, frame by frame).
- **Fixing artwork**: Paint (B) and Erase (E) tools draw on the selected part's image (or the variant
  shown); brush colour/size in the properties; *Undo stroke* (paint strokes have their own undo).
- **Face**: give a part variants (*Add variant*: open mouth, closed eyes…) and key the *Variant*.
  Presets *Blink* and *Talk* build those animations.
- **Generate** adds the missing standard poses/animations (idle, sing, miss, hey, death) as editable
  starting points; it never overwrites existing ones (*Regenerate all* does, after asking). Results
  depend on how the parts were drawn; adjust them by hand.
- **Sprite sheets**: *Frame spacing* sets the gap between packed frames. *Add to existing sheet…* takes a
  Sparrow PNG (with its XML next to it), keeps all its frames and adds this project's animations
  (prefixes `golden <animation>`; numbered if the name is taken), repacked into one sheet: with
  *Replace original* the files are overwritten after a timestamped `.bak` copy, otherwise
  `<name>-golden.png/.xml` is written next to them.
- **Open from the Character Editor**: *Open in Animation Studio* opens the character's saved Studio project,
  or imports an Animate-atlas character (like BF) as editable parts. Sparrow characters are whole-body
  drawings per frame and cannot be split automatically.
- **AI pose generation is not available**: no image-generation model or API is included or reachable in this
  build. *Generate* is rule-based (it moves and rotates the parts you have); it does not draw new art.
- **Export** writes a normal FNF character into the mod: `images/characters/<id>.png/.xml`
  (several sheets for big characters, FNF "multisparrow"), `data/characters/<id>.json` and a health
  icon from the head (`images/icons/icon-<id>.png`). **Test Play** exports and plays a song with the
  character as the player (F9 returns).
- Projects are saved in `mods/<mod>/golden/animstudio/<id>/` (project.json + parts/) and reopen from
  *Projects*. Custom keys: create `golden-animstudio-keys.json` next to the mods folder, e.g.
  `{"rotate": "E", "play": "SPACE"}` (actions: move, rotate, scale, pivot, pan, zoom, play, prevFrame,
  nextFrame, firstFrame, lastFrame, key, deleteKey, onion, layerUp, layerDown, rotLeft, rotRight, focus).

## Event System (replaces the Camera Editor)
Visual song editing on a timeline, played by the real game.

- Pick the song/difficulty in the properties (nothing selected). Its chart (notes, sustains, FNF
  events), characters and stage load; the preview shows the real stage and characters.
- Tracks: Player notes, Opponent notes, Chart events (these start **locked**: click the coloured
  square at the left of a track to unlock), Camera, Zoom, Shake, Flash, Color, Screen FX, Overlays,
  Text, Characters, Note Layout, Audio, Scripts.
- Add effects from the browser: click = at the playhead, or drag onto the timeline. Effects: camera
  focus/zoom/bop/rotation/drift/shake, flash (respects reduced flashing), fade, colour grading
  (brightness, contrast, saturation, hue, exposure, temperature, tint, sepia, invert + 10 grade
  presets), vignette, cinematic bars, blur, glitch/RGB split/VHS, pixelate, image overlays, text (fonts,
  outline, animations, 10 style presets, layers incl. behind characters), jumpscares, character
  animation/move/fade, note layout (middle scroll, swap, offset — the notes follow), scroll speed,
  sound effects, Lua calls. Presets combine several editable effects.
- Timeline: drag a clip to move it, drag its right edge to resize, click the ruler to scrub; Space
  plays the song in the preview (characters dance and sing); Left/Right step; snap = beat/step/off;
  Ctrl+wheel zooms the timeline, wheel scrolls it, Shift+wheel scrolls tracks; Ctrl+D duplicates,
  Delete deletes. Unlocked notes can be dragged, retimed, re-laned (Up/Down), resized (sustain),
  duplicated and deleted. *+Event* adds an FNF chart event; its value is editable as JSON.
- *Convert to chart event* turns a camera focus/zoom/bop/animation/speed effect into the FNF event.
- **Bot Preview** saves and plays the real song with Bot Play from the playhead (practice + bot:
  no scores are saved); F9 returns. *Validate* lists missing images/sounds and conflicting effects.
- Saved non-destructively: effects → `data/golden/events/<song>.json`; note/event edits → a copy of the
  chart in the mod (`data/songs/<song>/<song>-chart.json`). **Reset to Original** deletes both.
- Scripts: *New Lua event script* creates `scripts/events/eventN.lua`; drag it onto the timeline to call
  its `onEvent` at that time. *Open Script Editor* edits Lua/HScript files (Haxe scripting is FNF's
  HScript through Polymod, `.hxc` files).

## Cutscene Editor
The Event System timeline for a cutscene that plays **before a song's countdown** (Enter skips in
game). Same effects (images, text, character animations, camera, sounds, fades). Set the length and
"Play before the song" in the properties. Saved as `data/golden/cutscenes/<song>.json`.

## Character Editor
Opens any character (base game, mods, Studio exports) with the real game character as preview:
animations (prefix, frame rate, loop, per-animation offsets — arrow keys nudge, Shift = 10), position
and camera offsets, scale, flip, sing time, pixel mode, health icon, and a **health bar colour**.
Space plays the animation. Saves a copy into the mod (`data/characters/<id>.json`); health colours go to
`data/golden/healthcolors.json`. *Test Play* plays a song with the character.

## Game Over Editor
Opens with the **default setup** ready to edit: character, music (`music/<key>.ogg`, *Import music…*
copies a file there), retry music, death sound, background colour/image, camera zoom, text. Each asset
has a *Remove* button (back to FNF's). *New Setup* adds more setups; turn on **Per-song setups** and
*Assign* them to songs. *Play Death* / *Retry* preview. Saved as `data/golden/gameover.json`, used by the
real Game Over screen.

## Week Editor
Story Mode weeks (`data/levels/<id>.json`): name, title graphic, background (colour or image), menu
characters, songs (add / remove / reorder), visibility and an unlock requirement (another week must be
beaten; `data/golden/weeks.json`). Live story-menu preview. *Open Story Mode* saves and opens it.

## Note Skin Editor
New skins start from an existing note style. Edit name/author/fallback, per-direction **colours**
(applied in gameplay), texture paths, scales and animation prefixes; *Import … texture* copies a Sparrow
PNG + XML into the mod. Preview of all four directions (*Press / Confirm* toggles receptors).
*Use in song* writes a copy of the song's metadata into the mod with the new style. Saved as
`data/notestyles/<id>.json` (+ `data/golden/notecolors.json`).

## Main Menu Editor
Background image and tint, logo (image, position, scale), entry order and visibility, custom entries
(label + action: `song:<id>`, `state:freeplay|story|options|credits|mods|editors`, `url:<address>`;
button art is generated from the label unless you give a Sparrow atlas), spacing, X offset and menu
music (`music/<key>/<key>.ogg`). Live preview with the real menu art. Saved as
`data/golden/mainmenu.json`; *Open Main Menu* shows the real menu.

## Mod Asset Manager
All files of the target mod by folder, with search. Image preview (with pixel size), audio preview,
text preview, file size. Import (into the folder in the properties), Export, Rename, Replace, New
folder, Delete (asks; files go to `mods/.trash/` and can be recovered). **Scan** lists assets referenced
by the mod's data but missing, and images/sounds/music in the mod that nothing references.

## FNF editors
Chart Editor (with Golden: purple menubar + info panel, File → Import MIDI…, **E** = extend the selected
notes' sustain by one snap step (hold to repeat), **Shift+E** = extend by a beat, **Q** = shorten (never
below zero); one undo step each), Stage Editor and Offset Editor are FNF's own.

## Freeplay search
In Freeplay press **Ctrl+F** (or F3): type to search (name, id or artist), Up/Down to choose a row,
Left/Right to change *From* (all / base game / a mod) and *Sort* (week order / A-Z / recently played),
Ctrl+Backspace clears, Esc/Enter closes and keeps the filter.
