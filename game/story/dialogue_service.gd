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
			return npc.ambient_after if session.get("first_clears", {}).has("B04") else npc.ambient_before
	return "ไอน้ำกลบเสียงจากถนนอีกฝั่ง"

func available_choices(node_id: String, session: Dictionary) -> Array[Dictionary]:
	var node := _node(node_id)
	var choices: Array[Dictionary] = []
	if node.is_empty():
		return choices
	var progress: Dictionary = session.get("quest_states", {}).get(node.quest_id, {})
	if progress.get("pending_choice", "") == "harvest":
		return [{"id":"confirm_harvest","text":"ยืนยันการทำลายรัง ปิด Cure ในเซฟนี้"},{"id":"cancel","text":"กลับไปคิดอีกครั้ง"}]
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
