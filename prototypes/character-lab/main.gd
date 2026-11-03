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
var walk_dir := Vector2.ZERO
var actor_pos := Vector2(400, 563)
var combat_origin_x := 400.0
var attack_phase := "none"
var approach_progress := 0.0
var pipe_progress := 0.0
var skill_kind := 0
var skill_burst := 0.0
var float_Timer := 0.0
var float_text := ""
var float_pos := Vector2.ZERO
var float_color := Color("75c9cd")
var dummy_recoil := 0.0
var pipe_center := Vector2(180, 315)
var pipe_floor := Vector2(180, 492)

# 3D Blender viewport & rig references
var viewport_3d: SubViewport
var vesper_root: Node3D
var vesper_skel: Skeleton3D
var dummy_skel: Skeleton3D
var rig_nodes := {}
var suit_Dynamic_meshes: Array[MeshInstance3D] = []
var pauldron_r_mesh: MeshInstance3D
var mat_suit_active: StandardMaterial3D
var mat_pauldron_active: StandardMaterial3D

func _ready() -> void:
	setup_blender_3d_viewport()
	var theme := Theme.new()
	theme.default_font = load("res://NotoSansThai.ttf")
	theme.default_font_size = 16
	var ui := Control.new()
	ui.theme = theme
	add_child(ui)
	var title := Label.new()
	title.text = "VESPER  /  CHARACTER ATELIER  (BLENDER 3D)"
	title.position = Vector2(42, 20)
	title.add_theme_font_size_override("font_size", 26)
	title.modulate = cream
	ui.add_child(title)
	var sub := Label.new()
	sub.text = "ต้นแบบ Blender 3D Toon + เส้นขอบ  |  เดินจริง · เข้าปากท่อ · เดินเข้าโจมตีตามหลักฐาน REA"
	sub.position = Vector2(42, 62)
	ui.add_child(sub)
	var panel := VBoxContainer.new()
	panel.position = Vector2(842, 108)
	panel.size = Vector2(328, 635)
	panel.add_theme_constant_override("separation", 10)
	ui.add_child(panel)
	var intro := Label.new()
	intro.text = "แต่งตัวโมเดล Blender ระหว่างเคลื่อนไหว"
	intro.modulate = cream
	panel.add_child(intro)
	var names := [["อาวุธ", "ดาบฟันเฟือง", "ค้อนลูกสูบ", "กระบี่ช่าง"], ["ศีรษะ", "แว่นช่าง", "หมวกเกราะ", "หน้ากากกรองไอ"], ["ชุด", "เสื้อช่างหนัง", "เกราะทองเหลือง", "เสื้อคลุมกรมท่า"], ["โล่", "ไม่มีโล่", "โล่หม้อน้ำ", "โล่กลมทองเหลือง"]]
	for slot in 4:
		var label := Label.new()
		label.text = names[slot][0]
		panel.add_child(label)
		var select := OptionButton.new()
		select.custom_minimum_size.y = 36
		for item in names[slot].slice(1): select.add_item(item)
		select.item_selected.connect(func(index): gear[slot] = index; sync_3d_gear(); queue_redraw())
		panel.add_child(select)
	var emotion := OptionButton.new()
	emotion.custom_minimum_size.y = 36
	for item in ["บุคลิก · สงบมั่นใจ", "บุคลิก · พร้อมสู้", "บุคลิก · เหนื่อยล้า"]: emotion.add_item(item)
	emotion.item_selected.connect(func(index): mood = index)
	panel.add_child(emotion)
	var skill_select := OptionButton.new()
	skill_select.custom_minimum_size.y = 36
	for item in ["ท่าสกิล · แทงทะลวง (Stab)", "ท่าสกิล · พ่นไอแรงดัน (Steam)"]: skill_select.add_item(item)
	skill_select.item_selected.connect(func(index): skill_kind = index)
	panel.add_child(skill_select)
	var tempo := HSlider.new()
	tempo.min_value = 0.25
	tempo.max_value = 1.5
	tempo.step = 0.05
	tempo.value = 1.0
	tempo.custom_minimum_size.y = 26
	tempo.value_changed.connect(func(value): speed = value)
	var tempo_label := Label.new()
	tempo_label.text = "ความเร็วท่า  0.25× — 1.5×"
	panel.add_child(tempo_label)
	panel.add_child(tempo)
	var controls := HBoxContainer.new()
	controls.position = Vector2(24, 662)
	controls.add_theme_constant_override("separation", 6)
	ui.add_child(controls)
	for entry in [["ยืน", "idle"], ["เดิน", "walk"], ["เข้าท่อ", "enter_pipe"], ["โจมตี", "attack"], ["สกิล", "skill"], ["รับแรง", "hit"], ["ป้องกัน", "guard"], ["ล้ม", "down"]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(82, 42)
		button.pressed.connect(func(): set_mode(entry[1]))
		controls.add_child(button)
	var flip := Button.new()
	flip.text = "กลับด้าน"
	flip.custom_minimum_size = Vector2(80, 42)
	flip.pressed.connect(func(): facing *= -1)
	controls.add_child(flip)
	var pause := Button.new()
	pause.text = "หยุด/เล่น"
	pause.custom_minimum_size = Vector2(80, 42)
	pause.pressed.connect(func(): paused = not paused; if anim: anim.pause() if paused else anim.play())
	controls.add_child(pause)
	status = Label.new()
	status.position = Vector2(26, 718)
	status.text = "WASD/ลูกศร เดินจริง · Space โจมตี (หรือเข้าปากท่อเมื่ออยู่หน้าท่อ) · K สกิล · H รับแรง · G ป้องกัน"
	ui.add_child(status)

func setup_blender_3d_viewport() -> void:
	viewport_3d = SubViewport.new()
	viewport_3d.size = Vector2i(790, 540)
	viewport_3d.transparent_bg = true
	viewport_3d.msaa_3d = Viewport.MSAA_4X
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport_3d)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8c6cc")
	env.ambient_light_energy = 0.72
	env_node.environment = env
	viewport_3d.add_child(env_node)

	# Warm upper-left key light (matches art-direction.md)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-38, -32, 0)
	key_light.light_color = Color("fff0d6")
	key_light.light_energy = 1.25
	viewport_3d.add_child(key_light)

	# Subtle cool rim/fill light from right
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-15, 135, 0)
	fill_light.light_color = Color("75b8c8")
	fill_light.light_energy = 0.45
	viewport_3d.add_child(fill_light)

	# Orthographic camera: size = 5.4 so 1.0 unit in 3D = 100 pixels in the 790x540 stage!
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.4
	cam.position = Vector3(0, 0, 10.0)
	viewport_3d.add_child(cam)

	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_file(ProjectSettings.globalize_path("res://vesper_warrior.glb"), state)
	if err == OK:
		var scene_3d := gltf.generate_scene(state)
		viewport_3d.add_child(scene_3d)
		vesper_root = scene_3d.get_node_or_null("VesperRoot")
		if vesper_root == null:
			vesper_root = scene_3d
		index_rig_nodes(scene_3d)
		vesper_skel = find_skeleton(vesper_root)
		if rig_nodes.has("TargetDummyRoot"):
			dummy_skel = find_skeleton(rig_nodes["TargetDummyRoot"])
		stylize_blender_meshes(scene_3d)
		sync_3d_gear()
		update_3d_pose(0.0, 0.0, 0.0)

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := find_skeleton(child)
		if found != null:
			return found
	return null

func set_bone_rot(skel: Skeleton3D, bname: String, euler_xyz: Vector3) -> void:
	if skel == null: return
	var idx := skel.find_bone(bname)
	if idx >= 0:
		skel.set_bone_pose_rotation(idx, Basis.from_euler(euler_xyz, EULER_ORDER_XYZ).get_rotation_quaternion())

func set_bone_pos_offset(skel: Skeleton3D, bname: String, offset: Vector3) -> void:
	if skel == null: return
	var idx := skel.find_bone(bname)
	if idx >= 0:
		var rest_origin := skel.get_bone_rest(idx).origin
		skel.set_bone_pose_position(idx, rest_origin + offset)

func index_rig_nodes(node: Node) -> void:
	rig_nodes[node.name] = node
	for child in node.get_children():
		index_rig_nodes(child)

func stylize_blender_meshes(root_node: Node) -> void:
	var outline_mat := StandardMaterial3D.new()
	outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_mat.albedo_color = outline
	outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	outline_mat.grow = true
	outline_mat.grow_amount = 0.009

	mat_suit_active = StandardMaterial3D.new()
	mat_suit_active.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat_suit_active.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat_suit_active.roughness = 0.55
	mat_suit_active.next_pass = outline_mat

	mat_pauldron_active = StandardMaterial3D.new()
	mat_pauldron_active.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat_pauldron_active.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat_pauldron_active.metallic = 0.35
	mat_pauldron_active.roughness = 0.38
	mat_pauldron_active.next_pass = outline_mat

	for key in rig_nodes:
		var node_name: String = str(key)
		var n: Node = rig_nodes[key]
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh == null: continue
			var surf_count := mi.mesh.get_surface_count()
			for s_idx in surf_count:
				var orig_mat: Material = mi.get_active_material(s_idx)
				if orig_mat is BaseMaterial3D:
					var bm := orig_mat as BaseMaterial3D
					var tm := StandardMaterial3D.new()
					tm.albedo_color = bm.albedo_color
					tm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
					tm.specular_mode = BaseMaterial3D.SPECULAR_TOON
					tm.metallic = bm.metallic * 0.45
					tm.roughness = clampf(bm.roughness, 0.28, 0.68)
					if bm.emission_enabled:
						tm.emission_enabled = true
						tm.emission = bm.emission
						tm.emission_energy_multiplier = 1.5
					tm.next_pass = outline_mat
					mi.set_surface_override_material(s_idx, tm)
			if node_name in ["UpperArm_R", "UpperArm_L", "ThighMesh_R", "ThighMesh_L"] and surf_count > 0:
				suit_Dynamic_meshes.append(mi)
				mi.set_surface_override_material(surf_count - 1, mat_suit_active)
			elif node_name == "Pauldron_R" and surf_count > 0:
				pauldron_r_mesh = mi
				mi.set_surface_override_material(0, mat_pauldron_active)

func sync_3d_gear() -> void:
	if rig_nodes.is_empty(): return
	for i in 3:
		if rig_nodes.has("Weapon_%d" % i): rig_nodes["Weapon_%d" % i].visible = (gear[0] == i)
		if rig_nodes.has("Headgear_%d" % i): rig_nodes["Headgear_%d" % i].visible = (gear[1] == i)
		if rig_nodes.has("Suit_%d" % i): rig_nodes["Suit_%d" % i].visible = (gear[2] == i)
	if rig_nodes.has("Shield_1"): rig_nodes["Shield_1"].visible = (gear[3] == 1)
	if rig_nodes.has("Shield_2"): rig_nodes["Shield_2"].visible = (gear[3] == 2)
	var suit_col: Color = [Color("88583e"), Color("b48c4e"), Color("32526e")][gear[2]]
	if mat_suit_active:
		mat_suit_active.albedo_color = suit_col
	if mat_pauldron_active:
		mat_pauldron_active.albedo_color = Color("c89b58") if gear[2] == 1 else Color("7a95a2")

func is_near_pipe() -> bool:
	return actor_pos.distance_to(pipe_floor) < 78.0

func trigger_impact(amount_text: String, target_pos: Vector2, col: Color = Color("59a8ff")) -> void:
	float_text = amount_text
	float_pos = target_pos
	float_color = col
	float_Timer = 0.75
	if target_pos.x > 500:
		dummy_recoil = 1.0

func set_mode(next: String) -> void:
	if anim: anim.kill()
	strike = 0.0
	recoil = 0.0
	skill_burst = 0.0
	pipe_progress = 0.0
	approach_progress = 0.0
	attack_phase = "none"
	paused = false
	mode = next
	action_time = 0.0
	if next == "walk":
		if walk_dir == Vector2.ZERO:
			walk_dir = Vector2(facing, 0.0)
	elif next == "attack":
		facing = 1.0
		combat_origin_x = clampf(actor_pos.x, 280.0, 440.0)
		var start_y := actor_pos.y
		var target_x := 530.0
		var target_y := 563.0
		attack_phase = "approach"
		anim = create_tween()
		anim.tween_method(func(t: float):
			approach_progress = t
			actor_pos = Vector2(lerpf(combat_origin_x, target_x, t), lerpf(start_y, target_y, t))
		, 0.0, 1.0, 0.34)
		anim.tween_callback(func(): attack_phase = "windup")
		anim.tween_property(self, "strike", -0.75, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		anim.tween_callback(func(): attack_phase = "cleave")
		anim.tween_property(self, "strike", 1.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		anim.tween_callback(func():
			var dmg := "25" if gear[0] == 0 else ("34" if gear[0] == 1 else "22")
			trigger_impact(dmg, Vector2(648, 435), Color("4da6ff"))
		)
		anim.tween_interval(0.10)
		anim.tween_callback(func(): attack_phase = "retreat")
		anim.tween_method(func(t: float):
			approach_progress = 1.0 - t
			strike = lerpf(1.0, 0.0, clampf(t * 2.2, 0.0, 1.0))
			actor_pos.x = lerpf(target_x, combat_origin_x, t)
		, 0.0, 1.0, 0.34)
		anim.tween_callback(func():
			attack_phase = "none"
			strike = 0.0
			mode = "idle"
		)
	elif next == "skill":
		facing = 1.0
		combat_origin_x = clampf(actor_pos.x, 280.0, 440.0)
		var start_y := actor_pos.y
		var target_x := 515.0 if skill_kind == 0 else 440.0
		attack_phase = "approach"
		anim = create_tween()
		anim.tween_method(func(t: float):
			approach_progress = t
			actor_pos = Vector2(lerpf(combat_origin_x, target_x, t), lerpf(start_y, 563.0, t))
		, 0.0, 1.0, 0.24)
		anim.tween_callback(func(): attack_phase = "windup")
		anim.tween_property(self, "strike", -0.65, 0.15)
		anim.tween_callback(func(): attack_phase = "cleave")
		anim.tween_property(self, "strike", 1.15, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		anim.parallel().tween_property(self, "skill_burst", 1.0, 0.18)
		anim.tween_callback(func():
			var txt := "38 CRIT" if skill_kind == 0 else "29 STEAM"
			trigger_impact(txt, Vector2(648, 420), Color("ffb84d"))
		)
		anim.tween_interval(0.14)
		anim.tween_callback(func(): attack_phase = "retreat")
		anim.tween_method(func(t: float):
			approach_progress = 1.0 - t
			strike = lerpf(1.15, 0.0, clampf(t * 2.0, 0.0, 1.0))
			skill_burst = lerpf(1.0, 0.0, t)
			actor_pos.x = lerpf(target_x, combat_origin_x, t)
		, 0.0, 1.0, 0.28)
		anim.tween_callback(func():
			attack_phase = "none"
			strike = 0.0
			skill_burst = 0.0
			mode = "idle"
		)
	elif next == "hit":
		var hit_origin_x := actor_pos.x
		anim = create_tween()
		anim.tween_method(func(t: float):
			recoil = t
			actor_pos.x = hit_origin_x - facing * 18.0 * t
		, 0.0, 1.0, 0.09)
		anim.tween_callback(func():
			trigger_impact("-14", actor_pos + Vector2(0, -145), Color("ff5c5c"))
		)
		anim.tween_interval(0.06)
		anim.tween_method(func(t: float):
			recoil = 1.0 - t
			actor_pos.x = lerpf(hit_origin_x - facing * 18.0, hit_origin_x, t)
		, 0.0, 1.0, 0.42)
		anim.tween_callback(func():
			recoil = 0.0
			mode = "idle"
		)
	elif next == "guard":
		var guard_origin_x := actor_pos.x
		anim = create_tween()
		anim.tween_method(func(t: float):
			recoil = t * 0.55
			actor_pos.x = guard_origin_x - facing * 11.0 * t
		, 0.0, 1.0, 0.10)
		anim.tween_callback(func():
			trigger_impact("BLOCK", actor_pos + Vector2(facing * 28, -125), cream)
		)
		anim.tween_interval(0.22)
		anim.tween_method(func(t: float):
			recoil = 0.55 * (1.0 - t)
			actor_pos.x = lerpf(guard_origin_x - facing * 11.0, guard_origin_x, t)
		, 0.0, 1.0, 0.25)
	elif next == "down":
		anim = create_tween()
		anim.tween_property(self, "recoil", 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif next == "enter_pipe":
		var start_pos := actor_pos
		facing = -1.0 if pipe_floor.x < actor_pos.x else 1.0
		anim = create_tween()
		var walk_dur := clampf(start_pos.distance_to(pipe_floor) / 220.0, 0.08, 0.45)
		anim.tween_method(func(t: float):
			actor_pos = start_pos.lerp(pipe_floor, t)
			pipe_progress = t * 0.35
		, 0.0, 1.0, walk_dur)
		anim.tween_method(func(t: float):
			pipe_progress = 0.35 + t * 0.65
			actor_pos = pipe_floor.lerp(pipe_center + Vector2(0, 48), t)
		, 0.0, 1.0, 0.48)
		anim.tween_interval(0.22)
		anim.tween_callback(func():
			actor_pos = Vector2(400, 563)
			facing = 1.0
			pipe_progress = 0.0
			mode = "idle"
		)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var move_keys := [KEY_A, KEY_D, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
		if event.keycode in move_keys and not event.is_pressed() and keyboard_walk:
			if get_input_move_vector() == Vector2.ZERO:
				keyboard_walk = false
				walk_dir = Vector2.ZERO
				set_mode("idle")
		if not event.is_pressed() or event.is_echo(): return
		if event.keycode == KEY_SPACE:
			if is_near_pipe() and mode in ["idle", "walk"]:
				set_mode("enter_pipe")
			else:
				set_mode("attack")
		if event.keycode == KEY_K: set_mode("skill")
		if event.keycode == KEY_H: set_mode("hit")
		if event.keycode == KEY_G: set_mode("guard")

func get_input_move_vector() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): v.y += 1.0
	return v.normalized() if v.length() > 0 else Vector2.ZERO

func _process(delta: float) -> void:
	if anim: anim.set_speed_scale(speed)
	if not paused:
		var dt := delta * speed
		clock += dt
		action_time += dt
		if float_Timer > 0.0:
			float_Timer = maxf(0.0, float_Timer - dt)
		if dummy_recoil > 0.0:
			dummy_recoil = maxf(0.0, dummy_recoil - dt * 3.2)
		var input_vec := get_input_move_vector()
		if input_vec != Vector2.ZERO and mode in ["idle", "walk", "guard"]:
			keyboard_walk = true
			walk_dir = input_vec
			if mode != "walk": set_mode("walk")
			if absf(input_vec.x) > 0.05:
				facing = -1.0 if input_vec.x < 0 else 1.0
			actor_pos.x = clampf(actor_pos.x + input_vec.x * 165.0 * dt, 95.0, 560.0)
			actor_pos.y = clampf(actor_pos.y + input_vec.y * 95.0 * dt, 488.0, 612.0)
		elif mode == "walk" and not keyboard_walk:
			actor_pos.x += facing * 135.0 * dt
			if actor_pos.x > 520.0:
				actor_pos.x = 520.0
				facing = -1.0
			elif actor_pos.x < 145.0:
				actor_pos.x = 145.0
				facing = 1.0
			walk_dir = Vector2(facing, 0.0)
	queue_redraw()

func poly(points: Array, color: Color) -> void:
	var p := PackedVector2Array(points)
	draw_colored_polygon(p, color)
	p.append(p[0])
	draw_polyline(p, outline, 1.6, true)

func limb(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	draw_line(a, b, outline, width + 3.2, true)
	draw_line(a, b, color, width, true)
	draw_circle(a, width * 0.5, color)

func joint_between(start: Vector2, end: Vector2, length: float, bend: float) -> Vector2:
	var delta := end - start
	var distance := clampf(delta.length(), 0.01, length * 2.0 - 0.01)
	var direction := delta.normalized()
	return start + direction * distance * 0.5 + Vector2(-direction.y, direction.x) * sqrt(maxf(0.0, length * length - distance * distance * 0.25)) * bend

func ellipse_points(center: Vector2, rx: float, ry: float) -> Array:
	var points := []
	for i in 32: points.append(center + Vector2(cos(i * TAU / 32.0) * rx, sin(i * TAU / 32.0) * ry))
	return points

func gait_foot(phase: float) -> Vector2:
	var stride_x := cos(phase) * 19.5
	var lift_y := -maxf(0.0, -sin(phase)) * 13.5
	return Vector2(stride_x, lift_y)

func update_3d_pose(phase_clock: float, walk: float, torso_lean_x: float) -> void:
	if vesper_root == null or rig_nodes.is_empty(): return
	sync_3d_gear()
	var depth_scale := clampf(lerpf(0.74, 1.0, (actor_pos.y - 420.0) / 145.0), 0.62, 1.08)
	# Convert 2D stage coordinates (actor_pos inside Rect2(24, 105, 790, 540)) to 3D Orthographic coordinates
	var world_x := (actor_pos.x - 24.0 - 395.0) / 100.0
	var world_y := -(actor_pos.y - 105.0 - 270.0) / 100.0
	vesper_root.position = Vector3(world_x, world_y, 0.0)
	var s := 1.44 * depth_scale
	# 3D Facing & Pipe Entry rotation:
	# Facing right: -30 deg yaw (3/4 view toward camera); Entering pipe: smoothly turns to +90 deg (back view into pipe!)
	if mode == "enter_pipe" and pipe_progress >= 0.35:
		var turn_t := clampf((pipe_progress - 0.35) / 0.35, 0.0, 1.0)
		vesper_root.scale = Vector3(s, s, s)
		vesper_root.rotation.y = lerpf(deg_to_rad(-150.0 if facing < 0 else -30.0), deg_to_rad(90.0), turn_t)
	else:
		vesper_root.scale = Vector3(s * facing, s, s)
		vesper_root.rotation.y = deg_to_rad(-30.0 * facing)

	if rig_nodes.has("TargetDummyRoot"):
		var dummy_root: Node3D = rig_nodes["TargetDummyRoot"]
		var dummy_x := (655.0 + dummy_recoil * 14.0 - 24.0 - 395.0) / 100.0
		var dummy_y := -(563.0 - 105.0 - 270.0) / 100.0
		dummy_root.position = Vector3(dummy_x, dummy_y, -0.25)
		dummy_root.scale = Vector3(1.28, 1.28, 1.28)
		dummy_root.rotation = Vector3(0.0, deg_to_rad(24.0), 0.0)
		set_bone_rot(dummy_skel, "DummyTorsoBone", Vector3(0.0, 0.0, -dummy_recoil * 0.18))
		set_bone_rot(dummy_skel, "DummyArm", Vector3(0.0, 0.0, dummy_recoil * 0.38))

	var idle_breath := sin(clock * 2.8) * (1.2 if mood != 2 else 2.0)
	var walk_bounce := (-cos(phase_clock * 2.0) * 1.8 - 0.8) * walk
	var down_drop := 18.0 * recoil if mode == "down" else 0.0
	var cog_shift_z := -sin(phase_clock) * 0.022 * walk
	var pelvic_list := sin(phase_clock) * 0.065 * walk
	set_bone_pos_offset(vesper_skel, "Hip", Vector3(-recoil * 0.05, (idle_breath + walk_bounce - down_drop) * 0.01, cog_shift_z))
	set_bone_rot(vesper_skel, "Hip", Vector3(pelvic_list, sin(phase_clock) * 0.15 * walk, 0.0))

	var torso_pitch := -clampf(torso_lean_x * 0.020, -0.42, 0.50)
	if mode == "down":
		torso_pitch = -recoil * 0.85
	var torso_twist := -sin(phase_clock) * 0.14 * walk
	if strike < 0.0:
		torso_twist += strike * 0.42
	elif strike > 0.0:
		torso_twist += strike * 0.34
	set_bone_rot(vesper_skel, "Torso", Vector3(-pelvic_list * 0.7, torso_twist, torso_pitch))

	# Two-stage Neck & Head overlapping counter-rotation
	var head_nod := -0.14 if mood == 2 else (0.06 if mood == 1 else 0.0)
	var lag_phase := phase_clock - 0.45
	set_bone_rot(vesper_skel, "Neck", Vector3(0.0, -torso_twist * 0.22, -torso_pitch * 0.25 + sin(lag_phase) * 0.025 * walk))
	set_bone_rot(vesper_skel, "Head", Vector3(0.0, -torso_twist * 0.28, -torso_pitch * 0.32 + head_nod + sin(lag_phase - 0.3) * 0.035 * walk))

	# Secondary Overlapping HairBack & Mechanical SteamValve
	var hair_phase := phase_clock - 0.85
	var hair_pitch := sin(clock * 2.8 - 0.8) * 0.04 + sin(hair_phase * 2.0) * 0.09 * walk + strike * 0.18 - recoil * 0.22
	set_bone_rot(vesper_skel, "HairBack", Vector3(0.0, torso_twist * 0.18, hair_pitch))
	var valve_speed := 12.0 if (mode == "skill" and skill_kind == 1) else (4.5 if walk > 0.5 else 1.8)
	set_bone_rot(vesper_skel, "SteamValve", Vector3(clock * valve_speed, 0.0, 0.0))

	# Cinematic Facial Acting: Natural Periodic Blinking, Mood/Action Eyebrows & Eye Gaze
	var blink_cycle := fmod(clock, 3.6)
	var blink := 0.0
	if blink_cycle > 3.42:
		blink = sin(((blink_cycle - 3.42) / 0.18) * PI)
	if mood == 2:
		blink = maxf(blink, 0.38)
	if mode == "hit":
		blink = maxf(blink, clampf(recoil * 1.1, 0.0, 1.0))
	elif mode == "down":
		blink = maxf(blink, clampf(recoil, 0.0, 1.0))

	var brow_tilt := 0.0
	var brow_y := 0.0
	if mood == 1 or mode in ["attack", "skill", "guard"]:
		brow_tilt = 0.22
		brow_y = -0.006
	elif mood == 2 or mode in ["hit", "down"]:
		brow_tilt = -0.22
		brow_y = 0.006
	var eye_gaze_z := 0.006 if mode in ["attack", "skill"] else sin(clock * 1.4) * 0.004
	for side_pair_f in [["R", -1], ["L", 1]]:
		var sf: String = side_pair_f[0]
		var s_dir: int = side_pair_f[1]
		set_bone_pos_offset(vesper_skel, "Eye_" + sf, Vector3(0.0, 0.0, eye_gaze_z))
		set_bone_pos_offset(vesper_skel, "Eyelid_" + sf, Vector3(0.0, -0.044 * blink, 0.0))
		set_bone_pos_offset(vesper_skel, "Brow_" + sf, Vector3(0.0, brow_y, 0.0))
		set_bone_rot(vesper_skel, "Brow_" + sf, Vector3(-s_dir * brow_tilt, 0.0, 0.0))

	# 2-segment IK legs with Heel-Strike to Toe-Off Foot Roll & Belt Pouch Secondary Motion
	var hip_2d := Vector2(0, -53.0)
	for side_pair in [["R", 1], ["L", -1]]:
		var s_name: String = side_pair[0]
		var side: int = side_pair[1]
		var l_phase := phase_clock + (PI if side == -1 else 0.0)
		var leg_root := hip_2d + Vector2(side * 4.5, 0)
		var idle_stance := Vector2(side * 10.5 + (2.5 if side == 1 else -2.0), 0.0)
		if mode in ["attack", "skill"] and attack_phase in ["windup", "cleave"]:
			idle_stance = Vector2(side * 14.0 + (6.0 if side == 1 else -4.0), 0.0)
		var foot_2d := gait_foot(l_phase) * walk + idle_stance * (1.0 - walk)
		if mode == "down":
			foot_2d = Vector2(side * 16.0 - 10.0, 2.0)
		var ankle_2d := foot_2d - Vector2(1, 5)
		var knee_2d := joint_between(leg_root, ankle_2d, 28.0, -1.0)
		var thigh_dir := (knee_2d - leg_root).normalized()
		var shin_dir := (ankle_2d - knee_2d).normalized()
		var thigh_ang := atan2(thigh_dir.x, thigh_dir.y)
		var shin_ang := atan2(shin_dir.x, shin_dir.y) - thigh_ang
		var lift_ratio := clampf(-foot_2d.y / 13.5, 0.0, 1.0)
		var heel_strike := maxf(0.0, cos(l_phase)) * (1.0 - lift_ratio) * 0.22 * walk
		var push_off := maxf(0.0, -cos(l_phase)) * (1.0 - lift_ratio) * 0.28 * walk
		var foot_ang := -(thigh_ang + shin_ang) - lift_ratio * 0.38 - heel_strike + push_off
		var toe_ang := -push_off * 1.15 + lift_ratio * 0.18
		set_bone_rot(vesper_skel, "Thigh_" + s_name, Vector3(0.04 * side, 0.0, thigh_ang))
		set_bone_rot(vesper_skel, "Knee_" + s_name, Vector3(0.0, 0.0, shin_ang))
		set_bone_rot(vesper_skel, "Foot_" + s_name, Vector3(-0.04 * side, 0.0, foot_ang))
		set_bone_rot(vesper_skel, "Toe_" + s_name, Vector3(0.0, 0.0, toe_ang))

		var pouch_flare := maxf(0.0, -thigh_ang) * 0.35 + (0.12 if mode in ["attack", "skill"] else 0.0)
		var pouch_swing := sin(l_phase - 0.55) * 0.14 * walk
		set_bone_rot(vesper_skel, "Pouch_" + s_name, Vector3(side * pouch_flare, 0.0, pouch_swing))

	# Front Arm (Shoulder_R, Elbow_R, Hand_R, WeaponMount) with Wrist Follow-Through
	var shoulder_2d := hip_2d + Vector2(torso_lean_x, -49.0)
	var arm_root := shoulder_2d + Vector2(13, 4)
	var hand := arm_root + Vector2(22, 31)
	var angle := 0.72
	var wrist_snap := 0.0
	var is_stepping := walk > 0.5
	if mode == "idle":
		hand = arm_root + Vector2(22 + (5 if mood == 1 else 0), 31 - (6 if mood == 1 else 0) + sin(clock * 2.8 - 0.25) * 1.6)
		angle = 0.72 if mood != 1 else 0.52
	elif is_stepping:
		var arm_swing := -cos(phase_clock) * 12.0
		hand = arm_root + Vector2(19.0 + arm_swing, 30.0 - absf(arm_swing) * 0.2)
		angle = 0.66 + (-cos(phase_clock - 0.3) * 0.18)
		wrist_snap = sin(phase_clock - 0.4) * 0.12
	if attack_phase in ["windup", "cleave"] or strike != 0.0:
		if strike < 0.0:
			var w := clampf(-strike / 0.75, 0.0, 1.0)
			hand = arm_root.lerp(arm_root + Vector2(-6, -28), w)
			angle = lerpf(0.72, -0.95, w)
			wrist_snap = 0.28 * w
		else:
			var c := clampf(strike, 0.0, 1.2)
			if mode == "skill" and skill_kind == 0:
				hand = arm_root + Vector2(38.0 * c, 4.0 * c)
				angle = lerpf(0.72, 1.55, clampf(c, 0.0, 1.0))
				wrist_snap = -0.22 * clampf(c, 0.0, 1.0)
			else:
				hand = arm_root + Vector2(34.0 * c, 22.0 * c)
				angle = lerpf(-0.4, 1.92, clampf(c, 0.0, 1.0))
				wrist_snap = -0.32 * clampf(c, 0.0, 1.0)
	if mode == "guard":
		hand = arm_root + Vector2(8, 18)
		angle = 0.15
	elif mode == "hit":
		hand = arm_root + Vector2(-8 * recoil, 18 - 10 * recoil)
		angle = -0.35 * recoil
	elif mode == "down":
		hand = arm_root + Vector2(18, 22)
		angle = 1.45
	hand = arm_root + (hand - arm_root).limit_length(47.5)
	var elbow := joint_between(arm_root, hand, 24.0, 1.0)
	var up_arm_dir := (elbow - arm_root).normalized()
	var fore_arm_dir := (hand - elbow).normalized()
	var sh_r_ang := atan2(up_arm_dir.x, up_arm_dir.y) - torso_pitch
	var el_r_ang := atan2(fore_arm_dir.x, fore_arm_dir.y) - atan2(up_arm_dir.x, up_arm_dir.y)
	var world_arm_z := torso_pitch + sh_r_ang + el_r_ang + wrist_snap
	set_bone_rot(vesper_skel, "Shoulder_R", Vector3(0.22, 0.0, sh_r_ang))
	set_bone_rot(vesper_skel, "Elbow_R", Vector3(0.0, 0.0, el_r_ang))
	set_bone_rot(vesper_skel, "Hand_R", Vector3(0.0, 0.0, wrist_snap))
	set_bone_rot(vesper_skel, "WeaponMount", Vector3(-0.12, 0.0, -angle - world_arm_z))

	# Back Arm & Shield (Shoulder_L, Elbow_L, Hand_L, ShieldMount)
	var back_swing := cos(phase_clock) * 7.5 * walk
	var back_hand := shoulder_2d + Vector2(-28.0 + back_swing, 30.0)
	if mode == "guard":
		back_hand = shoulder_2d + Vector2(24.0 - recoil * 5.0, 4.0)
	elif attack_phase == "windup":
		back_hand = shoulder_2d + Vector2(14.0, -6.0)
	elif attack_phase == "cleave":
		back_hand = shoulder_2d + Vector2(-18.0, 20.0)
	elif mode == "hit":
		back_hand = shoulder_2d + Vector2(-22.0, 12.0)
	var back_root := shoulder_2d + Vector2(-13.0, 2.0)
	var back_elbow := joint_between(back_root, back_hand, 24.0, 1.0)
	var b_up_dir := (back_elbow - back_root).normalized()
	var b_fore_dir := (back_hand - back_elbow).normalized()
	var sh_l_ang := atan2(b_up_dir.x, b_up_dir.y) - torso_pitch
	var el_l_ang := atan2(b_fore_dir.x, b_fore_dir.y) - atan2(b_up_dir.x, b_up_dir.y)
	var guard_pull := 0.38 if mode == "guard" else -0.20
	set_bone_rot(vesper_skel, "Shoulder_L", Vector3(guard_pull, 0.0, sh_l_ang))
	set_bone_rot(vesper_skel, "Elbow_L", Vector3(0.0, 0.0, el_l_ang))
	set_bone_rot(vesper_skel, "Hand_L", Vector3(0.0, 0.0, -wrist_snap * 0.5))
	if mode == "guard":
		set_bone_pos_offset(vesper_skel, "ShieldMount", Vector3(0.16, -0.06, 0.24))
		set_bone_rot(vesper_skel, "ShieldMount", Vector3(0.0, 0.45, -sh_l_ang - el_l_ang))
	else:
		set_bone_pos_offset(vesper_skel, "ShieldMount", Vector3.ZERO)
		set_bone_rot(vesper_skel, "ShieldMount", Vector3(0.0, -0.25, 0.35))

func draw_pipe_rim_foreground() -> void:
	draw_arc(pipe_center, 110, -PI * 0.88, PI * 0.18, 48, Color("30464b"), 18, true)
	draw_arc(pipe_center, 98, -PI * 0.85, PI * 0.15, 48, outline, 4, true)
	for i in 10:
		var ang := i * TAU / 10.0
		if sin(ang) < 0.35:
			var p := pipe_center + Vector2.from_angle(ang) * 110.0
			draw_circle(p, 4.2, brass.darkened(0.45))

func draw_target_dummy() -> void:
	var base := Vector2(655 + dummy_recoil * 14.0, 563)
	draw_set_transform(base + Vector2(0, 10), 0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 54, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	draw_rect(Rect2(24, 105, 790, 540), Color("15252b"))
	for x in range(65, 815, 100):
		draw_line(Vector2(x, 107), Vector2(x, 460), Color("20353b"), 2)
	for y in [158, 440]:
		draw_line(Vector2(25, y), Vector2(813, y), Color("304047"), 8)
		for x in range(55, 815, 80): draw_circle(Vector2(x, y), 3, brass.darkened(0.5))
	draw_rect(Rect2(25, 465, 788, 180), Color("1d3035"))
	for x in range(-200, 1100, 110):
		draw_line(Vector2(420 + (x - 420) * 0.6, 465), Vector2(x, 645), Color("354449"), 1)
	for y in [495, 535, 590, 640]:
		draw_line(Vector2(25, y), Vector2(813, y), Color("354449"), 1)
	poly([Vector2(115, 465), Vector2(245, 465), Vector2(268, 520), Vector2(92, 520)], Color("26393f"))
	draw_arc(pipe_center, 110, 0, TAU, 64, Color("30464b"), 18, true)
	draw_circle(pipe_center, 94, Color("0b171b"))
	draw_circle(pipe_center + Vector2(0, 12), 70, Color(0.74, 0.57, 0.33, 0.10 + 0.04 * sin(clock * 3.0)))
	draw_arc(pipe_center, 98, 0, TAU, 64, Color("0d1c21"), 10, true)
	for i in 10:
		var p := pipe_center + Vector2.from_angle(i * TAU / 10.0) * 110.0
		draw_circle(p, 4, brass.darkened(0.55))
	var valve_pos := Vector2(308, 365)
	draw_line(valve_pos, valve_pos + Vector2(-22, 0), steel.darkened(0.3), 6)
	draw_arc(valve_pos, 22, 0, TAU, 24, brass, 4, true)
	for i in 4:
		var va := clock * 0.4 + i * PI * 0.5
		draw_line(valve_pos - Vector2.from_angle(va) * 20, valve_pos + Vector2.from_angle(va) * 20, brass, 2.5)
	var near_pipe := is_near_pipe()
	var arrow_col := Color("62b6cb") if near_pipe else Color(0.38, 0.71, 0.80, 0.35)
	poly([pipe_floor + Vector2(0, -18), pipe_floor + Vector2(18, 6), pipe_floor + Vector2(7, 6), pipe_floor + Vector2(7, 24), pipe_floor + Vector2(-7, 24), pipe_floor + Vector2(-7, 6), pipe_floor + Vector2(-18, 6)], arrow_col)
	for i in 5:
		var y := fmod(clock * 18.0 + i * 39.0, 190.0)
		draw_circle(Vector2(680 + sin(clock + i) * 12.0, 430 - y), 9 + i * 2, Color(0.5, 0.67, 0.69, 0.035))
	draw_target_dummy()

	# Ground contact shadow under 3D character
	var depth_scale := clampf(lerpf(0.74, 1.0, (actor_pos.y - 420.0) / 145.0), 0.62, 1.08)
	var pipe_fade := clampf(1.0 - maxf(0.0, pipe_progress - 0.45) * 1.6, 0.15, 1.0)
	draw_set_transform(actor_pos + Vector2(0, 8), 0, Vector2(depth_scale, 0.22 * depth_scale))
	draw_circle(Vector2.ZERO, 82, Color(0, 0, 0, 0.36 * pipe_fade))
	draw_set_transform(Vector2.ZERO)

	# Compute pose & update 3D Blender model in SubViewport
	var cycle := clock * 7.2
	var is_stepping := mode == "walk" or attack_phase in ["approach", "retreat"] or (mode == "enter_pipe" and pipe_progress < 0.85)
	var walk := 1.0 if is_stepping else 0.0
	var step_dir := -1.0 if attack_phase == "retreat" else 1.0
	var phase_clock := cycle * step_dir
	var torso_lean_x := 3.5 + (4.5 if mood == 1 else (6.0 if mood == 2 else 0.0)) + 3.0 * walk
	if strike < 0.0:
		torso_lean_x += strike * 11.0
	else:
		torso_lean_x += strike * 16.5
	torso_lean_x -= recoil * 12.0
	if mode == "guard":
		torso_lean_x -= 4.5
	update_3d_pose(phase_clock, walk, torso_lean_x)

	# Composite 3D Blender character onto the 2D stage
	if viewport_3d and viewport_3d.get_texture():
		draw_texture(viewport_3d.get_texture(), Vector2(24, 105))

	# Skill release effect from weapon tip
	if skill_burst > 0.01:
		var release_origin := actor_pos + Vector2(facing * 95.0, -118.0)
		if skill_kind == 0:
			draw_line(release_origin, release_origin + Vector2(facing * 95.0 * skill_burst, -6.0), Color(1.0, 0.88, 0.45, 0.88 * skill_burst), 9.0, true)
		else:
			for i in 4:
				var jet_pos := release_origin + Vector2(facing * (28.0 + i * 32.0 * skill_burst), sin(clock * 16.0 + i) * 12.0 - i * 4.0)
				draw_circle(jet_pos, (14.0 + i * 8.0) * skill_burst, Color(0.78, 0.93, 0.96, 0.55 * (1.0 - i * 0.18)))

	# Foreground pipe rim occludes 3D character when stepping inside pipe mouth
	if mode == "enter_pipe" and pipe_progress >= 0.35:
		draw_pipe_rim_foreground()

	if float_Timer > 0.0:
		var font: Font = load("res://NotoSansThai.ttf")
		var float_y := float_pos.y - (0.75 - float_Timer) * 48.0
		draw_string(font, Vector2(float_pos.x, float_y), float_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 26, float_color)

	if mode in ["attack", "skill", "enter_pipe"]:
		draw_rect(Rect2(36, 118, 255, 34), Color(0.06, 0.11, 0.13, 0.88))
		var font: Font = load("res://NotoSansThai.ttf")
		var wait_msg := "กำลังออกท่า... (Please Wait)" if mode != "enter_pipe" else "กำลังก้าวเข้าปากท่อ..."
		draw_string(font, Vector2(48, 141), wait_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cream)
	elif near_pipe:
		draw_rect(Rect2(36, 118, 310, 34), Color(0.06, 0.11, 0.13, 0.88))
		var font: Font = load("res://NotoSansThai.ttf")
		draw_string(font, Vector2(48, 141), "ใกล้ปากท่อ · กด Space หรือปุ่ม 'เข้าท่อ'", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("75c9cd"))
