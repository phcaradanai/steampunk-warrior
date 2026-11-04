extends SceneTree
# Real-renderer screenshots of the VFX Sandbox UI in its main states. Output dir: env CAPTURE_DIR.
# Usage: CAPTURE_DIR=<dir> Godot --path game --script res://tests/capture_vfx_sandbox.gd

var output: String
var sandbox

func _initialize() -> void:
	await process_frame
	create_timer(120).timeout.connect(func(): printerr("FAIL: sandbox capture timed out"); quit(1))
	output = OS.get_environment("CAPTURE_DIR")
	sandbox = load("res://tests/vfx_sandbox.tscn").instantiate()
	root.add_child(sandbox)
	await create_timer(1.0).timeout
	await _shot("crit", "ui_library", 0.12)
	await _shot("event:hero_hit", "ui_event_hero_hit", 0.1)
	await _shot("skill:S04", "ui_skill_S04", 0.75)
	await _shot("skill:S02", "ui_skill_S02", 0.62)
	await sandbox.set_compare(true)
	await _shot("crit", "ui_compare_crit", 0.08)
	await _shot("slash2", "ui_compare_slash2", 0.2)
	await sandbox.set_compare(false)
	sandbox.set_backdrop("light")
	await _shot("thunder", "ui_light_thunder", 0.12)
	sandbox.set_backdrop("dark")
	sandbox.search.text = "aura"
	sandbox._fill_tree()
	await _shot("aura_heated", "ui_dark_search_aura", 0.4)
	sandbox.search.text = ""
	sandbox._fill_tree()
	sandbox.set_backdrop("foundry")
	sandbox.set_full_view(true)
	await _shot("event:enemy_hit", "ui_full_view_enemy_hit", 0.12)
	print("sandbox captures done")
	quit(0)

func _shot(id: String, name: String, after: float) -> void:
	while sandbox.feedback.playing > 0: await create_timer(0.05).timeout
	await create_timer(0.3).timeout
	sandbox.select(id)
	await create_timer(after).timeout
	await RenderingServer.frame_post_draw
	Captures.frame(root).save_png("%s/%s.png" % [output, name])
