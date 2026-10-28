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

func configure(catalog: Dictionary, session: Dictionary, spawn: String = "entry") -> void:
	content = catalog
	progress = session
	for candidate in content.rooms:
		if candidate.id == progress.room_id:
			room = candidate
	walls = RoomLayout.walls(room.id)
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
	player.position = Vector2(850,240) if spawn == "right" else Vector2(110,240)
	add_child(player)
	for exit in room.exits:
		var right: bool = int(exit.to.substr(1)) > int(room.id.substr(1))
		markers.append({"kind":"exit","id":exit.to,"label":"ไป " + _room_name(exit.to),"position":Vector2(900,240) if right else Vector2(60,240)})
	for npc in content.story.npcs:
		if room.id in npc.get("rooms", [npc.room]):
			var count: int = markers.filter(func(m): return m.kind == "npc").size()
			markers.append({"kind":"npc","id":npc.id,"label":npc.name,"position":Vector2(300 + count*145,140)})
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
		markers.append({"kind":"rest","id":"rest","label":"พักเต็มพลัง ฟรี","position":Vector2(450,350)})
		markers.append({"kind":"training","id":"training","label":"โรงฝึกหม้อน้ำ","position":Vector2(640,145)})
	if room.id in ["R02","R05","R07","R09","R11"]:
		markers.append({"kind":"shop","id":"shop","label":"ร้านอุปกรณ์","position":Vector2(620,405)})
	if room.fast_travel and room.id != "R01":
		markers.append({"kind":"fast_travel","id":"R01","label":"รถรางกลับโรงซ่อม","position":Vector2(200,400)})
	queue_redraw()

func _room_name(id: String) -> String:
	for candidate in content.rooms:
		if candidate.id == id:
			return candidate.name
	return id

func refresh(session: Dictionary) -> void:
	progress = session
	queue_redraw()

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
	var palette: Dictionary = {"hub":"27383b","canal":"243d3b","rail":"363632","garden":"294137","coal":"333337","foundry":"43332b","archive":"333c41","reactor":"234444"}
	draw_rect(Rect2(0,0,960,480), Color(palette.get(room.get("palette", "hub"), "27383b")))
	var floor_index: int = {"hub":0,"canal":1,"rail":2,"garden":3,"coal":4,"foundry":4,"archive":5,"reactor":5}.get(room.get("palette","hub"),0)
	var cell := floors.get_size()/Vector2(2,3)
	# Recorded panel boundaries follow the generated source, not an assumed equal grid.
	var row_starts := [0.0,395.0,804.0]
	var row_ends := [395.0,804.0,1254.0]
	var row_index := floor_index/2
	var source := Rect2(Vector2((floor_index%2)*cell.x+3,row_starts[row_index]+3),Vector2(cell.x-6,row_ends[row_index]-row_starts[row_index]-6))
	draw_texture_rect_region(floors,Rect2(0,0,960,480),source,Color(0.58,0.62,0.60))
	for rect in walls:
		draw_rect(rect,Color("17282b"))
		draw_rect(rect,Color("677361"),false,2)
		if rect.size.y > 16 and rect.size.x > 16:
			draw_rect(rect.grow(-5),Color("584b37"))
			for y in range(int(rect.position.y)+10,int(rect.end.y)-4,12):
				draw_line(Vector2(rect.position.x+6,y),Vector2(rect.end.x-6,y),Color("8d7447"),2)
		for x in range(int(rect.position.x)+8,int(rect.end.x),24):
			draw_circle(Vector2(x,rect.position.y+6),2,Color("b18b55"))
	for marker in markers:
		var point: Vector2 = marker.position
		var color := Color("c2a66c")
		if marker.kind == "encounter":
			color = Color("cf846b") if marker.get("boss",false) else Color("a78069")
			if progress.get("first_clears",{}).has(marker.id):
				color = Color("678e78")
		elif marker.kind in ["rest","objective"]:
			color = Color("80b4a5")
		if marker.id == nearby.get("id", ""):
			draw_arc(point,27,0,TAU,32,Color("f1d9a0"),2)
		if marker.kind == "npc":
			ActorArt.paint(self,marker.id,point+Vector2(0,18),54)
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
			draw_rect(Rect2(point-Vector2(17,25),Vector2(34,50)),color.darkened(0.6))
			draw_rect(Rect2(point-Vector2(17,25),Vector2(34,50)),color,false,2)
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
		draw_string(font, point+Vector2(-70,43),marker.label,HORIZONTAL_ALIGNMENT_CENTER,140,14,Color("e6dfc9"))
