class_name Progression
extends RefCounted

var catalog: Dictionary

func _init(content: Dictionary = {}) -> void:
	catalog = content

func _entry(kind: String, id: String, content: Dictionary = {}) -> Dictionary:
	var source: Dictionary = content if not content.is_empty() else catalog
	for entry in source.get(kind, []):
		if entry.id == id:
			return entry
	return {}

func _result(player: Dictionary, ok: bool = true, reason: String = "", events: Array = []) -> Dictionary:
	return {"ok":ok,"reason":reason,"state":player.duplicate(true),"events":events}

func new_player(class_id: String) -> Dictionary:
	var profession := _entry("classes", class_id)
	if profession.is_empty():
		return {}
	var attributes: Dictionary = {}
	for name in ["VIT", "STR", "INT", "AGI"]:
		attributes[name] = int(profession.attributes[name])
	var player: Dictionary = {"class_id":class_id,"level":1,"xp":0,"base_attributes":attributes,"skill_ranks":{profession.starter_skill:1},"skill_points":0,"attribute_points":0,"items":[],"equipment":{"weapon":"W01","shield":"D01","head":"H01","suit":"A01"},"stash":[],"currency":75,"current_hp":0,"current_fp":0,"energy":100,"potions":{"life":5,"focus":5}}
	var stats := derive(player, catalog)
	player.current_hp = stats.max_hp
	player.current_fp = stats.max_fp
	return player

func derive(player: Dictionary, content: Dictionary) -> Dictionary:
	var base: Dictionary = player.get("base_attributes", {})
	var stats: Dictionary = {"max_hp":20 + 6 * int(base.get("VIT", 0)),"max_fp":20 + 4 * int(base.get("INT", 0)),"attack":5 + 2 * int(base.get("STR", 0)),"tech":5 + 2 * int(base.get("INT", 0)),"initiative":10 + int(base.get("AGI", 0)),"armor":0,"resist":0,"barrier":20 if player.get("class_id", "") == "C01" else 0,"equipment_specials":[]}
	for id in player.get("equipment", {}).values():
		var item := _entry("items", str(id), content)
		for key in item.get("bonuses", {}):
			if stats.has(key):
				stats[key] += int(item.bonuses[key])
		if not item.get("special", "").is_empty():
			stats.equipment_specials.append(item.special)
	var ranks: Dictionary = player.get("skill_ranks", {})
	stats.max_hp = maxi(1, int(floor(float(stats.max_hp) * (1.0 + 0.02 * int(ranks.get("S17", 0))))))
	stats.max_fp = maxi(0, int(floor(float(stats.max_fp) * (1.0 + 0.02 * int(ranks.get("S18", 0))))))
	stats.initiative += int(ranks.get("S19", 0))
	return stats

func xp_to_next(level: int) -> int:
	return 40 + 12 * (level - 1) + 4 * (level - 1) * (level - 1)

func gain_xp(player: Dictionary, amount: int) -> Dictionary:
	if amount < 0:
		return _result(player, false, "XPต้องไม่ติดลบ")
	var next: Dictionary = player.duplicate(true)
	if next.level >= 30:
		return _result(next)
	next.xp += amount
	var events: Array = []
	while next.level < 30 and next.xp >= xp_to_next(int(next.level)):
		next.xp -= xp_to_next(int(next.level))
		next.level += 1
		next.skill_points += 1
		next.attribute_points += 2
		next.base_attributes.VIT += 1
		events.append({"id":"level:" + str(next.level),"type":"level_up","payload":{"level":next.level}})
	if next.level == 30:
		next.xp = 0
	return _result(next, true, "", events)

func allocate_attribute(player: Dictionary, attribute: String) -> Dictionary:
	if not attribute in ["VIT", "STR", "INT", "AGI"]:
		return _result(player, false, "ไม่รู้จักค่าสถานะ")
	if player.get("attribute_points", 0) < 1:
		return _result(player, false, "แต้มค่าสถานะไม่พอ")
	var next: Dictionary = player.duplicate(true)
	next.attribute_points -= 1
	next.base_attributes[attribute] += 1
	return _result(next)

func learn_skill(player: Dictionary, skill_id: String) -> Dictionary:
	var skill := _entry("skills", skill_id)
	if skill.is_empty():
		return _result(player, false, "ไม่รู้จักสกิล")
	if player.get("skill_points", 0) < 1:
		return _result(player, false, "แต้มสกิลไม่พอ")
	if player.get("level", 1) < int(skill.required_level):
		return _result(player, false, "เลเวลยังไม่ถึง")
	var ranks: Dictionary = player.get("skill_ranks", {})
	if int(ranks.get(skill_id, 0)) >= int(skill.rank_cap):
		return _result(player, false, "สกิลเต็มระดับแล้ว")
	for parent in skill.parents:
		if int(ranks.get(parent, 0)) < 1:
			return _result(player, false, "ยังไม่ได้เรียนสกิลก่อนหน้า")
	var next: Dictionary = player.duplicate(true)
	next.skill_points -= 1
	next.skill_ranks[skill_id] = int(ranks.get(skill_id, 0)) + 1
	return _result(next)

func respec(player: Dictionary) -> Dictionary:
	var profession := _entry("classes", str(player.get("class_id", "")))
	if profession.is_empty():
		return _result(player, false, "ไม่รู้จักอาชีพ")
	var invested := 0
	for rank in player.get("skill_ranks", {}).values():
		invested += int(rank)
	var next: Dictionary = player.duplicate(true)
	next.skill_points += maxi(0, invested - 1)
	next.skill_ranks = {profession.starter_skill:1}
	var stats := derive(next, catalog)
	next.current_hp = mini(int(next.current_hp), int(stats.max_hp))
	next.current_fp = mini(int(next.current_fp), int(stats.max_fp))
	return _result(next)
