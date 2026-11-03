extends SceneTree
# Two-foe fights: plates stay on screen and apart; Tab and clicks pick living targets only.

var failed: int = 0

func check(value: bool, label: String) -> void:
	if not value:
		failed += 1
		printerr("FAIL: " + label)

func key(code: int, shift: bool = false) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.shift_pressed = shift
	press.pressed = true
	Input.parse_input_event(press)

func _initialize() -> void:
	await process_frame
	create_timer(90).timeout.connect(func():printerr("FAIL: targets smoke timed out");quit(1))
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,"user://test-targets-" + str(Time.get_ticks_usec()))
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
		var view: CombatView = scene.combat_view
		while not scene.combat.is_player_turn(): await process_frame
		await create_timer(0.3).timeout
		view._dismiss_card()
		await process_frame
		await process_frame
		var rects: Array[Rect2] = []
		for plate in view.plates.get_children():
			if plate is PanelContainer: rects.append(plate.get_global_rect())
		check(rects.size() == 3,id + ": hero plus two foe plates")
		for i in rects.size():
			check(Rect2(0,0,1280,720).encloses(rects[i]),id + ": plate %d inside the viewport %s" % [i,rects[i]])
			for j in range(i+1,rects.size()): check(not rects[i].intersects(rects[j]),id + ": plates %d and %d do not overlap" % [i,j])
		var ids: Array = view.living_enemies().map(func(a): return a.id)
		check(view.selected_target == ids[0],id + ": first foe is the default target")
		key(KEY_TAB)
		await process_frame
		check(view.selected_target == ids[1],id + ": Tab moves to the next living foe")
		key(KEY_TAB)
		await process_frame
		check(view.selected_target == ids[0],id + ": Tab wraps")
		key(KEY_TAB,true)
		await process_frame
		check(view.selected_target == ids[1],id + ": Shift+Tab goes back")
		view._pick_target(ids[0])
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		var plate: Control = view.plates.find_child("Plate_" + ids[1],true,false)
		click.position = plate.size*0.5
		plate.gui_input.emit(click)
		await process_frame
		check(view.selected_target == ids[1],id + ": clicking the second plate targets it")
		check(view.find_child("Target_next",true,false) != null,id + ": step buttons shown with two foes")
		# Kill the targeted foe: it can no longer be picked, controls vanish, plate dims and goes last.
		scene.combat._actor(ids[1]).hp = 0
		view._render()
		await process_frame
		view._plates()
		await process_frame
		check(view.selected_target == ids[0],id + ": a dead foe is dropped as target")
		view._pick_target(ids[1])
		view.cycle_target(1)
		check(view.selected_target == ids[0],id + ": a dead foe cannot be targeted")
		check(view.find_child("Target_next",true,false) == null,id + ": no step buttons with one foe left")
		var dead: Control = view.plates.find_child("Plate_" + ids[1],true,false)
		var live: Control = view.plates.find_child("Plate_" + ids[0],true,false)
		check(dead.modulate.a < 1.0 and dead.position.x > live.position.x,id + ": dead plate dims and sits last")
		check(Rect2(0,0,1280,720).encloses(dead.get_global_rect()) and not dead.get_global_rect().intersects(live.get_global_rect()),id + ": dead and live plates still apart")
		view.paused = true
	print("targets smoke done: %d failed" % failed)
	quit(1 if failed > 0 else 0)
