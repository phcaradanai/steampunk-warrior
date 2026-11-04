# Builds and renders the hub and pipe-line arena backdrops for the game.
# Run: /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python prototypes/environments/build_backdrops.py -- <out_dir>
import bpy, sys, math, json, os
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp"
os.makedirs(OUT, exist_ok=True)
MATS = {}


def reset():
    for scene_object in list(bpy.data.objects):
        bpy.data.objects.remove(scene_object, do_unlink=True)
    for collection in (bpy.data.meshes, bpy.data.lights, bpy.data.cameras, bpy.data.curves):
        for block in list(collection):
            collection.remove(block)


def mat(name, color, rough=0.7, metal=0.0, emit=None, strength=0.0, noise=0.0, bricks=None):
    key = name
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    base = bsdf.inputs["Base Color"]
    if bricks:
        tex = nodes.new("ShaderNodeTexBrick")
        tex.inputs["Color1"].default_value = (*color, 1)
        tex.inputs["Color2"].default_value = (*[c * 0.82 for c in color], 1)
        tex.inputs["Mortar"].default_value = (*[c * 0.35 for c in color], 1)
        tex.inputs["Scale"].default_value = bricks
        tex.inputs["Mortar Size"].default_value = 0.025
        links.new(tex.outputs["Color"], base)
    elif noise:
        tex = nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = noise
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (*[c * 0.72 for c in color], 1)
        ramp.color_ramp.elements[1].color = (*[min(1, c * 1.15) for c in color], 1)
        links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], base)
    else:
        base.default_value = (*color, 1)
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*emit, 1)
        bsdf.inputs["Emission Strength"].default_value = strength
    MATS[key] = m
    return m


def put(obj, material, name):
    obj.name = name
    obj.data.materials.append(material)
    return obj


def box(name, loc, size, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    obj = bpy.context.object
    obj.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    return put(obj, material, name)


def cyl(name, loc, radius, depth, material, rot=(0, 0, 0), verts=40, fill="NGON", smooth=True):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot, end_fill_type=fill)
    if smooth:
        bpy.ops.object.shade_smooth()
    return put(bpy.context.object, material, name)


def torus(name, loc, major, minor, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc, rotation=rot, major_segments=48, minor_segments=12)
    bpy.ops.object.shade_smooth()
    return put(bpy.context.object, material, name)


def sphere(name, loc, radius, material):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=loc, segments=16, ring_count=8)
    bpy.ops.object.shade_smooth()
    return put(bpy.context.object, material, name)


def light(kind, loc, energy, color, size=0.5, rot=(0, 0, 0)):
    data = bpy.data.lights.new("L", kind)
    data.energy = energy
    data.color = color
    if kind in ("POINT", "SPOT", "AREA"):
        data.shadow_soft_size = size
    obj = bpy.data.objects.new("Light", data)
    obj.location = loc
    obj.rotation_euler = rot
    bpy.context.scene.collection.objects.link(obj)
    return obj


def camera(loc, target, lens):
    data = bpy.data.cameras.new("Cam")
    data.lens = lens
    obj = bpy.data.objects.new("Cam", data)
    obj.location = loc
    obj.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.scene.camera = obj
    return obj


def setup(width, height, sky):
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.film_transparent = False
    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = 1.6
    lineset = scene.view_layers[0].freestyle_settings.linesets[0] if scene.view_layers[0].freestyle_settings.linesets else scene.view_layers[0].freestyle_settings.linesets.new("Ink")
    lineset.linestyle.color = (0.06, 0.08, 0.09)
    lineset.select_by_visibility = True
    lineset.select_crease = True
    lineset.select_silhouette = True
    lineset.select_border = True
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    world = bpy.data.worlds.new("World") if scene.world is None else scene.world
    scene.world = world
    world.use_nodes = True
    background = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    background.inputs["Color"].default_value = (*sky, 1)
    background.inputs["Strength"].default_value = 0.6


def render(name):
    path = os.path.join(OUT, name)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("WROTE", path)


def project(points):
    scene = bpy.context.scene
    bpy.context.view_layer.update()
    result = {}
    for key, point in points.items():
        co = world_to_camera_view(scene, scene.camera, Vector(point))
        result[key] = [round(co.x * scene.render.resolution_x, 1), round((1 - co.y) * scene.render.resolution_y, 1)]
    return result


# ---------------------------------------------------------------- hub
PIPES = {"R02": (-4.7, (0.95, 0.72, 0.38)), "P01": (0.0, (0.35, 0.95, 0.75)), "P02": (4.7, (1.0, 0.5, 0.18))}


def pipe_mouth(key, x, glow, rims):
    wall_y = 6.8
    iron = mat("PipeIron", (0.16, 0.19, 0.19), 0.45, 0.8, noise=6)
    brass = mat("Brass", (0.72, 0.52, 0.24), 0.35, 0.9)
    cyl(key + "_Shell", (x, wall_y - 0.15, 1.3), 1.1, 1.0, mat("TubeDark", (0.04, 0.05, 0.05), 0.8), rot=(math.pi / 2, 0, 0), fill="NOTHING")
    cyl(key + "_Inner", (x, wall_y + 0.3, 1.3), 1.1, 0.05, mat("Glow" + key, (0.02, 0.02, 0.02), emit=[c * 0.5 for c in glow], strength=1.2), rot=(math.pi / 2, 0, 0), smooth=False)
    rim = torus(key + "_Rim", (x, wall_y - 0.62, 1.3), 1.2, 0.17, brass, rot=(math.pi / 2, 0, 0))
    rims.append(rim)
    for i in range(10):
        a = i * math.tau / 10
        rims.append(sphere(key + "_Rivet%d" % i, (x + math.cos(a) * 1.2, wall_y - 0.8, 1.3 + math.sin(a) * 1.2), 0.07, brass))
    box(key + "_Ramp", (x, wall_y - 1.3, 0.04), (2.0, 1.4, 0.08), mat("RampPlate", (0.33, 0.3, 0.26), 0.6, 0.6, bricks=9))
    # Each line reads by shape, not only by glow colour: sign symbol differs per pipe.
    plate = box(key + "_Sign", (x, wall_y - 0.3, 3.05), (1.5, 0.12, 0.55), mat("SignPlate", (0.22, 0.17, 0.11), 0.6, 0.3))
    ink = mat("SignInk" + key, glow, emit=glow, strength=0.8)
    if key == "P01":
        for i in range(3):
            box(key + "_Wave%d" % i, (x - 0.45 + i * 0.45, wall_y - 0.38, 3.05), (0.3, 0.05, 0.08), ink, rot=(0, 0.5 * (-1) ** i, 0))
    elif key == "P02":
        box(key + "_RailA", (x, wall_y - 0.38, 3.15), (1.1, 0.05, 0.06), ink)
        box(key + "_RailB", (x, wall_y - 0.38, 2.95), (1.1, 0.05, 0.06), ink)
        for i in range(4):
            box(key + "_Tie%d" % i, (x - 0.42 + i * 0.28, wall_y - 0.38, 3.05), (0.07, 0.05, 0.38), ink)
    elif key.startswith("Exit"):
        # Exits point the way they lead so a door reads as travel, not a fight.
        side = -1 if key.endswith("L") else 1
        for i, z in enumerate((3.14, 2.96)):
            box(key + "_Chevron%d" % i, (x, wall_y - 0.38, z), (0.08, 0.05, 0.26), ink, rot=(0, side * (0.8 if i else -0.8), 0))
    else:
        cyl(key + "_Coin", (x, wall_y - 0.38, 3.05), 0.18, 0.05, ink, rot=(math.pi / 2, 0, 0))
    valve_x = x + 1.75
    cyl(key + "_ValveStem", (valve_x, wall_y - 0.2, 1.0), 0.07, 0.6, iron, rot=(math.pi / 2, 0, 0))
    torus(key + "_Valve", (valve_x, wall_y - 0.5, 1.0), 0.32, 0.05, mat("RedValve", (0.6, 0.14, 0.1), 0.5, 0.4), rot=(math.pi / 2, 0, 0))
    light("POINT", (x, wall_y - 1.2, 1.3), 140, glow, 0.8)
    return {key + "_floor": (x, wall_y - 1.6, 0.0), key + "_center": (x, wall_y - 0.6, 1.3), key + "_top": (x, wall_y - 0.6, 2.6)}


def hub():
    reset()
    setup(2560, 1040, (0.03, 0.05, 0.06))
    floor = mat("HubFloor", (0.29, 0.3, 0.28), 0.65, 0.55, bricks=2.5)
    wall = mat("HubWall", (0.33, 0.24, 0.18), 0.85, bricks=4.5)
    iron = mat("PipeIron", (0.16, 0.19, 0.19), 0.45, 0.8, noise=6)
    copper = mat("Copper", (0.62, 0.32, 0.18), 0.4, 0.9)
    box("Floor", (0, 2.5, -0.1), (20, 11, 0.2), floor)
    box("BackWall", (0, 7.2, 3), (20, 0.4, 6.4), wall)
    box("WallL", (-8.6, 2.5, 3), (0.4, 11, 6.4), wall)
    box("WallR", (8.6, 2.5, 3), (0.4, 11, 6.4), wall)
    box("Skirting", (0, 6.95, 0.25), (17, 0.15, 0.5), iron)
    rims = []
    points = {}
    for key, (x, glow) in PIPES.items():
        points.update(pipe_mouth(key, x, glow, rims))
    for z in (4.3, 4.85):
        cyl("Header%.1f" % z, (0, 6.75, z), 0.22, 17, copper, rot=(0, math.pi / 2, 0))
    for side in (-1, 1):
        cyl("Riser%d" % side, (side * 8.2, 6.5, 3), 0.25, 6, copper)
        cyl("Boiler%d" % side, (side * 7.2, 5.6, 1.5), 1.0, 3.0, iron)
        sphere("BoilerCap%d" % side, (side * 7.2, 5.6, 3.0), 1.0, iron)
        cyl("Gauge%d" % side, (side * 7.2, 4.6, 1.9), 0.3, 0.1, mat("GaugeFace", (0.9, 0.86, 0.72), emit=(1, 0.9, 0.6), strength=0.4), rot=(math.pi / 2, 0, 0))
        for i in range(2):
            box("Crate%d_%d" % (side, i), (side * (7.4 - i * 0.9), 0.2 + i * 1.2, 0.45 + i * 0.0), (0.9, 0.9, 0.9), mat("Crate", (0.42, 0.28, 0.16), 0.9, bricks=12))
        lamp = (side * 2.35, 6.85, 3.6)
        cyl("Lamp%d" % side, lamp, 0.14, 0.4, mat("Bulb", (1, 0.85, 0.5), emit=(1, 0.78, 0.4), strength=8))
        light("POINT", (lamp[0], lamp[1] - 0.6, lamp[2]), 260, (1, 0.72, 0.4), 0.3)
    light("SUN", (0, 0, 10), 1.2, (0.75, 0.85, 0.9), rot=(math.radians(35), math.radians(-15), math.radians(10)))
    light("AREA", (0, -2, 6), 500, (0.85, 0.9, 1), 6, rot=(math.radians(-20), 0, 0))
    camera((0, -11.5, 8.2), (0, 4.2, 1.6), 30)
    corners = {"floor_back_l": (-8.4, 6.95, 0), "floor_back_r": (8.4, 6.95, 0), "floor_front_l": (-8.4, -3, 0), "floor_front_r": (8.4, -3, 0)}
    points.update(corners)
    with open(os.path.join(OUT, "hub_points.json"), "w") as f:
        json.dump(project(points), f, indent=1)
    render("hub.png")
    # Rim pass: only the brass rims over a transparent film, drawn above the player to occlude pipe entry.
    keep = set(rims)
    for obj in bpy.data.objects:
        if obj.type == "MESH" and obj not in keep:
            obj.is_holdout = True
    bpy.context.scene.render.film_transparent = True
    bpy.context.scene.render.use_freestyle = True
    render("hub_rims.png")


# ---------------------------------------------------------------- arenas
def arena(name, sky, ground, far, props):
    reset()
    setup(2560, 800, sky)
    box("Ground", (0, 4, -0.1), (40, 16, 0.2), ground() if callable(ground) else ground)
    props()
    light("SUN", (0, 0, 10), 2.2, (1, 0.92, 0.82), rot=(math.radians(50), math.radians(20), math.radians(-30)))
    camera((0, -12, 2.4), (0, 8, 1.9), 32)
    with open(os.path.join(OUT, name + "_points.json"), "w") as f:
        json.dump(project({"left_stand": (-3.2, 1, 0), "right_stand": (3.2, 1, 0), "center": (0, 1, 0)}), f, indent=1)
    render(name + ".png")


def canal_props():
    wall = mat("SewerBrick", (0.24, 0.27, 0.24), 0.9, bricks=3.5)
    slime = mat("Slime", (0.12, 0.3, 0.22), 0.3, emit=(0.15, 0.6, 0.4), strength=0.5)
    iron = mat("PipeIron", (0.16, 0.19, 0.19), 0.45, 0.8, noise=6)
    box("Water", (0, 7.5, -0.05), (60, 4, 0.1), mat("Water", (0.05, 0.18, 0.16), 0.1, 0.2, emit=(0.1, 0.4, 0.3), strength=0.3))
    box("Ledge", (0, 10.2, 0.3), (60, 1.6, 0.6), wall)
    box("BackWall", (0, 11.5, 5), (60, 0.6, 10), wall)
    for i, x in enumerate(range(-18, 19, 6)):
        cyl("Arch%d" % i, (x, 11.15, 2.6), 1.9, 0.1, mat("Dark", (0.02, 0.03, 0.03), emit=(0.05, 0.22, 0.16), strength=0.6), rot=(math.pi / 2, 0, 0), smooth=False)
        torus("ArchRim%d" % i, (x, 10.95, 2.6), 2.0, 0.2, iron, rot=(math.pi / 2, 0, 0))
        box("Drip%d" % i, (x + 2.9, 11.1, 3.0), (0.35, 0.05, 6), slime)
        light("POINT", (x, 9.5, 2.6), 160, (0.4, 1, 0.7), 1)
    cyl("Overhead", (0, 10.6, 6.2), 0.6, 60, iron, rot=(0, math.pi / 2, 0))
    for x in (-11, 11):
        cyl("Column%d" % x, (x, 5.5, 4), 0.5, 8, iron)
    box("Grate", (0, 2.0, 0.01), (5, 1.0, 0.04), mat("Grate", (0.12, 0.14, 0.14), 0.5, 0.8, bricks=14))


def rail_props():
    iron = mat("PipeIron", (0.16, 0.19, 0.19), 0.45, 0.8, noise=6)
    rust = mat("Rust", (0.45, 0.22, 0.12), 0.85, 0.3, noise=4)
    brick = mat("YardBrick", (0.42, 0.24, 0.17), 0.9, bricks=3)
    for y in (6.4, 7.6):
        box("Rail%.1f" % y, (0, y, 0.08), (60, 0.12, 0.12), iron)
    for i in range(-30, 31):
        box("Tie%d" % i, (i, 7.0, 0.03), (0.3, 1.8, 0.08), mat("Tie", (0.25, 0.17, 0.1), 0.9))
    box("Wagon", (5, 10.5, 1.5), (8, 2.4, 2.2), rust)
    for x in (2.2, 7.8):
        cyl("Wheel%d" % x, (x, 9.25, 0.45), 0.45, 0.15, iron, rot=(math.pi / 2, 0, 0), smooth=False)
    box("Coal", (5, 10.5, 2.75), (7.6, 2.0, 0.4), mat("Coal", (0.06, 0.06, 0.07), 0.6, noise=20))
    box("Shed", (-15, 21, 2), (10, 3, 4), brick)
    for i, x in enumerate((-16, -6, 14)):
        cyl("Stack%d" % i, (x, 30, 6), 0.9, 16, brick)
    box("FarWall", (0, 34, 1.5), (120, 0.5, 3), brick)
    cyl("Sun", (9, 40, 11), 2.5, 0.1, mat("SunDisc", (1, 0.8, 0.5), emit=(1, 0.75, 0.45), strength=3), rot=(math.pi / 2, 0, 0), smooth=False)
    light("POINT", (-3, 1, 3), 200, (1, 0.6, 0.3), 1.5)


# ---------------------------------------------------------------- rooms
THEMES = {
    "hub": dict(wall=(0.36, 0.25, 0.17), floor=(0.33, 0.29, 0.24), glow=(1.0, 0.78, 0.45), sky=(0.04, 0.04, 0.05), floor_bricks=2.5, wall_bricks=4.5),
    "canal": dict(wall=(0.22, 0.27, 0.24), floor=(0.24, 0.29, 0.27), glow=(0.35, 0.95, 0.75), sky=(0.02, 0.05, 0.05), floor_bricks=3.0, wall_bricks=3.5),
    "rail": dict(wall=(0.42, 0.24, 0.17), floor=(0.3, 0.24, 0.19), glow=(1.0, 0.55, 0.25), sky=(0.05, 0.03, 0.02), floor_bricks=6.0, wall_bricks=3.0),
    "garden": dict(wall=(0.2, 0.3, 0.24), floor=(0.3, 0.33, 0.27), glow=(0.55, 1.0, 0.5), sky=(0.02, 0.05, 0.03), floor_bricks=2.0, wall_bricks=1.6),
    "coal": dict(wall=(0.16, 0.15, 0.15), floor=(0.13, 0.12, 0.12), glow=(1.0, 0.62, 0.3), sky=(0.01, 0.01, 0.01), floor_bricks=0, wall_bricks=0),
    "foundry": dict(wall=(0.38, 0.2, 0.13), floor=(0.24, 0.22, 0.21), glow=(1.0, 0.42, 0.12), sky=(0.05, 0.02, 0.01), floor_bricks=2.5, wall_bricks=3.0),
    "archive": dict(wall=(0.24, 0.27, 0.33), floor=(0.33, 0.25, 0.18), glow=(0.6, 0.75, 1.0), sky=(0.02, 0.02, 0.04), floor_bricks=7.0, wall_bricks=2.5),
    "reactor": dict(wall=(0.15, 0.25, 0.27), floor=(0.2, 0.25, 0.26), glow=(0.3, 0.95, 1.0), sky=(0.01, 0.03, 0.04), floor_bricks=2.0, wall_bricks=2.0),
}
VIEW_SCALE = 520.0 / 480.0


def floor_point(lx, ly):
    """Map a WorldView logical point to the Blender floor plane under the hub camera."""
    scene = bpy.context.scene
    cam = scene.camera
    bpy.context.view_layer.update()
    u = (lx * VIEW_SCALE + 120) / 1280.0
    v = 1.0 - (ly * VIEW_SCALE) / 520.0
    frame = cam.data.view_frame(scene=scene)
    xs = [c.x for c in frame]
    ys = [c.y for c in frame]
    local = Vector((min(xs) + u * (max(xs) - min(xs)), min(ys) + v * (max(ys) - min(ys)), frame[0].z))
    origin = cam.matrix_world.translation
    direction = (cam.matrix_world @ local) - origin
    t = -origin.z / direction.z
    return origin + direction * t


def room_prop(kind, rect, theme, index):
    corners = [floor_point(rect[0], rect[1]), floor_point(rect[0] + rect[2], rect[1] + rect[3])]
    cx, cy = (corners[0].x + corners[1].x) / 2, (corners[0].y + corners[1].y) / 2
    w, d = abs(corners[1].x - corners[0].x), max(0.5, abs(corners[1].y - corners[0].y))
    name = "Prop%d" % index
    wood = mat("PropWood", (0.42, 0.28, 0.16), 0.9, bricks=10)
    iron = mat("PipeIron", (0.16, 0.19, 0.19), 0.45, 0.8, noise=6)
    glow = THEMES[theme]["glow"]
    if kind == "stall":
        box(name, (cx, cy, 0.5), (w, d, 1.0), wood)
        box(name + "Awning", (cx, cy, 1.9), (w * 1.1, d * 1.2, 0.12), mat("Awning", (0.55, 0.18, 0.14), 0.8))
        for side in (-1, 1):
            cyl(name + "Pole%d" % side, (cx + side * w * 0.45, cy, 1.0), 0.05, 1.9, iron)
    elif kind == "crates":
        for i in range(3):
            box(name + "_%d" % i, (cx - w * 0.25 + (i % 2) * w * 0.5, cy, 0.4 + (i // 2) * 0.8), (w * 0.45, d, 0.8), wood)
    elif kind == "barrels":
        for i in range(3):
            cyl(name + "_%d" % i, (cx - w * 0.33 + i * w * 0.33, cy, 0.55), min(w, d) * 0.28, 1.1, mat("Barrel", (0.28, 0.4, 0.3), 0.6, 0.3))
    elif kind == "sluice":
        box(name, (cx, cy, 0.6), (w, d, 1.2), iron)
        torus(name + "Wheel", (cx, cy - d * 0.55, 0.9), 0.35, 0.05, mat("RedValve", (0.6, 0.14, 0.1), 0.5, 0.4), rot=(math.pi / 2, 0, 0))
    elif kind == "cart":
        box(name, (cx, cy, 0.7), (w, d, 0.8), mat("Rust", (0.45, 0.22, 0.12), 0.85, 0.3, noise=4))
        box(name + "Load", (cx, cy, 1.15), (w * 0.9, d * 0.8, 0.2), mat("Coal", (0.06, 0.06, 0.07), 0.6, noise=20))
        for side in (-1, 1):
            cyl(name + "Wheel%d" % side, (cx + side * w * 0.32, cy - d * 0.5, 0.28), 0.28, 0.1, iron, rot=(math.pi / 2, 0, 0), smooth=False)
    elif kind == "sacks":
        for i in range(4):
            sphere(name + "_%d" % i, (cx - w * 0.3 + (i % 3) * w * 0.3, cy, 0.3 + (i // 3) * 0.45), min(w, d) * 0.3, mat("Sack", (0.55, 0.45, 0.3), 0.95))
    elif kind == "planter":
        box(name, (cx, cy, 0.35), (w, d, 0.7), mat("Planter", (0.5, 0.36, 0.24), 0.8, bricks=6))
        for i in range(3):
            sphere(name + "Leaf%d" % i, (cx - w * 0.3 + i * w * 0.3, cy, 0.95), min(w, d) * 0.36, mat("Leaf", (0.2, 0.55, 0.25), 0.7, emit=(0.2, 0.6, 0.25), strength=0.25))
    elif kind == "heap":
        bpy.ops.mesh.primitive_cone_add(radius1=max(w, d) * 0.5, depth=1.1, location=(cx, cy, 0.55), vertices=10)
        put(bpy.context.object, mat("Coal", (0.06, 0.06, 0.07), 0.6, noise=20), name)
    elif kind == "anvil":
        box(name, (cx, cy, 0.35), (w * 0.5, d * 0.6, 0.7), iron)
        box(name + "Top", (cx, cy, 0.8), (w, d * 0.7, 0.25), iron)
    elif kind == "crucible":
        cyl(name, (cx, cy, 0.6), min(w, d) * 0.5, 1.2, iron)
        cyl(name + "Melt", (cx, cy, 1.2), min(w, d) * 0.42, 0.04, mat("Melt", (1, 0.4, 0.1), emit=(1, 0.45, 0.1), strength=6), smooth=False)
        light("POINT", (cx, cy, 1.8), 120, (1, 0.5, 0.2), 0.5)
    elif kind == "shelf":
        box(name, (cx, cy, 1.0), (w, d * 0.6, 2.0), wood)
        for i in range(3):
            box(name + "Books%d" % i, (cx, cy - d * 0.31, 0.45 + i * 0.6), (w * 0.9, 0.05, 0.4), mat("Books", (0.3, 0.2, 0.35), 0.8, bricks=20))
    elif kind == "desk":
        box(name, (cx, cy, 0.4), (w, d, 0.8), wood)
        cyl(name + "Lamp", (cx + w * 0.3, cy, 0.95), 0.08, 0.3, mat("Bulb", (1, 0.85, 0.5), emit=(1, 0.78, 0.4), strength=8))
    elif kind == "coil":
        cyl(name, (cx, cy, 0.8), min(w, d) * 0.35, 1.6, iron)
        for i in range(4):
            torus(name + "Ring%d" % i, (cx, cy, 0.3 + i * 0.4), min(w, d) * 0.42, 0.05, mat("CoilGlow", glow, emit=glow, strength=2))


PROP_OBJECTS = {}
PROP_META = {}


def crop_sprite(src, dst):
    """Crop a transparent render to its alpha bounding box; return the crop origin in backdrop pixels."""
    import numpy as np
    img = bpy.data.images.load(src)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]  # top-down rows
    ys, xs = np.nonzero(px[..., 3] > 0.004)
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()) + 1, int(ys.min()), int(ys.max()) + 1
    out = bpy.data.images.new("sprite", x1 - x0, y1 - y0, alpha=True)
    out.pixels = px[y0:y1, x0:x1][::-1].ravel().tolist()
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    out.filepath_raw = dst
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    bpy.data.images.remove(img)
    return {"file": os.path.basename(dst), "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0}


def room(rid, spec, exits):
    PROP_OBJECTS.clear()
    reset()
    theme = THEMES[spec["palette"]]
    setup(2560, 1040, theme["sky"])
    camera((0, -11.5, 8.2), (0, 4.2, 1.6), 30)
    floor = mat("Floor_" + spec["palette"], theme["floor"], 0.65, 0.45, bricks=theme["floor_bricks"], noise=0 if theme["floor_bricks"] else 9)
    wall = mat("Wall_" + spec["palette"], theme["wall"], 0.85, bricks=theme["wall_bricks"], noise=0 if theme["wall_bricks"] else 5)
    iron = mat("PipeIron", (0.16, 0.19, 0.19), 0.45, 0.8, noise=6)
    box("Floor", (0, 2.5, -0.1), (20, 11, 0.2), floor)
    box("BackWall", (0, 7.2, 3), (20, 0.4, 6.4), wall)
    box("WallL", (-8.6, 2.5, 3), (0.4, 11, 6.4), wall)
    box("WallR", (8.6, 2.5, 3), (0.4, 11, 6.4), wall)
    box("Skirting", (0, 6.95, 0.25), (17, 0.15, 0.5), iron)
    rims = []
    glow = theme["glow"]
    if exits.get("left"):
        pipe_mouth("ExitL", -4.7, glow, rims)
    if exits.get("right"):
        pipe_mouth("ExitR", 4.7, glow, rims)
    else:
        # Dead end: a bolted hatch so the slot still reads as a pipe, but shut.
        cyl("Hatch", (4.7, 6.6, 1.3), 1.15, 0.2, iron, rot=(math.pi / 2, 0, 0))
        for a in (0.6, -0.6):
            box("HatchBar%.1f" % a, (4.7, 6.45, 1.3), (2.0, 0.1, 0.2), mat("RedValve", (0.6, 0.14, 0.1), 0.5, 0.4), rot=(0, a, 0))
    if spec["center"] == "travel":
        pipe_mouth("Tram", 0.0, (1.0, 0.85, 0.5), rims)
    else:
        box("Machine", (0, 6.7, 1.6), (2.6, 0.6, 3.2), iron)
        for i in range(3):
            cyl("MachineGauge%d" % i, (-0.8 + i * 0.8, 6.35, 2.3), 0.28, 0.08, mat("GaugeFace", (0.9, 0.86, 0.72), emit=(1, 0.9, 0.6), strength=0.4), rot=(math.pi / 2, 0, 0))
        box("MachineGlow", (0, 6.38, 1.1), (1.8, 0.05, 0.5), mat("Glow_" + spec["palette"], glow, emit=glow, strength=1.5))
    for side in (-1, 1):
        cyl("Riser%d" % side, (side * 8.2, 6.5, 3), 0.25, 6, mat("Copper", (0.62, 0.32, 0.18), 0.4, 0.9))
        lamp = (side * 2.35, 6.85, 3.6)
        cyl("Lamp%d" % side, lamp, 0.14, 0.4, mat("Bulb", (1, 0.85, 0.5), emit=(1, 0.78, 0.4), strength=8))
        light("POINT", (lamp[0], lamp[1] - 0.6, lamp[2]), 220, glow, 0.3)
    for i, prop in enumerate(spec["props"]):
        before = set(bpy.data.objects)
        room_prop(prop["kind"], prop["rect"], spec["palette"], i)
        for obj in set(bpy.data.objects) - before:
            if obj.type == "MESH":
                PROP_OBJECTS.setdefault(i, []).append(obj)
    light("SUN", (0, 0, 10), 1.1, (0.75, 0.85, 0.9), rot=(math.radians(35), math.radians(-15), math.radians(10)))
    light("AREA", (0, -2, 6), 450, (0.85, 0.9, 1), 6, rot=(math.radians(-20), 0, 0))
    # Backdrop: props hidden from the camera but still casting shadows; they ship as separate y-sorted sprites.
    props = [o for objs in PROP_OBJECTS.values() for o in objs]
    for obj in props:
        obj.visible_camera = False
    render("room_%s.png" % rid)
    for obj in props:
        obj.visible_camera = True
    keep = set(rims)
    for obj in bpy.data.objects:
        if obj.type == "MESH" and obj not in keep:
            obj.is_holdout = True
    bpy.context.scene.render.film_transparent = True
    render("room_%s_rims.png" % rid)
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.is_holdout = obj not in props
    meta = []
    for i, objs in sorted(PROP_OBJECTS.items()):
        for obj in props:
            obj.hide_render = obj not in objs
        render("_tmp_prop.png")
        meta.append(crop_sprite(os.path.join(OUT, "_tmp_prop.png"), os.path.join(OUT, "props", "room_%s_%d.png" % (rid, i))))
    os.remove(os.path.join(OUT, "_tmp_prop.png"))
    PROP_META[rid] = meta


def back_wall(color, bricks, glow, feature):
    wall = mat("ArenaWall%s" % feature, color, 0.9, bricks=bricks, noise=0 if bricks else 5)
    box("BackWall", (0, 11.5, 5), (60, 0.6, 10), wall)
    box("Ledge", (0, 10.2, 0.3), (60, 1.6, 0.6), wall)
    for x in range(-18, 19, 6):
        light("POINT", (x, 9.0, 3.0), 140, glow, 1)
    return wall


def garden_props():
    glass = mat("Glass", (0.35, 0.6, 0.45), 0.1, emit=(0.3, 0.7, 0.4), strength=0.5)
    iron = mat("PipeIron", (0.16, 0.19, 0.19), 0.45, 0.8, noise=6)
    back_wall((0.2, 0.3, 0.24), 1.6, (0.55, 1.0, 0.5), "Garden")
    for i, x in enumerate(range(-18, 19, 4)):
        box("Pane%d" % i, (x, 11.15, 4.5), (3.6, 0.05, 6), glass)
        box("Mullion%d" % i, (x + 2, 11.1, 4.5), (0.15, 0.1, 7), iron)
    for i, x in enumerate((-12, -7, 6, 11)):
        cyl("Trunk%d" % i, (x, 9.2, 1.4), 0.18, 2.8, mat("Bark", (0.35, 0.24, 0.14), 0.9))
        sphere("Crown%d" % i, (x, 9.2, 3.2), 1.3, mat("Leaf", (0.2, 0.55, 0.25), 0.7, emit=(0.2, 0.6, 0.25), strength=0.25))


def coal_props():
    rock = back_wall((0.16, 0.15, 0.15), 0, (1.0, 0.62, 0.3), "Coal")
    for i, x in enumerate(range(-16, 17, 8)):
        box("Beam%d" % i, (x, 9.8, 2.5), (0.4, 0.4, 5), mat("Timber", (0.35, 0.24, 0.14), 0.9))
        cyl("Lantern%d" % i, (x + 0.4, 9.5, 3.2), 0.15, 0.35, mat("Bulb", (1, 0.85, 0.5), emit=(1, 0.7, 0.35), strength=8))
    box("Lintel", (0, 9.8, 5.0), (40, 0.5, 0.4), mat("Timber", (0.35, 0.24, 0.14), 0.9))
    for i, x in enumerate((-10, 9)):
        bpy.ops.mesh.primitive_cone_add(radius1=1.6, depth=1.6, location=(x, 8.5, 0.8), vertices=10)
        put(bpy.context.object, mat("Coal", (0.06, 0.06, 0.07), 0.6, noise=20), "Heap%d" % i)


def foundry_props():
    back_wall((0.38, 0.2, 0.13), 3.0, (1.0, 0.42, 0.12), "Foundry")
    melt = mat("Melt", (1, 0.4, 0.1), emit=(1, 0.45, 0.1), strength=6)
    iron = mat("PipeIron", (0.16, 0.19, 0.19), 0.45, 0.8, noise=6)
    # Window glow stays orange and below clipping (strength 6 blew out to cream).
    window = mat("FurnaceWindow", (1, 0.4, 0.1), emit=(1, 0.38, 0.08), strength=2.2)
    box("Channel", (0, 8.8, 0.02), (60, 0.6, 0.06), melt)
    for i, x in enumerate((-11, 0, 11)):
        cyl("Furnace%d" % i, (x, 10.4, 2.5), 1.5, 5, iron)
        box("Mouth%d" % i, (x, 8.95, 1.2), (1.4, 0.1, 1.0), window)
        light("POINT", (x, 8.0, 1.4), 300, (1, 0.45, 0.15), 1)


def archive_props():
    back_wall((0.24, 0.27, 0.33), 2.5, (0.6, 0.75, 1.0), "Archive")
    wood = mat("PropWood", (0.42, 0.28, 0.16), 0.9, bricks=10)
    for i, x in enumerate(range(-16, 17, 4)):
        box("Shelf%d" % i, (x, 10.6, 2.5), (3.4, 0.8, 5), wood)
        for j in range(4):
            box("Books%d_%d" % (i, j), (x, 10.15, 0.7 + j * 1.2), (3.1, 0.05, 0.8), mat("Books", (0.3, 0.2, 0.35), 0.8, bricks=20))


def reactor_props():
    back_wall((0.15, 0.25, 0.27), 2.0, (0.3, 0.95, 1.0), "Reactor")
    iron = mat("PipeIron", (0.16, 0.19, 0.19), 0.45, 0.8, noise=6)
    core = mat("Core", (0.3, 0.95, 1.0), emit=(0.2, 0.8, 0.9), strength=1.3)
    cyl("Core", (0, 10.6, 3.5), 2.2, 7, iron)
    box("CoreWindow", (0, 8.35, 3.2), (1.4, 0.05, 4.5), core)
    for i, x in enumerate((-12, -7, 7, 12)):
        cyl("Coil%d" % i, (x, 9.4, 1.6), 0.6, 3.2, iron)
        for j in range(4):
            torus("Ring%d_%d" % (i, j), (x, 9.4, 0.5 + j * 0.8), 0.7, 0.06, core)


ARENAS = {
    "arena_garden": ((0.03, 0.08, 0.05), lambda: mat("GardenFloor", (0.3, 0.33, 0.27), 0.7, bricks=2), None, lambda: garden_props()),
    "arena_coal": ((0.01, 0.01, 0.01), lambda: mat("CoalFloor", (0.13, 0.12, 0.12), 0.9, noise=14), None, lambda: coal_props()),
    "arena_foundry": ((0.06, 0.02, 0.01), lambda: mat("FoundryFloor", (0.24, 0.22, 0.21), 0.6, 0.5, bricks=2.5), None, lambda: foundry_props()),
    "arena_archive": ((0.02, 0.02, 0.04), lambda: mat("ArchiveFloor", (0.33, 0.25, 0.18), 0.8, bricks=7), None, lambda: archive_props()),
    "arena_reactor": ((0.01, 0.03, 0.04), lambda: mat("ReactorFloor", (0.2, 0.25, 0.26), 0.5, 0.6, bricks=2), None, lambda: reactor_props()),
    "arena_canal": ((0.05, 0.1, 0.1), lambda: mat("CanalFloor", (0.26, 0.3, 0.27), 0.7, 0.4, bricks=3), None, lambda: canal_props()),
    "arena_rail": ((0.55, 0.32, 0.2), lambda: mat("Cinder", (0.3, 0.26, 0.23), 0.95, noise=12), None, lambda: rail_props()),
}


def rooms(targets):
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "data")
    layout = json.load(open(os.path.join(root, "room_props.json")))
    catalog = {r["id"]: r for r in json.load(open(os.path.join(root, "rooms.json")))}
    for rid, spec in layout["rooms"].items():
        if targets and rid not in targets:
            continue
        number = int(rid[1:])
        exits = {"left": any(int(e["to"][1:]) < number for e in catalog[rid]["exits"]), "right": any(int(e["to"][1:]) > number for e in catalog[rid]["exits"])}
        room(rid, spec, exits)
    if PROP_META:
        # Merge so single-room re-renders keep the other rooms' entries.
        path = os.path.join(OUT, "props", "props.json")
        old = json.load(open(path)) if os.path.exists(path) else {}
        old.update(PROP_META)
        json.dump(old, open(path, "w"), indent=1, sort_keys=True)


if __name__ == "__main__":
    # Optional targets after the output dir: "hub", room ids like "R03", or arena names like "arena_canal".
    TARGETS = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else []
    wanted = lambda name: not TARGETS or name in TARGETS
    if wanted("hub"):
        hub()
    rooms([t for t in TARGETS if t.startswith("R")])
    for name, args in ARENAS.items():
        if wanted(name):
            arena(name, *args)
