"""Turns raw VFX renders/paintings into game textures for additive blending.

python3 prototypes/vfx/pack_textures.py <lightning_dir> <codex_dir> <out_dir> [<painted_dir> <painted_out_dir> ...]
- bolt_<n>.png (Blender) -> bolts.png: 8 frames side by side, each with a two-radius blue halo.
- arcs_<n>.png (Blender) -> arcs.png: 6 frames stacked vertically, same halo.
- impact_flare.png / shock_ring.png (Codex image gen, on black) -> alpha from brightness.
- Extra <painted_dir> <painted_out_dir> pairs: every PNG in the dir (Codex paintings on black) -> 512 px, same alpha rule.
Output RGBA: straight (non-premultiplied) colour, alpha = brightness, ready for CanvasItemMaterial BLEND_MODE_ADD.
"""
import os
import sys

from PIL import Image, ImageChops, ImageFilter

SRC, PAINT, OUT = sys.argv[1:4]
EXTRA = list(zip(sys.argv[4::2], sys.argv[5::2]))
HALO = (70, 140, 255)


def glow(frame: Image.Image, scale: float) -> Image.Image:
    """Core render plus a tight and a wide blue halo built from its alpha, composed additively on black."""
    frame = frame.convert("RGBA")
    alpha = frame.getchannel("A")
    base = Image.new("RGB", frame.size, (0, 0, 0))
    for radius, gain in ((4 * scale, 0.9), (16 * scale, 0.55)):
        blur = alpha.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: min(255, int(v * gain * 2.2)))
        tint = Image.merge("RGB", [blur.point(lambda v, c=c: v * c // 255) for c in HALO])
        base = ImageChops.add(base, tint)
    core = Image.new("RGB", frame.size, (0, 0, 0))
    core.paste(frame.convert("RGB"), mask=alpha)
    return ImageChops.add(base, core)


def to_additive(rgb: Image.Image) -> Image.Image:
    """Alpha = brightest channel; colour divided back out so additive blending reproduces the image on black."""
    r, g, b = rgb.split()
    a = ImageChops.lighter(ImageChops.lighter(r, g), b)
    px_rgb, px_a = rgb.load(), a.load()
    out = Image.new("RGBA", rgb.size)
    px = out.load()
    for y in range(rgb.size[1]):
        for x in range(rgb.size[0]):
            al = px_a[x, y]
            if al < 3:
                px[x, y] = (0, 0, 0, 0)
                continue
            cr, cg, cb = px_rgb[x, y]
            px[x, y] = (min(255, cr * 255 // al), min(255, cg * 255 // al), min(255, cb * 255 // al), al)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    bolts = sorted(f for f in os.listdir(SRC) if f.startswith("bolt_"))
    frames = [glow(Image.open(os.path.join(SRC, f)), 1.0).resize((256, 512), Image.LANCZOS) for f in bolts]
    atlas = Image.new("RGB", (256 * len(frames), 512))
    for i, frame in enumerate(frames):
        atlas.paste(frame, (i * 256, 0))
    to_additive(atlas).save(os.path.join(OUT, "bolts.png"))
    arcs = sorted(f for f in os.listdir(SRC) if f.startswith("arcs_"))
    frames = [glow(Image.open(os.path.join(SRC, f)), 1.0).resize((512, 128), Image.LANCZOS) for f in arcs]
    atlas = Image.new("RGB", (512, 128 * len(frames)))
    for i, frame in enumerate(frames):
        atlas.paste(frame, (0, i * 128))
    to_additive(atlas).save(os.path.join(OUT, "arcs.png"))
    for name in ("impact_flare.png", "shock_ring.png"):
        path = os.path.join(PAINT, name)
        if os.path.exists(path):
            to_additive(Image.open(path).convert("RGB").resize((512, 512), Image.LANCZOS)).save(os.path.join(OUT, name))
    for folder, out in EXTRA:
        os.makedirs(out, exist_ok=True)
        for name in sorted(f for f in os.listdir(folder) if f.endswith(".png")):
            to_additive(Image.open(os.path.join(folder, name)).convert("RGB").resize((512, 512), Image.LANCZOS)).save(os.path.join(out, name))
    print("packed into", OUT, "and", [o for _, o in EXTRA])


main()
