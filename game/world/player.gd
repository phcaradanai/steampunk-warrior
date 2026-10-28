class_name SteamPlayer
extends CharacterBody2D

var blocked: bool = false
var facing := Vector2.RIGHT
var class_id: String = "C01"

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	collision.shape = circle
	add_child(collision)

func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO if blocked else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * 180.0
	if direction.length_squared() > 0.0:
		facing = direction
	move_and_slide()
	queue_redraw()

func _draw() -> void:
	draw_ellipse(Vector2(0, 10), 15.0, 6.0, Color(0, 0, 0, 0.3))
	ActorArt.paint(self,class_id,Vector2(0,15),50,facing.x < 0)

