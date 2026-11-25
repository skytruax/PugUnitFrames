local ADDON, ns = ...

-- Small marks on the plate: the raid mark, resting, in combat, a resurrection on its way and the
-- answer to a ready check; and, for those who want them, the group leader's mark, the part
-- someone plays in the group (tank, healer, damage) and a flag for someone marked for fighting
-- other players. Those three start switched off: each has its own setting.
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
	return cfg.marks or cfg.leader or cfg.role or cfg.pvp or false
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

-- The small marks that ride the plate's top edge side by side, in the order they stand in. One
-- that is switched off leaves no gap.
local EDGE_ROW = { "leader", "state", "role" }

function Marks.Layout(frame, cfg, on)
	local marks = frame.marks
	marks.holder:SetShown(on)
	if not on then
		return
	end
	local body, pixel = frame.body, frame.pixel
	local narrow = cfg.width < Frame.NARROW
	local small = Frame.MarkSize(cfg)
	local big = math.max(12, math.min(22, cfg.height * 0.5))
	local step = small + 2

	-- Which marks this frame has. One it has not stays hidden and is never looked up.
	local has = {
		raid = cfg.marks or false, state = cfg.marks or false, center = cfg.marks or false,
		leader = cfg.leader or false, role = cfg.role or false, pvp = cfg.pvp or false,
	}
	marks.has = has
	for key, wanted in pairs(has) do
		if not wanted then
			marks[key]:Hide()
		end
	end
	-- These two are drawn or not by their alpha, which the game sets from an answer that can be
	-- sealed; the regions themselves are simply there while the mark is wanted.
	marks.leader:SetShown(has.leader)
	marks.pvp:SetShown(has.pvp)

	-- A mark on the top edge reaches half its height into the plate. On a plate with two lines
	-- of text that is where the name begins, at the left end of the bar: there the row stands
	-- over a portrait at the left end, and where the left end is the bar's, at the right end of
	-- the edge, which only a very long name reaches.
	local rowAtRight = (frame.nameRow ~= nil and not narrow and cfg.portrait ~= "left") or false

	-- From the right corner inwards: the quest icon (Quest.lua draws it there), the flag, and
	-- the row when it stands at this end.
	local fromRight = cfg.quest and 1 or 0
	marks.pvp:ClearAllPoints()
	marks.pvp:SetSize(small, small)
	marks.pvp:SetPoint("CENTER", body, "TOPRIGHT", -(small * 0.5 + fromRight * step), 0)
	if has.pvp then
		fromRight = fromRight + 1
	end

	local fromLeft = 0
	for _, key in ipairs(EDGE_ROW) do
		local mark = marks[key]
		mark:ClearAllPoints()
		mark:SetSize(small, small)
		if key == "role" and narrow then
			-- A narrow frame has its raid mark on the top edge: the part played sits in the
			-- bottom left corner instead.
			mark:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 2 * pixel, 2 * pixel)
		elseif has[key] and rowAtRight then
			mark:SetPoint("CENTER", body, "TOPRIGHT", -(small * 0.5 + fromRight * step), 0)
			fromRight = fromRight + 1
		elseif has[key] then
			mark:SetPoint("CENTER", body, "TOPLEFT", small * 0.5 + fromLeft * step, 0)
			fromLeft = fromLeft + 1
		end
	end

	marks.raid:ClearAllPoints()
	if frame.nameRow and not narrow then
		-- Two lines of text: the mark closes the name's line, at the right, clear of the name
		-- and of the icons above the plate. It keeps to the left of whatever rides the edge
		-- above that end of the bar (a portrait at the right end has the marks over itself).
		local size = math.min(big, 16)
		local clear = math.max(0, fromRight * step - (frame.barRight - pixel))
		marks.raid:SetSize(size, size)
		marks.raid:SetPoint("RIGHT", frame.health, "RIGHT", -(4 + clear), frame.nameRow)
	elseif not narrow and ns.Elements.Auras.Room(cfg).above > 0 then
		-- One line of text and icons standing above the plate: inside, under the top edge, where
		-- it keeps clear of the icons (a long name runs under it).
		marks.raid:SetSize(big, big)
		marks.raid:SetPoint("TOP", body, "TOP", 0, -2 * pixel)
	else
		-- One line, or a narrow plate: the words have the inside, so the mark rides the middle
		-- of the top edge.
		marks.raid:SetSize(big, big)
		marks.raid:SetPoint("CENTER", body, "TOP", 0, 0)
	end

	marks.center:ClearAllPoints()
	marks.center:SetSize(big, big)
	marks.center:SetPoint("CENTER", body, "CENTER")
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
	local has = marks.has
	if has.raid then
		Sealed.RaidMarkToTexture(marks.raid, unit)
	end
	if has.leader then
		Sealed.LeaderToAlpha(marks.leader, unit)
	end
	if has.state then
		ShowState(frame, unit)
	end
	if has.role then
		ShowRole(frame, unit)
	end
	if has.pvp then
		ShowPvP(frame, unit)
	end
	if has.center then
		ShowCenter(frame, unit)
		if event == "READY_CHECK_FINISHED" then
			-- The game forgets the answers a few seconds after the check ends; look again then.
			ns.After(READY_LINGER, function()
				if frame.unit and frame.active.Marks and frame.marks.has.center and UnitExists(frame.unit) then
					ShowCenter(frame, frame.unit)
				end
			end)
		end
	end
end

Frame.Register(Marks)
