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
var hud_bars: Dictionary = {}
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
	# The room fills the whole screen and the camera follows the hero; controls float over it as icons.
	world = WorldView.new()
	world.scale = Vector2.ONE*WorldView.FULL_SCALE
	world.follow = true
	world.configure(catalog.data,session.snapshot(),session.state.checkpoint.get("spawn_id","entry"))
	world.marker_selected.connect(_interact)
	world.nearby_changed.connect(_nearby_changed)
	screen.add_child(world)
	var stats := UIBuilder.glass_panel(screen,Vector2(16,16),Vector2(300,0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",4)
	stats.add_child(column)
	hud = UIBuilder.label(column,"",16,Color("f0d492"))
	hud.autowrap_mode = TextServer.AUTOWRAP_OFF
	hud_bars.clear()
	for entry in [["hp","potion_hp",Color("63b46e")],["fp","potion_fp",Color("5ab4e0")],["energy","energy",Color("e0b84a")]]:
		var row := HBoxContainer.new()
		column.add_child(row)
		var icon := TextureRect.new()
		icon.texture = load("res://art/icons/%s.svg" % entry[1])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(20,20)
		row.add_child(icon)
		var meter := UIBuilder.bar(row,0,1,entry[2],12)
		meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var amount := UIBuilder.label(row,"",13)
		amount.custom_minimum_size.x = 70
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hud_bars[entry[0]] = [meter,amount]
	var tools := HBoxContainer.new()
	tools.position = Vector2(1280-16-6*60,16)
	tools.add_theme_constant_override("separation",6)
	screen.add_child(tools)
	for entry in [["bag","กระเป๋าและอุปกรณ์: สวม ถอด หรือขายของ",_show_inventory,"OpenInventory"],["skills","สกิลและค่าสถานะ: ใช้แต้มที่ได้จากเลเวลอัป",_show_skills,"OpenSkills"],["quests","สมุดภารกิจ: งานที่รับอยู่และสิ่งที่ต้องทำต่อ",_show_quests,"OpenQuests"],["save","บันทึกหรือโหลดเกม",_show_save_slots,"OpenSave"],["settings","ตั้งค่าเสียง ปุ่ม และเอฟเฟกต์",_show_settings,"OpenSettings"],["log","อ่านบทสนทนาที่ผ่านมา",_show_backlog,"OpenBacklog"]]:
		var tool := UIBuilder.icon_button(tools,entry[0],entry[1],entry[2],entry[3],54)
		UIBuilder.hotkey(tool,{"OpenInventory":KEY_I,"OpenSkills":KEY_K,"OpenQuests":KEY_J,"OpenSave":KEY_F5,"OpenSettings":KEY_O,"OpenBacklog":KEY_L}[entry[3]])
	# Area title shows on entry then fades, like a mobile map banner.
	var banner := UIBuilder.label(screen,room.name + "\n" + room.purpose,26,Color("f1d9a0"))
	banner.position = Vector2(240,90)
	banner.size = Vector2(800,90)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_outline_color",Color("0b1214"))
	banner.add_theme_constant_override("outline_size",8)
	var fade := banner.create_tween()
	fade.tween_interval(2.2)
	fade.tween_property(banner,"modulate:a",0.0,0.6)
	status_line = UIBuilder.label(screen,"",16,Color("d8e6dc"))
	status_line.position = Vector2(240,640)
	status_line.size = Vector2(800,60)
	status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_line.add_theme_color_override("font_outline_color",Color("0b1214"))
	status_line.add_theme_constant_override("outline_size",6)
	interact_button = UIBuilder.icon_button(screen,"hand","เข้าใกล้สิ่งที่ต้องการ แล้วกด E",_activate,"Interact",96,"")
	interact_button.position = Vector2(1280-16-96,720-16-96)
	interact_button.disabled = true
	var help := UIBuilder.icon_button(screen,"help","ปุ่มควบคุม",func(): control_hint.get_parent().visible = not control_hint.get_parent().visible,"OpenHelp",48)
	help.position = Vector2(16,720-16-48)
	var hint_panel := UIBuilder.glass_panel(screen,Vector2(72,720-16-150),Vector2(300,150))
	hint_panel.visible = false
	control_hint = UIBuilder.label(hint_panel,_control_hint_text(),14,Color("c8d6cc"))
	_refresh_hud()
	_check_pending_ending.call_deferred()

func _refresh_hud() -> void:
	if session == null or session.state.is_empty():
		return
	if is_instance_valid(hud):
		var p: Dictionary = session.state.player
		var stats := session.progression.derive(p,catalog.data)
		hud.text = "Lv %d  ·  %d เฟือง  ·  XP %d/%d" % [p.level,p.currency,p.xp,session.progression.xp_to_next(int(p.level))]
		hud.tooltip_text = "%s · เงิน %d เฟือง" % [catalog.get_entry("classes",p.class_id).name,p.currency]
		hud.mouse_filter = Control.MOUSE_FILTER_PASS
		for entry in [["hp",p.current_hp,stats.max_hp],["fp",p.current_fp,stats.max_fp],["energy",p.energy,100]]:
			if not hud_bars.has(entry[0]) or not is_instance_valid(hud_bars[entry[0]][0]): continue
			hud_bars[entry[0]][0].max_value = entry[2]
			hud_bars[entry[0]][0].value = entry[1]
			hud_bars[entry[0]][1].text = "%d/%d" % [entry[1],entry[2]]
	if is_instance_valid(control_hint):
		control_hint.text = _control_hint_text()
	if is_instance_valid(world):
		world.refresh(session.snapshot())

func _nearby_changed(marker: Dictionary) -> void:
	if not is_instance_valid(interact_button):
		return
	interact_button.disabled = marker.is_empty()
	# The action button swaps its picture to what pressing it will do; the tooltip spells it out.
	interact_button.icon = load("res://art/icons/%s.svg" % ("hand" if marker.is_empty() else WorldView.marker_icon(marker)))
	interact_button.tooltip_text = "เข้าใกล้สิ่งที่ต้องการ แล้วกด E" if marker.is_empty() else settings.binding_label("interact") + "  |  " + marker.label
	interact_button.text = ""

func _activate() -> void:
	if is_instance_valid(world):
		world.activate_nearest()

func _message(text: String) -> void:
	if is_instance_valid(status_line):
		status_line.text = text
		status_line.modulate.a = 1.0
		var fade := status_line.create_tween()
		fade.tween_interval(3.5)
		fade.tween_property(status_line,"modulate:a",0.0,0.6)
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
		"pipe":
			var line := world_policy.pipe(marker.id)
			var next := world_policy.pipe_next(line,session.state)
			var allowed := world_policy.can_start_encounter(next,session.state,marker.id)
			if not allowed.ok:
				_message(allowed.reason)
				return
			var view := world
			await view.enter_pipe(marker)
			if world != view: return
			_start_encounter(next,marker.id,marker.position+Vector2(0,40))
		"exit", "fast_travel":
			if not world_policy.can_travel(session.state.room_id,marker.id,session.state):
				_message("ทางยังไม่เปิด ผ่านบอสของเขตก่อนหน้าก่อน")
				return
			var spawn := "right" if int(marker.id.substr(1)) < int(session.state.room_id.substr(1)) and marker.id != "R01" else "entry"
			# Returning to the hub lands in front of the pipe the player came through.
			if marker.id == "R01" and session.state.room_id == "R02": spawn = "left"
			elif marker.kind == "fast_travel": spawn = "entry"
			var view := world
			await view.enter_pipe(marker)
			if world != view: return
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
	shade.color = Color(0,0,0,0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(shade)
	modal = shade
	var panel := UIBuilder.glass_panel(shade,Vector2(90,36),Vector2(1100,648))
	panel.get_theme_stylebox("panel").bg_color = Color(0.04,0.08,0.09,0.94)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",8)
	panel.add_child(layout)
	var head := HBoxContainer.new()
	layout.add_child(head)
	var heading := UIBuilder.label(head,title,24,Color("e7c588"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if allow_close:
		# Esc already closes through _unhandled_input; a shortcut here would also fire on the opening key's release.
		UIBuilder.icon_button(head,"close","ปิด / กลับ  [Esc]",_close_modal.bind(false),"CloseModal",44)
	modal_notice = UIBuilder.label(layout,"\n".join([save_warning,reward_notice]).strip_edges(),15,Color("95c5b1"))
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 520
	layout.add_child(scroll)
	modal_body = VBoxContainer.new()
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_body.add_theme_constant_override("separation",8)
	scroll.add_child(modal_body)
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

const TIER_COLORS := ["8a9490","6fbf73","5ab4e0","b07ce0","e3b858"]
const STAT_NAMES := {"attack":"โจมตี","tech":"เทค","max_hp":"HP","max_fp":"FP","armor":"เกราะ","resist":"ต้านทาน","barrier":"โล่","initiative":"ความเร็ว"}
var inv_pick: Dictionary = {}

# Two panes like a mobile inventory: tiles on the left, the picked thing's detail and actions on the right.
func _modal_split() -> Array:
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation",16)
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_body.add_child(split)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation",8)
	split.add_child(left)
	var right := UIBuilder.glass_panel(split,Vector2.ZERO,Vector2.ZERO)
	right.custom_minimum_size = Vector2(360,500)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation",8)
	right.add_child(detail)
	return [left,detail]

func _tile(parent: Node, icon: Texture2D, tip: String, caption: String, picked: bool, callback: Callable, id: String = "", tier: int = 0) -> Button:
	var tile := UIBuilder.icon_button(parent,"bag",tip,callback,id,76,caption)
	tile.icon = icon
	var style: StyleBoxFlat = tile.get_theme_stylebox("normal").duplicate()
	style.set_corner_radius_all(12)
	style.border_color = Color("f1d9a0") if picked else Color(TIER_COLORS[clampi(tier-1,0,4)]) if tier > 0 else Color(0.4,0.5,0.48,0.8)
	style.set_border_width_all(3 if picked else 2)
	tile.add_theme_stylebox_override("normal",style)
	return tile

func _grid(parent: Node, title: String, columns: int = 8) -> GridContainer:
	UIBuilder.label(parent,title,17,Color("c8d6cc"))
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	parent.add_child(grid)
	return grid

func _pick(choice: Dictionary, shop: bool) -> void:
	inv_pick = choice
	if shop: _show_shop()
	else: _show_inventory()

func _item_detail(detail: VBoxContainer, item: Dictionary, note: String) -> void:
	var heading := UIBuilder.label(detail,item.name,22,Color(TIER_COLORS[clampi(int(item.tier)-1,0,4)]))
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	UIBuilder.label(detail,"%s · ระดับ %d · ต้องเลเวล %d" % [{"weapon":"อาวุธ","shield":"โล่","head":"หมวก","suit":"ชุด"}.get(item.slot,item.slot),int(item.tier),int(item.required_level)],14,Color("a7b9ac"))
	var equipped := catalog.get_entry("items",session.state.player.equipment.get(item.slot,""))
	for key in STAT_NAMES:
		var value: int = int(item.bonuses.get(key,0))
		var delta: int = value - int(equipped.get("bonuses",{}).get(key,0))
		if value == 0 and delta == 0: continue
		var line := UIBuilder.label(detail,"%s  %+d" % [STAT_NAMES[key],value] + (("   (%+d)" % delta) if equipped.get("id","") != item.id and delta != 0 else ""),17,Color("83dcb3") if delta > 0 else Color("e0806a") if delta < 0 else Color("e6dfca"))
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
	if not item.special.is_empty(): UIBuilder.label(detail,UIBuilder.item_description(item).split(" · ")[-1],15,Color("f1d9a0"))
	if not note.is_empty(): UIBuilder.label(detail,note,14,Color("8fb4a6"))

func _show_inventory() -> void:
	var p: Dictionary = session.state.player
	_open_modal("กระเป๋าและอุปกรณ์  ·  %d เฟือง" % p.currency)
	var panes := _modal_split()
	var left: VBoxContainer = panes[0]
	var detail: VBoxContainer = panes[1]
	if inv_pick.is_empty() or (inv_pick.from == "bag" and inv_pick.key >= p.items.size()) or (inv_pick.from == "stash" and inv_pick.key >= p.stash.size()) or (inv_pick.from == "slot" and not p.equipment.has(inv_pick.key)) or inv_pick.from in ["shop","supply"]:
		inv_pick = {"from":"bag","key":0} if not p.items.is_empty() else {"from":"slot","key":p.equipment.keys().front()} if not p.equipment.is_empty() else {}
	var slots := _grid(left,"สวมอยู่",4)
	for slot in ["weapon","shield","head","suit"]:
		var item := catalog.get_entry("items",p.equipment.get(slot,""))
		var picked: bool = inv_pick.get("from","") == "slot" and inv_pick.key == slot
		if item.is_empty(): _tile(slots,load("res://art/icons/%s.svg" % slot),"ช่อง%s ว่าง" % {"weapon":"อาวุธ","shield":"โล่","head":"หมวก","suit":"ชุด"}[slot],"ว่าง",false,func(): pass).disabled = true
		else: _tile(slots,UIBuilder.item_icon(item),item.name+"\n"+UIBuilder.item_description(item),"",picked,_pick.bind({"from":"slot","key":slot},false),"Slot_"+slot,int(item.tier))
	var bag := _grid(left,"กระเป๋า %d / 24" % p.items.size())
	for i in p.items.size():
		var item := catalog.get_entry("items",p.items[i])
		_tile(bag,UIBuilder.item_icon(item),item.name+"\n"+UIBuilder.item_description(item),"Lv%d" % item.required_level,inv_pick.get("from","") == "bag" and inv_pick.key == i,_pick.bind({"from":"bag","key":i},false),"Bag_%d" % i,int(item.tier))
	if session.state.room_id == "R01":
		var stash := _grid(left,"คลังโรงซ่อม %d" % p.stash.size())
		for i in p.stash.size():
			var item := catalog.get_entry("items",p.stash[i])
			_tile(stash,UIBuilder.item_icon(item),item.name+"\n"+UIBuilder.item_description(item),"",inv_pick.get("from","") == "stash" and inv_pick.key == i,_pick.bind({"from":"stash","key":i},false),"Stash_%d" % i,int(item.tier))
	if inv_pick.is_empty():
		UIBuilder.label(detail,"กระเป๋าว่าง",18)
		return
	var picked_id: String = p.items[inv_pick.key] if inv_pick.from == "bag" else p.stash[inv_pick.key] if inv_pick.from == "stash" else p.equipment[inv_pick.key]
	var item := catalog.get_entry("items",picked_id)
	_item_detail(detail,item,"ตัวเลขในวงเล็บเทียบกับของที่สวมอยู่" if inv_pick.from != "slot" else "กำลังสวมอยู่")
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",8)
	detail.add_child(actions)
	if inv_pick.from == "bag":
		var equip := UIBuilder.button(actions,"สวม",_inventory_action.bind({"kind":"equip","index":inv_pick.key},false),"EquipPicked")
		equip.disabled = int(p.level) < int(item.required_level)
		equip.tooltip_text = "สวมแทนของเดิม ของเดิมกลับเข้ากระเป๋า" if not equip.disabled else "เลเวลยังไม่ถึง"
		UIBuilder.button(actions,"ขาย +%d" % int(floor(float(item.price)*0.35)),_inventory_action.bind({"kind":"sell","index":inv_pick.key},false),"SellPicked").tooltip_text = "ขายได้ 35% ของราคา"
		UIBuilder.button(actions,"ฝาก",_inventory_action.bind({"kind":"stash_put","index":inv_pick.key},false),"StashPicked").tooltip_text = "ฝากไว้ที่คลังโรงซ่อม"
	elif inv_pick.from == "slot":
		UIBuilder.button(actions,"ถอด",_inventory_action.bind({"kind":"unequip","slot":inv_pick.key},false),"UnequipPicked").tooltip_text = "ถอดเก็บเข้ากระเป๋า"
	else:
		UIBuilder.button(actions,"รับคืน",_inventory_action.bind({"kind":"stash_take","index":inv_pick.key},false),"TakePicked").tooltip_text = "ย้ายจากคลังเข้ากระเป๋า"

func _inventory_action(request: Dictionary, shop: bool) -> void:
	var result := _commit("inventory",{"request":request})
	if result.ok:
		if shop:
			_show_shop()
		else:
			_show_inventory()

func _show_shop() -> void:
	var p: Dictionary = session.state.player
	_open_modal("ร้านอุปกรณ์  ·  %d เฟือง" % p.currency)
	var panes := _modal_split()
	var stock: Array = catalog.data.items.filter(func(item): return item.source == "shop:" + session.state.room_id)
	if not inv_pick.get("from","") in ["shop","supply"]: inv_pick = {"from":"shop","key":stock[0].id} if not stock.is_empty() else {"from":"supply","key":"life"}
	var grid := _grid(panes[0],"สินค้า")
	for item in stock:
		_tile(grid,UIBuilder.item_icon(item),"%s · %d เฟือง\n%s" % [item.name,item.price,UIBuilder.item_description(item)],"%d" % item.price,inv_pick.key == item.id,_pick.bind({"from":"shop","key":item.id},true),"Shop_"+item.id,int(item.tier))
	var supplies := {"life":["potion_hp","ยาHP","ฟื้น HP 35%% ในการต่อสู้ · มีอยู่ %d" % p.potions.life,{"kind":"potion_buy","potion":"life"}],"focus":["potion_fp","ยาFP","ฟื้น FP 35%% ในการต่อสู้ · มีอยู่ %d" % p.potions.focus,{"kind":"potion_buy","potion":"focus"}],"food":["energy","อาหาร","พลังงาน +50 ทันที · พลังงานตอนนี้ %d/100" % p.energy,{"kind":"food"}]}
	var row := _grid(panes[0],"ของใช้")
	for key in supplies:
		_tile(row,load("res://art/icons/%s.svg" % supplies[key][0]),supplies[key][1]+" · "+supplies[key][2],"%d" % (30 if key == "food" else 20),inv_pick.key == key,_pick.bind({"from":"supply","key":key},true),"Supply_"+key)
	var detail: VBoxContainer = panes[1]
	var price: int
	var request: Dictionary
	if inv_pick.from == "shop":
		var item := catalog.get_entry("items",inv_pick.key)
		_item_detail(detail,item,"ตัวเลขในวงเล็บเทียบกับของที่สวมอยู่")
		price = int(item.price)
		request = {"kind":"buy","item_id":item.id}
	else:
		var supply: Array = supplies[inv_pick.key]
		UIBuilder.label(detail,supply[1],22,Color("f1d9a0"))
		UIBuilder.label(detail,supply[2],16)
		price = 30 if inv_pick.key == "food" else 20
		request = supply[3]
	var buy := UIBuilder.button(detail,"ซื้อ  %d เฟือง" % price,_inventory_action.bind(request,true),"BuyPicked")
	buy.disabled = int(p.currency) < price
	buy.tooltip_text = "เงินไม่พอ" if buy.disabled else "ซื้อ เหลือ %d เฟือง" % (int(p.currency) - price)

var skill_pick: String = ""

func _show_skills() -> void:
	var p: Dictionary = session.state.player
	_open_modal("สกิลและค่าสถานะ  ·  แต้มสกิล %d  ·  แต้มค่าสถานะ %d" % [p.skill_points,p.attribute_points])
	var panes := _modal_split()
	var left: VBoxContainer = panes[0]
	var detail: VBoxContainer = panes[1]
	var attributes := _grid(left,"ค่าสถานะ (กดเพื่อเพิ่ม)",4)
	var names: Dictionary = {"VIT":["heal","ความทนทาน · เพิ่ม HP"],"STR":["weapon","กำลัง · เพิ่มพลังโจมตีกายภาพ"],"INT":["electric","เทคโนโลยี · เพิ่มพลังสกิลเทคและการฮีล"],"AGI":["energy","ความคล่อง · เพิ่มความเร็วในลำดับเทิร์น"]}
	for attribute in ["VIT","STR","INT","AGI"]:
		var tile := _tile(attributes,load("res://art/icons/%s.svg" % names[attribute][0]),names[attribute][1],"%s %d" % [attribute,p.base_attributes[attribute]],false,_grow.bind("allocate_attribute",{"attribute":attribute}),"Attr_"+attribute)
		tile.disabled = p.attribute_points <= 0
	if skill_pick.is_empty() or catalog.get_entry("skills",skill_pick).is_empty(): skill_pick = catalog.data.skills[0].id
	var actor := session.progression.derive(p,catalog.data)
	actor["class_id"] = p.class_id
	var resolver := CombatResolver.new()
	# Skill tree rows by unlock level, read left to right like a mobile talent board.
	for level in [1,5,10,15]:
		var row := _grid(left,"เลเวล %d" % level,8)
		for skill in catalog.data.skills.filter(func(s): return int(s.required_level) == level):
			var rank: int = int(p.skill_ranks.get(skill.id,0))
			var tile := _tile(row,UIBuilder.skill_icon(skill),skill.name,"%d/10" % rank,skill.id == skill_pick,func():
				skill_pick = skill.id
				_show_skills(),"Skill_"+skill.id,5 if rank >= 10 else 2 if rank > 0 else 0)
			if rank == 0: tile.modulate = Color(1,1,1,0.55)
	if session.state.room_id == "R01":
		UIBuilder.button(left,"คืนแต้มสกิลฟรี (คงสกิลเริ่มอาชีพ)",_grow.bind("respec",{}),"Respec")
	var skill := catalog.get_entry("skills",skill_pick)
	var rank: int = int(p.skill_ranks.get(skill.id,0))
	UIBuilder.label(detail,skill.name,22,Color("f1d9a0"))
	UIBuilder.label(detail,"%s · ระดับ %d/10" % ["ติดตัว" if skill.kind == "passive" else "ใช้งาน",rank],15,Color("a7b9ac"))
	var preview := resolver.skill_preview(actor,skill,maxi(1,rank))
	UIBuilder.label(detail,UIBuilder.skill_description(skill,preview,maxi(1,rank)),16)
	var parents: Array[String] = []
	for id in skill.parents: parents.append(catalog.get_entry("skills",id).name)
	UIBuilder.label(detail,"ต้องเลเวล %d" % skill.required_level + (" · ก่อนหน้า: " + " และ ".join(parents) if not parents.is_empty() else ""),14,Color("8fb4a6"))
	var check := session.progression.learn_skill(p,skill.id)
	var learn := UIBuilder.button(detail,"เรียน +1  (ใช้ 1 แต้ม)",_grow.bind("learn_skill",{"skill_id":skill.id}),"Learn_"+skill.id)
	learn.disabled = not check.ok
	learn.tooltip_text = check.get("reason","") if not check.ok else "เพิ่มระดับเป็น %d/10" % (rank+1)

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

func _start_encounter(id: String, pipe_id: String = "", resume_at: Vector2 = Vector2.INF) -> void:
	combat = CombatController.new(catalog.data)
	var result := combat.start(id,session.snapshot(),randi(),pipe_id)
	if not result.ok:
		_message(result.reason)
		if is_instance_valid(world): _show_world()
		return
	return_position = world.player.position if resume_at == Vector2.INF else resume_at
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
			var drop := catalog.get_entry("items",event.payload.get("drop",""))
			if not drop.is_empty():
				var row := HBoxContainer.new()
				modal_body.add_child(row)
				var icon := TextureRect.new()
				icon.texture = UIBuilder.item_icon(drop)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.custom_minimum_size = Vector2(40,40)
				row.add_child(icon)
				UIBuilder.label(row,"ของตก: " + drop.name,22,Color("f1d9a0")).autowrap_mode = TextServer.AUTOWRAP_OFF
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
	return "ซ้าย %s · ขวา %s\nขึ้น %s · ลง %s\n%s โต้ตอบ · Esc เมนู\nI กระเป๋า · K สกิล · J ภารกิจ · L บทคุย\nต่อสู้: 1–0 สกิล · Z–N คำสั่ง" % [settings.binding_label("move_left").split(" / ")[0],settings.binding_label("move_right").split(" / ")[0],settings.binding_label("move_up").split(" / ")[0],settings.binding_label("move_down").split(" / ")[0],settings.binding_label("interact")]
