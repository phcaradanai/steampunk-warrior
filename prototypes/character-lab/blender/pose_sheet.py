"""Contact sheet of vesper poses (side + the in-game 30 deg view) for eyeballing joints and gear clipping.

Run: Blender --background vesper_warrior.blend --python blender/pose_sheet.py -- --out sheet.png [--poses Idle:1,Attack:20]
"""
import bpy
import math
import sys
import numpy as np
from mathutils import Vector

ARM = "VesperRoot"
DEFAULT_POSES = ["Idle:1", "Walk:9", "Walk:25", "Run:6", "Attack:10", "Attack:18", "Attack:22", "Attack:28",
                 "Skill_Stab:20", "Skill_Steam:22", "Guard:14", "Hit:9", "Shoot:14", "Cast:16", "Cast:24",
                 "Heal:16", "Buff:12", "Buff:18", "Down:30", "Jump_Land:8"]
CELL = 300


def show_gear(weapon=0, shield=2, suit=0, head=0):
    for o in bpy.data.objects:
        for prefix, pick in (("Weapon_", weapon), ("Shield_", shield), ("Suit_", suit), ("Headgear_", head)):
            if o.name.startswith(prefix):
                o.hide_render = o.name != f"{prefix}{pick}"
    for name in ("Dummy_Mesh",):
        if name in bpy.data.objects:
            bpy.data.objects[name].hide_render = True


def camera(name, yaw_deg):
    cam = bpy.data.objects.get(name)
    if cam is None:
        cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
        bpy.context.scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.4
    yaw = math.radians(yaw_deg)
    target = Vector((0.15, 0.0, 0.85))
    cam.location = target + Vector((math.sin(yaw) * 6.0, -math.cos(yaw) * 6.0, 0.4))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    return cam


def render_cell(scene, cam, path):
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path, check_existing=False)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(CELL, CELL, 4)
    bpy.data.images.remove(img)
    return px


def run(out, poses, weapon=0, shield=2, suit=0, head=0):
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x = scene.render.resolution_y = CELL
    scene.render.film_transparent = False
    arm = bpy.data.objects[ARM]
    ad = arm.animation_data
    for t in ad.nla_tracks:
        t.mute = True
    show_gear(weapon, shield, suit, head)
    side, front = camera("QA_Side", 0.0), camera("QA_Game", 30.0)  # 30 deg = hero_3d.gd model yaw
    cols = []
    for spec in poses:
        name, frame = spec.split(":")
        ad.action = bpy.data.actions[name]
        ad.action_slot = ad.action.slots[0]
        scene.frame_set(int(frame))
        a = render_cell(scene, side, bpy.app.tempdir + "qa_a.png")
        b = render_cell(scene, front, bpy.app.tempdir + "qa_b.png")
        cols.append(np.concatenate([b, a], axis=0))
    per_row = min(10, len(cols))
    while len(cols) % per_row:
        cols.append(np.ones_like(cols[0]))
    rows = [np.concatenate(cols[i:i + per_row], axis=1) for i in range(0, len(cols), per_row)]
    sheet = np.concatenate(rows[::-1], axis=0)
    img = bpy.data.images.new("QA_Sheet", sheet.shape[1], sheet.shape[0], alpha=True)
    img.pixels = sheet.ravel()
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    return {"out": out, "poses": poses}


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[argv.index("--out") + 1]
    poses = argv[argv.index("--poses") + 1].split(",") if "--poses" in argv else DEFAULT_POSES
    gear = [int(x) for x in argv[argv.index("--gear") + 1].split(",")] if "--gear" in argv else [0, 2, 0]
    if "--cell" in argv:
        CELL = int(argv[argv.index("--cell") + 1])
    print("@@JSON@@", run(out, poses, *gear))
