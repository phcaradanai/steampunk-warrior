class_name Creature3D
extends Stage3D
# Mutants and world props built from toon primitives and animated in code, matching the hero's outline style.
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
	var fur := _color("fur", "8a7a72")
	_blob(body, Vector3(0, 0.36, 0), Vector3(0.8, 0.46, 0.46), fur)
	head = Node3D.new(); head.position = Vector3(0.45, 0.42, 0); body.add_child(head)
	_blob(head, Vector3.ZERO, Vector3(0.36, 0.3, 0.3), fur)
	_part(head, PrismMesh.new(), Vector3(0.2, -0.02, 0), Vector3(0.16, 0.22, 0.16), Color("d89a9a"), 0.0, Vector3(0, 0, -90))
	for z in [0.11, -0.11]: _part(head, CylinderMesh.new(), Vector3(-0.04, 0.17, z), Vector3(0.14, 0.02, 0.14), Color("d89a9a"), 0.0, Vector3(90, 0, 0))
	_blob(head, Vector3(0.13, 0.06, 0.12), Vector3(0.05, 0.05, 0.05), Color("1a1010"))
	_quad_legs(0.2, 0.05, 0.22, 0.16, 0.2, Color("d89a9a"))
	tail = _limb(body, Vector3(-0.4, 0.3, 0), 0.7, 0.03, Color("d89a9a"), Vector3(0, 0, -70))
	legs.erase(tail)
	_part(body, BoxMesh.new(), Vector3(-0.05, 0.6, 0), Vector3(0.42, 0.12, 0.36), _color("brass", "b07a35"))
	for i in 3: _crystal(body, Vector3(-0.15 + i * 0.12, 0.76, 0.0), 0.24, _color("glow", "39d98a"), -10 + i * 10)

func _build_dog() -> void:
	var fur := _color("fur", "4a4a50")
	_blob(body, Vector3(0, 0.62, 0), Vector3(0.85, 0.42, 0.4), fur)
	head = Node3D.new(); head.position = Vector3(0.5, 0.85, 0); body.add_child(head)
	_blob(head, Vector3.ZERO, Vector3(0.34, 0.3, 0.3), fur)
	_blob(head, Vector3(0.18, -0.06, 0), Vector3(0.22, 0.14, 0.16), fur.darkened(0.2))
	for z in [0.1, -0.1]:
		_part(head, PrismMesh.new(), Vector3(-0.05, 0.2, z), Vector3(0.08, 0.16, 0.06), fur.darkened(0.3))
		_blob(head, Vector3(0.12, 0.06, z * 1.2), Vector3(0.05, 0.05, 0.05), _color("glow", "ff8a3a"), 3.0)
	_quad_legs(0.42, 0.06, 0.26, 0.14, 0.48, fur.darkened(0.15))
	tail = _limb(body, Vector3(-0.42, 0.72, 0), 0.4, 0.05, fur, Vector3(0, 0, -120))
	legs.erase(tail)
	for i in 3: _blob(body, Vector3(-0.2 + i * 0.2, 0.92, 0), Vector3(0.18, 0.12, 0.18), Color(0.55, 0.55, 0.58), 0.3)

func _build_wolf() -> void:
	_build_dog()
	for i in 4:
		_part(body, CylinderMesh.new(), Vector3(-0.25 + i * 0.15, 0.95, 0.05 * (i % 2)), Vector3(0.05, 0.28, 0.05), Color("6b4a2a"), 0.0, Vector3(0, 0, -25 + i * 12))
	_crystal(body, Vector3(0.0, 1.05, 0), 0.18, _color("glow", "7cf08a"))

func _build_boar() -> void:
	var hide := _color("fur", "3a2e2a")
	_blob(body, Vector3(0, 0.55, 0), Vector3(0.95, 0.6, 0.55), hide)
	head = Node3D.new(); head.position = Vector3(0.52, 0.55, 0); body.add_child(head)
	_blob(head, Vector3.ZERO, Vector3(0.42, 0.4, 0.38), hide)
	_part(head, CylinderMesh.new(), Vector3(0.22, -0.05, 0), Vector3(0.18, 0.08, 0.18), Color("8a6a60"), 0.0, Vector3(0, 0, 90))
	for z in [0.1, -0.1]: _part(head, PrismMesh.new(), Vector3(0.2, 0.04, z), Vector3(0.05, 0.18, 0.05), Color("f2ead8"), 0.0, Vector3(0, 0, -40))
	_quad_legs(0.28, 0.08, 0.3, 0.18, 0.32, hide.darkened(0.2))
	for i in 5: _blob(body, Vector3(-0.35 + i * 0.16, 0.86, 0.12 * ((i % 2) * 2 - 1)), Vector3(0.08, 0.05, 0.08), _color("glow", "ff7a2a"), 3.0)

func _build_croc() -> void:
	var scale_skin := _color("fur", "4d6b3a")
	_blob(body, Vector3(0, 0.3, 0), Vector3(1.3, 0.34, 0.5), scale_skin)
	head = Node3D.new(); head.position = Vector3(0.72, 0.3, 0); body.add_child(head)
	_part(head, BoxMesh.new(), Vector3(0.2, 0, 0), Vector3(0.55, 0.16, 0.3), scale_skin)
	_part(head, BoxMesh.new(), Vector3(0.18, -0.1, 0), Vector3(0.5, 0.06, 0.28), scale_skin.lightened(0.15))
	for z in [0.1, -0.1]: _blob(head, Vector3(0.02, 0.1, z), Vector3(0.08, 0.08, 0.08), _color("glow", "ffcf4a"), 2.0)
	_quad_legs(0.18, 0.07, 0.4, 0.22, 0.2, scale_skin.darkened(0.2))
	tail = _limb(body, Vector3(-0.62, 0.3, 0), 0.7, 0.12, scale_skin, Vector3(0, 0, -80))
	legs.erase(tail)
	_part(body, CylinderMesh.new(), Vector3(-0.05, 0.62, 0), Vector3(0.55, 0.3, 0.55), _color("brass", "b5652e"), 0.0, Vector3(0, 0, 90))
	_part(body, CylinderMesh.new(), Vector3(-0.15, 0.85, 0), Vector3(0.1, 0.3, 0.1), Color("2a2a2a"))

func _build_deer() -> void:
	var hide := _color("fur", "9a7a52")
	_blob(body, Vector3(0, 0.95, 0), Vector3(0.8, 0.42, 0.38), hide)
	var neck := _limb(body, Vector3(0.32, 1.05, 0), 0.4, 0.07, hide, Vector3(0, 0, 150))
	legs.erase(neck)
	head = Node3D.new(); head.position = Vector3(0.52, 1.4, 0); body.add_child(head)
	_blob(head, Vector3.ZERO, Vector3(0.26, 0.2, 0.2), hide)
	for z in [0.08, -0.08]:
		for i in 3: _crystal(head, Vector3(-0.05 + i * 0.04, 0.2 + i * 0.1, z), 0.22, _color("glow", "7fe8ff"), 20 - i * 20)
	_quad_legs(0.7, 0.05, 0.28, 0.12, 0.8, hide.darkened(0.25))

func _build_bat() -> void:
	hover = 0.9
	var skin := _color("fur", "4a3a5a")
	_blob(body, Vector3(0, 0.0, 0), Vector3(0.36, 0.42, 0.32), skin)
	head = Node3D.new(); head.position = Vector3(0.12, 0.22, 0); body.add_child(head)
	_blob(head, Vector3.ZERO, Vector3(0.26, 0.22, 0.24), skin)
	for z in [0.07, -0.07]:
		_part(head, PrismMesh.new(), Vector3(-0.02, 0.17, z), Vector3(0.07, 0.16, 0.04), skin.darkened(0.2))
		_blob(head, Vector3(0.1, 0.03, z), Vector3(0.04, 0.04, 0.04), _color("glow", "c27bff"), 3.0)
	for z in [1.0, -1.0]:
		var wing := Node3D.new(); wing.position = Vector3(0, 0.05, 0.12 * z); body.add_child(wing)
		_part(wing, PrismMesh.new(), Vector3(0, 0, 0.35 * z), Vector3(0.5, 0.04, 0.6), skin.lightened(0.1), 0.0, Vector3(90 * z, 0, 0))
		wings.append(wing)

func _build_centipede() -> void:
	var shell := _color("fur", "b06a3a")
	for i in 6:
		var x := 0.5 - i * 0.2
		_blob(body, Vector3(x, 0.24, 0), Vector3(0.26, 0.22, 0.3), shell if i % 2 == 0 else shell.darkened(0.15))
		for z in [0.16, -0.16]: _limb(body, Vector3(x, 0.18, z), 0.18, 0.025, shell.darkened(0.3), Vector3(70 * signf(z), 0, 0))
	head = Node3D.new(); head.position = Vector3(0.66, 0.26, 0); body.add_child(head)
	_blob(head, Vector3.ZERO, Vector3(0.24, 0.2, 0.26), shell.lightened(0.1))
	for z in [0.07, -0.07]: _part(head, PrismMesh.new(), Vector3(0.14, -0.02, z), Vector3(0.05, 0.16, 0.04), Color("f0d080"), 0.0, Vector3(0, 0, -100))

func _build_beetle() -> void:
	var shell := _color("fur", "2f6b55")
	_blob(body, Vector3(0, 0.4, 0), Vector3(0.9, 0.5, 0.66), shell)
	_part(body, BoxMesh.new(), Vector3(0, 0.62, 0), Vector3(0.7, 0.04, 0.02), _color("brass", "c9a24a"), 0.4)
	head = Node3D.new(); head.position = Vector3(0.45, 0.36, 0); body.add_child(head)
	_blob(head, Vector3.ZERO, Vector3(0.26, 0.22, 0.3), shell.darkened(0.3))
	_part(head, PrismMesh.new(), Vector3(0.12, 0.18, 0), Vector3(0.08, 0.3, 0.08), _color("brass", "c9a24a"), 0.0, Vector3(0, 0, -30))
	for x in [0.2, 0.0, -0.2]:
		for z in [0.28, -0.28]: _limb(body, Vector3(x, 0.3, z), 0.3, 0.035, Color("1e2a26"), Vector3(55 * signf(z), 0, 0))

func _build_spider() -> void:
	var glass := _color("fur", "8fe0f0")
	_blob(body, Vector3(-0.25, 0.55, 0), Vector3(0.6, 0.5, 0.55), glass, 0.5)
	_blob(body, Vector3(0.2, 0.5, 0), Vector3(0.32, 0.28, 0.3), glass.darkened(0.3))
	head = body
	for i in 4:
		for z in [1.0, -1.0]:
			var pivot := _limb(body, Vector3(0.25 - i * 0.14, 0.52, 0.12 * z), 0.6, 0.025, Color("2a3a40"), Vector3(70 * z, 0, -20 + i * 15))
			pivot.rotation_degrees.x = 60 * z
	_crystal(body, Vector3(-0.25, 0.85, 0), 0.2, glass)

func _build_heron() -> void:
	hover = 0.0
	var plume := _color("fur", "c8d8b8")
	_blob(body, Vector3(0, 1.05, 0), Vector3(0.6, 0.36, 0.34), plume)
	for z in [0.08, -0.08]: _limb(body, Vector3(0, 0.9, z), 0.9, 0.025, Color("d9a040"))
	var neck := _limb(body, Vector3(0.25, 1.15, 0), 0.45, 0.05, plume, Vector3(0, 0, 160))
	legs.erase(neck)
	head = Node3D.new(); head.position = Vector3(0.38, 1.58, 0); body.add_child(head)
	_blob(head, Vector3.ZERO, Vector3(0.18, 0.15, 0.15), plume)
	_part(head, PrismMesh.new(), Vector3(0.2, -0.02, 0), Vector3(0.06, 0.32, 0.06), _color("glow", "b7f04a"), 1.0, Vector3(0, 0, -95))
	for z in [1.0, -1.0]:
		var wing := Node3D.new(); wing.position = Vector3(-0.05, 1.12, 0.16 * z); body.add_child(wing)
		_part(wing, PrismMesh.new(), Vector3(-0.15, 0, 0), Vector3(0.5, 0.05, 0.3), plume.darkened(0.15), 0.0, Vector3(90 * z, 0, 0))
		wings.append(wing)

func _build_sprout() -> void:
	_part(body, CylinderMesh.new(), Vector3(0, 0.3, 0), Vector3(0.1, 0.6, 0.1), Color("6b4a2a"))
	for i in 3:
		_part(body, PrismMesh.new(), Vector3(0.0, 0.4 + i * 0.12, 0.0), Vector3(0.3, 0.05, 0.12), Color("4caf50"), 0.0, Vector3(90, i * 60, 0))
	_crystal(body, Vector3(0, 0.75, 0), 0.32, _color("glow", "7fe8ff"))
	head = body

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

func end_action() -> void:
	_settle()

func _settle() -> void:
	action = ""
	busy = 0.0
