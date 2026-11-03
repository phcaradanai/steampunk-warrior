extends SceneTree
# Real-renderer contact sheet of every 3D figure in Roster3D. Output dir: env CAPTURE_DIR.

func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1600,1000)
	var sheet := ColorRect.new()
	sheet.color = Color("2a3436")
	sheet.size = Vector2(1600,1000)
	root.add_child(sheet)
	var ids: Array = Roster3D.PEOPLE.keys() + Roster3D.CREATURES.keys()
	for i in ids.size():
		var figure := Roster3D.create(ids[i])
		figure.size = Vector2(150,150)
		figure.position = Vector2((i % 8) * 160, int(i / 8) * 175)
		figure.facing_left = i % 2 == 1
		sheet.add_child(figure)
		var label := Label.new()
		label.text = ids[i]
		label.position = figure.position + Vector2(55,145)
		sheet.add_child(label)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("CAPTURE_DIR") + "/roster.png")
	print("roster captured ", ids.size())
	quit(0)
