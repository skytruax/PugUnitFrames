local ADDON, ns = ...

-- Moving frames. Unlocked, every frame gets a handle: a tinted box the size of the frame (for a
-- group, of the room a full one takes) that can be dragged. The frames themselves are protected
-- and stay where they are until the handle is dropped, so they are never dragged in a fight.
local Movers = {}
ns.Movers = Movers

local L = ns.L
local Defaults = ns.Defaults

local handles = {} -- [kind] = handle

local FILL = { 0.25, 0.70, 0.50, 0.35 }
local EDGE = { 0.45, 0.95, 0.70, 0.90 }

-- Where a frame is and how much room it takes, in screen units from the middle of the screen:
-- the point of it that the position is measured to, then x, y, width, height.
local function Footprint(kind)
	local cfg = ns.db.units[kind]
	if kind ~= "party" and kind ~= "raid" then
		return "CENTER", cfg.x, cfg.y, cfg.width * cfg.scale, cfg.height * cfg.scale
	end
	local members, columns, scale
	if kind == "party" then
		members, columns, scale = cfg.showPlayer and 5 or 4, 1, cfg.scale
	else
		members, columns, scale = cfg.perColumn, math.ceil(40 / cfg.perColumn), ns.Group.RaidScale(cfg)
	end
	local vertical = cfg.growth == "down" or cfg.growth == "up"
	local along = members * (vertical and cfg.height or cfg.width) + (members - 1) * cfg.spacing
	local across = columns * (vertical and cfg.width or cfg.height) + (columns - 1) * (cfg.columnSpacing or 0)
	local width, height = vertical and across or along, vertical and along or across
	return ns.Group.Corner(cfg), cfg.x, cfg.y, width * scale, height * scale
end
Movers.Footprint = Footprint

-- The handle was dropped: its place becomes the frame's.
local function OnDropped(handle)
	handle:StopMovingOrSizing()
	local cfg = ns.db.units[handle.kind]
	local middleX, middleY = UIParent:GetCenter()
	local point = handle.point
	local x, y
	if point == "CENTER" then
		x, y = handle:GetCenter()
	else
		x = point:find("LEFT") and handle:GetLeft() or handle:GetRight()
		y = point:find("TOP") and handle:GetTop() or handle:GetBottom()
	end
	cfg.x = math.floor(x - middleX + 0.5)
	cfg.y = math.floor(y - middleY + 0.5)
	ns.Refresh()
end

local function MakeHandle(kind)
	local handle = CreateFrame("Frame", nil, UIParent)
	handle.kind = kind
	handle:SetFrameStrata("DIALOG")
	handle:SetMovable(true)
	handle:SetClampedToScreen(true)
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")

	local fill = handle:CreateTexture(nil, "BACKGROUND")
	fill:SetAllPoints(handle)
	fill:SetColorTexture(FILL[1], FILL[2], FILL[3], FILL[4])
	handle.edge = ns.Frame.MakeEdge(handle, "BORDER")

	local label = handle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("CENTER")
	label:SetText(Defaults.Label(kind))

	handle:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	handle:SetScript("OnDragStop", function(self)
		ns.Try(OnDropped, self)
	end)
	handle:Hide()
	handles[kind] = handle
	return handle
end

-- Shows the handles where the frames are, or puts them away, as the settings say.
function Movers.Sync()
	local db = ns.db
	for _, kind in ipairs(Defaults.KINDS) do
		local handle = handles[kind]
		if db.locked or not db.units[kind].enabled then
			if handle then
				handle:Hide()
			end
		else
			handle = handle or MakeHandle(kind)
			local point, x, y, width, height = Footprint(kind)
			handle.point = point
			handle:ClearAllPoints()
			handle:SetPoint(point, UIParent, "CENTER", x, y)
			handle:SetSize(width, height)
			ns.Frame.LayoutEdge(handle.edge, handle, ns.Frame.Pixel(handle), EDGE)
			handle:Show()
		end
	end
end

function Movers.SetLocked(locked)
	if not locked and InCombatLockdown() then
		ns.Print(L["Frames cannot be moved during a fight. Unlock them when it is over."])
		return
	end
	ns.db.locked = locked
	Movers.Sync()
	if locked then
		ns.Print(L["Frames locked."])
	else
		ns.Print(L["Frames unlocked: drag a green box to move its frame, then type /pug lock."])
	end
end

-- A fight starts with the handles out: they go away, since nothing can be moved now.
ns.On("PLAYER_REGEN_DISABLED", function()
	if ns.db and not ns.db.locked then
		ns.db.locked = true
		Movers.Sync()
		ns.Print(L["A fight has started: frames are locked again."])
	end
end)
