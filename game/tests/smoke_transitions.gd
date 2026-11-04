extends SceneTree

var passed: int = 0
var failed: int = 0
var scene

func check(value: bool, label: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		printerr("FAIL: "+label)

func key(code: int, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func travel(destination: String, code: int = KEY_E) -> void:
	for marker in scene.world.markers:
		if marker.kind in ["exit","fast_travel"] and marker.id == destination:
			scene.world.player.position = marker.position+Vector2(-35 if marker.position.x > 480 else 35,0)
			break
	await physics_frame
	await process_frame
	root.gui_release_focus()
	check(scene.world.nearby.get("id","") == destination,"destination marker selected: "+destination)
	if code == 0:
		scene.find_child("Interact",true,false).pressed.emit()
	else:
		key(code,true)
	await process_frame
	if code != 0: key(code,false)
	# Exits are pipe mouths: the hero walks in and vanishes before the scene changes.
	for _i in range(120):
		if scene.session.state.room_id == destination and scene.world != null and scene.world.room.id == destination: break
		await process_frame
	check(scene.session.state.room_id == destination and scene.world.room.id == destination,"input changes actual scene: "+destination)
	check(scene.saves.load_slot("autosave").get("state",{}).get("room_id","") == destination,"transition autosave matches: "+destination)

# Right-hand hub mouth: keyboard opens the chooser, focus lands on an open line, Enter starts its fight.
func junction() -> void:
	for id in ["E01","E02","E03"]: scene.session.state.first_clears[id] = true
	scene.world.refresh(scene.session.snapshot())
	for marker in scene.world.markers:
		if marker.kind == "junction": scene.world.player.position = marker.position+Vector2(-35,0)
	await physics_frame
	await process_frame
	check(scene.world.nearby.get("kind","") == "junction","junction mouth is the nearest marker")
	key(KEY_E,true)
	await process_frame
	key(KEY_E,false)
	for _i in range(10): await process_frame
	check(is_instance_valid(scene.modal) and scene.modal.find_child("Line_P05",true,false) != null,"junction chooser lists every later line")
	var focused := root.gui_get_focus_owner()
	check(focused != null and focused.name == "Line_P02","keyboard focus starts on the first open line")
	key(KEY_RIGHT,true)
	await process_frame
	key(KEY_RIGHT,false)
	await process_frame
	var locked := root.gui_get_focus_owner()
	check(locked != null and locked.name == "Line_P03","arrow keys move between line tiles")
	key(KEY_ENTER,true)
	await process_frame
	key(KEY_ENTER,false)
	await process_frame
	check(scene.screen_mode == "world" and scene.combat == null,"a closed line does not start a fight")
	key(KEY_LEFT,true)
	await process_frame
	key(KEY_LEFT,false)
	await process_frame
	key(KEY_ENTER,true)
	await process_frame
	key(KEY_ENTER,false)
	for _i in range(200):
		if scene.combat != null: break
		await process_frame
	check(scene.combat != null and scene.combat.pipe_id == "P02","Enter on an open line enters the pipe and starts its fight")

func _initialize() -> void:
	await process_frame
	create_timer(30).timeout.connect(func():printerr("FAIL: transition smoke timed out");quit(1))
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var directory := "user://test-transition-"+str(Time.get_ticks_usec())
	scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,directory)
	root.add_child(scene)
	await process_frame
	await process_frame
	scene._new_game("C01")
	for chapter in scene.catalog.data.story.chapters: scene.session.state.world_flags["story:open:" + chapter.id] = true # chapter pages are covered by smoke_story
	await process_frame
	for marker in scene.world.markers:
		if marker.id == "R02": scene.world.player.position = marker.position+Vector2(35,0)
	await physics_frame
	await process_frame
	check(not root.is_input_handled(),"fresh frame has no consumed input")
	var old_world: WorldView = scene.world
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	old_world._unhandled_input(interact)
	check(root.is_input_handled(),"interact is consumed even when its signal replaces the caller scene")
	for _i in range(120):
		if not is_instance_valid(old_world) or not old_world.is_inside_tree(): break
		await process_frame
	check(scene.session.state.room_id == "R02" and (not is_instance_valid(old_world) or not old_world.is_inside_tree()),"pipe entry replaces the old scene once the hero is inside")
	await process_frame
	await travel("R03",KEY_SPACE)
	await travel("R02",KEY_E)
	await travel("R01",0)
	# Gate fixture isolates traversal; earned boss progression is checked separately.
	for boss in ["B01","B02","B03","B04","B05"]: scene.session.state.first_clears[boss] = true
	for index in range(2,13): await travel("R%02d" % index,KEY_E if index%2 == 0 else KEY_SPACE)
	for index in range(11,0,-1): await travel("R%02d" % index,KEY_SPACE if index%2 == 0 else KEY_E)
	await junction()
	scene.queue_free()
	await create_timer(.2).timeout
	for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	print("Transition smoke: %d passed,%d failed" % [passed,failed])
	quit(1 if failed else 0)
