extends SceneTree

var output: String

func _initialize() -> void:
	await process_frame
	create_timer(45).timeout.connect(func():printerr("FAIL: icon capture timed out");quit(1))
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: icon capture requires actual renderer")
		quit(1)
		return
	output = ProjectSettings.globalize_path("res://../docs/development/screenshots/review-2026-11-03/after-p2")
	DirAccess.make_dir_recursive_absolute(output)
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var directory := "user://test-icon-captures-" + str(Time.get_ticks_usec())
	var scene = load("res://main.tscn").instantiate()
	scene.saves = SaveService.new(catalog.data,directory)
	root.add_child(scene)
	await process_frame
	scene.find_child("NewGame",true,false).pressed.emit()
	await process_frame
	scene.find_child("Class_C05",true,false).pressed.emit()
	await process_frame
	scene.find_child("StorySkip",true,false).pressed.emit()
	await process_frame
	await process_frame
	# Display fixture: every item split between bag and stash.
	var p: Dictionary = scene.session.state.player
	p.items = []
	p.stash = []
	for item in catalog.data.items:
		(p.items if p.items.size() < 24 else p.stash).append(item.id)
	p.currency = 9999
	scene.session.state.room_id = "R01"
	scene._show_inventory()
	await process_frame
	await capture("inventory")
	scene._close_modal()
	scene.session.state.room_id = "R11"
	scene._show_shop()
	await process_frame
	await capture("shop")
	scene._close_modal()
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	scene.queue_free()
	await create_timer(.2).timeout
	quit(0)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := Captures.frame(root)
	image.save_png(output.path_join(label + ".png"))
	print("Captured ",label," ",image.get_size())
