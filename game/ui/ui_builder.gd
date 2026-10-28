class_name UIBuilder
extends RefCounted

static func label(parent: Node, text: String, size: int = 18, color: Color = Color("e6dfca")) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node

static func button(parent: Node, text: String, callback: Callable, id: String = "") -> Button:
	var node := Button.new()
	node.text = text
	if not id.is_empty():
		node.name = id
	node.custom_minimum_size.y = 42
	node.pressed.connect(callback)
	node.pressed.connect(func():
		if node.is_inside_tree(): node.get_tree().call_group("game_audio","play_sfx","ui"))
	parent.add_child(node)
	return node

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = load("res://art/fonts/NotoSansThai.ttf")
	result.default_font_size = 18
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("203638") if state == "hover" else Color("12272a")
		style.border_color = Color("d2ad66") if state in ["hover", "focus"] else Color("425354")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(4)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		result.set_stylebox(state, "Button", style)
	result.set_color("font_color", "Button", Color("e7dfca"))
	result.set_color("font_disabled_color", "Button", Color("687b79"))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("102125")
	panel.border_color = Color("64756b")
	panel.set_border_width_all(1)
	panel.content_margin_left = 22
	panel.content_margin_right = 22
	panel.content_margin_top = 18
	panel.content_margin_bottom = 18
	result.set_stylebox("panel", "PanelContainer", panel)
	return result


static func skill_description(skill: Dictionary, preview: Dictionary, rank: int) -> String:
	var lines: Array[String] = [skill.get("description_th",skill.name)]
	if skill.kind == "passive":
		var names: Dictionary = {"max_hp":"HPสูงสุด","max_fp":"FPสูงสุด","initiative":"ลำดับเทิร์น"}
		var percent: bool = preview.passive in ["max_hp","max_fp"]
		lines.append("%s +%s%s" % [names.get(preview.passive,""),str(int(round(preview.passive_total * (100 if percent else 1)))),"%" if percent else ""])
		return "\n".join(lines)
	lines.append("ระดับ %d · FP %d · แรงดัน %+d" % [rank,preview.fp_cost,preview.pressure_delta])
	if preview.damage_max > 0:
		lines.append("ความเสียหายพื้นฐาน %d–%d ×%d (ก่อนเกราะและสถานะ)" % [preview.damage_min,preview.damage_max,preview.hits])
	if preview.heal > 0:
		lines.append("ฟื้น HP %d" % preview.heal)
	if preview.barrier > 0:
		lines.append("สร้างโล่ %d" % preview.barrier)
	if preview.drone_max > 0:
		lines.append("โดรนโจมตีพื้นฐาน %d–%d ต่อคำสั่ง" % [preview.drone_min,preview.drone_max])
	var statuses: Dictionary = {"Wet":"เปียก","Heated":"ร้อนจัด","Corroded":"เกราะผุ","Marked":"ถูกหมายหัว","Staggered":"เสียจังหวะ","Sealed":"ปิดการฟื้นฟู","Haste":"เร่งจังหวะ"}
	if not preview.status.is_empty():
		lines.append("%s %dเทิร์น" % [statuses.get(preview.status,preview.status),preview.duration])
	if preview.cooldown > 0:
		lines.append("พัก %dคำสั่งของตนก่อนใช้ซ้ำ" % preview.cooldown)
	return "\n".join(lines)

static func item_description(item: Dictionary) -> String:
	var names := {"attack":"โจมตี","tech":"เทค","max_hp":"HP","max_fp":"FP","armor":"เกราะ","resist":"ต้านทาน","barrier":"โล่","initiative":"ความเร็ว"}
	var parts: Array[String] = []
	for key in item.bonuses:
		if item.bonuses[key] != 0: parts.append("%s %+d" % [names.get(key,key),item.bonuses[key]])
	if item.special == "vent_breaker": parts.append("หลังระบายไอ โจมตีโล่แรงขึ้น50%หนึ่งครั้ง")
	if item.special == "condensate_barrier": parts.append("ใช้สายควบแน่นแล้วได้โล่15%เทค")
	return " · ".join(parts)

static func item_icon(item: Dictionary) -> Texture2D:
	return load("res://art/icons/%s.svg" % (item.id if item.id in ["W26","A09"] else item.slot))

static func skill_icon(skill: Dictionary) -> Texture2D:
	var effects: Dictionary = skill.effects
	var icon: String = {"physical":"weapon","electric":"electric","thermal":"heat","chemical":"wet"}.get(effects.get("damage_type",""),"gear")
	if effects.has("heal"): icon = "heal"
	elif effects.has("barrier"): icon = "shield"
	elif effects.has("summon"): icon = "drone"
	return load("res://art/icons/%s.svg" % icon)
