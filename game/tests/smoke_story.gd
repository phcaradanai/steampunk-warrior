extends SceneTree
# Story flow: intro after class pick, chapter opening once, boss aftermath + closing after the first clear, ending pages then credits.

var failed: int = 0
var output: String = OS.get_environment("CAPTURE_DIR")

func check(value: bool, label: String) -> void:
	if not value:
		failed += 1
		printerr("FAIL: " + label)

func shot(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	for _i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [output, name])

func page_text(scene) -> String:
	var view = scene.find_child("StoryScreen",true,false)
	return "" if view == null else view.text_label.text

func _initialize() -> void:
	await process_frame
	create_timer(60).timeout.connect(func():printerr("FAIL: story smoke timed out");quit(1))
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,"user://test-story-"+str(Time.get_ticks_usec()))
	root.add_child(scene)
	await process_frame
	scene.settings.options.instant_text = true
	scene.find_child("NewGame",true,false).pressed.emit()
	await process_frame
	scene.find_child("Class_C01",true,false).pressed.emit()
	await process_frame
	var view = scene.find_child("StoryScreen",true,false)
	check(view != null and scene.screen_mode == "world" and scene.world.blocked,"intro opens over a blocked world")
	check(view.pages.size() >= 3 and page_text(scene) == catalog.data.story.intro[0].text,"first intro page shown")
	await shot("story_intro")
	scene.find_child("StoryNext",true,false).pressed.emit()
	await process_frame
	check(page_text(scene) == catalog.data.story.intro[1].text,"Next advances the intro")
	scene.find_child("StorySkip",true,false).pressed.emit()
	await process_frame
	check(scene.find_child("StoryScreen",true,false) == null and not scene.world.blocked,"skip ends the intro and frees the world")
	# Chapter opening: first visit to R03 only.
	scene.session.state.room_id = "R03"
	scene._show_world()
	await process_frame
	await process_frame
	check(scene.find_child("StoryScreen",true,false) != null and "บทที่ 1" in scene.find_child("StoryScreen",true,false).title_label.text,"entering the chapter's first room opens its banner page")
	check(scene.session.state.world_flags.get("story:open:CH01",false),"opening is remembered in world flags")
	await shot("story_chapter_opening")
	scene.find_child("StorySkip",true,false).pressed.emit()
	await process_frame
	scene._show_world()
	await process_frame
	await process_frame
	check(scene.find_child("StoryScreen",true,false) == null,"opening does not repeat")
	# Boss pre line on the confirm modal.
	scene.session.state.room_id = "R04"
	for earlier in ["E01","E02","E03","E04","E05"]: scene.session.state.first_clears[earlier] = true
	scene._show_world()
	await process_frame
	scene._confirm_encounter("E06")
	await process_frame
	check(scene.find_child("BossPreLine",true,false) != null and scene.find_child("BossPreLine",true,false).text == catalog.data.story.boss_lines.B01.pre_line,"boss confirm modal speaks the pre line")
	scene._close_modal(true)
	# First clear of B01 through the real commit, then the settlement chain ends in the aftermath pages.
	scene.session.state.player.xp = 0
	var before: Dictionary = scene.session.snapshot()
	var result: Dictionary = scene.session.commit_result("battle_won",{"id":"smoke-b01","encounter_id":"E06","xp":5,"gold":5})
	check(result.ok and scene.session.state.first_clears.has("B01"),"B01 first clear committed")
	scene.pending_story = DialogueService.new(catalog.data).boss_story("B01",scene.session.state)
	scene._settle_victory(before,result)
	await process_frame
	check(scene.find_child("StoryScreen",true,false) == null,"story waits for the settlement")
	for _i in 30:
		if scene.find_child("Learn_S01",true,false) != null: break
		var spend = scene.find_child("Settle_STR",true,false)
		if spend != null and not spend.disabled: spend.pressed.emit()
		var go = scene.find_child("ContinueSettle",true,false)
		if go != null and not go.disabled: go.pressed.emit()
		await process_frame
		await process_frame
	check(scene.find_child("StoryScreen",true,false) == null,"story waits until the skill board is closed")
	scene._close_modal(false)
	for _i in 4: await process_frame
	check(scene.find_child("StoryScreen",true,false) != null and page_text(scene) == catalog.data.story.boss_lines.B01.post_line,"boss aftermath shown after the settlement")
	await shot("story_boss_post")
	scene.find_child("StoryNext",true,false).pressed.emit()
	await process_frame
	check(page_text(scene) == catalog.data.story.chapters[0].closing,"chapter closing follows the aftermath")
	await shot("story_chapter_closing")
	scene.find_child("StoryNext",true,false).pressed.emit()
	await process_frame
	check(scene.find_child("StoryScreen",true,false) == null and scene.session.state.world_flags.get("story:close:CH01",false) and scene.session.state.world_flags.get("story:post:B01",false),"story ends and is remembered")
	check(DialogueService.new(catalog.data).boss_story("B01",scene.session.state).is_empty(),"aftermath is not offered twice")
	# Endings: choice with consequence lines, pages, credits, back to world.
	scene.session.state.first_clears["B06"] = true
	scene._show_ending_choices()
	await process_frame
	check(scene.find_child("EndingHint_Shutdown",true,false) != null and scene.find_child("EndingHint_Shutdown",true,false).text != "","ending choices describe their consequence")
	await shot("story_ending_choices")
	scene.find_child("Ending_Shutdown",true,false).pressed.emit()
	await process_frame
	view = scene.find_child("StoryScreen",true,false)
	check(view != null and view.pages[0].title == "รุ่งเช้าที่ไร้ควัน" and view.pages[view.pages.size()-1].get("credits",false),"ending pages end with credits")
	await shot("story_ending_page")
	for _i in view.pages.size() - 1:
		scene.find_child("StoryNext",true,false).pressed.emit()
		await process_frame
	check("สร้างด้วย Godot Engine" in page_text(scene),"credits page names the engine")
	await shot("story_credits")
	scene.find_child("StoryNext",true,false).pressed.emit()
	await process_frame
	check(scene.find_child("StoryScreen",true,false) == null and scene.screen_mode == "world" and not scene.world.blocked and scene.session.state.world_flags.get("postgame",false),"credits return to the playable world")
	# Pipe players: chapter opening before the line's first fight, boss starts go through the confirm modal.
	scene._new_game("C01")
	var mouth := Vector2(400,300)
	scene.session.state.world_flags["environment:sluice_release"] = true
	for earlier in ["E01","E02","E03","E04","E05"]: scene.session.state.first_clears[earlier] = true
	await scene._enter_pipe_line("P01",mouth)
	await process_frame
	view = scene.find_child("StoryScreen",true,false)
	check(view != null and "บทที่ 1" in view.title_label.text and scene.combat == null,"pipe line opens its chapter before the first fight")
	check(scene.session.state.world_flags.get("story:open:CH01",false),"pipe opening uses the same remembered flag")
	scene.find_child("StorySkip",true,false).pressed.emit()
	for _i in 4: await process_frame
	var confirm = scene.find_child("ConfirmEncounter",true,false)
	check(confirm != null and scene.find_child("BossPreLine",true,false) != null and scene.combat == null,"pipe boss start asks for confirmation and speaks the pre line")
	await shot("story_pipe_boss_confirm")
	confirm.pressed.emit()
	for _i in 200:
		await process_frame
		if scene.combat != null and scene.screen_mode == "combat": break
	check(scene.combat != null and scene.combat.pipe_id == "P01" and scene.combat.encounter.id == "E06","confirming runs the pipe entry and starts the boss fight in the line")
	scene.queue_free()
	await process_frame
	scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,"user://test-story2-"+str(Time.get_ticks_usec()))
	root.add_child(scene)
	await process_frame
	scene._new_game("C01")
	for earlier in ["E24","E25","E26","E27","E28","E29","E30","E31","E32","E33","E34","E35"]: scene.session.state.first_clears[earlier] = true
	for chapter in catalog.data.story.chapters: scene.session.state.world_flags["story:open:" + chapter.id] = true
	scene.session.state.quest_states.Q08.state = "active"
	var gate: Dictionary = scene.world_policy.can_start_encounter("E36",scene.session.state,"P05")
	check(gate.ok,"final fight is reachable in the pipe fixture: " + str(gate.get("reason","")))
	await scene._enter_pipe_line("P05",mouth)
	await process_frame
	var final_modal = scene.find_child("ConfirmEncounter",true,false)
	check(final_modal != null and scene.combat == null and scene.modal.find_children("*","Label",true,false).any(func(l): return "การต่อสู้สุดท้าย" in l.text),"final fight via P05 shows the final-fight warning")
	scene.queue_free()
	await process_frame
	print("Story smoke: %d failed" % failed)
	quit(1 if failed else 0)
