local ADDON, ns = ...

-- What every unit frame has in common: the plate it is drawn on, the elements laid out on it, and
-- the events that keep them up to date.
--
-- A unit frame is one of the game's secure unit buttons (a click on it targets the unit, a right
-- click opens its menu). Being protected, the button itself can only be shown, moved or sized out
-- of combat, and that is done by Units.lua and Group.lua. Everything that is drawn sits on
-- frame.body, an ordinary frame that fills the button, and can change at any time.
--
-- An element is one thing a frame shows (the health bar, the cast bar, ...). It registers itself
-- with Frame.Register as a table:
--     name                    its name; frame.made[name] and frame.active[name] track it
--     Wanted(cfg, kind)       does a frame of this kind, with these settings, show it?
--     Create(frame)           makes its widgets, the first time it is wanted
--     Layout(frame, cfg, on)  sizes and places them; `on` false means it has been switched off
--     Update(frame, unit, event, ...)   draws the unit's current state
--     events                  unit events that call Update, registered for the frame's own unit
--     closeEvents             more of those, only for the single frames (not party or raid)
--     playerEvents            unit events that call Update, registered for the player
--     worldEvents             other events that call Update
local Frame = {}
ns.Frame = Frame
ns.Elements = {}

local Style = ns.Style

-- How far above its button a frame's plate is drawn. The levels in between are for what shows
-- from under the plate (the threat outline).
Frame.BODY_LEVEL = 6

local GROUP_KINDS = { party = true, raid = true }

local elements = {} -- in the order their files load, which is the order they are laid out in
local frames = {}   -- every unit frame built so far

function Frame.Register(element)
	elements[#elements + 1] = element
	ns.Elements[element.name] = element
end

function Frame.All()
	return frames
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
-- A frame listens for its own unit's events and is told nothing about any other unit. What an
-- event carries along is not used: on this client an event's payload can be sealed, and every
-- element draws from the game's current state anyway.
local function OnEvent(self, event, ...)
	local listeners = self.listeners[event]
	local unit = self.unit
	if not listeners or not unit then
		return
	end
	for _, element in ipairs(listeners) do
		ns.Try(element.Update, self, unit, event, ...)
	end
end

local function Listen(frame, event, element, unit)
	local listeners = frame.listeners[event]
	if not listeners then
		listeners = {}
		frame.listeners[event] = listeners
	end
	listeners[#listeners + 1] = element
	if unit then
		local units = frame.eventUnits[event]
		if not units then
			units = {}
			frame.eventUnits[event] = units
		end
		units[unit] = true
	end
end

-- Registers what the frame's active elements listen for, for the unit it shows now.
local function RegisterEvents(frame)
	frame:UnregisterAllEvents()
	frame.listeners = {}
	frame.eventUnits = {}
	local unit = frame.unit
	if not unit then
		return
	end
	local worldEvents = {}
	for _, element in ipairs(elements) do
		if frame.active[element.name] then
			for _, event in ipairs(element.events or {}) do
				Listen(frame, event, element, unit)
			end
			if not GROUP_KINDS[frame.kind] then
				for _, event in ipairs(element.closeEvents or {}) do
					Listen(frame, event, element, unit)
				end
			end
			for _, event in ipairs(element.playerEvents or {}) do
				Listen(frame, event, element, "player")
			end
			for _, event in ipairs(element.worldEvents or {}) do
				Listen(frame, event, element)
				worldEvents[event] = true
			end
		end
	end
	-- An event is wanted for the frame's unit, for the player, or for both: two units at most.
	for event, units in pairs(frame.eventUnits) do
		local first = next(units)
		local second = next(units, first)
		frame:RegisterUnitEvent(event, first, second)
	end
	for event in pairs(worldEvents) do
		frame:RegisterEvent(event)
	end
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
-- Draws everything on the frame from the game's current state.
function Frame.Refresh(frame)
	local unit = frame.unit
	if not unit or not UnitExists(unit) then
		return
	end
	for _, element in ipairs(elements) do
		if frame.active[element.name] then
			ns.Try(element.Update, frame, unit)
		end
	end
end

function Frame.RefreshAll()
	for _, frame in ipairs(frames) do
		if frame:IsVisible() then
			Frame.Refresh(frame)
		end
	end
end

function Frame.RefreshKind(kind)
	for _, frame in ipairs(frames) do
		if frame.kind == kind and frame:IsVisible() then
			Frame.Refresh(frame)
		end
	end
end

-- Points the frame's drawing at a unit (or at none). The button's own "unit" attribute, which is
-- what a click acts on, is set by whoever owns the button; this follows it.
function Frame.SetUnit(frame, unit)
	if frame.unit == unit then
		return
	end
	frame.unit = unit
	RegisterEvents(frame)
	if unit and frame:IsVisible() then
		Frame.Refresh(frame)
	end
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
-- One screen pixel, in the frame's own units, so thin lines stay one crisp pixel at any UI scale.
function Frame.Pixel(frame)
	return PixelUtil.GetNearestPixelSize(1, frame:GetEffectiveScale(), 1)
end

-- Elements that sit outside the plate stack up under or over it. Each asks for its height and is
-- told how far from the plate's edge it starts.
function Frame.TakeBelow(frame, height)
	local offset = frame.below
	frame.below = offset + height + 3
	return offset + 3
end

function Frame.TakeAbove(frame, height)
	local offset = frame.above
	frame.above = offset + height + 3
	return offset + 3
end

-- A one-pixel line around a region, drawn just inside its bounds. Returns the four textures.
function Frame.MakeEdge(parent, layer)
	local edge = {}
	for i = 1, 4 do
		edge[i] = parent:CreateTexture(nil, layer or "BORDER")
	end
	return edge
end

function Frame.LayoutEdge(edge, region, pixel, color)
	local top, bottom, left, right = edge[1], edge[2], edge[3], edge[4]
	for i = 1, 4 do
		edge[i]:ClearAllPoints()
		edge[i]:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
	end
	top:SetPoint("TOPLEFT", region, "TOPLEFT")
	top:SetPoint("TOPRIGHT", region, "TOPRIGHT")
	top:SetHeight(pixel)
	bottom:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT")
	bottom:SetHeight(pixel)
	left:SetPoint("TOPLEFT", region, "TOPLEFT")
	left:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT")
	left:SetWidth(pixel)
	right:SetPoint("TOPRIGHT", region, "TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT")
	right:SetWidth(pixel)
end

-- Lays the frame out again from its settings: the plate, then every element in turn. Elements
-- that have been switched on are made, ones switched off are put away.
function Frame.Layout(frame)
	local cfg = ns.db.units[frame.kind]
	local theme = Style.theme
	local body = frame.body
	local pixel = Frame.Pixel(body)
	frame.cfg = cfg
	frame.pixel = pixel

	body.back:SetColorTexture(theme.back[1], theme.back[2], theme.back[3], theme.back[4])
	Frame.LayoutEdge(body.edge, body, pixel, theme.edge)

	-- The space inside the edge is shared out between the portrait, a square at one end, and the
	-- bars: barLeft and barRight are how far the bars stay from the plate's sides.
	local square = cfg.height - 2 * pixel
	frame.barLeft = pixel + (cfg.portrait == "left" and square + pixel or 0)
	frame.barRight = pixel + (cfg.portrait == "right" and square + pixel or 0)
	frame.barWidth = cfg.width - frame.barLeft - frame.barRight
	frame.powerHeight = cfg.powerHeight
	frame.below, frame.above = 0, 0
	for _, element in ipairs(elements) do
		local name = element.name
		local wanted = element.Wanted(cfg, frame.kind) and true or false
		if wanted and not frame.made[name] then
			element.Create(frame)
			frame.made[name] = true
		end
		if frame.made[name] then
			element.Layout(frame, cfg, wanted)
		end
		frame.active[name] = wanted
	end

	RegisterEvents(frame)
	if frame:IsVisible() then
		Frame.Refresh(frame)
	end
end

function Frame.LayoutAll()
	for _, frame in ipairs(frames) do
		Frame.Layout(frame)
	end
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function OnShow(self)
	Frame.Refresh(self)
end

local function OnAttributeChanged(self, name, value)
	if name == "unit" then
		Frame.SetUnit(self, value)
	end
end

local function OnEnter(self)
	local unit = self.unit
	local mode = ns.db.tooltips
	if not unit or mode == "never" or (mode == "calm" and InCombatLockdown()) then
		return
	end
	GameTooltip_SetDefaultAnchor(GameTooltip, self)
	GameTooltip:SetUnit(unit)
end

local function OnLeave()
	GameTooltip:Hide()
end

-- Units whose changes the game does not announce (the target's target) are looked at again a few
-- times a second while their frame is up.
local function OnUpdate(self, elapsed)
	self.sincePoll = self.sincePoll + elapsed
	if self.sincePoll >= self.pollEvery then
		self.sincePoll = 0
		Frame.Refresh(self)
	end
end

function Frame.SetPolling(frame, seconds)
	frame.pollEvery = seconds
	frame.sincePoll = 0
	frame:SetScript("OnUpdate", seconds and OnUpdate or nil)
end

-- Turns a secure unit button into one of our frames of the given kind. The button keeps whatever
-- unit its "unit" attribute names, now and later.
function Frame.Build(frame, kind)
	frame.kind = kind
	frame.made = {}
	frame.active = {}
	frame.listeners = {}
	frame.eventUnits = {}

	local body = CreateFrame("Frame", nil, frame)
	body:SetAllPoints(frame)
	body:SetFrameLevel(frame:GetFrameLevel() + Frame.BODY_LEVEL)
	body.back = body:CreateTexture(nil, "BACKGROUND")
	body.back:SetAllPoints(body)
	body.edge = Frame.MakeEdge(body, "BORDER")
	frame.body = body

	frame:SetScript("OnEvent", OnEvent)
	frame:HookScript("OnShow", OnShow)
	frame:HookScript("OnAttributeChanged", OnAttributeChanged)
	frame:HookScript("OnEnter", OnEnter)
	frame:HookScript("OnLeave", OnLeave)

	frames[#frames + 1] = frame
	Frame.Layout(frame)
	Frame.SetUnit(frame, frame:GetAttribute("unit"))
	return frame
end
