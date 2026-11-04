extends SceneTree
# Real-renderer fight capture of every late encounter that fields the R09-R12 foes. Output dir: env CAPTURE_DIR (P2 target UI).

func _initialize() -> void:
	await process_frame
	create_timer(120).timeout.connect(func():printerr("FAIL: late foe capture timed out");quit(1))
	var output := OS.get_environment("CAPTURE_DIR")
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,"user://test-latefoes-" + str(Time.get_ticks_usec()))
	root.add_child(scene)
	await process_frame
	scene._new_game("C01")
	scene.session.state.player.level = 30
	for id in ["E24","E35","E20"]:
		var encounter := catalog.get_entry("encounters",id)
		scene.session.state.room_id = encounter.room
		scene.session.state.first_clears[encounter.requires] = true
		scene._show_world()
		scene._start_encounter(id)
		await create_timer(0.4).timeout
		scene.combat_view._dismiss_card()
		scene.find_child("Basic_Guard",true,false).pressed.emit()
		for i in 40:
			await create_timer(0.05).timeout
			if scene.combat_view.feedback.playing > 0 and i > 8: break
		await create_timer(0.18).timeout
		await RenderingServer.frame_post_draw
		Captures.frame(root).save_png("%s/fight_%s.png" % [output, id])
		scene.combat_view.paused = true
	print("late foe captures done")
	quit(0)
