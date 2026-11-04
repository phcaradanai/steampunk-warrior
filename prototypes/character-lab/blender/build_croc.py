"""
B01 boiler crocodile (boss), modelled to match its sprite in game/art/characters/actors-b.png.
Run: /Applications/Blender.app/Contents/MacOS/Blender --background --python prototypes/character-lab/blender/build_croc.py

A heavy grey-green crocodile with a ridged back, tan belly and gaping jaw lit teal from inside,
carrying a brass boiler drum with glowing teal windows, gear bosses, pipes and two smokestacks.
Nodes Creature3D drives by name: Body (one hide mesh), Head (empty), Leg_FL/FR/HR/HL (shoulder / hip
pivots), Tail (pivot at the root).
"""

import math
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creature_kit import *  # noqa: E402,F403

GLB = os.path.join(ROOT, "game/art/characters/croc.glb")

HIDE = "4a5a40"
HIDE_DARK = "34402e"
BELLY = "9a8a5a"
BRASS = "9a6a1c"
BRASS_DARK = "4e2e0c"
GLOW = "2fe0c8"
MOUTH = "8a3a34"
TOOTH = "e8e0c8"


def fur_body(material):
    """Barrel body, shoulders, hips, neck and skull blended into one hide mesh; the snout is separate jaws."""
    blobs = [
        ((-0.05, 0.0, 0.38), (0.48, 0.33, 0.28), 0),      # barrel
        ((0.32, 0.0, 0.37), (0.24, 0.3, 0.24), -5),       # shoulders
        ((-0.42, 0.0, 0.35), (0.22, 0.27, 0.22), 5),      # hips
        ((0.58, 0.0, 0.39), (0.17, 0.19, 0.17), -5),      # neck
        ((0.74, 0.0, 0.43), (0.15, 0.16, 0.12), 0),       # skull
    ]
    return blob_body(blobs, material)


def build():
    reset()
    M = {
        "hide": mat("Mat_Hide", HIDE, roughness=0.8),
        "hide_dark": mat("Mat_HideDark", HIDE_DARK, roughness=0.8),
        "belly": mat("Mat_Belly", BELLY, roughness=0.8),
        "brass": mat("Mat_Brass", BRASS, metallic=0.7, roughness=0.35),
        "brass_dark": mat("Mat_BrassDark", BRASS_DARK, metallic=0.6, roughness=0.45),
        "glow": mat("Mat_Glow", GLOW, roughness=0.2, glow=1.8),
        "mouth": mat("Mat_Mouth", MOUTH, roughness=0.6),
        "tooth": mat("Mat_Tooth", TOOTH, roughness=0.4),
        "eye": mat("Mat_Eye", "ffb020", roughness=0.3, glow=2.0),
    }
    root = empty("Croc", (0, 0, 0))
    body = fur_body(M["hide"])
    body.parent = root

    # Belly plate and the double row of dorsal ridges from the neck to the hips.
    sphere("Belly", Vector((0.0, 0, 0.2)), (0.6, 0.24, 0.1), M["belly"], root)
    ridges = empty("Ridges", (0, 0, 0), root)
    for i in range(10):
        x = 0.5 - i * 0.1
        for y in (-0.12, 0.12):
            _, at, normal, _ = body.closest_point_on_mesh(Vector((x, y, 1.0)))
            cone(f"Ridge_{i}_{int(y > 0)}", at - normal * 0.01, 0.045, 0.07, M["hide_dark"], ridges, segs=4)

    # Boiler: a horizontal brass drum on the back with glowing windows, bands, gear bosses, pipes and stacks.
    boiler = empty("Boiler", (-0.02, 0, 0.66), root)
    disc("Drum", Vector((0, 0, 0)), 0.26, 0.8, M["brass"], boiler, rot=(0, 90, 0))
    for k, x in enumerate((-0.37, -0.13, 0.13, 0.37)):
        ring(f"Drum_Band{k}", (x, 0, 0), 0.265, 0.022, M["brass_dark"], boiler, rot=(0, 90, 0))
    for side, tag in ((-1, "N"), (1, "F")):
        for k, x in enumerate((-0.22, 0.0, 0.22)):
            at = Vector((x, 0.23 * side, 0.03))
            sphere(f"Window_{tag}{k}", at, (0.075, 0.045, 0.11), M["glow"], boiler)
            ring(f"Window_{tag}{k}_Rim", at + Vector((0, 0.012 * side, 0)), 0.085, 0.016, M["brass_dark"], boiler, rot=(90, 0, 0))
        gear_at = Vector((0.4, 0.25 * side, -0.1))
        disc(f"Gear_{tag}", gear_at, 0.075, 0.04, M["brass"], boiler)
        ring(f"Gear_{tag}_Rim", gear_at + Vector((0, 0.02 * side, 0)), 0.07, 0.014, M["brass_dark"], boiler, rot=(90, 0, 0))
        tube(f"Pipe_{tag}", [Vector((-0.36, 0.2 * side, -0.05)), Vector((-0.4, 0.24 * side, -0.18)), Vector((-0.3, 0.27 * side, -0.24))],
             [0.022, 0.022, 0.022], M["brass"], boiler, sides=8)
    for k, (x, h) in enumerate(((-0.2, 0.2), (0.12, 0.24))):
        base = Vector((x, 0, 0.22))
        disc(f"Stack_{k}", base + Vector((0, 0, h / 2)), 0.06, h, M["brass"], boiler, rot=(0, 0, 0))
        ring(f"Stack_{k}_Ring", base + Vector((0, 0, h * 0.4)), 0.066, 0.016, M["brass_dark"], boiler)
        disc(f"Stack_{k}_Mouth", base + Vector((0, 0, h + 0.015)), 0.078, 0.035, M["brass"], boiler, rot=(0, 0, 0))
    # Straps hang off the root: band() shrinkwraps in world space, so its parent must sit at the origin.
    band("Strap_Front", body, (0.3, 0, 0.38), (1, 0, 0.1), 0.3, 0.07, M["brass_dark"], root, thickness=0.035)
    band("Strap_Back", body, (-0.34, 0, 0.38), (1, 0, -0.1), 0.28, 0.07, M["brass_dark"], root, thickness=0.035)

    # Head: long open jaws with teeth and a teal glow in the throat, amber eyes on top.
    head = empty("Head", (0.76, 0, 0.43), root)
    upper = smooth_points([(0.72, 0, 0.47), (0.95, 0, 0.5), (1.12, 0, 0.5)], 3)
    tube("Jaw_Upper", [p - head.location for p in upper], [0.15 - 0.07 * i / (len(upper) - 1) for i in range(len(upper))], M["hide"], head, sides=10)
    lower = smooth_points([(0.72, 0, 0.35), (0.93, 0, 0.27), (1.08, 0, 0.21)], 3)
    tube("Jaw_Lower", [p - head.location for p in lower], [0.13 - 0.07 * i / (len(lower) - 1) for i in range(len(lower))], M["hide"], head, sides=10)
    sphere("Mouth", Vector((0.86, 0, 0.39)) - head.location, (0.16, 0.09, 0.07), M["mouth"], head, rot=(0, 12, 0))
    sphere("Throat_Glow", Vector((0.82, 0, 0.4)) - head.location, (0.09, 0.08, 0.055), M["glow"], head)
    for side, tag in ((-1, "N"), (1, "F")):
        sphere(f"Eye_{tag}", Vector((0.76, 0.1 * side, 0.57)) - head.location, (0.035, 0.03, 0.03), M["eye"], head)
        for k in range(6):
            t = k / 5
            cone(f"ToothU_{tag}{k}", Vector((0.84 + t * 0.26, 0.075 * side * (1 - 0.4 * t), 0.42 + 0.03 * t)) - head.location, 0.014, 0.05, M["tooth"], head, rot=(180, 0, 0), segs=4)
            cone(f"ToothL_{tag}{k}", Vector((0.84 + t * 0.22, 0.07 * side * (1 - 0.4 * t), 0.31 - 0.07 * t)) - head.location, 0.013, 0.045, M["tooth"], head, segs=4)

    # Sprawled legs: upper leg out and down to the elbow, then a clawed foot planted wide.
    legs = [("Leg_FL", (0.34, -0.2, 0.28), 1), ("Leg_FR", (0.34, 0.2, 0.28), 1),
            ("Leg_HR", (-0.42, 0.2, 0.28), -1), ("Leg_HL", (-0.42, -0.2, 0.28), -1)]
    for name, joint, fwd in legs:
        pivot = empty(name, joint, root)
        side = 1 if joint[1] > 0 else -1
        elbow = Vector((0.02 * fwd, 0.1 * side, -0.12))
        foot = Vector((0.08 * fwd, 0.14 * side, -joint[2] + 0.04))
        tube(name + "_Upper", [Vector((0, 0, 0.04)), elbow], [0.12, 0.095], M["hide"], pivot)
        tube(name + "_Lower", [elbow, foot], [0.09, 0.07], M["hide"], pivot)
        sphere(name + "_Foot", foot + Vector((0.03 * fwd, 0, -0.01)), (0.11, 0.08, 0.035), M["hide_dark"], pivot)
        for k, a in enumerate((-35, 0, 35)):
            d = Vector((math.cos(math.radians(a)) * fwd, math.sin(math.radians(a)), 0))
            cone(name + f"_Claw{k}", foot + Vector((0.03 * fwd, 0, -0.02)) + d * 0.08, 0.016, 0.05, M["tooth"], pivot,
                 rot=(0, 90 * fwd, a * fwd), segs=4)

    # Thick tail tapering back along the ground, ridged on top.
    tail = empty("Tail", (-0.56, 0, 0.34), root)
    pts = smooth_points([(0, 0, 0), (-0.25, 0, -0.08), (-0.5, 0, -0.18), (-0.7, 0, -0.24)], 5)
    radii = [0.22 * (1 - 0.88 * i / (len(pts) - 1)) for i in range(len(pts))]
    tube("Tail_Mesh", pts, radii, M["hide"], tail, sides=12)
    for i in range(1, len(pts) - 1, 2):
        cone(f"Tail_Ridge{i}", pts[i] + Vector((0, 0, radii[i] * 0.85)), radii[i] * 0.35, radii[i] * 0.5, M["hide_dark"], tail, segs=4)
    # Nose to tail tip must fit the 2-unit-wide square stage the code frames it in.
    root.scale = (0.88, 0.88, 0.88)
    return root


def main():
    root = build()
    render_views(root, "croc")
    export(root, GLB)
    print("CROC_OK", GLB)


main()
