-- Pug Unit Frames against Blizzard's real Forever interface code, in the wow-ui-sim simulator.
-- Run with tools/sim/run.sh (it copies this folder into a scratch copy of the addon).
--
-- Nothing here is a model written by us: the secure unit buttons, the group header that makes
-- the party frames, the unit watch that shows and hides them and the settings window are
-- Blizzard's own Lua. The simulator's character is a Paladin in a party of five.
local ns = PugUnitFrames

-- Every protected call the client refused while a test ran.
local refused = {}
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
watcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watcher:SetScript("OnEvent", function(_, event, addon, what)
	refused[#refused + 1] = event .. ": " .. tostring(addon) .. " " .. tostring(what)
end)

local function NothingRefused()
	assertEquals("", table.concat(refused, " | "))
end

local function NoProblems()
	local texts = {}
	for _, problem in ipairs(ns.GetProblems()) do
		texts[#texts + 1] = problem.text
	end
	assertEquals("", table.concat(texts, " | "))
end

test("login built the frames without an error or a refused call", function()
	assertTrue(ns.IsBuilt())
	NoProblems()
	NothingRefused()
end)

test("each single frame is a secure unit button for its unit", function()
	for _, kind in ipairs({ "player", "target", "targettarget", "focus", "pet" }) do
		local frame = _G["PugUnitFrames_" .. kind]
		assertNotNil(frame)
		local protected, explicit = frame:IsProtected()
		assertTrue(protected)
		assertTrue(explicit)
		assertEquals(kind, frame:GetAttribute("unit"))
		assertEquals("target", frame:GetAttribute("type1"))
		assertEquals("togglemenu", frame:GetAttribute("*type2"))
		assertEquals(SecureUnitButton_OnClick, frame:GetScript("OnClick"))
		assertTrue(ClickCastFrames[frame])
	end
end)

test("the player frame is up, sized and placed as the settings say", function()
	local frame, cfg = PugUnitFrames_player, ns.db.units.player
	assertTrue(frame:IsShown())
	assertAlmostEquals(cfg.width, frame:GetWidth(), 0.01)
	assertAlmostEquals(cfg.height, frame:GetHeight(), 0.01)
	local x, y = frame:GetCenter()
	local middleX, middleY = UIParent:GetCenter()
	assertAlmostEquals(cfg.x, x - middleX, 0.5)
	assertAlmostEquals(cfg.y, y - middleY, 0.5)
	assertEquals("player", frame.unit)
end)

-- The game's unit watch shows and hides a frame on its next update after the unit changed, so
-- the tests step the simulator's clock themselves.
if not PUGUF_SIM_CLOCK then -- the test files share one simulator, and its clock is switched over once
	A_Admin.SetManualClock(GetTime())
	PUGUF_SIM_CLOCK = true
end
local function Tick(seconds)
	A_Admin.AdvanceTime(seconds or 0.5)
end

test("a frame comes and goes with its unit", function()
	A_Admin.ClearTarget()
	Tick()
	assertFalse(PugUnitFrames_target:IsShown())
	A_Admin.SetTarget("Hogger", 11, 1, true)
	Tick()
	assertTrue(UnitExists("target"))
	assertTrue(PugUnitFrames_target:IsShown())
	assertEquals("target", PugUnitFrames_target.unit)
	A_Admin.ClearTarget()
	Tick()
	assertFalse(PugUnitFrames_target:IsShown())
	NoProblems()
end)

test("the party header made a frame for each of the four others", function()
	local header = PugUnitFrames_party
	assertTrue(header:IsShown())
	local count = 0
	for index = 1, 5 do
		local button = header:GetAttribute("child" .. index)
		if button and button:IsShown() then
			count = count + 1
			assertEquals("party", button.kind)
			assertEquals("party" .. index, button:GetAttribute("unit"))
			assertEquals(button:GetAttribute("unit"), button.unit)
			assertAlmostEquals(ns.db.units.party.width, button:GetWidth(), 0.01)
			assertAlmostEquals(ns.db.units.party.height, button:GetHeight(), 0.01)
			assertEquals("target", button:GetAttribute("type1"))
			assertNotNil(button.health)
		end
	end
	assertEquals(4, count)
	NoProblems()
end)

test("the game's own frames stepped aside", function()
	assertFalse(PlayerFrame:IsVisible())
	assertFalse(TargetFrame:IsVisible())
	assertFalse(PartyFrame:IsVisible())
	assertFalse(ns.Blizzard.NeedsReload())
end)

test("the options register with the Settings window and both pages build", function()
	assertNotNil(ns.Options.category)
	assertNotNil(ns.Options.framesCategory)
	ns.Options.Open()
	NoProblems()
end)

test("a setting changed through the profile reaches the frame", function()
	local cfg = ns.db.units.player
	local width = cfg.width
	cfg.width = width + 20
	ns.Refresh()
	assertAlmostEquals(width + 20, PugUnitFrames_player:GetWidth(), 0.01)
	cfg.width = width
	ns.Refresh()
	assertAlmostEquals(width, PugUnitFrames_player:GetWidth(), 0.01)
	NoProblems()
	NothingRefused()
end)

test("in combat a change of size waits for the fight to end, and nothing is refused", function()
	local cfg = ns.db.units.target
	local height = cfg.height
	A_Admin.SetInCombat(true)
	cfg.height = height + 10
	ns.Refresh()
	assertAlmostEquals(height, PugUnitFrames_target:GetHeight(), 0.01)
	A_Admin.SetInCombat(false)
	assertAlmostEquals(height + 10, PugUnitFrames_target:GetHeight(), 0.01)
	cfg.height = height
	ns.Refresh()
	NoProblems()
	NothingRefused()
end)

test("export and import bring the same settings back", function()
	local text = ns.Profiles.Export(ns.db)
	assertEquals("PUGUF2:", text:sub(1, 7))
	local copy = ns.Profiles.Import(text)
	assertNotNil(copy)
	assertEquals(ns.db.units.raid.perColumn, copy.units.raid.perColumn)
	assertEquals(ns.db.theme, copy.theme)
	local nothing, why = ns.Profiles.Import("PUGUF2:not really")
	assertNil(nothing)
	assertNotNil(why)
end)
