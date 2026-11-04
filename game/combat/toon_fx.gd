class_name ToonFx
extends Node2D
# Combat effects built from textures, not drawn shapes: each kind is a RECIPE of textured layers (Sprite2D, additive
# or normal blend, HDR modulate > 1 so the combat glow blooms it) plus GPU particle bursts. Textures live in
# art/vfx/ and come from Blender (lightning flipbooks, prototypes/vfx/blender/) and Codex image generation (painted
# single frames), packed by prototypes/vfx/pack_textures.py. Every layer is a pure function of `clock`, so the VFX
# Sandbox can scrub and step it; GPU particles run on real time. One-shots free themselves; loops run until freed.
# Visual direction: reference 1 (Hovl's sketchbook) per the user; see docs/vfx/VFX_STYLE_GUIDE.md.

const DURATION := {"hit":0.32, "crit":0.46, "block":0.42, "heal":0.75, "thrust":0.3, "slash2":0.42, "smash":0.55,
	"cleave":0.4, "zap":0.26, "zap_hit":0.34, "thunder":0.8, "cloud":0.9, "fire":0.7, "splash":0.6, "snare":0.6,
	"reticle":0.5, "bite":0.32, "howl":0.6, "muzzle":0.16, "charge":0.45, "dome":0.7, "haste":0.6, "steam":0.9,
	"warp":0.7}
const LOOPS := ["bolt", "beam", "aura_wet", "aura_heated", "aura_corroded", "aura_marked", "aura_sealed",
	"aura_staggered", "aura_haste"]
const TINTS := {"block":"80cde1", "heal":"83dcb3", "beam":"f1d9a0", "thrust":"efbb71", "slash2":"f3e7c6", "smash":"efbb71",
	"cleave":"e8573a", "zap":"9fe6ff", "zap_hit":"9fe6ff", "thunder":"9fe6ff", "cloud":"9fd65a", "fire":"ff8a3a",
	"splash":"6fc3ec", "snare":"c8823a", "reticle":"e8573a", "bite":"f3e7c6", "howl":"c9b8ff", "muzzle":"ffe2a0",
	"charge":"9fe6ff", "dome":"80cde1", "haste":"f1d9a0", "steam":"e6f2f2", "warp":"9fe6ff", "aura_wet":"6fc3ec",
	"aura_heated":"ff8a3a", "aura_corroded":"9fd65a", "aura_marked":"e8573a", "aura_sealed":"c8823a",
	"aura_staggered":"f1d9a0", "aura_haste":"f1d9a0"}
const PERIOD := {"bolt":0.4, "beam":1.2, "aura_wet":0.9, "aura_heated":1.0, "aura_corroded":1.4, "aura_marked":2.0,
	"aura_sealed":2.0, "aura_staggered":1.6, "aura_haste":0.7}
const DIR := "res://art/vfx/"

# Layer keys (all optional except tex):
#   tex      file under art/vfx/ ("@soft" = procedural radial glow)   frames Vector2i flipbook, fps (default 20)
#   t        [from, to] seconds (loops: within PERIOD)                 at Vector2 offset (x follows direction)
#   move     Vector2 travelled over the window (eased out)             orbit Vector2 radii, circles at `spin` rad/s
#   scale    [from, to], floats or Vector2 (eased out)                 squash y factor (floor-plane ellipses)
#   rot      start rotation (rad, mirrored with direction)             spin rad/s
#   color    "tint" (the effect's tint, default) or a hex              gain HDR multiplier (default 1.8)
#   fin/fout fade in over the first fin, fade out from fout (fractions of the window)
#   erode    true: leave by noise erosion instead of fading            mix   true: normal blend (smoke) not additive
#   copies   n copies, spaced by `spread` (and, in loops, staggered in time)
#   flipv    mirror vertically                                         pivot texture-pixel offset (Sprite2D.offset)
#   sky      true: stretch from above the stage top down to this layer (lightning)
#   span     true: stretch along `reach` (zap)
# Particles: {"burst": preset, "n": amount, "color": "tint"|hex, "at": Vector2}
const RECIPES := {
	"hit":[{"tex":"hit_burst.png", "t":[0, 0.3], "scale":[0.16, 0.48], "spin":1.2, "fout":0.4},
		{"tex":"ring_white.png", "t":[0, 0.26], "scale":[0.06, 0.34], "color":"ffe2a0", "gain":1.5, "fout":0.25},
		{"burst":"sparks", "n":14, "color":"ffd37a"}],
	"crit":[{"tex":"@soft", "t":[0, 0.12], "scale":[0.6, 0.9], "color":"ffe2a0", "gain":0.5, "fout":0.1},
		{"tex":"crit_burst.png", "t":[0, 0.4], "scale":[0.16, 0.46], "spin":0.8, "gain":1.6, "fout":0.3},
		{"tex":"hit_burst.png", "t":[0.02, 0.3], "scale":[0.1, 0.3], "spin":-2.0, "gain":2.4, "fout":0.3},
		{"tex":"ring_white.png", "t":[0, 0.36], "scale":[0.08, 0.5], "color":"ffe2a0", "gain":1.8, "fout":0.2},
		{"burst":"sparks", "n":30, "color":"ffd37a"}],
	"muzzle":[{"tex":"muzzle_flash.png", "t":[0, 0.14], "scale":[0.16, 0.3], "at":Vector2(30, 0), "fout":0.3},
		{"burst":"sparks", "n":6, "color":"ffe2a0"}],
	"thrust":[{"tex":"thrust_streak.png", "t":[0, 0.22], "at":Vector2(-60, 0), "move":Vector2(140, 0),
			"scale":[Vector2(0.25, 0.3), Vector2(0.55, 0.16)], "color":"fff4d6", "gain":2.2, "fout":0.5},
		{"tex":"hit_burst.png", "t":[0.06, 0.3], "scale":[0.08, 0.26], "spin":1.5, "fout":0.4},
		{"burst":"sparks", "n":10, "color":"ffd37a"}],
	"slash2":[{"tex":"slash_arc.png", "t":[0, 0.24], "rot":-0.35, "scale":[0.38, 0.5], "gain":2.0, "fout":0.35, "erode":true},
		{"tex":"slash_arc.png", "t":[0.13, 0.38], "rot":0.35, "flipv":true, "scale":[0.38, 0.5], "gain":2.0, "fout":0.35, "erode":true},
		{"tex":"hit_burst.png", "t":[0.08, 0.34], "scale":[0.08, 0.26], "spin":1.5, "fout":0.4},
		{"burst":"sparks", "n":12, "color":"ffd37a"}],
	"cleave":[{"tex":"slash_arc.png", "t":[0, 0.32], "rot":-0.2, "scale":[0.55, 0.78], "gain":2.2, "fout":0.35, "erode":true},
		{"tex":"slash_arc.png", "t":[0.02, 0.26], "rot":-0.2, "scale":[0.5, 0.7], "color":"fff4d6", "gain":2.0, "fout":0.3},
		{"tex":"ring_white.png", "t":[0.05, 0.36], "scale":[0.1, 0.5], "gain":1.4, "fout":0.2},
		{"burst":"sparks", "n":20, "color":"ffb08a"}],
	"smash":[{"tex":"crit_burst.png", "t":[0, 0.32], "scale":[0.14, 0.44], "spin":0.6, "color":"ffe2a0", "fout":0.35},
		{"tex":"ring_white.png", "t":[0, 0.5], "at":Vector2(0, 100), "squash":0.3, "scale":[0.12, 0.9], "gain":1.6, "fout":0.3},
		{"tex":"smoke_puff.png", "t":[0.05, 0.55], "at":Vector2(0, 92), "copies":4, "spread":Vector2(46, 0), "scale":[0.08, 0.2],
			"move":Vector2(0, -24), "color":"b9a58a", "gain":1.0, "mix":true, "erode":true, "fout":0.35},
		{"burst":"debris", "n":16, "color":"b9a58a", "at":Vector2(0, 90)}],
	"bite":[{"tex":"fang_marks.png", "t":[0, 0.3], "rot":0.3, "scale":[0.45, 0.36], "gain":1.8, "fout":0.4, "erode":true},
		{"tex":"hit_burst.png", "t":[0.1, 0.32], "scale":[0.08, 0.22], "fout":0.4},
		{"burst":"sparks", "n":8, "color":"f3e7c6"}],
	"zap":[{"tex":"thunder/arcs.png", "frames":Vector2i(1, 6), "fps":30, "span":true, "t":[0, 0.26], "gain":2.4, "fout":0.5}],
	"zap_hit":[{"tex":"thunder/impact_flare.png", "t":[0, 0.3], "scale":[0.14, 0.34], "spin":2.0, "gain":2.2, "fout":0.35},
		{"tex":"thunder/shock_ring.png", "t":[0, 0.34], "scale":[0.08, 0.36], "gain":1.8, "fout":0.25},
		{"burst":"sparks", "n":16, "color":"9fe6ff"}],
	"thunder":[{"tex":"@soft", "t":[0, 0.22], "at":Vector2(0, 40), "scale":[2.2, 2.5], "color":"8cb8ff", "gain":0.8, "fout":0.0},
		{"tex":"thunder/shock_ring.png", "t":[0, 0.5], "at":Vector2(0, 112), "squash":0.28, "scale":[0.15, 0.7], "gain":2.0, "fout":0.0},
		{"tex":"thunder/arcs.png", "frames":Vector2i(1, 6), "fps":16, "t":[0.03, 0.6], "at":Vector2(0, 104),
			"scale":[Vector2(0.55, 0.5), Vector2(0.9, 0.5)], "gain":2.0, "fout":0.5},
		{"tex":"thunder/bolts.png", "frames":Vector2i(8, 1), "fps":22, "sky":true, "t":[0, 0.14], "at":Vector2(0, 112), "scale":[1.35, 1.35], "gain":2.4, "fout":0.6},
		{"tex":"thunder/bolts.png", "frames":Vector2i(8, 1), "fps":22, "sky":true, "t":[0.18, 0.4], "at":Vector2(0, 112), "scale":[1.35, 1.35], "gain":2.4, "fout":0.6},
		{"tex":"thunder/impact_flare.png", "t":[0, 0.42], "at":Vector2(0, 100), "scale":[0.22, 0.5], "spin":1.5, "gain":2.4, "fout":0.3},
		{"tex":"thunder/impact_flare.png", "t":[0, 0.4], "scale":[0.12, 0.28], "spin":-2.2, "gain":1.8, "fout":0.3},
		{"tex":"thunder/arcs.png", "frames":Vector2i(1, 6), "fps":20, "t":[0.12, 0.75], "rot":1.2, "spin":2.0, "scale":[Vector2(0.28, 0.4), Vector2(0.28, 0.4)], "gain":1.9, "fout":0.45},
		{"burst":"sparks", "n":48, "color":"9fe6ff", "at":Vector2(0, 104)}],
	"fire":[{"tex":"fire_burst.png", "t":[0, 0.5], "scale":[0.12, 0.46], "color":"ffffff", "gain":1.9, "fout":0.4, "erode":true},
		{"tex":"flame.png", "t":[0.04, 0.6], "at":Vector2(0, 40), "copies":3, "spread":Vector2(46, 0), "pivot":Vector2(0, -200),
			"scale":[Vector2(0.12, 0.08), Vector2(0.2, 0.3)], "color":"ffffff", "gain":1.7, "fout":0.45, "erode":true},
		{"burst":"embers", "n":20, "color":"ffb04a"}],
	"cloud":[{"tex":"smoke_puff.png", "t":[0, 0.9], "copies":3, "spread":Vector2(48, -6), "scale":[0.12, 0.34], "gain":1.0, "mix":true, "erode":true, "fout":0.45},
		{"tex":"bubble.png", "t":[0.15, 0.8], "copies":3, "spread":Vector2(34, 0), "move":Vector2(0, -60), "scale":[0.03, 0.07], "gain":1.6, "fout":0.6}],
	"splash":[{"tex":"splash.png", "t":[0, 0.55], "at":Vector2(0, 30), "pivot":Vector2(0, -150), "scale":[Vector2(0.2, 0.1), Vector2(0.45, 0.42)], "color":"ffffff", "gain":1.4, "erode":true, "fout":0.4},
		{"tex":"ring_white.png", "t":[0, 0.5], "at":Vector2(0, 60), "squash":0.3, "scale":[0.1, 0.6], "gain":1.4, "fout":0.3},
		{"burst":"drops", "n":16, "color":"ffffff"}],
	"snare":[{"tex":"copper_band.png", "t":[0, 0.6], "at":Vector2(0, -24), "scale":[0.62, 0.36], "color":"ffffff", "gain":1.3, "fout":0.6},
		{"tex":"copper_band.png", "t":[0.06, 0.6], "at":Vector2(0, 24), "scale":[0.62, 0.36], "color":"ffffff", "gain":1.3, "fout":0.6},
		{"burst":"sparks", "n":8, "color":"ffd37a"}],
	"heal":[{"tex":"ring_white.png", "t":[0, 0.7], "squash":0.3, "scale":[0.12, 0.42], "gain":1.6, "fout":0.5},
		{"tex":"light_pillar.png", "t":[0.05, 0.72], "pivot":Vector2(0, -256), "scale":[Vector2(0.3, 0.1), Vector2(0.34, 0.42)], "color":"7dffc0", "gain":1.2, "fout":0.5},
		{"tex":"heal_cross.png", "t":[0.1, 0.75], "at":Vector2(0, -20), "copies":4, "spread":Vector2(26, -8), "move":Vector2(0, -140), "scale":[0.09, 0.06], "color":"ffffff", "gain":1.7, "fout":0.6},
		{"burst":"motes", "n":12, "color":"83dcb3", "at":Vector2(0, -10)}],
	"block":[{"tex":"hex_shield.png", "t":[0, 0.42], "at":Vector2(-34, 0), "scale":[Vector2(0.22, 0.4), Vector2(0.27, 0.48)], "color":"ffffff", "gain":1.6, "fout":0.45},
		{"burst":"sparks", "n":12, "color":"dff6ff", "at":Vector2(-50, 0)}],
	"dome":[{"tex":"hex_shield.png", "t":[0, 0.7], "scale":[0.08, 0.46], "color":"ffffff", "gain":1.4, "fout":0.5},
		{"tex":"ring_white.png", "t":[0, 0.5], "scale":[0.1, 0.55], "gain":1.4, "fout":0.3}],
	"charge":[{"tex":"ring_white.png", "t":[0, 0.45], "scale":[0.4, 0.04], "gain":1.8, "fin":0.2, "fout":0.8},
		{"tex":"@soft", "t":[0, 0.45], "scale":[0.05, 0.4], "gain":1.4, "fin":0.3, "fout":0.85}],
	"haste":[{"tex":"chevron.png", "t":[0, 0.6], "at":Vector2(-52, 40), "copies":3, "spread":Vector2(0, -30), "move":Vector2(0, -110), "scale":[0.09, 0.07], "gain":1.8, "fout":0.5},
		{"tex":"chevron.png", "t":[0, 0.6], "at":Vector2(52, 40), "copies":3, "spread":Vector2(0, -30), "move":Vector2(0, -110), "scale":[0.09, 0.07], "gain":1.8, "fout":0.5}],
	"steam":[{"tex":"smoke_puff.png", "t":[0, 0.9], "at":Vector2(-40, -30), "copies":3, "spread":Vector2(-34, -16), "move":Vector2(-60, -110),
		"scale":[0.1, 0.36], "gain":1.0, "mix":true, "erode":true, "fout":0.45}],
	"warp":[{"tex":"gear_circle.png", "t":[0, 0.7], "scale":[0.05, 0.34], "spin":3.0, "color":"ffffff", "gain":1.0, "mix":true, "fout":0.5},
		{"tex":"ring_white.png", "t":[0.1, 0.6], "scale":[0.1, 0.5], "gain":1.4, "fout":0.3}],
	"howl":[{"tex":"sound_rings.png", "t":[0, 0.6], "scale":[0.08, 0.5], "gain":1.5, "fout":0.4}],
	"reticle":[{"tex":"reticle.png", "t":[0, 0.5], "scale":[0.5, 0.26], "spin":2.5, "color":"ffffff", "gain":1.5, "fout":0.6}],
	"bolt":[{"tex":"glow_orb.png", "t":[0, 0.4], "scale":[0.24, 0.24], "gain":2.2, "fin":0.0, "fout":1.0}],
	"beam":[{"tex":"light_pillar.png", "t":[0, 1.2], "pivot":Vector2(0, -256), "scale":[Vector2(0.4, 0.62), Vector2(0.4, 0.62)], "gain":1.3, "fin":0.0, "fout":1.0},
		{"tex":"heal_cross.png", "t":[0, 1.2], "copies":3, "spread":Vector2(18, 0), "move":Vector2(0, -220), "scale":[0.05, 0.03], "color":"fff4d6", "gain":1.6, "fout":0.6}],
	"aura_wet":[{"tex":"water_drop.png", "t":[0, 0.9], "at":Vector2(0, -60), "copies":4, "spread":Vector2(24, 0), "move":Vector2(0, 120), "scale":[0.1, 0.085], "color":"ffffff", "gain":1.3, "fout":0.7}],
	"aura_heated":[{"tex":"flame.png", "t":[0, 1.0], "at":Vector2(0, 54), "copies":2, "spread":Vector2(88, 0), "move":Vector2(0, -90), "pivot":Vector2(0, -200),
		"scale":[Vector2(0.14, 0.12), Vector2(0.11, 0.26)], "color":"ffffff", "gain":1.6, "fout":0.6, "erode":true},
		{"tex":"flame.png", "t":[0, 1.0], "at":Vector2(0, 30), "copies":2, "spread":Vector2(60, 0), "move":Vector2(0, -80), "pivot":Vector2(0, -200),
		"scale":[Vector2(0.1, 0.09), Vector2(0.08, 0.2)], "color":"ffffff", "gain":1.6, "fout":0.6, "erode":true}],
	"aura_corroded":[{"tex":"bubble.png", "t":[0, 1.4], "at":Vector2(0, 34), "copies":5, "spread":Vector2(20, 0), "move":Vector2(0, -80), "scale":[0.07, 0.13], "gain":1.5, "fout":0.75}],
	"aura_marked":[{"tex":"reticle.png", "t":[0, 2.0], "scale":[0.3, 0.3], "spin":1.2, "color":"ffffff", "gain":1.3, "fin":0.0, "fout":1.0}],
	"aura_sealed":[{"tex":"copper_band.png", "t":[0, 2.0], "at":Vector2(0, -6), "scale":[0.4, 0.4], "color":"ffffff", "gain":1.2, "fin":0.0, "fout":1.0},
		{"tex":"copper_band.png", "t":[0, 2.0], "at":Vector2(0, 26), "scale":[0.38, 0.38], "color":"ffffff", "gain":1.2, "fin":0.0, "fout":1.0}],
	"aura_staggered":[{"tex":"star.png", "t":[0, 1.6], "copies":3, "orbit":Vector2(38, 11), "at":Vector2(0, -14), "spin":4.0, "scale":[0.12, 0.12], "color":"ffffff", "gain":1.4, "fin":0.0, "fout":1.0}],
	"aura_haste":[{"tex":"chevron.png", "t":[0, 0.7], "at":Vector2(-52, 40), "copies":2, "move":Vector2(0, -120), "scale":[0.12, 0.09], "gain":1.6, "fout":0.6},
		{"tex":"chevron.png", "t":[0, 0.7], "at":Vector2(52, 40), "copies":2, "move":Vector2(0, -120), "scale":[0.12, 0.09], "gain":1.6, "fout":0.6}],
}

# Every kind a skill, enemy role or status may name; tests check data against this.
static func kinds() -> Array:
	return DURATION.keys() + LOOPS

# ---- presets (data/vfx_presets.json, edited and saved from the VFX Sandbox; gameplay spawns through the same path)
const PRESET_PATH := "res://data/vfx_presets.json"
const PARAMS := {"scale":1.0, "speed":1.0, "opacity":1.0, "density":1.0, "tint":""}
static var presets: Dictionary = {}
static var _presets_loaded := false

static func preset(kind: String) -> Dictionary:
	if not _presets_loaded:
		_presets_loaded = true
		if FileAccess.file_exists(PRESET_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRESET_PATH))
			if parsed is Dictionary: presets = parsed
	var merged := PARAMS.duplicate()
	merged.merge(presets.get(kind, {}), true)
	return merged

static func reload_presets() -> void:
	presets.clear()
	_presets_loaded = false

# Writes only values that differ from PARAMS. Returns the FileAccess error when the path is read-only (exported game).
static func save_presets(path: String = PRESET_PATH) -> Error:
	var out := {}
	for kind in presets:
		var changed := {}
		for key in presets[kind]:
			if PARAMS.has(key) and presets[kind][key] != PARAMS[key]: changed[key] = presets[kind][key]
		if not changed.is_empty(): out[kind] = changed
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(out, "\t", true))
	return OK

# ---- shared resources
static var _textures: Dictionary = {}
static var _add: CanvasItemMaterial
static var _mix: CanvasItemMaterial
static var _noise: NoiseTexture2D
const ADD_SHADER := preload("res://combat/vfx_add.gdshader")
const MIX_SHADER := preload("res://combat/vfx_mix.gdshader")

static func _texture(name: String) -> Texture2D:
	if not _textures.has(name):
		if name == "@soft" or name == "@spark":
			var gradient := Gradient.new()
			gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
			gradient.offsets = PackedFloat32Array([0.0, 0.3 if name == "@spark" else 0.35, 1.0])
			var radial := GradientTexture2D.new()
			radial.gradient = gradient
			radial.fill = GradientTexture2D.FILL_RADIAL
			radial.fill_from = Vector2(0.5, 0.5)
			radial.fill_to = Vector2(1.0, 0.5)
			radial.width = 32 if name == "@spark" else 256
			radial.height = radial.width
			_textures[name] = radial
		else:
			_textures[name] = load(DIR + name)
	return _textures[name]

static func _shared() -> void:
	if _add != null: return
	_add = CanvasItemMaterial.new()
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_mix = CanvasItemMaterial.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.035
	_noise = NoiseTexture2D.new()
	_noise.width = 128
	_noise.height = 128
	_noise.seamless = true
	_noise.noise = noise

# Draws through both layer shaders and every particle preset, nearly invisible, at combat start so their pipelines
# compile before the first hit (a cold shader cache otherwise stalls the first use: 815 ms measured on M1 for one shader).
static func prewarm(parent: Node) -> void:
	_shared()
	for shader in [ADD_SHADER, MIX_SHADER]:
		var probe := Sprite2D.new()
		probe.texture = _texture("@spark")
		probe.modulate = Color(1, 1, 1, 0.01)
		probe.scale = Vector2.ONE * 0.05
		probe.material = ShaderMaterial.new()
		probe.material.shader = shader
		probe.material.set_shader_parameter("noise", _noise)
		parent.add_child(probe)
		parent.get_tree().create_timer(0.1).timeout.connect(probe.queue_free)
	# Particle process shaders compile per feature set (align, box emission, ...): run one of each preset unseen.
	for kind_name in ["hit", "fire", "splash", "smash", "heal"]:
		var fx := ToonFx.spawn(parent, kind_name, Vector2(8, 8), false, 0.05)
		fx.modulate.a = 0.004

# ---- instance
var kind: String = "hit"
var speed: float = 1.0  # playback rate from the preset
var tint: Color = Color("efbb71")
var size: float = 1.0
var direction: float = 1.0  # +1: effects travel/face right
var loop: bool = false
var reach := Vector2(240, 0)  # zap: end point relative to the start
var clock: float = 0.0:
	set(value):
		clock = value
		if is_inside_tree(): _pose()
var layers: Array = []  # [Sprite2D, layer dict, copy index, copy count]

static func spawn(parent: Node, kind: String, point: Vector2, flip: bool = false, size: float = 1.0, tint: Color = Color(0, 0, 0, 0)) -> ToonFx:
	return ToonFx.new().setup(parent, kind, point, flip, size, tint)

func setup(parent: Node, kind_name: String, point: Vector2, flip: bool, scale_by: float, color: Color) -> ToonFx:
	_shared()
	var p := preset(kind_name)
	kind = kind_name
	size = scale_by * float(p.scale)
	speed = float(p.speed)
	modulate.a = float(p.opacity)
	direction = -1.0 if flip else 1.0
	loop = kind in LOOPS
	if color.a > 0.0:
		tint = color
	elif not String(p.tint).is_empty():
		tint = Color(p.tint)
	elif TINTS.has(kind):
		tint = Color(TINTS[kind])
	position = point
	parent.add_child(self)
	for spec in RECIPES.get(kind, []):
		if spec.has("burst"): _burst(spec, float(p.density))
		else:
			var copies: int = spec.get("copies", 1)
			for i in copies: layers.append([_sprite(spec), spec, i, copies])
	_pose()
	return self

func _sprite(spec: Dictionary) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _texture(spec.tex)
	var frames: Vector2i = spec.get("frames", Vector2i.ONE)
	sprite.hframes = frames.x
	sprite.vframes = frames.y
	sprite.offset = spec.get("pivot", Vector2.ZERO)
	if spec.get("erode", false):
		sprite.material = ShaderMaterial.new()
		sprite.material.shader = MIX_SHADER if spec.get("mix", false) else ADD_SHADER
		sprite.material.set_shader_parameter("noise", _noise)
	else:
		sprite.material = _mix if spec.get("mix", false) else _add
	var hue: String = spec.get("color", "tint")
	sprite.set_meta("color", tint if hue == "tint" else Color(hue))
	add_child(sprite)
	return sprite

func _process(delta: float) -> void:
	clock += delta * speed
	if not loop and clock >= DURATION.get(kind, 0.5):
		queue_free()

static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)

# Every layer is a pure function of clock (sandbox scrubbing and fixed-clock captures rely on it).
func _pose() -> void:
	var period: float = PERIOD.get(kind, 0.0)
	for entry in layers:
		var sprite: Sprite2D = entry[0]
		var spec: Dictionary = entry[1]
		var index: int = entry[2]
		var count: int = entry[3]
		var window: Array = spec.t
		var length: float = maxf(0.001, float(window[1]) - float(window[0]))
		var t := clock
		if loop and period > 0.0:
			t = fposmod(clock + period * index / count, period)
		var u := (t - float(window[0])) / length
		sprite.visible = u >= 0.0 and u < 1.0
		if not sprite.visible: continue
		var e := _ease_out(u)
		var spread: Vector2 = spec.get("spread", Vector2.ZERO) * (index - (count - 1) * 0.5)
		var at: Vector2 = spec.get("at", Vector2.ZERO) + spread + spec.get("move", Vector2.ZERO) * e
		if spec.has("orbit"):
			var a: float = t * float(spec.get("spin", 1.0)) + TAU * index / count
			at += Vector2(cos(a), sin(a)) * spec.orbit
		var scales: Array = spec.get("scale", [1.0, 1.0])
		var s0: Vector2 = scales[0] if scales[0] is Vector2 else Vector2.ONE * float(scales[0])
		var s1: Vector2 = scales[1] if scales[1] is Vector2 else Vector2.ONE * float(scales[1])
		var sc := s0.lerp(s1, e)
		sc.y *= float(spec.get("squash", 1.0)) * (-1.0 if spec.get("flipv", false) else 1.0)
		sc.x *= direction
		sprite.rotation = (float(spec.get("rot", 0.0)) + (0.0 if spec.has("orbit") else float(spec.get("spin", 0.0)) * t)) * direction
		if spec.get("sky", false):
			# Lightning: bottom of the frame at this layer's point, top above the stage top.
			sprite.offset = Vector2(0, -256)
			sc.y = (position.y + at.y * size + 40.0) / 512.0 / size
		if spec.get("span", false):
			sprite.rotation = reach.angle()
			at = Vector2(reach.length() * 0.5 / size, 0).rotated(reach.angle())
			at.x *= direction
			sc = Vector2(reach.length() / 512.0 / size, 0.6)
		sprite.position = Vector2(at.x * direction, at.y) * size
		sprite.scale = sc * size
		if sprite.hframes * sprite.vframes > 1:
			sprite.frame = int(t * float(spec.get("fps", 20.0)) + index * 3) % (sprite.hframes * sprite.vframes)
		var fin: float = spec.get("fin", 0.06)
		var fout: float = spec.get("fout", 0.6)
		var alpha := clampf(u / fin, 0.0, 1.0) if fin > 0.0 else 1.0
		var leave := clampf((u - fout) / maxf(0.001, 1.0 - fout), 0.0, 1.0) if fout < 1.0 else 0.0
		var color: Color = sprite.get_meta("color")
		var gain: float = spec.get("gain", 1.8)
		if sprite.material is ShaderMaterial:
			sprite.material.set_shader_parameter("dissolve", leave)
			sprite.modulate = Color(color.r * gain, color.g * gain, color.b * gain, alpha)
		else:
			sprite.modulate = Color(color.r * gain, color.g * gain, color.b * gain, alpha * (1.0 - leave))

# One-shot GPU particle bursts. They run on real time (not `clock`); their lifetime fits inside the effect's.
func _burst(spec: Dictionary, density: float) -> void:
	var hue: String = spec.get("color", "tint")
	var color: Color = tint if hue == "tint" else Color(hue)
	var particles := GPUParticles2D.new()
	particles.amount = maxi(1, roundi(int(spec.get("n", 12)) * density))
	particles.one_shot = true
	particles.explosiveness = 0.95
	var at: Vector2 = spec.get("at", Vector2.ZERO)
	particles.position = Vector2(at.x * direction, at.y) * size
	particles.material = _add
	particles.texture = _texture("@spark")
	var m := ParticleProcessMaterial.new()
	m.particle_flag_disable_z = true
	match spec.burst:
		"sparks":
			# Streaks thrown away from the attacker, falling.
			particles.lifetime = 0.45
			m.direction = Vector3(direction, -0.6, 0)
			m.spread = 70.0
			m.initial_velocity_min = 220.0
			m.initial_velocity_max = 620.0
			m.gravity = Vector3(0, 1300, 0)
			m.particle_flag_align_y = true
			m.scale_min = 0.25
			m.scale_max = 0.55
			particles.scale = Vector2(0.35, 1.0)
		"embers":
			particles.lifetime = 0.7
			m.direction = Vector3(0, -1, 0)
			m.spread = 40.0
			m.initial_velocity_min = 60.0
			m.initial_velocity_max = 200.0
			m.gravity = Vector3(0, -80, 0)
			m.scale_min = 0.2
			m.scale_max = 0.45
		"drops":
			particles.lifetime = 0.6
			particles.texture = _texture("water_drop.png")
			particles.material = _mix
			m.direction = Vector3(0, -1, 0)
			m.spread = 55.0
			m.initial_velocity_min = 180.0
			m.initial_velocity_max = 420.0
			m.gravity = Vector3(0, 1100, 0)
			m.scale_min = 0.02
			m.scale_max = 0.045
		"debris":
			particles.lifetime = 0.55
			particles.material = _mix
			m.direction = Vector3(0, -1, 0)
			m.spread = 70.0
			m.initial_velocity_min = 140.0
			m.initial_velocity_max = 380.0
			m.gravity = Vector3(0, 1200, 0)
			m.scale_min = 0.18
			m.scale_max = 0.4
		"motes":
			particles.lifetime = 0.7
			m.direction = Vector3(0, -1, 0)
			m.spread = 25.0
			m.initial_velocity_min = 60.0
			m.initial_velocity_max = 160.0
			m.gravity = Vector3(0, -40, 0)
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			m.emission_box_extents = Vector3(40, 10, 0)
			m.scale_min = 0.2
			m.scale_max = 0.4
	var shrink := CurveTexture.new()
	shrink.curve = Curve.new()
	shrink.curve.add_point(Vector2(0, 1))
	shrink.curve.add_point(Vector2(1, 0))
	m.scale_curve = shrink
	var gain := 2.2 if particles.material == _add else 1.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(gain, gain, gain), Color(color.r * gain, color.g * gain, color.b * gain), Color(color.r, color.g, color.b, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	m.color_ramp = ramp_texture
	particles.process_material = m
	add_child(particles)
	particles.emitting = true
