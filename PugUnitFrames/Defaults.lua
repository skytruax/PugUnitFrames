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
	shadows = true,
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
	level = Bool(),
	portrait = Choice("none", "left", "right"),
	mirror = Bool(),                  -- the portrait turned to look the other way
	buffs = Number(0, 32, 1),         -- how many buff icons at most; 0: none
	debuffs = Number(0, 32, 1),
	auraSize = Number(10, 44, 1),
	auraPerRow = Number(1, 20, 1),
	auraSide = Choice("below", "above", "right", "left", "inside"),
	myBuffs = Bool(),                 -- of the buffs, only the ones the player cast
	myDebuffs = Bool(),               -- of the debuffs, only the ones the player put there
	castbar = Bool(),
	castHeight = Number(6, 30, 1),
	threat = Bool(),                  -- an outline while the unit is being attacked
	range = Bool(),                   -- fade a group member who is out of range
	heals = Bool(),                   -- healing on its way, past the end of the health bar
	absorbs = Bool(),                 -- shields that soak up damage, as a band along the top of the health bar
	marks = Bool(),                   -- raid mark, leader, role, PvP flag, resting, in combat
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
		"color", "invert", "fill", "powerHeight", "hideNoPower", "heals", "absorbs", "castbar", "castHeight", "points", "totems",
	} },
	{ key = "text", keys = {
		"name", "level", "healthText", "powerText", "portrait", "mirror",
		"marks", "happiness", "threat", "range", "highlight", "dispel",
	} },
	{ key = "icons", keys = {
		"buffs", "myBuffs", "debuffs", "myDebuffs", "auraSize", "auraPerRow", "auraSide",
	} },
}

-- Every setting of a frame, in the order of the sections.
Defaults.UNIT_ORDER = {}
for _, section in ipairs(Defaults.UNIT_SECTIONS) do
	for _, key in ipairs(section.keys) do
		Defaults.UNIT_ORDER[#Defaults.UNIT_ORDER + 1] = key
	end
end

Defaults.UNITS = {
	player = {
		enabled = true, x = -290, y = -210, width = 232, height = 46, scale = 1, powerHeight = 9,
		color = "class", healthText = "both", powerText = "value", name = true, level = true, portrait = "none",
		buffs = 0, debuffs = 0, myDebuffs = false, auraSize = 22, auraPerRow = 9, auraSide = "above",
		castbar = true, castHeight = 16, threat = true, heals = true, marks = true, totems = true,
		invert = false, fill = "right", mirror = false, myBuffs = false, absorbs = true, calm = 1, hideInGroup = false,
	},
	target = {
		enabled = true, x = 290, y = -210, width = 232, height = 46, scale = 1, powerHeight = 9,
		color = "class", healthText = "both", powerText = "value", name = true, level = true, portrait = "none",
		buffs = 9, debuffs = 18, myDebuffs = false, auraSize = 22, auraPerRow = 9, auraSide = "above",
		castbar = true, castHeight = 16, marks = true, points = true,
		invert = false, fill = "right", mirror = false, myBuffs = false, absorbs = true, hideNoPower = true,
	},
	targettarget = {
		enabled = true, x = 476, y = -219, width = 124, height = 28, scale = 1, powerHeight = 4,
		color = "class", healthText = "percent", powerText = "none", name = true, level = false, portrait = "none",
		buffs = 0, debuffs = 0, myDebuffs = false, auraSize = 18, auraPerRow = 6, auraSide = "below", marks = true,
		invert = false, fill = "right", mirror = false, myBuffs = false, absorbs = true, hideNoPower = true,
	},
	focus = {
		enabled = true, x = -319, y = -130, width = 174, height = 34, scale = 1, powerHeight = 6,
		color = "class", healthText = "percent", powerText = "none", name = true, level = false, portrait = "none",
		buffs = 0, debuffs = 6, myDebuffs = false, auraSize = 20, auraPerRow = 8, auraSide = "above",
		castbar = true, castHeight = 12, marks = true,
		invert = false, fill = "right", mirror = false, myBuffs = false, absorbs = true, hideNoPower = true,
	},
	pet = {
		enabled = true, x = -476, y = -219, width = 124, height = 28, scale = 1, powerHeight = 4,
		color = "reaction", healthText = "none", powerText = "none", name = true, level = false, portrait = "none",
		buffs = 0, debuffs = 0, myDebuffs = false, auraSize = 18, auraPerRow = 6, auraSide = "below",
		castbar = false, castHeight = 10, threat = true, heals = true, marks = false,
		invert = false, fill = "right", mirror = false, myBuffs = false, absorbs = true, calm = 1, happiness = true,
	},
	party = {
		enabled = true, x = -620, y = 160, width = 172, height = 40, scale = 1, powerHeight = 6,
		color = "class", healthText = "percent", powerText = "none", name = true, level = false, portrait = "none",
		buffs = 0, debuffs = 4, myDebuffs = false, auraSize = 20, auraPerRow = 4, auraSide = "right",
		castbar = false, castHeight = 10, threat = true, range = true, heals = true, marks = true, dispel = true,
		growth = "down", spacing = 12, showPlayer = false, showSolo = false,
		invert = false, fill = "right", mirror = false, myBuffs = false, absorbs = true, highlight = true, byRole = false,
	},
	raid = {
		enabled = true, x = -640, y = 250, width = 82, height = 40, scale = 1, powerHeight = 3,
		color = "class", healthText = "none", powerText = "none", name = true, level = false, portrait = "none",
		buffs = 0, debuffs = 2, myDebuffs = false, auraSize = 15, auraPerRow = 2, auraSide = "inside",
		threat = true, range = true, heals = true, marks = true, dispel = true,
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

-- The starting places are laid out for a wide screen. On a narrower one this pulls a frame that
-- would start off the side back in, to a little inside the edge. It is for fresh settings only:
-- where the player has put a frame is the player's business.
local SIDE_MARGIN = 12

local function FitToScreen(profile, only)
	local half = UIParent:GetWidth() / 2
	for kind, cfg in pairs(profile.units) do
		if not only or kind == only then
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
