extends SceneTree
# Victory settlement order: spoils count into totals, level-up gains, a forced attribute choice, then the skill board.

var failed: int = 0
var output: String = OS.get_environment("CAPTURE_DIR")

func check(value: bool, label: String) -> void:
	if not value:
		failed += 1
		printerr("FAIL: " + label)

func shot(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	Captures.frame(root).save_png("%s/%s.png" % [output, name])

func _initialize() -> void:
	await process_frame
	create_timer(40).timeout.connect(func():printerr("FAIL: settlement smoke timed out");quit(1))
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,"user://test-settle-"+str(Time.get_ticks_usec()))
	root.add_child(scene)
	await process_frame
	scene._new_game("C01")
	scene.session.state.player.xp = 39
	var gold_before: int = scene.session.state.player.currency
	for marker in scene.world.markers:
		if marker.id == "P01": scene.world.player.position = marker.position + Vector2(20,20)
	await physics_frame
	await process_frame
	scene._start_encounter("E01","P01",Vector2(480,340))
	while not scene.combat.is_player_turn(): await process_frame
	scene.combat_view._dismiss_card()
	scene.combat._actor("enemy0").hp = 1
	scene.find_child("Basic_Attack",true,false).pressed.emit()
	for _i in 600:
		await process_frame
		if scene.find_child("ContinueSettle",true,false) != null: break
	check(scene.find_child("ContinueSettle",true,false) != null and scene.screen_mode == "world","victory opens the settlement screen in the world")
	await create_timer(0.3).timeout
	await shot("settle_victory")
	check(scene.session.state.player.currency > gold_before and scene.session.state.player.level >= 2,"reward and level are already committed while counters play")
	var next = scene.find_child("ContinueSettle",true,false)
	next.pressed.emit()
	next.pressed.emit()
	await process_frame
	check(scene.find_child("Settle_STR",true,false) == null and scene.modal_body.get_parent() != null,"level-up summary comes before the attribute choice")
	await shot("settle_levelup")
	scene.find_child("ContinueSettle",true,false).pressed.emit()
	await process_frame
	check(scene.find_child("Settle_STR",true,false) != null,"attribute choice follows the level-up summary")
	check(scene.find_child("ContinueSettle",true,false).disabled,"continue stays locked until the new points are spent")
	await shot("settle_attributes")
	var str_before: int = scene.session.state.player.base_attributes.STR
	var owed: int = scene.session.state.player.attribute_points
	scene.find_child("Settle_STR",true,false).pressed.emit()
	await process_frame
	check(scene.session.state.player.base_attributes.STR == str_before + 1 and scene.session.state.player.attribute_points == owed - 1,"each tile spends one point")
	for _i in owed:
		if not scene.find_child("ContinueSettle",true,false).disabled: break
		scene.find_child("Settle_VIT",true,false).pressed.emit()
		await process_frame
	check(not scene.find_child("ContinueSettle",true,false).disabled,"continue unlocks once the points are spent")
	scene.find_child("ContinueSettle",true,false).pressed.emit()
	await process_frame
	await process_frame
	check(scene.find_child("Learn_S01",true,false) != null,"the skill board ends the settlement")
	await shot("settle_skills")
	scene.queue_free()
	await process_frame
	print("Settlement smoke: %d failed" % failed)
	quit(1 if failed else 0)
