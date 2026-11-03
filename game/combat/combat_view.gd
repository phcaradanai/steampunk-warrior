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
const STAGE_TOP := 100.0
const STAGE_SIZE := Vector2(1280,400)
const GROUND := 352.0
const STATUS_NAMES := {"Wet":"เปียก","Heated":"ร้อนจัด","Corroded":"เกราะผุ","Marked":"ถูกหมายหัว","Staggered":"เสียจังหวะ","Sealed":"ปิดการฟื้นฟู","Haste":"เร่งจังหวะ","Guard":"ตั้งรับ"}

func configure(active_controller: CombatController) -> void:
	controller = active_controller

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	add_child(feedback)
	_render()
	_title_card()
	_pump.call_deferred()

func _process(_delta: float) -> void:
	if is_instance_valid(stage): stage.queue_redraw()
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
		portrait.size = Vector2(210,210) if actor.side == "player" else Vector2(250,250) if boss else Vector2(170,170)
		var center := 360.0
		var feet := GROUND
		if actor.side == "player":
			hero_stage = Hero3D.new()
			hero_stage.set_equipment(actor.get("equipment",{}),controller.content.get("items",[]))
			portrait.attach_hero(hero_stage)
			# Hero3D frames the model with its feet slightly above the viewport bottom.
			portrait.set_meta("feet",portrait.size.y*0.925)
		else:
			var index: int = enemies.find(actor)
			center = 900.0 if enemies.size() == 1 else 850.0 + index*190.0
			feet = GROUND - index*16.0
			portrait.set_meta("feet",portrait.size.y-4)
		portrait.position = Vector2(center-portrait.size.x*0.5, feet-portrait.get_meta("feet"))
		portrait.set_meta("home",portrait.position)
		stage.add_child(portrait)
		portraits[actor.id] = portrait
	wait_label = UIBuilder.label(stage,"…กำลังออกท่า…",18,Color("f1d9a0"))
	wait_label.position = Vector2(540,360)
	wait_label.size = Vector2(200,30)
	wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _title_card() -> void:
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
	var note := UIBuilder.label(stage,"\n".join(notes.filter(func(n): return not n.is_empty())),18,Color("e6b984"))
	note.position = Vector2(240,262)
	note.size = Vector2(800,80)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_outline_color",Color("0b1214"))
	note.add_theme_constant_override("outline_size",6)
	var hold := 2.6 if not notes.is_empty() else 0.9
	var card := UIBuilder.label(stage,text,34,Color("f1d9a0"))
	card.position = Vector2(0,150)
	card.size = Vector2(1280,110)
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_theme_color_override("font_outline_color",Color("0b1214"))
	card.add_theme_constant_override("outline_size",8)
	var fade := card.create_tween()
	fade.tween_interval(hold)
	fade.tween_property(card,"modulate:a",0.0,0.4)
	fade.tween_callback(card.queue_free)
	var fade_note := note.create_tween()
	fade_note.tween_interval(hold)
	fade_note.tween_property(note,"modulate:a",0.0,0.4)
	fade_note.tween_callback(note.queue_free)

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
		if portraits.has(actor.id):
			portraits[actor.id].alive = actor.hp > 0
			if actor.side == "player" and actor.hp <= 0: hero_stage.perform("down")
	if not living.is_empty() and not living.any(func(a):return a.id == selected_target):
		selected_target = living[0].id
	# Bars and sounds change on the contact frame, so plates wait for the strike to land.
	if events.is_empty(): _plates()
	else: _plates_when_idle()
	_commands(living)
	_play_feedback.call_deferred(events)
	_focus_ready.call_deferred()

func _plates_when_idle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	while is_inside_tree() and feedback.playing > 0:
		await get_tree().process_frame
	if is_inside_tree(): _plates()

func _plates() -> void:
	for child in plates.get_children():
		plates.remove_child(child)
		child.queue_free()
	var log_label := UIBuilder.label(plates,last_log,16,Color("9fc7b5"))
	log_label.position = Vector2(24,STAGE_TOP+STAGE_SIZE.y-34)
	log_label.size = Vector2(500,28)
	log_label.add_theme_color_override("font_outline_color",Color("0b1214"))
	log_label.add_theme_constant_override("outline_size",5)
	var enemies: Array = controller.state.actors.filter(func(a): return a.side == "enemy")
	var width := 600.0/maxf(1,enemies.size())
	for actor in controller.state.actors:
		var panel := PanelContainer.new()
		if actor.side == "player":
			panel.position = Vector2(20,8)
			panel.size = Vector2(600,86)
		else:
			panel.position = Vector2(660+enemies.find(actor)*width,8)
			panel.size = Vector2(width-(8 if enemies.size() > 1 else 0),86)
		plates.add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",2)
		panel.add_child(column)
		var head := HBoxContainer.new()
		column.add_child(head)
		var name_label := UIBuilder.label(head,actor.get("name",actor.id),18,Color("f0d492") if actor.side=="player" else Color("d99882"))
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIBuilder.label(head,"HP %d / %d" % [actor.hp,actor.max_hp] + ("  ·  โล่ %d" % actor.barrier if actor.barrier > 0 else ""),15).autowrap_mode = TextServer.AUTOWRAP_OFF
		var health := ProgressBar.new()
		health.max_value = actor.max_hp
		health.value = actor.hp
		health.show_percentage = false
		health.custom_minimum_size.y = 10
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("63b46e") if actor.side == "player" else Color("c9644e")
		health.add_theme_stylebox_override("fill",fill)
		column.add_child(health)
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
	var bar := VBoxContainer.new()
	bar.position = Vector2(20,STAGE_TOP+STAGE_SIZE.y+8)
	bar.size = Vector2(1240,720-STAGE_TOP-STAGE_SIZE.y-16)
	bar.add_theme_constant_override("separation",6)
	ui.add_child(bar)
	var basics := HBoxContainer.new()
	bar.add_child(basics)
	var targets := OptionButton.new()
	targets.custom_minimum_size = Vector2(220,42)
	basics.add_child(targets)
	for i in range(living.size()):
		targets.add_item(living[i].name)
		if living[i].id == selected_target:
			targets.select(i)
	targets.item_selected.connect(func(index:int):
		selected_target=living[index].id
		_render())
	targets.disabled = not idle
	targets.tooltip_text = "เป้าหมาย"
	var hero: Dictionary = controller.state.actors[0]
	var info := UIBuilder.label(ui,"",15,Color("e6d4a4"))
	info.position = Vector2(24,688)
	info.size = Vector2(1232,28)
	info.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.clip_text = true
	var tips := _basic_tips(hero)
	var names: Array = [["attack","โจมตี","Basic_Attack"],["guard","ตั้งรับ","Basic_Guard"],["vent","ระบายไอ","Basic_Vent"],["life_potion","ยาHP (%d)" % hero.potions.life,"Basic_Life"],["focus_potion","ยาFP (%d)" % hero.potions.focus,"Basic_Focus"],["retreat","ถอย","Basic_Retreat"]]
	for data in names:
		var button := UIBuilder.button(basics,data[1],_submit.bind(data[0],""),data[2])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = not idle
		_explain(button,tips[data[0]],info)
	if not controller.training_id.is_empty():
		var finish := UIBuilder.button(basics,"จบการฝึก",_end_training,"FinishTraining")
		finish.disabled = not idle
		var labels: Dictionary = {"attack":"โจมตี","guard":"ตั้งรับ","vent":"ระบายไอ","shield_break":"ทำลายโล่","marked_hit":"โจมตีเป้าติดเครื่องหมาย","heal":"ฟื้นพลัง","wet_combo":"ไฟฟ้าหลังทำให้เปียก","sealing":"หยุดการฮีล","cleanse":"ล้างความร้อน","pressure_safe":"ลดแรงดันสู่ช่วงปลอดภัย","intent_counter":"ตั้งรับท่าหนัก","drone":"ใช้โดรน"}
		var objectives: Array[String] = []
		for objective in TrainingService.OBJECTIVES[controller.training_id]:
			objectives.append(("✓ " if objective in controller.completed else "○ ") + labels[objective])
		var goals := UIBuilder.label(ui,"   ·   ".join(objectives) + "   (สกิลยืมใช้ได้เฉพาะการฝึก)",15)
		goals.position = Vector2(24,STAGE_TOP+8)
		goals.size = Vector2(1232,28)
		goals.add_theme_color_override("font_outline_color",Color("0b1214"))
		goals.add_theme_constant_override("outline_size",5)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.add_child(scroll)
	var skills := GridContainer.new()
	skills.columns = 4
	skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(skills)
	for skill in controller.content.skills:
		if skill.kind != "active" or not controller.learned.has(skill.id):
			continue
		var rank: int = int(controller.learned[skill.id])
		var preview := controller.resolver.skill_preview(hero,skill,rank)
		var button := UIBuilder.button(skills,"%s  ·  FP%d" % [skill.name,preview.fp_cost],_submit.bind("skill",skill.id),"Skill_"+skill.id)
		button.custom_minimum_size.x = 302
		button.disabled = not idle or hero.fp < preview.fp_cost or hero.pressure + preview.pressure_delta > 100 or hero.cooldowns.get(skill.id,0) > 0
		button.tooltip_text = UIBuilder.skill_description(skill,preview,rank)
		_explain(button,button.tooltip_text.replace("\n","  ·  "),info)
		button.icon = UIBuilder.skill_icon(skill)
		button.add_theme_constant_override("icon_max_width",24)

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
	if pumping or settled or paused or feedback.playing > 0:
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
	var result := controller.end_training()
	if result.ok and not settled:
		settled = true
		finished.emit()


func _focus_ready() -> void:
	if not is_inside_tree() or paused or not controller.is_player_turn():
		return
	var control = find_child(focus_action,true,false)
	if control == null or control.disabled:
		control = find_child("Basic_Attack",true,false)
	if control != null:
		control.grab_focus()
