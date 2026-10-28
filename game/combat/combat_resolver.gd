class_name CombatResolver
extends RefCounted

func get_turn_order(actors: Array[Dictionary], acted_ids: Array[String]) -> Array[String]:
	var eligible: Array[Dictionary] = []
	for actor in actors:
		if actor.get("hp", 0) > 0 and not actor.id in acted_ids:
			eligible.append(actor)
	eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := _initiative(a)
		var right := _initiative(b)
		return a.id < b.id if left == right else left > right)
	var ids: Array[String] = []
	for actor in eligible:
		ids.append(actor.id)
	return ids

func _initiative(actor: Dictionary) -> int:
	var value: int = int(actor.get("initiative", 10))
	if actor.get("statuses", {}).has("Haste"):
		value += 20
	if actor.get("statuses", {}).has("Staggered"):
		value -= 20
	return value

func _actor(state: Dictionary, id: String) -> Dictionary:
	for actor in state.get("actors", []):
		if actor.get("id", "") == id:
			return actor
	return {}

func _reject(state: Dictionary, reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"state":state.duplicate(true),"events":[]}

func _emit(events: Array, commit_id: String, type: String, payload: Dictionary) -> void:
	events.append({"id":commit_id + ":" + str(events.size()),"type":type,"payload":payload})

func apply_action(state: Dictionary, action: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var commit_id: String = str(action.get("commit_id", ""))
	if commit_id.is_empty() or commit_id in state.get("action_ids", []):
		return _reject(state, "คำสั่งนี้ถูกใช้แล้วหรือไม่มีหมายเลข")
	if not state.get("outcome", "").is_empty():
		return _reject(state, "การต่อสู้จบแล้ว")
	var original_actor := _actor(state, str(action.get("actor_id", "")))
	if original_actor.is_empty() or original_actor.get("hp", 0) <= 0:
		return _reject(state, "ผู้ใช้คำสั่งไม่พร้อม")
	var typed_actors: Array[Dictionary] = []
	typed_actors.assign(state.get("actors", []))
	var acted: Array[String] = []
	acted.assign(state.get("acted_ids", []))
	var order := get_turn_order(typed_actors, acted)
	if order.is_empty() or order[0] != original_actor.id:
		return _reject(state, "ยังไม่ถึงเทิร์น")
	var kind: String = str(action.get("kind", ""))
	if not kind in ["attack", "skill", "guard", "vent", "life_potion", "focus_potion", "retreat"]:
		return _reject(state, "ไม่รู้จักคำสั่ง")
	var skill: Dictionary = action.get("skill", {})
	var effects: Dictionary = {}
	var fp_cost := 0
	var pressure_delta := 0
	var rank: int = int(action.get("rank", 1))
	var target_mode := "enemy"
	if kind == "skill":
		if skill.is_empty() or skill.get("kind", "") != "active" or rank < 1 or rank > 10 or not skill.get("effects") is Dictionary:
			return _reject(state, "สกิลไม่ถูกต้อง")
		fp_cost = int(skill.get("fp_cost", -1))
		pressure_delta = int(skill.get("pressure_delta", 0))
		if fp_cost < 0 or absi(pressure_delta) > 100:
			return _reject(state, "ต้นทุนสกิลไม่ถูกต้อง")
		fp_cost = _fp_cost(original_actor,skill)
		if original_actor.get("cooldowns", {}).get(skill.id, 0) > 0:
			return _reject(state, "สกิลยังพักอยู่")
		effects = skill.effects
		target_mode = skill.get("target", "enemy")
	elif kind == "attack":
		effects = {"power":float(action.get("power", 1.0)),"damage_type":action.get("damage_type", "physical")}
	else:
		target_mode = "self"
	if original_actor.get("fp", 0) < fp_cost:
		return _reject(state, "โฟกัสไม่พอ")
	if original_actor.get("pressure", 0) + pressure_delta > 100:
		return _reject(state, "แรงดันจะเกิน100 ต้องระบายก่อน")
	var targets: Array[String] = []
	if target_mode in ["self", "summon"]:
		targets.append(original_actor.id)
	elif target_mode == "all_enemies":
		for other in state.actors:
			if other.side != original_actor.side and other.hp > 0:
				targets.append(other.id)
	else:
		var target := _actor(state, str(action.get("target_id", "")))
		if target.is_empty() or target.hp <= 0 or (target.side != original_actor.side if target_mode == "ally" else target.side == original_actor.side):
			return _reject(state, "เลือกเป้าหมายที่ยังมีชีวิต")
		targets.append(target.id)
	if targets.is_empty():
		return _reject(state, "ไม่มีเป้าหมาย")
	if kind in ["life_potion", "focus_potion"]:
		var potion := "life" if kind == "life_potion" else "focus"
		if original_actor.get("potions", {}).get(potion, 0) < 1:
			return _reject(state, "ยาหมด")
	if kind == "retreat":
		for opponent in state.actors:
			if opponent.side != original_actor.side and opponent.hp > 0 and opponent.get("boss", false):
				return _reject(state, "ถอยจากบอสไม่ได้")
	var next: Dictionary = state.duplicate(true)
	var actor := _actor(next, original_actor.id)
	var started_statuses: Dictionary = actor.get("statuses", {}).duplicate(true)
	var started_cooldowns: Dictionary = actor.get("cooldowns", {}).duplicate(true)
	actor["statuses"] = actor.get("statuses", {})
	actor["cooldowns"] = actor.get("cooldowns", {})
	actor.statuses.erase("Guard")
	actor.fp -= fp_cost
	actor.pressure = clampi(int(actor.get("pressure", 0)) + pressure_delta, 0, 100)
	var events: Array = []
	_emit(events, commit_id, "action", {"actor_id":actor.id,"kind":kind,"skill_id":skill.get("id", "")})
	if kind == "vent":
		actor.pressure = maxi(0, int(actor.pressure) - 35)
		actor.fp = mini(int(actor.get("max_fp", 0)), int(actor.fp) + 5)
		actor["vent_bonus"] = true
	elif kind == "guard":
		actor.statuses["Guard"] = {"turns":1}
	elif kind == "retreat":
		next["outcome"] = "retreat"
	elif kind in ["life_potion", "focus_potion"]:
		var potion := "life" if kind == "life_potion" else "focus"
		actor.potions[potion] -= 1
		if potion == "life":
			_heal(actor, int(ceil(float(actor.max_hp) * 0.35)), events, commit_id)
		else:
			actor.fp = mini(int(actor.max_fp), int(actor.fp) + int(ceil(float(actor.max_fp) * 0.35)))
	else:
		var rank_scale := _rank_scale(rank)
		for target_id in targets:
			var target := _actor(next, target_id)
			if effects.has("power"):
				var was_wet: bool = target.get("statuses", {}).has("Wet")
				for _hit in range(int(effects.get("hits", 1))):
					if target.hp <= 0:
						break
					_damage(actor, target, effects, rank_scale, rng, events, commit_id)
				if effects.has("marked_multiplier"):
					target.get("statuses", {}).erase("Marked")
				if effects.get("stagger_wet", false) and was_wet and target.hp > 0:
					_status(target, "Staggered", 1, actor)
			if effects.has("heal"):
				var amount := _heal_amount(actor,effects,rank_scale)
				_heal(target, amount, events, commit_id)
			if effects.has("barrier"):
				target.barrier += int(ceil(float(effects.barrier) * float(actor.tech) * rank_scale))
			if effects.has("status") and target.hp > 0:
				_status(target, effects.status, int(effects.get("duration", 1)), actor)
			if effects.has("remove_status"):
				target.statuses.erase(effects.remove_status)
		if effects.get("summon", false):
			next["drone"] = {"owner_id":actor.id,"actions":int(effects.get("drone_actions", 3)),"power":float(effects.get("drone_power", 0.5)) * rank_scale}
		if effects.get("cooldown", 0) > 0:
			actor.cooldowns[skill.id] = int(effects.cooldown)
		if skill.get("id", "") == "S20" and actor.get("equipment_specials", []).has("condensate_barrier"):
			actor.barrier += int(ceil(float(actor.tech) * 0.15))
	if next.get("drone", {}).get("owner_id", "") == actor.id and kind != "retreat":
		for other in next.actors:
			if other.side != actor.side and other.hp > 0:
				_damage(actor, other, {"power":next.drone.power,"damage_type":"electric"}, 1.0, rng, events, commit_id)
				break
		next.drone.actions -= 1
		if next.drone.actions <= 0:
			next.drone = {}
	if started_statuses.has("Heated") and actor.statuses.has("Heated"):
		var heat_damage := maxi(1, int(ceil(float(actor.max_hp) * 0.03)))
		actor.hp = maxi(0, int(actor.hp) - heat_damage)
		_emit(events, commit_id, "damage", {"target_id":actor.id,"amount":heat_damage,"type":"Heated"})
	for status in started_statuses:
		if status == "Guard" or not actor.statuses.has(status):
			continue
		actor.statuses[status].turns -= 1
		if actor.statuses[status].turns <= 0:
			actor.statuses.erase(status)
	for cooldown in started_cooldowns:
		if cooldown != skill.get("id", ""):
			actor.cooldowns[cooldown] = maxi(0, int(actor.cooldowns.get(cooldown, 0)) - 1)
	if actor.get("boss", false):
		var phase := 0
		for threshold in actor.get("phase_thresholds", []):
			if float(actor.hp) / maxf(1.0, float(actor.max_hp)) <= float(threshold):
				phase += 1
		actor["phase"] = phase
	next["action_ids"] = next.get("action_ids", [])
	next.action_ids.append(commit_id)
	next["acted_ids"] = next.get("acted_ids", [])
	next.acted_ids.append(actor.id)
	var allies_alive := false
	var enemies_alive := false
	for other in next.actors:
		if other.hp > 0:
			if other.side == "player":
				allies_alive = true
			else:
				enemies_alive = true
	if not next.has("outcome") or next.outcome.is_empty():
		if not allies_alive:
			next["outcome"] = "defeat"
		elif not enemies_alive:
			next["outcome"] = "victory"
	var next_actors: Array[Dictionary] = []
	next_actors.assign(next.actors)
	var next_acted: Array[String] = []
	next_acted.assign(next.acted_ids)
	if get_turn_order(next_actors, next_acted).is_empty():
		next.acted_ids = []
		next["round"] = int(next.get("round", 1)) + 1
	return {"ok":true,"reason":"","state":next,"events":events}

func _status(target: Dictionary, status: String, duration: int, source: Dictionary) -> void:
	target["statuses"] = target.get("statuses", {})
	if status == "Wet":
		target.statuses.erase("Heated")
	elif status == "Heated":
		target.statuses.erase("Wet")
	if source.get("class_id", "") == "C05" and status in ["Wet", "Corroded"]:
		duration += 1
	var previous: int = int(target.statuses.get(status, {}).get("turns", 0))
	target.statuses[status] = {"turns":maxi(previous, duration)}

func _heal(target: Dictionary, amount: int, events: Array, commit_id: String) -> void:
	if target.get("statuses", {}).has("Sealed"):
		return
	var before: int = int(target.hp)
	target.hp = mini(int(target.max_hp), before + amount)
	_emit(events, commit_id, "heal", {"target_id":target.id,"amount":target.hp - before})

func _damage(source: Dictionary, target: Dictionary, effects: Dictionary, rank_scale: float, rng: RandomNumberGenerator, events: Array, commit_id: String) -> void:
	var type: String = effects.get("damage_type", "physical")
	var stat: float = float(source.get("attack", 1) if type == "physical" else source.get("tech", 1))
	var raw: float = float(effects.get("power", 1.0)) * stat * rank_scale
	var statuses: Dictionary = target.get("statuses", {})
	if statuses.has("Marked"):
		raw *= float(effects.get("marked_multiplier", 1.0))
		if source.get("class_id", "") == "C02":
			raw *= 1.1
	if float(source.hp) / maxf(1.0, float(source.max_hp)) <= 0.35:
		raw *= float(effects.get("low_hp_multiplier", 1.0))
	if type == "electric" and statuses.has("Wet"):
		raw *= 1.25
	var defense: float = float(target.get("armor", 0) if type == "physical" else target.get("resist", 0))
	if type == "physical":
		if statuses.has("Corroded"):
			defense *= 0.75
		defense *= 1.0 - float(effects.get("armor_ignore", 0.0))
	var amount := maxi(1, int(floor(raw * 100.0 / (100.0 + maxf(0.0, defense)) * rng.randf_range(0.95, 1.05))))
	if statuses.has("Guard"):
		amount = maxi(1, int(floor(amount * 0.5)))
	var shielded: bool = target.get("barrier", 0) > 0
	if shielded:
		amount = maxi(1, int(floor(amount * float(effects.get("shield_multiplier", 1.0)))))
		if source.get("vent_bonus", false) and source.get("equipment_specials", []).has("vent_breaker"):
			amount = int(ceil(amount * 1.5))
		target.barrier = maxi(0, int(target.barrier) - amount)
	else:
		target.hp = maxi(0, int(target.hp) - amount)
	source["vent_bonus"] = false
	_emit(events, commit_id, "damage", {"source_id":source.id,"target_id":target.id,"amount":amount,"shielded":shielded,"type":type})


func _fp_cost(actor: Dictionary, skill: Dictionary) -> int:
	var cost: int = int(skill.get("fp_cost",0))
	return maxi(1,cost-1) if actor.get("class_id","") == "C03" and cost > 0 else cost

func _rank_scale(rank: int) -> float:
	return 1.0 + 0.06 * (clampi(rank,1,10) - 1)

func _heal_amount(actor: Dictionary, effects: Dictionary, scale: float) -> int:
	var amount := int(ceil(float(effects.get("heal",0)) * float(actor.get("tech",0)) * scale))
	return int(ceil(amount * 1.2)) if actor.get("class_id","") == "C04" else amount

func skill_preview(actor: Dictionary, skill: Dictionary, rank: int) -> Dictionary:
	var effects: Dictionary = skill.get("effects",{})
	var type: String = effects.get("damage_type","physical")
	var stat: float = float(actor.get("attack",0) if type == "physical" else actor.get("tech",0))
	var scale := _rank_scale(rank)
	var raw: float = float(effects.get("power",0)) * stat * scale
	var duration: int = int(effects.get("duration",0))
	if actor.get("class_id","") == "C05" and effects.get("status","") in ["Wet","Corroded"]:
		duration += 1
	return {"fp_cost":_fp_cost(actor,skill),"pressure_delta":int(skill.get("pressure_delta",0)),"damage_min":int(floor(raw*0.95)),"damage_max":int(floor(raw*1.05)),"damage_type":type,"hits":int(effects.get("hits",1)),"heal":_heal_amount(actor,effects,scale),"barrier":int(ceil(float(effects.get("barrier",0))*float(actor.get("tech",0))*scale)),"status":effects.get("status",""),"duration":duration,"cooldown":int(effects.get("cooldown",0)),"target":skill.get("target","self"),"passive":effects.get("passive",""),"passive_total":float(effects.get("per_rank",0))*rank,"drone_min":int(floor(float(effects.get("drone_power",0))*float(actor.get("tech",0))*scale*0.95)),"drone_max":int(floor(float(effects.get("drone_power",0))*float(actor.get("tech",0))*scale*1.05))}
