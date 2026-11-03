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
	_clip_smoothness(t)
	_item_icons(t)
	return true

# Every item maps to a real icon; within one slot and tier at most 2 items may share art.
func _item_icons(t) -> void:
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var groups := {}
	var collisions := 0
	for item in catalog.data.items:
		var stem: String = UIBuilder.item_icon_name(item)
		t.check(ResourceLoader.exists("res://art/icons/%s.svg" % stem) and stem != item.slot,"item icon resolves to a family file: " + item.id)
		t.check(UIBuilder.item_icon(item) != null,"item icon builds with tier pip: " + item.id)
		var key := "%s/%d/%s" % [item.slot,int(item.tier),stem]
		groups[key] = int(groups.get(key,0)) + 1
	for key in groups:
		if groups[key] > 1: collisions += groups[key] - 1
		t.check(groups[key] <= 2,"at most two items share an icon per slot and tier: " + key)
	print("Item icon collisions: ",collisions)
	var unique := {}
	for item in catalog.data.items: unique[UIBuilder.item_icon_name(item)] = true
	t.check(UIBuilder.item_icon_name({"id":"W26","slot":"weapon","name":"ปืนย้อนเฟส"}) == "W26" and UIBuilder.item_icon_name({"id":"A09","slot":"suit","name":"ชุดชีวกล"}) == "A09","W26 and A09 keep unique icons")
	print("Distinct item icons: ",unique.size())

# A joint turning past ~75 degrees between 1/30s keys reads as a snap or a spinning wrist on screen.
func _clip_smoothness(t) -> void:
	var model = load("res://art/characters/vesper_warrior.glb").instantiate()
	var animator: AnimationPlayer = model.get_node("AnimationPlayer")
	for clip in ["Attack","Skill_Stab","Skill_Steam","Guard","Hit","Down"]:
		var anim := animator.get_animation(clip)
		for track in anim.get_track_count():
			var bone := str(anim.track_get_path(track)).get_slice(":",1)
			if anim.track_get_type(track) != Animation.TYPE_ROTATION_3D or not bone in ["Shoulder_R","Elbow_R","Hand_R","WeaponMount","Shoulder_L","Elbow_L"]: continue
			var worst := 0.0
			for key in range(1, anim.track_get_key_count(track)):
				worst = maxf(worst, rad_to_deg((anim.track_get_key_value(track,key) as Quaternion).angle_to(anim.track_get_key_value(track,key-1))))
			t.check(worst <= 75.0, "smooth %s %s (worst %d deg per key)" % [clip, bone, worst])
	model.free()
