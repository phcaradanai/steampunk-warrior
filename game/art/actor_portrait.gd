class_name ActorPortrait
extends Control

var actor_id: String = "C01"
var mirror: bool = false
var alive: bool = true
var motion_offset := Vector2.ZERO
var elapsed: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var data := ActorArt.mesh(actor_id)
	if data.is_empty(): return
	var height := minf(size.y-8,(size.x-8)*data.bounds.size.y/data.bounds.size.x)
	var breath := sin(elapsed*2.3)*1.2 if alive else 0.0
	ActorArt.paint(self,actor_id,Vector2(size.x*0.5,size.y-4+breath)+motion_offset,height,mirror,Color.WHITE if alive else Color(0.4,0.4,0.4,0.5))
