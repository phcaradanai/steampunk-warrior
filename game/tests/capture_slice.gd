extends SceneTree
# Real-renderer captures of the hub -> pipe -> combat -> loot loop. Output dir: env CAPTURE_DIR.

var output: String
var scene

func _initialize() -> void:
	await process_frame
	create_timer(90).timeout.connect(func():printerr("FAIL: slice capture timed out");quit(1))
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: slice capture requires actual renderer")
		quit(1)
		return
	output = OS.get_environment("CAPTURE_DIR")
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,"user://test-slice-" + str(Time.get_ticks_usec()))
	root.add_child(scene)
	await process_frame
	# Optional window size, e.g. CAPTURE_SIZE=1920x1080, to check sharpness at large physical sizes.
	if not OS.get_environment("CAPTURE_SIZE").is_empty(): scene.settings.set_option("window_size",OS.get_environment("CAPTURE_SIZE"))
	await process_frame
	scene._new_game("C01")
	await wait(0.4)
	await capture("hub")
	for marker in scene.world.markers:
		if marker.id == "P01": scene.world.player.position = marker.position + Vector2(60,70)
	await wait(0.2)
	scene.world.activate_nearest()
	await capture("hub_far")
	for marker in scene.world.markers:
		if marker.id == "P01": scene.world.player.position = marker.position + Vector2(30,20)
	await physics_frame
	await process_frame
	scene.world.activate_nearest()
	await wait(0.3)
	await capture("pipe_enter_a")
	await wait(0.35)
	await capture("pipe_enter_b")
	await wait(0.5)
	await capture("combat_title")
	var shots := 0
	for _step in range(400):
		await wait(0.05)
		if scene.screen_mode == "world": break
		var attack = scene.find_child("Basic_Attack",true,false)
		if attack != null and not attack.disabled:
			attack.pressed.emit()
			if shots < 1:
				await wait(0.16)
				await capture("combat_dash")
				await wait(0.2)
				await capture("combat_contact")
				shots += 1
		if scene.combat_view != null and scene.combat_view.settled and shots < 2:
			await wait(0.5)
			await capture("combat_loot")
			shots = 2
	await wait(0.3)
	await capture("victory_modal")
	print("slice captures done")
	quit(0)

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [output, label])
