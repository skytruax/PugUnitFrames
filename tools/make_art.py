#!/usr/bin/env python3
"""Draws every texture Free Unit Frames ships, from nothing but the shapes described here.

    python3 tools/make_art.py

Writes 32-bit TGA files into FreeUnitFrames/Art (the game reads those). Needs Pillow and numpy.
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
ART = os.path.join(ROOT, "FreeUnitFrames", "Art")
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


# ---------------------------------------------------------------------------
# The emblem: the bronze compass ring the Free addons share, with three bars on its disc
# ---------------------------------------------------------------------------
BARS = (  # how far below the middle, how full, colour: health, mana, energy
    (-0.112, 0.92, (104, 204, 138)),
    (0.000, 0.64, (92, 168, 230)),
    (0.112, 0.38, (236, 190, 86)),
)


def emblem(size, ss=None):
    """The addon's emblem, size x size. The ring and the disc are FreeControl's, drawn by the same
    code (tools/brand.py); in the middle, where FreeControl has a controller's four buttons, are
    three bars at three fills."""
    def bars(img, n, c):
        ink = brand.INK + (255,)
        half_w, half_h, line = 0.200 * n, 0.044 * n, 0.011 * n
        rows = np.arange(n, dtype=np.float32)
        for offset, share, colour in BARS:
            y, x0, x1 = c + offset * n, c - half_w, c + half_w
            shadow = Image.new("L", (n, n), 0)
            ImageDraw.Draw(shadow).rounded_rectangle([x0, y - half_h + 0.016 * n, x1, y + half_h + 0.016 * n], radius=half_h * 0.6, fill=255)
            img.alpha_composite(brand.tinted((0, 0, 0), shadow.filter(ImageFilter.GaussianBlur(0.014 * n)), 0.6))
            draw = ImageDraw.Draw(img)
            draw.rounded_rectangle([x0 - line, y - half_h - line, x1 + line, y + half_h + line], radius=half_h * 0.75, fill=ink)
            draw.rounded_rectangle([x0, y - half_h, x1, y + half_h], radius=half_h * 0.55, fill=(12, 36, 54, 255))
            # The filled part: lighter along the top, as the buttons of FreeControl's emblem are.
            fill = Image.new("L", (n, n), 0)
            ImageDraw.Draw(fill).rounded_rectangle([x0, y - half_h, x0 + 2 * half_w * share, y + half_h], radius=half_h * 0.55, fill=255)
            top = np.clip(np.asarray(colour, np.float32) * 1.22 + 14, 0, 255)
            bottom = np.asarray(colour, np.float32) * 0.70
            t = np.clip((rows - (y - half_h)) / (2 * half_h), 0, 1)[:, None]
            shade = Image.fromarray(np.broadcast_to((top * (1 - t) + bottom * t)[:, None, :], (n, n, 3)).astype(np.uint8), "RGB")
            img.paste(shade, mask=fill)
            gloss = Image.new("L", (n, n), 0)
            ImageDraw.Draw(gloss).rounded_rectangle([x0 + line, y - half_h + 0.008 * n, x0 + 2 * half_w * share - line, y - half_h * 0.2],
                                                    radius=half_h * 0.4, fill=255)
            gloss = ImageChops.multiply(gloss.filter(ImageFilter.GaussianBlur(0.006 * n)), fill)
            img.alpha_composite(brand.tinted((255, 255, 255), gloss, 0.30))

    if ss is None:
        ss = 8 if size <= 96 else 4 if size <= 256 else 3
    return brand.ring_emblem(size, bars, ss)


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

    save_tga(emblem(64), "Logo")  # the icon in the game's addon list
    print("art written to", ART)


if __name__ == "__main__":
    main()
