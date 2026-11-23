local ADDON, ns = ...

-- The player's totems: four small icons under the plate, each with the sweep of its time left.
local Frame, Style, Sealed = ns.Frame, ns.Style, ns.Sealed

local Totems = { name = "Totems" }

Totems.worldEvents = { "PLAYER_TOTEM_UPDATE", "PLAYER_ENTERING_WORLD" }

local SLOTS = 4
local SIZE = 22
local GAP = 3

function Totems.Wanted(cfg, kind)
	return cfg.totems and kind == "player" and Sealed.PlayerClassFile() == "SHAMAN" or false
end

function Totems.Create(frame)
	local holder = CreateFrame("Frame", nil, frame.body)
	local buttons = {}
	for slot = 1, SLOTS do
		local button = CreateFrame("Frame", nil, holder)
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetAllPoints(button)
		button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trims the icon's own border
		button.edge = Frame.MakeEdge(button, "OVERLAY")
		button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
		button.cooldown:SetAllPoints(button)
		button.cooldown:SetReverse(true)
		button.cooldown:SetDrawEdge(false)
		button:SetAlpha(0)
		buttons[slot] = button
	end
	frame.totems = { holder = holder, buttons = buttons }
end

function Totems.Layout(frame, cfg, on)
	local totems = frame.totems
	totems.holder:SetShown(on)
	if not on then
		return
	end
	local offset = Frame.TakeBelow(frame, SIZE)
	totems.holder:ClearAllPoints()
	totems.holder:SetPoint("TOPLEFT", frame.body, "BOTTOMLEFT", 0, -offset)
	totems.holder:SetSize(SLOTS * (SIZE + GAP) - GAP, SIZE)
	for slot, button in ipairs(totems.buttons) do
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", totems.holder, "TOPLEFT", (slot - 1) * (SIZE + GAP), 0)
		button:SetSize(SIZE, SIZE)
		Frame.LayoutEdge(button.edge, button, frame.pixel, Style.theme.edge)
	end
end

function Totems.Update(frame)
	for slot, button in ipairs(frame.totems.buttons) do
		Sealed.TotemToButton(button, slot)
	end
end

Frame.Register(Totems)
