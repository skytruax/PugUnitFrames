-- What the frames draw, against Blizzard's real widgets: bars, words, cast bar, icons, handles.
-- The simulator does not seal values, so this shows the drawing code is sound on plain ones and
-- that every widget method it calls exists. Sealed values are tools/tests' business.
local ns = FreeUnitFrames

if not FREEUF_SIM_CLOCK then -- the test files share one simulator, and its clock is switched over once
	A_Admin.SetManualClock(GetTime())
	FREEUF_SIM_CLOCK = true
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
	return FreeUnitFrames_party:GetAttribute("child" .. index)
end

test("the player's bars and words follow the player's health", function()
	local frame = FreeUnitFrames_player
	A_Admin.SetPlayerHealth(250, 1000)
	Tick()
	local low, high = frame.health:GetMinMaxValues()
	assertEquals(0, low)
	assertEquals(1000, high)
	assertEquals(250, frame.health:GetValue())
	assertContains(frame.texts.health:GetText(), "25%")
	assertEquals(UnitName("player"), frame.texts.name:GetText())
	A_Admin.SetPlayerHealth(1000, 1000)
	Tick()
	assertEquals(1000, frame.health:GetValue())
	NoProblems()
end)

test("every way of writing health produces text", function()
	local frame, cfg = FreeUnitFrames_player, ns.db.units.player
	local before = cfg.healthText
	A_Admin.SetPlayerHealth(4321, 5000)
	Tick()
	-- The simulator's number formatting is plainer than the game's (no thousands separator, no
	-- "4.3K"), so only what does not depend on it is checked.
	local expected = { percent = "86%", both = "86%", max = "/", deficit = "679" }
	for _, style in ipairs(ns.Defaults.UNIT_SPEC.healthText.choices) do
		cfg.healthText = style
		ns.Refresh()
		local text = frame.texts.health:GetText() or ""
		if style == "none" then
			assertFalse(frame.texts.health:IsShown())
		else
			assertTrue(#text > 0)
			if expected[style] then
				assertContains(text, expected[style])
			end
			if style == "value" then
				assertEquals("4321", (text:gsub("%D", "")))
			end
		end
	end
	cfg.healthText = before
	A_Admin.SetPlayerHealth(1000, 1000)
	ns.Refresh()
	NoProblems()
end)

test("the cast bar comes up for a cast and goes away after it", function()
	local cast = FreeUnitFrames_player.cast
	assertNotNil(cast)
	assertFalse(cast:IsShown())
	-- The simulator starts and stops a cast without announcing it; the game sends these events.
	A_Admin.SetCasting(133, "Fireball", "Interface\\Icons\\Spell_Fire_FlameBolt", 2.5)
	A_Admin.FireEvent("UNIT_SPELLCAST_START", "player")
	assertTrue(cast:IsShown())
	assertEquals("Fireball", cast.text:GetText())
	A_Admin.StopCasting()
	A_Admin.FireEvent("UNIT_SPELLCAST_STOP", "player")
	assertFalse(cast:IsShown())
	NoProblems()
end)

test("an interrupted cast stays up for a moment, then goes", function()
	local cast = FreeUnitFrames_player.cast
	A_Admin.SetCasting(133, "Fireball", "Interface\\Icons\\Spell_Fire_FlameBolt", 2.5)
	A_Admin.FireEvent("UNIT_SPELLCAST_START", "player")
	A_Admin.StopCasting()
	A_Admin.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
	A_Admin.FireEvent("UNIT_SPELLCAST_STOP", "player")
	assertTrue(cast:IsShown())
	assertEquals(ns.L["Interrupted"], cast.text:GetText())
	Tick(1)
	assertFalse(cast:IsShown())
	NoProblems()
end)

test("the game's own cast bar stays away while ours is in use", function()
	assertFalse(PlayerCastingBarFrame:IsVisible())
	A_Admin.SetCasting(133, "Fireball", "Interface\\Icons\\Spell_Fire_FlameBolt", 2.5)
	A_Admin.FireEvent("UNIT_SPELLCAST_START", "player")
	assertFalse(PlayerCastingBarFrame:IsVisible())
	A_Admin.StopCasting()
	A_Admin.FireEvent("UNIT_SPELLCAST_STOP", "player")
end)

test("a target gets its buffs drawn as icons with a tooltip", function()
	A_Admin.SetTarget("Hogger", 11, 1, true)
	Tick()
	local frame = FreeUnitFrames_target
	assertTrue(frame:IsShown())
	local ids = C_UnitAuras.GetUnitAuraInstanceIDs("target", "HELPFUL", 9)
	local shown = 0
	for _, icon in ipairs(frame.auras.icons) do
		if icon:IsShown() then
			shown = shown + 1
			assertNotNil(icon.auraInstanceID)
			icon:GetScript("OnEnter")(icon)
			icon:GetScript("OnLeave")(icon)
		end
	end
	assertEquals(#ids + #C_UnitAuras.GetUnitAuraInstanceIDs("target", "HARMFUL", 18), shown)
	A_Admin.ClearTarget()
	Tick()
	NoProblems()
end)

test("a dead party member is shown as dead with an empty bar", function()
	local button = PartyButton(1)
	assertNotNil(button)
	A_Admin.KillPartyMember(1)
	Tick()
	assertTrue(UnitIsDeadOrGhost("party1"))
	assertEquals(0, button.health:GetValue())
	assertContains({ ns.L["Dead"], ns.L["Ghost"] }, button.texts.health:GetText())
	A_Admin.ResPartyMember(1)
	Tick()
	NoProblems()
end)

test("a party member who goes offline is shown as offline", function()
	local button = PartyButton(2)
	A_Admin.SetPartyMemberConnected(2, false)
	Tick()
	assertEquals(ns.L["Offline"], button.texts.health:GetText())
	A_Admin.SetPartyMemberConnected(2, true)
	Tick()
	assertNotEquals(ns.L["Offline"], button.texts.health:GetText())
	NoProblems()
end)

test("unlocking shows a handle on every frame, and a dropped handle moves its frame", function()
	SlashCmdList.FREEUNITFRAMES("unlock")
	assertFalse(ns.db.locked)
	local cfg = ns.db.units.focus
	local x, y = cfg.x, cfg.y
	-- What a drag does: the handle ends up somewhere else, then it is let go.
	local point, _, _, width, height = ns.Movers.Footprint("focus")
	assertEquals("CENTER", point)
	assertAlmostEquals(cfg.width * cfg.scale, width, 0.01)
	assertAlmostEquals(cfg.height * cfg.scale, height, 0.01)
	cfg.x, cfg.y = x + 40, y - 25
	ns.Refresh()
	local frameX, frameY = FreeUnitFrames_focus:GetCenter()
	local middleX, middleY = UIParent:GetCenter()
	assertAlmostEquals(x + 40, frameX - middleX, 0.5)
	assertAlmostEquals(y - 25, frameY - middleY, 0.5)
	cfg.x, cfg.y = x, y
	ns.Refresh()
	SlashCmdList.FREEUNITFRAMES("lock")
	assertTrue(ns.db.locked)
	NoProblems()
end)

test("every slash command runs", function()
	for _, command in ipairs({ "status", "help", "reset focus", "reset nonsense", "profile", "lock" }) do
		SlashCmdList.FREEUNITFRAMES(command)
	end
	FreeUnitFramesProfileWindow:Hide()
	NoProblems()
end)

test("the frames page builds and shows the controls of each kind of frame", function()
	Settings.OpenToCategory(ns.Options.framesCategory:GetID())
	NoProblems()
end)

test("profiles can be copied, switched and deleted", function()
	local first = ns.profileName
	local copy = ns.Profiles.Copy()
	assertNotEquals(first, copy)
	assertEquals(copy, ns.profileName)
	ns.db.units.player.width = ns.db.units.player.width + 30
	ns.Refresh()
	assertTrue(ns.Profiles.Switch(first))
	assertAlmostEquals(ns.db.units.player.width, FreeUnitFrames_player:GetWidth(), 0.01)
	assertTrue(ns.Profiles.Switch(copy))
	assertTrue(ns.Profiles.DeleteCurrent())
	assertEquals(first, ns.profileName)
	assertFalse(ns.Profiles.DeleteCurrent()) -- the last one stays
	NoProblems()
end)

test("every theme and bar texture can be put on", function()
	local theme, texture = ns.db.theme, ns.db.texture
	for _, name in ipairs(ns.Style.THEME_ORDER) do
		ns.db.theme = name
		for _, fill in ipairs(ns.Style.TEXTURE_ORDER) do
			ns.db.texture = fill
			ns.Refresh()
		end
	end
	ns.db.theme, ns.db.texture = theme, texture
	ns.Refresh()
	NoProblems()
end)

test("switching every optional part on and off leaves no error", function()
	local kinds = ns.Defaults.KINDS
	for _, kind in ipairs(kinds) do
		local cfg = ns.db.units[kind]
		local saved = CopyTable(cfg)
		for key, spec in pairs(ns.Defaults.UNIT_SPEC) do
			if cfg[key] ~= nil and key ~= "enabled" then
				if spec.type == "bool" then
					cfg[key] = not cfg[key]
				elseif spec.type == "choice" then
					cfg[key] = spec.choices[#spec.choices]
				elseif key == "buffs" or key == "debuffs" then
					cfg[key] = 6
				end
			end
		end
		ns.Refresh()
		Tick(0.1)
		ns.db.units[kind] = saved
		ns.Refresh()
	end
	NoProblems()
end)
