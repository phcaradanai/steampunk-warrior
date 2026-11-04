extends SceneTree

var passed: int = 0
var failed: int = 0
func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: " + label)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _initialize() -> void:
	await process_frame
	create_timer(25).timeout.connect(func():printerr("FAIL: controls smoke timed out");quit(1))
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var directory := "user://test-controls-" + str(Time.get_ticks_usec())
	var scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,directory)
	root.add_child(scene)
	await process_frame
	var open = scene.find_child("OpenSettings",true,false)
	check(open != null,"settings available from title")
	if open == null:
		quit(1)
		return
	open.grab_focus()
	open.pressed.emit()
	await process_frame
	var contained := true
	for _step in range(30):
		key(KEY_TAB,true)
		await process_frame
		key(KEY_TAB,false)
		var focused := root.gui_get_focus_owner()
		if focused != null and not scene.modal.is_ancestor_of(focused): contained = false
	check(contained,"Tab focus remains within the active modal")
	scene.find_child("Rebind_move_right",true,false).pressed.emit()
	key(KEY_L,true)
	await process_frame
	key(KEY_L,false)
	await process_frame
	check(scene.settings.bindings.move_right == [KEY_L],"capture next physical key updates live binding")
	check(scene.find_children("ModalShade","",true,false).size() == 1,"rebinding refresh never stacks modals")
	key(KEY_ESCAPE,true)
	await process_frame
	key(KEY_ESCAPE,false)
	await process_frame
	check(not is_instance_valid(scene.modal),"Esc closes one modal")
	check(root.gui_get_focus_owner() == open,"modal closes back to invoking control focus")
	var persisted := InputSettings.new(directory.path_join("settings.cfg"))
	check(persisted.load_settings().ok and persisted.bindings.move_right == [KEY_L],"closing settings persists real remap")
	scene.find_child("NewGame",true,false).pressed.emit()
	await process_frame
	check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().name == "Class_C01","class menu starts with keyboard focus")
	key(KEY_ENTER,true)
	await process_frame
	key(KEY_ENTER,false)
	await process_frame
	check(scene.screen_mode == "world","keyboard Enter confirms focused class")
	scene.find_child("StorySkip",true,false).pressed.emit()
	await process_frame
	for chapter in scene.catalog.data.story.chapters: scene.session.state.world_flags["story:open:" + chapter.id] = true # chapter pages are covered by smoke_story
	check("L" in scene.control_hint.text,"world hints follow the rebound movement key")
	if scene.screen_mode != "world":
		quit(1)
		return
	scene.find_child("OpenInventory",true,false).pressed.emit()
	await process_frame
	check(scene.world.blocked,"inventory modal blocks world input")
	var before: Vector2 = scene.world.player.position
	Input.action_press("move_right")
	for _i in range(15):
		await physics_frame
	Input.action_release("move_right")
	check(scene.world.player.position.distance_to(before) < 0.1,"held movement cannot move body through modal")
	scene.find_child("CloseModal",true,false).pressed.emit()
	await process_frame
	check(not scene.world.blocked,"closing modal restores world movement")
	for marker in scene.world.markers:
		if marker.kind == "training":
			scene.world.player.position = marker.position - Vector2(40,0)
	await physics_frame
	await process_frame
	scene.find_child("Interact",true,false).pressed.emit()
	await process_frame
	scene.find_child("Training_T01",true,false).pressed.emit()
	await process_frame
	await create_timer(1.0).timeout
	scene.find_child("Basic_Attack",true,false).pressed.emit()
	key(KEY_ESCAPE,true)
	await process_frame
	key(KEY_ESCAPE,false)
	var paused_state: Dictionary = scene.combat.state.duplicate(true)
	await create_timer(0.7).timeout
	check(scene.combat.state == paused_state,"combat pause freezes pending AI while modal is open")
	key(KEY_ESCAPE,true)
	await process_frame
	key(KEY_ESCAPE,false)
	for _step in range(30):
		await create_timer(0.05).timeout
		if scene.combat.is_player_turn():
			break
	# Retry: a press during hit feedback is ignored by the combat view.
	for _step in range(80):
		scene.find_child("Basic_Retreat",true,false).pressed.emit()
		await create_timer(0.05).timeout
		if scene.screen_mode == "world":
			break
	check(scene.screen_mode == "world" and scene.session.state.player.xp == 14 and scene.session.state.player.energy == 100,"retreating from practice settles partialXP without energy loss")
	scene._close_modal(true)
	await process_frame
	# Pause menu: back to title from the world autosaves; from combat it commits nothing.
	key(KEY_ESCAPE,true)
	await process_frame
	key(KEY_ESCAPE,false)
	await process_frame
	check(scene.find_child("PauseTitle",true,false) != null and scene.find_child("PauseQuit",true,false) != null,"world pause offers back-to-title and quit")
	scene.find_child("PauseTitle",true,false).pressed.emit()
	await process_frame
	check(scene.find_child("ConfirmLeave",true,false) != null,"leaving asks for confirmation")
	key(KEY_ESCAPE,true)
	await process_frame
	key(KEY_ESCAPE,false)
	await process_frame
	await process_frame
	check(scene.find_child("PauseTitle",true,false) != null and scene.screen_mode == "world","closing the confirm returns to the pause menu")
	scene.session.state.player.xp += 3
	scene.find_child("PauseTitle",true,false).pressed.emit()
	await process_frame
	scene.find_child("ConfirmLeave",true,false).pressed.emit()
	await process_frame
	var autosaved: Dictionary = scene.saves.load_slot("autosave")
	check(scene.screen_mode == "title" and autosaved.ok and autosaved.state.player.xp == scene.session.state.player.xp and autosaved.state.room_id == scene.session.state.room_id,"back to title autosaves the current state")
	scene.find_child("Continue",true,false).pressed.emit()
	await process_frame
	scene.session.state.room_id = "R03"
	scene._start_encounter("E01")
	await process_frame
	check(scene.screen_mode == "combat","encounter opens combat")
	var commits_before: int = scene.session.recent_commits.size()
	var before_state: Dictionary = scene.session.snapshot()
	key(KEY_ESCAPE,true)
	await process_frame
	key(KEY_ESCAPE,false)
	await process_frame
	check(scene.find_child("PauseTitle",true,false) != null and scene.find_child("PauseQuit",true,false) != null and scene.find_child("OpenSave",true,false) == null,"combat pause offers back-to-title and quit")
	scene.find_child("PauseTitle",true,false).pressed.emit()
	await process_frame
	scene.find_child("ConfirmLeave",true,false).pressed.emit()
	await process_frame
	check(scene.screen_mode == "title","combat back-to-title reaches the title")
	check(scene.session.recent_commits.size() == commits_before and scene.session.snapshot() == before_state,"leaving combat commits no battle result")
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	scene.queue_free()
	await create_timer(.2).timeout
	print("Controls smoke: %d passed, %d failed" % [passed,failed])
	quit(1 if failed > 0 else 0)
