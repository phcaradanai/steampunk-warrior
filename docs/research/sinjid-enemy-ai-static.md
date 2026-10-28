# Sinjid 2004: complete static enemy controller audit

Source identity: SWF SHA-256 `e258423f2a5887ff236a67eb6eaf674a8d573a5cdb721c20b79c831da4d9e008`, header version6. Evidence here is FFdec ActionScript export plus direct SWF FrameLabel/PlaceObject2/RemoveObject2 decoding, **not REA Evidence or runtime observation**.

Read together with [combat formulas](/Users/Projects/Steampunk-warrior/docs/research/sinjid-skills-combat-static.md), [world inventory](/Users/Projects/Steampunk-warrior/docs/research/sinjid-world-inventory.json) and [full enemy controller JSON](/Users/Projects/Steampunk-warrior/docs/research/sinjid-enemy-ai-static.json). JSON retains each actor's load/turn source, exact code, root frame, placement depth, inherited handler frame, action labels, child sprite bindings and effect callbacks.

## Coverage and inherited controllers

The 40 encoded combat frames are 35 portal stages, 3 training tiers and 2 additional wasp encounters. They contain 50 distinct living enemy slots and 51 retained enemy-controller instances; WASP2 has a duplicate enemy2 controller. The roster has 26 displayed-name variants if Wasp and Poison Wasp are counted separately; these share avatar family2061. There are 34 archetype/move-set variants. Do not count HP-zero placeholder enemies as combatants.

Inventorying only scripts local to each encounter frame misses real behavior. SWF timeline display-list reconstruction establishes:

- MONSTER5/frame41 retains frame40 humanoid controllers for Skeleton and Undead.
- MONSTER7/frame42 replaces enemy1 with Skeleton Mage but retains the humanoid Skeleton enemy2 controller from frame40.
- MONSTER10/frame70 retains frame69 controller for Flesh Fiend.
- DARK4/frame75 retains frame74 controller for Anti Ninja.

Their move lists must not be guessed from enemy names. JSON records the supplying handler_frame and path for every controller.

## AI decision rules

In all audited encounter turn handlers, a living queued enemy chooses `attacks[random(numofmoves)]`, then sets midfight and advances turnnum modulo4. Every current move list contains unique labels, so each listed move has probability1/list length. No health-based move selection, mana spending, cooldown, scripted phase transition or foresight/telegraph is present in these handlers. Enemy healing can be chosen at full health and waste a turn.

If hero2 is alive, most handlers choose hero1 or hero2 with random(2)+1 before choosing the move; otherwise they target hero1. Exceptions: the additional WASP/WASP2 controllers directly use the existing enemytarget without resetting it. Dead enemy slots advance without acting. This is shared queue logic, not real-time chasing or pathfinding.

Representative source: [frame35 enemy2 turn](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_35/PlaceObject2_1909_29/CLIPACTIONRECORD onClipEvent(enterFrame).as:2>); a syntactically different but equivalent target-choice implementation is [frame67 Naga turn](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_67/PlaceObject2_2041_32/CLIPACTIONRECORD onClipEvent(enterFrame).as:2>). JSON retains every variation, not just this representative.

## Complete stage-to-move catalog

Notation: `A`=attack, `H`=heallife, `e0`…`e7`=Skille0…Skille7. Each entry is a separate equal-probability option, not a sequence. `E1/E2` refer to enemy slot. Source trace for each row is in the JSON.

| Archetype / variant | Encounter IDs | Moves |
| --- | --- | --- |
| Thief |HUMAN1;HUMAN4 E2|A|
| Bandit |HUMAN2;HUMAN4 E1|A,e0|
| Raider |HUMAN3;HUMAN7 E1|A,e2|
| Warrior |HUMAN5;HUMAN7 E2;HUMAN10 E2|A,e0,e2|
| Seer early |HUMAN6;HUMAN10 E1|A,e1,H|
| Mercenary |HUMAN8;HUMAN11 E1|A,e0,e1,e2,H|
| Assailant |HUMAN9;HUMAN11 E2;HUMAN15|A,e2|
| Agent early |HUMAN12|A,e0,e1,e2,e3,e4,H|
| Seer late |HUMAN13|A,e0,e1,H|
| Shaman early |HUMAN14|A,e1,e2,H|
| Ronin |HUMAN16;HUMAN19 E1|A,e0,e2,e4,e5,H|
| Agent late |HUMAN17|A,e0,e1,e2,e3,e4,e5,H|
| Samurai early |HUMAN18|A,e0,e2,e4,e5,H|
| Shaman late |HUMAN19 E2|A,e1,e3,H|
| Samurai pair |HUMAN20 E1+E2|A,e0,e2,e4|
| Poison Wasp |MONSTER1|attack,attack2|
| Undead early |MONSTER2|A,e2|
| Skeleton Mage |MONSTER3;MONSTER7 E1|attack1,attack2,heal|
| Mountain Naga |MONSTER4;MONSTER8 E2|attack2,attack|
| Skeleton |MONSTER5 E1;MONSTER7 E2|A,e0,e2,e4|
| Undead paired |MONSTER5 E2|A,e0,e2,e4|
| Golem early |MONSTER6|A,e0,e2|
| Golem paired |MONSTER8 E1|A,e0,e2,e4|
| Semi Demon |MONSTER9|A,e0,e2,e3,e4,e5|
| Flesh Fiend |MONSTER10|A,e0,e2,e3,e4,e5|
| Liquid Metal |DARK1|A,e0,e4,e2|
| Blood Spirit |DARK2|attack,ice,fire|
| Fallen Guardian |DARK3|A,e0,e4,e2|
| Anti Ninja |DARK4|A,e0,e4,e2|
| Shadow Reaper |DARK5|e6,e7|
| Training Ward basic |TRAIN1|attack,none,heal|
| Training Ward intermediate |TRAIN2|attack,none,heal,ice|
| Training Ward advanced |TRAIN3|attack,none,heal,ice,fire|
| Additional Wasp |WASP E1;WASP2 E1+E2|attack|

## All selected move signatures

Use damage tuple `(A,B,cannot_miss,C,D,accuracy,R)` from combat report: A is effective magical; B effective physical; C bypasses shield defense; D is strength-based physical; R is additive random damage. P/M/S/V/Q are raw actor phydmg/magdmg/str/speed/shddmg. Each listed hit invokes the shared damage/accuracy callback independently.

### Humanoid family1909 (humans, many monsters, four Rift bosses)

Exact frame-label bindings from SWF: attack→sprite1825; heallife→1821; Skille0→1901; Skille1→1899; Skille2→1900; Skille3→1902; Skille4→1904; Skille5→1906; Skille6→1907; Skille7→1908.

| Action | Actual effect | Source |
| --- | --- | --- |
| A |(P,M,false,Q,S,V,random(P/3)); one hit, without player's Inner Strength bonus|sprite1825/frame30/DoAction.as:7|
| H |Heal 4×portallevel[0], capped to maximum; depends on HUMAN portal progress even when another portal's enemy uses it|sprite1821/frame11/DoAction_2.as:7|
| e0 |(P+5,M,false,Q,S,V,random(P/3)+random(5))|sprite1901/frame33/DoAction.as:1|
| e1 |(0,M+10,false,Q,S,V+10,random(P/3))|sprite1899/frame25/DoAction.as:1|
| e2 |(1.5P,M,false,Q,S,V+3,random(P/3))|sprite1900/frame30/DoAction.as:1|
| e3 |(0,M+15,false,Q,S,V+10,random(P/3))|sprite1902/frame23/DoAction.as:1|
| e4 |(P+10,0,false,Q,S,V,random(P/3))|sprite1904/frame27/DoAction.as:1|
| e5 |(2P,M,false,Q,S,V,random(P/3))|sprite1906/frame33/DoAction.as:1|
| e6 |A=target current life; B=0; dodgeable; C=999; D=0; accuracyV; R=0|sprite1907/frame50/DoAction.as:1|
| e7 |(25,0,true,0,0,V,0), then heals self 30|sprite1908/frame16/DoAction.as:1 and frame23:1|

There is no player-style mana deduction before these enemy actions. Textures/equipment appearance do not replace the encounter's explicit stat values.

### Skeleton Mage family2010

- attack1→sprite2002/frame22: normal tuple(P,M,false,Q,S,V,random(P/3)).
- attack2→sprite2003/frame41: (0,M+20,false,Q,S,V+10,random(P/3)).
- heal→sprite2004/frame5: heal 95, capped to maximum.

### Mountain Naga family2041

- attack→sprite2023/frame15 and attack2→sprite2025/frame9 both pass the same six arguments(P,M,false,Q,S,V), one hit each. The seventh random-additive argument is omitted; do not silently substitute a random value. Numeric conversion of undefined in this SWF6/runtime requires corroboration.

### Wasp family2061

- attack→sprite2056/frame21 and attack2→sprite2057/frame14 also use identical six-argument(P,M,false,Q,S,V) callbacks, one hit each. They differ in animation timing, not an established poison status effect.

### Blood Spirit family2100

- attack→sprite2080/frame26: (P,M,true,Q,S,V,random(P/3)); one hit.
- ice→sprite2082/frame38: same forced-hit tuple; **one direct damage callback**, not two in this export.
- fire→sprite2083/frames32,50,78: same forced-hit tuple three times.
- Avatar has a heal label→sprite2099/frame5 for heal 300, but DARK2's action list does **not** select it. Do not count an encoded but unselected animation as a reachable boss move without another callsite.

### Training Ward family2124

- attack→sprite2104/frame26: forced-hit tuple(P,M,true,Q,S,V,random(P/3)), one hit.
- ice→sprite2105/frames26,34: same tuple twice.
- fire→sprite2106/frames32,50,78: same tuple three times.
- none→sprite2122: waits, toggles playerturn and releases midfight; no damage callback.
- heal→sprite2123/frame5: heal 300, capped to maximum.

All paths above are under `reference/sinjid/decompiled/scripts/DefineSprite_<ID>/frame_<N>/`. JSON supplies full paths and callback code for every action occurrence. Sprite action-frame completion releases midfight; frame counts are not claimed wall-clock durations.

## Five Rift bosses: actual differentiation

| Boss | Life / shield /speed | Body physical /magical defense | Static tactical identity |
| --- | --- | --- | --- |
| Liquid Metal |3000/350/27|70/20|High physical mitigation; four ordinary humanoid options|
| Blood Spirit |1800/4000/35|0/65|Very large shield; forced-hit attacks including triple hit; three uniformly random options|
| Fallen Guardian |4000/2300/38|40/40|Large life and shield; four ordinary humanoid options|
| Anti Ninja |4000/0/80|0/0|High speed and no active shield; inherited four-action controller, not an independently scripted phase machine|
| Shadow Reaper |1000/0/60|85/85|50% current-life-based shield breaker;50% unavoidable 25 plus self-heal 30|

Stats are frame72–76 `DoAction.as`. Defense percentages interact with the actual callback parameter reversal; e.g. nominal physical P attacks often deal magical-component damage. No health-threshold phase logic was found in these stage initializers, their selected attack callbacks or their actor turn handlers. Distinct bosses here primarily mean stat profiles and move repertoires.

## Additional WASP2 controller ambiguity

Direct root timeline reconstruction shows frame83 retains sprite2061 at depth29 from frame49 with instance name enemy2, and places another sprite2061 at depth34 with the same enemy2 name. Both have an enterFrame handler and mcname2="enemy2". Frame82's enemy1 at depth39 remains. The JSON preserves both controller instances rather than hiding one.

The effect of duplicate instance lookup and enterFrame scheduling in the actual AVM1 runtime is unresolved. Unique combat slots remain E1+E2; this is not evidence of three distinct enemies. Validate this edge case in runtime before claiming all encounter behavior confirmed.

## Menu, input, options and audio gap check

- Directional sprite909 frame1 enterFrame explicitly accepts arrows and WASD and pauses direction updates when root.pause is true. Horizontal facing takes priority over vertical facing when keys overlap. This facing handler alone does not prove diagonal movement rules; collision/movement script is in world audit.
- Interaction handlers check Space(32) and conditions such as pause/talking/meet/clearstage, with keyUp resetting the one-press latch. Example frame22/PlaceObject2_1599_216 keyDown lines2–4.
- Inventory buttons540/541 and Skills buttons542/543 require no encounter/no conversation/no pause, stop movement, show inventory panel and set pause. Combat choices are mouse release buttons; Space confirms many conversation/result screens. No key-rebinding or controller mapping was found in these game-specific input handlers.
- Options sprite478 uses noneditable dropdowns: High/Medium/Low maps to HIGH/MEDIUM/LOW renderer quality; Sound On/Off controls root.soundon. The corresponding initialize/enterFrame scripts retain selection indices, stop all sounds when Off and restart Dream when enabled. No separate music/SFX volume sliders in that options block.
- Root frame1 hides Flash context menu and focus rectangle. Root frame3 playSound(name) dispatches to soundfx.gotoAndPlay(name) only if soundon==On. Discrete audio call names found in `.as`: Battle,Dream,Flute,Orc,Over,Over2,Violin,coins,footsteps1,footsteps2,howl,itemget,miss,no,potion,skillup,songstart1,songstart2,swordc1,swordc2,thunder. These are call labels, not a verified inventory of distinct sound files.

Sources: [facing input](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_909/frame_1/PlaceObject2_908_2/CLIPACTIONRECORD onClipEvent(enterFrame).as:2>), [quality options](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_478/frame_2/PlaceObject2_100_FComboBoxSymbol_3/CLIPACTIONRECORD on(initialize).as:2>), [sound options](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_478/frame_2/PlaceObject2_100_FComboBoxSymbol_16/CLIPACTIONRECORD onClipEvent(enterFrame).as:2>), [sound dispatch](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_3/DoAction.as:1).

## Completion boundary

Static catalogs now cover every living enemy slot/controller in all 40 encoded encounter frames and every action label selected by those controllers, including inherited handlers and extra wasp encounters. Parsing/assertions verified that each encounter has actors and every selected label resolves to a sprite frame. Runtime execution of all stages, omitted-argument semantics, duplicate WASP2 controller and timeline event order are not established by this catalog. Audio playback quality and input usability remain untested.


## Runtime corroboration — 2026-10-27

This report records static reconstruction. Subsequent representative runtime results, including their controlled fixtures, exact REA Evidence IDs and unresolved limits, are summarized in [runtime coverage](runtime-coverage.md). Earlier statements that runtime was pending describe this report’s original inspection time; they are not the final project coverage status. No exhaustive playthrough is implied.
