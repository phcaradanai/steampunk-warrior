class_name GameSession
extends RefCounted

var content: Dictionary
var state: Dictionary = {}
var recent_commits: Array[String] = []
var progression: Progression
var inventory := InventoryService.new()

func _init(catalog: Dictionary = {}) -> void:
	content = catalog
	progression = Progression.new(content)

func new_game(class_id: String) -> Dictionary:
	var player := progression.new_player(class_id)
	if player.is_empty():
		return _reject("ไม่รู้จักอาชีพ")
	state = {"player":player,"room_id":"R01","quest_states":{},"world_flags":{},"first_clears":{},"claimed_rewards":{},"checkpoint":{"room_id":"R01","spawn_id":"entry"},"ending_history":[]}
	for quest in content.get("story", {}).get("quests", []):
		state.quest_states[quest.id] = {"state":"available","choice":""}
	recent_commits.clear()
	return {"ok":true,"reason":"","state":snapshot(),"events":[]}

func snapshot() -> Dictionary:
	return state.duplicate(true)

func _entry(kind: String, id: String) -> Dictionary:
	for entry in content.get(kind, []):
		if entry.id == id:
			return entry
	return {}

func _reject(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"state":snapshot(),"events":[]}

func commit_result(kind: String, payload: Dictionary) -> Dictionary:
	var id: String = str(payload.get("id", ""))
	if state.is_empty() or id.is_empty() or id in recent_commits or state.get("claimed_rewards", {}).has(id):
		return _reject("คำสั่งไม่พร้อมหรือดำเนินการแล้ว")
	var next: Dictionary = state.duplicate(true)
	var events: Array = []
	var claim_reward := false
	if kind == "battle_won":
		var encounter := _entry("encounters", str(payload.get("encounter_id", "")))
		if encounter.is_empty():
			return _reject("ไม่รู้จักการต่อสู้นี้")
		var first: bool = not next.first_clears.has(encounter.id)
		if not encounter.boss_id.is_empty() and not first and not next.world_flags.get("postgame", false):
			return _reject("เล่นบอสซ้ำได้หลังจบเรื่อง")
		var gear: Array = []
		if first:
			next.first_clears[encounter.id] = true
			if not encounter.boss_id.is_empty():
				next.first_clears[encounter.boss_id] = true
				for item in content.get("items", []):
					if item.source == "boss:" + encounter.boss_id:
						gear.append(item.id)
		var reward := inventory.transact(next.player, {"kind":"reward","items":gear}, content)
		if not reward.ok:
			return _reject(reward.reason)
		next.player = reward.state
		events.append_array(reward.events)
		var xp: int = int(encounter.xp) if first else int(floor(float(encounter.xp) * 0.25))
		var growth := progression.gain_xp(next.player, xp)
		next.player = growth.state
		events.append_array(growth.events)
		next.player.currency += int(encounter.gold)
		next.player.energy = maxi(0, int(next.player.energy) - int(encounter.energy_cost))
		var stats := progression.derive(next.player, content)
		next.player.current_hp = clampi(int(payload.get("current_hp", next.player.current_hp)), 1, int(stats.max_hp))
		next.player.current_fp = clampi(int(payload.get("current_fp", next.player.current_fp)), 0, int(stats.max_fp))
		if payload.has("potions"):
			next.player.potions = payload.potions.duplicate(true)
		claim_reward = true
		events.append({"id":id,"type":"battle_won","payload":{"encounter_id":encounter.id,"xp":xp,"gold":encounter.gold,"first":first}})
	elif kind == "battle_lost" or kind == "retreat":
		var stats := progression.derive(next.player, content)
		next.player.current_hp = stats.max_hp
		next.player.current_fp = stats.max_fp
		next.player.energy = maxi(0, int(next.player.energy) - 4)
		next.room_id = next.checkpoint.room_id
	elif kind == "rest":
		if next.room_id != "R01":
			return _reject("พักเต็มพลังได้ที่โรงซ่อม")
		var stats := progression.derive(next.player, content)
		next.player.current_hp = stats.max_hp
		next.player.current_fp = stats.max_fp
		next.player.energy = 100


	elif kind == "training_settle":
		var service := TrainingService.new(content)
		var objectives = payload.get("completed", [])
		if not objectives is Array:
			return _reject("รายการเป้าหมายฝึกไม่ถูกต้อง")
		var operation := service.settle(str(payload.get("tier_id", "")), objectives, next)
		if not operation.ok:
			return _reject(operation.reason)
		next = operation.state
		events.append_array(operation.events)
		claim_reward = true
	elif kind == "environment":
		var object_id: String = str(payload.get("object_id",""))
		if not WorldController.ENVIRONMENT.has(object_id) or WorldController.ENVIRONMENT[object_id].room != next.room_id:
			return _reject("ต้องยืนในห้องที่มีวาล์วนี้")
		next.world_flags["environment:"+object_id] = true
	elif kind == "quest_event":
		var service := QuestService.new(content)
		var operation := service.on_event(next, payload.get("event", {}))
		if not operation.ok:
			return _reject(operation.reason)
		next = operation.state
	elif kind == "dialogue_choice":
		var service := DialogueService.new(content)
		var operation := service.choose(str(payload.get("node_id", "")), str(payload.get("choice_id", "")), next)
		if not operation.ok:
			return _reject(operation.reason)
		next = operation.state
		for event in operation.events:
			if event.type == "quest_reward_request":
				var reward := _award_quest(next, event.payload.quest_id)
				if not reward.ok:
					return _reject(reward.reason)
				next = reward.state
				events.append_array(reward.events)
				claim_reward = true
	elif kind == "choose_ending":
		var choice: String = str(payload.get("ending", ""))
		var service := DialogueService.new(content)
		if not next.first_clears.has("B06") or not choice in service.get_ending_options(next):
			return _reject("ยังเลือกฉากจบนี้ไม่ได้")
		next.world_flags["ending_choice"] = choice
		next.world_flags["postgame"] = true
		if not choice in next.ending_history:
			next.ending_history.append(choice)
		next.room_id = "R11"
		next.checkpoint = {"room_id":"R11","spawn_id":"entry"}
		events.append({"id":id,"type":"ending","payload":{"ending":choice}})
	elif kind in ["learn_skill", "allocate_attribute", "respec", "inventory"]:
		var operation: Dictionary
		if kind == "learn_skill":
			operation = progression.learn_skill(next.player, str(payload.get("skill_id", "")))
		elif kind == "allocate_attribute":
			operation = progression.allocate_attribute(next.player, str(payload.get("attribute", "")))
		elif kind == "respec":
			if next.room_id != "R01":
				return _reject("คืนแต้มได้ที่โรงซ่อม")
			operation = progression.respec(next.player)
		else:
			var request: Dictionary = payload.get("request", {}).duplicate(true)
			if request.get("kind", "") == "reward":
				return _reject("รางวัลต้องมาจากภารกิจหรือการต่อสู้")
			request["room_id"] = next.room_id
			operation = inventory.transact(next.player, request, content)
		if not operation.ok:
			return _reject(operation.reason)
		next.player = operation.state
		events.append_array(operation.events)
	else:
		return _reject("ไม่รู้จักคำสั่งความคืบหน้า")
	if claim_reward:
		next.claimed_rewards[id] = true
	state = next
	recent_commits.append(id)
	if recent_commits.size() > 128:
		recent_commits.pop_front()
	for i in range(events.size()):
		events[i]["id"] = id + ":" + str(i)
	return {"ok":true,"reason":"","state":snapshot(),"events":events}


func _award_quest(session: Dictionary, quest_id: String) -> Dictionary:
	var service := QuestService.new(content)
	var quest := service.get_definition(quest_id)
	var progress: Dictionary = session.quest_states.get(quest_id, {})
	if quest.is_empty() or progress.get("state", "") != "objectives_complete" or progress.get("choice", "").is_empty():
		return {"ok":false,"reason":"ภารกิจยังไม่พร้อมรับรางวัล","state":session.duplicate(true),"events":[]}
	var items: Array = [] if quest.get("item", "").is_empty() else [quest.item]
	var reward := inventory.transact(session.player, {"kind":"reward","items":items}, content)
	if not reward.ok:
		return {"ok":false,"reason":reward.reason,"state":session.duplicate(true),"events":[]}
	var next: Dictionary = session.duplicate(true)
	var growth := progression.gain_xp(reward.state, int(quest.xp))
	next.player = growth.state
	next.player.currency += int(quest.gold)
	next.player.skill_points += int(quest.skill_point)
	next.quest_states[quest_id].state = "turned_in"
	var events: Array = reward.events.duplicate(true)
	events.append_array(growth.events)
	events.append({"id":"quest:" + quest_id,"type":"quest_turned_in","payload":{"quest_id":quest_id,"xp":quest.xp,"gold":quest.gold,"item":quest.item}})
	return {"ok":true,"reason":"","state":next,"events":events}
