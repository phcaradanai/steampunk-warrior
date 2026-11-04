"""Motion QA for vesper_warrior.blend: joint bend direction and part interpenetration across every action.

Run: Blender --background vesper_warrior.blend --python blender/rig_audit.py [-- --json out.json --actions Idle,Attack]
Joints: flex in degrees, elbows toward the front of the upper arm, knees toward the back (negative = bent the
wrong way). Clipping: deepest vertex of one loose mesh island inside another, per pair and action. Body parts are
measured beyond their bind-pose overlap; weapons and shields get no allowance except the gripping hand.
Constraints are muted so the numbers match the keyed channels Godot plays. feet_z = lowest sole per action.
"""
import bpy
import bmesh
import json
import math
import sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ARM = "VesperRoot"
CLIP_TOLERANCE = 0.008  # metres of overlap ignored (bevel/outline noise)
LIMBS = {"elbow_R": ("Shoulder_R", "Elbow_R", "Hand_R", 1), "elbow_L": ("Shoulder_L", "Elbow_L", "Hand_L", 1),
         "knee_R": ("Thigh_R", "Knee_R", "Foot_R", -1), "knee_L": ("Thigh_L", "Knee_L", "Foot_L", -1)}
# Islands that never meet in game: alternate gear of the same slot.
SLOTS = ("Weapon_", "Headgear_", "Suit_", "Shield_")
# Held gear and the body bones allowed to touch it (the grip).
HELD = ("Weapon_", "Shield_")
GRIP = {"WeaponMount": ("Hand_R",), "ShieldMount": ("Hand_L", "Elbow_L")}
STRIKES = ("Attack", "Skill_Stab", "Skill_Steam", "Shoot", "Cast", "Heal", "Buff", "Guard", "Hit")


def flex_angles(arm):
    out = {}
    for name, (a, b, c, sign) in LIMBS.items():
        pa, pb, pc = (arm.pose.bones[n] for n in (a, b, c))
        frame = (arm.matrix_world @ pa.matrix).to_3x3().normalized().inverted()
        upper = frame @ ((arm.matrix_world @ pb.head) - (arm.matrix_world @ pa.head))
        lower = frame @ ((arm.matrix_world @ pc.head) - (arm.matrix_world @ pb.head))
        cross = upper.x * lower.y - upper.y * lower.x
        out[name] = math.degrees(math.atan2(cross, upper.x * lower.x + upper.y * lower.y)) * sign
    return out


def islands(obj, depsgraph):
    """Loose parts of the evaluated mesh in world space, tagged by owner object and dominant bone."""
    ev = obj.evaluated_get(depsgraph)
    me = ev.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.transform(obj.matrix_world)
    groups = {g.index: g.name for g in obj.vertex_groups}
    weights = [max(v.groups, key=lambda g: g.weight).group if len(v.groups) else -1 for v in obj.data.vertices]
    seen = set()
    parts = []
    bm.verts.ensure_lookup_table()
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, idx = [v], []
        seen.add(v.index)
        while stack:
            cur = stack.pop()
            idx.append(cur.index)
            for e in cur.link_edges:
                o = e.other_vert(cur)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        sub = bmesh.new()
        lookup = {}
        for i in idx:
            lookup[i] = sub.verts.new(bm.verts[i].co)
        faces = {f for i in idx for f in bm.verts[i].link_faces}
        for f in faces:
            try:
                sub.faces.new([lookup[x.index] for x in f.verts])
            except ValueError:
                pass
        sub.normal_update()
        bone = groups.get(weights[idx[0]], "?")
        parts.append({"obj": obj.name, "bone": bone, "bm": sub, "bvh": BVHTree.FromBMesh(sub),
                      "co": [sub_v.co.copy() for sub_v in sub.verts],
                      "min": Vector([min(c[i] for c in (x.co for x in sub.verts)) for i in range(3)]),
                      "max": Vector([max(c[i] for c in (x.co for x in sub.verts)) for i in range(3)])})
    bm.free()
    ev.to_mesh_clear()
    return parts


def depth_inside(a, b):
    """Deepest vertex of island a inside closed island b (0 if none)."""
    if any(a["max"][i] < b["min"][i] or b["max"][i] < a["min"][i] for i in range(3)):
        return 0.0
    if not a["bvh"].overlap(b["bvh"]) and not _contains(b, a["co"][0]):
        return 0.0
    deepest = 0.0
    for co in a["co"]:
        if not _contains(b, co):
            continue
        hit = b["bvh"].find_nearest(co)
        if hit[0] is not None:
            deepest = max(deepest, hit[3])
    return deepest


def _contains(b, co):
    # Parity of hits along +X; islands are closed primitives.
    hits, origin = 0, co.copy()
    direction = Vector((1.0, 0.0137, 0.0071)).normalized()
    for _ in range(16):
        loc, _n, _i, _d = b["bvh"].ray_cast(origin, direction)
        if loc is None:
            break
        hits += 1
        origin = loc + direction * 1e-5
    return hits % 2 == 1


def same_slot_alternates(a, b):
    for s in SLOTS:
        if a["obj"].startswith(s) and b["obj"].startswith(s) and a["obj"] != b["obj"]:
            return True
    return False


def scene_parts(depsgraph):
    objs = sorted((o for o in bpy.data.objects if o.type == "MESH" and o.parent and o.parent.name == ARM), key=lambda o: o.name)
    parts = []
    for o in objs:
        parts += islands(o, depsgraph)
    return parts


def pair_key(a, b):
    return tuple(sorted((f"{a['obj']}:{a['bone']}", f"{b['obj']}:{b['bone']}")))


def is_held(a):
    return a["obj"].startswith(HELD)


def allowed(a, b):
    """Held gear may only touch the hand that grips it; everything else is judged against the bind pose."""
    for g, o in ((a, b), (b, a)):
        if is_held(g) and o["obj"] == "Vesper_Body" and o["bone"] in GRIP[g["bone"]]:
            return True
    return False


def overlap_depth(a, b):
    return max(depth_inside(a, b), depth_inside(b, a))


def run(actions=None):
    arm = bpy.data.objects[ARM]
    scene = bpy.context.scene
    ad = arm.animation_data
    for t in ad.nla_tracks:
        t.mute = True
    # Measure what Godot plays: the keyed channels, not Blender-only limit constraints.
    muted = [c for pb in arm.pose.bones for c in pb.constraints if not c.mute]
    for c in muted:
        c.mute = True

    # Body layering is judged against the bind pose; held gear (weapon, shield) gets no allowance.
    arm.data.pose_position = "REST"
    scene.frame_set(1)
    bind = scene_parts(bpy.context.evaluated_depsgraph_get())
    baseline = {}
    for i, a in enumerate(bind):
        for j in range(i + 1, len(bind)):
            b = bind[j]
            if is_held(a) or is_held(b) or same_slot_alternates(a, b):
                continue
            d = overlap_depth(a, b)
            if d > 0.0:
                baseline[(i, j)] = d
    for p in bind:
        p["bm"].free()
    arm.data.pose_position = "POSE"

    report = {"joints": {}, "clipping": {}, "feet_z": {}}
    names = actions or [t.name for t in ad.nla_tracks]
    for name in names:
        act = bpy.data.actions[name]
        ad.action = act
        ad.action_slot = act.slots[0]
        start, end = (int(x) for x in act.frame_range)
        step = 1 if name in STRIKES else 2
        worst_joint = {k: [999.0, -999.0] for k in LIMBS}
        feet = [9.0, -9.0]
        clips = {}
        for f in sorted(set(list(range(start, end + 1, step)) + [end])):
            scene.frame_set(f)
            for k, v in flex_angles(arm).items():
                worst_joint[k][0] = min(worst_joint[k][0], v)
                worst_joint[k][1] = max(worst_joint[k][1], v)
            parts = scene_parts(bpy.context.evaluated_depsgraph_get())
            sole = min((c.z for p in parts if p["obj"] == "Vesper_Body" and p["bone"].startswith(("Foot_", "Toe_")) for c in p["co"]), default=0.0)
            feet = [min(feet[0], sole), max(feet[1], sole)]
            for i, a in enumerate(parts):
                for j in range(i + 1, len(parts)):
                    b = parts[j]
                    if same_slot_alternates(a, b) or (a["obj"] == b["obj"] and a["bone"] == b["bone"]) or allowed(a, b):
                        continue
                    if not is_held(a) and not is_held(b) and a["bone"] == b["bone"]:
                        continue
                    d = overlap_depth(a, b) - baseline.get((i, j), 0.0)
                    if d > CLIP_TOLERANCE:
                        k = pair_key(a, b)
                        if d > clips.get(k, (0, 0))[0]:
                            clips[k] = (round(d, 3), f)
            for p in parts:
                p["bm"].free()
        report["joints"][name] = {k: [round(v[0], 1), round(v[1], 1)] for k, v in worst_joint.items()}
        report["clipping"][name] = sorted(([*k, *v] for k, v in clips.items()), key=lambda r: -r[2])
        report["feet_z"][name] = [round(feet[0], 3), round(feet[1], 3)]
    for c in muted:
        c.mute = False
    for t in ad.nla_tracks:
        t.mute = False
    return report


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[argv.index("--json") + 1] if "--json" in argv else None
    only = argv[argv.index("--actions") + 1].split(",") if "--actions" in argv else None
    result = run(actions=only)
    if out:
        open(out, "w").write(json.dumps(result, indent=1, ensure_ascii=False))
    print("@@JSON@@" + json.dumps(result))
