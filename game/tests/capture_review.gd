extends SceneTree
# Review captures for docs/superpowers/plans/2026-11-03-completion-plan.md. Output dir: env CAPTURE_DIR.

var out: String
var scene

func _initialize() -> void:
	await process_frame
	create_timer(240).timeout.connect(func():printerr("timeout");quit(1))
	out = OS.get_environment("CAPTURE_DIR")
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,"user://review-" + str(Time.get_ticks_usec()))
	root.add_child(scene)
	await process_frame
	await shot("title")
	scene._show_classes()
	await shot("classes")
	scene._new_game("C03")
	await wait(0.5)
	for chapter in catalog.data.story.chapters: scene.session.state.world_flags["story:open:" + chapter.id] = true
	await shot("hub_banner")
	await wait(2.4); await shot("hub")
	scene._open_pause(); await shot("pause"); scene._close_modal(true)
	scene._show_inventory(); await shot("inventory"); scene._close_modal(true)
	scene._show_skills(); await shot("skills"); scene._close_modal(true)
	scene._show_quests(); await shot("quests"); scene._close_modal(true)
	scene._show_training(); await shot("training"); scene._close_modal(true)
	scene.session.state.room_id = "R02"
	scene._show_world(); await wait(0.4); await shot("market")
	scene._show_shop(); await shot("shop"); scene._close_modal(true)
	scene._talk_npc("NPC03"); await wait(0.6); await shot("npc_talk"); scene._close_modal(true)
	# pause during combat
	for rid in ["R01","R07"]:
		scene.session.state.room_id = rid
		scene._show_world(); await wait(0.4); await shot("room_" + rid + "_banner")
	scene.session.state.room_id = "R03"
	scene._show_world(); await wait(0.3); await shot("room_R03")
	scene._start_encounter("E01")
	await wait(1.6)
	await shot("combat_idle")
	var esc := InputEventAction.new(); esc.action = "ui_cancel"; esc.pressed = true
	Input.parse_input_event(esc)
	await wait(0.3); await shot("combat_pause")
	scene._close_modal(true)
	# boss fights, level bumped so they render with real stats
	scene.session.state.player.level = 25
	for id in ["E06","E13","E20","E27","E31","E36"]:
		var enc := catalog.get_entry("encounters",id)
		scene.session.state.room_id = enc.room
		if not enc.requires.is_empty(): scene.session.state.first_clears[enc.requires] = true
		scene._show_world()
		scene._start_encounter(id)
		await wait(1.8)
		await shot("boss_" + enc.boss_id)
		scene.combat_view._dismiss_card()
		var skill = scene.find_child("Basic_Attack",true,false)
		if skill != null and not skill.disabled: skill.pressed.emit()
		await wait(1.6)
		await shot("boss_" + enc.boss_id + "_hit")
	# defeat modal
	scene.session.state.room_id = "R03"
	scene._show_world()
	scene._start_encounter("E01")
	await wait(0.5)
	scene.combat.state.outcome = "defeat"
	scene._finish_combat()
	await wait(0.3); await shot("defeat")
	scene._close_modal(true)
	# level-up chain
	var before: Dictionary = scene.session.snapshot()
	var r: Dictionary = scene.session.commit_result("battle_won",{"id":"rev1","encounter_id":"E02","xp":400,"gold":50,"drop":"W03"})
	print("commit ", r.ok, " ", r.get("reason",""))
	if r.ok:
		scene._settle_victory(before,r)
		await wait(1.5); await shot("settle_win")
		scene._settle_level_up(before,2); await shot("settle_levelup")
		scene._settle_attributes(2); await shot("settle_attr")
	# ending
	scene._close_modal(true)
	scene._show_ending_choices(); await shot("ending_choices")
	print("review captures done")
	quit(0)

func wait(s: float) -> void:
	await create_timer(s).timeout

func shot(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out,label])
