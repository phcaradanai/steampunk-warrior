// Shared by vfx_add / vfx_mix: a textured VFX layer that can be eaten away by noise (alpha erosion) instead of
// fading. dissolve 0 = whole, 1 = gone; the edge band softens so the cut reads as thinning energy or vapour.
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise : repeat_enable, filter_linear;

void fragment() {
	float n = texture(noise, UV * 1.6).r;
	COLOR.a *= smoothstep(dissolve * 1.1 - 0.1, dissolve * 1.1, n);
}
