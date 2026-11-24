local ADDON, ns = ...

-- The power bar: mana, rage, energy or focus, along the bottom of the plate.
local Frame, Style, Sealed = ns.Frame, ns.Style, ns.Sealed

local Power = { name = "Power" }

Power.events = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_CONNECTION" }
-- The game also reports power as it ticks, many times a second. That is worth it for the frames
-- a player watches closely, and not for forty raid frames.
Power.closeEvents = { "UNIT_POWER_FREQUENT" }

local MANA = Enum.PowerType.Mana

function Power.Wanted(cfg)
	return cfg.powerHeight > 0
end

function Power.Create(frame)
	local bar = CreateFrame("StatusBar", nil, frame.body)
	bar.trough = bar:CreateTexture(nil, "BACKGROUND")
	bar.trough:SetAllPoints(bar)
	if frame.kind == "player" then
		-- A druid in bear or cat form runs on rage or energy and still has mana, which the form's
		-- bar does not show: it gets a thin strip along the bottom of the power bar, as the game's
		-- own player frame gives it a small second bar.
		bar.mana = CreateFrame("StatusBar", nil, bar)
		bar.mana:Hide()
	end
	frame.power = bar
end

-- Puts the bar away or brings it back, and has the health bar take or give up the room.
local function SetGone(frame, gone)
	local bar = frame.power
	if bar.gone ~= gone then
		bar.gone = gone
		frame.powerGone = gone
		bar:SetShown(not gone)
		ns.Elements.Health.Fit(frame)
	end
end

function Power.Layout(frame, cfg, on)
	local bar, pixel = frame.power, frame.pixel
	if not on then
		bar:Hide()
		bar.gone, frame.powerGone = false, false
		return
	end
	-- Shown until Power.Update finds the unit has no power to show.
	bar:Show()
	if bar.gone then
		SetGone(frame, false)
	end
	bar:ClearAllPoints()
	bar:SetPoint("BOTTOMLEFT", frame.body, "BOTTOMLEFT", frame.barLeft, pixel)
	bar:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -frame.barRight, pixel)
	bar:SetHeight(frame.powerHeight)
	bar:SetStatusBarTexture(Style.texture)
	bar:SetReverseFill(cfg.fill == "left")
	bar.trough:SetTexture(Style.texture)

	local mana = bar.mana
	if mana then
		mana:ClearAllPoints()
		mana:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
		mana:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
		mana:SetHeight(math.max(2 * pixel, math.floor(frame.powerHeight / 3 + 0.5)))
		mana:SetStatusBarTexture(Style.TEXTURES.flat)
		mana:SetReverseFill(cfg.fill == "left")
		mana:SetStatusBarColor(Style.PowerColor("MANA"))
	end
end

-- The bar in a colour, and the empty part behind it in the same colour, darkened as the theme
-- darkens the empty part of a health bar.
local function Colour(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b)
	bar.trough:SetVertexColor(Style.Veiled(r, g, b))
end

-- Whether the unit has no power worth a bar. The game says so plainly for some (Sealed.HasNoPower).
-- For a creature it says only which kind of power it runs on, and players of this game report
-- that one that runs on rage never gathers any: its bar would stand empty for the whole fight.
local function HasNothing(unit, powerType, token)
	if Sealed.HasNoPower(unit, powerType) then
		return true
	end
	return token == "RAGE" and not UnitPlayerControlled(unit)
end

function Power.Update(frame, unit, event)
	local bar, cfg = frame.power, frame.cfg
	if not UnitIsConnected(unit) then
		SetGone(frame, false)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		Colour(bar, Style.Toned(Style.REACTION.gone))
		if bar.mana then
			bar.mana:Hide()
		end
		return
	end
	-- Which power the unit runs on is never sealed; how much of it there is can be.
	local powerType, token = UnitPowerType(unit)
	SetGone(frame, (cfg.hideNoPower and HasNothing(unit, powerType, token)) or false)
	Colour(bar, Style.PowerColor(token))
	Sealed.PowerToBar(bar, unit, powerType, event ~= nil and ns.db.smooth)

	local mana = bar.mana
	if mana then
		local hasMana = powerType ~= MANA and not Sealed.HasNoPower(unit, MANA)
		mana:SetShown(hasMana)
		if hasMana then
			Sealed.PowerToBar(mana, unit, MANA, false)
		end
	end
end

Frame.Register(Power)
