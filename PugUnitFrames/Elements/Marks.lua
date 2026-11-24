local ADDON, ns = ...

-- Small marks on the plate's rim: the raid mark, the group leader's, resting, in combat, the
-- part someone plays in the group (tank, healer, damage), a flag for someone marked for fighting
-- other players, a resurrection on its way, and the answer to a ready check.
local Frame, Sealed = ns.Frame, ns.Sealed

local Marks = { name = "Marks" }

-- UNIT_FACTION is also what the game sends when a unit's flag for fighting players goes up or down.
Marks.events = { "UNIT_FLAGS", "UNIT_FACTION", "INCOMING_RESURRECT_CHANGED" }
Marks.worldEvents = {
	"RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_UPDATE_RESTING",
	"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED",
}

local ART = ns.ART
local RAID_MARKS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons" -- the game's own sheet of eight
local READY_ART = { ready = ART .. "Mark-Ready", notready = ART .. "Mark-NotReady", waiting = ART .. "Mark-Waiting" }
local READY_LINGER = 6 -- seconds the answers stay up after a ready check ends
local ROLE_ART = { TANK = ART .. "Mark-Tank", HEALER = ART .. "Mark-Healer", DAMAGER = ART .. "Mark-Damage" }

-- The flag is white and takes the colour of the side its bearer fights for; amber for someone
-- who is everybody's enemy (a free-for-all area), or whose side the game does not name.
local SIDE = { Alliance = { 0.36, 0.58, 0.96 }, Horde = { 0.90, 0.26, 0.21 } }
local NO_SIDE = { 0.95, 0.74, 0.25 }

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
	marks.role = holder:CreateTexture(nil, "OVERLAY")   -- tank, healer or damage
	marks.pvp = holder:CreateTexture(nil, "OVERLAY")    -- marked for fighting other players
	marks.pvp:SetTexture(ART .. "Mark-PvP")
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

	-- The raid mark sits on the middle of the top edge. A wide frame has room for it inside, between
	-- the name and the numbers, where it keeps clear of icons standing above the plate; a narrow
	-- one has its name there, so the mark rides the edge.
	marks.raid:ClearAllPoints()
	marks.raid:SetSize(big, big)
	if cfg.width < Frame.NARROW then
		marks.raid:SetPoint("CENTER", frame.body, "TOP", 0, 0)
	else
		marks.raid:SetPoint("TOP", frame.body, "TOP", 0, -2 * frame.pixel)
	end

	marks.leader:ClearAllPoints()
	marks.leader:SetSize(small, small)
	marks.leader:SetPoint("CENTER", frame.body, "TOPLEFT", small * 0.5, 0)

	-- Resting or in combat: on the top edge beside the leader's mark, clear of a cast bar under
	-- the plate.
	marks.state:ClearAllPoints()
	marks.state:SetSize(small, small)
	marks.state:SetPoint("CENTER", frame.body, "TOPLEFT", small * 1.5 + 2, 0)

	-- The part played in the group: third along the top edge. A narrow frame has its raid mark
	-- there, so on one of those it sits in the bottom left corner instead.
	marks.role:ClearAllPoints()
	marks.role:SetSize(small, small)
	if cfg.width < Frame.NARROW then
		marks.role:SetPoint("BOTTOMLEFT", frame.body, "BOTTOMLEFT", 2 * frame.pixel, 2 * frame.pixel)
	else
		marks.role:SetPoint("CENTER", frame.body, "TOPLEFT", small * 2.5 + 4, 0)
	end

	-- The flag rides the top right corner.
	marks.pvp:ClearAllPoints()
	marks.pvp:SetSize(small, small)
	marks.pvp:SetPoint("CENTER", frame.body, "TOPRIGHT", -small * 0.5, 0)

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

local function ShowRole(frame, unit)
	local role = frame.marks.role
	local art = ROLE_ART[Sealed.Role(unit) or ""]
	if art then
		role:SetTexture(art)
		role:Show()
	else
		role:Hide()
	end
end

local function ShowPvP(frame, unit)
	local pvp = frame.marks.pvp
	if UnitIsPVPFreeForAll(unit) then
		pvp:SetVertexColor(NO_SIDE[1], NO_SIDE[2], NO_SIDE[3])
		pvp:SetAlpha(1)
		return
	end
	local color = SIDE[UnitFactionGroup(unit) or ""] or NO_SIDE
	pvp:SetVertexColor(color[1], color[2], color[3])
	-- Whether the flag is up can be sealed (for a creature, or a player outside the group).
	Sealed.PvPToAlpha(pvp, unit)
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
	ShowRole(frame, unit)
	ShowPvP(frame, unit)
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
