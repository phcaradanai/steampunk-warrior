class_name SaveService
extends RefCounted

const SLOTS: Array[String] = ["manual01","manual02","manual03","autosave"]
const VERSION: int = 1
var content: Dictionary
var directory: String

func _init(catalog: Dictionary = {}, root_path: String = "user://saves") -> void:
	content = catalog
	directory = root_path

func _entry(kind: String, id: String) -> Dictionary:
	for entry in content.get(kind, []):
		if entry.id == id:
			return entry
	return {}

func _failure(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"state":{},"events":[]}

func _whole(value: Variant, low: int, high: int) -> bool:
	if not value is int and not value is float:
		return false
	return is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

func _plain(value: Variant, depth: int = 0) -> bool:
	if depth > 12:
		return false
	if value is Dictionary:
		if value.size() > 20000:
			return false
		for key in value:
			if not key is String or key.length() > 180 or not _plain(value[key],depth+1):
				return false
		return true
	if value is Array:
		if value.size() > 10000:
			return false
		for item in value:
			if not _plain(item,depth+1):
				return false
		return true
	if value is String:
		return value.length() <= 4096
	if value is bool or value is int:
		return true
	return value is float and is_finite(value)

func _canonical_numbers(value: Variant) -> Variant:
	# JSON decodes every number as float; canonical game counters are integers.
	if value is float and absf(value) <= 9007199254740991.0 and value == floor(value):
		return int(value)
	if value is Array:
		var array: Array = []
		for item in value:
			array.append(_canonical_numbers(item))
		return array
	if value is Dictionary:
		var dictionary: Dictionary = {}
		for key in value:
			dictionary[key] = _canonical_numbers(value[key])
		return dictionary
	return value

func validate_snapshot(snapshot: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not _plain(snapshot) or snapshot.has("actors") or snapshot.has("combat") or snapshot.get("combat_active",false):
		return ["ข้อมูลเซฟไม่ใช่สถานะพักที่สมบูรณ์"]
	for key in ["player","quest_states","world_flags","first_clears","claimed_rewards","checkpoint"]:
		if not snapshot.get(key) is Dictionary:
			errors.append("ข้อมูลขาด: " + key)
	if not errors.is_empty():
		return errors
	var player: Dictionary = snapshot.player
	if _entry("classes",str(player.get("class_id", ""))).is_empty():
		errors.append("ไม่รู้จักอาชีพในเซฟ")
	for key in ["base_attributes","skill_ranks","equipment","potions"]:
		if not player.get(key) is Dictionary:
			errors.append("ข้อมูลตัวละครขาด: " + key)
	for key in ["items","stash"]:
		if not player.get(key) is Array:
			errors.append("กระเป๋าหรือคลังไม่ถูกต้อง")
	if not errors.is_empty():
		return errors
	for attribute in ["VIT","STR","INT","AGI"]:
		if not _whole(player.base_attributes.get(attribute),1,500):
			errors.append("ค่าสถานะตัวละครไม่ถูกต้อง")
	for key in ["level","xp","skill_points","attribute_points","currency","energy","current_hp","current_fp"]:
		var maximum: int = {"level":30,"xp":10000000,"skill_points":1000,"attribute_points":1000,"currency":1000000000,"energy":100,"current_hp":100000,"current_fp":100000}.get(key,0)
		if not _whole(player.get(key),1 if key in ["level","current_hp"] else 0,maximum):
			errors.append("ค่าตัวละครไม่ถูกต้อง: " + key)
	for potion in ["life","focus"]:
		if not _whole(player.potions.get(potion),0,99):
			errors.append("จำนวนยาไม่ถูกต้อง")
	if not errors.is_empty():
		return errors
	if player.items.size() > 24:
		errors.append("กระเป๋าเกิน24ช่อง")
	for id in player.items + player.stash:
		if not id is String or _entry("items",str(id)).is_empty():
			errors.append("ไม่รู้จักอุปกรณ์ในเซฟ")
	for slot in player.equipment:
		var item := _entry("items",str(player.equipment[slot]))
		if not slot in ["weapon","shield","head","suit"] or item.is_empty() or item.get("slot", "") != slot or int(item.get("required_level",99)) > int(player.get("level",0)):
			errors.append("อุปกรณ์ที่สวมไม่ตรงช่องหรือเลเวล")
	for id in player.skill_ranks:
		if _entry("skills",id).is_empty() or not _whole(player.skill_ranks[id],1,10):
			errors.append("ไม่รู้จักสกิลหรือระดับสกิลไม่ถูกต้อง")
	if not errors.is_empty():
		return errors
	for id in player.skill_ranks:
		var skill := _entry("skills",id)
		if int(skill.required_level) > int(player.level):
			errors.append("เลเวลไม่ถึงเงื่อนไขสกิล")
		for parent in skill.parents:
			if int(player.skill_ranks.get(parent,0)) < 1:
				errors.append("เงื่อนไขสกิลก่อนหน้าไม่ครบ")
	var profession := _entry("classes",str(player.get("class_id", "")))
	if not profession.is_empty() and player.skill_ranks.get(profession.starter_skill,0) < 1:
		errors.append("สกิลเริ่มอาชีพหาย")
	if _entry("rooms",str(snapshot.get("room_id", ""))).is_empty() or _entry("rooms",str(snapshot.checkpoint.get("room_id", ""))).is_empty() or not snapshot.checkpoint.get("spawn_id", "") in ["entry","left","right"]:
		errors.append("ห้องหรือจุดเกิดไม่ถูกต้อง")
	for id in snapshot.first_clears:
		if (_entry("encounters",id).is_empty() and not _entry("enemies",id).get("boss",false)) or not snapshot.first_clears[id] is bool or snapshot.first_clears[id] != true:
			errors.append("ไม่รู้จักความคืบหน้าการต่อสู้")
	for id in snapshot.claimed_rewards:
		if not snapshot.claimed_rewards[id] is bool or snapshot.claimed_rewards[id] != true:
			errors.append("ข้อมูลรับรางวัลไม่ถูกต้อง")
	var quest_ids: Array[String] = []
	var object_ids: Array[String] = []
	for quest in content.get("story",{}).get("quests",[]):
		quest_ids.append(quest.id)
		object_ids.append(quest.object_id)
		var progress = snapshot.quest_states.get(quest.id)
		if not progress is Dictionary or not progress.get("state", "") in ["available","active","objectives_complete","turned_in"] or not progress.get("choice", "") in ["","help","pragmatic"]:
			errors.append("สถานะภารกิจไม่ถูกต้อง")
		elif progress.has("pending_choice") and (quest.id != "Q04" or progress.pending_choice != "harvest" or progress.state != "objectives_complete"):
			errors.append("ตัวเลือกที่รอยืนยันไม่ถูกต้อง")
	if snapshot.quest_states.size() != quest_ids.size():
		errors.append("จำนวนภารกิจในเซฟไม่ครบ")
	for key in snapshot.world_flags:
		var value = snapshot.world_flags[key]
		if key.begins_with("training:"):
			var tier: String = key.trim_prefix("training:")
			if not TrainingService.OBJECTIVES.has(tier) or not value is Array:
				errors.append("สถานะการฝึกไม่ถูกต้อง")
			else:
				for objective in value:
					if not objective in TrainingService.OBJECTIVES[tier]:
						errors.append("เป้าหมายการฝึกไม่ถูกต้อง")
		elif key == "ending_choice":
			if not value in ["Shutdown","Seize","Cure"]:
				errors.append("ฉากจบไม่ถูกต้อง")
		elif key.begins_with("visited:"):
			if not value is bool or _entry("rooms",key.trim_prefix("visited:")).is_empty():
				errors.append("ห้องที่เคยเยือนไม่ถูกต้อง")
		elif key.begins_with("environment:"):
			if not value is bool or not WorldController.ENVIRONMENT.has(key.trim_prefix("environment:")):
				errors.append("วาล์วสิ่งแวดล้อมไม่ถูกต้อง")
		elif key.begins_with("objective:"):
			if not value is bool or not key.trim_prefix("objective:") in object_ids:
				errors.append("เป้าหมายโลกไม่ถูกต้อง")
		elif not value is bool:
			errors.append("ค่าธงเนื้อเรื่องไม่ถูกต้อง")
	if not snapshot.get("ending_history") is Array:
		errors.append("ประวัติฉากจบไม่ถูกต้อง")
	else:
		for ending in snapshot.ending_history:
			if not ending in ["Shutdown","Seize","Cure"]:
				errors.append("ประวัติฉากจบไม่ถูกต้อง")
	if not errors.is_empty():
		return errors
	var progression := Progression.new(content)
	var stats := progression.derive(player,content)
	if player.current_hp > stats.max_hp or player.current_fp > stats.max_fp or player.xp >= progression.xp_to_next(int(player.level)):
		errors.append("ทรัพยากรเกินค่าตัวละครที่คำนวณได้")
	return errors

func _path(slot_id: String, backup: bool = false) -> String:
	return directory.path_join(slot_id + ".json" + (".bak" if backup else ""))

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("ยังไม่มีไฟล์บันทึก")
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 2097152:
		return _failure("เปิดเซฟไม่ได้หรือไฟล์ใหญ่เกินไป")
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return _failure("ไฟล์เซฟอ่านไม่สมบูรณ์ เลือกกู้ไฟล์สำรองได้")
	var envelope: Dictionary = parser.data
	if envelope.get("version",0) != VERSION:
		return _failure("เซฟเป็นเวอร์ชันอื่น ไฟล์ปัจจุบันจะไม่ถูกแก้ไข")
	if not envelope.get("data") is Dictionary:
		return _failure("ข้อมูลเซฟขาดหาย")
	if not _plain(envelope.data):
		return _failure("โครงสร้างเซฟซับซ้อนหรือมีค่าที่ไม่รองรับ")
	var canonical: Dictionary = _canonical_numbers(envelope.data)
	var errors := validate_snapshot(canonical)
	if not errors.is_empty():
		return _failure("เซฟไม่ผ่านการตรวจ: " + errors[0])
	return {"ok":true,"reason":"","state":canonical,"events":[],"saved_at":envelope.get("saved_at",0)}

func _write_temp(path: String, text: String) -> bool:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		return false
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and _read(path).ok

func _rename(from: String, to: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(from),ProjectSettings.globalize_path(to))

func save_slot(slot_id: String, snapshot: Dictionary) -> Dictionary:
	if not slot_id in SLOTS:
		return _failure("ชื่อช่องบันทึกไม่ถูกต้อง")
	var errors := validate_snapshot(snapshot)
	if not errors.is_empty():
		return _failure("ยังบันทึกไม่ได้: " + errors[0])
	var path := _path(slot_id)
	if FileAccess.file_exists(path) and not _read(path).ok:
		return _failure("ไฟล์เดิมไม่ผ่านการตรวจ เลือกช่องใหม่หรือกู้สำรองก่อน ไฟล์เดิมยังอยู่")
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		return _failure("สร้างโฟลเดอร์บันทึกไม่ได้")
	var text := JSON.stringify({"version":VERSION,"saved_at":Time.get_unix_time_from_system(),"data":snapshot},"\t")
	var temp := path + ".tmp"
	if not _write_temp(temp,text):
		return _failure("เขียนไฟล์ชั่วคราวไม่ได้ เซฟเดิมยังอยู่")
	if FileAccess.file_exists(path):
		var backup_temp := _path(slot_id,true) + ".tmp"
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(backup_temp)) != OK or not _read(backup_temp).ok or _rename(backup_temp,_path(slot_id,true)) != OK:
			return _failure("สำรองไฟล์เดิมไม่ได้ เซฟเดิมยังอยู่")
	if _rename(temp,path) != OK:
		return _failure("แทนที่ไฟล์เซฟไม่ได้ ไฟล์เดิมและสำรองยังอยู่")
	return {"ok":true,"reason":"บันทึกแล้ว","state":snapshot.duplicate(true),"events":[]}

func load_slot(slot_id: String, use_backup: bool = false) -> Dictionary:
	if not slot_id in SLOTS:
		return _failure("ชื่อช่องบันทึกไม่ถูกต้อง")
	var result := _read(_path(slot_id,use_backup))
	result["backup_available"] = FileAccess.file_exists(_path(slot_id,true)) and _read(_path(slot_id,true)).ok
	return result

func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for id in SLOTS:
		var result := load_slot(id)
		slots.append({"id":id,"exists":FileAccess.file_exists(_path(id)),"valid":result.ok,"backup_available":result.backup_available,"reason":result.reason,"level":result.get("state",{}).get("player",{}).get("level",0),"room_id":result.get("state",{}).get("room_id","")})
	return slots

func restore_backup(slot_id: String) -> Dictionary:
	if not slot_id in SLOTS:
		return _failure("ชื่อช่องบันทึกไม่ถูกต้อง")
	var backup := _read(_path(slot_id,true))
	if not backup.ok:
		return backup
	var path := _path(slot_id)
	var temp := path + ".recover.tmp"
	if not _write_temp(temp,FileAccess.get_file_as_string(_path(slot_id,true))):
		return _failure("เตรียมไฟล์กู้คืนไม่ได้ ไฟล์เดิมยังอยู่")
	var archived := ""
	if FileAccess.file_exists(path):
		archived = path + ".rejected-" + str(Time.get_ticks_usec())
		if _rename(path,archived) != OK:
			return _failure("แยกเก็บไฟล์ปัจจุบันไม่ได้ จึงยังไม่กู้ทับ")
	if _rename(temp,path) != OK:
		if not archived.is_empty():
			_rename(archived,path)
		return _failure("กู้คืนไม่สำเร็จ ไฟล์สำรองยังอยู่")
	backup["reason"] = "กู้จากสำรองแล้ว ไฟล์ปัจจุบันเดิมถูกเก็บแยกไว้"
	return backup
