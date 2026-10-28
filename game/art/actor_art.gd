class_name ActorArt
extends RefCounted

static var _cache: Dictionary = {}
static var _sheets: Dictionary = {}
static var _regions: Dictionary = {}
const NPC_ACTORS := {"NPC01":"N14","NPC02":"C04","NPC03":"N17","NPC04":"N10","NPC05":"C05","NPC06":"N13","NPC07":"N18","NPC08":"C03"}

static func actor_id(actor: Dictionary) -> String:
	return actor.get("class_id","C01") if actor.get("side","") == "player" else actor.get("definition_id","N10")

static func mesh(id: String) -> Dictionary:
	id = NPC_ACTORS.get(id,id)
	if _cache.has(id): return _cache[id]
	if _regions.is_empty():
		_regions = JSON.parse_string(FileAccess.get_file_as_string("res://art/characters/regions.json"))
	if not _regions.has(id): return {}
	var entry: Dictionary = _regions[id]
	if not _sheets.has(entry.sheet):
		var texture: Texture2D = load("res://art/characters/%s.png" % entry.sheet)
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(texture.get_image(),0.5)
		_sheets[entry.sheet] = {"texture":texture,"bitmap":bitmap}
	var sheet: Dictionary = _sheets[entry.sheet]
	var r: Array = entry.rect
	var bounds := Rect2(r[0],r[1],r[2],r[3])
	# Trace the source alpha in-engine: neighboring tails can overlap bounding rectangles.
	var polygons: Array[PackedVector2Array] = sheet.bitmap.opaque_to_polygons(Rect2i(bounds),0.45)
	var largest := PackedVector2Array()
	var area := 0.0
	for polygon in polygons:
		var candidate := 0.0
		for i in polygon.size():
			candidate += polygon[i].cross(polygon[(i+1)%polygon.size()])
		if absf(candidate) > area:
			area = absf(candidate)
			largest = polygon
	var uv := PackedVector2Array()
	for i in largest.size():
		largest[i] += bounds.position
	for point in largest:
		uv.append(point / sheet.texture.get_size())
	var result := {"polygon":largest,"uv":uv,"texture":sheet.texture,"bounds":bounds,"triangles":Geometry2D.triangulate_polygon(largest)}
	_cache[id] = result
	return result

static func paint(canvas: CanvasItem, id: String, foot: Vector2, height: float, mirror: bool = false, tint: Color = Color.WHITE) -> void:
	var data := mesh(id)
	if data.is_empty(): return
	var bounds: Rect2 = data.bounds
	var factor := height / bounds.size.y
	var points := PackedVector2Array()
	var anchor := bounds.position + Vector2(bounds.size.x * 0.5,bounds.size.y)
	for point in data.polygon:
		var offset: Vector2 = (point-anchor)*factor
		if mirror: offset.x *= -1.0
		points.append(foot+offset)
	canvas.draw_polygon(points,PackedColorArray([tint]),data.uv,data.texture)
