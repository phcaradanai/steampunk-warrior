# VFX reference board

Visited on 2026-11-04 in the in-app browser. **What was actually accessible is stated per source.** Nothing was copied.
Only principles were taken and re-implemented in original code-drawn Godot effects.

| # | Source | Accessible content | Principles taken | Where applied |
|---|---|---|---|---|
| 1 | https://www.riotgames.com/en/artedu/visual-effects | Page text only. The episode video was **not** watched. | VFX artists must exercise restraint so players can follow the action; balance satisfaction with gameplay clarity; each effect must represent its action or state and belong to its source; harmonise a whole kit and roster. | Flash cut from ×2.6 to ×1.6; shake tiered by importance; face and number rule; status auras redesigned as readable state; tint carries the source skill. |
| 2 | https://realtimevfx.com/t/hovl-s-sketchbook/6983 | Thread text. On the second visit the images were **inspected** by opening their URLs directly: the first post's lightning strike, an ice-crystal strike, and fire impacts with embers (GIF, first frame). | A reply in the thread: "variation can make a good effect great", by mixing longer and shorter legs. Trails built as their own pass; post-processing judged by comparison. | Per-ray length/width variation in impacts, longer spikes in the hit direction; slash wake as a separate head/tail sweep. |
| 3 | https://realtimevfx.com/t/crystal-rose-aurelion-fan-art-breakdown/31934 | Breakdown text. Images and video **not** inspected. | Smoke shaped with a dissolve on an added texture instead of fading; distortion used sparingly for impact; layered parts per ability. | Noise-erosion exit for slashes, flames and smoke (`combat/vfx_layer.gdshaderinc`). No distortion yet. |
| 4 | https://www.vfxapprentice.com/students | Page text plus **still thumbnails** of the 2D FX section, one frame each, not animated. | Hand-drawn 2D fire uses 3 value bands (dark red outer, orange, yellow core) with tapered, curling tongues; liquid gets small white highlights; abstract impacts use chunky shapes with negative space. | Fire and Heated flames now have 3 bands; acid bubbles get a highlight arc; ink-star impact frame (chunky dark shape). |
| 5 | https://github.com/Unity-Technologies/VisualEffectGraph-Samples | README text. | The sample viewer pattern: a navigation menu of isolated samples, an FPS counter toggle, take-screenshot, demo mode. | VFX Sandbox: library tree, FPS/frame/draw-call HUD, screenshot, loop mode. |
| 6 | https://dev.epicgames.com/documentation/unreal-engine/content-examples-sample-project-for-unreal-engine | Doc text. | Content Examples: one concept per numbered stand, interactive, editable, reusable. | Sandbox: one effect per entry, played on demand, preset parameters editable and saved back for gameplay. |
| 7 | https://godotshaders.com/shader/ | Listing text. The "Dissolve with Glowing Edge" detail page **timed out**. | Dissolve with an edge treatment is a standard Godot technique; "2D outline with gap" and "Procedural Magic Circle" are canvas-item references. | Erosion written from scratch (value noise in local space, outline eroded first, lightened fill edge). No glowing edge, per the no-glow rule. |

## Gaps

- The brief asked for **3 animated examples per category**. That was not met: animated media did not load (2, 3), was a video
  (1), or was a still thumbnail (4). The timing principles therefore come from the text and from this game's own captures,
  not from watching reference animation.
- Choosing which references bind the visual direction is the human art director's call. This board is a starting point.

## Reference 1 (Hovl) as the target, chosen by the user on 2026-11-04

What the inspected images show, and how the game now matches it:
- **Bright core + coloured halo + bloom:** additive layers with HDR gain and canvas glow.
- **Branching lightning with secondary arcs on the ground:** Blender-rendered bolt and arc flipbooks, a flickering re-strike.
- **Painted shapes that dissolve:** Codex-painted textures with noise erosion.
- **Embers and sparks thrown off impacts:** GPU particles.
- **Not matched:** Hovl's full-screen chromatic aberration and the dramatic scene lighting (sky vortex, environment lit blue).
  These are post-processing and lighting on a 3D scene; this game is 2D arenas with 3D figures in sub-viewports.
