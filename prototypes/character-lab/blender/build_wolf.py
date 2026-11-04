"""
N09 grove wolf, modelled to match its sprite in game/art/characters/actors-a-v2.png.
Run: /Applications/Blender.app/Contents/MacOS/Blender --background --python prototypes/character-lab/blender/build_wolf.py

A lean brown wolf overgrown by the forest: moss tufts along the back and tail, wooden branches
curling over the shoulders and down the forelegs, branching antlers on the head, a pale face and
throat ruff, green eyes and a black nose. Nodes Creature3D drives by name:
  Body (one fur mesh), Head (empty), Leg_FL/FR/HR/HL (shoulder / hip pivots), Tail (pivot at the root).
"""

import math
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creature_kit import *  # noqa: E402,F403

GLB = os.path.join(ROOT, "game/art/characters/wolf.glb")

FUR = "7a5a3a"
FUR_PALE = "a89478"
MOSS = "42581a"
MOSS_LIGHT = "566e22"
WOOD = "8a5428"
WOOD_DARK = "5a3418"
PAW = "3a2818"


def fur_body(material):
    """Chest, lean barrel, rump, neck, skull and long muzzle blended into one fur mesh."""
    blobs = [
        ((0.2, 0.0, 0.66), (0.24, 0.17, 0.22), -10),      # chest
        ((-0.02, 0.0, 0.66), (0.28, 0.14, 0.15), 0),      # barrel, tucked belly
        ((-0.27, 0.0, 0.66), (0.19, 0.15, 0.18), 8),      # rump
        ((-0.27, 0.0, 0.56), (0.13, 0.13, 0.11), 20),     # haunch
        ((0.36, 0.0, 0.8), (0.17, 0.15, 0.18), -40),      # neck
        ((0.52, 0.0, 0.92), (0.14, 0.11, 0.11), 0),       # skull
        ((0.7, 0.0, 0.87), (0.16, 0.06, 0.055), 12),      # long muzzle
    ]
    return blob_body(blobs, material)


def tuft(name, body, near, size, material, parent):
    """Moss tuft: a leaning cone standing out of the fur where a ray from `near` toward the spine meets it."""
    centre = Vector((near.x, 0, 0.66))
    hit, at, normal, _ = body.ray_cast(near, (centre - near).normalized())
    if not hit:
        _, at, normal, _ = body.closest_point_on_mesh(near)
    lean = (normal + Vector((-0.8, 0, 0.2))).normalized()
    rot = [math.degrees(a) for a in lean.to_track_quat("Z", "Y").to_euler()]
    return cone(name, at - normal * 0.015, size * 0.45, size, material, parent, rot=rot, segs=5)


def branch(name, points, radius, material, parent, forks=()):
    """Curving wooden branch through points, with short forks (index, offset) splitting off it."""
    pts = smooth_points(points, 4)
    tube(name, pts, [radius * (1 - 0.8 * i / (len(pts) - 1)) for i in range(len(pts))], material, parent, sides=7)
    for k, (i, off) in enumerate(forks):
        base = Vector(points[i])
        tube(f"{name}_Fork{k}", [base, base + Vector(off)], [radius * 0.6, radius * 0.15], material, parent, sides=6)


def build():
    reset()
    M = {
        "fur": mat("Mat_Fur", FUR, roughness=0.85),
        "pale": mat("Mat_FurPale", FUR_PALE, roughness=0.85),
        "moss": mat("Mat_Moss", MOSS, roughness=0.9),
        "moss_light": mat("Mat_MossLight", MOSS_LIGHT, roughness=0.9),
        "wood": mat("Mat_Wood", WOOD, roughness=0.8),
        "wood_dark": mat("Mat_WoodDark", WOOD_DARK, roughness=0.8),
        "paw": mat("Mat_Paw", PAW, roughness=0.8),
        "eye": mat("Mat_Eye", "8ae030", roughness=0.3, glow=1.8),
        "nose": mat("Mat_Nose", "141010", roughness=0.4),
    }
    root = empty("Wolf", (0, 0, 0))
    body = fur_body(M["fur"])
    body.parent = root

    # Pale face and throat ruff.
    sphere("Ruff", Vector((0.4, 0, 0.72)), (0.12, 0.13, 0.14), M["pale"], root, rot=(0, -30, 0))

    # Moss mantle along the back, from the neck to the rump.
    mantle = empty("Mantle", (0, 0, 0), root)
    k = 0
    for i in range(12):
        x = 0.42 - i * 0.07
        for a in range(-105, 106, 35):
            ang = math.radians(a + (15 if i % 2 else 0))
            size = 0.11 + 0.04 * math.sin(math.pi * i / 11) - abs(ang) * 0.02
            near = Vector((x, math.sin(ang), 0.66 + math.cos(ang)))
            tuft(f"Moss_{k}", body, near, size, M["moss"] if k % 3 else M["moss_light"], mantle)
            k += 1

    # Branches curling up off the shoulders and the hips, both flanks.
    for side, tag in ((-1, "N"), (1, "F")):
        y = 0.14 * side
        branch(f"Branch_Shoulder_{tag}", [(0.18, y, 0.72), (0.12, y * 1.2, 0.86), (0.18, y * 1.3, 1.0), (0.1, y * 1.3, 1.1)], 0.03, M["wood"], mantle,
               forks=((1, (-0.1, 0.02 * side, 0.08)), (2, (0.07, 0.02 * side, 0.08))))
        branch(f"Branch_Back_{tag}", [(-0.05, y, 0.76), (-0.12, y * 1.1, 0.88), (-0.08, y * 1.2, 0.98)], 0.025, M["wood_dark"], mantle,
               forks=((1, (-0.08, 0.0, 0.05)),))
        branch(f"Branch_Hip_{tag}", [(-0.3, y, 0.74), (-0.38, y * 1.1, 0.84), (-0.46, y * 1.1, 0.88)], 0.025, M["wood"], mantle,
               forks=((1, (0.0, 0.0, 0.09)),))

    # Head: green eyes, black nose, pointed ears, antlers branching up and back.
    head = empty("Head", (0.54, 0, 0.92), root)
    sphere("Face", Vector((0.6, 0, 0.86)) - head.location, (0.12, 0.08, 0.06), M["pale"], head, rot=(0, 12, 0))
    for side, tag in ((-1, "N"), (1, "F")):
        cone(f"Ear_{tag}", Vector((0.47, 0.065 * side, 1.0)) - head.location, 0.045, 0.14, M["fur"], head, rot=(10 * side, -15, 0), segs=6)
        sphere(f"Eye_{tag}", Vector((0.62, 0.075 * side, 0.95)) - head.location, (0.026, 0.014, 0.013), M["eye"], head, rot=(0, 10, 15 * side))
        y = 0.06 * side
        antler = [(0.48, y, 1.0), (0.42, y * 1.5, 1.12), (0.36, y * 2.0, 1.24), (0.26, y * 2.2, 1.3)]
        branch(f"Antler_{tag}", [Vector(p) - head.location for p in antler], 0.022, M["wood"], head,
               forks=((1, (0.08, 0.02 * side, 0.1)), (2, (0.02, 0.03 * side, 0.12)), (3, (-0.04, 0.0, 0.08))))
    sphere("Nose", Vector((0.855, 0, 0.885)) - head.location, (0.028, 0.03, 0.024), M["nose"], head)

    # Legs: fur upper leg, a wooden branch wrapping the front shins, pale-brown paws.
    legs = [("Leg_FL", (0.24, -0.1, 0.56), "front"), ("Leg_FR", (0.24, 0.1, 0.56), "front"),
            ("Leg_HR", (-0.27, 0.11, 0.56), "hind"), ("Leg_HL", (-0.27, -0.11, 0.56), "hind")]
    for name, joint, kind in legs:
        pivot = empty(name, joint, root)
        top = joint[2]
        if kind == "front":
            knee = Vector((0.04, 0, -0.26))
            ankle = Vector((0.08, 0, -top + 0.05))
            tube(name + "_Upper", [Vector((0, 0, 0.06)), Vector((0.01, 0, -0.12)), knee], [0.075, 0.06, 0.045], M["fur"], pivot)
            branch(name + "_Bark", [Vector((0.02, 0, -0.02)), knee + Vector((0.03, 0, 0)), ankle + Vector((0.02, 0, 0.06))], 0.03, M["wood"], pivot)
        else:
            knee = Vector((-0.1, 0, -0.26))
            ankle = Vector((-0.04, 0, -top + 0.05))
            tube(name + "_Thigh", [Vector((0.02, 0, 0.06)), Vector((-0.04, 0, -0.1)), knee], [0.09, 0.075, 0.045], M["fur"], pivot)
        tube(name + "_Lower", [knee, ankle], [0.042, 0.036], M["fur"], pivot)
        paw = Vector((ankle.x + 0.04, 0, ankle.z - 0.02))
        sphere(name + "_Paw", paw, (0.07, 0.05, 0.035), M["paw"], pivot)
        for t in range(3):
            sphere(name + f"_Toe{t}", paw + Vector((0.06, (t - 1) * 0.026, -0.005)), (0.026, 0.015, 0.02), M["paw"], pivot)

    # Bushy mossy tail sweeping back and down.
    tail = empty("Tail", (-0.44, 0, 0.7), root)
    pts = smooth_points([(0, 0, 0), (-0.14, 0, -0.04), (-0.26, 0, -0.14), (-0.32, 0, -0.28), (-0.33, 0, -0.42)], 5)
    radii = [0.04 + 0.06 * math.sin(math.pi * min(1.0, i / (len(pts) - 1) * 1.2)) for i in range(len(pts))]
    radii[-1] = 0.012
    tail_mesh = tube("Tail_Mesh", pts, radii, M["fur"], tail, sides=12)
    for i in range(2, len(pts) - 1, 2):
        p = pts[i]
        cone(f"Tail_Moss{i}", p + Vector((0.0, 0, radii[i] * 0.7)), radii[i] * 0.6, radii[i] * 1.4, M["moss"], tail, rot=(0, -60, 0), segs=5)
    return root


def main():
    root = build()
    render_views(root, "wolf")
    export(root, GLB)
    print("WOLF_OK", GLB)


main()
