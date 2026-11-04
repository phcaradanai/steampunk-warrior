extends SceneTree
# Real-renderer captures of the hero holding each weapon family and mid-Shoot/Cast/Heal/Buff. Output dir: env CAPTURE_DIR.

func _initialize() -> void:
	await process_frame
	create_timer(60).timeout.connect(func():printerr("FAIL: weapon capture timed out");quit(1))
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: weapon capture requires actual renderer")
		quit(1)
		return
	var output := OS.get_environment("CAPTURE_DIR")
	var items: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	var holder := Control.new()
	holder.size = Vector2(1200, 760)
	root.add_child(holder)
	var bg := ColorRect.new()
	bg.color = Color("33424a")
	bg.size = holder.size
	holder.add_child(bg)
	var picks := {"blade":["W04","D02"], "blunt":["W05","D01"], "polearm":["W12","D04"], "gun":["W08","D01"], "staff":["W25","D13"]}
	var figures := {}
	var x := 0
	for family in picks:
		figures[family] = _figure(holder, items, picks[family], x, 0)
		x += 240
	# Same family at tiers 1..5 to show the tint.
	x = 0
	for id in ["W04","W14","W21","W24","W16"]:
		_figure(holder, items, [id, "D02"], x, 380)
		x += 240
	await create_timer(0.6).timeout
	await _shot(output, "families_and_tiers")
	for clip in ["shoot", "cast", "heal", "buff"]:
		var hero: Hero3D = figures["gun" if clip == "shoot" else "blade"]
		hero.perform(clip)
		await create_timer(Hero3D.CONTACT[Hero3D.ACTIONS[clip][0]] / Hero3D.ACTIONS[clip][1]).timeout
		await _shot(output, "clip_" + clip)
		await create_timer(1.5).timeout
	print("weapon captures done")
	quit(0)

func _figure(parent: Control, items: Array, ids: Array, x: int, y: int) -> Hero3D:
	var hero := Hero3D.new()
	hero.set_equipment({"weapon":ids[0], "shield":ids[1]}, items)
	hero.position = Vector2(x, y)
	hero.size = Vector2(240, 380)
	parent.add_child(hero)
	return hero

func _shot(output: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	Captures.frame(root).save_png("%s/%s.png" % [output, label])
