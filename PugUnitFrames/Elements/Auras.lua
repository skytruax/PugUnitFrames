local ADDON, ns = ...

-- Buffs and debuffs as rows of icons beside the plate, and for group frames a light on the plate
-- in the colour of a debuff the player can remove.
--
-- Buffs and debuffs each have a side of the plate (above, below, left, right, or on it). On the
-- same side the debuffs come first, nearest the plate, and the buffs start on a fresh row after
-- them. Which auras there are comes from the game already filtered and in order; what each one
-- is can be sealed, so an icon is drawn by handing the aura's id to Sealed.lua and nothing is
-- read back.
local Frame, Style, Sealed = ns.Frame, ns.Style, ns.Sealed

local Auras = { name = "Auras" }

Auras.events = { "UNIT_AURA" }

local GAP = 2
local SIDE_GAP = 4          -- between the plate and icons beside it
local STACK_GAP = 3         -- between the plate and icons above or below it (Frame.TakeAbove)
local LIGHT_WIDTH = 2       -- pixels of the removable-debuff light along the plate's rim
local PULSE = 0.55          -- seconds for that light to dim, and again to come back
local PULSE_LOW = 0.35      -- how far it dims

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

-- Sizes and places icon number `slot` of a side (counted from 0, row by row) for the frame's
-- settings.
local function PlaceIcon(frame, button, slot, side)
	local cfg, pixel = frame.cfg, frame.pixel
	local size = cfg.auraSize
	local step = size + GAP
	local column, row = slot % cfg.auraPerRow, math.floor(slot / cfg.auraPerRow)
	local body = frame.body

	button:ClearAllPoints()
	button:SetSize(size, size)
	if side == "above" then
		button:SetPoint("BOTTOMLEFT", body, "TOPLEFT", column * step, frame.auraAbove + row * step)
	elseif side == "below" then
		button:SetPoint("TOPLEFT", body, "BOTTOMLEFT", column * step, -(frame.auraBelow + row * step))
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
	-- The time left as a number on the icon, written by the game itself, for those who want it.
	button.cooldown:SetHideCountdownNumbers(not ns.db.auraTimers)
	button.cooldown:SetCountdownFont(Style.TIMER_FONT)
	-- The count of stacks is always outlined: on a bright icon (Inner Fire, a paladin's seal)
	-- light figures with only a soft shadow cannot be read.
	Style.SetFont(button.count, size >= 20 and -1 or -3, true)
	button.count:SetTextColor(Style.theme.text[1], Style.theme.text[2], Style.theme.text[3])
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
	-- The light for a debuff the player can remove: four lines along the plate's rim, on a frame
	-- of their own so that they can pulse together. A steady line is easy to miss in a fight; one
	-- that breathes is not.
	local lamp = CreateFrame("Frame", nil, holder)
	lamp:SetAllPoints(holder)
	lamp:Hide()
	local light = {}
	for i = 1, 4 do
		light[i] = lamp:CreateTexture(nil, "OVERLAY")
		light[i]:SetColorTexture(1, 1, 1, 1)
	end
	local pulse = lamp:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local dim = pulse:CreateAnimation("Alpha")
	dim:SetFromAlpha(1)
	dim:SetToAlpha(PULSE_LOW)
	dim:SetDuration(PULSE)
	dim:SetSmoothing("IN_OUT")
	frame.auras = { holder = holder, icons = {}, light = light, lamp = lamp, pulse = pulse }
end

-- Which sides of the plate have icons, and how many rows and columns of them at most.
local function Sides(cfg)
	local sides = {}
	local function Add(side, count)
		if count > 0 then
			local there = sides[side] or { rows = 0, columns = 0 }
			there.rows = there.rows + math.ceil(count / cfg.auraPerRow)
			there.columns = math.max(there.columns, math.min(count, cfg.auraPerRow))
			sides[side] = there
		end
	end
	Add(cfg.debuffSide, cfg.debuffs)
	Add(cfg.buffSide, cfg.buffs)
	return sides
end

-- The room the icons can take outside the plate, on each of its four sides. Group.lua keeps
-- the members of a group that far apart, so one member's icons never lie on the next one's plate.
function Auras.Room(cfg)
	local room = { above = 0, below = 0, left = 0, right = 0 }
	local step = cfg.auraSize + GAP
	local sides = Sides(cfg)
	for _, side in ipairs({ "above", "below" }) do
		local there = sides[side]
		if there then
			room[side] = STACK_GAP + there.rows * step - GAP
			-- Rows above or below start at the plate's left end and may run past its right end.
			room.right = math.max(room.right, there.columns * step - GAP - cfg.width)
		end
	end
	for _, side in ipairs({ "left", "right" }) do
		local there = sides[side]
		if there then
			room[side] = math.max(room[side], SIDE_GAP + there.columns * step - GAP)
			-- Rows beside the plate start at its top and may hang lower than its bottom edge.
			room.below = math.max(room.below, there.rows * step - GAP - cfg.height)
		end
	end
	return room
end

function Auras.Layout(frame, cfg, on)
	local auras = frame.auras
	auras.holder:SetShown(on)
	if not on then
		return
	end
	-- Rows above or below the plate start past whatever else is stacked there.
	local sides = Sides(cfg)
	frame.auraAbove = sides.above and Frame.TakeAbove(frame, 0) or 0
	frame.auraBelow = sides.below and Frame.TakeBelow(frame, 0) or 0
	for _, button in ipairs(auras.icons) do
		button:Hide()
	end

	local width, body = LIGHT_WIDTH * frame.pixel, frame.body
	local top, bottom, left, right = auras.light[1], auras.light[2], auras.light[3], auras.light[4]
	for i = 1, 4 do
		auras.light[i]:ClearAllPoints()
	end
	auras.pulse:Stop()
	auras.lamp:Hide()
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
local function DrawBlock(frame, unit, ids, slot, side, kindCurve)
	local auras, edge = frame.auras, Style.theme.edge
	for _, id in ipairs(ids) do
		auras.used = auras.used + 1
		local button = auras.icons[auras.used] or MakeIcon(frame)
		PlaceIcon(frame, button, slot, side)
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
	local taken = 0 -- slots the debuffs have used on their side
	if cfg.debuffs > 0 then
		local ids = Sealed.AuraIDs(unit, cfg.myDebuffs and "HARMFUL|PLAYER" or "HARMFUL", cfg.debuffs)
		taken = DrawBlock(frame, unit, ids, 0, cfg.debuffSide, Style.debuffKindCurve)
	end
	if cfg.buffs > 0 then
		-- On the debuffs' side the buffs start on a fresh row after them; on a side of their own,
		-- at its beginning.
		local slot = cfg.buffSide == cfg.debuffSide and math.ceil(taken / cfg.auraPerRow) * cfg.auraPerRow or 0
		DrawBlock(frame, unit, Sealed.AuraIDs(unit, cfg.myBuffs and "HELPFUL|PLAYER" or "HELPFUL", cfg.buffs), slot, cfg.buffSide, nil)
	end
	for index = auras.used + 1, #auras.icons do
		auras.icons[index]:Hide()
		auras.icons[index].auraInstanceID = nil
	end

	if cfg.dispel then
		-- "RAID" on a harmful aura means: one the player can remove.
		local id = Sealed.AuraIDs(unit, "HARMFUL|RAID", 1)[1]
		local lit = id ~= nil and Sealed.AuraKindToColor(auras.light, unit, id, Style.debuffKindCurve) or false
		if lit ~= auras.lamp:IsShown() then
			auras.lamp:SetShown(lit)
			if lit then
				auras.pulse:Play()
			else
				auras.pulse:Stop()
			end
		end
	elseif auras.lamp:IsShown() then
		auras.pulse:Stop()
		auras.lamp:Hide()
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
