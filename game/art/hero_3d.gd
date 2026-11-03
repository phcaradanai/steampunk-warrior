class_name Hero3D
extends SubViewportContainer
# Toon SD hero (prototypes/character-lab) rendered by an orthographic SubViewport for the 2.5D look.

const MODEL := preload("res://art/characters/vesper_warrior.glb")
const OUTLINE := Color("101b20")
const SUIT_COLORS := [Color("88583e"), Color("b48c4e"), Color("32526e")]
const LIMB_MESHES := ["UpperArm_R", "UpperArm_L", "ThighMesh_R", "ThighMesh_L"]
# Clip speed lifts the authored 1.5-1.7s actions into the combat pump's 0.36s turn rhythm.
const ACTIONS := {"attack":["Attack",1.7], "skill_stab":["Skill_Stab",1.6], "skill_steam":["Skill_Steam",1.6], "guard":["Guard",1.4], "hit":["Hit",1.5], "down":["Down",1.2], "vent":["Skill_Steam",1.6], "enter_pipe":["Enter_Pipe",1.4]}

var viewport: SubViewport
var model: Node3D
var animator: AnimationPlayer
var nodes: Dictionary = {}
var suit_material: StandardMaterial3D
var sparks: GPUParticles3D
var steam: GPUParticles3D
var facing_left: bool = false
var moving: bool = false
var down: bool = false
var busy: float = 0.0
var freeze: float = 0.0

func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8c6cc")
	environment.ambient_light_energy = 0.72
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -32, 0)
	key.light_color = Color("fff0d6")
	key.light_energy = 1.25
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 135, 0)
	fill.light_color = Color("75b8c8")
	fill.light_energy = 0.45
	viewport.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(0, 0.85, 10)
	viewport.add_child(camera)
	model = MODEL.instantiate()
	viewport.add_child(model)
	_index(model)
	nodes["TargetDummyRoot"].visible = false
	animator = model.get_node("AnimationPlayer")
	for clip in ["Idle", "Walk"]:
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animator.animation_finished.connect(func(_clip): busy = 0.0)
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
	var gear := variants(equipment, items)
	for i in 3:
		nodes["Weapon_%d" % i].visible = gear[0] == i
		nodes["Headgear_%d" % i].visible = gear[1] == i
		nodes["Suit_%d" % i].visible = gear[2] == i
	nodes["Shield_1"].visible = gear[3] == 1
	nodes["Shield_2"].visible = gear[3] == 2
	suit_material.albedo_color = SUIT_COLORS[gear[2]]

func perform(kind: String) -> void:
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

func hit_stop(seconds: float = 0.06) -> void:
	freeze = seconds

func _process(delta: float) -> void:
	model.rotation.y = deg_to_rad(-150.0 if facing_left else -30.0)
	sparks.position.x = -0.55 if facing_left else 0.55
	sparks.process_material.direction.x = -1.0 if facing_left else 1.0
	freeze = maxf(0.0, freeze - delta)
	animator.speed_scale = 0.0 if freeze > 0.0 else 1.0
	if busy > 0.0 or down: return
	var loop := "Walk" if moving else "Idle"
	if animator.current_animation != loop: animator.play(loop, 0.12)
