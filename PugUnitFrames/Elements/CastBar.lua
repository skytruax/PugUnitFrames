local ADDON, ns = ...

-- The cast bar, under the plate: the spell's icon, its name, a timer that fills for a cast and
-- drains for a channel with a bright edge where the fill ends, and a shield while it cannot be
-- interrupted. Where the frame asks for it, such a cast is also a greyed orange and not the
-- cast's gold, so that it is told apart before the shield is looked for.
local Frame, Style, Sealed = ns.Frame, ns.Style, ns.Sealed
local L = ns.L

local CastBar = { name = "CastBar" }

CastBar.events = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
	"UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

local INTERRUPT_HOLD = 0.7 -- seconds an interrupted cast stays up, in red
local INTERRUPTED = { 0.86, 0.24, 0.20 }
local SPARK_ALPHA = 0.75
local LOOK_AGAIN = 0.25    -- seconds between looks at a cast that is on show

function CastBar.Wanted(cfg)
	return cfg.castbar
end

-- A cast colour as Sealed.CastToParts takes it: the fill, then the empty part behind it, which
-- is the same colour darkened as the empty part of a health bar is.
local function Tints(color)
	local r, g, b = Style.Toned(color)
	local behindR, behindG, behindB = Style.Veiled(r, g, b)
	return { r, g, b, behindR, behindG, behindB }
end

-- The bar and its shadow, fully there (they are made see-through when a cast's time is up).
local function Solid(cast)
	for _, region in ipairs(cast.fading) do
		region:SetAlpha(1)
	end
end

-- A cast bar goes away when the game says the cast has ended. It does not always say so (a party
-- member out of sight; players report a hunter's Aimed Shot standing on the party frames for
-- good, the game's own included). So a bar that is up is looked at again a few times a second:
-- it is put away if the unit is plainly not casting, and unseen once the cast's time has run out.
local function LookAgain(cast)
	local frame = cast.frame
	if cast.held or not frame.unit or not frame.active.CastBar then
		return
	end
	if not Sealed.CastTimeLeftToAlpha(cast.fading, frame.unit) then
		cast:Hide()
	end
end

local function OnUpdate(cast, elapsed)
	cast.since = cast.since + elapsed
	if cast.since >= LOOK_AGAIN then
		cast.since = 0
		ns.Try(LookAgain, cast)
	end
end

function CastBar.Create(frame)
	local cast = CreateFrame("Frame", nil, frame.body)
	cast.frame = frame
	cast.since = 0
	cast.back = cast:CreateTexture(nil, "BACKGROUND")
	cast.back:SetAllPoints(cast)
	cast.edge = Frame.MakeEdge(cast, "BORDER")
	cast.icon = cast:CreateTexture(nil, "ARTWORK")
	cast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trims the icon's own border
	cast.bar = CreateFrame("StatusBar", nil, cast)
	cast.trough = cast.bar:CreateTexture(nil, "BACKGROUND")
	cast.trough:SetAllPoints(cast.bar)
	-- The bright edge rides the end of the fill: it is pinned to the edge of the bar's own fill
	-- texture, which the game moves, so nothing here has to know how far the cast is. What of
	-- its glow would reach past the bar is cut off.
	cast.bar:SetClipsChildren(true)
	cast.spark = cast.bar:CreateTexture(nil, "ARTWORK", nil, 1)
	cast.spark:SetTexture(ns.ART .. "Spark")
	cast.spark:SetBlendMode("ADD")
	cast.spark:SetAlpha(SPARK_ALPHA)
	cast.shadow = Frame.MakeShadow(frame, cast)
	cast.text = cast.bar:CreateFontString(nil, "OVERLAY")
	cast.text:SetWordWrap(false)
	cast.text:SetJustifyH("LEFT")
	cast.shield = cast.bar:CreateTexture(nil, "OVERLAY")
	cast.shield:SetTexture(ns.ART .. "Mark-Shield")
	cast.shield:SetAlpha(0)
	-- What Sealed.CastToParts draws on.
	cast.parts = { bar = cast.bar, trough = cast.trough, text = cast.text, icon = cast.icon, shield = cast.shield }
	cast.fading = { cast, cast.shadow.holder }
	cast:SetScript("OnUpdate", OnUpdate)
	cast:Hide()
	frame.cast = cast
end

function CastBar.Layout(frame, cfg, on)
	local cast, pixel, theme = frame.cast, frame.pixel, Style.theme
	if not on then
		cast:Hide()
		return
	end
	local height = cfg.castHeight
	local offset = Frame.TakeBelow(frame, height)
	local square = height - 2 * pixel

	cast:ClearAllPoints()
	cast:SetPoint("TOPLEFT", frame.body, "BOTTOMLEFT", 0, -offset)
	cast:SetPoint("TOPRIGHT", frame.body, "BOTTOMRIGHT", 0, -offset)
	cast:SetHeight(height)
	cast.back:SetColorTexture(theme.back[1], theme.back[2], theme.back[3], theme.back[4])
	Frame.LayoutEdge(cast.edge, cast, pixel, theme.edge)

	cast.icon:ClearAllPoints()
	cast.icon:SetPoint("TOPLEFT", cast, "TOPLEFT", pixel, -pixel)
	cast.icon:SetSize(square, square)

	cast.bar:ClearAllPoints()
	cast.bar:SetPoint("TOPLEFT", cast.icon, "TOPRIGHT", pixel, 0)
	cast.bar:SetPoint("BOTTOMRIGHT", cast, "BOTTOMRIGHT", -pixel, pixel)
	cast.bar:SetStatusBarTexture(Style.texture)
	cast.trough:SetTexture(Style.texture)
	-- The colours a cast is drawn in (Sealed.CastToParts lays them on when one begins).
	local open = Tints(Style.CAST)
	cast.parts.open = open
	cast.parts.shut = cfg.castLocked and Tints(Style.CAST_LOCKED) or nil
	cast.trough:SetVertexColor(open[4], open[5], open[6])

	local fill = cast.bar:GetStatusBarTexture()
	cast.spark:ClearAllPoints()
	cast.spark:SetPoint("TOP", fill, "TOPRIGHT")
	cast.spark:SetPoint("BOTTOM", fill, "BOTTOMRIGHT")
	cast.spark:SetWidth(math.max(8, height))
	Frame.LayoutShadow(cast.shadow, cast)

	Style.SetFont(cast.text, height >= 14 and -1 or -3)
	cast.text:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
	cast.text:ClearAllPoints()
	cast.text:SetPoint("LEFT", cast.bar, "LEFT", 4, 0)
	cast.text:SetPoint("RIGHT", cast.bar, "RIGHT", -(square + 4), 0)

	cast.shield:ClearAllPoints()
	cast.shield:SetPoint("RIGHT", cast.bar, "RIGHT", -2, 0)
	cast.shield:SetSize(square, square)
end

function CastBar.Update(frame, unit, event)
	local cast = frame.cast
	-- The player among the party frames: the player's own frame already shows that cast.
	if frame.kind == "party" and unit == "player" then
		cast:Hide()
		return
	end
	local casting, id = Sealed.CastToParts(cast.parts, unit)
	if casting then
		cast.id = id
		cast.held = false
		cast.since = 0
		Solid(cast)
		cast.spark:Show()
		cast:Show()
		return
	end

	if event == "UNIT_SPELLCAST_INTERRUPTED" and cast:IsShown() and not cast.held then
		-- Leave it up for a moment, full and red, so the interrupt is seen.
		cast.held = true
		Solid(cast)
		cast.bar:SetMinMaxValues(0, 1)
		cast.bar:SetValue(1)
		cast.bar:SetStatusBarColor(Style.Toned(INTERRUPTED))
		cast.text:SetText(L["Interrupted"])
		cast.shield:SetAlpha(0)
		cast.spark:Hide()
		ns.After(INTERRUPT_HOLD, function()
			if cast.held then
				cast.held = false
				-- Shows a cast that began in the meantime, or puts the bar away.
				if frame.unit and frame.active.CastBar then
					CastBar.Update(frame, frame.unit)
				else
					cast:Hide()
				end
			end
		end)
		return
	end

	if not cast.held then
		cast:Hide()
	end
end

Frame.Register(CastBar)
