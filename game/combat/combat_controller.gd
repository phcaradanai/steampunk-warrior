class_name CombatController
extends RefCounted

var content: Dictionary
var state: Dictionary = {}
var encounter: Dictionary = {}
var learned: Dictionary = {}
var completed: Array[String] = []
var training_id: String = ""
var busy: bool = false
var run_id: String = ""
var sequence: int = 0
var rng := RandomNumberGenerator.new()
var resolver := CombatResolver.new()

func _init(catalog: Dictionary = {}) -> void:
	content = catalog

func _entry(kind: String, id: String) -> Dictionary:
	for entry in content.get(kind, []):
		if entry.id == id:
			return entry
	return {}

func _result(ok: bool, reason: String = "", events: Array = []) -> Dictionary:
	return {"ok":ok,"reason":reason,"state":state.duplicate(true),"events":events}

func _hero(player: Dictionary) -> Dictionary:
	var progression := Progression.new(content)
	var hero := progression.derive(player, content)
	hero.merge({"id":"hero","name":"คุณ","side":"player","class_id":player.class_id,"hp":player.current_hp,"fp":player.current_fp,"pressure":0,"statuses":{},"cooldowns":{},"potions":player.potions.duplicate(true)}, true)
	return hero

func _begin(actors: Array, progress: Dictionary, seed_value: int) -> void:
	state = {"actors":actors,"round":1,"acted_ids":[],"action_ids":[],"drone":{},"seed":seed_value}
	state["original_order"] = progress.world_flags.get("objective:original_order",false)
	if actors.any(func(a):return a.get("definition_id","") == "B03"):
		state.actors.append(_root_actor())
	learned = progress.player.skill_ranks.duplicate(true)
	completed.clear()
	busy = false
	sequence = 0
	rng.seed = seed_value
	run_id = "combat:" + Crypto.new().generate_random_bytes(16).hex_encode()
	for actor in state.actors:
		if actor.side == "enemy":
			actor["intent"] = _plan_intent(actor)

func start(encounter_id: String, progress: Dictionary, seed_value: int = 1) -> Dictionary:
	var policy := WorldController.new(content)
	var allowed := policy.can_start_encounter(encounter_id, progress)
	if not allowed.ok:
		return _result(false, allowed.reason)
	encounter = _entry("encounters", encounter_id)
	training_id = ""
	var actors: Array = [_hero(progress.player)]
	for i in range(encounter.enemies.size()):
		var definition := _entry("enemies", encounter.enemies[i])
		var scale: float = float(encounter.scale)
		var hp := int(ceil(float(definition.base_hp) * scale))
		var actor: Dictionary = {"id":"enemy" + str(i),"definition_id":definition.id,"name":definition.name,"side":"enemy","role":definition.role,"boss":definition.boss,"hp":hp,"max_hp":hp,"fp":999,"max_fp":999,"attack":int(ceil(float(definition.attack) * scale)),"tech":int(ceil(float(definition.tech) * scale)),"armor":definition.armor,"resist":definition.resist,"initiative":definition.initiative,"barrier":definition.barrier,"pressure":0,"statuses":{},"cooldowns":{},"phase":0,"phase_thresholds":definition.get("phase_thresholds", [])}
		if definition.id == "B01" and progress.world_flags.get("objective:water_valve", false):
			actor.attack = int(ceil(actor.attack * 0.8))
		if definition.id == "B04" and progress.world_flags.get("environment:furnace_coolant",false):
			actor.attack = int(ceil(actor.attack*0.8))
			actor.tech = int(ceil(actor.tech*0.8))
		actors.append(actor)
	_begin(actors, progress, seed_value)
	var room := _entry("rooms",encounter.room)
	if not room.get("hazard","").is_empty() and WorldController.hazard_active(encounter.room,progress.world_flags):
		_actor("hero").statuses[room.hazard] = {"turns":2}
		if room.hazard == "Wet":
			for enemy in state.actors:
				if enemy.side == "enemy": enemy.statuses.Wet = {"turns":2}
	return _result(true)

func start_training(tier_id: String, progress: Dictionary, seed_value: int = 1) -> Dictionary:
	var service := TrainingService.new(content)
	var allowed := service.start(tier_id, progress)
	if not allowed.ok:
		return _result(false, allowed.reason)
	training_id = tier_id
	encounter = {}
	var hero := _hero(progress.player)
	hero.max_hp = 5000
	hero.hp = 3500
	hero.fp = 500
	hero.max_fp = 500
	hero.potions = {"life":99,"focus":99}
	if tier_id == "T03":
		hero.statuses["Heated"] = {"turns":99}
	if tier_id == "T04":
		hero.pressure = 80
	var dummy: Dictionary = {"id":"enemy0","name":"หุ่นฝึกหม้อน้ำ","side":"enemy","role":"training","boss":false,"hp":5000,"max_hp":5000,"fp":999,"max_fp":999,"attack":4,"tech":4,"armor":0,"resist":0,"initiative":1,"barrier":30 if tier_id == "T02" else 0,"pressure":0,"statuses":{},"cooldowns":{}}
	_begin([hero,dummy], progress, seed_value)
	for skill_id in TrainingService.LOANS[tier_id]:
		learned[skill_id] = maxi(1, int(learned.get(skill_id, 0)))
	return _result(true)

func is_finished() -> bool:
	return not state.get("outcome", "").is_empty()

func _actor(id: String) -> Dictionary:
	for actor in state.get("actors", []):
		if actor.id == id:
			return actor
	return {}

func is_player_turn() -> bool:
	if busy or state.is_empty() or is_finished():
		return false
	var actors: Array[Dictionary] = []
	actors.assign(state.actors)
	var acted: Array[String] = []
	acted.assign(state.acted_ids)
	var order := resolver.get_turn_order(actors, acted)
	return not order.is_empty() and order[0] == "hero"

func submit_player(kind: String, skill_id: String = "", target_id: String = "enemy0") -> Dictionary:
	if not is_player_turn():
		return _result(false, "รอผลคำสั่งก่อน")
	var action: Dictionary = {"commit_id":run_id + ":" + str(sequence),"actor_id":"hero","kind":kind,"target_id":target_id}
	if kind == "skill":
		if int(learned.get(skill_id, 0)) < 1:
			return _result(false, "ยังไม่ได้เรียนสกิลนี้")
		action["skill"] = _entry("skills", skill_id)
		action["rank"] = int(learned[skill_id])
	var before := state.duplicate(true)
	var result := resolver.apply_action(state, action, rng)
	if not result.ok:
		return result
	state = result.state
	sequence += 1
	busy = true
	if skill_id == "S20":
		for opponent in state.actors:
			if opponent.get("definition_id","") == "B04":
				opponent["heat"] = maxi(0,int(opponent.get("heat",0))-35)
	_settle_helpers()
	if not training_id.is_empty():
		_track_training(action, before, result.events)
	return _result(true, "", result.events)

func advance() -> Dictionary:
	busy = false
	if is_finished() or state.is_empty() or is_player_turn():
		return _result(true)
	var actors: Array[Dictionary] = []
	actors.assign(state.actors)
	var acted: Array[String] = []
	acted.assign(state.acted_ids)
	var order := resolver.get_turn_order(actors, acted)
	if order.is_empty():
		return _result(false, "ไม่มีผู้ทำคำสั่ง")
	var enemy := _actor(order[0])
	var action: Dictionary = enemy.intent.duplicate(true)
	action["actor_id"] = enemy.id
	if not action.has("target_id"):
		action["target_id"] = "hero"
	action["commit_id"] = run_id + ":" + str(sequence)
	var result := resolver.apply_action(state, action, rng)
	if not result.ok:
		return result
	state = result.state
	sequence += 1
	busy = true
	var current := _actor(enemy.id)
	current["actions_taken"] = int(current.get("actions_taken",0))+1
	_boss_action_complete(current,int(enemy.get("phase",0)),action)
	_settle_helpers()
	current["intent"] = _plan_intent(current)
	return _result(true, "", result.events)

func _root_actor() -> Dictionary:
	var boss := _actor("enemy0")
	var hp := maxi(30,int(boss.max_hp*0.08))
	return {"id":"root","definition_id":"root","name":"หน่อรากแก้ว","side":"enemy","role":"root","boss":false,"hp":hp,"max_hp":hp,"fp":999,"max_fp":999,"attack":1,"tech":maxi(8,int(boss.max_hp*0.025)),"armor":0,"resist":0,"initiative":1,"barrier":0,"pressure":0,"statuses":{},"cooldowns":{}}

func _settle_helpers() -> void:
	var root := _actor("root")
	if not root.is_empty() and _actor("enemy0").hp <= 0:
		root.hp = 0
		if _actor("hero").hp > 0:
			state["outcome"] = "victory"

func _boss_action_complete(enemy: Dictionary, old_phase: int, action: Dictionary) -> void:
	var id: String = enemy.get("definition_id","")
	if id == "B03" and int(enemy.phase) > old_phase and enemy.hp > 0:
		var root := _actor("root")
		if root.hp <= 0:
			root.hp = root.max_hp
			root.statuses.clear()
			root["intent"] = _plan_intent(root)
			if not "root" in state.acted_ids: state.acted_ids.append("root")
	if id == "B04":
		var heat: int = int(enemy.get("heat",0))
		enemy["heat"] = 0 if action.get("overheat",false) else clampi(heat+(35 if action.kind == "skill" else -15),0,100)
		enemy["cooling"] = action.get("overheat",false)
	if id == "B06" and int(enemy.phase) == 2 and not enemy.get("core_exposed",false):
		enemy["core_exposed"] = true
		enemy.armor = int(enemy.armor*0.45)
		enemy.resist = int(enemy.resist*0.45)

func _effect_intent(id: String, label: String, effects: Dictionary, target: String = "enemy") -> Dictionary:
	return {"kind":"skill","rank":1,"label":label,"skill":{"id":"AI_"+id,"kind":"active","fp_cost":0,"pressure_delta":0,"target":target,"effects":effects}}

func _memory_intent(index: int) -> Dictionary:
	match index%3:
		0: return {"kind":"guard","label":"บันทึกหนึ่ง: ตั้งรับและอ่านความทรงจำ"}
		1: return _effect_intent("memory_mark","บันทึกสอง: หมายหัว — นัดถัดไปแรงขึ้น",{"status":"Marked","duration":2})
	return _effect_intent("memory_shot","บันทึกสาม: ยิงรอยประทับ — เตรียม Guard",{"power":1.6,"marked_multiplier":1.5,"damage_type":"physical"})

func _boss_intent(enemy: Dictionary) -> Dictionary:
	var phase: int = int(enemy.get("phase",0))
	var count: int = int(enemy.get("actions_taken",0))
	match enemy.get("definition_id",""):
		"root":
			var heal := _effect_intent("root_heal","ส่งน้ำเลี้ยงฟื้นกวาง — Sealed ที่กวางหยุดได้",{"heal":1.0},"ally")
			heal["target_id"] = "enemy0"
			return heal
		"B02":
			if count%3 == 0 and enemy.barrier <= 0:
				return _skill_intent("S11","ซ่อมโล่ขบวน — เจาะโล่ก่อนยิงสวน")
			if count%3 == 2:
				return _effect_intent("rail_burst","ยิงสองนัด — ตั้งรับหรือกางโล่",{"power":0.7+phase*0.1,"hits":2,"damage_type":"physical"})
			return {"kind":"guard","label":"เปิดช่องเติมกระสุน — จังหวะเตรียมตัว"}
		"B03":
			if count%3 == 0: return {"kind":"guard","label":"หยั่งราก — หน่อกำลังส่งน้ำเลี้ยง"}
			return _skill_intent("S08","กรดรากแก้ว — โค่นหน่อหรือปิดการฟื้นฟู",phase)
		"B04":
			if enemy.get("cooling",false): return {"kind":"guard","label":"เตาหลอมเย็นตัว — จังหวะฟื้นพลังและโจมตี"}
			if int(enemy.get("heat",0)) >= 70:
				var heavy := _effect_intent("furnace","เตาหลอมวิกฤต — ฟาดสองครั้ง เตรียม Guard",{"power":0.85+phase*0.1,"hits":2,"damage_type":"thermal"})
				heavy["overheat"] = true
				return heavy
			return _effect_intent("furnace_heat","เติมเชื้อเพลิง — Wet ลดความร้อน",{"power":0.85+phase*0.1,"damage_type":"thermal","status":"Heated","duration":2})
		"B05":
			var memory := _memory_intent(count)
			if state.get("original_order",false): memory["following_label"] = _memory_intent(count+1).label
			return memory
		"B06":
			if count%4 == 0:
				return {"kind":"guard","label":"เปิดแกนเอเธอร์ — เตรียมรับท่าถัดไป" if phase == 2 else "อัดสนามเอเธอร์ — จังหวะฟื้นพลัง"}
			if count%4 == 3: return {"kind":"guard","label":"ปีกพับฟื้นสนาม — จังหวะโจมตีหรือเติมทรัพยากร"}
			if count%4 == 1:
				if phase == 0: return _skill_intent("S20","หมอกควบแน่น — ระวังไฟฟ้าท่าถัดไป")
				if phase == 1: return _effect_intent("queen_heat","ปีกความร้อน — ระบายหรือล้าง Heated",{"power":0.85,"damage_type":"thermal","status":"Heated","duration":2})
				return _effect_intent("queen_core","แกนเปิด: กรีดสามครั้ง — เตรียม Guard",{"power":0.6,"hits":3,"damage_type":"physical"})
			if phase == 0: return _effect_intent("queen_arc","อาร์กผ่านหมอก — เตรียม Guard",{"power":1.15,"damage_type":"electric"})
			if phase == 1: return _effect_intent("queen_wings","ปีกคู่ — ตั้งรับสองแรงกระแทก",{"power":0.65,"hits":2,"damage_type":"thermal"})
			return {"kind":"guard","label":"แกนไร้เกราะพักตัว — โอกาสโจมตี"}
	return {}

func _skill_intent(id: String, label: String, phase: int = 0) -> Dictionary:
	var skill := _entry("skills", id).duplicate(true)
	skill.fp_cost = 0
	skill.pressure_delta = 0
	if skill.effects.has("power"):
		skill.effects.power *= 1.0 + phase * 0.15
	if id in ["S09", "S11"]:
		skill.effects["cooldown"] = 2
	return {"kind":"skill","skill":skill,"rank":1,"label":label}

func _plan_intent(enemy: Dictionary) -> Dictionary:
	var boss_action := _boss_intent(enemy)
	if not boss_action.is_empty(): return boss_action
	var phase: int = int(enemy.get("phase", 0))
	var role: String = enemy.get("role", "bite")
	if role == "training":
		if training_id == "T04" and int(state.get("round", 1)) % 2 == 1:
			return {"kind":"attack","power":2.0,"label":"จำลองท่าหนัก — Guard ลดแรงกระแทก"}
		return {"kind":"guard","label":"รอให้ทดลองท่าต่อไป"}
	if role == "charge":
		if int(state.get("round", 1)) % 2 == 1:
			return {"kind":"guard","label":"อัดแรงดัน — ท่าถัดไปโจมตีหนัก"}
		return {"kind":"attack","power":2.2 + phase * 0.2,"label":"กระแทกหนัก — เตรียม Guard"}
	if role in ["guard", "repair"] and enemy.barrier <= 0 and enemy.cooldowns.get("S11", 0) <= 0:
		return _skill_intent("S11", "ซ่อมสนามโล่", phase)
	if role == "heal" and float(enemy.hp) / float(enemy.max_hp) < 0.6 and enemy.cooldowns.get("S09", 0) <= 0 and not enemy.statuses.has("Sealed"):
		return _skill_intent("S09", "ฉีดยาฟื้นฟู — Sealed หยุดได้", phase)
	var special: Dictionary = {"heat":["S14","พ่นควันร้อน"],"corrode":["S08","ปล่อยกรดกัดเกราะ"],"sealed":["S21","ฉีดสารยับยั้งการฟื้นฟู"],"wet":["S20","พ่นละอองเปียก"],"howl":["S03","ทำเครื่องหมายเป้าหมาย"],"mark":["S03","เล็งจุดอ่อน"],"area":["S05","ยิงกระจาย"],"electric":["S04","ปล่อยอาร์กไฟฟ้า"],"stagger":["S15","ฟาดเสียจังหวะ"]}
	if special.has(role):
		return _skill_intent(special[role][0], special[role][1], phase)
	return {"kind":"attack","power":1.0 + phase * 0.15,"label":"โจมตีเร็ว" if role == "quick" else "โจมตี"}

func _track_training(action: Dictionary, before: Dictionary, events: Array) -> void:
	var achieved: Array[String] = []
	if action.kind in ["attack", "guard", "vent"]:
		achieved.append(action.kind)
	var old_hero: Dictionary = before.actors[0]
	var hero := _actor("hero")
	var old_enemy: Dictionary = before.actors[1]
	var enemy := _actor("enemy0")
	if old_enemy.barrier > 0 and enemy.barrier <= 0:
		achieved.append("shield_break")
	if old_hero.statuses.has("Heated") and not hero.statuses.has("Heated"):
		achieved.append("cleanse")
	if enemy.statuses.has("Sealed"):
		achieved.append("sealing")
	if old_hero.pressure >= 75 and hero.pressure <= 50:
		achieved.append("pressure_safe")
	if not state.drone.is_empty():
		achieved.append("drone")
	if action.kind == "guard" and float(old_enemy.intent.get("power", 0)) >= 1.8:
		achieved.append("intent_counter")
	for event in events:
		if event.type == "heal" and event.payload.amount > 0:
			achieved.append("heal")
		if event.type == "damage" and event.payload.get("source_id", "") == "hero":
			if old_enemy.statuses.has("Marked"):
				achieved.append("marked_hit")
			if event.payload.get("type", "") == "electric" and old_enemy.statuses.has("Wet"):
				achieved.append("wet_combo")
	for objective in achieved:
		if objective in TrainingService.OBJECTIVES[training_id] and not objective in completed:
			completed.append(objective)

func end_training() -> Dictionary:
	if training_id.is_empty() or not is_player_turn():
		return _result(false, "จบการฝึกได้เมื่อถึงช่วงเลือกคำสั่ง")
	state["outcome"] = "training_end"
	return _result(true)

func result_payload() -> Dictionary:
	if not training_id.is_empty():
		return {"id":run_id,"tier_id":training_id,"completed":completed.duplicate()}
	var hero := _actor("hero")
	return {"id":run_id,"encounter_id":encounter.get("id", ""),"current_hp":hero.get("hp", 1),"current_fp":hero.get("fp", 0),"potions":hero.get("potions", {}).duplicate(true)}
