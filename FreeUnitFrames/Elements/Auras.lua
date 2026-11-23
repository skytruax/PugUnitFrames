local ADDON, ns = ...

-- Buffs and debuffs as rows of icons beside the plate, and for group frames a light on the plate
-- in the colour of a debuff the player can remove.
--
-- Debuffs come first (nearest the plate), buffs start on a fresh row after them. Which auras
-- there are comes from the game already filtered and in order; what each one is can be sealed,
-- so an icon is drawn by handing the aura's id to Sealed.lua and nothing is read back.
local Frame, Style, Sealed = ns.Frame, ns.Style, ns.Sealed

local Auras = { name = "Auras" }

Auras.events = { "UNIT_AURA" }

local GAP = 2
local SIDE_GAP = 4          -- between the plate and icons beside it
local LIGHT_WIDTH = 2       -- pixels of the removable-debuff light along the plate's rim

function Auras.Wanted(cfg)
	return cfg.buffs > 0 or cfg.debuffs > 0 or (cfg.dispel and true or false)
end

---------------------------------------------------------------------------
-- Icons
---------------------------------------------------------------------------
local function OnEnterIcon(self)
	if not self.unit or not self.auraInstanceID then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetUnitAuraByAuraInstanceID(self.unit, self.auraInstanceID)
end

local function OnLeaveIcon()
	GameTooltip:Hide()
end

local function MakeIcon(frame)
	local auras = frame.auras
	local button = CreateFrame("Frame", nil, auras.holder)
	-- The rim is a white square behind the icon, tinted: by the debuff's kind, or dark for a buff.
	button.edge = button:CreateTexture(nil, "BACKGROUND")
	button.edge:SetAllPoints(button)
	button.edge:SetColorTexture(1, 1, 1, 1)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trims the icon's own border
	button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	button.cooldown:SetReverse(true)
	button.cooldown:SetDrawEdge(false)
	button.cooldown:SetHideCountdownNumbers(true)
	-- The stack count sits above the sweep.
	local top = CreateFrame("Frame", nil, button)
	top:SetAllPoints(button)
	top:SetFrameLevel(button.cooldown:GetFrameLevel() + 1)
	button.count = top:CreateFontString(nil, "OVERLAY")
	button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 1)
	button:SetScript("OnEnter", OnEnterIcon)
	button:SetScript("OnLeave", OnLeaveIcon)
	button:Hide()
	auras.icons[#auras.icons + 1] = button
	return button
end

-- Sizes and places icon number `slot` (counted from 0, row by row) for the frame's settings.
local function PlaceIcon(frame, button, slot)
	local cfg, pixel = frame.cfg, frame.pixel
	local size = cfg.auraSize
	local step = size + GAP
	local column, row = slot % cfg.auraPerRow, math.floor(slot / cfg.auraPerRow)
	local body, side = frame.body, cfg.auraSide

	button:ClearAllPoints()
	button:SetSize(size, size)
	if side == "above" then
		button:SetPoint("BOTTOMLEFT", body, "TOPLEFT", column * step, frame.auraOffset + row * step)
	elseif side == "below" then
		button:SetPoint("TOPLEFT", body, "BOTTOMLEFT", column * step, -(frame.auraOffset + row * step))
	elseif side == "right" then
		button:SetPoint("TOPLEFT", body, "TOPRIGHT", SIDE_GAP + column * step, -row * step)
	elseif side == "left" then
		button:SetPoint("TOPRIGHT", body, "TOPLEFT", -(SIDE_GAP + column * step), -row * step)
	else -- inside: from the bottom right corner of the health bar, towards the left
		button:SetPoint("BOTTOMRIGHT", frame.health, "BOTTOMRIGHT", -(pixel + column * (size + pixel)), pixel + row * (size + pixel))
	end
	button.icon:ClearAllPoints()
	button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", pixel, -pixel)
	button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -pixel, pixel)
	button.cooldown:ClearAllPoints()
	button.cooldown:SetAllPoints(button.icon)
	Style.SetFont(button.count, size >= 20 and -1 or -3)
	-- Icons on the plate itself let the mouse through, so a click there still picks the unit.
	button:EnableMouse(side ~= "inside")
end

---------------------------------------------------------------------------
-- The element
---------------------------------------------------------------------------
function Auras.Create(frame)
	local holder = CreateFrame("Frame", nil, frame.body)
	holder:SetAllPoints(frame.body)
	holder:SetFrameLevel(frame.body:GetFrameLevel() + 7)
	local light = {}
	for i = 1, 4 do
		light[i] = holder:CreateTexture(nil, "OVERLAY")
		light[i]:SetColorTexture(1, 1, 1, 1)
		light[i]:Hide()
	end
	frame.auras = { holder = holder, icons = {}, light = light }
end

function Auras.Layout(frame, cfg, on)
	local auras = frame.auras
	auras.holder:SetShown(on)
	if not on then
		return
	end
	-- Rows above or below the plate start past whatever else is stacked there.
	if cfg.auraSide == "above" then
		frame.auraOffset = Frame.TakeAbove(frame, 0)
	elseif cfg.auraSide == "below" then
		frame.auraOffset = Frame.TakeBelow(frame, 0)
	else
		frame.auraOffset = 0
	end
	for _, button in ipairs(auras.icons) do
		button:Hide()
	end

	local width, body = LIGHT_WIDTH * frame.pixel, frame.body
	local top, bottom, left, right = auras.light[1], auras.light[2], auras.light[3], auras.light[4]
	for i = 1, 4 do
		auras.light[i]:ClearAllPoints()
		auras.light[i]:Hide()
	end
	top:SetPoint("TOPLEFT", body, "TOPLEFT")
	top:SetPoint("TOPRIGHT", body, "TOPRIGHT")
	top:SetHeight(width)
	bottom:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT")
	bottom:SetHeight(width)
	left:SetPoint("TOPLEFT", body, "TOPLEFT")
	left:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT")
	left:SetWidth(width)
	right:SetPoint("TOPRIGHT", body, "TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT")
	right:SetWidth(width)
end

-- Draws the auras with these ids on the next icons, from grid slot `slot` on. Returns the slot
-- after the last one drawn.
local function DrawBlock(frame, unit, ids, slot, kindCurve)
	local auras, edge = frame.auras, Style.theme.edge
	for _, id in ipairs(ids) do
		auras.used = auras.used + 1
		local button = auras.icons[auras.used] or MakeIcon(frame)
		PlaceIcon(frame, button, slot)
		if not kindCurve then
			button.edge:SetVertexColor(edge[1], edge[2], edge[3])
		end
		if Sealed.AuraToButton(button, unit, id, kindCurve) then
			button.unit, button.auraInstanceID = unit, id
			button:Show()
			slot = slot + 1
		else
			auras.used = auras.used - 1
		end
	end
	return slot
end

local function Draw(frame, unit)
	local auras, cfg = frame.auras, frame.cfg
	auras.used = 0
	local slot = 0
	if cfg.debuffs > 0 then
		local ids = Sealed.AuraIDs(unit, cfg.myDebuffs and "HARMFUL|PLAYER" or "HARMFUL", cfg.debuffs)
		slot = DrawBlock(frame, unit, ids, slot, Style.debuffKindCurve)
	end
	if cfg.buffs > 0 then
		-- Buffs start on a fresh row.
		slot = math.ceil(slot / cfg.auraPerRow) * cfg.auraPerRow
		DrawBlock(frame, unit, Sealed.AuraIDs(unit, "HELPFUL", cfg.buffs), slot, nil)
	end
	for index = auras.used + 1, #auras.icons do
		auras.icons[index]:Hide()
		auras.icons[index].auraInstanceID = nil
	end

	if cfg.dispel then
		-- "RAID" on a harmful aura means: one the player can remove.
		local id = Sealed.AuraIDs(unit, "HARMFUL|RAID", 1)[1]
		local lit = id ~= nil and Sealed.AuraKindToColor(auras.light, unit, id, Style.debuffKindCurve)
		for i = 1, 4 do
			auras.light[i]:SetShown(lit and true or false)
		end
	end
end

-- Auras change in bursts (a pull, a dispel, a raid buff): a frame told several times in one
-- moment is drawn once, on the next screen update.
local waiting = {}
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self)
	self:Hide()
	local list = waiting
	waiting = {}
	for frame in pairs(list) do
		if frame.unit and frame.active.Auras and frame:IsVisible() and UnitExists(frame.unit) then
			ns.Try(Draw, frame, frame.unit)
		end
	end
end)

function Auras.Update(frame, unit, event)
	if event == nil then
		Draw(frame, unit)
	else
		waiting[frame] = true
		driver:Show()
	end
end

Frame.Register(Auras)
