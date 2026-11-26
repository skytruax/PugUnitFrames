-- First of the test files (they run in the order of their names and share one simulator): what a
-- fresh install starts with, and then the settings the other files are written against.
--
-- What a frame starts out as is a matter of taste and changes with it (0.3.4 took the author's
-- own settings for it). The files after this one are about how things are drawn, against
-- Blizzard's real code, and were written for the frames as they started up to 0.3.3: this file
-- puts those settings back before they run, so that they do not break when the starting ones
-- change again. tools/tests does the same (BENCH in tests.lua).
local ns = PugUnitFrames

local function NoProblems()
	local texts = {}
	for _, problem in ipairs(ns.GetProblems()) do
		texts[#texts + 1] = problem.text
	end
	assertEquals("", table.concat(texts, " | "))
end

test("a fresh install starts with the author's own settings, and its frames are built with them", function()
	local db, units = ns.db, ns.db.units
	assertFalse(db.shadows)
	assertEquals("value", units.player.healthText)
	assertEquals("value", units.party.healthText)
	assertAlmostEquals(1.15, units.player.scale, 0.001)
	assertAlmostEquals(1.3, units.focus.scale, 0.001)
	assertAlmostEquals(1.2, units.party.scale, 0.001)
	assertTrue(units.party.castbar)
	assertTrue(units.party.level)
	assertTrue(units.party.mirror)
	assertFalse(units.target.marks)
	assertEquals(6, units.target.buffs)
	assertFalse(units.raid.enabled)
	assertFalse(units.player.levelBadge)
	assertTrue(units.target.castLocked, "grey orange for a cast that cannot be interrupted: the target")
	assertTrue(units.focus.castLocked, "and the focus")
	assertFalse(units.player.castLocked)
	assertAlmostEquals(1.15, PugUnitFrames_player:GetScale(), 0.001)
	assertAlmostEquals(units.player.width, PugUnitFrames_player:GetWidth(), 0.01)
	local party = PugUnitFrames_party
	assertAlmostEquals(1.2, party:GetScale(), 0.001)
	local member = party:GetAttribute("child1")
	assertNotNil(member)
	assertTrue(member.active.CastBar, "a party member has a cast bar from the start")
	assertTrue(member:IsEventRegistered("UNIT_SPELLCAST_START"))
	assertNotNil(member.texts.level:GetText(), "and its level")
	assertFalse(PugUnitFrames_raid:IsShown(), "the raid frames wait to be switched on")
	NoProblems()
end)

-- The settings of 0.3.3, on this simulator's screen (960 units wide: the frames at its sides
-- start twelve in from the edge).
local BENCH = {
	player = { scale = 1, healthText = "both", castHeight = 16, powerHeight = 10, x = -290, y = -210 },
	target = { scale = 1, healthText = "both", castHeight = 16, powerHeight = 10, buffs = 9, marks = true, x = 290, y = -210 },
	targettarget = { x = 398, y = -219 },
	focus = { scale = 1, x = -306, y = -130 },
	pet = { x = -406, y = -219 },
	party = { scale = 1, castbar = false, castHeight = 10, healthText = "short", level = false, mirror = false, x = -468, y = 160 },
	raid = { enabled = true, x = -468, y = 250 },
}

test("the settings the other test files are written against are put in place", function()
	ns.db.shadows = true
	for kind, values in pairs(BENCH) do
		for key, value in pairs(values) do
			ns.db.units[kind][key] = value
		end
	end
	ns.Refresh()
	assertAlmostEquals(1, PugUnitFrames_player:GetScale(), 0.001)
	assertFalse(ns.db.units.party.castbar)
	NoProblems()
end)
