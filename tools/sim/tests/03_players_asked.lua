-- What players of unit frames ran into, against Blizzard's real code: the game's target frame
-- set aside for a controller's menu, clicks with a key held, the ping key, a frame hidden by a
-- rule, the secure totem buttons. Each of these rests on how Blizzard's own Lua behaves, which
-- is what this simulator runs; tools/tests has the same things against sealed values. Opening
-- that menu itself is tools/sim/menu.sh, which has to run apart.
local ns = PugUnitFrames

if not PUGUF_SIM_CLOCK then -- the test files share one simulator, and its clock is switched over once
	A_Admin.SetManualClock(GetTime())
	PUGUF_SIM_CLOCK = true
end
local function Tick(seconds)
	A_Admin.AdvanceTime(seconds or 0.5)
end

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

local function PartyButton(index)
	return PugUnitFrames_party:GetAttribute("child" .. index)
end

test("the game's target frame is set aside: there with a target, unseen, beside ours", function()
	A_Admin.ClearTarget()
	Tick()
	assertFalse(TargetFrame:IsVisible())
	A_Admin.SetTarget("Hogger", 11, 1, true)
	Tick()
	-- Shown by Blizzard's unit watch, since its own events are gone.
	assertTrue(TargetFrame:IsVisible())
	assertFalse(TargetFrame:IsEventRegistered("PLAYER_TARGET_CHANGED"))
	assertTrue(TargetFrame:GetEffectiveScale() < 0.01)
	assertAlmostEquals(0, TargetFrame:GetEffectiveAlpha(), 0.001)
	local _, beside = TargetFrame:GetPoint(1)
	assertEquals(PugUnitFrames_target, beside)
	assertTrue(ns.Blizzard.IsKept("target"))
	A_Admin.ClearTarget()
	Tick()
	assertFalse(TargetFrame:IsVisible())
	NoProblems()
	NothingRefused()
end)

test("Blizzard's own lookup finds the target action for a plain click and the macro with a key held", function()
	for _, frame in ipairs({ PugUnitFrames_player, PugUnitFrames_focus, PartyButton(1) }) do
		assertEquals("target", SecureButton_GetModifiedAttribute(frame, "type", "LeftButton", ""))
		assertEquals("macro", SecureButton_GetModifiedAttribute(frame, "type", "LeftButton", "shift-"))
		assertEquals("macro", SecureButton_GetModifiedAttribute(frame, "type", "LeftButton", "alt-ctrl-"))
		assertEquals("/target [@mouseover,exists]", SecureButton_GetModifiedAttribute(frame, "macrotext", "LeftButton", "ctrl-"))
		assertEquals("togglemenu", SecureButton_GetModifiedAttribute(frame, "type", "RightButton", ""))
	end
end)

test("our frames answer the ping key as Blizzard's unit frames do", function()
	for _, frame in ipairs({ PugUnitFrames_player, PartyButton(1), PartyButton(4) }) do
		assertTrue(frame:GetAttribute("ping-receiver"))
		assertEquals(PingableType_UnitFrameMixin.GetTargetInfo, frame.GetTargetInfo)
		assertTrue(frame:GetIsPingable())
		assertTrue(frame:GetAllowRadialWheel())
		assertEquals(UnitGUID(frame.unit), frame:GetTargetInfo().guid)
	end
end)

test("the player's frame stays away in a group when asked, by Blizzard's state driver", function()
	local cfg = ns.db.units.player
	assertTrue(IsInGroup())
	cfg.hideInGroup = true
	ns.Refresh()
	Tick()
	assertFalse(PugUnitFrames_player:IsShown())
	cfg.hideInGroup = false
	ns.Refresh()
	Tick()
	assertTrue(PugUnitFrames_player:IsShown())
	NoProblems()
	NothingRefused()
end)

test("putting the party in order of roles loses nobody", function()
	local cfg = ns.db.units.party
	cfg.byRole = true
	ns.Refresh()
	Tick()
	local shown = 0
	for index = 1, 5 do
		local button = PartyButton(index)
		if button and button:IsShown() then
			shown = shown + 1
			assertEquals(button:GetAttribute("unit"), button.unit)
		end
	end
	assertEquals(4, shown)
	cfg.byRole = false
	ns.Refresh()
	Tick()
	NoProblems()
end)

test("a shaman's totem slots are Blizzard's secure buttons, set to send a totem away on a right click", function()
	A_Admin.SetPlayerClass(7)
	local _, class = UnitClass("player")
	assertEquals("SHAMAN", class)
	ns.Refresh()
	Tick()
	local totems = PugUnitFrames_player.totems
	assertNotNil(totems)
	for slot, click in ipairs(totems.clicks) do
		assertTrue((click:IsProtected()))
		assertEquals(SecureActionButton_OnClick, click:GetScript("OnClick"))
		assertEquals("destroytotem", SecureButton_GetModifiedAttribute(click, "type", "RightButton", ""))
		assertEquals("destroytotem", SecureButton_GetModifiedAttribute(click, "type", "RightButton", "shift-"))
		assertEquals(slot, SecureButton_GetModifiedAttribute(click, "totem-slot", "RightButton", ""))
		assertEquals(nil, SecureButton_GetModifiedAttribute(click, "type", "LeftButton", ""))
		assertFalse(click:IsMouseEnabled())
		-- What is seen is a frame of its own, exactly under what is clicked.
		local face = totems.buttons[slot]
		assertFalse((face:IsProtected()))
		assertAlmostEquals(0, face:GetAlpha(), 0.001)
		assertAlmostEquals(face:GetLeft(), click:GetLeft(), 0.01)
		assertAlmostEquals(face:GetTop(), click:GetTop(), 0.01)
	end
	-- A fight starts and ends, and nothing about the buttons is refused. (In the game the slots
	-- take the mouse as the fight is announced, a moment before the frames are locked. This
	-- simulator locks them first, so here they stay as they were: that half is tools/tests'.)
	A_Admin.SetInCombat(true)
	Tick()
	A_Admin.SetInCombat(false)
	Tick()
	assertFalse(totems.clicks[1]:IsMouseEnabled())
	A_Admin.SetPlayerClass(2)
	ns.Refresh()
	Tick()
	NoProblems()
	NothingRefused()
end)

test("the new parts draw on Blizzard's widgets without an error", function()
	local cfg = ns.db.units.player
	cfg.fill, cfg.invert, cfg.calm = "left", true, 0.4
	ns.db.alpha, ns.db.auraTimers = 0.8, true
	ns.Refresh()
	Tick()
	-- (The simulator's bars do not keep which way they fill, so that is not asked.)
	assertTrue(PugUnitFrames_player:GetAlpha() < 0.5)
	A_Admin.SetTarget("Hogger", 11, 1, true)
	Tick()
	assertAlmostEquals(0.8, PugUnitFrames_player:GetAlpha(), 0.001)
	assertAlmostEquals(0.8, PugUnitFrames_target:GetAlpha(), 0.001)
	cfg.fill = "up"
	ns.Refresh()
	Tick()
	assertEquals("VERTICAL", PugUnitFrames_player.health:GetOrientation())
	cfg.fill, cfg.invert, cfg.calm = "right", false, 1
	ns.db.alpha, ns.db.auraTimers = 1, false
	ns.Refresh()
	A_Admin.ClearTarget()
	Tick()
	NoProblems()
	NothingRefused()
end)
