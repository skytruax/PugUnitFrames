local ADDON, ns = ...

-- Every setting: what it starts as and what it may hold. The same description checks the saved
-- file when it is loaded, checks a set of settings a player pastes in, and tells the options
-- page which controls to draw.
local Defaults = {}
ns.Defaults = Defaults

local L = ns.L

-- The frames, in the order they are listed everywhere.
Defaults.KINDS = { "player", "target", "targettarget", "focus", "pet", "party", "raid" }

local LABELS = {
	player = "Player",
	target = "Target",
	targettarget = "Target of target",
	focus = "Focus",
	pet = "Pet",
	party = "Party",
	raid = "Raid",
}

function Defaults.Label(kind)
	return L[LABELS[kind]]
end

---------------------------------------------------------------------------
-- What a setting may hold
---------------------------------------------------------------------------
local function Bool() return { type = "bool" } end
local function Number(low, high, step) return { type = "number", low = low, high = high, step = step or 1 } end
local function Choice(...) return { type = "choice", choices = { ... } } end

-- Settings of the whole profile.
Defaults.GENERAL_SPEC = {
	theme = Choice("slate", "night", "hearth"),
	texture = Choice("smooth", "flat", "glass"),
	font = Choice("inter", "game"), -- the lettering: the addon's own font, or the game's
	fontSize = Number(8, 18, 1),
	outline = Bool(),      -- outlined text instead of a soft shadow
	shadows = Bool(),      -- a soft shadow under every plate
	smooth = Bool(),       -- bars glide to a new value instead of jumping
	farAlpha = Number(0.2, 0.9, 0.05), -- how see-through a group member out of range becomes
	alpha = Number(0.2, 1, 0.05),      -- how solid every frame is drawn
	auraTimers = Bool(),   -- the time left on buff and debuff icons as a number, not only as a sweep
	locked = Bool(),
	tooltips = Choice("always", "calm", "never"), -- the game's unit tooltip when the mouse is over a frame; calm = out of combat
	hideAll = Bool(),      -- the game's own frames stay hidden also where ours for them is switched off
}
Defaults.GENERAL_ORDER = {
	"theme", "texture", "font", "fontSize", "outline", "shadows", "smooth", "alpha", "farAlpha", "auraTimers", "tooltips",
}

Defaults.GENERAL = {
	theme = "slate",
	texture = "smooth",
	font = "inter",
	fontSize = 11,
	outline = false,
	shadows = false,
	smooth = true,
	farAlpha = 0.45,
	alpha = 1,
	auraTimers = false,
	locked = true,
	tooltips = "always",
	hideAll = false,
}

-- Which of the game's own frames step aside. Each is only hidden while ours for it is enabled,
-- unless the player asks for all of them to stay hidden regardless (hideAll, above).
Defaults.HIDE_ORDER = { "player", "target", "focus", "pet", "party", "raid", "castbar" }
Defaults.HIDE = { player = true, target = true, focus = true, pet = true, party = true, raid = true, castbar = true }

-- Settings a frame can have. A frame has the ones its defaults list, and no others.
Defaults.UNIT_SPEC = {
	enabled = Bool(),
	x = Number(-4000, 4000, 1),       -- from the middle of the screen to the frame's anchor point
	y = Number(-4000, 4000, 1),
	width = Number(40, 500, 2),
	height = Number(14, 160, 1),
	scale = Number(0.5, 2, 0.05),
	powerHeight = Number(0, 30, 1),   -- 0: no power bar
	hideNoPower = Bool(),             -- no power bar for something that has no power to show
	color = Choice("class", "reaction", "health", "plain"), -- what colours the health bar
	invert = Bool(),                  -- a dark bar, with the colour where health is missing
	fill = Choice("right", "left", "up"), -- which way the bars fill
	healthText = Choice("none", "value", "short", "percent", "both", "max", "deficit"),
	powerText = Choice("none", "value", "short", "percent", "max"),
	name = Bool(),
	surname = Bool(),                 -- a character's surname after the first name (under it on a narrow frame)
	level = Bool(),
	levelBadge = Bool(),              -- the level on a small plate of its own, on the portrait where there is one; off unless asked for
	portrait = Choice("none", "left", "right"),
	mirror = Bool(),                  -- the portrait turned to look the other way
	buffs = Number(0, 32, 1),         -- how many buff icons at most; 0: none
	debuffs = Number(0, 32, 1),
	auraSize = Number(10, 44, 1),
	auraPerRow = Number(1, 20, 1),
	buffSide = Choice("below", "above", "right", "left", "inside"),   -- where the buff icons stand
	debuffSide = Choice("below", "above", "right", "left", "inside"), -- and the debuff icons
	myBuffs = Bool(),                 -- of the buffs, only the ones the player cast
	myDebuffs = Bool(),               -- of the debuffs, only the ones the player put there
	castbar = Bool(),
	castHeight = Number(6, 30, 1),
	castLocked = Bool(),              -- a cast that cannot be interrupted in a greyed orange, not the cast's gold
	threat = Bool(),                  -- an outline while the unit is being attacked
	range = Bool(),                   -- fade a group member who is out of range
	heals = Bool(),                   -- healing on its way, past the end of the health bar
	absorbs = Bool(),                 -- shields that soak up damage, drawn after the health as healing on its way is
	marks = Bool(),                   -- raid mark, resting, in combat, ready check, resurrection
	leader = Bool(),                  -- the group leader's mark
	role = Bool(),                    -- tank, healer or damage
	pvp = Bool(),                     -- a flag on someone marked for fighting other players
	elite = Bool(),                   -- a dragon beside the level of an elite or rare creature
	quest = Bool(),                   -- Questie's icon on a creature that a quest of the player's needs
	happiness = Bool(),               -- a hunter's pet: how it feels
	highlight = Bool(),               -- a bright line around the group member the player has targeted
	calm = Number(0.1, 1, 0.05),      -- how solid the frame is drawn outside a fight with no target; 1: always in full
	hideInGroup = Bool(),             -- the player's frame stays away while in a party or raid
	dispel = Bool(),                  -- light the frame up in the colour of a debuff the player can remove
	points = Bool(),                  -- combo points on the target
	totems = Bool(),                  -- the player's totems
	-- groups
	growth = Choice("down", "up", "right", "left"), -- where the next member goes
	spacing = Number(0, 40, 1),
	showPlayer = Bool(),              -- the player among the party
	showSolo = Bool(),                -- the party frames with only the player on them, when not in a group
	byRole = Bool(),                  -- party: tanks first, then healers, then the rest
	perColumn = Number(1, 40, 1),     -- raid: members before the next column starts
	columnGrowth = Choice("right", "left", "down", "up"),
	columnSpacing = Number(0, 60, 1),
	scaleSmall = Number(0.5, 2, 0.05), -- raid: how much larger the frames are with up to 10 players
	scaleMid = Number(0.5, 2, 0.05),   -- raid: ... with up to 20
}

-- The options page shows a frame's settings a section at a time, in this order (it has the
-- sections' names).
Defaults.UNIT_SECTIONS = {
	{ key = "frame", keys = {
		"enabled", "width", "height", "scale", "calm", "hideInGroup",
		"growth", "spacing", "showPlayer", "showSolo", "byRole", "perColumn", "columnGrowth", "columnSpacing", "scaleSmall", "scaleMid",
	} },
	{ key = "bars", keys = {
		"color", "invert", "fill", "powerHeight", "hideNoPower", "heals", "absorbs", "castbar", "castHeight", "castLocked", "points", "totems",
	} },
	{ key = "text", keys = {
		"name", "surname", "level", "levelBadge", "healthText", "powerText", "portrait", "mirror",
	} },
	{ key = "marks", keys = {
		"marks", "leader", "role", "pvp", "elite", "quest", "happiness", "threat", "range", "highlight", "dispel",
	} },
	{ key = "icons", keys = {
		"buffs", "buffSide", "myBuffs", "debuffs", "debuffSide", "myDebuffs", "auraSize", "auraPerRow",
	} },
}

-- Every setting of a frame, in the order of the sections.
Defaults.UNIT_ORDER = {}
for _, section in ipairs(Defaults.UNIT_SECTIONS) do
	for _, key in ipairs(section.keys) do
		Defaults.UNIT_ORDER[#Defaults.UNIT_ORDER + 1] = key
	end
end

-- How each frame starts out. Version 0.3 changed some of this (portraits, the party's buffs and
-- health numbers, room for long names): Defaults.Migrate below brings older profiles along.
-- Version 0.3.4 changed more of it, to the settings the addon's author plays with: larger
-- frames, health as an amount, cast bars and levels on the party, no shadows, no raid frames
-- unless they are switched on. That is for new settings only (a new profile, a reset): what a
-- player already has is left as it is, sizes and places included.
--
-- The places here (x, y) are the close arrangement, which fits a screen of 1365 by 768 units
-- (16:9 at the game's own interface scale). A wider screen starts with the frames further apart:
-- see WIDE_PLACES below.
Defaults.UNITS = {
	player = {
		enabled = true, x = -290, y = -210, width = 232, height = 46, scale = 1.15, powerHeight = 12,
		color = "class", healthText = "value", powerText = "value", name = true, surname = true, level = true, levelBadge = false, portrait = "left",
		buffs = 0, debuffs = 0, myDebuffs = false, auraSize = 22, auraPerRow = 9, buffSide = "above", debuffSide = "above",
		castbar = true, castHeight = 20, castLocked = false, threat = true, heals = true, marks = true, totems = true,
		leader = false, role = false, pvp = false,
		invert = false, fill = "right", mirror = false, myBuffs = false, absorbs = true, calm = 1, hideInGroup = false,
	},
	target = {
		enabled = true, x = 290, y = -210, width = 232, height = 46, scale = 1.15, powerHeight = 12,
		color = "class", healthText = "value", powerText = "value", name = true, surname = true, level = true, levelBadge = false, portrait = "right",
		buffs = 6, debuffs = 18, myDebuffs = false, auraSize = 22, auraPerRow = 9, buffSide = "above", debuffSide = "above",
		castbar = true, castHeight = 20, castLocked = true, marks = false, points = true,
		leader = false, role = false, pvp = false, elite = true, quest = true,
		invert = false, fill = "right", mirror = false, myBuffs = false, absorbs = true, hideNoPower = true,
	},
	targettarget = {
		enabled = true, x = 504, y = -219, width = 140, height = 28, scale = 1, powerHeight = 4,
		color = "class", healthText = "none", powerText = "none", name = true, surname = true, level = false, levelBadge = false, portrait = "none",
		buffs = 0, debuffs = 0, myDebuffs = false, auraSize = 18, auraPerRow = 6, buffSide = "below", debuffSide = "below",
		marks = true, leader = false, role = false, pvp = false, elite = true, quest = true,
		invert = false, fill = "right", mirror = false, myBuffs = false, absorbs = true, hideNoPower = true,
	},
	focus = {
		enabled = true, x = -250, y = -125, width = 200, height = 40, scale = 1.3, powerHeight = 6,
		color = "class", healthText = "percent", powerText = "none", name = true, surname = true, level = false, levelBadge = false, portrait = "left",
		buffs = 0, debuffs = 6, myDebuffs = false, auraSize = 20, auraPerRow = 8, buffSide = "above", debuffSide = "above",
		castbar = true, castHeight = 12, castLocked = true, marks = true,
		leader = false, role = false, pvp = false, elite = true, quest = true,
		invert = false, fill = "right", mirror = false, myBuffs = false, absorbs = true, hideNoPower = true,
	},
	pet = {
		enabled = true, x = -496, y = -219, width = 124, height = 28, scale = 1, powerHeight = 4,
		color = "reaction", healthText = "none", powerText = "none", name = true, surname = true, level = false, levelBadge = false, portrait = "none",
		buffs = 0, debuffs = 0, myDebuffs = false, auraSize = 18, auraPerRow = 6, buffSide = "below", debuffSide = "below",
		castbar = false, castHeight = 10, castLocked = false, threat = true, heals = true, marks = false,
		invert = false, fill = "right", mirror = false, myBuffs = false, absorbs = true, calm = 1, happiness = true,
	},
	party = {
		enabled = true, x = -671, y = 330, width = 200, height = 40, scale = 1.2, powerHeight = 6,
		color = "class", healthText = "value", powerText = "none", name = true, surname = true, level = true, levelBadge = false, portrait = "left",
		buffs = 8, debuffs = 4, myDebuffs = false, auraSize = 20, auraPerRow = 8, buffSide = "above", debuffSide = "right",
		castbar = true, castHeight = 13, castLocked = false, threat = true, range = true, heals = true, marks = true, dispel = true,
		leader = false, role = false, pvp = false,
		growth = "down", spacing = 12, showPlayer = false, showSolo = false,
		invert = false, fill = "right", mirror = true, myBuffs = false, absorbs = true, highlight = true, byRole = false,
	},
	raid = {
		enabled = false, x = -640, y = 250, width = 82, height = 40, scale = 1, powerHeight = 3,
		color = "class", healthText = "none", powerText = "none", name = true, surname = true, level = false, levelBadge = false, portrait = "none",
		buffs = 0, debuffs = 2, myDebuffs = false, auraSize = 15, auraPerRow = 2, buffSide = "inside", debuffSide = "inside",
		threat = true, range = true, heals = true, marks = true, dispel = true,
		leader = false, role = false, pvp = false,
		growth = "down", spacing = 4, perColumn = 5, columnGrowth = "right", columnSpacing = 6,
		scaleSmall = 1.3, scaleMid = 1.15,
		invert = false, fill = "right", mirror = false, myBuffs = false, absorbs = true, highlight = true,
	},
}

---------------------------------------------------------------------------
-- Checking
---------------------------------------------------------------------------
-- A number is kept if it is one, inside its range. It is not pulled onto its step: the steps are
-- what the options page moves by, and a hand-edited 137 is as good a width as 136.
local function Fits(spec, value)
	if spec.type == "bool" then
		return type(value) == "boolean"
	elseif spec.type == "number" then
		-- value == value is false only for NaN, which would poison every size it touched.
		return type(value) == "number" and value == value and value >= spec.low and value <= spec.high
	end
	for _, choice in ipairs(spec.choices) do
		if value == choice then
			return true
		end
	end
	return false
end
Defaults.Fits = Fits

-- Makes `into` hold exactly the keys of `defaults`, each with a value its spec allows.
local function Conform(into, defaults, specs)
	for key in pairs(into) do
		if defaults[key] == nil then
			into[key] = nil
		end
	end
	for key, default in pairs(defaults) do
		if not Fits(specs[key], into[key]) then
			into[key] = default
		end
	end
	return into
end

---------------------------------------------------------------------------
-- Profiles from an older version
---------------------------------------------------------------------------
-- The saved file carries a number that says how its profiles are laid out (Core.lua). This is
-- what changed between 1 (version 0.2) and 2 (version 0.3).
--
-- Some frames start out differently now. A setting that still holds its old starting value is
-- taken for one the player never touched, and moves to the new one; whatever the player chose
-- stays as chosen. There is no telling a value left alone from one deliberately set to the same,
-- so someone who wanted no portrait gets one, once, and can switch it off again.
local OLD_STARTS = {
	player = { portrait = "none", powerHeight = 9 },
	target = { portrait = "none", powerHeight = 9 },
	targettarget = { healthText = "percent", width = 124, x = 476 },
	focus = { portrait = "none", width = 174, height = 34, x = -319 },
	party = { portrait = "none", healthText = "percent", buffs = 0, width = 172, auraPerRow = 4 },
}
-- And what each of those started as in version 0.3, which is where an untouched one goes. It is
-- written down here and not read from the starting settings above, which have moved on since.
local STARTS_0_3 = {
	player = { portrait = "left", powerHeight = 10 },
	target = { portrait = "right", powerHeight = 10 },
	targettarget = { healthText = "none", width = 140, x = 484 },
	focus = { portrait = "left", width = 200, height = 40, x = -306 },
	party = { portrait = "left", healthText = "short", buffs = 8, width = 200, auraPerRow = 8 },
}
-- Buffs and debuffs shared one setting for where their icons stand ("auraSide").
local OLD_AURA_SIDE = {
	player = "above", target = "above", targettarget = "below", focus = "above", pet = "below", party = "right", raid = "inside",
}
-- The party's icons start out differently as a set (buffs above each member now, eight icons
-- to a row). The set moves only as a whole: a party whose icons were set up in any way keeps
-- every one of these as it was.
local OLD_ICONS = { party = { buffs = 0, debuffs = 4, auraPerRow = 4, auraSize = 20, auraSide = "right" } }
local ICON_KEYS = { buffs = true, auraPerRow = true }
-- The gap between the members of a group, and between its columns, was the whole distance from
-- one plate to the next. It is now the clear room between them: what stands outside a plate
-- (rows of icons, a cast bar) is added to it (Group.lua). A gap the player had set is taken
-- down by what stood between the plates then, so that the members stay as far apart as they
-- were; a gap never touched is left to grow, which is what keeps icons off the next plate.
local OLD_GAPS = { party = { spacing = 12 }, raid = { spacing = 4, columnSpacing = 6 } }
-- What else decided how much stood between two members then, and has started differently since.
local OLD_BETWEEN = { party = { castbar = false, castHeight = 10 } }

-- How much stood between two members of a group, and between two columns, under the old
-- settings of a frame: asked of the code that lays groups out, of a copy of the settings with
-- whatever is missing filled in as it started then, and checked.
local function OldRoom(kind, cfg)
	local probe = {}
	for key, value in pairs(cfg) do
		probe[key] = value
	end
	for _, olds in ipairs({ OLD_STARTS[kind] or {}, OLD_ICONS[kind] or {}, OLD_BETWEEN[kind] or {} }) do
		for key, old in pairs(olds) do
			if probe[key] == nil then
				probe[key] = old
			end
		end
	end
	local side = probe.auraSide or OLD_AURA_SIDE[kind]
	probe.buffSide, probe.debuffSide = side, side
	Conform(probe, Defaults.UNITS[kind], Defaults.UNIT_SPEC)
	local between, betweenColumns = ns.Group.Gaps(probe)
	return between - probe.spacing, betweenColumns - (probe.columnSpacing or 0)
end

-- Brings a profile written under layout number `from` up to this version's. Returns the same
-- table. What it holds has not been checked yet (Sanitize does that next), so nothing in it is
-- taken for granted.
function Defaults.Migrate(profile, from)
	if type(profile) ~= "table" or type(profile.units) ~= "table" then
		return profile
	end
	if from < 3 then
		-- Version 0.3.2 put every level on a badge and saved that into every profile it touched,
		-- so there is no telling a badge someone chose from one that simply arrived. It was not
		-- liked: the level is plain text again, and the badge is switched off here, once. Whoever
		-- did like it switches it on again.
		for _, cfg in pairs(profile.units) do
			if type(cfg) == "table" then
				cfg.levelBadge = false
			end
		end
	end
	if from >= 2 then
		return profile
	end
	for kind, cfg in pairs(profile.units) do
		local starts = Defaults.UNITS[kind] and type(cfg) == "table" and (OLD_STARTS[kind] or {})
		if starts then
			-- A gap the player chose keeps the members as far apart as they were.
			local gaps = OLD_GAPS[kind]
			if gaps then
				local room, columnRoom = OldRoom(kind, cfg)
				if type(cfg.spacing) == "number" and cfg.spacing ~= gaps.spacing then
					cfg.spacing = math.max(0, cfg.spacing - room)
				end
				if type(cfg.columnSpacing) == "number" and cfg.columnSpacing ~= gaps.columnSpacing then
					cfg.columnSpacing = math.max(0, cfg.columnSpacing - columnRoom)
				end
			end

			local untouchedIcons = true
			for key, old in pairs(OLD_ICONS[kind] or {}) do
				untouchedIcons = untouchedIcons and (cfg[key] == nil or cfg[key] == old)
			end
			-- The debuffs stay where the icons were. So do the buffs, unless nothing about the
			-- icons was ever chosen: then they go where this version starts them.
			local side = cfg.auraSide
			if side ~= nil then
				cfg.debuffSide = side
				if side ~= OLD_AURA_SIDE[kind] or not untouchedIcons then
					cfg.buffSide = side
				end
			end
			-- A frame that grows keeps its edge where it was only if it was never moved.
			local widened = starts.width ~= nil and cfg.width == starts.width
			for key, old in pairs(starts) do
				if cfg[key] == old and (key ~= "x" or widened) and (untouchedIcons or not ICON_KEYS[key]) then
					cfg[key] = STARTS_0_3[kind][key]
				end
			end
		end
	end
	return profile
end

-- Brings a profile, however it arrived, to something every other file can rely on: every setting
-- present and allowed, nothing else in it. Returns the same table.
function Defaults.Sanitize(profile)
	local units = type(profile.units) == "table" and profile.units or {}
	local hide = type(profile.hide) == "table" and profile.hide or {}
	profile.units, profile.hide = nil, nil

	Conform(profile, Defaults.GENERAL, Defaults.GENERAL_SPEC)

	profile.hide = hide
	for key in pairs(hide) do
		if Defaults.HIDE[key] == nil then
			hide[key] = nil
		end
	end
	for key, default in pairs(Defaults.HIDE) do
		if type(hide[key]) ~= "boolean" then
			hide[key] = default
		end
	end

	profile.units = units
	for kind in pairs(units) do
		if not Defaults.UNITS[kind] then
			units[kind] = nil
		end
	end
	for kind, defaults in pairs(Defaults.UNITS) do
		if type(units[kind]) ~= "table" then
			units[kind] = {}
		end
		Conform(units[kind], defaults, Defaults.UNIT_SPEC)
	end
	return profile
end

-- Where the frames start on a screen with room for it: the author's own arrangement, the
-- player and the target well apart with the fight between them, the focus and the pet out at the
-- left. It was laid out on a screen 2134 units wide (16:9 with the interface scaled to 64%) and
-- needs most of that. The raid's place is the bottom left corner of that screen.
local WIDE_PLACES = {
	player = { x = -525, y = 141 }, target = { x = 506, y = 125 }, targettarget = { x = 567, y = 44 },
	focus = { x = -841, y = 153 }, pet = { x = -909, y = 94 }, party = { x = -652, y = 35 }, raid = { x = -1067, y = -319 },
}

-- A frame that would start off the side of the screen is pulled back in, to a little inside the
-- edge. This is for fresh settings only: where the player has put a frame is the player's business.
local SIDE_MARGIN = 12

-- How far from the middle of the screen a frame's sides are, at this place. A single frame is
-- placed by its middle, a group by its top left corner.
local function Sides(kind, cfg, x)
	local grouped = kind == "party" or kind == "raid"
	local left = grouped and x or x - cfg.width * cfg.scale / 2
	return left, left + cfg.width * cfg.scale
end

-- Whether the wide arrangement fits this screen: every frame that starts switched on, whole and
-- inside the margin. (One that starts switched off is pulled in like any other when it is used.)
local function WideFits(units)
	local half = UIParent:GetWidth() / 2
	for kind, place in pairs(WIDE_PLACES) do
		local cfg = Defaults.UNITS[kind]
		if cfg.enabled then
			local left, right = Sides(kind, units[kind] or cfg, place.x)
			if left < -half + SIDE_MARGIN or right > half - SIDE_MARGIN then
				return false
			end
		end
	end
	return true
end

local function FitToScreen(profile, only)
	local half = UIParent:GetWidth() / 2
	local wide = WideFits(profile.units)
	for kind, cfg in pairs(profile.units) do
		if not only or kind == only then
			if wide then
				cfg.x, cfg.y = WIDE_PLACES[kind].x, WIDE_PLACES[kind].y
			end
			-- A single frame is placed by its middle, a group by its top left corner.
			local grouped = kind == "party" or kind == "raid"
			local left = grouped and cfg.x or cfg.x - cfg.width * cfg.scale / 2
			local right = left + cfg.width * cfg.scale
			if left < -half + SIDE_MARGIN then
				cfg.x = math.floor(cfg.x + (-half + SIDE_MARGIN - left) + 0.5)
			elseif right > half - SIDE_MARGIN then
				cfg.x = math.floor(cfg.x - (right - (half - SIDE_MARGIN)) + 0.5)
			end
		end
	end
	return profile
end

-- A profile as a new player gets it.
function Defaults.Fresh()
	return FitToScreen(Defaults.Sanitize({}))
end

-- Puts one frame's settings, or with no kind the whole profile, back to how it started.
function Defaults.Reset(profile, kind)
	if kind then
		profile.units[kind] = CopyTable(Defaults.UNITS[kind])
		FitToScreen(profile, kind)
		return
	end
	wipe(profile)
	FitToScreen(Defaults.Sanitize(profile))
end

-- The spec of a setting of a frame, and whether that frame has it at all.
function Defaults.UnitSpec(kind, key)
	if Defaults.UNITS[kind][key] == nil then
		return nil
	end
	return Defaults.UNIT_SPEC[key]
end
