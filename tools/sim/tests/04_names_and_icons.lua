-- Version 0.3 against Blizzard's real code: names on a line of their own, the dragon beside an
-- elite's level, Questie's icon, portraits, and a party whose buffs stand above each member.
-- Here the regions have real sizes and places, which the stand-in of tools/tests has not.
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

test("the target's name has a line to itself, as wide as the health bar", function()
	A_Admin.SetTarget("Stormwind City Patroller", 24, 1, true)
	Tick()
	local frame = PugUnitFrames_target
	local texts = frame.texts
	assertEquals("Stormwind City Patroller", texts.name:GetText())
	-- Held at both ends of the health bar, with nothing else on its line.
	assertEquals(2, texts.name:GetNumPoints())
	local point, to, toPoint = texts.name:GetPoint(1)
	assertEquals("LEFT", point)
	assertEquals(frame.health, to)
	assertEquals("LEFT", toPoint)
	point, to, toPoint = texts.name:GetPoint(2)
	assertEquals("RIGHT", point)
	assertEquals(frame.health, to)
	assertEquals("RIGHT", toPoint)
	local room = frame.health:GetWidth() - 8
	assertTrue(room > 170, "room for a long name beside a portrait")
	assertTrue(texts.name:GetStringWidth() <= room, "and this one fits, also in the simulator's wider font")
	-- The name above, the level and the health number below it.
	local _, nameY = texts.name:GetCenter()
	local _, levelY = texts.level:GetCenter()
	local _, healthY = texts.health:GetCenter()
	assertTrue(nameY > levelY + 8)
	assertAlmostEquals(levelY, healthY, 1)
	assertTrue(texts.level:GetLeft() < texts.health:GetLeft(), "level from the left, number from the right")
	-- The power number sits on the power bar.
	local _, powerY = texts.power:GetCenter()
	local _, barY = frame.power:GetCenter()
	assertAlmostEquals(barY, powerY, 0.6)
	NoProblems()
end)

test("a character's first name and surname are both written, and a creature keeps its one name", function()
	local gameUnitName = UnitName
	UnitName = function(unit)
		local name = gameUnitName(unit)
		return name, (unit == "player" or unit == "party1") and "Brightmoor" or nil
	end
	A_Admin.SetPartySize(4)
	A_Admin.SetTarget("Hogger", 11, 1, true)
	Tick()
	ns.Frame.RefreshAll()
	local first = gameUnitName("player")
	assertEquals(first .. " Brightmoor", PugUnitFrames_player.texts.name:GetText())
	assertEquals(gameUnitName("party1") .. " Brightmoor", PartyButton(1).texts.name:GetText())
	assertEquals(gameUnitName("party2"), PartyButton(2).texts.name:GetText())
	assertEquals("Hogger", PugUnitFrames_target.texts.name:GetText())
	-- The line it is on has room for the longest name the game lets a character have.
	local room = PartyButton(1).health:GetWidth() - 8
	assertTrue(room >= 150, "the party's name line")
	ns.db.units.player.surname = false
	ns.Refresh()
	assertEquals(first, PugUnitFrames_player.texts.name:GetText())
	ns.db.units.player.surname = true
	ns.Refresh()
	UnitName = gameUnitName
	ns.Frame.RefreshAll()
	NoProblems()
end)

test("an elite target has the game's gold dragon before its level", function()
	A_Admin.SetTarget("Hogger", 11, 1, true)
	A_Admin.SetTargetType("elite", "Humanoid", 2)
	Tick()
	ns.Frame.Refresh(PugUnitFrames_target)
	local texts = PugUnitFrames_target.texts
	assertEquals("elite", UnitClassification("target"))
	assertTrue(texts.rank:IsShown())
	assertEquals("nameplates-icon-elite-gold", texts.rank:GetAtlas())
	assertTrue(texts.rank:GetRight() <= texts.level:GetLeft(), "the level stands after it")
	assertEquals("11+", texts.level:GetText())
	ns.db.units.target.elite = false
	ns.Refresh()
	assertFalse(texts.rank:IsShown())
	ns.db.units.target.elite = true
	ns.Refresh()
	assertTrue(texts.rank:IsShown())
	NoProblems()
end)

test("portraits stand at the ends of the plates, and the bars beside them", function()
	local player, target = PugUnitFrames_player, PugUnitFrames_target
	assertTrue(player.portrait:IsShown())
	assertAlmostEquals(player:GetLeft(), player.portrait:GetLeft(), 1.5)
	assertTrue(player.health:GetLeft() >= player.portrait:GetRight())
	assertTrue(target.portrait:IsShown())
	assertAlmostEquals(target:GetRight(), target.portrait:GetRight(), 1.5)
	assertTrue(target.health:GetRight() <= target.portrait:GetLeft())
	NoProblems()
end)

test("Questie's icon for a creature is drawn in the target frame's corner, when Questie can be asked", function()
	local asked = {}
	local old = QuestieLoader
	QuestieLoader = {
		ImportModule = function(_, name)
			return {
				GetIcon = function(guid)
					asked[#asked + 1] = guid
					return name == "QuestieNameplate" and "Interface\\Icons\\INV_Misc_QuestionMark" or nil
				end,
			}
		end,
	}
	A_Admin.SetTarget("Hogger", 11, 1, true)
	Tick()
	ns.Frame.Refresh(PugUnitFrames_target)
	local icon = PugUnitFrames_target.quest.icon
	local guid = ns.Sealed.CreatureGUID("target")
	if guid then
		assertTrue(icon:IsShown())
		assertEquals(guid, asked[#asked])
		local x = icon:GetCenter()
		assertTrue(x > PugUnitFrames_target:GetRight() - 20, "at the right end of the top edge")
	else
		-- This simulator's GUIDs are not written as the game writes a creature's: nothing to ask about.
		assertFalse(icon:IsShown())
		assertEquals(0, #asked)
	end
	assertEquals(nil, ns.Sealed.CreatureGUID("player"), "a player is not a creature")
	QuestieLoader = old
	ns.Frame.Refresh(PugUnitFrames_target)
	assertFalse(icon:IsShown(), "and without Questie there is none")
	NoProblems()
end)

test("party members stand far enough apart for the row of buffs above each", function()
	A_Admin.SetPartySize(4)
	Tick()
	local cfg = ns.db.units.party
	local first, second = PartyButton(1), PartyButton(2)
	assertTrue(first and second and first:IsVisible() and second:IsVisible())
	local row = 3 + cfg.auraSize
	assertAlmostEquals(cfg.spacing + row, first:GetBottom() - second:GetTop(), 0.6)
	assertTrue(first.portrait:IsShown())
	assertEquals("short", cfg.healthText)
	assertTrue(first.texts.health:GetText() ~= nil)
	local _, nameY = first.texts.name:GetCenter()
	local _, healthY = first.texts.health:GetCenter()
	assertTrue(nameY > healthY + 8, "the name above the amount")
	-- The marks nobody asked for are away.
	assertFalse(first.marks.leader:IsShown())
	assertFalse(first.marks.role:IsShown())
	assertFalse(first.marks.pvp:IsShown())
	NoProblems()
end)
