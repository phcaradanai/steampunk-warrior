# Steampunk Warrior — production art direction

Approved project style: original 2D painted cutouts, brass/soot/ether colors, human and mutated-animal opponents, Thai code-native UI. Builder selects this visual target within that brief; no original Sinjid art or living-artist style reference.

## Technical frame

Godot4.7.2,1280×720design with960×540minimum/1920×1080verified. Top-down walkable map with32px metrics,character collisionradius10. Combat uses full-body three-quarter side cutouts facingright forheroes;enemytextures mirrored at runtime. Character baseline bottomcenter,fullbody uncut,transparentalpha and≥8%cellpadding. Battle display around130–190pxhigh,worldactor36–48pxhigh. Linear filtering/mipmaps for painterly assets;no fake pixelart grid. EngineAtlasTexture regions and alpha bounds metadata preserve original PNG source unchanged.

## Visual system

Silhouettes first: squat broad boilerknight,slender railline gunner,teslacoil engineer,creamcoated fieldmedic,glassvial biomechanist. Mutants show recognizable animal anatomy plus ether growth/copper hardware;human enemies show occupational gear. Warm brass highlights,deep bluegreen shadow,small jade/cyan emissive accents;charcoal outlines and restrained papertexture. Warm upperleft light;faces/hands/weapon edges carry focalcontrast. No baked lettering,logos,UIframes,watermarks,checkerboards or scenery in character cutouts.

## Asset families

1. HeroC01 single transparent seed,reviewed at game scale before family generation.
2. ActoratlasA:4columns×5rows,5classes thenN01–N15. Every cell sameframe/facing/baseline,contained silhouette. Exact generateddimensions recorded;never assume gridaccuracy.
3. ActoratlasB:4columns×3rows,N16–N19,B01–B06,drone,root. Reference seed/familyA for invariants.
4. Six environment-family textures/illustrations:hub,canal,rail,garden,industrial,archive/reactor. Lowcontrast playfield;engine geometry defines real collision and interaction cues. Do not bake false impassable walls across routes.
5. Wide Vespercity titleart with negative space for code-native Thai title/menu.
6. Code-native SVG iconfamily forsimpleweapon/shield/gear/status symbols. W26/A09 visiblydistinct glow/details. Functional text staysControl/Label.

NPCs reuse appropriate original character cutouts (Ren/repairman,Ing/medic,Kita/smuggler,Valk/guard,Lin/biomechanist,Bolt/worker,Saren/researcher,Mira/arcengineer) with distinctnamed dialogue and faction colors. No promise of38fullyrigged characters or62outfit meshes:actor/equipment silhouettes share approvedvisualgroups;all62itemgameplaydefinitions stillrequired.

## Motion

Engine animation ofcutouts:anticipation/lunge/recoil/return,idlebreathing,projectilearcs,brass/ether impacts and readablecast circles. Animationneverowns damage orreward. Reducedshake/reducedflash flags mustdisable correspondingeffects withoutchanging outcome orcue availability.

## Acceptance

Inspect source/alpha/cellbounds and actualengine views. No atlascell mayclip anotheractor;all feet align toground. Keep nativefiles/prompt records/hash/provenance. Label generatedresult pending until inspected and integrated. Do not replace failed assets with greybox and count release complete. Final soundtrack/SFX mustbeoriginal orlicensed andplaybackverified.

## Integration evidence, 2026-10-27

The provider did not obey equal row heights or sufficient sprite gutters. The original PNG files remain unchanged. `regions.json` records measured character bounds; `ActorArt` uses native Godot BitMap alpha tracing and textured polygons to isolate each silhouette at render time. This prevents neighboring tails from leaking into portraits when their rectangular bounds overlap. BitMap points are local to the requested rectangle and must be translated into sheet coordinates before UV mapping. All32 silhouettes triangulate;66 art checks pass. Font and actor/floor/title integration were inspected in native AppleM1 captures: title960×540,world/dialogue/combat1280×720;18 captures across3 resolutions completed without engine errors. These are preview integration checks, not the final game release gate.

Floor panel measured vertical boundaries:0,395,804,1254; two columns split627. No sprite or floor PNG was resampled, cropped or edited by external scripts. Hashes and dimensions in asset-manifest.json. Prompt files accompany each family. AtlasA first generation is retained as a superseded draft. NPC portraits intentionally share approved actor silhouettes.
