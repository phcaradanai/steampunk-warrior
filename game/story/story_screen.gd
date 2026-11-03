extends Control
# Full-screen story pages: a dimmed backdrop, up to four 3D figures, a text panel. Enter/click/Next advances, Esc/Skip ends.
# Art is composed from existing assets (environments/*.png, Hero3D and Roster3D figures) as a placeholder until the D3 repaint.

signal finished

var pages: Array = []
var figure_factory: Callable
var instant: bool = false
var speed: float = 40.0
var final_label: String = "จบ"
var index: int = -1
var done: bool = false
var backdrop: TextureRect
var figure_layer: Control
var title_label: Label
var text_label: Label
var counter: Label
var next_button: Button
var panel: ColorRect
var rule: ColorRect
var tween: Tween

func _ready() -> void:
	name = "StoryScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var base := ColorRect.new()
	base.color = Color("050a0c")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	backdrop = TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.modulate = Color(0.55, 0.6, 0.62)
	add_child(backdrop)
	figure_layer = Control.new()
	figure_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	figure_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(figure_layer)
	panel = ColorRect.new()
	panel.color = Color(0.02, 0.05, 0.06, 0.9)
	panel.position = Vector2(0, 470)
	panel.size = Vector2(1280, 250)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	rule = ColorRect.new()
	rule.color = Color("d2ad66")
	rule.position = Vector2(0, 470)
	rule.size = Vector2(1280, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	title_label = _label(Vector2(90, 484), Vector2(1100, 40), 28, Color("e7c588"))
	text_label = _label(Vector2(90, 530), Vector2(1100, 120), 22, Color("e6dfca"))
	counter = _label(Vector2(90, 662), Vector2(200, 30), 16, Color("8bb2a3"))
	next_button = UIBuilder.button(self, "ต่อไป  [Enter]", _advance, "StoryNext")
	next_button.position = Vector2(1280 - 90 - 240, 654)
	next_button.size = Vector2(240, 44)
	var skip := UIBuilder.button(self, "ข้าม  [Esc]", finish, "StorySkip")
	skip.position = Vector2(1280 - 16 - 160, 16)
	skip.size = Vector2(160, 40)
	(func(): if is_instance_valid(next_button) and next_button.is_inside_tree(): next_button.grab_focus()).call_deferred()
	_advance()

func _label(at: Vector2, area: Vector2, font: int, color: Color) -> Label:
	var node := UIBuilder.label(self, "", font, color)
	node.position = at
	node.size = area
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		finish()
		get_viewport().set_input_as_handled()

func _advance() -> void:
	if done:
		return
	if tween != null and tween.is_running():
		tween.kill()
		text_label.visible_ratio = 1.0
		return
	index += 1
	if index >= pages.size():
		finish()
		return
	_show_page(pages[index])

func _show_page(page: Dictionary) -> void:
	var path := "res://art/environments/%s.png" % page.get("backdrop", "hub")
	backdrop.texture = load(path) if ResourceLoader.exists(path) else load("res://art/environments/hub.png")
	for child in figure_layer.get_children():
		figure_layer.remove_child(child)
		child.queue_free()
	var ids: Array = page.get("figures", [])
	var spacing := 300.0
	var left := 640.0 - spacing * (ids.size() - 1) * 0.5 - 200.0
	for i in ids.size():
		var figure: Stage3D = figure_factory.call(ids[i]) if figure_factory.is_valid() else null
		if figure == null:
			continue
		figure.size = Vector2(400, 400)  # wide enough that weapons are not clipped by the viewport edge
		figure.position = Vector2(left + spacing * i, 62)
		figure.facing_left = i % 2 == 1
		figure_layer.add_child(figure)
	# Credits fill the whole screen; story pages keep the bottom text panel.
	var credits: bool = page.get("credits", false)
	panel.position.y = 0 if credits else 470
	panel.size.y = 720 if credits else 250
	rule.visible = not credits
	title_label.position.y = 60 if credits else 484
	text_label.position.y = 120 if credits else 530
	text_label.size.y = 520 if credits else 120
	title_label.add_theme_font_size_override("font_size", 38 if credits else 28)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if credits else HORIZONTAL_ALIGNMENT_LEFT
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if credits else HORIZONTAL_ALIGNMENT_LEFT
	title_label.text = page.get("title", "")
	text_label.text = page.get("text", "")
	counter.text = "%d / %d" % [index + 1, pages.size()]
	next_button.text = (final_label if index == pages.size() - 1 else "ต่อไป") + "  [Enter]"
	text_label.visible_ratio = 1.0
	if not instant:
		text_label.visible_ratio = 0.0
		tween = create_tween()
		tween.tween_property(text_label, "visible_ratio", 1.0, maxf(0.3, float(text_label.text.length()) / maxf(1.0, speed)))

func finish() -> void:
	if done:
		return
	done = true
	finished.emit()
	queue_free()
