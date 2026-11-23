#!/usr/bin/env python3
"""Joins the simulator's pictures of the fight into the moving demo. tools/sim/demo.sh calls this.

    python3 tools/sim/demo_gif.py OUT.gif MOMENT-1.png MOMENT-2.png ...

Each picture is cut to its middle, brought down to the demo's size, and given the line that says
what it is. The GIF holds the first picture whole and, of each later one, only the pixels that
differ from the one before, which keeps a painted backdrop from being stored five times.

Needs Pillow and numpy.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE)))  # tools/, for the brand's lettering
import brand  # noqa: E402

CUT = (96, 54, 1824, 1026)  # of a 1920 x 1080 picture: the frames with a margin, still 16:9
SIZE = (1200, 675)
# How long each moment stays, in milliseconds. The third is the thick of it and is given longer.
HOLD = (1400, 1400, 2400, 1700, 1700)
NOTE = "Drawn by the addon's own code in a simulator of the game's interface, over a painted city. Spell icons and raid marks © Blizzard Entertainment."
KEEP = 255  # the palette entry that means: leave what the picture before had here


def moment(path):
    picture = Image.open(path).convert("RGB").crop(CUT).resize(SIZE, Image.LANCZOS).convert("RGBA")
    # A darker strip along the bottom for the small print, as on the listing's pictures.
    width, height = picture.size
    strip = np.zeros((height, width, 4), np.float32)
    rows = np.clip((np.arange(height, dtype=np.float32) - (height - 0.11 * height)) / (0.11 * height), 0, 1) ** 1.4
    strip[..., :3] = (8, 30, 70)
    strip[..., 3] = rows[:, None] * 0.80 * 255
    picture.alpha_composite(Image.fromarray(strip.astype(np.uint8), "RGBA"))
    brand.shadow_text(picture, (width / 2, height - 17), NOTE, 13, (214, 218, 230, 255), "Medium", spread=3, strength=0.9)
    return picture.convert("RGB")


def main(arguments):
    if len(arguments) < 2:
        sys.exit(__doc__)
    out, paths = arguments[0], arguments[1:]
    pictures = [moment(path) for path in paths]

    # One palette for the whole demo, taken from all the moments side by side, with one entry kept
    # free for "leave as it was". An octree spreads the colours over what is there; a median cut
    # shares them out by area, gives nearly all of them to the sky, and turns the cast bars beige.
    sheet = Image.new("RGB", (SIZE[0] * len(pictures), SIZE[1]))
    for index, picture in enumerate(pictures):
        sheet.paste(picture, (index * SIZE[0], 0))
    palette = sheet.quantize(colors=KEEP, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)

    frames = []
    before = None
    for picture in pictures:
        indexed = np.array(picture.quantize(palette=palette, dither=Image.Dither.FLOYDSTEINBERG))
        now = np.asarray(picture, np.int16)
        if before is not None:
            same = np.abs(now - before).max(axis=2) == 0
            indexed[same] = KEEP
        before = now
        frame = Image.fromarray(indexed.astype(np.uint8), "P")
        frame.putpalette(palette.getpalette())
        frames.append(frame)

    hold = [HOLD[index] if index < len(HOLD) else HOLD[-1] for index in range(len(frames))]
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=hold, loop=0, disposal=1,
                   transparency=KEEP, optimize=False)
    print("wrote %s: %d moments, %d KB" % (os.path.relpath(out), len(frames), os.path.getsize(out) // 1024))


if __name__ == "__main__":
    main(sys.argv[1:])
