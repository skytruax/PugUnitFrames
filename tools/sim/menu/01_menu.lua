-- The menu a controller opens on the target, against Blizzard's real code. Run by tools/sim/menu.sh.
--
-- Blizzard's controller mode has a button that opens the target's menu (inspect, trade, follow).
-- It does so as the menu of the game's own target frame: TargetFrame_OpenMenu(TargetFrame), in
-- Blizzard_GamepadActionBars. Blizzard's menu closes on its next update if the frame it belongs
-- to is not on screen. So an addon that hides that frame takes the menu away from everyone who
-- plays with a controller, which is why Pug Unit Frames sets it aside instead (Blizzard.lua).
-- This makes the same call and looks whether the menu is still open two updates later.
local ns = PugUnitFrames

A_Admin.SetManualClock(GetTime())

-- The simulator lacks a function that Blizzard's unit menu asks on its way; it is stood in for
-- here with the plainest answer.
C_VoiceChat = C_VoiceChat or {}
C_VoiceChat.CanPlayerUseVoiceChat = C_VoiceChat.CanPlayerUseVoiceChat or function() return false end

test("the menu a controller opens on the target stays open", function()
	A_Admin.SetTarget("Hogger", 11, 1, true)
	A_Admin.AdvanceTime(0.5)
	assertTrue(ns.Blizzard.IsKept("target"))
	assertTrue(TargetFrame:IsVisible())
	TargetFrame_OpenMenu(TargetFrame)
	assertTrue(Menu.GetManager():IsAnyMenuOpen())
	A_Admin.AdvanceTime(0.1)
	A_Admin.AdvanceTime(0.1)
	assertTrue(Menu.GetManager():IsAnyMenuOpen())
	Menu.GetManager():CloseMenus()
	local problems = {}
	for _, problem in ipairs(ns.GetProblems()) do
		problems[#problems + 1] = problem.text
	end
	assertEquals("", table.concat(problems, " | "))
end)

test("without a target there is no frame for it to belong to, and the controller's button does not ask", function()
	A_Admin.ClearTarget()
	A_Admin.AdvanceTime(0.5)
	assertFalse(TargetFrame:IsVisible())
	assertFalse(UnitExists("target"))
end)
