"""Renders lightning flipbook frames for the Hovl-style `thunder` / `zap_hit` effect.

Headless: /Applications/Blender.app/Contents/MacOS/Blender -b -P prototypes/vfx/blender/build_lightning.py -- <out_dir>
Writes <out_dir>/bolt_<n>.png (512x1024 tall strike, sky -> ground) and <out_dir>/arcs_<n>.png (ground-crawling arcs),
transparent RGBA, emission only. Glow halos and atlas packing happen afterwards in pack_lightning.py.
Original procedural geometry (midpoint-displaced branching curves); no third-party assets.
"""
import math
import os
import random
import sys

import bpy

OUT = sys.argv[sys.argv.index("--") + 1]
BOLTS = 8
ARCS = 6


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "CYCLES"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0.0, -10.0, 0.0)
    cam.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scene.camera = cam
    return scene, cam_data


def emission(name, color, strength):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    for node in list(nodes):
        nodes.remove(node)
    out = nodes.new("ShaderNodeOutputMaterial")
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (*color, 1.0)
    emit.inputs["Strength"].default_value = strength
    mat.node_tree.links.new(emit.outputs[0], out.inputs[0])
    return mat


def displace(a, b, rough, depth, rng):
    """Midpoint displacement in the XZ plane: jagged but with long straight runs, like real strikes."""
    if depth == 0:
        return [a, b]
    mid = [(a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5]
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dz)
    nx, nz = -dz / (length or 1.0), dx / (length or 1.0)
    off = rng.gauss(0.0, 0.5) * rough * length
    mid = [mid[0] + nx * off, mid[1] + nz * off]
    left = displace(a, mid, rough, depth - 1, rng)
    return left[:-1] + displace(mid, b, rough, depth - 1, rng)


LIMIT = (1.85, 3.9)  # half-width / half-height of the frame in world units; points are clamped inside it


def tube(points, radius, taper, mat, y=0.0):
    points = [(max(-LIMIT[0], min(LIMIT[0], x)), max(-LIMIT[1], min(LIMIT[1], z))) for x, z in points]
    curve = bpy.data.curves.new("bolt", type="CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for i, (x, z) in enumerate(points):
        spline.points[i].co = (x, y, z, 1.0)
        # Thick at the root, thin at the tip.
        spline.points[i].radius = max(0.15, 1.0 - taper * i / max(1, len(points) - 1))
    obj = bpy.data.objects.new("bolt", curve)
    obj.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def strike(path, rng, mats, width, branch_chance, branch_depth, rough):
    """Main channel plus forks; each fork recurses once more, thinner and shorter."""
    tube(path, width * 1.0, 0.55, mats[0])
    tube(path, width * 0.38, 0.55, mats[1], y=-0.05)
    if branch_depth == 0:
        return
    for i in range(2, len(path) - 2):
        if rng.random() > branch_chance:
            continue
        x, z = path[i]
        dx, dz = path[min(i + 3, len(path) - 1)][0] - x, path[min(i + 3, len(path) - 1)][1] - z
        angle = math.atan2(dz, dx) + rng.choice((-1, 1)) * rng.uniform(0.35, 0.9)
        reach = rng.uniform(0.35, 1.1) * (1.0 if branch_depth > 1 else 0.6)
        end = [x + math.cos(angle) * reach, z + math.sin(angle) * reach]
        strike(displace([x, z], end, rough, 4, rng), rng, mats, width * 0.5, branch_chance * 0.7, branch_depth - 1, rough)


def clear():
    for obj in list(bpy.data.objects):
        if obj.type == "CURVE":
            bpy.data.objects.remove(obj, do_unlink=True)


def render(scene, cam_data, name, size, ortho):
    scene.render.resolution_x, scene.render.resolution_y = size
    cam_data.ortho_scale = ortho
    scene.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)


def main():
    global LIMIT
    LIMIT = (1.85, 3.9)
    os.makedirs(OUT, exist_ok=True)
    scene, cam_data = setup_scene()
    # Strength 1: colours stay inside the Standard view range (higher clips the blue sheath to white).
    mats = (emission("Glow", (0.32, 0.6, 1.0), 1.0), emission("Core", (0.95, 0.98, 1.0), 1.0))
    for n in range(BOLTS):
        rng = random.Random(100 + n)
        clear()
        # Sky at z=+3.8 down to the ground at z=-3.8; slight lean so frames differ in silhouette.
        top = [rng.uniform(-0.4, 0.4), 3.9]
        path = displace(top, [rng.uniform(-0.12, 0.12), -3.75], 0.16, 6, rng)
        strike(path, rng, mats, 0.05, 0.22, 2, 0.28)
        render(scene, cam_data, "bolt_%d.png" % n, (512, 1024), 8.0)
    LIMIT = (3.9, 0.95)  # arcs frame is 8 x 2 units
    for n in range(ARCS):
        rng = random.Random(500 + n)
        clear()
        # Arcs crawl out from the strike point along the ground, both ways.
        for side in (-1, 1):
            for k in range(2):
                end = [side * rng.uniform(2.4, 3.8), rng.uniform(-0.25, 0.35)]
                path = displace([0.0, 0.0], end, 0.3, 5, rng)
                strike(path, rng, mats, 0.035, 0.18, 1, 0.3)
        render(scene, cam_data, "arcs_%d.png" % n, (1024, 256), 8.0)  # 8 x 2 units
    print("lightning frames written to", OUT)


main()
