local ADDON, ns = ...

-- The words on the plate: level and name, and the health and power numbers.
--
-- A wide frame has the level and name on the left and the numbers on the right, health over
-- power. A narrow one (a raid frame) has the name in the middle and the health number under it.
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
local PAD = 4

function Texts.Wanted(cfg)
	return cfg.name or cfg.level or cfg.healthText ~= "none" or cfg.powerText ~= "none"
end

function Texts.Create(frame)
	-- Above the bars, which are frames of their own, so the words are never covered.
	local holder = CreateFrame("Frame", nil, frame.body)
	holder:SetAllPoints(frame.body)
	holder:SetFrameLevel(frame.body:GetFrameLevel() + 6)
	local texts = { holder = holder }
	for _, key in ipairs({ "level", "name", "health", "power" }) do
		local text = holder:CreateFontString(nil, "OVERLAY")
		text:SetWordWrap(false)
		texts[key] = text
	end
	frame.texts = texts
end

function Texts.Layout(frame, cfg, on)
	local texts, theme = frame.texts, Style.theme
	texts.holder:SetShown(on)
	if not on then
		return
	end
	local health = frame.health
	local narrow = cfg.width < NARROW
	local showHealth, showPower = cfg.healthText ~= "none", cfg.powerText ~= "none"

	-- On a tall plate the name is set a size larger than the numbers beside it.
	local tall = not narrow and cfg.height >= 40
	Style.SetFont(texts.level, tall and 1 or 0)
	Style.SetFont(texts.name, tall and 1 or 0)
	Style.SetFont(texts.health, narrow and -1 or 0)
	Style.SetFont(texts.power, -2)
	texts.name:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
	texts.health:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
	texts.power:SetTextColor(theme.quiet[1], theme.quiet[2], theme.quiet[3])

	for _, key in ipairs({ "level", "name", "health", "power" }) do
		texts[key]:ClearAllPoints()
	end
	texts.level:SetShown(cfg.level)
	texts.name:SetShown(cfg.name)
	texts.health:SetShown(showHealth)
	texts.power:SetShown(showPower)

	if narrow then
		-- Name in the middle, the health number under it; no room for more.
		texts.level:Hide()
		texts.power:Hide()
		texts.name:SetJustifyH("CENTER")
		texts.name:SetWidth(frame.barWidth - 2 * PAD)
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

	-- The numbers take what they need on the right; the name gets the rest and is cut short
	-- with an ellipsis by the game if it does not fit.
	local numbers = 0
	if showHealth then
		numbers = (cfg.healthText == "both" or cfg.healthText == "max") and 0.46 or 0.30
	elseif showPower then
		numbers = 0.30
	end
	texts.health:SetJustifyH("RIGHT")
	texts.power:SetJustifyH("RIGHT")
	if showHealth and showPower then
		texts.health:SetPoint("BOTTOMRIGHT", health, "RIGHT", -PAD, 0)
		texts.power:SetPoint("TOPRIGHT", health, "RIGHT", -PAD, -1)
	else
		texts.health:SetPoint("RIGHT", health, "RIGHT", -PAD, 0)
		texts.power:SetPoint("RIGHT", health, "RIGHT", -PAD, 0)
	end

	texts.level:SetJustifyH("LEFT")
	texts.level:SetPoint("LEFT", health, "LEFT", PAD, 0)
	texts.name:SetJustifyH("LEFT")
	if cfg.level then
		texts.name:SetPoint("LEFT", texts.level, "RIGHT", 3, 0)
	else
		texts.name:SetPoint("LEFT", health, "LEFT", PAD, 0)
	end
	local levelRoom = cfg.level and Style.fontSize * 2.5 or 0
	texts.name:SetWidth(math.max(10, frame.barWidth * (1 - numbers) - 2 * PAD - levelRoom))
end

-- "60", "62+" for an elite, "62R" for a rare one and "62R+" for one that is both, "??" for
-- something too far above the player to tell.
local CLASSIFICATION_SUFFIX = { elite = "+", rareelite = "R+", worldboss = "+", rare = "R" }

-- How far the game's difficulty colours are lifted towards white. As they come, the red of a
-- deadly fight is the red of the hostile bar it is written on, and the grey of an easy one is
-- lost on any bar.
local LIFT = 0.45

local function ShowLevel(text, unit)
	local level = UnitLevel(unit)
	local label = level and level > 0 and tostring(level) or "??"
	text:SetText(label .. (CLASSIFICATION_SUFFIX[UnitClassification(unit)] or ""))
	if UnitCanAttack("player", unit) then
		-- The game's own colour for how hard a fight it would be.
		local color = GetCreatureDifficultyColor(level and level > 0 and level or 999)
		text:SetTextColor(color.r + (1 - color.r) * LIFT, color.g + (1 - color.g) * LIFT, color.b + (1 - color.b) * LIFT)
	else
		-- Someone who cannot be fought: the same tone as the name, so it reads on any bar.
		local plain = Style.theme.text
		text:SetTextColor(plain[1], plain[2], plain[3])
	end
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
		if cfg.name then
			Sealed.NameToText(texts.name, unit)
		end
		if cfg.level then
			ShowLevel(texts.level, unit)
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
			Sealed.NameToText(texts.name, unit)
		end
	end
end

Frame.Register(Texts)
