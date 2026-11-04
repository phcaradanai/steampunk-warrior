# VFX performance

**Hardware measured:** Apple M1, 8 GB, macOS. Godot 4.7.2, Mobile renderer (Metal). 1280×720 window, vsync off, HDR 2D and glow on.
**Not measured:** Windows. An export preset exists, but no Windows hardware was available.

**Tool:** `game/tests/vfx_perf.gd`. It runs the VFX Sandbox (real arena, 3D hero, 3D foe) for 4 s per case.
`VFX_LEGACY=1` runs the pre-refinement polygon ToonFx under the same load. Raw output is in `captures/perf_textured_m1.txt`.

```bash
/Users/oyl-mac_m1/Downloads/Godot.app/Contents/MacOS/Godot --path game --script res://tests/vfx_perf.gd
```

## Results: 3 interleaved runs each, range of means

| Case | Polygon v1 (before) | Textured (current) |
|---|---|---|
| Idle, no effects | 2.7–3.7 ms | 2.7–3.6 ms |
| Realistic turn: 2 auras + 1 crit every 0.3 s | 3.5–6.1 ms | 2.7–3.7 ms |
| 7 auras | 3.3–6.8 ms | 2.7–3.7 ms |
| Worst case: 7 auras + 6 impacts every 0.1 s | 19.3–23.6 ms (42–52 fps) | **3.8–4.9 ms (203–267 fps)** |

Textured effects are **about 4–5× cheaper** in the worst case. The polygon version triangulated every shape on the CPU each
frame; sprites and GPU particles don't. The budget is 16.7 ms per frame: the project chose the Mobile renderer to hold
60 FPS (`docs/development/README.md`).

## Shader compilation (first use)

Every textured layer shader and particle feature set compiles the first time it is used. `ToonFx.prewarm` (called from
`CombatFeedback._ready`) draws both layer shaders and one burst of each particle preset, nearly invisible, at combat
start, behind the title card.

| Run | Worst-case max frame |
|---|---|
| Cold cache, prewarm without particles | 55.5 ms |
| Cold cache, prewarm with particles (run 1) | 108.8 ms: one outlier. Every case in that run, idle included, was slow. |
| Cold cache, prewarm with particles (runs 2 and 3) | 24.4 ms, 19.3 ms |

Two of three cold runs stayed under 25 ms. The outlier run was slow across the board, which points to machine load
rather than compilation, but that isn't proven.

## Notes

- Lifetimes are bounded: one-shots free at `DURATION`. Loops (auras, beam, bolt) are freed by their owners
  (`CombatFeedback.sync_auras`, `play_loot`, `_projectile`). Particle bursts are one-shot children and are freed with the effect.
- Textures: 25 files, 4.4 MB on disk at 512 px.
- No VFX quality levels: the measured cost doesn't call for them on M1. Revisit after measuring Windows or low-end hardware.
- The sandbox HUD shows FPS, frame time, live effects, draw calls and objects from `Performance`. There is no
  per-effect GPU time.
