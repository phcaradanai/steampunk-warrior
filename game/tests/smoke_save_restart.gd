extends SceneTree

var failed: int = 0
func check(condition: bool, label: String) -> void:
	if not condition:
		failed += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	await process_frame
	create_timer(20).timeout.connect(func():printerr("FAIL: save restart smoke timed out");quit(1))
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var directory := "user://test-ui-restart-owned"
	var scene = load("res://main.tscn").instantiate()
	var injectable: bool = scene.get_property_list().any(func(p):return p.name == "saves")
	check(injectable,"main scene owns injectable save service")
	if not injectable:
		scene.free()
		quit(1)
		return
	scene.saves = SaveService.new(catalog.data,directory)
	root.add_child(scene)
	await process_frame
	var read_mode: bool = "read" in OS.get_cmdline_user_args()
	if not read_mode:
		scene.find_child("NewGame",true,false).pressed.emit()
		await process_frame
		scene.find_child("Class_C05",true,false).pressed.emit()
		await process_frame
		scene.session.state.player.current_hp = 33
		scene.session.state.player.current_fp = 12
		scene.session.state.player.energy = 44
		scene.session.state.player.stash = ["W26"]
		scene.session.state.quest_states.Q01.state = "active"
		scene.find_child("OpenSave",true,false).pressed.emit()
		await process_frame
		scene.find_child("Save_manual01",true,false).pressed.emit()
		check(scene.saves.load_slot("manual01").ok,"actual save button wrote valid manual slot")
	else:
		scene.find_child("LoadGame",true,false).pressed.emit()
		await process_frame
		scene.find_child("Load_manual01",true,false).pressed.emit()
		await process_frame
		var player: Dictionary = scene.session.state.get("player",{})
		check(scene.screen_mode == "world","fresh process reconstructs actual world after load")
		check(player.get("class_id","") == "C05" and player.get("current_hp",0) == 33 and player.get("current_fp",0) == 12 and player.get("energy",0) == 44,"resources and class survived full quit/relaunch")
		check(player.get("stash",[]) == ["W26"] and scene.session.state.quest_states.Q01.state == "active","stash and active quest survived full quit/relaunch")
		for filename in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(filename))
		DirAccess.remove_absolute(directory)
	scene.queue_free()
	await create_timer(.2).timeout
	print("Save restart ","read" if read_mode else "write",": ",failed," failed")
	quit(1 if failed > 0 else 0)
