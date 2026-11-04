"""
N01 pipe-biter rat, modelled to match its sprite in game/art/characters/actors-a-v2.png.
Run: /Applications/Blender.app/Contents/MacOS/Blender --background --python prototypes/character-lab/blender/build_rat.py

Axes: Blender +X is forward, +Z up, -Y toward the viewer (glTF turns these into Creature3D's +X, +Y, +Z).
Creature3D animates the nodes by name and overwrites their rotation every frame, so each pivot Empty
sits at its joint with identity rotation and the bent pose lives in the child mesh:
  Body (one fur mesh: torso, haunch, neck, head), Head (empty), Leg_FL/FR/HR/HL (pivot empties), Tail (pivot empty).
"""

import math
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creature_kit import *  # noqa: E402,F403

GLB = os.path.join(ROOT, "game/art/characters/rat.glb")

FUR = "574b45"
FUR_DARK = "5f5550"
PINK = "b06c66"
PINK_DEEP = "a05e5a"
BRASS = "9c661e"
BRASS_DARK = "7a4c18"
CRYSTAL = "1fae5a"
TUBE = "2f8a62"


def fur_body(material):
    """Rump, torso, chest, neck, skull and snout blended into one fur mesh."""
    blobs = [
        ((-0.18, 0.0, 0.28), (0.25, 0.2, 0.24), 0),        # rump
        ((-0.1, 0.0, 0.17), (0.22, 0.17, 0.14), 12),       # haunch drop toward the heel
        ((-0.02, 0.0, 0.41), (0.28, 0.2, 0.24), -26),      # torso, reared with a high hump
        ((0.15, 0.0, 0.5), (0.2, 0.18, 0.2), -30),         # chest / shoulders
        ((0.29, 0.0, 0.57), (0.15, 0.15, 0.14), -10),      # neck
        ((0.42, 0.0, 0.6), (0.18, 0.125, 0.12), 6),        # skull, long and low
        ((0.6, 0.0, 0.55), (0.15, 0.07, 0.07), 16),        # wedge muzzle
        ((0.47, 0.0, 0.53), (0.11, 0.11, 0.07), 0),        # cheeks
    ]
    return blob_body(blobs, material)


def build():
    reset()
    M = {
        "fur": mat("Mat_Fur", FUR, roughness=0.8),
        "fur_dark": mat("Mat_FurDark", FUR_DARK, roughness=0.8),
        "pink": mat("Mat_Pink", PINK, roughness=0.6),
        "pink_deep": mat("Mat_PinkDeep", PINK_DEEP, roughness=0.6),
        "brass": mat("Mat_Brass", BRASS, metallic=0.7, roughness=0.35),
        "brass_dark": mat("Mat_BrassDark", BRASS_DARK, metallic=0.6, roughness=0.45),
        "crystal": mat("Mat_Crystal", CRYSTAL, roughness=0.2, glow=0.9),
        "tube": mat("Mat_Tube", TUBE, roughness=0.3),
        "eye": mat("Mat_Eye", "f08a2a", roughness=0.3, glow=1.2),
        "pupil": mat("Mat_Pupil", "140c0a", roughness=0.4),
        "nose": mat("Mat_Nose", "c86a6a", roughness=0.5),
    }
    root = empty("Rat", (0, 0, 0))
    body = fur_body(M["fur"])
    body.parent = root

    # Head details: big round pink ears, orange eye, pink nose.
    head = empty("Head", (0.45, 0, 0.6), root)
    for side in (-1, 1):
        ear_at = Vector((0.34, 0.12 * side, 0.75))
        sphere(f"Ear_{'N' if side < 0 else 'F'}", ear_at, (0.085, 0.022, 0.092), M["fur"], head, rot=(0, -15, 25 * side)).location -= head.location
        inner = sphere(f"EarIn_{'N' if side < 0 else 'F'}", ear_at + Vector((0.005, -0.012 * -side, 0.0)) * 1.0 + Vector((0, 0.0, 0)),
                       (0.066, 0.012, 0.072), M["pink"], head, rot=(0, -15, 25 * side))
        inner.location -= head.location
        inner.location.y += -0.012 if side < 0 else 0.012
        eye = sphere(f"Eye_{'N' if side < 0 else 'F'}", Vector((0.51, 0.093 * side, 0.64)), (0.03, 0.018, 0.018), M["eye"], head, rot=(0, 0, 18 * side))
        eye.location -= head.location
        pupil = sphere(f"Pupil_{'N' if side < 0 else 'F'}", Vector((0.522, 0.104 * side, 0.64)), (0.011, 0.008, 0.015), M["pupil"], head)
        pupil.location -= head.location
    nose = sphere("Nose", Vector((0.745, 0, 0.555)), (0.035, 0.04, 0.032), M["nose"], head)
    nose.location -= head.location
    for side in (-1, 1):
        tooth = sphere(f"Tooth_{side}", Vector((0.69, 0.016 * side, 0.495)), (0.012, 0.01, 0.022), mat("Mat_Tooth", "f2e8d0"), head)
        tooth.location -= head.location

    # Legs: pivots at the elbow / knee, bent pose baked in the child mesh.
    # Order alternates swing sign in Creature3D: near-front and far-hind move together (diagonal gait).
    legs = [
        ("Leg_FL", (0.16, -0.12, 0.42), "front", -1),
        ("Leg_FR", (0.16, 0.12, 0.42), "front", 1),
        ("Leg_HR", (-0.12, 0.15, 0.17), "hind", 1),
        ("Leg_HL", (-0.12, -0.15, 0.17), "hind", -1),
    ]
    for name, joint, kind, side in legs:
        pivot = empty(name, joint, root)
        j = Vector(joint)
        if kind == "front":
            # Fur upper arm drops back to the elbow, pink forearm reaches forward to a planted hand.
            elbow = Vector((-0.02, 0, -0.17))
            wrist = Vector((0.12, 0, -0.37))
            tube(name + "_Upper", [Vector((0, 0, 0.02)), elbow * 0.5, elbow], [0.075, 0.065, 0.05], M["fur"], pivot)
            tube(name + "_Fore", [elbow, (elbow + wrist) / 2, wrist], [0.042, 0.034, 0.028], M["pink"], pivot)
            hand_at = wrist + Vector((0.03, 0, -0.015))
            sphere(name + "_Hand", hand_at, (0.055, 0.04, 0.022), M["pink"], pivot)
            for k in range(3):
                sphere(name + f"_Finger{k}", hand_at + Vector((0.05, (k - 1) * 0.022, -0.006)), (0.028, 0.011, 0.012), M["pink"], pivot)
        else:
            # Shin runs back-down from the knee to the heel, long rat foot lies flat forward.
            path = [j, j + Vector((-0.08, 0, -0.08)), j + Vector((-0.1, 0, -0.14))]
            tube(name + "_Shin", [p - j for p in path], [0.07, 0.05, 0.035], M["pink"], pivot)
            heel = Vector((-0.1, 0, -0.145))
            foot = [heel, heel + Vector((0.12, 0, -0.01)), heel + Vector((0.24, 0, -0.014))]
            tube(name + "_Foot", foot, [0.035, 0.038, 0.028], M["pink"], pivot)
            for k in range(3):
                sphere(name + f"_Toe{k}", heel + Vector((0.27, (k - 1) * 0.026, -0.014)), (0.03, 0.011, 0.012), M["pink"], pivot)

    # Tail: long pink taper curling back, up into a loop and down to the floor.
    tail = empty("Tail", (-0.44, 0, 0.24), root)
    ctrl = [(0, 0, 0), (-0.1, 0, 0.06), (-0.22, 0, 0.12), (-0.33, 0, 0.08), (-0.38, 0, -0.04), (-0.34, 0, -0.15),
            (-0.22, 0, -0.21), (-0.08, 0, -0.225), (0.06, 0, -0.23)]
    pts = smooth_points(ctrl, 5)
    radii = [0.045 * (1 - 0.75 * i / (len(pts) - 1)) for i in range(len(pts))]
    tube("Tail_Mesh", pts, radii, M["pink_deep"], tail)

    # Harness: bands drawn around the body, then shrinkwrapped onto the fur and given thickness.
    harness = empty("Harness", (0, 0, 0), root)
    band("Strap_Collar", body, (0.22, 0, 0.55), (math.cos(math.radians(-30)), 0, math.sin(math.radians(-30))), 0.2, 0.11, M["brass"], harness, thickness=0.04)
    band("Strap_Girth", body, (-0.04, 0, 0.36), (math.cos(math.radians(-65)), 0, math.sin(math.radians(-65))), 0.25, 0.07, M["brass"], harness)
    band("Strap_Diagonal", body, (0.08, 0, 0.5), (math.cos(math.radians(30)), 0, math.sin(math.radians(30))), 0.2, 0.055, M["brass"], harness)
    # Saddle: a curved plate on the spine that carries the crystal cradle.
    band("Saddle", body, (-0.08, 0, 0.45), (1, 0, 0), 0.24, 0.26, M["brass"], harness, arc=(-70, 70))
    # Medallion and rivets on both flanks: combat foes face left, so the far side is the one on screen.
    for side, tag in ((-1, "N"), (1, "F")):
        med_at = surface(body, Vector((0.13, 0.4 * side, 0.58)), 0.03)
        disc(f"Medallion_{tag}", med_at, 0.065, 0.025, M["brass"], harness)
        ring(f"Medallion_Rim_{tag}", med_at + Vector((0, 0.013 * side, 0)), 0.062, 0.009, M["brass_dark"], harness, rot=(90, 0, 0))
        swirl = [(0.04 * (k / 18) * math.cos(k * 0.75), 0, 0.04 * (k / 18) * math.sin(k * 0.75)) for k in range(19)]
        tube(f"Medallion_Swirl_{tag}", [med_at + Vector((0, 0.015 * side, 0)) + Vector(p) for p in swirl], [0.006] * len(swirl), M["brass_dark"], harness, sides=6)
        for k, (x, z) in enumerate(((0.27, 0.7), (0.3, 0.6), (0.0, 0.5), (-0.08, 0.36), (0.1, 0.3), (-0.2, 0.55))):
            sphere(f"Rivet_{tag}{k}", surface(body, Vector((x, 0.4 * side, z)), 0.035), (0.014, 0.014, 0.014), M["brass_dark"], harness, segs=8)

    # Back cradle: crystal cluster rising from the saddle, looped green tube behind it.
    frame = empty("BackFrame", (-0.1, 0, 0.66), root)
    crystals = [((0.0, 0.0, 0.0), 0.06, 0.34, (0, -24, 0)),
                ((0.1, 0.05, -0.01), 0.045, 0.27, (10, -6, 30)),
                ((-0.1, -0.05, -0.02), 0.045, 0.22, (-12, -40, 0)),
                ((0.15, -0.06, -0.03), 0.032, 0.15, (-10, 12, 0)),
                ((-0.17, 0.05, -0.05), 0.035, 0.16, (14, -58, 0)),
                ((0.04, -0.08, -0.02), 0.03, 0.12, (-25, -10, 0))]
    for k, (at, r, h, rot) in enumerate(crystals):
        prism(f"Crystal_{k}", Vector(at), r * 1.25, h * 1.2, M["crystal"], frame, rot=rot)
    ring("Cradle_Rim", (0.0, 0.0, 0.0), 0.15, 0.032, M["brass"], frame, rot=(0, 0, 0))
    disc("Cradle_Base", Vector((0, 0, -0.04)), 0.16, 0.08, M["brass_dark"], frame, rot=(180, 0, 0))
    for k in range(6):
        a = math.radians(k * 60 + 15)
        sphere(f"Cradle_Rivet_{k}", Vector((0.15 * math.cos(a), 0.15 * math.sin(a), 0.03)), (0.016, 0.016, 0.016), M["brass_dark"], frame, segs=8)
    ring("Tube_Loop", (-0.22, 0.0, -0.08), 0.1, 0.024, M["tube"], frame, rot=(90, 25, 0), arc=290)

    # Head pivot carries no animation in Creature3D; it marks the skull for future use.
    return root


def main():
    root = build()
    render_views(root, "rat")
    export(root, GLB)
    print("RAT_OK", GLB)


main()
