class_name WorldController
extends RefCounted

var content: Dictionary
var session: GameSession
var last_error: String = ""
const ENVIRONMENT := {
	"canal_gate":{"room":"R03","label":"ปิดประตูน้ำ ลดละอองเปียก"},
	"sluice_release":{"room":"R04","label":"ระบายน้ำออกจากลานต่อสู้"},
	"specimen_intake":{"room":"R07","label":"ปิดวาล์วไหลเข้า ช่วยรังมีชีวิต"},
	"specimen_exhaust":{"room":"R07","label":"เปิดวาล์วระบาย ช่วยรังมีชีวิต"},
	"lab_scrubber":{"room":"R08","label":"เปิดเครื่องกรองไอกรด"},
	"coal_exhaust":{"room":"R09","label":"เปิดปล่องดูดควันร้อน"},
	"furnace_coolant":{"room":"R10","label":"เปิดหล่อเย็น ลดพลังนายช่าง20%"},
}
const HAZARD_CONTROLS := {"R03":"canal_gate","R04":"sluice_release","R07":"specimen_exhaust","R08":"lab_scrubber","R09":"coal_exhaust","R10":"furnace_coolant"}

static func hazard_active(room: String, flags: Dictionary) -> bool:
	return HAZARD_CONTROLS.has(room) and not flags.get("environment:"+HAZARD_CONTROLS[room],false)

func _init(catalog: Dictionary = {}, active_session: GameSession = null) -> void:
	content = catalog
	session = active_session

func _entry(kind: String, id: String) -> Dictionary:
	for entry in content.get(kind, []):
		if entry.id == id:
			return entry
	return {}

func can_travel(from_id: String, to_id: String, progress: Dictionary) -> bool:
	var from := _entry("rooms", from_id)
	var to := _entry("rooms", to_id)
	if from.is_empty() or to.is_empty() or from_id == to_id:
		return false
	for exit in from.exits:
		if exit.to == to_id:
			return exit.requires.is_empty() or progress.get("first_clears", {}).has(exit.requires)
	if from.get("fast_travel", false) and to_id == "R01":
		return true
	if from_id == "R01" and to.get("fast_travel", false) and progress.get("world_flags", {}).get("visited:" + to_id, false):
		return true
	return false

func enter_room(room_id: String, spawn_id: String) -> void:
	last_error = ""
	if session == null or session.state.is_empty():
		last_error = "ยังไม่มีการผจญภัย"
		return
	if not can_travel(session.state.room_id, room_id, session.state):
		last_error = "ทางยังไม่เปิด"
		return
	var next := session.snapshot()
	next.room_id = room_id
	next.world_flags["visited:" + room_id] = true
	next.checkpoint = {"room_id":room_id,"spawn_id":spawn_id}
	session.state = next

func can_start_encounter(encounter_id: String, progress: Dictionary) -> Dictionary:
	var encounter := _entry("encounters", encounter_id)
	var reason := ""
	if encounter.is_empty():
		reason = "ไม่รู้จักการต่อสู้"
	elif progress.get("room_id", "") != encounter.room:
		reason = "ต้องไปยังพื้นที่นั้นก่อน"
	elif progress.get("player", {}).get("energy", 0) <= 0:
		reason = "พลังงานหมด กลับโรงซ่อมพักฟรีได้"
	elif progress.get("player", {}).get("current_hp", 0) <= 0:
		reason = "พักฟื้นก่อนเริ่มต่อสู้"
	elif not encounter.boss_id.is_empty() and progress.get("first_clears", {}).has(encounter.id) and not progress.get("world_flags", {}).get("postgame", false):
		reason = "บอสนี้ผ่านแล้ว เล่นซ้ำหลังจบเรื่อง"
	elif not encounter.requires.is_empty() and not progress.get("first_clears", {}).has(encounter.requires):
		var previous := _entry("encounters", encounter.requires)
		if previous.is_empty() or previous.get("optional_bypass", "").is_empty() or not progress.get("world_flags", {}).get(previous.optional_bypass, false):
			reason = "ผ่านเหตุการณ์ก่อนหน้าหรือหาทางเลือกก่อน"
	return {"ok":reason.is_empty(),"reason":reason}
