# VFX audit

> **Superseded implementation note (2026-11-04):** the per-effect scores below audit the original code-drawn version
> and the first polygon refinement pass. At the user's request every effect has since been rebuilt with textures,
> particles and glow (`VFX_REFINEMENT_REPORT.md`, phase 2). The inventory, triggers and sources are unchanged. The
> scores have **not** been redone for the textured version: judge those from `captures/before_after_1..4.jpg` and in the
> sandbox.

Date: 2026-11-04. Engine: Godot 4.7.2, Mobile renderer (Metal on the Apple M1 dev machine). The game is a hybrid:
3D toon-shaded figures (`Stage3D` sub-viewports) stand on painted 2D arena backdrops, and every combat effect is
**code-drawn 2D** (`ToonFx`, `Node2D._draw`) on an overlay above them. The project has no particle nodes. Before this pass it
also had no shaders. Sprite-sheet VFX were removed on purpose in commit 020c07d, because they clashed with the toon figures.

Scores are 1–10 on seven axes: **R** readability at gameplay scale, **A** artistic quality, **M** motion, **T** timing/impact,
**S** consistency with the game's style, **G** gameplay-feedback clarity, **P** performance. They are the agent's
judgement from real-renderer captures (`captures/before_*`, `captures/after/*`, `captures/before_after_*.jpg`). They are not
a measurement, and the human reviewer has the final say. "→" gives before → after. A single value means no change was made.

## Inventory: combat effects (`game/combat/toon_fx.gd`, spawned by `combat_feedback.gd`)

Triggers come from `CombatFeedback`. Skills name a recipe in `data/skills.json` `vfx`: `cast` at the caster, `travel` to the
target, and `impact` on each hit. Enemy basic attacks use `ROLE_ATTACK_VFX`. Guard, vent and focus use `ACTION_VFX`.
Statuses use `STATUS_AURAS`.

| ID | Purpose / trigger | R | A | M | T | S | G | P | Weakness found → change | Pri |
|---|---|---|---|---|---|---|---|---|---|---|
| hit | basic blow lands (most frequent) | 5→8 | 5→7 | 5→7 | 5→8 | 7→8 | 6→8 | 9 | cream core covered the face; symmetric pop → ink impact frame, directional spikes, shrink-out | P1 |
| crit | the player's every blow (`heavy`) and S13 | 4→8 | 5→7 | 5→7 | 5→8 | 7→8 | 5→8 | 9 | 30 px cream disc hid the target for 0.1 s; ring crossed the damage number → same as hit, ring shortened | P1 |
| muzzle | gun cast | 6→7 | 6 | 6 | 6→7 | 7 | 6 | 9 | inherits the impact change | P3 |
| thrust | S01 | 6→7 | 6 | 6 | 6→7 | 7 | 7 | 9 | inherits the impact change | P2 |
| slash2 | S02, `quick` foes | 3→7 | 4→7 | 4→7 | 4→7 | 6→8 | 4→7 | 9 | arcs floated above the head and below the feet, never crossed the body → X of arcs through the chest, head/tail wake | P1 |
| cleave | S16 | 4→7 | 5→7 | 4→7 | 5→7 | 6→8 | 5→7 | 9 | same as slash2 | P1 |
| smash | S07, `charge`/`stagger` foes | 6→7 | 5→7 | 6→7 | 7 | 6→7 | 7 | 8 | grey dust faded into a muddy smear → toon erosion exit | P2 |
| bite | `bite`/`howl` foes | 6 | 6 | 6 | 6 | 7 | 6 | 9 | pale teeth on brass foes are low-contrast (not changed) | P3 |
| zap | S04/S06 travel | 7 | 7 | 7 | 7 | 8 | 7 | 9 | reads well; no change | — |
| zap_hit | S04/S06 impact | 7 | 7 | 7 | 7 | 8 | 7 | 9 | no change | — |
| thunder | S15 | 8 | 7 | 7 | 8 | 8 | 8 | 9 | no change | — |
| fire | S14, Heated tick | 6→7 | 5→7 | 6 | 6 | 7 | 6→7 | 9 | two flat tones → three value bands (dark outer, tint, core) | P2 |
| cloud | S08 | 6→7 | 5→7 | 5→7 | 6 | 6→8 | 6 | 8 | translucent mush at the end → erosion with dark rim | P2 |
| splash | S20 | 4→6 | 4→6 | 5→6 | 5→6 | 6→7 | 4→6 | 9 | thin ring, specks → floor ripple and stretched drops in a crown | P2 |
| snare | S21 | 7 | 6 | 6 | 7 | 7 | 7 | 9 | no change | — |
| heal | S09, life potion | 3→7 | 4→7 | 4→7 | 4→6 | 6→8 | 3→7 | 9 | tiny marks at the feet → snap-open ring, flat light column, larger rising crosses | P1 |
| block | shielded hit | 6 | 6 | 6 | 6 | 7 | 6 | 9 | small but readable (not changed) | P3 |
| dome | S11, guard | 6 | 6 | 6 | 6 | 7 | 6 | 9 | no change | P3 |
| charge | cast wind-up | 6 | 6 | 6 | 6 | 7 | 6 | 9 | no change | P3 |
| haste | S10 cast | 6→7 | 6 | 6 | 6 | 7 | 6→7 | 9 | chevrons enlarged | P3 |
| steam | vent, S22 | 6→7 | 5→7 | 6→7 | 6 | 6→8 | 6 | 8 | grey translucent ending → erosion | P2 |
| warp | S12 drone | 6 | 6 | 6 | 6 | 7 | 6 | 9 | no change | P3 |
| howl | enemy | 6 | 5 | 6 | 6 | 7 | 6 | 9 | thin rings (not changed) | P3 |
| reticle | S03 impact | 8 | 7 | 7 | 7 | 8 | 8 | 9 | no change | — |
| bolt | projectile loop | 7 | 6 | 6 | 7 | 7 | 7 | 9 | no change | — |
| beam | loot drop loop | 6 | 6 | 6 | 6 | 7 | 6 | 9 | no change | P3 |
| aura_wet | Wet status | 3→7 | 4→6 | 5→6 | – | 6→7 | 3→7 | 9 | 6 px drops faded the whole cycle → 9 px drops, opacity held | P1 |
| aura_heated | Heated | 2→7 | 4→7 | 5→6 | – | 6→7 | 2→7 | 9 | invisible on brass foes → three-band flames on the silhouette edges | P1 |
| aura_corroded | Corroded | 3→7 | 4→6 | 5→6 | – | 6→7 | 3→7 | 9 | hair-thin rings → filled acid bubbles with highlight | P1 |
| aura_marked | Marked | 8 | 7 | 7 | – | 8 | 8 | 9 | no change | — |
| aura_sealed | Sealed | 3→7 | 4→6 | 5→6 | – | 6→7 | 3→7 | 9 | copper on brass vanished → thicker clamp bands with bright rivets | P1 |
| aura_staggered | Staggered | 7 | 7 | 7 | – | 8 | 7 | 9 | no change | — |
| aura_haste | Haste | 4→6 | 5→6 | 6 | – | 7 | 4→6 | 9 | small chevrons → larger chevrons, opacity held | P2 |

## Inventory: feedback beats (`combat_feedback.gd`)

| Beat | Before | After | Notes |
|---|---|---|---|
| Whole-figure hit flash | ×2.6 for 0.24 s: washed brass foes to yellow and hid the impact shape (R 3, "excessive glow") | ×1.6 for 0.16 s (`HIT_FLASH`, `HIT_FLASH_TIME`) | still off with *reduced flash* |
| Screen shake | every damage event set trauma = 1, linear, 6 px | quadratic, tiered (block 0.3, player blow 0.55, blow taken 0.7, critical recipe 1.0), max 7 px | still off with *reduced shake* |
| Hit-stop | 0.06 s clip freeze on the player's blows | unchanged | |
| Recoil, damage number pop, miss sidestep + "พลาด!" | readable | unchanged | the number pop overlaps the crit ring for a few frames (minor) |
| Victory loot (gears, icon, beam) | readable | unchanged | |
| Anchor maths (`_anchor`) | global-position subtraction: wrong under any scaled parent | full-transform conversion | identical in game (unscaled); fixes the sandbox view |

## Inventory: non-combat visual feedback (audited, not changed in this pass)

| Effect | Source | Notes |
|---|---|---|
| Pipe entry (rim overlay, steam, fade) | `world/world_view.gd:215-239` | tween-driven; not in the sandbox |
| Scene strip fade, status line fade | `main.gd:246`, `main.gd:309` | UI transitions |
| Combat title card in/out | `combat/combat_view.gd:200-210` | |
| HP/barrier bar tween on contact | `combat/combat_view.gd:283-286` | synced to `impact_landed` |
| Settlement / XP tally | `main.gd:945-949` | |
| Dialogue typing, story screen | `main.gd:546`, `story/story_screen.gd:132` | text, not VFX |
| Hero/creature clips, hit_stop freeze | `art/stage_3d.gd`, `art/hero_3d.gd` | 3D animation, not VFX |

These run through other systems (world, UI, story), so the sandbox does not cover them. See *Remaining work* in
`VFX_REFINEMENT_REPORT.md`.
