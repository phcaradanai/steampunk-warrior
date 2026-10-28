extends Node2D

var clock := 0.0
var speed := 1.0
var mode := "idle"
var mood := 0
var facing := 1.0
var gear := [0, 0, 0, 0]
var paused := false
var action_time := 0.0
var status: Label
var outline := Color("101b20")
var brass := Color("bd9254")
var steel := Color("738d99")
var cream := Color("e2d5b7")
var anim: Tween
var strike := 0.0
var recoil := 0.0
var keyboard_walk := false

func _ready() -> void:
	var theme := Theme.new()
	theme.default_font = load("res://NotoSansThai.ttf")
	theme.default_font_size = 17
	var ui := Control.new()
	ui.theme = theme
	add_child(ui)
	var title := Label.new()
	title.text = "VESPER  /  CHARACTER ATELIER"
	title.position = Vector2(42, 24)
	title.add_theme_font_size_override("font_size", 27)
	title.modulate = cream
	ui.add_child(title)
	var sub := Label.new()
	sub.text = "ต้นแบบ 01 · นักรบไอน้ำ  |  ทดลองท่าทางและเครื่องแต่งกาย"
	sub.position = Vector2(42, 68)
	ui.add_child(sub)
	var panel := VBoxContainer.new()
	panel.position = Vector2(842, 120)
	panel.size = Vector2(322, 610)
	panel.add_theme_constant_override("separation", 12)
	ui.add_child(panel)
	var intro := Label.new()
	intro.text = "แต่งตัวระหว่างเคลื่อนไหวได้"
	intro.modulate = cream
	panel.add_child(intro)
	var names := [["อาวุธ", "ดาบฟันเฟือง", "ค้อนลูกสูบ", "กระบี่ช่าง"], ["ศีรษะ", "แว่นช่าง", "หมวกเกราะ", "หน้ากากกรองไอ"], ["ชุด", "เสื้อช่างหนัง", "เกราะทองเหลือง", "เสื้อคลุมกรมท่า"], ["โล่", "ไม่มีโล่", "โล่หม้อน้ำ", "โล่กลมทองเหลือง"]]
	for slot in 4:
		var label := Label.new()
		label.text = names[slot][0]
		panel.add_child(label)
		var select := OptionButton.new()
		select.custom_minimum_size.y = 40
		for item in names[slot].slice(1): select.add_item(item)
		select.item_selected.connect(func(index): gear[slot] = index; queue_redraw())
		panel.add_child(select)
	var emotion := OptionButton.new()
	for item in ["บุคลิก · สงบมั่นใจ", "บุคลิก · พร้อมสู้", "บุคลิก · เหนื่อยล้า"]: emotion.add_item(item)
	emotion.item_selected.connect(func(index): mood = index)
	panel.add_child(emotion)
	var tempo := HSlider.new()
	tempo.min_value = 0.25
	tempo.max_value = 1.5
	tempo.step = 0.05
	tempo.value = 1.0
	tempo.custom_minimum_size.y = 30
	tempo.value_changed.connect(func(value): speed = value)
	var tempo_label := Label.new()
	tempo_label.text = "ความเร็วท่า  0.25× — 1.5×"
	panel.add_child(tempo_label)
	panel.add_child(tempo)
	var controls := HBoxContainer.new()
	controls.position = Vector2(40, 665)
	controls.add_theme_constant_override("separation", 8)
	ui.add_child(controls)
	for entry in [["ยืน", "idle"], ["เดิน", "walk"], ["โจมตี", "attack"], ["รับแรง", "hit"], ["ป้องกัน", "guard"]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(105, 44)
		button.pressed.connect(func(): set_mode(entry[1]))
		controls.add_child(button)
	var flip := Button.new()
	flip.text = "กลับด้าน"
	flip.pressed.connect(func(): facing *= -1)
	controls.add_child(flip)
	var pause := Button.new()
	pause.text = "หยุด / เล่น"
	pause.pressed.connect(func(): paused = not paused; if anim: anim.pause() if paused else anim.play())
	controls.add_child(pause)
	status = Label.new()
	status.position = Vector2(42, 723)
	status.text = "A / D เดิน · Space โจมตี · H รับแรง · G ป้องกัน · เปลี่ยนชุดทางขวา"
	ui.add_child(status)

func set_mode(next: String) -> void:
	if anim: anim.kill()
	strike = 0
	recoil = 0
	paused = false
	mode = next
	if next == "attack":
		anim = create_tween()
		anim.tween_property(self, "strike", -0.6, 0.23)
		anim.tween_property(self, "strike", 1.0, 0.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		anim.tween_interval(0.10)
		anim.tween_property(self, "strike", 0.0, 0.36)
		anim.tween_callback(func(): mode = "idle")
	elif next == "hit":
		anim = create_tween()
		anim.tween_property(self, "recoil", 1.0, 0.09)
		anim.tween_property(self, "recoil", 0.0, 0.55)
		anim.tween_callback(func(): mode = "idle")

func _unhandled_key_input(event: InputEvent) -> void:
	if event.keycode in [KEY_A, KEY_D] and not event.is_pressed() and keyboard_walk:
		if not Input.is_physical_key_pressed(KEY_A) and not Input.is_physical_key_pressed(KEY_D):
			keyboard_walk = false
			set_mode("idle")
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_SPACE: set_mode("attack")
	if event.keycode == KEY_H: set_mode("hit")
	if event.keycode == KEY_G: set_mode("guard")

func _process(delta: float) -> void:
	if anim: anim.set_speed_scale(speed)
	if not paused:
		clock += delta * speed
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_D):
			keyboard_walk = true
			if mode != "walk": set_mode("walk")
			facing = -1.0 if Input.is_physical_key_pressed(KEY_A) else 1.0
	queue_redraw()

func poly(points: Array, color: Color) -> void:
	var p := PackedVector2Array(points)
	draw_colored_polygon(p, color)
	p.append(p[0])
	draw_polyline(p, outline, 1.6, true)

func limb(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	draw_line(a, b, outline, width + 3, true)
	draw_line(a, b, color, width, true)
	draw_circle(a, width * 0.5, color)

func joint_between(start: Vector2, end: Vector2, length: float, bend: float) -> Vector2:
	var delta := end-start
	var distance := clampf(delta.length(),0.01,length*2-0.01)
	var direction := delta.normalized()
	return start+direction*distance*0.5+Vector2(-direction.y,direction.x)*sqrt(maxf(0,length*length-distance*distance*0.25))*bend

func ellipse_points(center: Vector2, rx: float, ry: float) -> Array:
	var points := []
	for i in 32: points.append(center+Vector2(cos(i*TAU/32)*rx,sin(i*TAU/32)*ry))
	return points

func gait_foot(phase: float) -> Vector2:
	return Vector2(cos(phase)*18, -maxf(0,-sin(phase))*12)

func _draw() -> void:
	# This is an isolated appearance study; the live game and its saves are never loaded.
	draw_rect(Rect2(24, 110, 790, 535), Color("15252b"))
	for x in range(65, 815, 100):
		draw_line(Vector2(x, 112), Vector2(x, 460), Color("20353b"), 2)
	for y in [160, 440]:
		draw_line(Vector2(25,y), Vector2(813,y), Color("304047"), 8)
		for x in range(55, 815, 80): draw_circle(Vector2(x,y), 3, brass.darkened(0.5))
	draw_rect(Rect2(25, 465, 788, 180), Color("1d3035"))
	for x in range(-200, 1100, 110): draw_line(Vector2(420 + (x-420)*0.6,465),Vector2(x,645),Color("354449"),1)
	for y in [495, 535, 590, 640]: draw_line(Vector2(25,y),Vector2(813,y),Color("354449"),1)
	draw_arc(Vector2(180,315),110,0,TAU,64,Color("30464b"),18,true)
	draw_arc(Vector2(180,315),98,0,TAU,64,Color("0d1c21"),10,true)
	for i in 10:
		var p := Vector2(180,315) + Vector2.from_angle(i*TAU/10)*110
		draw_circle(p,4,brass.darkened(0.55))
	for i in 5:
		var y := fmod(clock * 18 + i * 39, 190)
		draw_circle(Vector2(680 + sin(clock+i)*12,430-y), 9+i*2, Color(0.5,0.67,0.69,0.035))
	draw_set_transform(Vector2(432,573),0,Vector2(1,0.22))
	draw_circle(Vector2.ZERO,88,Color(0,0,0,0.32))
	draw_set_transform(Vector2(432,563),0,Vector2(2.6*facing,2.6))
	var cycle := clock * 6.0
	var walk := 1.0 if mode == "walk" else 0.0
	var bob := sin(clock*2.5)*(1.2 if mood != 2 else 2.2) - absf(sin(cycle))*2*walk
	var hip := Vector2(-recoil*7, -53 + bob)
	var shoulder := hip + Vector2(3 + strike*8-recoil*10 + (5 if mood==2 else 0), -49)
	var suit: Color = [Color("80533c"), Color("a8844c"), Color("304d67")][gear[2]]
	# Far limbs are rendered first so hands and equipment share the same joint positions.
	for side in [-1,1]:
		var swing := sin(cycle + (PI if side == -1 else 0))*walk
		var leg_root := hip + Vector2(side*3,0)
		var foot := gait_foot(cycle+(PI if side==-1 else 0))*walk+Vector2(side*7*(1-walk),0)
		var knee := joint_between(leg_root,foot-Vector2(1,5),28,-1)
		limb(leg_root,knee,12,suit.darkened(0.22 if side==-1 else 0))
		limb(knee,foot-Vector2(1,5),10,Color("35454b"))
		draw_circle(knee,5,brass)
		poly([foot+Vector2(-7,-7),foot+Vector2(5,-7),foot+Vector2(12,-2),foot+Vector2(11,2),foot+Vector2(-7,2)],Color("293237"))
	var back_hand := shoulder+Vector2(-37+cos(cycle)*4*walk,38 - (12 if mode == "guard" else 0))
	var back_root := shoulder-Vector2(18,-2)
	var back_elbow := joint_between(back_root,back_hand,24,1)
	limb(back_root,back_elbow,11,suit.darkened(0.3))
	limb(back_elbow,back_hand,9,steel.darkened(0.3))
	if gear[3] > 0:
		var center := back_hand+Vector2(-9,14)
		if gear[3] == 1:
			poly([center+Vector2(-13,-22),center+Vector2(13,-22),center+Vector2(15,13),center+Vector2(0,25),center+Vector2(-15,13)],steel.darkened(0.2))
			for y in [-12,-4,4,12]: draw_line(center+Vector2(-9,y),center+Vector2(9,y),brass,2)
		else:
			poly(ellipse_points(center,15,22),outline)
			poly(ellipse_points(center,13,20),brass)
			poly(ellipse_points(center,9,14),steel.darkened(0.4))
			draw_circle(center,6,brass.lightened(0.2))
	draw_circle(back_root,7,steel.darkened(0.2))
	if gear[2] == 2:
		poly([shoulder+Vector2(-16,8),hip+Vector2(-22+sin(clock*3)*3,27),hip+Vector2(10,20),shoulder+Vector2(13,8)],suit.darkened(0.25))
	poly([shoulder+Vector2(-16,-4),shoulder+Vector2(15,-2),hip+Vector2(13,2),hip+Vector2(-14,2)],suit)
	limb(shoulder+Vector2(-10,0),hip+Vector2(9,-1),4,Color("352b29"))
	for y in [12,23,34]: draw_circle(shoulder+Vector2(6,y),1.8,brass.lightened(0.2))
	poly([hip+Vector2(-16,-7),hip+Vector2(15,-7),hip+Vector2(15,0),hip+Vector2(-16,0)],Color("332a26"))
	draw_rect(Rect2(hip+Vector2(-3,-8),Vector2(8,9)),brass)
	var head := shoulder+Vector2(2,-21)
	limb(shoulder,head,10,Color("b98c6b"))
	poly([head+Vector2(-11,-14),head+Vector2(8,-15),head+Vector2(14,-3),head+Vector2(10,12),head+Vector2(-7,11),head+Vector2(-12,0)],Color("c49a78"))
	poly([head+Vector2(-12,-4),head+Vector2(-13,-15),head+Vector2(6,-19),head+Vector2(12,-10),head+Vector2(1,-10),head+Vector2(-5,-4)],Color("302b2b"))
	if gear[1] == 0:
		limb(head+Vector2(-11,-8),head+Vector2(11,-8),4,brass)
		for x in [-1,9]:
			draw_circle(head+Vector2(x,-8),5,outline)
			draw_circle(head+Vector2(x,-8),3.4,Color("75c9cd"))
	elif gear[1] == 1:
		poly([head+Vector2(-14,-3),head+Vector2(-13,-17),head+Vector2(4,-22),head+Vector2(14,-13),head+Vector2(16,-1)],steel)
		limb(head+Vector2(-15,-3),head+Vector2(16,-3),4,brass)
	else:
		poly([head+Vector2(-5,1),head+Vector2(15,0),head+Vector2(14,12),head+Vector2(-4,12)],steel.darkened(0.25))
		draw_circle(head+Vector2(12,7),6,brass)
		draw_circle(head+Vector2(12,7),3,outline)
	draw_line(head+Vector2(5,-1),head+Vector2(11,-2 if mood==1 else 0),outline,2)
	var arm_root := shoulder+Vector2(15,4)
	var elbow := arm_root+Vector2(12 + strike*20,23-strike*28)
	var hand := arm_root+Vector2(17 + strike*38,41-strike*39)
	if mode == "walk":
		elbow.x -= sin(cycle)*10
		hand.x -= cos(cycle)*10
	if mode == "guard":
		elbow = arm_root+Vector2(18,12)
		hand = arm_root+Vector2(30,-6)
	if mood == 1 and mode == "idle": hand += Vector2(8,-12)
	hand = arm_root+(hand-arm_root).limit_length(47.5)
	elbow = joint_between(arm_root,hand,24,1)
	limb(arm_root,elbow,13,suit)
	draw_circle(arm_root,9,brass if gear[2]==1 else steel)
	draw_circle(arm_root,3,outline)
	limb(elbow,hand,10,steel)
	draw_circle(elbow,5,brass)
	var angle := 0.35 + strike*1.1
	if mode == "guard": angle = -0.35
	var tip := hand + Vector2.from_angle(angle-PI/2)*58
	limb(hand+Vector2.from_angle(angle-PI/2)*-8,hand+Vector2.from_angle(angle-PI/2)*12,4,Color("45332b"))
	var axis := (tip-hand).normalized()
	var normal := axis.orthogonal()
	if gear[0] == 1:
		limb(hand,tip,5,brass)
		poly([tip+normal*17-axis*8,tip-normal*17-axis*8,tip-normal*17+axis*9,tip+normal*17+axis*9],steel)
		draw_circle(tip,5,brass)
	else:
		var width := 7.0 if gear[0]==0 else 3.5
		poly([hand+axis*12+normal*width,tip+axis*9,tip-normal*width,hand+axis*12-normal*width],Color("b5c8cd"))
		draw_line(hand+axis*15,tip,Color("edf4e8"),1.4,true)
		limb(hand+axis*10-normal*11,hand+axis*10+normal*11,3,brass)
	draw_circle(hand,5,Color("44382d"))
	draw_set_transform(Vector2.ZERO)
