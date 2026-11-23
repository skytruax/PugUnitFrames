#!/usr/bin/env python3
"""Draws the pictures for the CurseForge page and the README, in the look the Free addons share.

    python3 tools/make_listing.py            # all of them
    python3 tools/make_listing.py banner     # only the ones named

  curseforge/logo.png                  the project avatar: 400 x 400, as CurseForge requires
  curseforge/gallery/01-hero.png       title picture
  curseforge/gallery/02-frames.png     the five single frames
  curseforge/gallery/03-groups.png     party and raid, and what they tell you
  curseforge/gallery/04-combat.png     what keeps working in a fight
  curseforge/gallery/05-auras.png      buffs, debuffs and cast bars
  curseforge/gallery/06-looks.png      the three themes and three bar textures
  curseforge/gallery/07-arrange.png    moving frames, and the commands
  curseforge/web/*.jpg                 the same seven at 1280 x 720, a fraction of the size: what
                                       the description page loads, so it opens quickly
  docs/banner.png                      the README header
  docs/social.png                      for GitHub's Settings > Social preview
  docs/logo.png                        the emblem, for the README
  curseforge/description.html          curseforge/description.md as HTML, for the page editor's
                                       source view (needs the "markdown" package)

Every picture is an illustration built from the addon's own textures, colours and layout numbers,
and says so on the picture: the frames are drawn here the way Frame.lua lays them out, with
stand-in tiles where the game would show spell icons. Screenshots have to come from the game.

Needs Pillow and numpy. The title typeface is fetched once; see tools/brand.py.
"""
import functools
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # the sibling modules, also under python -I
import brand  # noqa: E402
import make_art  # noqa: E402

ROOT = brand.ROOT
ART = os.path.join(ROOT, "FreeUnitFrames", "Art")
OUT = os.path.join(ROOT, "curseforge")
GALLERY = os.path.join(OUT, "gallery")
DOCS = os.path.join(ROOT, "docs")

TITLE = "Free Unit Frames"
TAGLINE = "Clean, light unit frames. Your whole group at a glance."
NOTE = "Illustration built from the addon's own artwork, not a screenshot."

# ---------------------------------------------------------------------------
# The addon's look, as Style.lua and Defaults.lua have it (theme Slate)
# ---------------------------------------------------------------------------
# name -> back, edge, trough, text, quiet (0-255), tone: the three themes of Style.lua
THEMES = {
    "Slate": dict(back=(13, 15, 18, 230), edge=(0, 0, 0, 255), trough=(36, 38, 43, 255), text=(242, 242, 237, 255),
                  quiet=(161, 168, 176, 255), tone=0.84),
    "Night": dict(back=(8, 10, 20, 235), edge=(3, 3, 8, 255), trough=(23, 28, 46, 255), text=(230, 237, 255, 255),
                  quiet=(140, 158, 199, 255), tone=0.78),
    "Hearth": dict(back=(26, 18, 13, 230), edge=(5, 3, 0, 255), trough=(51, 38, 28, 255), text=(255, 245, 224, 255),
                   quiet=(199, 173, 138, 255), tone=0.92),
}
SLATE = THEMES["Slate"]
TEXT, QUIET = SLATE["text"], SLATE["quiet"]

CLASS = {
    "WARRIOR": (0.78, 0.61, 0.43), "PALADIN": (0.96, 0.55, 0.73), "HUNTER": (0.67, 0.83, 0.45),
    "ROGUE": (1.00, 0.96, 0.41), "PRIEST": (1.00, 1.00, 1.00), "SHAMAN": (0.00, 0.44, 0.87),
    "MAGE": (0.25, 0.78, 0.92), "WARLOCK": (0.53, 0.53, 0.93), "DRUID": (1.00, 0.49, 0.04),
}
POWER = {"MANA": (0.27, 0.53, 0.93), "RAGE": (0.83, 0.24, 0.22), "ENERGY": (0.94, 0.82, 0.31), "FOCUS": (0.92, 0.56, 0.27)}
HOSTILE = (0.84, 0.29, 0.24)
CAST = (0.93, 0.74, 0.28)
HEAL = (0.45, 0.92, 0.55)
THREAT = (0.90, 0.22, 0.18)
KIND = {"magic": (0.27, 0.58, 0.98), "curse": (0.66, 0.31, 0.92), "disease": (0.72, 0.52, 0.20), "poison": (0.27, 0.78, 0.33), "none": (0.72, 0.16, 0.14)}


def toned(colour, tone=SLATE["tone"]):
    return tuple(round(255 * channel * tone) for channel in colour)


@functools.lru_cache(maxsize=None)
def art(name):
    return Image.open(os.path.join(ART, name + ".tga")).convert("RGBA")


def bar_fill(width, height, colour, alpha=255, texture="Bar-Smooth"):
    """A piece of one of the addon's bar textures at this size, in this colour (0-255 per channel)."""
    width, height = max(1, round(width)), max(1, round(height))
    grey = np.asarray(art(texture).convert("L").resize((width, height), Image.BILINEAR), np.float32) / 255
    rgba = np.empty((height, width, 4), np.float32)
    rgba[..., :3] = grey[..., None] * np.asarray(colour, np.float32)
    rgba[..., 3] = alpha
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def rect(canvas, x0, y0, x1, y1, fill):
    x0, y0, x1, y1 = round(x0), round(y0), round(x1), round(y1)
    if x1 > x0 and y1 > y0:
        canvas.alpha_composite(Image.new("RGBA", (x1 - x0, y1 - y0), fill), (x0, y0))


def label(canvas, xy, string, size, fill=TEXT, weight="Bold", anchor="lm"):
    """Text with the soft one-pixel shadow the addon gives its lettering."""
    offset = max(1, round(size * 0.09))
    draw = ImageDraw.Draw(canvas)
    font = brand.font(size, weight)
    draw.text((xy[0] + offset, xy[1] + offset), string, font=font, fill=(0, 0, 0, 230), anchor=anchor)
    draw.text(xy, string, font=font, fill=fill, anchor=anchor)


def tile(size, hue, rim=None):
    """A stand-in for a spell icon: a shaded tile with a pale mark, rimmed like the addon's icons
    (dark for a buff, in the colour of its kind for a debuff)."""
    size = max(4, round(size))
    pixel = max(1, round(size / 20))
    out = Image.new("RGBA", (size, size), toned(rim) + (255,) if rim else SLATE["edge"])
    inner = size - 2 * pixel
    top = tuple(min(255, round(255 * c * 0.95 + 20)) for c in hue)
    bottom = tuple(round(255 * c * 0.42) for c in hue)
    out.paste(brand.vertical((inner, inner), top, bottom), (pixel, pixel))
    draw = ImageDraw.Draw(out)
    middle, reach = size / 2, inner * 0.24
    draw.polygon([(middle, middle - reach), (middle + reach, middle), (middle, middle + reach), (middle - reach, middle)],
                 fill=(255, 255, 255, 190))
    return out


# ---------------------------------------------------------------------------
# One unit frame, laid out as Frame.lua and the elements lay it out
# ---------------------------------------------------------------------------
def frame(canvas, left, top, k, width, height, power_height, name, colour, share, power=None, power_share=1.0,
          level=None, right=None, sub=None, leader=False, dead=False, faded=False, heal=0.0, threat=False,
          cast=None, cast_height=16, auras=(), aura_size=20, aura_side="right", narrow=False, font_size=11,
          theme=SLATE, texture="Bar-Smooth", lit=None, shield=False, points=0, mark=None):
    """Draws a frame with its top left corner at (left, top). k is how many picture pixels one
    of the addon's units takes. Returns the frame's bottom edge in the picture."""
    px = max(1, round(k))  # the one-pixel edge
    w, h = round(width * k), round(height * k)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    BACK, EDGE, TROUGH, TEXT, QUIET, tone = theme["back"], theme["edge"], theme["trough"], theme["text"], theme["quiet"], theme["tone"]

    def toned(colour):
        return tuple(round(255 * channel * tone) for channel in colour)

    def bar_fill(width, height, colour, alpha=255):
        return globals()["bar_fill"](width, height, colour, alpha, texture)

    if threat:  # the outline lies under the plate and shows two pixels past it
        rect(layer, left - 2 * px, top - 2 * px, left + w + 2 * px, top + h + 2 * px, toned(THREAT) + (255,))
    rect(layer, left, top, left + w, top + h, BACK)
    for x0, y0, x1, y1 in ((left, top, left + w, top + px), (left, top + h - px, left + w, top + h),
                           (left, top, left + px, top + h), (left + w - px, top, left + w, top + h)):
        rect(layer, x0, y0, x1, y1, EDGE)

    power_h = round(power_height * k)
    bar_left, bar_right = left + px, left + w - px
    health_top = top + px
    health_bottom = top + h - (power_h + 2 * px if power_h > 0 else px)
    bar_w = bar_right - bar_left
    rect(layer, bar_left, health_top, bar_right, health_bottom, TROUGH)
    shown = 0.0 if dead else share
    if shown > 0:
        layer.alpha_composite(bar_fill(bar_w * shown, health_bottom - health_top, toned(colour)), (bar_left, health_top))
    if heal > 0 and not dead:
        reach = min(heal, 1 - shown)
        if reach > 0:
            layer.alpha_composite(bar_fill(bar_w * reach, health_bottom - health_top, tuple(round(255 * c) for c in HEAL), 140),
                                  (bar_left + round(bar_w * shown), health_top))
    if power_h > 0:
        rect(layer, bar_left, top + h - px - power_h, bar_right, top + h - px, TROUGH)
        if power and power_share > 0:
            layer.alpha_composite(bar_fill(bar_w * power_share, power_h, toned(POWER[power])), (bar_left, top + h - px - power_h))

    middle = (health_top + health_bottom) / 2
    size, pad = font_size * k, 4 * k
    if narrow:
        if right:
            label(layer, (left + w / 2, middle - size * 0.55), name, size, TEXT, anchor="mm")
            label(layer, (left + w / 2, middle + size * 0.6), right, size * 0.9, TEXT, anchor="mm")
        else:
            label(layer, (left + w / 2, middle), name, size, TEXT, anchor="mm")
    else:
        x = bar_left + pad
        if level:
            label(layer, (x, middle), level, size, TEXT)
            x += ImageDraw.Draw(layer).textlength(level, font=brand.font(size)) + 3 * k
        label(layer, (x, middle), name, size, TEXT)
        if right and sub:
            label(layer, (bar_right - pad, middle - size * 0.5), right, size, TEXT, anchor="rm")
            label(layer, (bar_right - pad, middle + size * 0.62), sub, size * 0.82, QUIET, "SemiBold", "rm")
        elif right:
            label(layer, (bar_right - pad, middle), right, size, TEXT, anchor="rm")

    if lit:  # a debuff the player can remove: its colour along the rim, two pixels wide
        glow = toned(KIND[lit]) + (255,)
        for x0, y0, x1, y1 in ((left, top, left + w, top + 2 * px), (left, top + h - 2 * px, left + w, top + h),
                               (left, top, left + 2 * px, top + h), (left + w - 2 * px, top, left + w, top + h)):
            rect(layer, x0, y0, x1, y1, glow)
    if mark:  # resting, in combat, ready, ...: one of the addon's own marks, in the middle or on the rim
        which, where = mark
        size_px = round(max(12, min(22, height * 0.5)) * k)
        picture = art("Mark-" + which).resize((size_px, size_px), Image.LANCZOS)
        if where == "center":
            layer.alpha_composite(picture, (round(left + w / 2 - size_px / 2), round(top + h / 2 - size_px / 2)))
        else:
            small = round(size_px * 0.72)
            layer.alpha_composite(picture.resize((small, small), Image.LANCZOS), (round(left), round(top + h - small / 2)))

    if leader:
        mark = round(max(10, min(16, height * 0.36)) * k)
        layer.alpha_composite(art("Mark-Leader").resize((mark, mark), Image.LANCZOS), (round(left), round(top - mark / 2)))

    bottom = top + h
    if cast:
        spell, done, hue = cast
        cast_h = round(cast_height * k)
        cast_top = bottom + round(3 * k)
        rect(layer, left, cast_top, left + w, cast_top + cast_h, BACK)
        for x0, y0, x1, y1 in ((left, cast_top, left + w, cast_top + px), (left, cast_top + cast_h - px, left + w, cast_top + cast_h),
                               (left, cast_top, left + px, cast_top + cast_h), (left + w - px, cast_top, left + w, cast_top + cast_h)):
            rect(layer, x0, y0, x1, y1, EDGE)
        square = cast_h - 2 * px
        layer.alpha_composite(tile(square, hue), (left + px, cast_top + px))
        cast_left = left + px + square + px
        cast_w = left + w - px - cast_left
        layer.alpha_composite(bar_fill(cast_w * done, square, toned(CAST)), (cast_left, cast_top + px))
        label(layer, (cast_left + 4 * k, cast_top + cast_h / 2), spell, (font_size - 1) * k, TEXT)
        if shield:
            layer.alpha_composite(art("Mark-Shield").resize((square, square), Image.LANCZOS), (left + w - px - square - round(2 * k), cast_top + px))
        bottom = cast_top + cast_h
    if points:  # combo points: five pips under the plate, some of them filled
        pip_h, gap = round(5 * k), round(2 * k)
        pip_top = bottom + round(3 * k)
        pip_w = (w - gap * 4) / 5
        for index in range(5):
            x0 = left + round(index * (pip_w + gap))
            rect(layer, x0, pip_top, x0 + round(pip_w), pip_top + pip_h, BACK)
            if index < points:
                layer.alpha_composite(bar_fill(pip_w, pip_h, (245, 199, 64)), (x0, pip_top))
        bottom = pip_top + pip_h

    step = round((aura_size + 2) * k)
    for index, (hue, kind) in enumerate(auras):
        icon = tile(aura_size * k, hue, KIND[kind] if kind else None)
        if aura_side == "right":
            layer.alpha_composite(icon, (left + w + round(4 * k) + index * step, top))
        elif aura_side == "above":
            layer.alpha_composite(icon, (left + index * step, top - round(3 * k) - icon.height))
        else:  # inside: from the bottom right corner of the health bar, towards the left
            layer.alpha_composite(icon, (bar_right - px - (index + 1) * (icon.width + px) + px, health_bottom - px - icon.height))

    if faded:  # out of range
        alpha = layer.getchannel("A").point(lambda v: int(v * 0.45))
        layer.putalpha(alpha)
    canvas.alpha_composite(layer)
    return bottom


# ---------------------------------------------------------------------------
# The stage: a party, the player, a target, and a corner of a raid
# ---------------------------------------------------------------------------
FIRE, FROST, NATURE, HOLY, SHADOW = (0.95, 0.45, 0.20), (0.35, 0.65, 0.95), (0.40, 0.75, 0.35), (0.95, 0.85, 0.45), (0.55, 0.35, 0.80)

PARTY = [
    dict(name="Thryn", colour=CLASS["WARRIOR"], share=0.64, power="RAGE", power_share=0.45, right="64%", threat=True,
         auras=[(SHADOW, "curse")]),
    dict(name="Lioren", colour=CLASS["PRIEST"], share=1.0, power="MANA", power_share=0.72, right="100%"),
    dict(name="Maeve", colour=CLASS["MAGE"], share=0.38, power="MANA", power_share=0.30, right="38%", heal=0.30,
         auras=[(NATURE, "poison"), (FROST, "magic")]),
    dict(name="Brask", colour=CLASS["HUNTER"], share=0.86, power="MANA", power_share=0.90, right="86%", faded=True),
]

RAID = [
    ("Thryn", "WARRIOR", 0.64), ("Lioren", "PRIEST", 1.0), ("Maeve", "MAGE", 0.38), ("Brask", "HUNTER", 0.86), ("Odda", "SHAMAN", 0.92),
    ("Wren", "DRUID", 1.0), ("Sable", "ROGUE", 0.71), ("Ivo", "WARLOCK", 0.0), ("Halla", "PALADIN", 0.55), ("Cade", "WARRIOR", 1.0),
    ("Tamsin", "PRIEST", 0.9), ("Rook", "HUNTER", 1.0), ("Eira", "MAGE", 0.47), ("Bram", "SHAMAN", 1.0), ("Nell", "DRUID", 0.8),
]


def stage(canvas, cx, cy, k):
    """Draws the frames around (cx, cy): the party on the left, the player and the target in the
    middle, three columns of raid frames on the right."""
    def at(x, y):
        return round(cx + x * k), round(cy + y * k)

    # Party: four frames of 172 x 40, twelve apart.
    for index, member in enumerate(PARTY):
        left, top = at(-590, -98 + index * 52)
        frame(canvas, left, top, k, 172, 40, 6, **member)

    # Player, with a cast under way; the target beside it with its buffs and debuffs above.
    left, top = at(-330, -34)
    frame(canvas, left, top, k, 232, 46, 9, "Halla", CLASS["PALADIN"], 0.71, "MANA", 0.58, level="60", right="3,550  71%", sub="2,310",
          leader=True, cast=("Holy Light", 0.62, HOLY))
    left, top = at(-74, -34)
    frame(canvas, left, top, k, 232, 46, 9, "Hogger", HOSTILE, 0.42, "RAGE", 0.35, level="11+", right="279  42%", sub="35",
          auras=[(FIRE, "none"), (SHADOW, "curse"), (NATURE, "poison"), (FROST, "magic")], aura_size=22, aura_side="above")

    # Raid: narrow frames of 82 x 40, five to a column.
    for index, (name, cls, share) in enumerate(RAID):
        column, row = divmod(index, 5)
        left, top = at(200 + column * 88, -98 + row * 44)
        frame(canvas, left, top, k, 82, 40, 3, name, CLASS[cls], share, "MANA", 1.0, dead=share == 0, narrow=True,
              right="Dead" if share == 0 else None, font_size=10,
              auras=[(FROST, "magic")] if name == "Eira" else (), aura_size=15, aura_side="inside",
              threat=name == "Halla", faded=name in ("Rook", "Bram"))


# ---------------------------------------------------------------------------
# Emblem and title pictures
# ---------------------------------------------------------------------------
W, H = 1920, 1080


@functools.lru_cache(maxsize=None)
def logo(size=400):
    return make_art.emblem(size)


def hero(w=W, h=H, k=2.0, title_y=128, title_size=150, tagline_size=46, stage_y=500, note_size=18, city=0.70):
    """The title, the frames in open sky, and the city along the bottom. `city` is how much of
    the picture's height the drawn scene takes; the rest, above it, is more of its sky."""
    scene = brand.landscape(w, round(h * city))
    gap = h - scene.height
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    if gap > 0:
        # Carry the scene's top edge upward, smoothed sideways so its grain does not streak, and
        # a little deeper towards the top of the picture.
        strip = scene.convert("RGB").crop((0, 0, w, 8)).resize((max(2, w // 48), 1), Image.BOX).resize((w, 1), Image.BICUBIC)
        sky = np.asarray(strip.resize((w, gap), Image.NEAREST)).astype(np.float32)
        deepen = np.linspace(0.84, 1.0, gap, dtype=np.float32)[:, None, None]
        sky = sky * deepen + brand.noise((w, gap), 1.6, 5)
        canvas.paste(Image.fromarray(np.clip(sky, 0, 255).astype(np.uint8), "RGB"), (0, 0))
    canvas.alpha_composite(scene, (0, gap))

    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    shade = np.clip(1 - np.hypot((x - w / 2) / (0.66 * w), (y - stage_y) / (0.42 * h)), 0, 1) ** 1.2 * 0.40
    scrim = np.zeros((h, w, 4), np.float32)
    scrim[..., :3] = (8, 30, 70)
    scrim[..., 3] = shade * 255
    canvas.alpha_composite(Image.fromarray(scrim.astype(np.uint8), "RGBA"))  # keeps the frames readable
    foot = np.zeros((h, w, 4), np.float32)  # and a darker strip along the bottom, for the small print
    foot[..., :3] = (8, 30, 70)
    foot[..., 3] = np.clip((y - (h - 0.13 * h)) / (0.13 * h), 0, 1) ** 1.4 * 0.80 * 255
    canvas.alpha_composite(Image.fromarray(foot.astype(np.uint8), "RGBA"))

    stage(canvas, w / 2 + 62 * k, stage_y, k)
    brand.title_text(canvas, (w / 2, title_y), TITLE, title_size * 1.22)
    brand.shadow_text(canvas, (w / 2, title_y + title_size * 0.76), TAGLINE, tagline_size, (238, 240, 248, 255), "SemiBold", spread=7)
    brand.shadow_text(canvas, (w / 2, h - 26), NOTE, note_size, (206, 210, 224, 255), "Medium", spread=4, strength=0.9)
    return canvas


def gallery_hero():
    return hero()


def banner():
    return hero(1600, 600, 1.22, 74, 92, 29, 352, note_size=15, city=0.56)


def social():
    return hero(1280, 640, 1.0, 84, 100, 28, 372, note_size=14, city=0.56)


# ---------------------------------------------------------------------------
# Feature pictures: a dark slide with the emblem, a headline, and the frames
# ---------------------------------------------------------------------------
WHITE, SOFT, DIM, GOLD = brand.WHITE, brand.SOFT, brand.DIM, brand.GOLD


def slide(parts, sub, glows=()):
    canvas = brand.backdrop(W, H, glows)
    canvas.alpha_composite(logo().resize((56, 56), Image.LANCZOS), (72, 50))
    brand.text(canvas, (142, 79), TITLE, 30, WHITE, "Bold", "lm")
    brand.headline(canvas, W / 2, 196, parts, 84)
    brand.text(canvas, (W / 2, 278), sub, 32, SOFT, "Medium")
    brand.text(canvas, (W / 2, H - 34), NOTE, 20, DIM, "Medium")
    return canvas


def caption(canvas, cx, y, title, sub=None, size=29):
    brand.text(canvas, (cx, y), title, size, WHITE, "Bold")
    if sub:
        brand.text(canvas, (cx, y + size * 1.3), sub, size * 0.76, SOFT, "Medium")


def frames():
    canvas = slide([("Seven frames, ", WHITE), ("yours to arrange.", GOLD)],
                   "Player, target, target of target, focus, pet, party and raid. Switch each off, size it, scale it, move it.")
    k = 2.25
    gap, wide_gap = 28, 56
    # The five single frames, in the order they start out across the screen.
    total = (124 + 232 + 232 + 124) * k + 2 * gap + wide_gap
    row = 640
    left = round((W - total) / 2)
    frame(canvas, left, row + round(18 * k), k, 124, 28, 4, "Ember", (0.35, 0.74, 0.38), 0.9, "FOCUS", 0.7)
    caption(canvas, left + 124 * k / 2, row + 150, "Pet")
    left += round(124 * k) + gap
    frame(canvas, left, row, k, 232, 46, 9, "Halla", CLASS["PALADIN"], 0.71, "MANA", 0.58, level="60", right="3,550  71%", sub="2,310",
          leader=True, cast=("Holy Light", 0.62, HOLY))
    caption(canvas, left + 232 * k / 2, row + 200, "Player", "with its cast bar")
    player_left = left
    left += round(232 * k) + wide_gap
    frame(canvas, left, row, k, 232, 46, 9, "Hogger", HOSTILE, 0.42, "RAGE", 0.35, level="11+", right="279  42%", sub="35",
          auras=[(FIRE, "none"), (SHADOW, "curse"), (NATURE, "poison"), (FROST, "magic"), (HOLY, None), (FROST, None)],
          aura_size=22, aura_side="above", points=3)
    caption(canvas, left + 232 * k / 2, row + 200, "Target", "buffs, debuffs, combo points")
    left += round(232 * k) + gap
    frame(canvas, left, row + round(18 * k), k, 124, 28, 4, "Halla", CLASS["PALADIN"], 0.71, "MANA", 0.58, right="71%")
    caption(canvas, left + 124 * k / 2, row + 150, "Target of target")
    focus_left, focus_top = player_left + round(29 * k), row - round(104 * k)
    frame(canvas, focus_left, focus_top, k, 174, 34, 6, "Maeve", CLASS["MAGE"], 0.38, "MANA", 0.30,
          right="38%", cast=("Frostbolt", 0.35, FROST), cast_height=12)
    caption(canvas, focus_left + round(174 * k) + 130, focus_top + 26, "Focus", "its own cast bar")
    return canvas


def groups():
    canvas = slide([("Your group, ", WHITE), ("at a glance.", GOLD)],
                   "Party and raid frames tell you who is hurt, who is being hit, who is out of reach, and whom you can help.")
    k = 2.2
    left, top = 130, 384
    notes = [
        ("An outline on whoever is being attacked", dict(threat=True)),
        ("Healing on its way, past the end of the bar", dict(heal=0.28)),
        ("Lit in the colour of a debuff you can remove", dict(lit="poison", auras=[(NATURE, "poison")])),
        ("Faded when out of range", dict(faded=True)),
    ]
    members = [("Thryn", "WARRIOR", 0.64, "RAGE", 0.45), ("Lioren", "PRIEST", 0.55, "MANA", 0.72),
               ("Maeve", "MAGE", 0.80, "MANA", 0.30), ("Brask", "HUNTER", 0.86, "MANA", 0.90)]
    for index, ((name, cls, share, power, power_share), (note_text, extra)) in enumerate(zip(members, notes)):
        y = top + index * round(52 * k)
        frame(canvas, left, y, k, 172, 40, 6, name, CLASS[cls], share, power, power_share, right="%d%%" % round(share * 100), **extra)
        brand.text(canvas, (left + round(172 * k) + 86, y + 40 * k / 2), note_text, 26, SOFT, "Medium", "lm")

    # A raid of twenty, five to a column.
    raid_left, raid_top, rk = 1262, 384, 1.66
    names = ["Thryn", "Lioren", "Maeve", "Brask", "Odda", "Wren", "Sable", "Ivo", "Halla", "Cade",
             "Tamsin", "Rook", "Eira", "Bram", "Nell", "Garr", "Pia", "Dov", "Sten", "Yara"]
    classes = ["WARRIOR", "PRIEST", "MAGE", "HUNTER", "SHAMAN", "DRUID", "ROGUE", "WARLOCK", "PALADIN", "WARRIOR",
               "PRIEST", "HUNTER", "MAGE", "SHAMAN", "DRUID", "ROGUE", "PALADIN", "WARLOCK", "WARRIOR", "MAGE"]
    shares = [0.64, 1.0, 0.38, 0.86, 0.92, 1.0, 0.71, 0.0, 0.55, 1.0, 0.9, 1.0, 0.47, 1.0, 0.8, 0.95, 1.0, 0.6, 1.0, 0.88]
    for index, (name, cls, share) in enumerate(zip(names, classes, shares)):
        column, row = divmod(index, 5)
        frame(canvas, raid_left + round(column * 88 * rk), raid_top + round(row * 44 * rk), rk, 82, 40, 3, name, CLASS[cls], share,
              "MANA", 1.0, dead=share == 0, narrow=True, right="Dead" if share == 0 else None, font_size=10,
              threat=name == "Halla", faded=name in ("Rook", "Bram"), lit="magic" if name == "Eira" else None,
              auras=[(FROST, "magic")] if name == "Eira" else (), aura_size=15, aura_side="inside",
              mark=("Ready", "center") if name in ("Wren", "Cade") else None)
    caption(canvas, raid_left + 4 * 88 * rk / 2, raid_top + round(5 * 44 * rk) + 30, "Raid frames for 10, 20 or 40",
            "larger in a small raid", 27)
    return canvas


def combat():
    canvas = slide([("Built for ", WHITE), ("how Forever fights.", GOLD)],
                   "In a fight the game seals health, names, casts and auras from addons. These frames are written around that.")
    k = 2.7
    left, top = round(W / 2 - 232 * k / 2), 470
    frame(canvas, left, top, k, 232, 46, 9, "Hogger", HOSTILE, 0.42, "RAGE", 0.35, level="11+", right="279  42%", sub="35",
          auras=[(FIRE, "none"), (SHADOW, "curse"), (NATURE, "poison"), (FROST, "magic")], aura_size=22, aura_side="above",
          cast=("Enrage", 0.48, FIRE), shield=True, threat=True)
    points = [
        (left - 330, top - 40, "Health and names", "drawn by the game itself"),
        (left + round(232 * k) + 330, top - 40, "Debuffs by kind", "magic, curse, disease, poison"),
        (left - 330, top + 190, "Threat and range", "shown without being read"),
        (left + round(232 * k) + 330, top + 190, "Cast bars", "with a shield when you cannot interrupt"),
    ]
    for x, y, title, sub in points:
        caption(canvas, x, y, title, sub, 30)
    brand.pills(canvas, W / 2, 900, ["Keeps drawing in the middle of a fight", "A late joiner gets a frame at once",
                                     "No libraries, no borrowed code"], 28, 62)
    return canvas


def auras():
    canvas = slide([("Buffs, debuffs ", WHITE), ("and cast bars.", GOLD)],
                   "Icons with time left and stacks, rimmed in the colour of their kind. Above, below, beside, or on the frame.")
    kinds = [("magic", "Magic", FROST), ("curse", "Curse", SHADOW), ("disease", "Disease", (0.72, 0.52, 0.2)), ("poison", "Poison", NATURE),
             ("none", "Other", FIRE)]
    size, step = 112, 230
    x0 = W / 2 - ((len(kinds) - 1) * step + size) / 2
    for index, (kind, name, hue) in enumerate(kinds):
        x = round(x0 + index * step)
        canvas.alpha_composite(tile(size, hue, KIND[kind]), (x, 366))
        caption(canvas, x + size / 2, 520, name, None, 28)
    k = 2.3
    gap = 150
    left = round(W / 2 - 232 * k - gap / 2)
    frame(canvas, left, 640, k, 232, 46, 9, "Halla", CLASS["PALADIN"], 0.71, "MANA", 0.58, level="60", right="71%",
          cast=("Holy Light", 0.62, HOLY))
    caption(canvas, left + 232 * k / 2, 860, "A cast fills, a channel drains", "and an interrupted one flashes red")
    left += round(232 * k) + gap
    frame(canvas, left, 640, k, 232, 46, 9, "Hogger", HOSTILE, 0.42, "RAGE", 0.35, level="11+", right="42%",
          cast=("Enrage", 0.4, FIRE), shield=True)
    caption(canvas, left + 232 * k / 2, 860, "A shield when it cannot be interrupted")
    return canvas


def looks():
    canvas = slide([("Three looks. ", WHITE), ("Three textures.", GOLD)],
                   "Slate, Night and Hearth, with smooth, flat or glass bars: all drawn for this addon. Colour by class, by foe, or by health.")
    k = 2.2
    textures = [("Bar-Smooth", "Smooth"), ("Bar-Flat", "Flat"), ("Bar-Glass", "Glass")]
    column_w = round(232 * k) + 64
    x0 = 200  # room on the left for the names of the textures
    for column, (theme_name, theme) in enumerate(THEMES.items()):
        x = x0 + column * column_w
        caption(canvas, x + 232 * k / 2, 376, theme_name, None, 34)
        for row, (texture, texture_name) in enumerate(textures):
            y = 440 + row * round(64 * k)
            cls, name, share = [("PALADIN", "Halla", 0.71), ("SHAMAN", "Odda", 0.86), ("DRUID", "Wren", 0.48)][row]
            frame(canvas, x, y, k, 232, 46, 9, name, CLASS[cls], share, "MANA", 0.58, level="60", right="%d%%" % round(share * 100),
                  theme=theme, texture=texture)
            if column == 0:
                brand.text(canvas, (x - 28, y + 46 * k / 2), texture_name, 26, SOFT, "Medium", "rm")
    return canvas


def arrange():
    canvas = slide([("Unlock, drag, ", WHITE), ("done.", GOLD)],
                   "A green handle appears on every frame. Sizes, colours, texts and icons are in the options, frame by frame.")
    # The handles where the frames start out (Defaults.lua), as /freeuf unlock shows them:
    # name, x and y from the middle of the screen, width, height, and whether x and y are a corner.
    places = [("Party", -620, 160, 172, 4 * 40 + 3 * 12, True), ("Focus", -319, -130, 174, 34, False),
              ("Player", -290, -210, 232, 46, False), ("Pet", -476, -219, 124, 28, False),
              ("Target", 290, -210, 232, 46, False), ("Target of target", 476, -219, 124, 28, False)]
    scale, middle_x, middle_y = 1.18, W / 2 + 48, 512
    for name, x, y, width, height, corner in places:
        w, h = round(width * scale), round(height * scale)
        left = round(middle_x + x * scale - (0 if corner else w / 2))
        top = round(middle_y - y * scale - (0 if corner else h / 2))
        canvas.alpha_composite(Image.new("RGBA", (w, h), (64, 178, 128, 90)), (left, top))
        ImageDraw.Draw(canvas).rectangle([left, top, left + w - 1, top + h - 1], outline=(115, 242, 178, 230), width=2)
        brand.text(canvas, (left + w / 2, top + h / 2), name, 22 if w > 200 else 16, (255, 214, 96, 255), "Bold")
    commands = [("/freeuf", "open the options"), ("/freeuf unlock", "show the handles"), ("/freeuf reset target", "put a frame back"),
                ("/freeuf profile", "copy your settings out, or paste a set in"), ("/freeuf status", "version and any errors")]
    for index, (command, what) in enumerate(commands[:3]):
        x = 300 + index * 520
        brand.text(canvas, (x, 850), command, 30, WHITE, "Bold", "lm")
        brand.text(canvas, (x, 890), what, 24, SOFT, "Medium", "lm")
    for index, (command, what) in enumerate(commands[3:]):
        x = 300 + index * 780
        brand.text(canvas, (x, 950), command, 30, WHITE, "Bold", "lm")
        brand.text(canvas, (x, 990), what, 24, SOFT, "Medium", "lm")
    return canvas


# ---------------------------------------------------------------------------
# The description page
# ---------------------------------------------------------------------------
WEB = os.path.join(OUT, "web")


def description_html():
    """The listing text as HTML: CurseForge's editor takes HTML in its source view, not Markdown."""
    import markdown  # only this output needs it

    with open(os.path.join(OUT, "description.md"), encoding="utf-8") as handle:
        return markdown.markdown(handle.read(), extensions=["sane_lists"]) + "\n"


def web_copy(path):
    """Writes the 1280 x 720 JPEG copy of one gallery picture and returns where it went. The
    colour is kept at full resolution so the lettering stays crisp."""
    os.makedirs(WEB, exist_ok=True)
    out = os.path.join(WEB, os.path.splitext(os.path.basename(path))[0] + ".jpg")
    Image.open(path).convert("RGB").resize((1280, 720), Image.LANCZOS).save(out, quality=88, subsampling=0, optimize=True)
    return out


def web_copies():
    """The web copy of every gallery picture there is, without drawing any of them again."""
    return [web_copy(os.path.join(GALLERY, name)) for name in sorted(os.listdir(GALLERY)) if name.endswith(".png")]


PICTURES = {
    "logo": (lambda: logo(400), os.path.join(OUT, "logo.png")),
    "readme-logo": (lambda: logo(256), os.path.join(DOCS, "logo.png")),
    "hero": (gallery_hero, os.path.join(GALLERY, "01-hero.png")),
    "frames": (frames, os.path.join(GALLERY, "02-frames.png")),
    "groups": (groups, os.path.join(GALLERY, "03-groups.png")),
    "combat": (combat, os.path.join(GALLERY, "04-combat.png")),
    "auras": (auras, os.path.join(GALLERY, "05-auras.png")),
    "looks": (looks, os.path.join(GALLERY, "06-looks.png")),
    "arrange": (arrange, os.path.join(GALLERY, "07-arrange.png")),
    "banner": (banner, os.path.join(DOCS, "banner.png")),
    "social": (social, os.path.join(DOCS, "social.png")),
    "web": (web_copies, WEB),
    "description": (description_html, os.path.join(OUT, "description.html")),
}


def main():
    wanted = sys.argv[1:] or list(PICTURES)
    for name in wanted:
        if name not in PICTURES:
            raise SystemExit("no picture called %r; there are: %s" % (name, ", ".join(PICTURES)))
        make, path = PICTURES[name]
        os.makedirs(GALLERY, exist_ok=True)
        os.makedirs(DOCS, exist_ok=True)
        result = make()
        if name == "web":
            for copy in result:
                print("wrote %s (%d KB)" % (os.path.relpath(copy, ROOT), os.path.getsize(copy) // 1024))
        elif name == "description":
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(result)
            print("wrote", os.path.relpath(path, ROOT))
        else:
            result.save(path)
            print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
