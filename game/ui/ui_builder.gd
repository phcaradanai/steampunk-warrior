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

# Mobile-style control: a picture instead of a word, the words live in the tooltip.
static func icon_button(parent: Node, icon: String, tip: String, callback: Callable, id: String = "", side: float = 56.0, caption: String = "") -> Button:
	var node := button(parent, caption, callback, id)
	node.icon = load("res://art/icons/%s.svg" % icon)
	node.expand_icon = true
	node.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP if not caption.is_empty() else VERTICAL_ALIGNMENT_CENTER
	node.custom_minimum_size = Vector2(side, side)
	node.tooltip_text = tip
	node.add_theme_font_size_override("font_size", 13)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.1, 0.11, 0.78) if state != "hover" else Color(0.1, 0.2, 0.21, 0.9)
		style.border_color = Color("d2ad66") if state in ["hover", "focus"] else Color(0.4, 0.5, 0.48, 0.8)
		style.set_border_width_all(2)
		style.set_corner_radius_all(int(side * 0.5))
		style.set_content_margin_all(side * 0.16)
		node.add_theme_stylebox_override(state, style)
	return node

# PC play: every icon also answers to a key, shown as a corner tag and in its tooltip.
static func hotkey(node: Button, keycode: Key) -> void:
	for action in InputMap.get_actions():
		if action.begins_with("move_") or action == "interact":
			for event in InputMap.action_get_events(action):
				if event is InputEventKey and (event.physical_keycode == keycode or event.keycode == keycode): return
	var press := InputEventKey.new()
	press.keycode = keycode
	var shortcut := Shortcut.new()
	shortcut.events = [press]
	node.shortcut = shortcut
	node.shortcut_in_tooltip = false
	var name := OS.get_keycode_string(keycode)
	node.tooltip_text += "  [" + name + "]"
	var tag := Label.new()
	tag.text = name
	tag.position = Vector2(4, 0)
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color("f1d9a0"))
	tag.add_theme_color_override("font_outline_color", Color("0b1214"))
	tag.add_theme_constant_override("outline_size", 4)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(tag)

static func glass_panel(parent: Node, at: Vector2, area: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = at
	panel.size = area
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.09, 0.72)
	style.border_color = Color(0.55, 0.45, 0.28, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

static func bar(parent: Node, value: float, maximum: float, color: Color, height: float = 10.0) -> ProgressBar:
	var node := ProgressBar.new()
	node.max_value = maxf(1.0, maximum)
	node.value = value
	node.show_percentage = false
	node.custom_minimum_size.y = height
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(int(height * 0.5))
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.45)
	back.set_corner_radius_all(int(height * 0.5))
	node.add_theme_stylebox_override("fill", fill)
	node.add_theme_stylebox_override("background", back)
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
	var names := {"attack":"โจมตี","tech":"เทค","max_hp":"HP","max_fp":"FP","armor":"เกราะ","resist":"ต้านทาน","barrier":"โล่","initiative":"ความเร็ว","accuracy":"แม่นยำ","evasion":"หลบ","pierce":"เจาะเกราะ","focus":"เจาะต้านทาน"}
	var parts: Array[String] = []
	for key in item.bonuses:
		if item.bonuses[key] != 0: parts.append("%s %+d" % [names.get(key,key),item.bonuses[key]])
	if item.special == "vent_breaker": parts.append("หลังระบายไอ โจมตีโล่แรงขึ้น50%หนึ่งครั้ง")
	if item.special == "condensate_barrier": parts.append("ใช้สายควบแน่นแล้วได้โล่15%เทค")
	return " · ".join(parts)

# Thai name keyword -> icon family, first match wins (so longer gun names precede plain ปืน).
const ICON_FAMILIES := {
	"weapon":[["มีด","knife"],["กระบอง","club"],["ประแจ","wrench"],["ค้อน","hammer"],["ขวาน","axe"],["ดาบ","sword"],["เลื่อย","saw"],["กรงเล็บ","claw"],["เคียว","scythe"],["หอก","spear"],["ทวน","lance"],["คทา","staff"],["ปืนคาร์ไบน์","carbine"],["ปืนอาร์ก","arcgun"],["ปืนกรด","rifle"],["ปืนคอนเดนเซอร์","rifle"],["ปืน","pistol"]],
	"shield":[["ฝาท่อ","round"],["แผ่นเหล็ก","plate"],["ทองเหลือง","buckler"],["รถไฟ","train"],["ขดลวด","coil"],["กรองพิษ","filter"],["ลูกสูบ","piston"],["ไอน้ำ","round"],["เรือนกระจก","glass"],["ฉนวน","plate"],["คนงาน","tower"],["อาร์ก","arc"],["รากแก้ว","organic"],["เตาหลอม","buckler"],["จดหมายเหตุ","tower"],["ปฏิกรณ์","coil"],["ชีวภาพ","organic"]],
	"head":[["แว่น","goggles"],["หมวกคนงาน","hardhat"],["กรอง","mask"],["หน้ากาก","mask"],["เอเธอร์","antenna"],["กระบัง","visor"],["แกนเมือง","crown"],["หมวก","helmet"]],
	"suit":[["เกราะคนงาน","vest"],["รางเหล็ก","vest"],["กรองพิษ","hazmat"],["ฉนวน","insulated"],["หัวใจเมือง","core"],["เกราะ","heavy"],["เสื้อ","coat"],["ชุดแพทย์","coat"]],
}
const TIER_PIP := ["8a9490","6fbf73","5ab4e0","b07ce0","e3b858"]
static var _icon_cache := {}

# Icon file stem for an item: W26/A09 keep their unique art, others get a slot_family file.
static func item_icon_name(item: Dictionary) -> String:
	if item.id in ["W26","A09"]: return item.id
	for pair in ICON_FAMILIES.get(item.slot,[]):
		if str(item.name).contains(pair[0]): return "%s_%s" % [item.slot,pair[1]]
	return item.slot

# Family art plus a tier-colored pip in the corner so tiers read without the tile border.
static func item_icon(item: Dictionary) -> Texture2D:
	var stem := item_icon_name(item)
	var tier := clampi(int(item.get("tier",0)),0,5)
	var key := "%s:%d" % [stem,tier]
	if _icon_cache.has(key): return _icon_cache[key]
	var base: Texture2D = load("res://art/icons/%s.svg" % stem)
	if tier == 0: return base
	var image: Image = base.get_image()
	image.convert(Image.FORMAT_RGBA8)
	var size := image.get_width()
	var radius := size * 0.15
	var center := Vector2(size - radius - 1.0,size - radius - 1.0)
	var color := Color(TIER_PIP[tier - 1])
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5,y + 0.5).distance_to(center)
			if d <= radius: image.set_pixel(x,y,Color("0b1a1c") if d > radius - 1.6 else color)
	var texture := ImageTexture.create_from_image(image)
	_icon_cache[key] = texture
	return texture

static func skill_icon(skill: Dictionary) -> Texture2D:
	if skill.has("icon"): return load("res://art/icons/%s.svg" % skill.icon)
	var effects: Dictionary = skill.effects
	var icon: String = {"physical":"weapon","electric":"electric","thermal":"heat","chemical":"wet"}.get(effects.get("damage_type",""),"gear")
	if effects.has("heal"): icon = "heal"
	elif effects.has("barrier"): icon = "shield"
	elif effects.has("summon"): icon = "drone"
	return load("res://art/icons/%s.svg" % icon)
