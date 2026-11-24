#!/usr/bin/env python3
"""Draws every texture Pug Unit Frames ships, from nothing but the shapes described here.

    python3 tools/make_art.py

Writes 32-bit TGA files into PugUnitFrames/Art (the game reads those). Needs Pillow and numpy.
Everything is drawn large and scaled down, which is what makes the edges smooth. The pictures for
the README and the CurseForge page are tools/make_listing.py's.

Bar fills are white-to-grey, because the game multiplies them by the colour a bar is given.
"""
import math
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # the sibling module, also under python -I
import brand  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "PugUnitFrames", "Art")
SS = 8  # every shape is drawn this many times too large


def save_tga(image, name):
    """Uncompressed 32-bit TGA, rows stored bottom-up: the plainest form of the format."""
    image = image.convert("RGBA")
    width, height = image.size
    assert width & (width - 1) == 0 and height & (height - 1) == 0, "the game wants power-of-two sizes"
    red, green, blue, alpha = image.transpose(Image.FLIP_TOP_BOTTOM).split()
    pixels = Image.merge("RGBA", (blue, green, red, alpha)).tobytes()
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 8)
    with open(os.path.join(ART, name + ".tga"), "wb") as handle:
        handle.write(header + pixels)


def canvas(size):
    return Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))


def finish(image, size):
    return image.resize((size, size), Image.LANCZOS)


def scale(points):
    return [(x * SS, y * SS) for x, y in points]


# ---------------------------------------------------------------------------
# Bar fills
# ---------------------------------------------------------------------------
def bar(name, shade, along=None):
    """shade(t) gives the brightness (0-1) at height t, 0 at the top and 1 at the bottom.
    along(u), when given, scales it along the bar, u being 0 at the empty end and 1 at the full one."""
    width, height = 256, 32
    image = Image.new("RGBA", (width, height))
    for y in range(height):
        for x in range(width):
            level = shade(y / (height - 1)) * (along(x / (width - 1)) if along else 1.0)
            value = max(0, min(255, round(255 * level)))
            image.putpixel((x, y), (value, value, value, 255))
    save_tga(image, name)


def smooth(t):
    # Lit from above: a bright lip under the top edge, a full body, and a darker foot, so a bar
    # reads as a solid thing with light on it and not as a painted stripe.
    lip = 0.05 * math.exp(-((t - 0.10) / 0.09) ** 2)
    foot = 0.10 * max(0.0, (t - 0.80) / 0.20) ** 2
    return 0.95 - 0.22 * t ** 1.5 + lip - foot


def deepening(u):
    # A bar is a touch deeper in tone towards its empty end. The game shows the part of the picture
    # that matches how full the bar is, so a bar that runs low is left with the deeper part.
    return 0.86 + 0.14 * u ** 0.8


def flat(_t):
    return 1.0


def glass(t):
    # A bright band over the top half, then the darker body under it.
    if t < 0.46:
        return 1.0 - 0.10 * (t / 0.46)
    return 0.74 - 0.14 * ((t - 0.46) / 0.54)


# ---------------------------------------------------------------------------
# The shadow under a plate, and the bright edge of a bar's fill
# ---------------------------------------------------------------------------
SHADOW_SIZE = 64    # the plate is the middle half of the picture: 16 texels of shadow on every side
SHADOW_PLATE = 16


def shadow():
    """A soft dark cushion, black with only its alpha changing. Frame.lua lays it under a plate in
    nine pieces (corners, sides, middle), so it keeps its shape whatever the plate's size."""
    n, edge = SHADOW_SIZE * SS, SHADOW_PLATE * SS
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle([edge, edge, n - edge - 1, n - edge - 1], radius=2 * SS, fill=255)
    # Two blurs: a tight one that hugs the plate and a wide one that fades out, as a real shadow
    # does. Raised a little, so the shadow is still there half-way out; it ends before the
    # picture's edge, or the pieces would show their seams.
    tight = np.asarray(mask.filter(ImageFilter.GaussianBlur(2.6 * SS)), np.float32)
    wide = np.asarray(mask.filter(ImageFilter.GaussianBlur(5.2 * SS)), np.float32)
    level = np.clip(1.9 * (0.35 * tight + 0.65 * wide) - 14, 0, 255)
    alpha = Image.fromarray(level.astype(np.uint8), "L")
    image = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    image.putalpha(alpha)
    save_tga(image.resize((SHADOW_SIZE, SHADOW_SIZE), Image.LANCZOS), "Shadow")


def spark():
    """The bright edge where a bar's fill ends: a thin white line with a soft glow to both sides,
    fading out towards the top and the bottom. It is added to what is under it, not painted over it."""
    size = 32
    xs = np.arange(size, dtype=np.float32) - (size - 1) / 2
    ys = np.linspace(-1, 1, size, dtype=np.float32)
    across = 0.85 * np.exp(-(xs / 1.1) ** 2) + 0.42 * np.exp(-(xs / 4.6) ** 2)
    down = 1.0 - 0.38 * np.abs(ys) ** 2.2
    alpha = np.clip(np.outer(down, across), 0, 1)
    image = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    image.putalpha(Image.fromarray((alpha * 255).astype(np.uint8), "L"))
    save_tga(image, "Spark")


# ---------------------------------------------------------------------------
# Marks: small pictures on the rim of a frame, 64 x 64
# ---------------------------------------------------------------------------
def outlined(draw_shape, fill, size=64, outline=(12, 12, 14, 255), grow=2.2):
    """Draws a shape with a dark rim around it, so it reads on any background."""
    mask = Image.new("L", (size * SS, size * SS), 0)
    draw_shape(ImageDraw.Draw(mask))
    rim = mask.filter(ImageFilter.MaxFilter(int(grow * SS) * 2 + 1))
    image = canvas(size)
    image.paste(Image.new("RGBA", image.size, outline), (0, 0), rim)
    image.paste(Image.new("RGBA", image.size, fill), (0, 0), mask)
    return image


def shade_down(image, strength=0.28):
    """Darkens towards the bottom, for a little body."""
    width, height = image.size
    ramp = Image.new("L", (1, height))
    for y in range(height):
        ramp.putpixel((0, y), round(255 * strength * y / height))
    dark = Image.new("RGBA", image.size, (0, 0, 0, 255))
    dark.putalpha(Image.composite(ramp.resize(image.size), Image.new("L", image.size, 0), image.getchannel("A")))
    return Image.alpha_composite(image, dark)


def mark(name, draw_shape, fill, size=64):
    save_tga(finish(shade_down(outlined(draw_shape, fill, size)), size), name)


def crown(draw):
    draw.polygon(scale([(10, 46), (8, 20), (22, 32), (32, 12), (42, 32), (56, 20), (54, 46)]), fill=255)
    draw.rectangle(scale([(10, 46), (54, 54)]), fill=255)


def swords(draw):
    for sign in (1, -1):
        def flip(x, y):
            return (32 + sign * (x - 32), y)
        # blade, from the tip at the top to the guard
        draw.polygon(scale([flip(12, 8), flip(18, 8), flip(46, 40), flip(40, 46)]), fill=255)
        # guard and grip
        draw.polygon(scale([flip(34, 48), flip(48, 34), flip(52, 38), flip(38, 52)]), fill=255)
        draw.polygon(scale([flip(44, 44), flip(48, 40), flip(56, 52), flip(52, 56)]), fill=255)


def moon(draw):
    draw.ellipse(scale([(10, 8), (54, 52)]), fill=255)
    draw.ellipse(scale([(24, 4), (62, 42)]), fill=0)


def check(draw):
    draw.line(scale([(12, 34), (26, 48), (52, 16)]), fill=255, width=9 * SS, joint="curve")


def cross(draw):
    draw.line(scale([(16, 16), (48, 48)]), fill=255, width=9 * SS)
    draw.line(scale([(48, 16), (16, 48)]), fill=255, width=9 * SS)


def dots(draw):
    for x in (16, 32, 48):
        draw.ellipse(scale([(x - 6, 26), (x + 6, 38)]), fill=255)


def rising(draw):
    # An arrow pointing up out of a shallow arc: someone is being brought back.
    draw.polygon(scale([(32, 6), (50, 28), (38, 28), (38, 46), (26, 46), (26, 28), (14, 28)]), fill=255)
    draw.arc(scale([(10, 36), (54, 60)]), 20, 160, fill=255, width=5 * SS)


def shield(draw):
    draw.polygon(scale([(32, 6), (54, 14), (54, 32), (32, 58), (10, 32), (10, 14)]), fill=255)


# The part someone plays in a group.
def tank(draw):
    # A kite shield: flat across the top, drawn in to a point.
    draw.polygon(scale([(11, 8), (53, 8), (53, 30), (32, 58), (11, 30)]), fill=255)


def healer(draw):
    draw.rectangle(scale([(25, 8), (39, 56)]), fill=255)
    draw.rectangle(scale([(8, 25), (56, 39)]), fill=255)


def damage(draw):
    # One sword, point up and to the right.
    draw.polygon(scale([(52, 6), (58, 12), (26, 44), (20, 38)]), fill=255)
    draw.polygon(scale([(12, 32), (16, 28), (36, 48), (32, 52)]), fill=255)
    draw.polygon(scale([(8, 50), (14, 56), (22, 48), (16, 42)]), fill=255)


def pennant(draw):
    # A flag on its staff, for someone marked for fighting other players. White: the game tints
    # it with the colour of the side its bearer fights for.
    draw.rectangle(scale([(12, 6), (18, 58)]), fill=255)
    draw.polygon(scale([(18, 8), (56, 14), (42, 24), (56, 34), (18, 40)]), fill=255)


def face(mouth):
    """A round face with two eyes and the mouth drawn by mouth(draw): a hunter's pet's mood."""
    def shape(draw):
        draw.ellipse(scale([(6, 6), (58, 58)]), fill=255)
        for x in (22, 42):
            draw.ellipse(scale([(x - 4, 20), (x + 4, 30)]), fill=0)
        mouth(draw)
    return shape


def smile(draw):
    draw.arc(scale([(18, 20), (46, 48)]), 25, 155, fill=0, width=5 * SS)


def level(draw):
    draw.line(scale([(21, 42), (43, 42)]), fill=0, width=5 * SS)


def frown(draw):
    draw.arc(scale([(18, 38), (46, 66)]), 205, 335, fill=0, width=5 * SS)


# ---------------------------------------------------------------------------
# The emblem: the bronze compass ring the Free addons share, with a pug looking out of it
# ---------------------------------------------------------------------------
FAWN_LIGHT, FAWN_DARK = (244, 214, 170), (198, 150, 98)   # the coat, lit from above
MASK_LIGHT, MASK_DARK = (86, 66, 58), (40, 30, 28)        # the black mask of the muzzle and round the eyes
EAR = (50, 38, 34)
TONGUE = (238, 124, 134)


def emblem(size, ss=None):
    """The addon's emblem, size x size. The ring and the disc are FreeControl's, drawn by the same
    code (tools/brand.py); in the middle, where FreeControl has a controller's four buttons, a pug
    looks out: fawn head, black mask and ears, round eyes. A drawing of our own, made of nothing
    but the shapes below."""
    def pug(img, n, c):
        ink = brand.INK + (255,)

        def box(cx, cy, rx, ry):
            return [c + (cx - rx) * n, c + (cy - ry) * n, c + (cx + rx) * n, c + (cy + ry) * n]

        def blank():
            return Image.new("L", (n, n), 0)

        def ellipses(*shapes):
            mask = blank()
            draw = ImageDraw.Draw(mask)
            for shape in shapes:
                draw.ellipse(box(*shape), fill=255)
            return mask

        def soft(mask, radius):
            """Rounds a shape's corners off."""
            return mask.filter(ImageFilter.GaussianBlur(radius * n)).point(lambda v: 255 if v >= 128 else 0)

        def grown(mask, by):
            return mask.filter(ImageFilter.MaxFilter(int(by * n) * 2 + 1))

        def shade(mask, top, bottom, y0, y1):
            rows = np.clip((np.arange(n, dtype=np.float32) - (c + y0 * n)) / max(1.0, (y1 - y0) * n), 0, 1)[:, None]
            rgb = np.asarray(top, np.float32) * (1 - rows) + np.asarray(bottom, np.float32) * rows
            img.paste(Image.fromarray(np.broadcast_to(rgb[:, None, :], (n, n, 3)).astype(np.uint8), "RGB"), mask=mask)

        def flat(colour, mask, opacity=1.0):
            img.alpha_composite(brand.tinted(colour, mask, opacity))

        line = 0.011  # the dark outline every part gets

        # The head: a round skull over wide cheeks.
        head = soft(ellipses((0, -0.030, 0.198, 0.172), (0, 0.048, 0.226, 0.150)), 0.012)
        shadow = ImageChops.offset(head, 0, round(0.020 * n)).filter(ImageFilter.GaussianBlur(0.018 * n))
        flat((0, 0, 0), shadow, 0.45)
        flat(ink[:3], grown(head, line))
        shade(head, FAWN_LIGHT, FAWN_DARK, -0.20, 0.20)
        # A lighter brow and a little warmth low on the cheeks, so the head is not a flat disc.
        brow = ImageChops.multiply(ellipses((0, -0.120, 0.120, 0.060)).filter(ImageFilter.GaussianBlur(0.03 * n)), head)
        flat((255, 244, 220), brow, 0.40)
        for side in (-1, 1):
            cheek = ImageChops.multiply(ellipses((side * 0.150, 0.075, 0.060, 0.050)).filter(ImageFilter.GaussianBlur(0.025 * n)), head)
            flat((178, 120, 78), cheek, 0.35)

        # The ears: small dark flaps folded forward over the corners of the skull.
        for side in (-1, 1):
            flap = blank()
            ImageDraw.Draw(flap).polygon([(c + side * 0.214 * n, c - 0.178 * n), (c + side * 0.088 * n, c - 0.196 * n),
                                          (c + side * 0.122 * n, c - 0.100 * n), (c + side * 0.236 * n, c - 0.030 * n)], fill=255)
            flap = soft(flap, 0.016)
            flat(ink[:3], grown(flap, line))
            shade(flap, (74, 58, 52), EAR, -0.20, -0.03)

        # The mask: the muzzle, a bridge up the nose, and a patch round each eye.
        mask = soft(ellipses((0, 0.092, 0.128, 0.098), (0, 0.010, 0.052, 0.080), (-0.098, -0.022, 0.070, 0.064), (0.098, -0.022, 0.070, 0.064)), 0.010)
        mask = ImageChops.multiply(mask, head)
        shade(mask, MASK_LIGHT, MASK_DARK, -0.09, 0.19)
        d = ImageDraw.Draw(img)
        # Two creases across the brow.
        for cy, rx, ry in ((-0.108, 0.074, 0.030), (-0.140, 0.046, 0.020)):
            d.arc(box(0, cy, rx, ry), 205, 335, fill=(150, 104, 66, 255), width=max(1, round(0.009 * n)))

        # The eyes: large, round and dark, with the light in them.
        for side in (-1, 1):
            eye = ellipses((side * 0.098, -0.022, 0.047, 0.047))
            flat((156, 112, 76), grown(eye, 0.007))
            flat((16, 12, 12), eye)
            flat((96, 62, 40), ImageChops.multiply(ellipses((side * 0.098, 0.004, 0.040, 0.028)).filter(ImageFilter.GaussianBlur(0.008 * n)), eye), 0.75)
            flat((255, 255, 255), ellipses((side * 0.098 - 0.016, -0.038, 0.015, 0.015)), 0.95)
            flat((255, 255, 255), ellipses((side * 0.098 + 0.016, -0.004, 0.006, 0.006)), 0.60)

        # The tongue first, so the mouth's line lies over its top.
        tongue = ellipses((0, 0.150, 0.030, 0.036))
        flat(ink[:3], grown(tongue, 0.006))
        shade(tongue, (250, 150, 158), TONGUE, 0.11, 0.19)
        d = ImageDraw.Draw(img)
        d.line([(c, c + 0.130 * n), (c, c + 0.168 * n)], fill=(196, 84, 98, 255), width=max(1, round(0.006 * n)))
        cover = ellipses((0, 0.104, 0.060, 0.026))
        shade(cover, (62, 48, 42), (54, 42, 38), 0.07, 0.13)
        d = ImageDraw.Draw(img)
        stroke = max(1, round(0.010 * n))
        d.line([(c, c + 0.066 * n), (c, c + 0.098 * n)], fill=ink, width=stroke)
        d.arc(box(-0.040, 0.094, 0.040, 0.034), 0, 150, fill=ink, width=stroke)
        d.arc(box(0.040, 0.094, 0.040, 0.034), 30, 180, fill=ink, width=stroke)
        # The nose, wide and black, with a glint.
        nose = soft(ellipses((0, 0.040, 0.046, 0.030), (0, 0.052, 0.026, 0.024)), 0.006)
        flat((12, 10, 10), nose)
        flat((255, 255, 255), ellipses((-0.012, 0.030, 0.016, 0.007)).filter(ImageFilter.GaussianBlur(0.004 * n)), 0.45)
        # Whisker spots.
        for side in (-1, 1):
            for dx, dy in ((0.062, 0.086), (0.084, 0.104), (0.060, 0.118)):
                flat((126, 100, 88), ellipses((side * dx, dy, 0.006, 0.006)))

    if ss is None:
        ss = 8 if size <= 96 else 4 if size <= 256 else 3
    return brand.ring_emblem(size, pug, ss)


def main():
    os.makedirs(ART, exist_ok=True)
    bar("Bar-Smooth", smooth, deepening)
    bar("Bar-Flat", flat)
    bar("Bar-Glass", glass, deepening)
    shadow()
    spark()

    mark("Mark-Leader", crown, (240, 196, 72, 255))
    mark("Mark-Combat", swords, (226, 92, 70, 255))
    mark("Mark-Rest", moon, (176, 200, 240, 255))
    mark("Mark-Ready", check, (104, 214, 122, 255))
    mark("Mark-NotReady", cross, (226, 84, 70, 255))
    mark("Mark-Waiting", dots, (236, 190, 86, 255))
    mark("Mark-Resurrect", rising, (250, 236, 170, 255))
    mark("Mark-Shield", shield, (176, 184, 196, 255))
    mark("Mark-Tank", tank, (122, 164, 226, 255))
    mark("Mark-Healer", healer, (104, 214, 122, 255))
    mark("Mark-Damage", damage, (226, 108, 84, 255))
    mark("Mark-PvP", pennant, (255, 255, 255, 255))
    mark("Mood-Happy", face(smile), (104, 214, 122, 255))
    mark("Mood-Content", face(level), (236, 190, 86, 255))
    mark("Mood-Unhappy", face(frown), (226, 84, 70, 255))

    save_tga(emblem(64), "Logo")  # the icon in the game's addon list
    print("art written to", ART)


if __name__ == "__main__":
    main()
