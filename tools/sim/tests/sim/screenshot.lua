-- Runs in the simulator after login, just before the screenshot is taken (tools/sim/run.sh).
-- Sets up a moment of a fight for the frames to draw: a party of four, a hostile elite target, a
-- focus, the player healing. The fight has five moments; PugUnitFramesSimStep picks one
-- (tools/sim/demo.sh renders them all for the moving demo). The still picture is the third.
--
-- The addon's code is what draws the picture, unchanged. What stands in for the game:
--   * The simulator can set up a player, a target, a focus and four party members. It has no
--     handle for other units' auras, casts and power, for threat, range or raid marks, so the
--     scene answers those game functions itself (see "The scene's answers" below).
--   * It has none of the game's art. tools/sim/scene_art.py puts the game's icons for the scene's
--     spells, its raid marks and a painted city into the scratch copy (PugUnitFramesSimArt);
--     without them icons are blank squares and the world is the simulator's grey.
--   * It draws a bar that runs on a timer as empty, and does not move the end of a bar's fill
--     texture as the game does, which is what the cast bar's bright edge is pinned to. The scene
--     fills each cast bar as far as its cast has come and pins the edge there.
--   * Blizzard's own interface is put away: with no art it is a scatter of bare numbers.
local ns = PugUnitFrames
local art = PugUnitFramesSimArt
local STEP = PugUnitFramesSimStep or 3

local function Icon(spell)
	if art and art.icons[spell] then
		return art.folder .. art.icons[spell]
	end
	return 134400 -- no picture for it: a blank square
end

---------------------------------------------------------------------------
-- The fight, moment by moment
---------------------------------------------------------------------------
local MAGIC, CURSE, DISEASE, POISON, NONE = 1, 2, 3, 4, 0

-- What each spell is when it sits on someone: its kind, whether it harms, how long it lasts.
local SPELLS = {
	["Rend"] = { kind = NONE, harmful = true, total = 21 },
	["Sunder Armor"] = { kind = NONE, harmful = true, total = 30 },
	["Frost Nova"] = { kind = MAGIC, harmful = true, total = 8 },
	["Curse of Agony"] = { kind = CURSE, harmful = true, total = 24 },
	["Curse of Weakness"] = { kind = CURSE, harmful = true, total = 120 },
	["Devouring Plague"] = { kind = DISEASE, harmful = true, total = 24 },
	["Viper Sting"] = { kind = POISON, harmful = true, total = 8 },
	["Deadly Poison"] = { kind = POISON, harmful = true, total = 12, removable = true },
	["Immolate"] = { kind = MAGIC, harmful = true, total = 15 },
	["Battle Shout"] = { total = 120 },
	["Enrage"] = { total = 8 },
}

-- player: health, mana, and how far into Holy Light (2.5 s) if casting
-- target, focus and each of the party: health, power
-- auras: spell, seconds left, stacks        casts: spell, seconds done, seconds in all, shielded
local FIGHT = {
	{ -- 1: the pull. Everyone whole; the warlock is already casting.
		player = { 5000, 3180 }, target = { 664, 12 }, focus = { 520, 440 },
		party = { { 5100, 8 }, { 3100, 2900 }, { 3600, 2600 }, { 4000, 2200 } },
		threat = 1,
		auras = { target = { { "Battle Shout", 112 } } },
		casts = { focus = { "Shadow Bolt", 0.5, 2.5 } },
	},
	{ -- 2: Hogger turns on the tank and winds up.
		player = { 5000, 3180 }, target = { 571, 30 }, focus = { 520, 400 },
		party = { { 4131, 34 }, { 3100, 2760 }, { 3600, 2440 }, { 4000, 2050 } },
		threat = 3,
		auras = {
			target = { { "Rend", 14 }, { "Sunder Armor", 28, 1 }, { "Battle Shout", 108 } },
			party1 = { { "Rend", 19 } },
		},
		casts = { focus = { "Shadow Bolt", 2.0, 2.5 }, target = { "Enrage", 0.4, 3.0, true } },
	},
	{ -- 3: the bolt has landed on the shaman and poison with it; the hunter has run too far; the heal is on its way.
		player = { 3550, 2310, 1.4 }, target = { 279, 35 }, focus = { 402, 310 },
		party = { { 3264, 62 }, { 3100, 2480 }, { 1368, 640 }, { 3440, 1900 } },
		threat = 3, far = true,
		auras = {
			target = { { "Rend", 9 }, { "Sunder Armor", 22, 3 }, { "Frost Nova", 5 }, { "Curse of Agony", 17 }, { "Devouring Plague", 11 },
				{ "Viper Sting", 6 }, { "Battle Shout", 104 } },
			focus = { { "Curse of Weakness", 60 }, { "Immolate", 8 } },
			party1 = { { "Rend", 12 }, { "Sunder Armor", 20, 2 } },
			party3 = { { "Deadly Poison", 9, 3 }, { "Frost Nova", 4 } },
		},
		casts = { focus = { "Shadow Bolt", 1.0, 2.5 }, target = { "Enrage", 1.9, 3.0, true } },
	},
	{ -- 4: the heal has landed and the poison is gone; Hogger is enraged; the warlock's next cast is cut short.
		player = { 3900, 1730 }, target = { 152, 64 }, focus = { 265, 300 },
		party = { { 2805, 80 }, { 3100, 2300 }, { 3096, 640 }, { 3780, 1820 } },
		threat = 3, interrupted = "focus",
		auras = {
			target = { { "Rend", 6 }, { "Sunder Armor", 28, 4 }, { "Curse of Agony", 14 }, { "Devouring Plague", 8 }, { "Battle Shout", 100 },
				{ "Enrage", 7 } },
			focus = { { "Curse of Weakness", 57 }, { "Immolate", 5 } },
			party1 = { { "Rend", 9 }, { "Sunder Armor", 17, 2 } },
			party3 = { { "Frost Nova", 1 } },
		},
		casts = { focus = { "Shadow Bolt", 0.6, 2.5 } },
	},
	{ -- 5: nearly done.
		player = { 4300, 1730 }, target = { 38, 80 }, focus = { 96, 290 },
		party = { { 3060, 92 }, { 3100, 2420 }, { 3240, 780 }, { 4000, 1700 } },
		threat = 3,
		auras = {
			target = { { "Rend", 3 }, { "Sunder Armor", 25, 5 }, { "Curse of Agony", 11 }, { "Devouring Plague", 5 }, { "Battle Shout", 96 },
				{ "Enrage", 4 } },
			focus = { { "Curse of Weakness", 54 }, { "Immolate", 2 } },
			party1 = { { "Sunder Armor", 14, 2 } },
		},
		casts = {},
	},
}
local moment = FIGHT[STEP] or error("the fight has no moment " .. tostring(STEP))

---------------------------------------------------------------------------
-- Where the frames stand in the picture (a 960 x 540 screen; the settings are the player's own
-- to change, these are simply a tidy arrangement of them)
---------------------------------------------------------------------------
local units = ns.db.units
-- The simulator answers "is the pet visible" with yes although there is no pet, which leaves an
-- empty pet frame in the picture. In the game the frame is only up while a pet is.
units.pet.enabled = false
units.party.x, units.party.y = -395, 212
units.focus.x, units.focus.y = -128, -22
units.player.x, units.player.y = -99, -118
units.target.x, units.target.y = 241, -118
ns.Refresh()

---------------------------------------------------------------------------
-- Who is there (the simulator's own controls)
---------------------------------------------------------------------------
local WARRIOR, HUNTER, PRIEST, SHAMAN, WARLOCK = 1, 3, 5, 7, 9
local HEALTH = { player = 5000, target = 664, focus = 520, party = { 5100, 3100, 3600, 4000 } }
local MANA = { player = 3180, focus = 440, party = { 100, 2900, 2600, 2200 } }

A_Admin.SetPlayerName("Halla")
A_Admin.SetPlayerLevel(60)
A_Admin.SetPlayerHealth(moment.player[1], HEALTH.player)
A_Admin.SetPlayerPower(moment.player[2], MANA.player)

local PARTY = { { "Thryn", WARRIOR, 60 }, { "Lioren", PRIEST, 60 }, { "Maeve", SHAMAN, 59 }, { "Brask", HUNTER, 60 } }
for index, member in ipairs(PARTY) do
	A_Admin.SetPartyMember(index, member[1], member[2], member[3])
	A_Admin.SetPartyMemberHealth(index, moment.party[index][1], HEALTH.party[index])
end

A_Admin.SetTarget("Hogger", 11, WARRIOR, true)
A_Admin.SetTargetType("elite", "Humanoid", 2)
A_Admin.SetTargetHealth(moment.target[1], HEALTH.target)

A_Admin.SetFocus("Morgash", 12, WARLOCK)
A_Admin.SetFocusHealth(moment.focus[1], HEALTH.focus)
A_Admin.SetFocusPower(moment.focus[2], MANA.focus)

---------------------------------------------------------------------------
-- The scene's answers, for what the simulator has no handle for
---------------------------------------------------------------------------
local now = GetTime()

local auraByID, aurasOf, nextID = {}, {}, 5000
for unit, list in pairs(moment.auras) do
	aurasOf[unit] = {}
	for _, entry in ipairs(list) do
		local spell = SPELLS[entry[1]] or error("the scene has no spell " .. tostring(entry[1]))
		nextID = nextID + 1
		local aura = { id = nextID, spell = entry[1], left = entry[2], stacks = entry[3] or 0, kind = spell.kind, harmful = spell.harmful or false,
			removable = spell.removable, total = spell.total }
		auraByID[nextID] = aura
		table.insert(aurasOf[unit], aura)
	end
end

function C_UnitAuras.GetUnitAuraInstanceIDs(unit, filter, limit)
	local ids = {}
	local harmful = filter:find("HARMFUL", 1, true) ~= nil
	local removable = filter:find("RAID", 1, true) ~= nil
	for _, aura in ipairs(aurasOf[unit] or {}) do
		if aura.harmful == harmful and (not removable or aura.removable) and #ids < (limit or 40) then
			ids[#ids + 1] = aura.id
		end
	end
	return ids
end

function C_UnitAuras.GetAuraDataByAuraInstanceID(_, id)
	local aura = auraByID[id]
	if aura then
		return { auraInstanceID = id, name = aura.spell, icon = Icon(aura.spell), applications = aura.stacks,
			duration = aura.total, expirationTime = now + aura.left, isHarmful = aura.harmful }
	end
end

function C_UnitAuras.GetAuraDuration(_, id)
	local aura = auraByID[id]
	local duration = C_DurationUtil.CreateDuration()
	if aura then
		duration:SetTimeFromEnd(now + aura.left, aura.total)
	end
	return duration
end

function C_UnitAuras.GetAuraApplicationDisplayCount(_, id, minimum)
	local aura = auraByID[id]
	local stacks = aura and aura.stacks or 0
	return stacks >= (minimum or 2) and tostring(stacks) or ""
end

function C_UnitAuras.GetAuraDispelTypeColor(_, id, curve)
	local aura = auraByID[id]
	return aura and curve:Evaluate(aura.kind or NONE) or nil
end

-- Casts of the others (the player's own is the simulator's).
local casts = {}
for unit, cast in pairs(moment.casts) do
	casts[unit] = { spell = cast[1], done = cast[2], length = cast[3], shielded = cast[4] or false, id = 70 + #cast[1] }
end
local gameCastingInfo, gameCastingDuration = UnitCastingInfo, UnitCastingDuration

function UnitCastingDuration(unit)
	local cast = casts[unit]
	if not cast then
		return gameCastingDuration(unit)
	end
	local duration = C_DurationUtil.CreateDuration()
	duration:SetTimeFromStart(GetTime() - cast.done, cast.length)
	return duration
end

function UnitCastingInfo(unit)
	local cast = casts[unit]
	if not cast then
		return gameCastingInfo(unit)
	end
	local start = (GetTime() - cast.done) * 1000
	return cast.spell, cast.spell, Icon(cast.spell), start, start + cast.length * 1000, false, nil, cast.shielded, nil, cast.id
end

-- What each of the others runs on and how much is left (the simulator gives every party member
-- the same): type, token, now, at most.
local POWER = { target = { 1, "RAGE", moment.target[2], 100 } }
for index, member in ipairs(moment.party) do
	local rage = index == 1
	POWER["party" .. index] = { rage and 1 or 0, rage and "RAGE" or "MANA", member[2], MANA.party[index] }
end
local gamePowerType, gamePower, gamePowerMax = UnitPowerType, UnitPower, UnitPowerMax

function UnitPowerType(unit)
	local power = POWER[unit]
	if power then
		return power[1], power[2]
	end
	return gamePowerType(unit)
end

function UnitPower(unit, ...)
	local power = POWER[unit]
	return power and power[3] or gamePower(unit, ...)
end

function UnitPowerMax(unit, ...)
	local power = POWER[unit]
	return power and power[4] or gamePowerMax(unit, ...)
end

-- The tank has the target on him; in the thick of it the hunter has run too far to be healed.
function UnitThreatSituation(unit)
	return unit == "party1" and moment.threat or 0
end

function UnitInRange(unit)
	return not (moment.far and unit == "party4"), true
end

local MARKS = { target = 8, focus = 1 } -- skull and star
function GetRaidTargetIndex(unit)
	return MARKS[unit]
end

---------------------------------------------------------------------------
-- The moment
---------------------------------------------------------------------------
A_Admin.SetManualClock(now)
local healing = moment.player[3]
if healing then
	A_Admin.SetCasting(635, "Holy Light", Icon("Holy Light"), 2.5)
	A_Admin.FireEvent("UNIT_SPELLCAST_START", "player")
end
A_Admin.AdvanceTime(healing or 1)

-- Blizzard's interface goes away once the frames have come up for their units (the simulator
-- shows and hides those through frames of its own, which must still be running then).
for _, child in ipairs({ UIParent:GetChildren() }) do
	local name = child:GetName()
	if not (name and name:find("^PugUnitFrames")) then
		child:Hide()
	end
end
A_Admin.SetInCombat(true)

if art then
	-- The game's sheet of raid marks, in the place of the one the simulator does not have.
	for _, frame in ipairs(ns.Frame.All()) do
		if frame.marks then
			frame.marks.raid:SetTexture(art.folder .. art.marks)
		end
	end
	-- A world behind the frames.
	local world = CreateFrame("Frame", "PugUnitFramesSimWorld", UIParent)
	world:SetAllPoints(UIParent)
	world:SetFrameStrata("BACKGROUND")
	local picture = world:CreateTexture(nil, "BACKGROUND")
	picture:SetAllPoints(world)
	picture:SetTexture(art.folder .. art.backdrop)
end

ns.Frame.RefreshAll()

-- Each cast bar on show, filled as far as its cast has come, with its bright edge where the fill ends.
local done = { player = healing and healing / 2.5 or nil }
for unit, cast in pairs(casts) do
	done[unit] = cast.done / cast.length
end
for _, frame in ipairs(ns.Frame.All()) do
	local cast, share = frame.cast, done[frame.unit or ""]
	if cast and share and cast:IsShown() then
		cast.bar:SetMinMaxValues(0, 1)
		cast.bar:SetValue(share)
		local along = cast.bar:GetWidth() * share
		cast.spark:ClearAllPoints()
		cast.spark:SetPoint("TOP", cast.bar, "TOPLEFT", along, 0)
		cast.spark:SetPoint("BOTTOM", cast.bar, "BOTTOMLEFT", along, 0)
	end
end

-- A cast cut short: it ends, and the game says it was interrupted. The frame's own code holds
-- the bar up in red for a moment, which is the moment in the picture.
if moment.interrupted then
	casts[moment.interrupted] = nil
	A_Admin.FireEvent("UNIT_SPELLCAST_INTERRUPTED", moment.interrupted)
end
