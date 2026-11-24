local ADDON, ns = ...

-- A bright line around the frame of the group member the player has targeted, so that in a row
-- of party or raid frames the eye finds the one it is working on.
local Frame, Style, Sealed = ns.Frame, ns.Style, ns.Sealed

local Highlight = { name = "Highlight" }

Highlight.worldEvents = { "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE" }

function Highlight.Wanted(cfg)
	return cfg.highlight and true or false
end

function Highlight.Create(frame)
	-- Above everything else on the plate.
	local holder = CreateFrame("Frame", nil, frame.body)
	holder:SetAllPoints(frame.body)
	holder:SetFrameLevel(frame.body:GetFrameLevel() + 9)
	holder:SetAlpha(0)
	holder.edge = Frame.MakeEdge(holder, "OVERLAY")
	frame.highlight = holder
end

function Highlight.Layout(frame, cfg, on)
	local holder = frame.highlight
	holder:SetShown(on)
	if on then
		Frame.LayoutEdge(holder.edge, holder, frame.pixel, Style.theme.text)
	end
end

-- Whether two unit names stand for the same creature can come back sealed: the line is drawn or
-- not by handing the answer to the frame's alpha.
function Highlight.Update(frame, unit)
	Sealed.SameUnitToAlpha(frame.highlight, unit, "target")
end

Frame.Register(Highlight)
