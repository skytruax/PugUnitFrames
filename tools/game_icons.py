#!/usr/bin/env python3
"""The game's own spell icons and raid marks, for the pictures.

The icons are Blizzard Entertainment's artwork. They appear in the pictures the way they appear in
any screenshot of the game; they are not part of the addon and are not covered by this
repository's licence. For that reason the icon files are never committed: they are downloaded on
first use into tools/.icon-cache/ (git-ignored) from a public mirror of the game's interface art,
pinned to one commit so the pictures can be rebuilt the same way.

    python3 tools/game_icons.py     # fetch every icon the pictures use; writes nothing else

In the game the addon ships none of these either: it hands whatever icon the game names for an
aura or a cast straight to the game to draw. tools/make_listing.py --placeholders draws stand-ins
instead and needs none of this.
"""
import os
import sys
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, "tools", ".icon-cache")
# https://github.com/Gethe/wow-ui-textures, branch "classic": the same commit FreeControl's pictures use
MIRROR = "https://raw.githubusercontent.com/Gethe/wow-ui-textures/312a6e61bab69370c65ccc0a08f1075d62196294/"

# Spell -> its icon file in the mirror's ICONS folder (the file names are case-sensitive there).
FILES = {
    # casts
    "Holy Light": "Spell_Holy_HolyBolt.PNG",
    "Frostbolt": "Spell_Frost_FrostBolt02.PNG",
    "Shadow Bolt": "Spell_Shadow_ShadowBolt.PNG",
    "Enrage": "Ability_Druid_Enrage.PNG",
    # debuffs, by kind: magic
    "Frost Nova": "Spell_Frost_FrostNova.PNG",
    "Polymorph": "Spell_Nature_Polymorph.PNG",
    "Moonfire": "Spell_Nature_StarFall.PNG",
    # curse
    "Curse of Agony": "Spell_Shadow_CurseOfSargeras.PNG",
    "Curse of Weakness": "Spell_Shadow_CurseOfMannoroth.PNG",
    # disease
    "Devouring Plague": "Spell_Shadow_BlackPlague.PNG",
    # poison
    "Deadly Poison": "Ability_Rogue_DualWeild.PNG",
    "Viper Sting": "Ability_Hunter_AimedShot.PNG",
    # no kind
    "Sunder Armor": "Ability_Warrior_Sunder.PNG",
    "Rend": "Ability_Gouge.PNG",
    "Immolate": "Spell_Fire_Immolation.PNG",
    # buffs
    "Arcane Intellect": "Spell_Holy_MagicalSentry.PNG",
    "Mark of the Wild": "Spell_Nature_Regeneration.PNG",
    "Power Word: Fortitude": "Spell_Holy_WordFortitude.PNG",
    "Blessing of Might": "Spell_Holy_FistOfJustice.PNG",
    "Renew": "Spell_Holy_Renew.PNG",
    "Battle Shout": "Ability_Warrior_BattleShout.PNG",
}

# The eight raid marks, by the number the game gives each: star, circle, diamond, triangle, moon,
# square, cross, skull. They are in the mirror's TARGETINGFRAME folder, one file each.
MARKS = {
    1: "UI-RaidTargetingIcon_1.PNG", 2: "UI-RaidTargetingIcon_2.PNG", 3: "UI-RAIDTARGETINGICON_3.PNG",
    4: "UI-RaidTargetingIcon_4.PNG", 5: "UI-RaidTargetingIcon_5.PNG", 6: "UI-RaidTargetingIcon_6.PNG",
    7: "UI-RaidTargetingIcon_7.PNG", 8: "UI-RaidTargetingIcon_8.PNG",
}


def fetch(folder, filename):
    """Path of the cached copy of one of the mirror's files, downloading it first if it is not there."""
    target = os.path.join(CACHE, filename)
    if not os.path.exists(target):
        os.makedirs(CACHE, exist_ok=True)
        url = MIRROR + folder + "/" + filename
        with urllib.request.urlopen(url, timeout=30) as response:
            data = response.read()
        if not data.startswith(b"\x89PNG\r\n\x1a\n"):
            raise ValueError("%s did not return a PNG file" % url)
        partial = target + ".part"
        with open(partial, "wb") as handle:
            handle.write(data)
        os.replace(partial, target)
    return target


def icon(name):
    """The icon for a spell as an RGBA image (64 x 64, the size the game ships them in)."""
    return Image.open(fetch("ICONS", FILES[name])).convert("RGBA")


def mark(number):
    """One of the eight raid marks as an RGBA image."""
    return Image.open(fetch("TARGETINGFRAME", MARKS[number])).convert("RGBA")


if __name__ == "__main__":
    for spell in FILES:
        icon(spell)
    for number in MARKS:
        mark(number)
    print("%d icons and %d raid marks in %s" % (len(FILES), len(MARKS), os.path.relpath(CACHE, ROOT)))
    sys.exit(0)
