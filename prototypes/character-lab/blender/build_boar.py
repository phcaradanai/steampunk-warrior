"""
N07 coal boar, modelled to match its sprite in game/art/characters/actors-a-v2.png.
Run: /Applications/Blender.app/Contents/MacOS/Blender --background --python prototypes/character-lab/blender/build_boar.py

Coal-black boar with a humped back of coal-lump bristles and ember glints, a leather harness with
brass rings, an ember eye, brass-capped tusks, a pink snout and short legs on dark hooves.
Nodes Creature3D drives by name: Body (one hide mesh), Head (empty), Leg_FL/FR/HR/HL (shoulder / hip pivots).
"""

import math
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creature_kit import *  # noqa: E402,F403

GLB = os.path.join(ROOT, "game/art/characters/boar.glb")

HIDE = "2a2422"
COAL = "1a1716"
EMBER = "e85a14"
LEATHER = "7a3e16"
BRASS = "8e5c18"
BRASS_DARK = "4a2a0c"
SNOUT = "b06a62"
TUSK = "d8b47a"
HOOF = "141212"


def fur_body(material):
    """Shoulder hump, barrel, rump, thick neck, sloping head and snout blended into one hide mesh."""
    blobs = [
        ((0.1, 0.0, 0.55), (0.3, 0.25, 0.3), -10),        # shoulder hump
        ((-0.12, 0.0, 0.46), (0.32, 0.24, 0.25), 0),      # barrel
        ((-0.36, 0.0, 0.44), (0.22, 0.22, 0.23), 8),      # rump
        ((0.3, 0.0, 0.47), (0.2, 0.22, 0.22), 0),         # neck
        ((0.48, 0.0, 0.43), (0.22, 0.19, 0.19), 10),      # big wedge head
        ((0.66, 0.0, 0.36), (0.13, 0.1, 0.1), 10),        # snout
    ]
    return blob_body(blobs, material)


def spike(name, body, near, size, material, parent):
    """Coal lump bristle standing out along the hide's normal where a ray from `near` meets it."""
    # Cast in toward the spine so every lump lands on its own patch instead of snapping to the hump.
    centre = Vector((near.x, 0, 0.45))
    hit, at, normal, _ = body.ray_cast(near, (centre - near).normalized())
    if not hit:
        _, at, normal, _ = body.closest_point_on_mesh(near)
    rot = [math.degrees(a) for a in normal.to_track_quat("Z", "Y").to_euler()]
    return cone(name, at - normal * 0.015, size * 0.7, size * 0.65, material, parent, rot=rot, segs=5)


def build():
    reset()
    M = {
        "hide": mat("Mat_Hide", HIDE, roughness=0.85),
        "coal": mat("Mat_Coal", COAL, roughness=0.7),
        "ember": mat("Mat_Ember", EMBER, roughness=0.4, glow=1.6),
        "leather": mat("Mat_Leather", LEATHER, roughness=0.7),
        "brass": mat("Mat_Brass", BRASS, metallic=0.7, roughness=0.35),
        "brass_dark": mat("Mat_BrassDark", BRASS_DARK, metallic=0.6, roughness=0.45),
        "snout": mat("Mat_Snout", SNOUT, roughness=0.6),
        "tusk": mat("Mat_Tusk", TUSK, roughness=0.4),
        "eye": mat("Mat_Eye", "ff6a1a", roughness=0.3, glow=2.6),
        "hoof": mat("Mat_Hoof", HOOF, roughness=0.5),
        "ear_in": mat("Mat_EarIn", "a0504a", roughness=0.6),
    }
    root = empty("Boar", (0, 0, 0))
    body = fur_body(M["hide"])
    body.parent = root

    # Coal-lump bristles over the hump and spine, thinning toward the rump.
    bristles = empty("Bristles", (0, 0, 0), root)
    k = 0
    for i in range(11):
        x = 0.36 - i * 0.075
        for a in range(-75, 76, 25):
            ang = math.radians(a + (12 if i % 2 else 0))
            size = 0.08 + 0.05 * math.sin(math.pi * (1 - i / 10)) - abs(ang) * 0.02
            spike(f"Bristle_{k}", body, Vector((x, math.sin(ang), 0.45 + math.cos(ang))), size, M["coal"], bristles)
            k += 1

    # Ember glints showing through the hide on both flanks.
    for side, tag in ((-1, "N"), (1, "F")):
        for j, crack in enumerate(([(0.0, 0.44), (0.05, 0.37), (0.0, 0.3)], [(-0.25, 0.5), (-0.2, 0.42)],
                                   [(-0.4, 0.38), (-0.36, 0.3), (-0.4, 0.24)], [(0.22, 0.36), (0.27, 0.3)], [(0.4, 0.46), (0.45, 0.4)])):
            pts = [surface(body, Vector((x, side * 0.5, z)), 0.004) for x, z in crack]
            tube(f"Ember_{tag}{j}", pts, [0.016] * (len(pts) - 1) + [0.006], M["ember"], root, sides=6)

    # Harness: diagonal shoulder strap, girth, rump strap, brass ring where they cross, rivets.
    harness = empty("Harness", (0, 0, 0), root)
    band("Strap_Shoulder", body, (0.16, 0, 0.5), (math.cos(math.radians(25)), 0, math.sin(math.radians(25))), 0.28, 0.06, M["leather"], harness, thickness=0.03)
    band("Strap_Girth", body, (0.0, 0, 0.46), (math.cos(math.radians(-25)), 0, math.sin(math.radians(-25))), 0.27, 0.06, M["leather"], harness, thickness=0.03)
    band("Strap_Rump", body, (-0.3, 0, 0.46), (1, 0, 0.1), 0.25, 0.055, M["leather"], harness, thickness=0.03)
    for side, tag in ((-1, "N"), (1, "F")):
        for j, (x, z) in enumerate(((0.08, 0.46), (-0.3, 0.6))):
            at = surface(body, Vector((x, side * 0.5, z)), 0.045)
            ring(f"Ring_{tag}{j}", at, 0.055, 0.016, M["brass"], harness, rot=(90, 0, 0))
            disc(f"Boss_{tag}{j}", at, 0.035, 0.03, M["brass_dark"], harness)
        for j, (x, z) in enumerate(((0.2, 0.62), (0.26, 0.4), (-0.05, 0.6), (-0.06, 0.3), (-0.3, 0.38))):
            sphere(f"Rivet_{tag}{j}", surface(body, Vector((x, side * 0.5, z)), 0.04), (0.014, 0.014, 0.014), M["brass"], harness, segs=8)

    # Head: pointed ears, ember eyes, pink snout disc, brass-capped tusks curling up.
    head = empty("Head", (0.5, 0, 0.43), root)
    for side, tag in ((-1, "N"), (1, "F")):
        base = Vector((0.47, 0.12 * side, 0.6)) - head.location
        cone(f"Ear_{tag}", base, 0.075, 0.22, M["hide"], head, rot=(25 * side, -30, 0), segs=6)
        cone(f"EarIn_{tag}", base + Vector((0.02, 0.014 * side, 0.01)), 0.055, 0.18, M["ear_in"], head, rot=(25 * side, -30, 0), segs=6)
        sphere(f"Eye_{tag}", Vector((0.58, 0.13 * side, 0.48)) - head.location, (0.026, 0.014, 0.016), M["eye"], head, rot=(0, -15, 20 * side))
        tusk = smooth_points([(0.66, 0.08 * side, 0.3), (0.74, 0.14 * side, 0.32), (0.78, 0.17 * side, 0.43), (0.73, 0.17 * side, 0.53)], 4)
        tube(f"Tusk_{tag}", [p - head.location for p in tusk], [0.042 - 0.037 * i / (len(tusk) - 1) for i in range(len(tusk))], M["tusk"], head, sides=8)
        ring(f"Tusk_{tag}_Cap", Vector((0.7, 0.11 * side, 0.31)) - head.location, 0.044, 0.012, M["brass"], head, rot=(0, 60, 0), seg=12)
        sphere(f"Nostril_{tag}", Vector((0.8, 0.032 * side, 0.34)) - head.location, (0.012, 0.016, 0.02), M["hoof"], head)
    disc("Snout", Vector((0.78, 0, 0.34)) - head.location, 0.085, 0.04, M["snout"], head, rot=(0, 90, 0))

    # Short thick legs on split dark hooves.
    legs = [("Leg_FL", (0.2, -0.13, 0.34)), ("Leg_FR", (0.2, 0.13, 0.34)),
            ("Leg_HR", (-0.32, 0.13, 0.34)), ("Leg_HL", (-0.32, -0.13, 0.34))]
    for name, joint in legs:
        pivot = empty(name, joint, root)
        top = joint[2]
        ankle = Vector((0.02, 0, -top + 0.07))
        tube(name + "_Leg", [Vector((0, 0, 0.06)), Vector((0.0, 0, -0.12)), ankle], [0.1, 0.075, 0.055], M["hide"], pivot)
        for toe in (-1, 1):
            sphere(name + f"_Hoof{int(toe > 0)}", ankle + Vector((0.03, toe * 0.025, -0.04)), (0.05, 0.03, 0.035), M["hoof"], pivot)
    return root


def main():
    root = build()
    render_views(root, "boar")
    export(root, GLB)
    print("BOAR_OK", GLB)


main()
