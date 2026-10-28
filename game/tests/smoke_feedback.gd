extends SceneTree

var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: "+label)

func _initialize() -> void:
	await process_frame
	create_timer(10).timeout.connect(func():printerr("FAIL: feedback smoke timed out");quit(1))
	if not FileAccess.file_exists("res://combat/combat_feedback.gd"):
		check(false,"combat events must animate without applying damage again")
		quit(1)
		return
	var scene = load("res://main.tscn").instantiate()
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var directory := "user://test-feedback-"+str(Time.get_ticks_usec())
	scene.saves = SaveService.new(catalog.data,directory)
	root.add_child(scene)
	await process_frame
	await process_frame
	scene._new_game("C01")
	scene.session.state.room_id = "R03"
	scene._show_world()
	scene._start_encounter("E01")
	await process_frame
	var view: CombatView = scene.combat_view
	view.paused = true
	var before: Dictionary = scene.combat.state.duplicate(true)
	var events: Array = [{"id":"visual-only","type":"damage","payload":{"target_id":"hero","amount":12,"type":"physical","shielded":false}}]
	view._render(events)
	await process_frame
	await process_frame
	var numbers: Array = view.feedback.get_children().filter(func(n):return n is Label)
	var anchor: Vector2 = view.portraits.hero.global_position+view.portraits.hero.size*.5
	check(not numbers.is_empty() and numbers[0].global_position.distance_to(anchor) < 110,"damage number follows the laid-out target portrait")
	view.feedback.play_events(events,view.portraits,{"reduced_shake":true,"reduced_flash":true})
	check(view.feedback.shake_enabled == false and view.feedback.flash_enabled == false,"reduced effects suppress shake and flash")
	await create_timer(.4).timeout
	check(scene.combat.state == before,"feedback cannot change HP,FP,turns or rewards")
	check(view.portraits.hero.motion_offset.length() < .01,"hit recoil returns to its resting position")
	check(view.feedback.bursts.is_empty(),"impact effects expire instead of accumulating")
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	scene.queue_free()
	await process_frame
	await process_frame
	print("Feedback smoke: ",failures," failures")
	quit(1 if failures > 0 else 0)
