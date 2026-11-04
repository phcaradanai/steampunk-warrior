class_name SkillTree
extends Control
# Three branch columns of hexagon skill nodes under a branch emblem, rows by unlock level, joined by elbow links.

const BRANCHES := [
	{"id":"support","name":"ป้องกันและฟื้นฟู","icon":"heal","color":Color("63c95a")},
	{"id":"combat","name":"ต่อสู้","icon":"fight","color":Color("e8573a")},
	{"id":"tech","name":"เทคโนโลยี","icon":"electric","color":Color("e9bd3a")},
]
const LEVELS := [1, 5, 10, 15]
const HEX := 31.0       # hexagon radius (centre to corner)
const ROW_TOP := 132.0  # y of the first row's centres, below the emblem and branch name
const ROW_GAP := 94.0
const NODE_GAP := 74.0

var skills: Array = []
var ranks: Dictionary = {}
var pick: String = ""
var learnable: Callable
var on_pick: Callable
var centres: Dictionary = {}
var colors: Dictionary = {}
# Textures are loaded before drawing: one first loaded inside _draw renders as a flat square on GL Compatibility.
var emblems: Array[Texture2D] = []

func setup(all_skills: Array, skill_ranks: Dictionary, picked: String, can_learn: Callable, picked_callback: Callable) -> SkillTree:
	skills = all_skills
	ranks = skill_ranks
	pick = picked
	learnable = can_learn
	on_pick = picked_callback
	custom_minimum_size = Vector2(0, ROW_TOP + ROW_GAP * (LEVELS.size() - 1) + HEX + 14.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Some icons import without mipmaps; a mipmapped filter samples them as one flat colour.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(_layout)
	return self

func _ready() -> void:
	for branch in BRANCHES:
		emblems.append(load("res://art/icons/%s.svg" % branch.icon))
	for skill in skills:
		var node := HexNode.new()
		node.name = "Skill_" + skill.id
		node.tree = self
		node.skill = skill
		node.icon_texture = UIBuilder.skill_icon(skill)
		node.tooltip_text = "%s · ต้องเลเวล %d" % [skill.name, skill.required_level]
		node.pressed.connect(on_pick.bind(skill.id))
		node.pressed.connect(func(): if node.is_inside_tree(): node.get_tree().call_group("game_audio","play_sfx","ui"))
		add_child(node)
	_layout()

func branch_of(skill: Dictionary) -> int:
	for i in BRANCHES.size():
		if BRANCHES[i].id == skill.get("branch", "combat"): return i
	return 1

func _layout() -> void:
	if size.x <= 0.0: return
	var column := size.x / BRANCHES.size()
	centres.clear()
	for b in BRANCHES.size():
		for row in LEVELS.size():
			var members := skills.filter(func(s): return branch_of(s) == b and int(s.required_level) == LEVELS[row])
			# Sit each node under its parents (already placed in earlier rows) so links stay short and uncrossed.
			members.sort_custom(func(a, c): return _parent_x(a, column * (b + 0.5)) < _parent_x(c, column * (b + 0.5)))
			for i in members.size():
				centres[members[i].id] = Vector2(column * (b + 0.5) + (i - (members.size() - 1) * 0.5) * NODE_GAP, ROW_TOP + row * ROW_GAP)
	for child in get_children():
		if child is HexNode:
			colors[child.skill.id] = BRANCHES[branch_of(child.skill)].color
			child.size = Vector2.ONE * HEX * 2.0
			child.position = centres[child.skill.id] - child.size * 0.5
	queue_redraw()

func _parent_x(skill: Dictionary, fallback: float) -> float:
	var xs: Array = skill.parents.filter(func(id): return centres.has(id)).map(func(id): return centres[id].x)
	if xs.is_empty(): return fallback
	return xs.reduce(func(a, x): return a + x, 0.0) / xs.size()

func _draw() -> void:
	var column := size.x / BRANCHES.size()
	var font := get_theme_default_font()
	for b in BRANCHES.size():
		var branch: Dictionary = BRANCHES[b]
		var area := Rect2(column * b + 3.0, 0.0, column - 6.0, size.y)
		draw_rect(area, Color(branch.color, 0.07))
		draw_rect(area, Color(branch.color, 0.28), false, 1.0)
		# Branch emblem: ringed medallion with the branch icon and name.
		var at := Vector2(column * (b + 0.5), 34.0)
		draw_circle(at, 27.0, Color(branch.color, 0.18))
		draw_circle(at, 24.0, Color(0.05, 0.07, 0.07))
		draw_arc(at, 24.0, 0.0, TAU, 40, branch.color, 3.0, true)
		draw_texture_rect(emblems[b], Rect2(at - Vector2(15, 15), Vector2(30, 30)), false, branch.color.lightened(0.35))
		draw_string(font, Vector2(area.position.x, at.y + 48.0), branch.name, HORIZONTAL_ALIGNMENT_CENTER, area.size.x, 13, Color(branch.color, 0.85))
	# Links behind the nodes: elbow from the parent's bottom to just above the child, with joint dots.
	var chain := {pick: true}
	for skill in skills:
		if skill.id == pick:
			for parent in skill.parents: chain[parent] = true
	for skill in skills:
		for parent in skill.parents:
			if not centres.has(parent) or not centres.has(skill.id): continue
			var from: Vector2 = centres[parent] + Vector2(0, HEX)
			var to: Vector2 = centres[skill.id] - Vector2(0, HEX)
			var bend := to.y - 16.0
			var lit := int(ranks.get(parent, 0)) > 0 and int(ranks.get(skill.id, 0)) > 0
			var hot: bool = chain.has(skill.id) and chain.has(parent) and (skill.id == pick or parent == pick)
			var color: Color = colors.get(skill.id, Color.WHITE)
			color.a = 0.95 if hot else 0.7 if lit else 0.32
			if colors.get(parent) != colors.get(skill.id) and not hot:
				# Prerequisite from another branch: a faint dashed hint, so it doesn't run a bar across the middle column.
				bend = (from.y + to.y) * 0.5
				for leg in [[from, Vector2(from.x, bend)], [Vector2(from.x, bend), Vector2(to.x, bend)], [Vector2(to.x, bend), to]]:
					draw_dashed_line(leg[0], leg[1], Color(color, 0.3), 1.5, 6.0)
				continue
			var points := PackedVector2Array([from, Vector2(from.x, bend), Vector2(to.x, bend), to])
			draw_polyline(points, Color(0, 0, 0, 0.45), 6.0 if hot else 5.0)
			draw_polyline(points, color, 3.5 if hot else 2.5)
			for joint in [Vector2(from.x, bend), Vector2(to.x, bend)]:
				draw_circle(joint, 3.5, color)


# One skill: a hexagon in its branch colour with the skill icon and rank, drawn by hand (no button styleboxes).
class HexNode extends Button:
	var tree: SkillTree
	var skill: Dictionary
	var icon_texture: Texture2D

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _has_point(point: Vector2) -> bool:
		return Geometry2D.is_point_in_polygon(point, _hex(size * 0.5, size.x * 0.5))

	func _hex(at: Vector2, radius: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i in 6:
			points.append(at + Vector2.from_angle(deg_to_rad(-90.0 + i * 60.0)) * radius)
		return points

	func _draw() -> void:
		var at := size * 0.5
		var radius := size.x * 0.5
		var color: Color = tree.colors.get(skill.id, Color.WHITE)
		var rank := int(tree.ranks.get(skill.id, 0))
		var open: bool = tree.learnable.is_valid() and tree.learnable.call(skill.id)
		var picked: bool = skill.id == tree.pick
		var lit := picked or has_focus() or is_hovered()
		var tone := color if rank > 0 else color.lerp(Color(0.45, 0.48, 0.47), 0.55)
		if picked:
			var glow := _hex(at, radius + 4.0)
			glow.append(glow[0])
			draw_polyline(glow, Color("f1d9a0"), 3.0, true)
		draw_colored_polygon(_hex(at, radius), Color(0.04, 0.06, 0.06).lerp(tone, 0.22 if rank > 0 else 0.08))
		var ring := _hex(at, radius - 2.0)
		ring.append(ring[0])
		draw_polyline(ring, tone.lightened(0.3) if lit else tone, 3.5 if lit or open else 2.5, true)
		var inner := _hex(at, radius - 7.0)
		inner.append(inner[0])
		draw_polyline(inner, Color(tone, 0.35), 1.0, true)
		var side := radius * 0.95
		draw_texture_rect(icon_texture, Rect2(at - Vector2(side, side) * 0.5 - Vector2(0, 5), Vector2(side, side)), false, tone.lightened(0.45) if rank > 0 else Color(tone, 0.7))
		var caption := "%d/10" % rank
		var font := get_theme_default_font()
		draw_string(font, Vector2(0, at.y + radius * 0.62), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color("f3e7c6") if rank > 0 else Color(0.75, 0.78, 0.76, 0.8))
		if open:
			# Can be learned right now: a small plus badge on the top-right edge.
			var badge := at + Vector2(radius * 0.62, -radius * 0.58)
			draw_circle(badge, 8.0, Color("f1d9a0"))
			draw_string(font, badge + Vector2(-4.5, 5.0), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.1, 0.1, 0.08))
