extends SceneTree
func _initialize() -> void:
	await process_frame
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var directory := "user://test-overflow-ui-"+str(Time.get_ticks_usec())
	var scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,directory)
	root.add_child(scene)
	await process_frame
	await process_frame
	scene._new_game("C01")
	for _i in range(24): scene.session.state.player.items.append("W01")
	scene.session.state.quest_states.Q05.state = "objectives_complete"
	var result: Dictionary = scene._commit("dialogue_choice",{"node_id":"D05","choice_id":"help"})
	scene._show_dialogue("D05")
	await process_frame
	var passed: bool = result.ok and "W25" in scene.session.state.player.stash and "คลังโรงซ่อม" in scene.modal_notice.text
	if not passed: printerr("FAIL: quest reward overflow must name the stash in visible UI")
	scene.queue_free()
	await create_timer(.2).timeout
	for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	print("Overflow notice smoke: ",passed)
	quit(0 if passed else 1)
