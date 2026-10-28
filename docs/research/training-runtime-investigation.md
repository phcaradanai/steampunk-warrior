# Training EXP: shield hit, breaking blow and body hit

Original SWF SHA-256 `e258423f2a5887ff236a67eb6eaf674a8d573a5cdb721c20b79c831da4d9e008`. Static evidence: FFdec export plus direct SWF timeline-tag decoding. Runtime source: parent's controlled REA training probe, whose output is `runtime-training-results.json`; do not present fixture-adjusted life/shield/energy as natural progression.

## Correction

The earlier world report's phrase **“shield break adds ceil(exprate×2)” is incorrect**. The double-EXP callback is the ward's **body-hit reaction**, not its shield-breaking reaction. A breaking blow follows a third reaction that has no EXP/energy callback.

| Damage result | Enemy avatar label/frame | Reaction child | EXP added | Energy spent |
| --- | --- | --- | --- | --- |
| Shield survives |block /8|2115|exprate|engrate|
| Shield breaks |blockbreak /9|2120|No callback found|No callback found|
| Body hit, ward survives |hit /5|2107|ceil(exprate×2)|engrate|
| Attack misses |miss /7|2109|No callback found|No callback found|
| Body killing blow |die /6 supersedes hit|2108|Hit callback can be bypassed|Hit callback can be bypassed|

At Basic rates exprate3/engrate2, expected deltas are shield survivor +3/−2, breaking blow +0/−0, and surviving body hit +6/−2. Thus one normal shield hit followed by one shield-breaking hit leaves cumulative EXP3 and energy98 from a fixture that began EXP0/energy100. Only the subsequent surviving body hit should bring EXP9/energy96.

## Exact timeline binding

[Retained bindings and uncompressed byte offsets](/Users/Projects/Steampunk-warrior/docs/research/training-timeline-bindings.json) establish root TRAIN1/frame81, TRAIN2/frame80 and TRAIN3/frame79 all have `enemy1` at depth32, character2124. Their `enemy1counter` at depth203 is character1914, a separate visual feedback timeline.

Within sprite2124:

- Frame5 label `hit` places character2107 at depth2, instance `hero`.
- Frame8 label `block` places character2115 at depth2, instance `hero`.
- Frame9 label `blockbreak` places character2120 at depth2, instance `hero`.
- Corresponding DoAction scripts assign hero.mcname/subject/dmgtype from the actor wrapper's mcname2/subject2/dmgtype2. These wrappers are not the counter object.

The root `heroDamage` function is called for player-to-enemy attacks. When target shield>0, it first plays `targetcounter.gotoAndPlay("blockdmg")` for numerical feedback, then selects the actor's `blockbreak` or `block` label. When shield is absent it selects actor `hit`, subtracts body life, then overrides to `die` if life≤0. Source: [heroDamage shield branch](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_17/DoAction.as:242>) and [body/death branch](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/frame_17/DoAction.as:260>).

Counter sprite1914 updates displayed damage and bar widths and returns to its idle frame. Its exported scripts contain no expup/engb changes. Counter's blockdmg animation therefore does not determine training rewards.

## Callback sources

- [2115 frame3](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_2115/frame_3/DoAction.as:1>) subtracts engrate, adds exprate, checks exhaustion, updates energy bar.
- [2107 frame3](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_2107/frame_3/DoAction.as:1>) subtracts engrate and adds ceil(exprate×2), then performs the same exhaustion check.
- [2120 frame17](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_2120/frame_17/DoAction.as:1>) only returns actor to stand and sets shieldtype to None. It contains no EXP/energy award. No other exported ActionScript callback exists for this reaction sprite.
- [2115 frame16](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_2115/frame_16/DoAction.as:1>) and [2107 frame10](</Users/Projects/Steampunk-warrior/reference/sinjid/decompiled/scripts/DefineSprite_2107/frame_10/DoAction.as:1>) return the actor to stand after reaction. Changing labels replaces the child at depth2. There is no evidence that the break result comes from an old 2115 child failing to restart; the break uses a different child by design.

## Final representative runtime result

The finalized [training result](runtime-training-results.json) and [REA evidence](rea-runtime-training-evidence.json) pass all three assertions: shield survives EXP0→3/energy100→98; breaking hit leaves EXP3/energy98; surviving body hit reaches EXP9/energy96. Manual End Training settles EXP9 into the player total. The same run checks slower empty-energy movement, HP/MP drain and inventory pause. These are controlled fixtures calling original handlers; they do not establish every training rank or a lethal body-hit payout. The lethal-reaction interruption remains a bounded source finding.

See [combined coverage](runtime-coverage.md) for exact evidence binding and limits. No original source or preserved SWF was changed.
