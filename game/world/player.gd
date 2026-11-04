class_name SteamPlayer
extends CharacterBody2D

var blocked: bool = false
var facing := Vector2.RIGHT
var class_id: String = "C01"
var hero: Hero3D
var depth_scaled: bool = false

func _init() -> void:
	hero = Hero3D.new()
	hero.size = Vector2(96, 96)
	# Faster walk needs a faster stride so feet don't slide.
	hero.walk_speed = 1.6
	hero.position = Vector2(-48, 22 - 96)
	hero.pivot_offset = Vector2(48, 96 - 22)
	add_child(hero)

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	collision.shape = circle
	add_child(collision)

func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO if blocked else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * 288.0
	if direction.length_squared() > 0.0:
		facing = direction
	move_and_slide()
	hero.moving = direction.length_squared() > 0.0
	if direction.x != 0.0: hero.facing_left = direction.x < 0.0
	# Oblique hub: nearer the camera reads larger, matching the painted floor perspective.
	hero.scale = Vector2.ONE * (depth_scale(position.y) if depth_scaled else 1.0)
	queue_redraw()

static func depth_scale(y: float) -> float:
	return lerpf(1.25, 1.65, clampf((y - 262.0) / 210.0, 0.0, 1.0))

func _draw() -> void:
	draw_ellipse(Vector2(0, 10), 15.0, 6.0, Color(0, 0, 0, 0.3))

