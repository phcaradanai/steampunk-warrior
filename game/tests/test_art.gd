extends RefCounted

func run(t) -> bool:
	if not FileAccess.file_exists("res://art/actor_art.gd"):
		t.check(false,"original actor art must render isolated silhouettes")
		return true
	var art = load("res://art/actor_art.gd")
	var regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/characters/regions.json"))
	t.check(regions.size() == 32,"five heroes, nineteen enemies, six bosses and two helpers have art")
	for id in regions:
		var data: Dictionary = art.mesh(id)
		t.check(not data.is_empty() and data.polygon.size() > 3 and data.triangles.size() > 0,"triangulatable isolated cutout: " + id)
		if data.is_empty(): continue
		var bounds: Rect2 = data.bounds
		t.check(bounds.size.x > 100 and bounds.size.y > 100,"full body scale recorded: " + id)
		for point in data.polygon:
			if not bounds.grow(1).has_point(point):
				t.check(false,"mesh remains in its character bounds: " + id)
				break
	t.check(art.actor_id({"class_id":"C05","side":"player"}) == "C05" and art.actor_id({"definition_id":"B06","side":"enemy"}) == "B06","world and combat use stable content IDs for art")
	return true
