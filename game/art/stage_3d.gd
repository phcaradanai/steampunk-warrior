class_name Stage3D
extends Control
# One toon-lit 3D figure in its own orthographic viewport, drawn into a 2D Control at physical resolution.

var viewport: SubViewport
var camera: Camera3D
var facing_left: bool = false
var moving: bool = false
var running: bool = false
var walk_speed: float = 1.0
var down: bool = false
var busy: float = 0.0
var freeze: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(0, 0.85, 10)
	viewport.add_child(camera)

# Render at physical pixels (window stretch x canvas scale) so the figure stays crisp on retina and when scaled up.
func _sync_resolution() -> void:
	if not is_inside_tree(): return
	var oversample := clampf(get_global_transform_with_canvas().get_scale().x * get_viewport().get_final_transform().get_scale().x, 2.0, 4.0)
	var target := Vector2i((size * oversample).round())
	if target.x > 0 and target.y > 0 and viewport.size != target:
		viewport.size = target

func _draw() -> void:
	draw_texture_rect(viewport.get_texture(), Rect2(Vector2.ZERO, size), false)

func _process(_delta: float) -> void:
	_sync_resolution()
	queue_redraw()

# Height of the figure's top as a fraction of the control, measured from the top edge (for markers above heads).
func top_fraction() -> float:
	return 0.1

func perform(_kind: String) -> void:
	pass

# Seconds from starting a strike to the blow landing, and from landing to the end of the follow-through.
func strike_timing(_kind: String) -> Vector2:
	return Vector2(0.3, 0.2)

# Drop whatever one-shot is playing so locomotion takes over (stepping back after a strike).
func end_action() -> void:
	busy = 0.0

func hit_stop(seconds: float = 0.06) -> void:
	freeze = seconds

func set_equipment(_equipment: Dictionary, _items: Array) -> void:
	pass

static func toon(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.albedo_color = Color("101b20")
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 0.012
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_TOON
	material.roughness = 0.55
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	material.next_pass = outline
	return material
