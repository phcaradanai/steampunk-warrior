# VFX Sandbox guide

The sandbox plays every combat effect on the real arena art, the 3D hero and 3D foes, through the **same code the game
runs**:
- Single effects go through `ToonFx.spawn`.
- "Gameplay events" and "Skills" go through a real `CombatFeedback`: dash, clip, cast, projectile, impact, flash,
  shake, numbers and sound, exactly as in a fight.

It lives in `game/tests/`, which export excludes (`export_presets.cfg` `exclude_filter="tests/*"`), so it never ships.

## Run

```bash
/Users/oyl-mac_m1/Downloads/Godot.app/Contents/MacOS/Godot --path game res://tests/vfx_sandbox.tscn
```

You can also open `game/tests/vfx_sandbox.tscn` in the editor and press F6.

## Layout

- **Left: library.** A searchable tree with five effect families (impacts, elemental, support/casts, travel/loot, status
  auras), **Gameplay events** (player crit, blow taken, block, heal, miss, victory loot) and **Skills** (every skill with a
  `vfx` recipe, S01–S22). Below the tree: what the effect means in play, its duration, or the skill's recipe.
- **Centre: stage.** It shows the 1280×720 combat stage at 0.77 scale. The top-left HUD shows FPS, frame time, live effects,
  draw calls and objects.
- **Bottom bar:**
  - Transport: ▶ play, ⏸ pause, ⏭ one frame, timeline scrubber, speed (0.1×–2×), loop, flash on/off, shake on/off,
    *real view* (1:1 full window, G or Esc to return), 📷 screenshot.
  - Environment: **A/B compare**, compare-with (the original polygon version), backdrop (7 arenas plus a flat light and a flat dark), foe (brass soldier, rat, coat gunner, iron giant,
    training dummy), camera distance (0.6–1.6, zooms on the target), window size (1280×720, 960×540, 1920×1080).
  - **Presets** (single effects only): size, speed, opacity, piece count (density), colour. Reset, Save and Load.

## Keys

| Key | Action |
|---|---|
| Space | play / replay |
| P | pause |
| . | step one frame (pause first) |
| ↑ ↓ ← → | previous / next effect |
| C | toggle A/B compare |
| G or Esc | toggle the 1:1 real view |
| F12 | screenshot |

## Compare

Turn on **A/B compare**. Two copies of the foe stand side by side and play in sync:
- **Left:** the original code-drawn polygon ToonFx (`tests/vfx_lab/toon_fx_v1.gd`).
- **Right:** the current textured version that the game uses.

Compare works for single effects. Gameplay events and skills always play the current version, because they run the live
`CombatFeedback`.

## Presets → gameplay

The sliders edit `ToonFx.presets[kind]` live. **Save** writes `game/data/vfx_presets.json`. The game reads that file the
first time any effect spawns, so a saved preset is what players see. Only values that differ from the defaults are
written. **Load** re-reads the file and **Reset** clears the current kind. When the game runs exported, `res://` is
read-only and Save reports an error.

## Screenshots and recordings

- 📷 / F12 saves to `user://vfx_captures/` and shows the full path in the status line.
- Real-time frames of every effect (GPU particles run on real time):
  ```bash
  CAPTURE_DIR=/abs/out /Users/oyl-mac_m1/Downloads/Godot.app/Contents/MacOS/Godot --path game --script res://tests/capture_vfx_textured.gd
  ```
  Options: `VFX_KINDS=hit,crit`, `VFX_COMPARE=1`.
- Fixed-clock strips (textured layers are a pure function of the clock; particles are not):
  ```bash
  CAPTURE_DIR=/abs/out /Users/oyl-mac_m1/Downloads/Godot.app/Contents/MacOS/Godot --path game --script res://tests/vfx_showcase.gd
  ```
  Options: `VFX_KINDS=hit,crit`, `VFX_FOE=N15`, `VFX_ARENA=archive`, `VFX_SIZE=960x540`, `VFX_LEGACY=1` (before).
- UI screenshots of the sandbox: `CAPTURE_DIR=… Godot --path game --script res://tests/capture_vfx_sandbox.gd`.
- Real combat video through the actual game: `Godot --path game --write-movie /abs/out/frame.png --fixed-fps 30 --script
  res://tests/record_combat_vfx.gd` (env `VFX_ENCOUNTER`, `VFX_TURNS`).
- Performance: `tests/vfx_perf.gd` (see `VFX_PERFORMANCE.md`).

## Known limits

- Pause freezes ToonFx clocks and tweens. Frame-step and scrub move the textured layers only. GPU particles and
  CombatFeedback tweens (numbers, dash) keep real time.
- HDR 2D is on during combat. Raw `get_image()` read-backs are linear (dark), so capture scripts use `Captures.frame`
  (`tests/captures.gd`), which converts to sRGB. The screen itself is unaffected.
- The preset sliders show no numeric readout. Values appear in the status line when changed.
- Non-combat effects (pipe entry, scene fades) are not in the sandbox. See `VFX_AUDIT.md`.
