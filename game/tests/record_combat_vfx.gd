extends SceneTree
# Records real combat (actual CombatView/CombatFeedback path) for VFX review: attacks, then every usable skill.
# Usage: Godot --path game --write-movie <dir>/frame.png --fixed-fps 30 --script res://tests/record_combat_vfx.gd
# Env: VFX_ENCOUNTER (default E10), VFX_CLASS (default C01), VFX_TURNS (default 6).

func _initialize() -> void:
	await process_frame
	create_timer(240).timeout.connect(func(): printerr("FAIL: combat recording timed out"); quit(1))
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data, "user://test-vfx-" + str(Time.get_ticks_usec()))
	root.add_child(scene)
	await process_frame
	scene._new_game(OS.get_environment("VFX_CLASS") if OS.has_environment("VFX_CLASS") else "C01")
	scene.session.state.player.level = 30
	var id: String = OS.get_environment("VFX_ENCOUNTER") if OS.has_environment("VFX_ENCOUNTER") else "E10"
	var encounter := catalog.get_entry("encounters", id)
	scene.session.state.room_id = encounter.room
	scene.session.state.first_clears[encounter.get("requires", "")] = true
	scene._show_world()
	scene._start_encounter(id)
	await create_timer(0.4).timeout
	var view = scene.combat_view
	view._dismiss_card()
	var turns := int(OS.get_environment("VFX_TURNS")) if OS.has_environment("VFX_TURNS") else 6
	var used := 0
	for turn in turns:
		await _idle(view)
		if not is_instance_valid(view) or view.settled: break
		var button: Button = null
		for b in view.find_children("Skill_*", "Button", true, false):
			if not b.disabled and b.name.trim_prefix("Skill_") not in view.get_meta("used", []):
				button = b
				break
		if button == null or turn % 2 == 0: button = view.find_child("Basic_Attack", true, false)
		else: view.set_meta("used", view.get_meta("used", []) + [String(button.name).trim_prefix("Skill_")])
		print("turn ", turn, ": ", button.name)
		button.pressed.emit()
		used += 1
		await create_timer(0.2).timeout
	await _idle(view)
	print("combat recording done: ", used, " actions")
	quit(0)

func _idle(view) -> void:
	for i in 200:
		if not is_instance_valid(view) or view.settled: return
		if view.feedback.playing == 0 and not view.pumping: return
		await create_timer(0.05).timeout
	await create_timer(0.3).timeout
