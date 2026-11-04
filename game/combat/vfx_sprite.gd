class_name VfxSprite
extends Sprite2D
# Plays one pixelfx sprite sheet (art/vfx/<name>.png + .json) at its pivot; one-shots free themselves, loops run until freed.

const PIXEL := 3.0
static var _meta := {}
var fps: float = 30.0
var frames: int = 1
var loop: bool = false
var clock: float = 0.0

static func spawn(parent: Node, name: String, point: Vector2, flip: bool = false, pixel: float = PIXEL) -> VfxSprite:
	var fx := VfxSprite.new()
	var meta: Dictionary = _load(name)
	fx.texture = load("res://art/vfx/%s.png" % name)
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.hframes = meta.columns
	fx.vframes = ceili(float(meta.frames)/meta.columns)
	fx.frames = meta.frames
	fx.fps = meta.fps
	fx.loop = meta.loop
	fx.centered = false
	fx.offset = -Vector2(meta.pivot[0], meta.pivot[1])
	fx.flip_h = flip
	# Flipping mirrors the sheet around its own centre, so move the pivot to the mirrored column.
	if flip: fx.offset.x = meta.pivot[0] - meta.frameSize[0]
	fx.scale = Vector2.ONE*pixel
	fx.position = point
	parent.add_child(fx)
	return fx

static func _load(name: String) -> Dictionary:
	if not _meta.has(name):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/vfx/%s.json" % name))
		_meta[name] = data.meta.pixelfx
	return _meta[name]

func _process(delta: float) -> void:
	clock += delta
	var index := int(clock*fps)
	if index >= frames and not loop:
		queue_free()
		return
	frame = index % frames
