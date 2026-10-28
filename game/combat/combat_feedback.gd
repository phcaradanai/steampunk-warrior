class_name CombatFeedback
extends Control

var bursts: Array[Dictionary] = []
var shake_enabled: bool = true
var flash_enabled: bool = true
var clock: float = 0.0
var trauma: float = 0.0
var shake_offset := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	clock += delta
	trauma = maxf(0,trauma-delta*5)
	shake_offset = Vector2(sin(clock*83),cos(clock*71))*trauma*3 if shake_enabled else Vector2.ZERO
	for burst in bursts: burst.life -= delta
	bursts = bursts.filter(func(b):return b.life > 0)
	queue_redraw()

func play_events(events: Array, portraits: Dictionary, options: Dictionary) -> void:
	shake_enabled = not options.get("reduced_shake",false)
	flash_enabled = not options.get("reduced_flash",false)
	for event in events:
		var payload: Dictionary = event.payload
		if event.type == "action" and portraits.has(payload.actor_id) and payload.kind in ["attack","skill"]:
			var actor: ActorPortrait = portraits[payload.actor_id]
			var motion := actor.create_tween()
			motion.tween_property(actor,"motion_offset",Vector2(-12 if actor.mirror else 12,-2),.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			motion.tween_property(actor,"motion_offset",Vector2.ZERO,.16).set_trans(Tween.TRANS_SINE)
		if not event.type in ["damage","heal"] or not portraits.has(payload.target_id): continue
		var target: ActorPortrait = portraits[payload.target_id]
		var point := target.global_position-global_position+target.size*Vector2(.5,.5)
		var color := Color("83dcb3") if event.type == "heal" else Color("80cde1") if payload.get("shielded",false) else Color("efbb71")
		bursts.append({"point":point,"color":color,"life":.32,"shielded":payload.get("shielded",false)})
		trauma = 1.0 if event.type == "damage" else trauma
		if flash_enabled:
			target.modulate = Color(1.35,1.25,1.1)
			target.create_tween().tween_property(target,"modulate",Color.WHITE,.18)
		var recoil := target.create_tween()
		recoil.tween_property(target,"motion_offset",Vector2(5 if target.mirror else -5,0),.055)
		recoil.tween_property(target,"motion_offset",Vector2.ZERO,.18)
		var number := Label.new()
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.text = ("+" if event.type == "heal" else "−")+str(payload.amount)
		number.add_theme_font_size_override("font_size",24)
		number.add_theme_color_override("font_color",color)
		number.add_theme_color_override("font_outline_color",Color("09171b"))
		number.add_theme_constant_override("outline_size",5)
		number.position = point-Vector2(20,30)
		add_child(number)
		var rise := number.create_tween().set_parallel(true)
		rise.tween_property(number,"position:y",point.y-62,.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rise.tween_property(number,"modulate:a",0.0,.32)
		rise.chain().tween_callback(number.queue_free)

func _draw() -> void:
	for burst in bursts:
		var elapsed: float = 1.0-burst.life/.32
		var color: Color = burst.color
		color.a *= 1.0-elapsed
		var point: Vector2 = burst.point+shake_offset
		if burst.shielded:
			draw_arc(point,18+elapsed*16,0,TAU,32,color,2)
		else:
			for i in range(8):
				var direction := Vector2.from_angle(i*TAU/8)
				draw_line(point+direction*(6+elapsed*12),point+direction*(13+elapsed*28),color,2)
