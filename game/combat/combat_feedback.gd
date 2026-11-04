class_name CombatFeedback
extends Control

const STAB_SKILLS := ["S01","S02","S03","S05","S07","S13","S16"]
# Melee moves cross the arena to the target; the rest fire from where the actor stands.
const MELEE_SKILLS := ["S01","S02","S07","S16"]
# Basic attacks by enemy role (skills carry their own `vfx` in skills.json); other actions by kind.
const ROLE_ATTACK_VFX := {"bite":"bite", "charge":"smash", "quick":"slash2", "howl":"bite", "stagger":"smash"}
const ACTION_VFX := {"guard":{"cast":"dome"}, "vent":{"cast":"steam"}, "focus_potion":{"cast":"charge"}}
# Statuses shown as a looping effect on the figure, at a height given as in _anchor (0 = frame top, 1 = feet).
const STATUS_AURAS := {"Wet":["aura_wet",0.45], "Heated":["aura_heated",0.6], "Corroded":["aura_corroded",0.65],
	"Marked":["aura_marked",0.45], "Sealed":["aura_sealed",0.6], "Staggered":["aura_staggered",0.22], "Haste":["aura_haste",0.6]}
const DASH := 0.36
const HOLD := 0.12
const RETURN := 0.42
var shake_enabled: bool = true
var flash_enabled: bool = true
var clock: float = 0.0
var trauma: float = 0.0
var shake_offset := Vector2.ZERO
var playing: int = 0
# The effect recipe of the action being played; its damage and heal events use it on impact.
var current_vfx: Dictionary = {}
var auras: Dictionary = {}  # "actor_id:Status" -> [ToonFx, ActorPortrait, height]
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
	for key in auras:
		var aura: Array = auras[key]
		if is_instance_valid(aura[0]) and is_instance_valid(aura[1]): aura[0].position = _anchor(aura[1], aura[2]) + aura[1].motion_offset

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
			current_vfx = _vfx_for(payload)
			var casts: Variant = current_vfx.get("cast", [])
			for cast in (casts if casts is Array else [casts]):
				ToonFx.spawn(self, cast, _anchor(actor, 0.55), actor.mirror, 1.0, _tint(cast))
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
		elif event.type == "miss" and portraits.has(payload.target_id):
			_miss(portraits[payload.target_id], portraits.get(payload.get("source_id","")))
		index += 1
	if mover != null and is_instance_valid(mover) and is_inside_tree():
		await get_tree().create_timer(recover + HOLD).timeout
		await _return(mover)
	playing -= 1

func _first_target(events: Array, from: int, actor_id: String, portraits: Dictionary) -> ActorPortrait:
	for i in range(from+1, events.size()):
		var payload: Dictionary = events[i].payload
		if events[i].type == "action": break
		if events[i].type in ["damage","miss"] and payload.get("source_id","") == actor_id and payload.target_id != actor_id and portraits.has(payload.target_id):
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

func _projectile(actor: ActorPortrait, target: ActorPortrait, _payload: Dictionary) -> void:
	var from := _anchor(actor, 0.45)
	var to := _anchor(target, 0.45)
	var travel: String = current_vfx.get("travel", "bolt" if current_vfx.is_empty() else "")
	if travel.is_empty(): return
	if travel == "zap":
		# Lightning is instant: the arc spans the gap and flickers out.
		var arc := ToonFx.spawn(self, "zap", from, false, 1.0, _tint("zap"))
		arc.reach = to - from
		if is_inside_tree(): await get_tree().create_timer(.1).timeout
		return
	var bolt := ToonFx.spawn(self, travel, from, false, 1.0, _tint(travel))
	bolt.rotation = (to-from).angle()
	var flight := create_tween()
	flight.tween_property(bolt,"position",to,.18)
	await flight.finished
	bolt.queue_free()

func _anchor(portrait: ActorPortrait, height: float) -> Vector2:
	return portrait.global_position-global_position+Vector2(portrait.size.x*.5, portrait.get_meta("feet",portrait.size.y)*height)

# A dodged blow: the target sidesteps away from the attacker and "พลาด!" floats up; no damage, no flash.
func _miss(target: ActorPortrait, source: ActorPortrait) -> void:
	if is_inside_tree(): get_tree().call_group("game_audio","play_sfx","whoosh")
	var away := 1.0 if source == null or source.position.x < target.position.x else -1.0
	var step := target.create_tween()
	step.tween_property(target,"motion_offset",Vector2(26*away,-4),.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	step.tween_property(target,"motion_offset",Vector2.ZERO,.22).set_trans(Tween.TRANS_SINE)
	var label := _label("พลาด!", 30, Color("d8e6dc"))
	var point := _anchor(target, 0.35)
	label.position = point - Vector2(40, 20)
	var rise := label.create_tween().set_parallel(true)
	rise.tween_property(label,"position:y",point.y-80,.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.tween_property(label,"modulate:a",0.0,.25).set_delay(.3)
	rise.chain().tween_callback(label.queue_free)

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
	var impact: String = current_vfx.get("impact", "hit")
	if source == null and payload.get("type","") == "Heated": impact = "fire"
	if event.type == "heal":
		ToonFx.spawn(self, "heal", _anchor(target, 1.0))
	elif payload.get("shielded",false):
		# The barrier faces the attacker; impact sparks fly away from it.
		ToonFx.spawn(self, "block", point, not from_right)
	elif impact in ["hit", "crit"]:
		ToonFx.spawn(self, "crit" if (heavy or impact == "crit") and flash_enabled else "hit", point, from_right)
	else:
		ToonFx.spawn(self, impact, point, from_right, 1.0, _tint(impact))
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
		var beam := ToonFx.spawn(self, "beam", Vector2(origin.x, floor_y))
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
static var _skill_vfx: Dictionary = {}

func _vfx_for(payload: Dictionary) -> Dictionary:
	if payload.kind == "skill":
		_hero_action(payload)  # loads the skills table
		return _skill_vfx.get(payload.skill_id, {})
	if payload.kind == "attack":
		var role := ""
		var controller = get_parent().get("controller")
		if controller != null:
			for actor in controller.state.actors:
				if actor.id == payload.actor_id: role = actor.get("role", "")
		return {"impact":ROLE_ATTACK_VFX.get(role, "hit")}
	return ACTION_VFX.get(payload.kind, {})

func _tint(kind: String) -> Color:
	var hex: String = current_vfx.get("tint", "")
	# A skill's tint colours its charge, travel and impact; kinds whose colour carries meaning keep their own.
	if hex.is_empty() or kind in ["muzzle", "dome", "steam", "warp", "haste"]:
		return Color(0, 0, 0, 0)
	return Color(hex)

# Looping status effects follow their figure; added and removed to match the resolver's statuses.
func sync_auras(actors: Array, portraits: Dictionary) -> void:
	var wanted := {}
	for actor in actors:
		if actor.hp <= 0 or not portraits.has(actor.id): continue
		for status in actor.get("statuses", {}):
			if STATUS_AURAS.has(status): wanted[actor.id + ":" + status] = [portraits[actor.id], STATUS_AURAS[status]]
	for key in auras.keys():
		if not wanted.has(key) or not is_instance_valid(auras[key][0]):
			if is_instance_valid(auras[key][0]): auras[key][0].queue_free()
			auras.erase(key)
	for key in wanted:
		if auras.has(key): continue
		var portrait: ActorPortrait = wanted[key][0]
		var spec: Array = wanted[key][1]
		var fx := ToonFx.spawn(self, spec[0], _anchor(portrait, spec[1]), portrait.mirror, 0.9)
		auras[key] = [fx, portrait, spec[1]]

func _hero_action(payload: Dictionary, hero: Stage3D = null) -> String:
	if payload.kind == "attack": return "shoot" if hero != null and hero.get("weapon_model") == "gun" else "attack"
	if payload.kind != "skill": return payload.kind
	if _clips.is_empty():
		for skill in JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json")):
			if skill.has("clip"): _clips[skill.id] = skill.clip
			if skill.has("vfx"): _skill_vfx[skill.id] = skill.vfx
	return _clips.get(payload.skill_id, "skill_stab" if payload.skill_id in STAB_SKILLS else "skill_steam")
