extends SceneTree
# Usage: godot --path . [--rendering-driver opengl3] --script res://tests/fps_probe.gd
# Prints renderer and Engine.get_frames_per_second after 3 s in R07. Windowed, not headless; vsync caps FPS.
func _initialize() -> void:
	await process_frame
	var scene = load("res://main.tscn").instantiate()
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	scene.saves = SaveService.new(catalog.data,"user://test-fps-" + str(Time.get_ticks_usec()))
	root.add_child(scene)
	await process_frame
	scene.find_child("NewGame",true,false).pressed.emit()
	await process_frame
	scene.find_child("Class_C01",true,false).pressed.emit()
	await process_frame
	scene.find_child("StorySkip",true,false).pressed.emit()
	await process_frame
	# Direct state edit: travel gating would refuse R07 on a fresh game.
	var room_id := "R01" if "r01" in OS.get_cmdline_user_args() else "R07"
	scene.session.state.room_id = room_id
	scene.session.state.checkpoint = {"room_id":room_id,"spawn_id":"entry"}
	scene._show_world()
	var views: Array = scene.find_children("*","SubViewport",true,false)
	if "nomsaa" in OS.get_cmdline_user_args():
		for v in views: v.msaa_3d = Viewport.MSAA_DISABLED
	if "novp" in OS.get_cmdline_user_args():
		for v in views: v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if "nostage" in OS.get_cmdline_user_args():
		for v in views: v.get_parent().visible = false
	await create_timer(3.0).timeout
	print("FPS_PROBE viewports=",views.size()," msaa=","off" if "nomsaa" in OS.get_cmdline_user_args() else "as-is")
	for v in views: print("  vp ",v.size," ",v.get_parent().get_class()," vis=",v.get_parent().is_visible_in_tree()," ",v.get_parent().get_global_rect())
	print("FPS_PROBE room=",scene.session.state.room_id," renderer=",RenderingServer.get_current_rendering_method()," driver=",RenderingServer.get_current_rendering_driver_name()," fps=",Engine.get_frames_per_second())
	quit()
