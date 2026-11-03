extends RefCounted

func run(t) -> bool:
	if not FileAccess.file_exists("res://save/save_service.gd"):
		t.check(false,"SaveService must preserve a good save on failures and validate all canonical fields")
		return true
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var session := GameSession.new(catalog.data)
	session.new_game("C05")
	session.state.player.items = ["W02","H02"]
	session.state.player.stash = ["W26"]
	session.state.player.current_hp = 33
	session.state.player.current_fp = 12
	session.state.player.energy = 44
	session.state.world_flags["objective:water_valve"] = true
	session.state.quest_states.Q01.state = "active"
	session.state.claimed_rewards["battle:test"] = true
	var directory := "user://test-saves-" + str(Time.get_ticks_usec())
	var service = load("res://save/save_service.gd").new(catalog.data,directory)
	var original := session.snapshot()
	var result: Dictionary = service.save_slot("manual01",original)
	t.check(result.ok,"valid save writes slot")
	result = service.load_slot("manual01")
	t.check(result.ok and result.state == original,"all canonical fields roundtrip includingHP/FP/stash/flags/claims")
	var invalid := original.duplicate(true)
	invalid.player.skill_ranks["missing"] = 1
	t.check(not service.save_slot("manual01",invalid).ok and service.load_slot("manual01").state == original,"unknownskill rejected without overwriting good save")
	invalid = original.duplicate(true)
	invalid.player.equipment.weapon = "D01"
	t.check(not service.save_slot("manual01",invalid).ok,"wrong equipment slot is rejected")
	invalid = original.duplicate(true)
	invalid.player.level = []
	t.check(not service.save_slot("manual01",invalid).ok,"wrong numeric type rejected without a runtime exception")
	invalid = original.duplicate(true)
	invalid.player.skill_ranks.S20 = []
	invalid.player.skill_ranks.S21 = 1
	t.check(not service.save_slot("manual01",invalid).ok,"malformed parent rank rejected before dependency comparisons")
	invalid = original.duplicate(true)
	invalid.player.energy = -1
	t.check(not service.save_slot("manual01",invalid).ok,"negative energy rejected at save boundary")
	t.check(not service.save_slot("../escape",original).ok,"slot path traversal rejected")
	var changed := original.duplicate(true)
	changed.player.currency = 400
	result = service.save_slot("manual01",changed)
	t.check(result.ok and service.load_slot("manual01",true).state == original,"backup retains previous known-good state")
	var path: String = directory.path_join("manual01.json")
	var temp: String = path + ".tmp"
	DirAccess.make_dir_absolute(temp)
	var failure: Dictionary = service.save_slot("manual01",original)
	t.check(not failure.ok and service.load_slot("manual01").state == changed,"blocked temporary write preserves current good save")
	DirAccess.remove_absolute(temp)
	var future: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	future.version = 99
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(future))
	file.close()
	t.check(not service.load_slot("manual01").ok,"future version does not silently mutate into current schema")
	t.check(not service.save_slot("manual01",original).ok and JSON.parse_string(FileAccess.get_file_as_string(path)).version == 99,"future version file cannot be silently overwritten")
	result = service.load_slot("manual01",true)
	t.check(result.ok and result.state == original,"explicit backup load works without editing future file")
	result = service.restore_backup("manual01")
	t.check(result.ok and service.load_slot("manual01").state == original,"explicit recovery restores backup while preserving rejected original")
	var preserved := false
	for filename in DirAccess.get_files_at(directory):
		if ".rejected-" in filename:
			preserved = true
	t.check(preserved,"recovery archives current file rather than destroying it")
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	_migration(t,catalog.data)
	return true

func _put(path: String, text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _migration(t, data: Dictionary) -> void:
	var directory := "user://test-saves-v1-" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	var service = load("res://save/save_service.gd").new(data,directory)
	var fixture := FileAccess.get_file_as_string("res://tests/fixtures/save_v1.json")
	var path: String = directory.path_join("manual01.json")
	_put(path,fixture)
	var result: Dictionary = service.load_slot("manual01")
	t.check(service.VERSION == 2 and result.ok and result.state.player.upgrades == {},"v1 fixture loads and migrates to v2 with empty upgrades")
	t.check(result.ok and result.state.player.stash == ["W26"] and result.state.player.current_hp == 33,"migration keeps existing player fields")
	# Re-save writes v2, the v1 file becomes the backup, and both still load.
	t.check(service.save_slot("manual01",result.state).ok and JSON.parse_string(FileAccess.get_file_as_string(path)).version == 2,"re-save writes version 2")
	t.check(service.load_slot("manual01").ok and service.load_slot("manual01",true).ok and JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("manual01.json.bak"))).version == 1,"v2 file and v1 backup both load")
	# Unknown ids are dropped, not fatal; equipment hp/fp clamp afterwards.
	var stale: Dictionary = JSON.parse_string(fixture)
	stale.data.player.items.append("GONE01")
	stale.data.player.stash.append("GONE02")
	stale.data.player.equipment.head = "GONE03"
	stale.data.player.upgrades = {"GONE01":2,"W02":1}
	_put(path,JSON.stringify(stale))
	result = service.load_slot("manual01")
	t.check(result.ok and not "GONE01" in result.state.player.items and not "GONE02" in result.state.player.stash and not result.state.player.equipment.has("head"),"migration drops items no longer in the catalog")
	t.check(result.ok and result.state.player.upgrades == {"W02":1},"migration prunes upgrades for missing or unowned items")
	# v1 .bak restore.
	DirAccess.remove_absolute(path)
	_put(directory.path_join("manual01.json.bak"),fixture)
	_put(path,"{ broken")
	t.check(not service.load_slot("manual01").ok,"corrupt file still rejected")
	result = service.restore_backup("manual01")
	t.check(result.ok and result.state.player.upgrades == {} and service.load_slot("manual01").ok,"v1 backup restore works")
	var future: Dictionary = JSON.parse_string(fixture)
	future.version = 3
	_put(path,JSON.stringify(future))
	result = service.load_slot("manual01")
	t.check(not result.ok and "ใหม่กว่า" in result.reason,"v3 rejected with newer-version reason")
	future.version = 0
	_put(path,JSON.stringify(future))
	t.check(not service.load_slot("manual01").ok,"version 0 rejected")
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)

