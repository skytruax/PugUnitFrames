local ADDON, ns = ...

-- Party and raid frames.
--
-- Each is one of the game's secure group headers: a frame that, by itself and also in the middle
-- of a fight, makes a unit button for every member, lays the buttons out and points each at its
-- member. What we give it is the template for a button (Templates.xml), a little secure code to
-- size a new one, and the layout as attributes. Changing any of that is only possible out of
-- combat.
local Group = {}
ns.Group = Group

local Frame = ns.Frame

local headers = {} -- party = ..., raid = ...

local MAX_RAID = 40
local RAID_GROUPS = "1,2,3,4,5,6,7,8"
local ROLE_ORDER = "TANK,HEALER,DAMAGER,NONE"

-- Runs in the game's restricted environment for every button a header makes. It has no access
-- to this addon: the sizes come from attributes on the header, and what a click does (Frame.CLICKS)
-- is written into the snippet below.
local INITIAL_CONFIG = [[
	local header = self:GetParent()
	self:SetWidth(header:GetAttribute("pug-width"))
	self:SetHeight(header:GetAttribute("pug-height"))
]]
do
	local names = {}
	for name in pairs(Frame.CLICKS) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local value = Frame.CLICKS[name]
		INITIAL_CONFIG = INITIAL_CONFIG .. ("\tself:SetAttribute(%q, %s)\n"):format(name,
			type(value) == "string" and ("%q"):format(value) or tostring(value))
	end
end

function Group.Get(kind)
	return headers[kind]
end

-- Called by the button template as a header makes a button, which can be in the middle of a
-- fight: nothing here may touch the button itself, only draw on it. The header gives the button
-- its unit afterwards, and again whenever the roster changes; Frame.lua follows that attribute.
function Group.OnButtonLoad(button)
	local header = button:GetParent()
	Frame.Build(button, header.kind)
	_G.ClickCastFrames = _G.ClickCastFrames or {}
	_G.ClickCastFrames[button] = true
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
local VERTICAL = { down = true, up = true }

-- Columns have to run across the way members run. Settings that say otherwise are read as the
-- usual choice for that direction.
local function ColumnGrowth(cfg)
	local across = cfg.columnGrowth or "right"
	if VERTICAL[cfg.growth] == VERTICAL[across] then
		return VERTICAL[cfg.growth] and "right" or "down"
	end
	return across
end
Group.ColumnGrowth = ColumnGrowth

-- The corner of a group that stays put as members come and go, given which ways it grows.
local function Corner(cfg)
	local across = ColumnGrowth(cfg)
	local vertical = (cfg.growth == "up" or across == "up") and "BOTTOM" or "TOP"
	local horizontal = (cfg.growth == "left" or across == "left") and "RIGHT" or "LEFT"
	return vertical .. horizontal
end
Group.Corner = Corner

-- How far apart the members of a group stand, and its columns: the gap the settings ask for,
-- and on top of it whatever a member has standing outside its plate towards the next one (rows
-- of icons, a cast bar). The gap in the settings is then what it says, the clear room between
-- one member's things and the next member's, wherever the icons are put.
local function Gaps(cfg)
	local room = ns.Elements.Auras.Room(cfg)
	local upright = room.above + room.below + (cfg.castbar and cfg.castHeight + 3 or 0)
	local level = room.left + room.right
	if VERTICAL[cfg.growth] then
		return cfg.spacing + upright, (cfg.columnSpacing or 0) + level
	end
	return cfg.spacing + level, (cfg.columnSpacing or 0) + upright
end
Group.Gaps = Gaps

-- How much larger raid frames are drawn in a small raid.
local function RaidScale(cfg)
	local members = ns.Sealed.GroupSize()
	if members <= 10 then
		return cfg.scale * cfg.scaleSmall
	elseif members <= 20 then
		return cfg.scale * cfg.scaleMid
	end
	return cfg.scale
end
Group.RaidScale = RaidScale

-- The edge of a button that the next one is attached to, and the step to it.
local GROWTH = {
	down = { point = "TOP", x = 0, y = -1 },
	up = { point = "BOTTOM", x = 0, y = 1 },
	right = { point = "LEFT", x = 1, y = 0 },
	left = { point = "RIGHT", x = -1, y = 0 },
}
local COLUMN_ANCHOR = { right = "LEFT", left = "RIGHT", down = "TOP", up = "BOTTOM" }

local function EachButton(header, fn)
	for index = 1, MAX_RAID do
		local button = header:GetAttribute("child" .. index)
		if not button then
			return
		end
		fn(button)
	end
end

local function Configure(header, kind)
	local cfg = ns.db.units[kind]
	local growth = GROWTH[cfg.growth]
	local scale = kind == "raid" and RaidScale(cfg) or cfg.scale
	local between, betweenColumns = Gaps(cfg)

	-- The header is told nothing while it is hidden; shown again at the end, it lays out once.
	header:Hide()

	header:SetAttribute("pug-width", cfg.width)
	header:SetAttribute("pug-height", cfg.height)
	-- A button keeps the anchors of the old layout unless they are taken off first.
	EachButton(header, function(button)
		button:ClearAllPoints()
		button:SetSize(cfg.width, cfg.height)
	end)

	header:SetAttribute("point", growth.point)
	header:SetAttribute("xOffset", growth.x * between)
	header:SetAttribute("yOffset", growth.y * between)
	if kind == "party" then
		header:SetAttribute("showParty", true)
		header:SetAttribute("showRaid", false)
		header:SetAttribute("showSolo", cfg.showSolo)
		header:SetAttribute("showPlayer", cfg.showPlayer)
		-- By the part each member has taken: tanks first, then healers, then everyone else.
		header:SetAttribute("groupBy", cfg.byRole and "ASSIGNEDROLE" or nil)
		header:SetAttribute("groupingOrder", cfg.byRole and ROLE_ORDER or nil)
	else
		header:SetAttribute("showRaid", true)
		header:SetAttribute("showParty", false)
		header:SetAttribute("showSolo", false)
		header:SetAttribute("showPlayer", true)
		header:SetAttribute("groupFilter", RAID_GROUPS)
		header:SetAttribute("groupBy", "GROUP")
		header:SetAttribute("groupingOrder", RAID_GROUPS)
		header:SetAttribute("unitsPerColumn", cfg.perColumn)
		header:SetAttribute("maxColumns", math.ceil(MAX_RAID / cfg.perColumn))
		header:SetAttribute("columnSpacing", betweenColumns)
		header:SetAttribute("columnAnchorPoint", COLUMN_ANCHOR[ColumnGrowth(cfg)])
	end

	header:ClearAllPoints()
	-- The settings hold the position in screen units; a scaled frame measures in its own.
	header:SetPoint(Corner(cfg), UIParent, "CENTER", cfg.x / scale, cfg.y / scale)
	header:SetScale(scale)
	header.sizedFor = scale
	if cfg.enabled then
		header:Show()
	end
end

-- Call out of combat.
function Group.ApplyLayout()
	for kind, header in pairs(headers) do
		Configure(header, kind)
		EachButton(header, Frame.Layout)
	end
end

-- Call out of combat, once.
function Group.Spawn()
	for _, kind in ipairs({ "party", "raid" }) do
		local header = CreateFrame("Frame", "PugUnitFrames_" .. kind, UIParent, "SecureGroupHeaderTemplate")
		header.kind = kind
		header:SetFrameStrata("LOW")
		header:SetAttribute("template", "PugUnitFramesGroupButtonTemplate")
		header:SetAttribute("initialConfigFunction", INITIAL_CONFIG)
		headers[kind] = header
	end
	Group.ApplyLayout()
end

-- The roster changed: a button may now stand for someone else, and a raid that crossed 10 or 20
-- players changes size (once the fight, if there is one, is over).
ns.On("GROUP_ROSTER_UPDATE", function()
	Frame.RefreshKind("party")
	Frame.RefreshKind("raid")
	local raid = headers.raid
	if raid and raid.sizedFor ~= RaidScale(ns.db.units.raid) then
		ns.RunOutOfCombat("raid-scale", function()
			Configure(raid, "raid")
		end)
	end
end)
