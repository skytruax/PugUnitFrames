<p align="center">
  <img src="docs/banner.png" alt="Free Unit Frames: a party of four, the player casting, a hostile target and a corner of a raid" width="100%">
</p>

<h1 align="center">Free Unit Frames</h1>

<p align="center">
  <b>Clean, light unit frames for World of Warcraft: Forever.</b><br>
  You, your target and its target, focus, pet, party and raid: dark, thin and easy to read.
</p>

<p align="center">
  <a href="https://github.com/skytruax/FreeUnitFrames/actions/workflows/tests.yml"><img alt="Tests" src="https://github.com/skytruax/FreeUnitFrames/actions/workflows/tests.yml/badge.svg"></a>
  <img alt="World of Warcraft: Forever 1.60.1" src="https://img.shields.io/badge/WoW%20Forever-1.60.1-3b82c4">
  <a href="LICENSE"><img alt="Licence: MIT" src="https://img.shields.io/badge/licence-MIT-3fa55b"></a>
</p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="#what-you-get">What you get</a> ·
  <a href="#settings">Settings</a> ·
  <a href="#how-it-is-built">How it is built</a> ·
  <a href="#developing">Developing</a>
</p>

<p align="center"><sub>The picture above is an illustration built from the addon's own artwork, not a screenshot. The
spell icons and raid marks in it are Blizzard's, and its title lettering is LifeCraft, a typeface by Eliot Truelove.</sub></p>

---

## Status

**0.1.0 is the first version.** It passes both of its test suites (a model of the client that seals
values the way the game does, and a simulator running Blizzard's real interface code), and it has
only just started to be played. If something looks wrong in the game, `/freeuf status` lists any
error it caught: please open an issue with that text.

## What you get

- **Seven frames**: player, target, target of target, focus, pet, party, and raid for 10, 20 or
  40 players. Each can be switched off, sized, scaled and moved on its own.
- **Health and power bars** coloured by class, by friend or foe, by how much health is left, or
  plain. Health and power as exact numbers, short numbers, a percentage, or what is missing.
- **Buffs and debuffs** as icons with their time left and stacks, debuffs rimmed in the colour of
  their kind. On the target, optionally only your own.
- **Cast bars** for player, target, focus and pet, with a shield on a cast that cannot be
  interrupted and a moment of red when one is.
- **For groups**: members out of range fade, an outline appears on whoever is being attacked,
  healing on its way shows past the end of the health bar, and a frame lights up in the colour of
  a debuff you can remove.
- **Marks**: raid icons, the leader's crown, resting, in combat, ready-check answers, and a
  resurrection on its way.
- **Combo points** on the target for rogues and druids, **totems** under the player for shamans.
- **Three looks** (Slate, Night, Hearth) and three bar textures, all drawn for this addon.
- **Party frames when alone**, if you like to see yourself there, and no second copy of your own
  cast bar on your own party frame.
- **Profiles** you can copy, switch per character, and carry in and out of the game as text.
- English, German, Spanish and French.

A click on a frame targets the unit, a right click opens its menu, and addons that bind spells to
clicks on unit frames find these frames where they look for them.

## Install

Copy the `FreeUnitFrames` folder into `World of Warcraft/_forever_/Interface/AddOns/` and start the
game, or log out and in again if it is running.

The game's own player, target, focus, pet, party and raid frames and its cast bar step aside for the
ones this addon draws. Each can be kept: Options > AddOns > Free Unit Frames.

## Settings

`/freeuf` opens the options.

| Command | What it does |
| --- | --- |
| `/freeuf` | open the options |
| `/freeuf unlock` | show a green box on every frame; drag one to move its frame |
| `/freeuf lock` | put the boxes away |
| `/freeuf reset <frame\|all>` | put a frame back where and how it started (`player`, `target`, `targettarget`, `focus`, `pet`, `party`, `raid`) |
| `/freeuf profile` | your settings as text to copy; paste someone else's to bring them in as a new profile |
| `/freeuf status` | version, what the game is sealing right now, and any errors caught this session |

Frames are protected by the game while you fight: they can be moved, sized, switched on and off only
out of combat. A change made in a fight is kept and happens when the fight ends.

## How it is built

On this client much of what a unit frame shows reaches an addon **sealed**: the game hands over a
value that can be passed on to be drawn, and that the addon may not read, compare or calculate with.
Health always is. Maximum health, power, names, classes, casts, auras, threat and range are under
conditions Blizzard documents.

Free Unit Frames is written so that it never needs to know. Every such value goes straight from the
game function that answers it to a widget method that Blizzard documents as accepting sealed
values: a bar's value, a text, a texture, an alpha. Where something has to be decided on a number
the addon cannot see (which threat outline? how many combo points?), the deciding is given to the
game too: a row of bars, each running from one level to the next, which the game fills.

All of that lives in one file, [`Sealed.lua`](FreeUnitFrames/Sealed.lua), and the test suite fails
if any other file calls a game function whose answer can be sealed. The list of those functions is
made from Blizzard's own API documentation.

The frames are the game's secure unit buttons, and party and raid are its secure group headers, so
they keep working in combat, including for someone who joins in the middle of a fight. No library
and no other addon's code is included, the game's menus are left alone, and none of its code is
hooked. The game's own frames are put away as the addon loads, before any of them has come up, so
that none of their code runs on the addon's account: on this client that is what keeps protected
actions, a controller's among them, from being refused later.

## Developing

```
FreeUnitFrames/        the addon: what goes into Interface/AddOns
  Sealed.lua           the one place that touches values the game can seal
  Frame.lua            the plate, the events, and the layout every frame shares
  Elements/            one file per thing a frame shows
  Units.lua Group.lua  the single frames; the party and raid headers
tools/
  tests/               the model of the client and the scenarios run against it
  sim/                 the simulator run: Blizzard's real interface code, in Docker
  make_art.py          draws every texture the addon ships
  make_listing.py      draws the banner, the logo and the store pictures
  game_icons.py        fetches the game's own spell icons and raid marks those pictures show
  brand.py             the look those pictures share with FreeControl's
  sealed_list.py       makes tools/sealed_apis.txt from Blizzard's API documentation
```

Two test suites, neither needing the game:

```
pip install lupa==2.8
python3 tools/tests/run.py           # a model of the client that seals values; also checks the source
tools/sim/lab/build-image.sh         # once: fetches the simulator and builds its Docker image
tools/sim/run.sh                     # Blizzard's interface code with the addon loaded; takes a screenshot
```

Neither is the game. The model is written from Blizzard's documentation and the simulator does not
seal values, so anything that depends on how the live client behaves is confirmed by playing.

<p align="center">
  <img src="docs/sim-screenshot.png" alt="The frames as the simulator draws them: a party of four, the player with a cast bar, and a hostile elite target" width="820">
</p>

<p align="center"><sub>The addon running beside Blizzard's interface code in the simulator, which has none of the game's
fonts or spell icons: the lettering is not the game's and the blank squares are icons.</sub></p>

The pictures and textures are drawn by scripts too (`pip install pillow numpy`):

```
python3 tools/make_art.py            # the textures in FreeUnitFrames/Art
python3 tools/make_listing.py        # docs/banner.png, docs/social.png, the logo, curseforge/gallery
```

The pictures show the game's own spell icons and raid marks, as the frames do in the game. Those
are Blizzard Entertainment's and are not part of this repository: `tools/game_icons.py` fetches
them into a git-ignored folder from a [public mirror](https://github.com/Gethe/wow-ui-textures) of
the game's interface art when the pictures are built (`--placeholders` draws stand-ins instead).
The addon itself ships no icon: it hands whatever the game names back to the game to draw.

## Licence

MIT. See [LICENSE](LICENSE). The simulator the tests use is a separate project under GPL-3.0
([wow-ui-sim](https://github.com/Osso/wow-ui-sim)); nothing of it is part of the addon.
