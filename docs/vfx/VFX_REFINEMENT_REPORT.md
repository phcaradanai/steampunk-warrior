# VFX refinement report

Date: 2026-11-04. The human reviewer is the final judge of visual quality; nothing here self-certifies it.
Evidence: `docs/vfx/captures/`. Every image comes from the real renderer on an Apple M1.

## Phase 1: polygon refinement (superseded)

The first pass refined the original code-drawn `ToonFx`:
- ink-star impacts and X slashes;
- larger status auras;
- noise-erosion puffs;
- the hit flash cut from ×2.6 to ×1.6;
- quadratic, tiered screen shake;
- presets, the VFX Sandbox, and the perf tools.

The user reviewed it in the sandbox and rejected the look because it did not resemble the references. They asked for
**no polygons**, reference-1 (Hovl) quality, and allowed Blender and Codex image generation. The feedback, flash, shake,
anchor, preset and sandbox work from phase 1 carries over into phase 2.

## Phase 2: textured effects (current)

1. **Reference study:** the Hovl sketchbook images were inspected directly. The lightning strike was chosen as the first
   target (`VFX_REFERENCE_BOARD.md`).
2. **Prototype:** a lightning strike built from a Blender bolt/arc flipbook, a Codex flare and ring, GPU sparks, and
   HDR glow. The user approved the direction ("Yes, do the rest").
3. **Textures:**
   - 23 painted textures from three parallel Codex image-gen jobs, packed to 512 px with alpha = brightness.
   - Lightning flipbooks rendered headless in Blender 5.2.3.
4. **Engine:** `ToonFx` was rewritten as a recipe system for all 33 kinds:
   - textured `Sprite2D` layers, additive or normal blend;
   - noise-erosion shaders (`vfx_add` / `vfx_mix`);
   - GPU particle presets.
   
   The public API (`spawn`, kinds, durations, tints, presets) is unchanged, so `CombatFeedback`, skills, roles,
   statuses and tests needed no changes. HDR 2D and canvas glow are switched on by `CombatFeedback` during combat only.
5. **Iterations,** each made from real-time captures (`tests/capture_vfx_textured.gd`):
   - **Pass 1** (all 33): steam stacked into a column; warp blew out to an orange ball; auras too small; heal pillar
     yellow; hit small.
   - **Pass 2:** spread steam, enlarged auras, green pillar, bigger hit. Warp was still blown out, so it was switched to
     normal blend.
   - **Pass 3** (real combat recording): the crit's soft glow swallowed the target, so its flash and the glow intensity
     were reduced.
6. **Gameplay verification:** recorded the real E10 fight through the actual game (`captures/combat/combat_E10_textured.mp4`,
   `combat_E10_textured_impacts.jpg`). Player crits, enemy guard domes and S01 thrust all play via `CombatFeedback`.
   Movie Maker output has normal brightness, so HDR does not darken the final image.
7. **Tests:** `tools/check_game.sh`: 2087 passed, 0 failed; transition smoke 84/84.
8. **Performance:** about 4–5× cheaper than polygons in the worst case. Shader compilation is pre-warmed
   (`VFX_PERFORMANCE.md`).

## Before / after

`captures/before_after_1..4.jpg` cover all 33 effects. Each effect has two rows:
- **before:** original polygon ToonFx, fixed-clock samples;
- **after:** textured, real-time samples at 0.02–0.6 s.

In the sandbox, **A/B compare** plays both side by side.

## Quality gates

| Gate | Status |
|---|---|
| All existing VFX inventoried | ✅ `VFX_AUDIT.md` |
| All effects accessible in the sandbox | ✅ 33 kinds, 6 gameplay events, 19 skills. ❌ non-combat items (pipe entry, scene fades) |
| High-priority effects refined | ✅ every kind rebuilt with textures. 3 critique passes on the weakest |
| Visual comparisons | ✅ before/after sheets plus live A/B |
| Effects reviewed in motion | ⚠️ 8 real-time samples per effect plus a real-combat video. No frame-by-frame review of every loop |
| Visual consistency | ⚠️ one pipeline and one glow model for all effects; painted textures come from one style prompt. Some textures are more detailed than others (gear circle vs chevron) |
| Performance regression | ✅ faster than before. Windows not measured |
| Works in actual gameplay | ✅ recorded fight |
| No critical rendering errors | ✅ none in runs or tests |
| Known limitations documented | ✅ below |
| Human approval | ✅ direction approved after the prototype. ⏳ final approval of the full set is pending |

## Remaining work and limits

1. **Per-effect matching to reference 1** beyond lightning: other Hovl-style elements (fire, ice-like crystal) need their own
   reference review with you.
2. **Hovl's screen-level look is not reproduced:** chromatic aberration and scene lighting (sky vortex, environment lit blue).
3. **Particles aren't on the effect clock:** frame-step and scrub in the sandbox don't move them.
4. **Textures come from image generation:** consistent per texture, not hand-tuned. Check the image-gen terms before a
   commercial release.
5. **No re-audit:** the per-effect audit scores were not redone for the textured version.
6. **Not covered:** non-combat effects (pipe entry, scene fades), and Windows performance.
