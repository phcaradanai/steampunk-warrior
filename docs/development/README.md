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
