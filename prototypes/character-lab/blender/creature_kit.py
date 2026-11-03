"""
Shared modelling kit for the Blender-built mutants (build_rat.py, build_dog.py, ...).
Axes: Blender +X is forward, +Z up, -Y toward the viewer (glTF turns these into Creature3D's +X, +Y, +Z).
Creature3D overwrites pivot rotations every frame, so pivots sit at joints with identity rotation and
the bent pose lives in their child meshes.
"""

import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix, Euler

ROOT = "/Users/Projects/Steampunk-warrior"
RENDER_DIR = os.path.join(ROOT, "prototypes/character-lab/blender/renders")
os.makedirs(RENDER_DIR, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, hex_col, metallic=0.0, roughness=0.55, glow=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    c = tuple(int(hex_col[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    lin = tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (1.0,)
    bsdf.inputs["Base Color"].default_value = lin
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if glow > 0.0:
        bsdf.inputs["Emission Color"].default_value = lin
        bsdf.inputs["Emission Strength"].default_value = glow
    m.diffuse_color = lin
    return m


def link(obj, parent=None):
    bpy.context.scene.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def empty(name, at, parent=None):
    e = link(bpy.data.objects.new(name, None), parent)
    e.empty_display_size = 0.05
    e.location = at
    return e


def mesh_from_bm(name, bm, material, parent=None, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = smooth
    return link(bpy.data.objects.new(name, me), parent)


def sphere(name, at, size, material, parent=None, rot=(0, 0, 0), segs=16):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=max(6, segs // 2), radius=1.0)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(at) @ Euler([math.radians(r) for r in rot]).to_matrix().to_4x4()
                        @ Matrix.Diagonal((*size, 1)), verts=bm.verts)
    return mesh_from_bm(name, bm, material, parent)


def tube(name, points, radii, material, parent=None, sides=10):
    """Swept circle through points with a radius per point; used for limbs, tail, straps."""
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(points):
        p = Vector(p)
        d = (Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(i - 1, 0)])).normalized()
        side = d.cross(Vector((0, 1, 0)))
        if side.length < 1e-4:
            side = d.cross(Vector((1, 0, 0)))
        side.normalize()
        up = side.cross(d).normalized()
        ring = [bm.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * radii[i])
                for a in (2 * math.pi * k / sides for k in range(sides))]
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    for ring, flip in ((rings[0], True), (rings[-1], False)):
        f = bm.faces.new(ring[::-1] if flip else ring)
        bmesh.ops.poke(bm, faces=[f])
    # Godot culls back faces, so the winding must face outward or the ink outline covers the limb.
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_from_bm(name, bm, material, parent)


def smooth_points(ctrl, steps=6):
    """Catmull-Rom through control points so tails and straps curve instead of kinking."""
    out = []
    pts = [Vector(ctrl[0])] + [Vector(c) for c in ctrl] + [Vector(ctrl[-1])]
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for s in range(steps):
            t = s / steps
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    out.append(Vector(ctrl[-1]))
    return out


def prism(name, at, radius, height, material, parent=None, rot=(0, 0, 0)):
    """Hexagonal crystal: six-sided column with a pointed cap, base at `at`."""
    bm = bmesh.new()
    base = [bm.verts.new((radius * math.cos(a), radius * math.sin(a), 0)) for a in (math.pi * k / 3 for k in range(6))]
    top = [bm.verts.new((radius * math.cos(a), radius * math.sin(a), height * 0.72)) for a in (math.pi * k / 3 for k in range(6))]
    tip = bm.verts.new((0, 0, height))
    bm.faces.new(base[::-1])
    for k in range(6):
        bm.faces.new((base[k], base[(k + 1) % 6], top[(k + 1) % 6], top[k]))
        bm.faces.new((top[k], top[(k + 1) % 6], tip))
    bmesh.ops.transform(bm, matrix=Matrix.Translation(at) @ Euler([math.radians(r) for r in rot]).to_matrix().to_4x4(), verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_from_bm(name, bm, material, parent, smooth=False)


def cone(name, at, radius, height, material, parent=None, rot=(0, 0, 0), segs=8):
    """Pointed cone with its base at `at` (ears, teeth, horns)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius, radius2=0.0, depth=height)
    bmesh.ops.translate(bm, vec=(0, 0, height / 2), verts=bm.verts)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(at) @ Euler([math.radians(r) for r in rot]).to_matrix().to_4x4(), verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_from_bm(name, bm, material, parent, smooth=False)


def ring(name, at, major, minor, material, parent=None, rot=(0, 0, 0), arc=360.0, seg=28):
    """Torus or partial torus band (harness straps, frame rails, tube loop)."""
    pts = []
    for k in range(seg + 1):
        a = math.radians(arc) * k / seg
        pts.append((major * math.cos(a), major * math.sin(a), 0.0))
    m = Matrix.Translation(at) @ Euler([math.radians(r) for r in rot]).to_matrix().to_4x4()
    pts = [m @ Vector(p) for p in pts]
    return tube(name, pts, [minor] * len(pts), material, parent, sides=8)


def surface(target, point, offset):
    """Closest point on target's surface pushed out along its normal (places rivets and medallions on the fur)."""
    ok, at, normal, _ = target.closest_point_on_mesh(point)
    return at + normal * offset


def disc(name, at, radius, depth, material, parent=None, rot=(90, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=radius, radius2=radius * 0.85, depth=depth)
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Euler([math.radians(r) for r in rot]).to_matrix(), verts=bm.verts)
    bmesh.ops.translate(bm, vec=at, verts=bm.verts)
    return mesh_from_bm(name, bm, material, parent, smooth=False)


def band(name, target, centre, normal, radius, width, material, parent=None, arc=(0, 360), thickness=0.026):
    """Ribbon circling `centre` in the plane of `normal`, shrinkwrapped onto target and solidified into a strap."""
    n = Vector(normal).normalized()
    a = n.cross(Vector((0, 1, 0)))
    if a.length < 1e-4:
        a = n.cross(Vector((0, 0, 1)))
    a.normalize()
    b = n.cross(a).normalized()
    seg = 40
    closed = arc[1] - arc[0] >= 360
    count = seg if closed else seg + 1
    bm = bmesh.new()
    rows = []
    for k in range(count):
        t = math.radians(arc[0] + (arc[1] - arc[0]) * k / seg)
        p = Vector(centre) + (a * math.cos(t) + b * math.sin(t)) * radius
        rows.append((bm.verts.new(p - n * width / 2), bm.verts.new(p + n * width / 2)))
    for k in range(count if closed else count - 1):
        r0, r1 = rows[k], rows[(k + 1) % count]
        bm.faces.new((r0[0], r1[0], r1[1], r0[1]))
    ob = mesh_from_bm(name, bm, material, parent)
    sub = ob.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    wrap = ob.modifiers.new("Wrap", "SHRINKWRAP")
    wrap.target = target
    wrap.wrap_method = "NEAREST_SURFACEPOINT"
    wrap.wrap_mode = "OUTSIDE_SURFACE"
    wrap.offset = 0.006
    solid = ob.modifiers.new("Solid", "SOLIDIFY")
    solid.thickness = thickness
    solid.offset = 0.0
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    return ob


def blob_body(blobs, material):
    """Ellipsoids (centre, half-sizes, tilt about Y) voxel-remeshed into one mesh so the ink outline has no inner seams."""
    bm = bmesh.new()
    for at, half, tilt in blobs:
        part = bmesh.new()
        bmesh.ops.create_uvsphere(part, u_segments=24, v_segments=12, radius=1.0)
        bmesh.ops.transform(part, matrix=Matrix.Translation(at) @ Euler((0, math.radians(tilt), 0)).to_matrix().to_4x4()
                            @ Matrix.Diagonal((*half, 1)), verts=part.verts)
        tmp = bpy.data.meshes.new("tmp")
        part.to_mesh(tmp)
        part.free()
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    body = mesh_from_bm("Body", bm, material)
    remesh = body.modifiers.new("Remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.018
    smooth = body.modifiers.new("Smooth", "SMOOTH")
    smooth.factor = 0.8
    smooth.iterations = 12
    dec = body.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = 0.12
    bpy.context.view_layer.objects.active = body
    for m in list(body.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    for p in body.data.polygons:
        p.use_smooth = True
    return body


def export(root, glb):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in [root] + list(root.children_recursive):
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_cameras=False, export_lights=False, export_animations=False)


def render_views(root, prefix):
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError as e:
        print(e)
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_object_outline = True
    shading.object_outline_color = (0.06, 0.1, 0.12)
    shading.show_cavity = True
    scene.render.film_transparent = True
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.4
    cam = link(bpy.data.objects.new("Cam", cam_data))
    scene.camera = cam
    for name, yaw in (("game", -30), ("side", 0), ("front", -90)):
        root.rotation_euler = (0, 0, math.radians(yaw))
        cam.location = (0, -10, 0.85)
        cam.rotation_euler = (math.radians(90), 0, 0)
        scene.render.filepath = os.path.join(RENDER_DIR, f"{prefix}_{name}.png")
        bpy.ops.render.render(write_still=True)
    root.rotation_euler = (0, 0, 0)
    bpy.data.objects.remove(cam)
