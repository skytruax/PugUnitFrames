#!/usr/bin/env python3
"""What the simulator needs to draw a scene with. tools/sim/run.sh calls this.

    python3 tools/sim/scene_art.py OUT_DIR FONT_DIR

The simulator has none of the game's art and cannot read a font out of an addon's folder: a spell
icon or a raid mark comes out as a blank square, there is no world behind the interface, and all
text is drawn in the fallback font of its image. This writes stand-ins for the picture into the
scratch copy of the addon that run.sh makes, never into the addon you ship:

    OUT_DIR/icons/<spell>.png   the game's own icons for the spells of the scene (tools/game_icons.py
                                fetches each once from a public mirror into tools/.icon-cache/)
    OUT_DIR/marks.png           the game's sheet of raid marks, put together from its eight marks
    OUT_DIR/backdrop.png        the painted city of the listing pictures (tools/brand.py), as a world
    OUT_DIR/../SimArt.lua       tells the scene (tests/sim/screenshot.lua) what is there
    FONT_DIR/*.ttf              the addon's own font under the names of the image's fallback fonts,
                                so the simulator letters the frames as the game will

Needs Pillow and numpy.
"""
import os
import re
import shutil
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tools"))  # the sibling modules, also under python -I
import brand  # noqa: E402
import game_icons  # noqa: E402

ADDON_FONT = os.path.join(ROOT, "FreeUnitFrames", "Fonts", "Inter-SemiBold.ttf")
# The fonts in the simulator's image (fonts-dejavu-core). It falls back to these for every text.
FALLBACK_FONTS = (
    "DejaVuSans.ttf", "DejaVuSans-Bold.ttf", "DejaVuSansMono.ttf", "DejaVuSansMono-Bold.ttf",
    "DejaVuSansMono-Oblique.ttf", "DejaVuSansMono-BoldOblique.ttf", "DejaVuSerif.ttf", "DejaVuSerif-Bold.ttf",
)
IN_GAME = "Interface\\\\AddOns\\\\FreeUnitFrames\\\\tests\\\\sim\\\\art\\\\"
SIZE = (1920, 1080)


def slug(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def icons(out):
    """Every spell icon the tools know, by the spell's name."""
    folder = os.path.join(out, "icons")
    os.makedirs(folder, exist_ok=True)
    written = {}
    for name in sorted(game_icons.FILES):
        game_icons.icon(name).save(os.path.join(folder, slug(name) + ".png"))
        written[name] = "icons\\\\" + slug(name) + ".png"
    return written


def marks(out):
    """The eight raid marks on one sheet, laid out as the game's own is: four to a row."""
    sheet = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    for number in range(1, 9):
        cell = game_icons.mark(number).resize((64, 64), Image.LANCZOS)
        sheet.alpha_composite(cell, (((number - 1) % 4) * 64, ((number - 1) // 4) * 64))
    sheet.save(os.path.join(out, "marks.png"))
    return "marks.png"


def backdrop(out):
    brand.landscape(*SIZE).convert("RGBA").save(os.path.join(out, "backdrop.png"))
    return "backdrop.png"


def fonts(folder):
    os.makedirs(folder, exist_ok=True)
    for name in FALLBACK_FONTS:
        shutil.copyfile(ADDON_FONT, os.path.join(folder, name))


def main(arguments):
    if len(arguments) != 2:
        sys.exit(__doc__)
    out, font_folder = arguments
    os.makedirs(out, exist_ok=True)
    listed = icons(out)
    sheet = marks(out)
    world = backdrop(out)
    fonts(font_folder)

    lines = ["-- Written by tools/sim/scene_art.py for one run of the simulator.", "FreeUnitFramesSimArt = {",
             '\tfolder = "%s",' % IN_GAME, '\tmarks = "%s",' % sheet, '\tbackdrop = "%s",' % world, "\ticons = {"]
    for name, path in sorted(listed.items()):
        lines.append('\t\t["%s"] = "%s",' % (name, path))
    lines += ["\t},", "}", ""]
    with open(os.path.join(os.path.dirname(out), "..", "..", "SimArt.lua"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))
    print("scene art: %d icons, the raid marks, a backdrop and the font" % len(listed))


if __name__ == "__main__":
    main(sys.argv[1:])
