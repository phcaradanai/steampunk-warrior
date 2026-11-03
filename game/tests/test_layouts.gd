extends RefCounted

func run(t) -> bool:
	if not FileAccess.file_exists("res://world/room_layout.gd"):
		t.check(false,"twelve rooms need distinct reachable layouts")
		return true
	var layout = load("res://world/room_layout.gd")
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var session := GameSession.new(catalog.data)
	session.new_game("C01")
	var signatures: Dictionary = {}
	for room in catalog.data.rooms:
		session.state.room_id = room.id
		var view := WorldView.new()
		view.configure(catalog.data,session.snapshot())
		var signature: String = str(view.walls)
		t.check(not signatures.has(signature),"distinct spatial layout: "+room.id)
		signatures[signature] = true
		# The hub floor starts below its painted back wall, so flood from the spawn point there.
		var start := Vector2i(30,22) if view.oblique else Vector2i(6,14)
		var reachable: Array[Vector2] = layout.reachable(view.walls,10,start)
		for marker in view.markers:
			t.check(reachable.any(func(point):return point.distance_to(marker.position) <= 64),"reachable interaction: "+room.id+" "+marker.id)
		var wide: Array[Vector2] = layout.reachable(view.walls,48,start)
		# Oblique rooms: the walk between the left and right pipe mouths must fit a 96px body.
		var route: Array = [Vector2(231,340),Vector2(729,340)] if view.oblique else [Vector2(850,240)]
		t.check(route.all(func(goal): return wide.any(func(point):return point.distance_to(goal) < 24)),"primary route supports96px clearance: "+room.id)
		if view.oblique and not view.hub:
			var props: Array = layout.oblique().rooms[room.id].props
			var sprites := WorldView.prop_sprites(room.id)
			t.check(sprites.size() == props.size(),"every prop has a sprite entry: "+room.id)
			for i in mini(props.size(),sprites.size()):
				t.check(ResourceLoader.exists("res://art/environments/props/"+sprites[i].file),"prop sprite file exists: %s %d"%[room.id,i])
				var anchor: Node2D = view.get_node("Prop%d"%i)
				var rect: Array = props[i].rect
				t.check(view.y_sort_enabled and anchor.get_parent() == view.player.get_parent() and is_equal_approx(anchor.position.y,rect[1]+rect[3]),"prop foot line is its front edge: %s %d"%[room.id,i])
				# Circle radius 10: a hero walking behind has feet y <= rect.y-10, in front >= rect bottom+10.
				t.check(rect[1]-10.0 < anchor.position.y and rect[1]+rect[3]+10.0 > anchor.position.y,"hero behind sorts behind, in front sorts in front: %s %d"%[room.id,i])
		view.free()
	return true
