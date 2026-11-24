local ADDON, ns = ...

-- Combo points on the target: a row of five pips under the plate.
--
-- How many there are can come back sealed, so the count is never looked at. Pip i is a little
-- status bar that runs from i-1 to i: the game fills it once there are i points.
local Frame, Style, Sealed = ns.Frame, ns.Style, ns.Sealed

local Points = { name = "Points" }

-- The game's own combo points listen for all three: the frequent one is what makes a point show
-- the moment it is gained.
Points.playerEvents = { "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER" }
Points.worldEvents = { "PLAYER_TARGET_CHANGED" }

local COUNT = 5
local HEIGHT = 5
local GAP = 2
local USERS = { ROGUE = true, DRUID = true }

function Points.Wanted(cfg, kind)
	return cfg.points and kind == "target" and USERS[Sealed.PlayerClassFile() or ""] or false
end

function Points.Create(frame)
	local holder = CreateFrame("Frame", nil, frame.body)
	local bars = {}
	for index = 1, COUNT do
		local bar = CreateFrame("StatusBar", nil, holder)
		bar.trough = bar:CreateTexture(nil, "BACKGROUND")
		bar.trough:SetAllPoints(bar)
		bar:SetMinMaxValues(index - 1, index)
		bar:SetValue(0)
		bars[index] = bar
	end
	frame.points = { holder = holder, bars = bars }
end

function Points.Layout(frame, cfg, on)
	local points, theme = frame.points, Style.theme
	points.holder:SetShown(on)
	if not on then
		return
	end
	local offset = Frame.TakeBelow(frame, HEIGHT)
	local width = (cfg.width - GAP * (COUNT - 1)) / COUNT
	points.holder:ClearAllPoints()
	points.holder:SetPoint("TOPLEFT", frame.body, "BOTTOMLEFT", 0, -offset)
	points.holder:SetPoint("TOPRIGHT", frame.body, "BOTTOMRIGHT", 0, -offset)
	points.holder:SetHeight(HEIGHT)
	for index, bar in ipairs(points.bars) do
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", points.holder, "TOPLEFT", (index - 1) * (width + GAP), 0)
		bar:SetSize(width, HEIGHT)
		bar:SetStatusBarTexture(Style.texture)
		bar:SetStatusBarColor(Style.POINT[1], Style.POINT[2], Style.POINT[3])
		bar.trough:SetColorTexture(theme.back[1], theme.back[2], theme.back[3], theme.back[4])
	end
end

function Points.Update(frame)
	Sealed.ComboPointsToBars(frame.points.bars)
end

Frame.Register(Points)
