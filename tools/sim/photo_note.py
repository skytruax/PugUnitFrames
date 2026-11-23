#!/usr/bin/env python3
"""Writes across the foot of a composite what it is. tools/sim/photos.sh calls this.

    python3 tools/sim/photo_note.py IN.png OUT.png

A picture of the game with the addon's frames on it looks like a screenshot and is not one: the
frames were drawn in the simulator. The line says so, large enough to be read at a glance.

Needs Pillow and numpy.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))  # tools/, for the brand's lettering
import brand  # noqa: E402

NOTE = (
    "Composite, not a screenshot: the frames were drawn by the addon's own code in a simulator and laid over a picture of the game.",
    "Picture, spell icons and raid marks \u00a9 Blizzard Entertainment.",
)


def main(arguments):
    if len(arguments) != 2:
        sys.exit(__doc__)
    source, out = arguments
    picture = Image.open(source).convert("RGBA")
    width, height = picture.size
    # As large as fits: the line has to be read at a glance, also when the picture is shown small.
    size = round(height * 0.0215)
    while size > 10 and max(brand.font(size, "SemiBold").getlength(line) for line in NOTE) > width * 0.94:
        size -= 1
    step = round(size * 1.45)
    band = step * len(NOTE) + round(size * 1.1)
    strip = np.zeros((height, width, 4), np.float32)
    rows = np.clip((np.arange(height, dtype=np.float32) - (height - band - step)) / step, 0, 1)
    strip[..., :3] = (6, 10, 18)
    strip[..., 3] = rows[:, None] * 0.86 * 255
    picture.alpha_composite(Image.fromarray(strip.astype(np.uint8), "RGBA"))
    for index, line in enumerate(NOTE):
        y = height - band + round(size * 0.9) + index * step
        brand.shadow_text(picture, (width / 2, y), line, size, (236, 238, 244, 255), "SemiBold", spread=4, strength=0.9)
    picture.convert("RGB").save(out)
    print("wrote", os.path.relpath(out))


if __name__ == "__main__":
    main(sys.argv[1:])
