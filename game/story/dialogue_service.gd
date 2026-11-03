class_name DialogueService
extends RefCounted

var content: Dictionary
var quests: QuestService

func _init(catalog: Dictionary = {}) -> void:
	content = catalog
	quests = QuestService.new(content)

func _node(id: String) -> Dictionary:
	for node in content.get("story", {}).get("dialogue", []):
		if node.id == id:
			return node
	return {}

func get_text(node_id: String, session: Dictionary) -> String:
	var node := _node(node_id)
	if node.is_empty():
		return "ไม่มีบทสนทนานี้"
	var progress: Dictionary = session.get("quest_states", {}).get(node.quest_id, {})
	if progress.get("pending_choice", "") == "harvest":
		return content.story.harvest_warning
	if node.quest_id == "Q04" and progress.get("state","") == "objectives_complete" and not _safe_specimen(session):
		return "ก่อนช่วยรัง ปิดวาล์วไหลเข้าและเปิดวาล์วระบายในเรือนเพาะให้ครบสองจุด\n"+node.complete_text
	if node.quest_id == "Q04" and progress.get("state","") == "turned_in" and session.get("world_flags",{}).get("harvested_sample",false):
		return "ลินเก็บขวดที่นิ่งสนิท “เรามีสารพอศึกษา แต่ไม่มีเซลล์มีชีวิตพอเริ่มวงจรฟื้นฟูแล้ว ฉันจะช่วยคนที่เหลือด้วยทางอื่น”"
	if node.quest_id == "Q08" and progress.get("state","") == "turned_in":
		return node.after_text+"\n"+get_epilogue(session)
	match progress.get("state", "available"):
		"active": return node.active_text
		"objectives_complete": return node.complete_text
		"turned_in": return node.after_text
	return node.text

func ambient_line(npc_id: String, session: Dictionary) -> String:
	if npc_id == "NPC05" and session.get("world_flags",{}).get("harvested_sample",false):
		return "ลินเก็บขวดตัวอย่างที่นิ่งสนิท “เรามีสารพอศึกษา แต่ไม่มีเซลล์มีชีวิตพอเริ่มวงจรฟื้นฟูแล้ว ฉันจะช่วยคนที่เหลือด้วยทางอื่น”"
	for npc in content.get("story", {}).get("npcs", []):
		if npc.id == npc_id:
			var by_chapter: Dictionary = npc.get("ambient_by_chapter", {})
			var chapter := current_chapter_id(session)
			if by_chapter.has(chapter):
				return by_chapter[chapter]
			return npc.ambient_after if session.get("first_clears", {}).has("B04") else npc.ambient_before
	return "ไอน้ำกลบเสียงจากถนนอีกฝั่ง"

func available_choices(node_id: String, session: Dictionary) -> Array[Dictionary]:
	var node := _node(node_id)
	var choices: Array[Dictionary] = []
	if node.is_empty():
		return choices
	var progress: Dictionary = session.get("quest_states", {}).get(node.quest_id, {})
	if progress.get("pending_choice", "") == "harvest":
		return [{"id":"confirm_harvest","text":"ยืนยันการทำลายรัง ปิดทางจบ “ลมหายใจใหม่” ในเซฟนี้"},{"id":"cancel","text":"กลับไปคิดอีกครั้ง"}]
	match progress.get("state", "available"):
		"available": choices.append({"id":"accept","text":"รับเรื่องนี้ไว้"})
		"objectives_complete":
			if progress.get("choice", "").is_empty():
				for choice in node.choices:
					if node.quest_id == "Q04" and choice.id == "help" and not _safe_specimen(session): continue
					choices.append(choice)
	choices.append({"id":"leave","text":"กลับไปสำรวจต่อ"})
	return choices

func _safe_specimen(session: Dictionary) -> bool:
	var flags: Dictionary = session.get("world_flags",{})
	return flags.get("environment:specimen_intake",false) and flags.get("environment:specimen_exhaust",false)

func choose(node_id: String, choice_id: String, session: Dictionary) -> Dictionary:
	var allowed := false
	for choice in available_choices(node_id, session):
		if choice.id == choice_id:
			allowed = true
	if not allowed:
		return {"ok":false,"reason":"ตัวเลือกนี้ใช้ไม่ได้แล้ว","state":session.duplicate(true),"events":[]}
	var next: Dictionary = session.duplicate(true)
	var node := _node(node_id)
	var id: String = node.quest_id
	var quest := quests.get_definition(id)
	var progress: Dictionary = next.quest_states.get(id, {"state":"available","choice":""})
	var events: Array = []
	if choice_id == "accept":
		progress.state = "objectives_complete" if next.world_flags.get("objective:" + quest.object_id, false) else "active"
	elif choice_id == "pragmatic" and id == "Q04":
		progress["pending_choice"] = "harvest"
	elif choice_id == "cancel":
		progress.erase("pending_choice")
	elif choice_id in ["help", "pragmatic", "confirm_harvest"]:
		progress.choice = "pragmatic" if choice_id == "confirm_harvest" else choice_id
		progress.erase("pending_choice")
		next.world_flags[id + ":" + str(progress.choice)] = true
		if id == "Q04":
			var rescued: bool = progress.choice == "help"
			next.world_flags["rescued_specimen"] = rescued
			next.world_flags["harvested_sample"] = not rescued
			if rescued:
				next.world_flags["bypass:E15"] = true
		if id == "Q08":
			next.world_flags["protected_witness"] = progress.choice == "help"
		events.append({"id":"quest:" + id,"type":"quest_reward_request","payload":{"quest_id":id}})
	next.quest_states[id] = progress
	return {"ok":true,"reason":"","state":next,"events":events}

func get_ending_options(session: Dictionary) -> Array[String]:
	var options: Array[String] = ["Shutdown", "Seize"]
	var flags: Dictionary = session.get("world_flags", {})
	var q08: Dictionary = session.get("quest_states", {}).get("Q08", {})
	if flags.get("rescued_specimen", false) and not flags.get("harvested_sample", false) and q08.get("state", "") == "turned_in":
		options.append("Cure")
	return options

func get_epilogue(session: Dictionary) -> String:
	if session.get("quest_states",{}).get("Q08",{}).get("state","") != "turned_in": return ""
	if session.get("world_flags",{}).get("protected_witness",false):
		return "โบลท์พาซาเรนออกจากเขตโรงงานก่อนรุ่งเช้า สำเนาคำสั่งกระจายถึงทุกชุมชน พยานเริ่มชีวิตใหม่โดยมีคนงานคอยคุ้มครอง"
	return "คำสั่งต้นฉบับเข้าสู่หอจดหมายเหตุเมืองโดยปิดชื่อผู้ให้ข้อมูล ซาเรนอยู่ตรวจสำเนาทุกหน้าและลงชื่อรับผิดชอบการเก็บรักษาต่อสภา"

# ---------------------------------------------------------------- story pages
# A page is {title, text, backdrop, figures}; figures are "hero" or an actor id. Placeholder art until the D3 repaint.
func _chapters() -> Array:
	return content.get("story", {}).get("chapters", [])

func intro_pages() -> Array:
	return content.get("story", {}).get("intro", [])

func current_chapter_id(session: Dictionary) -> String:
	var clears: Dictionary = session.get("first_clears", {})
	for chapter in _chapters():
		for boss in chapter.bosses:
			if not clears.has(boss):
				return chapter.id
	return "CH05"

func chapter_of_boss(boss_id: String) -> Dictionary:
	for chapter in _chapters():
		if boss_id in chapter.bosses:
			return chapter
	return {}

func _chapter_page(chapter: Dictionary, title: String, text: String, figures: Array) -> Dictionary:
	return {"title":title,"text":text,"backdrop":chapter.get("backdrop","hub"),"figures":figures}

# Opening of the chapter whose entry room the player stands in, once, unless its first boss is already beaten.
func opening_due(session: Dictionary) -> Dictionary:
	for i in _chapters().size():
		if _chapters()[i].get("entry_room", "") == session.get("room_id", ""):
			var due := _opening(i, session)
			if not due.is_empty():
				return due
	return {}

# Hub pipe lines P01–P05 run chapters 1–5: the first fight of a line opens its chapter even if the entry room was skipped.
func opening_for_pipe(line_id: String, session: Dictionary) -> Dictionary:
	var index := int(line_id.trim_prefix("P")) - 1
	return _opening(index, session) if index >= 0 and index < _chapters().size() else {}

func _opening(i: int, session: Dictionary) -> Dictionary:
	var chapter: Dictionary = _chapters()[i]
	if session.get("world_flags", {}).get("story:open:" + chapter.id, false) or session.get("first_clears", {}).has(chapter.bosses[0]):
		return {}
	return {"flag":"story:open:" + chapter.id,"pages":[_chapter_page(chapter,"บทที่ %d  ·  %s" % [i+1,chapter.name],chapter.opening,chapter.get("figures",["hero"]))]}

# Pages after a first boss clear: the aftermath line, then the chapter closing when its last boss fell.
func boss_story(boss_id: String, session: Dictionary) -> Dictionary:
	var lines: Dictionary = content.get("story", {}).get("boss_lines", {})
	var chapter := chapter_of_boss(boss_id)
	var flags: Dictionary = session.get("world_flags", {})
	if not lines.has(boss_id) or chapter.is_empty() or flags.get("story:post:" + boss_id, false):
		return {}
	var set_flags: Array[String] = ["story:post:" + boss_id]
	var pages: Array = [_chapter_page(chapter,chapter.name,lines[boss_id].post_line,[lines[boss_id].post_speaker])]
	var done := true
	for boss in chapter.bosses:
		done = done and session.get("first_clears", {}).has(boss)
	if done and not flags.get("story:close:" + chapter.id, false):
		set_flags.append("story:close:" + chapter.id)
		pages.append(_chapter_page(chapter,"จบบท  ·  " + chapter.name,chapter.closing,["hero"]))
	return {"flags":set_flags,"pages":pages}

func ending(id: String) -> Dictionary:
	for entry in content.get("story", {}).get("endings", []):
		if entry.id == id:
			return entry
	return {}

# Name and text, the quest-dependent epilogue, the slideshow, then the epitaph.
func ending_pages(id: String, session: Dictionary) -> Array:
	var entry := ending(id)
	if entry.is_empty():
		return []
	var pages: Array = [{"title":entry.name,"text":entry.text,"backdrop":entry.get("backdrop","hub"),"figures":entry.get("figures",["hero"])}]
	var epilogue := get_epilogue(session)
	if not epilogue.is_empty():
		pages.append({"title":"ผลของการเลือกครั้งก่อน","text":epilogue,"backdrop":entry.get("backdrop","hub"),"figures":["hero","NPC07"]})
	pages.append_array(entry.get("pages", []))
	pages.append({"title":entry.name,"text":entry.get("epitaph",""),"backdrop":entry.get("backdrop","hub"),"figures":["hero"]})
	return pages

const CREDIT_SUMMARY := {
	"Engine":"เอนจินเกม Godot Engine ใบอนุญาต MIT",
	"Thai font":"ฟอนต์ Noto Sans Thai ใบอนุญาต SIL OFL 1.1",
	"Character cutouts":"ภาพตัวละคร พื้น และภาพหน้าชื่อเกม สร้างตามทิศทางของโปรเจกต์ด้วยเครื่องมือสร้างภาพ",
	"Interface icons":"ไอคอน ฉาก การเคลื่อนไหว และเอฟเฟกต์ เขียนขึ้นใหม่ด้วยโค้ดและ SVG",
	"Combat VFX":"สไปรต์เอฟเฟกต์การต่อสู้จาก pixelfx ใบอนุญาต MIT",
	"Music":"ดนตรีและเสียงประกอบ สังเคราะห์ขึ้นใหม่สำหรับเกมนี้",
	"Original Thai story":"เนื้อเรื่อง บทสนทนา ภารกิจ และข้อมูลเกม เขียนขึ้นใหม่เป็นภาษาไทย",
}

# One Thai line per bullet of ASSET_CREDITS.md that we recognise; licences stay in the file.
func credits_lines() -> Array[String]:
	var lines: Array[String] = []
	var file := FileAccess.open("res://ASSET_CREDITS.md", FileAccess.READ)
	if file != null:
		for raw in file.get_as_text().split("\n"):
			var line := raw.strip_edges()
			if not line.begins_with("- "):
				continue
			for key in CREDIT_SUMMARY:
				if line.begins_with("- " + key) and not CREDIT_SUMMARY[key] in lines:
					lines.append(CREDIT_SUMMARY[key])
	if lines.is_empty():
		lines.assign(CREDIT_SUMMARY.values())
	return lines

func credits_page() -> Dictionary:
	var title: String = content.get("story", {}).get("title", "")
	return {"title":title,"text":"สร้างด้วย Godot Engine\n\n" + "\n".join(credits_lines()) + "\n\nขอบคุณที่เล่นจนจบ","backdrop":"title","figures":[],"credits":true}
