# Sinjid 2004: skills, classes and combat — static findings

Analyzed export: `reference/sinjid/decompiled/scripts` and `texts`, produced by FFdec from SWF SHA-256 `e258423f2a5887ff236a67eb6eaf674a8d573a5cdb721c20b79c831da4d9e008`.

Authority: direct reading of FFdec ActionScript export through shell, **not REA Evidence and not observed gameplay**. Parent investigation is responsible for joining this export to REA artifact identity. Paths/line numbers below refer to this retained export. No game implementation changed.

## Exhaustive player skill catalog

19 usable learned nodes, indices 0–18; the initializer allocates 20 entries, so array length 20 does not imply 20 skills. All 19 learning buttons spend one skill point per rank and require rank<10. The second set of skill-tree buttons `DefineButton2_2207` through `2225` supplies the guards below. Complete guards, costs and active effect callbacks are retained in [machine-readable catalog](/Users/Projects/Steampunk-warrior/docs/research/sinjid-skills-static.json).

Names independently match text IDs 1182–1274. `P`, `M`, `S`, `V`, `Q` mean the actor's variables `phydmg`, `magdmg`, `str`, `speed`, `shddmg`; `rN` is rank at skill index N. Damage callback tuple is **(magical component A, physical component B, cannot-miss, extra shield damage C, strength component D, accuracy speed, random additive)**. Many callers put nominal physical values in A and nominal magical values in B, so applying the UI's descriptions literally gives the wrong damage type.

| ID | Skill | Type | Minimum / predecessors | Mana gate / spent | Actual callback/effect |
| --- | --- | --- | --- | --- | --- |
| 0 | Stab | offense | 1 / none | 15 /15 | A=P+5r10+4r0; B=M; C=Q; D=S; accuracy V; random(P/3)+random(10); one hit |
| 1 | Shurikens | offense | 1 / none |20 /20| Both living enemy slots, one hit each: A=0; B=M+15+7r1+7r8; enemy1 C=D=0; enemy2 C=Q,D=S; accuracy V; random(P/3)+random(5) |
| 2 | Double Strike | offense |1 /0|20 /20| Two hits: q=.52+.08r2; A=Pq+5r10; B=Mq; C=Q(.62+.08r1); D=Sq; V; random(P/3) |
| 3 | Speed Strike | offense |1 /0|20 /20| A=P+.6r3×hero1speed+5r10; B=M; C=Q; D=S; cannot miss; passed accuracy V+7; random(P/3)+random(5) |
| 4 | Energy Shot | offense |1 /1|25 /25| A=0; B=M+40+9r4+7r8; C=D=0; accuracy V+5; random(P/3) |
| 5 | Blast Fire | offense |1 /1|25 /25| Two hits on each living enemy slot: A=0; B=M+7+5r5+7r8; C=D=0; accuracy V+5; random(P/3)+random(5) |
| 6 | Vertical Strike | offense |1 /2|20 /20| A=P+5r10; B=M; C=Q; D=S(1+.8r6); accuracy V−2; random(P/3)+random(5) |
| 7 | Shadow Blend | passive |1 /3|—| Battle initialization sets hero1 speed=speedb+2r7 |
| 8 | Energy Field | passive |1 /4|—| +7r8 to B of skills1,4,5,15,16 |
| 9 | Charge | support |1 /4|0 /0| Restore round(25r9) mana; cap at maximum |
| 10 | Inner Strength | passive |5 /6|—| +5r10 to A of basic Attack and skills0,2,3,6,13,14,17 |
| 11 | Mana Bomb | offense |5 /8|1 /all| A=0; B=current mana×(.7+.8r11); C=D=0; accuracy V; random(P/3)+random(5); then sets hero1mana=0; button does not subtract1 |
| 12 | Heal | support |5 /9|15 /15| Restore round(max life×(.13+.12r12)); cap at maximum |
| 13 | Avenger | offense |10 /10|25 /25| A=P+5r10+(r13+1)(max life−life); B=M; C=Q; D=S; V; random(P/3)+random(10) |
| 14 | Split | offense |10 /10|25 /25| A=P+5r10+target current life×(.10+.02r14); B=M; C=Q; D=S; V; random(P/3)+random(10) |
| 15 | Shadow Strike | offense |10 /7 AND11|40 /40| A=0; B=M+60+25r1+7r8; C=D=0; cannot miss; random(P/3)+random(5) |
| 16 | Annihilate | offense |10 /5 AND12|60 /60| Up to three hits on selected target, subsequent hits guarded target life>0: A=0; B=M+15+7r1+7r8; C=D=0; V; random(P/3)+random(5) |
| 17 | Execution | offense |15 /13 AND14|70 /70| Up to four hits: A=P(.60+.05r17)+5r10; B=M; C=Q; D=S; V; random(P/3)+random(10); subsequent hits check target life |
| 18 | Shadow Replicate | support |15 /15|100 /100| Spawn/reset hero2 life=max=70+30r18; P=M=13+12r18; speed=hero1speed+4r18; shadow auto-attacks |

The active battle buttons additionally require the player's queued turn, `midfight==false`, learned skill, nonempty Weapon, and at least one living enemy. All learned actives are available as battle UI buttons; no four-slot loadout restriction found. No per-skill cooldown counter found in the 19 learning guards, 16 player action handlers or active effect callbacks. This is bounded static coverage, not proof that every timeline visual state behaves correctly.

Skill prerequisite/cost citations: [Stab learning](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_2208/BUTTONCONDACTION%20on(release).as:2), [two-predecessor Shadow Strike](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_2221/BUTTONCONDACTION on(release).as:2>), [Execution level gate](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_2219/BUTTONCONDACTION on(rollOver).as:3>), [Mana Bomb no upfront subtraction](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1948/BUTTONCONDACTION on(release).as:2>).

Effect citations (each file's first executable line): Stab sprite1836 frame33; Shurikens sprite1862 frame18; Double Strike sprite1843 frames26/38; Speed Strike sprite1845 frame23; Energy Shot sprite1878 frame25; Blast Fire sprite1880 frames17/26; Vertical Strike sprite1847 frame49; Charge sprite1882 frame11 DoAction_2; Heal sprite1881 frame11 DoAction_2; Avenger sprite1848 frame35; Split sprite1851 frame66; Mana Bomb sprite1885 frame27; Shadow Strike sprite1887 frame24; Annihilate sprite1896 frames16/25/36; Execution sprite1849 frames28/38/44/49; Shadow Replicate sprite1898 frame14. The JSON contains their complete paths and exact callback text.

## Four class definitions and starting state

Class-specific buttons mutate common initial state; damage columns below are final stat variables after those mutations, including initialized starter weapon damage. These are raw variables, not corrected UI damage types.

| Class | Start life /mana /strength /speed | P/M | physical/magical defense | Starter / weapon | Chosen level boost life,mana,strength,speed |
| --- | --- | --- | --- | --- | --- |
| Balanced |75/75/15/15|8/2|3/2|Shurikens / Iron Knife|10,10,2,2|
| Warrior |85/65/17/13|10/0|5/0|Stab / Iron Knife|15,5,3,1|
| Spell Caster |75/90/15/13|0/10|0/5|Charge / Energy Knife|10,15,1,2|
| Shadow Ninja |70/80/13/17|8/3|2/2|Shadow Blend / Iron Knife|10,10,1,3|

All start level1, 75 gold, 5 life potions, 5 mana potions, max energy50, no shield/suit/helmet, zero XP, first threshold50. Initialization is [frame17 DoAction_3](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_17/DoAction_3.as:3); class mutations are buttons512–515, each lines2–16. Spell Caster explicitly resets magdmgb=5 then adds5, yielding10. Initial Iron Knife adds5 to phydmgb (case-insensitive AVM1 member semantics should be runtime checked).

Starter Charge and Shadow Blend are set directly without learning upstream skills. Prerequisites still apply to future upgrades: a Spell Caster trying to rank up Charge must learn Energy Shot; Shadow Ninja must learn Speed Strike to rank up Shadow Blend. There is no class-exclusivity condition in skill-learning buttons.

## Level progression / XP

[Reward expUP callback](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_85/PlaceObject2_2164_18/CLIPACTIONRECORD onClipEvent(load).as:12>) increments current XP one point per reward tick. On equality with threshold it adds a stat point and skill point, +5 max life, +5 max mana, +3 max energy, then increments level. For levels5,10,…95 it adds +2 strength, +2 speed and another skill point. Next XP threshold is 50×new level, not a cumulative total.

Important overflow behavior: the remaining reward XP is copied into current XP; if that reaches the next threshold it clamps to threshold−1. Therefore a large reward does not necessarily produce multiple levelups and can discard XP. No max-level comparison found in this advancement function; **95 limits the five-level bonus loop, not an observed max-level cap**.

Stat-choice buttons2196–2199 spend the stat point using the class array. Strength or Speed also add +2 max energy. Levelup continuation button2186 lines2–4 fills current mana/energy/life to their maxima. These are separate timing steps, not instantaneous restoration inside expUP.

## Combat execution and resolution

The callback definitions are [frame17 DoAction](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_17/DoAction.as:185). For each hit:

```text
attack_roll = random(accuracy_speed/2) + accuracy_speed/2
defense_roll = random(target_speed/2)
cannot_miss forces defense_roll=-1
hit when defense_roll < attack_roll

body_damage = round(B-ceil(B*physical_def/100)
                  +A-ceil(A*magical_def/100)
                  +D-ceil(D*physical_def/100)) + random_additive

shield_damage uses corresponding shield defenses and adds C inside round(...).
```

The functions do not clamp damage to zero. Random additive and extra shield damage bypass the respective defense percentages. While shield HP>0, only shield HP is reduced; a breaking hit sets shield to0 and **does not overflow into body life**. Without shield, body life is reduced and clamped at0 on death. Attacker-side nominal P/M do not decide effective damage type; parameter position does.

[Battle initialization](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_1993/frame_1/DoAction.as:10) copies persistent life/mana, restores shield to the stored equipped amount and adds Shadow Blend speed. It also **swaps shield defense assignments**: hero1shdmagdef=shdphydefb and hero1shdphydef=shdmagdefb (lines31–32), repeated for hero2 in DoAction_2 lines27–28. This affects incoming damage beyond the P/M caller reversal.

[speedorder()](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_17/DoAction.as:158) sorts four speed values descending, then assigns actor names using a nested j=1..2 loop with overwrite behavior. Do not replace this with the wiki's claimed simple tie priority. Example static translation with hero1=15, hero2=0, enemy1=15, enemy2=15 yields enemy2,enemy1,hero1,hero2. Equal candidate assignments can overwrite earlier candidates within the same loop. Runtime correspondence remains to be observed.

Only one direct speedorder() call site was found: battle controller sprite1993 frame11 line4. Summoning mutates hero2speed but does not call speedorder in sprite1898; therefore the existing queue may not reflect the shadow's newly increased speed. This is a static control-flow limitation, not confirmed runtime timing.

Each player command advances turnnum once modulo4 and sets midfight. Animation completion clears midfight. Dead/absent actor entries are skipped by their enterFrame handlers; attacks include living enemies and optionally living shadow. Enemy AI selects uniformly from its `attacks` array (duplicates weight outcomes); if shadow is alive it randomly targets hero1 or hero2. [Representative enemy handler](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_35/PlaceObject2_1909_29/CLIPACTIONRECORD onClipEvent(enterFrame).as:2>). No intended-next-action telegraph is established by that handler.

The shadow's turn handler auto-uses Attack, consumes no player mana, and is hidden at life0; [frame35 shadow handler](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_35/PlaceObject2_1909_53/CLIPACTIONRECORD onClipEvent(enterFrame).as:11>). Shadow starts with life0 and copied equipment-related stats, then summon updates only life, P/M and speed; casting again resets life to summon maximum. No “already summoned” guard in button1947.

Basic Attack has no mana/weapon guard in button1911. Life/Mana Potion buttons1938/1939 consume an inventory potion and a turn; effects restore80 capped at maximum (sprites1821/1822 frame11 DoAction_2). All three require player turn, no active animation and living enemies. No basic Guard/Defend command was found among these handlers.

Battle controller [sprite1993 frame14](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_1993/frame_14/DoAction.as:1) waits until animations finish before resolving hero death or all-enemy death/endtrain. Dead current target switches to the remaining enemy. Hero death takes precedence when both sides are dead.

## Energy and defeat

Retry [button2250](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_2250/BUTTONCONDACTION on(release).as:3>) decrements current portal progress index, sets persistent life/mana/energy to5 and reloads the saved hub location. It does not perform full recovery.

Energy drain lives in timeline sprite622. Frame240 drains1 energy when positive; other callbacks at roughly12-frame intervals drain1 life, then mana if life>1 and mana>1 while energy==0. Example [frame12](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_622/frame_12/DoAction.as:1). Therefore mana drain stops once life reaches1. Do not infer a wall-clock rate until the SWF frame rate and pause/clip activation are checked. Training scripts2107/2115 frame3 subtract engrate; normal win continuation button2170 subtracts engcost. Parent's encounter catalog must join the per-encounter values.

## Corrections to secondary sources / design implications

- Confirmed:19 learned skills,13 offensive/3 supportive/3 passive; rank10; level gates1/5/10/15; shared tree with two-parent nodes and direct starter exceptions.
- Mana Bomb uses full current mana, not current mana−1, in this export.
- Shadow Strike and Annihilate damage depend on Shurikens rank, not their own rank. Double Strike shield multiplier also reads Shurikens rank. Spending ranks can therefore have surprising or ineffective outcomes.
- Nominal P/M damage components are reversed in many callers; player shield defenses are also swapped at initialization.
- Multi-target Shurikens is asymmetric between slots. Multi-hit skills make separate hit/defense checks and can break shield before later hits damage body.
- No keyword hits for status mechanisms such as poison damage-over-time, stun, bleed, burn, slow or cooldown were found in the exported `.as` corpus; “Poison Wasp” is an enemy name. Existing special attacks/summons/healing are not evidence for a generic status system.
- A richer successor needs meaningful builds, multi-actor targeting, distinct damage/shield interactions and deep progression, not merely more named buttons. Exact new targets should follow the completed reference audit.

## Remaining uncertainty / coverage boundary

This report covers all19 player learnable nodes and their action callbacks, all4 class mutators, advancement, shared damage/accuracy, turn ordering, summon, healing, shield and defeat logic. Enemy-specific action catalogs, scripted boss patterns and complete encounter data are separate work. Timeline label-to-sprite bindings and AVM1 case-insensitivity/runtime scheduling need runtime corroboration. No wall-clock action duration or animation feel has been measured. No claim that static analysis is equivalent to completing every game route.


## Runtime corroboration — 2026-10-27

This report records static reconstruction. Subsequent representative runtime results, including their controlled fixtures, exact REA Evidence IDs and unresolved limits, are summarized in [runtime coverage](runtime-coverage.md). Earlier statements that runtime was pending describe this report’s original inspection time; they are not the final project coverage status. No exhaustive playthrough is implied.
