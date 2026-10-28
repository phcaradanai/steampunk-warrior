class_name TrainingService
extends RefCounted

const OBJECTIVES: Dictionary = {"T01":["attack","guard","vent"],"T02":["shield_break","marked_hit","heal"],"T03":["wet_combo","sealing","cleanse"],"T04":["pressure_safe","intent_counter","drone"]}
const LOANS: Dictionary = {"T01":[],"T02":["S01","S03","S09"],"T03":["S20","S04","S21","S22"],"T04":["S12","S22","S11","S20"]}
var content: Dictionary
var progression: Progression

func _init(catalog: Dictionary = {}) -> void:
	content = catalog
	progression = Progression.new(content)

func definition(id: String) -> Dictionary:
	for tier in content.get("training", []):
		if tier.id == id:
			return tier
	return {}

func _result(session: Dictionary, ok: bool, reason: String = "", events: Array = []) -> Dictionary:
	return {"ok":ok,"reason":reason,"state":session.duplicate(true),"events":events}

func start(id: String, session: Dictionary) -> Dictionary:
	var tier := definition(id)
	if tier.is_empty():
		return _result(session, false, "ไม่รู้จักระดับการฝึก")
	if session.get("room_id", "") != "R01" or session.get("player", {}).get("energy", 0) <= 0:
		return _result(session, false, "พักที่โรงซ่อมแล้วเริ่มฝึก")
	if tier.unlock_after != "start" and not session.get("first_clears", {}).has(tier.unlock_after):
		return _result(session, false, "ยังไม่เปิดการฝึกระดับนี้")
	return _result(session, true, "", [{"id":"training:" + id,"type":"training_started","payload":{"tier_id":id,"objectives":OBJECTIVES[id],"loan_skills":LOANS[id]}}])

func settle(id: String, completed: Array, session: Dictionary) -> Dictionary:
	var eligibility := start(id, session)
	if not eligibility.ok:
		return eligibility
	var tier := definition(id)
	var unique: Array[String] = []
	for objective in completed:
		if not objective is String or not objective in OBJECTIVES[id]:
			return _result(session, false, "เป้าหมายการฝึกไม่ถูกต้อง")
		if not objective in unique:
			unique.append(objective)
	var next: Dictionary = session.duplicate(true)
	var claim_key := "training:" + id
	var claimed: Array = next.world_flags.get(claim_key, []).duplicate()
	var xp := 0
	var count: int = OBJECTIVES[id].size()
	for objective in unique:
		var repeat: bool = objective in claimed
		var budget: int = int(tier.reward_repeat_xp if repeat else tier.reward_first_xp)
		var index: int = OBJECTIVES[id].find(objective)
		xp += int(floor(float(budget) / count)) + (1 if index < budget % count else 0)
		if not repeat:
			claimed.append(objective)
	next.world_flags[claim_key] = claimed
	var growth := progression.gain_xp(next.player, xp)
	next.player = growth.state
	var events: Array = growth.events.duplicate(true)
	events.append({"id":"training:" + id,"type":"training_settled","payload":{"tier_id":id,"xp":xp,"completed":unique}})
	return _result(next, true, "", events)
