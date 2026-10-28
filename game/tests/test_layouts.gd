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
		var reachable: Array[Vector2] = layout.reachable(view.walls,10)
		for marker in view.markers:
			t.check(reachable.any(func(point):return point.distance_to(marker.position) <= 64),"reachable interaction: "+room.id+" "+marker.id)
		var wide: Array[Vector2] = layout.reachable(view.walls,48)
		t.check(wide.any(func(point):return point.distance_to(Vector2(850,240)) < 24),"primary route supports96px clearance: "+room.id)
		view.free()
	return true
