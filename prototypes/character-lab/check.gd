extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.gear == [0, 0, 0, 0])
	# Verify IK gait foot trajectory & non-slip ground phase
	for i in 100:
		var phase := i * TAU / 100.0
		var foot: Vector2 = scene.gait_foot(phase)
		var hip := Vector2(0, -53)
		var ankle := foot - Vector2(1, 5)
		var knee: Vector2 = scene.joint_between(hip, ankle, 28, -1)
		assert(absf(hip.distance_to(knee) - 28) < 0.01)
		assert(absf(ankle.distance_to(knee) - 28) < 0.01)
		if phase < PI: assert(absf(foot.y) < 0.01)
		else: assert(foot.y <= 0)
	assert(scene.gait_foot(0.1).x < scene.gait_foot(0).x)
	# Verify equipment selection slots
	for slot in 4:
		for value in 3:
			scene.gear[slot] = value
			await process_frame
	# Verify real walking translates actor_pos
	var start_x: float = scene.actor_pos.x
	scene.facing = 1.0
	scene.set_mode("walk")
	await create_timer(0.18).timeout
	assert(scene.actor_pos.x > start_x)
	# Verify attack approaches target dummy, swings weapon, triggers impact, and retreats
	scene.actor_pos = Vector2(432, 563)
	scene.set_mode("attack")
	await create_timer(0.20).timeout
	assert(scene.attack_phase == "approach")
	assert(scene.actor_pos.x > 440.0)
	await create_timer(0.32).timeout
	assert(scene.strike != 0.0)
	# Verify skill animation and release effect
	scene.set_mode("skill")
	await create_timer(0.45).timeout
	assert(scene.skill_burst > 0.0 or scene.strike != 0.0)
	# Verify interruption into hit recoil and recovery
	scene.set_mode("hit")
	await create_timer(0.08).timeout
	assert(scene.recoil > 0.0)
	await create_timer(0.55).timeout
	assert(scene.mode == "idle")
	# Verify pipe entry motion & rim occlusion state
	scene.set_mode("enter_pipe")
	await create_timer(0.55).timeout
	assert(scene.pipe_progress >= 0.35)
	scene.set_mode("idle")
	scene.actor_pos = Vector2(432, 563)
	scene.facing = 1.0
	scene.gear = [0, 0, 0, 2]
	scene.set_mode("walk")
	await create_timer(0.1).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		for i in 4:
			scene.paused = true
			scene.facing = 1.0
			scene.actor_pos = Vector2(360 + i * 28, 563)
			scene.clock = (i * PI / 2.0) / 7.2
			scene.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://gait-%d.png" % i)
		scene.paused = false
		scene.facing = 1.0
		scene.actor_pos = Vector2(432, 563)
		scene.gear = [0, 0, 0, 0]
		scene.set_mode("idle")
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview.png")
	print("PASS equipment selections, walk displacement, step-in attack motion, pipe entry, hit recovery")
	quit()
