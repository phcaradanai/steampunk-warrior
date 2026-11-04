"""
B06 aether queen (boss), modelled to match its sprite in game/art/characters/actors-b.png.
Run: /Applications/Blender.app/Contents/MacOS/Blender --background --python prototypes/character-lab/blender/build_mantis.py

A giant brass praying mantis: a long segmented abdomen under fanned layers of teal leaf-wings with
brass veins, a raised prothorax with a glowing teal core, a crowned triangular head with big teal
eyes and curled antennae, raptorial forelegs folded in front with long teal blades, and four spindly
walking legs. The wings and forelegs stay still, so they are not named Wing_* / Leg_*.
Nodes Creature3D drives by name: Body (one brass mesh), Head (empty), Leg_FL/FR/HR/HL (hip pivots).
"""

import math
import os
import sys
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creature_kit import *  # noqa: E402,F403

GLB = os.path.join(ROOT, "game/art/characters/mantis.glb")

BRASS = "8a5a1a"
BRASS_DARK = "4e2e0c"
LEG = "9a6a22"
WING = "23735e"
GLOW = "3ff0d0"


def fur_body(material):
    """Segmented abdomen, thorax, raised prothorax and head blended into one brass mesh."""
    blobs = [
        ((-0.12, 0.0, 0.6), (0.16, 0.14, 0.14), 0),       # metathorax
        ((-0.32, 0.0, 0.6), (0.18, 0.17, 0.16), 5),       # abdomen
        ((-0.55, 0.0, 0.58), (0.2, 0.18, 0.17), 8),
        ((-0.78, 0.0, 0.54), (0.18, 0.16, 0.15), 12),
        ((-0.98, 0.0, 0.48), (0.14, 0.12, 0.11), 18),
        ((-1.12, 0.0, 0.42), (0.08, 0.07, 0.07), 25),     # abdomen tip
        ((0.06, 0.0, 0.64), (0.12, 0.11, 0.11), -20),     # thorax
        ((0.2, 0.0, 0.8), (0.16, 0.075, 0.075), -55),     # prothorax rising to the head
        ((0.32, 0.0, 0.98), (0.13, 0.065, 0.065), -60),
        ((0.44, 0.0, 1.18), (0.07, 0.12, 0.09), 0),       # head, wide like a mantis
        ((0.5, 0.0, 1.1), (0.06, 0.05, 0.07), 30),        # mouthparts
    ]
    return blob_body(blobs, material)


def leaf(name, anchor, tip, width, material, parent, thickness=0.014):
    """Pointed flat wing leaf from anchor to tip, broad side facing the camera (world Y), solidified."""
    anchor, tip = Vector(anchor), Vector(tip)
    d = (tip - anchor)
    length = d.length
    d.normalize()
    up = Vector((0, 0, 1)) - d * d.z
    up.normalize()
    bm = bmesh.new()
    steps = 12
    top = [anchor + d * length * (i / steps) + up * (width / 2) * math.sin(math.pi * i / steps) ** 0.8 for i in range(steps + 1)]
    bottom = [anchor + d * length * (i / steps) - up * (width / 2) * math.sin(math.pi * i / steps) ** 0.8 for i in range(1, steps)]
    verts = [bm.verts.new(p) for p in top + bottom[::-1]]
    face = bm.faces.new(verts)
    bmesh.ops.triangulate(bm, faces=[face], quad_method="BEAUTY", ngon_method="BEAUTY")
    ob = mesh_from_bm(name, bm, material, parent, smooth=False)
    solid = ob.modifiers.new("Solid", "SOLIDIFY")
    solid.thickness = thickness
    solid.offset = 0.0
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=solid.name)
    return ob


def build():
    reset()
    M = {
        "brass": mat("Mat_Brass", BRASS, metallic=0.7, roughness=0.35),
        "brass_dark": mat("Mat_BrassDark", BRASS_DARK, metallic=0.6, roughness=0.45),
        "leg": mat("Mat_Leg", LEG, metallic=0.7, roughness=0.35),
        "wing": mat("Mat_Wing", WING, roughness=0.5),
        "glow": mat("Mat_Glow", GLOW, roughness=0.15, glow=2.0),
    }
    root = empty("Mantis", (0, 0, 0))
    body = fur_body(M["brass"])
    body.parent = root

    # Abdomen segment plates and the serrated underside.
    plates = empty("Plates", (0, 0, 0), root)
    for k, (x, z) in enumerate(((-0.22, 0.6), (-0.42, 0.59), (-0.64, 0.56), (-0.86, 0.51), (-1.02, 0.46))):
        band(f"Segment_{k}", body, (x, 0, z), (1, 0, 0.18), 0.22, 0.035, M["brass_dark"], plates, thickness=0.03)
    for k in range(6):
        x = -0.3 - k * 0.13
        _, at, normal, _ = body.closest_point_on_mesh(Vector((x, 0, 0.0)))
        cone(f"Serration_{k}", at - normal * 0.01, 0.03, 0.07, M["brass_dark"], plates, rot=(180, 15, 0), segs=4)

    # Teal core glowing on the front of the prothorax.
    core = surface(body, Vector((0.55, 0, 0.7)), 0.01)
    sphere("Core", core, (0.05, 0.065, 0.065), M["glow"], root)
    ring("Core_Rim", core, 0.06, 0.012, M["brass_dark"], root, rot=(0, 90, 0), seg=16)

    # Head: crown of short spikes, big teal eyes, curled antennae, small mandibles.
    head = empty("Head", (0.44, 0, 1.18), root)
    for side, tag in ((-1, "N"), (1, "F")):
        sphere(f"Eye_{tag}", Vector((0.47, 0.11 * side, 1.24)) - head.location, (0.036, 0.03, 0.04), M["glow"], head)
        antenna = smooth_points([(0.47, 0.04 * side, 1.27), (0.5, 0.06 * side, 1.42), (0.4, 0.1 * side, 1.55),
                                 (0.22, 0.12 * side, 1.6), (0.08, 0.12 * side, 1.55), (0.04, 0.12 * side, 1.45)], 5)
        tube(f"Antenna_{tag}", [p - head.location for p in antenna], [0.012 - 0.008 * i / (len(antenna) - 1) for i in range(len(antenna))],
             M["leg"], head, sides=6)
        cone(f"Crown_{tag}", Vector((0.42, 0.07 * side, 1.26)) - head.location, 0.018, 0.09, M["leg"], head, rot=(-25 * side, -10, 0), segs=5)
        cone(f"Mandible_{tag}", Vector((0.52, 0.03 * side, 1.07)) - head.location, 0.016, 0.06, M["brass_dark"], head, rot=(180, -20, 0), segs=5)
    cone("Crown_Mid", Vector((0.42, 0, 1.27)) - head.location, 0.022, 0.12, M["leg"], head, rot=(0, -10, 0), segs=5)

    # Raptorial forelegs folded in front: coxa, spiked femur up, spiked tibia down, hook, long teal blade.
    arms = empty("Forelegs", (0, 0, 0), root)
    for side, tag in ((-1, "N"), (1, "F")):
        y = side
        hip = Vector((0.22, 0.08 * y, 0.8))
        coxa = Vector((0.34, 0.14 * y, 0.62))
        knee = Vector((0.58, 0.16 * y, 0.98))
        wrist = Vector((0.66, 0.15 * y, 0.62))
        hook = Vector((0.62, 0.14 * y, 0.55))
        tube(f"Coxa_{tag}", [hip, coxa], [0.045, 0.038], M["leg"], arms, sides=8)
        tube(f"Femur_{tag}", [coxa, coxa.lerp(knee, 0.5) + Vector((0.02, 0, 0)), knee], [0.05, 0.042, 0.032], M["leg"], arms, sides=8)
        tube(f"Tibia_{tag}", [knee, wrist], [0.03, 0.022], M["leg"], arms, sides=8)
        tube(f"Hook_{tag}", [wrist, hook], [0.02, 0.006], M["brass_dark"], arms, sides=6)
        sphere(f"Knee_{tag}", knee, (0.045, 0.045, 0.045), M["brass_dark"], arms)
        for k in range(4):
            t = 0.25 + k * 0.18
            cone(f"FemurSpike_{tag}{k}", coxa.lerp(knee, t), 0.012, 0.06, M["brass_dark"], arms, rot=(0, 140, 0), segs=4)
            cone(f"TibiaSpike_{tag}{k}", knee.lerp(wrist, t), 0.01, 0.05, M["brass_dark"], arms, rot=(0, -120, 0), segs=4)
        leaf(f"Blade_{tag}", Vector((0.6, 0.2 * y, 0.98)), Vector((0.74, 0.2 * y, 0.34)), 0.13, M["wing"], arms)

    # Wings: two fans of pointed teal leaves from the thorax, sweeping back over the abdomen, brass vein down each.
    wings = empty("Wings", (0, 0, 0), root)
    fans = [(14, 1.25, 0.26, 0.08), (4, 1.35, 0.3, 0.12), (-6, 1.4, 0.3, 0.16),
            (-15, 1.35, 0.3, 0.2), (-23, 1.25, 0.28, 0.23), (-30, 1.15, 0.24, 0.25)]
    for side, tag in ((-1, "N"), (1, "F")):
        anchor = Vector((0.0, 0.06 * side, 0.76))
        for k, (elev, length, width, spread) in enumerate(fans):
            e = math.radians(elev)
            tip = anchor + Vector((-math.cos(e) * length, spread * side, math.sin(e) * length))
            leaf(f"Fan_{tag}{k}", anchor, tip, width, M["wing"], wings)
            tube(f"Fan_{tag}{k}_Vein", [anchor, anchor.lerp(tip, 0.92)], [0.01, 0.004], M["leg"], wings, sides=5)

    # Sit everything lower than first blocked out: the sprite is wider than tall, and the antennae must
    # clear the stage's top edge. The legs are built after the drop so their feet still meet the ground.
    for child in root.children:
        child.location.z -= 0.1

    # Four walking legs: femur up to a high knee, tibia down to a clawed foot.
    legs = [("Leg_FL", (0.04, -0.1, 0.48), 1), ("Leg_FR", (0.04, 0.1, 0.48), 1),
            ("Leg_HR", (-0.1, 0.11, 0.46), -1), ("Leg_HL", (-0.1, -0.11, 0.46), -1)]
    for name, joint, fwd in legs:
        pivot = empty(name, joint, root)
        side = 1 if joint[1] > 0 else -1
        knee = Vector((0.16, 0.24 * side, 0.2)) if fwd > 0 else Vector((-0.2, 0.28 * side, 0.26))
        foot = Vector((0.36, 0.42 * side, -joint[2] + 0.03)) if fwd > 0 else Vector((-0.52, 0.44 * side, -joint[2] + 0.03))
        tube(name + "_Femur", [Vector((0, 0, 0)), knee], [0.045, 0.036], M["leg"], pivot, sides=8)
        tube(name + "_Tibia", [knee, foot], [0.034, 0.024], M["leg"], pivot, sides=8)
        sphere(name + "_Knee", knee, (0.045, 0.045, 0.045), M["brass_dark"], pivot)
        for k in (-1, 1):
            cone(name + f"_Claw{int(k > 0)}", foot, 0.01, 0.05, M["brass_dark"], pivot, rot=(0, 90 * fwd + 30 * k, 0), segs=4)
    return root


def main():
    root = build()
    render_views(root, "mantis")
    export(root, GLB)
    print("MANTIS_OK", GLB)


main()
