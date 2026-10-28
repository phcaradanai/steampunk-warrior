extends SceneTree

var passed: int = 0
var failed: int = 0

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	var suites: Array[String] = ["catalog", "combat", "progression", "inventory", "rewards", "story", "world", "training", "controller", "slice_campaign", "save", "ui_state", "art", "bosses", "environment", "campaign", "audio", "layouts", "acquisition"]
	var args := OS.get_cmdline_user_args()
	if args.has("--suite"):
		var index := args.find("--suite")
		if index + 1 < args.size():
			suites = [args[index + 1]]
	for suite in suites:
		var path := "res://tests/test_%s.gd" % suite
		if not FileAccess.file_exists(path):
			check(false, "test suite missing: " + suite)
			continue
		var script = load(path)
		if script == null or not script.can_instantiate():
			check(false, "test suite cannot load: " + suite)
			continue
		var completed = script.new().run(self)
		if completed != true:
			check(false, "suite interrupted before completion: " + suite)
	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
