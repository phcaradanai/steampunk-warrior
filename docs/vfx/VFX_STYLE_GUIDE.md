# VFX style guide: Steampunk Warrior combat effects

**Direction (approved by the user on 2026-11-04):** textured, glowing, stylized-realtime VFX in the manner of
reference 1 (Hovl's sketchbook, `VFX_REFERENCE_BOARD.md`), over the existing toon-shaded figures and painted arenas.
**No drawn polygons.** The earlier code-drawn toon shapes (`tests/vfx_lab/toon_fx_v1.gd`) remain only as the "before" in
the sandbox. The final verdict on how well each effect matches the reference belongs to the user.

## 1. How an effect is built

Every effect is a **recipe** in `game/combat/toon_fx.gd` (`RECIPES`), made of:

| Ingredient | What | Source |
|---|---|---|
| Textured layers | `Sprite2D` with additive blend (light, energy) or normal blend (smoke, gears) | `game/art/vfx/*.png` |
| Flipbooks | Lightning bolts (8 frames), ground arcs (6 frames) | Blender, `prototypes/vfx/blender/build_lightning.py` |
| Painted textures | Bursts, slash smear, flame, smoke, rings, hex shield, gear circle, … (23 + 2 lightning) | Codex image generation on black, packed by `prototypes/vfx/pack_textures.py` (alpha = brightness) |
| GPU particles | `sparks` (velocity streaks), `embers`, `drops`, `debris`, `motes` | `ToonFx._burst` |
| Erosion | Noise dissolve instead of fading (slashes, fire, smoke, flames) | `combat/vfx_add.gdshader`, `vfx_mix.gdshader`, `vfx_layer.gdshaderinc` |
| Glow | HDR 2D + canvas glow; only modulate > 1 blooms | `CombatFeedback._ready` (combat only, restored afterwards) |

## 2. Colour and value

- **Energy layers are additive, with gain 1.5–2.4** (HDR) so the glow picks them up. Arena, figures and UI stay ≤ 1, so
  they never bloom.
- Tints carry meaning: `TINTS` (heal mint, barrier cyan, electric blue, chemical green, water blue, copper, threat red).
  A skill's `tint` recolours its cast, travel and impact. Painted textures that already have their colour (fire, gear,
  hex shield, reticle, splash) use `color: "ffffff"`.
- Smoke and gears use **normal blend**: additive on brass figures blows out to an orange blob (seen on warp, then fixed).

## 3. Motion

| Phase | Rule |
|---|---|
| Impact | The strongest frame lands on the contact frame (CombatFeedback waits for `strike_timing`). Bursts scale up with a cubic ease-out, and rings expand. |
| Follow-through | Particles carry energy away from the attacker. Layers spin or travel (`spin`, `move`). |
| Dissipation | **Erode, don't fade**, for anything with a silhouette (slash, flame, smoke). Plain alpha fade only for light (glow, rings). |
| Loops (auras) | `PERIOD` per status. Copies are staggered in time, and the silhouette stays visible most of the cycle. |

## 4. Intensity and clarity (Riot restraint principle)

- **Shake:** quadratic, tiered (block 0.3, player blow 0.55, blow taken 0.7, critical 1.0), max 7 px.
- **Figure flash:** ×1.6 for 0.16 s.
- **Glow intensity:** 0.7. The crit's soft flash is small (gain 0.5, 0.12 s), because a larger one hid the target in real
  combat.
- **The target must be readable** again within about 0.1 s. Only the lightning strike's first 2 frames may white it out,
  on purpose.
- Every effect is checked at gameplay scale on several foes and arenas in the sandbox, and in a real recorded fight.

## 5. Adding or changing an effect

1. Make the texture: paint it with Codex image gen on pure black, or render it in Blender. Then run
   `pack_textures.py` and import it (`Godot --headless --path game --import`).
2. Add or edit the recipe in `RECIPES`. Keys are documented above it.
3. Tune it in the sandbox (presets: size, speed, opacity, density, colour), then save the result to `data/vfx_presets.json`.
4. Capture it with `tests/capture_vfx_textured.gd` and compare with A/B.
