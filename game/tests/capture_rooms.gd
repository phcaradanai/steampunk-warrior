extends SceneTree
# Real-renderer capture of every room plus one fight per arena theme. Output dir: env CAPTURE_DIR.

func _initialize() -> void:
	await process_frame
	create_timer(120).timeout.connect(func():printerr("FAIL: room capture timed out");quit(1))
	var output := OS.get_environment("CAPTURE_DIR")
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,"user://test-rooms-" + str(Time.get_ticks_usec()))
	root.add_child(scene)
	await process_frame
	scene._new_game("C01")
	scene.session.state.player.level = 30
	for room in catalog.data.rooms:
		scene.session.state.room_id = room.id
		scene._show_world()
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/room_%s.png" % [output, room.id])
	# One enemy turn per theme so the enemy dash is visible too.
	for id in ["E10","E14","E22","E26","E29","E33"]:
		var encounter := catalog.get_entry("encounters",id)
		scene.session.state.room_id = encounter.room
		scene.session.state.first_clears[encounter.requires] = true
		scene._show_world()
		scene._start_encounter(id)
		await create_timer(0.4).timeout
		scene.find_child("Basic_Guard",true,false).pressed.emit()
		for i in 40:
			await create_timer(0.05).timeout
			if scene.combat_view.feedback.playing > 0 and i > 8: break
		await create_timer(0.18).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/fight_%s.png" % [output, id])
		scene.combat_view.paused = true
	print("room captures done")
	quit(0)
