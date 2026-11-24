local ADDON, ns = ...

-- A frame that steps back while nothing is going on: outside a fight and with no target it is
-- drawn fainter, and it is back in full the moment a fight starts, a target is picked or the
-- mouse is over it. For the player's own frame and the pet's.
--
-- Health does not count, although "not at full health" would be a good reason to stay in full:
-- how much health a unit has is always sealed, the player's own included, so this addon cannot
-- know it.
--
-- It is the unit button itself that fades. Its alpha is one of the things about a protected
-- frame that may change during a fight.
local Frame = ns.Frame

local Fade = { name = "Fade" }

Fade.worldEvents = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED" }

function Fade.Wanted(cfg)
	return cfg.calm ~= nil and cfg.calm < 1
end

local function Apply(frame, event)
	local alpha = ns.db.alpha
	if frame.active.Fade then
		-- The game announces a fight a moment before it counts the player as in one, and its end
		-- a moment after: the event itself is the better witness.
		local fighting = event == "PLAYER_REGEN_DISABLED" or (event ~= "PLAYER_REGEN_ENABLED" and InCombatLockdown())
		if not fighting and not frame.hovered and not UnitExists("target") then
			alpha = alpha * frame.cfg.calm
		end
	end
	frame:SetAlpha(alpha)
end

function Fade.Create(frame)
	frame:HookScript("OnEnter", function(self)
		self.hovered = true
		ns.Try(Apply, self)
	end)
	frame:HookScript("OnLeave", function(self)
		self.hovered = false
		ns.Try(Apply, self)
	end)
end

-- Frame.Layout marks an element active only after laying it out, and Frame.Refresh draws it
-- right after: switched off, the frame is put back to the overall opacity here.
function Fade.Layout(frame, cfg, on)
	if not on then
		frame:SetAlpha(ns.db.alpha)
	end
end

function Fade.Update(frame, _, event)
	Apply(frame, event)
end

Frame.Register(Fade)
