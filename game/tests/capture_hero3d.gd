extends SceneTree
# Real-renderer captures of the 3D hero in world and combat. Output dir: env CAPTURE_DIR.

var output: String

func _initialize() -> void:
	await process_frame
	create_timer(40).timeout.connect(func():printerr("FAIL: hero capture timed out");quit(1))
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: hero capture requires actual renderer")
		quit(1)
		return
	output = OS.get_environment("CAPTURE_DIR")
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,"user://test-hero3d-" + str(Time.get_ticks_usec()))
	root.add_child(scene)
	await process_frame
	scene.find_child("NewGame",true,false).pressed.emit()
	await process_frame
	scene.find_child("Class_C01",true,false).pressed.emit()
	await wait(0.4)
	await capture("world_idle")
	Input.action_press("move_right")
	await wait(0.45)
	await capture("world_walk")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await wait(0.3)
	await capture("world_walk_left")
	Input.action_release("move_left")
	scene._start_training("T01")
	await wait(0.5)
	await capture("combat_idle")
	scene.combat_view._dismiss_card()
	scene.find_child("Basic_Attack",true,false).pressed.emit()
	await wait(0.3)
	await capture("combat_attack_a")
	await wait(0.35)
	await capture("combat_attack_b")
	await wait(1.6)
	await capture("combat_after")
	print("hero captures done")
	quit(0)

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [output, label])
