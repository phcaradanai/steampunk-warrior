extends Control

var catalog := ContentCatalog.new()
var session: GameSession
var saves: SaveService
var settings: InputSettings
var audio: GameAudio
var combat_view: CombatView
var focus_return: WeakRef
var focus_hint: String = ""
var settings_modal: bool = false
var binding_target: String = ""
var backlog: Array[Dictionary] = []
var dialogue_label: Label
var dialogue_tween: Tween
var world_policy: WorldController
var world: WorldView
var combat: CombatController
var screen: Control
var screen_mode: String = "title"
var modal: Control
var modal_body: VBoxContainer
var modal_notice: Label
var modal_locked: bool = false
var hud: Label
var control_hint: Label
var status_line: Label
var interact_button: Button
var save_warning: String = ""
var reward_notice: String = ""
var request_sequence: int = 0
var request_prefix: String = ""
var return_position := Vector2(110,240)

func _ready() -> void:
	theme = UIBuilder.theme()
	request_prefix = Crypto.new().generate_random_bytes(8).hex_encode()
	catalog.load_all("res://data")
	var errors := catalog.validate_all()
	if not errors.is_empty():
		UIBuilder.label(self,"ข้อมูลเกมไม่สมบูรณ์\n" + "\n".join(errors),22)
		return
	if saves == null:
		saves = SaveService.new(catalog.data)
	settings = InputSettings.new(saves.directory.path_join("settings.cfg"))
	settings.load_settings()
	audio = GameAudio.new()
	add_child(audio)
	session = GameSession.new(catalog.data)
	world_policy = WorldController.new(catalog.data,session)
	_show_title()

func _clear_screen(mode: String) -> void:
	_close_modal(true)
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	world = null
	combat_view = null
	hud = null
	control_hint = null
	status_line = null
	screen_mode = mode
	if is_instance_valid(audio): audio.set_context("city" if mode != "combat" else "boss" if not combat.encounter.get("boss_id","").is_empty() else "combat")
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)

func _show_title() -> void:
	reward_notice = ""
	_clear_screen("title")
	var background := TextureRect.new()
	background.texture = load("res://art/environments/title.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.02,0.08,0.09,0.68)
	shade.position = Vector2(42,42)
	shade.size = Vector2(710,630)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(shade)
	var column := VBoxContainer.new()
	column.position = Vector2(70,70)
	column.size = Vector2(654,560)
	column.add_theme_constant_override("separation",18)
	screen.add_child(column)
	UIBuilder.label(column,"STEAMPUNK WARRIOR",18,Color("8bb2a3"))
	UIBuilder.label(column,"เถ้าถ่านแห่งนครเหล็ก",40,Color("e7c588"))
	UIBuilder.label(column,catalog.data.story.prologue,20)
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation",12)
	actions.add_theme_constant_override("v_separation",12)
	column.add_child(actions)
	var begin := UIBuilder.button(actions,"เริ่มการเดินทาง",_show_classes,"NewGame")
	begin.custom_minimum_size.x = 315
	if saves.load_slot("autosave").ok:
		UIBuilder.button(actions,"เล่นต่อ",_load_slot.bind("autosave"),"Continue").custom_minimum_size.x = 315
	UIBuilder.button(actions,"โหลดบันทึก",_show_save_slots,"LoadGame").custom_minimum_size.x = 315
	UIBuilder.button(actions,"ตั้งค่า",_show_settings,"OpenSettings").custom_minimum_size.x = 315
	UIBuilder.button(actions,"ออกจากเกม",func():get_tree().quit()).custom_minimum_size.x = 315
	UIBuilder.label(column,settings.warning if not settings.warning.is_empty() else str(ProjectSettings.get_setting("application/config/version"))+" · ภาษาไทย · เล่นคนเดียวออฟไลน์",14,Color("a2b6a7"))
	begin.grab_focus.call_deferred()

func _show_classes() -> void:
	_clear_screen("classes")
	var column := VBoxContainer.new()
	column.position = Vector2(180,55)
	column.size = Vector2(920,610)
	column.add_theme_constant_override("separation",12)
	screen.add_child(column)
	UIBuilder.label(column,"คุณเป็นใครในนครเวสเปอร์",32,Color("e7c588"))
	UIBuilder.label(column,"ทุกอาชีพเรียนสกิลร่วมกันได้ แต่ความถนัดและความสามารถประจำตัวต่างกัน",18)
	var first: Button
	for profession in catalog.data.classes:
		var button := UIBuilder.button(column,profession.name + "\n" + profession.trait,_new_game.bind(profession.id),"Class_" + profession.id)
		button.custom_minimum_size.y = 76
		if first == null:
			first = button
	UIBuilder.button(column,"กลับ",_show_title)
	first.grab_focus.call_deferred()

func _new_game(class_id: String) -> void:
	var result := session.new_game(class_id)
	if result.ok:
		backlog.clear()
		_show_world()
		_autosave()

func _show_world() -> void:
	_clear_screen("world")
	var room: Dictionary = catalog.get_entry("rooms",session.state.room_id)
	var heading := UIBuilder.label(screen,room.name,32,Color("e7c588"))
	heading.position = Vector2(24,18)
	heading.size = Vector2(710,50)
	var toolbar := HBoxContainer.new()
	toolbar.position = Vector2(780,24)
	toolbar.size = Vector2(460,44)
	screen.add_child(toolbar)
	UIBuilder.button(toolbar,"บันทึก",_show_save_slots,"OpenSave")
	UIBuilder.button(toolbar,"ตั้งค่า",_show_settings,"OpenSettings")
	UIBuilder.button(toolbar,"บทคุย",_show_backlog,"OpenBacklog")
	status_line = UIBuilder.label(screen,"นครเวสเปอร์ · สำรวจเครื่องจักร คุยกับผู้คน และเลือกการต่อสู้",16,Color("8fb4a6"))
	status_line.position = Vector2(26,80)
	status_line.size = Vector2(1210,45)
	var side := VBoxContainer.new()
	side.position = Vector2(24,150)
	side.size = Vector2(230,480)
	side.add_theme_constant_override("separation",10)
	screen.add_child(side)
	hud = UIBuilder.label(side,"",18)
	UIBuilder.label(side,room.purpose,16,Color("a7b6a5"))
	UIBuilder.button(side,"กระเป๋าและอุปกรณ์",_show_inventory,"OpenInventory")
	UIBuilder.button(side,"สกิลและค่าสถานะ",_show_skills)
	UIBuilder.button(side,"สมุดภารกิจ",_show_quests)
	world = WorldView.new()
	world.position = Vector2(280,150)
	world.configure(catalog.data,session.snapshot(),session.state.checkpoint.get("spawn_id","entry"))
	world.marker_selected.connect(_interact)
	world.nearby_changed.connect(_nearby_changed)
	screen.add_child(world)
	interact_button = UIBuilder.button(screen,"เข้าใกล้สิ่งที่ต้องการ แล้วกด E หรือคลิกที่นี่",_activate,"Interact")
	interact_button.position = Vector2(280,650)
	interact_button.size = Vector2(960,48)
	interact_button.disabled = true
	control_hint = UIBuilder.label(screen,_control_hint_text(),14,Color("8fa497"))
	control_hint.position = Vector2(24,650)
	control_hint.size = Vector2(230,60)
	_refresh_hud()
	_check_pending_ending.call_deferred()

func _refresh_hud() -> void:
	if session == null or session.state.is_empty():
		return
	if is_instance_valid(hud):
		var p: Dictionary = session.state.player
		var stats := session.progression.derive(p,catalog.data)
		hud.text = "%s · เลเวล %d\nHP %d / %d\nFP %d / %d\nพลังงาน %d / 100\nเงิน %d เฟือง\nXP %d / %d" % [catalog.get_entry("classes",p.class_id).name,p.level,p.current_hp,stats.max_hp,p.current_fp,stats.max_fp,p.energy,p.currency,p.xp,session.progression.xp_to_next(int(p.level))]
	if is_instance_valid(control_hint):
		control_hint.text = _control_hint_text()
	if is_instance_valid(world):
		world.refresh(session.snapshot())

func _nearby_changed(marker: Dictionary) -> void:
	if not is_instance_valid(interact_button):
		return
	interact_button.disabled = marker.is_empty()
	interact_button.text = "เข้าใกล้สิ่งที่ต้องการ แล้วกด E" if marker.is_empty() else settings.binding_label("interact") + "  |  " + marker.label

func _activate() -> void:
	if is_instance_valid(world):
		world.activate_nearest()

func _message(text: String) -> void:
	if is_instance_valid(status_line):
		status_line.text = text
	if is_instance_valid(modal_notice):
		modal_notice.text = text

func _commit(kind: String, payload: Dictionary = {}) -> Dictionary:
	request_sequence += 1
	payload["id"] = "ui:" + request_prefix + ":" + str(request_sequence)
	var result := session.commit_result(kind,payload)
	_record_reward_notices(result.get("events",[]))
	_refresh_hud()
	if not result.ok:
		_message(result.reason)
	elif screen_mode == "world":
		_autosave()
	return result

func _interact(marker: Dictionary) -> void:
	match marker.kind:
		"exit", "fast_travel":
			if not world_policy.can_travel(session.state.room_id,marker.id,session.state):
				_message("ทางยังไม่เปิด ผ่านบอสของเขตก่อนหน้าก่อน")
				return
			var spawn := "right" if int(marker.id.substr(1)) < int(session.state.room_id.substr(1)) and marker.id != "R01" else "entry"
			world_policy.enter_room(marker.id,spawn)
			_show_world()
			_autosave()
		"rest":
			if _commit("rest").ok:
				_message("พักฟรี ฟื้น HP / FP / พลังงานเต็มแล้ว")
		"objective":
			if _commit("quest_event",{"event":{"type":"interact","payload":{"object_id":marker.id}}}).ok:
				_message("สำรวจ " + marker.label + " แล้ว กลับไปคุยกับผู้เกี่ยวข้องได้")
		"environment":
			if _commit("environment",{"object_id":marker.id}).ok:
				_message("ปรับวาล์วแล้ว: "+marker.label)
		"npc": _talk_npc(marker.id)
		"shop": _show_shop()
		"training": _show_training()
		"encounter": _confirm_encounter(marker.id)

func _open_modal(title: String, allow_close: bool = true) -> void:
	if not is_instance_valid(modal):
		var focused := get_viewport().gui_get_focus_owner()
		focus_return = weakref(focused) if focused != null else null
	_close_modal(true)
	if is_instance_valid(audio): audio.duck(true)
	modal_locked = not allow_close
	if is_instance_valid(combat_view):
		combat_view.paused = true
	if is_instance_valid(world):
		world.blocked = true
	var shade := ColorRect.new()
	shade.name = "ModalShade"
	shade.color = Color(0,0,0,0.75)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(shade)
	modal = shade
	var panel := PanelContainer.new()
	panel.position = Vector2(180,55)
	panel.size = Vector2(920,610)
	shade.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",10)
	panel.add_child(layout)
	UIBuilder.label(layout,title,26,Color("e7c588"))
	modal_notice = UIBuilder.label(layout,"\n".join([save_warning,reward_notice]).strip_edges(),15,Color("95c5b1"))
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 410
	layout.add_child(scroll)
	modal_body = VBoxContainer.new()
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_body.add_theme_constant_override("separation",8)
	scroll.add_child(modal_body)
	if allow_close:
		UIBuilder.button(layout,"ปิด / กลับ",_close_modal.bind(false),"CloseModal")
	_focus_modal.call_deferred()

func _close_modal(force: bool = false) -> void:
	if modal_locked and not force:
		return
	if not is_instance_valid(modal):
		return
	if not force: reward_notice = ""
	if settings_modal:
		var saved := settings.save_settings()
		if not saved.ok:
			save_warning = saved.reason
	settings_modal = false
	binding_target = ""
	if is_instance_valid(modal):
		modal.get_parent().remove_child(modal)
		modal.queue_free()
	modal = null
	if is_instance_valid(audio): audio.duck(false)
	modal_notice = null
	modal_locked = false
	if is_instance_valid(world):
		world.blocked = false
		_nearby_changed(world.nearby)
		_refresh_hud()
	if is_instance_valid(combat_view):
		combat_view.paused = false
	_restore_focus.call_deferred(focus_return)

func _talk_npc(npc_id: String) -> void:
	for quest in catalog.data.story.quests:
		if quest.npc_id == npc_id and quest.room == session.state.room_id:
			_show_dialogue("D" + str(quest.id).substr(1))
			return
	_open_modal(_npc_name(npc_id))
	var service := DialogueService.new(catalog.data)
	var text := service.ambient_line(npc_id,session.state)
	UIBuilder.label(modal_body,text,20)
	_add_backlog(_npc_name(npc_id),text)

func _npc_name(id: String) -> String:
	for npc in catalog.data.story.npcs:
		if npc.id == id:
			return npc.name
	return "ผู้คนในเมือง"

func _show_dialogue(node_id: String) -> void:
	var node: Dictionary = {}
	for candidate in catalog.data.story.dialogue:
		if candidate.id == node_id:
			node = candidate
	if node.is_empty():
		return
	_open_modal(_npc_name(node.speaker))
	var service := DialogueService.new(catalog.data)
	var text := service.get_text(node_id,session.state)
	var dialogue_row := HBoxContainer.new()
	dialogue_row.add_theme_constant_override("separation",18)
	modal_body.add_child(dialogue_row)
	var portrait := ActorPortrait.new()
	portrait.actor_id = node.speaker
	portrait.custom_minimum_size = Vector2(100,150)
	dialogue_row.add_child(portrait)
	dialogue_label = UIBuilder.label(dialogue_row,text,21)
	dialogue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_backlog(_npc_name(node.speaker),text)
	var important: bool = session.state.quest_states[node.quest_id].get("pending_choice", "") == "harvest"
	if not settings.options.instant_text and not important:
		dialogue_label.visible_ratio = 0.0
		dialogue_tween = dialogue_label.create_tween()
		dialogue_tween.tween_property(dialogue_label,"visible_ratio",1.0,float(text.length()) / float(settings.options.text_speed))
		UIBuilder.button(modal_body,"แสดงข้อความทันที",_show_text_instant)
	for choice in service.available_choices(node_id,session.state):
		UIBuilder.button(modal_body,choice.text,_choose_dialogue.bind(node_id,choice.id))

func _choose_dialogue(node_id: String, choice_id: String) -> void:
	if choice_id == "leave":
		_close_modal()
		return
	var service := DialogueService.new(catalog.data)
	for choice in service.available_choices(node_id,session.state):
		if choice.id == choice_id:
			_add_backlog("คุณ",choice.text)
	if _commit("dialogue_choice",{"node_id":node_id,"choice_id":choice_id}).ok:
		_show_dialogue(node_id)

func _show_inventory() -> void:
	_open_modal("อุปกรณ์และคลังโรงซ่อม")
	for slot in ["weapon","shield","head","suit"]:
		var id: String = session.state.player.equipment.get(slot, "")
		if not id.is_empty():
			var equipped := catalog.get_entry("items",id)
			var button := UIBuilder.button(modal_body,"ถอด " + equipped.name+"\n"+UIBuilder.item_description(equipped),_inventory_action.bind({"kind":"unequip","slot":slot},false))
			button.icon = UIBuilder.item_icon(equipped)
	UIBuilder.label(modal_body,"กระเป๋า %d / 24" % session.state.player.items.size(),20)
	for i in range(session.state.player.items.size()):
		var item := catalog.get_entry("items",session.state.player.items[i])
		var row := HBoxContainer.new()
		modal_body.add_child(row)
		var icon := TextureRect.new()
		icon.texture = UIBuilder.item_icon(item)
		icon.custom_minimum_size = Vector2(36,36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label := UIBuilder.label(row,"%s · เลเวล %d\n%s" % [item.name,item.required_level,UIBuilder.item_description(item)],17)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIBuilder.button(row,"สวม",_inventory_action.bind({"kind":"equip","index":i},false))
		UIBuilder.button(row,"ขาย",_inventory_action.bind({"kind":"sell","index":i},false))
		UIBuilder.button(row,"ฝาก",_inventory_action.bind({"kind":"stash_put","index":i},false))
	if session.state.room_id == "R01":
		UIBuilder.label(modal_body,"คลัง",20)
		for i in range(session.state.player.stash.size()):
			UIBuilder.button(modal_body,"รับ " + catalog.get_entry("items",session.state.player.stash[i]).name,_inventory_action.bind({"kind":"stash_take","index":i},false))

func _inventory_action(request: Dictionary, shop: bool) -> void:
	var result := _commit("inventory",{"request":request})
	if result.ok:
		if shop:
			_show_shop()
		else:
			_show_inventory()

func _show_shop() -> void:
	_open_modal("ร้านอุปกรณ์ · เงิน %d เฟือง" % session.state.player.currency)
	for item in catalog.data.items:
		if item.source == "shop:" + session.state.room_id:
			var button := UIBuilder.button(modal_body,"%s · %d เฟือง · เลเวล %d\n%s" % [item.name,item.price,item.required_level,UIBuilder.item_description(item)],_inventory_action.bind({"kind":"buy","item_id":item.id},true))
			button.icon = UIBuilder.item_icon(item)
	UIBuilder.button(modal_body,"ยาHP · 20 เฟือง",_inventory_action.bind({"kind":"potion_buy","potion":"life"},true))
	UIBuilder.button(modal_body,"ยาFP · 20 เฟือง",_inventory_action.bind({"kind":"potion_buy","potion":"focus"},true))
	UIBuilder.button(modal_body,"อาหาร พลังงาน+50 · 30 เฟือง",_inventory_action.bind({"kind":"food"},true))

func _show_skills() -> void:
	var p: Dictionary = session.state.player
	_open_modal("แต้มสกิล %d · แต้มค่าสถานะ %d" % [p.skill_points,p.attribute_points])
	var attributes := HBoxContainer.new()
	modal_body.add_child(attributes)
	var names: Dictionary = {"VIT":"ความทนทาน","STR":"กำลัง","INT":"เทคโนโลยี","AGI":"ความคล่อง"}
	for attribute in ["VIT","STR","INT","AGI"]:
		var button := UIBuilder.button(attributes,"%s %d +" % [names[attribute],p.base_attributes[attribute]],_grow.bind("allocate_attribute",{"attribute":attribute}))
		button.disabled = p.attribute_points <= 0
	if session.state.room_id == "R01":
		UIBuilder.button(modal_body,"คืนแต้มสกิลฟรี (คงสกิลเริ่มอาชีพ)",_grow.bind("respec",{}))
	var actor := session.progression.derive(p,catalog.data)
	actor["class_id"] = p.class_id
	var resolver := CombatResolver.new()
	for skill in catalog.data.skills:
		var rank: int = int(p.skill_ranks.get(skill.id,0))
		var button := UIBuilder.button(modal_body,"%s · ระดับ %d/10 · เรียน +" % [skill.name,rank],_grow.bind("learn_skill",{"skill_id":skill.id}),"Learn_"+skill.id)
		button.disabled = not session.progression.learn_skill(p,skill.id).ok
		var preview := resolver.skill_preview(actor,skill,maxi(1,rank))
		var description := UIBuilder.skill_description(skill,preview,maxi(1,rank))
		var parents: Array[String] = []
		for id in skill.parents:
			parents.append(catalog.get_entry("skills",id).name)
		description += "\nต้องเลเวล %d" % skill.required_level
		if not parents.is_empty():
			description += " · ก่อนหน้า: " + " และ ".join(parents)
		button.tooltip_text = description
		UIBuilder.label(modal_body,description,15,Color("a7b9ac"))

func _grow(kind: String, payload: Dictionary) -> void:
	if _commit(kind,payload).ok:
		_show_skills()

func _show_quests() -> void:
	_open_modal("สมุดภารกิจ")
	var states: Dictionary = {"available":"ยังไม่รับ","active":"กำลังสำรวจ","objectives_complete":"กลับไปคุยได้","turned_in":"เสร็จแล้ว"}
	for quest in catalog.data.story.quests:
		UIBuilder.label(modal_body,"%s — %s\n%s · %s" % [quest.name,states.get(session.state.quest_states[quest.id].state,"—"),catalog.get_entry("rooms",quest.room).name,quest.object_name],18)

func _show_training() -> void:
	_open_modal("โรงฝึกหม้อน้ำ · สกิลยืม ไม่ใช้แต้มจริง")
	var service := TrainingService.new(catalog.data)
	for tier in catalog.data.training:
		var button := UIBuilder.button(modal_body,tier.name + " — " + tier.focus,_start_training.bind(tier.id),"Training_"+tier.id)
		button.disabled = not service.start(tier.id,session.state).ok

func _confirm_encounter(id: String) -> void:
	var allowed := world_policy.can_start_encounter(id,session.state)
	if not allowed.ok:
		_message(allowed.reason)
		return
	var encounter := catalog.get_entry("encounters",id)
	_open_modal(encounter.name)
	if not encounter.boss_id.is_empty():
		UIBuilder.label(modal_body,catalog.data.story.boss_intros.get(encounter.boss_id,""),20,Color("d9c8a0"))
	var room := catalog.get_entry("rooms",encounter.room)
	if not room.hazard.is_empty() and WorldController.hazard_active(room.id,session.state.world_flags):
		UIBuilder.label(modal_body,"อันตรายเริ่มไฟต์: "+{"Wet":"ทั้งสองฝ่ายเปียก2เทิร์น ไฟฟ้าจะแรงขึ้น","Corroded":"เกราะคุณผุ2เทิร์น","Heated":"คุณร้อนจัด2เทิร์น"}[room.hazard]+" · ปรับวาล์วในห้องเพื่อลดอันตรายได้",18,Color("e6b984"))
	UIBuilder.label(modal_body,"เริ่มการต่อสู้โดยสมัครใจ\nใช้พลังงาน %d เมื่อจบ · ถ้าแพ้กลับจุดพัก พลังงานลด4\nอ่านสัญญาณศัตรูก่อนเลือกท่า" % encounter.energy_cost,20)
	if encounter.boss_id == "B06":
		UIBuilder.label(modal_body,"นี่คือการต่อสู้สุดท้าย ตรวจภารกิจและหลักฐานก่อนยืนยัน หากยังไม่พร้อมกลับไปสำรวจได้",20,Color("e6b984"))
		var service := DialogueService.new(catalog.data)
		if not "Cure" in service.get_ending_options(session.state):
			UIBuilder.label(modal_body,"Cure ยังไม่เปิด ต้องช่วยตัวอย่างที่ยังมีชีวิตและส่งคำสั่งต้นฉบับ หากเลือกทำลายรังแล้วจะปิดในเซฟนี้",18)
	UIBuilder.button(modal_body,"เริ่มต่อสู้",_start_encounter.bind(id),"ConfirmEncounter")

func _start_encounter(id: String) -> void:
	combat = CombatController.new(catalog.data)
	var result := combat.start(id,session.snapshot(),randi())
	if not result.ok:
		_message(result.reason)
		return
	return_position = world.player.position
	_autosave()
	_show_combat()

func _start_training(id: String) -> void:
	combat = CombatController.new(catalog.data)
	var result := combat.start_training(id,session.snapshot(),randi())
	if not result.ok:
		_message(result.reason)
		return
	return_position = world.player.position
	_show_combat()

func _show_combat() -> void:
	_clear_screen("combat")
	var view := CombatView.new()
	combat_view = view
	view.configure(combat)
	view.effect_options = settings.options
	view.finished.connect(_finish_combat)
	screen.add_child(view)

func _finish_combat() -> void:
	audio.play_sfx("victory" if combat.state.outcome in ["victory","training_end"] else "defeat")
	var kind := "training_settle" if not combat.training_id.is_empty() else ("battle_won" if combat.state.outcome == "victory" else "battle_lost")
	if combat.state.outcome == "retreat" and combat.training_id.is_empty():
		kind = "retreat"
	var result := session.commit_result(kind,combat.result_payload())
	_record_reward_notices(result.get("events",[]))
	var practice: bool = not combat.training_id.is_empty()
	var won: bool = practice or combat.state.outcome in ["victory","training_end"]
	_show_world()
	if won:
		world.player.position = return_position
	if not result.ok:
		_message(result.reason)
		return
	_autosave()
	if combat.encounter.get("boss_id", "") == "B06" and won:
		_show_ending_choices()
		return
	_open_modal("จบการฝึก" if practice else ("ผ่านการต่อสู้" if won else "กลับสู่จุดพัก"))
	for event in result.events:
		if event.type == "battle_won":
			UIBuilder.label(modal_body,"XP +%d · เงิน +%d" % [event.payload.xp,event.payload.gold],24)
		elif event.type == "training_settled":
			UIBuilder.label(modal_body,"เก็บเป้าหมายสำเร็จแล้ว · XP +%d" % event.payload.xp,24)
	if not won:
		UIBuilder.label(modal_body,"ฟื้น HP/FP แล้ว พลังงานลด4 เปลี่ยนอุปกรณ์หรือกลับโรงซ่อมพักฟรีก่อนลองใหม่ได้",20)

func _show_ending_choices() -> void:
	_open_modal("เสียงของเมืองอยู่ในมือคุณ",false)
	var service := DialogueService.new(catalog.data)
	for id in service.get_ending_options(session.state):
		for ending in catalog.data.story.endings:
			if ending.id == id:
				UIBuilder.button(modal_body,ending.name,_choose_ending.bind(id),"Ending_"+id)

func _choose_ending(id: String) -> void:
	if not _commit("choose_ending",{"ending":id}).ok:
		return
	_show_world()
	for ending in catalog.data.story.endings:
		if ending.id == id:
			_open_modal(ending.name)
			UIBuilder.label(modal_body,ending.text,24)
			var epilogue := DialogueService.new(catalog.data).get_epilogue(session.state)
			if not epilogue.is_empty(): UIBuilder.label(modal_body,epilogue,20)
			UIBuilder.label(modal_body,"กลับมาสำรวจต่อได้ รางวัลผ่านครั้งแรกจะไม่แจกซ้ำ",17)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(modal):
			_close_modal()
		elif screen_mode in ["world","combat"]:
			_open_modal("หยุดพัก")
			if screen_mode == "world":
				UIBuilder.button(modal_body,"บันทึก / โหลด",_show_save_slots)
			UIBuilder.button(modal_body,"ตั้งค่า",_show_settings)
			UIBuilder.label(modal_body,"บันทึกอัตโนมัติหลังเปลี่ยนห้องและทำรายการสำเร็จ ไม่บันทึกกลางไฟต์",18)
		get_viewport().set_input_as_handled()


func _autosave() -> void:
	if screen_mode != "world" or session.state.is_empty():
		return
	var result := saves.save_slot("autosave",session.snapshot())
	save_warning = "" if result.ok else result.reason + " · ใช้ช่องบันทึกอื่นได้"
	if not result.ok:
		_message(save_warning)

func _show_save_slots() -> void:
	_open_modal("บันทึก / โหลด · 3ช่องและอัตโนมัติ")
	for slot in saves.list_slots():
		var label: String = "อัตโนมัติ" if slot.id == "autosave" else "ช่อง " + str(slot.id).right(2)
		if slot.valid:
			label += " · เลเวล %d · %s" % [slot.level,catalog.get_entry("rooms",slot.room_id).name]
		elif slot.exists:
			label += " · " + slot.reason
		else:
			label += " · ว่าง"
		UIBuilder.label(modal_body,label,18)
		var actions := HBoxContainer.new()
		modal_body.add_child(actions)
		if slot.id != "autosave" and screen_mode == "world" and not session.state.is_empty():
			UIBuilder.button(actions,"บันทึกช่องนี้",_save_slot.bind(slot.id),"Save_"+slot.id)
		if slot.valid:
			UIBuilder.button(actions,"โหลด",_load_slot.bind(slot.id),"Load_"+slot.id)
		if slot.backup_available:
			UIBuilder.button(actions,"กู้สำรอง (เก็บไฟล์ปัจจุบันแยก)",_confirm_recovery.bind(slot.id))

func _save_slot(id: String) -> void:
	if screen_mode != "world":
		return
	var result := saves.save_slot(id,session.snapshot())
	if result.ok:
		_show_save_slots()
	_message(result.reason)

func _load_slot(id: String) -> void:
	var result := saves.load_slot(id)
	if not result.ok:
		_message(result.reason)
		return
	session.state = result.state
	reward_notice = ""
	backlog.clear()
	session.recent_commits.clear()
	_show_world()
	_message("โหลดบันทึกแล้ว")
	_autosave()

func _confirm_recovery(id: String) -> void:
	_open_modal("กู้คืนจากไฟล์สำรอง")
	UIBuilder.label(modal_body,"จะใช้สำรองล่าสุดที่ผ่านการตรวจ ไฟล์ปัจจุบันจะถูกเก็บแยกไว้ ไม่ลบทิ้ง",20)
	UIBuilder.button(modal_body,"ยืนยันกู้สำรอง",_recover_slot.bind(id))

func _recover_slot(id: String) -> void:
	var result := saves.restore_backup(id)
	if not result.ok:
		_message(result.reason)
		return
	session.state = result.state
	reward_notice = ""
	backlog.clear()
	session.recent_commits.clear()
	_show_world()
	_message(result.reason)

func _check_pending_ending() -> void:
	if screen_mode == "world" and session.state.first_clears.has("B06") and not session.state.world_flags.get("postgame",false):
		_show_ending_choices()


func _focus_modal() -> void:
	if not is_instance_valid(modal):
		return
	var controls: Array[Control] = []
	for control in modal.find_children("*","Control",true,false):
		if control.focus_mode == Control.FOCUS_NONE or not control.is_visible_in_tree(): continue
		if control is BaseButton and control.disabled: continue
		controls.append(control)
	for i in controls.size():
		var control := controls[i]
		var previous := control.get_path_to(controls[posmod(i-1,controls.size())])
		var next := control.get_path_to(controls[(i+1)%controls.size()])
		control.focus_previous = previous
		control.focus_next = next
		control.focus_neighbor_top = previous
		control.focus_neighbor_left = previous
		control.focus_neighbor_bottom = next
		control.focus_neighbor_right = next
	if not focus_hint.is_empty():
		var hinted = modal.find_child(focus_hint,true,false)
		focus_hint = ""
		if hinted is BaseButton and not hinted.disabled:
			hinted.grab_focus()
			return
	for control in modal_body.find_children("*","Control",true,false):
		if control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree():
			if control is BaseButton and control.disabled:
				continue
			control.grab_focus()
			return
	var close = modal.find_child("CloseModal",true,false)
	if close != null:
		close.grab_focus()

func _record_reward_notices(events: Array) -> void:
	var names: Array[String] = []
	for event in events:
		if event.type == "stash_overflow": names.append(catalog.get_entry("items",event.payload.item_id).name)
	if not names.is_empty():
		reward_notice = "กระเป๋าเต็ม: "+" · ".join(names)+" ส่งเข้าคลังโรงซ่อมแล้ว กลับ R01 เพื่อรับได้"
		if is_instance_valid(modal_notice): modal_notice.text = "\n".join([save_warning,reward_notice]).strip_edges()

func _restore_focus(reference: WeakRef) -> void:
	if reference == null:
		return
	var control = reference.get_ref()
	if control is Control and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()

func _show_settings() -> void:
	_open_modal("ตั้งค่า · Enter ยืนยัน · Esc กลับ")
	settings_modal = true
	for key in ["master","music","sfx"]:
		var row := HBoxContainer.new()
		modal_body.add_child(row)
		var title: String = {"master":"เสียงรวม","music":"ดนตรี","sfx":"เสียงเอฟเฟกต์"}[key]
		UIBuilder.label(row,title,18).custom_minimum_size.x = 190
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.01
		slider.value = settings.options[key]
		slider.custom_minimum_size = Vector2(450,38)
		row.add_child(slider)
		slider.value_changed.connect(_set_volume.bind(key))
	for key in ["reduced_shake","reduced_flash","instant_text"]:
		var toggle := CheckButton.new()
		toggle.text = {"reduced_shake":"ลดการสั่นหน้าจอ","reduced_flash":"ลดแสงกะพริบ","instant_text":"แสดงบทคุยทันที"}[key]
		toggle.button_pressed = settings.options[key]
		modal_body.add_child(toggle)
		toggle.toggled.connect(_set_toggle.bind(key))
	UIBuilder.label(modal_body,"ความเร็วบทคุย",18)
	var speed := HSlider.new()
	speed.min_value = 1
	speed.max_value = 120
	speed.step = 1
	speed.value = settings.options.text_speed
	speed.custom_minimum_size.y = 36
	modal_body.add_child(speed)
	speed.value_changed.connect(func(value:float):settings.set_option("text_speed",int(value)))
	var modes := OptionButton.new()
	modes.add_item("หน้าต่าง")
	modes.add_item("เต็มหน้าจอ")
	modes.select(1 if settings.options.window_mode == "fullscreen" else 0)
	modal_body.add_child(modes)
	modes.item_selected.connect(func(index:int):settings.set_option("window_mode","fullscreen" if index==1 else "windowed"))
	var sizes := OptionButton.new()
	for size in ["960x540","1280x720","1920x1080"]:
		sizes.add_item(size)
	sizes.select(["960x540","1280x720","1920x1080"].find(settings.options.window_size))
	modal_body.add_child(sizes)
	sizes.item_selected.connect(func(index:int):settings.set_option("window_size",["960x540","1280x720","1920x1080"][index]))
	UIBuilder.label(modal_body,"ปุ่มเล่น · คลิกคำสั่งแล้วกดปุ่มใหม่",20)
	var names: Dictionary = {"move_left":"เดินซ้าย","move_right":"เดินขวา","move_up":"เดินขึ้น","move_down":"เดินลง","interact":"โต้ตอบ"}
	for action in InputSettings.DEFAULT_BINDINGS:
		UIBuilder.button(modal_body,names[action]+" · "+settings.binding_label(action),_capture_binding.bind(action),"Rebind_"+action)
	UIBuilder.button(modal_body,"คืนค่าเริ่มต้นทั้งหมด",_restore_settings)

func _set_volume(value: float, key: String) -> void:
	settings.set_option(key,value)

func _set_toggle(value: bool, key: String) -> void:
	settings.set_option(key,value)

func _restore_settings() -> void:
	settings.restore_defaults()
	_show_settings()

func _capture_binding(action: String) -> void:
	binding_target = action
	_message("กดปุ่มใหม่ · Esc ยกเลิกการเปลี่ยนปุ่ม")

func _input(event: InputEvent) -> void:
	if binding_target.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
		return
	var action := binding_target
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	binding_target = ""
	if code == KEY_ESCAPE:
		_message("ยกเลิกการเปลี่ยนปุ่มแล้ว")
	else:
		var result := settings.rebind(action,code)
		focus_hint = "Rebind_" + action
		_show_settings()
		_message("เปลี่ยนปุ่มแล้ว" if result.ok else result.reason)
	get_viewport().set_input_as_handled()

func _add_backlog(speaker: String, text: String) -> void:
	if not backlog.is_empty() and backlog[-1].speaker == speaker and backlog[-1].text == text:
		return
	backlog.append({"speaker":speaker,"text":text})
	if backlog.size() > 200:
		backlog.pop_front()

func _show_backlog() -> void:
	_open_modal("ประวัติบทคุย · การเดินทางครั้งนี้")
	if backlog.is_empty():
		UIBuilder.label(modal_body,"ยังไม่มีบทคุยที่อ่าน",20)
	for line in backlog:
		UIBuilder.label(modal_body,line.speaker,18,Color("d5ba7e"))
		UIBuilder.label(modal_body,line.text,18)

func _show_text_instant() -> void:
	if dialogue_tween != null and dialogue_tween.is_valid():
		dialogue_tween.kill()
	if is_instance_valid(dialogue_label):
		dialogue_label.visible_ratio = 1.0


func _control_hint_text() -> String:
	return "ซ้าย %s · ขวา %s\nขึ้น %s · ลง %s\n%s โต้ตอบ · Esc เมนู" % [settings.binding_label("move_left").split(" / ")[0],settings.binding_label("move_right").split(" / ")[0],settings.binding_label("move_up").split(" / ")[0],settings.binding_label("move_down").split(" / ")[0],settings.binding_label("interact")]
