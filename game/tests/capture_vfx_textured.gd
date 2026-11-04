extends SceneTree
# Real-time captures of every effect through the VFX Sandbox (GPU particles run on real time, so no fixed clock).
# Usage: CAPTURE_DIR=<dir> [VFX_KINDS=hit,crit] [VFX_COMPARE=1] Godot --path game --script res://tests/capture_vfx_textured.gd
# Writes <kind>_<n>.png at the TIMES below (seconds after the effect starts).

const TIMES := [0.02, 0.06, 0.1, 0.15, 0.22, 0.3, 0.42, 0.6]

func _initialize() -> void:
	await process_frame
	create_timer(600).timeout.connect(func(): printerr("FAIL: textured capture timed out"); quit(1))
	var output := OS.get_environment("CAPTURE_DIR")
	var sandbox = load("res://tests/vfx_sandbox.tscn").instantiate()
	root.add_child(sandbox)
	sandbox.set_full_view(true)
	sandbox.shake = false
	await create_timer(1.2).timeout
	if OS.has_environment("VFX_COMPARE"): await sandbox.set_compare(true)
	var kinds: Array = Array(OS.get_environment("VFX_KINDS").split(",", false)) if OS.has_environment("VFX_KINDS") else ToonFx.kinds()
	for kind in kinds:
		while sandbox.feedback.playing > 0: await process_frame
		await create_timer(0.35).timeout
		var start := Time.get_ticks_usec()
		sandbox.select(kind)
		for i in TIMES.size():
			while (Time.get_ticks_usec() - start) / 1e6 < TIMES[i]: await process_frame
			await RenderingServer.frame_post_draw
			Captures.frame(root).save_png("%s/%s_%d.png" % [output, kind, i])
		await create_timer(0.5).timeout
	print("textured captures done: ", kinds.size())
	quit(0)
