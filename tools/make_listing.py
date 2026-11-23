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
  curseforge/gallery/08-logo.png       the emblem and the name, large
  curseforge/web/*.jpg                 the same eight at 1280 x 720, a fraction of the size: what
                                       the description page loads, so it opens quickly
  docs/banner.png                      the README header
  docs/social.png                      for GitHub's Settings > Social preview
  docs/logo.png                        the emblem, for the README
  curseforge/description.html          curseforge/description.md as HTML, for the page editor's
                                       source view (needs the "markdown" package)

    python3 tools/make_listing.py --placeholders   # with drawn stand-ins for the spell icons

Every picture is an illustration built from the addon's own textures, colours and layout numbers,
and says so on the picture: the frames are drawn here the way Frame.lua lays them out. The spell
icons and raid marks on them are the game's own, as they are in the game, where the addon hands
whatever icon the game names straight back to the game to draw. Those are Blizzard's: they are
fetched by tools/game_icons.py when the pictures are built and credited on each picture.
Screenshots have to come from the game.

Needs Pillow and numpy. The title typeface is fetched once; see tools/brand.py.
"""
import functools
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # the sibling modules, also under python -I
import brand  # noqa: E402
import game_icons  # noqa: E402
import make_art  # noqa: E402

ROOT = brand.ROOT
ART = os.path.join(ROOT, "FreeUnitFrames", "Art")
OUT = os.path.join(ROOT, "curseforge")
GALLERY = os.path.join(OUT, "gallery")
DOCS = os.path.join(ROOT, "docs")

TITLE = "Free Unit Frames"
TAGLINE = "Clean, light unit frames. Your whole group at a glance."
PLACEHOLDERS = False  # set by --placeholders: draw stand-ins instead of the game's spell icons and raid marks


def note():
    """The line every picture carries: what it is, and whose the spell icons in it are."""
    line = "Illustration built from the addon's own artwork, not a screenshot."
    return line + (" Spell icons are placeholders." if PLACEHOLDERS else " Spell icons and raid marks \u00a9 Blizzard Entertainment.")

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
THREAT_TEXT = (242, 108, 96, 255)
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


def tile(size, spell, rim=None):
    """A spell's icon as the addon draws it: trimmed of its own border and set in a rim (dark for a
    buff, in the colour of its kind for a debuff). With --placeholders, a shaded stand-in tile."""
    size = max(4, round(size))
    pixel = max(1, round(size / 20))
    out = Image.new("RGBA", (size, size), toned(rim) + (255,) if rim else SLATE["edge"])
    inner = size - 2 * pixel
    if not PLACEHOLDERS:
        picture = game_icons.icon(spell)
        trim = round(picture.width * 0.08)  # Auras.lua cuts the same 8% off each side
        picture = picture.crop((trim, trim, picture.width - trim, picture.height - trim))
        out.paste(picture.resize((inner, inner), Image.LANCZOS).convert("RGB"), (pixel, pixel))
        return out
    seed = sum(ord(character) for character in spell)
    hue = [(0.95, 0.45, 0.20), (0.35, 0.65, 0.95), (0.40, 0.75, 0.35), (0.95, 0.85, 0.45), (0.55, 0.35, 0.80)][seed % 5]
    top = tuple(min(255, round(255 * c * 0.95 + 20)) for c in hue)
    bottom = tuple(round(255 * c * 0.42) for c in hue)
    out.paste(brand.vertical((inner, inner), top, bottom), (pixel, pixel))
    middle, reach = size / 2, inner * 0.24
    ImageDraw.Draw(out).polygon([(middle, middle - reach), (middle + reach, middle), (middle, middle + reach), (middle - reach, middle)],
                                fill=(255, 255, 255, 190))
    return out


# ---------------------------------------------------------------------------
# One unit frame, laid out as Frame.lua and the elements lay it out
# ---------------------------------------------------------------------------
def over(canvas, layer, x, y):
    """Lays a layer on the canvas at (x, y), which may be partly off it."""
    x, y = round(x), round(y)
    box = (max(0, -x), max(0, -y), min(layer.width, canvas.width - x), min(layer.height, canvas.height - y))
    if box[2] > box[0] and box[3] > box[1]:
        canvas.alpha_composite(layer.crop(box), (x + box[0], y + box[1]))


def shadow_under(canvas, box, blur=14, drop=8, strength=0.55):
    """A soft shadow under a rectangle, so that it stands off whatever is behind it."""
    x0, y0, x1, y1 = [round(v) for v in box]
    pad = blur * 3
    mask = Image.new("L", (x1 - x0 + 2 * pad, y1 - y0 + 2 * pad), 0)
    ImageDraw.Draw(mask).rectangle([pad, pad, pad + x1 - x0, pad + y1 - y0], fill=round(255 * strength))
    shade = Image.new("RGBA", mask.size, (0, 0, 0, 255))
    shade.putalpha(mask.filter(ImageFilter.GaussianBlur(blur)))
    over(canvas, shade, x0 - pad, y0 - pad + drop)


def cast_bar(canvas, left, top, k, width, height, spell, done, icon, shield=False, interrupted=False,
             theme=SLATE, texture="Bar-Smooth", font_size=10):
    """A cast bar as CastBar.lua lays it out: icon, timer, spell name, and a shield at the end
    while the cast cannot be interrupted. An interrupted one is full and red for a moment."""
    px = max(1, round(k))
    w, h = round(width * k), round(height * k)
    tone = theme["tone"]
    rect(canvas, left, top, left + w, top + h, theme["back"])
    for x0, y0, x1, y1 in ((left, top, left + w, top + px), (left, top + h - px, left + w, top + h),
                           (left, top, left + px, top + h), (left + w - px, top, left + w, top + h)):
        rect(canvas, x0, y0, x1, y1, theme["edge"])
    square = h - 2 * px
    canvas.alpha_composite(tile(square, icon), (left + px, top + px))
    bar_left = left + px + square + px
    bar_w = left + w - px - bar_left
    colour = (0.86, 0.24, 0.20) if interrupted else CAST
    share = 1.0 if interrupted else done
    canvas.alpha_composite(bar_fill(bar_w * share, square, toned(colour, tone), texture=texture), (bar_left, top + px))
    label(canvas, (bar_left + 4 * k, top + h / 2), "Interrupted" if interrupted else spell, font_size * k, theme["text"])
    if shield and not interrupted:
        canvas.alpha_composite(art("Mark-Shield").resize((square, square), Image.LANCZOS), (left + w - px - square - round(2 * k), top + px))
    return top + h


def frame(canvas, left, top, k, width, height, power_height, name, colour, share, power=None, power_share=1.0,
          level=None, right=None, sub=None, leader=False, dead=False, faded=False, heal=0.0, threat=False,
          cast=None, cast_height=16, auras=(), aura_size=20, aura_side="right", narrow=False, font_size=11,
          theme=SLATE, texture="Bar-Smooth", lit=None, shield=False, points=0, mark=None, raid_mark=None, shadow=False):
    """Draws a frame with its top left corner at (left, top). k is how many picture pixels one
    of the addon's units takes. Returns the frame's bottom edge in the picture."""
    left, top = round(left), round(top)
    px = max(1, round(k))  # the one-pixel edge
    w, h = round(width * k), round(height * k)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    BACK, EDGE, TROUGH, TEXT, QUIET, tone = theme["back"], theme["edge"], theme["trough"], theme["text"], theme["quiet"], theme["tone"]

    def toned(colour):
        return tuple(round(255 * channel * tone) for channel in colour)

    def bar_fill(width, height, colour, alpha=255):
        return globals()["bar_fill"](width, height, colour, alpha, texture)

    if shadow and not faded:
        shadow_under(canvas, (left, top, left + w, top + h))
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
        crown = round(max(10, min(16, height * 0.36)) * k)
        over(layer, art("Mark-Leader").resize((crown, crown), Image.LANCZOS), left, top - crown / 2)
    if raid_mark and not PLACEHOLDERS:  # one of the game's eight: inside a wide frame, riding the edge of a narrow one
        big = round(max(12, min(22, height * 0.5)) * k)
        mark_top = top - big / 2 if narrow else top + 2 * px
        over(layer, game_icons.mark(raid_mark).resize((big, big), Image.LANCZOS), left + w / 2 - big / 2, mark_top)

    bottom = top + h
    if cast:
        spell, done, cast_icon = cast
        cast_top = bottom + round(3 * k)
        if shadow:
            shadow_under(canvas, (left, cast_top, left + w, cast_top + round(cast_height * k)), blur=10, drop=6, strength=0.45)
        bottom = cast_bar(layer, left, cast_top, k, width, cast_height, spell, done, cast_icon, shield, False, theme, texture, font_size - 1)
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
    for index, aura in enumerate(auras):
        spell, kind = aura[0], aura[1]
        icon = tile(aura_size * k, spell, KIND[kind] if kind else None)
        if len(aura) > 2:  # how many stacks, bottom right as on the addon's icons
            label(icon, (icon.width - round(1.5 * k), icon.height - round(5.5 * k)), aura[2], max(7, (aura_size * 0.5) * k), anchor="rm")
        if aura_side == "right":
            over(layer, icon, left + w + round(4 * k) + index * step, top)
        elif aura_side == "left":
            over(layer, icon, left - round(4 * k) - icon.width - index * step, top)
        elif aura_side == "above":
            over(layer, icon, left + index * step, top - round(3 * k) - icon.height)
        elif aura_side == "below":
            over(layer, icon, left + index * step, bottom + round(3 * k))
        else:  # inside: from the bottom right corner of the health bar, towards the left
            over(layer, icon, bar_right - px - (index + 1) * (icon.width + px) + px, health_bottom - px - icon.height)

    if faded:  # out of range
        layer.putalpha(layer.getchannel("A").point(lambda v: int(v * 0.45)))
    canvas.alpha_composite(layer)
    return bottom


# ---------------------------------------------------------------------------
# The stage: a party, the player, a target, and a corner of a raid
# ---------------------------------------------------------------------------
# The auras on show: (spell, kind of debuff or None for a buff[, stacks]). The spells are in tools/game_icons.py.
CURSE, POISON, MAGIC, BLEED = ("Curse of Agony", "curse"), ("Deadly Poison", "poison", "3"), ("Frost Nova", "magic"), ("Rend", "none")
BUFFS = [("Blessing of Might", None), ("Arcane Intellect", None), ("Mark of the Wild", None)]

PARTY = [
    dict(name="Thryn", colour=CLASS["WARRIOR"], share=0.64, power="RAGE", power_share=0.45, right="64%", threat=True,
         auras=[CURSE]),
    dict(name="Lioren", colour=CLASS["PRIEST"], share=1.0, power="MANA", power_share=0.72, right="100%"),
    dict(name="Maeve", colour=CLASS["MAGE"], share=0.38, power="MANA", power_share=0.30, right="38%", heal=0.30,
         auras=[POISON, MAGIC]),
    dict(name="Brask", colour=CLASS["HUNTER"], share=0.86, power="MANA", power_share=0.90, right="86%", faded=True),
]

RAID = [
    ("Thryn", "WARRIOR", 0.64), ("Lioren", "PRIEST", 1.0), ("Maeve", "MAGE", 0.38), ("Brask", "HUNTER", 0.86), ("Odda", "SHAMAN", 0.92),
    ("Wren", "DRUID", 1.0), ("Sable", "ROGUE", 0.71), ("Ivo", "WARLOCK", 0.0), ("Halla", "PALADIN", 0.55), ("Cade", "WARRIOR", 1.0),
    ("Tamsin", "PRIEST", 0.9), ("Rook", "HUNTER", 1.0), ("Eira", "MAGE", 0.47), ("Bram", "SHAMAN", 1.0), ("Nell", "DRUID", 0.8),
]


def stage(canvas, cx, cy, k):
    """Draws the frames around (cx, cy): the party on the left, the player and the target in the
    middle, three columns of raid frames on the right. Over a bright scene, so each casts a shadow."""
    def at(x, y):
        return round(cx + x * k), round(cy + y * k)

    # Party: four frames of 172 x 40, twelve apart.
    for index, member in enumerate(PARTY):
        left, top = at(-590, -98 + index * 52)
        frame(canvas, left, top, k, 172, 40, 6, shadow=True, **member)

    # Player, with a cast under way; the target beside it with its buffs and debuffs above.
    left, top = at(-330, -34)
    frame(canvas, left, top, k, 232, 46, 9, "Halla", CLASS["PALADIN"], 0.71, "MANA", 0.58, level="60", right="3,550  71%", sub="2,310",
          leader=True, cast=("Holy Light", 0.62, "Holy Light"), shadow=True)
    left, top = at(-74, -34)
    frame(canvas, left, top, k, 232, 46, 9, "Hogger", HOSTILE, 0.42, "RAGE", 0.35, level="11+", right="279  42%", sub="35",
          auras=[BLEED, CURSE, POISON, MAGIC] + BUFFS[:2], aura_size=22, aura_side="above", raid_mark=8, points=3, shadow=True)

    # Raid: narrow frames of 82 x 40, five to a column.
    for index, (name, cls, share) in enumerate(RAID):
        column, row = divmod(index, 5)
        left, top = at(200 + column * 88, -98 + row * 44)
        frame(canvas, left, top, k, 82, 40, 3, name, CLASS[cls], share, "MANA", 1.0, dead=share == 0, narrow=True,
              right="Dead" if share == 0 else None, font_size=10,
              auras=[("Polymorph", "magic")] if name == "Eira" else (), aura_size=15, aura_side="inside",
              threat=name == "Halla", faded=name in ("Rook", "Bram"), lit="magic" if name == "Eira" else None,
              raid_mark={"Thryn": 1}.get(name), shadow=True)


# ---------------------------------------------------------------------------
# Emblem and title pictures
# ---------------------------------------------------------------------------
W, H = 1920, 1080


@functools.lru_cache(maxsize=None)
def logo(size=400):
    return make_art.emblem(size)


def hero(w=W, h=H, k=2.0, title_y=128, title_size=150, tagline_size=46, stage_y=500, note_size=18, city=0.70, chips=()):
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

    stage(canvas, w / 2 + 66 * k, stage_y, k)
    brand.title_text(canvas, (w / 2, title_y), TITLE, title_size * 1.22)
    brand.shadow_text(canvas, (w / 2, title_y + title_size * 0.76), TAGLINE, tagline_size, (238, 240, 248, 255), "SemiBold", spread=7)
    if chips:
        brand.pills(canvas, w / 2, h - 96, chips, 28, 58, (8, 10, 20, 150), (255, 255, 255, 76))
    brand.shadow_text(canvas, (w / 2, h - 26), note(), note_size, (206, 210, 224, 255), "Medium", spread=4, strength=0.9)
    return canvas


def gallery_hero():
    return hero(k=1.62, stage_y=560, chips=("Player, target, focus, pet, party and raid", "Keeps drawing in the middle of a fight",
                                    "Three looks, shareable profiles"))


def banner():
    return hero(1600, 600, 1.22, 74, 92, 29, 352, note_size=15, city=0.56)


def social():
    return hero(1280, 640, 1.0, 84, 100, 28, 372, note_size=14, city=0.56)


def logo_picture(w=W, h=H):
    """The emblem, large, in open sky over the sunny city, with the name under it: the picture to
    use wherever the addon is shown as itself and not by what it does."""
    scene = brand.landscape(w, round(h * 0.50))
    gap = h - scene.height
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    strip = scene.convert("RGB").crop((0, 0, w, 8)).resize((max(2, w // 48), 1), Image.BOX).resize((w, 1), Image.BICUBIC)
    sky = np.asarray(strip.resize((w, gap), Image.NEAREST)).astype(np.float32)
    sky = sky * np.linspace(0.78, 1.0, gap, dtype=np.float32)[:, None, None] + brand.noise((w, gap), 1.6, 5)
    canvas.paste(Image.fromarray(np.clip(sky, 0, 255).astype(np.uint8), "RGB"), (0, 0))
    canvas.alpha_composite(scene, (0, gap))

    size = round(h * 0.46)
    cx, cy = w // 2, round(h * 0.285)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)

    def veil(colour, strength):
        layer = np.zeros((h, w, 4), np.float32)
        layer[..., :3] = colour
        layer[..., 3] = np.clip(strength, 0, 1) * 255
        canvas.alpha_composite(Image.fromarray(layer.astype(np.uint8), "RGBA"))

    # A soft light behind the emblem, and a deeper blue behind the lettering so it reads over the roofs.
    veil((255, 246, 214), np.clip(1 - np.hypot(x - cx, y - cy) / (size * 0.95), 0, 1) ** 2 * 0.45)
    veil((8, 30, 70), np.clip(1 - np.hypot((x - cx) / (0.50 * w), (y - 0.70 * h) / (0.20 * h)), 0, 1) ** 1.1 * 0.62)
    veil((8, 30, 70), np.clip((y - (h - 0.13 * h)) / (0.13 * h), 0, 1) ** 1.4 * 0.80)

    emblem = make_art.emblem(size)
    pad = round(size * 0.2)  # room for the shadow to fade out in, or its edge would show as a box
    shade = Image.new("L", (size + 2 * pad, size + 2 * pad), 0)
    shade.paste(emblem.getchannel("A").point(lambda v: int(v * 0.60)), (pad, pad))
    shadow = Image.new("RGBA", shade.size, (4, 20, 48, 255))
    shadow.putalpha(shade.filter(ImageFilter.GaussianBlur(size * 0.035)))
    over(canvas, shadow, cx - size / 2 - pad, cy - size / 2 - pad + size * 0.05)
    over(canvas, emblem, cx - size / 2, cy - size / 2)

    brand.title_text(canvas, (w / 2, h * 0.655), TITLE, h * 0.155)
    brand.shadow_text(canvas, (w / 2, h * 0.655 + h * 0.112), TAGLINE, h * 0.042, (238, 240, 248, 255), "SemiBold", spread=7)
    brand.shadow_text(canvas, (w / 2, h - 26), "Emblem and scenery drawn for the addon.", 18 * h / 1080, (206, 210, 224, 255), "Medium",
                      spread=4, strength=0.9)
    return canvas


# ---------------------------------------------------------------------------
# Feature pictures: a dark slide with the emblem and a headline, filled with cards
# ---------------------------------------------------------------------------
WHITE, SOFT, DIM, GOLD = brand.WHITE, brand.SOFT, brand.DIM, brand.GOLD
PANEL, PANEL_EDGE = (255, 255, 255, 10), (255, 255, 255, 32)
GREY, GREY_EDGE = (10, 14, 26, 150), (255, 255, 255, 70)  # the game's own interface, in a diagram


def slide(parts, sub, glows=()):
    canvas = brand.backdrop(W, H, glows)
    canvas.alpha_composite(logo().resize((56, 56), Image.LANCZOS), (72, 50))
    brand.text(canvas, (142, 79), TITLE, 30, WHITE, "Bold", "lm")
    brand.headline(canvas, W / 2, 196, parts, 84)
    brand.text(canvas, (W / 2, 278), sub, 32, SOFT, "Medium")
    brand.text(canvas, (W / 2, H - 34), note(), 20, DIM, "Medium")
    return canvas


def card(canvas, box, title=None, tag=None):
    """A rounded panel that holds one part of a slide, with its title and a quieter note beside it."""
    brand.box(canvas, box, 28, PANEL, PANEL_EDGE)
    if title:
        brand.text(canvas, (box[0] + 36, box[1] + 50), title, 34, WHITE, "Bold", "lm")
    if tag:
        brand.text(canvas, (box[2] - 36, box[1] + 50), tag, 24, SOFT, "Medium", "rm")


def small_caps(canvas, xy, string, colour=GOLD, size=19, anchor="lm"):
    brand.text(canvas, xy, string.upper(), size, colour, "Bold", anchor)


def point(canvas, x, y, title, sub, size=33):
    """A gold tick, a point made in bold, and a line under it."""
    def badge(d, scale):
        d.ellipse((0, 0, 44 * scale - 1, 44 * scale - 1), fill=GOLD)
        d.line([(11 * scale, 23 * scale), (19 * scale, 31 * scale), (33 * scale, 14 * scale)], fill=(44, 32, 8, 255),
               width=5 * scale, joint="curve")
    canvas.alpha_composite(brand.drawn(44, 44, badge), (round(x), round(y - 22)))
    brand.text(canvas, (x + 66, y - 14), title, size, WHITE, "Bold", "lm")
    brand.text(canvas, (x + 66, y + 26), sub, size * 0.70, SOFT, "Medium", "lm")


def said(canvas, x, y, title, sub, size=28):
    brand.text(canvas, (x, y), title, size, WHITE, "Bold", "lm")
    brand.text(canvas, (x, y + size * 1.25), sub, size * 0.76, SOFT, "Medium", "lm")


@functools.lru_cache(maxsize=None)
def world(width, height):
    """The sunny city of the title pictures at dusk-level brightness: the game world, seen behind
    the interface in a diagram, where it must not outshine the frames."""
    scene = brand.landscape(width, height).convert("RGB")
    return Image.blend(scene, Image.new("RGB", scene.size, (6, 12, 28)), 0.60)


def game_screen(canvas, box, bars=True):
    """A stylised game screen: the world behind, and the game's own interface sketched in grey."""
    x0, y0, x1, y1 = box
    width, height = x1 - x0, y1 - y0
    corners = brand.drawn(width, height, lambda d, sc: d.rounded_rectangle(
        (0, 0, width * sc - 1, height * sc - 1), radius=22 * sc, fill=(255, 255, 255, 255))).getchannel("A")
    scene = world(width, height).convert("RGBA")
    scene.putalpha(corners)
    canvas.alpha_composite(scene, (x0, y0))
    brand.box(canvas, box, 22, (0, 0, 0, 0), (255, 255, 255, 60))
    radius = 66
    cx, cy = x1 - 44 - radius, y0 + 40 + radius
    canvas.alpha_composite(brand.drawn(2 * radius, 2 * radius, lambda d, sc: d.ellipse(
        (0, 0, 2 * radius * sc - 1, 2 * radius * sc - 1), fill=GREY, outline=GREY_EDGE, width=2 * sc)), (cx - radius, cy - radius))
    brand.text(canvas, (cx, cy + radius + 18), "Minimap", 17, SOFT, "Medium")
    if bars:
        size, gap, count = 40, 6, 12 if width > 1300 else 8  # a narrower diagram has room for fewer
        left = round((x0 + x1) / 2 - (count * (size + gap) - gap) / 2)
        for index in range(count):
            brand.box(canvas, (left + index * (size + gap), y1 - 34 - size, left + index * (size + gap) + size, y1 - 34), 6, GREY, GREY_EDGE, 1)
        brand.text(canvas, ((x0 + x1) / 2, y1 - 16), "Your action bars", 17, SOFT, "Medium")
        for index in range(5):
            brand.box(canvas, (x1 - 40 - (index + 1) * 40, y1 - 34 - 34, x1 - 40 - (index + 1) * 40 + 34, y1 - 34), 6, GREY, GREY_EDGE, 1)
        brand.text(canvas, (x1 - 40 - 100, y1 - 16), "Menus and bags", 17, SOFT, "Medium")


RAID_20 = list(zip(
    ["Thryn", "Lioren", "Maeve", "Brask", "Odda", "Wren", "Sable", "Ivo", "Halla", "Cade",
     "Tamsin", "Rook", "Eira", "Bram", "Nell", "Garr", "Pia", "Dov", "Sten", "Yara"],
    ["WARRIOR", "PRIEST", "MAGE", "HUNTER", "SHAMAN", "DRUID", "ROGUE", "WARLOCK", "PALADIN", "WARRIOR",
     "PRIEST", "HUNTER", "MAGE", "SHAMAN", "DRUID", "ROGUE", "PALADIN", "WARLOCK", "WARRIOR", "MAGE"],
    [0.64, 1.0, 0.38, 0.86, 0.92, 1.0, 0.71, 0.0, 0.55, 1.0, 0.9, 1.0, 0.47, 1.0, 0.8, 0.95, 1.0, 0.6, 1.0, 0.88]))


def raid_grid(canvas, left, top, k, members, columns_of=5):
    """Raid frames, five to a column: a mark or two, someone dead, someone hit, someone out of range."""
    for index, (name, cls, share) in enumerate(members):
        column, row = divmod(index, columns_of)
        frame(canvas, left + round(column * 88 * k), top + round(row * 44 * k), k, 82, 40, 3, name, CLASS[cls], share, "MANA", 1.0,
              dead=share == 0, narrow=True, right="Dead" if share == 0 else None, font_size=10,
              threat=name == "Halla", faded=name in ("Rook", "Bram"), lit="magic" if name == "Eira" else None,
              auras=[("Polymorph", "magic")] if name == "Eira" else (), aura_size=15, aura_side="inside",
              mark=("Ready", "center") if name in ("Wren", "Cade") else None, raid_mark={"Thryn": 1, "Lioren": 5}.get(name))


def frames():
    canvas = slide([("Seven frames, ", WHITE), ("yours to arrange.", GOLD)],
                   "Player, target, target of target, focus, pet, party and raid. Switch each off, size it, scale it, move it.")
    x0, y0, x1, y1 = 110, 330, 1810, 1000
    game_screen(canvas, (x0, y0, x1, y1))

    raid_grid(canvas, x0 + 40, y0 + 36, 1.05, RAID_20[:15])
    small_caps(canvas, (x0 + 40 + 290, y0 + 52), "Raid")
    brand.text(canvas, (x0 + 40 + 290, y0 + 80), "10, 20 or 40", 19, SOFT, "Medium", "lm")

    k = 1.3
    for index, member in enumerate(PARTY):
        frame(canvas, x0 + 40, y0 + 300 + index * round(52 * k), k, 172, 40, 6, **member)
    small_caps(canvas, (x0 + 40, y0 + 300 + 4 * round(52 * k) + 4), "Party")

    k = 1.5
    frame(canvas, x0 + 610, y0 + 286, k, 174, 34, 6, "Maeve", CLASS["MAGE"], 0.38, "MANA", 0.30, right="38%",
          cast=("Frostbolt", 0.35, "Frostbolt"), cast_height=12)
    small_caps(canvas, (x0 + 610 + round(174 * k) + 18, y0 + 286 + 26), "Focus")

    frame(canvas, x0 + 396, y0 + 458, k, 124, 28, 4, "Ember", (0.35, 0.74, 0.38), 0.9, "FOCUS", 0.7)
    small_caps(canvas, (x0 + 396 + round(124 * k) / 2, y0 + 458 + 66), "Pet", anchor="mm")

    bottom = frame(canvas, x0 + 610, y0 + 436, k, 232, 46, 9, "Halla", CLASS["PALADIN"], 0.71, "MANA", 0.58, level="60",
                   right="3,550  71%", sub="2,310", leader=True, cast=("Holy Light", 0.62, "Holy Light"), mark=("Rest", "rim"))
    small_caps(canvas, (x0 + 610 + round(232 * k) / 2, bottom + 26), "Player", anchor="mm")

    bottom = frame(canvas, x0 + 1010, y0 + 436, k, 232, 46, 9, "Hogger", HOSTILE, 0.42, "RAGE", 0.35, level="11+", right="279  42%",
                   sub="35", auras=[BLEED, CURSE, POISON, MAGIC] + BUFFS, aura_size=22, aura_side="above", points=3, raid_mark=8)
    small_caps(canvas, (x0 + 1010 + round(232 * k) / 2, bottom + 26), "Target", anchor="mm")

    frame(canvas, x0 + 1010 + round(232 * k) + 16, y0 + 458, k, 124, 28, 4, "Halla", CLASS["PALADIN"], 0.71, "MANA", 0.58, right="71%")
    small_caps(canvas, (x0 + 1010 + round(232 * k) + 16 + round(124 * k) / 2, y0 + 458 + 66), "Target of target", anchor="mm")
    return canvas


def groups():
    canvas = slide([("Your group, ", WHITE), ("at a glance.", GOLD)],
                   "Party and raid frames tell you who is hurt, who is being hit, who is out of reach, and whom you can help.")
    party = (70, 330, 1030, 1000)
    card(canvas, party, "Party", "with yourself among them, or when alone, if you like")
    k = 2.5
    told = [
        ("Thryn", "WARRIOR", 0.64, "RAGE", 0.45, dict(threat=True), "Being attacked", "an outline, amber to red"),
        ("Lioren", "PRIEST", 0.55, "MANA", 0.72, dict(heal=0.28), "Healing on its way", "past the end of the bar"),
        ("Maeve", "MAGE", 0.80, "MANA", 0.30, dict(lit="poison", auras=[("Viper Sting", "poison")]), "A debuff you can remove",
         "the frame lights up in its colour"),
        ("Brask", "HUNTER", 0.86, "MANA", 0.90, dict(faded=True), "Out of range", "the frame fades"),
    ]
    for index, (name, cls, share, power, power_share, extra, title, sub) in enumerate(told):
        top = 424 + index * 136
        frame(canvas, 110, top, k, 172, 40, 6, name, CLASS[cls], share, power, power_share, right="%d%%" % round(share * 100), **extra)
        said(canvas, 110 + round(172 * k) + 82, top + 34, title, sub)

    raid = (1060, 330, 1850, 1000)
    card(canvas, raid, "Raid", "10, 20 or 40 players")
    rk = 1.95
    raid_grid(canvas, raid[0] + round((raid[2] - raid[0] - (3 * 88 + 82) * rk) / 2), 424, rk, RAID_20)
    brand.text(canvas, ((raid[0] + raid[2]) / 2, 902), "Drawn larger in a small raid", 27, WHITE, "Bold")
    brand.text(canvas, ((raid[0] + raid[2]) / 2, 942), "ready checks, raid marks, and dead or offline said in words", 21, SOFT, "Medium")
    return canvas


def combat():
    canvas = slide([("Built for ", WHITE), ("how Forever fights.", GOLD)],
                   "In a fight the game seals health, names, casts and auras from addons. These frames are written around that.")
    points = [
        ("Health, names and casts keep drawing", "What the game seals goes straight back to the game to be drawn."),
        ("A late joiner gets a frame at once", "Party and raid are the game's own secure group frames."),
        ("Nothing of the game's is hooked", "Its menus are left alone, with controller play in mind."),
        ("No libraries, no borrowed code", "Written from scratch for this client."),
        ("It tells you when something is wrong", "/freeuf status lists any error it caught."),
    ]
    for index, (title, sub) in enumerate(points):
        point(canvas, 96, 408 + index * 118, title, sub)

    box = (1010, 330, 1850, 1000)
    card(canvas, box, "In the middle of a fight")
    k = 2.9
    left = box[0] + round((box[2] - box[0] - 232 * k) / 2)
    top = 606
    small_caps(canvas, (left, top - round(25 * k) - 26), "Debuffs, rimmed by kind")
    bottom = frame(canvas, left, top, k, 232, 46, 9, "Hogger", HOSTILE, 0.42, "RAGE", 0.35, level="11+", right="279  42%", sub="35",
                   auras=[BLEED, CURSE, POISON, MAGIC], aura_size=22, aura_side="above", raid_mark=8,
                   cast=("Enrage", 0.48, "Enrage"), shield=True, threat=True)
    small_caps(canvas, (left, bottom + 34), "A shield: this cast cannot be interrupted")
    small_caps(canvas, (left, bottom + 72), "The red outline: it is on you", THREAT_TEXT)
    return canvas


def auras():
    canvas = slide([("Buffs, debuffs ", WHITE), ("and cast bars.", GOLD)],
                   "Icons with time left and stacks, rimmed in the colour of their kind. Above, below, beside, or on the frame.")
    top = (70, 330, 1850, 650)
    card(canvas, top, "Debuffs wear the colour of their kind", "on your target, only your own if you like")
    kinds = [("magic", "Magic", "Frost Nova"), ("curse", "Curse", "Curse of Agony"), ("disease", "Disease", "Devouring Plague"),
             ("poison", "Poison", "Deadly Poison"), ("none", "Other", "Rend"), (None, "A buff", "Arcane Intellect")]
    size, step = 132, 268
    x0 = round((top[0] + top[2]) / 2 - ((len(kinds) - 1) * step + size) / 2)
    for index, (kind, name, spell) in enumerate(kinds):
        x = x0 + index * step
        shadow_under(canvas, (x, 424, x + size, 424 + size), blur=12, drop=7, strength=0.5)
        icon = tile(size, spell, KIND[kind] if kind else None)
        if kind == "poison":
            label(icon, (size - 8, size - 26), "3", 42, anchor="rm")
        canvas.alpha_composite(icon, (x, 424))
        brand.text(canvas, (x + size / 2, 600), name, 28, WHITE, "Bold")

    casts = (70, 680, 950, 1000)
    card(canvas, casts, "Cast bars", "player, target, focus, pet")
    k = 2.05
    rows = [("Holy Light", 0.62, "Holy Light", False, False, "a cast fills, a channel drains"),
            ("Enrage", 0.44, "Enrage", True, False, "a shield: cannot be interrupted"),
            ("Frostbolt", 0.7, "Frostbolt", False, True, "a moment in red")]
    for index, (spell, done, icon, shield, interrupted, told) in enumerate(rows):
        y = 778 + index * 70
        cast_bar(canvas, 110, y, k, 232, 18, spell, done, icon, shield, interrupted)
        brand.text(canvas, (110 + round(232 * k) + 26, y + round(18 * k) / 2), told, 21, SOFT, "Medium", "lm")

    where = (980, 680, 1850, 1000)
    card(canvas, where, "Icons where you want them")
    k = 1.34
    places = [("above", "Above"), ("below", "Below"), ("right", "Beside"), ("inside", "On the frame")]
    for index, (side, name) in enumerate(places):
        left = where[0] + 36 + index * 208
        shown = [CURSE, MAGIC] if side != "right" else [CURSE]
        width = 132 if side != "right" else 108
        frame(canvas, left, 822, k, width, 40, 6, "Maeve", CLASS["MAGE"], 0.62, "MANA", 0.4, auras=shown,
              aura_size=20 if side != "inside" else 16, aura_side=side, font_size=11)
        brand.text(canvas, (left + round(132 * k) / 2, 956), name, 24, WHITE, "Bold")
    return canvas


def looks():
    canvas = slide([("Three looks. ", WHITE), ("Three textures.", GOLD)],
                   "Slate, Night and Hearth, with smooth, flat or glass bars: all drawn for this addon. Colour by class, by foe, or by health.")
    k = 2.2
    textures = [("Bar-Smooth", "Smooth"), ("Bar-Flat", "Flat"), ("Bar-Glass", "Glass")]
    people = [("PALADIN", "Halla", 0.71, "MANA", 0.58), ("SHAMAN", "Odda", 0.86, "MANA", 0.74), ("DRUID", "Wren", 0.48, "ENERGY", 0.9)]
    for column, (theme_name, theme) in enumerate(THEMES.items()):
        box = (60 + column * 607, 330, 60 + column * 607 + 587, 1000)
        card(canvas, box, theme_name, "theme")
        left = box[0] + round((587 - 232 * k) / 2)
        for row, ((texture, texture_name), (cls, name, share, power, power_share)) in enumerate(zip(textures, people)):
            top = 452 + row * 178
            small_caps(canvas, (left, top - 20), texture_name, DIM, 18)
            frame(canvas, left, top, k, 232, 46, 9, name, CLASS[cls], share, power, power_share, level="60",
                  right="%d%%" % round(share * 100), theme=theme, texture=texture, leader=row == 0)
    return canvas


def arrange():
    canvas = slide([("Unlock, drag, ", WHITE), ("done.", GOLD)],
                   "A green handle appears on every frame. Sizes, colours, texts and icons are in the options, frame by frame.")
    box = (70, 330, 1180, 1000)
    card(canvas, box, "Every frame gets a handle", "/freeuf unlock")
    sx0, sy0, sx1, sy1 = box[0] + 34, box[1] + 92, box[2] - 34, box[3] - 34
    game_screen(canvas, (sx0, sy0, sx1, sy1))
    handles = [("Party", 36, 34, 172, 196), ("Pet", 222, 270, 124, 28), ("Focus", 362, 190, 174, 34),
               ("Player", 362, 262, 232, 46), ("Target of target", 866, 384, 124, 28)]

    def handle(name, x, y, w, h, alpha=90, edge=(115, 242, 178, 230)):
        left, top = sx0 + x, sy0 + y
        canvas.alpha_composite(Image.new("RGBA", (w, h), (64, 178, 128, alpha)), (left, top))
        ImageDraw.Draw(canvas).rectangle([left, top, left + w - 1, top + h - 1], outline=edge, width=2)
        if name:
            brand.text(canvas, (left + w / 2, top + h / 2), name, 21 if w > 200 else 15, GOLD, "Bold")

    for name, x, y, w, h in handles:
        handle(name, x, y, w, h)
    # The target's handle on its way: where it was, the way it went, where it is now, and the pointer.
    was, now = (626, 262), (626, 376)
    draw = ImageDraw.Draw(canvas)
    for step in range(0, 232, 16):  # the old place, dashed
        draw.line([(sx0 + was[0] + step, sy0 + was[1]), (sx0 + was[0] + min(step + 9, 232), sy0 + was[1])], fill=(115, 242, 178, 120), width=2)
        draw.line([(sx0 + was[0] + step, sy0 + was[1] + 46), (sx0 + was[0] + min(step + 9, 232), sy0 + was[1] + 46)], fill=(115, 242, 178, 120), width=2)
    for step in range(56, 104, 14):
        draw.line([(sx0 + was[0] + 116, sy0 + was[1] + step), (sx0 + was[0] + 116, sy0 + was[1] + step + 8)], fill=GOLD, width=3)
    draw.polygon([(sx0 + now[0] + 116 - 9, sy0 + now[1] - 12), (sx0 + now[0] + 116 + 9, sy0 + now[1] - 12), (sx0 + now[0] + 116, sy0 + now[1] - 1)], fill=GOLD)
    handle("Target", now[0], now[1], 232, 46, alpha=140, edge=(255, 214, 96, 255))
    px, py = sx0 + now[0] + 170, sy0 + now[1] + 24
    pointer = [(0, 0), (0, 34), (9, 26), (15, 40), (21, 37), (15, 24), (27, 24)]
    canvas.alpha_composite(brand.drawn(32, 44, lambda d, sc: d.polygon([(2 * sc + x * sc, 2 * sc + y * sc) for x, y in pointer],
                                                                    fill=(255, 255, 255, 255), outline=(0, 0, 0, 255), width=2 * sc)), (px, py))

    side = (1210, 330, 1850, 1000)
    card(canvas, side, "Commands")
    commands = [("/freeuf", "open the options"), ("/freeuf unlock", "show the handles; /freeuf lock puts them away"),
                ("/freeuf reset target", "put a frame back as it started"), ("/freeuf profile", "your settings as text: copy, or paste"),
                ("/freeuf status", "the version, and any error it caught")]
    for index, (command, what) in enumerate(commands):
        y = 440 + index * 106
        brand.text(canvas, (side[0] + 40, y), command, 31, GOLD, "Bold", "lm")
        brand.text(canvas, (side[0] + 40, y + 40), what, 22, SOFT, "Medium", "lm")
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
    "logo-picture": (logo_picture, os.path.join(GALLERY, "08-logo.png")),
    "banner": (banner, os.path.join(DOCS, "banner.png")),
    "social": (social, os.path.join(DOCS, "social.png")),
    "web": (web_copies, WEB),
    "description": (description_html, os.path.join(OUT, "description.html")),
}


def main():
    global PLACEHOLDERS
    PLACEHOLDERS = "--placeholders" in sys.argv[1:]
    wanted = [name for name in sys.argv[1:] if name != "--placeholders"] or list(PICTURES)
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
