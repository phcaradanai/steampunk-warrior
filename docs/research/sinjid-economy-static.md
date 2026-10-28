# Sinjid: equipment, inventory, economy and assets — static findings

Analyzed file: `reference/sinjid/original.swf`, SHA-256 `e258423f2a5887ff236a67eb6eaf674a8d573a5cdb721c20b79c831da4d9e008`.

Evidence here is JPEXS FFdec 26.4.0 decompilation plus direct parsing of SWF sprite placements. It is **not gameplay observation and not a claim that REA natively decompiled SWF**. Parent investigation records REA captures separately.

## Complete item definition inventory

[Numeric item catalog](/Users/Projects/Steampunk-warrior/docs/research/sinjid-items-static.csv) contains every non-placeholder AddItem definition, all 16 fields, source line and computed normal-shop sale value. [JSON catalog](/Users/Projects/Steampunk-warrior/docs/research/sinjid-items-static.json) adds literal-reference locations and shop stock/button mappings.

| Type | Definitions | Boundary |
| --- | ---: | --- |
| Weapon | 25 | Includes Blood Razor, which has no literal use outside its definition in the full exported script set. Defined count is not an obtainable count. |
| Shield | 17 | Includes loot-only entries. |
| Head Gear | 10 | All ten appear in shop stocks. |
| Suit | 8 | All eight appear in shop stocks. |
| Drink | 1 | Medicine, a quest trade item; potion counters are separate. |
| Relic | 1 | Mendo's Ring, quest item. |
| Herb | 1 | White Leaves, quest trade item. |
| Total | 63 | 60 equipment definitions plus 3 quest/trade items. |

Excluded `name` schema example, `None` empty-slot sentinel and symbolic `Name` headgear placeholder. The last placeholder is not valid numeric gear. The code table therefore disagrees with a secondary-source claim of 59 equipment: preserve the defined/obtainable distinction rather than silently selecting one number.

Definition source: [DoAction_2.as](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_17/DoAction_2.as:1). `Rust Blade` is a real defined/shop item at line 27. `Blood Razor` at line 15 is a defined-only candidate after bounded literal searches of every exported `.as` file; dynamic construction remains an unknown.

Item schema is defined by `AddItem` in [shared functions](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_17/DoAction.as:134): name, type, physical/magic/extra-shield damage, physical/magic defense, shield physical/magic defense, shield HP, speed, bonus HP, bonus mana, special skill, required strength, description. Parameter `itmstr` is misleadingly named: its position is consumed as bonus mana, not bonus strength. No real item definition supplies a nonzero special-skill field.

## Shop stocks and exact prices

Reconstruction follows sprite 1458's display list at each ShowFrame, the placed DefineButton2 ID, its handler's `slotnum`/`cost`, and the same frame's `itemstats[slot]` assignment. It does not guess prices from item stats. All six gear shop labels have NPC routing references; detailed room links belong to the world report.

| Shop label / sprite frame | Item: gold |
| --- | --- |
| Items_0 / 3 | Silver Knife 30; Spiked Axe 60; Heavy Blade 90; Leather Wrist 15; Metal Wrist 30; Wooden Guard 40; Hand Blade 60; Bandana 10; Metal Band 15; Leather Armour 100 |
| Items_1 / 4 | Rust Blade 120; Katana 150; Shield Breaker 200; Blaze Edge 330; Wooden Rod 120; Metal Guard 150; Double Blade 200; Claw Blade 400; Golden Rod 400 |
| Items_2 / 5 | Focus Band 40; Fire Band 60; Power Band 100; Snake Band 60; Metal Plates 150; Metal Armour 350; Snake Skin 170 |
| Items_3 / 6 | Fusion Edge 700; Demon Skin 220; Demon Rags 800; Ki Band 210; Focus Armour 800; Energy Wrist 560; Blade Shield 600 |
| Items_5 / 7 | Shadow Katana 1000; Shadow Spirit 1000; Shadow Armour 1500; Shadow Band 400; Shadow Wrist 400 |
| Items_4 / 8 | Golden Blade 1100; Ion Bo 900; Guard Blade 1500; Golden Armour 1600; Golden Band 400; The Guardian 980; Voodoo Shield 800 |
| Trade / 9 | White Leaves 0 |
| Blacksmith / 12 | Alternating Long Sword / Chain Mail, ten entries at 50 each; Chain Mail is undefined in the item table. Treat this screen as a leftover/incomplete definition until reachability is established. |

Thus the six actual gear stocks contain **45 purchase offers**, distinct from 60 equipment definitions. Full exact handler/stock paths are in the JSON catalog. Example: [Items_0 stock](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_1458/frame_3/DoAction.as:1), [Silver Knife price](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1024/BUTTONCONDACTION%20on(press,%20release,%20rollOver).as:2).

NPC shop routes: Items_0 in root frame 24, Items_1/2 in frame 26, Items_3 in frame 29, Items_4/5 in frame 31. Actual labeled room identities must come from root FrameLabel parsing, not assumptions about frame numbers.

Purchase handlers immediately subtract gold and place the item on the cursor (`itempick`) if the cursor is empty and gold is sufficient. They do not require a free bag slot at that moment and do not decrement stock. See [purchase handler](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1024/BUTTONCONDACTION%20on(press).as:1). `GetItem()` is a different path used for quest acquisition: it searches bag slots before charging.

## Sale rules

Normal gear shops accept Weapon, Suit, Shield and Head Gear. Sale value is `Math.round(sum(item[2..12]) × multiplier)` where multiplier is Weapon 1.3, Suit 2.34 (1.3 × 1.8), Shield 0.4 and Head Gear 0.7. Required strength and special skill are excluded; negative stats such as Guard Blade's mana penalty reduce value. [Price calculation](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1010/BUTTONCONDACTION%20on(rollOver).as:1), [sale action](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1010/BUTTONCONDACTION%20on(press).as:1).

Trade's separate seller accepts `Drink` and pays 3 gold, making Medicine's loop free White Leaves → NPC conversion → Medicine → 3 gold. [Trade seller](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1099/BUTTONCONDACTION%20on(rollOver).as:1). The Blacksmith's separate seller applies 1.3 to gear except Suit 2.34; unlike normal shops it has no Shield/Head Gear discount. Do not merge these handlers into a single claimed original formula.

## Inventory and equipment

- Four equipped slots: Weapon slot 0, Shield 1, Suit 2, Helmet 3. Eight general bag slots 4–11. Shop display uses slots 20–29; they are not player carrying capacity. The initialization array is larger but search/acquisition loops explicitly use 4..11.
- Equipping checks exact item category plus base `strb >= item[14]`. Click swaps the cursor with the equipment slot, removing old bonuses then adding new bonuses. [Weapon handler](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_957/BUTTONCONDACTION%20on(press).as:1), [Shield handler](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_958/BUTTONCONDACTION%20on(press).as:1).
- `EquipItem` adds every combat bonus, increases both maximum and current mana by the item's mana bonus, and caps current mana. `RemoveItem` subtracts both maximum/current mana and floors current mana at zero. HP maximum changes but current HP is not adjusted there. [Bonus application](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_17/DoAction.as:287).
- `GetItemDrop` silently inserts in the first free bag slot; a full bag gets nothing. The victory screen clears `droppedstuff` regardless, so that loot is lost. [Drop insertion](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_17/DoAction.as:58), [victory](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_85/DoAction.as:1).
- Tooltip displays at most four nonzero fields from indexes 2..13, so some multi-stat items hide extra stats. This is a UI limitation, not absent underlying stats.
- Discard button only blocks category `Required Item`; actual quest items use Herb/Relic/Drink, so that guard does not protect them. [Discard](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_944/BUTTONCONDACTION%20on(press).as:1).
- Inventory frame 2 resets the cursor to `None`; do not copy this casually into a new game because an item held on the cursor can be lost when this transition is reached. Static risk, not reproduced runtime.
- `SearchItem` contains `if(ask = true)` (assignment, not comparison), so a found matching item is consumed regardless of caller intention. Existing quest callers pass true, but the helper is unsafe as a general query.

## Loot selection

`ItemRand(k0,k1,k2)` pushes nonempty parameters and chooses `random(length)`. There is no chance-to-drop roll in that function; one nonempty item is deterministic, two entries are an equal candidate selection under Flash's integer random semantics. Fourth arguments in callers are ignored. [Function](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_17/DoAction.as:39).

| Root frame / combat label | Candidates |
| --- | --- |
| 51 / HUMAN3 | Raider Sword |
| 52 / HUMAN5 | Wooden Shield or Long Sword |
| 58 / HUMAN14 | Wooden Staff |
| 38 / HUMAN11 | Double Razor |
| 67 / MONSTER4 | Metal Shield |
| 69 / MONSTER9 | Demon Sword or Demon Shield |
| 70 / MONSTER10 | Spike Sword or Spike Shield |
| 74 / DARK3 | Fallen Blade or Fallen Shield |

There are eight call sites. `droppedstuff` is selected at encounter setup, awarded at victory, then reset. Investigate death/re-entry paths before treating this as a fully proven no-stale-loot guarantee. `itemlog` is initialized but no later script references it, so it does not establish first-clear-only drops or collection completion.

## Consumables and other gold sinks

Life and mana potions are separate integer counters, not entries in the eight-slot bag. New game starts with 5 of each and 75 gold ([initialization](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_17/DoAction_3.as:70)).

| Purchase/service | Cost | Effect |
| --- | ---: | --- |
| Life potion | 25 | +1 lifepots; use restores 80 HP |
| Mana potion | 15 | +1 manapots; use restores 80 MP |
| Meal_0 | 5 | +20 Energy, +5 HP, +5 MP |
| Meal_2 | 15 | +50 Energy, +15 HP, +15 MP |
| Meal_1 | 20 | +60 Energy, +20 HP, +20 MP |
| Meal_3 | 1 | +2 Energy, +2 HP, +2 MP |
| Healing service button 1408 | 10 | +40 HP |
| Healing service button 1410 | 20 | +60 HP and +60 MP |
| Healing service button 1411 | 30 | +120 HP and +120 MP |

All values cap at maxima. Meal data are button 1314–1317 hover handlers; purchases are release handlers, which spend money even at full resource. Potion purchase is [1394](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1394/BUTTONCONDACTION%20on(release).as:1) and [1395](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1395/BUTTONCONDACTION%20on(release).as:1). No explicit potion stack cap appears in these purchase handlers.

Overworld use requires not `meet`/not talking, consumes a potion and caps HP/MP. In combat the player must have the turn, no animation in progress, a positive counter and live enemies; use consumes the turn. Hero HP potion animation heals 80; enemy users of that shared animation heal `4 × Human gateway level`, a distinct rule. [Combat life potion button](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1938/BUTTONCONDACTION%20on(release).as:1), [heal animation](/Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_1821/frame_11/DoAction_2.as:1).

## Economic progression implications

The economy ties combat rewards to purchases and persistent resource upkeep. Early victory HUMAN1 grants 30 gold; the cheapest gear offer is 10 and first body armor costs 100, while late offers reach 1600. Potion/meal/heal spending competes with gear buying. Loot can become upgrades or sale income. There is a small repeatable crafting/trade loop, not a broad crafting tree. Equipment has strength gates and mixed bonuses/penalties, so raw price alone does not define upgrade quality. Reward tables and repeat encounter progression are in the world report.

## Embedded assets and animation architecture

Direct recursive tag inventory in this SWF: 353 DefineSprite timelines, 194 DefineButton2 objects, 1,019 static vector shapes (793 DefineShape + 53 DefineShape2 + 173 DefineShape3), 42 DefineMorphShape objects, 6 bitmap definitions (4 DefineBitsLossless + 2 DefineBitsJPEG2), 16 DefineSound entries, 272 DefineText plus 412 DefineEditText entries, 7 font definitions (3 DefineFont + 4 DefineFont2). Counts describe definitions, not unique visible characters or exported media files.

The game is primarily Flash vector/timeline composition, not sprite-sheet rendering. Shared body-part names and equipment `gotoAndStop(itemName)` calls swap visuals by timeline label; combat skill timelines call damage/heal functions on selected animation frames. The inventory itself is a labeled sprite timeline controlling shop/skill/book/heal/training panels. These are architecture observations from definitions and scripts; frame rate, actual animation timing, audio mix and visual quality require runtime review.

## Verification boundary

Catalog generation checked every AddItem row has 16 fields, item names are unique after exclusions, SWF tag lengths remain within carrier bounds, and the six gear shop frames yield 45 offers. The parser was run against the preserved carrier and all exported ActionScript for literal references. All numbers are static findings; no combat/shop input or animation was executed by this subtask. Runtime navigation and edge cases remain for the parent investigation.


## Runtime corroboration — 2026-10-27

This report records static reconstruction. Subsequent representative runtime results, including their controlled fixtures, exact REA Evidence IDs and unresolved limits, are summarized in [runtime coverage](runtime-coverage.md). Earlier statements that runtime was pending describe this report’s original inspection time; they are not the final project coverage status. No exhaustive playthrough is implied.
