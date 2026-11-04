extends SceneTree
# Real-renderer capture: hero behind and in front of the first prop in three rooms. Output dir: env CAPTURE_DIR.

func _initialize() -> void:
	await process_frame
	create_timer(90).timeout.connect(func():printerr("FAIL: occlusion capture timed out");quit(1))
	var output := OS.get_environment("CAPTURE_DIR")
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,"user://test-occlusion-" + str(Time.get_ticks_usec()))
	root.add_child(scene)
	await process_frame
	scene._new_game("C01")
	await create_timer(0.3).timeout
	for id in ["R03","R07","R10"]:
		scene.session.state.room_id = id
		scene._show_world()
		await create_timer(0.3).timeout
		while is_instance_valid(scene.story_screen):
			var card = scene.story_screen
			card.finished.emit()
			card.queue_free()
			await process_frame
		var rect: Array = RoomLayout.oblique().rooms[id].props[0].rect
		for spot in {"behind":rect[1]-12.0,"front":rect[1]+rect[3]+12.0}.keys():
			var feet: float = rect[1]-12.0 if spot == "behind" else rect[1]+rect[3]+12.0
			scene.world.player.position = Vector2(rect[0]+rect[2]*0.5,feet)
			await create_timer(0.25).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%s_%s.png" % [output,id,spot])
	print("occlusion captures done")
	quit(0)
