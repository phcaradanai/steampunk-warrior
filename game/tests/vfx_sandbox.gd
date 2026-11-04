extends Control
# VFX Sandbox — every combat effect on the real arena art, hero and foes, through the same code the game runs:
# ToonFx kinds are spawned with ToonFx.spawn/setup, and "gameplay events"/"skills" go through a real CombatFeedback.
# Run: Godot --path game res://tests/vfx_sandbox.tscn   (dev only; tests/* is excluded from export)
# Guide: docs/vfx/VFX_SANDBOX_GUIDE.md. Captures: tests/vfx_showcase.gd drives this scene on a fixed clock.

const StageHolder := preload("res://tests/vfx_lab/stage_holder.gd")
const LegacyFx := preload("res://tests/vfx_lab/toon_fx_v1.gd")

const SIDEBAR := 300.0
const VIEW := Rect2(300, 0, 980, 552)
const FOES := {"N12":"ทหารเกราะทองเหลือง", "N01":"หนูกลายพันธุ์", "N15":"มือปืนเสื้อโค้ท", "N21":"ยักษ์เหล็ก", "dummy":"หุ่นซ้อม"}
const BACKDROPS := ["canal", "rail", "garden", "coal", "foundry", "archive", "reactor", "light", "dark"]
const HERO_FEET := Vector2(330, 560)
const FOE_FEET := Vector2(910, 560)
const CATEGORIES := [
	["กระแทก (Impacts)", ["hit", "crit", "muzzle", "thrust", "slash2", "cleave", "smash", "bite"]],
	["ธาตุ (Elemental)", ["zap", "zap_hit", "thunder", "fire", "cloud", "splash", "snare"]],
	["สนับสนุน / ร่าย (Support & casts)", ["heal", "block", "dome", "charge", "haste", "steam", "warp", "howl", "reticle"]],
	["เดินทาง / รางวัล (Travel & loot)", ["bolt", "beam"]],
	["สถานะต่อเนื่อง (Status auras)", ["aura_wet", "aura_heated", "aura_corroded", "aura_marked", "aura_sealed", "aura_staggered", "aura_haste"]],
]
# Whole gameplay beats played by CombatFeedback itself (flash, recoil, numbers, shake, hit-stop, sounds).
const EVENTS := {
	"event:hero_hit":"ฮีโร่ตีโดน (crit ของผู้เล่น)", "event:enemy_hit":"ศัตรูตีโดนฮีโร่", "event:blocked":"ฮีโร่ป้องกัน",
	"event:heal":"ฟื้นพลัง", "event:miss":"หลบ / พลาด", "event:loot":"ชนะ + ของดรอป"}
# Effects drawn on the caster (CombatFeedback spawns `cast` recipes and ACTION_VFX at the actor).
const CASTS := ["charge", "dome", "haste", "steam", "warp"]
const AURA_HEIGHT := {"aura_wet":0.45, "aura_heated":0.6, "aura_corroded":0.65, "aura_marked":0.45, "aura_sealed":0.6,
	"aura_staggered":0.22, "aura_haste":0.6}
const STRIKES := ["hit", "crit", "thrust", "slash2", "cleave", "smash", "zap_hit", "thunder", "fire", "splash", "snare",
	"bite", "cloud", "reticle"]
const PURPOSE := {
	"hit":"การโจมตีปกติโดนเป้า", "crit":"การโจมตีของผู้เล่น / คริติคอล — แรงที่สุดในกลุ่มกระแทก", "muzzle":"ปากกระบอกปืนตอนยิง",
	"thrust":"ท่าแทง S01", "slash2":"ฟันต่อเนื่อง S02 / ศัตรูสาย quick", "cleave":"ฟันกวาด S16", "smash":"ค้อน S07 / ศัตรูพุ่งชน",
	"bite":"ศัตรูกัด", "zap":"สายฟ้าวิ่งหาเป้า S04/S06", "zap_hit":"สายฟ้ากระทบ", "thunder":"ฟ้าผ่าลงเป้า S15",
	"fire":"ไฟลุก S14 / สถานะร้อนจัด", "cloud":"หมอกพิษ S08", "splash":"น้ำแตก S20", "snare":"ห่วงทองแดงรัด S21",
	"heal":"ฟื้น HP S09 / โพชั่น", "block":"กันการโจมตีด้วยโล่", "dome":"สนามโล่ S11 / คำสั่งป้องกัน", "charge":"รวมพลังก่อนร่าย",
	"haste":"เร่งความเร็ว S10", "steam":"ระบายไอน้ำ (คำสั่ง vent)", "warp":"ปล่อยโดรน S12", "howl":"ศัตรูหอน", "reticle":"เล็งจุดอ่อน S03",
	"bolt":"กระสุน / พลังวิ่งหาเป้า", "beam":"ลำแสงของดรอป", "aura_wet":"สถานะเปียก", "aura_heated":"สถานะร้อนจัด",
	"aura_corroded":"สถานะกัดกร่อน", "aura_marked":"สถานะถูกล็อกเป้า", "aura_sealed":"สถานะถูกผนึก", "aura_staggered":"สถานะมึน",
	"aura_haste":"สถานะเร่งความเร็ว"}
const COMPARE_WITH := {"v1":"ต้นฉบับ polygon (ก่อนปรับ)"}

var current := "thunder"          # selected library id: a ToonFx kind, "event:…" or "skill:S01"
var compare := false
var compare_with := "v1"
var paused := false
var play_speed := 1.0
var loop := false
var flash := true
var shake := true
var zoom := 1.0
var foe_key := "N12"
var backdrop := "canal"
var full_view := false
var primary: Array = []       # live effects the scrubber drives
var held: Array = []          # loops kept until the next play
var skills: Dictionary = {}   # id -> skills.json entry
var frame_ms := 0.0

var clip: Control
var holder: Control
var stage: Control
var art: TextureRect
var flat: ColorRect
var hero: ActorPortrait
var foe: ActorPortrait
var twin: ActorPortrait       # compare mode: the left foe that shows the other version
var feedback: CombatFeedback
var overlay: Control          # == feedback; kept for scripts that spawn into the sandbox
var panel: Control            # all UI; hidden for captures and the 1:1 view
var tree: Tree
var search: LineEdit
var title: Label
var about: Label
var hud: Label
var status: Label
var scrub: HSlider
var params: Dictionary = {}   # param name -> Range or ColorPickerButton
var param_box: Control
var labels: Array = []

func _ready() -> void:
	size = Vector2(1280, 720)
	for skill in JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json")):
		if skill.has("vfx"): skills[skill.id] = skill
	var back := ColorRect.new()
	back.color = Color("0b1214")
	back.size = size
	add_child(back)
	clip = Control.new()
	clip.clip_contents = true
	add_child(clip)
	holder = StageHolder.new()
	clip.add_child(holder)
	stage = Control.new()
	stage.size = Vector2(1280, 720)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(stage)
	holder.stage = stage
	art = TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size = stage.size
	stage.add_child(art)
	flat = ColorRect.new()
	flat.size = stage.size
	stage.add_child(flat)
	hero = _figure(Hero3D.new(), HERO_FEET, Vector2(300, 300), false)
	feedback = CombatFeedback.new()
	feedback.size = stage.size
	holder.add_child(feedback)
	overlay = feedback
	_build_ui()
	set_backdrop("canal")
	set_foe("N12")
	_layout()
	select(current)

func _process(delta: float) -> void:
	frame_ms = lerpf(frame_ms, delta * 1000.0 / maxf(Engine.time_scale, 0.0001), 0.1)
	if Engine.get_process_frames() % 10 == 0 and hud != null:
		var live := feedback.find_children("*", "Node2D", false, false).size()
		hud.text = "FPS %d · เฟรม %.1f ms · เอฟเฟกต์ที่ทำงาน %d · draw calls %d · objects %d" % [Engine.get_frames_per_second(),
			frame_ms, live, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)]
	if scrub != null and not paused and not primary.is_empty() and is_instance_valid(primary[0]):
		var fx = primary[0]
		scrub.set_value_no_signal(clampf(fx.clock / _life(fx), 0.0, 1.0))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo: return
	match event.keycode:
		KEY_SPACE: play()
		KEY_P: set_paused(not paused)
		KEY_PERIOD: step()
		KEY_C: set_compare(not compare)
		KEY_F12: screenshot()
		KEY_ESCAPE, KEY_G: set_full_view(not full_view)
		KEY_DOWN, KEY_RIGHT: _walk(1)
		KEY_UP, KEY_LEFT: _walk(-1)

# ---------------------------------------------------------------- stage

func _figure(figure: Stage3D, feet: Vector2, frame: Vector2, is_foe: bool) -> ActorPortrait:
	var portrait := ActorPortrait.new()
	portrait.mirror = is_foe
	portrait.size = frame
	portrait.set_meta("feet", frame.y * 0.925)
	portrait.set_meta("body", frame.x)
	if figure != null:
		figure.facing_left = is_foe
		portrait.attach_hero(figure)
	portrait.position = feet - Vector2(frame.x * 0.5, frame.y * 0.925)
	portrait.set_meta("home", portrait.position)
	stage.add_child(portrait)
	return portrait

# Same anchor maths as CombatFeedback._anchor (stage coordinates).
func anchor(portrait: ActorPortrait, height: float) -> Vector2:
	return portrait.position + Vector2(portrait.size.x * 0.5, portrait.get_meta("feet") * height)

func set_backdrop(name: String) -> void:
	backdrop = name
	flat.visible = name in ["light", "dark"]
	flat.color = Color("d9d3c4") if name == "light" else Color("0d1518")
	if not flat.visible: art.texture = load("res://art/environments/arena_%s.png" % name)
	_sync()

func set_foe(key: String) -> void:
	# CombatFeedback holds the portraits until its beat ends; swapping them mid-beat would free a live target.
	while feedback.playing > 0: await get_tree().process_frame
	foe_key = key
	for portrait in [foe, twin]:
		if portrait != null: portrait.queue_free()
	twin = null
	foe = _figure(Roster3D.create(key), FOE_FEET, Vector2(250, 250), true)
	if compare:
		hero.visible = false
		foe.position.x = FOE_FEET.x - 125.0
		foe.set_meta("home", foe.position)
		twin = _figure(Roster3D.create(key), Vector2(430, FOE_FEET.y), Vector2(250, 250), true)
	else:
		hero.visible = true
	_place_labels()
	_sync()

func set_compare(on: bool) -> void:
	compare = on
	await set_foe(foe_key)
	select(current)

func _place_labels() -> void:
	for label in labels: label.queue_free()
	labels.clear()
	if not compare: return
	for pair in [[twin, COMPARE_WITH[compare_with]], [foe, "ปัจจุบัน texture (ใช้ในเกม)"]]:
		var label := Label.new()
		label.text = pair[1]
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color("f1d9a0"))
		label.add_theme_color_override("font_outline_color", Color("09171b"))
		label.add_theme_constant_override("outline_size", 8)
		label.position = Vector2(pair[0].position.x + pair[0].size.x * 0.5 - 160.0, 120)
		label.size = Vector2(320, 40)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stage.add_child(label)
		labels.append(label)

func set_full_view(on: bool) -> void:
	full_view = on
	_layout()

func set_zoom(value: float) -> void:
	zoom = value
	_layout()

func _layout() -> void:
	panel.visible = not full_view
	var area := Rect2(Vector2.ZERO, size) if full_view else VIEW
	clip.position = area.position
	clip.size = area.size
	var fit := minf(area.size.x / 1280.0, area.size.y / 720.0) * zoom
	holder.scale = Vector2.ONE * fit
	# Zoom about the foe so "camera distance" keeps the target in view.
	var focus := Vector2(1280, 720) * 0.5 if zoom <= 1.0 else Vector2(FOE_FEET.x - (125.0 if compare else 0.0), 420)
	holder.position = area.size * 0.5 - focus * fit

# ---------------------------------------------------------------- playback

func select(id: String) -> void:
	current = id
	if compare: _place_labels()
	if tree != null and (tree.get_selected() == null or tree.get_selected().get_metadata(0) != id): _fill_tree()
	_sync()
	_show_params()
	play()

func _walk(step_by: int) -> void:
	var ids := _ids()
	var at := ids.find(current)
	select(ids[wrapi(at + step_by, 0, ids.size())])

func _ids() -> Array:
	var out: Array = []
	for group in CATEGORIES: out += group[1]
	out += EVENTS.keys()
	for id in skills: out.append("skill:" + id)
	return out

func _duration(kind: String) -> float:
	return ToonFx.DURATION.get(kind, 0.75) / float(ToonFx.preset(kind).speed)

func play() -> void:
	if feedback.playing > 0: return
	set_paused(false)
	for fx in held + primary:
		if is_instance_valid(fx): fx.queue_free()
	held.clear()
	primary.clear()
	var id := current
	if id.begins_with("event:"):
		await _play_event(id.trim_prefix("event:"))
	elif id.begins_with("skill:"):
		await _play_skill(id.trim_prefix("skill:"))
	else:
		primary.append(spawn(id))
		if compare: primary.append(_spawn_other(id))
		if id in STRIKES:
			feedback.shake_enabled = shake
			feedback.trauma = 0.7 if shake else 0.0
			for target in ([foe, twin] if compare else [foe]):
				if flash: target.create_tween().tween_property(target, "modulate", Color.WHITE, CombatFeedback.HIT_FLASH_TIME).from(CombatFeedback.HIT_FLASH).set_ease(Tween.EASE_OUT)
		for fx in primary:
			if fx.loop: held.append(fx)
		if not id in ToonFx.LOOPS: await get_tree().create_timer(_duration(id) + 0.05).timeout
	if loop and is_inside_tree() and current == id:
		await get_tree().create_timer(0.45).timeout
		if loop and not paused and current == id: play()

# Spawns `kind` where the game would (hero on the left hits the foe on the right) and returns it.
func spawn(kind: String) -> ToonFx:
	for fx in held:
		if is_instance_valid(fx): fx.queue_free()
	held.clear()
	var at := _placement(kind, foe)
	var fx := ToonFx.spawn(feedback, kind, at[0], at[1], at[2])
	_aim(fx, kind)
	return fx

func _spawn_other(kind: String) -> Node2D:
	var at := _placement(kind, twin)
	var fx: Node2D
	fx = LegacyFx.spawn(feedback, kind, at[0], at[1], at[2])
	_aim(fx, kind)
	return fx

# [point, flip, size] the way CombatFeedback places each kind; in compare mode casts sit on the foe itself.
func _placement(kind: String, target: ActorPortrait) -> Array:
	if kind in CASTS and not compare: return [anchor(hero, 0.55), false, 1.0]
	if kind in CASTS or kind == "muzzle": return [anchor(target, 0.55), false, 1.0]
	if kind in ["heal", "beam"]: return [anchor(target, 1.0), false, 1.0]
	if kind == "block": return [anchor(target, 0.5), true, 1.0]
	if AURA_HEIGHT.has(kind): return [anchor(target, AURA_HEIGHT[kind]), true, 0.9]
	if kind in ["bolt", "zap"]: return [anchor(target, 0.45) - Vector2(360, 0), false, 1.0]
	return [anchor(target, 0.5), false, 1.0]

func _aim(fx: Node2D, kind: String) -> void:
	if kind == "zap": fx.reach = Vector2(360, 0)
	if kind == "bolt": fx.position += Vector2(180, 0)

func _portraits() -> Dictionary:
	return {"hero":hero, "foe":foe}

func _options() -> Dictionary:
	return {"reduced_shake":not shake, "reduced_flash":not flash}

func _play_event(id: String) -> void:
	feedback.current_vfx = {}
	var events: Array = []
	match id:
		"hero_hit": events = [{"type":"damage", "payload":{"target_id":"foe", "source_id":"hero", "amount":24}}]
		"enemy_hit": events = [{"type":"damage", "payload":{"target_id":"hero", "source_id":"foe", "amount":9}}]
		"blocked": events = [{"type":"damage", "payload":{"target_id":"hero", "source_id":"foe", "amount":3, "shielded":true}}]
		"heal": events = [{"type":"heal", "payload":{"target_id":"hero", "amount":30}}]
		"miss": events = [{"type":"miss", "payload":{"target_id":"foe", "source_id":"hero"}}]
		"loot":
			var items: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
			await feedback.play_loot(foe, 60, items[0], {})
			return
	await feedback.play_events(events, _portraits(), _options())

# A real skill turn: the action (dash, clip, cast, projectile) then its damage or heal, exactly as in a fight.
func _play_skill(id: String) -> void:
	var skill: Dictionary = skills[id]
	var events: Array = [{"type":"action", "payload":{"actor_id":"hero", "kind":"skill", "skill_id":id}}]
	if skill.vfx.get("impact", "") == "heal":
		events.append({"type":"heal", "payload":{"target_id":"hero", "amount":30}})
	elif skill.get("target", "") in ["enemy", "all_enemies"]:
		events.append({"type":"damage", "payload":{"target_id":"foe", "source_id":"hero", "amount":42}})
	await feedback.play_events(events, _portraits(), _options())

func set_paused(on: bool) -> void:
	paused = on
	Engine.time_scale = 0.0 if paused else play_speed
	_sync()

func set_speed(value: float) -> void:
	play_speed = value
	if not paused: Engine.time_scale = value
	_sync()

# One 60 Hz frame forward for the effects on screen (ToonFx clocks; tweens stay frozen while paused).
func step() -> void:
	set_paused(true)
	for fx in feedback.get_children():
		if fx is Node2D and "clock" in fx:
			fx.clock += 1.0 / 60.0 * float(fx.get("speed") if "speed" in fx else 1.0)
			if fx.has_method("_pose"): fx._pose()
			fx.queue_redraw()

func _life(fx: Node) -> float:
	return float(fx.life) if "life" in fx else ToonFx.DURATION.get(fx.kind, 0.75)

func _scrubbed(value: float) -> void:
	if primary.is_empty(): return
	set_paused(true)
	for fx in primary:
		if is_instance_valid(fx):
			fx.clock = value * _life(fx) * 0.999
			if fx.has_method("_pose"): fx._pose()
			fx.queue_redraw()

# Flash state `seconds` after contact, for fixed-clock captures.
func flash_foe(seconds: float) -> void:
	var k := clampf(seconds / CombatFeedback.HIT_FLASH_TIME, 0.0, 1.0)
	for target in ([foe, twin] if compare else [foe]):
		target.modulate = CombatFeedback.HIT_FLASH.lerp(Color.WHITE, 1.0 - pow(1.0 - k, 2.0)) if flash else Color.WHITE

func screenshot() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://vfx_captures")
	var path := "user://vfx_captures/%s_%s.png" % [current.replace(":", "_"), Time.get_datetime_string_from_system().replace(":", "")]
	Captures.frame(get_viewport()).save_png(path)
	_status("บันทึกภาพแล้ว: " + ProjectSettings.globalize_path(path))

# ---------------------------------------------------------------- presets

func _show_params() -> void:
	var is_kind := not current.contains(":")
	param_box.visible = is_kind
	if not is_kind: return
	var p := ToonFx.preset(current)
	for key in ["scale", "speed", "opacity", "density"]:
		params[key].set_value_no_signal(float(p[key]))
	params.tint.color = Color(p.tint) if not String(p.tint).is_empty() else Color(ToonFx.TINTS.get(current, "efbb71"))

func _set_param(key: String, value: Variant) -> void:
	if current.contains(":"): return
	var entry: Dictionary = ToonFx.presets.get(current, {})
	entry[key] = value
	ToonFx.presets[current] = entry
	_status("พรีเซ็ต %s: %s = %s (ยังไม่บันทึก)" % [current, key, str(value)])
	play()

func _reset_preset() -> void:
	ToonFx.presets.erase(current)
	_show_params()
	_status("คืนค่าเริ่มต้นของ " + current)
	play()

func _save_presets() -> void:
	var error := ToonFx.save_presets()
	_status("บันทึกพรีเซ็ตลง data/vfx_presets.json แล้ว — เกมใช้ค่านี้ทันที" if error == OK else "บันทึกไม่ได้ (error %d)" % error)

func _reload_presets() -> void:
	ToonFx.reload_presets()
	_show_params()
	_status("โหลดพรีเซ็ตจากไฟล์แล้ว")

# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	panel = Control.new()
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var side := _box(panel, Rect2(0, 0, SIDEBAR, 720), Color("101b20"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	side.add_child(col)
	_label(col, "VFX Sandbox", 22, Color("f1d9a0"))
	_label(col, "Space เล่น · P หยุด · . ทีละเฟรม · ↑↓ เลือก · C เทียบ · G มุมมองจริง · F12 จับภาพ", 11, Color("8fa6a8"), true)
	search = LineEdit.new()
	search.placeholder_text = "ค้นหาเอฟเฟกต์…"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_t): _fill_tree())
	col.add_child(search)
	tree = Tree.new()
	tree.hide_root = true
	tree.custom_minimum_size = Vector2(0, 380)
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.add_theme_font_size_override("font_size", 13)
	tree.item_selected.connect(func():
		var item := tree.get_selected()
		if item != null and item.get_metadata(0) != null and item.get_metadata(0) != current: select(item.get_metadata(0)))
	col.add_child(tree)
	_fill_tree()
	about = _label(col, "", 13, Color("c9d6d3"), true)
	about.custom_minimum_size = Vector2(SIDEBAR - 20, 0)
	# Bottom bar under the stage.
	var bottom := _box(panel, Rect2(SIDEBAR, VIEW.end.y, 1280 - SIDEBAR, 720 - VIEW.end.y), Color("101b20"))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	bottom.add_child(rows)
	var head := HBoxContainer.new()
	rows.add_child(head)
	title = _label(head, "", 16, Color("f1d9a0"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status = _label(head, "", 12, Color("83dcb3"))
	var transport := HBoxContainer.new()
	rows.add_child(transport)
	_button(transport, "▶ เล่น", play)
	_button(transport, "⏸ หยุด", func(): set_paused(not paused))
	_button(transport, "⏭ เฟรม", step)
	_label(transport, " ไทม์ไลน์", 12, Color("8fa6a8"))
	scrub = HSlider.new()
	scrub.min_value = 0.0
	scrub.max_value = 1.0
	scrub.step = 0.001
	scrub.custom_minimum_size = Vector2(230, 0)
	scrub.focus_mode = Control.FOCUS_NONE
	scrub.value_changed.connect(_scrubbed)
	transport.add_child(scrub)
	_label(transport, " ความเร็ว", 12, Color("8fa6a8"))
	var speed := OptionButton.new()
	speed.focus_mode = Control.FOCUS_NONE
	for s in [0.1, 0.25, 0.5, 1.0, 2.0]: speed.add_item("%sx" % s)
	speed.select(3)
	speed.item_selected.connect(func(i): set_speed([0.1, 0.25, 0.5, 1.0, 2.0][i]))
	_compact(speed, 70)
	transport.add_child(speed)
	_toggle(transport, "วน", false, func(on): loop = on; play())
	_toggle(transport, "แฟลช", true, func(on): flash = on)
	_toggle(transport, "สั่น", true, func(on): shake = on)
	_button(transport, "มุมมองจริง (G)", func(): set_full_view(true))
	_button(transport, "📷 จับภาพ", screenshot)
	var env := HBoxContainer.new()
	rows.add_child(env)
	_toggle(env, "เทียบ A/B", false, set_compare)
	var versus := OptionButton.new()
	versus.focus_mode = Control.FOCUS_NONE
	for key in COMPARE_WITH: versus.add_item(COMPARE_WITH[key])
	versus.item_selected.connect(func(i): compare_with = COMPARE_WITH.keys()[i]; _place_labels(); play())
	_compact(versus, 150)
	env.add_child(versus)
	var back := OptionButton.new()
	back.focus_mode = Control.FOCUS_NONE
	for name in BACKDROPS: back.add_item({"light":"พื้นสว่าง", "dark":"พื้นมืด"}.get(name, "ฉาก " + name))
	back.item_selected.connect(func(i): set_backdrop(BACKDROPS[i]))
	_compact(back, 110)
	env.add_child(back)
	var foes := OptionButton.new()
	foes.focus_mode = Control.FOCUS_NONE
	for key in FOES: foes.add_item(FOES[key])
	foes.item_selected.connect(func(i): await set_foe(FOES.keys()[i]); play())
	_compact(foes, 130)
	env.add_child(foes)
	_label(env, " ระยะกล้อง", 12, Color("8fa6a8"))
	var distance := HSlider.new()
	distance.min_value = 0.6
	distance.max_value = 1.6
	distance.step = 0.05
	distance.value = 1.0
	distance.focus_mode = Control.FOCUS_NONE
	distance.custom_minimum_size = Vector2(80, 0)
	distance.value_changed.connect(set_zoom)
	env.add_child(distance)
	var res := OptionButton.new()
	res.focus_mode = Control.FOCUS_NONE
	for r in ["1280×720", "960×540", "1920×1080"]: res.add_item(r)
	res.item_selected.connect(func(i):
		DisplayServer.window_set_size([Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1920, 1080)][i])
		_status("หน้าต่าง " + res.get_item_text(i)))
	_compact(res, 100)
	env.add_child(res)
	param_box = HBoxContainer.new()
	rows.add_child(param_box)
	_label(param_box, "พรีเซ็ต:", 12, Color("8fa6a8"))
	for spec in [["scale", "ขนาด", 0.5, 2.0], ["speed", "ความเร็ว", 0.25, 2.0], ["opacity", "ทึบ", 0.2, 1.0], ["density", "จำนวนชิ้น", 0.3, 2.0]]:
		_label(param_box, spec[1], 12, Color("c9d6d3"))
		var slider := HSlider.new()
		slider.min_value = spec[2]
		slider.max_value = spec[3]
		slider.step = 0.05
		slider.focus_mode = Control.FOCUS_NONE
		slider.custom_minimum_size = Vector2(70, 0)
		slider.drag_ended.connect(func(_changed): _set_param(spec[0], snappedf(slider.value, 0.05)))
		param_box.add_child(slider)
		params[spec[0]] = slider
	var picker := ColorPickerButton.new()
	picker.focus_mode = Control.FOCUS_NONE
	picker.custom_minimum_size = Vector2(36, 0)
	picker.popup_closed.connect(func(): _set_param("tint", picker.color.to_html(false)))
	param_box.add_child(picker)
	params.tint = picker
	_button(param_box, "คืนค่า", _reset_preset)
	_button(param_box, "บันทึก", _save_presets)
	_button(param_box, "โหลด", _reload_presets)
	hud = Label.new()
	hud.position = VIEW.position + Vector2(10, 8)
	hud.add_theme_font_size_override("font_size", 13)
	hud.add_theme_color_override("font_color", Color("e8f0ee"))
	hud.add_theme_color_override("font_outline_color", Color("09171b"))
	hud.add_theme_constant_override("outline_size", 5)
	panel.add_child(hud)

func _fill_tree() -> void:
	tree.clear()
	var root := tree.create_item()
	var filter := search.text.strip_edges().to_lower()
	var groups: Array = CATEGORIES.duplicate()
	groups.append(["เหตุการณ์ในเกมจริง (Gameplay events)", EVENTS.keys()])
	var skill_ids: Array = []
	for id in skills: skill_ids.append("skill:" + id)
	groups.append(["สกิลผู้เล่น (Skills, ระบบเดียวกับในเกม)", skill_ids])
	for group in groups:
		var parent: TreeItem = null
		for id in group[1]:
			var text := _name(id)
			if not filter.is_empty() and not (text.to_lower().contains(filter) or id.contains(filter) or PURPOSE.get(id, "").contains(filter)): continue
			if parent == null:
				parent = tree.create_item(root)
				parent.set_text(0, group[0])
				parent.set_selectable(0, false)
				parent.set_custom_color(0, Color("f1d9a0"))
			var item := tree.create_item(parent)
			item.set_text(0, text)
			item.set_metadata(0, id)
			if id == current:
				item.select(0)
				tree.scroll_to_item(item)

func _name(id: String) -> String:
	if EVENTS.has(id): return EVENTS[id]
	if id.begins_with("skill:"):
		var skill: Dictionary = skills[id.trim_prefix("skill:")]
		return "%s %s" % [skill.id, skill.name]
	return id

func _sync() -> void:
	if title == null: return
	title.text = _name(current) + ("  —  " + current if not current.contains(":") else "") + ("   ⏸" if paused else "")
	var detail: String = PURPOSE.get(current, "")
	if current.begins_with("skill:"): detail = "สูตร: " + JSON.stringify(skills[current.trim_prefix("skill:")].vfx)
	elif current.begins_with("event:"): detail = "เล่นผ่าน CombatFeedback จริง (ตัวเลข, แฟลช, สั่น, เสียง)"
	elif not current.contains(":"): detail += " · %.2f s%s" % [_duration(current), " (วน)" if current in ToonFx.LOOPS else ""]
	if compare and current.contains(":"): detail += " · โหมดเทียบใช้กับเอฟเฟกต์เดี่ยวเท่านั้น"
	about.text = detail

func _status(text: String) -> void:
	if status != null: status.text = text

func _box(parent: Control, rect: Rect2, color: Color) -> PanelContainer:
	var box := PanelContainer.new()
	box.position = rect.position
	box.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(10)
	box.add_theme_stylebox_override("panel", style)
	parent.add_child(box)
	return box

func _label(parent: Control, text: String, font_size: int, color: Color, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if wrap: label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _compact(option: OptionButton, width: float) -> void:
	option.fit_to_longest_item = false
	option.clip_text = true
	option.custom_minimum_size = Vector2(width, 0)
	option.add_theme_font_size_override("font_size", 12)

func _toggle(parent: Control, text: String, on: bool, action: Callable) -> void:
	var box := CheckButton.new()
	box.text = text
	box.button_pressed = on
	box.focus_mode = Control.FOCUS_NONE
	box.add_theme_font_size_override("font_size", 12)
	box.toggled.connect(action)
	parent.add_child(box)
