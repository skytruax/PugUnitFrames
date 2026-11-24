#!/usr/bin/env python3
"""A dwarf in the forge hall of a mountain city: the backdrop of the title pictures.

    python3 tools/forge_hall.py OUT.png [WIDTH HEIGHT]

A drawing of our own of the kind of hall the game's dwarves live in: two rows of stone pillars
under round arches, a great furnace at the far end, molten metal running in channels in the floor,
and a dwarf standing in the middle of it with his hammer, seen from behind the way a player sees
a character. It is made of nothing but the shapes in this file, stands in for the game world
behind the frames, and is plainly not a screenshot.

Needs Pillow and numpy.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # the sibling module, also under python -I
import brand  # noqa: E402

SS = 2  # shapes are drawn this many times too large and brought down, which smooths their edges

GLOW = (255, 170, 72)     # the light of the furnace on whatever it reaches
MOLTEN = (255, 214, 120)  # molten metal
STONE_NEAR, STONE_FAR = (26, 17, 16), (128, 70, 38)  # a pillar close by, and one far down the hall in the haze


def mix(a, b, t):
    return tuple(a[i] * (1 - t) + b[i] * t for i in range(3))


def rgb(colour, alpha=255):
    return tuple(int(round(max(0, min(255, c)))) for c in colour) + (alpha,)


def lit(image, colour, mask, opacity=1.0):
    """Adds light of a colour where the mask is: what is under it gets brighter, not painted over."""
    box = mask.getbbox()
    if not box:
        return image
    piece = image.crop(box)
    base = np.asarray(piece.convert("RGB"), np.float32)
    amount = np.asarray(mask.crop(box), np.float32)[..., None] / 255 * opacity
    out = Image.fromarray(np.clip(base + np.asarray(colour, np.float32) * amount, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    out.putalpha(piece.getchannel("A"))
    image.paste(out, box[:2])
    return image


class Pen:
    """Draws filled shapes on a mask, so a list of shapes reads as a list of shapes."""

    def __init__(self, mask):
        self.draw = ImageDraw.Draw(mask)

    def polygon(self, points):
        self.draw.polygon(points, fill=255)

    def ellipse(self, box):
        self.draw.ellipse(box, fill=255)


def dwarf(height, rim=GLOW):
    """The dwarf from behind, `height` pixels tall, on a clear picture a little wider than tall:
    horned helm, hair and braids over the shoulders, round pauldrons, hands at his sides, the
    right one on the haft of a hammer whose head rests on the floor. He stands between us and the
    furnace, so he is dark, with its light along his upper edges and his sides."""
    u = height * SS
    w, h = round(1.40 * u), round(1.06 * u)
    cx, top = w / 2, 0.03 * u

    def P(x, y):
        return (cx + x * u, top + y * u)

    def box(x, y, rx, ry):
        return [cx + (x - rx) * u, top + (y - ry) * u, cx + (x + rx) * u, top + (y + ry) * u]

    figure = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    reach = max(2, round(0.012 * u))  # how far the light comes in over an edge

    def part(paint, colour, edge=1.0, round_off=0.010):
        """One group of shapes in one colour, its corners rounded, with the furnace's light on the
        edges that face up and out. Nothing is lit from below."""
        nonlocal figure
        mask = Image.new("L", (w, h), 0)
        paint(Pen(mask))
        if round_off:
            mask = mask.filter(ImageFilter.GaussianBlur(round_off * u)).point(lambda v: 255 if v >= 128 else 0)
        figure.alpha_composite(brand.tinted(colour, mask))
        over = ImageChops.subtract(mask, ImageChops.offset(mask, 0, reach))
        sides = ImageChops.lighter(ImageChops.subtract(mask, ImageChops.offset(mask, reach, 0)), ImageChops.subtract(mask, ImageChops.offset(mask, -reach, 0)))
        band = ImageChops.lighter(over, sides.point(lambda v: int(v * 0.72)))
        figure = lit(figure, rim, band, 0.95 * edge)
        figure = lit(figure, rim, ImageChops.multiply(band.filter(ImageFilter.GaussianBlur(0.016 * u)), mask), 0.60 * edge)

    dark, plate, cloth, hair, horn, steel = (22, 15, 15), (42, 31, 28), (34, 20, 22), (92, 42, 18), (84, 66, 52), (52, 46, 48)

    def hammer(d):
        d.polygon([P(0.440, 0.760), P(0.690, 0.760), P(0.690, 0.985), P(0.440, 0.985)])                   # the head, on the floor
        d.polygon([P(0.422, 0.790), P(0.708, 0.790), P(0.708, 0.840), P(0.422, 0.840)])                   # a band round each end of it
        d.polygon([P(0.422, 0.905), P(0.708, 0.905), P(0.708, 0.955), P(0.422, 0.955)])

    def haft(d):
        d.polygon([P(0.540, 0.770), P(0.582, 0.770), P(0.412, 0.520), P(0.370, 0.520)])                   # up through his hand
        d.ellipse(box(0.388, 0.506, 0.034, 0.034))                                                       # its pommel

    def legs(d):
        for side in (-1, 1):
            d.polygon([P(side * 0.022, 0.720), P(side * 0.180, 0.720), P(side * 0.176, 0.900), P(side * 0.026, 0.900)])
            d.polygon([P(side * 0.012, 0.875), P(side * 0.200, 0.875), P(side * 0.226, 0.985), P(side * 0.008, 0.985)])  # boot

    def body(d):
        d.polygon([P(-0.270, 0.290), P(0.270, 0.290), P(0.215, 0.640), P(-0.215, 0.640)])                 # the back
        d.polygon([P(-0.212, 0.615), P(0.212, 0.615), P(0.262, 0.800), P(-0.262, 0.800)])                 # the skirt of plates

    def back_plate(d):
        d.polygon([P(-0.165, 0.345), P(0.165, 0.345), P(0.128, 0.555), P(-0.128, 0.555)])

    def belt(d):
        d.polygon([P(-0.222, 0.585), P(0.222, 0.585), P(0.226, 0.640), P(-0.226, 0.640)])

    def arms(d):
        for side in (-1, 1):
            d.polygon([P(side * 0.258, 0.330), P(side * 0.400, 0.345), P(side * 0.438, 0.530), P(side * 0.318, 0.548)])   # upper arm
            d.polygon([P(side * 0.318, 0.520), P(side * 0.442, 0.505), P(side * 0.430, 0.660), P(side * 0.330, 0.668)])   # forearm

    def bracers(d):
        for side in (-1, 1):
            d.polygon([P(side * 0.304, 0.560), P(side * 0.452, 0.546), P(side * 0.446, 0.640), P(side * 0.312, 0.652)])
            d.ellipse(box(side * 0.380, 0.688, 0.066, 0.058))                                           # fist

    def pauldrons(d):
        for side in (-1, 1):
            d.ellipse(box(side * 0.300, 0.322, 0.132, 0.088))
            d.ellipse(box(side * 0.352, 0.392, 0.092, 0.050))

    def mane(d):
        d.ellipse(box(0, 0.300, 0.176, 0.118))
        d.ellipse(box(-0.118, 0.372, 0.088, 0.078))
        d.ellipse(box(0.118, 0.372, 0.088, 0.078))
        d.ellipse(box(0, 0.395, 0.090, 0.070))

    def braids(d):
        for side in (-1, 1):  # a braid down each side of the back, with a ring near its end
            d.polygon([P(side * 0.050, 0.400), P(side * 0.112, 0.400), P(side * 0.102, 0.560), P(side * 0.060, 0.560)])
            d.ellipse(box(side * 0.081, 0.580, 0.032, 0.032))

    def helm(d):
        d.ellipse(box(0, 0.142, 0.140, 0.126))
        d.polygon([P(-0.150, 0.150), P(0.150, 0.150), P(0.158, 0.236), P(-0.158, 0.236)])

    def helm_trim(d):
        d.polygon([P(-0.170, 0.216), P(0.170, 0.216), P(0.170, 0.256), P(-0.170, 0.256)])                 # its rim
        d.polygon([P(-0.020, 0.016), P(0.020, 0.016), P(0.024, 0.220), P(-0.024, 0.220)])                 # the ridge over the crown

    def horns(d):
        for side in (-1, 1):
            # A horn is a row of discs along a curve, growing smaller towards the tip.
            for step in range(48):
                t = step / 47
                x = 0.120 + 0.165 * t - 0.022 * t * t
                y = 0.150 - 0.030 * t - 0.128 * t * t
                r = 0.047 * (1 - t) + 0.006
                d.ellipse(box(side * x, y, r, r))

    part(hammer, steel, 0.95, 0.006)
    part(haft, (60, 40, 26), 0.9, 0.004)
    part(legs, dark, 0.55)
    part(body, cloth, 0.75)
    part(back_plate, plate, 0.30)
    part(belt, (58, 40, 26), 0.35, 0.004)
    part(arms, dark, 0.85, 0.016)
    part(bracers, plate, 0.80)
    part(pauldrons, plate, 1.0, 0.004)
    part(mane, hair, 0.85, 0.006)
    part(braids, (110, 52, 22), 0.60, 0.006)
    part(horns, horn, 1.0, 0.0)
    part(helm, plate, 1.0, 0.004)
    part(helm_trim, (58, 44, 36), 0.55, 0.003)
    return figure.resize((round(w / SS), round(h / SS)), Image.LANCZOS)


def hall(w, h, eye=0.47, figure=0.31, stand=0.985, seed=7):
    """The hall, w x h. `eye` is how far down the picture the far end of the hall lies, `figure`
    how tall the dwarf is as a share of the height (0 leaves him out), `stand` where his feet are."""
    rng = np.random.default_rng(seed)
    W, H = w * SS, h * SS
    vx, vy = W / 2, H * eye
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)

    # The air of the hall: the furnace's light at the far end, falling away to near dark.
    reach = np.hypot((x - vx) / (0.62 * W), (y - vy) / (0.80 * H))
    stops = ((0.00, (255, 206, 120)), (0.10, (236, 140, 56)), (0.30, (150, 70, 30)), (0.62, (62, 30, 20)), (1.05, (16, 10, 12)))
    air = np.zeros((H, W, 3), np.float32)
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        t = np.clip((reach - t0) / (t1 - t0), 0, 1)[..., None]
        inside = ((reach >= t0) & (reach < t1))[..., None]
        air = np.where(inside, np.asarray(c0, np.float32) * (1 - t) + np.asarray(c1, np.float32) * t, air)
    air = np.where((reach >= stops[-1][0])[..., None], np.asarray(stops[-1][1], np.float32), air)
    img = Image.fromarray(air.astype(np.uint8), "RGB").convert("RGBA")
    d = ImageDraw.Draw(img)

    def depth(i):
        """How large things are at the i-th pair of pillars: 1 at the nearest, smaller with every pair."""
        return 1 / (1 + 0.60 * i)

    def floor_y(s):
        return vy + 0.47 * H * s

    # The floor: stone flags, lit where they face the furnace and dark near us.
    far = depth(6.4)
    floor = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rows = np.clip((y - floor_y(far)) / (H - floor_y(far)), 0, 1)
    tone = np.asarray((214, 122, 54), np.float32) * (1 - rows[..., None]) ** 2.2 + np.asarray((22, 14, 14), np.float32) * (1 - (1 - rows[..., None]) ** 2.2)
    centre = np.clip(1 - np.abs(x - vx) / (0.50 * W), 0, 1)[..., None] ** 1.5   # the light runs down the middle of the floor
    tone = tone * (0.55 + 0.45 * centre)
    flags = np.dstack([tone, np.where(y >= floor_y(far), 255, 0)[..., None]]).astype(np.uint8)
    floor = Image.fromarray(flags, "RGBA")
    img.alpha_composite(floor)
    d = ImageDraw.Draw(img)
    for k in range(-14, 15):  # joints running away from us
        d.line([(vx, vy), (vx + k * 0.13 * W, H + 0.3 * H)], fill=(10, 6, 6, 70), width=max(1, SS))
    for i in np.arange(0.0, 6.5, 0.5):  # and across
        yy = floor_y(depth(i))
        d.line([(0, yy), (W, yy)], fill=(10, 6, 6, 62), width=max(1, SS))
    img.paste(Image.fromarray(air.astype(np.uint8), "RGB"), mask=Image.fromarray(np.where(y < floor_y(far), 255, 0).astype(np.uint8), "L"))

    # Molten metal in a channel along the foot of each row of pillars.
    channels = Image.new("L", (W, H), 0)
    cd = ImageDraw.Draw(channels)
    for side in (-1, 1):
        cd.polygon([(vx, vy), (vx + side * 0.300 * W * 3, vy + 0.47 * H * 3), (vx + side * 0.345 * W * 3, vy + 0.47 * H * 3)], fill=255)
    channels = ImageChops.multiply(channels, Image.fromarray(np.where(y >= floor_y(far), 255, 0).astype(np.uint8), "L"))
    img = lit(img, GLOW, channels.filter(ImageFilter.GaussianBlur(0.018 * H)), 0.55)
    img.alpha_composite(brand.tinted(MOLTEN, channels, 0.92))
    d = ImageDraw.Draw(img)

    # The furnace at the far end: a dark mass with a burning mouth, a hood running up into the roof, and an anvil before it.
    fw, fh = 0.150 * W, 0.300 * H
    d.polygon([(vx - fw * 0.46, vy - fh * 0.62), (vx + fw * 0.46, vy - fh * 0.62), (vx + fw * 0.20, 0), (vx - fw * 0.20, 0)], fill=rgb((40, 20, 14)))
    d.rounded_rectangle([vx - fw / 2, vy - fh * 0.66, vx + fw / 2, floor_y(far) + 0.004 * H], radius=fw * 0.16, fill=rgb((30, 15, 11)))
    mouth = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mouth)
    md.rounded_rectangle([vx - fw * 0.30, vy - fh * 0.30, vx + fw * 0.30, floor_y(far) - 0.002 * H], radius=fw * 0.28, fill=255)
    img.alpha_composite(brand.tinted((255, 150, 50), mouth))
    core = Image.new("L", (W, H), 0)
    ImageDraw.Draw(core).rounded_rectangle([vx - fw * 0.20, vy - fh * 0.20, vx + fw * 0.20, floor_y(far) - 0.002 * H], radius=fw * 0.19, fill=255)
    core = core.filter(ImageFilter.GaussianBlur(fw * 0.05))
    img.alpha_composite(brand.tinted((255, 244, 196), core))
    img = lit(img, GLOW, mouth.filter(ImageFilter.GaussianBlur(0.060 * H)), 0.85)
    img = lit(img, (255, 120, 40), mouth.filter(ImageFilter.GaussianBlur(0.170 * H)), 0.55)
    d = ImageDraw.Draw(img)
    aw = fw * 0.36  # the anvil, dark against the mouth
    ay = floor_y(far) + 0.004 * H
    d.polygon([(vx - aw * 0.62, ay - aw * 0.58), (vx + aw * 0.42, ay - aw * 0.58), (vx + aw * 0.42, ay - aw * 0.40), (vx + aw * 0.14, ay - aw * 0.34),
               (vx + aw * 0.20, ay - aw * 0.10), (vx + aw * 0.36, ay), (vx - aw * 0.36, ay), (vx - aw * 0.20, ay - aw * 0.10), (vx - aw * 0.14, ay - aw * 0.34),
               (vx - aw * 0.36, ay - aw * 0.40)], fill=rgb((16, 9, 8)))
    d.polygon([(vx - aw * 0.62, ay - aw * 0.58), (vx - aw * 1.02, ay - aw * 0.50), (vx - aw * 0.36, ay - aw * 0.40)], fill=rgb((16, 9, 8)))  # its horn

    # The pillars and the arches over the hall, the farthest first.
    for i in (6, 5, 4, 3, 2, 1, 0):
        s = depth(i)
        haze = min(1.0, i / 6.5) ** 0.8
        stone = mix(STONE_NEAR, STONE_FAR, haze)
        shade = mix(stone, (8, 5, 6), 0.45)
        half, reach_x = 0.085 * W * s, 0.560 * W * s
        top, foot = vy - 0.80 * H * s, floor_y(s)
        # The arch: a round band from the head of one pillar to the head of the other.
        thick = 0.060 * H * s
        ring = [vx - reach_x - half * 0.2, top - 0.36 * H * s, vx + reach_x + half * 0.2, top + 0.36 * H * s]
        d.arc(ring, 180, 360, fill=rgb(shade), width=round(thick))
        inner_ring = [ring[0] + thick * 0.86, ring[1] + thick * 0.86, ring[2] - thick * 0.86, ring[3] - thick * 0.86]
        d.arc(inner_ring, 180, 360, fill=rgb(mix(stone, GLOW, 0.20 + 0.25 * haze)), width=max(1, round(thick * 0.14)))  # its underside, lit
        for side in (-1, 1):
            px = vx + side * reach_x
            d.rectangle([px - half, top, px + half, foot], fill=rgb(stone))
            # The face turned to the furnace catches its light.
            inner = px - side * half
            d.rectangle(sorted([inner, inner + side * half * 0.34], key=float) and [min(inner, inner + side * half * 0.34), top, max(inner, inner + side * half * 0.34), foot],
                        fill=rgb(mix(stone, GLOW, 0.34 + 0.30 * haze)))
            d.rectangle([min(inner, inner + side * half * 0.07), top, max(inner, inner + side * half * 0.07), foot], fill=rgb(mix(stone, (255, 226, 160), 0.55 + 0.25 * haze)))
            for block in (0.06, 0.20):  # the head and the foot of the pillar stand out a little
                d.rectangle([px - half * 1.22, top + (foot - top) * 0.0, px + half * 1.22, top + (foot - top) * block * 0.30], fill=rgb(shade))
            d.rectangle([px - half * 1.25, foot - (foot - top) * 0.050, px + half * 1.25, foot], fill=rgb(shade))
            for course in range(1, 9):  # courses of stone
                cy = top + (foot - top) * course / 9
                d.line([(px - half, cy), (px + half, cy)], fill=rgb((8, 5, 6), 70), width=max(1, round(SS * s)))
            if i in (1, 2, 3):  # a lamp on a chain between the pillars
                lx, ly = vx + side * reach_x * 0.56, vy - 0.33 * H * s
                d.line([(lx, 0), (lx, ly)], fill=rgb((14, 9, 9)), width=max(1, round(0.004 * H * s)))
                lamp = Image.new("L", (W, H), 0)
                ImageDraw.Draw(lamp).ellipse([lx - 0.016 * H * s, ly - 0.020 * H * s, lx + 0.016 * H * s, ly + 0.020 * H * s], fill=255)
                img = lit(img, GLOW, lamp.filter(ImageFilter.GaussianBlur(0.045 * H * s)), 0.90)
                img.alpha_composite(brand.tinted((255, 232, 170), lamp))
                d = ImageDraw.Draw(img)
                d.rectangle([lx - 0.020 * H * s, ly - 0.028 * H * s, lx + 0.020 * H * s, ly - 0.020 * H * s], fill=rgb((14, 9, 9)))
                d.rectangle([lx - 0.020 * H * s, ly + 0.020 * H * s, lx + 0.020 * H * s, ly + 0.027 * H * s], fill=rgb((14, 9, 9)))

    # Sparks rising from the furnace.
    sparks = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(sparks)
    for _ in range(220):
        sx = rng.normal(vx, 0.15 * W)
        sy = vy + 0.10 * H - abs(rng.normal(0, 0.30 * H))
        r = rng.uniform(0.8, 2.6) * SS
        sd.ellipse([sx - r, sy - r, sx + r, sy + r], fill=int(rng.uniform(110, 255)))
    img = lit(img, (255, 190, 96), sparks.filter(ImageFilter.GaussianBlur(1.2 * SS)), 0.95)
    img = lit(img, (255, 150, 60), sparks.filter(ImageFilter.GaussianBlur(5.0 * SS)), 0.65)

    out = img.resize((w, h), Image.LANCZOS)

    if figure > 0:
        tall = round(h * figure)
        who = dwarf(tall)
        left, top = round(w / 2 - who.width / 2), round(h * stand - who.height * (0.985 + 0.03) / 1.06)
        # His shadow lies towards us, since the light is beyond him.
        shadow = Image.new("L", (w, h), 0)
        base = top + who.height * (0.03 + 0.985) / 1.06
        ImageDraw.Draw(shadow).polygon([(w / 2 - 0.24 * tall, base - 0.02 * tall), (w / 2 + 0.52 * tall, base - 0.02 * tall),
                                        (w / 2 + 1.25 * tall, base + 1.2 * tall), (w / 2 - 0.80 * tall, base + 1.2 * tall)], fill=255)
        out.alpha_composite(brand.tinted((4, 2, 3), shadow.filter(ImageFilter.GaussianBlur(0.035 * tall)), 0.62))
        box = (max(0, -left), max(0, -top), min(who.width, w - left), min(who.height, h - top))
        if box[2] > box[0] and box[3] > box[1]:
            out.alpha_composite(who.crop(box), (left + box[0], top + box[1]))

    # The edges of the picture fall away into the dark, and a little grain keeps the flat tones alive.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    edge = np.clip(np.hypot((xx - w / 2) / (0.78 * w), (yy - h * 0.52) / (0.86 * h)) - 0.55, 0, 1) ** 1.6
    dark = np.zeros((h, w, 4), np.float32)
    dark[..., :3] = (6, 3, 5)
    dark[..., 3] = edge * 0.80 * 255
    out.alpha_composite(Image.fromarray(dark.astype(np.uint8), "RGBA"))
    grain = np.asarray(out.convert("RGB"), np.float32) + brand.noise((w, h), 2.2, seed)
    return Image.fromarray(np.clip(grain, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


if __name__ == "__main__":
    if len(sys.argv) not in (2, 4):
        sys.exit(__doc__)
    size = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) == 4 else (1920, 1080)
    hall(*size).convert("RGB").save(sys.argv[1])
    print("wrote", sys.argv[1])
