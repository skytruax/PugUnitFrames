local ADDON, ns = ...

-- Fades a group member who is too far away to heal or help.
local Frame, Sealed = ns.Frame, ns.Sealed

local Range = { name = "Range" }

Range.events = { "UNIT_IN_RANGE_UPDATE", "UNIT_CONNECTION" }

function Range.Wanted(cfg)
	return cfg.range
end

function Range.Create()
end

function Range.Layout(frame, cfg, on)
	if not on then
		frame.body:SetAlpha(1)
		frame.body.shadow.holder:SetAlpha(1)
	end
end

-- The plate fades, and its shadow with it (the shadow lies under the plate on a frame of its own).
function Range.Update(frame, unit)
	Sealed.RangeToAlpha(frame.body, unit, 1, ns.db.farAlpha)
	Sealed.RangeToAlpha(frame.body.shadow.holder, unit, 1, ns.db.farAlpha)
end

Frame.Register(Range)
