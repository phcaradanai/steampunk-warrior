"""
N02 smoke hound, modelled to match its sprite in game/art/characters/actors-a-v2.png.
Run: /Applications/Blender.app/Contents/MacOS/Blender --background --python prototypes/character-lab/blender/build_dog.py

Black wolf-hound with ember cracks in its fur, red glowing eyes, brass collar and leg greaves,
and a brass boiler on its back with two smokestacks. Nodes Creature3D drives by name:
  Body (one fur mesh), Head (empty), Leg_FL/FR/HR/HL (pivots at shoulder / hip), Tail (pivot at the root).
"""

import math
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creature_kit import *  # noqa: E402,F403

GLB = os.path.join(ROOT, "game/art/characters/dog.glb")

FUR = "2a292d"
PAW = "1a191c"
BRASS = "8e5c18"
BRASS_DARK = "5e3810"
EMBER = "e8400a"
EYE = "ff3a1a"


def fur_body(material):
    """Chest, barrel, rump, maned neck, skull and muzzle blended into one fur mesh."""
    blobs = [
        ((0.2, 0.0, 0.66), (0.26, 0.19, 0.24), -10),      # deep chest
        ((-0.02, 0.0, 0.67), (0.28, 0.16, 0.16), 0),      # barrel, tucked belly
        ((-0.26, 0.0, 0.67), (0.2, 0.17, 0.19), 8),       # rump
        ((-0.27, 0.0, 0.57), (0.14, 0.15, 0.12), 20),     # haunch
        ((0.36, 0.0, 0.8), (0.22, 0.2, 0.24), -40),       # maned neck
        ((0.3, 0.0, 0.62), (0.15, 0.16, 0.15), 0),        # ruff under the throat
        ((0.52, 0.0, 0.94), (0.15, 0.125, 0.125), 0),     # skull
        ((0.72, 0.0, 0.89), (0.18, 0.068, 0.062), 12),    # long muzzle
        ((0.67, 0.0, 0.83), (0.14, 0.055, 0.035), 20),    # lower jaw, dropped in a snarl
    ]
    return blob_body(blobs, material)


def build():
    reset()
    M = {
        "fur": mat("Mat_Fur", FUR, roughness=0.85),
        "paw": mat("Mat_Paw", PAW, roughness=0.8),
        "brass": mat("Mat_Brass", BRASS, metallic=0.7, roughness=0.35),
        "brass_dark": mat("Mat_BrassDark", BRASS_DARK, metallic=0.6, roughness=0.45),
        "ember": mat("Mat_Ember", EMBER, roughness=0.4, glow=1.6),
        "eye": mat("Mat_Eye", EYE, roughness=0.3, glow=3.0),
        "tooth": mat("Mat_Tooth", "efe6d2"),
        "nose": mat("Mat_Nose", "111014"),
    }
    root = empty("Dog", (0, 0, 0))
    body = fur_body(M["fur"])
    body.parent = root

    # Head: pointed ears, red glowing eyes, black nose, bared teeth.
    head = empty("Head", (0.54, 0, 0.94), root)
    for side, tag in ((-1, "N"), (1, "F")):
        cone(f"Ear_{tag}", Vector((0.48, 0.075 * side, 1.0)) - head.location, 0.065, 0.2, M["fur"], head, rot=(10 * side, -6, 0))
        sphere(f"Eye_{tag}", Vector((0.64, 0.085 * side, 0.98)) - head.location, (0.038, 0.02, 0.02), M["eye"], head, rot=(0, 10, 15 * side))
        for k in range(3):
            cone(f"Tooth_{tag}{k}", Vector((0.84 - k * 0.05, 0.045 * side, 0.86)) - head.location, 0.011, 0.04, M["tooth"], head, rot=(180, 0, 0))
    sphere("Nose", Vector((0.9, 0, 0.88)) - head.location, (0.032, 0.035, 0.028), M["nose"], head)

    # Legs pivot at shoulder / hip and run straight down: fur upper leg, brass greave, dark paw.
    legs = [
        ("Leg_FL", (0.26, -0.11, 0.58), "front"),
        ("Leg_FR", (0.26, 0.11, 0.58), "front"),
        ("Leg_HR", (-0.27, 0.12, 0.6), "hind"),
        ("Leg_HL", (-0.27, -0.12, 0.6), "hind"),
    ]
    for name, joint, kind in legs:
        pivot = empty(name, joint, root)
        top = joint[2]
        if kind == "front":
            knee = Vector((0.06, 0, -0.28))
            ankle = Vector((0.12, 0, -top + 0.06))
            tube(name + "_Upper", [Vector((0, 0, 0.06)), Vector((0.01, 0, -0.14)), knee], [0.1, 0.085, 0.07], M["fur"], pivot)
            tube(name + "_Lower", [knee, ankle], [0.065, 0.058], M["fur"], pivot)
        else:
            # Hind leg: thick thigh back to the hock, then the cannon bone forward-down to the paw.
            knee = Vector((-0.12, 0, -0.3))
            ankle = Vector((-0.08, 0, -top + 0.06))
            tube(name + "_Thigh", [Vector((0.02, 0, 0.06)), Vector((-0.02, 0, -0.1)), knee], [0.12, 0.1, 0.07], M["fur"], pivot)
            tube(name + "_Lower", [knee, ankle], [0.065, 0.058], M["fur"], pivot)
        greave_at = Vector((ankle.x, 0, ankle.z + 0.1))
        disc(name + "_Greave", greave_at, 0.085, 0.17, M["brass"], pivot, rot=(0, 0, 0))
        for dz in (-0.06, 0.06):
            ring(name + f"_GreaveRim{int(dz > 0)}", greave_at + Vector((0, 0, dz)), 0.085, 0.016, M["brass_dark"], pivot)
        paw = Vector((ankle.x + 0.04, 0, ankle.z - 0.03))
        sphere(name + "_Paw", paw, (0.1, 0.07, 0.045), M["paw"], pivot)
        for k in range(3):
            sphere(name + f"_Toe{k}", paw + Vector((0.085, (k - 1) * 0.034, -0.006)), (0.035, 0.02, 0.025), M["paw"], pivot)

    # Bushy tail hanging back and down from the rump.
    tail = empty("Tail", (-0.44, 0, 0.72), root)
    pts = smooth_points([(0, 0, 0), (-0.12, 0, -0.03), (-0.22, 0, -0.12), (-0.28, 0, -0.26), (-0.3, 0, -0.4)], 5)
    radii = [0.05 + 0.07 * math.sin(math.pi * min(1.0, i / (len(pts) - 1) * 1.3)) for i in range(len(pts))]
    radii[-1] = 0.015
    tube("Tail_Mesh", pts, radii, M["fur"], tail, sides=12)

    # Ember cracks glowing through the fur on both flanks.
    cracks = [
        [(-0.05, 0.80), (0.0, 0.72), (-0.04, 0.64), (0.03, 0.55)],
        [(-0.2, 0.80), (-0.15, 0.70), (-0.22, 0.60), (-0.18, 0.50)],
        [(0.12, 0.78), (0.17, 0.70), (0.13, 0.62), (0.2, 0.55)],
        [(-0.34, 0.70), (-0.29, 0.60), (-0.35, 0.50), (-0.3, 0.42)],
        [(-0.1, 0.72), (-0.2, 0.70)],
        [(-0.3, 0.78), (-0.4, 0.72)],
        [(0.38, 0.76), (0.42, 0.68)],
    ]
    for side, tag in ((-1, "N"), (1, "F")):
        for k, crack in enumerate(cracks):
            pts = [surface(body, Vector((x, 0.5 * side, z)), 0.004) for x, z in crack]
            tube(f"Crack_{tag}{k}", pts, [0.02] + [0.016] * (len(pts) - 2) + [0.006], M["ember"], root, sides=6)

    # Harness: collar round the neck, girth strap behind the front legs, saddle under the boiler.
    harness = empty("Harness", (0, 0, 0), root)
    band("Collar", body, (0.4, 0, 0.8), (math.cos(math.radians(-50)), 0, math.sin(math.radians(-50))), 0.2, 0.09, M["brass"], harness, thickness=0.04)
    band("Girth", body, (0.06, 0, 0.66), (1, 0, 0), 0.22, 0.06, M["brass_dark"], harness)
    for side, tag in ((-1, "N"), (1, "F")):
        med_at = surface(body, Vector((0.36, 0.5 * side, 0.7)), 0.05)
        disc(f"Collar_Medallion_{tag}", med_at, 0.05, 0.03, M["brass"], harness)
        ring(f"Collar_MedallionRim_{tag}", med_at + Vector((0, 0.016 * side, 0)), 0.045, 0.01, M["brass_dark"], harness, rot=(90, 0, 0))
        for k, (x, z) in enumerate(((0.45, 0.86), (0.3, 0.78), (0.06, 0.76), (0.06, 0.57))):
            sphere(f"Rivet_{tag}{k}", surface(body, Vector((x, 0.5 * side, z)), 0.04), (0.014, 0.014, 0.014), M["brass_dark"], harness, segs=8)

    # Boiler: a glowing brass pot on the spine feeding two stacked smokestacks.
    boiler = empty("Boiler", (-0.02, 0, 0.84), root)
    sphere("Boiler_Pot", Vector((0, 0, 0)), (0.17, 0.15, 0.11), M["brass"], boiler)
    ring("Boiler_Belt", (0, 0, 0.0), 0.16, 0.018, M["brass_dark"], boiler)
    sphere("Boiler_Glow", Vector((0.0, 0, -0.02)), (0.15, 0.17, 0.075), M["ember"], boiler)
    for k, (x, h) in enumerate(((0.12, 0.2), (-0.1, 0.17))):
        base = Vector((x, 0, 0.04))
        disc(f"Stack_{k}", base + Vector((0, 0, h / 2)), 0.06, h, M["brass"], boiler, rot=(0, 0, 0))
        for j in range(3):
            ring(f"Stack_{k}_Ring{j}", base + Vector((0, 0, 0.05 + j * (h - 0.05) / 2)), 0.066, 0.02, M["brass_dark"], boiler)
        disc(f"Stack_{k}_Mouth", base + Vector((0, 0, h + 0.01)), 0.075, 0.03, M["brass"], boiler, rot=(0, 0, 0))
        sphere(f"Stack_{k}_Ember", base + Vector((0, 0, h + 0.025)), (0.055, 0.055, 0.014), M["ember"], boiler)
    return root


def main():
    root = build()
    render_views(root, "dog")
    export(root, GLB)
    print("DOG_OK", GLB)


main()
