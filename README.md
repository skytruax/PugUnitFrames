<p align="center">
  <img src="docs/banner.png" alt="Pug Unit Frames: the pug emblem and the name over a party of four, the player casting, a hostile target and a corner of a raid, in a forge hall where a dwarf stands with his hammer" width="100%">
</p>

<h1 align="center">Pug Unit Frames</h1>

<p align="center">
  <b>Clean, light unit frames for World of Warcraft: Forever.</b><br>
  You, your target and its target, focus, pet, party and raid: dark, thin and easy to read.<br>
  A pug is a small dog, and a PUG is a pick-up group. These are frames for both.
</p>

<p align="center">
  <a href="https://github.com/skytruax/PugUnitFrames/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/skytruax/PugUnitFrames?label=release&color=d9a441"></a>
  <a href="https://github.com/skytruax/PugUnitFrames/actions/workflows/tests.yml"><img alt="Tests" src="https://github.com/skytruax/PugUnitFrames/actions/workflows/tests.yml/badge.svg"></a>
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

<p align="center">
  <img src="docs/demo.gif" alt="A fight on the frames, moment by moment: the pull, the tank taking the hits, a party member poisoned while the player heals, the heal landing as a cast is interrupted, and the target nearly dead" width="900">
</p>

<p align="center"><sub>The moving picture is the addon's own code drawing a fight in a simulator of the game's interface, over a
painted city (<a href="#developing">how</a>). The picture at the top is an illustration built from the addon's own artwork.
Neither is a screenshot of the game. The spell icons, raid marks, portraits and the dragon beside an elite's level are
Blizzard's (the portraits are the faces the game shows until it has drawn a unit's own), and the title lettering is
LifeCraft, a typeface by Eliot Truelove.</sub></p>

---

## A homage, not the original

[PitBull Unit Frames 4.0](https://www.curseforge.com/wow/addons/pitbull-unit-frames-4-0), by
ckknight, shefkin and nebula169 ([source](https://github.com/nebularg/PitBull4)), is the dog-themed
unit frames addon a great many of us played with for years, and the credit for the idea belongs to
them. PitBull has not come to Forever, so here is a smaller dog in its honour.

Pug Unit Frames is **not that project** and has nothing to do with its authors. It is a new addon,
written from scratch, with none of PitBull's code or art in it. Until version 0.2 it was called
Free Unit Frames.

## Status

**0.3 changes what you see when you log in**: first name and surname, portraits, a dragon on
elites, Questie's quest icons, and a party with its buffs above each member
([changelog](CHANGELOG.md)). It passes both of its test suites (a model of the client that seals
values the way the game does, and a simulator running Blizzard's real interface code). Neither is
the game, so expect a rough edge. If something looks wrong in the game, `/pug status` lists any
error it caught: please open an issue with that text.

## What you get

<table>
  <tr>
    <td width="50%" valign="top">
      <img src="curseforge/web/02-frames.jpg" alt="A game screen with all seven frames labelled: raid, party, focus, pet, player, target, target of target">
      <b>Seven frames, yours to arrange.</b> Player, target, target of target, focus, pet, party,
      and raid for 10, 20 or 40. Each can be switched off, sized, scaled and moved on its own.
    </td>
    <td width="50%" valign="top">
      <img src="curseforge/web/03-groups.jpg" alt="Party frames with a threat outline, incoming heal, removable debuff and range fade, beside a raid of twenty">
      <b>Your group, at a glance.</b> An outline on whoever is being attacked, healing on its way
      past the end of the bar, a frame lit in the colour of a debuff you can remove, and members
      out of range faded.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <img src="curseforge/web/04-combat.jpg" alt="A checklist of what keeps working in a fight, beside a hostile target with debuffs, a threat outline and a shielded cast bar">
      <b>Built for how Forever fights.</b> In a fight the game seals health, names, casts and auras
      from addons. These frames are written around that, and a late joiner gets a frame at once.
    </td>
    <td width="50%" valign="top">
      <img src="curseforge/web/05-auras.jpg" alt="Debuff icons rimmed by kind, three cast bars, and the four places icons can go">
      <b>Buffs, debuffs and cast bars.</b> Icons with time left and stacks, debuffs rimmed in the
      colour of their kind, on the target only your own if you like. Cast bars with a shield on a
      cast that cannot be interrupted and a moment of red when one is.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <img src="curseforge/web/06-looks.jpg" alt="The same frames in the themes Slate, Night and Hearth, with smooth, flat and glass bars">
      <b>Three looks, three textures.</b> Slate, Night and Hearth, all drawn for this addon, lettered
      in Inter (which the addon brings with it; the game's own font is one setting away), with a
      soft shadow under every plate. Health coloured by class, by friend or foe, by how much is
      left, or plain; numbers exact, short, as a percentage, or as what is missing.
    </td>
    <td width="50%" valign="top">
      <img src="curseforge/web/07-arrange.jpg" alt="Green handles on the frames of a game screen, one being dragged, and the list of commands">
      <b>Unlock, drag, done.</b> A handle on every frame, and everything else in the options, frame
      by frame. Profiles can be copied, switched per character, and carried in and out as text.
    </td>
  </tr>
</table>

Also in there: portraits; a character's first name and surname, on a line of their own wherever a
frame has the height (first name over surname on a raid frame), which is also where a long creature
name fits; the game's dragon beside the level of an elite or rare creature (and the level on a
small badge at the foot of the portrait, for those who switch that on); Questie's icon on a
creature that one of your quests needs, if you run [Questie](https://github.com/Questie/Questie);
each party member's buffs in a row above the frame, as on the target; raid icons, resting, in
combat, ready-check answers and a resurrection on its way; the leader's crown, a mark for tank,
healer and damage and a flag on anyone marked for fighting players, each of them switched on if you
want it; shields drawn after the health as healing on its way is, with a pale cap on the end of
the bar when there is more shield than room; combo points on the target for rogues and
druids, a druid's mana under the form's bar, a hunter's pet's mood, and totems under the player for
shamans, sent away with a right click; party frames when you are alone, if you like to see yourself
there, in order of role if you like; a player frame that fades when nothing is going on; English,
German, Spanish and French.

A click on a frame targets the unit, with Shift, Ctrl or Alt held as well, and a right click opens
its menu. The game's ping key pings whoever a frame shows. Addons that bind spells to clicks on
unit frames find these frames where they look for them. With a controller, the menu the game opens
on your target works as it does without the addon: the game's own target frame, which that menu
belongs to, is set aside unseen and not hidden.

<sub>These six pictures are illustrations, not screenshots, drawn by <code>tools/make_listing.py</code>
from the addon's own textures and layout numbers, as the frames look since version 0.3. The spell icons,
raid marks, portraits and the elite dragon in them are Blizzard's.</sub>

## Install

1. Download the zip from the [latest release](https://github.com/skytruax/PugUnitFrames/releases/latest).
2. Unzip it into `World of Warcraft\_forever_\Interface\AddOns\`, so that you end up with
   `...\AddOns\PugUnitFrames\PugUnitFrames.toc`.
3. Start the game, or log out and in again if it is running.

The game's own player, target, focus, pet, party and raid frames and its cast bar step aside for the
ones this addon draws. Each can be kept: Options > AddOns > Pug Unit Frames.

## Settings

`/pug` opens the options.

| Command | What it does |
| --- | --- |
| `/pug` | open the options |
| `/pug unlock` | show a green box on every frame; drag one to move its frame |
| `/pug lock` | put the boxes away |
| `/pug reset <frame\|all>` | put a frame back where and how it started (`player`, `target`, `targettarget`, `focus`, `pet`, `party`, `raid`) |
| `/pug profile` | your settings as text to copy; paste someone else's to bring them in as a new profile |
| `/pug status` | version, what the game is sealing right now, and any errors caught this session |

Frames are protected by the game while you fight: they can be moved, sized, switched on and off only
out of combat. A change made in a fight is kept and happens when the fight ends.

## How it is built

On this client much of what a unit frame shows reaches an addon **sealed**: the game hands over a
value that can be passed on to be drawn, and that the addon may not read, compare or calculate with.
Health always is. Maximum health, power, names, classes, casts, auras, threat and range are under
conditions Blizzard documents.

Pug Unit Frames is written so that it never needs to know. Every such value goes straight from the
game function that answers it to a widget method that Blizzard documents as accepting sealed
values: a bar's value, a text, a texture, an alpha. Where something has to be decided on a number
the addon cannot see (which threat outline? how many combo points?), the deciding is given to the
game too: a row of bars, each running from one level to the next, which the game fills.

All of that lives in one file, [`Sealed.lua`](PugUnitFrames/Sealed.lua), and the test suite fails
if any other file calls a game function whose answer can be sealed. The list of those functions is
made from Blizzard's own API documentation.

Buffs and debuffs are the exception, because for them there is no sealed answer to pass on: while
the game keeps auras sealed, an addon that so much as asks which auras a unit has gets an error.
What the game offers instead is its own aura container, a frame an addon creates and sets up (which
unit, which auras, how many, in what rows) and the game fills itself. This addon gives each of the
container's buttons its parts as the game creates it (an icon, a sweep for the time left, a count,
a rim) and never learns what any aura is. [`Elements/Auras.lua`](PugUnitFrames/Elements/Auras.lua)
is all of it.

The frames are the game's secure unit buttons, and party and raid are its secure group headers, so
they keep working in combat, including for someone who joins in the middle of a fight. No library
and no other addon's code is included, the game's menus are left alone, and none of its code is
hooked. The game's own frames are put away as the addon loads, before any of them has come up, so
that none of their code runs on the addon's account: on this client that is what keeps protected
actions, a controller's among them, from being refused later.

## Developing

```
PugUnitFrames/        the addon: what goes into Interface/AddOns
  Sealed.lua           the one place that touches values the game can seal
  Frame.lua            the plate, the events, and the layout every frame shares
  Elements/            one file per thing a frame shows
  Units.lua Group.lua  the single frames; the party and raid headers
tools/
  tests/               the model of the client and the scenarios run against it
  sim/                 the simulator run: Blizzard's real interface code, in Docker
    run.sh demo.sh     the tests and the picture; the moving demo
    menu.sh            opens the target's menu the way the game's controller mode does
    photos.sh          the picture over photographs of your own, each marked as a composite
    scene_art.py       what a picture needs that the simulator lacks: icons, raid marks, portraits, a world, the font
  make_art.py          draws every texture the addon ships
  make_listing.py      draws the banner, the logo and the store pictures
  forge_hall.py        the dwarf in his forge hall behind the title pictures: a drawing of our own
  game_icons.py        fetches the game's own spell icons, raid marks, portraits and dragons those pictures show
  brand.py             the look those pictures share with FreeControl's
  sealed_list.py       makes tools/sealed_apis.txt from Blizzard's API documentation
```

Two test suites, neither needing the game:

```
pip install lupa==2.8
python3 tools/tests/run.py           # a model of the client that seals values; also checks the source
tools/sim/lab/build-image.sh         # once: fetches the simulator and builds its Docker image
tools/sim/run.sh                     # Blizzard's interface code with the addon loaded; takes a picture
tools/sim/menu.sh                    # the controller's menu on the target: does it stay open?
tools/sim/demo.sh                    # the same fight, moment by moment: docs/demo.gif
tools/sim/photos.sh                  # the same fight over pictures of your own (tools/sim/backdrops/)
```

Neither is the game. The model is written from Blizzard's documentation and the simulator does not
seal values, so anything that depends on how the live client behaves is confirmed by playing.

<p align="center">
  <img src="docs/sim-screenshot.png" alt="The frames as the simulator draws them in the middle of a fight: a party of four with a threat outline, a removable debuff and a member out of range, a focus casting, the player healing, and a hostile elite target with its debuffs and a cast that cannot be interrupted" width="900">
</p>

<p align="center"><sub>The addon's own code drawing beside Blizzard's interface code in the simulator. The simulator has
none of the game's art and no world, and reads no font from an addon's folder, so the scene
(<code>tools/sim/tests/sim/screenshot.lua</code>) hands it the game's icons for its spells, the raid marks, the game's stand-in
portraits and its elite dragon, a painted city and the addon's own font, and answers the game functions the simulator has no handle for: other units' casts
and power, threat, range. The simulator knows no auras for the scene's people either, so the scene puts them on the addon's buttons itself, in the rows the game's
aura container lays them in. Blizzard's own interface, bare without its art, is put away.</sub></p>

The pictures and textures are drawn by scripts too (`pip install pillow numpy`):

```
python3 tools/make_art.py            # the textures in PugUnitFrames/Art
python3 tools/make_listing.py        # docs/banner.png, docs/social.png, the logo, curseforge/gallery
```

The pictures show the game's own spell icons, raid marks, stand-in portraits and elite dragon, as the
frames show the game's art in the game. Those
are Blizzard Entertainment's and are not part of this repository: `tools/game_icons.py` fetches
them into a git-ignored folder from a [public mirror](https://github.com/Gethe/wow-ui-textures) of
the game's interface art when the pictures are built (`--placeholders` draws stand-ins instead).
The addon itself ships no icon: it hands whatever the game names back to the game to draw.

## Licence

MIT. See [LICENSE](LICENSE).

The addon brings one thing that is not ours: the typeface its frames are lettered in,
[Inter](https://github.com/rsms/inter) by the Inter Project Authors, under the SIL Open Font
License 1.1. The font file is unchanged and its licence is beside it
([PugUnitFrames/Fonts](PugUnitFrames/Fonts)).

The simulator the tests use is a separate project under GPL-3.0
([wow-ui-sim](https://github.com/Osso/wow-ui-sim)); nothing of it is part of the addon.
