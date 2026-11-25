local ADDON, ns = ...

-- The words on the plate: the name, the level (with a dragon beside it for an elite or a rare
-- creature), and the health and power numbers.
--
-- A character of this game has a first name and a surname, twelve letters each at most, and a
-- creature's name can be longer than that. So a plate with room for two lines gives the upper
-- one to the name alone, the whole width of the bar; the health number has the lower one. A
-- plate too low for that has one line: the name from the left, the numbers from the right, the
-- name in what the numbers leave. A narrow plate (a raid frame) has the name in the middle,
-- first name over surname, or the first name with the health number under it.
--
-- The level stands on a small plate of its own, a badge: a dark tile with a thin rim, the number
-- and the rim in the colour of how hard a fight the unit would be (gold for someone who cannot
-- be fought), the dragon inside it. It sits on the lower edge of the portrait where the frame
-- has one large enough, and otherwise at the start of the line the level would be written on.
-- With the badge switched off the level is plain text on that line, as it was before 0.3.2.
--
-- The power number sits on the power bar when the bar is tall enough to hold it, and beside the
-- level or under the health number when it is not.
local Frame, Style, Sealed = ns.Frame, ns.Style, ns.Sealed
local L = ns.L

local Texts = { name = "Texts" }

Texts.events = {
	"UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_CLASSIFICATION_CHANGED", "UNIT_FACTION", "UNIT_CONNECTION",
	"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
}
-- On the frames a player watches closely the power number moves with every tick, as the bar
-- under it does (Power.lua); without this it would only follow in steps.
Texts.closeEvents = { "UNIT_POWER_FREQUENT" }

local NARROW = Frame.NARROW
local PAD = 4         -- between an end of the bar and the words
local NARROW_PAD = 2  -- a narrow plate has less to spare
local AFTER_RANK = 2  -- between the dragon and the level
local AFTER_BADGE = 4 -- between the badge and what follows it on the line
local BADGE_PAD = 4   -- inside the badge, left and right of what it holds
local FIGURE = 0.64   -- how wide a figure of the level is, as a share of the letter size

-- The game's own pictures, the ones it puts on a nameplate: a gold dragon for an elite and for
-- a boss, a silver one for a rare elite, a star for a rare creature that is not elite.
local RANK_ART = {
	elite = "nameplates-icon-elite-gold",
	worldboss = "nameplates-icon-elite-gold",
	rareelite = "nameplates-icon-elite-silver",
	rare = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star",
}

function Texts.Wanted(cfg)
	return cfg.name or cfg.level or cfg.healthText ~= "none" or cfg.powerText ~= "none" or (cfg.elite and true or false)
end

function Texts.Create(frame)
	-- Above the bars, which are frames of their own, so the words are never covered.
	local holder = CreateFrame("Frame", nil, frame.body)
	holder:SetAllPoints(frame.body)
	holder:SetFrameLevel(frame.body:GetFrameLevel() + 6)
	local texts = { holder = holder }
	for _, key in ipairs({ "name", "health", "power" }) do
		local text = holder:CreateFontString(nil, "OVERLAY")
		text:SetWordWrap(false)
		texts[key] = text
	end
	-- The level's badge: a dark tile with a thin rim, the level in it and the dragon beside it.
	-- Without the badge it is the same box with nothing drawn on it, holding the two in a row.
	local badge = CreateFrame("Frame", nil, holder)
	badge:SetFrameLevel(holder:GetFrameLevel() + 1)
	badge.back = badge:CreateTexture(nil, "BACKGROUND")
	badge.back:SetAllPoints(badge)
	badge.edge = Frame.MakeEdge(badge, "BORDER")
	badge:Hide()
	texts.badge = badge
	texts.level = badge:CreateFontString(nil, "OVERLAY")
	texts.level:SetWordWrap(false)
	texts.rank = badge:CreateTexture(nil, "OVERLAY") -- the dragon
	texts.rank:Hide()
	texts.levelLength = 2
	frame.texts = texts
end

-- Places the badge with the level and the dragon in it, a power number that has no bar to sit
-- on, and on a plate with one line the name. What stands on a line starts where the thing
-- before it ends, and the badge is as wide as what it holds, so this is done again when the
-- unit on show gains or loses its dragon, or its level is written with more or fewer figures.
local function Arrange(frame, ranked)
	local texts, cfg, health = frame.texts, frame.cfg, frame.health
	local badge, rank, level, name = texts.badge, texts.rank, texts.level, texts.name
	local showLevel = (cfg.level and not texts.narrow) or false
	local hasBadge = showLevel or ranked
	texts.ranked = ranked
	badge:SetShown(hasBadge)
	rank:SetShown(ranked)
	level:SetShown(showLevel)
	badge:ClearAllPoints()
	rank:ClearAllPoints()
	level:ClearAllPoints()
	name:ClearAllPoints()

	-- The badge is as wide as its dragon, its figures and the room around them.
	local pad = texts.badged and BADGE_PAD or 0
	local rankSize = ranked and (texts.badged and texts.rankSize - 2 or texts.rankSize) or 0
	local figures = showLevel and math.ceil(texts.levelLength * texts.levelSize * FIGURE) or 0
	local between = (ranked and showLevel) and AFTER_RANK or 0
	badge:SetSize(math.max(1, 2 * pad + rankSize + between + figures), texts.rankSize)
	if ranked then
		rank:SetSize(rankSize, rankSize)
		rank:SetPoint("LEFT", badge, "LEFT", pad, 0)
	end
	level:SetPoint("RIGHT", badge, "RIGHT", -pad, 0)

	-- What the next thing on the line stands after, at which of its points, and how far from it.
	local after, point, gap, y = health, "LEFT", PAD, texts.lowY
	if hasBadge and texts.onPortrait then
		-- On the lower edge of the portrait, in the middle of it.
		local middle = frame.pixel + (cfg.height - 2 * frame.pixel) / 2
		if cfg.portrait == "left" then
			badge:SetPoint("BOTTOM", frame.body, "BOTTOMLEFT", middle, 2 * frame.pixel)
		else
			badge:SetPoint("BOTTOM", frame.body, "BOTTOMRIGHT", -middle, 2 * frame.pixel)
		end
	elseif hasBadge then
		badge:SetPoint("LEFT", after, point, gap, y)
		after, point, gap, y = badge, "RIGHT", AFTER_BADGE, 0
	end
	if texts.powerBeside then
		texts.power:ClearAllPoints()
		texts.power:SetPoint("LEFT", after, point, gap, y)
	end
	if texts.twoRows then
		-- The upper line is the name's alone, from one end of the bar to the other.
		name:SetPoint("LEFT", health, "LEFT", PAD, texts.nameY)
		name:SetPoint("RIGHT", health, "RIGHT", -PAD, texts.nameY)
	else
		-- One line: the name runs from the badge to where the numbers' room begins.
		name:SetPoint("LEFT", after, point, gap, y)
		name:SetPoint("RIGHT", health, "RIGHT", texts.nameEnd, 0)
	end
end

function Texts.Layout(frame, cfg, on)
	local texts, theme = frame.texts, Style.theme
	texts.holder:SetShown(on)
	if not on then
		return
	end
	local health, pixel = frame.health, frame.pixel
	local narrow = cfg.width < NARROW
	local showHealth, showPower = cfg.healthText ~= "none", cfg.powerText ~= "none"

	-- On a tall plate the name is set a size larger than the numbers.
	local tall = not narrow and cfg.height >= 40
	local nameSize = Style.fontSize + (tall and 1 or 0)
	local numberSize = Style.fontSize + (narrow and -1 or 0)
	local powerSize = math.max(6, Style.fontSize - 2)

	-- The level on a plate of its own, and that plate on the portrait, where there is one at
	-- least twice as high as the badge: on a smaller one it would leave nothing of the face.
	local badged = (cfg.levelBadge and cfg.level and not narrow) or false
	local badgeHeight = numberSize + 5
	local onPortrait = badged and cfg.portrait ~= "none" and cfg.height - 2 * pixel >= 2 * badgeHeight
	-- The power number goes on the power bar, where the bar is tall enough for it.
	local onBar = showPower and not narrow and cfg.powerHeight > powerSize
	-- Two lines, where the health bar has the height and there is something for the lower one.
	local barHeight = cfg.height - 2 * pixel - (cfg.powerHeight > 0 and cfg.powerHeight + pixel or 0)
	local lower = (cfg.level and not onPortrait) or showHealth or (showPower and not onBar)
	local twoRows = (not narrow and cfg.name and lower and barHeight >= nameSize + numberSize + 5) or false

	-- How far above and below the middle of the health bar the two lines run. They hold to the
	-- middle, not to the bar's edges, so they stay together when the bar grows (a power bar put
	-- away) or shrinks.
	texts.narrow = narrow
	texts.twoRows = twoRows
	texts.nameY = twoRows and math.ceil(nameSize / 2) + 1 or 0
	texts.lowY = twoRows and -(math.ceil(numberSize / 2) + 1) or 0
	frame.nameRow = twoRows and texts.nameY or nil

	-- Beside the name on a tall plate with one line the level is the name's size; anywhere else,
	-- its badge included, the numbers'.
	local levelDelta = (not badged and tall and not twoRows) and 1 or 0
	texts.badged, texts.onPortrait = badged, onPortrait
	texts.rankSize = badgeHeight
	texts.levelSize = Style.fontSize + levelDelta
	Style.SetFont(texts.name, tall and 1 or 0)
	Style.SetFont(texts.level, levelDelta)
	Style.SetFont(texts.health, narrow and -1 or 0)
	Style.SetFont(texts.power, -2)
	texts.name:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
	texts.health:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
	-- On its bar the power number has the bar's colour behind it and is written in full white;
	-- beside the other words it is the quieter of them.
	local powerTone = onBar and theme.text or theme.quiet
	texts.power:SetTextColor(powerTone[1], powerTone[2], powerTone[3])

	local badge = texts.badge
	badge.back:SetShown(badged)
	badge.back:SetColorTexture(theme.back[1], theme.back[2], theme.back[3], 0.92)
	for index = 1, 4 do
		badge.edge[index]:SetShown(badged)
	end
	Frame.LayoutEdge(badge.edge, badge, pixel, texts.tint or Style.LEVEL)

	for _, key in ipairs({ "name", "health", "power" }) do
		texts[key]:ClearAllPoints()
	end
	texts.name:SetShown(cfg.name)
	texts.health:SetShown(showHealth)
	texts.power:SetShown(showPower and not narrow)
	texts.rankable = (cfg.elite and not narrow) or false
	texts.powerBeside = false
	-- How the name is written (Sealed.NameToText). A narrow plate has no room for both names on
	-- one line: the surname goes on a line of its own, where there is no health number under
	-- the name to need that line.
	local stacked = (narrow and cfg.surname and not showHealth) or false
	texts.nameHow = (not cfg.surname and "first") or (not narrow and "full") or (stacked and "stacked") or "first"
	texts.name:SetWordWrap(stacked)
	texts.name:SetMaxLines(stacked and 2 or 1)

	if narrow then
		-- Name in the middle, the health number under it; no room for more.
		badge:Hide()
		texts.rank:Hide()
		texts.ranked = false
		texts.name:SetJustifyH("CENTER")
		texts.name:SetWidth(math.max(1, frame.barWidth - 2 * NARROW_PAD))
		texts.health:SetJustifyH("CENTER")
		if cfg.name and showHealth then
			texts.name:SetPoint("BOTTOM", health, "CENTER", 0, 1)
			texts.health:SetPoint("TOP", health, "CENTER", 0, -1)
		else
			texts.name:SetPoint("CENTER", health, "CENTER")
			texts.health:SetPoint("CENTER", health, "CENTER")
		end
		return
	end

	texts.level:SetJustifyH("RIGHT")
	texts.name:SetJustifyH("LEFT")
	texts.health:SetJustifyH("RIGHT")
	texts.power:SetJustifyH("RIGHT")

	-- The numbers, from the right. On a plate with one line, a power number that has no bar to
	-- sit on goes under the health number, the two as a column.
	local column = showHealth and showPower and not onBar and not twoRows
	if showHealth then
		if column then
			texts.health:SetPoint("BOTTOMRIGHT", health, "RIGHT", -PAD, 0)
		else
			texts.health:SetPoint("RIGHT", health, "RIGHT", -PAD, texts.lowY)
		end
	end
	local powerBesideName = false
	if showPower then
		if onBar then
			texts.power:SetPoint("RIGHT", frame.power, "RIGHT", -PAD, 0)
		elseif twoRows then
			-- On the lower line, after the level: Arrange places it.
			texts.powerBeside = true
			texts.power:SetJustifyH("LEFT")
		elseif column then
			texts.power:SetPoint("TOPRIGHT", health, "RIGHT", -PAD, -1)
		else
			texts.power:SetPoint("RIGHT", health, "RIGHT", -PAD, 0)
			powerBesideName = true
		end
	end
	-- On a plate with one line the name ends where the numbers' room begins. How wide a number
	-- comes out is the game's to know (it can be sealed, and the size of a text that holds a
	-- sealed number is sealed with it), so the name is not tied to the number itself: the
	-- numbers have a share of the bar, a larger one for the styles that write two numbers.
	local share = 0
	if showHealth then
		share = (cfg.healthText == "both" or cfg.healthText == "max") and 0.46 or 0.30
	elseif powerBesideName then
		share = 0.30
	end
	texts.nameEnd = -(PAD + frame.barWidth * share)

	-- Without a dragon for now: Texts.Update puts it there for a unit that has one.
	Arrange(frame, false)
end

-- "60", "62+" for an elite, "62R" for a rare one and "62R+" for one that is both, "??" for
-- something too far above the player to tell. In a badge that has the dragon in it the number
-- stands alone: the dragon says the rest.
local CLASSIFICATION_SUFFIX = { elite = "+", rareelite = "R+", worldboss = "+", rare = "R" }

-- How far the game's difficulty colours are lifted towards white. As they come, the red of a
-- deadly fight is the red of the hostile bar it is written on, and the grey of an easy one is
-- lost on any bar. On the dark badge they need less: enough for that grey to be read.
local LIFT = 0.45
local BADGE_LIFT = 0.25

-- Writes the level and colours it, and the rim of its badge with it; `ranked` says that the
-- dragon is shown beside it. Returns how many characters the level takes, which is what the
-- badge's width goes by. The level and what kind of creature a unit is are never sealed.
local function ShowLevel(frame, unit, ranked)
	local texts = frame.texts
	local text = texts.level
	local level = UnitLevel(unit)
	local suffix = (texts.badged and ranked) and "" or (CLASSIFICATION_SUFFIX[UnitClassification(unit)] or "")
	local label = (level and level > 0 and tostring(level) or "??") .. suffix
	text:SetText(label)
	local r, g, b
	if UnitCanAttack("player", unit) then
		-- The game's own colour for how hard a fight it would be.
		local color = GetCreatureDifficultyColor(level and level > 0 and level or 999)
		local lift = texts.badged and BADGE_LIFT or LIFT
		r, g, b = color.r + (1 - color.r) * lift, color.g + (1 - color.g) * lift, color.b + (1 - color.b) * lift
	elseif texts.badged then
		-- Someone who cannot be fought: the gold the game writes levels in.
		r, g, b = Style.LEVEL[1], Style.LEVEL[2], Style.LEVEL[3]
	else
		-- Beside the name, the same tone as the name, so it reads on any bar.
		r, g, b = Style.theme.text[1], Style.theme.text[2], Style.theme.text[3]
	end
	text:SetTextColor(r, g, b)
	texts.tint = { r, g, b, 1 }
	for index = 1, 4 do
		texts.badge.edge[index]:SetColorTexture(r, g, b, 1)
	end
	return #label
end

-- Puts the picture for the unit's standing on the dragon and says whether it has one. What a
-- creature is (elite, rare, a boss) is never sealed.
local function ShowRank(frame, unit)
	local texts = frame.texts
	local art = texts.rankable and RANK_ART[UnitClassification(unit)]
	if art then
		texts.rank:SetAtlas(art)
		return true
	end
	return false
end

-- Dead, a ghost or offline, or nothing: these are never sealed.
local function StatusOf(unit)
	if not UnitIsConnected(unit) then
		return L["Offline"]
	elseif UnitIsGhost(unit) then
		return L["Ghost"]
	elseif UnitIsDead(unit) then
		return L["Dead"]
	end
end

local HEALTH_EVENTS = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_CONNECTION = true }
local POWER_EVENTS = {
	UNIT_POWER_UPDATE = true, UNIT_POWER_FREQUENT = true, UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true, UNIT_CONNECTION = true,
}
local IDENTITY_EVENTS = { UNIT_NAME_UPDATE = true, UNIT_LEVEL = true, UNIT_CLASSIFICATION_CHANGED = true, UNIT_FACTION = true }

function Texts.Update(frame, unit, event)
	local texts, cfg = frame.texts, frame.cfg
	local all = event == nil
	local status = StatusOf(unit)

	if all or IDENTITY_EVENTS[event] then
		if not texts.narrow then
			local ranked = ShowRank(frame, unit)
			local length = cfg.level and ShowLevel(frame, unit, ranked) or texts.levelLength
			if ranked ~= texts.ranked or length ~= texts.levelLength then
				texts.levelLength = length
				Arrange(frame, ranked)
			end
		end
		if cfg.name then
			Sealed.NameToText(texts.name, unit, texts.nameHow)
		end
	end
	if (all or HEALTH_EVENTS[event]) and cfg.healthText ~= "none" then
		if status then
			texts.health:SetText(status)
		else
			Sealed.HealthToText(texts.health, unit, cfg.healthText)
		end
	end
	if (all or POWER_EVENTS[event]) and cfg.powerText ~= "none" then
		-- No number for a power bar that has been put away for having nothing to show (Power.lua).
		if status or frame.powerGone then
			texts.power:SetText("")
		else
			Sealed.PowerToText(texts.power, unit, (UnitPowerType(unit)), cfg.powerText)
		end
	end
	-- A narrow frame with no health number still has to say that someone is dead or gone.
	if (all or HEALTH_EVENTS[event]) and cfg.healthText == "none" and cfg.name and cfg.width < NARROW then
		if status then
			texts.name:SetText(status)
		elseif not all then
			Sealed.NameToText(texts.name, unit, texts.nameHow)
		end
	end
end

Frame.Register(Texts)
