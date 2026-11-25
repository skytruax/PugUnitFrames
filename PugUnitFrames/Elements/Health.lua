local ADDON, ns = ...

-- The health bar, and after the health on it, the healing that is on its way and the shields
-- that soak up damage.
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

	-- A shield (Power Word: Shield and its like) is drawn the same way, in a pale colour: a
	-- third bar that starts where the healing on its way ends, on the same scale again, so its
	-- length is the shield's size. Only as much of it is drawn as there is room for before the
	-- end of the health bar. When there is more shield than room, a pale cap lights up on the
	-- end of the bar: that is all a shield on someone at full health has to show, which is when
	-- a shield is usually cast.
	bar.shield = CreateFrame("StatusBar", nil, bar)
	bar.shield:SetFrameLevel(bar.heal:GetFrameLevel() + 1)
	-- The cap sits over the three bars.
	bar.capHolder = CreateFrame("Frame", nil, bar)
	bar.capHolder:SetAllPoints(bar)
	bar.capHolder:SetFrameLevel(bar.shield:GetFrameLevel() + 1)
	bar.cap = bar.capHolder:CreateTexture(nil, "OVERLAY")
	bar.cap:SetColorTexture(1, 1, 1, 1)
	bar.cap:SetAlpha(0)

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
		heal:SetWidth(math.max(1, frame.barWidth))
	else
		heal:SetPoint("TOPLEFT", fill, "TOPRIGHT")
		heal:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
		heal:SetWidth(math.max(1, frame.barWidth))
	end
	heal:SetStatusBarTexture(Style.texture)
	heal:SetOrientation(orientation)
	heal:SetReverseFill(leftward)
	heal:SetStatusBarColor(Style.HEAL[1], Style.HEAL[2], Style.HEAL[3], Style.HEAL[4])
	heal:SetShown(cfg.heals and true or false)

	-- The shield follows the healing on its way, or the health itself where healing is not drawn.
	local shield, tint = bar.shield, Style.ABSORB
	local before = cfg.heals and heal:GetStatusBarTexture() or fill
	shield:ClearAllPoints()
	if upright then
		shield:SetPoint("BOTTOMLEFT", before, "TOPLEFT")
		shield:SetPoint("BOTTOMRIGHT", before, "TOPRIGHT")
		shield:SetHeight(cfg.height)
	elseif leftward then
		shield:SetPoint("TOPRIGHT", before, "TOPLEFT")
		shield:SetPoint("BOTTOMRIGHT", before, "BOTTOMLEFT")
		shield:SetWidth(math.max(1, frame.barWidth))
	else
		shield:SetPoint("TOPLEFT", before, "TOPRIGHT")
		shield:SetPoint("BOTTOMLEFT", before, "BOTTOMRIGHT")
		shield:SetWidth(math.max(1, frame.barWidth))
	end
	shield:SetStatusBarTexture(Style.texture)
	shield:SetOrientation(orientation)
	shield:SetReverseFill(leftward)
	shield:SetStatusBarColor(tint[1], tint[2], tint[3], tint[4])
	shield:SetShown(cfg.absorbs and true or false)

	-- The cap: the shield's colour on the end the bar fills towards, fading back into the bar.
	local cap, reach = bar.cap, math.max(6, math.floor(cfg.height * 0.2 + 0.5))
	local faint, full = CreateColor(tint[1], tint[2], tint[3], 0), CreateColor(tint[1], tint[2], tint[3], 0.95)
	cap:ClearAllPoints()
	if upright then
		cap:SetPoint("TOPLEFT", bar, "TOPLEFT")
		cap:SetPoint("TOPRIGHT", bar, "TOPRIGHT")
		cap:SetHeight(reach)
		cap:SetGradient("VERTICAL", faint, full)
	elseif leftward then
		cap:SetPoint("TOPLEFT", bar, "TOPLEFT")
		cap:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
		cap:SetWidth(reach)
		cap:SetGradient("HORIZONTAL", full, faint)
	else
		cap:SetPoint("TOPRIGHT", bar, "TOPRIGHT")
		cap:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
		cap:SetWidth(reach)
		cap:SetGradient("HORIZONTAL", faint, full)
	end
	bar.capHolder:SetShown(cfg.absorbs and true or false)
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
		Empty(bar.shield)
		bar.cap:SetAlpha(0)
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
		Sealed.ShieldToBar(bar.shield, bar.cap, unit, cfg.heals and true or false)
	end
end

Frame.Register(Health)
