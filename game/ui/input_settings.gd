class_name InputSettings
extends RefCounted

const DEFAULT_BINDINGS: Dictionary = {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],"interact":[KEY_E,KEY_SPACE]}
const DEFAULT_OPTIONS: Dictionary = {"master":0.8,"music":0.65,"sfx":0.8,"reduced_shake":false,"reduced_flash":false,"instant_text":false,"text_speed":30,"window_mode":"windowed","window_size":"1280x720"}
const RESERVED: Array[int] = [KEY_ESCAPE,KEY_ENTER,KEY_TAB,KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META]
var bindings: Dictionary = DEFAULT_BINDINGS.duplicate(true)
var options: Dictionary = DEFAULT_OPTIONS.duplicate(true)
var path: String
var warning: String = ""

func _init(settings_path: String = "user://saves/settings.cfg") -> void:
	path = settings_path

func _result(ok: bool, reason: String = "") -> Dictionary:
	return {"ok":ok,"reason":reason}

func _valid_option(key: String, value: Variant) -> bool:
	if not DEFAULT_OPTIONS.has(key):
		return false
	if key in ["master","music","sfx"]:
		return (value is float or value is int) and is_finite(float(value)) and value >= 0.0 and value <= 1.0
	if key in ["reduced_shake","reduced_flash","instant_text"]:
		return value is bool
	if key == "text_speed":
		return value is int and value >= 1 and value <= 120
	if key == "window_mode":
		return value is String and value in ["windowed","fullscreen"]
	return value is String and value in ["960x540","1280x720","1920x1080"]

func _valid_bindings(candidate: Dictionary) -> bool:
	var used: Array[int] = []
	for action in DEFAULT_BINDINGS:
		var keys = candidate.get(action)
		if not keys is Array or keys.is_empty() or keys.size() > 2:
			return false
		for key in keys:
			if not key is int or key <= 0 or key in RESERVED or key in used:
				return false
			used.append(key)
	return true

func load_settings() -> Dictionary:
	bindings = DEFAULT_BINDINGS.duplicate(true)
	options = DEFAULT_OPTIONS.duplicate(true)
	warning = ""
	if FileAccess.file_exists(path):
		var config := ConfigFile.new()
		var valid: bool = config.load(path) == OK and config.get_value("meta","version",0) == 1
		var candidate: Dictionary = {}
		var candidate_options: Dictionary = {}
		if valid:
			for action in DEFAULT_BINDINGS:
				candidate[action] = config.get_value("bindings",action,[])
			valid = _valid_bindings(candidate)
			for key in DEFAULT_OPTIONS:
				var value = config.get_value("options",key,DEFAULT_OPTIONS[key])
				candidate_options[key] = value
				valid = valid and _valid_option(key,value)
		if valid:
			bindings = candidate
			options = candidate_options
		else:
			warning = "อ่านการตั้งค่าเดิมไม่ได้ ใช้ค่าเริ่มต้นที่เล่นได้แทน"
	apply_bindings()
	apply_options()
	return _result(warning.is_empty(),warning)

func apply_bindings() -> void:
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)
	# Enter remains menu confirmation; Space belongs to world interaction only.
	for action in ["ui_accept","ui_cancel"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = KEY_ENTER if action == "ui_accept" else KEY_ESCAPE
		InputMap.action_add_event(action,event)

func rebind(action: String, keycode: int) -> Dictionary:
	if not DEFAULT_BINDINGS.has(action) or keycode <= 0 or keycode in RESERVED:
		return _result(false,"ใช้ปุ่มนี้ไม่ได้ ต้องคง Enter / Esc / Tab สำหรับเมนู")
	for other in bindings:
		if other != action and keycode in bindings[other]:
			return _result(false,"ปุ่มนี้ถูกใช้กับคำสั่งอื่นแล้ว")
	bindings[action] = [keycode]
	apply_bindings()
	return _result(true)

func set_option(key: String, value: Variant) -> Dictionary:
	if not _valid_option(key,value):
		return _result(false,"ค่าการตั้งค่าไม่ถูกต้อง")
	options[key] = value
	apply_options(key)
	return _result(true)

func apply_options(changed: String = "") -> void:
	for name in ["Master","Music","SFX"]:
		var index := AudioServer.get_bus_index(name)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(index,name)
			AudioServer.set_bus_send(index,"Master")
		var key: String = {"Master":"master","Music":"music","SFX":"sfx"}[name]
		var volume: float = float(options[key])
		AudioServer.set_bus_mute(index,volume <= 0.0001)
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(0.0001,volume)))
	if DisplayServer.get_name() != "headless" and changed in ["","window_mode","window_size"]:
		DisplayServer.window_set_min_size(Vector2i(960,540))
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if options.window_mode == "fullscreen" else DisplayServer.WINDOW_MODE_WINDOWED)
		if options.window_mode == "windowed":
			var dimensions: PackedStringArray = options.window_size.split("x")
			DisplayServer.window_set_size(Vector2i(int(dimensions[0]),int(dimensions[1])))

func restore_defaults() -> void:
	bindings = DEFAULT_BINDINGS.duplicate(true)
	options = DEFAULT_OPTIONS.duplicate(true)
	apply_bindings()
	apply_options()

func binding_label(action: String) -> String:
	var labels: Array[String] = []
	for key in bindings.get(action,[]):
		labels.append(OS.get_keycode_string(key))
	return " / ".join(labels)

func save_settings() -> Dictionary:
	if not _valid_bindings(bindings):
		return _result(false,"ปุ่มตั้งค่าไม่สมบูรณ์")
	if FileAccess.file_exists(path):
		var old := ConfigFile.new()
		var loaded: bool = old.load(path) == OK
		var version = old.get_value("meta","version",0)
		if loaded and version is int and version > 1:
			return _result(false,"การตั้งค่ามาจากรุ่นใหม่กว่า จึงไม่เขียนทับ")
	var config := ConfigFile.new()
	config.set_value("meta","version",1)
	for action in bindings:
		config.set_value("bindings",action,bindings[action])
	for key in options:
		config.set_value("options",key,options[key])
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())) != OK:
		return _result(false,"สร้างโฟลเดอร์ตั้งค่าไม่ได้")
	var temp := path + ".tmp"
	if config.save(temp) != OK:
		return _result(false,"บันทึกการตั้งค่าไม่ได้")
	var verify := ConfigFile.new()
	if verify.load(temp) != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(path)) != OK:
		return _result(false,"แทนที่การตั้งค่าไม่ได้ ไฟล์เดิมยังอยู่")
	return _result(true,"บันทึกการตั้งค่าแล้ว")
