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

func configure(active_controller: CombatController) -> void:
	controller = active_controller

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_render()
	_pump.call_deferred()

func _render(events: Array = []) -> void:
	get_tree().call_group("game_audio","combat_events",events)
	for event in events:
		if event.type == "damage":
			last_log = ("โล่รับ " if event.payload.get("shielded",false) else "ได้รับ ") + str(event.payload.amount) + " ความเสียหาย"
		elif event.type == "heal":
			last_log = "ฟื้นพลัง " + str(event.payload.amount)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	portraits.clear()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + edge,28)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",10)
	margin.add_child(layout)
	var title: String = controller.encounter.get("name", "โรงฝึกหม้อน้ำ")
	UIBuilder.label(layout, title,28,Color("d5ba7e"))
	UIBuilder.label(layout, "รอบ %d  ·  โล่รับแรงก่อนร่างกาย  ·  เปลี่ยนคิวได้ด้วยสถานะ" % int(controller.state.round),15)
	var cards := HBoxContainer.new()
	cards.custom_minimum_size.y = 194
	cards.add_theme_constant_override("separation",16)
	layout.add_child(cards)
	var living: Array[Dictionary] = []
	for actor in controller.state.actors:
		if actor.side == "enemy" and actor.hp > 0:
			living.append(actor)
	if not living.is_empty() and not living.any(func(a):return a.id == selected_target):
		selected_target = living[0].id
	for actor in controller.state.actors:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.add_child(panel)
		var row := HBoxContainer.new()
		panel.add_child(row)
		var portrait := ActorPortrait.new()
		portrait.actor_id = ActorArt.actor_id(actor)
		portrait.mirror = actor.side == "enemy"
		portrait.alive = actor.hp > 0
		portrait.custom_minimum_size = Vector2(190 if actor.get("boss",false) and controller.state.actors.size() == 2 else 110,140)
		row.add_child(portrait)
		portraits[actor.id] = portrait
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(column)
		UIBuilder.label(column,actor.get("name",actor.id),22,Color("f0d492") if actor.side=="player" else Color("d99882"))
		var health := ProgressBar.new()
		health.max_value = actor.max_hp
		health.value = actor.hp
		health.show_percentage = false
		health.custom_minimum_size.y = 12
		column.add_child(health)
		UIBuilder.label(column,"HP %d / %d   ·   โล่ %d" % [actor.hp,actor.max_hp,actor.barrier],16)
		if actor.side == "player":
			UIBuilder.label(column,"FP %d / %d   ·   แรงดัน %d / 100" % [actor.fp,actor.max_fp,actor.pressure],16)
		else:
			UIBuilder.label(column,"เตรียม: " + actor.get("intent",{}).get("label","—"),16,Color("edbd83"))
			if actor.get("boss",false):
				UIBuilder.label(column,"ช่วงที่ " + str(int(actor.get("phase",0)) + 1),14)
				if actor.get("definition_id","") == "B04": UIBuilder.label(column,"ความร้อน %d / 100" % actor.get("heat",0),14)
				if actor.get("core_exposed",false): UIBuilder.label(column,"แกนเปิด: เกราะและต้านทานลด55%",14)
			if actor.get("intent",{}).has("following_label"): UIBuilder.label(column,"ท่าหลังจากนี้: "+actor.intent.following_label,13,Color("91b7b5"))
		if not actor.statuses.is_empty():
			var status_names: Dictionary = {"Wet":"เปียก","Heated":"ร้อนจัด","Corroded":"เกราะผุ","Marked":"ถูกหมายหัว","Staggered":"เสียจังหวะ","Sealed":"ปิดการฟื้นฟู","Haste":"เร่งจังหวะ","Guard":"ตั้งรับ"}
			var active: Array[String] = []
			for status in actor.statuses:
				active.append("%s %d" % [status_names.get(status,status),actor.statuses[status].turns])
			UIBuilder.label(column," · ".join(active),14,Color("83bdaa"))
	UIBuilder.label(layout,last_log,18,Color("9fc7b5"))
	var selection := HBoxContainer.new()
	layout.add_child(selection)
	var target_label := UIBuilder.label(selection,"เป้าหมาย",16)
	target_label.custom_minimum_size.x = 100
	selection.custom_minimum_size.y = 42
	var targets := OptionButton.new()
	targets.custom_minimum_size = Vector2(260,42)
	targets.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	selection.add_child(targets)
	for i in range(living.size()):
		targets.add_item(living[i].name)
		if living[i].id == selected_target:
			targets.select(i)
	targets.item_selected.connect(func(index:int):selected_target=living[index].id)
	targets.disabled = not controller.is_player_turn() or paused
	var basics := HBoxContainer.new()
	layout.add_child(basics)
	var hero: Dictionary = controller.state.actors[0]
	var names: Array = [["attack","โจมตี","Basic_Attack"],["guard","ตั้งรับ","Basic_Guard"],["vent","ระบายไอ","Basic_Vent"],["life_potion","ยาHP (%d)" % hero.potions.life,"Basic_Life"],["focus_potion","ยาFP (%d)" % hero.potions.focus,"Basic_Focus"],["retreat","ถอย","Basic_Retreat"]]
	for data in names:
		var button := UIBuilder.button(basics,data[1],_submit.bind(data[0],""),data[2])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = not controller.is_player_turn() or paused
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 100
	layout.add_child(scroll)
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
		button.custom_minimum_size.x = 276
		button.disabled = not controller.is_player_turn() or paused or hero.fp < preview.fp_cost or hero.pressure + preview.pressure_delta > 100 or hero.cooldowns.get(skill.id,0) > 0
		button.tooltip_text = UIBuilder.skill_description(skill,preview,rank)
		button.icon = UIBuilder.skill_icon(skill)
		button.add_theme_constant_override("icon_max_width",24)
	if not controller.training_id.is_empty():
		var labels: Dictionary = {"attack":"โจมตี","guard":"ตั้งรับ","vent":"ระบายไอ","shield_break":"ทำลายโล่","marked_hit":"โจมตีเป้าติดเครื่องหมาย","heal":"ฟื้นพลัง","wet_combo":"ไฟฟ้าหลังทำให้เปียก","sealing":"หยุดการฮีล","cleanse":"ล้างความร้อน","pressure_safe":"ลดแรงดันสู่ช่วงปลอดภัย","intent_counter":"ตั้งรับท่าหนัก","drone":"ใช้โดรน"}
		var objectives: Array[String] = []
		for objective in TrainingService.OBJECTIVES[controller.training_id]:
			objectives.append(("✓ " if objective in controller.completed else "○ ") + labels[objective])
		UIBuilder.label(layout,"   ·   ".join(objectives),15)
		var finish := UIBuilder.button(layout,"จบการฝึกและเก็บ XP ที่ทำได้",_end_training,"FinishTraining")
		finish.disabled = not controller.is_player_turn() or paused
		UIBuilder.label(layout,"สกิลยืมใช้ได้เฉพาะการฝึก ไม่ใช้แต้มจริง",14,Color("9fc7b5"))

	feedback = CombatFeedback.new()
	feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(feedback)
	_play_feedback.call_deferred(events)
	_focus_ready.call_deferred()

func _play_feedback(events: Array) -> void:
	if events.is_empty(): return
	var current := feedback
	await get_tree().process_frame
	if is_instance_valid(current) and current == feedback:
		current.play_events(events,portraits,effect_options)

func _submit(kind: String, skill: String) -> void:
	if pumping or settled or paused:
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
		await get_tree().create_timer(0.36).timeout
		if not is_inside_tree():
			return
		if paused:
			continue
		if controller.is_finished():
			settled = true
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
