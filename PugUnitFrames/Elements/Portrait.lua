local ADDON, ns = ...

-- The unit's face, in a square at one end of the plate.
local Frame, Style = ns.Frame, ns.Style

local Portrait = { name = "Portrait" }

Portrait.events = { "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_CONNECTION" }

function Portrait.Wanted(cfg)
	return cfg.portrait ~= "none"
end

function Portrait.Create(frame)
	frame.portrait = frame.body:CreateTexture(nil, "ARTWORK")
end

function Portrait.Layout(frame, cfg, on)
	local picture, pixel = frame.portrait, frame.pixel
	picture:SetShown(on)
	if not on then
		return
	end
	local square = cfg.height - 2 * pixel
	-- The game draws these round, on a square; cutting the rim off leaves a square face. Mirrored,
	-- the face looks the other way (towards the bars, say, when it stands at the right end).
	if cfg.mirror then
		picture:SetTexCoord(0.86, 0.14, 0.14, 0.86)
	else
		picture:SetTexCoord(0.14, 0.86, 0.14, 0.86)
	end
	picture:ClearAllPoints()
	picture:SetSize(square, square)
	if cfg.portrait == "left" then
		picture:SetPoint("TOPLEFT", frame.body, "TOPLEFT", pixel, -pixel)
	else
		picture:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", -pixel, -pixel)
	end
end

function Portrait.Update(frame, unit)
	SetPortraitTexture(frame.portrait, unit)
end

Frame.Register(Portrait)
