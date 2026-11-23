#!/usr/bin/env python3
"""The look the Free addons' pictures share: the sunny city under a clear sky, the title set in
LifeCraft, and the bronze compass ring of the emblem.

This is the drawing code behind FreeControl's banner and logo (github.com/skytruax/FreeControl,
tools/make_listing.py and tools/make_art.py), kept the same here on purpose so that the addons
look like one family. tools/make_listing.py uses it; nothing in it is specific to unit frames.

The title typeface, LifeCraft, is Eliot Truelove's Warcraft-style font. It is donationware (free
to use; its author asks for a donation) and somebody else's work, so the file is never committed:
it is fetched once into tools/.font-cache/ (git-ignored). The other lettering is Inter.
"""
import functools
import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BRONZE_LIGHT = (226, 200, 138)
BRONZE_DARK = (84, 62, 32)
INK = (6, 6, 8)
WHITE = (246, 246, 250, 255)
SOFT = (184, 192, 210, 255)   # a slide's second line
DIM = (140, 148, 168, 255)    # small print
GOLD = (255, 214, 96, 255)    # the part of a headline that carries the point


# ---------------------------------------------------------------------------
# Lettering
# ---------------------------------------------------------------------------
def font(size, weight="Bold"):
    for path in (os.path.expanduser("~/.local/share/fonts/Inter/Inter-%s.ttf" % weight),
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, round(size))
    raise FileNotFoundError("no font found; add one to font() in tools/brand.py")


# The title on the big pictures is set in LifeCraft; see the top of this file.
TITLE_FONT_ZIP = "https://dl.dafont.com/dl/?f=lifecraft"
TITLE_FONT_FILE = "LifeCraft_Font.ttf"
FONT_CACHE = os.path.join(ROOT, "tools", ".font-cache")


@functools.lru_cache(maxsize=None)
def title_font_path():
    """Where the title typeface is, fetching it the first time; None if it cannot be had, in
    which case the title falls back to the ordinary typeface."""
    path = os.path.join(FONT_CACHE, TITLE_FONT_FILE)
    if not os.path.exists(path):
        import io
        import urllib.request
        import zipfile
        try:
            request = urllib.request.Request(TITLE_FONT_ZIP, headers={"User-Agent": "Mozilla/5.0 (picture build)"})
            with urllib.request.urlopen(request, timeout=40) as response:
                archive = zipfile.ZipFile(io.BytesIO(response.read()))
            names = [n for n in archive.namelist() if n.lower().endswith(".ttf")]
            os.makedirs(FONT_CACHE, exist_ok=True)
            with open(path, "wb") as f:
                f.write(archive.read(names[0]))
        except Exception as problem:  # no network, or the site has moved: say so and carry on plainer
            print("could not fetch the title typeface (%s); using the ordinary one" % problem)
            return None
    return path


def title_text(canvas, xy, string, size):
    """The big title: Warcraft-style letters, cream running to gold, with a dark edge and a soft
    shadow. Falls back to the ordinary bold typeface if the title one is not to be had."""
    path = title_font_path()
    if not path:
        shadow_text(canvas, xy, string, size * 0.86, WHITE, "Black")
        return
    face = ImageFont.truetype(path, round(size))
    edge_w = max(2, round(size * 0.030))
    fill = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(fill).text(xy, string, font=face, fill=255, anchor="mm")
    edge = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(edge).text(xy, string, font=face, fill=255, anchor="mm", stroke_width=edge_w)
    shadow = ImageChops.offset(edge.filter(ImageFilter.GaussianBlur(size * 0.045)), 0, round(size * 0.035))
    canvas.alpha_composite(masked((6, 26, 60), shadow, 0.70))
    canvas.alpha_composite(masked((48, 30, 14), edge))
    box_ = fill.getbbox() or (0, 0, canvas.width, canvas.height)
    tint = Image.new("RGB", canvas.size, (255, 250, 236))
    tint.paste(vertical((canvas.width, max(1, box_[3] - box_[1])), (255, 252, 240), (244, 206, 132)), (0, box_[1]))
    canvas.alpha_composite(masked(tint, fill))
    # A hairline of light along the top of the letters, as on an embossed sign.
    lip = ImageChops.subtract(fill, ImageChops.offset(fill, 0, max(1, round(size * 0.012))))
    canvas.alpha_composite(masked((255, 255, 255), lip, 0.55))


# ---------------------------------------------------------------------------
# Small drawing helpers
# ---------------------------------------------------------------------------
def vertical(size, top, bottom):
    w, h = size
    t = np.linspace(0, 1, h)[:, None, None]
    row = np.array(top, dtype=np.float32) * (1 - t) + np.array(bottom, dtype=np.float32) * t
    return Image.fromarray(np.broadcast_to(row, (h, w, 3)).astype(np.uint8), "RGB")


def masked(fill, mask, opacity=1.0):
    if isinstance(fill, tuple):
        fill = Image.new("RGB", mask.size, fill)
    out = fill.convert("RGBA")
    out.putalpha(mask.point(lambda v: int(v * opacity)) if opacity != 1.0 else mask)
    return out


def noise(size, strength, seed):
    rng = np.random.default_rng(seed)
    w, h = size
    grain = rng.normal(0, strength, (h // 3 + 1, w // 3 + 1)).astype(np.float32)
    return np.asarray(Image.fromarray(grain).resize((w, h), Image.BICUBIC))[..., None]


def drawn(w, h, paint, ss=4):
    """A w x h layer that `paint(draw, scale)` drew on. It is drawn `ss` times larger and scaled
    down, because the drawing calls themselves do not smooth their edges."""
    w, h = round(w), round(h)
    layer = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    paint(ImageDraw.Draw(layer), ss)
    return layer.resize((w, h), Image.LANCZOS)


def box(canvas, rect, radius, fill, outline=None, width=2):
    """A rounded rectangle, blended onto the canvas."""
    x0, y0, x1, y1 = [round(v) for v in rect]
    w, h = x1 - x0, y1 - y0
    canvas.alpha_composite(drawn(w, h, lambda d, s: d.rounded_rectangle(
        (0, 0, w * s - 1, h * s - 1), radius=radius * s, fill=fill, outline=outline, width=width * s)), (x0, y0))


def text(canvas, xy, string, size, fill=WHITE, weight="Bold", anchor="mm"):
    ImageDraw.Draw(canvas).text(xy, string, font=font(size, weight), fill=fill, anchor=anchor)


def shadow_text(canvas, xy, string, size, fill=WHITE, weight="Bold", anchor="mm", spread=10, strength=0.75):
    """Text with a soft dark halo, for writing over a picture."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((xy[0], xy[1] + size * 0.05), string, font=font(size, weight),
                               fill=(0, 0, 0, round(255 * strength)), anchor=anchor)
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(spread)))
    text(canvas, xy, string, size, fill, weight, anchor)


def pills(canvas, cx, cy, labels, size=28, height=58, fill=(255, 255, 255, 18), outline=(255, 255, 255, 64)):
    """A centred row of rounded labels."""
    f, pad, gap = font(size, "SemiBold"), 30, 18
    widths = [ImageDraw.Draw(canvas).textlength(label, font=f) + 2 * pad for label in labels]
    x = cx - (sum(widths) + gap * (len(labels) - 1)) / 2
    for label, width in zip(labels, widths):
        box(canvas, (x, cy - height / 2, x + width, cy + height / 2), height / 2, fill, outline)
        ImageDraw.Draw(canvas).text((x + width / 2, cy), label, font=f, fill=WHITE, anchor="mm")
        x += width + gap


def headline(canvas, cx, y, parts, size):
    """One centred line made of (text, colour) parts."""
    d, f = ImageDraw.Draw(canvas), font(size, "Black")
    widths = [d.textlength(string, font=f) for string, _ in parts]
    x = cx - sum(widths) / 2
    for (string, colour), width in zip(parts, widths):
        d.text((x, y), string, font=f, fill=colour, anchor="lm")
        x += width


# ---------------------------------------------------------------------------
# Backgrounds
# ---------------------------------------------------------------------------
def backdrop(w, h, glows=(), seed=11):
    """Dark slate, lighter towards the middle. glows: (x, y, radius x, radius y, strength) of warm light."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    dist = np.hypot((x - w / 2) / (w / 2), (y - h * 0.52) / (h / 2))
    base = np.array((38, 44, 60), dtype=np.float32) * np.clip(1.08 - 0.5 * dist, 0.35, 1.1)[..., None]
    for gx, gy, rx, ry, strength in glows:
        fall = np.clip(1 - np.hypot((x - gx) / rx, (y - gy) / ry), 0, 1)[..., None] ** 2
        base = base + np.array((255, 190, 100), dtype=np.float32) * fall * strength
    base = base + noise((w, h), 2.5, seed)
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


# ---------------------------------------------------------------------------
# The scene behind the title pictures
# ---------------------------------------------------------------------------
def ridge(w, rng, sharp):
    """The outline of a line of hills as heights from 0 to 1; sharp gives pointed peaks."""
    x = np.linspace(0, 1, w, dtype=np.float32)
    total = np.zeros(w, np.float32)
    amp, knots = 1.0, 4
    for _ in range(6):
        values = rng.uniform(-1, 1, knots + 1).astype(np.float32)
        pos = x * knots
        i = np.minimum(pos.astype(np.int32), knots - 1)
        t = (1 - np.cos((pos - i) * np.pi)) / 2
        total += amp * (values[i] * (1 - t) + values[i + 1] * t)
        amp *= 0.5
        knots *= 2
    if sharp:
        total = -np.abs(total)
    total -= total.min()
    return total / total.max()


def cloud(w, h, rng, grain):
    """Soft blotches from 0 to 1: a small field of random numbers stretched over the picture.
    grain is how many blotches fit across its width."""
    small = rng.uniform(0, 1, (max(2, round(grain * h / w)), grain)).astype(np.float32)
    field = np.asarray(Image.fromarray(small).resize((w, h), Image.BICUBIC))
    return np.clip(field, 0, 1)


def landscape(w, h, seed=4):
    """A sunny city of white stone and blue roofs under a bright sky: a keep and a cathedral
    among lesser towers, gold on the spires, banners on the gate. It is a drawing of our own of
    the kind of city the game's humans live in, stands in for the game world behind the bar,
    and is plainly not a screenshot."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    sky_top, sky_low = np.array((22, 112, 188), np.float32), np.array((170, 226, 242), np.float32)
    air = np.array((176, 222, 240), np.float32)  # what distance fades things towards
    stone, shade, roof, roof_dark = (242, 236, 222), (204, 204, 212), (48, 108, 186), (30, 74, 140)
    gold, glass = (250, 204, 86), (52, 84, 128)

    def mix(a, b, amount):
        return np.asarray(a, np.float32) * (1 - amount) + np.asarray(b, np.float32) * amount

    def far(colour, depth):
        """A colour as it looks `depth` of the way from the horizon (0) to the near wall (1)."""
        return tuple(int(v) for v in mix(air, colour, 0.30 + 0.70 * depth)) + (255,)

    # Sky: a deep clear blue overhead, paling to the horizon, the sun off to the upper right.
    rows = np.clip(y / (0.80 * h), 0, 1)[..., None] ** 0.85
    sky = mix(sky_top, sky_low, rows)
    sun = np.clip(1 - np.hypot((x - 0.84 * w) / (0.50 * w), (y - 0.16 * h) / (0.46 * h)), 0, 1)[..., None] ** 2
    img = Image.fromarray(np.clip(mix(sky, (255, 252, 236), sun * 0.55), 0, 255).astype(np.uint8), "RGB").convert("RGBA")

    # Fair-weather clouds, kept to the sides so the title has clear sky behind it.
    clouds = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(clouds)
    for cx, cy, size in ((0.09, 0.30, 1.0), (0.26, 0.42, 0.62), (0.93, 0.36, 0.9), (0.76, 0.46, 0.55), (0.50, 0.50, 0.42)):
        puffs = [(dx, rng.uniform(0.55, 1.0)) for dx in np.linspace(-1, 1, 7)]
        for layer_colour, drop in (((196, 224, 242, 255), 0.012), ((255, 255, 255, 255), 0.0)):  # the shaded underside first
            for dx, big_r in puffs:
                r = 0.036 * h * size * big_r * (1 - 0.45 * abs(dx))
                px, py = (cx + dx * 0.075 * size) * w, (cy + drop) * h - r * 0.55
                d.ellipse([(px - r * 1.5) * 2, (py - r) * 2, (px + r * 1.5) * 2, (py + r) * 2], fill=layer_colour)
            d.rounded_rectangle([(cx - 0.085 * size) * w * 2, (cy + drop - 0.012 * size) * h * 2, (cx + 0.085 * size) * w * 2,
                                 (cy + drop + 0.012 * size) * h * 2], radius=0.012 * size * h * 2, fill=layer_colour)
    img.alpha_composite(clouds.resize((w, h), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.2)))

    # The mountains behind the city, blue with distance.
    for base, amp, colour, alpha in ((0.60, 0.22, (120, 176, 220), 255), (0.66, 0.14, (104, 168, 206), 255)):
        crest = (base - amp * ridge(w, rng, True)) * h
        sink = np.clip((y - crest[None, :]) / (0.20 * h), 0, 1)[..., None]
        fill = mix(np.array(colour, np.float32), air, sink * 0.7)
        hills = np.concatenate([fill, (np.clip(y - crest[None, :] + 0.5, 0, 1) * alpha)[..., None]], axis=-1)
        img.alpha_composite(Image.fromarray(hills.clip(0, 255).astype(np.uint8), "RGBA"))

    ss = 2
    row = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(row)

    def box(x0, top, x1, bottom, fill):
        d.rectangle([x0 * ss, top * ss, x1 * ss, bottom * ss], fill=fill)

    def tri(points, fill):
        d.polygon([(px * ss, py * ss) for px, py in points], fill=fill)

    def spire(cx, foot, wide, body, roof_h, depth, flag=False, lit=True):
        """A round tower: a pale shaft with its shaded side, a collar, a blue cone with its dark
        side, a gold ball on the point, and now and then a banner."""
        top = foot - body
        box(cx - wide / 2, top, cx + wide / 2, foot, far(stone, depth))
        box(cx + wide * 0.14, top, cx + wide / 2, foot, far(shade, depth))
        box(cx - wide * 0.64, top - wide * 0.16, cx + wide * 0.64, top + wide * 0.08, far(shade, depth))
        eave, tip = top - wide * 0.14, top - wide * 0.14 - roof_h
        tri([(cx - wide * 0.74, eave), (cx + wide * 0.74, eave), (cx, tip)], far(roof, depth))
        tri([(cx + wide * 0.10, eave), (cx + wide * 0.74, eave), (cx, tip)], far(roof_dark, depth))
        if lit and wide > 0.008 * w:
            for level in range(1, 1 + int(body / (wide * 1.6))):
                wy = top + level * wide * 1.5
                if wy + wide * 0.5 < foot:
                    box(cx - wide * 0.10, wy, cx + wide * 0.06, wy + wide * 0.42, far(glass, depth))
        r = max(1.0, wide * 0.12)
        d.ellipse([(cx - r) * ss, (tip - r) * ss, (cx + r) * ss, (tip + r) * ss], fill=far(gold, depth))
        if flag:
            mast = tip - wide * 0.62
            d.line([(cx * ss, tip * ss), (cx * ss, mast * ss)], fill=far(shade, depth), width=max(2, round(wide * 0.07 * ss)))
            tri([(cx, mast), (cx + wide * 0.70, mast + wide * 0.16), (cx, mast + wide * 0.34)], far(gold, depth))

    def house(cx, foot, half, body, depth, blue):
        box(cx - half, foot - body, cx + half, foot, far(stone if blue else (232, 220, 200), depth))
        tri([(cx - half * 1.18, foot - body), (cx + half * 1.18, foot - body), (cx, foot - body - half * 1.25)],
            far(roof if blue else (156, 96, 76), depth))
        tri([(cx, foot - body), (cx + half * 1.18, foot - body), (cx, foot - body - half * 1.25)],
            far(roof_dark if blue else (124, 72, 60), depth))

    def wall(x0, x1, top, foot, depth, tooth):
        box(x0, top, x1, foot, far(stone, depth))
        box(x0, top + (foot - top) * 0.10, x1, top + (foot - top) * 0.16, far(shade, depth))  # a string course
        at = x0
        while at < x1:
            box(at, top - tooth * 0.8, min(x1, at + tooth), top, far(stone, depth))
            at += tooth * 2

    def trees(foot, count, depth, x0=0.0, x1=1.0):
        for _ in range(count):
            tx, r = rng.uniform(x0, x1) * w, rng.uniform(0.010, 0.020) * h * (0.6 + 0.6 * depth)
            green = (rng.integers(70, 104), rng.integers(150, 182), rng.integers(84, 112))
            d.ellipse([(tx - r * 1.2) * ss, (foot - r * 1.9) * ss, (tx + r * 1.2) * ss, (foot + r * 0.3) * ss], fill=far(green, depth))

    def settle(centre=None, strength=0.0):
        """Puts the row just drawn on the picture, then a breath of haze over its feet."""
        nonlocal row, d
        img.alpha_composite(row.resize((w, h), Image.LANCZOS))
        row = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
        d = ImageDraw.Draw(row)
        if centre:
            band = np.exp(-((y - centre * h) / (0.03 * h)) ** 2) * (0.6 + 0.4 * cloud(w, h, rng, 6)) * strength
            fog = np.concatenate([np.full((h, w, 3), (236, 246, 250), np.float32), band[..., None] * 255], axis=-1)
            img.alpha_composite(Image.fromarray(fog.clip(0, 255).astype(np.uint8), "RGBA"))

    # The far quarter: a crowd of roofs and small towers, pale with distance.
    foot = 0.725 * h
    for _ in range(40):
        wide = rng.uniform(0.007, 0.012) * w
        spire(rng.uniform(0.02, 0.98) * w, foot, wide, rng.uniform(0.03, 0.09) * h, wide * rng.uniform(1.5, 2.4), 0.18, lit=False)
    for _ in range(90):
        house(rng.uniform(0, 1) * w, foot, rng.uniform(0.006, 0.011) * w, rng.uniform(0.012, 0.030) * h, 0.18, rng.uniform() < 0.8)
    box(0, foot - 0.004 * h, w, foot + 0.06 * h, far(stone, 0.18))
    settle(0.725, 0.5)

    # The keep and the cathedral, one to each side of the middle, with the town between.
    foot = 0.815 * h
    depth = 0.62
    kx = 0.225 * w  # the keep: a tall hall crowded with spires, the highest in the middle
    box(kx - 0.088 * w, foot - 0.125 * h, kx + 0.088 * w, foot, far(stone, depth))
    box(kx + 0.030 * w, foot - 0.125 * h, kx + 0.088 * w, foot, far(shade, depth))
    wall(kx - 0.108 * w, kx + 0.108 * w, foot - 0.062 * h, foot, depth, 0.006 * w)
    for dx, wide, body, roof_h, flag in ((0, 0.032, 0.300, 0.115, True), (-0.042, 0.020, 0.215, 0.078, False), (0.042, 0.020, 0.215, 0.078, False),
                                         (-0.076, 0.016, 0.160, 0.060, True), (0.076, 0.016, 0.160, 0.060, True),
                                         (-0.103, 0.014, 0.105, 0.046, False), (0.103, 0.014, 0.105, 0.046, False)):
        spire(kx + dx * w, foot, wide * w, body * h, roof_h * h, depth, flag)
    cx = 0.780 * w  # the cathedral: a long nave under a blue roof, two west towers, a spire over the crossing
    box(cx - 0.072 * w, foot - 0.108 * h, cx + 0.072 * w, foot, far(stone, depth))
    tri([(cx - 0.078 * w, foot - 0.108 * h), (cx + 0.078 * w, foot - 0.108 * h), (cx + 0.062 * w, foot - 0.156 * h),
         (cx - 0.062 * w, foot - 0.156 * h)], far(roof, depth))
    for nx in np.linspace(-0.058, 0.058, 7):  # the nave's tall windows
        box(cx + nx * w - 0.003 * w, foot - 0.085 * h, cx + nx * w + 0.003 * w, foot - 0.030 * h, far(glass, depth))
    for dx, wide, body, roof_h, flag in ((0.014, 0.023, 0.235, 0.140, True), (-0.060, 0.018, 0.178, 0.072, False), (-0.031, 0.018, 0.178, 0.072, False),
                                         (0.068, 0.013, 0.132, 0.052, False)):
        spire(cx + dx * w, foot, wide * w, body * h, roof_h * h, depth, flag)
    mx = 0.515 * w  # the mages' tower: taller and thinner than its neighbours, violet-roofed, on a green mound
    d.ellipse([(mx - 0.050 * w) * ss, (foot - 0.045 * h) * ss, (mx + 0.050 * w) * ss, (foot + 0.045 * h) * ss], fill=far((96, 170, 104), depth))
    box(mx - 0.007 * w, foot - 0.230 * h, mx + 0.007 * w, foot - 0.030 * h, far(stone, depth))
    box(mx + 0.002 * w, foot - 0.230 * h, mx + 0.007 * w, foot - 0.030 * h, far(shade, depth))
    for ring_y, ring_w in ((0.090, 0.012), (0.150, 0.011), (0.205, 0.010)):
        box(mx - ring_w * w, foot - ring_y * h, mx + ring_w * w, foot - ring_y * h + 0.008 * h, far(shade, depth))
    tri([(mx - 0.013 * w, foot - 0.230 * h), (mx + 0.013 * w, foot - 0.230 * h), (mx, foot - 0.300 * h)], far((122, 92, 190), depth))
    tri([(mx + 0.002 * w, foot - 0.230 * h), (mx + 0.013 * w, foot - 0.230 * h), (mx, foot - 0.300 * h)], far((88, 62, 150), depth))
    d.ellipse([(mx - 0.003 * w) * ss, (foot - 0.300 * h - 0.003 * w) * ss, (mx + 0.003 * w) * ss, (foot - 0.300 * h + 0.003 * w) * ss],
              fill=far(gold, depth))
    for _ in range(12):  # lesser towers of the same quarter
        tx = rng.choice([rng.uniform(0.02, 0.10), rng.uniform(0.36, 0.65), rng.uniform(0.90, 0.99)]) * w
        wide = rng.uniform(0.010, 0.016) * w
        spire(tx, foot, wide, rng.uniform(0.06, 0.13) * h, wide * rng.uniform(1.7, 2.6), depth, rng.uniform() < 0.3)
    for _ in range(70):
        house(rng.uniform(0, 1) * w, foot, rng.uniform(0.007, 0.013) * w, rng.uniform(0.016, 0.042) * h, depth, rng.uniform() < 0.75)
    trees(foot, 34, depth)
    box(0, foot - 0.004 * h, w, foot + 0.07 * h, far(stone, depth))
    settle(0.815, 0.42)

    # The outer wall, nearest and brightest: towers along it, and the great gate with its banners.
    depth = 1.0
    foot, top = 1.02 * h, 0.905 * h
    trees(top + 0.004 * h, 46, 0.9)
    wall(0, w, top, foot, depth, 0.009 * w)
    for tx in (0.035, 0.165, 0.335, 0.665, 0.835, 0.965):
        spire(tx * w, foot, 0.032 * w, foot - top + 0.050 * h, 0.066 * h, depth, tx in (0.165, 0.835))
    box(0.445 * w, top - 0.034 * h, 0.555 * w, foot, far(stone, depth))  # the gatehouse
    for side in (-1, 1):
        spire((0.5 + side * 0.062) * w, foot, 0.044 * w, foot - top + 0.090 * h, 0.092 * h, depth, True)
        bx = (0.5 + side * 0.030) * w  # a blue banner with a gold band to each side of the arch
        box(bx - 0.007 * w, top - 0.018 * h, bx + 0.007 * w, top + 0.046 * h, far((40, 92, 172), depth))
        box(bx - 0.007 * w, top + 0.006 * h, bx + 0.007 * w, top + 0.014 * h, far(gold, depth))
    d.rectangle([0.479 * w * ss, 0.936 * h * ss, 0.521 * w * ss, h * ss], fill=far((56, 84, 124), depth))  # the archway
    d.pieslice([0.479 * w * ss, (0.936 * h - 0.021 * w) * ss, 0.521 * w * ss, (0.936 * h + 0.021 * w) * ss], 180, 360,
               fill=far((56, 84, 124), depth))
    settle()

    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
    rgb = mix(rgb, (22, 150, 186), 0.08)  # a breath of the game's own blue-green over everything, no more
    edge = np.hypot((x - w / 2) / (w / 2), (y - h / 2) / (h / 2))
    rgb = rgb * np.clip(1.03 - 0.16 * edge ** 2, 0, 1.03)[..., None] + noise((w, h), 1.6, seed)
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


# ---------------------------------------------------------------------------
# The emblem: a bronze compass ring around a sea-blue disc
# ---------------------------------------------------------------------------
def tinted(fill, alpha_mask, opacity=1.0):
    """A flat colour seen through a mask."""
    if opacity != 1.0:
        alpha_mask = alpha_mask.point(lambda v: int(v * opacity))
    out = Image.new("RGBA", alpha_mask.size, tuple(fill) + (255,))
    out.putalpha(alpha_mask)
    return out


def ring_emblem(size, paint_middle, ss=3):
    """The emblem, size x size: the bronze compass ring with a stud at each quarter and a sea-blue
    disc inside it. paint_middle(img, n, c) draws what goes on the disc: n is the side of the
    oversized drawing it is given, c its middle."""
    n = size * ss
    c = n / 2
    ink = INK + (255,)
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def disc_mask(radius, cx=c, cy=c):
        m = Image.new("L", (n, n), 0)
        ImageDraw.Draw(m).ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=255)
        return m

    def shaded(top, bottom, y0, y1):
        rows = np.clip((np.arange(n, dtype=np.float32) - y0) / max(1.0, y1 - y0), 0, 1)[:, None]
        rgb = np.asarray(top, np.float32) * (1 - rows) + np.asarray(bottom, np.float32) * rows
        return Image.fromarray(np.broadcast_to(rgb[:, None, :], (n, n, 3)).astype(np.uint8), "RGB")

    # Studs first, so the ring overlaps their inner halves: a faceted diamond at each quarter
    # and a smaller one between.
    for step in range(8):
        angle = math.radians(step * 45 - 90)
        major = step % 2 == 0
        reach, half = (0.418 if major else 0.392) * n, (0.082 if major else 0.040) * n
        sx, sy = c + math.cos(angle) * reach, c + math.sin(angle) * reach
        d.polygon([(sx, sy - half), (sx + half, sy), (sx, sy + half), (sx - half, sy)], fill=ink)
        inset = half * 0.86
        top, right, bottom, left = (sx, sy - inset), (sx + inset, sy), (sx, sy + inset), (sx - inset, sy)
        d.polygon([top, (sx, sy), left], fill=(240, 214, 152, 255))     # lit from the upper left
        d.polygon([top, right, (sx, sy)], fill=(196, 160, 96, 255))
        d.polygon([left, (sx, sy), bottom], fill=(150, 112, 60, 255))
        d.polygon([(sx, sy), right, bottom], fill=(92, 66, 34, 255))

    # The ring.
    outer, inner = 0.392 * n, 0.305 * n
    band = ImageChops.subtract(disc_mask(outer), disc_mask(inner))
    img.paste(ink, mask=disc_mask(outer + 0.008 * n))
    img.paste(shaded(BRONZE_LIGHT, BRONZE_DARK, c - outer, c + outer), mask=band)
    d = ImageDraw.Draw(img)
    for radius, colour, width in ((outer - 0.016 * n, (252, 236, 190, 150), 0.006), (inner + 0.012 * n, (40, 28, 12, 170), 0.006)):
        d.ellipse([c - radius, c - radius, c + radius, c + radius], outline=colour, width=max(1, round(width * n)))
    for tick in range(48):  # the graduations of a compass card
        angle = math.radians(tick * 7.5)
        r0, r1 = (0.326 if tick % 4 == 0 else 0.336) * n, (0.370 if tick % 4 == 0 else 0.360) * n
        d.line([(c + math.cos(angle) * r0, c + math.sin(angle) * r0), (c + math.cos(angle) * r1, c + math.sin(angle) * r1)],
               fill=(52, 36, 16, 210), width=max(1, round(0.006 * n)))

    # The disc: light in its upper middle, deep at the rim, with the ring's shadow on its edge.
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    fall = np.clip(np.hypot(xx - c, yy - (c - 0.07 * n)) / (inner * 1.15), 0, 1)[..., None] ** 1.2
    sea = np.array((96, 208, 228), np.float32) * (1 - fall) + np.array((5, 58, 88), np.float32) * fall
    img.paste(ink, mask=disc_mask(inner + 0.004 * n))
    img.paste(Image.fromarray(sea.astype(np.uint8), "RGB"), mask=disc_mask(inner - 0.006 * n))
    rim = ImageChops.subtract(disc_mask(inner), disc_mask(inner - 0.045 * n)).filter(ImageFilter.GaussianBlur(0.016 * n))
    img.alpha_composite(tinted((0, 0, 0), ImageChops.multiply(rim, disc_mask(inner - 0.006 * n)), 0.55))

    paint_middle(img, n, c)
    return img.resize((size, size), Image.LANCZOS)
