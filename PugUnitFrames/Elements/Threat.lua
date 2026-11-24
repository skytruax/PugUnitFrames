local ADDON, ns = ...

-- An outline around the plate while the unit is being attacked: amber when something is on it,
-- orange when most of it is, red when all of it is.
--
-- The level (0 to 3) can come back sealed, so it is never looked at. Three outlines lie under the
-- plate, each a status bar that runs from one level to the next: the game fills outline 2 when
-- the level reaches 2, and so on, and the highest one filled is the one seen.
local Frame, Style, Sealed = ns.Frame, ns.Style, ns.Sealed

local Threat = { name = "Threat" }

Threat.events = { "UNIT_THREAT_SITUATION_UPDATE" }

local WIDTH = 2 -- pixels of outline showing past the plate

function Threat.Wanted(cfg)
	return cfg.threat
end

function Threat.Create(frame)
	local holder = CreateFrame("Frame", nil, frame)
	local bars = {}
	for level = 1, 3 do
		local bar = CreateFrame("StatusBar", nil, holder)
		bar:SetAllPoints(holder)
		bar:SetStatusBarTexture(Style.TEXTURES.flat)
		bar:SetMinMaxValues(level - 1, level)
		bar:SetValue(0)
		bars[level] = bar
	end
	frame.threat = { holder = holder, bars = bars }
end

function Threat.Layout(frame, cfg, on)
	local threat = frame.threat
	threat.holder:SetShown(on)
	if not on then
		return
	end
	local reach = WIDTH * frame.pixel
	local level = frame:GetFrameLevel()
	threat.holder:ClearAllPoints()
	threat.holder:SetPoint("TOPLEFT", frame.body, "TOPLEFT", -reach, reach)
	threat.holder:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", reach, -reach)
	-- Under the plate (Frame.Build raises it by Frame.BODY_LEVEL), so only the part that reaches
	-- past it shows, with the stronger outline over the weaker.
	threat.holder:SetFrameLevel(level + 1)
	for index, bar in ipairs(threat.bars) do
		bar:SetFrameLevel(level + 1 + index)
		bar:SetStatusBarColor(Style.THREAT[index][1], Style.THREAT[index][2], Style.THREAT[index][3])
	end
end

function Threat.Update(frame, unit)
	Sealed.ThreatToBars(frame.threat.bars, unit)
end

Frame.Register(Threat)
