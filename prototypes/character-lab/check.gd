extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.gear == [0,0,0,0])
	for i in 100:
		var phase := i*TAU/100.0
		var foot: Vector2 = scene.gait_foot(phase)
		var hip := Vector2(0,-53)
		var ankle := foot-Vector2(1,5)
		var knee: Vector2 = scene.joint_between(hip,ankle,28,-1)
		assert(absf(hip.distance_to(knee)-28)<0.01)
		assert(absf(ankle.distance_to(knee)-28)<0.01)
		if phase<PI: assert(absf(foot.y)<0.01)
		else: assert(foot.y<=0)
	assert(scene.gait_foot(0.1).x < scene.gait_foot(0).x)
	for slot in 4:
		for value in 3:
			scene.gear[slot] = value
			await process_frame
	scene.set_mode("attack")
	await create_timer(0.3).timeout
	assert(scene.strike != 0)
	scene.set_mode("hit")
	await create_timer(0.15).timeout
	assert(scene.recoil > 0)
	await create_timer(0.7).timeout
	assert(scene.mode == "idle")
	scene.gear = [0,0,0,2]
	scene.set_mode("walk")
	await create_timer(0.2).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		for i in 4:
			scene.paused = true
			scene.clock = (i*PI/2)/6.0
			scene.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://gait-%d.png" % i)
	print("PASS equipment selections, attack motion, interruption, hit recovery")
	quit()
