local ADDON, ns = ...

-- Small marks on the plate's rim: the raid mark, the group leader's, resting, in combat, a
-- resurrection on its way, and the answer to a ready check.
local Frame, Sealed = ns.Frame, ns.Sealed

local Marks = { name = "Marks" }

Marks.events = { "UNIT_FLAGS", "INCOMING_RESURRECT_CHANGED" }
Marks.worldEvents = {
	"RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_UPDATE_RESTING",
	"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED",
}

local ART = ns.ART
local RAID_MARKS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons" -- the game's own sheet of eight
local READY_ART = { ready = ART .. "Mark-Ready", notready = ART .. "Mark-NotReady", waiting = ART .. "Mark-Waiting" }
local READY_LINGER = 6 -- seconds the answers stay up after a ready check ends

function Marks.Wanted(cfg)
	return cfg.marks
end

function Marks.Create(frame)
	-- Above the bars and the words.
	local holder = CreateFrame("Frame", nil, frame.body)
	holder:SetAllPoints(frame.body)
	holder:SetFrameLevel(frame.body:GetFrameLevel() + 8)

	local marks = { holder = holder }
	marks.raid = holder:CreateTexture(nil, "OVERLAY")
	marks.raid:SetTexture(RAID_MARKS)
	marks.leader = holder:CreateTexture(nil, "OVERLAY")
	marks.leader:SetTexture(ART .. "Mark-Leader")
	marks.state = holder:CreateTexture(nil, "OVERLAY")  -- resting or in combat
	marks.center = holder:CreateTexture(nil, "OVERLAY") -- ready check answer or resurrection
	frame.marks = marks
end

function Marks.Layout(frame, cfg, on)
	local marks = frame.marks
	marks.holder:SetShown(on)
	if not on then
		return
	end
	local small = math.max(10, math.min(16, cfg.height * 0.36))
	local big = math.max(12, math.min(22, cfg.height * 0.5))

	marks.raid:ClearAllPoints()
	marks.raid:SetSize(big, big)
	marks.raid:SetPoint("CENTER", frame.body, "TOP", 0, 0)

	marks.leader:ClearAllPoints()
	marks.leader:SetSize(small, small)
	marks.leader:SetPoint("CENTER", frame.body, "TOPLEFT", small * 0.5, 0)

	marks.state:ClearAllPoints()
	marks.state:SetSize(small, small)
	marks.state:SetPoint("CENTER", frame.body, "BOTTOMLEFT", small * 0.5, 0)

	marks.center:ClearAllPoints()
	marks.center:SetSize(big, big)
	marks.center:SetPoint("CENTER", frame.body, "CENTER")
end

local function ShowState(frame, unit)
	local state = frame.marks.state
	if UnitAffectingCombat(unit) then
		state:SetTexture(ART .. "Mark-Combat")
		state:Show()
	elseif frame.kind == "player" and IsResting() then
		state:SetTexture(ART .. "Mark-Rest")
		state:Show()
	else
		state:Hide()
	end
end

local function ShowCenter(frame, unit)
	local center = frame.marks.center
	local ready = Sealed.ReadyCheckAnswer(unit)
	if ready and READY_ART[ready] then
		center:SetTexture(READY_ART[ready])
		center:Show()
	elseif Sealed.IsBeingResurrected(unit) then
		center:SetTexture(ART .. "Mark-Resurrect")
		center:Show()
	else
		center:Hide()
	end
end

function Marks.Update(frame, unit, event)
	local marks = frame.marks
	Sealed.RaidMarkToTexture(marks.raid, unit)
	Sealed.LeaderToAlpha(marks.leader, unit)
	ShowState(frame, unit)
	ShowCenter(frame, unit)
	if event == "READY_CHECK_FINISHED" then
		-- The game forgets the answers a few seconds after the check ends; look again then.
		ns.After(READY_LINGER, function()
			if frame.unit and frame.active.Marks and UnitExists(frame.unit) then
				ShowCenter(frame, frame.unit)
			end
		end)
	end
end

Frame.Register(Marks)
