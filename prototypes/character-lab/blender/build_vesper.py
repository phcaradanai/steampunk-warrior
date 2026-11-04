"""
Autonomous Blender 5.2.3 LTS 3D Artist, Advanced Rigging & Natural Motion Pipeline
Project: Steampunk Warrior (Vesper Character Lab — SD Super-Deformed Steampunk Style)
SD Proportion & Modeling Study Reference: https://sketchfab.com/3d-models/sd-gundam-53ff87c9b83b4830be195d9ce44c09a1
Role: Autonomous Senior 3D Technical Artist, Character Rigger, Animator, Cinematic Director & Pipeline Engineer

Pipeline Coverage:
  Concept -> Modeling -> Joint Topology -> UV -> Materials -> Advanced Rigging (29 Bones + Custom Widgets + Joint Limits)
  -> Multi-Bone Skinning -> 12 Natural Character Actions + 2 Automaton Actions -> Motion Polish
  -> Studio & Cinematic DoF Lighting -> Multi-Angle & Filmstrip Playblast Rendering -> Automated QA -> GLB/Blend Export
"""

import bpy
import bmesh
import math
import os
import json
import socket
import time
from mathutils import Vector, Matrix, Euler

OUT_DIR = "/Users/Projects/Steampunk-warrior/prototypes/character-lab"
RENDER_DIR = os.path.join(OUT_DIR, "blender", "renders")
os.makedirs(RENDER_DIR, exist_ok=True)


# ==============================================================================
# 1. SKILL & ENVIRONMENT DISCOVERY + SCENE CONFIGURATION
# ==============================================================================
def probe_environment():
    s = socket.socket()
    s.settimeout(0.25)
    mcp_connected = (s.connect_ex(("127.0.0.1", 9876)) == 0)
    s.close()
    enabled_addons = list(bpy.context.preferences.addons.keys())
    return {
        "blender_version": bpy.app.version_string,
        "blender_build_hash": bpy.app.build_hash.decode("utf-8", errors="ignore"),
        "mcp_port_9876_active": mcp_connected,
        "execution_mode": "Blender Python API (bpy) Autonomous Headless Pipeline",
        "enabled_addons": enabled_addons,
    }


def reset_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block_list in (
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.armatures,
        bpy.data.actions,
        bpy.data.cameras,
        bpy.data.lights,
        bpy.data.collections,
    ):
        for block in list(block_list):
            block_list.remove(block)

    scene = bpy.context.scene
    scene.render.fps = 24
    scene.frame_start = 1
    scene.frame_end = 48
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 18
    scene.cycles.use_denoising = False
    scene.render.use_freestyle = True
    scene.render.line_thickness = 1.45
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'Medium High Contrast'

    if scene.world is None:
        scene.world = bpy.data.worlds.new("StudioWorld")
    bg = scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.11, 0.16, 0.19, 1.0)
        bg.inputs[1].default_value = 0.92


# ==============================================================================
# 2. STEAMPUNK PBR / STYLIZED MATERIALS
# ==============================================================================
MAT_CACHE = {}


def make_mat(name, hex_col, metallic=0.0, roughness=0.50, emission_hex=None, emission_strength=0.0):
    if name in MAT_CACHE:
        return MAT_CACHE[name]
    mat = bpy.data.materials.new(name=name)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    h = hex_col.lstrip('#')
    r, g, b = tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    r, g, b = pow(r, 2.2), pow(g, 2.2), pow(b, 2.2)
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if emission_hex and "Emission Color" in bsdf.inputs:
            eh = emission_hex.lstrip('#')
            er, eg, eb = tuple(pow(int(eh[i:i + 2], 16) / 255.0, 2.2) for i in (0, 2, 4))
            bsdf.inputs["Emission Color"].default_value = (er, eg, eb, 1.0)
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    mat.diffuse_color = (r, g, b, 1.0)
    MAT_CACHE[name] = mat
    return mat


def init_materials():
    make_mat("Mat_Skin", "f0c49e", 0.0, 0.58)
    make_mat("Mat_SkinShade", "d8a47e", 0.0, 0.62)
    make_mat("Mat_Hair", "4c301e", 0.05, 0.68)
    make_mat("Mat_EyeWhite", "fcf9f2", 0.0, 0.22)
    make_mat("Mat_EyeIris", "2b6e82", 0.10, 0.25)
    make_mat("Mat_DarkIron", "1e282e", 0.50, 0.42)
    make_mat("Mat_Brass", "dba64e", 0.80, 0.26)
    make_mat("Mat_Copper", "bc6d42", 0.74, 0.32)
    make_mat("Mat_Steel", "b0c6d2", 0.78, 0.26)
    make_mat("Mat_SteelDark", "526874", 0.65, 0.36)
    make_mat("Mat_LeatherTunic", "8f5a3c", 0.06, 0.60)
    make_mat("Mat_LeatherDark", "3e2920", 0.08, 0.64)
    make_mat("Mat_NavyCoat", "2a4b68", 0.12, 0.52)
    make_mat("Mat_Cream", "f0e4cc", 0.0, 0.52)
    make_mat("Mat_CyanGlow", "66e6f2", 0.10, 0.16, emission_hex="52dce8", emission_strength=2.3)
    make_mat("Mat_AmberGlow", "ffae38", 0.10, 0.18, emission_hex="ff9e22", emission_strength=2.1)
    make_mat("Mat_Wood", "684c38", 0.0, 0.72)


# ==============================================================================
# 3. PROCEDURAL SD HARD-SURFACE + MULTI-BONE JOINT TOPOLOGY BUILDER
# ==============================================================================
class MeshPartBuilder:
    """Builds clean, beveled, multi-material, UV-unwrapped, multi-bone weighted SD meshes."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.materials = []
        self.mat_map = {}
        self.vert_bone_weights = []

    def _mat_idx(self, mat_name):
        mat = MAT_CACHE[mat_name]
        if mat_name not in self.mat_map:
            self.mat_map[mat_name] = len(self.materials)
            self.materials.append(mat)
        return self.mat_map[mat_name]

    def _append_bm(self, temp_bm, mat_name, bone_weights_fn, bevel_width=0.008, bevel_segments=1, smooth_shading=False):
        bmesh.ops.remove_doubles(temp_bm, verts=list(temp_bm.verts), dist=0.0001)
        if bevel_width > 0.0 and len(temp_bm.edges) > 0:
            bmesh.ops.bevel(
                temp_bm,
                geom=list(temp_bm.edges),
                offset=bevel_width,
                offset_type='OFFSET',
                segments=bevel_segments,
                profile=0.5,
                affect='EDGES',
                clamp_overlap=True,
            )
        bmesh.ops.remove_doubles(temp_bm, verts=list(temp_bm.verts), dist=0.0001)
        bmesh.ops.recalc_face_normals(temp_bm, faces=list(temp_bm.faces))
        m_idx = self._mat_idx(mat_name)

        vert_map = {}
        for v in temp_bm.verts:
            nv = self.bm.verts.new(v.co)
            vert_map[v] = nv
            if callable(bone_weights_fn):
                self.vert_bone_weights.append(bone_weights_fn(v.co))
            elif isinstance(bone_weights_fn, dict):
                self.vert_bone_weights.append(dict(bone_weights_fn))
            else:
                self.vert_bone_weights.append({str(bone_weights_fn): 1.0})

        for f in temp_bm.faces:
            try:
                nf = self.bm.faces.new([vert_map[v] for v in f.verts])
                nf.material_index = m_idx
                nf.smooth = smooth_shading
            except ValueError:
                pass
        temp_bm.free()

    def add_box(
        self,
        size,
        center=(0, 0, 0),
        rot_deg=(0, 0, 0),
        mat="Mat_Steel",
        bone="Torso",
        bevel=0.009,
        taper_top_x=1.0,
        taper_top_y=1.0,
        shear_x=0.0,
    ):
        tbm = bmesh.new()
        bmesh.ops.create_cube(tbm, size=1.0)
        for v in tbm.verts:
            v.co.x *= size[0]
            v.co.y *= size[1]
            v.co.z *= size[2]
            if v.co.z > 0:
                v.co.x *= taper_top_x
                v.co.y *= taper_top_y
                v.co.x += shear_x
        rot_m = Euler([math.radians(a) for a in rot_deg], 'XYZ').to_matrix().to_4x4()
        bmesh.ops.transform(tbm, matrix=Matrix.Translation(center) @ rot_m, verts=list(tbm.verts))
        self._append_bm(tbm, mat, bone, bevel_width=bevel, bevel_segments=2 if bevel >= 0.015 else 1)

    def add_cylinder(
        self,
        radius,
        depth,
        center=(0, 0, 0),
        rot_deg=(0, 0, 0),
        mat="Mat_Brass",
        bone="Torso",
        segments=16,
        bevel=0.005,
        r_top=None,
    ):
        tbm = bmesh.new()
        r2 = radius if r_top is None else r_top
        bmesh.ops.create_cone(
            tbm,
            cap_ends=True,
            cap_tris=False,
            segments=segments,
            radius1=radius,
            radius2=r2,
            depth=depth,
        )
        rot_m = Euler([math.radians(a) for a in rot_deg], 'XYZ').to_matrix().to_4x4()
        bmesh.ops.transform(tbm, matrix=Matrix.Translation(center) @ rot_m, verts=list(tbm.verts))
        self._append_bm(tbm, mat, bone, bevel_width=bevel, bevel_segments=1, smooth_shading=True)

    def add_sphere(self, radius, scale=(1, 1, 1), center=(0, 0, 0), rot_deg=(0, 0, 0), mat="Mat_Skin", bone="Head"):
        tbm = bmesh.new()
        bmesh.ops.create_uvsphere(tbm, u_segments=16, v_segments=12, radius=radius)
        for v in tbm.verts:
            v.co.x *= scale[0]
            v.co.y *= scale[1]
            v.co.z *= scale[2]
        rot_m = Euler([math.radians(a) for a in rot_deg], 'XYZ').to_matrix().to_4x4()
        bmesh.ops.transform(tbm, matrix=Matrix.Translation(center) @ rot_m, verts=list(tbm.verts))
        self._append_bm(tbm, mat, bone, bevel_width=0.0, smooth_shading=True)

    def add_joint_sleeve(
        self,
        radius_bottom,
        radius_top,
        z_bottom,
        z_top,
        xy_center=(0.0, 0.0),
        bone_bottom="Hip",
        bone_top="Torso",
        mat="Mat_LeatherDark",
        rings=5,
        segments=16,
    ):
        """Creates a multi-ring deforming joint sleeve with smooth Hermite weight blending across two bones."""
        tbm = bmesh.new()
        ring_verts = []
        for r_i in range(rings):
            t = r_i / float(rings - 1)
            z = z_bottom + (z_top - z_bottom) * t
            rad = radius_bottom + (radius_top - radius_bottom) * t
            # Slight accordion bellows bulge on middle rings for natural joint compression
            bulge = 1.0 + 0.05 * math.sin(t * math.pi)
            row = []
            for s_i in range(segments):
                ang = s_i * math.tau / float(segments)
                vx = xy_center[0] + math.cos(ang) * rad * bulge
                vy = xy_center[1] + math.sin(ang) * rad * bulge
                row.append(tbm.verts.new((vx, vy, z)))
            ring_verts.append(row)

        for r_i in range(rings - 1):
            for s_i in range(segments):
                s_next = (s_i + 1) % segments
                tbm.faces.new((
                    ring_verts[r_i][s_i],
                    ring_verts[r_i][s_next],
                    ring_verts[r_i + 1][s_next],
                    ring_verts[r_i + 1][s_i],
                ))
        # Cap ends so the joint sleeve is 100% manifold watertight
        tbm.faces.new(reversed(ring_verts[0]))
        tbm.faces.new(ring_verts[-1])

        def weight_blend(co):
            raw_t = max(0.0, min(1.0, (co.z - z_bottom) / max(1e-5, z_top - z_bottom)))
            smooth_t = raw_t * raw_t * (3.0 - 2.0 * raw_t)
            if smooth_t <= 0.02:
                return {bone_bottom: 1.0}
            if smooth_t >= 0.98:
                return {bone_top: 1.0}
            return {bone_bottom: round(1.0 - smooth_t, 4), bone_top: round(smooth_t, 4)}

        self._append_bm(tbm, mat, weight_blend, bevel_width=0.0, smooth_shading=True)

    def build_object(self, armature_obj, collection):
        me = bpy.data.meshes.new(self.name + "_Mesh")
        bmesh.ops.recalc_face_normals(self.bm, faces=list(self.bm.faces))
        self.bm.to_mesh(me)
        self.bm.free()
        assert len(me.vertices) == len(self.vert_bone_weights), f"Vertex weight count mismatch on {self.name}"

        for mat in self.materials:
            me.materials.append(mat)

        obj = bpy.data.objects.new(self.name, me)
        collection.objects.link(obj)
        obj.parent = armature_obj

        vgroups = {}
        for v_idx, bw in enumerate(self.vert_bone_weights):
            for bname, w in bw.items():
                if w <= 0.0:
                    continue
                if bname not in vgroups:
                    vgroups[bname] = obj.vertex_groups.new(name=bname)
                vgroups[bname].add([v_idx], w, 'REPLACE')

        mod = obj.modifiers.new(name="Armature", type='ARMATURE')
        mod.object = armature_obj
        mod.use_deform_preserve_volume = True

        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        if len(me.uv_layers) == 0:
            me.uv_layers.new(name="UVMap")
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.03)
        bpy.ops.object.mode_set(mode='OBJECT')
        obj.select_set(False)
        return obj


# ==============================================================================
# 4. ADVANCED RIGGING: 29-BONE SD ARMATURE + CUSTOM WIDGETS + JOINT LIMITS
# ==============================================================================
BONE_REST_POS = {
    "Root":        (0.00,  0.00, 0.00),
    "Hip":         (0.00,  0.00, 0.54),
    "Pouch_R":     (0.06, -0.15, 0.54),
    "Pouch_L":     (0.06,  0.15, 0.54),
    "Torso":       (0.00,  0.00, 0.64),
    "SteamValve":  (-0.26, 0.00, 0.83),
    "Neck":        (0.01,  0.00, 0.95),
    "Head":        (0.01,  0.00, 1.00),
    "HairBack":    (-0.12, 0.00, 1.24),
    "Eye_R":       (0.20, -0.090, 1.19),
    "Eye_L":       (0.20,  0.090, 1.19),
    "Eyelid_R":    (0.205,-0.095, 1.236),
    "Eyelid_L":    (0.205, 0.095, 1.236),
    "Brow_R":      (0.205,-0.095, 1.256),
    "Brow_L":      (0.205, 0.095, 1.256),
    "Shoulder_R":  (0.00, -0.24, 0.92),
    "Elbow_R":     (0.00, -0.26, 0.74),
    "Hand_R":      (0.02, -0.26, 0.56),
    "WeaponMount": (0.07, -0.26, 0.55),
    "Shoulder_L":  (0.00,  0.24, 0.92),
    "Elbow_L":     (0.00,  0.26, 0.74),
    "Hand_L":      (0.02,  0.26, 0.56),
    "ShieldMount": (0.04,  0.33, 0.72),
    "Thigh_R":     (0.00, -0.14, 0.52),
    "Knee_R":      (0.00, -0.15, 0.30),
    "Foot_R":      (0.00, -0.15, 0.08),
    "Toe_R":       (0.11, -0.15, 0.03),
    "Thigh_L":     (0.00,  0.14, 0.52),
    "Knee_L":      (0.00,  0.15, 0.30),
    "Foot_L":      (0.00,  0.15, 0.08),
    "Toe_L":       (0.11,  0.15, 0.03),
}

BONE_PARENTS = {
    "Root": None,
    "Hip": "Root",
    "Pouch_R": "Hip",
    "Pouch_L": "Hip",
    "Torso": "Hip",
    "SteamValve": "Torso",
    "Neck": "Torso",
    "Head": "Neck",
    "HairBack": "Head",
    "Eye_R": "Head",
    "Eye_L": "Head",
    "Eyelid_R": "Head",
    "Eyelid_L": "Head",
    "Brow_R": "Head",
    "Brow_L": "Head",
    "Shoulder_R": "Torso",
    "Elbow_R": "Shoulder_R",
    "Hand_R": "Elbow_R",
    "WeaponMount": "Hand_R",
    "Shoulder_L": "Torso",
    "Elbow_L": "Shoulder_L",
    "Hand_L": "Elbow_L",
    "ShieldMount": "Elbow_L",
    "Thigh_R": "Hip",
    "Knee_R": "Thigh_R",
    "Foot_R": "Knee_R",
    "Toe_R": "Foot_R",
    "Thigh_L": "Hip",
    "Knee_L": "Thigh_L",
    "Foot_L": "Knee_L",
    "Toe_L": "Foot_L",
}


def build_control_widgets(widget_col):
    """Creates wireframe custom control shapes for animation-friendly rig manipulation in Blender."""
    widgets = {}
    for wname, radius in (("WGT_Root", 0.35), ("WGT_Hip", 0.24), ("WGT_Torso", 0.26), ("WGT_Head", 0.28), ("WGT_Limb", 0.10)):
        me = bpy.data.meshes.new(wname + "_Mesh")
        bm = bmesh.new()
        bmesh.ops.create_circle(bm, cap_ends=False, radius=radius, segments=16)
        bm.to_mesh(me)
        bm.free()
        wobj = bpy.data.objects.new(wname, me)
        widget_col.objects.link(wobj)
        wobj.hide_render = True
        wobj.hide_viewport = True
        widgets[wname] = wobj
    return widgets


def build_vesper_armature(collection, widgets):
    arm_data = bpy.data.armatures.new("VesperArmature")
    arm_obj = bpy.data.objects.new("VesperRoot", arm_data)
    collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode='EDIT')

    edit_bones = {}
    for bname, pos in BONE_REST_POS.items():
        eb = arm_data.edit_bones.new(bname)
        eb.head = Vector(pos)
        eb.tail = Vector(pos) + Vector((0.0, 0.0, 0.12))
        eb.roll = 0.0
        edit_bones[bname] = eb

    for bname, pname in BONE_PARENTS.items():
        if pname:
            edit_bones[bname].parent = edit_bones[pname]
            edit_bones[bname].use_connect = False

    bpy.ops.object.mode_set(mode='OBJECT')

    # Assign Custom Control Shapes & Joint Limits
    shape_map = {
        "Root": "WGT_Root",
        "Hip": "WGT_Hip",
        "Torso": "WGT_Torso",
        "Head": "WGT_Head",
        "Hand_R": "WGT_Limb",
        "Hand_L": "WGT_Limb",
        "Foot_R": "WGT_Limb",
        "Foot_L": "WGT_Limb",
    }
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = 'XYZ'
        if pb.name in shape_map and shape_map[pb.name] in widgets:
            pb.custom_shape = widgets[shape_map[pb.name]]

    # Anatomical Joint Rotation Limit Constraints (prevent hyperextension)
    for kname in ("Knee_R", "Knee_L"):
        pb = arm_obj.pose.bones[kname]
        con = pb.constraints.new(type='LIMIT_ROTATION')
        con.name = "AnatomicalKneeLimit"
        con.owner_space = 'LOCAL'
        con.use_limit_x = True
        con.min_x, con.max_x = math.radians(-15.0), math.radians(15.0)
        con.use_limit_y = True
        con.min_y, con.max_y = math.radians(-15.0), math.radians(15.0)
        con.use_limit_z = True
        con.min_z, con.max_z = math.radians(-135.0), math.radians(12.0)

    for ename in ("Elbow_R", "Elbow_L"):
        pb = arm_obj.pose.bones[ename]
        con = pb.constraints.new(type='LIMIT_ROTATION')
        con.name = "AnatomicalElbowLimit"
        con.owner_space = 'LOCAL'
        con.use_limit_z = True
        con.min_z, con.max_z = math.radians(-20.0), math.radians(145.0)

    return arm_obj


# ==============================================================================
# 5. SD STEAMPUNK WARRIOR (VESPER) & EQUIPMENT MESHES
# ==============================================================================
def wpos(bone_name, dx=0.0, dy=0.0, dz=0.0):
    bx, by, bz = BONE_REST_POS[bone_name]
    return (bx + dx, by + dy, bz + dz)


def build_vesper_meshes(arm_obj, char_col, equip_col):
    # --------------------------------------------------------------------------
    # 1. Vesper_Body (Multi-Bone Skinned Waist/Neck/Elbow/Knee Sleeves, Expressive
    #    SD Face with Articulated Eyes, Eyelids, Brows & HairBack, Pouches & Boots)
    # --------------------------------------------------------------------------
    body = MeshPartBuilder("Vesper_Body")

    # Smooth Multi-Bone Waist Tunic Sleeve (Hip <-> Torso)
    body.add_joint_sleeve(
        radius_bottom=0.145,
        radius_top=0.150,
        z_bottom=0.52,
        z_top=0.72,
        xy_center=(0.01, 0.0),
        bone_bottom="Hip",
        bone_top="Torso",
        mat="Mat_LeatherDark",
        rings=5,
        segments=16,
    )
    body.add_box((0.26, 0.30, 0.15), wpos("Hip", 0.01, 0, 0.01), mat="Mat_LeatherDark", bone="Hip", bevel=0.014)
    # Center Brass Belt Buckle
    body.add_box((0.06, 0.11, 0.12), wpos("Hip", 0.145, 0, 0.02), mat="Mat_Brass", bone="Hip", bevel=0.008)
    body.add_box((0.065, 0.07, 0.08), wpos("Hip", 0.15, 0, 0.02), mat="Mat_DarkIron", bone="Hip", bevel=0.004)

    # Articulated Secondary-Motion Belt Pouches & Hip Tassets (Pouch_R / Pouch_L)
    for s_tag, side in (("R", -1), ("L", 1)):
        pbone = f"Pouch_{s_tag}"
        body.add_box((0.08, 0.11, 0.13), wpos(pbone, 0.065, side * -0.03, 0.0), rot_deg=(0, -8, 0), mat="Mat_LeatherTunic", bone=pbone, bevel=0.01)
        body.add_box((0.04, 0.055, 0.04), wpos(pbone, 0.10, side * -0.03, 0.01), rot_deg=(0, -8, 0), mat="Mat_Brass", bone=pbone, bevel=0.004)
        body.add_box((0.20, 0.065, 0.14), wpos(pbone, -0.06, side * 0.035, 0.0), rot_deg=(8 * side, 0, 0), mat="Mat_LeatherDark", bone=pbone, bevel=0.01)

    # Compact, Broad SD Torso Core & Multi-Bone Skinned Neck Sleeve (Torso <-> Neck <-> Head)
    body.add_box((0.26, 0.35, 0.32), wpos("Torso", 0.01, 0, 0.17), mat="Mat_LeatherTunic", bone="Torso", bevel=0.016, taper_top_x=1.08, taper_top_y=1.06)
    body.add_joint_sleeve(
        radius_bottom=0.086,
        radius_top=0.082,
        z_bottom=0.92,
        z_top=1.06,
        xy_center=(0.01, 0.0),
        bone_bottom="Torso",
        bone_top="Head",
        mat="Mat_Skin",
        rings=4,
        segments=14,
    )

    # GIANT EXPRESSIVE SD HUMAN HEAD (0.40m wide x 0.38m tall Chibi Steampunk Head)
    body.add_box((0.37, 0.40, 0.36), wpos("Head", 0.02, 0, 0.21), mat="Mat_Skin", bone="Head", bevel=0.055, taper_top_x=0.95, taper_top_y=0.94)
    # Sculpted Nose, Chin & Confident Mouth
    body.add_box((0.065, 0.058, 0.065), wpos("Head", 0.21, 0, 0.16), mat="Mat_SkinShade", bone="Head", bevel=0.014)
    body.add_box((0.035, 0.11, 0.020), wpos("Head", 0.202, 0, 0.095), mat="Mat_DarkIron", bone="Head", bevel=0.004)

    # Large Expressive SD Eyes (Rigged Iris/Pupil on Eye_R/L, Blinking Upper Eyelids on Eyelid_R/L, Brows on Brow_R/L)
    for s_tag, side in (("R", -1), ("L", 1)):
        ebone = f"Eye_{s_tag}"
        lbone = f"Eyelid_{s_tag}"
        bbone = f"Brow_{s_tag}"
        # Sclera stays on Head
        body.add_box((0.04, 0.105, 0.082), wpos("Head", 0.195, side * 0.095, 0.19), rot_deg=(-4 * side, 0, 0), mat="Mat_EyeWhite", bone="Head", bevel=0.01)
        # Mobile Iris, Pupil & Catchlight on Eye_R / Eye_L
        body.add_box((0.045, 0.062, 0.068), wpos(ebone, 0.012, 0.0, 0.0), rot_deg=(-4 * side, 0, 0), mat="Mat_EyeIris", bone=ebone, bevel=0.008)
        body.add_box((0.050, 0.034, 0.042), wpos(ebone, 0.016, 0.0, 0.0), rot_deg=(-4 * side, 0, 0), mat="Mat_DarkIron", bone=ebone, bevel=0.005)
        body.add_box((0.052, 0.018, 0.018), wpos(ebone, 0.020, side * 0.012, 0.018), mat="Mat_EyeWhite", bone=ebone, bevel=0.003)
        # Blinking Upper Eyelid & Lash Plate on Eyelid_R / Eyelid_L
        body.add_box((0.052, 0.110, 0.040), wpos(lbone, 0.005, 0.0, 0.008), rot_deg=(-4 * side, 0, 0), mat="Mat_SkinShade", bone=lbone, bevel=0.004)
        body.add_box((0.054, 0.112, 0.010), wpos(lbone, 0.007, 0.0, -0.012), rot_deg=(-4 * side, 0, 0), mat="Mat_DarkIron", bone=lbone, bevel=0.002)
        # Expressive Articulated Eyebrow on Brow_R / Brow_L
        body.add_box((0.048, 0.118, 0.026), wpos(bbone, 0.010, 0.0, 0.0), rot_deg=(-8 * side, 0, 0), mat="Mat_Hair", bone=bbone, bevel=0.005)
        # Chibi Ears
        body.add_box((0.065, 0.05, 0.10), wpos("Head", 0.01, side * 0.21, 0.18), mat="Mat_SkinShade", bone="Head", bevel=0.014)

    # Chunky Layered SD Hair (Crown & Bangs on Head; Secondary Follow-Through Locks on HairBack)
    body.add_box((0.41, 0.43, 0.12), wpos("Head", 0.01, 0, 0.37), mat="Mat_Hair", bone="Head", bevel=0.025, taper_top_x=0.90, taper_top_y=0.90)
    body.add_box((0.14, 0.43, 0.20), wpos("Head", -0.11, 0, 0.28), mat="Mat_Hair", bone="Head", bevel=0.022)
    # Articulated Rear Hair Tail / Locks on HairBack bone for overlapping follow-through
    body.add_box((0.16, 0.41, 0.20), wpos("HairBack", -0.01, 0, -0.08), rot_deg=(0, 8, 0), mat="Mat_Hair", bone="HairBack", bevel=0.022, taper_top_y=0.92)
    body.add_box((0.12, 0.26, 0.12), wpos("HairBack", -0.04, 0, -0.17), rot_deg=(0, 14, 0), mat="Mat_Hair", bone="HairBack", bevel=0.016)
    # Layered Spiky Front Bangs
    body.add_box((0.12, 0.14, 0.08), wpos("Head", 0.18, -0.08, 0.35), rot_deg=(12, 16, 0), mat="Mat_Hair", bone="Head", bevel=0.012)
    body.add_box((0.12, 0.15, 0.09), wpos("Head", 0.19, 0.05, 0.35), rot_deg=(-10, 18, 0), mat="Mat_Hair", bone="Head", bevel=0.012)
    for side in (-1, 1):
        body.add_box((0.14, 0.06, 0.22), wpos("Head", 0.09, side * 0.195, 0.24), mat="Mat_Hair", bone="Head", bevel=0.014)

    # Multi-Bone Elbow Sleeves, Chunky SD Elbow Drums, Flared Forearm Gauntlets & Gloved Fists
    for s_tag, side in (("R", -1), ("L", 1)):
        body.add_joint_sleeve(
            radius_bottom=0.054,
            radius_top=0.056,
            z_bottom=0.69,
            z_top=0.79,
            xy_center=(0.0, side * 0.25),
            bone_bottom=f"Elbow_{s_tag}",
            bone_top=f"Shoulder_{s_tag}",
            mat="Mat_LeatherDark",
            rings=4,
            segments=12,
        )
        body.add_cylinder(0.056, 0.12, wpos(f"Elbow_{s_tag}", 0, 0, 0.01), rot_deg=(90, 0, 0), mat="Mat_Brass", bone=f"Elbow_{s_tag}")
        body.add_box((0.14, 0.14, 0.17), wpos(f"Elbow_{s_tag}", 0.01, 0, -0.09), mat="Mat_Steel", bone=f"Elbow_{s_tag}", bevel=0.014, taper_top_x=0.82, taper_top_y=0.82)
        body.add_box((0.15, 0.15, 0.036), wpos(f"Elbow_{s_tag}", 0.01, 0, -0.03), mat="Mat_Brass", bone=f"Elbow_{s_tag}", bevel=0.006)
        body.add_box((0.155, 0.155, 0.038), wpos(f"Elbow_{s_tag}", 0.01, 0, -0.16), mat="Mat_Brass", bone=f"Elbow_{s_tag}", bevel=0.006)
        # Chunky Leather-Gloved Fist with Brass Knuckle Plate (Hand_R / Hand_L)
        body.add_box((0.115, 0.11, 0.105), wpos(f"Hand_{s_tag}", 0.015, 0, -0.02), mat="Mat_LeatherDark", bone=f"Hand_{s_tag}", bevel=0.014)
        body.add_box((0.12, 0.115, 0.035), wpos(f"Hand_{s_tag}", 0.02, 0, 0.01), mat="Mat_Brass", bone=f"Hand_{s_tag}", bevel=0.006)

    # Multi-Bone Knee Sleeves, SD Knee Drums, Flared Greaves, Ankle Caps & Two-Part Articulated Sabaton Boots (Foot + Toe)
    for s_tag, side in (("R", -1), ("L", 1)):
        body.add_joint_sleeve(
            radius_bottom=0.064,
            radius_top=0.068,
            z_bottom=0.25,
            z_top=0.36,
            xy_center=(0.0, side * 0.145),
            bone_bottom=f"Knee_{s_tag}",
            bone_top=f"Thigh_{s_tag}",
            mat="Mat_LeatherDark",
            rings=4,
            segments=12,
        )
        body.add_cylinder(0.066, 0.16, wpos(f"Knee_{s_tag}", 0, 0, 0.0), rot_deg=(90, 0, 0), mat="Mat_Brass", bone=f"Knee_{s_tag}")
        body.add_box((0.095, 0.13, 0.11), wpos(f"Knee_{s_tag}", 0.075, 0, -0.015), rot_deg=(0, -8, 0), mat="Mat_Brass", bone=f"Knee_{s_tag}", bevel=0.012)
        body.add_box((0.185, 0.17, 0.19), wpos(f"Knee_{s_tag}", 0.0, 0, -0.11), mat="Mat_SteelDark", bone=f"Knee_{s_tag}", bevel=0.016, taper_top_x=0.80, taper_top_y=0.82)
        body.add_box((0.04, 0.06, 0.17), wpos(f"Knee_{s_tag}", 0.085, 0, -0.11), mat="Mat_Steel", bone=f"Knee_{s_tag}", bevel=0.006)
        # Circular Brass Ankle Gauge Cap (SD ankle drum detail)
        body.add_cylinder(0.054, 0.195, wpos(f"Foot_{s_tag}", 0.0, 0, 0.03), rot_deg=(90, 0, 0), mat="Mat_Brass", bone=f"Foot_{s_tag}")
        body.add_cylinder(0.036, 0.204, wpos(f"Foot_{s_tag}", 0.0, 0, 0.03), rot_deg=(90, 0, 0), mat="Mat_DarkIron", bone=f"Foot_{s_tag}")
        body.add_box((0.15, 0.18, 0.075), wpos(f"Foot_{s_tag}", 0.07, 0, 0.045), rot_deg=(0, 18, 0), mat="Mat_Steel", bone=f"Foot_{s_tag}", bevel=0.012)
        # Rear/Mid Boot Heel & Arch (weighted to Foot_R/L)
        body.add_box((0.20, 0.175, 0.070), wpos(f"Foot_{s_tag}", 0.015, 0, -0.022), mat="Mat_DarkIron", bone=f"Foot_{s_tag}", bevel=0.014, taper_top_x=0.82, taper_top_y=0.88)
        body.add_box((0.22, 0.188, 0.042), wpos(f"Foot_{s_tag}", 0.015, 0, -0.062), mat="Mat_LeatherDark", bone=f"Foot_{s_tag}", bevel=0.008)
        # Articulated Front Brass Toe-Cap & Forefoot Sole (weighted to Toe_R/L for natural toe-off roll!)
        body.add_box((0.13, 0.18, 0.064), wpos(f"Toe_{s_tag}", 0.030, 0, 0.022), mat="Mat_Brass", bone=f"Toe_{s_tag}", bevel=0.012)
        body.add_box((0.14, 0.186, 0.042), wpos(f"Toe_{s_tag}", 0.032, 0, -0.012), mat="Mat_LeatherDark", bone=f"Toe_{s_tag}", bevel=0.008)
    body.build_object(arm_obj, char_col)

    # --------------------------------------------------------------------------
    # 2. Dynamic Suit Limbs & Chunky SD Layered Shoulder Pauldron (Pauldron_R)
    # --------------------------------------------------------------------------
    for s_tag in ("R", "L"):
        u_arm = MeshPartBuilder(f"UpperArm_{s_tag}")
        u_arm.add_sphere(0.068, (1, 1, 1), wpos(f"Shoulder_{s_tag}", 0, 0, 0.0), mat="Mat_DarkIron", bone=f"Shoulder_{s_tag}")
        u_arm.add_box((0.125, 0.125, 0.17), wpos(f"Shoulder_{s_tag}", 0, 0, -0.09), mat="Mat_LeatherTunic", bone=f"Shoulder_{s_tag}", bevel=0.012)
        u_arm.build_object(arm_obj, char_col)

        thigh = MeshPartBuilder(f"ThighMesh_{s_tag}")
        thigh.add_sphere(0.076, (1, 1, 1), wpos(f"Thigh_{s_tag}", 0, 0, 0.0), mat="Mat_DarkIron", bone=f"Thigh_{s_tag}")
        thigh.add_box((0.155, 0.155, 0.21), wpos(f"Thigh_{s_tag}", 0.005, 0, -0.11), mat="Mat_LeatherTunic", bone=f"Thigh_{s_tag}", bevel=0.014)
        thigh.build_object(arm_obj, char_col)

    pauldron = MeshPartBuilder("Pauldron_R")
    pauldron.add_box((0.22, 0.20, 0.15), wpos("Shoulder_R", 0.0, -0.04, 0.03), rot_deg=(-10, 0, 0), mat="Mat_Steel", bone="Shoulder_R", bevel=0.018, taper_top_y=0.82)
    pauldron.add_box((0.23, 0.21, 0.036), wpos("Shoulder_R", 0.0, -0.04, -0.03), rot_deg=(-10, 0, 0), mat="Mat_Brass", bone="Shoulder_R", bevel=0.008)
    pauldron.add_cylinder(0.032, 0.04, wpos("Shoulder_R", 0.09, -0.08, 0.03), rot_deg=(0, 90, 0), mat="Mat_Brass", bone="Shoulder_R")
    pauldron.build_object(arm_obj, char_col)

    # --------------------------------------------------------------------------
    # 3. BoilerPack (SD Twin-Cylinder Steam Boiler + Mechanical Rotating SteamValve)
    # --------------------------------------------------------------------------
    boiler = MeshPartBuilder("BoilerPack")
    boiler.add_box((0.16, 0.34, 0.28), wpos("Torso", -0.17, 0, 0.18), mat="Mat_DarkIron", bone="Torso", bevel=0.014, taper_top_y=0.90)
    for side in (-1, 1):
        boiler.add_cylinder(0.072, 0.26, wpos("Torso", -0.23, side * 0.095, 0.19), mat="Mat_Copper", bone="Torso", bevel=0.006)
        boiler.add_sphere(0.072, (1, 1, 0.65), wpos("Torso", -0.23, side * 0.095, 0.32), mat="Mat_Brass", bone="Torso")
        boiler.add_cylinder(0.076, 0.028, wpos("Torso", -0.23, side * 0.095, 0.26), mat="Mat_Brass", bone="Torso")
        boiler.add_cylinder(0.076, 0.028, wpos("Torso", -0.23, side * 0.095, 0.12), mat="Mat_Brass", bone="Torso")
        boiler.add_cylinder(0.050, 0.07, wpos("Torso", -0.22, side * 0.095, 0.04), rot_deg=(0, 22, 0), mat="Mat_DarkIron", bone="Torso", r_top=0.032)
        boiler.add_cylinder(0.036, 0.02, wpos("Torso", -0.23, side * 0.095, 0.01), rot_deg=(0, 22, 0), mat="Mat_CyanGlow", bone="Torso")
        boiler.add_cylinder(0.030, 0.14, wpos("Torso", -0.20, side * 0.105, 0.38), rot_deg=(-10 * side, -16, 0), mat="Mat_DarkIron", bone="Torso")
        boiler.add_cylinder(0.038, 0.03, wpos("Torso", -0.22, side * 0.115, 0.44), rot_deg=(-10 * side, -16, 0), mat="Mat_Brass", bone="Torso")
    # Center Glowing Steam Furnace Core + Articulated SteamValve Wheel (Ambient Mechanical Motion)
    boiler.add_cylinder(0.062, 0.03, wpos("Torso", -0.25, 0, 0.19), rot_deg=(0, 90, 0), mat="Mat_Brass", bone="Torso")
    boiler.add_cylinder(0.048, 0.035, wpos("Torso", -0.255, 0, 0.19), rot_deg=(0, 90, 0), mat="Mat_CyanGlow", bone="Torso")
    boiler.add_box((0.022, 0.13, 0.022), wpos("SteamValve", -0.01, 0, 0.0), mat="Mat_Brass", bone="SteamValve", bevel=0.003)
    boiler.add_box((0.022, 0.022, 0.13), wpos("SteamValve", -0.01, 0, 0.0), mat="Mat_Brass", bone="SteamValve", bevel=0.003)
    boiler.build_object(arm_obj, char_col)

    # --------------------------------------------------------------------------
    # 4. OVERSIZED HEROIC SD WEAPONS (Weapon_0, Weapon_1, Weapon_2)
    # --------------------------------------------------------------------------
    w0 = MeshPartBuilder("Weapon_0")
    w0.add_sphere(0.046, (1, 1, 1), wpos("WeaponMount", 0, 0, -0.15), mat="Mat_Brass", bone="WeaponMount")
    w0.add_cylinder(0.030, 0.18, wpos("WeaponMount", 0, 0, -0.04), mat="Mat_LeatherDark", bone="WeaponMount")
    w0.add_box((0.12, 0.18, 0.06), wpos("WeaponMount", 0, 0, 0.07), mat="Mat_Brass", bone="WeaponMount", bevel=0.01)
    w0.add_cylinder(0.10, 0.05, wpos("WeaponMount", 0, 0, 0.09), rot_deg=(90, 0, 0), mat="Mat_Brass", bone="WeaponMount", segments=12)
    for i in range(10):
        ang = i * math.tau / 10.0
        w0.add_box(
            (0.034, 0.054, 0.034),
            wpos("WeaponMount", math.cos(ang) * 0.105, 0, 0.09 + math.sin(ang) * 0.105),
            rot_deg=(0, math.degrees(ang), 0),
            mat="Mat_Brass",
            bone="WeaponMount",
            bevel=0.004,
        )
    w0.add_box((0.14, 0.028, 0.70), wpos("WeaponMount", 0, 0, 0.46), mat="Mat_Steel", bone="WeaponMount", bevel=0.007, taper_top_x=0.74)
    w0.add_box((0.102, 0.022, 0.20), wpos("WeaponMount", 0, 0, 0.89), mat="Mat_Steel", bone="WeaponMount", bevel=0.004, taper_top_x=0.06)
    w0.add_box((0.042, 0.034, 0.52), wpos("WeaponMount", 0, 0, 0.40), mat="Mat_DarkIron", bone="WeaponMount", bevel=0.004)
    w0.add_box((0.020, 0.038, 0.46), wpos("WeaponMount", 0, 0, 0.39), mat="Mat_CyanGlow", bone="WeaponMount", bevel=0.002)
    w0.build_object(arm_obj, equip_col)

    w1 = MeshPartBuilder("Weapon_1")
    w1.add_cylinder(0.032, 0.84, wpos("WeaponMount", 0, 0, 0.28), mat="Mat_LeatherDark", bone="WeaponMount")
    w1.add_cylinder(0.045, 0.07, wpos("WeaponMount", 0, 0, -0.14), mat="Mat_Brass", bone="WeaponMount")
    w1.add_cylinder(0.040, 0.12, wpos("WeaponMount", 0, 0, 0.16), mat="Mat_Brass", bone="WeaponMount")
    w1.add_box((0.38, 0.22, 0.25), wpos("WeaponMount", 0.02, 0, 0.72), mat="Mat_DarkIron", bone="WeaponMount", bevel=0.022)
    w1.add_cylinder(0.115, 0.07, wpos("WeaponMount", 0.22, 0, 0.72), rot_deg=(0, 90, 0), mat="Mat_Brass", bone="WeaponMount")
    w1.add_cylinder(0.085, 0.07, wpos("WeaponMount", -0.20, 0, 0.72), rot_deg=(0, -90, 0), mat="Mat_Copper", bone="WeaponMount", r_top=0.045)
    w1.add_cylinder(0.052, 0.02, wpos("WeaponMount", -0.235, 0, 0.72), rot_deg=(0, -90, 0), mat="Mat_AmberGlow", bone="WeaponMount")
    w1.add_cylinder(0.046, 0.26, wpos("WeaponMount", 0.02, -0.12, 0.72), rot_deg=(0, 90, 0), mat="Mat_Copper", bone="WeaponMount")
    w1.add_cylinder(0.046, 0.26, wpos("WeaponMount", 0.02, 0.12, 0.72), rot_deg=(0, 90, 0), mat="Mat_Copper", bone="WeaponMount")
    w1.build_object(arm_obj, equip_col)

    # Weapon_2 = gun family (roster gear 2): grip at the hand, boiler tank under a long barrel, glowing muzzle coil.
    w2 = MeshPartBuilder("Weapon_2")
    w2.add_box((0.07, 0.05, 0.20), wpos("WeaponMount", -0.01, 0, -0.03), rot_deg=(0, 10, 0), mat="Mat_LeatherDark", bone="WeaponMount", bevel=0.010)
    w2.add_box((0.13, 0.075, 0.30), wpos("WeaponMount", 0.02, 0, 0.19), mat="Mat_Brass", bone="WeaponMount", bevel=0.012)
    w2.add_box((0.05, 0.05, 0.10), wpos("WeaponMount", 0.015, 0, 0.065), mat="Mat_DarkIron", bone="WeaponMount", bevel=0.006)
    w2.add_cylinder(0.034, 0.58, wpos("WeaponMount", 0.04, 0, 0.62), mat="Mat_Steel", bone="WeaponMount", segments=12)
    w2.add_cylinder(0.052, 0.07, wpos("WeaponMount", 0.04, 0, 0.90), mat="Mat_Brass", bone="WeaponMount", segments=12)
    w2.add_cylinder(0.044, 0.03, wpos("WeaponMount", 0.04, 0, 0.945), mat="Mat_CyanGlow", bone="WeaponMount", segments=12)
    w2.add_cylinder(0.062, 0.34, wpos("WeaponMount", -0.06, 0, 0.50), mat="Mat_Copper", bone="WeaponMount", segments=12)
    w2.add_cylinder(0.068, 0.04, wpos("WeaponMount", -0.06, 0, 0.35), mat="Mat_Brass", bone="WeaponMount", segments=12)
    w2.add_cylinder(0.068, 0.04, wpos("WeaponMount", -0.06, 0, 0.65), mat="Mat_Brass", bone="WeaponMount", segments=12)
    w2.add_box((0.03, 0.03, 0.05), wpos("WeaponMount", 0.09, 0, 0.82), mat="Mat_DarkIron", bone="WeaponMount", bevel=0.004)
    w2.add_box((0.022, 0.030, 0.44), wpos("WeaponMount", 0.07, 0, 0.58), mat="Mat_CyanGlow", bone="WeaponMount", bevel=0.002)
    w2.build_object(arm_obj, equip_col)

    # Weapon_4 = polearm family (gear 4; 3 stays "none" for NPCs): long shaft, tapered spear head, brass collar and coil.
    w4 = MeshPartBuilder("Weapon_4")
    w4.add_cylinder(0.030, 1.30, wpos("WeaponMount", 0, 0, 0.55), mat="Mat_LeatherDark", bone="WeaponMount")
    w4.add_cylinder(0.044, 0.07, wpos("WeaponMount", 0, 0, -0.10), mat="Mat_Brass", bone="WeaponMount")
    w4.add_cylinder(0.040, 0.10, wpos("WeaponMount", 0, 0, 0.14), mat="Mat_Brass", bone="WeaponMount")
    for i in range(4):
        w4.add_cylinder(0.046, 0.022, wpos("WeaponMount", 0, 0, 0.78 + i * 0.045), mat="Mat_Copper", bone="WeaponMount")
    w4.add_cylinder(0.052, 0.07, wpos("WeaponMount", 0, 0, 1.17), mat="Mat_Brass", bone="WeaponMount")
    w4.add_box((0.15, 0.030, 0.36), wpos("WeaponMount", 0, 0, 1.38), mat="Mat_Steel", bone="WeaponMount", bevel=0.006, taper_top_x=0.06)
    w4.add_box((0.034, 0.036, 0.30), wpos("WeaponMount", 0, 0, 1.36), mat="Mat_CyanGlow", bone="WeaponMount", bevel=0.002)
    for side in (-1, 1):
        w4.add_box((0.05, 0.026, 0.13), wpos("WeaponMount", 0.08 * side, 0, 1.22), rot_deg=(0, -28 * side, 0), mat="Mat_Steel", bone="WeaponMount", bevel=0.004, taper_top_x=0.3)
    w4.build_object(arm_obj, equip_col)

    # Weapon_5 = staff family (gear 5): shaft with a brass cage holding a glowing core, copper coil below.
    w5 = MeshPartBuilder("Weapon_5")
    w5.add_cylinder(0.028, 1.12, wpos("WeaponMount", 0, 0, 0.46), mat="Mat_Wood", bone="WeaponMount")
    w5.add_cylinder(0.042, 0.07, wpos("WeaponMount", 0, 0, -0.10), mat="Mat_Brass", bone="WeaponMount")
    w5.add_cylinder(0.038, 0.10, wpos("WeaponMount", 0, 0, 0.14), mat="Mat_Brass", bone="WeaponMount")
    for i in range(5):
        w5.add_cylinder(0.042, 0.02, wpos("WeaponMount", 0, 0, 0.70 + i * 0.05), mat="Mat_Copper", bone="WeaponMount")
    w5.add_cylinder(0.060, 0.06, wpos("WeaponMount", 0, 0, 1.03), mat="Mat_Brass", bone="WeaponMount")
    w5.add_sphere(0.105, (1, 1, 1), wpos("WeaponMount", 0, 0, 1.18), mat="Mat_CyanGlow", bone="WeaponMount")
    for ang in (0, 90, 180, 270):
        r = math.radians(ang)
        w5.add_box((0.026, 0.026, 0.26), wpos("WeaponMount", math.cos(r) * 0.115, math.sin(r) * 0.115, 1.18), rot_deg=(0, 0, 0), mat="Mat_Brass", bone="WeaponMount", bevel=0.004)
    w5.add_cylinder(0.12, 0.022, wpos("WeaponMount", 0, 0, 1.18), rot_deg=(0, 0, 0), mat="Mat_Brass", bone="WeaponMount", segments=16, r_top=0.12)
    w5.add_sphere(0.036, (1, 1, 1), wpos("WeaponMount", 0, 0, 1.34), mat="Mat_Brass", bone="WeaponMount")
    w5.build_object(arm_obj, equip_col)

    # --------------------------------------------------------------------------
    # 5. SD HEADGEARS (Headgear_0, Headgear_1, Headgear_2)
    # --------------------------------------------------------------------------
    hg0 = MeshPartBuilder("Headgear_0")
    hg0.add_box((0.39, 0.42, 0.065), wpos("Head", 0.02, 0, 0.305), mat="Mat_LeatherDark", bone="Head", bevel=0.010)
    for side in (-1, 1):
        hg0.add_cylinder(0.072, 0.065, wpos("Head", 0.215, side * 0.105, 0.31), rot_deg=(0, 90, 0), mat="Mat_Brass", bone="Head")
        hg0.add_cylinder(0.056, 0.070, wpos("Head", 0.220, side * 0.105, 0.31), rot_deg=(0, 90, 0), mat="Mat_CyanGlow", bone="Head")
        hg0.add_box((0.04, 0.03, 0.05), wpos("Head", 0.19, side * 0.195, 0.31), mat="Mat_Brass", bone="Head", bevel=0.005)
    hg0.add_box((0.04, 0.08, 0.032), wpos("Head", 0.225, 0, 0.31), mat="Mat_Brass", bone="Head", bevel=0.005)
    hg0.build_object(arm_obj, equip_col)

    hg1 = MeshPartBuilder("Headgear_1")
    hg1.add_box((0.43, 0.45, 0.24), wpos("Head", 0.01, 0, 0.32), mat="Mat_SteelDark", bone="Head", bevel=0.045, taper_top_x=0.88, taper_top_y=0.88)
    hg1.add_box((0.45, 0.47, 0.055), wpos("Head", 0.02, 0, 0.255), mat="Mat_Brass", bone="Head", bevel=0.012)
    hg1.add_box((0.38, 0.075, 0.14), wpos("Head", 0.01, 0, 0.44), mat="Mat_Brass", bone="Head", bevel=0.014, taper_top_x=0.82)
    hg1.add_cylinder(0.048, 0.04, wpos("Head", 0.22, 0, 0.33), rot_deg=(0, 90, 0), mat="Mat_Brass", bone="Head")
    hg1.add_cylinder(0.034, 0.045, wpos("Head", 0.225, 0, 0.33), rot_deg=(0, 90, 0), mat="Mat_CyanGlow", bone="Head")
    for side in (-1, 1):
        hg1.add_box((0.20, 0.055, 0.22), wpos("Head", 0.06, side * 0.225, 0.16), rot_deg=(10 * side, 6, 0), mat="Mat_SteelDark", bone="Head", bevel=0.012)
        hg1.add_cylinder(0.028, 0.05, wpos("Head", 0.14, side * 0.23, 0.20), rot_deg=(90, 0, 0), mat="Mat_Brass", bone="Head")
    hg1.build_object(arm_obj, equip_col)

    hg2 = MeshPartBuilder("Headgear_2")
    hg2.add_box((0.18, 0.32, 0.16), wpos("Head", 0.15, 0, 0.11), mat="Mat_DarkIron", bone="Head", bevel=0.020, taper_top_y=0.84)
    hg2.add_box((0.06, 0.12, 0.11), wpos("Head", 0.225, 0, 0.11), mat="Mat_Brass", bone="Head", bevel=0.010)
    for side in (-1, 1):
        hg2.add_cylinder(0.062, 0.095, wpos("Head", 0.21, side * 0.135, 0.09), rot_deg=(28 * side, 68, 0), mat="Mat_Brass", bone="Head")
        hg2.add_cylinder(0.048, 0.10, wpos("Head", 0.215, side * 0.14, 0.09), rot_deg=(28 * side, 68, 0), mat="Mat_Copper", bone="Head")
    hg2.add_box((0.08, 0.36, 0.075), wpos("Head", 0.205, 0, 0.205), mat="Mat_Brass", bone="Head", bevel=0.010)
    hg2.add_box((0.085, 0.32, 0.048), wpos("Head", 0.21, 0, 0.205), mat="Mat_CyanGlow", bone="Head", bevel=0.005)
    hg2.build_object(arm_obj, equip_col)

    # --------------------------------------------------------------------------
    # 6. SD LAYERED SUITS (Suit_0, Suit_1, Suit_2)
    # --------------------------------------------------------------------------
    s0 = MeshPartBuilder("Suit_0")
    s0.add_box((0.28, 0.37, 0.30), wpos("Torso", 0.015, 0, 0.18), mat="Mat_LeatherTunic", bone="Torso", bevel=0.018, taper_top_x=1.08, taper_top_y=1.06)
    s0.add_box((0.30, 0.075, 0.34), wpos("Torso", 0.02, 0, 0.18), rot_deg=(36, 0, 0), mat="Mat_LeatherDark", bone="Torso", bevel=0.008)
    for i in range(3):
        s0.add_cylinder(0.022, 0.055, wpos("Torso", 0.165, -0.06 + i * 0.06, 0.23 - i * 0.05), rot_deg=(0, 90, 0), mat="Mat_Brass", bone="Torso")
    for i in range(3):
        s0.add_cylinder(0.020, 0.025, wpos("Torso", 0.162, 0.085, 0.09 + i * 0.075), rot_deg=(0, 90, 0), mat="Mat_Brass", bone="Torso")
    s0.add_box((0.20, 0.18, 0.13), wpos("Shoulder_L", 0.0, 0.03, 0.02), rot_deg=(10, 0, 0), mat="Mat_LeatherDark", bone="Shoulder_L", bevel=0.016)
    s0.add_box((0.21, 0.19, 0.032), wpos("Shoulder_L", 0.0, 0.03, -0.03), rot_deg=(10, 0, 0), mat="Mat_Brass", bone="Shoulder_L", bevel=0.006)
    s0.build_object(arm_obj, equip_col)

    s1 = MeshPartBuilder("Suit_1")
    s1.add_box((0.31, 0.41, 0.31), wpos("Torso", 0.02, 0, 0.185), mat="Mat_Brass", bone="Torso", bevel=0.024, taper_top_x=1.08, taper_top_y=1.06)
    s1.add_box((0.32, 0.28, 0.22), wpos("Torso", 0.03, 0, 0.19), mat="Mat_Copper", bone="Torso", bevel=0.018)
    s1.add_cylinder(0.072, 0.045, wpos("Torso", 0.185, 0, 0.20), rot_deg=(0, 90, 0), mat="Mat_Brass", bone="Torso")
    s1.add_cylinder(0.054, 0.050, wpos("Torso", 0.190, 0, 0.20), rot_deg=(0, 90, 0), mat="Mat_CyanGlow", bone="Torso")
    s1.add_box((0.23, 0.21, 0.16), wpos("Shoulder_L", 0.0, 0.04, 0.03), rot_deg=(10, 0, 0), mat="Mat_Brass", bone="Shoulder_L", bevel=0.018)
    for s_tag, side in (("R", -1), ("L", 1)):
        s1.add_box((0.22, 0.08, 0.16), wpos(f"Pouch_{s_tag}", -0.05, side * 0.045, 0.0), rot_deg=(12 * side, 0, 0), mat="Mat_Brass", bone=f"Pouch_{s_tag}", bevel=0.012)
    s1.build_object(arm_obj, equip_col)

    s2 = MeshPartBuilder("Suit_2")
    s2.add_box((0.29, 0.39, 0.31), wpos("Torso", 0.015, 0, 0.18), mat="Mat_NavyCoat", bone="Torso", bevel=0.018, taper_top_x=1.06, taper_top_y=1.06)
    s2.add_box((0.16, 0.18, 0.27), wpos("Torso", 0.095, 0, 0.19), mat="Mat_Cream", bone="Torso", bevel=0.010)
    s2.add_box((0.26, 0.32, 0.09), wpos("Torso", -0.01, 0, 0.34), mat="Mat_NavyCoat", bone="Torso", bevel=0.012)
    s2.add_box((0.27, 0.33, 0.028), wpos("Torso", -0.01, 0, 0.38), mat="Mat_Brass", bone="Torso", bevel=0.005)
    for row in range(3):
        for side in (-1, 1):
            s2.add_cylinder(0.018, 0.025, wpos("Torso", 0.165, side * 0.06, 0.10 + row * 0.075), rot_deg=(0, 90, 0), mat="Mat_Brass", bone="Torso")
    for s_tag, side in (("R", -1), ("L", 1)):
        s2.add_box((0.26, 0.19, 0.22), wpos(f"Pouch_{s_tag}", -0.08, side * -0.04, -0.04), rot_deg=(6 * side, 8, 0), mat="Mat_NavyCoat", bone=f"Pouch_{s_tag}", bevel=0.014, taper_top_x=0.84, taper_top_y=0.86)
    s2.add_box((0.21, 0.20, 0.14), wpos("Shoulder_L", 0.0, 0.04, 0.03), rot_deg=(10, 0, 0), mat="Mat_NavyCoat", bone="Shoulder_L", bevel=0.016)
    s2.add_box((0.22, 0.21, 0.032), wpos("Shoulder_L", 0.0, 0.04, -0.03), rot_deg=(10, 0, 0), mat="Mat_Brass", bone="Shoulder_L", bevel=0.006)
    s2.build_object(arm_obj, equip_col)

    # --------------------------------------------------------------------------
    # 7. OVERSIZED SD STEAMPUNK SHIELDS (Shield_1, Shield_2)
    # --------------------------------------------------------------------------
    sh1 = MeshPartBuilder("Shield_1")
    sh1.add_box((0.34, 0.055, 0.58), wpos("ShieldMount", 0.02, 0.06, -0.02), mat="Mat_DarkIron", bone="ShieldMount", bevel=0.016, taper_top_x=0.88)
    sh1.add_box((0.37, 0.065, 0.055), wpos("ShieldMount", 0.02, 0.06, 0.25), mat="Mat_Brass", bone="ShieldMount", bevel=0.008)
    sh1.add_box((0.37, 0.065, 0.055), wpos("ShieldMount", 0.02, 0.06, -0.29), mat="Mat_Brass", bone="ShieldMount", bevel=0.008)
    sh1.add_box((0.055, 0.065, 0.58), wpos("ShieldMount", 0.175, 0.06, -0.02), mat="Mat_Brass", bone="ShieldMount", bevel=0.008)
    sh1.add_box((0.055, 0.065, 0.58), wpos("ShieldMount", -0.135, 0.06, -0.02), mat="Mat_Brass", bone="ShieldMount", bevel=0.008)
    sh1.add_cylinder(0.095, 0.065, wpos("ShieldMount", 0.02, 0.07, -0.02), rot_deg=(90, 0, 0), mat="Mat_Copper", bone="ShieldMount")
    sh1.add_cylinder(0.055, 0.072, wpos("ShieldMount", 0.02, 0.075, -0.02), rot_deg=(90, 0, 0), mat="Mat_CyanGlow", bone="ShieldMount")
    sh1.add_box((0.16, 0.070, 0.036), wpos("ShieldMount", 0.02, 0.068, 0.16), mat="Mat_CyanGlow", bone="ShieldMount", bevel=0.004)
    sh1.build_object(arm_obj, equip_col)

    sh2 = MeshPartBuilder("Shield_2")
    sh2.add_cylinder(0.24, 0.048, wpos("ShieldMount", 0.02, 0.06, -0.02), rot_deg=(90, 0, 0), mat="Mat_Brass", bone="ShieldMount", segments=24)
    sh2.add_cylinder(0.19, 0.056, wpos("ShieldMount", 0.02, 0.066, -0.02), rot_deg=(90, 0, 0), mat="Mat_Copper", bone="ShieldMount", segments=24)
    sh2.add_cylinder(0.11, 0.064, wpos("ShieldMount", 0.02, 0.072, -0.02), rot_deg=(90, 0, 0), mat="Mat_Steel", bone="ShieldMount", segments=10)
    sh2.add_sphere(0.068, (1.0, 0.65, 1.0), wpos("ShieldMount", 0.02, 0.09, -0.02), mat="Mat_CyanGlow", bone="ShieldMount")
    sh2.build_object(arm_obj, equip_col)
    # Shield_3 = tower style: tall full-cover slab with a viewport slit and rivet studs.
    sh3 = MeshPartBuilder("Shield_3")
    sh3.add_box((0.40, 0.06, 0.86), wpos("ShieldMount", 0.02, 0.06, -0.06), mat="Mat_SteelDark", bone="ShieldMount", bevel=0.018, taper_top_x=0.86)
    sh3.add_box((0.43, 0.07, 0.06), wpos("ShieldMount", 0.02, 0.065, 0.37), mat="Mat_Brass", bone="ShieldMount", bevel=0.008)
    sh3.add_box((0.43, 0.07, 0.06), wpos("ShieldMount", 0.02, 0.065, -0.49), mat="Mat_Brass", bone="ShieldMount", bevel=0.008)
    sh3.add_box((0.05, 0.07, 0.86), wpos("ShieldMount", 0.215, 0.065, -0.06), mat="Mat_Brass", bone="ShieldMount", bevel=0.008)
    sh3.add_box((0.05, 0.07, 0.86), wpos("ShieldMount", -0.175, 0.065, -0.06), mat="Mat_Brass", bone="ShieldMount", bevel=0.008)
    sh3.add_box((0.22, 0.075, 0.045), wpos("ShieldMount", 0.02, 0.07, 0.24), mat="Mat_CyanGlow", bone="ShieldMount", bevel=0.004)
    sh3.add_cylinder(0.085, 0.075, wpos("ShieldMount", 0.02, 0.075, -0.18), rot_deg=(90, 0, 0), mat="Mat_Copper", bone="ShieldMount")
    for zz in (0.0, -0.36):
        for xx in (-0.11, 0.15):
            sh3.add_cylinder(0.022, 0.08, wpos("ShieldMount", xx, 0.075, zz), rot_deg=(90, 0, 0), mat="Mat_Brass", bone="ShieldMount", segments=8)
    sh3.build_object(arm_obj, equip_col)


# ==============================================================================
# 6. SD STEAMPUNK AUTOMATON TARGET DUMMY
# ==============================================================================
def build_target_dummy(prop_col):
    arm_data = bpy.data.armatures.new("DummyArmature")
    arm_obj = bpy.data.objects.new("TargetDummyRoot", arm_data)
    prop_col.objects.link(arm_obj)
    arm_obj.location = (2.36, 0.25, 0.0)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode='EDIT')

    b_base = arm_data.edit_bones.new("DummyBaseBone")
    b_base.head = (0, 0, 0.0)
    b_base.tail = (0, 0, 0.2)
    b_base.roll = 0.0

    b_torso = arm_data.edit_bones.new("DummyTorsoBone")
    b_torso.head = (0, 0, 0.12)
    b_torso.tail = (0, 0, 1.1)
    b_torso.roll = 0.0
    b_torso.parent = b_base

    b_arm = arm_data.edit_bones.new("DummyArm")
    b_arm.head = (-0.24, 0, 0.86)
    b_arm.tail = (-0.24, 0, 1.00)
    b_arm.roll = 0.0
    b_arm.parent = b_torso

    bpy.ops.object.mode_set(mode='OBJECT')
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = 'XYZ'

    dm = MeshPartBuilder("Dummy_Mesh")
    dm.add_cylinder(0.36, 0.09, (0, 0, 0.045), mat="Mat_SteelDark", bone="DummyBaseBone", r_top=0.28)
    dm.add_cylinder(0.085, 0.95, (0, 0, 0.52), mat="Mat_LeatherDark", bone="DummyTorsoBone")
    dm.add_box((0.36, 0.38, 0.44), (0, 0, 0.68), mat="Mat_Wood", bone="DummyTorsoBone", bevel=0.025)
    dm.add_box((0.38, 0.40, 0.065), (0, 0, 0.68), mat="Mat_Brass", bone="DummyTorsoBone", bevel=0.008)
    dm.add_sphere(0.24, (1.05, 1.05, 0.95), (0, 0, 1.14), mat="Mat_Steel", bone="DummyTorsoBone")
    dm.add_cylinder(0.245, 0.06, (0, 0, 1.12), mat="Mat_Brass", bone="DummyTorsoBone")
    dm.add_sphere(0.068, (0.6, 1.0, 1.0), (-0.23, 0, 1.14), mat="Mat_CyanGlow", bone="DummyTorsoBone")
    dm.add_box((0.12, 0.12, 0.34), (-0.36, 0, 0.78), rot_deg=(0, 48, 0), mat="Mat_SteelDark", bone="DummyArm", bevel=0.012)
    dm.build_object(arm_obj, prop_col)
    return arm_obj


# ==============================================================================
# 7. NATURAL CHARACTER ANIMATION, CINEMATIC ACTING & MECHANICAL MOTION
# ==============================================================================
def ik_2bone_angles(root_xy, target_xy, seg_len, bend_sign):
    dx = target_xy[0] - root_xy[0]
    dy = target_xy[1] - root_xy[1]
    dist = max(0.01, min(math.hypot(dx, dy), seg_len * 2.0 - 0.01))
    ux, uy = dx / dist, dy / dist
    mid_x = root_xy[0] + ux * dist * 0.5
    mid_y = root_xy[1] + uy * dist * 0.5
    perp_h = math.sqrt(max(0.0, seg_len * seg_len - dist * dist * 0.25))
    jx = mid_x - uy * perp_h * bend_sign
    jy = mid_y + ux * perp_h * bend_sign
    u1x, u1y = jx - root_xy[0], jy - root_xy[1]
    u2x, u2y = target_xy[0] - jx, target_xy[1] - jy
    ang1 = math.atan2(u1x, u1y)
    ang2 = math.atan2(u2x, u2y) - ang1
    return ang1, ang2


# Keyframed poses for the skill-type clips: t -> (hand dx, dy from shoulder anchor, weapon angle, wrist,
# off-hand dx, dy from the far shoulder, torso lean, torso twist, crouch (m), recoil kick, hip lift (m)).
REST_POSE = (22.0, 31.0, 0.72, 0.0, -28.0, 30.0, 0.0, 0.0, 0.0, 0.0, 0.0)
CLIP_KEYS = {
    # Raise, hold the aim, fire at 0.46 (muzzle flips up, torso kicks back), settle, lower.
    "Shoot": [(0.0, REST_POSE), (0.22, (42.0, 4.0, 1.55, -0.12, 22.0, 8.0, 6.0, 0.10, 0.02, 0.0, 0.0)),
              (0.42, (42.0, 4.0, 1.55, -0.12, 22.0, 8.0, 6.0, 0.10, 0.02, 0.0, 0.0)),
              (0.46, (36.0, 0.0, 1.85, -0.20, 18.0, 8.0, 2.0, 0.04, 0.02, 0.6, 0.0)),
              (0.60, (42.0, 5.0, 1.60, -0.12, 22.0, 8.0, 5.0, 0.10, 0.02, 0.1, 0.0)),
              (0.78, (40.0, 6.0, 1.55, -0.10, 22.0, 8.0, 4.0, 0.08, 0.02, 0.0, 0.0)), (1.0, REST_POSE)],
    # Gather at the chest, charge both hands overhead, sweep forward to release at 0.58.
    "Cast": [(0.0, REST_POSE), (0.18, (14.0, 6.0, 0.40, 0.10, 14.0, 6.0, -5.0, -0.08, 0.03, 0.0, 0.0)),
             (0.50, (18.0, -30.0, 0.30, 0.20, 10.0, -28.0, -9.0, -0.18, 0.04, 0.0, 0.0)),
             (0.58, (44.0, 0.0, 1.45, -0.20, 30.0, 2.0, 14.0, 0.30, 0.03, 0.15, 0.0)),
             (0.72, (44.0, 4.0, 1.40, -0.20, 30.0, 6.0, 10.0, 0.25, 0.03, 0.0, 0.0)), (1.0, REST_POSE)],
    # Hunch over, press the injector against the chest at 0.42, then open the arms and stand tall in a glow.
    "Heal": [(0.0, REST_POSE), (0.30, (-9.0, 10.0, 0.10, 0.50, 6.0, 12.0, 8.0, -0.10, 0.03, 0.0, 0.0)),
             (0.46, (-9.0, 10.0, 0.10, 0.50, 6.0, 12.0, 9.0, -0.10, 0.03, 0.0, 0.0)),
             (0.64, (26.0, -16.0, 0.50, 0.0, -22.0, -14.0, -7.0, 0.0, 0.0, 0.0, 0.035)),
             (0.82, (26.0, -14.0, 0.50, 0.0, -22.0, -12.0, -6.0, 0.0, 0.0, 0.0, 0.03)), (1.0, REST_POSE)],
    # Brace in a crouch with fists to the chest, burst upward at 0.5 with arms thrown open.
    "Buff": [(0.0, REST_POSE), (0.36, (8.0, 14.0, 0.30, 0.0, 8.0, 14.0, 10.0, 0.0, 0.07, 0.0, 0.0)),
             (0.50, (30.0, -26.0, 0.35, -0.20, -16.0, -30.0, -12.0, -0.10, 0.0, 0.0, 0.03)),
             (0.74, (30.0, -22.0, 0.35, -0.20, -16.0, -26.0, -9.0, -0.08, 0.0, 0.0, 0.02)), (1.0, REST_POSE)],
}
CLIP_CONTACT = {"Shoot": 0.46, "Cast": 0.58, "Heal": 0.46, "Buff": 0.50}


def clip_pose(mode, t_norm):
    keys = CLIP_KEYS.get(mode)
    if keys is None:
        return None
    for (t0, p0), (t1, p1) in zip(keys, keys[1:]):
        if t0 <= t_norm <= t1:
            k = (t_norm - t0) / max(1e-6, t1 - t0)
            k = k * k * (3.0 - 2.0 * k)
            return [a + (b - a) * k for a, b in zip(p0, p1)]
    return list(keys[-1][1])


def compute_vesper_pose(mode, t_norm, strike=0.0, recoil=0.0, swing=None):
    """
    Implements the 10 Natural Animation Principles:
      1. Weight & Balance / CoG Shift    6. Arcs
      2. Anticipation                    7. Ease In / Ease Out
      3. Follow-through                  8. Timing & Spacing
      4. Overlapping Action              9. Natural Asymmetry
      5. Contact & Foot-Roll Constraints 10. Cinematic Facial Acting & Mechanical Idle
    """
    phase = t_norm * math.tau
    lag_phase = phase - 0.45
    hair_phase = phase - 0.85

    walk = 1.0 if mode in ("Walk", "Enter_Pipe") else 0.0
    run = 1.0 if mode == "Run" else 0.0
    if mode in ("Attack", "Skill_Stab", "Skill_Steam") and (t_norm < 0.25 or t_norm > 0.75):
        walk = 1.0
    loco = max(walk, run)
    cp = clip_pose(mode, t_norm)
    if cp is not None:
        recoil += cp[9]

    # 1. Weight, Balance & Vertical Bounce (Down on contact absorption, Up on passing push-off)
    idle_breath = math.sin(phase) * 0.012 if mode in ("Idle", "Turn_Look") else 0.0
    walk_bounce = (-math.cos(phase * 2.0) * 0.018 - 0.008) * walk
    run_bounce = (-math.cos(phase * 2.0) * 0.034 - 0.012) * run
    jump_z = 0.0
    if mode == "Jump_Land":
        if t_norm < 0.22:
            # Crouch anticipation
            c_t = math.sin((t_norm / 0.22) * math.pi)
            jump_z = -0.095 * c_t
        elif t_norm < 0.64:
            # Ballistic flight arc
            f_t = (t_norm - 0.22) / 0.42
            jump_z = 0.24 * math.sin(f_t * math.pi)
        else:
            # Impact absorption & settle
            l_t = (t_norm - 0.64) / 0.36
            jump_z = -0.105 * math.sin(l_t * math.pi) * (1.0 - l_t * 0.5)

    down_drop = -0.18 * recoil if mode == "Down" else 0.0
    # Net hip drop in metres for the skill clips; the ankles are lowered by the same amount so the feet stay planted.
    hip_drop = (cp[8] - cp[10]) if cp is not None else 0.0
    down_drop -= hip_drop

    # Lateral Center-of-Gravity Shift over supporting stance leg
    cog_shift_y = -math.sin(phase) * (0.022 * walk + 0.032 * run)
    if mode == "Turn_Look":
        cog_shift_y = math.sin(phase) * 0.028

    # Pelvic List (Hip X tilt) & Axial Rotation (Hip Y yaw)
    pelvic_list = math.sin(phase) * (0.065 * walk + 0.095 * run)
    hip_yaw = math.sin(phase) * (0.15 * walk + 0.22 * run)
    if mode == "Enter_Pipe" and t_norm >= 0.35:
        turn_t = min(1.0, (t_norm - 0.35) / 0.45)
        hip_yaw = turn_t * math.radians(114.0)
    elif mode == "Turn_Look":
        hip_yaw = math.sin(phase) * 0.22

    # 2. Spine Pitch, Counter-Torsion & Anticipation Coil
    torso_lean = 3.5 + 3.5 * walk + 9.5 * run
    if mode == "Jump_Land":
        torso_lean += (-12.0 if 0.22 <= t_norm < 0.64 else 8.5 * math.sin(t_norm * math.pi))
    if strike < 0.0:
        torso_lean += strike * 11.5
    elif strike > 0.0:
        torso_lean += strike * 16.5
    torso_lean -= recoil * 12.0
    if cp is not None:
        torso_lean += cp[6]
    if mode == "Guard":
        torso_lean -= 4.5

    torso_pitch = -max(-0.45, min(0.52, torso_lean * 0.020))
    if mode == "Down":
        torso_pitch = -recoil * 0.85

    torso_twist = -math.sin(phase) * (0.14 * walk + 0.22 * run)
    if strike < 0.0:
        torso_twist += strike * 0.44
    elif strike > 0.0:
        torso_twist += strike * 0.36
    elif mode == "Turn_Look":
        torso_twist = math.sin(phase - 0.2) * 0.28
    if cp is not None:
        torso_twist += cp[7]

    rots = {}
    locs = {
        "Root": (0.0, 0.0, 0.0),
        "Hip": (-recoil * 0.05, cog_shift_y, idle_breath + walk_bounce + run_bounce + jump_z + down_drop),
    }
    rots["Root"] = (0.0, 0.0, 0.0)
    rots["Hip"] = (pelvic_list, hip_yaw, 0.0)
    rots["Torso"] = (-pelvic_list * 0.7, torso_twist, torso_pitch)

    # 3. Neck & Head Overlapping Counter-Rotation + Cinematic Acting
    head_yaw_extra = math.sin(phase - 0.35) * 0.38 if mode == "Turn_Look" else 0.0
    head_pitch_extra = math.sin(phase * 2.0 - 0.4) * 0.08 if mode == "Turn_Look" else 0.0
    neck_yaw = -torso_twist * 0.22 + head_yaw_extra * 0.35
    neck_pitch = -torso_pitch * 0.25 + math.sin(lag_phase) * 0.025 * loco
    head_yaw = -torso_twist * 0.28 + head_yaw_extra * 0.65
    head_pitch = -torso_pitch * 0.32 + head_pitch_extra + math.sin(lag_phase - 0.3) * 0.035 * loco
    rots["Neck"] = (0.0, neck_yaw, neck_pitch)
    rots["Head"] = (0.0, head_yaw, head_pitch)

    # 4. Secondary Overlapping Action (HairBack & Belt Pouches) & Mechanical SteamValve
    hair_pitch = (
        math.sin(hair_phase) * 0.04
        + math.sin(hair_phase * 2.0) * (0.09 * walk + 0.16 * run)
        + max(0.0, jump_z) * 0.45
        + strike * 0.18
        - recoil * 0.22
    )
    hair_yaw = -head_yaw * 0.35 + math.cos(hair_phase) * 0.06 * loco
    rots["HairBack"] = (0.0, hair_yaw, hair_pitch)

    # Ambient Mechanical Valve Rotation (seamless oscillation in loops; high-speed spin on Skill_Steam)
    valve_ang = math.sin(phase) * 0.85 + math.sin(phase * 2.0) * 0.35
    if mode in ("Skill_Steam", "Cast", "Buff"):
        valve_ang = t_norm * math.tau * 3.0
    rots["SteamValve"] = (valve_ang, 0.0, 0.0)

    # 5. Cinematic Facial Performance (Eye Tracking, Blinking Eyelids & Expressive Eyebrows)
    blink = 0.0
    if mode == "Idle" and 0.32 <= t_norm <= 0.42:
        blink = math.sin(((t_norm - 0.32) / 0.10) * math.pi)
    elif mode == "Turn_Look" and ((0.20 <= t_norm <= 0.28) or (0.68 <= t_norm <= 0.76)):
        sub_t = (t_norm - 0.20) / 0.08 if t_norm <= 0.28 else (t_norm - 0.68) / 0.08
        blink = math.sin(sub_t * math.pi)
    elif mode == "Hit":
        blink = min(1.0, recoil * 1.1)
    elif mode == "Down":
        blink = min(1.0, recoil)

    eye_y = math.sin(phase - 0.2) * 0.012 if mode == "Turn_Look" else (math.sin(phase) * 0.004 if mode == "Idle" else 0.0)
    eye_z = 0.005 if strike < -0.1 else (-0.004 if mode == "Guard" else 0.0)

    brow_z = 0.0
    brow_tilt = 0.0  # positive = angry/focused inward V-furrow; negative = sad/worried/surprised
    if mode in ("Attack", "Skill_Stab", "Skill_Steam", "Guard", "Run", "Shoot", "Cast", "Buff"):
        brow_tilt = 0.22
        brow_z = -0.006
    elif mode == "Turn_Look":
        brow_tilt = -0.10 * math.sin(phase)
        brow_z = 0.010 * abs(math.sin(phase))
    elif mode in ("Hit", "Down"):
        brow_tilt = -0.24 * recoil
        brow_z = 0.008 * recoil

    for s_tag, side in (("R", -1), ("L", 1)):
        locs[f"Eye_{s_tag}"] = (0.0, eye_y, eye_z)
        rots[f"Eye_{s_tag}"] = (0.0, 0.0, 0.0)
        locs[f"Eyelid_{s_tag}"] = (0.0, 0.0, -0.044 * blink)
        rots[f"Eyelid_{s_tag}"] = (0.0, 0.0, 0.0)
        locs[f"Brow_{s_tag}"] = (0.0, 0.0, brow_z)
        rots[f"Brow_{s_tag}"] = (-side * brow_tilt, 0.0, 0.0)

    # 6. Legs, Contact Constraints & Heel-to-Toe Foot Roll
    hip_2d = (0.0, -53.0)
    for s_tag, side in (("R", 1), ("L", -1)):
        l_phase = phase + (math.pi if side == -1 else 0.0)
        leg_root = (hip_2d[0] + side * 4.5, hip_2d[1])
        # Asymmetric martial arts idle stance
        idle_st = (side * 10.5 + (2.5 if side == 1 else -2.0), 0.0)
        if abs(strike) > 0.1 or swing is not None or cp is not None:
            idle_st = (side * 14.0 + (6.0 if side == 1 else -4.0), 0.0)

        stride_amp = 24.5 if run > 0.5 else 19.5
        lift_amp = 20.0 if run > 0.5 else 13.5
        stride_x = math.cos(l_phase) * stride_amp
        lift_y = -max(0.0, -math.sin(l_phase)) * lift_amp

        fx = stride_x * loco + idle_st[0] * (1.0 - loco)
        fy = lift_y * loco + idle_st[1] * (1.0 - loco)
        if mode == "Jump_Land":
            if 0.22 <= t_norm < 0.64:
                fx = side * 12.0
                fy = -14.0 * math.sin(((t_norm - 0.22) / 0.42) * math.pi)
            else:
                fx = side * 13.5
                fy = 0.0
        elif mode == "Down":
            fx, fy = side * 16.0 - 10.0, 2.0

        ankle = (fx - 1.0, fy - 5.0 - hip_drop * 100.0)
        t_ang, s_ang = ik_2bone_angles(leg_root, ankle, 28.0, -1.0)
        lift_ratio = max(0.0, min(1.0, -fy / max(1.0, lift_amp)))

        # Heel-Strike to Toe-Off Foot Roll Mechanics
        heel_strike = max(0.0, math.cos(l_phase)) * (1.0 - lift_ratio) * 0.22 * loco
        push_off = max(0.0, -math.cos(l_phase)) * (1.0 - lift_ratio) * 0.28 * loco
        f_ang = -(t_ang + s_ang) - lift_ratio * 0.38 - heel_strike + push_off
        toe_ang = -push_off * 1.15 + lift_ratio * 0.18

        rots[f"Thigh_{s_tag}"] = (0.04 * side, 0.0, t_ang)
        rots[f"Knee_{s_tag}"] = (0.0, 0.0, s_ang)
        rots[f"Foot_{s_tag}"] = (-0.04 * side, 0.0, f_ang)
        rots[f"Toe_{s_tag}"] = (0.0, 0.0, toe_ang)

        # Secondary Belt Pouch / Tasset Outward Flare & Overlapping Bounce
        pouch_flare = max(0.0, -t_ang) * 0.35 + (0.12 if mode in ("Attack", "Jump_Land") else 0.0)
        pouch_swing = math.sin(l_phase - 0.55) * 0.14 * loco
        rots[f"Pouch_{s_tag}"] = (-side * pouch_flare, 0.0, pouch_swing)

    # 7. Front Arm, Wrist Follow-Through & Weapon Arc
    sh_2d = (hip_2d[0] + torso_lean, hip_2d[1] - 49.0)
    arm_root = (sh_2d[0] + 13.0, sh_2d[1] + 4.0)
    hand = [arm_root[0] + 22.0, arm_root[1] + 31.0 + math.sin(phase - 0.25) * 1.6]
    w_angle = 0.72
    wrist_Snap = 0.0

    if loco > 0.5:
        sw_amp = 17.5 if run > 0.5 else 12.0
        sw = -math.cos(phase) * sw_amp
        hand = [arm_root[0] + 19.0 + sw, arm_root[1] + (25.0 if run > 0.5 else 30.0) - abs(sw) * 0.22]
        w_angle = 0.66 - math.cos(phase - 0.3) * 0.18
        wrist_Snap = math.sin(phase - 0.4) * 0.12
    elif mode == "Jump_Land":
        hand = [arm_root[0] + 16.0, arm_root[1] + 20.0 - jump_z * 35.0]
        w_angle = 0.55 - jump_z * 0.8
    elif mode == "Turn_Look":
        hand = [arm_root[0] + 20.0 + math.sin(phase) * 4.0, arm_root[1] + 28.0]
        w_angle = 0.62 + math.sin(phase - 0.3) * 0.15

    # Strike pose per move at strength c; wind-up, swing and recovery all blend between fixed poses so the
    # hand never passes through the shoulder and the blade never flips (no elbow snap, no spinning wrist).
    def strike_pose(c):
        if mode == "Skill_Stab":
            return (38.0 * c, 4.0 * c, 1.55, -0.22)
        return (34.0 * c, 22.0 * c, 1.92, -0.32)
    windup_pose = (-6.0, -28.0, -0.95, 0.28)
    rest_pose = (22.0, 31.0, 0.72, 0.0)
    pose = None
    if swing is not None:
        p = swing * swing * (3.0 - 2.0 * swing)
        goal = strike_pose(min(1.2, 1.0 if mode == "Attack" else 1.1))
        pose = [windup_pose[i] + (goal[i] - windup_pose[i]) * p for i in range(4)]
    elif strike < 0.0:
        w = min(1.0, -strike / 0.75)
        pose = [rest_pose[i] + (windup_pose[i] - rest_pose[i]) * w for i in range(4)]
    elif strike > 0.0:
        c = min(1.2, strike)
        goal = strike_pose(c)
        k = min(1.0, c)
        pose = [rest_pose[i] + (goal[i] - rest_pose[i]) * k for i in range(2)] + [rest_pose[i] + (goal[i] - rest_pose[i]) * k for i in range(2, 4)]
        if c > 1.0:
            pose[0], pose[1] = goal[0], goal[1]
    if pose is not None:
        hand = [arm_root[0] + pose[0], arm_root[1] + pose[1]]
        w_angle = pose[2]
        wrist_Snap = pose[3]
    if mode == "Guard":
        hand = [arm_root[0] + 8.0, arm_root[1] + 18.0]
        w_angle = 0.15
    elif mode == "Hit":
        hand = [arm_root[0] - 8.0 * recoil, arm_root[1] + 18.0 - 10.0 * recoil]
        w_angle = -0.35 * recoil
    elif mode == "Down":
        hand = [arm_root[0] + 18.0, arm_root[1] + 22.0]
        w_angle = 1.45

    if cp is not None:
        hand = [arm_root[0] + cp[0], arm_root[1] + cp[1]]
        w_angle = cp[2]
        wrist_Snap = cp[3]
    dx, dy = hand[0] - arm_root[0], hand[1] - arm_root[1]
    dlen = math.hypot(dx, dy)
    if dlen > 47.5:
        hand = [arm_root[0] + dx * 47.5 / dlen, arm_root[1] + dy * 47.5 / dlen]
    u_ang, f_ang = ik_2bone_angles(arm_root, hand, 24.0, 1.0)
    sh_r_ang = u_ang - torso_pitch
    el_r_ang = f_ang
    world_arm_z = torso_pitch + sh_r_ang + el_r_ang + wrist_Snap
    rots["Shoulder_R"] = (0.22, 0.0, sh_r_ang)
    rots["Elbow_R"] = (0.0, 0.0, el_r_ang)
    rots["Hand_R"] = (0.0, 0.0, wrist_Snap)
    rots["WeaponMount"] = (-0.12, 0.0, -w_angle - world_arm_z)

    # 8. Back Arm, Wrist & Shield
    back_root = (sh_2d[0] - 13.0, sh_2d[1] + 2.0)
    b_sw = math.cos(phase) * (12.0 if run > 0.5 else 7.5) * loco
    b_hand = [sh_2d[0] - 28.0 + b_sw, sh_2d[1] + (24.0 if run > 0.5 else 30.0)]
    if mode == "Guard":
        b_hand = [sh_2d[0] + 24.0 - recoil * 5.0, sh_2d[1] + 4.0]
    elif swing is not None:
        q = swing * swing * (3.0 - 2.0 * swing)
        b_hand = [sh_2d[0] + 14.0 - 32.0 * q, sh_2d[1] - 6.0 + 26.0 * q]
    elif strike < 0.0:
        # Blend instead of switching at a threshold, so the guard arm doesn't snap when the wind-up starts.
        w = min(1.0, -strike / 0.75)
        b_hand = [b_hand[0] + (sh_2d[0] + 14.0 - b_hand[0]) * w, b_hand[1] + (sh_2d[1] - 6.0 - b_hand[1]) * w]
    elif strike > 0.0:
        k = min(1.0, strike)
        b_hand = [b_hand[0] + (sh_2d[0] - 18.0 - b_hand[0]) * k, b_hand[1] + (sh_2d[1] + 20.0 - b_hand[1]) * k]
    elif mode == "Hit":
        b_hand = [sh_2d[0] - 22.0, sh_2d[1] + 12.0]
    if cp is not None:
        b_hand = [sh_2d[0] + cp[4], sh_2d[1] + cp[5]]
    bu_ang, bf_ang = ik_2bone_angles(back_root, b_hand, 24.0, 1.0)
    sh_l_ang = bu_ang - torso_pitch
    el_l_ang = bf_ang
    rots["Shoulder_L"] = (0.38 if mode == "Guard" else -0.20, 0.0, sh_l_ang)
    rots["Elbow_L"] = (0.0, 0.0, el_l_ang)
    rots["Hand_L"] = (0.0, 0.0, -wrist_Snap * 0.5)
    if mode == "Guard":
        locs["ShieldMount"] = (0.16, -0.06, 0.24)
        rots["ShieldMount"] = (0.0, 0.45, -sh_l_ang - el_l_ang)
    else:
        locs["ShieldMount"] = (0.0, 0.0, 0.0)
        rots["ShieldMount"] = (0.0, -0.25, 0.35)

    return locs, rots


def apply_pose_to_armature(arm_obj, locs, rots, frame=None):
    for bname, pb in arm_obj.pose.bones.items():
        pb.location = locs.get(bname, (0.0, 0.0, 0.0))
        pb.rotation_euler = rots.get(bname, (0.0, 0.0, 0.0))
        if frame is not None:
            pb.keyframe_insert(data_path="location", frame=frame)
            pb.keyframe_insert(data_path="rotation_euler", frame=frame)


def smooth_action_fcurves(act):
    for layer in act.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for kp in fc.keyframe_points:
                        kp.interpolation = 'BEZIER'
                        kp.handle_left_type = 'AUTO_CLAMPED'
                        kp.handle_right_type = 'AUTO_CLAMPED'
                    fc.update()


def build_vesper_actions(arm_obj, dummy_obj):
    arm_obj.animation_data_create()

    action_specs = [
        ("Idle", 48, True),
        ("Walk", 32, True),
        ("Run", 20, True),
        ("Jump_Land", 28, False),
        ("Turn_Look", 40, True),
        ("Attack", 40, False),
        ("Skill_Stab", 36, False),
        ("Skill_Steam", 36, False),
        ("Shoot", 28, False),
        ("Cast", 40, False),
        ("Heal", 36, False),
        ("Buff", 32, False),
        ("Guard", 28, False),
        ("Hit", 24, False),
        ("Down", 32, False),
        ("Enter_Pipe", 48, False),
    ]

    for act_name, end_f, is_cyclic in action_specs:
        act = bpy.data.actions.new(name=act_name)
        act.use_fake_user = True
        arm_obj.animation_data.action = act

        # Strikes sweep fast; key every frame so no joint turns far enough between keys to take the short way round.
        step = 1 if act_name in ("Attack", "Skill_Stab", "Skill_Steam", "Shoot", "Cast") else 2
        frames = list(range(1, end_f + 1, step))
        if end_f not in frames:
            frames.append(end_f)

        start_locs, start_rots = None, None
        for f in frames:
            t_norm = (f - 1) / float(end_f - 1)
            if is_cyclic and f == end_f and start_locs is not None:
                apply_pose_to_armature(arm_obj, start_locs, start_rots, frame=f)
                continue

            strike = 0.0
            recoil = 0.0
            swing = None
            if act_name in ("Attack", "Skill_Stab", "Skill_Steam"):
                if 0.20 <= t_norm < 0.25:
                    # Subtle anticipation coil before windup
                    strike = -0.18 * ((t_norm - 0.20) / 0.05)
                elif 0.25 <= t_norm < 0.45:
                    strike = -0.18 - 0.57 * ((t_norm - 0.25) / 0.20)
                elif 0.45 <= t_norm < 0.65:
                    w_t = (t_norm - 0.45) / 0.20
                    strike = -0.75 + (1.85 if act_name != "Attack" else 1.75) * min(1.0, w_t * 1.55)
                    swing = min(1.0, w_t * 1.55)
                elif t_norm >= 0.65:
                    strike = max(0.0, 1.0 - (t_norm - 0.65) / 0.25)
            elif act_name == "Guard":
                if 0.15 <= t_norm <= 0.75:
                    recoil = 0.55 * math.sin((t_norm - 0.15) / 0.60 * math.pi)
            elif act_name == "Hit":
                if t_norm < 0.35:
                    recoil = t_norm / 0.35
                else:
                    recoil = max(0.0, 1.0 - (t_norm - 0.35) / 0.65)
            elif act_name == "Down":
                recoil = min(1.0, t_norm / 0.55)

            locs, rots = compute_vesper_pose(act_name, t_norm, strike=strike, recoil=recoil, swing=swing)
            if f == 1:
                start_locs, start_rots = locs, rots
            apply_pose_to_armature(arm_obj, locs, rots, frame=f)

        smooth_action_fcurves(act)
        track = arm_obj.animation_data.nla_tracks.new()
        track.name = act_name
        strip = track.strips.new(act_name, 1, act)
        strip.action_slot = act.slots[0]
        track.mute = False

    idle_act = bpy.data.actions["Idle"]
    arm_obj.animation_data.action = idle_act
    arm_obj.animation_data.action_slot = idle_act.slots[0]

    dummy_obj.animation_data_create()
    for d_name in ("Dummy_Idle", "Dummy_Hit"):
        d_act = bpy.data.actions.new(name=d_name)
        d_act.use_fake_user = True
        dummy_obj.animation_data.action = d_act
        for f, rec in ((1, 0.0), (6, 1.0 if d_name == "Dummy_Hit" else 0.0), (14, -0.25 if d_name == "Dummy_Hit" else 0.0), (24, 0.0)):
            dummy_obj.pose.bones["DummyTorsoBone"].rotation_euler = (0.0, 0.0, -rec * 0.18)
            dummy_obj.pose.bones["DummyTorsoBone"].keyframe_insert("rotation_euler", frame=f)
            dummy_obj.pose.bones["DummyArm"].rotation_euler = (0.0, 0.0, rec * 0.38)
            dummy_obj.pose.bones["DummyArm"].keyframe_insert("rotation_euler", frame=f)
        smooth_action_fcurves(d_act)
        tr = dummy_obj.animation_data.nla_tracks.new()
        tr.name = d_name
        st = tr.strips.new(d_name, 1, d_act)
        st.action_slot = d_act.slots[0]


# ==============================================================================
# 8. STUDIO ENVIRONMENT, THREE-POINT LIGHTING & CINEMATIC DoF CAMERA
# ==============================================================================
def build_studio_lighting_and_cameras(env_col, arm_obj):
    def add_light(name, ltype, energy, color, loc, rot_deg):
        ldata = bpy.data.lights.new(name=name, type=ltype)
        ldata.energy = energy
        ldata.color = color
        if ltype == 'SUN':
            ldata.angle = math.radians(10.0)
        lobj = bpy.data.objects.new(name, ldata)
        env_col.objects.link(lobj)
        lobj.location = loc
        lobj.rotation_euler = Euler([math.radians(a) for a in rot_deg], 'XYZ')
        return lobj

    add_light("KeyLight", 'SUN', 3.5, (1.0, 0.96, 0.90), (2.5, -3.5, 4.2), (48, 12, 28))
    add_light("FillLight", 'SUN', 1.6, (0.76, 0.88, 1.0), (-3.0, -2.5, 2.2), (62, -18, -38))
    add_light("RimLight", 'SUN', 2.3, (1.0, 0.86, 0.65), (0.0, 3.5, 3.2), (-45, 0, 180))

    # Orthographic Turnaround / Playblast Camera
    cam_data = bpy.data.cameras.new("PreviewCamera")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 2.0
    cam_obj = bpy.data.objects.new("PreviewCamera", cam_data)
    env_col.objects.link(cam_obj)

    # Cinematic Perspective Camera with 50mm lens, Depth of Field & Subject Tracking
    cin_data = bpy.data.cameras.new("CinematicCamera")
    cin_data.type = 'PERSP'
    cin_data.lens = 50.0
    cin_data.dof.use_dof = True
    cin_data.dof.focus_distance = 2.65
    cin_data.dof.aperture_fstop = 2.8
    cin_obj = bpy.data.objects.new("CinematicCamera", cin_data)
    env_col.objects.link(cin_obj)
    cin_obj.location = (0.35, -2.55, 1.08)

    focus_empty = bpy.data.objects.new("CinematicFocusTarget", None)
    env_col.objects.link(focus_empty)
    focus_empty.location = (0.05, 0.0, 1.02)
    cin_data.dof.focus_object = focus_empty

    track_con = cin_obj.constraints.new(type='TRACK_TO')
    track_con.target = focus_empty
    track_con.track_axis = 'TRACK_NEGATIVE_Z'
    track_con.up_axis = 'UP_Y'

    bpy.context.scene.camera = cam_obj
    return cam_obj, cin_obj


def set_active_gear(weapon_idx=0, headgear_idx=0, suit_idx=0, shield_idx=2):
    for i in range(6):
        for prefix, sel in (("Weapon", weapon_idx), ("Headgear", headgear_idx), ("Suit", suit_idx)):
            obj = bpy.data.objects.get(f"{prefix}_{i}")
            if obj:
                obj.hide_render = (i != sel)
    for i in (1, 2, 3):
        obj = bpy.data.objects.get(f"Shield_{i}")
        if obj:
            obj.hide_render = (i != shield_idx)
    suit_mat = [MAT_CACHE["Mat_LeatherTunic"], MAT_CACHE["Mat_Brass"], MAT_CACHE["Mat_NavyCoat"]][suit_idx]
    for lname in ("UpperArm_R", "UpperArm_L", "ThighMesh_R", "ThighMesh_L"):
        obj = bpy.data.objects.get(lname)
        if obj and len(obj.data.materials) > 0:
            obj.data.materials[len(obj.data.materials) - 1] = suit_mat


def stitch_filmstrip(image_paths, out_path):
    """Stitches multiple rendered frame PNGs horizontally into a single temporal playblast strip."""
    imgs = [bpy.data.images.load(p) for p in image_paths]
    w, h = imgs[0].size[0], imgs[0].size[1]
    n = len(imgs)
    strip_w = w * n
    strip_img = bpy.data.images.new("FilmstripTemp", width=strip_w, height=h, alpha=True)

    src_buffers = [list(im.pixels[:]) for im in imgs]
    dst_pixels = [0.0] * (strip_w * h * 4)

    for y in range(h):
        for i, buf in enumerate(src_buffers):
            src_row_start = y * w * 4
            dst_row_start = (y * strip_w + i * w) * 4
            dst_pixels[dst_row_start:dst_row_start + w * 4] = buf[src_row_start:src_row_start + w * 4]

    strip_img.pixels[:] = dst_pixels
    strip_img.filepath_raw = out_path
    strip_img.file_format = 'PNG'
    strip_img.save()

    for im in imgs:
        bpy.data.images.remove(im)
    bpy.data.images.remove(strip_img)


# ==============================================================================
# 9. MULTI-ANGLE, RIG STRESS TEST & FILMSTRIP PLAYBLAST VERIFICATION RENDERS
# ==============================================================================
def render_verification_previews(arm_obj, dummy_obj, cam_obj, cin_obj):
    scene = bpy.context.scene
    scene.render.resolution_x = 500
    scene.render.resolution_y = 500

    arm_obj.animation_data.use_nla = False
    dummy_mesh = bpy.data.objects.get("Dummy_Mesh")
    if dummy_mesh:
        dummy_mesh.hide_render = True

    set_active_gear(weapon_idx=0, headgear_idx=0, suit_idx=0, shield_idx=2)
    idle_act = bpy.data.actions["Idle"]
    arm_obj.animation_data.action = idle_act
    arm_obj.animation_data.action_slot = idle_act.slots[0]
    scene.frame_set(1)
    scene.camera = cam_obj

    # 1. Multi-Angle Turnaround (Front 3/4, Side, Back 3/4, Front)
    angles = [
        ("view_0_front34.png", -32.0),
        ("view_1_side.png", 0.0),
        ("view_2_back34.png", 138.0),
        ("view_3_front.png", -90.0),
    ]
    cam_obj.location = (0.04, -4.5, 0.80)
    cam_obj.rotation_euler = Euler((math.radians(90.0), 0.0, 0.0), 'XYZ')
    cam_obj.data.ortho_scale = 1.88

    for fname, yaw_deg in angles:
        arm_obj.rotation_euler = (0.0, 0.0, math.radians(yaw_deg))
        scene.render.filepath = os.path.join(RENDER_DIR, fname)
        bpy.ops.render.render(write_still=True)

    # 2. Equipment Loadout Variants
    loadouts = [
        ("gear_0_machinist.png", (0, 0, 0, 2)),
        ("gear_1_boiler_knight.png", (1, 1, 1, 1)),
        ("gear_2_steam_officer.png", (2, 2, 2, 2)),
        ("gear_3_lancer.png", (4, 1, 0, 3)),
        ("gear_4_staff_adept.png", (5, 0, 2, 1)),
    ]
    arm_obj.rotation_euler = (0.0, 0.0, math.radians(-32.0))
    for fname, (w_i, h_i, s_i, sh_i) in loadouts:
        set_active_gear(w_i, h_i, s_i, sh_i)
        scene.render.filepath = os.path.join(RENDER_DIR, fname)
        bpy.ops.render.render(write_still=True)

    # 3. Representative Animation Frames + Walk & Combat Temporal Playblast Strips
    set_active_gear(0, 0, 0, 2)
    anim_shots = [
        ("anim_0_walk_contact.png", "Walk", 1, -28.0),
        ("anim_1_walk_pass.png", "Walk", 9, -28.0),
        ("anim_2_attack_windup.png", "Attack", 17, -28.0),
        ("anim_3_attack_cleave.png", "Attack", 23, -28.0),
        ("anim_4_guard_block.png", "Guard", 14, -32.0),
        ("anim_5_pipe_turn.png", "Enter_Pipe", 36, -24.0),
        ("anim_6_shoot_aim.png", "Shoot", 8, -28.0),
        ("anim_7_cast_release.png", "Cast", 24, -28.0),
        ("anim_8_heal_inject.png", "Heal", 15, -28.0),
        ("anim_9_buff_burst.png", "Buff", 16, -28.0),
    ]
    for fname, act_name, frame_num, yaw_deg in anim_shots:
        act = bpy.data.actions[act_name]
        set_active_gear(2 if act_name == "Shoot" else 0, 0, 0, 2)
        arm_obj.animation_data.action = act
        arm_obj.animation_data.action_slot = act.slots[0]
        arm_obj.rotation_euler = (0.0, 0.0, math.radians(yaw_deg))
        scene.frame_set(frame_num)
        scene.render.filepath = os.path.join(RENDER_DIR, fname)
        bpy.ops.render.render(write_still=True)

    # 4. Walk Cycle 4-Frame Temporal Playblast Contact Sheet (Contact R -> Passing R -> Contact L -> Passing L)
    scene.render.resolution_x = 340
    scene.render.resolution_y = 420
    walk_act = bpy.data.actions["Walk"]
    arm_obj.animation_data.action = walk_act
    arm_obj.animation_data.action_slot = walk_act.slots[0]
    arm_obj.rotation_euler = (0.0, 0.0, math.radians(-26.0))
    walk_strip_files = []
    for idx, f_num in enumerate((1, 9, 17, 25)):
        scene.frame_set(f_num)
        fp = os.path.join(RENDER_DIR, f"_tmp_walk_{idx}.png")
        scene.render.filepath = fp
        bpy.ops.render.render(write_still=True)
        walk_strip_files.append(fp)
    stitch_filmstrip(walk_strip_files, os.path.join(RENDER_DIR, "playblast_walk_strip.png"))
    for fp in walk_strip_files:
        if os.path.exists(fp):
            os.remove(fp)

    # 5. Rig Stress Test & Action Variety 4-Panel Sheet (Run Sprint, Jump Apex, Turn/Look Blink, Deep Squat Land)
    stress_shots = [
        ("Run", 5, -28.0),
        ("Jump_Land", 13, -28.0),
        ("Turn_Look", 11, -48.0),
        ("Jump_Land", 21, -28.0),
    ]
    stress_files = []
    for idx, (act_n, f_num, yaw_deg) in enumerate(stress_shots):
        act = bpy.data.actions[act_n]
        arm_obj.animation_data.action = act
        arm_obj.animation_data.action_slot = act.slots[0]
        arm_obj.rotation_euler = (0.0, 0.0, math.radians(yaw_deg))
        scene.frame_set(f_num)
        fp = os.path.join(RENDER_DIR, f"_tmp_stress_{idx}.png")
        scene.render.filepath = fp
        bpy.ops.render.render(write_still=True)
        stress_files.append(fp)
    stitch_filmstrip(stress_files, os.path.join(RENDER_DIR, "rig_stress_test.png"))
    for fp in stress_files:
        if os.path.exists(fp):
            os.remove(fp)

    # 6. Cinematic Close-Up Shot (50mm DoF Perspective Camera + Facial Acting & Rim Lighting)
    scene.render.resolution_x = 540
    scene.render.resolution_y = 540
    scene.camera = cin_obj
    turn_act = bpy.data.actions["Turn_Look"]
    arm_obj.animation_data.action = turn_act
    arm_obj.animation_data.action_slot = turn_act.slots[0]
    arm_obj.rotation_euler = (0.0, 0.0, math.radians(-34.0))
    scene.frame_set(7)
    scene.render.filepath = os.path.join(RENDER_DIR, "cinematic_hero_dof.png")
    bpy.ops.render.render(write_still=True)

    # Restore clean state for export
    scene.camera = cam_obj
    if dummy_mesh:
        dummy_mesh.hide_render = False
    set_active_gear(0, 0, 0, 2)
    arm_obj.rotation_euler = (0.0, 0.0, 0.0)
    arm_obj.animation_data.action = idle_act
    arm_obj.animation_data.action_slot = idle_act.slots[0]
    arm_obj.animation_data.use_nla = True
    scene.frame_set(1)


# ==============================================================================
# 10. AUTOMATED QUALITY ASSURANCE (GEOMETRY, RIG, ANIMATION & PERFORMANCE QA)
# ==============================================================================
def validate_pipeline(arm_obj, dummy_obj, env_info, export_col):
    report = {
        "environment": env_info,
        "style": "SD (Super-Deformed ~2.2-head) Steampunk Warrior",
        "geometry_qa": {
            "meshes_checked": 0,
            "total_vertices": 0,
            "total_triangles": 0,
            "degenerate_faces": 0,
            "unapplied_transforms": 0,
            "missing_uv_meshes": [],
            "missing_material_meshes": [],
        },
        "rig_qa": {
            "vesper_bone_count": len(arm_obj.data.bones),
            "dummy_bone_count": len(dummy_obj.data.bones),
            "custom_control_shapes": sum(1 for pb in arm_obj.pose.bones if pb.custom_shape is not None),
            "joint_limit_constraints": sum(len(pb.constraints) for pb in arm_obj.pose.bones),
            "unweighted_vertices": 0,
            "multi_bone_blended_vertices": 0,
        },
        "animation_qa": {
            "actions_verified": [],
            "loop_continuity_max_delta": {},
        },
    }

    mesh_objs = [o for o in export_col.all_objects if o.type == 'MESH']
    for obj in mesh_objs:
        me = obj.data
        report["geometry_qa"]["meshes_checked"] += 1
        report["geometry_qa"]["total_vertices"] += len(me.vertices)
        me.calc_loop_triangles()
        report["geometry_qa"]["total_triangles"] += len(me.loop_triangles)

        if (obj.scale - Vector((1.0, 1.0, 1.0))).length > 1e-4:
            report["geometry_qa"]["unapplied_transforms"] += 1
        if len(me.uv_layers) == 0:
            report["geometry_qa"]["missing_uv_meshes"].append(obj.name)
        if len(me.materials) == 0:
            report["geometry_qa"]["missing_material_meshes"].append(obj.name)
        for poly in me.polygons:
            if poly.area <= 1e-8:
                report["geometry_qa"]["degenerate_faces"] += 1
        for v in me.vertices:
            total_w = sum(g.weight for g in v.groups)
            if total_w < 0.99:
                report["rig_qa"]["unweighted_vertices"] += 1
            if len(v.groups) >= 2:
                report["rig_qa"]["multi_bone_blended_vertices"] += 1

    required_actions = [
        "Idle", "Walk", "Run", "Jump_Land", "Turn_Look",
        "Attack", "Skill_Stab", "Skill_Steam", "Guard", "Hit", "Down", "Enter_Pipe",
        "Shoot", "Cast", "Heal", "Buff",
    ]
    for act_name in required_actions:
        assert act_name in bpy.data.actions, f"Missing required Action: {act_name}"
        act = bpy.data.actions[act_name]
        fcurve_count = sum(len(bag.fcurves) for layer in act.layers for strip in layer.strips for bag in strip.channelbags)
        assert fcurve_count > 0, f"Action {act_name} has 0 FCurves"
        report["animation_qa"]["actions_verified"].append({"name": act_name, "fcurves": fcurve_count})

    for loop_name, end_f in (("Idle", 48), ("Walk", 32), ("Run", 20), ("Turn_Look", 40)):
        act = bpy.data.actions[loop_name]
        max_delta = 0.0
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        v_start = fc.evaluate(1)
                        v_end = fc.evaluate(end_f)
                        max_delta = max(max_delta, abs(v_start - v_end))
        report["animation_qa"]["loop_continuity_max_delta"][loop_name] = round(max_delta, 7)
        assert max_delta < 1e-4, f"Loop continuity error in {loop_name}: {max_delta}"

    assert report["geometry_qa"]["degenerate_faces"] == 0
    assert report["geometry_qa"]["unapplied_transforms"] == 0
    assert report["rig_qa"]["unweighted_vertices"] == 0
    assert report["rig_qa"]["multi_bone_blended_vertices"] > 100
    assert len(report["geometry_qa"]["missing_uv_meshes"]) == 0
    assert len(report["geometry_qa"]["missing_material_meshes"]) == 0

    report_path = os.path.join(RENDER_DIR, "validation_report.json")
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print("VALIDATION_REPORT:", json.dumps(report))


def main():
    t0 = time.time()
    env_info = probe_environment()
    reset_scene()
    init_materials()

    # Studio-Standard Organized Collections
    export_col = bpy.data.collections.new("COL_Export_Assets")
    bpy.context.scene.collection.children.link(export_col)

    char_col = bpy.data.collections.new("COL_Vesper_Character")
    equip_col = bpy.data.collections.new("COL_Vesper_Equipment")
    prop_col = bpy.data.collections.new("COL_Props_Automaton")
    export_col.children.link(char_col)
    export_col.children.link(equip_col)
    export_col.children.link(prop_col)

    widget_col = bpy.data.collections.new("COL_Rig_Widgets")
    env_col = bpy.data.collections.new("COL_Studio_Cinematic")
    bpy.context.scene.collection.children.link(widget_col)
    bpy.context.scene.collection.children.link(env_col)

    widgets = build_control_widgets(widget_col)
    arm_obj = build_vesper_armature(char_col, widgets)
    build_vesper_meshes(arm_obj, char_col, equip_col)
    dummy_obj = build_target_dummy(prop_col)
    build_vesper_actions(arm_obj, dummy_obj)

    cam_obj, cin_obj = build_studio_lighting_and_cameras(env_col, arm_obj)

    validate_pipeline(arm_obj, dummy_obj, env_info, export_col)
    render_verification_previews(arm_obj, dummy_obj, cam_obj, cin_obj)

    for obj in export_col.all_objects:
        obj.hide_render = False
        obj.hide_viewport = False

    blend_path = os.path.join(OUT_DIR, "vesper_warrior.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)

    bpy.ops.object.select_all(action='DESELECT')
    for obj in export_col.all_objects:
        obj.select_set(True)

    glb_path = os.path.join(OUT_DIR, "vesper_warrior.glb")
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format='GLB',
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_materials='EXPORT',
        export_skins=True,
        export_animations=True,
        export_animation_mode='NLA_TRACKS',
    )
    print(f"PIPELINE_COMPLETE in {time.time() - t0:.2f}s:", blend_path, glb_path)


if __name__ == "__main__":
    main()
