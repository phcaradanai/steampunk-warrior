extends SceneTree

var passed: int = 0
var failed: int = 0

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	await process_frame
	create_timer(25.0).timeout.connect(func():
		printerr("FAIL: playable smoke exceeded25seconds")
		quit(1))
	var scene = load("res://main.tscn").instantiate()
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var save_directory := "user://test-playable-" + str(Time.get_ticks_usec())
	scene.saves = SaveService.new(catalog.data,save_directory)
	root.add_child(scene)
	await process_frame
	var start = scene.find_child("NewGame", true, false)
	check(start != null, "title exposes playable New Game button")
	if start == null:
		scene.queue_free()
		await create_timer(.2).timeout
		print("Playable smoke: %d passed, %d failed" % [passed,failed])
		quit(1)
		return
	start.pressed.emit()
	await process_frame
	var profession = scene.find_child("Class_C01", true, false)
	check(profession != null,"class selection exposes actual class button")
	if profession == null:
		quit(1)
		return
	profession.pressed.emit()
	await process_frame
	await capture("world")
	check(scene.screen_mode == "world" and scene.session.state.room_id == "R01","selected character enters actual world")
	var position_before: Vector2 = scene.world.player.position
	Input.action_press("move_right")
	for _i in range(20):
		await physics_frame
	Input.action_release("move_right")
	check(scene.world.player.position.x > position_before.x + 40,"CharacterBody moves with actual InputMap in physics frames")
	for room_id in ["R02","R03"]:
		for marker in scene.world.markers:
			if marker.kind == "exit" and marker.id == room_id:
				scene.world.player.position = marker.position - Vector2(40,0)
		await physics_frame
		await process_frame
		var interact = scene.find_child("Interact",true,false)
		check(interact != null and not interact.disabled,"nearby exit enables real interaction control")
		interact.pressed.emit()
		await process_frame
		check(scene.session.state.room_id == room_id,"actual exit travels to " + room_id)
	for marker in scene.world.markers:
		if marker.kind == "encounter" and marker.id == "E01":
			scene.world.player.position = marker.position - Vector2(40,0)
	await physics_frame
	await process_frame
	scene.find_child("Interact",true,false).pressed.emit()
	await process_frame
	var confirm = scene.find_child("ConfirmEncounter",true,false)
	check(confirm != null,"encounter requires explicit confirmation")
	if confirm == null:
		quit(1)
		return
	confirm.pressed.emit()
	await capture("combat")
	for _step in range(160):
		await create_timer(0.05).timeout
		if scene.screen_mode == "world":
			break
		var attack = scene.find_child("Basic_Attack",true,false)
		if attack != null and not attack.disabled:
			attack.pressed.emit()
	check(scene.session.state.first_clears.has("E01"),"fight through real buttons commits first clear and returns to world")
	for filename in DirAccess.get_files_at(save_directory):
		DirAccess.remove_absolute(save_directory.path_join(filename))
	DirAccess.remove_absolute(save_directory)
	scene.queue_free()
	await create_timer(.2).timeout
	print("Playable smoke: %d passed, %d failed" % [passed,failed])
	quit(1 if failed > 0 else 0)


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var folder := ProjectSettings.globalize_path("res://../docs/development/screenshots")
	DirAccess.make_dir_recursive_absolute(folder)
	check(image.save_png(folder.path_join(label+".png")) == OK,"capture actual rendered " + label)
