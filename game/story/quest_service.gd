class_name QuestService
extends RefCounted

var content: Dictionary

func _init(catalog: Dictionary = {}) -> void:
	content = catalog

func get_definition(id: String) -> Dictionary:
	for quest in content.get("story", {}).get("quests", []):
		if quest.id == id:
			return quest
	return {}

func on_event(session: Dictionary, event: Dictionary) -> Dictionary:
	var next: Dictionary = session.duplicate(true)
	var object_id: String = str(event.get("payload", {}).get("object_id", ""))
	if event.get("type", "") != "interact" or object_id.is_empty():
		return {"ok":false,"reason":"เหตุการณ์ภารกิจไม่ถูกต้อง","state":next,"events":[]}
	var found := false
	for quest in content.get("story", {}).get("quests", []):
		if quest.get("object_id", "") != object_id:
			continue
		found = true
		next.world_flags["objective:" + object_id] = true
		var progress: Dictionary = next.quest_states.get(quest.id, {"state":"available","choice":""})
		if progress.state == "active":
			progress.state = "objectives_complete"
			next.quest_states[quest.id] = progress
	if not found:
		return {"ok":false,"reason":"วัตถุนี้ไม่ใช่เป้าหมายภารกิจ","state":session.duplicate(true),"events":[]}
	return {"ok":true,"reason":"","state":next,"events":[]}
