extends SceneTree
# Renders the key-art title (2560x1440) from the game's own assets. Run with the real renderer:
#   Godot --path game --script res://tests/render_title.gd   (writes res://art/environments/title.png)
# Title text is drawn by main.gd; the left ~45% stays dark for the menu panel.

const W := 2560
const H := 1440
# Tunables (re-run after rig/gear changes): hero gear [weapon, head, suit, shield], hero turn in degrees (0 = profile right, see Hero3D), poses as clip fractions.
const HERO_GEAR := [1, 1, 1, 0]
const HERO_YAW := -75.0
const HERO_POSE := 0.42
const HERO_RECT := Rect2(1650, 200, 1300, 1300)
const BOSS_RECT := Rect2(1140, -300, 1800, 1800)

func _initialize() -> void:
	await process_frame
	create_timer(90).timeout.connect(func():printerr("render_title timed out");quit(1))
	if DisplayServer.get_name() == "headless":
		printerr("render_title needs the real renderer")
		quit(1)
		return
	var canvas := SubViewport.new()
	canvas.size = Vector2i(W, H)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas.transparent_bg = false
	root.add_child(canvas)
	var base := Control.new()
	base.size = Vector2(W, H)
	canvas.add_child(base)

	# Backdrop: reactor arena, darkened and teal-graded.
	var back := TextureRect.new()
	back.texture = load("res://art/environments/arena_reactor.png")
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.size = Vector2(W, H)
	back.modulate = Color(0.5, 0.68, 0.78)
	base.add_child(back)
	_glow(base, Vector2(2000, 520), 1200, Color(1.0, 0.55, 0.2, 0.55))  # reactor core haze behind the boss
	_glow(base, Vector2(2150, 900), 900, Color(0.35, 0.8, 0.85, 0.22))   # cool rim fill on the hero side

	# Boss looms behind, mantis glowing.
	var boss := Roster3D.create("B06")
	boss.facing_left = true
	boss.size = BOSS_RECT.size
	boss.position = BOSS_RECT.position
	boss.modulate = Color(0.6, 0.68, 0.82)
	base.add_child(boss)
	_glow(base, Vector2(1950, 520), 600, Color(0.4, 0.95, 0.9, 0.18))
	# Floor mist between boss and hero.
	var mist := _gradient(Vector2(0, 0), Vector2(0, 1), [[0.0, Color(0.5, 0.65, 0.7, 0.0)], [1.0, Color(0.55, 0.7, 0.72, 0.30)]])
	mist.position = Vector2(0, 760)
	mist.size = Vector2(W, 680)
	base.add_child(mist)

	# Hero in the foreground, mid-strike.
	var hero := Hero3D.new()
	hero.apply_variant({"gear":HERO_GEAR,"pack":true,"colors":{"suit":"8a3a2a","Mat_LeatherTunic":"8a3a2a"},"build":Vector3(1.1,0.96,1.1)})
	hero.facing_left = true
	hero.nodes["Dummy_Mesh"].visible = false
	hero.size = HERO_RECT.size
	hero.position = HERO_RECT.position
	base.add_child(hero)
	_glow(base, Vector2(2020, 760), 700, Color(1.0, 0.7, 0.3, 0.16))
	_glow(base, Vector2(2380, 520), 500, Color(0.4, 0.9, 1.0, 0.18))

	# Steam wisps in front.
	for i in 9:
		var seed := float(i)
		_glow(base, Vector2(1000 + fmod(seed * 397.0, 1500.0), 1060 + fmod(seed * 131.0, 300.0)), 260 + fmod(seed * 53.0, 160.0), Color(0.88, 0.95, 0.96, 0.10))

	# Dark left side for the menu panel, plus vignette and bottom fade.
	var side := _gradient(Vector2(0, 0), Vector2(1, 0), [[0.0, Color(0.01, 0.04, 0.05, 0.92)], [0.55, Color(0.01, 0.04, 0.05, 0.66)], [1.0, Color(0.01, 0.04, 0.05, 0.0)]])
	side.size = Vector2(W * 0.62, H)
	base.add_child(side)
	var vig := _gradient(Vector2(0, 0), Vector2(0, 1), [[0.0, Color(0, 0.02, 0.03, 0.55)], [0.25, Color(0, 0.02, 0.03, 0.0)], [0.8, Color(0, 0.02, 0.03, 0.0)], [1.0, Color(0, 0.02, 0.03, 0.7)]])
	vig.size = Vector2(W, H)
	base.add_child(vig)

	# Colour grade: teal shadows, warm highlights.
	var grade := ColorRect.new()
	grade.size = Vector2(W, H)
	grade.color = Color(0.1, 0.5, 0.55)
	grade.material = CanvasItemMaterial.new()
	grade.material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	grade.color = Color(0.88, 0.97, 1.0)
	base.add_child(grade)

	# Freeze the hero on a mid-swing frame, boss on a menacing strike frame.
	await process_frame
	hero.animator.play("Attack")
	hero.busy = 1000.0
	hero.animator.seek(hero.animator.get_animation("Attack").length * HERO_POSE, true)
	hero.animator.pause()
	hero.sparks.position = Vector3(-0.9, 0.9, 0.3)
	boss.perform("attack")
	await create_timer(0.9).timeout
	boss.action_time = 0.0
	hero.animator.seek(hero.animator.get_animation("Attack").length * HERO_POSE, true)
	# Hero's own _process pins the yaw to profile; take over the turn for a 3/4 view toward the camera.
	hero._sync_resolution()
	hero.set_process(false)
	hero.model.rotation.y = deg_to_rad(HERO_YAW)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var image := canvas.get_texture().get_image()
	image.save_png("res://art/environments/title.png")
	print("title rendered ", image.get_size())
	quit(0)

func _glow(parent: Control, center: Vector2, radius: float, color: Color) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([color, Color(color.r, color.g, color.b, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size = Vector2(radius * 2, radius * 2)
	rect.position = center - Vector2(radius, radius)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if color.a < 0.3 and color.r > 0.9 and color.g < 0.9 else CanvasItemMaterial.BLEND_MODE_MIX
	rect.material = mat
	parent.add_child(rect)

func _gradient(from: Vector2, to: Vector2, stops: Array) -> TextureRect:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for stop in stops:
		offsets.append(stop[0])
		colors.append(stop[1])
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = from
	texture.fill_to = to
	texture.width = 512
	texture.height = 512
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
