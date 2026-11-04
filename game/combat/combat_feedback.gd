class_name CombatFeedback
extends Control

const STAB_SKILLS := ["S01","S02","S03","S05","S07","S13","S16"]
# Melee moves cross the arena to the target; the rest fire from where the actor stands.
const MELEE_SKILLS := ["S01","S02","S07","S16"]
const DASH := 0.36
const HOLD := 0.12
const RETURN := 0.42
var shake_enabled: bool = true
var flash_enabled: bool = true
var clock: float = 0.0
var trauma: float = 0.0
var shake_offset := Vector2.ZERO
var playing: int = 0
# impact_landed carries the event so the view can move HP on the contact frame; impacted is a plain cue for tests and audio.
signal impact_landed(event: Dictionary)
signal impacted(target_id: String)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	clock += delta
	trauma = maxf(0,trauma-delta*5)
	shake_offset = Vector2(sin(clock*83),cos(clock*71))*trauma*3 if shake_enabled else Vector2.ZERO
	var stage := get_parent().get("stage") as Control
	if stage != null: stage.position = Vector2(0,CombatView.STAGE_TOP) + shake_offset*2

# Plays one resolved turn: approach, strike, impacts on the contact frame, then step back.
func play_events(events: Array, portraits: Dictionary, options: Dictionary) -> void:
	shake_enabled = not options.get("reduced_shake",false)
	flash_enabled = not options.get("reduced_flash",false)
	playing += 1
	var mover: ActorPortrait = null
	var recover := 0.0
	var index := 0
	while index < events.size():
		var event: Dictionary = events[index]
		var payload: Dictionary = event.payload
		if event.type == "action" and portraits.has(payload.actor_id):
			var actor: ActorPortrait = portraits[payload.actor_id]
			var target := _first_target(events, index, payload.actor_id, portraits)
			var gunner: bool = payload.kind == "attack" and actor.hero != null and actor.hero.get("weapon_model") == "gun"
			var melee: bool = (payload.kind == "attack" and not gunner) or (payload.kind == "skill" and payload.skill_id in MELEE_SKILLS)
			if target != null and melee and is_inside_tree():
				await _dash(actor, target)
				mover = actor
			_strike(actor, payload)
			_sound(event)
			# Damage, numbers and the target's flinch wait for the blow to actually land in the clip.
			var timing: Vector2 = actor.hero.strike_timing(_hero_action(payload, actor.hero)) if actor.hero != null else Vector2(0.18, 0.15)
			recover = timing.y
			if target != null and is_inside_tree():
				await get_tree().create_timer(timing.x).timeout
				if not melee: await _projectile(actor, target, payload)
		elif event.type in ["damage","heal"] and portraits.has(payload.target_id):
			_impact(event, portraits)
		index += 1
	if mover != null and is_instance_valid(mover) and is_inside_tree():
		await get_tree().create_timer(recover + HOLD).timeout
		await _return(mover)
	playing -= 1

func _first_target(events: Array, from: int, actor_id: String, portraits: Dictionary) -> ActorPortrait:
	for i in range(from+1, events.size()):
		var payload: Dictionary = events[i].payload
		if events[i].type == "action": break
		if events[i].type == "damage" and payload.get("source_id","") == actor_id and payload.target_id != actor_id and portraits.has(payload.target_id):
			return portraits[payload.target_id]
	return null

# Where the attacker's frame must sit to stand at the target's front edge; wide figures (B06 wings and blades) are measured from their meshes, not the frame.
func _dash_spot(actor: ActorPortrait, target: ActorPortrait, side: float) -> Vector2:
	var half := float(target.get_meta("body",target.size.x))*0.32
	var edge := half*side
	if target.hero is Creature3D and target.hero.size.y > 0.0:
		# Stage3D frames model y in 2.0 world units, so the frame height gives pixels per unit.
		var span: Vector2 = target.hero.extent_x() * (target.hero.size.y / Stage3D.FRAME)
		edge = span.y if side > 0 else span.x
	# Stop a weapon's reach short of the edge so the weapon, not the torso, makes contact.
	var reach := edge + float(actor.get_meta("body",actor.size.x))*0.28*side
	return Vector2(target.position.x + target.size.x*0.5 + reach - actor.size.x*0.5, target.position.y + target.get_meta("feet",target.size.y) - actor.get_meta("feet",actor.size.y))

func _dash(actor: ActorPortrait, target: ActorPortrait) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(target): return
	var home: Vector2 = actor.get_meta("home", actor.position)
	var side := -1.0 if target.position.x > home.x else 1.0
	var spot := _dash_spot(actor, target, side)
	if actor.hero != null:
		actor.hero.facing_left = side > 0
		actor.hero.running = true
	var run := actor.create_tween()
	run.tween_property(actor,"position",spot,DASH).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await run.finished
	if actor.hero != null: actor.hero.running = false

func _return(actor: ActorPortrait) -> void:
	var home: Vector2 = actor.get_meta("home", actor.position)
	if actor.hero != null:
		actor.hero.end_action()
		actor.hero.facing_left = home.x < actor.position.x
		actor.hero.running = true
	var back := actor.create_tween()
	back.tween_property(actor,"position",home,RETURN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await back.finished
	if is_instance_valid(actor) and actor.hero != null:
		actor.hero.running = false
		actor.hero.facing_left = actor.mirror

func _strike(actor: ActorPortrait, payload: Dictionary) -> void:
	if actor.hero != null:
		actor.hero.perform(_hero_action(payload, actor.hero))
	elif payload.kind in ["attack","skill"]:
		# 2D foes lunge and lean into the swing; the hero's 3D clip carries its own wind-up.
		var lean := actor.create_tween()
		lean.tween_property(actor,"motion_offset",Vector2(-16 if actor.mirror else 16,-6),.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		lean.tween_property(actor,"motion_offset",Vector2.ZERO,.2).set_trans(Tween.TRANS_SINE)

func _projectile(actor: ActorPortrait, target: ActorPortrait, payload: Dictionary) -> void:
	var from := _anchor(actor, 0.45)
	var to := _anchor(target, 0.45)
	var bolt := VfxSprite.spawn(self, "bolt-steam" if payload.get("skill_id","") in ["S04","S06","S15"] else "bolt-brass", from, false, 2.0)
	bolt.rotation = (to-from).angle()
	var flight := create_tween()
	flight.tween_property(bolt,"position",to,.18)
	await flight.finished
	bolt.queue_free()

func _anchor(portrait: ActorPortrait, height: float) -> Vector2:
	return portrait.global_position-global_position+Vector2(portrait.size.x*.5, portrait.get_meta("feet",portrait.size.y)*height)

func _sound(event: Dictionary) -> void:
	if is_inside_tree(): get_tree().call_group("game_audio","combat_events",[event])

func _impact(event: Dictionary, portraits: Dictionary) -> void:
	_sound(event)
	impact_landed.emit(event)
	impacted.emit(event.payload.target_id)
	var payload: Dictionary = event.payload
	var target: ActorPortrait = portraits[payload.target_id]
	if target.hero != null and event.type == "damage":
		target.hero.perform("guard" if payload.get("shielded",false) else "hit")
	# The player's own blows freeze its clip for a beat and throw sparks, whatever the target is made of.
	var heavy: bool = event.type == "damage" and payload.get("source_id","") == "hero" and payload.target_id != "hero" and portraits.has("hero") and portraits.hero.hero != null
	if heavy: portraits.hero.hero.hit_stop()
	var point := _anchor(target, 0.5)
	var color := Color("83dcb3") if event.type == "heal" else Color("80cde1") if payload.get("shielded",false) else Color("efbb71")
	var source: ActorPortrait = portraits.get(payload.get("source_id",""))
	var from_right: bool = source != null and source != target and source.position.x > target.position.x
	if event.type == "heal":
		VfxSprite.spawn(self, "heal-aoe", _anchor(target, 1.0), false, 2.0)
	elif payload.get("shielded",false):
		# The shield sheet faces an attacker on its right; the spark sheets fly off to the right.
		VfxSprite.spawn(self, "shield-block", _anchor(target, 1.0), not from_right)
	else:
		VfxSprite.spawn(self, "crit-hit" if heavy and flash_enabled else "hit-spark", point, from_right)
	trauma = 1.0 if event.type == "damage" else trauma
	if flash_enabled:
		# Whole-figure flash so the blow reads at a glance, then fade back.
		target.modulate = Color(2.6,2.4,1.9)
		target.create_tween().tween_property(target,"modulate",Color.WHITE,.24).set_ease(Tween.EASE_OUT)
	var away := 1.0 if target.mirror else -1.0
	var recoil := target.create_tween()
	recoil.tween_property(target,"motion_offset",Vector2(10*away,0),.055)
	recoil.tween_property(target,"motion_offset",Vector2.ZERO,.18)
	var number := Label.new()
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.text = ("+" if event.type == "heal" else "")+str(payload.amount)
	number.add_theme_font_size_override("font_size",34)
	number.add_theme_color_override("font_color",color)
	number.add_theme_color_override("font_outline_color",Color("09171b"))
	number.add_theme_constant_override("outline_size",7)
	number.position = point-Vector2(24,46)
	number.pivot_offset = Vector2(24,20)
	number.scale = Vector2.ONE*1.5
	add_child(number)
	var rise := number.create_tween().set_parallel(true)
	rise.tween_property(number,"scale",Vector2.ONE,.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(number,"position:y",point.y-96,.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.tween_property(number,"modulate:a",0.0,.25).set_delay(.35)
	rise.chain().tween_callback(number.queue_free)

# Victory spoils burst out of the last foe: a fan of gears for gold, then the dropped part.
func play_loot(source: ActorPortrait, gold: int, item: Dictionary, options: Dictionary) -> void:
	playing += 1
	var origin := _anchor(source, 0.5)
	var floor_y := _anchor(source, 1.0).y
	var banner := _label("ชนะ!", 52, Color("f6d98f"))
	# Below the HP panels and log line, above the drop's name tag.
	banner.position = Vector2(460, CombatView.STAGE_TOP+150)
	banner.size = Vector2(360,70)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in range(clampi(gold/10, 4, 14)):
		var coin := ColorRect.new()
		coin.size = Vector2(10,10)
		coin.rotation = randf()*TAU
		coin.color = Color("e3b858")
		coin.position = origin
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(coin)
		var land := Vector2(origin.x + randf_range(-110,110), floor_y + randf_range(-6,10))
		var arc := coin.create_tween().set_parallel(true)
		arc.tween_property(coin,"position:x",land.x,.5)
		arc.tween_property(coin,"position:y",origin.y-randf_range(50,110),.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		arc.tween_property(coin,"position:y",land.y,.28).set_delay(.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		arc.tween_property(coin,"rotation",coin.rotation+TAU*2,.5)
	if not item.is_empty():
		var icon := TextureRect.new()
		icon.texture = UIBuilder.item_icon(item)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = Vector2(56,56)
		icon.pivot_offset = icon.size*0.5
		icon.position = origin-icon.size*0.5
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		var beam := VfxSprite.spawn(self, "loot-beam", Vector2(origin.x, floor_y), false, 2.0)
		beam.create_tween().tween_callback(beam.queue_free).set_delay(1.3)
		var pop := icon.create_tween()
		pop.tween_property(icon,"position:y",origin.y-110,.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		var name_label := _label("ได้รับ " + item.name, 22, Color("f1d9a0"))
		name_label.position = Vector2(origin.x-160, origin.y-160)
		name_label.size = Vector2(320,30)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_inside_tree():
		await get_tree().create_timer(1.3 if not options.get("reduced_motion",false) else 0.6).timeout
	playing -= 1

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_outline_color",Color("09171b"))
	label.add_theme_constant_override("outline_size",8)
	add_child(label)
	return label

# skills.json `clip` names the hero action; a gun in hand turns the basic attack into a shot.
static var _clips: Dictionary = {}

func _hero_action(payload: Dictionary, hero: Stage3D = null) -> String:
	if payload.kind == "attack": return "shoot" if hero != null and hero.get("weapon_model") == "gun" else "attack"
	if payload.kind != "skill": return payload.kind
	if _clips.is_empty():
		for skill in JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json")):
			if skill.has("clip"): _clips[skill.id] = skill.clip
	return _clips.get(payload.skill_id, "skill_stab" if payload.skill_id in STAB_SKILLS else "skill_steam")
