extends SceneTree

var output: String
var failures: int = 0
var size_label: String = ""

func _initialize() -> void:
	await process_frame
	create_timer(45).timeout.connect(func():printerr("FAIL: interface capture timed out");quit(1))
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: interface capture requires actual renderer")
		quit(1)
		return
	output = ProjectSettings.globalize_path("res://../docs/development/screenshots")
	DirAccess.make_dir_recursive_absolute(output)
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var directory := "user://test-ui-captures-" + str(Time.get_ticks_usec())
	var scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,directory)
	root.add_child(scene)
	await process_frame
	for dimensions in ["960x540","1280x720","1920x1080"]:
		size_label = dimensions
		scene.settings.set_option("window_size",dimensions)
		scene._show_title()
		await process_frame
		await process_frame
		await capture("title")
		scene.find_child("OpenSettings",true,false).pressed.emit()
		await process_frame
		await capture("settings")
		scene._close_modal()
		scene.find_child("NewGame",true,false).pressed.emit()
		await process_frame
		scene.find_child("Class_C05",true,false).pressed.emit()
		await process_frame
		await capture("world")
		scene._show_skills()
		await process_frame
		await capture("skills")
		scene._close_modal()
		scene.settings.options.instant_text = true
		scene._show_dialogue("D04")
		await process_frame
		await capture("dialogue")
		scene._close_modal()
		# Controlled display fixture; not a natural campaign or skill acquisition claim.
		scene.session.state.room_id = "R03"
		scene.session.state.checkpoint = {"room_id":"R03","spawn_id":"entry"}
		scene._show_world()
		scene._start_encounter("E01")
		for skill in catalog.data.skills:
			if skill.kind == "active":
				scene.combat.learned[skill.id] = 1
		scene.combat_view._render()
		await process_frame
		await capture("combat_all_skills")
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	scene.queue_free()
	await create_timer(.2).timeout
	print("Interface captures: ",failures," failures across3sizes6screens")
	quit(1 if failures > 0 else 0)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var dimensions := size_label.split("x")
	if image.get_size() != Vector2i(int(dimensions[0]),int(dimensions[1])):
		printerr("FAIL: actual framebuffer ",image.get_size()," differs from ",size_label)
		failures += 1
	var path := output.path_join("ui_"+size_label+"_"+label+".png")
	if image.save_png(path) != OK:
		failures += 1
	print("Captured ",size_label," ",label," ",image.get_size())
