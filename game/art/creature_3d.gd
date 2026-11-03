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
# Boss phase overlays (set_phase): -1 until first applied; only the B06 mantis has any.
var phase: int = -1
var fx: Node3D
var _emissives: Array = []
var _plates: Array = []
var _smoke: CPUParticles3D
var _smoke_on := false
var _light: OmniLight3D
var _halo: MeshInstance3D
var _core: Node3D
var _rim: Node3D
var _extent := Vector2.ZERO
var _extent_left := false
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
			if source.emission_enabled: _emissives.append([node, surface, color, source.emission_energy_multiplier])
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
	set_phase(0)

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

# ---------------------------------------------------------------- boss phases
# B06: bio-armour (green crystal shell) -> smoke (broken shell, dark aether haze, dim glow) -> open core (armour gone, bright thorax core).
const PHASE_GLOW := [1.0, 0.4, 2.4]
const PHASE_LIGHT := [[Color("6fe08a"), 0.7], [Color("4a3a6a"), 0.25], [Color("ffe6a0"), 2.6]]

func set_phase(n: int) -> void:
	if kind != "mantis" or n == phase: return
	var changed := phase >= 0
	phase = clampi(n, 0, 2)
	if fx == null: _build_phase_fx()
	for shard in _plates:
		shard.visible = phase < 2
		shard.material_override = Stage3D.toon(Color("2fc06a") if phase == 0 else Color("3a2f4a"), 0.9 if phase == 0 else 0.15)
		shard.scale = shard.get_meta("rest") * (1.0 if phase == 0 else 0.55)
	for entry in _emissives:
		var color: Color = entry[2].lerp(Color.WHITE, 0.4) if phase == 2 else entry[2]
		entry[0].set_surface_override_material(entry[1], Stage3D.toon(color, entry[3] * PHASE_GLOW[phase]))
	_core.visible = phase == 2
	_rim.visible = phase == 2
	_halo.visible = phase == 2
	_smoke_on = phase == 1
	_light.light_color = PHASE_LIGHT[phase][0]
	_light.light_energy = PHASE_LIGHT[phase][1]
	if changed and is_inside_tree(): _burst()

func _build_phase_fx() -> void:
	fx = Node3D.new()
	body.add_child(fx)
	_core = body.find_child("Core", true, false)
	_rim = body.find_child("Core_Rim", true, false)
	var center: Vector3 = _core.mesh.get_aabb().get_center()
	# Armour shards ride the dorsal ridge, over the thorax core and on the flanks.
	var spots: Array = [Vector3(0.3, 0.8, 0), Vector3(0.2, 0.76, 0.1), Vector3(0.2, 0.76, -0.1), Vector3(-0.1, 0.7, 0)]
	for x in [-0.29, -0.5, -0.67, -0.89, -1.06]: spots.append(Vector3(x, 0.72 - (absf(x) - 0.3) * 0.12, 0))
	for x in [-0.4, -0.8]:
		spots.append(Vector3(x, 0.66, 0.17))
		spots.append(Vector3(x, 0.66, -0.17))
	for spot in spots:
		var rest := Vector3(0.08, 0.2 - maxf(0.0, -spot.x - 0.3) * 0.08, 0.08)
		var shard := _part(fx, PrismMesh.new(), spot + Vector3(0, rest.y * 0.45, 0), rest, Color("2fc06a"), 0.9, Vector3(0, 0, randf_range(-14, 14)))
		shard.set_meta("rest", rest)
		_plates.append(shard)
	_halo = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.19
	sphere.height = 0.38
	_halo.mesh = sphere
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(1.0, 0.85, 0.45, 0.55)
	_halo.material_override = glow
	_halo.position = center
	_core.get_parent().add_child(_halo)
	_light = OmniLight3D.new()
	_light.position = center + Vector3(0, 0.15, 0.25)
	_light.omni_range = 2.5
	fx.add_child(_light)
	_smoke = CPUParticles3D.new()
	var puff := QuadMesh.new()
	puff.size = Vector2(0.5, 0.5)
	var haze := StandardMaterial3D.new()
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	haze.vertex_color_use_as_albedo = true
	haze.albedo_texture = _soft_dot()
	puff.material = haze
	_smoke.mesh = puff
	_smoke.position = Vector3(-0.25, 0.55, 0)
	_smoke.amount = 36
	_smoke.lifetime = 2.4
	_smoke.preprocess = 2.4
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = 0.7
	_smoke.direction = Vector3.UP
	_smoke.spread = 25.0
	_smoke.initial_velocity_min = 0.1
	_smoke.initial_velocity_max = 0.3
	_smoke.gravity = Vector3(0.05, 0.12, 0)
	_smoke.scale_amount_min = 0.8
	_smoke.scale_amount_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(0.16, 0.1, 0.24, 0.0))
	fade.set_color(1, Color(0.1, 0.07, 0.16, 0.0))
	fade.add_point(0.3, Color(0.1, 0.06, 0.16, 0.75))
	_smoke.color_ramp = fade
	_smoke.emitting = false
	fx.add_child(_smoke)

func _soft_dot() -> Texture2D:
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture

# Short radial spray on every phase change, tinted by the phase being entered.
func _burst() -> void:
	var spray := CPUParticles3D.new()
	var mote := SphereMesh.new()
	mote.radius = 0.05
	mote.height = 0.1
	var tint := StandardMaterial3D.new()
	tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tint.albedo_color = [Color("9cffb0"), Color("a58ad0"), Color("fff0b0")][phase]
	mote.material = tint
	spray.mesh = mote
	spray.position = Vector3(0.1, 0.65, 0)
	spray.one_shot = true
	spray.explosiveness = 1.0
	spray.amount = 40
	spray.lifetime = 0.7
	spray.spread = 180.0
	spray.direction = Vector3.UP
	spray.initial_velocity_min = 1.0
	spray.initial_velocity_max = 2.6
	spray.gravity = Vector3.ZERO
	fx.add_child(spray)
	spray.emitting = true
	get_tree().create_timer(1.2).timeout.connect(spray.queue_free)

# Horizontal screen extent of the figure's meshes, in world units from the model origin (the camera looks straight down -Z, so world x is screen x).
func extent_x() -> Vector2:
	if _extent != Vector2.ZERO and _extent_left == facing_left: return _extent
	var turn := Transform3D(Basis(Vector3.UP, deg_to_rad(-150.0 if facing_left else -30.0)), Vector3.ZERO) * model.global_transform.affine_inverse()
	var low := INF
	var high := -INF
	for node in body.find_children("*", "MeshInstance3D", true, false):
		if fx != null and (fx.is_ancestor_of(node) or node == _halo): continue
		var box: AABB = (turn * node.global_transform) * node.mesh.get_aabb()
		low = minf(low, box.position.x)
		high = maxf(high, box.end.x)
	if low > high: return Vector2(-0.5, 0.5)
	_extent = Vector2(low, high)
	_extent_left = facing_left
	return _extent

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
	# Particle emission needs the tree, so it follows the phase from here rather than from set_phase.
	if _smoke != null and _smoke.emitting != _smoke_on: _smoke.emitting = _smoke_on
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
