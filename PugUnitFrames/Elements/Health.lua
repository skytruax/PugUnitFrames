local ADDON, ns = ...

-- The health bar, and on it the healing that is on its way and the shields that soak up damage.
local Frame, Style, Sealed = ns.Frame, ns.Style, ns.Sealed

local Health = { name = "Health" }

Health.events = {
	"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_CONNECTION", "UNIT_FACTION", "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED",
}

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

	-- A shield (Power Word: Shield and its like) is a pale band along the top of the bar, on the
	-- same scale again: as long as the shield is large against full health. It starts at the
	-- bar's own start and not where the health ends, so it shows on someone at full health too,
	-- which is when a shield is usually cast.
	bar.absorb = CreateFrame("StatusBar", nil, bar)
	bar.absorb:SetFrameLevel(bar.heal:GetFrameLevel() + 1)

	frame.health = bar
end

-- Gives the bar the room the plate has for it: all of it down to the power bar, or down to the
-- plate's edge when there is no power bar or it has been put away (Power.lua). The bars are
-- ordinary frames, so this is done in a fight as well.
function Health.Fit(frame)
	local bar, pixel = frame.health, frame.pixel
	local powered = frame.powerHeight > 0 and not frame.powerGone
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", frame.body, "TOPLEFT", frame.barLeft, -pixel)
	bar:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -frame.barRight, powered and frame.powerHeight + 2 * pixel or pixel)
end

function Health.Layout(frame, cfg)
	local bar, pixel, theme = frame.health, frame.pixel, Style.theme
	-- Which way the bar fills: to the right, to the left (a target frame that mirrors the
	-- player's), or upwards (small raid frames read well that way).
	local upright, leftward = cfg.fill == "up", cfg.fill == "left"
	local orientation = upright and "VERTICAL" or "HORIZONTAL"

	Health.Fit(frame)
	bar:SetStatusBarTexture(Style.texture)
	bar:SetOrientation(orientation)
	bar:SetReverseFill(leftward)
	bar.trough:SetTexture(Style.texture)
	bar.veil:SetColorTexture(theme.veil[1], theme.veil[2], theme.veil[3], theme.shade)

	-- Turned round, the bar itself is dark and the colour shows where health is missing: the
	-- colour goes on the part behind the bar, bare, and the bar is the theme's dark tone.
	bar.inverted = cfg.invert and true or false
	bar.veil:SetShown(not bar.inverted)
	if bar.inverted then
		bar:SetStatusBarColor(Style.Veiled(Style.Toned(theme.plain)))
	end

	local heal, fill = bar.heal, bar:GetStatusBarTexture()
	heal:ClearAllPoints()
	if upright then
		heal:SetPoint("BOTTOMLEFT", fill, "TOPLEFT")
		heal:SetPoint("BOTTOMRIGHT", fill, "TOPRIGHT")
		heal:SetHeight(cfg.height)
	elseif leftward then
		heal:SetPoint("TOPRIGHT", fill, "TOPLEFT")
		heal:SetPoint("BOTTOMRIGHT", fill, "BOTTOMLEFT")
		heal:SetWidth(frame.barWidth)
	else
		heal:SetPoint("TOPLEFT", fill, "TOPRIGHT")
		heal:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
		heal:SetWidth(frame.barWidth)
	end
	heal:SetStatusBarTexture(Style.texture)
	heal:SetOrientation(orientation)
	heal:SetReverseFill(leftward)
	heal:SetStatusBarColor(Style.HEAL[1], Style.HEAL[2], Style.HEAL[3], Style.HEAL[4])
	heal:SetShown(cfg.heals and true or false)

	local absorb = bar.absorb
	absorb:ClearAllPoints()
	absorb:SetPoint("TOPLEFT", bar, "TOPLEFT")
	absorb:SetPoint("TOPRIGHT", bar, "TOPRIGHT")
	absorb:SetHeight(math.max(2 * pixel, math.floor(cfg.height * 0.10 + 0.5)))
	absorb:SetStatusBarTexture(Style.TEXTURES.flat)
	absorb:SetReverseFill(leftward)
	absorb:SetStatusBarColor(Style.ABSORB[1], Style.ABSORB[2], Style.ABSORB[3], Style.ABSORB[4])
	absorb:SetShown(cfg.absorbs and true or false)
end

-- The bar and the empty part behind it take the same colour (which may be sealed numbers: they
-- are only handed on). A bar turned round keeps its dark tone and only the part behind changes.
local function Colour(bar, r, g, b)
	if not bar.inverted then
		bar:SetStatusBarColor(r, g, b)
	end
	bar.trough:SetVertexColor(r, g, b)
end

local function Paint(bar, unit, cfg)
	-- Someone else's kill is grey whatever colours the bar otherwise: there is nothing in it for
	-- the player, and the game's own target frame says so the same way.
	if not UnitIsPlayer(unit) and UnitIsTapDenied(unit) then
		Colour(bar, Style.Toned(Style.REACTION.tapped))
		return
	end
	if cfg.color == "health" and Sealed.HealthShareToBarColor(not bar.inverted and bar or nil, unit, Style.healthCurve, bar.trough) then
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

local function Empty(bar)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
end

function Health.Update(frame, unit, event)
	local bar, cfg = frame.health, frame.cfg
	-- Someone who is dead or has gone offline has an empty bar, whatever number the game still holds.
	if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
		Empty(bar)
		Empty(bar.heal)
		Empty(bar.absorb)
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
	if cfg.absorbs then
		Sealed.AbsorbsToBar(bar.absorb, unit)
	end
end

Frame.Register(Health)
