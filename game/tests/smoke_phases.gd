extends SceneTree
# B06 phase visuals follow the HP the player sees, and a dash stops at the target's visible front edge. Set CAPTURE_DIR to also save a shot per phase.

var failed: int = 0

func check(value: bool, label: String) -> void:
	if not value:
		failed += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	await process_frame
	create_timer(90).timeout.connect(func():printerr("FAIL: phase smoke timed out");quit(1))
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,"user://test-phases-"+str(Time.get_ticks_usec()))
	root.add_child(scene)
	await process_frame
	scene._new_game("C01")
	var encounter := catalog.get_entry("encounters","E36")
	scene.session.state.room_id = encounter.room
	scene.session.state.first_clears[encounter.requires] = true
	scene._show_world()
	scene._start_encounter("E36")
	var view: CombatView = scene.combat_view
	await create_timer(0.5).timeout
	view._dismiss_card()
	var queen: Creature3D = view.portraits.enemy0.hero
	var boss: Dictionary = scene.combat._actor("enemy0")
	var out := OS.get_environment("CAPTURE_DIR")
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	var seen: Array = []
	for step in [[1.0, 0], [0.7, 1], [0.35, 2]]:
		boss.hp = int(boss.max_hp * step[0])
		view._plates()
		await create_timer(0.3).timeout
		check(queen.phase == step[1], "B06 shows phase %d at %d%% HP (saw %d)" % [step[1], int(step[0]*100), queen.phase])
		seen.append([queen._plates[0].visible, queen._core.visible, queen._smoke.emitting, queen._light.light_energy])
		await create_timer(0.5).timeout
		if not out.is_empty():
			await RenderingServer.frame_post_draw
			Captures.frame(root).save_png("%s/boss_B06_phase%d.png" % [out, step[1]])
	check(seen[0] != seen[1] and seen[1] != seen[2] and seen[0] != seen[2], "rendered B06 state differs per phase")
	check(seen[1][2] and not seen[0][2] and not seen[2][2], "smoke emits only in phase 1")
	boss.hp = int(boss.max_hp * 0.9)
	view._plates()
	check(queen.phase == 2, "phase never steps back")
	# Dash stop: the hero must end up left of the mantis' visible body (wings and blades included), not inside it.
	var hero: ActorPortrait = view.portraits.hero
	var foe: ActorPortrait = view.portraits.enemy0
	var spot: Vector2 = view.feedback._dash_spot(hero, foe, -1.0)
	var ppu: float = queen.size.y / Stage3D.FRAME
	var front: float = foe.position.x + foe.size.x * 0.5 + queen.extent_x().x * ppu
	check(spot.x + hero.size.x * 0.5 < front, "dash stops left of B06 front edge (%.0f vs %.0f)" % [spot.x + hero.size.x * 0.5, front])
	check(spot.x + hero.size.x * 0.5 > front - 400.0, "dash does not stop absurdly far from B06 (%.0f vs %.0f)" % [spot.x + hero.size.x * 0.5, front])
	print("B06 extent %s ppu %.1f hero centre %.0f front %.0f" % [queen.extent_x(), ppu, spot.x + hero.size.x * 0.5, front])
	scene.queue_free()
	await process_frame
	print("Phase smoke: %d failed" % failed)
	quit(1 if failed else 0)
