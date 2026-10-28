extends RefCounted

func run(t) -> bool:
	if not FileAccess.file_exists("res://ui/input_settings.gd"):
		t.check(false,"InputSettings must preserve reachable controls and preferences")
		return true
	var path := "user://test-settings-" + str(Time.get_ticks_usec()) + "/settings.cfg"
	var service = load("res://ui/input_settings.gd").new(path)
	t.check(service.load_settings().ok,"missing preferences load usable defaults")
	var before: Dictionary = service.bindings.duplicate(true)
	t.check(not service.rebind("move_right",KEY_A).ok and service.bindings == before,"rebind conflicts reject without altering controls")
	t.check(service.rebind("move_right",KEY_L).ok,"unused key can be rebound")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_L
	t.check(InputMap.event_is_action(event,"move_right"),"rebind changes actual engine InputMap")
	t.check(not service.rebind("interact",KEY_ESCAPE).ok,"menu escape cannot be stolen by gameplay action")
	t.check(not service.rebind("missing",KEY_K).ok,"unknown actions rejected")
	t.check(service.set_option("master",0.0).ok and AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"zero master slider actually mutes audio bus")
	t.check(not service.set_option("music",1.5).ok,"invalid volume rejected")
	t.check(service.set_option("reduced_flash",true).ok and service.save_settings().ok,"accessibility preference writes separate settings file")
	var loaded = load("res://ui/input_settings.gd").new(path)
	t.check(loaded.load_settings().ok and loaded.bindings.move_right == [KEY_L] and loaded.options.reduced_flash and loaded.options.master == 0.0,"bindings and settings survive reload independently of game slots")
	loaded.restore_defaults()
	event.physical_keycode = KEY_D
	t.check(InputMap.event_is_action(event,"move_right") and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"restore defaults restores actual controls and volume")
	for filename in DirAccess.get_files_at(path.get_base_dir()):
		DirAccess.remove_absolute(path.get_base_dir().path_join(filename))
	DirAccess.remove_absolute(path.get_base_dir())
	return true
