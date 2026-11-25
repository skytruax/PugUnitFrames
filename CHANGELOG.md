# Changelog

## Not released yet

- **New starting settings.** A new profile, and a frame you reset, now starts with the settings the addon's author plays with:
    - larger frames (player and target at 115%, party at 120%, focus at 130%), with a taller power bar and cast bar on player and target;
    - health written as an amount on player, target and party;
    - cast bars and levels on the party, and party portraits that look towards the bars;
    - at most six buffs on the target, and no raid mark or combat mark on it;
    - no shadows under the frames;
    - raid frames switched off: in a raid you keep the game's own raid frames until you switch these on (Options > Frames > Raid > Show this frame).
- **Where the frames start.** On a wide screen (an interface scaled down, or an ultrawide monitor) they start in the author's arrangement: player at the left and target at the right of the fight, focus and pet out at the left edge, the party below the player. Where that does not fit, they start close together around the lower middle, as before, moved apart a little for their new sizes.
- **Settings you already have are not changed**: no frame of yours is moved, resized or switched off by this update. `/pug reset all` gives you the new starting settings if you want them.

## v0.3.3

- **The level is plain text again**, at the start of the line under the name with the dragon before it, exactly as it was before 0.3.2. The badge that 0.3.2 put on the portrait is still there for those who liked it, as a setting that starts switched off: "Level as a badge", Options > Frames > Text and portrait. Settings saved by 0.3.2 have it switched off once, since 0.3.2 had switched it on for everyone; if you want the badge, switch it on again.

Fixed, after a second reading of 0.3.2:

- Logging in or reloading in the middle of a fight, with the game slow to hand the addon's font over: the frames made when the fight ended were lettered in the game's font, while `/pug status` said the addon's was in use. They are made in the font the game has handed over by then.
- With the font set to the game's own, the addon's font file was still tried, and reported after ten minutes if the game would not take it. A font nobody asks for is left alone.
- Icons on the target of target (off unless you switch them on) were taken down and put up again four times a second, and the tooltip of the one under the mouse with them. Once a second now.
- A part of a frame that could not be made was made again at every change of a setting, each time leaving its pieces behind. It is tried once.
- The level's badge, on a frame without a portrait and with a low health bar, could hang a pixel over the bar's lower edge.

## v0.3.2

Fixed:

- **Buffs and debuffs in a fight.** In a fight this game does not let an addon ask which buffs and debuffs a unit has: every such question is an error (the line "Auras cannot be accessed when secret" in `/pug status`, hundreds of times in an evening), and the icons stood still until the fight was over. The icons are now drawn by the game's own aura container, which the game fills itself, in a fight and out of it, on buttons this addon dresses: icon, time left, stacks, and a rim in the colour of the debuff's kind. The light on a party or raid frame for a debuff you can remove works the same way. The tooltip on an icon is the game's own.
- **The addon's font.** The game can take its time before it hands an addon's font file over. Version 0.3.1 gave up after twelve seconds, lettered the frames in the game's font for the rest of the session and called it an error. The file is now asked for as the addon loads and tried again for as long as it takes, and the frames change to it the moment the game takes it. Only after ten minutes of refusals is anything said, once. `/pug status` has a "Font" line that says which font is in use and why.
- One part of a frame that fails no longer keeps the rest of that frame, or the frames laid out after it, from being set up; it is reported and left out.

New:

- **The level on a badge.** The player's and the target's level stands on a small dark tile at the foot of the portrait, the number and the rim in the colour of how hard the fight would be, gold for someone who cannot be fought. An elite's dragon and a rare creature's star are inside it, and the number then stands alone. On a frame without a portrait the badge starts the line the level was on. "Level as a badge" is a setting of each frame (Options > Frames > Text and portrait) and starts switched on; off, the level is plain text as before.

Good to know:

- Icons come in the game's order now, your own first.
- A change to the icons' size made in the middle of a fight is taken up when the fight ends: the game closes its aura buttons to addons while it keeps auras sealed.

## v0.3.1

- **Shields are drawn the way healing on its way is**: a pale stretch of bar that starts where the health ends (after the healing, when some is on its way) and is as long as the shield is large. It takes the place of the band along the top of the bar. Only as much of a shield is drawn as there is room for before the end of the bar; when there is more shield than room, a pale cap lights up on the bar's end. That cap is all a shield on someone at full health has to show, which is when a shield is usually cast. "Shields on the health bar" still switches it, frame by frame.

## v0.3.0

What you see when you log in has changed. Every part of it is a setting, and can be switched back.

- **First name and surname.** A character on Forever has both, and the frames wrote only the first. They write both now, as the game's own frames do. On a raid frame the surname has a line of its own under the first name. If you have the game hide your own surname, your own frame leaves it off as well. "Surname" is a setting of each frame.
- **Room for a whole name.** Where a frame has the height, the name has a line to itself, as wide as the health bar, with the level and the health number on the line under it and the power number on the power bar. A long creature name is written out where it used to be cut short, and the party frame starts wider so that two names of twelve letters fit beside a portrait.
- **Portraits** on the player, the target (at the right end, as the game has it), the focus and each party member. Options > Frames > Text and portrait.
- **A dragon beside the level of an elite or rare creature**: the game's own, as on its nameplates. Gold for an elite or a boss, silver for a rare elite, a star for a rare creature. The "+" and "R" after the level stay.
- **Questie's quest icon.** A creature that one of your quests needs carries the icon Questie puts on its nameplate, in the top right corner of the target, target of target and focus frames. It needs Questie to be installed. In a dungeon the game does not tell addons which creature a unit is, and there is no icon there.
- **The leader's mark, the role mark and the PvP flag start switched off**, and each has its own setting now (Options > Frames > Marks). Raid icons, resting, in combat and ready-check answers are as before.
- **Party: buffs above each member**, in a row as on the target, with the debuffs still beside the frame; and health written as an amount, not a percentage.
- Buffs and debuffs each have their own side of a frame ("Buffs go", "Debuffs go"), in place of one setting for both.
- The members of a group stand apart by the gap you set plus whatever stands between them (a row of icons, a cast bar), so one member's icons no longer lie on the next member's frame. A gap you had set by hand is taken down by what stood between the frames, so they stay as far apart as you had them.
- The target of target starts wider and without a health number, so that a name fits on it; the focus frame starts larger, with room for a portrait and a long name.
- On a frame with two lines of text a raid mark sits at the end of the name's line, clear of the name and of the icons above the frame, and the small marks on the frame's top edge stand over its portrait, clear of where the name begins.
- The frame settings have a fifth section, Marks.

Your settings: a setting you had never changed moves to its new starting value, and whatever you had chosen stays as you chose it. A party whose icons you had set up keeps them exactly as they were. There is no telling a setting left alone from one set to the same value on purpose, so if you had, say, kept portraits off deliberately, switch them off once more. Profile text exported from 0.2 can still be pasted in.

## v0.2.0

- A new name: Pug Unit Frames. It was Free Unit Frames, a name that turned out to be in use already. A pug is a small dog, and a PUG is a pick-up group. It is a homage to PitBull Unit Frames, which has not come to Forever, and it is not that project.
- The addon's folder is now `PugUnitFrames` and its command `/pug` (also `/puf` and `/pugunitframes`). Delete the old `FreeUnitFrames` folder: the addon says so at login if it is still there. Settings made under the old name are not carried over.
- A new emblem: a pug in the compass ring.

Fixed:

- With a controller, the menu the game opens on your target (inspect, trade, follow) closed the moment it opened. The game opens it as the menu of its own target frame, which this addon used to hide, and a menu closes when the frame it belongs to is not on screen. That frame is now set aside unseen instead of hidden, and the game shows it with your target as it always did.
- A shaman's totem slots could light up empty in a fight, and a totem whose time had run out could stay drawn until the fight ended. In a fight the game calls a slot taken for every element you have learnt; a slot is now drawn by the time left on it.
- A click on a frame with Shift, Ctrl or Alt held did nothing. It now targets, as a plain click does. A click you have bound to a spell, in the game's click casting or in an addon such as Clique, is cast as bound.
- The game's ping key did nothing with the mouse over a frame. It now pings whoever the frame shows.
- A cast bar could stay up for good when the game never said the cast had ended (a party member's Aimed Shot is the known case). A bar on show is now looked at again a few times a second and goes when its time is up.
- "The font could not be loaded" could be reported at login when the game was only slow to have the file ready. It is tried again a few times first, and the frames change to it when it arrives.
- The count of stacks on an icon could not be read on a bright icon. It is outlined now, whatever the text setting.
- The power number followed the bar in steps, and a combo point showed a moment late. Both now move with every tick on the frames you watch closely.
- A rare creature had no mark beside its level: it is now "23R", and "23R+" when it is elite as well.
- Someone else's kill was only grey when the bar was coloured by class or by friend and foe. It is grey however the bar is coloured.

New:

- Totems: a right click on one sends it away, in a fight too, and the mouse over one says what it is, as on the game's own totem frame.
- Shields that soak up damage (Power Word: Shield) show as a pale band along the top of the health bar, sized against full health, so it shows on someone at full health too.
- A druid in bear or cat form keeps a thin strip of mana under the form's bar.
- A hunter sees how the pet feels in a small face beside the pet frame: green, amber, or red when it is time to feed it.
- A flag on anyone marked for fighting other players, in their side's colour, and a mark for the part a group member plays (tank, healer, damage). The party can be put in that order: tanks first, then healers.
- A bright line around the party or raid frame of whoever you have targeted.
- The power bar of a creature that has no power to show is put away and its health bar takes the room (target, target of target and focus; a setting).
- The player's and the pet's frame can fade while nothing is going on (no fight, no target) and come back with a fight, a target or the mouse. One setting for how solid all frames are drawn. The player's frame can stay away while you are in a group.
- The game's own frames can stay hidden also where the frame here is switched off, for those who show themselves among the party frames and want no player frame at all.
- Bars can fill to the left or upwards. A bar can be turned round: dark, with the colour where health is missing. The portrait can be mirrored.
- Buffs can be limited to your own, as debuffs could. The time left on an icon can be shown as a number.
- The light for a debuff you can remove now pulses, so it is seen in a fight.
- The options show a frame's settings in four sections (Frame, Bars, Text and marks, Icons) instead of one long list.

## v0.1.1

- Nothing in the frames has changed. This is the first version built and published by the release workflow, to CurseForge and GitHub alike, and the addon now carries its CurseForge project id.

## v0.1.0

The first version.

- Frames for the player, the target, the target's target, the focus, the pet, the party, and the raid. Each can be switched off, sized, scaled and moved on its own; raid frames are drawn larger in raids of up to 10 and up to 20 players.
- Health and power bars, coloured by class, by friend or foe, by how full they are, or plain. Health and power as exact numbers, short numbers, a percentage, both, against the maximum, or as what is missing.
- Buffs and debuffs as icons with time left and stacks, debuffs rimmed in the colour of their kind, optionally only your own. A choice of where they go: above, below, left, right, or on the frame.
- Cast bars for the player, target, focus and pet: icon, spell name, a bright edge on the end of the fill, a shield when the cast cannot be interrupted, and a moment in red when it is.
- For party and raid: members out of range fade, an outline shows on whoever is being attacked, healing on its way shows past the end of the health bar, and a frame lights up in the colour of a debuff you can remove.
- Party frames can stay up when you are alone, with or without yourself among them, and your own party frame does not repeat your cast bar.
- With the game's target frame put away, picking and losing a target still makes the sounds it always has.
- Marks on the rim of a frame: raid icons, the leader, resting, in combat, ready-check answers, a resurrection on its way.
- Combo points on the target for rogues and druids. Totems under the player for shamans.
- Three themes (Slate, Night, Hearth) and three bar textures. Every plate casts a soft shadow, which can be switched off. The empty part of a bar is the bar's own colour, darkened, and very light class colours are taken down a little so the lettering stands out on them.
- Lettering in Inter, a typeface the addon brings with it (SIL Open Font License, in the `Fonts` folder). The game's own font can be chosen instead, and is used where the game runs in Korean or Chinese.
- Profiles: copy, switch per character, delete, and export or import as text.
- The game's own player, target, focus, pet, party and raid frames and its cast bar step aside while the matching frame here is in use. Each can be kept in the options.
- Commands: `/freeuf`, `/freeuf unlock`, `/freeuf lock`, `/freeuf reset`, `/freeuf profile`, `/freeuf status`.
- English, German, Spanish and French.
