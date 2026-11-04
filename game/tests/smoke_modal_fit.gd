extends SceneTree
# Every modal must fit the 1280x720 canvas: there is no scrolling anywhere.

var failed: int = 0
var scene

func measure(label: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	var panel: Control = scene.modal_body.get_parent().get_parent()
	var rect: Rect2 = panel.get_global_rect()
	var ok := Rect2(0,0,1280,720).encloses(rect)
	if not ok: failed += 1
	print("%s %s %s" % ["OK  " if ok else "FAIL", label, rect])

func _initialize() -> void:
	await process_frame
	create_timer(60).timeout.connect(func():printerr("FAIL: modal fit timed out");quit(1))
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,"user://test-modal-fit-" + str(Time.get_ticks_usec()))
	root.add_child(scene)
	await process_frame
	scene._new_game("C01")
	var p: Dictionary = scene.session.state.player
	p.level = 30
	p.attribute_points = 10
	p.skill_points = 10
	var items: Array = catalog.data.items.map(func(i): return i.id)
	p.items = items.slice(0,24)
	p.stash = items.slice(0,30)
	scene.session.state.room_id = "R01"
	scene._show_world()
	scene._show_inventory(); await measure("inventory")
	scene._show_shop(); await measure("shop")
	scene._show_skills(); await measure("skills")
	scene._show_quests(); await measure("quests")
	scene._show_training(); await measure("training")
	scene._show_settings(); await measure("settings")
	scene._show_save_slots(); await measure("saves")
	scene._open_pause(); await measure("pause")
	for i in 80: scene.backlog.append({"speaker":"ผู้พูด","text":"บรรทัดทดสอบยาวพอสมควรเพื่อดูว่าประวัติบทคุยล้นจอหรือไม่ %d" % i})
	scene._show_backlog(); await measure("backlog")
	scene.settle_points = 4
	scene._settle_attributes(2); await measure("settle_attributes")
	scene._settle_level_up({"player":p.duplicate(true)},2); await measure("level_up")
	scene._show_ending_choices(); await measure("ending")
	scene.settings.options.instant_text = true
	scene._show_dialogue("D04"); await measure("dialogue")
	scene._confirm_leave(false); await measure("leave")
	scene._close_modal(true)
	scene.queue_free()
	await process_frame
	print("Modal fit: %d failed" % failed)
	quit(1 if failed > 0 else 0)
