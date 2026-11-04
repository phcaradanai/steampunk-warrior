extends Node2D
# SANDBOX ONLY: ToonFx exactly as shipped in commit 01cd80a (before the VFX refinement pass), kept so the
# VFX Sandbox can play the original next to the current version. Not used by gameplay; excluded from export (tests/*).
# Combat effects drawn in code to match the toon-shaded 3D figures: flat colour shapes with the same dark
# outline, bright cores and eased motion. One-shots free themselves; loops (bolt, beam) run until freed.

const OUTLINE := Color("101b20")
const DURATION := {"hit":0.32, "crit":0.46, "block":0.42, "heal":0.75, "thrust":0.3, "slash2":0.42, "smash":0.55,
	"cleave":0.4, "zap":0.26, "zap_hit":0.34, "thunder":0.5, "cloud":0.9, "fire":0.7, "splash":0.6, "snare":0.6,
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
# Every kind a skill, enemy role or status may name; tests check data against this.
static func kinds() -> Array:
	return DURATION.keys() + LOOPS

var kind: String = "hit"
var tint: Color = Color("efbb71")
var size: float = 1.0
var direction: float = 1.0  # +1: effects travel/face right
var clock: float = 0.0
var loop: bool = false
var rays: Array = []    # [angle, length scale, width scale]
var sparks: Array = []  # [angle, speed, size]
var reach := Vector2(240, 0)  # zap: end point relative to the start
var jag: Array = []           # zap/thunder: zigzag offsets, re-rolled while it flickers
var rng := RandomNumberGenerator.new()

static func spawn(parent: Node, kind: String, point: Vector2, flip: bool = false, size: float = 1.0, tint: Color = Color(0, 0, 0, 0)) -> Node2D:
	var fx = load("res://tests/vfx_lab/toon_fx_v1.gd").new()
	fx.kind = kind
	fx.size = size
	fx.direction = -1.0 if flip else 1.0
	fx.loop = kind in LOOPS
	if tint.a > 0.0:
		fx.tint = tint
	elif TINTS.has(kind):
		fx.tint = Color(TINTS[kind])
	fx.position = point
	fx._seed()
	parent.add_child(fx)
	return fx

func _seed() -> void:
	rng.randomize()
	var count := 10 if kind == "crit" else 7
	for i in count:
		rays.append([TAU * i / count + rng.randf_range(-0.25, 0.25), rng.randf_range(0.7, 1.15), rng.randf_range(0.8, 1.2)])
	for i in (10 if kind == "crit" else 6):
		# Sparks fly away from the attacker, in a cone, then fall.
		sparks.append([rng.randf_range(-1.0, 0.6), rng.randf_range(160.0, 320.0), rng.randf_range(3.0, 6.0)])

func _process(delta: float) -> void:
	clock += delta
	if kind in ["zap", "thunder", "zap_hit"] and int(clock * 30.0) != int((clock - delta) * 30.0): jag.clear()
	if not loop and clock >= DURATION.get(kind, 0.4):
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = clock / DURATION.get(kind, 1.0)
	match kind:
		"hit": _impact(t, 1.0)
		"crit": _impact(t, 1.45)
		"block": _block(t)
		"heal": _heal(t)
		"bolt": _bolt()
		"beam": _beam()
		"thrust": _thrust(t)
		"slash2": _slash(t, 2, 1.0)
		"cleave": _slash(t, 1, 1.5)
		"smash": _smash(t)
		"zap": _zap(t, Vector2.ZERO, reach, 7)
		"zap_hit": _zap_hit(t)
		"thunder": _thunder(t)
		"cloud": _cloud(t)
		"fire": _fire(t)
		"splash": _splash(t)
		"snare": _snare(t)
		"reticle": _reticle(t, false)
		"bite": _bite(t)
		"howl": _rings(t, 3, 90.0)
		"muzzle": _impact(t, 0.6)
		"charge": _charge(t)
		"dome": _dome(t)
		"haste": _haste(t, false)
		"steam": _steam(t, 1.0)
		"warp": _warp(t)
		"aura_wet": _aura_wet()
		"aura_heated": _aura_heated()
		"aura_corroded": _aura_corroded()
		"aura_marked": _reticle(0.0, true)
		"aura_sealed": _aura_sealed()
		"aura_staggered": _aura_staggered()
		"aura_haste": _haste(fmod(clock, 0.6) / 0.6, true)

static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)

# Fill with the toon outline around it, the way the 3D figures read.
func _shape(points: PackedVector2Array, color: Color, outline: float = 3.0) -> void:
	if points.size() < 3: return
	var ring := points.duplicate()
	ring.append(points[0])
	draw_polyline(ring, Color(OUTLINE, color.a), outline * size, true)
	# Shapes that start from zero size are degenerate on their first frame; skip the fill rather than error.
	if not Geometry2D.triangulate_polygon(points).is_empty(): draw_colored_polygon(points, color)

func _spike(angle: float, inner: float, outer: float, width: float, color: Color) -> void:
	var d := Vector2.from_angle(angle)
	var n := d.orthogonal() * width
	_shape(PackedVector2Array([d * inner + n, d * outer, d * inner - n, d * (inner * 0.6)]), color)

func _diamond(at: Vector2, radius: float, color: Color) -> void:
	_shape(PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius * 0.7, 0), at + Vector2(0, radius), at + Vector2(-radius * 0.7, 0)]), color, 2.0)

func _impact(t: float, power: float) -> void:
	var e := _ease_out(t)
	var fade := 1.0 - clampf((t - 0.45) / 0.55, 0.0, 1.0)
	var s := size * power
	if kind == "crit":
		# Shockwave ring behind the burst.
		draw_arc(Vector2.ZERO, (24.0 + 60.0 * e) * s, 0.0, TAU, 40, Color(OUTLINE, fade), (9.0 - 6.0 * e) * s + 3.0, true)
		draw_arc(Vector2.ZERO, (24.0 + 60.0 * e) * s, 0.0, TAU, 40, Color(Color("ffe2a0"), fade), (9.0 - 6.0 * e) * s, true)
	for ray in rays:
		var reach: float = (22.0 + 26.0 * e) * ray[1] * s
		_spike(ray[0], (6.0 + 16.0 * e) * s, reach, (7.0 * (1.0 - e) + 1.5) * ray[2] * s, Color(tint.lightened(0.15), fade))
	for spark in sparks:
		var angle: float = spark[0]
		var travel: float = spark[1] * clock
		var at := Vector2(cos(angle) * travel * direction, sin(angle) * travel + 260.0 * clock * clock) * s
		_diamond(at, spark[2] * s * (1.0 - t * 0.6), Color(Color("ffd37a"), fade))
	# White-hot core that pops then shrinks.
	var core := (16.0 + 6.0 * sin(minf(t * 3.0, 1.0) * PI)) * (1.0 - e * 0.8) * s
	draw_circle(Vector2.ZERO, core + 3.0 * size, Color(OUTLINE, fade))
	draw_circle(Vector2.ZERO, core, Color(Color("fff4d6"), fade))

func _block(t: float) -> void:
	var e := _ease_out(t)
	var fade := 1.0 - clampf((t - 0.5) / 0.5, 0.0, 1.0)
	var radius := (52.0 + 12.0 * e) * size
	var centre := Vector2(-18.0 * direction, 0.0) * size
	var facing := 0.0 if direction > 0.0 else PI
	var half := deg_to_rad(58.0)
	# Hex-plated barrier arc facing the attacker, flashing bright then thinning out.
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 13:
		var a: float = facing - half + 2.0 * half * i / 12.0
		outer.append(centre + Vector2.from_angle(a) * radius)
		inner.insert(0, centre + Vector2.from_angle(a) * (radius - (20.0 - 12.0 * e) * size))
	var plate := outer + inner
	_shape(plate, Color(tint.lerp(Color.WHITE, 0.6 * (1.0 - e)), 0.9 * fade))
	for i in range(1, 4):
		var a: float = facing - half + 2.0 * half * i / 4.0
		draw_line(centre + Vector2.from_angle(a) * (radius - 10.0 * size), centre + Vector2.from_angle(a) * radius, Color(OUTLINE, fade), 2.0 * size)
	for spark in sparks:
		var angle: float = facing + spark[0] * 1.4
		var at: Vector2 = centre + Vector2.from_angle(angle) * (radius + spark[1] * clock * 0.5)
		_diamond(at, spark[2] * size * 0.8, Color(Color("dff6ff"), fade))

func _heal(t: float) -> void:
	var e := _ease_out(t)
	var fade := 1.0 - clampf((t - 0.55) / 0.45, 0.0, 1.0)
	# Ring on the floor, then plus marks rising off it.
	var ring := Vector2(70.0, 20.0) * (0.4 + 0.6 * e) * size
	var points := PackedVector2Array()
	for i in 32:
		points.append(Vector2(cos(TAU * i / 32.0) * ring.x, sin(TAU * i / 32.0) * ring.y))
	points.append(points[0])
	draw_polyline(points, Color(OUTLINE, fade), 7.0 * size, true)
	draw_polyline(points, Color(tint, fade), 4.0 * size, true)
	for i in 5:
		var rise: float = clampf(t * 1.4 - i * 0.12, 0.0, 1.0)
		if rise <= 0.0: continue
		var at := Vector2((i - 2) * 24.0, -20.0 - 120.0 * _ease_out(rise)) * size
		var arm := 9.0 * size * (1.0 - rise * 0.4)
		var w := 3.5 * size
		var plus := PackedVector2Array([at + Vector2(-w, -arm), at + Vector2(w, -arm), at + Vector2(w, -w), at + Vector2(arm, -w), at + Vector2(arm, w), at + Vector2(w, w),
			at + Vector2(w, arm), at + Vector2(-w, arm), at + Vector2(-w, w), at + Vector2(-arm, w), at + Vector2(-arm, -w), at + Vector2(-w, -w)])
		_shape(plus, Color(tint.lightened(0.3), fade * (1.0 - rise * 0.5)), 2.5)

func _bolt() -> void:
	# Glowing slug along +x with a tapering trail; the caller rotates the node to its flight line.
	for i in range(3, 0, -1):
		var back := -14.0 * i * size
		_shape(PackedVector2Array([Vector2(back - 12.0 * size, 0), Vector2(back + 8.0 * size, -7.0 * size / i), Vector2(back + 14.0 * size, 0), Vector2(back + 8.0 * size, 7.0 * size / i)]), Color(tint, 0.5 / i), 2.0)
	var head := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		head.append(Vector2(cos(a) * 16.0, sin(a) * 8.0) * size)
	_shape(head, tint)
	draw_circle(Vector2(4.0, 0) * size, 4.5 * size, Color("fff4d6"))

func _beam() -> void:
	# Column of light from the floor with motes rising through it.
	var pulse := 0.75 + 0.25 * sin(clock * 9.0)
	var w := 26.0 * size * pulse
	var h := 300.0 * size
	draw_polygon(PackedVector2Array([Vector2(-w, 0), Vector2(w, 0), Vector2(w * 0.4, -h), Vector2(-w * 0.4, -h)]),
		PackedColorArray([Color(tint, 0.55), Color(tint, 0.55), Color(tint, 0.0), Color(tint, 0.0)]))
	for i in 6:
		var rise := fmod(clock * 0.8 + i / 6.0, 1.0)
		_diamond(Vector2(sin(i * 2.3 + clock * 3.0) * w * 0.6, -rise * h * 0.8), 4.0 * size, Color(Color("fff4d6"), 1.0 - rise))

func _fade(t: float, from: float = 0.55) -> float:
	return 1.0 - clampf((t - from) / (1.0 - from), 0.0, 1.0)

func _crescent(centre: Vector2, radius: float, from_angle: float, sweep: float, thick: float, color: Color) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 15:
		var k := i / 14.0
		var a := from_angle + sweep * k
		var w := thick * (0.1 + 0.9 * sin(k * PI))  # tapered at both tips, never zero (keeps the polygon simple)
		outer.append(centre + Vector2.from_angle(a) * (radius + w * 0.5))
		inner.insert(0, centre + Vector2.from_angle(a) * (radius - w * 0.5))
	_shape(outer + inner, color, 2.5)

func _puff(at: Vector2, radius: float, color: Color) -> void:
	draw_circle(at, radius + 2.5 * size, Color(OUTLINE, color.a))
	draw_circle(at, radius, color)
	draw_circle(at + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.35, Color(Color.WHITE, color.a * 0.35))

func _thrust(t: float) -> void:
	# A piercing streak driving through the target, then brass gear shards.
	var e := _ease_out(t / 0.6)
	var fade := _fade(t, 0.4)
	var tip := (40.0 + 80.0 * e) * direction * size
	var tail := (-90.0 + 60.0 * e) * direction * size
	_shape(PackedVector2Array([Vector2(tail, 0), Vector2(tip * 0.6, -15.0 * size * (1.0 - e * 0.5)), Vector2(tip, 0), Vector2(tip * 0.6, 15.0 * size * (1.0 - e * 0.5))]), Color(Color("fff4d6"), fade))
	_impact(t, 0.7)

func _slash(t: float, count: int, power: float) -> void:
	# Crescent blade arcs, one after another, crossing over the target.
	for i in count:
		var local := clampf((t - i * 0.28) / 0.55, 0.0, 1.0)
		if local <= 0.0: continue
		var e := _ease_out(local)
		var fade := 1.0 - clampf((local - 0.5) / 0.5, 0.0, 1.0)
		var flip := 1.0 if i % 2 == 0 else -1.0
		var start := (-2.2 if flip > 0 else 2.2) + (0.0 if direction > 0 else PI)
		_crescent(Vector2(-20.0 * direction, -10.0 * flip) * size, 62.0 * power * size, start, (1.9 * e + 0.2) * flip * direction, 16.0 * power * size, Color(tint, fade))
	if t > 0.2: _impact(t - 0.2, 0.7 * power)

func _smash(t: float) -> void:
	# Heavy blow: shock ellipse on the floor line, cracks fanning out, dust kicked up.
	var e := _ease_out(t)
	var fade := _fade(t)
	var floor_y := 46.0 * size
	draw_arc(Vector2(0, floor_y), (30.0 + 110.0 * e) * size, PI, TAU, 24, Color(OUTLINE, fade), 9.0 * size)
	draw_arc(Vector2(0, floor_y), (30.0 + 110.0 * e) * size, PI, TAU, 24, Color(tint, fade), 5.0 * size)
	for ray in rays:
		var a: float = PI + 0.35 + ray[1] * 2.4
		var crack := PackedVector2Array([Vector2(0, floor_y)])
		for k in 4:
			crack.append(Vector2(0, floor_y) + Vector2.from_angle(a + sin(k * 2.1 + ray[0]) * 0.25) * (k + 1) * 20.0 * e * size)
		draw_polyline(crack, Color(OUTLINE, fade), 4.0 * size)
	for i in 6:
		var at := Vector2((i - 2.5) * 34.0 * e, floor_y - 30.0 * e - 10.0 * sin(i)) * size
		_puff(at, (10.0 + 6.0 * e) * size, Color(Color("b9a58a"), fade * 0.85))
	_impact(t, 1.3)

func _jagged(from: Vector2, to: Vector2, segments: int, amplitude: float) -> PackedVector2Array:
	if jag.size() != segments:
		jag.clear()
		for i in segments: jag.append(rng.randf_range(-1.0, 1.0))
	var points := PackedVector2Array([from])
	var normal := (to - from).orthogonal().normalized()
	for i in range(1, segments):
		points.append(from.lerp(to, float(i) / segments) + normal * float(jag[i]) * amplitude)
	points.append(to)
	return points

func _zap(t: float, from: Vector2, to: Vector2, segments: int) -> void:
	var fade := _fade(t, 0.5)
	var points := _jagged(from, to, segments, 18.0 * size)
	draw_polyline(points, Color(OUTLINE, fade), 9.0 * size)
	draw_polyline(points, Color(tint, fade), 5.0 * size)
	draw_polyline(points, Color(Color.WHITE, fade), 2.0 * size)

func _zap_hit(t: float) -> void:
	var fade := _fade(t, 0.4)
	for ray in rays:
		var to: Vector2 = Vector2.from_angle(ray[0]) * (30.0 + 30.0 * ray[1]) * size * (0.6 + 0.4 * t)
		var mid: Vector2 = to * 0.5 + to.orthogonal() * 0.25 * sin(clock * 40.0 + ray[0] * 5.0)
		var points := PackedVector2Array([Vector2.ZERO, mid, to])
		draw_polyline(points, Color(OUTLINE, fade), 7.0 * size)
		draw_polyline(points, Color(tint, fade), 3.5 * size)
	draw_circle(Vector2.ZERO, 14.0 * (1.0 - t * 0.6) * size, Color(Color.WHITE, fade))

func _thunder(t: float) -> void:
	# A bolt from above straight onto the target, then the burst.
	if t < 0.55: _zap(t / 0.55 * 0.5, Vector2(rng.randf_range(-6, 6), -520.0) * size, Vector2.ZERO, 10)
	_zap_hit(t)
	_rings(t, 2, 80.0)

func _cloud(t: float) -> void:
	# Chemical fog billowing out and thinning, with a few popping bubbles.
	var e := _ease_out(t)
	var fade := _fade(t, 0.5)
	for i in 7:
		var a := TAU * i / 7.0 + 0.4
		var at := Vector2(cos(a) * 46.0, sin(a) * 22.0 - 10.0) * e * size
		_puff(at, (18.0 + 10.0 * e + 4.0 * sin(i * 1.7)) * size, Color(tint.darkened(0.15 * (i % 2)), fade * 0.8))
	for spark in sparks:
		var at := Vector2(cos(spark[0] * 3.0) * 40.0, -spark[1] * 0.25 * t) * size
		draw_arc(at, spark[2] * size, 0.0, TAU, 10, Color(tint.lightened(0.4), fade), 2.0 * size)

func _flame(at: Vector2, height: float, width: float, color: Color) -> void:
	_shape(PackedVector2Array([at + Vector2(-width, 0), at + Vector2(-width * 0.6, -height * 0.45), at + Vector2(0, -height),
		at + Vector2(width * 0.6, -height * 0.45), at + Vector2(width, 0), at + Vector2(0, width * 0.6)]), color, 2.5)

func _fire(t: float) -> void:
	# Flame tongues bursting up around the target, embers drifting off.
	var e := _ease_out(t / 0.5)
	var fade := _fade(t, 0.5)
	for i in 5:
		var x := (i - 2) * 22.0 * size
		var flick := 0.8 + 0.2 * sin(clock * 30.0 + i * 1.9)
		_flame(Vector2(x, 30.0 * size), (40.0 + 30.0 * (1.0 - abs(i - 2) / 2.0)) * e * flick * size, 13.0 * size, Color(tint, fade))
		_flame(Vector2(x, 30.0 * size), (22.0 + 16.0 * (1.0 - abs(i - 2) / 2.0)) * e * flick * size, 6.0 * size, Color(Color("ffe08a"), fade))
	for spark in sparks:
		_diamond(Vector2(cos(spark[0] * 4.0) * 40.0, 10.0 - spark[1] * 0.4 * t) * size, spark[2] * 0.7 * size, Color(Color("ffd37a"), fade))

func _splash(t: float) -> void:
	# Water burst: droplets thrown in arcs, a ring on the floor.
	var fade := _fade(t)
	for spark in sparks:
		var a: float = -PI * 0.5 + spark[0] * 1.6
		var travel: float = spark[1] * 0.7 * clock
		var at := Vector2(cos(a) * travel, sin(a) * travel + 420.0 * clock * clock) * size
		var r: float = spark[2] * 1.1 * size
		_shape(PackedVector2Array([at + Vector2(0, -r * 1.8), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)]), Color(tint, fade), 2.0)
	var ring := (20.0 + 60.0 * _ease_out(t)) * size
	draw_arc(Vector2(0, 40.0 * size), ring, 0.0, TAU, 28, Color(OUTLINE, fade), 6.0 * size)
	draw_arc(Vector2(0, 40.0 * size), ring, 0.0, TAU, 28, Color(tint, fade), 3.0 * size)

func _snare(t: float) -> void:
	# Copper clamp bands snapping shut around the target.
	var e := _ease_out(t / 0.5)
	var fade := _fade(t, 0.6)
	for i in 2:
		var gap := (1.0 - e) * 50.0 * size
		var y := (i * 34.0 - 20.0) * size
		_crescent(Vector2(-gap, y), 44.0 * size, PI * 0.55, PI * 0.9, 12.0 * size, Color(tint, fade))
		_crescent(Vector2(gap, y), 44.0 * size, -PI * 0.45, PI * 0.9, 12.0 * size, Color(tint, fade))
	if e >= 1.0:
		for i in 4: _diamond(Vector2((i - 1.5) * 24.0, -50.0) * size, 4.0 * size, Color(Color("ffe2a0"), fade))

func _reticle(t: float, steady: bool) -> void:
	# Brass-ringed crosshair locking on (shrinks onto the target), or held turning while Marked.
	var e := 1.0 if steady else _ease_out(t / 0.6)
	var fade := 1.0 if steady else _fade(t, 0.6)
	var r := (70.0 - 34.0 * e) * size
	var spin := clock * (1.2 if steady else 4.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(OUTLINE, fade), 7.0 * size)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(tint, fade), 3.5 * size)
	for i in 4:
		var a := spin + i * PI * 0.5
		var d := Vector2.from_angle(a)
		_shape(PackedVector2Array([d * (r - 10.0 * size), d * (r + 12.0 * size) + d.orthogonal() * 6.0 * size, d * (r + 12.0 * size) - d.orthogonal() * 6.0 * size]), Color(tint, fade), 2.0)

func _bite(t: float) -> void:
	# Two rows of fangs snapping together.
	var e := _ease_out(t / 0.45)
	var fade := _fade(t, 0.5)
	var open := (1.0 - e) * 46.0 * size
	for row in [-1.0, 1.0]:
		for i in 4:
			var x := (i - 1.5) * 28.0 * size
			var base: float = row * (open + 8.0 * size)
			_shape(PackedVector2Array([Vector2(x - 13.0 * size, base), Vector2(x + 13.0 * size, base), Vector2(x, base - row * 32.0 * size)]), Color(tint, fade), 3.0)
	if e >= 1.0: _impact(t - 0.45, 0.6)

func _rings(t: float, count: int, spread: float) -> void:
	for i in count:
		var local := clampf(t * 1.4 - i * 0.18, 0.0, 1.0)
		if local <= 0.0: continue
		var r := (20.0 + spread * _ease_out(local)) * size
		var fade := 1.0 - local
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(OUTLINE, fade), 7.0 * size)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(tint, fade), 3.5 * size)

func _charge(t: float) -> void:
	# Energy gathering into the hand: motes and a ring pulled inward.
	var fade := _fade(t, 0.7)
	var pull := 1.0 - _ease_out(t)
	draw_arc(Vector2.ZERO, (14.0 + 50.0 * pull) * size, 0.0, TAU, 28, Color(tint, fade * 0.9), 3.0 * size)
	for ray in rays:
		_diamond(Vector2.from_angle(ray[0] + t * 2.0) * (12.0 + 70.0 * pull * ray[1]) * size, 4.0 * size, Color(tint.lightened(0.4), fade))
	draw_circle(Vector2.ZERO, (6.0 + 8.0 * t) * size, Color(Color.WHITE, fade))

func _hex_ring(radius: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 7:
		points.append(Vector2.from_angle(deg_to_rad(-90.0 + i * 60.0)) * radius)
	draw_polyline(points, Color(OUTLINE, color.a), width + 3.0 * size, true)
	draw_polyline(points, color, width, true)

func _dome(t: float) -> void:
	# Hex-plated barrier blooming around the caster, then settling transparent.
	var e := _ease_out(t / 0.5)
	var fade := _fade(t, 0.6)
	var r := 95.0 * e * size
	draw_circle(Vector2.ZERO, r, Color(tint, 0.16 * fade))
	_hex_ring(r, Color(tint, fade), 4.0 * size)
	for i in 6:
		var at := Vector2.from_angle(deg_to_rad(-90.0 + i * 60.0)) * r * 0.55
		draw_arc(at, r * 0.2, 0.0, TAU, 6, Color(tint.lightened(0.3), fade * 0.6), 2.0 * size)

func _haste(t: float, steady: bool) -> void:
	# Chevrons streaming upward past the figure.
	for i in 3:
		var local := fmod(t + i / 3.0, 1.0)
		var fade := (1.0 - local) * (0.8 if steady else 1.0)
		var y := (40.0 - 140.0 * local) * size
		for side in [-1.0, 1.0]:
			var x: float = side * 52.0 * size
			_shape(PackedVector2Array([Vector2(x - 12.0 * size, y + 8.0 * size), Vector2(x, y - 6.0 * size), Vector2(x + 12.0 * size, y + 8.0 * size), Vector2(x, y)]), Color(tint, fade), 2.0)

func _steam(t: float, power: float) -> void:
	# Pressure vented as white plumes billowing up and out from the boiler.
	var fade := _fade(t, 0.45)
	for i in 6:
		var local := clampf(t * 1.3 - i * 0.07, 0.0, 1.0)
		var at := Vector2((-30.0 - 40.0 * local) * direction + sin(i * 2.0) * 16.0, -20.0 - 120.0 * local - i * 6.0) * size * power
		_puff(at, (10.0 + 22.0 * local) * size * power, Color(tint, fade * 0.85))

func _warp(t: float) -> void:
	# Deploying a drone: a spinning gear ring and a flash at its centre.
	var e := _ease_out(t / 0.6)
	var fade := _fade(t, 0.6)
	var r := 40.0 * e * size
	var teeth := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0 + clock * 3.0
		teeth.append(Vector2.from_angle(a) * (r + (8.0 if i % 2 == 0 else 0.0) * size))
	_shape(teeth, Color(Color("c8a25a"), fade))
	draw_circle(Vector2.ZERO, r * 0.55, Color(tint, fade))
	_rings(t, 1, 70.0)

func _aura_wet() -> void:
	for i in 4:
		var local := fmod(clock * 0.9 + i * 0.25, 1.0)
		var at := Vector2((i - 1.5) * 22.0, -60.0 + 110.0 * local) * size
		var r := 6.5 * size
		_shape(PackedVector2Array([at + Vector2(0, -r * 1.8), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)]), Color(tint, 1.0 - local), 1.5)

func _aura_heated() -> void:
	draw_circle(Vector2.ZERO, 50.0 * size, Color(tint, 0.14 + 0.06 * sin(clock * 6.0)))
	for i in 6:
		var local := fmod(clock * 0.7 + i / 6.0, 1.0)
		_flame(Vector2(sin(i * 2.4) * 34.0, 40.0 - 90.0 * local) * size, 16.0 * size * (1.0 - local), 5.0 * size, Color(tint, 1.0 - local))

func _aura_corroded() -> void:
	for i in 5:
		var local := fmod(clock * 0.6 + i * 0.2, 1.0)
		var at := Vector2(sin(i * 1.9) * 34.0, 30.0 - 70.0 * local) * size
		draw_arc(at, (5.0 + 6.0 * local) * size, 0.0, TAU, 12, Color(OUTLINE, 1.0 - local), 5.0 * size)
		draw_arc(at, (5.0 + 6.0 * local) * size, 0.0, TAU, 12, Color(tint, 1.0 - local), 2.5 * size)

func _aura_sealed() -> void:
	# Copper band turning around the waist.
	var spin := clock * 1.5
	for i in 3:
		_crescent(Vector2.ZERO, 50.0 * size, spin + i * TAU / 3.0, 1.3, 9.0 * size, Color(tint, 0.9))

func _aura_staggered() -> void:
	# Little stars circling over the head.
	for i in 3:
		var a := clock * 4.0 + i * TAU / 3.0
		var at := Vector2(cos(a) * 34.0, sin(a) * 10.0) * size
		var star := PackedVector2Array()
		for k in 10:
			star.append(at + Vector2.from_angle(-PI * 0.5 + k * PI / 5.0) * (11.0 if k % 2 == 0 else 4.5) * size)
		_shape(star, Color(tint, 0.95), 2.0)
