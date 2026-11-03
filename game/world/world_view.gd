class_name WorldView
extends Node2D

signal marker_selected(marker: Dictionary)
signal nearby_changed(marker: Dictionary)

var content: Dictionary
var progress: Dictionary
var room: Dictionary
var player: SteamPlayer
var markers: Array[Dictionary] = []
var nearby: Dictionary = {}
var blocked: bool = false
var font: Font = preload("res://art/fonts/NotoSansThai.ttf")
var walls: Array[Rect2] = []
var floors: Texture2D = preload("res://art/environments/floors.png")
var art: Texture2D
var rims: Sprite2D
var hub: bool = false
var oblique: bool = false
# Pipe mouths are painted at the same three wall spots in every room (prototypes/environments/build_backdrops.py).
const LEFT_PIPE := Vector2(231,300)
const CENTER_PIPE := Vector2(480,300)
const RIGHT_PIPE := Vector2(729,300)
const HUB_PIPES := {"R02":LEFT_PIPE,"P01":CENTER_PIPE,"P02":RIGHT_PIPE}
# Wall valve wheels beside the left pipe and beside the centre (tram) or right pipe.
const VALVES := [Vector2(328,300),Vector2(569,300),Vector2(810,300)]
const HUB_FLOOR := 262.0
# Logical room is 960x480; the screen shows it at this scale with the art running past both sides.
const VIEW_SCALE := 520.0/480.0
# Full-screen play: the room is drawn at this scale and the view pans to keep the hero in frame.
const FULL_SCALE := 720.0/480.0
var follow: bool = false

func configure(catalog: Dictionary, session: Dictionary, spawn: String = "entry") -> void:
	content = catalog
	progress = session
	for candidate in content.rooms:
		if candidate.id == progress.room_id:
			room = candidate
	hub = not room.get("pipes", []).is_empty()
	var art_path := "res://art/environments/hub.png" if hub else "res://art/environments/room_%s.png" % room.id
	oblique = ResourceLoader.exists(art_path)
	walls = RoomLayout.oblique_walls(room.id) if oblique else RoomLayout.walls(room.id)
	if oblique: art = load(art_path)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for rect in walls:
		var body := StaticBody2D.new()
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		body.position = rect.position + rect.size * 0.5
		body.add_child(collision)
		add_child(body)
	player = SteamPlayer.new()
	player.class_id = progress.player.class_id
	player.hero.set_equipment(progress.player.get("equipment",{}),content.items)
	player.position = Vector2(850,240) if spawn == "right" else Vector2(110,240)
	if hub: player.position = HUB_PIPES.R02 + Vector2(0,40) if spawn == "left" else Vector2(480,410)
	elif oblique: player.position = (RIGHT_PIPE if spawn == "right" else LEFT_PIPE) + Vector2(0,40)
	player.depth_scaled = oblique
	add_child(player)
	for exit in room.exits:
		var right: bool = int(exit.to.substr(1)) > int(room.id.substr(1))
		var at := Vector2(900,240) if right else Vector2(60,240)
		var pipe_at: Vector2 = HUB_PIPES.get(exit.to,at) if hub else (RIGHT_PIPE if right else LEFT_PIPE) if oblique else at
		markers.append({"kind":"exit","id":exit.to,"label":"ท่อไป " + _room_name(exit.to),"name":("ท่อไป " if hub else "→ " if right else "← ") + _room_name(exit.to),"position":pipe_at})
	var policy := WorldController.new(content)
	for line in room.get("pipes", []):
		var detail := policy.pipe(line.id)
		var next := policy.pipe_next(detail, progress)
		var stage: int = line.encounters.find(next) + 1
		var text: String = line.name + " · " + line.line
		if not policy.pipe_open(detail, progress):
			text += " · ปิด: ผ่าน " + _encounter_name(line.requires) + " ก่อน"
		else:
			text += " · ระดับ %d/%d · ถัดไป: %s" % [stage, line.encounters.size(), _encounter_name(next)]
		markers.append({"kind":"pipe","id":line.id,"label":text,"name":line.name,"position":HUB_PIPES.get(line.id,Vector2(480,300)),"encounter":next})
	var npc_slots: Array[Vector2] = [Vector2(330,360),Vector2(630,360),Vector2(200,330),Vector2(760,330)]
	for npc in content.story.npcs:
		if room.id in npc.get("rooms", [npc.room]):
			var count: int = markers.filter(func(m): return m.kind == "npc").size()
			markers.append({"kind":"npc","id":npc.id,"label":npc.name,"position":npc_slots[count%4] if hub else Vector2(300 + count*145,140)})
	for quest in content.story.quests:
		if quest.room == room.id:
			markers.append({"kind":"objective","id":quest.object_id,"label":quest.object_name,"position":Vector2(420,100)})
	var valve_count := 0
	for id in WorldController.ENVIRONMENT:
		var valve: Dictionary = WorldController.ENVIRONMENT[id]
		if valve.room == room.id:
			markers.append({"kind":"environment","id":id,"label":valve.label,"position":Vector2(220+valve_count*470,80)})
			valve_count += 1
	var slots: Array[Vector2] = [Vector2(320,300),Vector2(500,350),Vector2(680,285),Vector2(800,380),Vector2(820,155)]
	var index := 0
	for encounter in content.encounters:
		if encounter.room == room.id:
			markers.append({"kind":"encounter","id":encounter.id,"label":encounter.name,"position":slots[index],"boss":not encounter.boss_id.is_empty(),"actor_id":encounter.enemies[0]})
			index += 1
	if room.id == "R01":
		markers.append({"kind":"rest","id":"rest","label":"พักเต็มพลัง ฟรี","position":Vector2(110,430) if hub else Vector2(450,350)})
		markers.append({"kind":"training","id":"training","label":"โรงฝึกหม้อน้ำ","position":Vector2(860,430) if hub else Vector2(640,145)})
	if oblique:
		rims = Sprite2D.new()
		rims.texture = load(art_path.replace(".png","_rims.png"))
		rims.centered = false
		rims.position = Vector2(-120,0)/VIEW_SCALE
		rims.scale = Vector2.ONE*1280.0/rims.texture.get_width()/VIEW_SCALE
		rims.z_index = 2
		rims.visible = false
		add_child(rims)
	if room.id in ["R02","R05","R07","R09","R11"]:
		markers.append({"kind":"shop","id":"shop","label":"ร้านอุปกรณ์","position":Vector2(620,405)})
	if room.fast_travel and room.id != "R01":
		markers.append({"kind":"fast_travel","id":"R01","label":"รถรางกลับโรงซ่อม","name":"รถรางกลับโรงซ่อม","position":CENTER_PIPE if oblique else Vector2(200,400)})
	if oblique and not hub: _place_on_floor()
	_spawn_figures()
	queue_redraw()

# People, foes and props stand in the room as 3D figures, y-sorted with the player.
func _spawn_figures() -> void:
	y_sort_enabled = true
	for marker in markers:
		var key: String = {"npc":marker.id,"encounter":marker.get("actor_id",""),"training":"dummy","rest":"rest","shop":"shop","objective":"objective"}.get(marker.kind,"")
		if not Roster3D.has(key): continue
		var figure := Roster3D.create(key)
		var side := 120.0 if marker.get("boss",false) else 96.0
		figure.size = Vector2(side,side)
		figure.position = Vector2(-side*0.5,-side*0.925)
		figure.pivot_offset = Vector2(side*0.5,side*0.925)
		figure.facing_left = marker.kind == "encounter" or marker.position.x > 480
		if oblique: figure.scale = Vector2.ONE*SteamPlayer.depth_scale(marker.position.y)
		var anchor := Node2D.new()
		anchor.position = marker.position
		anchor.add_child(figure)
		add_child(anchor)
		marker["figure"] = anchor
	_tint_cleared()

func _tint_cleared() -> void:
	for marker in markers:
		if marker.has("figure") and marker.kind == "encounter":
			marker.figure.modulate = Color(0.65,0.75,0.65,0.65) if progress.get("first_clears",{}).has(marker.id) else Color.WHITE

# Oblique rooms reuse the content order above but put each marker on a painted floor slot or wall valve.
func _place_on_floor() -> void:
	var slots: Array = RoomLayout.oblique().slots
	var next_slot := 0
	var valve := 0
	for marker in markers:
		if marker.kind in ["exit","fast_travel","pipe"]: continue
		if marker.kind == "environment":
			marker.position = VALVES[valve] if valve == 0 or room.fast_travel else VALVES[2]
			valve += 1
			continue
		while next_slot < slots.size() - 1 and walls.slice(4).any(func(rect): return _hides(rect,Vector2(slots[next_slot][0],slots[next_slot][1]))):
			next_slot += 1
		marker.position = Vector2(slots[next_slot][0],slots[next_slot][1])
		next_slot += 1

# Props are part of the backdrop, so nothing may stand on one or just behind it where it would draw on top.
func _hides(rect: Rect2, slot: Vector2) -> bool:
	return rect.grow(12).has_point(slot) or (absf(slot.x - rect.get_center().x) < 90 and slot.y < rect.position.y and rect.position.y - slot.y < 110)

func _encounter_name(id: String) -> String:
	for candidate in content.encounters:
		if candidate.id == id:
			return candidate.name
	return id

# Walk up the ramp, turn into the mouth and vanish behind the rim before the caller changes scene.
func enter_pipe(marker: Dictionary) -> void:
	blocked = true
	var mouth: Vector2 = marker.position
	var walk := create_tween()
	player.hero.moving = true
	player.hero.facing_left = mouth.x < player.position.x
	walk.tween_property(player,"position",mouth+Vector2(0,8),clampf(player.position.distance_to(mouth)/220.0,0.12,0.5))
	await walk.finished
	if is_instance_valid(rims): rims.visible = true
	player.hero.moving = false
	player.hero.perform("enter_pipe")
	var steam := CPUParticles2D.new()
	steam.position = mouth+Vector2(0,-30)
	steam.amount = 24
	steam.one_shot = true
	steam.explosiveness = 0.8
	steam.lifetime = 0.7
	steam.direction = Vector2.UP
	steam.spread = 70
	steam.initial_velocity_min = 40
	steam.initial_velocity_max = 110
	steam.scale_amount_min = 6
	steam.scale_amount_max = 12
	steam.color = Color(0.9,0.95,0.97,0.55)
	steam.z_index = 3
	add_child(steam)
	steam.emitting = true
	var inside := create_tween().set_parallel()
	inside.tween_property(player,"position",mouth+Vector2(0,-18),0.45).set_ease(Tween.EASE_IN)
	inside.tween_property(player,"modulate",Color(0.25,0.3,0.3,0.0),0.45).set_ease(Tween.EASE_IN)
	await inside.finished

func _room_name(id: String) -> String:
	for candidate in content.rooms:
		if candidate.id == id:
			return candidate.name
	return id

func refresh(session: Dictionary) -> void:
	progress = session
	if player != null: player.hero.set_equipment(progress.player.get("equipment",{}),content.items)
	_tint_cleared()
	queue_redraw()

func _process(_delta: float) -> void:
	if follow and player != null:
		# Keep the painted room covering the screen: art spans local x -110.8..1070.8.
		var target := clampf(640.0 - player.position.x*scale.x, 1280.0 - 1070.8*scale.x, 110.8*scale.x)
		position.x = lerpf(position.x, target, 0.15) if position.x != 0.0 else target

func _physics_process(_delta: float) -> void:
	if player == null:
		return
	player.blocked = blocked
	var closest: Dictionary = {}
	var distance := 64.0
	for marker in markers:
		var candidate := player.position.distance_to(marker.position)
		if candidate < distance:
			distance = candidate
			closest = marker
	if closest.get("id", "") != nearby.get("id", ""):
		nearby = closest
		nearby_changed.emit(nearby)
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not blocked and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		# The marker handler can remove this scene before the signal returns.
		activate_nearest()

func activate_nearest() -> void:
	if not blocked and not nearby.is_empty() and player.position.distance_to(nearby.position) <= 64.0:
		marker_selected.emit(nearby)

func _draw() -> void:
	var span := Rect2(Vector2(-120,0)/VIEW_SCALE,Vector2(1280,520)/VIEW_SCALE)
	if oblique:
		draw_texture_rect(art,span,false)
		_draw_markers()
		return
	var palette: Dictionary = {"hub":"27383b","canal":"243d3b","rail":"363632","garden":"294137","coal":"333337","foundry":"43332b","archive":"333c41","reactor":"234444"}
	draw_rect(span, Color(palette.get(room.get("palette", "hub"), "27383b")))
	var floor_index: int = {"hub":0,"canal":1,"rail":2,"garden":3,"coal":4,"foundry":4,"archive":5,"reactor":5}.get(room.get("palette","hub"),0)
	var cell := floors.get_size()/Vector2(2,3)
	# Recorded panel boundaries follow the generated source, not an assumed equal grid.
	var row_starts := [0.0,395.0,804.0]
	var row_ends := [395.0,804.0,1254.0]
	var row_index := floor_index/2
	var source := Rect2(Vector2((floor_index%2)*cell.x+3,row_starts[row_index]+3),Vector2(cell.x-6,row_ends[row_index]-row_starts[row_index]-6))
	draw_texture_rect_region(floors,span,source,Color(0.58,0.62,0.60))
	for rect in walls:
		draw_rect(rect,Color("17282b"))
		draw_rect(rect,Color("677361"),false,2)
		if rect.size.y > 16 and rect.size.x > 16:
			draw_rect(rect.grow(-5),Color("584b37"))
			for y in range(int(rect.position.y)+10,int(rect.end.y)-4,12):
				draw_line(Vector2(rect.position.x+6,y),Vector2(rect.end.x-6,y),Color("8d7447"),2)
		for x in range(int(rect.position.x)+8,int(rect.end.x),24):
			draw_circle(Vector2(x,rect.position.y+6),2,Color("b18b55"))
	_draw_markers()

static var _badge_icons: Dictionary = {}

# The room draws with mipmapped filtering for its large backdrop, so badge icons need mipmaps of their own.
static func _badge_icon(name: String) -> Texture2D:
	if not _badge_icons.has(name):
		var image: Image = load("res://art/icons/%s.svg" % name).get_image()
		image.decompress()
		image.generate_mipmaps()
		_badge_icons[name] = ImageTexture.create_from_image(image)
	return _badge_icons[name]

static func marker_icon(marker: Dictionary) -> String:
	if marker.kind == "exit": return "exit_right" if marker.get("name","").begins_with("→") else "exit_left"
	return {"pipe":"fight","fast_travel":"travel","npc":"talk","encounter":"fight","environment":"valve","objective":"objective","rest":"rest","training":"train","shop":"shop"}.get(marker.kind,"hand")

# Mobile style: every interactable wears a small picture badge; its words appear only when the hero is close.
func _draw_badge(marker: Dictionary, point: Vector2) -> void:
	var near: bool = marker.id == nearby.get("id","")
	var height := 0.55 if marker.kind in ["rest","shop","objective"] else 0.9
	var lift := 210.0 if marker.kind in ["exit","pipe","fast_travel"] else 78.0 if marker.kind == "environment" else 96.0*height*SteamPlayer.depth_scale(point.y)*(1.25 if marker.get("boss",false) else 1.0) + 8.0
	if near: draw_ellipse(point+Vector2(0,10),46,12,Color(1,0.85,0.5,0.35))
	var badge := point - Vector2(0,lift)
	var radius := 17.0 if near else 13.0
	var cleared: bool = marker.kind == "encounter" and progress.get("first_clears",{}).has(marker.id)
	draw_circle(badge,radius,Color(0.04,0.08,0.09,0.85))
	draw_arc(badge,radius,0,TAU,32,Color("f1d9a0") if near else Color("678e78") if cleared else Color("b89a5e"),2.0)
	if marker.kind == "environment":
		draw_circle(badge+Vector2(radius*0.8,-radius*0.8),4,Color("80e0a8") if progress.world_flags.get("environment:"+marker.id,false) else Color("e0a050"))
	var icon := _badge_icon(marker_icon(marker))
	draw_texture_rect(icon,Rect2(badge-Vector2.ONE*radius*0.72,Vector2.ONE*radius*1.44),false)
	if near:
		var text: String = marker.get("name",marker.label) if marker.kind in ["exit","pipe","fast_travel"] else marker.label
		var width := 300.0
		draw_rect(Rect2(badge+Vector2(-width*0.5,-radius-30),Vector2(width,24)),Color(0.04,0.08,0.09,0.8))
		draw_string(font,badge+Vector2(-width*0.5,-radius-12),text,HORIZONTAL_ALIGNMENT_CENTER,width,15,Color("f1d9a0"))

func _draw_markers() -> void:
	for marker in markers:
		var point: Vector2 = marker.position
		var color := Color("c2a66c")
		if marker.kind == "encounter":
			color = Color("cf846b") if marker.get("boss",false) else Color("a78069")
			if progress.get("first_clears",{}).has(marker.id):
				color = Color("678e78")
		elif marker.kind in ["rest","objective"]:
			color = Color("80b4a5")
		if oblique:
			_draw_badge(marker, point)
			continue
		# Oblique rooms are seen from further back, so floor markers draw larger around their own point.
		var k := 1.5 if oblique else 1.0
		draw_set_transform(point*(1.0-k),0,Vector2(k,k))
		if marker.id == nearby.get("id", ""):
			draw_arc(point,27,0,TAU,32,Color("f1d9a0"),2)
		if marker.has("figure"):
			pass
		elif marker.kind == "npc":
			ActorArt.paint(self,marker.id,point+Vector2(0,18),64 if oblique else 54)
		elif marker.kind == "encounter":
			draw_ellipse(point+Vector2(0,15),21,7,color.darkened(0.5))
			ActorArt.paint(self,marker.actor_id,point+Vector2(0,18),64 if marker.boss else 48,true,Color(0.65,0.75,0.65,0.65) if progress.get("first_clears",{}).has(marker.id) else Color.WHITE)
		elif marker.kind == "environment":
			var enabled: bool = progress.world_flags.get("environment:"+marker.id,false)
			var brass := Color("80c8a8") if enabled else Color("d1a357")
			draw_line(point+Vector2(0,12),point+Vector2(0,25),Color("79674e"),9)
			draw_circle(point,18,Color("213536"))
			draw_arc(point,16,0,TAU,32,brass,3)
			for i in range(4):
				var angle: float = i*PI*0.5+(0.7 if enabled else 0)
				draw_line(point,point+Vector2.from_angle(angle)*15,brass,3)
			draw_circle(point,5,brass)
		elif marker.kind in ["exit","fast_travel"]:
			# Rooms connect through pipe mouths instead of doors.
			draw_circle(point+Vector2(0,-6),24,Color("0d1416"))
			draw_arc(point+Vector2(0,-6),24,0,TAU,32,color,5)
			for i in range(8):
				draw_circle(point+Vector2(0,-6)+Vector2.from_angle(i*TAU/8)*24,2,color.lightened(0.3))
		elif marker.kind == "training":
			draw_line(point+Vector2(0,-18),point+Vector2(0,18),Color("9b7950"),7)
			draw_line(point+Vector2(-20,-5),point+Vector2(20,-5),Color("9b7950"),6)
			draw_circle(point+Vector2(0,-23),9,Color("bd9456"))
			draw_circle(point,10,Color("374c4c"))
			draw_arc(point,7,0,TAU,24,Color("d9b574"),2)
		elif marker.kind == "rest":
			draw_rect(Rect2(point-Vector2(25,12),Vector2(50,28)),Color("9c7b4c"))
			draw_rect(Rect2(point-Vector2(21,9),Vector2(42,19)),Color("47736b"))
			draw_rect(Rect2(point-Vector2(18,7),Vector2(12,15)),Color("c8c1a2"))
		elif marker.kind == "shop":
			draw_rect(Rect2(point-Vector2(24,14),Vector2(48,28)),Color("947449"))
			draw_rect(Rect2(point-Vector2(29,23),Vector2(58,10)),Color("4c8c81"))
			for x in [-15,15]: draw_circle(point+Vector2(x,17),7,Color("233438"))
			draw_line(point+Vector2(-16,-5),point+Vector2(16,-5),Color("d9b574"),3)
		else:
			draw_circle(point,14,color.darkened(0.4))
			draw_arc(point,14,0,TAU,24,color,3)
			draw_line(point-Vector2(6,0),point+Vector2(6,0),color,3)
		# Oblique rooms label above the head so names never fall under the bottom bar.
		draw_string(font, point+Vector2(-70,(-100 if marker.has("figure") else -74) if oblique else 43),marker.label,HORIZONTAL_ALIGNMENT_CENTER,140,14,Color("e6dfc9"))
		draw_set_transform(Vector2.ZERO)
