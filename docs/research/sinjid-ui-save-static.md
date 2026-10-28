# Sinjid UI, input, options, audio and save static audit

Target preserved SWF SHA-256: `e258423f2a5887ff236a67eb6eaf674a8d573a5cdb721c20b79c831da4d9e008`. Static FFdec export plus direct SWF tag decoding. This report complements world/combat/economy reports and does not claim that every menu branch was played. Parent REA run now supplies independent process/decompiler Evidence `ev_2895973c7147bd64e41b588ae68b61c9899e5ec6ad27afab76f72be80b5e49ef`; the snapshot truncated some files, so its limits must remain separate from this static census.

## SWF timeline and startup flow

Direct header decode: 600×470 pixels, 24 fps, 323 root frames. The Archive item metadata's 400×400 dimensions are not the SWF header dimensions. Root input is compressed Flash6 (CWS); the decompressed body retained separately.

| Phase | Timeline / source | Behavior |
| --- | --- | --- |
| Boot | root frames1–2 | Defaults sound On, High quality, tilelock true, hides native Flash menu/focus rectangle. Frame2 loops until all bytes loaded. |
| Written prologue | root frame3 | Long attack-on-village story text with proceed button151. Clicking stops sounds and plays forward. |
| Animated prologue | root frames6–12 | Story scenes with skip button184 on observed frame7–11 placements; skip stops sounds and jumps to title/menu17. |
| Title/menu | root frame17 | Defines global helpers/item/skill/class tables and initializes new-game state; buttons468 start,467 load,466 options,472 return to written prologue. |
| Second story setup | root frame18 | Twenty-years-training explanatory story text484; continue button468 plays to class screen. |
| Class/name selection | root frame19 | Four class buttons512–515 choose starting stat/skill/portrait and play to hub initialization. playername is initialized Sinjid in frame17 and is part of save data. |
| Hub build | root frame20 (`reload`) | Builds grid/character/HUD/talkbox/encounter/inventory, starts Flute track; then room21 Arena0. On combat reload it reapplies saved coordinates/stage. |
| Hub rooms | root frames21–31 | 11 explicit FrameLabels, described in world report. |
| Combat/settlement | root frame labels35–83, victory85, levelup86, SkillPut89 | Encounter definitions and battle scene objects; reward/level-up flow leads to continue. |
| Defeat | root frame90 | Retry-return, load saved game and continue-like handlers exist; not a single automatic full-heal path. |
| Story end | root frame91 then animation until323 | Save/continue or continue without save; ending text/epilogue. |

Sources: [frame_1/DoAction.as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_1/DoAction.as:1>), [frame_2/DoAction.as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_2/DoAction.as:1>), [frame_3/DoAction.as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_3/DoAction.as:1>), [DefineButton2_151/BUTTONCONDACTION on(release).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_151/BUTTONCONDACTION on(release).as:1>), [DefineButton2_184/BUTTONCONDACTION on(release).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_184/BUTTONCONDACTION on(release).as:1>), [DefineButton2_468/BUTTONCONDACTION on(release).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_468/BUTTONCONDACTION on(release).as:1>), [DefineButton2_472/BUTTONCONDACTION on(release).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_472/BUTTONCONDACTION on(release).as:1>), [frame_17/DoAction_3.as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_17/DoAction_3.as:1>), [DefineButton2_512/BUTTONCONDACTION on(release).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_512/BUTTONCONDACTION on(release).as:1>), [frame_20/DoAction_2.as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_20/DoAction_2.as:1>).

Important behavior boundary: executing frame17 resets the new-game globals before a later Load Game action populates saved values. That is not the same as deleting the SharedObject; the save actions explicitly flush persisted data separately. Actual replay after returning to title needs runtime checking.

## Shared UI screen inventory

The main `inventory` MovieClip1458 is a multi-screen UI, not merely a bag. Its binary labels are:

| Frame | Labels / screen role |
| ---: | --- |
| 1 | blanki |
| 2 | Buy, Inventory |
| 3 | Items_0 |
| 4 | Items_1 |
| 5 | Items_2 |
| 6 | Items_3 |
| 7 | Items_5 |
| 8 | Items_4 |
| 9 | Trade |
| 12 | Blacksmith |
| 13 | Skills |
| 14 | SkillPut |
| 16 | Meals, Meal_0 |
| 17 | Save |
| 18 | Books |
| 19 | book |
| 20 | Pots |
| 21 | Heal |
| 22 | Training |

Frame-label existence does not establish menu reachability: `Blacksmith` exists at12, but a bounded literal search of all exported scripts found no direct incoming string reference. Do not promote it to an implemented accessible crafting loop without tracing instance state or observing entry. Likewise Buy/Inventory and Meals/Meal_0 are aliases, not distinct content counts.

Inventory buttons540/541 open Inventory; skills buttons542/543 open Skills. Guards block opening while encounter, talking or pause is active. Opening stops the overworld movement animation, reveals the shared panel and pauses movement. NPC services set `inventorytype` and send the same panel to its matching label. Training portal goes to Training. Sources: [DefineButton2_540/BUTTONCONDACTION on(release).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_540/BUTTONCONDACTION on(release).as:1>), [DefineButton2_542/BUTTONCONDACTION on(release).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_542/BUTTONCONDACTION on(release).as:1>), [frame_29/PlaceObject2_1504_75/CLIPACTIONRECORD onClipEvent(keyDown).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_29/PlaceObject2_1504_75/CLIPACTIONRECORD onClipEvent(keyDown).as:1>).

Close buttons commonly accept mouse release or Space and require the held/dragged item state to be clear; they refresh equipment artwork/HP-MP-energy bars and unpause. Some use only hold, others require itempick==None as well. This is why testing UI close behavior while dragging matters; it is not a generic unconditional dismiss. Sources: [DefineButton2_1291/BUTTONCONDACTION on(release, keyPress Space).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1291/BUTTONCONDACTION on(release, keyPress Space).as:1>), [DefineButton2_1386/BUTTONCONDACTION on(release, keyPress Space).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1386/BUTTONCONDACTION on(release, keyPress Space).as:1>).

Root HUD provides quality toggle, return-to-title and external Infrarift-link buttons. Return-to-title clears scene flags, stops sound and removes transient panels before gotoAndPlay17. No confirmation dialog is visible in that handler. It does not itself call the save handler. Sources: [DefineButton2_1461/BUTTONCONDACTION on(release).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1461/BUTTONCONDACTION on(release).as:1>), [DefineButton2_1462/BUTTONCONDACTION on(release).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1462/BUTTONCONDACTION on(release).as:1>), [DefineButton2_1463/BUTTONCONDACTION on(release).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1463/BUTTONCONDACTION on(release).as:1>).

## Input and UI feedback

| Input | Static behavior | Boundary |
| --- | --- | --- |
| Arrow keys / WASD | Four-direction overworld movement; vertical and horizontal checks can both run in the same frame | Uses collision grid; 6px/frame with energy, 4px/frame empty; diagonal normalization absent in visible controller |
| Space | Near NPC/door/portal interact; many panel close/continue actions; TalkBox animation advance | Requires proximity, pause/talking state and in some doors spacedown key-up debounce |
| Mouse release | Menus, class choice, skill allocation, inventory/equipment, purchases, battle actions/target choices | Most core menu choices are Flash buttons, not an HTML-accessible tree |
| Enter/Space in combo component | Generic built-in FComboBox keyboard behavior | Not evidence that every game menu supports keyboard-only navigation |
| Shift+mouse | Debug collision tile editor gated by tilelock==false | tilelock initializes true and no unlocking assignment was found; not advertised as normal gameplay |

Sources: [frame_20/DoAction_2.as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_20/DoAction_2.as:21>), [frame_20/DoAction_2.as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_20/DoAction_2.as:124>), [frame_20/DoAction_2.as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_20/DoAction_2.as:154>), [DefineSprite_932/frame_2/DoAction.as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_932/frame_2/DoAction.as:1>).

A full exported-script key census found numeric checks for Space32, Enter13 (generic combo), Shift16 (locked editor), arrows37–40 and WASD65/68/83/87. It did not find direct Escape27, I73, controller/gamepad or remapping checks. This is a bounded source finding, not proof that the Flash host cannot add its own bindings.

Feedback includes hover highlights/yellow proximity glow, directional pointer arrows near room-edge exits, combat hit/miss/block/break counters and character states, potion/coin/item/skill sounds, progress bars, inventory item stats and portraits. The world report records NPC hint/knowledge support. The original explicitly sets `_root._focusrect = false`; no modern accessibility semantics, scalable text setting or reduced-motion setting was found. A Godot adaptation should improve those rather than copy the limitation.

## Options and audio

Title Options has two noneditable dropdowns: quality High/Medium/Low maps to Flash `_quality` HIGH/MEDIUM/LOW; sound On/Off controls soundon. Sound Off calls stopAllSounds and clears played; returning On resumes Dream once. Defaults are On/High. These option values are absent from save field lists, so persistent settings are not demonstrated. Sources: [DefineSprite_478/frame_2/PlaceObject2_100_FComboBoxSymbol_3/CLIPACTIONRECORD on(initialize).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_478/frame_2/PlaceObject2_100_FComboBoxSymbol_3/CLIPACTIONRECORD on(initialize).as:1>), [DefineSprite_478/frame_2/PlaceObject2_100_FComboBoxSymbol_3/CLIPACTIONRECORD onClipEvent(enterFrame).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_478/frame_2/PlaceObject2_100_FComboBoxSymbol_3/CLIPACTIONRECORD onClipEvent(enterFrame).as:1>), [DefineSprite_478/frame_2/PlaceObject2_100_FComboBoxSymbol_16/CLIPACTIONRECORD on(initialize).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_478/frame_2/PlaceObject2_100_FComboBoxSymbol_16/CLIPACTIONRECORD on(initialize).as:1>), [DefineSprite_478/frame_2/PlaceObject2_100_FComboBoxSymbol_16/CLIPACTIONRECORD onClipEvent(enterFrame).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_478/frame_2/PlaceObject2_100_FComboBoxSymbol_16/CLIPACTIONRECORD onClipEvent(enterFrame).as:1>).

Audio uses the `soundfx` MovieClip180 timeline: playSound(name) checks soundon then gotoAndPlay(name). Root scene transitions stop previous sounds and choose a new cue. No bus mixer, independent music/SFX levels or volume slider was found. Sources: [frame_3/DoAction.as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_3/DoAction.as:1>), [frame_20/DoAction.as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_20/DoAction.as:1>), [frame_85/DoAction.as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_85/DoAction.as:1>).

Binary labels in MovieClip180: `Dream`, `Flute`, `Orc`, `Over`, `Over2`, `Violin`, `Battle1`, `Battle2`, `Battle3`, `no`, `skillput`, `coins`, `footsteps1`, `howl`, `swordc1`, `swordc2`, `thunder`, `songstart1`, `songstart2`.

Literal playSound calls include names without an exact matching label in this MovieClip, including Battle, itemget, miss, potion, skillup and footsteps2. This is a static candidate mismatch, not an observed silent-cue bug; missing-label Flash behavior and alternative sound paths need runtime checking. The stage may contain ordinary sound tags independently of those helper calls. Complete soundtrack asset rights/identity and audible playback are outside this source audit.

## Full save serialization contract

SharedObject name: `user_profile`. Save uses unversioned arrays plus top-level fields, flushes synchronously from a user action and does not inspect flush success in the visible handler. No schema validation, backup/atomic replacement or migration handling is visible. Source: [frame_17/DoAction_3.as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_17/DoAction_3.as:9>), [DefineButton2_1332/BUTTONCONDACTION on(release).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1332/BUTTONCONDACTION on(release).as:1>).

`user.data.stats` positional order for Elder Save / title Load:

| Index | Variable | Meaning |
| ---: | --- | --- |
| 0 | `strb` | Strength |
| 1 | `speedb` | Speed |
| 2 | `lifemaxb` | Max life |
| 3 | `manamaxb` | Max mana |
| 4 | `expb` | Current experience |
| 5 | `engmaxb` | Max energy |
| 6 | `gold` | Gold |
| 7 | `phydmgb` | Physical damage base/equipped total |
| 8 | `magdmgb` | Magical damage base/equipped total |
| 9 | `phydefb` | Physical defense |
| 10 | `magdefb` | Magical defense |
| 11 | `shdphydefb` | Shield physical defense |
| 12 | `shdmagdefb` | Shield magical defense |
| 13 | `shdptsb` | Shield points |
| 14 | `shddmgb` | Shield damage |
| 15 | `level` | Character level |
| 16 | `playername` | Player name |
| 17 | `newobjective` | Objective field (full quest implementation not established) |
| 18 | `Helmet` | Equipped helmet |
| 19 | `Suit` | Equipped suit |
| 20 | `Weapon` | Equipped weapon |
| 21 | `Shield` | Equipped shield |
| 22 | `manapots` | Mana potion count |
| 23 | `lifepots` | Life potion count |
| 24 | `skillpts` | Unspent skill points |
| 25 | `expmaxb` | Next-level experience threshold |
| 26 | `rests` | Remaining full rests |
| 27 | `ninjaav` | Portrait/character appearance key |
| 28 | `classname` | Displayed class name |
| 29 | `classtype` | Class array key |
| 30 | `moon_q` | Ring-gift flag |

Additional fields:

| Saved field | Content |
| --- | --- |
| `user.data.itemstats` | All current inventory slot entries copied by enumeration; default initializes28 slots |
| `user.data.skill` | All current skill rank entries copied by enumeration; default initializes20 indices |
| `user.data.p1/p2/p3` | Human/Monster/Dark next-stage counters |
| `user.data.life/mana/eng` | Current overworld HP/MP/energy |

Not in these lists: current room/stage/position, battle in-flight state/turn order/target, options sound/quality, inventory drag state, collision tile edits, schema version. Character stats use stored equipment-adjusted totals rather than a clean normalized base-plus-loadout save contract.

There are two variants: Elder Save1332/title Load467 include index30 moon_q; ending Save2257/defeat Load2254 omit it. Main Load uses `user.data.stats[strb] != undefined` as its availability guard, where the initializer sets strb15; it is not a named-field or schema check. Loops copy positional values directly. Sources: [DefineButton2_1332/BUTTONCONDACTION on(release).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1332/BUTTONCONDACTION on(release).as:1>), [DefineButton2_467/BUTTONCONDACTION on(release).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_467/BUTTONCONDACTION on(release).as:1>), [DefineButton2_2257/BUTTONCONDACTION on(release).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_2257/BUTTONCONDACTION on(release).as:1>), [DefineButton2_2254/BUTTONCONDACTION on(release).as](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_2254/BUTTONCONDACTION on(release).as:1>).

The ending save handler calls `_root.inventory.saved.play()` even though the root ending display list no longer necessarily contains that panel; this is another candidate no-op/error depending Flash tolerance, not a verified save failure. Do not infer from it that the following data writes never run.

## Navigation placement data for runtime validation

[sinjid-npc-placements.json](/Users/Projects/Steampunk-warrior/docs/research/sinjid-npc-placements.json) reconstructs root display-list snapshots at26 important frames. Each object has character ID, depth, optional instance name and complete MATRIX (scale/skew/translation). The JSON also includes all61 sprites with FrameLabels and root tag counts. [extract_swf_placements.py](/Users/Projects/Steampunk-warrior/docs/research/extract_swf_placements.py) regenerates it from the local decompressed SWF with assertions on stage dimensions/fps/frame count/room count and unsupported placement tags.

These are static registration-point translations in stage pixels, not runtime hitbox centers. NPC sprites, grid animation and depth swaps can move things later. Initial grid placement is(0.75,1.05). initializeChar(10.5,7) gives local player(300,195), therefore stage approximately(300.75,196.05) before later animation. A hitTest against the character's stepper may require approaching below an NPC/portal registration point.

| Room | Useful initial registration points x,y | Destination / role |
| --- | --- | --- |
| Arena0 | 300,123;491,234;105,173;193,267 | Upstairs exit;Elder;Healer;Student |
| Arena1 | 8,209;592,209;300,309 | Human room;merchant room;entrance |
| Arena2 | 299,166;592,209 | Human portal;back to junction |
| Arena3 | 450,126;8,209;431,300 | Stairs to tavern;back to junction;trade merchant |
| Arena4 | 8,209;418,308 | Upper merchants;back to merchant room |
| Arena5 | 300,124;8,209;592,209 | Shrine;library;tavern |
| Arena6 | 226,267;361,93;592,209 | Lady;library books;back to vendors |
| Arena7 | 592,209;8,209;406,115;300,305 | Training/Monster room;ring-giver/gate;moon;back to vendors |
| Arena8 | 196,124;466,158;8,209 | Training entry;Monster portal;back to shrine |
| Arena9 | 252,217;300,124;592,209 | Ring giver;Dark gate;back to shrine |
| Arena10 | 309,157;300,305 | Dark portal;back to gate room |

## Remaining uncertainty

Startup/title/class flow and some ordinary gameplay are being corroborated separately by parent REA browser captures. This static report does not replace those captures. Exact transient UI animation positions, mouse hit-test geometry, keyboard-only usability, every audio cue, corrupt/full local-storage behavior, save variants and every game-over choice have not all been exercised here. No new game code or assets were implemented.


## Runtime corroboration — 2026-10-27

This report records static reconstruction. Subsequent representative runtime results, including their controlled fixtures, exact REA Evidence IDs and unresolved limits, are summarized in [runtime coverage](runtime-coverage.md). Earlier statements that runtime was pending describe this report’s original inspection time; they are not the final project coverage status. No exhaustive playthrough is implied.
