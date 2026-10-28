Current release:0.1.1. The user-reported keyboard room-transition defect in0.1.0is fixed and separately verified; see [hotfix evidence](0.1.1-transition-hotfix.md). Prior0.1.0acceptance below is historical and did not cover that input path.

# Steampunk Warrior0.1.0 — desktop acceptance

Verified2026-10-28,Asia/Bangkok. Godot4.7.2.stable.official.ed1daf0bf. This is the full original Thai offline game scope approved by the user, not the earlier slice.

## Content and behavior

|Requirement|Delivered|Evidence|
|---|---:|---|
|Classes|5|Five fresh earned campaign simulations|
|Learned skills|22(19active,3passive)|Every node/rank1–10; shared execution/preview math|
|Bosses|6|Distinct patterns,root helper,heat,memory sequence,three final phases|
|Walkable rooms|12|120layout checks; reachable markers and96px primary route clearance|
|Obtainable gear|62|208acquisition/training checks; actual source transaction,equip,visible stats/icons|
|Training tiers|4|Actual controller actions; partial and repeat XP claims|
|Encounters/quests/endings|36/8/3|Earned campaign branches; rescue bypass; irreversible harvest; witness aftermath|

Full suite:1,136passed,0failed. Five campaigns finish atlevel23 without required repeat farming. Rounds/currency: C01=220/3245,C02=221/3145,C03=283/3365,C04=304/3485,C05=226/3565. C03takes the optional rescue bypass. These are automated decision policies, not five human playthroughs or proof that every possible build is equally strong.

Native AppleM1/OpenGL4.1 checks:15controls checks,12playable UI/physics checks,feedback-only state invariance,overflow notification,3music tracks+8effects with mixed-PCM verification,ducking and independent mutes.18final interface captures across960×540/1280×720/1920×1080;12room+6boss+impact render fixtures. Fixtures are labelled separately from naturally earned campaign evidence.

`content-completion.csv` lists177stable content IDs and exact evidence. Artwork prompt/hash records in docs/development/art/. No final actor sprite is a greybox; native SVG icons/props intentionally share visual families.

## Actual macOS executable

Exported universal app,ad-hoc signature verified with codesign. Opened the exported executable outside the editor through normal UI: NewGame→C01→walk→manual01save→quit→relaunch→Continue. Loaded a separately validated C03level23save earned by the campaign test; the release app offered all3endings. Selected Cure; Thai ending and witness epilogue rendered, returned toR11. Persisted autosave confirmed Cure/postgame/R11/W26/level23. QA-created normal saves were archived privately; the originally empty normal profile was restored.

The release template ignores the external `--script` test-driver attempt; that attempt is not counted as a passing release test. Native release verification used actual mouse/keyboard actions. Packed audio/resource checks additionally used the final PCK with the matching engine.

Actual final PCK audit:118files; all runtime catalog counts and license files present; no tests,builds,research orSWF. Final macOS and Windows data packs are built from the same reviewed source. Hashes in SHA256SUMS.txt and content-hashes.json.

## Platform limits

- macOS tested on AppleM1. Universal Intel executable is included but not independently run on an Intel Mac.
- macOS app has ad-hoc signing; no Apple DeveloperID/notarization or public-store submission.
- Windows x86_64 `.exe`+`.pck` export succeeds with official matching templates. No Windows machine was available; window/fullscreen/input/audio/backup behavior on Windows is unverified. Do not label it Windows-certified.
- No Steam/itch/public upload occurred.

## Final independent review

One fresh read-only whole-game review. No Critical defect. Reproduced and fixed both Important findings: harvest warning priority and modal focus escape. Regraded overflow-notice loss,unreachable harvest aftermath and absent witness epilogue as Important because they hide earned gear or promised choice consequences. All reproduced RED before fixes; story,focus and overflow smoke are GREEN,followed by full1,136-check regression. No deferred reviewer findings remain. Shutdown QA waits for audio teardown; abrupt-test-exit resource warnings are not counted as passing clean verification.

## Decisions and costs if wrong

1. Work inside new game/ in the supplied project; no Git repository existed. No unsolicited Git initialization,worktree,commit or PR. Research preserved. Cost: no commit-based rollback; ledger and files retained.
2. Use the verified installed4.7.2engine. Only Web templates were initially present; official missing desktop templates fetched by HTTPS range,ZIP CRC checked,and installed without overwriting existing templates. Cost: builds depend on this pinned engine/templates.
3. Leveling raises maxima but does not silently heal or reset expedition energy; free hub rest does. Starter gearW01/D01/H01/A01,currency75,potions5each. Cost: players must plan explicit rests; earned campaigns verify viability.
4. Training supplies temporary loaner resources/skills; canonical HP/FP/skills never inherit them. Per-objective first claims persist. Cost: practice stats differ from the player's actual build; UI labels the loans.
5. Native scenes are composed by focused scripts rather than empty per-room scene wrappers. Twelve static layouts and content IDs own room variation. Cost: visual layout edits currently use source data instead of individual scene editors.
6. Actor sheets did not obey equal grid gutters. Preserve PNGs unchanged and isolate silhouettes with engine alpha polygons/measured regions. City music serves hub and exploration; NPCs and icons share approved families. Cost: additional atlas layout/art variants require region QA; no promise of62separate outfit meshes or38rigged actors.
7. Final local build is ad-hoc signed; Windows export is supplied with explicit runtime limits. Cost: distribution to other machines needs further platform verification/signing.
8. No Git branch finishing menu applies; retain the SDD ledger because there is no Git history to replace it. Cost: progress history remains a local document.
