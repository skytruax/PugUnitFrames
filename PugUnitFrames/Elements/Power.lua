local ADDON, ns = ...

-- The power bar: mana, rage, energy or focus, along the bottom of the plate.
local Frame, Style, Sealed = ns.Frame, ns.Style, ns.Sealed

local Power = { name = "Power" }

Power.events = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_CONNECTION" }
-- The game also reports power as it ticks, many times a second. That is worth it for the frames
-- a player watches closely, and not for forty raid frames.
Power.closeEvents = { "UNIT_POWER_FREQUENT" }

function Power.Wanted(cfg)
	return cfg.powerHeight > 0
end

function Power.Create(frame)
	local bar = CreateFrame("StatusBar", nil, frame.body)
	bar.trough = bar:CreateTexture(nil, "BACKGROUND")
	bar.trough:SetAllPoints(bar)
	frame.power = bar
end

function Power.Layout(frame, cfg, on)
	local bar, pixel = frame.power, frame.pixel
	bar:SetShown(on)
	if not on then
		return
	end
	bar:ClearAllPoints()
	bar:SetPoint("BOTTOMLEFT", frame.body, "BOTTOMLEFT", frame.barLeft, pixel)
	bar:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -frame.barRight, pixel)
	bar:SetHeight(frame.powerHeight)
	bar:SetStatusBarTexture(Style.texture)
	bar.trough:SetTexture(Style.texture)
end

-- The bar in a colour, and the empty part behind it in the same colour, darkened as the theme
-- darkens the empty part of a health bar.
local function Colour(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b)
	bar.trough:SetVertexColor(Style.Veiled(r, g, b))
end

function Power.Update(frame, unit, event)
	local bar = frame.power
	if not UnitIsConnected(unit) then
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		Colour(bar, Style.Toned(Style.REACTION.gone))
		return
	end
	-- Which power the unit runs on is never sealed; how much of it there is can be.
	local powerType, token = UnitPowerType(unit)
	Colour(bar, Style.PowerColor(token))
	Sealed.PowerToBar(bar, unit, powerType, event ~= nil and ns.db.smooth)
end

Frame.Register(Power)
