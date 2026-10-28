# Sinjid: Shadow of the Warrior — source catalog

Date: 2026-10-27. Scope: the 2004 game, not Sinjid (2013) or Battle Arena (2003).

**Status: source-assisted investigation, NOT completed REA analysis.** All gameplay entries below are secondary-source assertions pending verification against a byte-identified SWF and/or runtime observation. Search-index text was accessible; direct Fandom opens were robots-blocked. This file does not claim code recovery, runtime execution, or complete coverage.

## Primary / preserved anchors

- [Creator's Newgrounds release](https://www.newgrounds.com/portal/view/209736): Krin describes an RPG focused on combat, items, skills and difficult Dark Portal bosses.
- [Museum reference selected by user](https://www.webdesignmuseum.org/flash-games/sinjid-shadow-of-the-warrior-in-2004): identifies 2004 game and authors InfraRift / Krin.
- [Archive preservation item](https://archive.org/details/sinjid_sotw_flash): SWF/Ruffle preservation anchor. Byte identity and build variant must be established separately by REA.

## Content baseline hypotheses

| Dimension | Candidate baseline | Verification required |
| --- | --- | --- |
| Classes | 4 | Starting values, growth and starter-node exceptions |
| Learned skills | 19, each up to rank 10 | All skill nodes, edges, level gates, costs and actual effects |
| Battle actions | 3 universal actions beyond learned skills | Inventory quantities and menu restrictions |
| Combat stages | Human 20 + Monster 10 + Dark 5 = 35 | Variant-specific tables; one retrospective conflicts |
| Training | 3 wards | All stat tables / energy / XP behavior |
| Enemy archetypes | 11 human + 8 monster + 5 Dark + 1 ward = 25 | Encounter composition and unique variants |
| Equipment | Catalog enumerates 24 weapons + 17 shields + 10 headgear + 8 suits = 59 | Duplicates, aliases and missing entries |
| Hub | Multiple connected service, lore and gate rooms | Exact room IDs, topology, exits and gates unresolved |

The former 6-skill/9-battle proposal cannot satisfy “more than reference” if these baselines are confirmed. Count functional content separately from reskins, repeated stages and rank upgrades. The candidate arithmetic above is an analyst count of source entries, not verified game data.

## Level design and traversal

[Shadow Temple source](https://sinjid.fandom.com/wiki/Shadow_Temple) describes a compact hub with paid recovery, saving/limited free rests, food/potion service, equipment merchants, training, library and three combat gateways. Human stages are mandatory; clearing all 20 opens Dark Rift, whose five fights have special mechanics. Monster stages are harder than early human fights. This suggests alternating optional progression rather than a single linear chain.

[Namu map source](https://namu.moe/w/Sinjid%20%3A%20Shadow%20Of%20The%20Warrior/%EB%A7%B5) identifies entrance, dining area, Human Gateway, basic shop, tavern, intermediate shop, library, statue room, Monster Portal, Dark Rift entrance and Dark Rift room. Training needs a distinct room-ID check. Reported edges: entrance north→dining; dining west→Human and east→basic shop; basic shop north→tavern; tavern west→intermediate; intermediate west→library and north→statues. Reported save NPC grants ten full recoveries; human completion enables leaving through entrance for ending. These are partial edges, not a complete map. Do not infer unreported reverse doors.

Important level-design evidence still missing: every room's bounds, collision, entrances, exit spawn points, interactable ranges, camera framing, ordering cues, optional detours, gate requirements, arena background reuse and all NPC/book scripts.

## Skill inventory and graph hypothesis

[Skills source](https://sinjid.fandom.com/wiki/Skills_%28Sinjid%3A_Shadow_of_the_Warrior%29) lists 19 learnable skills: 13 offensive, 3 supportive, 3 passive; rank cap 10. Universal actions: Attack, Life Potion, Mana Potion. Candidate edges:

```text
Stab → Double Strike → Vertical Strike → Inner Strength [L5]
Stab → Speed Strike → Shadow Blend
Shuriken → Energy Shot → Energy Field → Mana Bomb [L5]
Energy Shot → Charge → Heal [L5]
Shuriken → Blast Fire
Inner Strength → Avenger [L10], Split [L10]
Shadow Blend + Mana Bomb → Shadow Strike [L10]
Blast Fire + Heal → Annihilate [L10]
Avenger + Split → Execution [L15]
Shadow Strike → Shadow Replicate [L15]
```

Source also alleges swapped physical/magical scaling and Shuriken-linked upgrade bugs; preserve as hypotheses. Clone/summon and multi-target attacks mean the combat model must support more than a fixed 1v1. Validate starter skills bypassing upstream nodes before implementing prerequisites.

Full numeric formulas, rank-by-rank differences, accuracy, resource charges, targeting, AI interactions and UI descriptions remain unverified.

## Classes and advancement

[Classes source](https://sinjid.fandom.com/wiki/Classes_%28Sinjid%3A_Shadow_of_the_Warrior%29): irreversible new-game class choice; all classes can learn shared skills. Balanced starts Shuriken; Warrior Stab; Spell Caster Charge; Shadow Ninja Shadow Blend. Growth rates favor broad, strength/life, mana, and speed builds respectively. Level-up grants baseline life/mana/energy and a player-selected boost among Strength, Speed, Max Life, Max Mana. Class changes the boost size. Source says one skill point per level, plus another each fifth level up to 95. Exact values and level cap must come from game data.

## Combat, shields, energy and defeat

[Stats source](https://sinjid.fandom.com/wiki/Stats_%28Sinjid%3A_Shadow_of_the_Warrior%29): Speed orders actors and accuracy; tie priority reportedly Enemy 1→Enemy 2→Sinjid→Shadow. Strength gates equipment. Life/mana persist across fights. Retry reportedly returns to hub with life, mana and energy at 5. Energy drains during overworld activity and after combat; training uses per-hit cost. Empty energy slows traversal and drains life/mana toward a floor; source reports an asymmetry bug. These timing claims assume stable original frame rate and need testing under Ruffle.

[Game overview source](https://sinjid.fandom.com/wiki/Sinjid_Shadow_of_the_Warrior): shields have their own HP and defenses, absorb incoming damage, break during combat, and reset next fight; some weapons specialize in shield damage. Build choices therefore involve equipment requirements, shield-breaking, offense type, speed/accuracy and resource sustain. Do not reduce shields to a flat defense number.

## Encounter catalog

[Enemy source](https://sinjid.fandom.com/wiki/Enemies_-_Sinjid_Shadow_of_the_Warrior): human roster Thief, Bandit, Raider, Warrior, Seer, Mercenary, Assailant, Shaman, Agent, Ronin, Samurai. Monster roster Poison Wasp, Undead, Skeleton Mage, Mountain Naga, Skeleton, Golem, Semi Demon, Flesh Fiend. Human encounters sometimes contain two enemies. Item rewards can differ by stage. Exact 20/10 stage compositions and all stats/AI/reward tables remain unresolved.

[Dark Rift source](https://sinjid.fandom.com/wiki/Dark_Rift): levels 1–5 respectively Liquid Metal, Blood Spirit, Fallen Guardian, Anti Ninja, Shadow Reaper; gate opens after Human completion. Two late-game merchants specialize in general ultimate gear and speed-oriented shadow equipment. NPCs explain Rift and hint at an enemy tactic. Source names Fallen Sword while item index says Fallen Blade: alias conflict to resolve against SWF.

## Equipment catalog candidate (59 entries)

[Item index](https://sinjid.fandom.com/wiki/Items%3A_Sinjid_Shadow_of_the_Warrior):

- Weapons (24): Iron Knife; Energy Knife; Silver Knife; Spiked Axe; Heavy Blade; Rust Blade; Katana; Shield Breaker; Blaze Edge; Wooden Rod; Golden Rod; Fusion Edge; Shadow Katana; Shadow Spirit; Golden Blade; Ion Bo; Guard Blade; Raider Sword; Long Sword; Double Razor; Wooden Staff; Demon Sword; Spike Sword; Fallen Blade.
- Shields (17): Leather Wrist; Metal Wrist; Wooden Guard; Hand Blade; Metal Guard; Double Blade; Claw Blade; Energy Wrist; Blade Shield; Shadow Wrist; The Guardian; Voodoo Shield; Wooden Shield; Metal Shield; Demon Shield; Spike Shield; Fallen Shield.
- Headgear (10): Bandana; Metal Band; Focus Band; Fire Band; Power Band; Snake Band; Demon Skin; Ki Band; Shadow Band; Golden Band.
- Suits (8): Leather Armour; Snake Skin; Metal Plates; Metal Armour; Demon Rags; Focus Armour; Shadow Armour; Golden Armour.

Prices, sell values, requirements, stat modifiers, merchant placement and drop sources still require extraction. Do not import Sinjid 2013 equipment buffs, crafting or eight-slot equipment assumptions.

## Economy, training and side content

[Training Ward source](https://sinjid.fandom.com/wiki/Training_Ward): three tiers suggested at levels 1/5/10; per damaging hit costs energy 2/3/10 and grants XP 3/5/20. XP reportedly doubles after ward shield depletion. Non-damaging actions do not spend training energy. Wards retaliate; training is not a passive menu reward. Verify whether XP, shield and level-up timing make loops exploitable.

[Miscellaneous item source](https://sinjid.fandom.com/wiki/Sinjid_Shadow_of_the_Warrior_Miscellaneous_Items): White Leaves from a trader→Medicine through a woman→sell for 3 gold. Mendo's Ring from a meditating ninja→interact with moon on third floor→one extra skill point. These provide an economy fallback and an exploration reward. Exact quantities, repeatability, dialogue gates and consumption must be inspected.

## Contradictions and completeness gate

[Retrospective](https://www.tjohearn.com/2020/12/26/revisiting-the-sinjid-trilogy-as-adobe-flash-is-discontinued/) estimates roughly 12 rooms, 30 gear pieces, and 20 Monster fights. Those conflict with catalog enumeration and the 10-stage Monster sources. Retrospective also describes two small sidequests. Treat estimates as memory-based observations, not authoritative counts.

No category below may be marked complete merely because it has a wiki page:

1. Identify exact SWF bytes, origin, hash, language/build variant and frame rate.
2. Recover complete scene/room graph and all interactables; compare with runtime navigation.
3. Extract every skill and dependency, all class values, growth, level limits, XP curve and bugs.
4. Extract every encounter composition, enemy behavior, boss phases, rewards and gating.
5. Extract complete equipment/consumables, requirements, prices, drops and economic fallbacks.
6. Recover story, conversations, books, sidequests, secrets and actual ending conditions.
7. Verify combat turns, simultaneous actors, targeting, shield absorption, resource carryover and defeat.
8. Inspect save schema, save trigger, load behavior, rest limits, audio/options/UI and input edge cases.
9. Record static-versus-runtime disagreements and unresolved unknowns in the final REA evidence ledger.
10. Only then set explicit new-game targets exceeding the verified reference in skill/build depth and level/encounter content; preserve meaningful choice rather than pad counts.
