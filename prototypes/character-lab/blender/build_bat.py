"""
N03 aether bat, modelled to match its sprite in game/art/characters/actors-a-v2.png.
Run: /Applications/Blender.app/Contents/MacOS/Blender --background --python prototypes/character-lab/blender/build_bat.py

Grey bat diving forward under two raised teal wings veined with glowing aether, big pink-lined ears,
a brass goggle over one eye and a brass vest carrying green aether canisters.
Origin is the body centre: Creature3D lifts flyers by `hover`. Nodes it drives by name:
  Body (one fur mesh), Head (empty), Wing_N / Wing_F (shoulder pivots, flapped about +X), Leg_HL / Leg_HR (hip pivots).
"""

import math
import os
import sys
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creature_kit import *  # noqa: E402,F403

GLB = os.path.join(ROOT, "game/art/characters/bat.glb")

FUR = "5e5956"
FUR_LIGHT = "86807a"
SKIN = "4e3a32"
EAR_IN = "c48a86"
MEMBRANE = "3c6a68"
VEIN = "3ff0e0"
BONE = "5e3a28"
BRASS = "8e5c18"
BRASS_DARK = "5e3810"
AETHER = "2fd890"
LENS = "35d8d8"


def fur_body(material):
    """Torso, rump, chest, skull and snout blended into one fur mesh; the bat dives nose-down."""
    blobs = [
        ((0.0, 0.0, 0.0), (0.2, 0.14, 0.15), 18),         # torso
        ((-0.17, 0.0, 0.05), (0.14, 0.12, 0.12), 25),     # rump
        ((0.13, 0.0, -0.04), (0.13, 0.13, 0.13), 10),     # chest
        ((0.25, 0.0, -0.06), (0.12, 0.11, 0.11), 15),     # skull
        ((0.36, 0.0, -0.1), (0.08, 0.05, 0.05), 25),      # snout
    ]
    return blob_body(blobs, material)


def membrane(name, outline, material, parent, thickness=0.014):
    """Flat wing skin through the outline points, triangulated and given a little thickness so outlines close."""
    bm = bmesh.new()
    verts = [bm.verts.new(p) for p in outline]
    face = bm.faces.new(verts)
    bmesh.ops.triangulate(bm, faces=[face], quad_method="BEAUTY", ngon_method="BEAUTY")
    ob = mesh_from_bm(name, bm, material, parent, smooth=False)
    solid = ob.modifiers.new("Solid", "SOLIDIFY")
    solid.thickness = thickness
    solid.offset = 0.0
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=solid.name)
    return ob


def wing(tag, side, at, M, root):
    """Raised wing: arm up to the wrist, four fingers fanning back, scalloped skin between them, glowing veins."""
    pivot = empty(f"Wing_{tag}", at, root)
    s = side
    shoulder = Vector((0, 0, 0))
    elbow = Vector((0.1, 0.12 * s, 0.28))
    wrist = Vector((0.04, 0.26 * s, 0.6))
    tips = [Vector((-0.04, 0.42 * s, 1.0)), Vector((-0.42, 0.5 * s, 0.92)),
            Vector((-0.74, 0.46 * s, 0.6)), Vector((-0.62, 0.3 * s, 0.16))]
    hip = Vector((-0.26, 0.04 * s, -0.02))
    outline = [shoulder, elbow, wrist, tips[0]]
    for a, b in zip(tips, tips[1:]):
        outline += [a.lerp(b, 0.5).lerp(wrist, 0.22), b]
    outline += [tips[-1].lerp(hip, 0.5).lerp(wrist, 0.18), hip]
    skin = membrane(f"Wing_{tag}_Skin", outline, M["membrane"], pivot)
    tube(f"Wing_{tag}_Arm", [shoulder, elbow, wrist], [0.035, 0.03, 0.026], M["bone"], pivot)
    sphere(f"Wing_{tag}_Thumb", wrist + Vector((0.04, 0, 0.03)), (0.03, 0.022, 0.03), M["bone"], pivot)
    for k, tip in enumerate(tips):
        tube(f"Wing_{tag}_Finger{k}", [wrist, wrist.lerp(tip, 0.5) + Vector((0.02, 0, 0.02)), tip], [0.02, 0.014, 0.007], M["bone"], pivot, sides=6)
    # Veins sit just proud of both faces of the skin (the outline is not planar, so snap to the skin), branching from each finger.
    for face in (-1, 1):
        def on_skin(p, face=face):
            # Query from just off this side so the hit lands on this face of the solidified skin.
            _, at, normal, _ = skin.closest_point_on_mesh(p + Vector((0, 0.15 * face, 0)))
            return at + normal * 0.004
        for k in range(len(tips) - 1):
            mid = tips[k].lerp(tips[k + 1], 0.5).lerp(wrist, 0.35)
            root_pt = wrist.lerp(mid, 0.5)
            branch = [on_skin(root_pt), on_skin(mid + Vector((0.03, 0, -0.03))), on_skin(mid.lerp(tips[k], 0.4))]
            tube(f"Wing_{tag}_Vein{k}_{face}", branch, [0.006, 0.005, 0.002], M["vein"], pivot, sides=5)
            tube(f"Wing_{tag}_VeinB{k}_{face}", [on_skin(mid), on_skin(mid.lerp(tips[k + 1], 0.45))], [0.006, 0.003], M["vein"], pivot, sides=5)
    return pivot


def build():
    reset()
    M = {
        "fur": mat("Mat_Fur", FUR, roughness=0.85),
        "fur_light": mat("Mat_FurLight", FUR_LIGHT, roughness=0.85),
        "skin": mat("Mat_Skin", SKIN, roughness=0.7),
        "ear_in": mat("Mat_EarIn", EAR_IN, roughness=0.6),
        "membrane": mat("Mat_Membrane", MEMBRANE, roughness=0.6),
        "vein": mat("Mat_Vein", VEIN, roughness=0.3, glow=1.2),
        "bone": mat("Mat_Bone", BONE, roughness=0.7),
        "brass": mat("Mat_Brass", BRASS, metallic=0.7, roughness=0.35),
        "brass_dark": mat("Mat_BrassDark", BRASS_DARK, metallic=0.6, roughness=0.45),
        "aether": mat("Mat_Aether", AETHER, roughness=0.2, glow=1.4),
        "lens": mat("Mat_Lens", LENS, roughness=0.15, glow=1.6),
        "eye": mat("Mat_Eye", "141014", roughness=0.3),
        "nose": mat("Mat_Nose", "c88a86", roughness=0.5),
    }
    root = empty("Bat", (0, 0, 0))
    body = fur_body(M["fur"])
    body.parent = root
    sphere("Chest_Ruff", Vector((0.16, 0, -0.1)), (0.1, 0.1, 0.08), M["fur_light"], root)

    # Head: tall ears with pink lining, beady eyes, pink nose, brass goggle over the near eye.
    head = empty("Head", (0.25, 0, -0.06), root)
    for side, tag in ((-1, "N"), (1, "F")):
        base = Vector((0.2, 0.07 * side, 0.02)) - head.location
        cone(f"Ear_{tag}", base, 0.1, 0.34, M["fur"], head, rot=(-12 * side, -28, 0), segs=10)
        cone(f"EarIn_{tag}", base + Vector((0.016, 0.016 * side, 0.012)), 0.075, 0.28, M["ear_in"], head, rot=(-12 * side, -28, 0), segs=10)
        sphere(f"Eye_{tag}", Vector((0.32, 0.07 * side, -0.04)) - head.location, (0.02, 0.012, 0.016), M["eye"], head)
    sphere("Nose", Vector((0.435, 0, -0.12)) - head.location, (0.02, 0.025, 0.018), M["nose"], head)
    goggle_at = Vector((0.32, -0.095, -0.035)) - head.location
    ring("Goggle_Rim", goggle_at, 0.04, 0.012, M["brass"], head, rot=(90, 0, 0))
    disc("Goggle_Lens", goggle_at + Vector((0, -0.004, 0)), 0.032, 0.014, M["lens"], head)
    band("Goggle_Strap", body, (0.27, 0, -0.05), (1, 0, 0.35), 0.11, 0.025, M["brass_dark"], root, thickness=0.016)

    # Vest: brass band round the torso with an aether canister on each flank.
    harness = empty("Harness", (0, 0, 0), root)
    band("Vest", body, (0.04, 0, -0.01), (1, 0, -0.3), 0.16, 0.16, M["brass"], harness, thickness=0.03)
    band("Vest_Edge", body, (0.11, 0, -0.03), (1, 0, -0.3), 0.15, 0.025, M["brass_dark"], harness, thickness=0.04)
    for side, tag in ((-1, "N"), (1, "F")):
        at = surface(body, Vector((0.02, 0.4 * side, -0.03)), 0.05)
        disc(f"Canister_{tag}", at, 0.045, 0.14, M["aether"], harness, rot=(0, 90, 0))
        for dx in (-0.075, 0.075):
            disc(f"Canister_{tag}_Cap{int(dx > 0)}", at + Vector((dx, 0, 0)), 0.052, 0.025, M["brass"], harness, rot=(0, 90, 0))
        for k, (x, z) in enumerate(((0.12, 0.04), (0.1, -0.1), (-0.08, 0.05))):
            sphere(f"Rivet_{tag}{k}", surface(body, Vector((x, 0.4 * side, z)), 0.04), (0.012, 0.012, 0.012), M["brass_dark"], harness, segs=8)

    # Wings rise from the shoulders; legs dangle back from the hips.
    for side, tag in ((-1, "N"), (1, "F")):
        wing(tag, side, (0.04, 0.1 * side, 0.08), M, root)
    for side, tag in ((-1, "L"), (1, "R")):
        pivot = empty(f"Leg_H{tag}", (-0.22, 0.07 * side, -0.06), root)
        knee = Vector((-0.08, 0, -0.1))
        foot = Vector((-0.18, 0, -0.17))
        tube(f"Leg_H{tag}_Shin", [Vector((0, 0, 0)), knee, foot], [0.035, 0.025, 0.018], M["skin"], pivot)
        for k in range(3):
            cone(f"Leg_H{tag}_Claw{k}", foot, 0.01, 0.06, M["skin"], pivot, rot=(0, -120 + k * 12, (k - 1) * 20))
    # The sprite's wings fill the frame: scale up on the root, as far as the camera frame allows.
    root.scale = (1.05, 1.05, 1.05)
    return root


def main():
    root = build()
    render_views(root, "bat")
    export(root, GLB)
    print("BAT_OK", GLB)


main()
