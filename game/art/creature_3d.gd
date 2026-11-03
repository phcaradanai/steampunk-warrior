class_name Creature3D
extends Stage3D
# Mutants and world props built from toon primitives and animated in code, matching the hero's outline style.
# Mutants N01-N09, bosses B01/B03/B06 and the root summon are Blender GLBs (prototypes/character-lab/blender/build_<kind>.py) whose named pivots the same code animates.
# Local axes before the facing turn: +X is forward, +Y up, +Z toward the viewer.

var kind: String = ""
var palette: Dictionary = {}
var model: Node3D
var body: Node3D
var legs: Array[Node3D] = []
var wings: Array[Node3D] = []
var tail: Node3D
var head: Node3D
var clock: float = 0.0
var action: String = ""
var action_time: float = 0.0
var hover: float = 0.0
const STRIKE := 0.8
const STRIKE_CONTACT := 0.48
const RAT := preload("res://art/characters/rat.glb")
const DOG := preload("res://art/characters/dog.glb")
const BAT := preload("res://art/characters/bat.glb")
const CENTIPEDE := preload("res://art/characters/centipede.glb")
const BEETLE := preload("res://art/characters/beetle.glb")
const SPIDER := preload("res://art/characters/spider.glb")
const BOAR := preload("res://art/characters/boar.glb")
const HERON := preload("res://art/characters/heron.glb")
const WOLF := preload("res://art/characters/wolf.glb")
const CROC := preload("res://art/characters/croc.glb")
const DEER := preload("res://art/characters/deer.glb")
const SPROUT := preload("res://art/characters/sprout.glb")
const MANTIS := preload("res://art/characters/mantis.glb")

func build(creature: String, colors: Dictionary) -> Creature3D:
	kind = creature
	palette = colors
	model = Node3D.new()
	viewport.add_child(model)
	body = Node3D.new()
	model.add_child(body)
	call("_build_" + kind)
	return self

func _color(key: String, fallback: String) -> Color:
	return Color(palette.get(key, fallback))

func _part(parent: Node3D, mesh: Mesh, at: Vector3, scale_by: Vector3, color: Color, glow: float = 0.0, rotate_by: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.scale = scale_by
	instance.rotation_degrees = rotate_by
	instance.material_override = Stage3D.toon(color, glow)
	parent.add_child(instance)
	return instance

func _blob(parent: Node3D, at: Vector3, scale_by: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	return _part(parent, SphereMesh.new(), at, scale_by, color, glow)

# A limb hangs from a pivot at its joint so swinging the pivot swings the whole leg.
func _limb(parent: Node3D, joint: Vector3, length: float, radius: float, color: Color, tilt: Vector3 = Vector3.ZERO) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = joint
	pivot.rotation_degrees = tilt
	parent.add_child(pivot)
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = maxf(length, radius * 2.0)
	_part(pivot, capsule, Vector3(0, -length * 0.5, 0), Vector3.ONE, color)
	legs.append(pivot)
	return pivot

func _crystal(parent: Node3D, at: Vector3, height: float, color: Color, lean: float = 0.0) -> void:
	_part(parent, PrismMesh.new(), at, Vector3(height * 0.35, height, height * 0.35), color, 1.6, Vector3(0, 0, lean))

func _quad_legs(length: float, radius: float, spread_x: float, spread_z: float, top: float, color: Color) -> void:
	for x in [spread_x, -spread_x]:
		for z in [spread_z, -spread_z]:
			_limb(body, Vector3(x, top, z), length, radius, color)

# ---------------------------------------------------------------- mutants
func _build_rat() -> void:
	_load_figure(RAT)

# Blender-built mutant (prototypes/character-lab/blender/build_<kind>.py): toon every surface, then pick up
# the identity-rotation pivots by name so the procedural gait above drives them.
func _load_figure(scene: PackedScene) -> void:
	var figure := scene.instantiate()
	body.add_child(figure)
	# Palette variants (N24 off the wolf, N25 off the heron): "fur" recolours every surface sharing the
	# Body mesh's material, "glow" recolours every emissive surface.
	var hide_name := ""
	var main := figure.find_child("Body") as MeshInstance3D
	if main != null and main.get_active_material(0) != null: hide_name = main.get_active_material(0).resource_name
	for node in figure.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var source := node.get_active_material(surface) as BaseMaterial3D
			if source == null: continue
			var color := source.albedo_color
			if source.emission_enabled and palette.has("glow"): color = Color(palette.glow)
			elif source.resource_name == hide_name and palette.has("fur"): color = Color(palette.fur)
			node.set_surface_override_material(surface, Stage3D.toon(color, source.emission_energy_multiplier if source.emission_enabled else 0.0))
	head = figure.find_child("Head")
	tail = figure.find_child("Tail")
	for leg in ["Leg_FL", "Leg_FR", "Leg_HR", "Leg_HL"]:
		if figure.find_child(leg): legs.append(figure.find_child(leg))
	# Many-legged figures name legs Leg_<segment><a|b>, already ordered so the alternating swing ripples.
	if legs.is_empty():
		for leg in figure.find_children("Leg_*", "", true, false):
			if not leg.get_parent().name.begins_with("Leg_"): legs.append(leg)
	for wing in ["Wing_N", "Wing_F"]:
		if figure.find_child(wing): wings.append(figure.find_child(wing))

func _build_dog() -> void:
	_load_figure(DOG)

func _build_wolf() -> void:
	_load_figure(WOLF)

func _build_boar() -> void:
	_load_figure(BOAR)

func _build_croc() -> void:
	_load_figure(CROC)

func _build_deer() -> void:
	_load_figure(DEER)

func _build_mantis() -> void:
	_load_figure(MANTIS)

func _build_bat() -> void:
	# Lower than the old 0.9 so the raised wings stay inside the camera frame.
	hover = 0.45
	_load_figure(BAT)

func _build_centipede() -> void:
	_load_figure(CENTIPEDE)

func _build_beetle() -> void:
	_load_figure(BEETLE)

func _build_spider() -> void:
	_load_figure(SPIDER)

func _build_heron() -> void:
	_load_figure(HERON)

func _build_sprout() -> void:
	_load_figure(SPROUT)

# ---------------------------------------------------------------- world props
func _build_bed() -> void:
	_part(body, BoxMesh.new(), Vector3(0, 0.25, 0), Vector3(1.4, 0.3, 0.7), Color("8a6a40"))
	_part(body, BoxMesh.new(), Vector3(0, 0.45, 0), Vector3(1.3, 0.12, 0.62), Color("3f7a70"))
	_part(body, BoxMesh.new(), Vector3(-0.48, 0.55, 0), Vector3(0.3, 0.12, 0.5), Color("e8e0c8"))
	_part(body, BoxMesh.new(), Vector3(-0.7, 0.55, 0), Vector3(0.08, 0.7, 0.7), Color("6a4a2a"))

func _build_cart() -> void:
	_part(body, BoxMesh.new(), Vector3(0, 0.55, 0), Vector3(1.1, 0.5, 0.6), Color("8a6a40"))
	_part(body, BoxMesh.new(), Vector3(0, 1.25, 0), Vector3(1.3, 0.08, 0.8), Color("3f8a80"))
	for x in [-0.5, 0.5]: _part(body, CylinderMesh.new(), Vector3(x, 0.95, 0.3), Vector3(0.04, 0.6, 0.04), Color("2a2a2a"))
	for x in [-0.35, 0.35]: _part(body, CylinderMesh.new(), Vector3(x, 0.22, 0.32), Vector3(0.44, 0.06, 0.44), Color("2a3436"), 0.0, Vector3(90, 0, 0))
	for i in 3: _blob(body, Vector3(-0.3 + i * 0.3, 0.88, 0), Vector3(0.22, 0.22, 0.22), [Color("c9a24a"), Color("8fd0c0"), Color("d07050")][i])

func _build_crate() -> void:
	_part(body, BoxMesh.new(), Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6), Color("9a7240"))
	_part(body, BoxMesh.new(), Vector3(0, 0.3, 0.31), Vector3(0.62, 0.1, 0.02), Color("5a4024"))
	_crystal(body, Vector3(0, 0.82, 0), 0.24, _color("glow", "f6d98f"))

# ---------------------------------------------------------------- motion
func perform(name: String) -> void:
	if down: return
	if name == "down": down = true
	action = name
	action_time = 0.0
	busy = 1.0

func _process(delta: float) -> void:
	super(delta)
	model.rotation.y = deg_to_rad(-150.0 if facing_left else -30.0)
	if freeze > 0.0:
		freeze -= delta
		return
	clock += delta
	action_time += delta
	var go := moving or running
	var stride := sin(clock * (13.0 if running else 11.0 if moving else 2.2))
	for i in legs.size():
		legs[i].rotation_degrees.z = stride * (28.0 if go else 3.0) * (1 if i % 2 == 0 else -1)
	for i in wings.size():
		wings[i].rotation_degrees.x = sin(clock * 14.0) * 35.0 * (1 if i % 2 == 0 else -1)
	if tail != null: tail.rotation_degrees.y = sin(clock * 3.0) * 20.0
	body.position = Vector3(0, hover + sin(clock * 2.2) * 0.02 + (absf(stride) * 0.04 if go else 0.0), 0)
	body.scale = Vector3(1, 1 + sin(clock * 2.2) * 0.02, 1)
	body.rotation = Vector3.ZERO
	match action:
		"attack", "skill_stab", "skill_steam":
			# Rear back, snap forward to land at STRIKE_CONTACT, then ease home.
			var t := action_time / STRIKE
			var reach: float
			if t < 0.5: reach = -0.16 * (t / 0.5)
			elif t < 0.6: reach = lerpf(-0.16, 0.34, (t - 0.5) / 0.1)
			else: reach = lerpf(0.34, 0.0, minf(1.0, (t - 0.6) / 0.4))
			body.position.x += reach
			body.rotation.z = deg_to_rad(-reach * 45.0)
			if t >= 1.0: _settle()
		"hit", "guard":
			var t := action_time / 0.35
			body.position.x -= 0.14 * sin(minf(1.0, t) * PI)
			body.rotation.z = deg_to_rad(12.0 * sin(minf(1.0, t) * PI))
			if t >= 1.0: _settle()
		"down":
			var t := minf(1.0, action_time / 0.5)
			body.rotation.x = deg_to_rad(80.0 * t)
			body.position.y = lerpf(hover, 0.0, t)

func strike_timing(_kind: String) -> Vector2:
	return Vector2(STRIKE_CONTACT, 0.2)

var _top := -1.0

func top_fraction() -> float:
	if _top < 0.0:
		var highest := 0.0
		for node in model.find_children("*","MeshInstance3D",true,false):
			var box: AABB = (model.global_transform.affine_inverse() * node.global_transform) * node.mesh.get_aabb()
			highest = maxf(highest, box.end.y)
		# Camera frames model y from -0.15 to 1.85.
		_top = clampf(1.0 - (highest + hover + 0.15) / 2.0, 0.0, 0.9)
	return _top

func end_action() -> void:
	_settle()

func _settle() -> void:
	action = ""
	busy = 0.0
