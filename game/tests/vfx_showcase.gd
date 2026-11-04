extends SceneTree
# Fixed-clock captures of the VFX Sandbox (tests/vfx_sandbox.tscn), so every frame is deterministic.
# Needs the real renderer (not --headless).
# Usage: CAPTURE_DIR=<dir> [VFX_KINDS=hit,crit] [VFX_FOE=N12] [VFX_ARENA=canal] [VFX_SIZE=960x540] [VFX_LEGACY=1]
#   Godot --path game --script res://tests/vfx_showcase.gd
# Per kind: <kind>_strip.png (target crop at the STEPS times, with the game's hit flash),
# <kind>_gray.png (same, greyscale, for value contrast) and <kind>_full.png (whole frame at 0.06 s).

const STEPS := [0.0, 0.03, 0.06, 0.1, 0.15, 0.22, 0.3, 0.4, 0.55, 0.75]
const CROP := Rect2(560, 200, 520, 420)  # size is used; position follows each effect

func _initialize() -> void:
	await process_frame
	var output := OS.get_environment("CAPTURE_DIR")
	if output.is_empty():
		printerr("FAIL: set CAPTURE_DIR")
		quit(1)
		return
	var sandbox = load("res://tests/vfx_sandbox.tscn").instantiate()
	root.add_child(sandbox)
	sandbox.set_full_view(true)
	sandbox.shake = false
	await sandbox.set_foe(OS.get_environment("VFX_FOE") if OS.has_environment("VFX_FOE") else "N12")
	sandbox.set_backdrop(OS.get_environment("VFX_ARENA") if OS.has_environment("VFX_ARENA") else "canal")
	var scale := 1.0
	if not OS.get_environment("VFX_SIZE").is_empty():
		var wanted := OS.get_environment("VFX_SIZE").split("x")
		DisplayServer.window_set_size(Vector2i(int(wanted[0]), int(wanted[1])))
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		scale = float(wanted[0]) / 1280.0
	await create_timer(0.8).timeout
	var kinds: Array = Array(OS.get_environment("VFX_KINDS").split(",", false)) if OS.has_environment("VFX_KINDS") else ToonFx.kinds()
	var crop := Rect2i(CROP.position * scale, CROP.size * scale)
	for kind in kinds:
		var sheet := Image.create(crop.size.x * STEPS.size(), crop.size.y, false, Image.FORMAT_RGBA8)
		var fx: Node2D = sandbox.spawn(kind)
		if OS.has_environment("VFX_LEGACY"):
			# Same placement, drawn by the pre-refinement ToonFx (tests/vfx_lab/toon_fx_v1.gd) for before/after sheets.
			fx.queue_free()
			var at: Array = sandbox._placement(kind, sandbox.foe)
			fx = sandbox.LegacyFx.spawn(sandbox.feedback, kind, at[0], at[1], at[2])
			sandbox._aim(fx, kind)
		# Crop around the effect itself (casts sit on the hero), clamped to the frame.
		var centre := (fx.position + (Vector2(180, 0) if kind == "zap" else Vector2.ZERO)) * scale
		crop.position = Vector2i((centre - Vector2(crop.size) * Vector2(0.67, 0.58)).clamp(Vector2.ZERO, Vector2(1280, 720) * scale - Vector2(crop.size)))
		fx.set_process(false)
		var duration: float = ToonFx.DURATION.get(kind, 0.75)
		for i in STEPS.size():
			fx.clock = STEPS[i] if kind in ToonFx.LOOPS else minf(STEPS[i], duration - 0.001)
			fx.queue_redraw()
			sandbox.flash_foe(STEPS[i] if kind in sandbox.STRIKES else 99.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var frame := Captures.frame(root)
			frame.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(frame, crop, Vector2i(crop.size.x * i, 0))
			if i == 2: frame.save_png("%s/%s_full.png" % [output, kind])
		fx.queue_free()
		sheet.save_png("%s/%s_strip.png" % [output, kind])
		sheet.convert(Image.FORMAT_L8)
		sheet.save_png("%s/%s_gray.png" % [output, kind])
	print("vfx showcase done: %d kinds" % kinds.size())
	quit(0)
