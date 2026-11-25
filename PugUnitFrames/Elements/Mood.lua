local ADDON, ns = ...

-- How a hunter's pet feels: a small face beside the pet frame, green when it is happy, amber
-- when it is content, red when it is unhappy and close to leaving. The game shows this on its
-- own pet frame, which is put away while ours is in use, and a hunter has to see it to know when
-- to feed the pet.
local Frame, Sealed = ns.Frame, ns.Sealed

local Mood = { name = "Mood" }

Mood.events = { "UNIT_HAPPINESS" }
Mood.playerEvents = { "UNIT_PET" }

local ART = ns.ART
-- By the game's number for it: 1 unhappy, 2 content, 3 happy.
local FACES = { ART .. "Mood-Unhappy", ART .. "Mood-Content", ART .. "Mood-Happy" }
local GAP = 3

function Mood.Wanted(cfg, kind)
	return kind == "pet" and cfg.happiness and Sealed.PlayerClassFile() == "HUNTER" or false
end

function Mood.Create(frame)
	frame.mood = frame.body:CreateTexture(nil, "OVERLAY")
	frame.mood:Hide()
end

function Mood.Layout(frame, cfg, on)
	local face = frame.mood
	if not on then
		face:Hide()
		return
	end
	local size = math.max(12, math.min(20, cfg.height * 0.6))
	face:ClearAllPoints()
	face:SetSize(size, size)
	-- To the right of the plate, or to its left when that is where the icons go.
	if cfg.buffSide == "right" or cfg.debuffSide == "right" then
		face:SetPoint("RIGHT", frame.body, "LEFT", -GAP, 0)
	else
		face:SetPoint("LEFT", frame.body, "RIGHT", GAP, 0)
	end
end

function Mood.Update(frame)
	local face = frame.mood
	-- Nothing comes back when there is no pet that has a mood.
	local happiness = C_PetInfo.GetPetHappiness()
	local art = happiness and FACES[happiness]
	if art then
		face:SetTexture(art)
		face:Show()
	else
		face:Hide()
	end
end

Frame.Register(Mood)
