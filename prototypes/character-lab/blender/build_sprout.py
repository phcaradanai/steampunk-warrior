"""
Root sprout summon (หน่อรากแก้ว), modelled to match its sprite "root" in game/art/characters/actors-b.png.
Run: /Applications/Blender.app/Contents/MacOS/Blender --background --python prototypes/character-lab/blender/build_sprout.py

A low bark-scaled creature with a mane of broad green leaves along its back, a glowing teal glass orb
set in a riveted brass bezel on each flank, a small wooden face with teal eyes, and stubby clawed legs.
Nodes Creature3D drives by name: Body (one bark mesh), Head (empty), Leg_FL/FR/HR/HL (pivots), Tail.
"""

import math
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creature_kit import *  # noqa: E402,F403

GLB = os.path.join(ROOT, "game/art/characters/sprout.glb")

BARK = "6a4424"
BARK_DARK = "4a2c14"
LEAF = "4a8a2a"
LEAF_LIGHT = "6aa83a"
BRASS = "9a6a1c"
BRASS_DARK = "4e2e0c"
GLOW = "2fe0c8"


def fur_body(material):
    """Domed back, belly, rump and a short neck into the small head, blended into one bark mesh."""
    blobs = [
        ((0.0, 0.0, 0.34), (0.34, 0.24, 0.2), 0),         # domed back
        ((-0.26, 0.0, 0.3), (0.18, 0.2, 0.16), 10),       # rump
        ((0.26, 0.0, 0.32), (0.14, 0.16, 0.14), -10),     # shoulders and neck
        ((0.42, 0.0, 0.33), (0.14, 0.13, 0.11), 5),        # head
    ]
    return blob_body(blobs, material)


def facing(normal, tilt):
    """Euler (degrees) turning +Z along `normal` leaned back by `tilt`, for leaves and scales."""
    d = (normal + Vector((-tilt, 0, 0))).normalized()
    return [math.degrees(a) for a in d.to_track_quat("Z", "Y").to_euler()]


def build():
    reset()
    M = {
        "bark": mat("Mat_Bark", BARK, roughness=0.85),
        "bark_dark": mat("Mat_BarkDark", BARK_DARK, roughness=0.85),
        "leaf": mat("Mat_Leaf", LEAF, roughness=0.7),
        "leaf_light": mat("Mat_LeafLight", LEAF_LIGHT, roughness=0.7),
        "brass": mat("Mat_Brass", BRASS, metallic=0.7, roughness=0.35),
        "brass_dark": mat("Mat_BrassDark", BRASS_DARK, metallic=0.6, roughness=0.45),
        "glow": mat("Mat_Glow", GLOW, roughness=0.15, glow=1.8),
    }
    root = empty("Sprout", (0, 0, 0))
    body = fur_body(M["bark"])
    body.parent = root

    # Bark scales overlapping down the flanks, leaves fanning up along the spine.
    cover = empty("Cover", (0, 0, 0), root)
    k = 0
    for i in range(9):
        x = 0.3 - i * 0.07
        for a in range(-110, 111, 22):
            ang = math.radians(a + (11 if i % 2 else 0))
            near = Vector((x, math.sin(ang), 0.32 + math.cos(ang)))
            hit, at, normal, _ = body.ray_cast(near, (Vector((x, 0, 0.32)) - near).normalized())
            if not hit:
                continue
            if abs(a) <= 44:
                if (i + k) % 2:
                    k += 1
                    continue
                size = 0.13 + 0.05 * math.sin(math.pi * i / 8)
                sphere(f"Leaf_{k}", at + normal * size * 0.5, (0.016, size * 0.5, size), M["leaf"] if k % 3 else M["leaf_light"], cover,
                       rot=facing(normal, 1.1), segs=8)
            else:
                cone(f"Scale_{k}", at - normal * 0.01, 0.045, 0.07, M["bark_dark"] if k % 2 else M["bark"], cover,
                     rot=facing(normal, 1.2), segs=4)
            k += 1

    # Glass orb set in a riveted brass bezel on each flank.
    for side, tag in ((-1, "N"), (1, "F")):
        at = surface(body, Vector((0.04, 0.6 * side, 0.36)), 0.02)
        sphere(f"Orb_{tag}", at, (0.16, 0.08, 0.16), M["glow"], root)
        ring(f"Orb_{tag}_Bezel", at + Vector((0, 0.03 * side, 0)), 0.165, 0.03, M["brass"], root, rot=(90, 0, 0), seg=32)
        for j in range(8):
            t = math.radians(j * 45)
            sphere(f"Orb_{tag}_Rivet{j}", at + Vector((0.165 * math.cos(t), 0.055 * side, 0.165 * math.sin(t))), (0.012, 0.012, 0.012), M["brass_dark"], root, segs=6)

    # Head: wooden face with glowing eyes and a leaf crest.
    head = empty("Head", (0.45, 0, 0.33), root)
    for side, tag in ((-1, "N"), (1, "F")):
        sphere(f"Eye_{tag}", Vector((0.51, 0.08 * side, 0.37)) - head.location, (0.034, 0.024, 0.03), M["glow"], head)
        sphere(f"Crest_{tag}", Vector((0.38, 0.05 * side, 0.44)) - head.location, (0.018, 0.04, 0.09), M["leaf_light"], head, rot=(25 * side, -20, 0), segs=8)
    cone("Snout", Vector((0.54, 0, 0.31)) - head.location, 0.05, 0.06, M["bark_dark"], head, rot=(0, 90, 0), segs=6)

    # Stubby bark legs with root-like claws.
    legs = [("Leg_FL", (0.2, -0.14, 0.22)), ("Leg_FR", (0.2, 0.14, 0.22)),
            ("Leg_HR", (-0.24, 0.14, 0.22)), ("Leg_HL", (-0.24, -0.14, 0.22))]
    for name, joint in legs:
        pivot = empty(name, joint, root)
        side = 1 if joint[1] > 0 else -1
        foot = Vector((0.04, 0.06 * side, -joint[2] + 0.04))
        tube(name + "_Leg", [Vector((0, 0, 0.04)), foot], [0.09, 0.065], M["bark"], pivot)
        for k, a in enumerate((-30, 0, 30)):
            d = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), -0.2)).normalized()
            tube(name + f"_Claw{k}", [foot, foot + d * 0.09], [0.018, 0.005], M["bark_dark"], pivot, sides=5)

    tail = empty("Tail", (-0.42, 0, 0.28), root)
    pts = smooth_points([(0, 0, 0), (-0.1, 0, -0.06), (-0.18, 0, -0.16), (-0.2, 0, -0.24)], 4)
    tube("Tail_Mesh", pts, [0.07 * (1 - 0.85 * i / (len(pts) - 1)) for i in range(len(pts))], M["bark"], tail, sides=8)
    # The sprite reads as a sturdy beast beside the boss, not a seedling.
    root.scale = (1.35, 1.35, 1.35)
    return root


def main():
    root = build()
    render_views(root, "sprout")
    export(root, GLB)
    print("SPROUT_OK", GLB)


main()
