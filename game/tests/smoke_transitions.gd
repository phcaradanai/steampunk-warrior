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
	await process_frame
	check(scene.session.state.room_id == destination and scene.world.room.id == destination,"input changes actual scene: "+destination)
	check(scene.saves.load_slot("autosave").get("state",{}).get("room_id","") == destination,"transition autosave matches: "+destination)

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
	await process_frame
	scene.world.player.position = Vector2(865,240)
	await physics_frame
	await process_frame
	check(not root.is_input_handled(),"fresh frame has no consumed input")
	var old_world: WorldView = scene.world
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	old_world._unhandled_input(interact)
	check(root.is_input_handled(),"interact is consumed even when its signal replaces the caller scene")
	check(scene.session.state.room_id == "R02" and not old_world.is_inside_tree(),"transition removes old scene synchronously")
	await process_frame
	await travel("R03",KEY_SPACE)
	await travel("R02",KEY_E)
	await travel("R01",0)
	# Gate fixture isolates traversal; earned boss progression is checked separately.
	for boss in ["B01","B02","B03","B04","B05"]: scene.session.state.first_clears[boss] = true
	for index in range(2,13): await travel("R%02d" % index,KEY_E if index%2 == 0 else KEY_SPACE)
	for index in range(11,0,-1): await travel("R%02d" % index,KEY_SPACE if index%2 == 0 else KEY_E)
	scene.queue_free()
	await create_timer(.2).timeout
	for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	print("Transition smoke: %d passed,%d failed" % [passed,failed])
	quit(1 if failed else 0)
