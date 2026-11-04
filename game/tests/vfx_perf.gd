extends SceneTree
# VFX cost on the real renderer, vsync off: the sandbox idle vs. worst case (all 7 status auras on the foe plus a
# fresh impact burst every 0.1 s, ~36 effects live). Also a realistic turn: 2 auras + one impact every 0.3 s.
# Prints mean/p95/max frame time per case.
# Usage: [VFX_LEGACY=1] Godot --path game --script res://tests/vfx_perf.gd   (VFX_LEGACY: the pre-refinement ToonFx)

const AURAS := ["aura_wet", "aura_heated", "aura_corroded", "aura_marked", "aura_sealed", "aura_staggered", "aura_haste"]
const BURST := ["crit", "slash2", "smash", "thunder", "fire", "cloud"]

var Fx = ToonFx

func _initialize() -> void:
	if OS.has_environment("VFX_LEGACY"): Fx = load("res://tests/vfx_lab/toon_fx_v1.gd")
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var sandbox = load("res://tests/vfx_sandbox.tscn").instantiate()
	root.add_child(sandbox)
	sandbox.set_full_view(true)
	await create_timer(1.0).timeout
	await _measure("idle (no effects)", func(_t): pass)
	var pair: Array = []
	for kind in ["aura_wet", "aura_marked"]:
		pair.append(Fx.spawn(sandbox.overlay, kind, sandbox.anchor(sandbox.foe, 0.5), true, 0.9))
	var turn := {"next": 0.0}
	await _measure("realistic: 2 auras + impact/0.3 s", func(t):
		if t >= turn.next:
			turn.next = t + 0.3
			Fx.spawn(sandbox.overlay, "crit", sandbox.anchor(sandbox.foe, 0.5), false))
	for fx in pair: fx.queue_free()
	var held: Array = []
	for kind in AURAS:
		held.append(Fx.spawn(sandbox.overlay, kind, sandbox.anchor(sandbox.foe, 0.5), true, 0.9))
	await _measure("7 auras", func(_t): pass)
	var state := {"next": 0.0}
	await _measure("7 auras + 6 impacts every 0.1 s", func(t):
		if t >= state.next:
			state.next = t + 0.1
			for kind in BURST: Fx.spawn(sandbox.overlay, kind, sandbox.anchor(sandbox.foe, 0.5), false))
	print("live ToonFx nodes at end: ", sandbox.overlay.get_child_count())
	quit(0)

func _measure(label: String, tick: Callable) -> void:
	var frames: Array = []
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < 4_000_000:
		tick.call((Time.get_ticks_usec() - start) / 1e6)
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
	frames.sort()
	var mean: float = frames.reduce(func(a, b): return a + b, 0.0) / frames.size()
	print("VFX_PERF %-34s frames=%d fps=%.0f mean=%.2fms p95=%.2fms max=%.2fms " % [label, frames.size(), 1000.0 / mean,
		mean, frames[int(frames.size() * 0.95)], frames[-1]])
