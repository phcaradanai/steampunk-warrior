class_name ContentCatalog
extends RefCounted

const KINDS: Array[String] = ["classes", "skills", "items", "enemies", "encounters", "rooms", "training", "story"]
const EXPECTED: Dictionary = {"classes": 5, "skills": 22, "items": 62, "enemies": 25, "encounters": 36, "rooms": 12, "training": 4}
var data: Dictionary = {}
var load_errors: Array[String] = []

func load_all(root: String = "res://data") -> Dictionary:
	data.clear()
	load_errors.clear()
	for kind in KINDS:
		var path := root.path_join(kind + ".json")
		if not FileAccess.file_exists(path):
			load_errors.append("Missing catalog: " + kind)
			continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK:
			load_errors.append("Invalid JSON: " + kind)
			continue
		if (kind == "story" and not parser.data is Dictionary) or (kind != "story" and not parser.data is Array):
			load_errors.append("Invalid catalog shape: " + kind)
			continue
		data[kind] = parser.data
	return data

func get_entry(kind: String, id: String) -> Dictionary:
	for entry in data.get(kind, []):
		if entry is Dictionary and entry.get("id", "") == id:
			return entry
	return {}

func validate_all() -> Array[String]:
	var errors: Array[String] = load_errors.duplicate()
	for kind in EXPECTED:
		var entries = data.get(kind, [])
		if not entries is Array or entries.size() != EXPECTED[kind]:
			errors.append("Incorrect content count: " + kind)
			continue
		var ids: Dictionary = {}
		for entry in entries:
			if not entry is Dictionary or not entry.get("id") is String or entry.get("id", "").is_empty():
				errors.append("Invalid ID: " + kind)
				continue
			if ids.has(entry.id):
				errors.append("Duplicate ID: " + entry.id)
			ids[entry.id] = true
	if not errors.is_empty():
		return errors
	var resolved: Array[String] = []
	for skill in data.skills:
		if not skill.get("parents") is Array or not skill.get("effects") is Dictionary:
			errors.append("Invalid skill definition: " + skill.id)
			continue
		if not skill.get("fp_cost") is float and not skill.get("fp_cost") is int:
			errors.append("Invalid FP type: " + skill.id)
		elif skill.fp_cost < 0 or skill.fp_cost > 1000:
			errors.append("Invalid FP cost: " + skill.id)
		if skill.get("rank_cap", 0) != 10 or skill.get("required_level", 0) < 1 or skill.get("required_level", 0) > 30:
			errors.append("Invalid rank or level gate: " + skill.id)
	for _pass in range(data.skills.size()):
		for skill in data.skills:
			if not skill.get("parents") is Array or skill.id in resolved:
				continue
			var ready := true
			for parent in skill.parents:
				if not parent in resolved:
					ready = false
			if ready:
				resolved.append(skill.id)
	if resolved.size() != data.skills.size():
		errors.append("Missing or cyclic skill prerequisites")
	for profession in data.classes:
		if get_entry("skills", profession.get("starter_skill", "")).is_empty():
			errors.append("Missing starter skill: " + profession.id)
	var story: Dictionary = data.get("story", {})
	var quest_ids: Array[String] = []
	for quest in story.get("quests", []):
		quest_ids.append(quest.get("id", ""))
		if get_entry("rooms", quest.get("room", "")).is_empty():
			errors.append("Missing quest room: " + quest.id)
	for item in data.items:
		if not item.get("bonuses") is Dictionary or not item.get("slot", "") in ["weapon", "shield", "head", "suit"]:
			errors.append("Invalid equipment: " + item.id)
		var source: PackedStringArray = str(item.get("source", "")).split(":")
		if source.size() != 2:
			errors.append("Invalid acquisition: " + item.id)
		elif (source[0] == "shop" and get_entry("rooms", source[1]).is_empty()) or (source[0] == "quest" and not source[1] in quest_ids) or (source[0] == "boss" and not get_entry("enemies", source[1]).get("boss", false)) or not source[0] in ["shop", "quest", "boss"]:
			errors.append("Unknown acquisition source: " + item.id)
	for room in data.rooms:
		if not room.get("exits") is Array:
			errors.append("Invalid room exits: " + room.id)
			continue
		for exit in room.exits:
			if not exit is Dictionary or get_entry("rooms", exit.get("to", "")).is_empty():
				errors.append("Unknown room exit: " + room.id)
			elif not exit.get("requires", "").is_empty() and not get_entry("enemies", exit.requires).get("boss", false):
				errors.append("Unknown gate: " + room.id)
	for encounter in data.encounters:
		if get_entry("rooms", encounter.get("room", "")).is_empty():
			errors.append("Missing encounter room: " + encounter.id)
		for enemy in encounter.get("enemies", []):
			if get_entry("enemies", enemy).is_empty():
				errors.append("Missing encounter enemy: " + encounter.id)
		if encounter.get("enemies", []).size() < 1 or encounter.get("enemies", []).size() > 2:
			errors.append("Invalid enemy count: " + encounter.id)
		if not encounter.get("requires", "").is_empty() and get_entry("encounters", encounter.requires).is_empty():
			errors.append("Unknown encounter prerequisite: " + encounter.id)

	var npc_ids: Array[String] = []
	for npc in story.get("npcs", []):
		if not npc is Dictionary or not npc.get("id") is String:
			errors.append("Invalid story character")
			continue
		if npc.id in npc_ids:
			errors.append("Duplicate story character: " + npc.id)
		npc_ids.append(npc.id)
		if get_entry("rooms", npc.get("room", "")).is_empty():
			errors.append("Missing character room: " + npc.id)
	if npc_ids.size() != 8 or quest_ids.size() != 8:
		errors.append("Expected eight characters and eight quests")
	var objectives: Array[String] = []
	for quest in story.get("quests", []):
		if not quest.get("npc_id", "") in npc_ids:
			errors.append("Missing quest character: " + quest.id)
		if not quest.get("item", "").is_empty() and get_entry("items", quest.item).is_empty():
			errors.append("Missing quest reward: " + quest.id)
		var object_id: String = str(quest.get("object_id", ""))
		if object_id.is_empty() or object_id in objectives:
			errors.append("Invalid quest objective: " + quest.id)
		objectives.append(object_id)
	var dialogue_ids: Array[String] = []
	for node in story.get("dialogue", []):
		if not node is Dictionary or not node.get("id") is String:
			errors.append("Invalid dialogue node")
			continue
		if node.id in dialogue_ids:
			errors.append("Duplicate dialogue node: " + node.id)
		dialogue_ids.append(node.id)
		if not node.get("speaker", "") in npc_ids or not node.get("quest_id", "") in quest_ids:
			errors.append("Missing dialogue reference: " + node.id)
		for field in ["text", "active_text", "complete_text", "after_text"]:
			if not node.get(field) is String or node.get(field, "").is_empty():
				errors.append("Missing dialogue text: " + node.id)
	if dialogue_ids.size() != 8:
		errors.append("Expected eight quest dialogue graphs")
	if not errors.is_empty():
		return errors
	# Reachability adds boss keys only when that boss's room is reachable.
	var reached: Array[String] = ["R01"]
	var keys: Array[String] = []
	for _pass in range(data.rooms.size() + 1):
		for room in data.rooms:
			if not room.id in reached:
				continue
			for enemy in data.enemies:
				if enemy.get("boss", false) and enemy.get("room", "") == room.id and not enemy.id in keys:
					keys.append(enemy.id)
			for exit in room.exits:
				if (exit.get("requires", "").is_empty() or exit.requires in keys) and not exit.to in reached:
					reached.append(exit.to)
	if reached.size() != data.rooms.size():
		errors.append("Room gate prevents progression")
	return errors
