"""
N08 brass heron, modelled to match its sprite in game/art/characters/actors-a-v2.png.
Run: /Applications/Blender.app/Contents/MacOS/Blender --background --python prototypes/character-lab/blender/build_heron.py

A brass-plated heron with folded teal-green wings and a long feather tail, an S-curved neck with a
glowing green throat sac, a dark crest, a long gold beak and two thin brass legs with clawed toes.
The wings stay folded, so they are not named Wing_* (Creature3D would flap them).
Nodes Creature3D drives by name: Body (one brass mesh), Head (empty), Leg_HL / Leg_HR (hip pivots).
"""

import math
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creature_kit import *  # noqa: E402,F403

GLB = os.path.join(ROOT, "game/art/characters/heron.glb")

BRASS = "8e5c18"
BRASS_DARK = "4e2e0c"
FEATHER = "1f6a62"
FEATHER_LIGHT = "2f8a5a"
SAC = "5ae04a"
BEAK = "b08a2a"
CREST = "1e1a18"


def fur_body(material):
    """Breast, back, rump and the S-curved neck blended into one brass mesh."""
    blobs = [
        ((0.05, 0.0, 0.78), (0.32, 0.2, 0.24), -22),      # breast and back
        ((-0.24, 0.0, 0.68), (0.22, 0.16, 0.16), -25),    # rump
        ((0.26, 0.0, 0.98), (0.13, 0.11, 0.15), -40),     # neck base
        ((0.3, 0.0, 1.15), (0.09, 0.08, 0.12), 10),       # neck curve back
        ((0.34, 0.0, 1.3), (0.08, 0.075, 0.1), -25),      # upper neck
        ((0.4, 0.0, 1.4), (0.12, 0.09, 0.09), 0),         # head
    ]
    return blob_body(blobs, material)


def feather(name, root_at, length, width, lean, side, material, parent):
    """One long flat feather: a stretched leaf from root_at, leaning back and down by `lean` degrees."""
    d = Vector((-math.cos(math.radians(lean)), 0, -math.sin(math.radians(lean))))
    tip = Vector(root_at) + d * length
    mid = Vector(root_at).lerp(tip, 0.45)
    return tube(name, [Vector(root_at), mid, tip], [width * 0.4, width, 0.004], material, parent, sides=6)


def build():
    reset()
    M = {
        "brass": mat("Mat_Brass", BRASS, metallic=0.7, roughness=0.35),
        "brass_dark": mat("Mat_BrassDark", BRASS_DARK, metallic=0.6, roughness=0.45),
        "feather": mat("Mat_Feather", FEATHER, roughness=0.6),
        "feather_light": mat("Mat_FeatherLight", FEATHER_LIGHT, roughness=0.6),
        "sac": mat("Mat_Sac", SAC, roughness=0.2, glow=1.6),
        "beak": mat("Mat_Beak", BEAK, metallic=0.5, roughness=0.35),
        "crest": mat("Mat_Crest", CREST, roughness=0.7),
        "eye": mat("Mat_Eye", "f0c020", roughness=0.3, glow=1.2),
    }
    root = empty("Heron", (0, 0, 0))
    body = fur_body(M["brass"])
    body.parent = root

    # Plating seams across the breast and down the neck.
    plates = empty("Plates", (0, 0, 0), root)
    for k, (x, z, r) in enumerate(((0.14, 0.84, 0.21), (0.02, 0.76, 0.23), (-0.12, 0.7, 0.2))):
        band(f"Seam_{k}", body, (x, 0, z), (1, 0, -0.4), r, 0.02, M["brass_dark"], plates, thickness=0.02)
    for k, z in enumerate((1.04, 1.13, 1.22, 1.3)):
        band(f"NeckRing_{k}", body, (0.31, 0, z), (0.2, 0, 1), 0.1, 0.018, M["brass_dark"], plates, thickness=0.02)

    # Folded wings: layered feathers along each flank, and a long tail fan.
    wings = empty("Feathers", (0, 0, 0), root)
    for side, tag in ((-1, "N"), (1, "F")):
        for k in range(6):
            at = surface(body, Vector((0.26 - k * 0.06, side * 0.5, 0.92 - k * 0.04)), 0.01)
            feather(f"Fold_{tag}{k}", at, 0.55 + k * 0.06, 0.1, 18 + k * 4, side,
                    M["feather"] if k % 2 else M["feather_light"], wings)
        cover = surface(body, Vector((0.1, side * 0.5, 0.86)), 0.0)
        sphere(f"Shoulder_{tag}", cover, (0.22, 0.035, 0.09), M["brass"], wings, rot=(0, 22, 0))
    for k in range(5):
        y = (k - 2) * 0.035
        feather(f"Tail_{k}", (-0.38, y, 0.66), 0.42 - abs(k - 2) * 0.04, 0.06, 38 + abs(k - 2) * 4, 0, M["feather"], wings)

    # Head: dark swept crest, gold eye, long gold beak, glowing throat sac hanging under the jaw.
    head = empty("Head", (0.4, 0, 1.4), root)
    for k in range(4):
        cone(f"Crest_{k}", Vector((0.36 - k * 0.02, 0, 1.46 - k * 0.01)) - head.location, 0.02, 0.16 + k * 0.03, M["crest"], head, rot=(0, -70 - k * 6, 0), segs=5)
    for side, tag in ((-1, "N"), (1, "F")):
        sphere(f"Eye_{tag}", Vector((0.45, 0.075 * side, 1.43)) - head.location, (0.018, 0.01, 0.014), M["eye"], head)
    cone("Beak_Upper", Vector((0.49, 0, 1.4)) - head.location, 0.038, 0.42, M["beak"], head, rot=(0, 94, 0), segs=8)
    cone("Beak_Lower", Vector((0.48, 0, 1.375)) - head.location, 0.028, 0.36, M["beak"], head, rot=(0, 99, 0), segs=8)
    sphere("Throat_Sac", Vector((0.44, 0, 1.18)) - head.location, (0.11, 0.1, 0.17), M["sac"], head, rot=(0, -12, 0))

    # Legs: thin brass shank to a backward ankle, then down to three forward toes and a hind claw.
    for side, tag in ((-1, "L"), (1, "R")):
        pivot = empty(f"Leg_H{tag}", (0.0, 0.08 * side, 0.6), root)
        knee = Vector((0.08, 0, -0.22))
        foot = Vector((0.0, 0, -0.58))
        tube(f"Leg_H{tag}_Thigh", [Vector((0, 0, 0.04)), knee], [0.055, 0.032], M["brass"], pivot, sides=8)
        sphere(f"Leg_H{tag}_Knee", knee, (0.035, 0.035, 0.035), M["brass_dark"], pivot)
        tube(f"Leg_H{tag}_Shank", [knee, foot], [0.03, 0.024], M["brass"], pivot, sides=8)
        for k, a in enumerate((-30, 0, 30)):
            d = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0))
            tube(f"Leg_H{tag}_Toe{k}", [foot, foot + d * 0.12 + Vector((0, 0, -0.012))], [0.016, 0.008], M["brass"], pivot, sides=6)
        tube(f"Leg_H{tag}_Hallux", [foot, foot + Vector((-0.08, 0, -0.012))], [0.014, 0.007], M["brass"], pivot, sides=6)
    return root


def main():
    root = build()
    render_views(root, "heron")
    export(root, GLB)
    print("HERON_OK", GLB)


main()
