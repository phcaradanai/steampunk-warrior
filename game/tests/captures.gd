class_name Captures
# Viewport read-back for capture scripts. With use_hdr_2d the viewport holds linear colour and Godot converts to
# sRGB only when blitting to the screen, so a raw get_image() is darker than what players see; convert it here.
static func frame(viewport: Viewport) -> Image:
	var image := viewport.get_texture().get_image()
	if viewport.use_hdr_2d:
		image.convert(Image.FORMAT_RGBA8)
		image.linear_to_srgb()
	return image
