# Development record

User approved the expanded design and starting full implementation on2026-10-27. Scope remains5classes/22skills/6bosses/12rooms/62gear/4training,plus the approved spec/plan. Caveman affects chat wording only.

Engine pinned: `4.7.2.stable.official.ed1daf0bf`. Existing binary: `/Users/oyl-mac_m1/Downloads/Godot.app/Contents/MacOS/Godot`. Existing export templates: `4.7.2.stable`.

Project: [game/project.godot](../../game/project.godot). Open with Godot or run binary with `--path /Users/Projects/Steampunk-warrior/game`.

Checks:

- Domain suites: `Godot --headless --path game --script res://tests/run_tests.gd`
- Playable UI/physics smoke: `Godot --headless --path game --script res://tests/smoke_playable.gd`
- Real renderer plus captures: `Godot --path game --script res://tests/smoke_playable.gd`

Use the verified absolute binary path in place of `Godot`. Latest logs live in `logs/development/`. Captures are real AppleM1/OpenGL viewport images under `docs/development/screenshots/`,not generated mockups. UI smoke drives actual button signals and physics InputMap; marker positioning is a controlled fixture,not an unaided human playthrough.

The project has no Git repository. Implementation is isolated in new game/; research data is not included in the game. Detailed resumable ledger: `.superpowers/sdd/2026-10-27-steampunk-warrior/progress.md`.

Planning `docs/design/verify_plan.py` is a historical planning-before-product check and deliberately asserts that a game project did not exist at that time. It is not the post-approval runtime test command.

Current stage: task6 slice,not full release. Full campaign/productionart/audio/save/release gates remain active; do not count this slice as the finished goal.


## Full desktop build,2026-10-28

Full game delivered atgame/builds/macos/SteampunkWarrior.zip;Windows export atgame/builds/windows/SteampunkWarrior-Windows.zip(runtime unverified). Final suite1136/1136;native controls15/15,playable12/12,actual release NewGame/save/relaunch/ending/postgame observed. Canonical evidence,decisions and platform limits:docs/release/desktop-checklist.md. Existing historical slice notes above are superseded by that acceptance report.

## Hub pipes and combat stage slice, 2026-11-03

First slice of the reference-feel pass from `docs/research/2026-10-28-visual-feel-rea.md`: R01 is now an oblique hub with three painted pipe mouths (R02 market, P01 drain line, P02 rail line). Lines live in `rooms.json` R01 `pipes`; each line's progress is derived from `first_clears`, P02 opens after E03, and a cleared line replays its last normal fight. Walking into a pipe plays the entry (rim overlay, steam, fade) before the scene changes. Combat is a shared-ground stage over an arena backdrop: melee moves dash to the target, numbers/sound/bars land on contact, ranged skills fire a bolt. Every encounter has two `drops` candidates; the first clear awards one, shown as loot on the stage and in the result modal.

Backdrops are rendered by `prototypes/environments/build_backdrops.py` (headless Blender) into `game/art/environments/{hub,hub_rims,arena_canal,arena_rail}.png`. Slice captures: `CAPTURE_DIR=<dir> Godot --path game --script res://tests/capture_slice.gd`.

Follow-up the same day: every room R02–R12 is now an oblique painted room (`room_Rxx.png` + `_rims.png`). Exits sit at the left/right pipe mouths, fast travel uses the centre tram pipe, dead ends show a bolted hatch, and valves are the painted wheels by the pipes. Marker slots and the two prop obstacles per room come from `game/data/room_props.json`, which both `RoomLayout.oblique_walls` and the Blender builder read. Arenas exist per palette (canal, rail, garden, coal, foundry, archive, reactor); hub fights and training use rail. `capture_rooms.gd` captures every room and one enemy turn per arena theme.

Still open: props are baked into the backdrop, so the hero walking behind a prop draws over it (markers avoid those spots); enemies remain 2D art beside the 3D hero; R02 market has no shop-stall interaction beyond the existing shop marker.

## 3D roster and icon-first PC UI, 2026-11-03

- Every NPC, foe and interactive prop is 3D (`game/art/roster_3d.gd`): people are Vesper rig variants (`Hero3D.apply_variant`), mutants/props are procedural toon kits (`creature_3d.gd`), except mutants N01-N09 (rat, dog, bat, centipede, beetle, spider, boar, heron, wolf) and bosses B01 croc / B03 deer, which load `art/characters/<kind>.glb` built by `prototypes/character-lab/blender/build_<kind>.py` (shared helpers in `creature_kit.py`) (`Creature3D._load_figure` toons it and drives the named `Leg_*`/`Tail`/`Wing_*` pivots), all on `Stage3D`, which renders at physical resolution. `capture_roster.gd` makes a contact sheet.
- Renderer switched from Compatibility to Mobile: with ~7 figure viewports Compatibility ran ~15 FPS in R07, Mobile holds the 60 FPS vsync cap. Export presets are macOS/Windows only.
- World and combat are full-screen; HUD, tools and commands float as icon buttons. Words live in tooltips, the combat info line (hover or keyboard focus) and badges that name an interactable only when the hero is close. The world camera pans with the hero.
- PC hotkeys, shown as corner tags: world I/K/J/F5/O/L; combat 1–0 skills, Z X C V B N basic commands, M ends training. A hotkey is skipped if it collides with a movement/interact binding.
