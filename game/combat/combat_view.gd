class_name CombatView
extends Control

signal finished
var controller: CombatController
var pumping: bool = false
var paused: bool = false
var focus_action: String = "Basic_Attack"
var settled: bool = false
var selected_target: String = "enemy0"
var last_log: String = "อ่านสัญญาณศัตรู แล้วเลือกคำสั่ง"
var feedback: CombatFeedback
var portraits: Dictionary = {}
var effect_options: Dictionary = {}
var hero_stage: Hero3D
# The stage persists across renders so dashes and clips are never cut by a UI rebuild.
var stage: Control
var ui: Control
var wait_label: Label
var plates: Control
var target_marker: Control
var card: ColorRect
var card_note: Label
var card_tween: Tween
var clock: float = 0.0
# HP and barrier as the player sees them: they change when a blow lands on screen, not when the resolver decides.
var shown: Dictionary = {}
var hp_bars: Dictionary = {}
var hp_texts: Dictionary = {}
var barrier_bars: Dictionary = {}
# The arena fills the screen; plates and commands float over it.
const STAGE_TOP := 0.0
const STAGE_SIZE := Vector2(1280,720)
const GROUND := 560.0
const STATUS_NAMES := {"Wet":"เปียก","Heated":"ร้อนจัด","Corroded":"เกราะผุ","Marked":"ถูกหมายหัว","Staggered":"เสียจังหวะ","Sealed":"ปิดการฟื้นฟู","Haste":"เร่งจังหวะ","Guard":"ตั้งรับ"}

func configure(active_controller: CombatController) -> void:
	controller = active_controller

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sync_shown()
	_build_stage()
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	plates = Control.new()
	plates.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plates)
	feedback = CombatFeedback.new()
	feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	feedback.impact_landed.connect(_on_impact)
	add_child(feedback)
	_render()
	_title_card()
	_pump.call_deferred()

func _process(delta: float) -> void:
	clock += delta
	if is_instance_valid(stage): stage.queue_redraw()
	if is_instance_valid(target_marker) and portraits.has(selected_target):
		var foe: ActorPortrait = portraits[selected_target]
		target_marker.visible = controller.is_player_turn() and not paused and not settled and foe.alive and feedback.playing == 0
		var top: float = foe.hero.top_fraction() if foe.hero != null else 0.1
		target_marker.position = foe.position + Vector2(foe.size.x*0.5, foe.size.y*top - 18.0 + sin(clock*5.0)*6.0)
	if is_instance_valid(wait_label):
		wait_label.visible = not settled and (feedback.playing > 0 or not controller.is_player_turn())

func backdrop() -> String:
	var theme: String = controller.content.get("rooms",[]).filter(func(r): return r.id == controller.encounter.get("room","")).map(func(r): return r.palette).front() if not controller.encounter.is_empty() else "rail"
	if not controller.pipe_id.is_empty():
		theme = WorldController.new(controller.content).pipe(controller.pipe_id).get("theme",theme)
	return theme if ResourceLoader.exists("res://art/environments/arena_%s.png" % theme) else "rail"

func _build_stage() -> void:
	stage = Control.new()
	stage.position = Vector2(0,STAGE_TOP)
	stage.size = STAGE_SIZE
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var art := TextureRect.new()
	art.texture = load("res://art/environments/arena_%s.png" % backdrop())
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.size = STAGE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(art)
	var shadows := Control.new()
	shadows.size = STAGE_SIZE
	shadows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadows.draw.connect(func():
		for portrait in portraits.values():
			if not is_instance_valid(portrait): continue
			var feet: Vector2 = portrait.position + Vector2(portrait.size.x*0.5, portrait.get_meta("feet",portrait.size.y))
			var width: float = portrait.size.x*0.32
			shadows.draw_set_transform(feet,0,Vector2(1,0.26))
			shadows.draw_circle(Vector2.ZERO,width,Color(0,0,0,0.42 if portrait.alive else 0.2)))
	stage.add_child(shadows)
	stage.draw.connect(shadows.queue_redraw)
	var enemies: Array = controller.state.actors.filter(func(a): return a.side == "enemy")
	for actor in controller.state.actors:
		var portrait := ActorPortrait.new()
		portrait.actor_id = ActorArt.actor_id(actor)
		portrait.mirror = actor.side == "enemy"
		portrait.alive = actor.hp > 0
		var boss: bool = actor.get("boss",false)
		portrait.size = Vector2(300,300) if actor.side == "player" else Vector2(350,350) if boss else Vector2(250,250)
		var center := 330.0
		var feet := GROUND
		if actor.side == "player":
			hero_stage = Hero3D.new()
			hero_stage.set_equipment(actor.get("equipment",{}),controller.content.get("items",[]))
			portrait.attach_hero(hero_stage)
			# Hero3D frames the model with its feet slightly above the viewport bottom.
			portrait.set_meta("feet",portrait.size.y*0.925)
		else:
			var figure := Roster3D.create(Roster3D.actor_key(actor))
			if figure != null:
				figure.facing_left = true
				portrait.attach_hero(figure)
			var index: int = enemies.find(actor)
			center = 910.0 if enemies.size() == 1 else 820.0 + index*220.0
			feet = GROUND - index*24.0
			# Tap a foe to make it the target.
			portrait.mouse_filter = Control.MOUSE_FILTER_STOP
			portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			portrait.tooltip_text = actor.name + " · แตะเพื่อเลือกเป้าหมาย"
			portrait.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and controller._actor(actor.id).hp > 0:
					selected_target = actor.id
					_render())
			portrait.set_meta("feet",portrait.size.y*0.925 if figure != null else portrait.size.y-4)
		portrait.position = Vector2(center-portrait.size.x*0.5, feet-portrait.get_meta("feet"))
		portrait.set_meta("home",portrait.position)
		stage.add_child(portrait)
		portraits[actor.id] = portrait
	# Bobbing arrow over the chosen foe while it is the player's turn.
	target_marker = Control.new()
	target_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_marker.draw.connect(func():
		target_marker.draw_colored_polygon(PackedVector2Array([Vector2(-14,-10),Vector2(14,-10),Vector2(0,8)]),Color("f1d9a0"))
		target_marker.draw_polyline(PackedVector2Array([Vector2(-14,-10),Vector2(14,-10),Vector2(0,8),Vector2(-14,-10)]),Color("0b1214"),2.0))
	stage.add_child(target_marker)
	wait_label = UIBuilder.label(stage,"…กำลังออกท่า…",18,Color("f1d9a0"))
	wait_label.position = Vector2(540,500)
	wait_label.size = Vector2(200,30)
	wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _title_card() -> void:
	_dismiss_card()
	var text: String = controller.encounter.get("name","โรงฝึกหม้อน้ำ")
	if not controller.pipe_id.is_empty():
		var line := WorldController.new(controller.content).pipe(controller.pipe_id)
		text = "%s\nระดับ %d · %s" % [line.name, line.encounters.find(controller.encounter.id)+1, controller.encounter.name]
	var notes: Array[String] = []
	var boss: String = controller.encounter.get("boss_id","")
	if not boss.is_empty(): notes.append(controller.content.get("story",{}).get("boss_intros",{}).get(boss,""))
	var hero: Dictionary = controller.state.actors[0]
	var hazards := {"Wet":"อันตราย: ทั้งสองฝ่ายเปียก ไฟฟ้าจะแรงขึ้น","Corroded":"อันตราย: เกราะคุณผุ","Heated":"อันตราย: คุณร้อนจัด"}
	for hazard in hazards:
		if hero.statuses.has(hazard): notes.append(hazards[hazard] + " · ปรับวาล์วในห้องเพื่อลดได้")
	var lines := "\n".join(notes.filter(func(n): return not n.is_empty()))
	var hold := 2.6 if not lines.is_empty() else 0.9
	# One dim band above the actors' heads (boss tops start near y=236, HP panels end near y=122); commands wait for it.
	card = ColorRect.new()
	card.color = Color(0.04,0.07,0.08,0.66)
	card.position = Vector2(0,140)
	card.size = Vector2(1280,95 if not lines.is_empty() else 54)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(card)
	var title := _fixed_label(card,text.replace("\n","  ·  "),30,Color("f1d9a0"),Rect2(0,2,1280,42))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color",Color("0b1214"))
	title.add_theme_constant_override("outline_size",8)
	if not lines.is_empty():
		card_note = _fixed_label(card,lines,16,Color("f0cf9f"),Rect2(90,41,1100,48),true)
		card_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_note.add_theme_color_override("font_outline_color",Color("0b1214"))
		card_note.add_theme_constant_override("outline_size",6)
	ui.modulate = Color(1,1,1,0.45)
	card_tween = card.create_tween()
	card_tween.tween_interval(hold)
	card_tween.tween_callback(_dismiss_card)

func _dismiss_card() -> void:
	if card == null: return
	var gone := card
	card = null
	ui.modulate = Color.WHITE
	card_tween.kill()
	var fade := gone.create_tween()
	fade.tween_property(gone,"modulate:a",0.0,0.2)
	fade.tween_callback(gone.queue_free)
	_focus_ready()

# A Label sized after its text is measured at width 0 keeps that huge height; size it first so its rect is real.
func _fixed_label(parent: Node, text: String, font_size: int, color: Color, rect: Rect2, wrap: bool = false) -> Label:
	var node := Label.new()
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.position = rect.position
	node.size = rect.size
	node.text = text
	parent.add_child(node)
	return node

# Enter, Space or a click skips the card; nothing else reaches the commands while it is up.
func _input(event: InputEvent) -> void:
	if card == null: return
	var key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if key or click:
		_dismiss_card()
		get_viewport().set_input_as_handled()

func _render(events: Array = []) -> void:
	for event in events:
		if event.type == "damage":
			last_log = ("โล่รับ " if event.payload.get("shielded",false) else "ได้รับ ") + str(event.payload.amount) + " ความเสียหาย"
		elif event.type == "heal":
			last_log = "ฟื้นพลัง " + str(event.payload.amount)
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	var living: Array[Dictionary] = []
	for actor in controller.state.actors:
		if actor.side == "enemy" and actor.hp > 0:
			living.append(actor)

	if not living.is_empty() and not living.any(func(a):return a.id == selected_target):
		selected_target = living[0].id
	# Bars and sounds change on the contact frame, so plates wait for the strike to land.
	if events.is_empty(): _plates()
	else: _plates_when_idle()
	_commands(living)
	_play_feedback.call_deferred(events)
	_focus_ready.call_deferred()

func shown_hp(id: String) -> int:
	return int(shown.get(id,{}).get("hp",0))

func _sync_shown() -> void:
	for actor in controller.state.actors:
		var top: int = maxi(int(actor.get("barrier",0)), int(shown.get(actor.id,{}).get("max_barrier",0)))
		shown[actor.id] = {"hp":int(actor.hp),"barrier":int(actor.get("barrier",0)),"max_hp":int(actor.max_hp),"max_barrier":top}

func _on_impact(event: Dictionary) -> void:
	var id: String = event.payload.target_id
	if not shown.has(id): return
	var seen: Dictionary = shown[id]
	if event.type == "heal":
		seen.hp = mini(seen.max_hp, seen.hp + int(event.payload.amount))
	elif event.payload.get("shielded",false):
		seen.barrier = maxi(0, seen.barrier - int(event.payload.amount))
	else:
		seen.hp = maxi(0, seen.hp - int(event.payload.amount))
	if hp_bars.has(id) and is_instance_valid(hp_bars[id]):
		hp_bars[id].create_tween().tween_property(hp_bars[id],"value",float(seen.hp),0.18)
		hp_texts[id].text = _hp_text(seen)
	if barrier_bars.has(id) and is_instance_valid(barrier_bars[id]):
		barrier_bars[id].create_tween().tween_property(barrier_bars[id],"value",float(seen.barrier),0.18)
	if seen.hp <= 0 and portraits.has(id):
		_fall(portraits[id])

func _fall(portrait: ActorPortrait) -> void:
	portrait.alive = false
	if portrait.hero == null or portrait.hero.down: return
	# Let the flinch read first, then drop.
	await get_tree().create_timer(0.22).timeout
	if is_instance_valid(portrait) and portrait.hero != null: portrait.hero.perform("down")

func _hp_text(seen: Dictionary) -> String:
	return "HP %d / %d" % [seen.hp,seen.max_hp] + ("  ·  โล่ %d" % seen.barrier if seen.barrier > 0 else "")

func _plates_when_idle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	while is_inside_tree() and feedback.playing > 0:
		await get_tree().process_frame
	if is_inside_tree(): _plates()

func _plates() -> void:
	# Between strikes the resolver is authoritative again (FP, pressure, statuses, deaths without a blow).
	_sync_shown()
	for actor in controller.state.actors:
		if actor.hp <= 0 and portraits.has(actor.id): _fall(portraits[actor.id])
	hp_bars.clear()
	hp_texts.clear()
	barrier_bars.clear()
	for child in plates.get_children():
		plates.remove_child(child)
		child.queue_free()
	var log_label := _fixed_label(plates,last_log,16,Color("d8e6dc"),Rect2(340,112,600,28))
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_label.add_theme_color_override("font_outline_color",Color("0b1214"))
	log_label.add_theme_constant_override("outline_size",5)
	var enemies: Array = controller.state.actors.filter(func(a): return a.side == "enemy")
	var width := 440.0/maxf(1,enemies.size())
	for actor in controller.state.actors:
		var panel: PanelContainer
		if actor.side == "player":
			panel = UIBuilder.glass_panel(plates,Vector2(16,12),Vector2(440,0))
		else:
			panel = UIBuilder.glass_panel(plates,Vector2(824+enemies.find(actor)*width,12),Vector2(width-(8 if enemies.size() > 1 else 0),0))
			if actor.id == selected_target and enemies.size() > 1: panel.get_theme_stylebox("panel").border_color = Color("f1d9a0")
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",2)
		panel.add_child(column)
		var head := HBoxContainer.new()
		column.add_child(head)
		var name_label := UIBuilder.label(head,actor.get("name",actor.id),18,Color("f0d492") if actor.side=="player" else Color("d99882"))
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hp_texts[actor.id] = UIBuilder.label(head,_hp_text(shown[actor.id]),15)
		hp_texts[actor.id].autowrap_mode = TextServer.AUTOWRAP_OFF
		hp_bars[actor.id] = UIBuilder.bar(column,actor.hp,actor.max_hp,Color("63b46e") if actor.side == "player" else Color("c9644e"),12)
		# The barrier soaks blows before HP; give it its own bar so a shielded hit visibly lands.
		if shown[actor.id].max_barrier > 0:
			barrier_bars[actor.id] = UIBuilder.bar(column,shown[actor.id].barrier,shown[actor.id].max_barrier,Color("80cde1"),6)
			barrier_bars[actor.id].tooltip_text = "โล่: รับความเสียหายก่อน HP"
		if actor.side == "player":
			UIBuilder.bar(column,actor.fp,actor.max_fp,Color("5ab4e0"),6).tooltip_text = "FP"
			UIBuilder.bar(column,actor.pressure,100,Color("e08a3a"),6).tooltip_text = "แรงดัน"
		var detail: Array[String] = []
		if actor.side == "player":
			detail.append("FP %d / %d  ·  แรงดัน %d / 100" % [actor.fp,actor.max_fp,actor.pressure])
		else:
			detail.append("เตรียม: " + actor.get("intent",{}).get("label","—"))
			if actor.get("boss",false):
				detail.append("ช่วงที่ " + str(int(actor.get("phase",0)) + 1))
				if actor.get("definition_id","") == "B04": detail.append("ความร้อน %d / 100" % actor.get("heat",0))
				if actor.get("core_exposed",false): detail.append("แกนเปิด: เกราะและต้านทานลด55%")
			if actor.get("intent",{}).has("following_label"): detail.append("ถัดไป: "+actor.intent.following_label)
		var active: Array[String] = []
		for status in actor.statuses:
			active.append("%s %d" % [STATUS_NAMES.get(status,status),actor.statuses[status].turns])
		if not active.is_empty(): detail.append(" · ".join(active))
		var info := UIBuilder.label(column,"  ·  ".join(detail),14,Color("edbd83") if actor.side == "enemy" else Color("c8d6cc"))
		info.autowrap_mode = TextServer.AUTOWRAP_OFF
		info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info.clip_text = true

func _commands(living: Array[Dictionary]) -> void:
	var idle: bool = controller.is_player_turn() and not paused
	var hero: Dictionary = controller.state.actors[0]
	var skill_list: Array = controller.content.skills.filter(func(skill): return skill.kind == "active" and controller.learned.has(skill.id))
	var rows := maxi(1, ceili(skill_list.size()/10.0))
	var info := UIBuilder.label(ui,"",15,Color("f1d9a0"))
	info.position = Vector2(16,720-16-rows*66-34)
	info.size = Vector2(1248,26)
	info.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.clip_text = true
	info.add_theme_color_override("font_outline_color",Color("0b1214"))
	info.add_theme_constant_override("outline_size",6)
	# Action cluster, bottom right, mobile style: pictures with counts; the words are in the tooltip and info line.
	var basics := HBoxContainer.new()
	basics.add_theme_constant_override("separation",8)
	basics.position = Vector2(1280-16-(7 if not controller.training_id.is_empty() else 6)*72,720-16-64)
	ui.add_child(basics)
	var tips := _basic_tips(hero)
	var names: Array = [["attack","weapon","","Basic_Attack"],["guard","shield","","Basic_Guard"],["vent","vent","","Basic_Vent"],["life_potion","potion_hp","%d" % hero.potions.life,"Basic_Life"],["focus_potion","potion_fp","%d" % hero.potions.focus,"Basic_Focus"],["retreat","retreat","","Basic_Retreat"]]
	for data in names:
		var button := UIBuilder.icon_button(basics,data[1],tips[data[0]],_submit.bind(data[0],""),data[3],64,data[2])
		button.disabled = not idle
		UIBuilder.hotkey(button,[KEY_Z,KEY_X,KEY_C,KEY_V,KEY_B,KEY_N][names.find(data)])
		_explain(button,button.tooltip_text,info)
	if not controller.training_id.is_empty():
		var finish := UIBuilder.icon_button(basics,"finish","จบการฝึกและเก็บ XP ที่ทำได้",_end_training,"FinishTraining",64)
		finish.disabled = not idle
		UIBuilder.hotkey(finish,KEY_M)
		_explain(finish,finish.tooltip_text,info)
		var labels: Dictionary = {"attack":"โจมตี","guard":"ตั้งรับ","vent":"ระบายไอ","shield_break":"ทำลายโล่","marked_hit":"โจมตีเป้าติดเครื่องหมาย","heal":"ฟื้นพลัง","wet_combo":"ไฟฟ้าหลังทำให้เปียก","sealing":"หยุดการฮีล","cleanse":"ล้างความร้อน","pressure_safe":"ลดแรงดันสู่ช่วงปลอดภัย","intent_counter":"ตั้งรับท่าหนัก","drone":"ใช้โดรน"}
		var objectives: Array[String] = []
		for objective in TrainingService.OBJECTIVES[controller.training_id]:
			objectives.append(("✓ " if objective in controller.completed else "○ ") + labels[objective])
		var goals := UIBuilder.label(ui,"   ·   ".join(objectives) + "   (สกิลยืมใช้ได้เฉพาะการฝึก)",15)
		goals.position = Vector2(16,142)
		goals.size = Vector2(1248,28)
		goals.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		goals.add_theme_color_override("font_outline_color",Color("0b1214"))
		goals.add_theme_constant_override("outline_size",5)
	# Keyboard and pad still cycle targets here; mouse and touch can tap the foe instead.
	var targets := OptionButton.new()
	targets.custom_minimum_size = Vector2(180,36)
	targets.position = Vector2(1280-16-180,720-16-64-46)
	ui.add_child(targets)
	for i in range(living.size()):
		targets.add_item(living[i].name)
		if living[i].id == selected_target:
			targets.select(i)
	targets.item_selected.connect(func(index:int):
		selected_target=living[index].id
		_render())
	targets.disabled = not idle
	targets.tooltip_text = "เป้าหมาย (แตะศัตรูเพื่อเลือกก็ได้)"
	var skills := GridContainer.new()
	skills.columns = 10
	skills.add_theme_constant_override("h_separation",6)
	skills.add_theme_constant_override("v_separation",6)
	skills.position = Vector2(16,720-16-rows*66)
	ui.add_child(skills)
	for skill in skill_list:
		var rank: int = int(controller.learned[skill.id])
		var preview := controller.resolver.skill_preview(hero,skill,rank)
		var tip: String = skill.name + "  ·  " + UIBuilder.skill_description(skill,preview,rank).replace("\n","  ·  ")
		var button := UIBuilder.icon_button(skills,"gear",tip,_submit.bind("skill",skill.id),"Skill_"+skill.id,60,str(preview.fp_cost))
		button.icon = UIBuilder.skill_icon(skill)
		button.disabled = not idle or hero.fp < preview.fp_cost or hero.pressure + preview.pressure_delta > 100 or hero.cooldowns.get(skill.id,0) > 0
		var slot := skill_list.find(skill)
		if slot < 10: UIBuilder.hotkey(button,[KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0][slot])
		_explain(button,button.tooltip_text,info)

# Hover and keyboard focus both show what a command will do, since tooltips alone never reach pad or keys.
func _explain(button: Button, text: String, info: Label) -> void:
	if button.tooltip_text.is_empty(): button.tooltip_text = text
	button.mouse_entered.connect(func(): info.text = text)
	button.focus_entered.connect(func(): info.text = text)
	if button.name == focus_action: info.text = text

func _basic_tips(hero: Dictionary) -> Dictionary:
	var target: Dictionary = {}
	for actor in controller.state.actors:
		if actor.id == selected_target: target = actor
	var armor: float = float(target.get("armor",0)) * (0.75 if target.get("statuses",{}).has("Corroded") else 1.0)
	var hit: float = float(hero.get("attack",1)) * 100.0 / (100.0 + armor)
	var attack := "โจมตี %s: ประมาณ %d–%d ความเสียหายกายภาพ ไม่ใช้ FP" % [target.get("name","เป้าหมาย"),maxi(1,floor(hit*0.95)),maxi(1,floor(hit*1.05))]
	if target.get("barrier",0) > 0: attack += " · โดนโล่ %d ก่อนถึงร่างกาย" % target.barrier
	if target.get("statuses",{}).has("Guard"): attack += " · เป้ากำลังตั้งรับ ความเสียหายเหลือครึ่ง"
	var life := int(ceil(float(hero.max_hp)*0.35))
	var focus := int(ceil(float(hero.max_fp)*0.35))
	return {
		"attack":attack,
		"guard":"ตั้งรับ: ความเสียหายที่ได้รับลดครึ่งจนถึงตาถัดไปของคุณ · เหมาะเมื่อศัตรูเตรียมท่าหนัก",
		"vent":"ระบายไอ: แรงดัน %d → %d · แรงดันเกิน 100 จะใช้สกิลที่เพิ่มแรงดันไม่ได้" % [hero.pressure,maxi(0,int(hero.pressure)-35)],
		"life_potion":"ยาHP: ฟื้น HP %d (35%%) · เหลือ %d ขวด · ใช้หนึ่งตา" % [mini(life,int(hero.max_hp)-int(hero.hp)),hero.potions.life],
		"focus_potion":"ยาFP: ฟื้น FP %d (35%%) · เหลือ %d ขวด · ใช้หนึ่งตา" % [mini(focus,int(hero.max_fp)-int(hero.fp)),hero.potions.focus],
		"retreat":"ถอย: จบการฝึกและเก็บ XP ที่ทำได้" if not controller.training_id.is_empty() else "ถอย: ออกจากไฟต์ ไม่ได้รางวัล ฟื้น HP/FP เต็ม เสียพลังงาน 4 กลับจุดพัก",
	}

func _play_feedback(events: Array) -> void:
	if events.is_empty(): return
	await get_tree().process_frame
	if is_instance_valid(feedback):
		feedback.play_events(events,portraits,effect_options)

func _submit(kind: String, skill: String) -> void:
	if pumping or settled or paused or card != null or feedback.playing > 0:
		return
	focus_action = "Skill_" + skill if kind == "skill" else {"attack":"Basic_Attack","guard":"Basic_Guard","vent":"Basic_Vent","life_potion":"Basic_Life","focus_potion":"Basic_Focus","retreat":"Basic_Retreat"}.get(kind,"Basic_Attack")
	var result := controller.submit_player(kind,skill,selected_target)
	if not result.ok:
		last_log = result.reason
		_render()
		return
	_render(result.events)
	_pump()

func _pump() -> void:
	if pumping or settled or controller.is_player_turn():
		return
	pumping = true
	while is_inside_tree():
		await get_tree().create_timer(0.24).timeout
		# Each turn waits for the previous dash/strike to land before the next actor moves.
		while is_inside_tree() and (feedback.playing > 0 or paused):
			await get_tree().process_frame
		if not is_inside_tree():
			return
		if controller.is_finished():
			settled = true
			await _victory()
			finished.emit()
			return
		var result := controller.advance()
		if not result.ok:
			last_log = result.reason
			pumping = false
			_render()
			return
		_render(result.events)
		if controller.is_player_turn():
			break
	pumping = false
	_render()

func _victory() -> void:
	if controller.state.get("outcome","") != "victory" or not controller.training_id.is_empty():
		return
	var fallen: Array = portraits.keys().filter(func(id): return id != "hero")
	var source: ActorPortrait = portraits[fallen.back()] if not fallen.is_empty() else portraits.hero
	var item_id := GameSession.pick_drop(controller.encounter,controller.result_payload().id) if controller.first_clear else ""
	var item: Dictionary = {}
	for candidate in controller.content.get("items",[]):
		if candidate.id == item_id: item = candidate
	await feedback.play_loot(source,int(controller.encounter.get("gold",0)),item,effect_options)

func _exit_tree() -> void:
	if hero_stage != null and hero_stage.get_parent() == null:
		hero_stage.free()

func _end_training() -> void:
	if card != null: return
	var result := controller.end_training()
	if result.ok and not settled:
		settled = true
		finished.emit()


func _focus_ready() -> void:
	if not is_inside_tree() or paused or card != null or not controller.is_player_turn():
		return
	var control = find_child(focus_action,true,false)
	if control == null or control.disabled:
		control = find_child("Basic_Attack",true,false)
	if control != null:
		control.grab_focus()
