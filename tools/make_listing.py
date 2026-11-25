#!/usr/bin/env python3
"""Draws the pictures for the CurseForge page and the README, in the look the Free addons share.

    python3 tools/make_listing.py            # all of them
    python3 tools/make_listing.py banner     # only the ones named

  curseforge/logo.png                  the project avatar: 400 x 400, as CurseForge requires
  curseforge/gallery/01-hero.png       title picture: the emblem and the name, the frames, a dwarf in a forge hall
  curseforge/gallery/02-frames.png     the five single frames
  curseforge/gallery/03-groups.png     party and raid, and what they tell you
  curseforge/gallery/04-combat.png     what keeps working in a fight
  curseforge/gallery/05-auras.png      buffs, debuffs and cast bars
  curseforge/gallery/06-looks.png      the three themes and three bar textures
  curseforge/gallery/07-arrange.png    moving frames, and the commands
  curseforge/gallery/08-logo.png       the emblem and the name, large
  curseforge/gallery/09-in-play.png    the simulator's picture of a fight (docs/sim-screenshot.png,
                                       which tools/sim/run.sh writes) with a headline and its note
  curseforge/web/*.jpg                 the same nine at 1280 x 720, a fraction of the size: what
                                       the description page loads, so it opens quickly
  docs/banner.png                      the README header
  docs/social.png                      for GitHub's Settings > Social preview
  docs/logo.png                        the emblem, for the README
  curseforge/description.html          curseforge/description.md as HTML, for the page editor's
                                       source view (needs the "markdown" package)

    python3 tools/make_listing.py --placeholders   # with drawn stand-ins for the spell icons

Every picture but one is an illustration built from the addon's own textures, colours and layout
numbers, and says so on the picture: the frames are drawn here the way Frame.lua lays them out.
The one is 09-in-play, whose frames the addon's own code drew in the simulator. The spell
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
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # the sibling modules, also under python -I
import brand  # noqa: E402
import forge_hall  # noqa: E402
import game_icons  # noqa: E402
import make_art  # noqa: E402

ROOT = brand.ROOT
ART = os.path.join(ROOT, "PugUnitFrames", "Art")
OUT = os.path.join(ROOT, "curseforge")
GALLERY = os.path.join(OUT, "gallery")
DOCS = os.path.join(ROOT, "docs")

TITLE = "Pug Unit Frames"
TAGLINE = "Clean, light unit frames. Your whole group at a glance."
PLACEHOLDERS = False  # set by --placeholders: draw stand-ins instead of the game's spell icons and raid marks


def note():
    """The line every picture carries: what it is, and whose the spell icons in it are."""
    line = "Illustration built from the addon's own artwork, not a screenshot."
    return line + (" Spell icons are placeholders." if PLACEHOLDERS
                   else " Spell icons, raid marks, portraits and the elite dragon \u00a9 Blizzard Entertainment.")

# ---------------------------------------------------------------------------
# The addon's look, as Style.lua and Defaults.lua have it (theme Slate)
# ---------------------------------------------------------------------------
# name -> back, edge, text, quiet (0-255), tone, shade, veil: the three themes of Style.lua
THEMES = {
    "Slate": dict(back=(13, 15, 18, 230), edge=(0, 0, 0, 255), text=(242, 242, 237, 255),
                  quiet=(161, 168, 176, 255), tone=0.84, shade=0.70, veil=(0.00, 0.00, 0.00)),
    "Night": dict(back=(8, 10, 20, 235), edge=(3, 3, 8, 255), text=(230, 237, 255, 255),
                  quiet=(140, 158, 199, 255), tone=0.78, shade=0.74, veil=(0.02, 0.05, 0.16)),
    "Hearth": dict(back=(26, 18, 13, 230), edge=(5, 3, 0, 255), text=(255, 245, 224, 255),
                   quiet=(199, 173, 138, 255), tone=0.92, shade=0.66, veil=(0.15, 0.08, 0.03)),
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
GONE = (0.42, 0.43, 0.45)  # the bar of someone dead or offline
CAST = (0.93, 0.74, 0.28)
EASY = (185, 185, 185, 255)  # the level of a creature far below the player: the game's grey, lifted as Texts.lua lifts it
HEAL = (0.45, 0.92, 0.55)
THREAT = (0.90, 0.22, 0.18)
THREAT_TEXT = (242, 108, 96, 255)
KIND = {"magic": (0.27, 0.58, 0.98), "curse": (0.66, 0.31, 0.92), "disease": (0.72, 0.52, 0.20), "poison": (0.27, 0.78, 0.33), "none": (0.72, 0.16, 0.14)}


def toned(colour, tone=SLATE["tone"]):
    return tuple(round(255 * channel * tone) for channel in colour)


@functools.lru_cache(maxsize=None)
def art(name):
    return Image.open(os.path.join(ART, name + ".tga")).convert("RGBA")


def readable(colour):
    """A very light colour taken down far enough for light lettering to stand out on it, as
    Style.Readable does (colour as 0-255 per channel)."""
    light = (0.30 * colour[0] + 0.59 * colour[1] + 0.11 * colour[2]) / 255
    if light > 0.62:
        return tuple(round(channel * 0.62 / light) for channel in colour)
    return tuple(colour)


def bar_fill(width, height, colour, alpha=255, texture="Bar-Smooth", share=1.0):
    """A piece of one of the addon's bar textures at this size, in this colour (0-255 per channel).
    `share` is how full the bar is: the game shows that much of the picture, from its empty end."""
    width, height = max(1, round(width)), max(1, round(height))
    picture = art(texture).convert("L")
    picture = picture.crop((0, 0, max(1, round(picture.width * min(1.0, max(0.0, share)))), picture.height))
    grey = np.asarray(picture.resize((width, height), Image.BILINEAR), np.float32) / 255
    rgba = np.empty((height, width, 4), np.float32)
    rgba[..., :3] = grey[..., None] * np.asarray(colour, np.float32)
    rgba[..., 3] = alpha
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def rect(canvas, x0, y0, x1, y1, fill):
    x0, y0, x1, y1 = round(x0), round(y0), round(x1), round(y1)
    if x1 > x0 and y1 > y0:
        canvas.alpha_composite(Image.new("RGBA", (x1 - x0, y1 - y0), fill), (x0, y0))


def label(canvas, xy, string, size, fill=TEXT, weight="SemiBold", anchor="lm"):
    """Text in the addon's own font (Inter SemiBold), with the soft one-pixel shadow it gives its lettering."""
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
    # Behind the fill, the cast colour under the theme's veil, as the empty part of a health bar is.
    trough = tuple(round(channel * (1 - theme["shade"]) + 255 * veil * theme["shade"])
                   for channel, veil in zip(toned(CAST, tone), theme["veil"]))
    canvas.alpha_composite(bar_fill(bar_w, square, trough, texture=texture), (bar_left, top + px))
    canvas.alpha_composite(bar_fill(bar_w * share, square, toned(colour, tone), texture=texture, share=share), (bar_left, top + px))
    if not interrupted and 0 < share < 1:  # the bright edge on the end of the fill, cut off at the bar's ends
        glow = art("Spark").resize((max(2, round(max(8, height) * k)), square), Image.LANCZOS)
        glow.putalpha(glow.getchannel("A").point(lambda v: int(v * 0.75)))
        lit = Image.new("RGBA", (bar_w, square), (0, 0, 0, 0))
        over(lit, glow, round(bar_w * share - glow.width / 2), 0)
        box = (bar_left, top + px, bar_left + bar_w, top + px + square)
        under = np.asarray(canvas.crop(box), np.float32)  # the edge is added to what is under it, as in the game
        under[..., :3] = np.clip(under[..., :3] + np.asarray(lit.getchannel("A"), np.float32)[..., None], 0, 255)
        canvas.paste(Image.fromarray(under.astype(np.uint8), "RGBA"), box[:2])
    label(canvas, (bar_left + 4 * k, top + h / 2), "Interrupted" if interrupted else spell, font_size * k, theme["text"])
    if shield and not interrupted:
        canvas.alpha_composite(art("Mark-Shield").resize((square, square), Image.LANCZOS), (left + w - px - square - round(2 * k), top + px))
    return top + h


ABSORB = (0.66, 0.84, 1.00)  # a shield that soaks up damage, as Style.ABSORB has it
PAD = 4  # between an end of a bar and the words on it, as Texts.lua has it


@functools.lru_cache(maxsize=None)
def face(who, size, mirror=False):
    """One of the game's stand-in portraits cut the way Portrait.lua cuts a portrait: the round
    picture's rim off, which leaves a square face."""
    picture = game_icons.portrait(who)
    cut = round(picture.width * 0.14)
    picture = picture.crop((cut, cut, picture.width - cut, picture.height - cut)).resize((size, size), Image.LANCZOS)
    return picture.transpose(Image.FLIP_LEFT_RIGHT) if mirror else picture


def frame(canvas, left, top, k, width, height, power_height, name, colour, share, power=None, power_share=1.0,
          surname=None, level=None, health=None, power_text=None, portrait=None, who=None, mirror=False, rank=None,
          dead=False, faded=False, heal=0.0, absorb=0.0, threat=False,
          cast=None, cast_height=16, auras=(), buffs=(), aura_size=20, aura_side="right", buff_side=None, per_row=8,
          narrow=False, font_size=11, theme=SLATE, texture="Bar-Smooth", lit=None, shield=False, points=0, mark=None,
          raid_mark=None, shadow=False, level_colour=None):
    """Draws a frame with its top left corner at (left, top), laid out as the addon lays one out
    since 0.3. k is how many picture pixels one of the addon's units takes. Returns the frame's
    bottom edge in the picture.

    name, surname     a character has both; a creature has one name
    level, rank       the level as it is written ("60", "11+") and the dragon before it ("gold", "silver")
    health, power_text  the numbers as they are written: health on the lower line, power on its bar
    portrait, who     "left" or "right", and whose stand-in face (tools/game_icons.py); mirror turns it round
    auras, buffs      debuffs and buffs as (spell, kind[, stacks]); aura_side and buff_side say where
    heal, absorb      healing on its way and a shield, as shares of full health
    """
    left, top = round(left), round(top)
    px = max(1, round(k))  # the one-pixel edge
    w, h = round(width * k), round(height * k)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    BACK, EDGE, TEXT, QUIET, tone = theme["back"], theme["edge"], theme["text"], theme["quiet"], theme["tone"]
    left_over = 1 - theme["shade"]  # how much of a bar's colour shows in its empty part

    def toned(colour):
        return tuple(round(255 * channel * tone) for channel in colour)

    def dimmed(colour):
        return tuple(round(channel * left_over + 255 * veil * theme["shade"]) for channel, veil in zip(colour, theme["veil"]))

    def bar_fill(width, height, colour, alpha=255, share=1.0):
        return globals()["bar_fill"](width, height, colour, alpha, texture, share)

    def length(string, size):
        return ImageDraw.Draw(layer).textlength(string, font=brand.font(size, "SemiBold"))

    if shadow and not faded:
        shadow_under(canvas, (left, top, left + w, top + h))
    if threat:  # the outline lies under the plate and shows two pixels past it
        rect(layer, left - 2 * px, top - 2 * px, left + w + 2 * px, top + h + 2 * px, toned(THREAT) + (255,))
    rect(layer, left, top, left + w, top + h, BACK)
    for x0, y0, x1, y1 in ((left, top, left + w, top + px), (left, top + h - px, left + w, top + h),
                           (left, top, left + px, top + h), (left + w - px, top, left + w, top + h)):
        rect(layer, x0, y0, x1, y1, EDGE)

    # The portrait is a square at one end, inside the edge; the bars have the rest.
    square = h - 2 * px if portrait else 0
    bar_left = left + px + (square + px if portrait == "left" else 0)
    bar_right = left + w - px - (square + px if portrait == "right" else 0)
    if portrait and not PLACEHOLDERS:
        picture = face(who or "human-male", square, mirror)
        layer.alpha_composite(picture, (left + px if portrait == "left" else left + w - px - square, top + px))
    elif portrait:
        x0 = left + px if portrait == "left" else left + w - px - square
        rect(layer, x0, top + px, x0 + square, top + px + square, (52, 58, 66, 255))

    power_h = round(power_height * k)
    health_top = top + px
    health_bottom = top + h - (power_h + 2 * px if power_h > 0 else px)
    bar_w = bar_right - bar_left
    bar_h = health_bottom - health_top
    # The empty part of the bar is the bar's own colour, darkened; grey for someone dead.
    painted = readable(toned(colour))
    shown = 0.0 if dead else share
    layer.alpha_composite(bar_fill(bar_w, bar_h, dimmed(toned(GONE) if dead else painted)), (bar_left, health_top))
    if shown > 0:
        layer.alpha_composite(bar_fill(bar_w * shown, bar_h, painted, share=shown), (bar_left, health_top))
    after = shown
    if heal > 0 and not dead:  # healing on its way: past the end of the health, as long as the heal is large
        reach = min(heal, 1 - after)
        if reach > 0:
            layer.alpha_composite(bar_fill(bar_w * reach, bar_h, tuple(round(255 * c) for c in HEAL), 140),
                                  (bar_left + round(bar_w * after), health_top))
            after += reach
    if absorb > 0 and not dead:  # a shield: the same after that, pale; a cap on the bar's end when it does not fit
        reach = min(absorb, 1 - after)
        if reach > 0:
            layer.alpha_composite(bar_fill(bar_w * reach, bar_h, tuple(round(255 * c) for c in ABSORB), 184),
                                  (bar_left + round(bar_w * after), health_top))
        if absorb > 1 - after + 1e-6:
            cap = round(5 * k)
            fade = np.zeros((bar_h, cap, 4), np.float32)
            fade[..., :3] = [255 * c for c in ABSORB]
            fade[..., 3] = np.linspace(0, 235, cap, dtype=np.float32)[None, :]
            layer.alpha_composite(Image.fromarray(fade.astype(np.uint8), "RGBA"), (bar_right - cap, health_top))
    if power_h > 0:
        ran_on = toned(POWER[power]) if power else toned(GONE)
        layer.alpha_composite(bar_fill(bar_w, power_h, dimmed(ran_on)), (bar_left, top + h - px - power_h))
        if power and power_share > 0:
            layer.alpha_composite(bar_fill(bar_w * power_share, power_h, ran_on, share=power_share), (bar_left, top + h - px - power_h))

    # The words, as Texts.lua places them.
    middle = (health_top + health_bottom) / 2
    tall = not narrow and height >= 40
    name_units = font_size + (1 if tall else 0)   # on a tall plate the name is a size larger
    number_units = font_size - (1 if narrow else 0)
    power_units = max(6, font_size - 2)
    on_bar = bool(power_text) and not narrow and power_height > power_units
    bar_units = height - 2 - (power_height + 1 if power_height > 0 else 0)
    lower = bool(level) or bool(health) or (bool(power_text) and not on_bar)
    two_rows = not narrow and bool(name) and lower and bar_units >= name_units + number_units + 5
    name_y = middle - (np.ceil(name_units / 2) + 1) * k if two_rows else middle
    low_y = middle + (np.ceil(number_units / 2) + 1) * k if two_rows else middle
    full = name + (" " + surname if surname else "")
    name_row = None
    if narrow:
        size = font_size * k
        if health:  # the first name over the number
            label(layer, ((bar_left + bar_right) / 2, middle - size * 0.55), name, size, TEXT, anchor="mm")
            label(layer, ((bar_left + bar_right) / 2, middle + size * 0.6), health, number_units * k, TEXT, anchor="mm")
        elif surname:  # the first name over the surname
            label(layer, ((bar_left + bar_right) / 2, middle - size * 0.58), name, size, TEXT, anchor="mm")
            label(layer, ((bar_left + bar_right) / 2, middle + size * 0.58), surname, size, TEXT, anchor="mm")
        else:
            label(layer, ((bar_left + bar_right) / 2, middle), name, size, TEXT, anchor="mm")
    else:
        x = bar_left + PAD * k
        if rank and not PLACEHOLDERS:  # the game's dragon before an elite's level
            side = round((number_units + 5) * k)
            dragon = game_icons.rank("nameplates-icon-elite-" + rank).resize((side, side), Image.LANCZOS)
            over(layer, dragon, x - k, low_y - side / 2)
            x += side - k + 2 * k
        if level:
            size = (font_size + (1 if tall and not two_rows else 0)) * k
            label(layer, (x, low_y), level, size, level_colour or TEXT)
            x += length(level, size) + 3 * k
        if power_text and not on_bar and two_rows:  # no bar to sit on: beside the level, the quieter of the words
            label(layer, (x + 3 * k, low_y), power_text, power_units * k, QUIET)
        if two_rows:
            name_row = name_y
            label(layer, (bar_left + PAD * k, name_y), full, name_units * k, TEXT)
        else:
            label(layer, (x, middle), full, name_units * k, TEXT)
        if health:
            label(layer, (bar_right - PAD * k, low_y), health, number_units * k, TEXT, anchor="rm")
        if on_bar:  # the power number on the power bar, written in full white
            label(layer, (bar_right - PAD * k, top + h - px - power_h / 2), power_text, power_units * k, TEXT, anchor="rm")

    if lit:  # a debuff the player can remove: its colour along the rim, two pixels wide
        glow = toned(KIND[lit]) + (255,)
        for x0, y0, x1, y1 in ((left, top, left + w, top + 2 * px), (left, top + h - 2 * px, left + w, top + h),
                               (left, top, left + 2 * px, top + h), (left + w - 2 * px, top, left + w, top + h)):
            rect(layer, x0, y0, x1, y1, glow)
    small = round(max(10, min(16, height * 0.36)) * k)  # Frame.MarkSize
    big = round(max(12, min(22, height * 0.5)) * k)
    if mark:  # resting, in combat, ready, ...: one of the addon's own marks, in the middle or on the top edge
        which, where = mark
        picture = art("Mark-" + which)
        if where == "center":
            layer.alpha_composite(picture.resize((big, big), Image.LANCZOS), (round(left + w / 2 - big / 2), round(top + h / 2 - big / 2)))
        elif name_row is not None and portrait != "left":
            # Two lines of words and the bar's left end at the plate's: the mark rides the right end of the edge.
            over(layer, picture.resize((small, small), Image.LANCZOS), left + w - small, top - small / 2)
        else:  # over the portrait at the left end, or at the left end of the edge
            over(layer, picture.resize((small, small), Image.LANCZOS), left, top - small / 2)
    if raid_mark and not PLACEHOLDERS:  # one of the game's eight
        if name_row is not None:  # two lines: it closes the name's line, at the right
            size = min(big, round(16 * k))
            over(layer, game_icons.mark(raid_mark).resize((size, size), Image.LANCZOS), bar_right - PAD * k - size, name_row - size / 2)
        elif not narrow and (aura_side == "above" and auras or (buff_side or aura_side) == "above" and buffs):
            over(layer, game_icons.mark(raid_mark).resize((big, big), Image.LANCZOS), left + w / 2 - big / 2, top + 2 * px)
        else:  # one line, or a narrow plate: it rides the middle of the top edge
            over(layer, game_icons.mark(raid_mark).resize((big, big), Image.LANCZOS), left + w / 2 - big / 2, top - big / 2)

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

    # Icons, as the game's aura container lays them out for Auras.lua: the debuffs first, the
    # buffs after them, on a fresh row where they share a side.
    step = round((aura_size + 2) * k)
    placed = {}  # side -> rows used so far
    for kind_index, group in enumerate((auras, buffs)):
        side = aura_side if kind_index == 0 else (buff_side or aura_side)
        first_row = placed.get(side, 0)
        for index, aura in enumerate(group):
            spell, kind = aura[0], aura[1]
            icon = tile(aura_size * k, spell, KIND[kind] if kind else None)
            if len(aura) > 2:  # how many stacks, bottom right as on the addon's icons
                label(icon, (icon.width - round(1.5 * k), icon.height - round(5.5 * k)), aura[2], max(7, (aura_size * 0.5) * k), anchor="rm")
            column, row = index % per_row, first_row + index // per_row
            if side == "right":
                over(layer, icon, left + w + round(4 * k) + column * step, top + row * step)
            elif side == "left":
                over(layer, icon, left - round(4 * k) - icon.width - column * step, top + row * step)
            elif side == "above":
                over(layer, icon, left + column * step, top - round(3 * k) - icon.height - row * step)
            elif side == "below":
                over(layer, icon, left + column * step, bottom + round(3 * k) + row * step)
            else:  # inside: from the bottom right corner of the health bar, towards the left
                over(layer, icon, bar_right - px - (column + 1) * (icon.width + px) + px, health_bottom - px - icon.height - row * (icon.height + px))
        if group:
            placed[side] = first_row + (len(group) + per_row - 1) // per_row

    if faded:  # out of range
        layer.putalpha(layer.getchannel("A").point(lambda v: int(v * 0.45)))
    canvas.alpha_composite(layer)
    return bottom


# ---------------------------------------------------------------------------
# The stage: a party, the player, a target, and a corner of a raid
# ---------------------------------------------------------------------------
# The auras on show: (spell, kind of debuff or None for a buff[, stacks]). The spells are in tools/game_icons.py.
CURSE, POISON, MAGIC, BLEED = ("Curse of Agony", "curse"), ("Deadly Poison", "poison", "3"), ("Frost Nova", "magic"), ("Rend", "none")
SUNDER = ("Sunder Armor", "none", "3")
FORT, WILD, WIT, MIGHT = ("Power Word: Fortitude", None), ("Mark of the Wild", None), ("Arcane Intellect", None), ("Blessing of Might", None)
SHOUT, RENEW, WORD = ("Battle Shout", None), ("Renew", None), ("Power Word: Shield", None)
BUFFS = [MIGHT, WIT, WILD]

# The party of the simulator's picture: a character has a first name and a surname, a portrait
# that looks towards the bars, a level, the buffs in a row above the plate and the debuffs beside
# it, and health written as an amount.
PARTY = [
    dict(name="Thryn", surname="Ironbeard", who="dwarf-male", colour=CLASS["WARRIOR"], share=0.64, power="RAGE", power_share=0.45,
         health="3264", threat=True, auras=[BLEED, ("Sunder Armor", "none", "2")], buffs=[FORT, WILD, MIGHT, SHOUT]),
    dict(name="Lioren", surname="Dawnwhisper", who="nightelf-male", colour=CLASS["PRIEST"], share=1.0, power="MANA", power_share=0.72,
         health="3100", absorb=0.3, buffs=[FORT, WILD, WIT, WORD]),
    dict(name="Maeve", surname="Copperpot", who="gnome-female", colour=CLASS["MAGE"], share=0.38, power="MANA", power_share=0.30,
         health="1368", heal=0.30, lit="poison", auras=[POISON, MAGIC], buffs=[FORT, WILD, WIT, RENEW], level="59"),
    dict(name="Brask", surname="Holloway", who="human-male", colour=CLASS["HUNTER"], share=0.86, power="MANA", power_share=0.90,
         health="3440", faded=True, buffs=[FORT, WILD, MIGHT]),
]
PARTY_PITCH = 40 + 12 + 3 + 20  # a plate, the gap, and the row of buffs above the next member


def party_frame(canvas, left, top, k, member, **extra):
    """A party member's frame as it starts out: 200 x 40 with a portrait, buffs above, debuffs beside."""
    told = dict(portrait="left", mirror=True, level="60", aura_side="right", buff_side="above", aura_size=20, per_row=8)
    told.update(member)
    told.update(extra)
    return frame(canvas, left, top, k, 200, 40, 6, **told)


def player_frame(canvas, left, top, k, **extra):
    told = dict(surname="Brightmoor", who="human-female", portrait="left", level="60", health="3550", power_text="2310")
    told.update(extra)
    return frame(canvas, left, top, k, 232, 46, 10, "Halla", CLASS["PALADIN"], 0.71, "MANA", 0.58, **told)


def target_frame(canvas, left, top, k, **extra):
    """A hostile elite: its power bar is put away (a creature that gathers no rage has none to show)."""
    told = dict(who="creature", portrait="right", rank="gold", level="11+", level_colour=EASY, health="279",
                auras=[BLEED, SUNDER, MAGIC, CURSE, POISON, ("Immolate", "magic")], buffs=[SHOUT], aura_size=22, aura_side="above",
                per_row=9)
    told.update(extra)
    return frame(canvas, left, top, k, 232, 46, 0, "Hogger", HOSTILE, 0.42, **told)


def focus_frame(canvas, left, top, k, **extra):
    told = dict(surname="Vilecaller", who="orc-male", portrait="left", health="77%", raid_mark=1, auras=[("Viper Sting", "poison"), ("Immolate", "magic")],
                aura_side="above", aura_size=20, cast=("Shadow Bolt", 0.55, "Shadow Bolt"), cast_height=12)
    told.update(extra)
    return frame(canvas, left, top, k, 200, 40, 6, "Morgash", CLASS["WARLOCK"], 0.77, "MANA", 0.62, **told)


# A raid: first name, surname, class, share of health.
RAID_20 = [
    ("Thryn", "Ironbeard", "WARRIOR", 0.64), ("Lioren", "Dawnwhisper", "PRIEST", 1.0), ("Maeve", "Copperpot", "MAGE", 0.38),
    ("Brask", "Holloway", "HUNTER", 0.86), ("Odda", "Stormcaller", "SHAMAN", 0.92), ("Wren", "Thistledown", "DRUID", 1.0),
    ("Sable", "Quickblade", "ROGUE", 0.71), ("Ivo", "Grimward", "WARLOCK", 0.0), ("Halla", "Brightmoor", "PALADIN", 0.55),
    ("Cade", "Marrowick", "WARRIOR", 1.0), ("Tamsin", "Vale", "PRIEST", 0.9), ("Rook", "Ashford", "HUNTER", 1.0),
    ("Eira", "Frostmere", "MAGE", 0.47), ("Bram", "Stonefist", "SHAMAN", 1.0), ("Nell", "Greenbough", "DRUID", 0.8),
    ("Garr", "Blackthorn", "ROGUE", 0.95), ("Pia", "Sunvale", "PALADIN", 1.0), ("Dov", "Nightfall", "WARLOCK", 0.6),
    ("Sten", "Hallowell", "WARRIOR", 1.0), ("Yara", "Windrider", "MAGE", 0.88),
]


def raid_grid(canvas, left, top, k, members, columns_of=5, shadow=False, ready=()):
    """Raid frames, five to a column, first name over surname: a mark or two, someone dead, someone
    hit, someone out of range, a debuff the player can remove."""
    for index, (name, surname, cls, share) in enumerate(members):
        column, row = divmod(index, columns_of)
        dead = share == 0
        frame(canvas, left + round(column * 88 * k), top + round(row * 44 * k), k, 82, 40, 3, name, CLASS[cls], share, "MANA", 1.0,
              surname=None if dead else surname, health="Dead" if dead else None, dead=dead, narrow=True, font_size=10,
              threat=name == "Halla", faded=name in ("Rook", "Bram"), lit="magic" if name == "Eira" else None,
              auras=[("Polymorph", "magic")] if name == "Eira" else (), aura_size=15, aura_side="inside",
              mark=("Ready", "center") if name in ready else None, raid_mark={"Thryn": 1, "Lioren": 5}.get(name), shadow=shadow)


def stage(canvas, cx, cy, k):
    """Draws the frames around (cx, cy): the party on the left, the player and the target in the
    middle, three columns of raid frames on the right."""
    def at(x, y):
        return round(cx + x * k), round(cy + y * k)

    for index, member in enumerate(PARTY):
        left, top = at(-532, -104 + index * PARTY_PITCH)
        party_frame(canvas, left, top, k, member)

    # The player, with a cast under way; the target beside it with its debuffs and buffs above.
    left, top = at(-254, 6)
    player_frame(canvas, left, top, k, cast=("Holy Light", 0.62, "Holy Light"), mark=("Combat", "rim"))
    left, top = at(2, 6)
    target_frame(canvas, left, top, k, points=3)

    left, top = at(274, -104)
    raid_grid(canvas, left, top, k, RAID_20[:15])


# ---------------------------------------------------------------------------
# Emblem and title pictures
# ---------------------------------------------------------------------------
W, H = 1920, 1080


@functools.lru_cache(maxsize=None)
def logo(size=400):
    return make_art.emblem(size)


def hero(w=W, h=H, k=2.0, title_y=128, title_size=150, tagline_size=46, stage_y=500, note_size=18, chips=(),
         eye=0.36, figure=0.30, stand=0.88):
    """The emblem and the title, the frames, and behind them a dwarf in a forge hall (tools/forge_hall.py:
    a drawing of our own). `eye` is how far down the picture the hall's far end with its furnace
    lies, `figure` how tall the dwarf is as a share of the height, `stand` where his feet are: they
    are chosen so the furnace shows between the title and the frames and the dwarf stands under them."""
    canvas = forge_hall.hall(w, h, eye=eye, figure=figure, stand=stand)

    y, x = np.mgrid[0:h, 0:w].astype(np.float32)

    def veil(colour, strength):
        layer = np.zeros((h, w, 4), np.float32)
        layer[..., :3] = colour
        layer[..., 3] = np.clip(strength, 0, 1) * 255
        canvas.alpha_composite(Image.fromarray(layer.astype(np.uint8), "RGBA"))

    # Darker behind the lettering at the top and behind the small print at the foot.
    veil((8, 5, 8), np.clip(1 - y / (title_y + title_size * 1.25), 0, 1) ** 1.3 * 0.72)
    veil((8, 5, 8), np.clip((y - (h - 0.13 * h)) / (0.13 * h), 0, 1) ** 1.4 * 0.80)

    stage(canvas, w / 2, stage_y, k)

    # The emblem and the name side by side, the pair of them centred.
    size = title_size * 1.22
    path = brand.title_font_path()
    face = ImageFont.truetype(path, round(size)) if path else brand.font(size * 0.86, "Black")
    name_width = face.getlength(TITLE)
    badge = round(title_size * 1.30)
    gap = title_size * 0.14
    left = (w - (badge + gap + name_width)) / 2
    emblem = make_art.emblem(badge)
    pad = round(badge * 0.2)  # room for the shadow to fade out in, or its edge would show as a box
    shade = Image.new("L", (badge + 2 * pad, badge + 2 * pad), 0)
    shade.paste(emblem.getchannel("A").point(lambda v: int(v * 0.70)), (pad, pad))
    shadow = Image.new("RGBA", shade.size, (0, 0, 0, 255))
    shadow.putalpha(shade.filter(ImageFilter.GaussianBlur(badge * 0.04)))
    over(canvas, shadow, left - pad, title_y - badge / 2 - pad + badge * 0.05)
    over(canvas, emblem, left, title_y - badge / 2)
    brand.title_text(canvas, (left + badge + gap + name_width / 2, title_y), TITLE, size)
    brand.shadow_text(canvas, (w / 2, title_y + title_size * 0.85), TAGLINE, tagline_size, (244, 240, 232, 255), "SemiBold", spread=7)
    if chips:
        brand.pills(canvas, w / 2, h - 96, chips, 28, 58, (8, 10, 20, 170), (255, 255, 255, 76))
    brand.shadow_text(canvas, (w / 2, h - 26), note(), note_size, (214, 210, 204, 255), "Medium", spread=4, strength=0.9)
    return canvas


def gallery_hero():
    return hero(k=1.62, stage_y=560, chips=("Player, target, focus, pet, party and raid", "Keeps drawing in the middle of a fight",
                                    "Three looks, shareable profiles"))


def banner():
    return hero(1600, 600, 1.22, 74, 92, 29, 352, note_size=15, eye=0.42, figure=0.265, stand=0.925)


def social():
    return hero(1280, 640, 1.0, 84, 100, 28, 372, note_size=14, eye=0.42, figure=0.285, stand=0.935)


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


def frames():
    canvas = slide([("Seven frames, ", WHITE), ("yours to arrange.", GOLD)],
                   "Player, target, target of target, focus, pet, party and raid. Switch each off, size it, scale it, move it.")
    x0, y0, x1, y1 = 110, 330, 1810, 1000
    game_screen(canvas, (x0, y0, x1, y1))

    raid_grid(canvas, x0 + 40, y0 + 34, 1.0, RAID_20[:15])
    small_caps(canvas, (x0 + 40 + 276, y0 + 50), "Raid")
    brand.text(canvas, (x0 + 40 + 276, y0 + 78), "10, 20 or 40", 19, SOFT, "Medium", "lm")

    k = 1.12
    for index, member in enumerate(PARTY):
        party_frame(canvas, x0 + 40, y0 + 308 + index * round(PARTY_PITCH * k), k, member)
    small_caps(canvas, (x0 + 40 + round(200 * k) + 70, y0 + 308 + 3 * round(PARTY_PITCH * k) + 22), "Party")

    k = 1.4
    focus_frame(canvas, x0 + 660, y0 + 190, k)
    small_caps(canvas, (x0 + 660 + round(200 * k) + 18, y0 + 190 + 28), "Focus")

    frame(canvas, x0 + 454, y0 + 432, k, 124, 28, 4, "Ember", (0.35, 0.74, 0.38), 0.9, "FOCUS", 0.7)
    small_caps(canvas, (x0 + 454 + round(124 * k) / 2, y0 + 432 + 62), "Pet", anchor="mm")

    bottom = player_frame(canvas, x0 + 660, y0 + 420, k, cast=("Holy Light", 0.62, "Holy Light"), mark=("Rest", "rim"))
    small_caps(canvas, (x0 + 660 + round(232 * k) / 2, bottom + 26), "Player", anchor="mm")

    bottom = target_frame(canvas, x0 + 1014, y0 + 420, k, points=3)
    small_caps(canvas, (x0 + 1014 + round(232 * k) / 2, bottom + 26), "Target", anchor="mm")

    frame(canvas, x0 + 1014 + round(232 * k) + 16, y0 + 432, k, 140, 28, 4, "Halla", CLASS["PALADIN"], 0.71, "MANA", 0.58,
          surname="Brightmoor")
    small_caps(canvas, (x0 + 1014 + round(232 * k) + 16 + round(140 * k) / 2, y0 + 432 + 62), "Target of target", anchor="mm")
    return canvas


def groups():
    canvas = slide([("Your group, ", WHITE), ("at a glance.", GOLD)],
                   "Party and raid frames tell you who is hurt, who is being hit, who is out of reach, and whom you can help.")
    party = (70, 330, 1030, 1000)
    card(canvas, party, "Party", "buffs above, debuffs beside, cast bars if you like")
    k = 1.9
    told = [
        (PARTY[0], dict(), "Being attacked", "an outline, amber to red"),
        (PARTY[1], dict(share=0.55, health="1705", heal=0.22, absorb=0.14), "Healing on its way, a shield", "each drawn past the end of the health"),
        (PARTY[2], dict(share=0.80, health="2880", heal=0.0, auras=[("Viper Sting", "poison")]), "A debuff you can remove",
         "the frame lights up in its colour"),
        (PARTY[3], dict(), "Out of range", "the frame fades"),
    ]
    for index, (member, extra, title, sub) in enumerate(told):
        top = 468 + index * 132
        party_frame(canvas, 110, top, k, member, **extra)
        said(canvas, 110 + round(200 * k) + 112, top + 22, title, sub)

    raid = (1060, 330, 1850, 1000)
    card(canvas, raid, "Raid", "10, 20 or 40 players")
    rk = 1.95
    raid_grid(canvas, raid[0] + round((raid[2] - raid[0] - (3 * 88 + 82) * rk) / 2), 424, rk, RAID_20, ready=("Tamsin", "Pia"))
    brand.text(canvas, ((raid[0] + raid[2]) / 2, 902), "Drawn larger in a small raid", 27, WHITE, "Bold")
    brand.text(canvas, ((raid[0] + raid[2]) / 2, 942), "first name over surname, raid marks, ready checks, dead said in words", 21, SOFT, "Medium")
    return canvas


def combat():
    canvas = slide([("Built for ", WHITE), ("how Forever fights.", GOLD)],
                   "In a fight the game seals health, names, casts and auras from addons. These frames are written around that.")
    points = [
        ("Health, names and casts keep drawing", "What the game seals goes straight back to the game to be drawn."),
        ("Buffs and debuffs keep drawing", "The game's own aura container draws them, on buttons the addon dresses."),
        ("A late joiner gets a frame at once", "Party and raid are the game's own secure group frames."),
        ("Nothing of the game's is hooked", "Its menus are left alone, with controller play in mind."),
        ("It tells you when something is wrong", "/pug status lists any error it caught."),
    ]
    for index, (title, sub) in enumerate(points):
        point(canvas, 96, 408 + index * 118, title, sub)

    box = (1010, 330, 1850, 1000)
    card(canvas, box, "In the middle of a fight")
    k = 2.9
    left = box[0] + round((box[2] - box[0] - 232 * k) / 2)
    top = 640
    small_caps(canvas, (left, top - round(51 * k) - 22), "Debuffs rimmed by kind, its buffs above them")
    bottom = target_frame(canvas, left, top, k, cast=("Enrage", 0.48, "Enrage"), shield=True, threat=True)
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
    card(canvas, casts, "Cast bars", "player, target, focus, pet, party")
    k = 2.05
    rows = [("Holy Light", 0.62, "Holy Light", False, False, "a cast fills, a channel drains"),
            ("Enrage", 0.44, "Enrage", True, False, "a shield: cannot be interrupted"),
            ("Frostbolt", 0.7, "Frostbolt", False, True, "a moment in red")]
    for index, (spell, done, icon, shield, interrupted, told) in enumerate(rows):
        y = 778 + index * 70
        cast_bar(canvas, 110, y, k, 232, 18, spell, done, icon, shield, interrupted)
        brand.text(canvas, (110 + round(232 * k) + 26, y + round(18 * k) / 2), told, 21, SOFT, "Medium", "lm")

    where = (980, 680, 1850, 1000)
    card(canvas, where, "Icons where you want them", "a side for each kind")
    k = 1.3
    places = [("above", "right", "Buffs above"), ("below", "below", "Both below"), ("right", "right", "Both beside"), ("inside", "inside", "On the frame")]
    for index, (buff_side, debuff_side, name) in enumerate(places):
        left = where[0] + 36 + index * 208
        beside = "right" in (buff_side, debuff_side)
        width = 112 if beside else 136
        frame(canvas, left, 836, k, width, 40, 6, "Maeve", CLASS["MAGE"], 0.62, "MANA", 0.4,
              auras=[CURSE], buffs=[WIT, WILD] if buff_side != "right" else [WIT], aura_side=debuff_side, buff_side=buff_side,
              aura_size=20 if buff_side != "inside" else 15, per_row=3, font_size=11)
        brand.text(canvas, (left + round(136 * k) / 2, 968), name, 23, WHITE, "Bold")
    return canvas


def looks():
    canvas = slide([("Three looks. ", WHITE), ("Three textures.", GOLD)],
                   "Slate, Night and Hearth, with smooth, flat or glass bars: all drawn for this addon. Colour by class, by foe, or by health.")
    k = 2.2
    textures = [("Bar-Smooth", "Smooth"), ("Bar-Flat", "Flat"), ("Bar-Glass", "Glass")]
    people = [("PALADIN", "Halla", "Brightmoor", "human-female", 0.71, "MANA", 0.58, "3550", "2310"),
              ("SHAMAN", "Odda", "Stormcaller", "orc-male", 0.86, "MANA", 0.74, "4128", "3010"),
              ("DRUID", "Wren", "Thistledown", "nightelf-male", 0.48, "ENERGY", 0.9, "1920", "90")]
    for column, (theme_name, theme) in enumerate(THEMES.items()):
        box = (60 + column * 607, 330, 60 + column * 607 + 587, 1000)
        card(canvas, box, theme_name, "theme")
        left = box[0] + round((587 - 232 * k) / 2)
        for row, ((texture, texture_name), (cls, name, surname, who, share, power, power_share, health, power_text)) in enumerate(zip(textures, people)):
            top = 452 + row * 178
            small_caps(canvas, (left, top - 20), texture_name, DIM, 18)
            frame(canvas, left, top, k, 232, 46, 10, name, CLASS[cls], share, power, power_share, surname=surname, who=who, portrait="left",
                  level="60", health=health, power_text=power_text, theme=theme, texture=texture)
    return canvas


def arrange():
    canvas = slide([("Unlock, drag, ", WHITE), ("done.", GOLD)],
                   "A green handle appears on every frame. Sizes, colours, texts and icons are in the options, frame by frame.")
    box = (70, 330, 1180, 1000)
    card(canvas, box, "Every frame gets a handle", "/pug unlock")
    sx0, sy0, sx1, sy1 = box[0] + 34, box[1] + 92, box[2] - 34, box[3] - 34
    game_screen(canvas, (sx0, sy0, sx1, sy1))
    handles = [("Party", 36, 34, 200, 265), ("Pet", 250, 271, 124, 28), ("Focus", 386, 184, 200, 40),
               ("Player", 386, 262, 232, 46), ("Target of target", 894, 385, 140, 28)]

    def handle(name, x, y, w, h, alpha=90, edge=(115, 242, 178, 230)):
        left, top = sx0 + x, sy0 + y
        canvas.alpha_composite(Image.new("RGBA", (w, h), (64, 178, 128, alpha)), (left, top))
        ImageDraw.Draw(canvas).rectangle([left, top, left + w - 1, top + h - 1], outline=edge, width=2)
        if name:
            brand.text(canvas, (left + w / 2, top + h / 2), name, 21 if w >= 200 else 15, GOLD, "Bold")

    for name, x, y, w, h in handles:
        handle(name, x, y, w, h)
    # The target's handle on its way: where it was, the way it went, where it is now, and the pointer.
    was, now = (650, 262), (650, 376)
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
    commands = [("/pug", "open the options"), ("/pug unlock", "show the handles; /pug lock puts them away"),
                ("/pug reset target", "put a frame back as it started"), ("/pug profile", "your settings as text: copy, or paste"),
                ("/pug status", "the version, and any error it caught")]
    for index, (command, what) in enumerate(commands):
        y = 440 + index * 106
        brand.text(canvas, (side[0] + 40, y), command, 31, GOLD, "Bold", "lm")
        brand.text(canvas, (side[0] + 40, y + 40), what, 22, SOFT, "Medium", "lm")
    return canvas


# ---------------------------------------------------------------------------
# The description page
# ---------------------------------------------------------------------------
SIM_NOTE = ("Drawn by the addon's own code in a simulator of the game's interface, over a painted city. Not a screenshot of the game. "
            "Spell icons, raid marks, portraits and the elite dragon \u00a9 Blizzard Entertainment.")


def in_play():
    """The simulator's picture of the middle of a fight (tools/sim/run.sh writes docs/sim-screenshot.png),
    with a headline in its open sky and the line that says what it is. Every frame in it was drawn
    by the addon's code, not by this script."""
    path = os.path.join(DOCS, "sim-screenshot.png")
    canvas = Image.open(path).convert("RGBA")
    if canvas.size != (W, H):
        raise SystemExit("%s is %dx%d, not %dx%d: run tools/sim/run.sh first" % ((os.path.relpath(path, ROOT),) + canvas.size + (W, H)))
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    # A soft shade behind the headline, in the sky's own blue, and a darker strip for the small print.
    shade = np.zeros((H, W, 4), np.float32)
    shade[..., :3] = (8, 30, 70)
    shade[..., 3] = np.clip(1 - np.hypot((x - 1290) / 640, (y - 190) / 200), 0, 1) ** 1.3 * 0.46 * 255
    canvas.alpha_composite(Image.fromarray(shade.astype(np.uint8), "RGBA"))
    foot = np.zeros((H, W, 4), np.float32)
    foot[..., :3] = (8, 30, 70)
    foot[..., 3] = np.clip((y - (H - 0.11 * H)) / (0.11 * H), 0, 1) ** 1.4 * 0.82 * 255
    canvas.alpha_composite(Image.fromarray(foot.astype(np.uint8), "RGBA"))

    cx = 1290
    canvas.alpha_composite(logo().resize((56, 56), Image.LANCZOS), (cx - 196, 62))
    brand.shadow_text(canvas, (cx - 122, 91), TITLE, 30, WHITE, "Bold", "lm", spread=6)
    halo = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    brand.headline(halo, cx, 186, [("This is the addon ", (0, 0, 0, 200)), ("drawing.", (0, 0, 0, 200))], 78)
    canvas.alpha_composite(halo.filter(ImageFilter.GaussianBlur(9)))
    brand.headline(canvas, cx, 184, [("This is the addon ", WHITE), ("drawing.", GOLD)], 78)
    brand.shadow_text(canvas, (cx, 262), "Its own code, running beside Blizzard's interface in a simulator.", 30, (238, 240, 248, 255),
                      "Medium", spread=6)
    brand.shadow_text(canvas, (W / 2, H - 26), SIM_NOTE, 18, (206, 210, 224, 255), "Medium", spread=4, strength=0.9)
    return canvas


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
    "in-play": (in_play, os.path.join(GALLERY, "09-in-play.png")),
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
