-- Version 0.3.2 against Blizzard's real code: the party's icons in the game's aura containers,
-- the light for a debuff the player can remove, a party member's cast bar, the font the addon
-- brings. The game's group header, its aura container and its buttons are Blizzard's own Lua
-- here; what the simulator does not do is seal anything, so that a fight changes nothing in it
-- (tools/tests models that part).
local ns = PugUnitFrames

if not PUGUF_SIM_CLOCK then -- the test files share one simulator, and its clock is switched over once
	A_Admin.SetManualClock(GetTime())
	PUGUF_SIM_CLOCK = true
end
local function Tick(seconds)
	A_Admin.AdvanceTime(seconds or 0.5)
end

local function NoProblems()
	local texts = {}
	for _, problem in ipairs(ns.GetProblems()) do
		texts[#texts + 1] = problem.text
	end
	assertEquals("", table.concat(texts, " | "))
end

local function PartyButton(index)
	return PugUnitFrames_party:GetAttribute("child" .. index)
end

-- What the game has put on one of its own aura buttons is closed to addon code. The simulator
-- lets a test ask as the game's own code would.
local function Seen(object, method, ...)
	return securecallfunction(object[method], object, ...)
end

-- The parts of a side's buttons that are on screen with an aura. (A container that has been
-- put away keeps its buttons as they were, unseen.)
local function ShownParts(there)
	local shown = {}
	for _, part in ipairs(there and there.parts or {}) do
		if Seen(part.button, "IsVisible") then
			shown[#shown + 1] = part
		end
	end
	return shown
end

test("a party member's buffs are drawn above the plate by the game's container, the debuffs beside it", function()
	A_Admin.SetPartySize(4)
	Tick()
	local cfg = ns.db.units.party
	local button = PartyButton(1)
	local above, beside = button.auras.sides.above, button.auras.sides.right
	assertNotNil(above, "a container above the plate")
	assertNotNil(beside, "and one to its right")
	assertEquals("party1", above.container:GetUnit())
	assertEquals("party1", beside.container:GetUnit())
	local buffs = #C_UnitAuras.GetUnitAuraInstanceIDs("party1", "HELPFUL", cfg.buffs)
	local debuffs = #C_UnitAuras.GetUnitAuraInstanceIDs("party1", "HARMFUL", cfg.debuffs)
	assertTrue(buffs > 0, "the simulator's party member has a buff")
	local shown = ShownParts(above)
	assertEquals(buffs, #shown)
	for _, part in ipairs(shown) do
		local left, bottom, width, height = Seen(part.button, "GetRect")
		assertAlmostEquals(cfg.auraSize, width, 0.01)
		assertAlmostEquals(cfg.auraSize, height, 0.01)
		assertTrue(bottom >= button:GetTop() + 2, "above the plate")
		assertTrue(bottom + height <= PartyButton(1):GetTop() + 3 + cfg.auraSize + 0.5, "in the room kept for it")
		assertNotNil(Seen(part.icon, "GetTexture"))
	end
	assertEquals(debuffs, #ShownParts(beside))
	-- Every member's containers follow that member.
	assertEquals("party3", PartyButton(3).auras.sides.above.container:GetUnit())
	NoProblems()
end)

test("the light for a debuff the player can remove is one of the game's buttons, as large as the plate and out of the pointer's way", function()
	local button = PartyButton(1)
	local lamp = button.auras.lamp
	assertNotNil(lamp.host, "a container of its own")
	assertNotNil(lamp.button, "with the game's button in it")
	assertEquals("party1", lamp.host:GetUnit())
	assertNotNil(lamp.host:GetAuraSlotFrame("removable"), "the game's slot for such a debuff")
	assertTrue(lamp.host:IsAuraSlotEnabled("removable"))
	assertFalse(lamp.button:IsMouseEnabled(), "the plate under it keeps the pointer")
	assertFalse(Seen(lamp.button, "IsVisible"), "dark while there is nothing to remove")
	assertEquals(4, #lamp.lines)
	-- Switched off, the game stops looking for such debuffs; switched on again, it looks again.
	ns.db.units.party.dispel = false
	ns.Refresh()
	assertFalse(lamp.host:IsAuraSlotEnabled("removable"))
	ns.db.units.party.dispel = true
	ns.Refresh()
	assertTrue(lamp.host:IsAuraSlotEnabled("removable"))
	NoProblems()
end)

test("moving the buffs to another side moves them to that side's container", function()
	local cfg = ns.db.units.party
	local button = PartyButton(1)
	local buffs = #C_UnitAuras.GetUnitAuraInstanceIDs("party1", "HELPFUL", cfg.buffs)
	cfg.buffSide = "below"
	ns.Refresh()
	Tick()
	local below = button.auras.sides.below
	assertNotNil(below, "a container under the plate, made when it was first wanted")
	local shown = ShownParts(below)
	assertEquals(buffs, #shown)
	for _, part in ipairs(shown) do
		local _, bottom, _, height = Seen(part.button, "GetRect")
		assertTrue(bottom + height <= button:GetBottom() - 2, "under the plate")
	end
	assertFalse(button.auras.sides.above.container:IsShown(), "and the one above is put away")
	cfg.buffSide = "above"
	ns.Refresh()
	Tick()
	assertEquals(buffs, #ShownParts(button.auras.sides.above))
	assertFalse(below.container:IsShown())
	-- None at all.
	cfg.buffs = 0
	ns.Refresh()
	Tick()
	assertEquals(0, #ShownParts(button.auras.sides.above))
	cfg.buffs = 8
	ns.Refresh()
	Tick()
	assertEquals(buffs, #ShownParts(button.auras.sides.above))
	NoProblems()
end)

-- The simulator has no casts but the player's. A party member's is put in front of the two
-- functions the addon asks, as the game would answer them.
local function WithPartyCast(run)
	local gameInfo, gameDuration = UnitCastingInfo, UnitCastingDuration
	local casting = false
	local duration = C_DurationUtil.CreateDuration()
	UnitCastingInfo = function(unit)
		if unit == "party1" and casting then
			return "Smite", "Smite", "Interface\\Icons\\Spell_Holy_HolySmite", GetTime() * 1000, (GetTime() + 2.5) * 1000, false, "cast-1", false, 585, 77
		end
		return gameInfo(unit)
	end
	UnitCastingDuration = function(unit)
		if unit == "party1" then
			return casting and duration or nil
		end
		return gameDuration(unit)
	end
	local ok, problem = pcall(run, function(on)
		casting = on
		if on then
			duration:SetTimeFromStart(GetTime(), 2.5)
		end
	end)
	UnitCastingInfo, UnitCastingDuration = gameInfo, gameDuration
	if not ok then
		error(problem, 0)
	end
end

test("a party member's cast bar comes up once cast bars are switched on for the party", function()
	local cfg = ns.db.units.party
	assertFalse(cfg.castbar, "off to begin with")
	local first, second = PartyButton(1), PartyButton(2)
	local gap = first:GetBottom() - second:GetTop()
	cfg.castbar = true
	ns.Refresh()
	Tick()
	first, second = PartyButton(1), PartyButton(2)
	assertTrue(first.active.CastBar, "the element is on")
	assertTrue(first:IsEventRegistered("UNIT_SPELLCAST_START"), "the frame listens for its member's casts")
	assertAlmostEquals(gap + cfg.castHeight + 3, first:GetBottom() - second:GetTop(), 0.6)
	WithPartyCast(function(SetCasting)
		local cast = first.cast
		assertFalse(cast:IsShown())
		-- Announced by the game.
		SetCasting(true)
		A_Admin.FireEvent("UNIT_SPELLCAST_START", "party1")
		assertTrue(cast:IsVisible(), "the bar is up")
		assertEquals("Smite", cast.text:GetText())
		assertAlmostEquals(first:GetLeft(), cast:GetLeft(), 0.6)
		assertAlmostEquals(first:GetWidth(), cast:GetWidth(), 0.6)
		assertTrue(cast:GetTop() <= first:GetBottom() - 2, "under its member's plate")
		assertTrue(cast:GetBottom() >= second:GetTop() + 3 + cfg.auraSize, "and clear of the next member's buffs")
		Tick(0.3)
		assertTrue(cast:IsVisible(), "it stays while the cast runs")
		assertAlmostEquals(1, cast:GetAlpha(), 0.01)
		SetCasting(false)
		A_Admin.FireEvent("UNIT_SPELLCAST_STOP", "party1")
		assertFalse(cast:IsShown(), "and goes with it")

		-- A cast whose end the game never announces is put away when it is found to be over.
		SetCasting(true)
		A_Admin.FireEvent("UNIT_SPELLCAST_START", "party1")
		assertTrue(cast:IsVisible())
		SetCasting(false)
		Tick(0.3)
		Tick(0.3)
		assertFalse(cast:IsShown(), "gone without a word from the game")
	end)
	cfg.castbar = false
	ns.Refresh()
	Tick()
	assertAlmostEquals(gap, PartyButton(1):GetBottom() - PartyButton(2):GetTop(), 0.6)
	NoProblems()
end)

test("the game is asked for the addon's font as it loads, and the frames are lettered in it", function()
	assertNotNil(PugUnitFramesFont, "Fonts.xml made the font object")
	local file = PugUnitFramesFont:GetFont()
	assertContains(file:gsub("\\", "/"), "PugUnitFrames/Fonts/Inter-SemiBold.ttf")
	local used = PugUnitFrames_player.texts.name:GetFont()
	assertContains(used:gsub("\\", "/"), "Inter-SemiBold.ttf")
	NoProblems()
end)

test("in a fight the frames are drawn as out of one, and nothing is refused", function()
	A_Admin.SetTarget("Hogger", 11, 1, true)
	Tick()
	A_Admin.SetInCombat(true)
	Tick()
	assertTrue(InCombatLockdown())
	ns.Frame.RefreshAll()
	A_Admin.ClearTarget()
	Tick()
	A_Admin.SetTarget("Hogger", 11, 1, true)
	Tick()
	local there = PugUnitFrames_target.auras.sides.above
	local wanted = #C_UnitAuras.GetUnitAuraInstanceIDs("target", "HELPFUL", 9) + #C_UnitAuras.GetUnitAuraInstanceIDs("target", "HARMFUL", 18)
	assertEquals(wanted, #ShownParts(there), "a target picked in the fight has its icons")
	A_Admin.SetInCombat(false)
	Tick()
	A_Admin.ClearTarget()
	Tick()
	NoProblems()
end)
