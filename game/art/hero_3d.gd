class_name Hero3D
extends Stage3D
# Toon SD hero (prototypes/character-lab) rendered by an orthographic SubViewport for the 2.5D look.

const MODEL := preload("res://art/characters/vesper_warrior.glb")
const OUTLINE := Color("101b20")
const SUIT_COLORS := [Color("88583e"), Color("b48c4e"), Color("32526e")]
const LIMB_MESHES := ["UpperArm_R", "UpperArm_L", "ThighMesh_R", "ThighMesh_L"]
# Clip speed lifts the authored 1.5-1.7s actions into the combat pump's 0.36s turn rhythm.
const ACTIONS := {"attack":["Attack",1.15], "skill_stab":["Skill_Stab",1.1], "skill_steam":["Skill_Steam",1.1], "guard":["Guard",1.2], "hit":["Hit",1.25], "down":["Down",1.0], "vent":["Skill_Steam",1.1], "enter_pipe":["Enter_Pipe",1.4]}
# Clip time where the blade or nozzle reaches full extension, read from the Shoulder_R rotation peaks.
const CONTACT := {"Attack":0.92, "Skill_Stab":0.85, "Skill_Steam":0.84}

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

static func variants(equipment: Dictionary, items: Array) -> Array:
	# shortcut: the model has 3 meshes per slot, so 62 items share them by name family; add meshes to split guns/spears.
	var names := {}
	for item in items:
		if equipment.values().has(item.id): names[item.slot] = [item.name, int(item.tier)]
	var weapon: String = names.get("weapon", [""])[0]
	var head: String = names.get("head", [""])[0]
	var suit: String = names.get("suit", [""])[0]
	return [
		1 if _has_any(weapon, ["ค้อน", "กระบอง", "ประแจ", "ขวาน"]) else 0 if weapon.is_empty() or _has_any(weapon, ["ดาบ", "มีด", "เคียว", "เลื่อย", "กรงเล็บ"]) else 2,
		1 if head.contains("หมวก") else 2 if _has_any(head, ["หน้ากาก", "กระบัง"]) else 0,
		1 if suit.contains("เกราะ") else 2 if suit.begins_with("ชุด") else 0,
		0 if not names.has("shield") else 1 if names.shield[1] <= 2 else 2]

static func _has_any(text: String, words: Array) -> bool:
	return words.any(func(word): return text.contains(word))

func set_equipment(equipment: Dictionary, items: Array) -> void:
	_show_gear(variants(equipment, items))

func _show_gear(gear: Array) -> void:
	for i in 3:
		nodes["Weapon_%d" % i].visible = gear[0] == i
		nodes["Headgear_%d" % i].visible = gear[1] == i
		nodes["Suit_%d" % i].visible = gear[2] == i
	nodes["Shield_1"].visible = gear[3] == 1
	nodes["Shield_2"].visible = gear[3] == 2
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
	if kind in ["attack", "skill_stab"]: _burst(sparks, 0.12)
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

func _attach(kind: String, color: Color) -> void:
	var skeleton: Skeleton3D = nodes["Head"].get_parent() if nodes.has("Head") else null
	for node in nodes.values():
		if node is Skeleton3D and node.find_bone("Head") >= 0: skeleton = node
	if skeleton == null: return
	var mount := BoneAttachment3D.new()
	mount.bone_name = "Torso" if kind == "wings" else "Head"
	skeleton.add_child(mount)
	# Rig faces +X; the head bone sits at the neck with the blocky head centred ~0.2 above it.
	var parts: Array = {
		"beard":[[SphereMesh, Vector3(0.21, 0.06, 0.0), Vector3(0.14, 0.2, 0.28)]],
		"hood":[[SphereMesh, Vector3(-0.03, 0.24, 0.0), Vector3(0.56, 0.56, 0.62)]],
		"visor":[[BoxMesh, Vector3(0.24, 0.21, 0.0), Vector3(0.05, 0.08, 0.42)]],
		"crown":[[CylinderMesh, Vector3(0.0, 0.47, 0.0), Vector3(0.36, 0.08, 0.36)], [PrismMesh, Vector3(0.0, 0.56, -0.12), Vector3(0.08, 0.16, 0.08)], [PrismMesh, Vector3(0.0, 0.56, 0.12), Vector3(0.08, 0.16, 0.08)], [PrismMesh, Vector3(0.0, 0.6, 0.0), Vector3(0.09, 0.22, 0.09)]],
		"wings":[[PrismMesh, Vector3(-0.22, 0.15, -0.28), Vector3(0.05, 0.6, 0.3)], [PrismMesh, Vector3(-0.22, 0.15, 0.28), Vector3(0.05, 0.6, 0.3)]],
	}.get(kind, [])
	var glow := 1.4 if kind in ["visor","wings","crown"] else 0.0
	for part in parts:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = part[0].new()
		mesh_instance.position = part[1]
		mesh_instance.scale = part[2]
		mesh_instance.material_override = Stage3D.toon(color, glow)
		mount.add_child(mesh_instance)
