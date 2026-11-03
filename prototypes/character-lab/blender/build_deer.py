"""
B03 grove stag (boss), modelled to match its sprite in game/art/characters/actors-b.png.
Run: /Applications/Blender.app/Contents/MacOS/Blender --background --python prototypes/character-lab/blender/build_deer.py

A shaggy bark-and-moss stag with a pale throat, glowing teal eyes and vast antlers sprouting teal
leaves, wearing a brass saddle rig with a gem canister on the back, a medallion on the flank and
glowing lanterns hanging at the chest and side. Nodes Creature3D drives by name:
  Body (one hide mesh), Head (empty), Leg_FL/FR/HR/HL (shoulder / hip pivots), Tail (pivot).
"""

import math
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creature_kit import *  # noqa: E402,F403

GLB = os.path.join(ROOT, "game/art/characters/deer.glb")

HIDE = "6a4a2a"
PALE = "b09a7a"
MOSS = "4a5e20"
LEAF = "2fa898"
ANTLER = "7a5a34"
BRASS = "9a6a1c"
BRASS_DARK = "4e2e0c"
GLOW = "3ff0d0"
HOOF = "2a1e14"


def fur_body(material):
    """Deep chest, barrel, rump, upright neck and narrow skull blended into one hide mesh."""
    blobs = [
        ((0.22, 0.0, 0.86), (0.25, 0.19, 0.24), -10),     # chest
        ((-0.02, 0.0, 0.88), (0.28, 0.17, 0.19), 0),      # barrel
        ((-0.28, 0.0, 0.88), (0.2, 0.17, 0.2), 8),        # rump
        ((0.36, 0.0, 1.06), (0.13, 0.12, 0.2), -25),      # neck
        ((0.46, 0.0, 1.28), (0.11, 0.09, 0.1), 15),       # skull
        ((0.6, 0.0, 1.22), (0.1, 0.06, 0.06), 25),        # muzzle
    ]
    return blob_body(blobs, material)


def shag(name, body, near, size, material, parent, droop=0.9):
    """Hanging hair lock: a cone pointing down-back out of the hide where a ray toward the core meets it."""
    centre = Vector((near.x, 0, 0.88))
    hit, at, normal, _ = body.ray_cast(near, (centre - near).normalized())
    if not hit:
        _, at, normal, _ = body.closest_point_on_mesh(near)
    d = (normal + Vector((-0.3, 0, -droop))).normalized()
    rot = [math.degrees(a) for a in d.to_track_quat("Z", "Y").to_euler()]
    return cone(name, at - normal * 0.01, size * 0.4, size, material, parent, rot=rot, segs=5)


def antler(tag, side, M, parent, origin):
    """One antler: a beam sweeping up and back with tines, each tine tipped by a cluster of teal leaves."""
    s = side
    beam = [Vector((0, 0.04 * s, 0)), Vector((-0.05, 0.12 * s, 0.1)), Vector((-0.04, 0.24 * s, 0.22)),
            Vector((-0.14, 0.32 * s, 0.32)), Vector((-0.3, 0.36 * s, 0.36))]
    beam = [origin + p for p in beam]
    pts = smooth_points(beam, 4)
    tube(f"Antler_{tag}", pts, [0.03 * (1 - 0.7 * i / (len(pts) - 1)) for i in range(len(pts))], M["antler"], parent, sides=7)
    tips = [pts[-1]]
    for k, (i, off) in enumerate(((1, (0.12, 0.06 * s, 0.1)), (2, (0.08, 0.06 * s, 0.14)), (3, (0.0, 0.04 * s, 0.14)))):
        base = beam[i]
        tip = base + Vector(off)
        tube(f"Antler_{tag}_Tine{k}", [base, tip], [0.018, 0.006], M["antler"], parent, sides=6)
        tips.append(tip)
    for k, tip in enumerate(tips):
        for j in range(4):
            a = math.radians(j * 90 + k * 25)
            d = Vector((math.cos(a) * 0.6, math.sin(a) * 0.6 * s, 0.7)).normalized()
            rot = [math.degrees(x) for x in d.to_track_quat("Z", "Y").to_euler()]
            sphere(f"Leaf_{tag}{k}{j}", tip + d * 0.05, (0.028, 0.028, 0.07), M["leaf"], parent, rot=rot, segs=8)


def build():
    reset()
    M = {
        "hide": mat("Mat_Hide", HIDE, roughness=0.85),
        "pale": mat("Mat_Pale", PALE, roughness=0.85),
        "moss": mat("Mat_Moss", MOSS, roughness=0.9),
        "leaf": mat("Mat_Leaf", LEAF, roughness=0.5, glow=0.6),
        "antler": mat("Mat_Antler", ANTLER, roughness=0.7),
        "brass": mat("Mat_Brass", BRASS, metallic=0.7, roughness=0.35),
        "brass_dark": mat("Mat_BrassDark", BRASS_DARK, metallic=0.6, roughness=0.45),
        "glow": mat("Mat_Glow", GLOW, roughness=0.2, glow=1.8),
        "hoof": mat("Mat_Hoof", HOOF, roughness=0.6),
        "nose": mat("Mat_Nose", "1a1210", roughness=0.4),
    }
    root = empty("Deer", (0, 0, 0))
    body = fur_body(M["hide"])
    body.parent = root
    sphere("Throat", Vector((0.42, 0, 1.0)), (0.1, 0.11, 0.17), M["pale"], root, rot=(0, -25, 0))

    # Shaggy coat: hanging locks of bark-brown and moss over the back, flanks and belly.
    coat = empty("Coat", (0, 0, 0), root)
    k = 0
    for i in range(11):
        x = 0.36 - i * 0.07
        for a in range(-120, 121, 30):
            ang = math.radians(a + (15 if i % 2 else 0))
            near = Vector((x, math.sin(ang), 0.88 + math.cos(ang)))
            size = 0.12 + 0.04 * abs(math.sin(ang))
            shag(f"Lock_{k}", body, near, size, M["moss"] if k % 3 == 0 else M["hide"], coat)
            k += 1

    # Brass rig: saddle band, gem canister on the back, flank medallion, hanging lanterns.
    rig = empty("Rig", (0, 0, 0), root)
    band("Saddle", body, (-0.04, 0, 0.9), (1, 0, 0), 0.24, 0.14, M["brass"], root, thickness=0.04)
    band("Chest_Strap", body, (0.3, 0, 0.92), (math.cos(math.radians(40)), 0, math.sin(math.radians(40))), 0.25, 0.05, M["brass_dark"], root, thickness=0.03)
    can_at = Vector((-0.14, 0, 1.18))
    disc("Canister", can_at, 0.09, 0.28, M["brass"], rig, rot=(0, 90, 0))
    sphere("Canister_Gem", can_at + Vector((-0.02, 0, 0.0)), (0.11, 0.1, 0.1), M["glow"], rig)
    for dx in (-0.12, 0.12):
        ring(f"Canister_Cap{int(dx > 0)}", can_at + Vector((dx, 0, 0)), 0.075, 0.018, M["brass_dark"], rig, rot=(0, 90, 0))
    for side, tag in ((-1, "N"), (1, "F")):
        med = surface(body, Vector((0.0, 0.5 * side, 0.92)), 0.04)
        disc(f"Medallion_{tag}", med, 0.06, 0.03, M["brass"], rig)
        sphere(f"Medallion_{tag}_Gem", med + Vector((0, 0.015 * side, 0)), (0.035, 0.02, 0.035), M["glow"], rig)
        lantern = surface(body, Vector((-0.1, 0.5 * side, 0.72)), 0.06)
        tube(f"Lantern_{tag}_Chain", [lantern + Vector((0, 0, 0.12)), lantern + Vector((0, 0, 0.06))], [0.008, 0.008], M["brass_dark"], rig, sides=5)
        disc(f"Lantern_{tag}", lantern, 0.035, 0.1, M["glow"], rig, rot=(0, 0, 0))
        for dz in (-0.055, 0.055):
            disc(f"Lantern_{tag}_Cap{int(dz > 0)}", lantern + Vector((0, 0, dz)), 0.042, 0.02, M["brass"], rig, rot=(0, 0, 0))
    chest_lantern = Vector((0.5, 0, 0.82))
    tube("Lantern_Chest_Chain", [chest_lantern + Vector((-0.04, 0, 0.14)), chest_lantern + Vector((0, 0, 0.06))], [0.008, 0.008], M["brass_dark"], rig, sides=5)
    disc("Lantern_Chest", chest_lantern, 0.035, 0.1, M["glow"], rig, rot=(0, 0, 0))

    # Head: pointed ears, glowing eyes, dark nose, antlers.
    head = empty("Head", (0.48, 0, 1.28), root)
    for side, tag in ((-1, "N"), (1, "F")):
        cone(f"Ear_{tag}", Vector((0.42, 0.08 * side, 1.34)) - head.location, 0.04, 0.14, M["hide"], head, rot=(-60 * side, -20, 0), segs=6)
        sphere(f"Eye_{tag}", Vector((0.54, 0.07 * side, 1.3)) - head.location, (0.022, 0.012, 0.014), M["glow"], head)
        antler(tag, side, M, head, Vector((0.44, 0.0, 1.36)) - head.location)
    sphere("Nose", Vector((0.7, 0, 1.18)) - head.location, (0.025, 0.028, 0.022), M["nose"], head)

    # Long legs with shaggy upper legs and dark hooves.
    legs = [("Leg_FL", (0.24, -0.1, 0.76), 1), ("Leg_FR", (0.24, 0.1, 0.76), 1),
            ("Leg_HR", (-0.3, 0.1, 0.78), -1), ("Leg_HL", (-0.3, -0.1, 0.78), -1)]
    for name, joint, fwd in legs:
        pivot = empty(name, joint, root)
        top = joint[2]
        knee = Vector((0.03 * fwd, 0, -0.34)) if fwd > 0 else Vector((-0.1, 0, -0.32))
        ankle = Vector((0.04 if fwd > 0 else -0.04, 0, -top + 0.06))
        tube(name + "_Upper", [Vector((0, 0, 0.08)), knee], [0.085, 0.05], M["hide"], pivot)
        tube(name + "_Lower", [knee, ankle], [0.038, 0.03], M["hide"], pivot)
        for k in range(3):
            cone(name + f"_Shag{k}", knee + Vector((0, (k - 1) * 0.03, 0.12)), 0.03, 0.18, M["moss"] if k == 1 else M["hide"], pivot, rot=(180, 0, 0), segs=5)
        sphere(name + "_Hoof", ankle + Vector((0.02, 0, -0.03)), (0.05, 0.04, 0.035), M["hoof"], pivot)

    tail = empty("Tail", (-0.46, 0, 0.98), root)
    cone("Tail_Mesh", Vector((0, 0, 0)), 0.06, 0.16, M["pale"], tail, rot=(0, -140, 0), segs=6)
    # Antler tips must stay under the stage's 1.85 top edge.
    root.scale = (0.88, 0.88, 0.88)
    return root


def main():
    root = build()
    render_views(root, "deer")
    export(root, GLB)
    print("DEER_OK", GLB)


main()
