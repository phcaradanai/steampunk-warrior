extends SceneTree
# A foe must not fall before the blow that kills it lands, and its HP bar must change on that blow, not later.

var failed: int = 0

func check(value: bool, label: String) -> void:
	if not value:
		failed += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	await process_frame
	create_timer(60).timeout.connect(func():printerr("FAIL: combat timing smoke timed out");quit(1))
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
	# While the title card is up no command may go through, by button or hotkey; Enter skips the card.
	view._title_card()
	var before: int = scene.combat.sequence
	scene.find_child("Basic_Attack",true,false).pressed.emit()
	var hotkey := InputEventKey.new()
	hotkey.keycode = KEY_Z
	hotkey.pressed = true
	Input.parse_input_event(hotkey)
	await process_frame
	check(view.card != null and scene.combat.sequence == before and view.feedback.playing == 0 and scene.combat.is_player_turn(), "no command is submitted while the title card is up")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await process_frame
	check(view.card == null and scene.combat.sequence == before, "Enter dismisses the card without submitting")
	view._title_card()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = scene.find_child("Basic_Attack",true,false).get_global_rect().get_center()
	Input.parse_input_event(click)
	await process_frame
	check(view.card == null and scene.combat.sequence == before, "a click on a command dismisses the card without submitting")
	# One normal hit kills: the resolver knows at once, the screen must wait for contact.
	scene.combat._actor("enemy0").hp = 1
	view._render()
	var foe: ActorPortrait = view.portraits.enemy0
	# Lambdas capture locals by value, so the flag lives in a dictionary.
	var seen := {"landed":false}
	view.feedback.impacted.connect(func(id: String): if id == "enemy0": seen.landed = true)
	scene.find_child("Basic_Attack",true,false).pressed.emit()
	check(scene.combat.sequence > before, "an attack submits once the card is gone")
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
	# Victory: the banner must not sit on the loot tag, the log line or the HP panels.
	var banner: Label
	for _i in 600:
		await process_frame
		for l in view.feedback.get_children():
			if l is Label and l.text == "ชนะ!": banner = l
		if banner != null: break
	check(banner != null, "victory banner appears")
	if banner != null:
		await process_frame
		var others: Array = view.feedback.get_children().filter(func(n): return n is Label and n != banner)
		others.append_array(view.plates.get_children())
		for other in others:
			check(not banner.get_global_rect().intersects(other.get_global_rect()), "victory banner %s clear of %s %s" % [banner.get_global_rect(), other.get_global_rect(), other.text if other is Label else other.name])
		print("victory overlap checked against %d nodes" % others.size())
	scene.queue_free()
	await process_frame
	# Boss intro: its note sits clear of both actors and every HP panel.
	var boss_scene = load("res://main.tscn").instantiate()
	boss_scene.saves = SaveService.new(catalog.data,"user://test-timing-boss-"+str(Time.get_ticks_usec()))
	root.add_child(boss_scene)
	await process_frame
	boss_scene._new_game("C01")
	var boss := catalog.get_entry("encounters","E06")
	boss_scene.session.state.room_id = boss.room
	boss_scene.session.state.first_clears[boss.requires] = true
	boss_scene._show_world()
	boss_scene._start_encounter("E06")
	var boss_view: CombatView = boss_scene.combat_view
	await process_frame
	await process_frame
	check(boss_view.card_note != null and boss_view.card_note.text != "", "boss intro note is shown")
	if boss_view.card_note != null:
		var rect := boss_view.card_note.get_global_rect()
		for id in boss_view.portraits:
			check(not rect.intersects(boss_view.portraits[id].get_global_rect()), "boss note %s clear of %s %s" % [rect, id, boss_view.portraits[id].get_global_rect()])
		for panel in boss_view.plates.get_children():
			if panel is PanelContainer: check(not rect.intersects(panel.get_global_rect()), "boss note clear of HP panel")
	boss_scene.queue_free()
	await process_frame
	print("Combat timing smoke: %d failed" % failed)
	quit(1 if failed else 0)
