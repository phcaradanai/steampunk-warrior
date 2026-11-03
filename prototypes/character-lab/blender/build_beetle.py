"""
N05 armoured beetle, modelled to match its sprite in game/art/characters/actors-a-v2.png.
Run: /Applications/Blender.app/Contents/MacOS/Blender --background --python prototypes/character-lab/blender/build_beetle.py

A rhinoceros beetle under two riveted brass wing-cases, a ringed brass collar with a short horn,
a black head with a glowing teal lens on each side and a great curved brass horn, and six black
legs with brass knee guards. Nodes Creature3D drives by name:
  Body (dark core mesh), Head (empty), Leg_<pair><a|b> (hip pivots, alternating near/far per pair).
"""

import math
import os
import sys
import bmesh
from mathutils import Vector, Matrix, Euler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creature_kit import *  # noqa: E402,F403

GLB = os.path.join(ROOT, "game/art/characters/beetle.glb")

CORE = "201c1c"
BRASS = "74470f"
BRASS_DARK = "3e240a"
LENS = "2fd8c8"
CLAW = "121012"


def fur_body(material):
    """Dark abdomen, thorax and head blended into one mesh under the shell."""
    blobs = [
        ((-0.12, 0.0, 0.22), (0.36, 0.26, 0.15), 0),      # abdomen
        ((0.27, 0.0, 0.26), (0.16, 0.2, 0.15), -10),      # thorax
        ((0.47, 0.0, 0.27), (0.14, 0.13, 0.13), -15),     # head
    ]
    return blob_body(blobs, material)


def elytron(name, side, material, parent):
    """One wing-case: the `side` half of a dome, open underneath, thickened so the outline closes."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=1.0)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y * side < -0.02 or v.co.z < -0.25], context="VERTS")
    m = Matrix.Translation((-0.14, 0.018 * side, 0.27)) @ Euler((math.radians(-4 * side), math.radians(-6), 0)).to_matrix().to_4x4() @ Matrix.Diagonal((0.44, 0.32, 0.37, 1))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    ob = mesh_from_bm(name, bm, material, parent)
    solid = ob.modifiers.new("Solid", "SOLIDIFY")
    solid.thickness = 0.03
    solid.offset = 1.0
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=solid.name)
    bmesh_obj = ob.data
    bmesh_obj.validate()
    return ob


def build():
    reset()
    M = {
        "core": mat("Mat_Core", CORE, roughness=0.75),
        "brass": mat("Mat_Brass", BRASS, metallic=0.7, roughness=0.35),
        "brass_dark": mat("Mat_BrassDark", BRASS_DARK, metallic=0.6, roughness=0.45),
        "lens": mat("Mat_Lens", LENS, roughness=0.15, glow=1.6),
        "claw": mat("Mat_Claw", CLAW, roughness=0.5),
    }
    root = empty("Beetle", (0, 0, 0))
    body = fur_body(M["core"])
    body.parent = root

    # Wing-cases with rivets along the rim and down the seam.
    shell = empty("Shell", (0, 0, 0), root)
    for side, tag in ((-1, "N"), (1, "F")):
        case = elytron(f"Elytron_{tag}", side, M["brass"], shell)
        edge = [Vector((-0.14 + 0.43 * math.cos(math.radians(a)), side * 0.33, 0.12 + 0.1 * math.sin(math.radians(a)))) for a in range(-170, 10, 15)]
        # Groove splitting the case into an upper dome and a lower side plate, as on the sprite.
        groove = [Vector((x, side * 0.5, 0.36 - 0.12 * ((x + 0.14) / 0.44) ** 2)) for x in [i * 0.05 - 0.52 for i in range(16)]]
        tube(f"Elytron_{tag}_Groove", [surface(case, p, 0.006) for p in groove], [0.016] * len(groove), M["brass_dark"], shell, sides=6)
        tube(f"Elytron_{tag}_Edge", [surface(case, p, 0.004) for p in edge], [0.018] * len(edge), M["brass_dark"], shell, sides=6)
        for k in range(7):
            t = math.radians(-150 + k * 40)
            rim = Vector((-0.14 + 0.36 * math.cos(t), side * 0.4, 0.24 + 0.05 * math.sin(t)))
            sphere(f"Rivet_{tag}{k}", surface(case, rim, 0.01), (0.014, 0.014, 0.014), M["brass_dark"], shell, segs=8)
            seam = Vector((-0.44 + k * 0.09, side * 0.06, 0.8))
            sphere(f"Seam_{tag}{k}", surface(case, seam, 0.01), (0.012, 0.012, 0.012), M["brass_dark"], shell, segs=8)

    # Collar: ringed brass band round the thorax, short horn on top, gear boss on each shoulder.
    band("Collar", body, (0.32, 0, 0.27), (1, 0, 0.25), 0.2, 0.12, M["brass"], shell, thickness=0.045)
    band("Collar_Rim", body, (0.39, 0, 0.28), (1, 0, 0.25), 0.19, 0.025, M["brass_dark"], shell, thickness=0.06)
    cone("Collar_Horn", Vector((0.33, 0, 0.44)), 0.045, 0.14, M["brass"], shell, rot=(0, 18, 0))
    for side, tag in ((-1, "N"), (1, "F")):
        at = surface(body, Vector((0.3, side * 0.5, 0.25)), 0.06)
        disc(f"Gear_{tag}", at, 0.05, 0.03, M["brass"], shell)
        ring(f"Gear_{tag}_Rim", at + Vector((0, 0.016 * side, 0)), 0.045, 0.01, M["brass_dark"], shell, rot=(90, 0, 0))

    # Head: glowing teal lens tube on each side, great curved horn.
    head = empty("Head", (0.48, 0, 0.28), root)
    for side, tag in ((-1, "N"), (1, "F")):
        at = Vector((0.49, 0.13 * side, 0.29)) - head.location
        disc(f"Lens_{tag}", at, 0.075, 0.11, M["lens"], head)
        for dy in (-0.055, 0.055):
            ring(f"Lens_{tag}_Rim{int(dy > 0)}", at + Vector((0, dy, 0)), 0.078, 0.015, M["brass"], head, rot=(90, 0, 0))
        disc(f"Lens_{tag}_Pupil", at + Vector((0, 0.06 * side, 0)), 0.032, 0.012, M["claw"], head)
    horn = smooth_points([(0.56, 0, 0.32), (0.68, 0, 0.36), (0.77, 0, 0.48), (0.8, 0, 0.62), (0.75, 0, 0.75)], 5)
    tube("Horn", [p - head.location for p in horn], [0.07 - 0.065 * i / (len(horn) - 1) for i in range(len(horn))], M["brass"], head, sides=10)
    ring("Horn_Band", Vector((0.63, 0, 0.34)) - head.location, 0.065, 0.014, M["brass_dark"], head, rot=(0, 75, 0))

    # Six legs: thigh out to a brass knee guard, shin down to a black hooked claw.
    for k, (x, reach) in enumerate(((0.3, 0.16), (0.05, 0.02), (-0.22, -0.16))):
        order = ((-1, "a"), (1, "b")) if k % 2 == 0 else ((1, "a"), (-1, "b"))
        for side, slot in order:
            pivot = empty(f"Leg_{k:02d}{slot}", (x, side * 0.17, 0.15), root)
            knee = Vector((reach * 0.5, side * 0.17, 0.03))
            foot = Vector((reach, side * 0.27, -0.12))
            tube(f"Leg_{k:02d}{slot}_Thigh", [Vector((0, 0, 0)), knee], [0.055, 0.048], M["core"], pivot, sides=8)
            tube(f"Leg_{k:02d}{slot}_Shin", [knee, foot], [0.045, 0.032], M["core"], pivot, sides=8)
            sphere(f"Leg_{k:02d}{slot}_Guard", knee + Vector((0.01, 0.01 * side, 0.02)), (0.065, 0.055, 0.055), M["brass"], pivot)
            cone(f"Leg_{k:02d}{slot}_Spur", knee.lerp(foot, 0.5), 0.022, 0.06, M["brass"], pivot, rot=(0, 60 if reach >= 0 else -60, 0))
            cone(f"Leg_{k:02d}{slot}_Claw", foot, 0.03, 0.05, M["claw"], pivot, rot=(180, -30 if reach >= 0 else 30, 0))
    return root


def main():
    root = build()
    render_views(root, "beetle")
    export(root, GLB)
    print("BEETLE_OK", GLB)


main()
