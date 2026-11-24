local ADDON, ns = ...

-- The health bar, and on it the healing that is on its way.
local Frame, Style, Sealed = ns.Frame, ns.Style, ns.Sealed

local Health = { name = "Health" }

Health.events = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_CONNECTION", "UNIT_FACTION", "UNIT_HEAL_PREDICTION" }

function Health.Wanted()
	return true
end

function Health.Create(frame)
	local bar = CreateFrame("StatusBar", nil, frame.body)
	-- The empty part of the bar is the bar's own colour, darkened: the colour laid down once more
	-- with the theme's dark veil over it. One over the other takes no arithmetic, so it works
	-- with a colour the game has sealed, which could not be made darker by multiplying.
	bar.trough = bar:CreateTexture(nil, "BACKGROUND", nil, 0)
	bar.trough:SetAllPoints(bar)
	bar.veil = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
	bar.veil:SetAllPoints(bar)

	-- Healing on its way is a second bar that starts where the health ends and uses the same
	-- scale, so its length is the heal's size. Whatever would run past full health is cut off.
	bar.heal = CreateFrame("StatusBar", nil, bar)
	bar:SetClipsChildren(true)

	frame.health = bar
end

function Health.Layout(frame, cfg)
	local bar, pixel, theme = frame.health, frame.pixel, Style.theme
	local above = frame.powerHeight > 0 and frame.powerHeight + 2 * pixel or pixel

	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", frame.body, "TOPLEFT", frame.barLeft, -pixel)
	bar:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -frame.barRight, above)
	bar:SetStatusBarTexture(Style.texture)
	bar.trough:SetTexture(Style.texture)
	bar.veil:SetColorTexture(theme.veil[1], theme.veil[2], theme.veil[3], theme.shade)

	local heal, fill = bar.heal, bar:GetStatusBarTexture()
	heal:ClearAllPoints()
	heal:SetPoint("TOPLEFT", fill, "TOPRIGHT")
	heal:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
	heal:SetWidth(frame.barWidth)
	heal:SetStatusBarTexture(Style.texture)
	heal:SetStatusBarColor(Style.HEAL[1], Style.HEAL[2], Style.HEAL[3], Style.HEAL[4])
	heal:SetShown(cfg.heals and true or false)
end

-- The bar and the empty part behind it take the same colour (which may be sealed numbers: they
-- are only handed on).
local function Colour(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b)
	bar.trough:SetVertexColor(r, g, b)
end

local function Paint(bar, unit, cfg)
	if cfg.color == "health" and Sealed.HealthShareToBarColor(bar, unit, Style.healthCurve, bar.trough) then
		return
	end
	if cfg.color == "plain" then
		Colour(bar, Style.Toned(Style.theme.plain))
		return
	end
	if cfg.color == "class" and UnitIsPlayer(unit) then
		local r, g, b, plain = Sealed.ClassColor(unit)
		if r then
			if plain then
				local tone = Style.theme.tone
				r, g, b = Style.Readable(r * tone, g * tone, b * tone)
			end
			Colour(bar, r, g, b)
			return
		end
	end
	Colour(bar, Style.Readable(Style.ReactionColor(unit)))
end

function Health.Update(frame, unit, event)
	local bar, cfg = frame.health, frame.cfg
	-- Someone who is dead or has gone offline has an empty bar, whatever number the game still holds.
	if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		bar.heal:SetMinMaxValues(0, 1)
		bar.heal:SetValue(0)
		-- All of the bar is its empty part now: grey, whoever it was.
		bar.trough:SetVertexColor(Style.Toned(Style.REACTION.gone))
		return
	end
	-- A bar glides to a new value of the same unit. When the frame has just been pointed at
	-- someone else (no event) it jumps, or it would sweep from the last unit's health to this one's.
	Sealed.HealthToBar(bar, unit, event ~= nil and ns.db.smooth)
	Paint(bar, unit, cfg)
	if cfg.heals then
		Sealed.IncomingHealsToBar(bar.heal, unit)
	end
end

Frame.Register(Health)
