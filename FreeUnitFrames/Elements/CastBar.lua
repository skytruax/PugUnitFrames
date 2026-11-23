local ADDON, ns = ...

-- The cast bar, under the plate: the spell's icon, its name, a timer that fills for a cast and
-- drains for a channel, and a shield while it cannot be interrupted.
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

function CastBar.Wanted(cfg)
	return cfg.castbar
end

function CastBar.Create(frame)
	local cast = CreateFrame("Frame", nil, frame.body)
	cast.back = cast:CreateTexture(nil, "BACKGROUND")
	cast.back:SetAllPoints(cast)
	cast.edge = Frame.MakeEdge(cast, "BORDER")
	cast.icon = cast:CreateTexture(nil, "ARTWORK")
	cast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trims the icon's own border
	cast.bar = CreateFrame("StatusBar", nil, cast)
	cast.text = cast.bar:CreateFontString(nil, "OVERLAY")
	cast.text:SetWordWrap(false)
	cast.text:SetJustifyH("LEFT")
	cast.shield = cast.bar:CreateTexture(nil, "OVERLAY")
	cast.shield:SetTexture(ns.ART .. "Mark-Shield")
	cast.shield:SetAlpha(0)
	-- What Sealed.CastToParts draws on.
	cast.parts = { bar = cast.bar, text = cast.text, icon = cast.icon, shield = cast.shield }
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
		cast.bar:SetStatusBarColor(Style.Toned(Style.CAST))
		cast:Show()
		return
	end

	if event == "UNIT_SPELLCAST_INTERRUPTED" and cast:IsShown() and not cast.held then
		-- Leave it up for a moment, full and red, so the interrupt is seen.
		cast.held = true
		cast.bar:SetMinMaxValues(0, 1)
		cast.bar:SetValue(1)
		cast.bar:SetStatusBarColor(Style.Toned(INTERRUPTED))
		cast.text:SetText(L["Interrupted"])
		cast.shield:SetAlpha(0)
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
