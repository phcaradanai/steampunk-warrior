# Shurikens probe discrepancy — fixture interruption finding

Original SWF SHA-256: `e258423f2a5887ff236a67eb6eaf674a8d573a5cdb721c20b79c831da4d9e008`. This note combines retained probe results with static ActionScript and SWF timeline inspection; it does not itself create a new REA/runtime observation.

## Conclusion

The zero-damage run is not sufficient evidence of a Shurikens formula or binding bug. The probe previously reset `midfight=false` and the turn queue while an enemy animation was still running. A late enemy hit can replace the player's new Shurikens animation before its damage callback. This interruption mechanism is directly supported by original code. The exact failed run did not log the nested timeline transition, so causation remains a strongly supported explanation pending the parent's synchronized retry.

## Existing successful observation

`runtime-skills-first-attempt.json`, record `active-skill-1-Shurikens`, records:

| Field | Before | After |
| --- | --- | --- |
| hero1mana |1000|980|
| enemy1life |50000|49859|
| enemy2life |50000|49841|
| hero1life |24993|24981|
| turnnum /midfight |0 /false|3 /true|

The fixture assigns hero1life=25000. Its acknowledged “before” already contains24993, independently demonstrating enemy activity during fixture preparation/acknowledgment. The prior Stab record ends at turnnum3/midfighttrue. Therefore the next fixture was not isolated even though it forcibly exposed a selectable player turn. The first-attempt run ultimately failed Charge, not Shurikens.

At inspection, the subsequent `runtime-skills-results.json` (probe hash723f228c3f331bb6f8745761e9db4ea6b1717411a9af64302461c55c0ff1def1, runner hashc3b1766dce3c4a005303955547b0873713a3532295f32ec39b8ec3eef046b709) failed the assertion “Shurikens: no primary damage” after Stab; its saved Stab record likewise ended turnnum2/midfighttrue. This working output path can be replaced by later retries. Its failing Shurikens after-snapshot was not appended as a normal result record, so the assertion alone should not be treated as a complete timeline trace. Preserve a separate failed after-snapshot if this failure recurs.

## Original binding and callback path

1. [Battle button1940](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineButton2_1940/BUTTONCONDACTION on(rollOver).as:2>) sets skilllabel1 and mana requirement20. Release subtracts mana before calling Fight("Skill1").
2. [Fight](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_17/DoAction.as:350>) seeks the currently queued actor to the named label.
3. Direct SWF FrameLabel/PlaceObject2 decoding shows sprite1909 labelSkill1 at frame23, placing sprite1862 at depth1 with instance namehero. [Frame23 binding script](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_1909/frame_23/DoAction.as:1>) assigns hero.mcname=mcname2, hero.subject=subject2 and hero.dmgtype=dmgtype2. No missing/mismatched instance name was found.
4. [Sprite1862/frame18](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_1862/frame_18/DoAction.as:1>) saves herotarget, selects each living enemy in turn, invokes the damage callback, and restores the original target. Its callback uses `(0,M+15+7r1+7r8,false,...)`; at rank10, M10 gives a165 physical component before target defenses. With speed20 versus15, the attack roll's minimum10 exceeds the defense roll's maximum6, so a normal accuracy miss cannot explain both targets staying at50000 under this fixture.
5. [Frame25 completion](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_1862/frame_25/DoAction.as:1>) releases midfight and returns the actor to stand. Damage occurs at frame18; merely seeing mana spent or seeing stand later does not prove frame18 executed.

## How an in-flight enemy animation interrupts it

[enemyDamage](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_17/DoAction.as:216>) executes `_root[_root.enemytarget].gotoAndStop("hit")` on an unshielded hit before subtracting life. Shield block/break at lines202/207 and miss at229 also seek the target actor to reaction labels. These operations do not check whether the target is currently animating a player skill; the normal midfight gate prevents overlap elsewhere.

The SWF actor timeline's hit label is sprite1909 frame8, replacing the active hero child with sprite1828. [Hit child frame11](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_1828/frame_11/DoAction.as:1>) returns the actor to stand. Replacing child1862 before its frame18 prevents the scheduled Shurikens damage script from running. Mana already paid by the button remains spent.

The fixture did not stop/replace existing enemy children; it only reset global flags/queue and stats. The original [enemy handler](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_35/PlaceObject2_1909_29/CLIPACTIONRECORD onClipEvent(enterFrame).as:15>) starts an animation and advances turnnum immediately. Its damage callback can occur much later, while the global midfight flag remains true. Forcing that flag false does not cancel the previously launched animation.

SWF declares24fps. Stab animation completes at frame65, ordinary humanoid attack at55, and Skille0 at65. Player action plus two enemy animations can exceed7 seconds even at declared frame rate; fixed4.4-second sleeps are not a safe cycle-completion condition. Runtime scheduling can extend elapsed time further.

## Minimal verification correction

Wait for the original queue to return to hero1 **and** original midfightfalse before preparing each fixture and again after the skill and both enemy responses. Do not force these conditions to become true while animation children are running. Record before/after nested hero and enemy wrapper/child frame numbers if another discrepancy occurs.

No original skill function or live browser was modified by this investigation. The synchronized retry must decide whether the artifact is resolved; do not publish “Shurikens deals no damage” as a reference-game behavior from the failed fixture.
