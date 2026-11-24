# Changelog

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
