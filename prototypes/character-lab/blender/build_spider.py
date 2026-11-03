"""
N06 glass spider, modelled to match its sprite in game/art/characters/actors-a-v2.png.
Run: /Applications/Blender.app/Contents/MacOS/Blender --background --python prototypes/character-lab/blender/build_spider.py

A brass automaton spider whose abdomen is a glass orb of swirling aether held in a brass meridian
ring, a domed brass head with six glowing teal eyes, and eight segmented brass legs ending in dark claws.
Nodes Creature3D drives by name: Body (dark core mesh), Head (empty), Leg_<pair><a|b> (hip pivots).
"""

import math
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creature_kit import *  # noqa: E402,F403

GLB = os.path.join(ROOT, "game/art/characters/spider.glb")

CORE = "1e2224"
BRASS = "7c4c14"
BRASS_DARK = "40260c"
GLASS = "1c5450"
AETHER = "3ff0c0"
EYE = "35e8d8"
CLAW = "1a1a1e"

ORB = Vector((-0.2, 0, 0.56))
ORB_R = 0.32


def fur_body(material):
    """Dark core: head, waist and the cup under the orb, blended into one mesh."""
    blobs = [
        ((0.24, 0.0, 0.34), (0.24, 0.2, 0.15), -5),       # cephalothorax
        ((0.02, 0.0, 0.34), (0.12, 0.1, 0.09), 0),        # waist
        ((-0.2, 0.0, 0.3), (0.2, 0.18, 0.1), 0),          # cup under the orb
    ]
    return blob_body(blobs, material)


def build():
    reset()
    M = {
        "core": mat("Mat_Core", CORE, roughness=0.7),
        "brass": mat("Mat_Brass", BRASS, metallic=0.7, roughness=0.35),
        "brass_dark": mat("Mat_BrassDark", BRASS_DARK, metallic=0.6, roughness=0.45),
        "glass": mat("Mat_Glass", GLASS, roughness=0.1),
        "aether": mat("Mat_Aether", AETHER, roughness=0.2, glow=2.6),
        "eye": mat("Mat_Eye", EYE, roughness=0.15, glow=2.0),
        "claw": mat("Mat_Claw", CLAW, roughness=0.5),
    }
    root = empty("Spider", (0, 0, 0))
    body = fur_body(M["core"])
    body.parent = root

    # Abdomen: glass orb with aether lightning crawling over it, a brass meridian ring, base collar and top knob.
    orb_node = empty("Orb", (0, 0, 0), root)
    orb = sphere("Orb_Glass", ORB, (ORB_R, ORB_R * 0.95, ORB_R), M["glass"], orb_node, segs=32)
    bolts = [[(-50, 30), (-20, 10), (5, 35), (30, 15)], [(-10, -30), (20, -10), (45, -35)],
             [(150, 20), (120, -5), (95, 25)], [(200, -20), (230, 5), (260, -15)], [(60, 50), (80, 20), (110, 40)], [(-80, -20), (-60, 5), (-95, 30)], [(-130, 40), (-160, 15), (-140, -15)]]
    for k, bolt in enumerate(bolts):
        pts = []
        for lon, lat in bolt:
            d = Vector((math.cos(math.radians(lat)) * math.cos(math.radians(lon)),
                        math.cos(math.radians(lat)) * math.sin(math.radians(lon)), math.sin(math.radians(lat))))
            pts.append(ORB + Vector((d.x * ORB_R, d.y * ORB_R * 0.95, d.z * ORB_R)) * 1.0)
        pts = [surface(orb, p, 0.004) for p in pts]
        tube(f"Bolt_{k}", pts, [0.022] * (len(pts) - 1) + [0.008], M["aether"], orb_node, sides=6)
    ring("Meridian", ORB, ORB_R + 0.03, 0.028, M["brass"], orb_node, rot=(90, 0, 0), seg=40)
    for k in range(10):
        a = math.radians(20 + k * 16)
        at = ORB + Vector((math.cos(a) * (ORB_R + 0.03), -0.03, math.sin(a) * (ORB_R + 0.03)))
        sphere(f"Meridian_Stud_{k}", at, (0.014, 0.014, 0.014), M["brass_dark"], orb_node, segs=8)
    ring("Orb_Collar", ORB + Vector((0, 0, -0.2)), 0.26, 0.03, M["brass"], orb_node)
    disc("Orb_Cup", ORB + Vector((0, 0, -0.25)), 0.22, 0.06, M["brass_dark"], orb_node, rot=(0, 0, 0))
    sphere("Orb_Knob", ORB + Vector((0, 0, ORB_R + 0.04)), (0.04, 0.04, 0.035), M["brass"], orb_node)

    # Head: domed brass carapace with six teal eyes and a pair of short fangs.
    head = empty("Head", (0.26, 0, 0.36), root)
    sphere("Carapace", Vector((0.25, 0, 0.39)) - head.location, (0.26, 0.22, 0.17), M["brass"], head)
    ring("Carapace_Rim", Vector((0.25, 0, 0.33)) - head.location, 0.23, 0.022, M["brass_dark"], head)
    for side, tag in ((-1, "N"), (1, "F")):
        for j, (x, y, z, r) in enumerate(((0.48, 0.06, 0.43, 0.048), (0.45, 0.12, 0.5, 0.032), (0.41, 0.16, 0.41, 0.028))):
            sphere(f"Eye_{tag}{j}", Vector((x, y * side, z)) - head.location, (r, r, r), M["eye"], head)
            ring(f"Eye_{tag}{j}_Rim", Vector((x - 0.01, y * side, z)) - head.location, r * 1.05, 0.007, M["brass_dark"], head, rot=(0, 90, 0), seg=12)
        cone(f"Fang_{tag}", Vector((0.47, 0.05 * side, 0.3)) - head.location, 0.03, 0.1, M["claw"], head, rot=(180, -25, 0))

    # Eight legs: hip, raised knee, long shin down to a dark claw; front pairs reach forward, back pairs back.
    pairs = [(0.34, 0.36), (0.26, 0.14), (0.16, -0.1), (0.06, -0.32)]
    for k, (x, reach) in enumerate(pairs):
        order = ((-1, "a"), (1, "b")) if k % 2 == 0 else ((1, "a"), (-1, "b"))
        for side, slot in order:
            hip_z = 0.36
            pivot = empty(f"Leg_{k:02d}{slot}", (x, side * 0.17, hip_z), root)
            knee = Vector((reach * 0.55, side * 0.34, 0.3))
            ankle = Vector((reach * 1.1, side * 0.52, -hip_z + 0.15))
            name = f"Leg_{k:02d}{slot}"
            tube(name + "_Femur", [Vector((0, 0, 0)), knee], [0.06, 0.05], M["brass"], pivot, sides=8)
            tube(name + "_Tibia", [knee, knee.lerp(ankle, 0.55) + Vector((0, side * 0.03, 0.02)), ankle], [0.05, 0.045, 0.035], M["brass"], pivot, sides=8)
            sphere(name + "_Knee", knee, (0.065, 0.065, 0.065), M["brass_dark"], pivot)
            sphere(name + "_Ankle", knee.lerp(ankle, 0.6) + Vector((0, side * 0.03, 0.02)), (0.05, 0.05, 0.05), M["brass_dark"], pivot)
            cone(name + "_Claw", ankle, 0.038, 0.16, M["claw"], pivot, rot=(180, -15 if reach >= 0 else 15, 0))
    return root


def main():
    root = build()
    render_views(root, "spider")
    export(root, GLB)
    print("SPIDER_OK", GLB)


main()
