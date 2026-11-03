class_name Hero3D
extends Stage3D
# Toon SD hero (prototypes/character-lab) rendered by an orthographic SubViewport for the 2.5D look.

const MODEL := preload("res://art/characters/vesper_warrior.glb")
const OUTLINE := Color("101b20")
const SUIT_COLORS := [Color("88583e"), Color("b48c4e"), Color("32526e")]
const LIMB_MESHES := ["UpperArm_R", "UpperArm_L", "ThighMesh_R", "ThighMesh_L"]
# Clip speed lifts the authored 1.5-1.7s actions into the combat pump's 0.36s turn rhythm.
const ACTIONS := {"attack":["Attack",1.15], "skill_stab":["Skill_Stab",1.1], "skill_steam":["Skill_Steam",1.1], "guard":["Guard",1.2], "hit":["Hit",1.25], "down":["Down",1.0], "vent":["Skill_Steam",1.1], "enter_pipe":["Enter_Pipe",1.4], "shoot":["Shoot",1.1], "cast":["Cast",1.1], "heal":["Heal",1.1], "buff":["Buff",1.1]}
# Clip time where the blade or nozzle reaches full extension, read from the Shoulder_R rotation peaks.
const CONTACT := {"Attack":0.92, "Skill_Stab":0.85, "Skill_Steam":0.84, "Shoot":0.52, "Cast":0.94, "Heal":0.67, "Buff":0.65}
# Gear mesh index per weapon/shield `model` in items.json. Weapon index 3 stays "none" for NPCs (roster_3d.gd).
const WEAPON_INDEX := {"blade":0, "blunt":1, "gun":2, "polearm":4, "staff":5}
const SHIELD_INDEX := {"plate":1, "light":2, "tower":3}
const WEAPON_NODES := [0, 1, 2, 4, 5]
const TIER_COLORS := ["8a9490","6fbf73","5ab4e0","b07ce0","e3b858"]
const TIERED := {"Mat_Steel":0.4, "Mat_SteelDark":0.3, "Mat_Brass":0.18}

var model: Node3D
var animator: AnimationPlayer
var nodes: Dictionary = {}
var suit_material: StandardMaterial3D
var sparks: GPUParticles3D
var steam: GPUParticles3D
# Per-instance toon copies keyed by the GLB material name, so a variant recolours only itself.
var toons: Dictionary = {}
var variant: Dictionary = {}
var dummy: bool = false
var weapon_model: String = "blade"
# [toon, base colour, GLB material name] per weapon mesh, so a tier tint never accumulates.
var weapon_toons: Dictionary = {}

func _init() -> void:
	super()
	model = MODEL.instantiate()
	viewport.add_child(model)
	_index(model)
	nodes["TargetDummyRoot"].visible = false
	animator = model.get_node("AnimationPlayer")
	for clip in ["Idle", "Walk"]:
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animator.animation_finished.connect(func(_clip):
		busy = 0.0
		if dummy: animator.play("Dummy_Idle"))
	_stylize()
	sparks = _particles(Color("ffc865"), 18, 0.35, Vector3(0, -6, 0), 3.2)
	steam = _particles(Color(0.86, 0.95, 0.97, 0.7), 14, 0.7, Vector3(0, 1.2, 0), 1.6)
	set_equipment({}, [])
	animator.play("Idle")

func _index(node: Node) -> void:
	nodes[node.name] = node
	for child in node.get_children():
		_index(child)

func _stylize() -> void:
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.albedo_color = OUTLINE
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 0.009
	suit_material = _toon(SUIT_COLORS[0], outline)
	for node in nodes.values():
		if not node is MeshInstance3D or node.mesh == null: continue
		for surface in node.mesh.get_surface_count():
			var source = node.get_active_material(surface)
			if not source is BaseMaterial3D: continue
			var toon := _toon(source.albedo_color, outline)
			if not toons.has(source.resource_name): toons[source.resource_name] = []
			toons[source.resource_name].append(toon)
			if node.name.begins_with("Weapon_"):
				if not weapon_toons.has(node.name): weapon_toons[node.name] = []
				weapon_toons[node.name].append([toon, toon.albedo_color, source.resource_name])
			toon.metallic = source.metallic * 0.45
			toon.roughness = clampf(source.roughness, 0.28, 0.68)
			if source.emission_enabled:
				toon.emission_enabled = true
				toon.emission = source.emission
				toon.emission_energy_multiplier = 1.5
			node.set_surface_override_material(surface, toon)
		if node.name in LIMB_MESHES:
			node.set_surface_override_material(node.mesh.get_surface_count() - 1, suit_material)

func _toon(color: Color, outline: Material) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_TOON
	material.roughness = 0.55
	material.next_pass = outline
	return material

func _particles(color: Color, amount: int, life: float, gravity: Vector3, velocity: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.explosiveness = 0.9
	particles.amount = amount
	particles.lifetime = life
	particles.local_coords = true
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(1, 0.3, 0)
	process.spread = 55.0
	process.initial_velocity_min = velocity * 0.5
	process.initial_velocity_max = velocity
	process.gravity = gravity
	process.scale_min = 0.6
	process.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	particles.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.035 if gravity.y < 0 else 0.09
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.position = Vector3(0.55, 0.95, 0.2)
	viewport.add_child(particles)
	return particles

# gear = [weapon mesh, head, suit, shield mesh]. Weapons and shields come from the item's `model` field;
# the name keywords are only a fallback for items without one.
static func variants(equipment: Dictionary, items: Array) -> Array:
	var worn := {}
	for item in items:
		if equipment.values().has(item.id): worn[item.slot] = item
	var head: String = worn.get("head", {}).get("name", "")
	var suit: String = worn.get("suit", {}).get("name", "")
	return [
		_weapon_index(worn.get("weapon", {})),
		1 if head.contains("หมวก") else 2 if _has_any(head, ["หน้ากาก", "กระบัง"]) else 0,
		1 if suit.contains("เกราะ") else 2 if suit.begins_with("ชุด") else 0,
		_shield_index(worn.get("shield", {}))]

static func _weapon_index(item: Dictionary) -> int:
	if item.is_empty(): return 0
	if WEAPON_INDEX.has(item.get("model", "")): return WEAPON_INDEX[item.model]
	var name: String = item.name
	if _has_any(name, ["ค้อน", "กระบอง", "ประแจ", "ขวาน"]): return 1
	if name.contains("ปืน"): return 2
	if _has_any(name, ["หอก", "ทวน"]): return 4
	if name.contains("คทา"): return 5
	return 0

static func _shield_index(item: Dictionary) -> int:
	if item.is_empty(): return 0
	if SHIELD_INDEX.has(item.get("model", "")): return SHIELD_INDEX[item.model]
	return 1 if int(item.get("tier", 1)) <= 2 else 2

static func _has_any(text: String, words: Array) -> bool:
	return words.any(func(word): return text.contains(word))

func set_equipment(equipment: Dictionary, items: Array) -> void:
	_show_gear(variants(equipment, items))
	var tier := 0
	for item in items:
		if item.slot == "weapon" and equipment.values().has(item.id): tier = int(item.tier)
	_tint_weapons(tier)

# Subtle tier tint on the weapon's metal so it still reads as steel/brass.
func _tint_weapons(tier: int) -> void:
	var tint := Color(TIER_COLORS[clampi(tier - 1, 0, 4)])
	for entries in weapon_toons.values():
		for entry in entries:
			entry[0].albedo_color = entry[1].lerp(tint, TIERED.get(entry[2], 0.0)) if tier > 0 else entry[1]

func _show_gear(gear: Array) -> void:
	for i in 3:
		nodes["Headgear_%d" % i].visible = gear[1] == i
		nodes["Suit_%d" % i].visible = gear[2] == i
	for i in WEAPON_NODES: nodes["Weapon_%d" % i].visible = gear[0] == i
	for i in [1, 2, 3]: nodes["Shield_%d" % i].visible = gear[3] == i
	weapon_model = str(WEAPON_INDEX.find_key(gear[0])) if WEAPON_INDEX.values().has(gear[0]) else "none"
	suit_material.albedo_color = SUIT_COLORS[gear[2]]

func perform(kind: String) -> void:
	if dummy:
		if kind in ["hit","guard"]: animator.play("Dummy_Hit", 0.05, 1.6)
		return
	if not ACTIONS.has(kind) or down or not animator.has_animation(ACTIONS[kind][0]): return
	var action: Array = ACTIONS[kind]
	down = kind == "down"
	busy = 1.0
	animator.play(action[0], 0.08, action[1])
	if kind in ["attack", "skill_stab", "shoot"]: _burst(sparks, 0.12)
	elif kind in ["skill_steam", "vent"]: _burst(steam, 0.18)

func _burst(particles: GPUParticles3D, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(particles): particles.restart()


func _process(delta: float) -> void:
	super(delta)
	model.rotation.y = deg_to_rad(-150.0 if facing_left else -30.0)
	sparks.position.x = -0.55 if facing_left else 0.55
	sparks.process_material.direction.x = -1.0 if facing_left else 1.0
	freeze = maxf(0.0, freeze - delta)
	animator.speed_scale = 0.0 if freeze > 0.0 else 1.0
	if busy > 0.0 or down or dummy: return
	var loop := "Run" if running else "Walk" if moving else "Idle"
	if animator.current_animation != loop: animator.play(loop, 0.12, walk_speed if loop == "Walk" else 1.0)

func strike_timing(kind: String) -> Vector2:
	if not ACTIONS.has(kind) or dummy: return super(kind)
	var clip: String = ACTIONS[kind][0]
	var speed: float = ACTIONS[kind][1]
	var length := animator.get_animation(clip).length
	var contact: float = CONTACT.get(clip, length * 0.5)
	# Return once the follow-through settles, not when the whole clip has wound down.
	return Vector2(contact / speed, minf(0.35, (length - contact) / speed))

# NPCs and human foes reuse the hero rig: fixed gear, recoloured cloth/hair/skin, body proportions and a few head props.
func apply_variant(spec: Dictionary) -> void:
	variant = spec
	if spec.get("dummy", false):
		dummy = true
		for child in model.get_children():
			if child is Node3D: child.visible = child.name == "TargetDummyRoot"
		nodes["TargetDummyRoot"].visible = true
		nodes["TargetDummyRoot"].position = Vector3.ZERO
		animator.get_animation("Dummy_Idle").loop_mode = Animation.LOOP_LINEAR
		animator.play("Dummy_Idle")
		return
	_show_gear(spec.get("gear", [0,0,0,0]))
	nodes["BoilerPack"].visible = spec.get("pack", true)
	for material_name in spec.get("colors", {}):
		var color: Color = Color(spec.colors[material_name])
		if material_name == "suit":
			suit_material.albedo_color = color
		for toon in toons.get(material_name, []):
			toon.albedo_color = color
	model.scale = spec.get("build", Vector3.ONE)
	for extra in spec.get("extras", []):
		_attach(extra, Color(spec.get("extra_color", "e9e4d8")))

# Boss-specific kits: [mesh ("box"/"sphere"/"cyl"), position, scale, colour hex ("" = the spec's extra_color), glow, rotation degrees], on the named bone.
const BOSS_EXTRAS := {
	"conductor_cap":{"bone":"Head","parts":[["cyl", Vector3(0.0, 0.43, 0.0), Vector3(0.4, 0.16, 0.4), "1c2a3e", 0.0, Vector3.ZERO], ["box", Vector3(0.22, 0.37, 0.0), Vector3(0.2, 0.035, 0.38), "10161e", 0.0, Vector3.ZERO], ["sphere", Vector3(0.2, 0.46, 0.0), Vector3(0.09, 0.09, 0.09), "ffcf4a", 1.2, Vector3.ZERO]]},
	"loco_plate":{"bone":"Torso","parts":[["cyl", Vector3(0.2, 0.0, 0.0), Vector3(0.62, 0.08, 0.62), "2c3440", 0.0, Vector3(0, 0, 90)], ["cyl", Vector3(0.25, 0.0, 0.0), Vector3(0.46, 0.04, 0.46), "b8862c", 0.0, Vector3(0, 0, 90)], ["sphere", Vector3(0.28, 0.0, 0.0), Vector3(0.14, 0.14, 0.14), "ffe08a", 1.6, Vector3.ZERO]]},
	"lantern":{"bone":"Torso","parts":[["cyl", Vector3(0.1, -0.12, -0.36), Vector3(0.03, 0.14, 0.03), "2a2a30", 0.0, Vector3.ZERO], ["sphere", Vector3(0.1, -0.27, -0.36), Vector3(0.14, 0.18, 0.14), "ffb84a", 2.2, Vector3.ZERO]]},
	"furnace_arm":{"bone":"Hand_R","parts":[["box", Vector3(0.0, 0.0, 0.0), Vector3(0.26, 0.24, 0.24), "3a3a42", 0.0, Vector3.ZERO], ["box", Vector3(0.05, 0.0, 0.0), Vector3(0.28, 0.07, 0.18), "ff6a1a", 2.0, Vector3.ZERO]]},
	"chimney_pack":{"bone":"Torso","parts":[["box", Vector3(-0.28, 0.1, 0.0), Vector3(0.18, 0.4, 0.34), "3a3a42", 0.0, Vector3.ZERO], ["cyl", Vector3(-0.3, 0.5, -0.08), Vector3(0.09, 0.45, 0.09), "2a2a30", 0.0, Vector3.ZERO], ["cyl", Vector3(-0.3, 0.45, 0.1), Vector3(0.09, 0.35, 0.09), "2a2a30", 0.0, Vector3.ZERO], ["cyl", Vector3(-0.3, 0.73, -0.08), Vector3(0.12, 0.04, 0.12), "ff6a1a", 2.2, Vector3.ZERO], ["cyl", Vector3(-0.3, 0.63, 0.1), Vector3(0.12, 0.04, 0.12), "ff6a1a", 2.2, Vector3.ZERO], ["sphere", Vector3(-0.34, 0.9, -0.08), Vector3(0.2, 0.14, 0.2), "5a5a62", 0.0, Vector3.ZERO]]},
	"records_cabinet":{"bone":"Torso","parts":[["box", Vector3(-0.28, 0.1, 0.0), Vector3(0.18, 0.5, 0.36), "4a5262", 0.0, Vector3.ZERO], ["box", Vector3(-0.18, 0.25, 0.0), Vector3(0.03, 0.08, 0.26), "9fb8ff", 1.4, Vector3.ZERO], ["box", Vector3(-0.18, 0.1, 0.0), Vector3(0.03, 0.08, 0.26), "9fb8ff", 1.4, Vector3.ZERO], ["box", Vector3(-0.18, -0.05, 0.0), Vector3(0.03, 0.08, 0.26), "9fb8ff", 1.4, Vector3.ZERO]]},
	"lens_visor":{"bone":"Head","parts":[["cyl", Vector3(0.26, 0.2, 0.1), Vector3(0.14, 0.08, 0.14), "2a2a30", 0.0, Vector3(0, 0, 90)], ["sphere", Vector3(0.31, 0.2, 0.1), Vector3(0.1, 0.1, 0.1), "9fe8ff", 2.0, Vector3.ZERO], ["box", Vector3(0.24, 0.21, -0.05), Vector3(0.05, 0.08, 0.3), "2a2a30", 0.0, Vector3.ZERO]]},
	# NPC role props. Hand_R items sit in the gripping fist; torso/head items follow the boss kits' axes (+X forward, +Y up).
	"wrench":{"bone":"Hand_R","parts":[["box", Vector3(0.16, 0.0, 0.0), Vector3(0.36, 0.07, 0.07), "8a8a92", 0.0, Vector3.ZERO], ["cyl", Vector3(0.36, 0.0, 0.0), Vector3(0.18, 0.06, 0.18), "a0a0aa", 0.0, Vector3(90, 0, 0)], ["box", Vector3(0.4, 0.0, 0.0), Vector3(0.09, 0.09, 0.08), "26303a", 0.0, Vector3.ZERO]]},
	"apron":{"bone":"Torso","parts":[["box", Vector3(0.2, -0.08, 0.0), Vector3(0.06, 0.5, 0.36), "6a4a30", 0.0, Vector3.ZERO], ["box", Vector3(0.23, -0.02, 0.0), Vector3(0.04, 0.16, 0.22), "4a3220", 0.0, Vector3.ZERO]]},
	"medic_satchel":{"bone":"Torso","parts":[["box", Vector3(0.0, -0.2, 0.32), Vector3(0.28, 0.26, 0.14), "8a5a3a", 0.0, Vector3.ZERO], ["box", Vector3(0.0, -0.05, 0.32), Vector3(0.3, 0.06, 0.16), "6a4228", 0.0, Vector3.ZERO], ["box", Vector3(0.0, -0.2, 0.4), Vector3(0.1, 0.1, 0.02), "f0f0f0", 0.0, Vector3.ZERO]]},
	"red_cross":{"bone":"Torso","parts":[["box", Vector3(0.21, 0.12, 0.0), Vector3(0.04, 0.24, 0.24), "f4f4f0", 0.0, Vector3.ZERO], ["box", Vector3(0.235, 0.12, 0.0), Vector3(0.03, 0.18, 0.06), "d02a2a", 0.0, Vector3.ZERO], ["box", Vector3(0.235, 0.12, 0.0), Vector3(0.03, 0.06, 0.18), "d02a2a", 0.0, Vector3.ZERO]]},
	"medic_cap":{"bone":"Head","parts":[["cyl", Vector3(0.0, 0.42, 0.0), Vector3(0.38, 0.06, 0.38), "f4f4f0", 0.0, Vector3.ZERO], ["box", Vector3(0.2, 0.43, 0.0), Vector3(0.02, 0.1, 0.1), "d02a2a", 0.0, Vector3.ZERO], ["box", Vector3(0.2, 0.43, 0.0), Vector3(0.02, 0.04, 0.2), "d02a2a", 0.0, Vector3.ZERO]]},
	"merchant_cap":{"bone":"Head","parts":[["cyl", Vector3(0.0, 0.43, 0.0), Vector3(0.42, 0.07, 0.42), "5a2a40", 0.0, Vector3.ZERO], ["box", Vector3(0.22, 0.4, 0.0), Vector3(0.12, 0.03, 0.3), "2a1a24", 0.0, Vector3.ZERO], ["sphere", Vector3(0.0, 0.5, 0.0), Vector3(0.07, 0.07, 0.07), "ffcf4a", 0.8, Vector3.ZERO]]},
	"scarf":{"bone":"Head","parts":[["cyl", Vector3(0.0, -0.08, 0.0), Vector3(0.46, 0.05, 0.46), "e0a030", 0.0, Vector3.ZERO], ["box", Vector3(0.12, -0.25, 0.0), Vector3(0.05, 0.3, 0.12), "e0a030", 0.0, Vector3(0, 0, 8)]]},
	"ledger":{"bone":"Hand_R","parts":[["box", Vector3(0.0, 0.0, 0.0), Vector3(0.28, 0.06, 0.38), "5a2a1a", 0.0, Vector3.ZERO], ["box", Vector3(0.0, 0.035, 0.0), Vector3(0.24, 0.02, 0.34), "e8dcc0", 0.0, Vector3.ZERO], ["box", Vector3(0.0, 0.0, -0.18), Vector3(0.3, 0.07, 0.03), "c89a3a", 0.0, Vector3.ZERO]]},
	"police_cap":{"bone":"Head","parts":[["cyl", Vector3(0.0, 0.44, 0.0), Vector3(0.44, 0.08, 0.44), "1c2a3e", 0.0, Vector3.ZERO], ["box", Vector3(0.22, 0.4, 0.0), Vector3(0.12, 0.03, 0.3), "10161e", 0.0, Vector3.ZERO], ["sphere", Vector3(0.2, 0.44, 0.0), Vector3(0.1, 0.1, 0.1), "ffcf4a", 1.0, Vector3.ZERO]]},
	"badge":{"bone":"Torso","parts":[["cyl", Vector3(0.22, 0.2, 0.12), Vector3(0.14, 0.03, 0.14), "ffcf4a", 1.0, Vector3(0, 0, 90)], ["box", Vector3(0.2, 0.12, -0.02), Vector3(0.04, 0.5, 0.06), "b8862c", 0.0, Vector3(0, 0, 0)]]},
	"baton":{"bone":"Hand_R","parts":[["cyl", Vector3(0.2, 0.0, 0.0), Vector3(0.07, 0.2, 0.07), "2a2a30", 0.0, Vector3(0, 0, 90)], ["cyl", Vector3(0.38, 0.0, 0.0), Vector3(0.09, 0.03, 0.09), "b8862c", 0.0, Vector3(0, 0, 90)]]},
	"glasses":{"bone":"Head","parts":[["cyl", Vector3(0.23, 0.2, 0.1), Vector3(0.14, 0.03, 0.14), "bfeaf4", 0.6, Vector3(0, 0, 90)], ["cyl", Vector3(0.23, 0.2, -0.1), Vector3(0.14, 0.03, 0.14), "bfeaf4", 0.6, Vector3(0, 0, 90)], ["box", Vector3(0.235, 0.21, 0.0), Vector3(0.03, 0.03, 0.08), "2a2a30", 0.0, Vector3.ZERO]]},
	"lab_coat":{"bone":"Torso","parts":[["box", Vector3(0.0, -0.33, 0.0), Vector3(0.36, 0.2, 0.46), "d8e4ec", 0.0, Vector3.ZERO], ["box", Vector3(0.21, 0.0, 0.0), Vector3(0.03, 0.5, 0.05), "9fb0bc", 0.0, Vector3.ZERO], ["box", Vector3(0.2, 0.18, 0.14), Vector3(0.05, 0.1, 0.12), "b0c0cc", 0.0, Vector3(0, 0, 0)]]},
	"specimen_jar":{"bone":"Hand_R","parts":[["cyl", Vector3(0.14, 0.0, 0.0), Vector3(0.2, 0.11, 0.2), "9fe8c0", 0.7, Vector3(0, 0, 90)], ["cyl", Vector3(0.27, 0.0, 0.0), Vector3(0.22, 0.03, 0.22), "5a5a62", 0.0, Vector3(0, 0, 90)], ["sphere", Vector3(0.14, 0.0, 0.0), Vector3(0.1, 0.1, 0.1), "b7f04a", 1.4, Vector3.ZERO]]},
	"hard_hat":{"bone":"Head","parts":[["sphere", Vector3(0.0, 0.4, 0.0), Vector3(0.46, 0.3, 0.46), "f2c230", 0.0, Vector3.ZERO], ["box", Vector3(0.0, 0.5, 0.0), Vector3(0.38, 0.04, 0.08), "d8a020", 0.0, Vector3.ZERO], ["cyl", Vector3(0.1, 0.34, 0.0), Vector3(0.5, 0.03, 0.5), "f2c230", 0.0, Vector3.ZERO]]},
	"pail":{"bone":"Hand_R","parts":[["cyl", Vector3(-0.24, 0.0, 0.0), Vector3(0.26, 0.11, 0.26), "7a8a94", 0.0, Vector3(0, 0, 90)], ["cyl", Vector3(-0.14, 0.0, 0.0), Vector3(0.22, 0.005, 0.22), "4a8ac0", 0.8, Vector3(0, 0, 90)], ["box", Vector3(-0.07, 0.0, 0.0), Vector3(0.14, 0.02, 0.02), "3a3a42", 0.0, Vector3.ZERO]]},
	"doc_case":{"bone":"Hand_R","parts":[["box", Vector3(-0.2, 0.0, 0.0), Vector3(0.3, 0.42, 0.14), "6a5a3a", 0.0, Vector3.ZERO], ["box", Vector3(-0.08, 0.0, 0.0), Vector3(0.04, 0.2, 0.04), "3a2a1a", 0.0, Vector3.ZERO], ["box", Vector3(-0.1, 0.0, 0.08), Vector3(0.06, 0.1, 0.03), "c89a3a", 0.0, Vector3.ZERO]]},
	"scroll_tube":{"bone":"Torso","parts":[["cyl", Vector3(-0.2, 0.3, 0.0), Vector3(0.12, 0.3, 0.12), "d8c8a0", 0.0, Vector3(0, 0, 70)], ["cyl", Vector3(-0.2, 0.3, 0.0), Vector3(0.13, 0.02, 0.13), "6a5a3a", 0.0, Vector3(0, 0, 70)]]},
	"goggles_up":{"bone":"Head","parts":[["cyl", Vector3(0.0, 0.38, 0.0), Vector3(0.44, 0.06, 0.44), "3a2a1a", 0.0, Vector3.ZERO], ["cyl", Vector3(0.18, 0.4, 0.1), Vector3(0.14, 0.08, 0.14), "b8862c", 0.0, Vector3(0, 0, 90)], ["cyl", Vector3(0.18, 0.4, -0.1), Vector3(0.14, 0.08, 0.14), "b8862c", 0.0, Vector3(0, 0, 90)], ["cyl", Vector3(0.22, 0.4, 0.1), Vector3(0.1, 0.02, 0.1), "7fe8ff", 1.2, Vector3(0, 0, 90)], ["cyl", Vector3(0.22, 0.4, -0.1), Vector3(0.1, 0.02, 0.1), "7fe8ff", 1.2, Vector3(0, 0, 90)]]},
	"tool_belt":{"bone":"Torso","parts":[["cyl", Vector3(0.0, -0.24, 0.0), Vector3(0.5, 0.06, 0.5), "5a3a24", 0.0, Vector3.ZERO], ["box", Vector3(0.2, -0.24, 0.0), Vector3(0.06, 0.08, 0.1), "c89a3a", 0.0, Vector3.ZERO], ["box", Vector3(0.0, -0.36, 0.28), Vector3(0.06, 0.2, 0.06), "8a8a92", 0.0, Vector3.ZERO], ["box", Vector3(0.1, -0.34, -0.28), Vector3(0.12, 0.16, 0.08), "4a3220", 0.0, Vector3.ZERO]]},
	"circuit_board":{"bone":"Hand_R","parts":[["box", Vector3(0.12, 0.0, 0.0), Vector3(0.3, 0.34, 0.03), "2a7a4a", 0.0, Vector3.ZERO], ["box", Vector3(0.12, 0.04, 0.03), Vector3(0.12, 0.12, 0.03), "1a1a20", 0.0, Vector3.ZERO], ["box", Vector3(0.2, -0.08, 0.03), Vector3(0.03, 0.14, 0.015), "ffcf4a", 1.0, Vector3.ZERO]]},
	"ledger_pages":{"bone":"Torso","parts":[["box", Vector3(0.0, 0.55, -0.4), Vector3(0.03, 0.28, 0.2), "e8e0cc", 0.4, Vector3(12, 0, 18)], ["box", Vector3(0.1, 0.72, -0.3), Vector3(0.03, 0.28, 0.2), "e8e0cc", 0.4, Vector3(-8, 0, -10)], ["box", Vector3(0.05, 0.45, 0.42), Vector3(0.03, 0.28, 0.2), "e8e0cc", 0.4, Vector3(6, 0, 14)]]},
}

func _attach(kind: String, color: Color) -> void:
	var skeleton: Skeleton3D = nodes["Head"].get_parent() if nodes.has("Head") else null
	for node in nodes.values():
		if node is Skeleton3D and node.find_bone("Head") >= 0: skeleton = node
	if skeleton == null: return
	var mount := BoneAttachment3D.new()
	var kit: Dictionary = BOSS_EXTRAS.get(kind, {})
	mount.bone_name = kit.get("bone", "Torso" if kind == "wings" else "Head")
	skeleton.add_child(mount)
	# Rig faces +X; the head bone sits at the neck with the blocky head centred ~0.2 above it.
	var parts: Array = {
		"beard":[[SphereMesh, Vector3(0.21, 0.06, 0.0), Vector3(0.14, 0.2, 0.28)]],
		"hood":[[SphereMesh, Vector3(-0.03, 0.24, 0.0), Vector3(0.56, 0.56, 0.62)]],
		"visor":[[BoxMesh, Vector3(0.24, 0.21, 0.0), Vector3(0.05, 0.08, 0.42)]],
		"crown":[[CylinderMesh, Vector3(0.0, 0.47, 0.0), Vector3(0.36, 0.08, 0.36)], [PrismMesh, Vector3(0.0, 0.56, -0.12), Vector3(0.08, 0.16, 0.08)], [PrismMesh, Vector3(0.0, 0.56, 0.12), Vector3(0.08, 0.16, 0.08)], [PrismMesh, Vector3(0.0, 0.6, 0.0), Vector3(0.09, 0.22, 0.09)]],
		"wings":[[PrismMesh, Vector3(-0.22, 0.15, -0.28), Vector3(0.05, 0.6, 0.3)], [PrismMesh, Vector3(-0.22, 0.15, 0.28), Vector3(0.05, 0.6, 0.3)]],
	}.get(kind, kit.get("parts", []))
	var glow := 1.4 if kind in ["visor","wings","crown"] else 0.0
	for part in parts:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = {"box":BoxMesh,"sphere":SphereMesh,"cyl":CylinderMesh}[part[0]].new() if part[0] is String else part[0].new()
		mesh_instance.position = part[1]
		mesh_instance.scale = part[2]
		var tint := color if part.size() < 4 or part[3] == "" else Color(part[3])
		mesh_instance.material_override = Stage3D.toon(tint, glow if part.size() < 5 else part[4])
		if part.size() > 5: mesh_instance.rotation_degrees = part[5]
		mount.add_child(mesh_instance)
