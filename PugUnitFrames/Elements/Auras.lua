local ADDON, ns = ...

-- Buffs and debuffs as rows of icons beside the plate, and for group frames a light on the plate
-- in the colour of a debuff the player can remove.
--
-- On this client an addon may not ask which auras a unit has while the game keeps auras sealed,
-- which is above all in a fight: every such question is an error then, not a sealed answer.
-- What the game offers in its place is its own aura container: a frame an addon creates and
-- sets up (which unit, which auras, how many, in what rows), and which the game itself fills
-- with one button for each aura, in a fight and out of it. The addon makes the parts of a
-- button as the game creates it (an icon, a sweep for the time left, a count of stacks, a rim)
-- and hands them over; the game puts each aura on them. So this file never learns what any
-- aura is, and never asks.
--
-- Buffs and debuffs each have a side of the plate (above, below, left, right, or on it), and
-- every side in use has a container of its own. On a shared side the debuffs come first,
-- nearest the plate, and the buffs start on a fresh row after them.
local Frame, Style = ns.Frame, ns.Style

local Auras = { name = "Auras" }

-- The containers hear of auras changing themselves. This only waits for a fight to end, to
-- bring the buttons' look up to date where that had to wait.
Auras.worldEvents = { "PLAYER_REGEN_ENABLED" }

local GAP = 2
local SIDE_GAP = 4          -- between the plate and icons beside it
local STACK_GAP = 3         -- between the plate and icons above or below it (Frame.TakeAbove)
local LOOK_AFRESH = 1       -- seconds between fresh looks at the auras of a unit the game sends no news of
local LIGHT_WIDTH = 2       -- pixels of the removable-debuff light along the plate's rim
local PULSE = 0.55          -- seconds for that light to dim, and again to come back
local PULSE_LOW = 0.35      -- how far it dims

local SIDES = { "above", "below", "left", "right", "inside" }
local KINDS = { "debuffs", "buffs" } -- in the order they are laid out
local MINE = { debuffs = "myDebuffs", buffs = "myBuffs" }
local SIDE_OF = { debuffs = "debuffSide", buffs = "buffSide" }
local FILTER = { debuffs = "HARMFUL", buffs = "HELPFUL" }

function Auras.Wanted(cfg)
	return cfg.buffs > 0 or cfg.debuffs > 0 or (cfg.dispel and true or false)
end

---------------------------------------------------------------------------
-- What the settings ask for
---------------------------------------------------------------------------
-- Which sides of the plate have icons: per side, how many of each kind at most, and how many
-- rows and columns that can come to.
local function Sides(cfg)
	local sides = {}
	for _, kind in ipairs(KINDS) do
		-- Whole icons only: the game takes no half button, and a settings file can be edited by hand.
		local count = math.floor(cfg[kind])
		if count > 0 then
			local side = cfg[SIDE_OF[kind]]
			local there = sides[side] or { rows = 0, columns = 0 }
			there[kind] = count
			there.rows = there.rows + math.ceil(count / cfg.auraPerRow)
			there.columns = math.max(there.columns, math.min(count, cfg.auraPerRow))
			sides[side] = there
		end
	end
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

-- Whether the game is keeping auras sealed right now. While it is, the buttons the game has
-- made are closed to this addon.
local function AurasSealed()
	return C_Secrets.ShouldAurasBeSecret()
end

---------------------------------------------------------------------------
-- A button's parts
---------------------------------------------------------------------------
-- Sizes and letters the parts of one button from the settings. Only possible while auras are
-- not sealed (and as the game creates the button, which is when it first runs).
local function Dress(frame, part)
	local cfg, pixel, theme = frame.cfg, frame.pixel, Style.theme
	local size = cfg.auraSize
	part.button:SetSize(size, size)
	-- Icons on the plate itself let the mouse through, so a click there still picks the unit.
	part.button:EnableMouse(part.side ~= "inside")
	part.icon:ClearAllPoints()
	part.icon:SetPoint("TOPLEFT", part.button, "TOPLEFT", pixel, -pixel)
	part.icon:SetPoint("BOTTOMRIGHT", part.button, "BOTTOMRIGHT", -pixel, pixel)
	part.cooldown:ClearAllPoints()
	part.cooldown:SetAllPoints(part.icon)
	-- The time left as a number on the icon, written by the game itself, for those who want it.
	part.cooldown:SetHideCountdownNumbers(not ns.db.auraTimers)
	part.cooldown:SetCountdownFont(Style.TIMER_FONT)
	-- The count of stacks is always outlined: on a bright icon (Inner Fire, a paladin's seal)
	-- light figures with only a soft shadow cannot be read.
	Style.SetFont(part.count, size >= 20 and -1 or -3, true)
	part.count:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
	if part.kind == "buffs" then
		-- A buff's rim is the theme's dark edge. A debuff's is coloured by the game, by its kind.
		part.edge:SetVertexColor(theme.edge[1], theme.edge[2], theme.edge[3])
	end
end

-- Called by the game for each button it creates for a group, before the button is closed to
-- addon code: this is the one moment to give it its parts. The game writes on a part the moment
-- it is handed over (a question mark for the icon, an empty count), so every part has its size
-- and its font first.
local function MakeButton(frame, there, kind, button)
	-- The rim is a white square behind the icon, tinted: dark for a buff, and for a debuff in
	-- the colour of its kind (magic, curse, disease, poison), which the game looks up on this
	-- addon's own colour curve.
	local edge = button:CreateTexture(nil, "BACKGROUND")
	edge:SetAllPoints(button)
	edge:SetColorTexture(1, 1, 1, 1)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trims the icon's own border
	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown:SetReverse(true)
	cooldown:SetDrawEdge(false)
	-- The stack count sits above the sweep.
	local top = CreateFrame("Frame", nil, button)
	top:SetAllPoints(button)
	top:SetFrameLevel(cooldown:GetFrameLevel() + 1)
	local count = top:CreateFontString(nil, "OVERLAY")
	count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 1)

	local part = { button = button, edge = edge, icon = icon, cooldown = cooldown, count = count, kind = kind, side = there.side }
	there.parts[#there.parts + 1] = part
	Dress(frame, part)

	button:SetIcon(icon)
	button:SetDurationCooldown(cooldown)
	button:SetApplicationCount(count)
	if kind == "debuffs" then
		button:AddDispelTypeTexture(edge, {
			style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
			showWhenHarmful = true, showWithoutDispelType = true,
			customDispelColorCurve = Style.debuffKindCurve,
		})
	end
	-- The game shows an aura's tooltip itself when the mouse is over its button.
	button:SetTooltipAnchorPoint("ANCHOR_BOTTOMRIGHT", 0, 0)
end

-- The light for a debuff the player can remove is a button too: one that the game shows while
-- there is such a debuff and hides while there is none. It is as large as the plate, lets the
-- mouse through, and all it has is four lines along the plate's rim, which the game tints by
-- the debuff's kind and which breathe while they are lit. A steady line is easy to miss in a
-- fight; one that breathes is not.
local DressLamp

local function MakeLamp(frame, button)
	local lamp = frame.auras.lamp
	button:SetAllPoints(frame.body)
	lamp.button = button
	lamp.lines = {}
	for index = 1, 4 do
		local line = button:CreateTexture(nil, "OVERLAY")
		line:SetColorTexture(1, 1, 1, 1)
		lamp.lines[index] = line
	end
	DressLamp(frame)
	for index = 1, 4 do
		button:AddDispelTypeTexture(lamp.lines[index], {
			style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
			showWhenHarmful = true, showWithoutDispelType = true,
			customDispelColorCurve = Style.debuffKindCurve,
		})
	end
	local pulse = button:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local dim = pulse:CreateAnimation("Alpha")
	dim:SetFromAlpha(1)
	dim:SetToAlpha(PULSE_LOW)
	dim:SetDuration(PULSE)
	dim:SetSmoothing("IN_OUT")
	lamp.pulse = pulse
	button:AddAuraShownAnimation(pulse)
	-- The game passes every click on one of its aura buttons on to what lies under it. With the
	-- mouse switched off the pointer passes too, so the plate keeps its own tooltip.
	button:EnableMouse(false)
end

function DressLamp(frame)
	local lamp = frame.auras.lamp
	local width, button = LIGHT_WIDTH * frame.pixel, lamp.button
	local top, bottom, left, right = lamp.lines[1], lamp.lines[2], lamp.lines[3], lamp.lines[4]
	for index = 1, 4 do
		lamp.lines[index]:ClearAllPoints()
	end
	top:SetPoint("TOPLEFT", button, "TOPLEFT")
	top:SetPoint("TOPRIGHT", button, "TOPRIGHT")
	top:SetHeight(width)
	bottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
	bottom:SetHeight(width)
	left:SetPoint("TOPLEFT", button, "TOPLEFT")
	left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT")
	left:SetWidth(width)
	right:SetPoint("TOPRIGHT", button, "TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
	right:SetWidth(width)
end

-- Brings every button made so far in line with the settings, or notes that it has to wait.
local function DressAll(frame)
	local auras = frame.auras
	if AurasSealed() then
		auras.undressed = true
		return
	end
	auras.undressed = false
	for _, side in ipairs(SIDES) do
		local there = auras.sides[side]
		for _, part in ipairs(there and there.parts or {}) do
			Dress(frame, part)
		end
	end
	if auras.lamp.button then
		DressLamp(frame)
	end
end

---------------------------------------------------------------------------
-- A side's container
---------------------------------------------------------------------------
-- Where each side's container hangs on the plate, and which way its rows run from there: the
-- corner the rows start from, then right or left, then down or up. Returns the gap between icons.
local function Hang(frame, there, cfg)
	local container, body, pixel = there.container, frame.body, frame.pixel
	local flow = AnchorUtil.FlowDirection
	local corner, across, along = "TOPLEFT", flow.Right, flow.Down
	container:ClearAllPoints()
	if there.side == "above" then
		corner, along = "BOTTOMLEFT", flow.Up
		container:SetPoint("BOTTOMLEFT", body, "TOPLEFT", 0, frame.auraAbove)
	elseif there.side == "below" then
		container:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -frame.auraBelow)
	elseif there.side == "right" then
		container:SetPoint("TOPLEFT", body, "TOPRIGHT", SIDE_GAP, 0)
	elseif there.side == "left" then
		corner, across = "TOPRIGHT", flow.Left
		container:SetPoint("TOPRIGHT", body, "TOPLEFT", -SIDE_GAP, 0)
	else -- inside: from the bottom right corner of the health bar, towards the left
		corner, across, along = "BOTTOMRIGHT", flow.Left, flow.Up
		container:SetPoint("BOTTOMRIGHT", frame.health, "BOTTOMRIGHT", -pixel, pixel)
	end
	container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
	container:SetFlowLayoutAnchorPoint(corner)
	container:SetFlowLayoutGrowthDirection(across, along)
	-- A row holds as many icons as the settings say and no more: the game starts a new row when
	-- the next icon would make the row longer than this.
	local gap = there.side == "inside" and pixel or GAP
	container:SetFlowLayoutMaximumLineSize(cfg.auraPerRow * (cfg.auraSize + gap) - gap + 0.5)
	return gap
end

local function MakeSide(frame, side)
	local auras = frame.auras
	local container = CreateFrame("AuraContainer", nil, auras.holder, "CustomAuraContainerTemplate")
	local there = { container = container, side = side, groups = {}, parts = {} }
	auras.sides[side] = there
	return there
end

-- Sets one side's container up from the settings: `wanted` is what Sides() says of this side,
-- or nil when it has no icons now.
local function SetUpSide(frame, there, cfg, wanted)
	local container = there.container
	container:SetShown(wanted ~= nil)
	if not wanted then
		return
	end
	local gap = Hang(frame, there, cfg)
	for order, kind in ipairs(KINDS) do
		local count = wanted[kind] or 0
		local filter = FILTER[kind] .. (cfg[MINE[kind]] and "|PLAYER" or "")
		local layout = {
			elementSpacing = gap, lineSpacing = gap, groupLineSpacing = gap,
			-- Buffs start on a fresh row after the debuffs.
			forceNewLine = kind == "buffs",
			elementWidth = cfg.auraSize, elementHeight = cfg.auraSize, layoutIndex = order,
		}
		if count > 0 and not there.groups[kind] then
			-- The game makes the group's first buttons at once, and more whenever it needs them.
			container:AddAuraGroup(kind, filter, {
				maxFrameCount = count, layout = layout,
				initializeFrame = function(button)
					ns.Try(MakeButton, frame, there, kind, button)
				end,
			})
			there.groups[kind] = true
		elseif there.groups[kind] then
			container:SetAuraGroupEnabled(kind, count > 0)
			if count > 0 then
				container:SetAuraGroupMaxFrameCount(kind, count)
				container:SetAuraGroupFilterString(kind, filter)
				container:SetAuraGroupLayout(kind, layout)
			end
		end
	end
	if frame.unit then
		container:SetUnit(frame.unit)
	end
end

-- The light for a debuff the player can remove ("RAID" on a harmful aura means just that): a
-- container of its own with one slot, which is the game's word for a single aura on a button
-- that stays where it is put.
local function SetUpLamp(frame, cfg)
	local auras, lamp = frame.auras, frame.auras.lamp
	local wanted = cfg.dispel and true or false
	if wanted and not lamp.host then
		lamp.host = CreateFrame("AuraContainer", nil, auras.holder, "CustomAuraContainerTemplate")
		lamp.host:SetAllPoints(frame.body)
	end
	if wanted and not lamp.slot then
		lamp.host:AddAuraSlot("removable", "HARMFUL|RAID", {
			initializeFrame = function(button)
				ns.Try(MakeLamp, frame, button)
			end,
		})
		lamp.slot = true
	end
	if lamp.slot then
		lamp.host:SetShown(wanted)
		lamp.host:SetAuraSlotEnabled("removable", wanted)
		if frame.unit then
			lamp.host:SetUnit(frame.unit)
		end
	end
end

---------------------------------------------------------------------------
-- The element
---------------------------------------------------------------------------
function Auras.Create(frame)
	local holder = CreateFrame("Frame", nil, frame.body)
	holder:SetAllPoints(frame.body)
	holder:SetFrameLevel(frame.body:GetFrameLevel() + 7)
	frame.auras = { holder = holder, sides = {}, lamp = {}, undressed = false }
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
	-- Each side and the light are set up on their own: if the game will not have one of them,
	-- that one is reported and the others are still there.
	for _, side in ipairs(SIDES) do
		local there = auras.sides[side]
		if sides[side] and not there then
			there = MakeSide(frame, side)
		end
		if there then
			ns.Try(SetUpSide, frame, there, cfg, sides[side])
		end
	end
	ns.Try(SetUpLamp, frame, cfg)

	DressAll(frame)
end

-- Has every container look at its unit afresh. The game tells a container when the auras of
-- its unit change; it does not tell it that the unit now stands for someone else (a new
-- target, a group button handed to another member).
function Auras.Update(frame, unit, event)
	local auras = frame.auras
	-- A look that had to wait (the buttons were closed to the addon) is caught up with at the
	-- end of a fight, and whenever the frame is drawn afresh.
	if auras.undressed then
		DressAll(frame)
	end
	if event == "PLAYER_REGEN_ENABLED" then
		return
	end
	-- A fresh look takes every icon down and puts it up again (and the tooltip of the one under
	-- the mouse with it). A frame drawn afresh four times a second, as the target's target is
	-- because the game sends no news of that unit, has it once a second.
	local now = GetTime()
	if frame.pollEvery and auras.unit == unit and now - (auras.looked or 0) < LOOK_AFRESH then
		return
	end
	auras.unit, auras.looked = unit, now
	for _, side in ipairs(SIDES) do
		local there = auras.sides[side]
		if there then
			there.container:SetUnit(unit)
			there.container:UpdateAllAuras()
		end
	end
	if auras.lamp.host then
		auras.lamp.host:SetUnit(unit)
		auras.lamp.host:UpdateAllAuras()
	end
end

Frame.Register(Auras)
