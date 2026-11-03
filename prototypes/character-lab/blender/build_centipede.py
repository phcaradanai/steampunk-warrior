"""
N04 copper centipede, modelled to match its sprite in game/art/characters/actors-a-v2.png.
Run: /Applications/Blender.app/Contents/MacOS/Blender --background --python prototypes/character-lab/blender/build_centipede.py

Seven riveted copper plates arch over a dark core that rises toward the head, teal aether gems glow
between the plates, each segment walks on a pair of claw legs, and the helmeted head carries
hooked mandibles and two long antennae swept back over the body.
Nodes Creature3D drives by name: Body (core mesh), Head (empty), Leg_<segment><a|b> (hip pivots).
Legs alternate near/far per segment so the code's alternating swing ripples down each side.
"""

import math
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creature_kit import *  # noqa: E402,F403

GLB = os.path.join(ROOT, "game/art/characters/centipede.glb")

COPPER = "7c461a"
COPPER_DARK = "4a2610"
CORE = "2e2420"
GEM = "2fe0c0"
EYE = "4cff7a"

SEGMENTS = 7


def segment(k):
    """Centre x, centre z and core half-size of segment k (0 is the tail, the body climbs toward the head)."""
    t = k / (SEGMENTS - 1)
    x = -0.6 + k * 0.18
    z = 0.27 + 0.16 * t * t
    r = 0.14 + 0.05 * math.sin(math.pi * min(1.0, t * 1.2))
    return x, z, r


def fur_body(material):
    """Dark core: one ellipsoid per segment plus the head capsule, blended so plates sit on a continuous body."""
    blobs = []
    for k in range(SEGMENTS):
        x, z, r = segment(k)
        blobs.append(((x, 0.0, z), (0.12, r * 1.05, r), -8 * k / SEGMENTS))
    blobs.append(((0.62, 0.0, 0.47), (0.15, 0.13, 0.12), -15))
    return blob_body(blobs, material)


def build():
    reset()
    M = {
        "core": mat("Mat_Core", CORE, roughness=0.8),
        "copper": mat("Mat_Copper", COPPER, metallic=0.7, roughness=0.35),
        "copper_dark": mat("Mat_CopperDark", COPPER_DARK, metallic=0.6, roughness=0.45),
        "gem": mat("Mat_Gem", GEM, roughness=0.2, glow=1.4),
        "eye": mat("Mat_Eye", EYE, roughness=0.2, glow=2.0),
    }
    root = empty("Centipede", (0, 0, 0))
    body = fur_body(M["core"])
    body.name = "Body"
    body.parent = root

    # Armour: an arched plate over every segment, rivets along its rim, a gem in each gap on both flanks.
    armour = empty("Armour", (0, 0, 0), root)
    for k in range(SEGMENTS):
        x, z, r = segment(k)
        lean = math.radians(-12 - 6 * k / SEGMENTS)
        axis = (math.cos(lean), 0, math.sin(lean))
        band(f"Plate_{k}", body, (x + 0.02, 0, z), axis, r + 0.05, 0.18, M["copper"], armour, arc=(-88, 88), thickness=0.085)
        band(f"Plate_{k}_Rim", body, (x + 0.085, 0, z + 0.01), axis, r + 0.06, 0.025, M["copper_dark"], armour, arc=(-85, 85), thickness=0.1)
        for side, tag in ((-1, "N"), (1, "F")):
            for j, a in enumerate((30, 65)):
                at = surface(body, Vector((x + 0.02, side * math.sin(math.radians(a)), z + math.cos(math.radians(a)))), 0.095)
                sphere(f"Rivet_{k}{tag}{j}", at, (0.014, 0.014, 0.014), M["copper_dark"], armour, segs=8)
            if 0 < k:
                gx = x - 0.095
                at = surface(body, Vector((gx, side, z - 0.07)), 0.01)
                sphere(f"Gem_{k}{tag}", at, (0.055, 0.04, 0.05), M["gem"], armour)
                ring(f"Gem_{k}{tag}_Rim", at, 0.055, 0.012, M["copper_dark"], armour, rot=(90, 0, 0))

    # Legs: one pair per segment, copper with a joint ring, ending in a pointed claw on the ground.
    for k in range(SEGMENTS):
        x, z, r = segment(k)
        order = ((-1, "a"), (1, "b")) if k % 2 == 0 else ((1, "a"), (-1, "b"))
        for side, slot in order:
            hip_z = z - r * 0.55
            pivot = empty(f"Leg_{k:02d}{slot}", (x + 0.03, side * r * 0.8, hip_z), root)
            knee = Vector((0.03, side * 0.12, -0.02))
            ankle = Vector((0.08, side * 0.16, -hip_z + 0.11))
            tube(f"Leg_{k:02d}{slot}_Thigh", [Vector((0, 0, 0)), knee], [0.042, 0.036], M["copper"], pivot, sides=8)
            tube(f"Leg_{k:02d}{slot}_Shin", [knee, knee.lerp(ankle, 0.5) + Vector((0.02, 0, 0)), ankle], [0.036, 0.032, 0.028], M["copper"], pivot, sides=8)
            ring(f"Leg_{k:02d}{slot}_Joint", knee, 0.04, 0.011, M["copper_dark"], pivot, rot=(0, 90, 0), seg=12)
            cone(f"Leg_{k:02d}{slot}_Claw", ankle, 0.032, 0.12, M["copper"], pivot, rot=(180, -15, 0))

    # Head: dark face under a copper helmet, green eyes, hooked mandibles, antennae swept back.
    head = empty("Head", (0.66, 0, 0.48), root)
    sphere("Helmet", Vector((0.67, 0, 0.51)) - head.location, (0.17, 0.15, 0.12), M["copper"], head, rot=(0, -12, 0))
    cone("Helmet_Crest", Vector((0.6, 0, 0.57)) - head.location, 0.05, 0.12, M["copper_dark"], head, rot=(0, -70, 0))
    for side, tag in ((-1, "N"), (1, "F")):
        sphere(f"Eye_{tag}", Vector((0.78, 0.1 * side, 0.5)) - head.location, (0.032, 0.018, 0.022), M["eye"], head, rot=(0, 0, 20 * side))
        jaw = smooth_points([(0.76, 0.05 * side, 0.42), (0.86, 0.07 * side, 0.38), (0.9, 0.05 * side, 0.29), (0.86, 0.03 * side, 0.23)], 4)
        tube(f"Mandible_{tag}", [p - head.location for p in jaw], [0.045 - 0.032 * i / (len(jaw) - 1) for i in range(len(jaw))], M["copper"], head, sides=8)
        antenna = smooth_points([(0.72, 0.05 * side, 0.58), (0.66, 0.08 * side, 0.82), (0.45, 0.12 * side, 0.96), (0.15, 0.14 * side, 0.94), (-0.1, 0.15 * side, 0.84)], 5)
        tube(f"Antenna_{tag}", [p - head.location for p in antenna], [0.012 - 0.008 * i / (len(antenna) - 1) for i in range(len(antenna))], M["copper_dark"], head, sides=6)
    return root


def main():
    root = build()
    render_views(root, "centipede")
    export(root, GLB)
    print("CENTI_OK", GLB)


main()
