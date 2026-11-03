extends SceneTree
# A foe must not fall before the blow that kills it lands, and its HP bar must change on that blow, not later.

var failed: int = 0

func check(value: bool, label: String) -> void:
	if not value:
		failed += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	await process_frame
	create_timer(30).timeout.connect(func():printerr("FAIL: combat timing smoke timed out");quit(1))
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,"user://test-timing-"+str(Time.get_ticks_usec()))
	root.add_child(scene)
	await process_frame
	scene._new_game("C01")
	scene.session.state.room_id = "R03"
	scene._show_world()
	scene._start_encounter("E01")
	var view: CombatView = scene.combat_view
	while not scene.combat.is_player_turn(): await process_frame
	await create_timer(0.3).timeout
	# One normal hit kills: the resolver knows at once, the screen must wait for contact.
	scene.combat._actor("enemy0").hp = 1
	view._render()
	var foe: ActorPortrait = view.portraits.enemy0
	# Lambdas capture locals by value, so the flag lives in a dictionary.
	var seen := {"landed":false}
	view.feedback.impacted.connect(func(id: String): if id == "enemy0": seen.landed = true)
	scene.find_child("Basic_Attack",true,false).pressed.emit()
	var fell_early := false
	var bar_early := false
	for _i in 240:
		await process_frame
		if foe.hero.down and not seen.landed: fell_early = true
		if not seen.landed and view.shown_hp("enemy0") != 1: bar_early = true
		if seen.landed: break
	check(seen.landed, "the strike reaches its contact frame")
	check(not fell_early, "foe falls only after the fatal blow lands")
	check(not bar_early, "foe HP bar holds until the blow lands")
	await create_timer(0.2).timeout
	check(view.shown_hp("enemy0") == 0, "foe HP bar drops on the blow, before the attacker walks back")
	await create_timer(0.6).timeout
	check(foe.hero.down, "foe lies down after the fatal blow")
	scene.queue_free()
	await process_frame
	print("Combat timing smoke: %d failed" % failed)
	quit(1 if failed else 0)
