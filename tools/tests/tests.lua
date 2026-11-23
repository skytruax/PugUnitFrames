-- Scenarios for Free Unit Frames, run by tools/tests/run.py against wowmock.lua.
-- Each runs in a fresh Lua state: the stand-in for the client, then the addon, then the scenario.
--
-- The stand-in seals what the client seals. A value that arrives on a widget sealed is opened
-- with Value() to check that the right one arrived; the addon itself never could.
TESTS = {}
local function Test(name, fn)
	TESTS[#TESTS + 1] = { name = name, fn = fn }
end

local M = Mock
local Value, IsSealed = M.Unseal, M.IsSealed

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function Equal(expected, actual, what)
	if expected ~= actual then
		error(("%s: expected %s, got %s"):format(what or "value", tostring(expected), tostring(actual)), 2)
	end
end

local function Near(expected, actual, what)
	if type(actual) ~= "number" or math.abs(expected - actual) > 0.001 then
		error(("%s: expected %s, got %s"):format(what or "value", tostring(expected), tostring(actual)), 2)
	end
end

local function True(value, what)
	if not value then
		error((what or "value") .. ": expected something true, got " .. tostring(value), 2)
	end
end

local function False(value, what)
	if value then
		error((what or "value") .. ": expected nothing true, got " .. tostring(value), 2)
	end
end

local function Sealed(value, what)
	if not IsSealed(value) then
		error((what or "value") .. ": expected a sealed value, got " .. tostring(value), 2)
	end
end

local function PlainValue(value, what)
	if IsSealed(value) then
		error((what or "value") .. ": expected a plain value, got a sealed one", 2)
	end
end

local function Printed(fragment)
	for _, line in ipairs(M.printed) do
		if line:find(fragment, 1, true) then
			return true
		end
	end
	return false
end

local function LoadAddon()
	local ns = {}
	for _, path in ipairs(ADDON_LUA_FILES) do
		local chunk = assert(loadstring(ReadFile(path), "@" .. path))
		chunk("FreeUnitFrames", ns)
	end
	return ns
end

local function Player(class, extra)
	local fields = {
		name = "Uther", class = class or "PALADIN", level = 60, isPlayer = true, playerControlled = true,
		health = 4000, healthMax = 5000, power = 3000, powerMax = 4000, reaction = 5,
	}
	for key, value in pairs(extra or {}) do
		fields[key] = value
	end
	return M.SetUnit("player", fields)
end

-- Sets a player up, loads the addon and goes through the game's login events.
local function Login(class)
	if not M.units.player then
		Player(class)
	end
	local ns = LoadAddon()
	M.Fire("ADDON_LOADED", "FreeUnitFrames")
	M.Fire("PLAYER_LOGIN")
	M.Fire("PLAYER_ENTERING_WORLD")
	M.UpdateUnitWatch()
	return ns
end

local function Friend(index, extra)
	local classes = { "WARRIOR", "PRIEST", "MAGE", "DRUID" }
	local fields = {
		name = "Friend" .. index, class = classes[(index - 1) % #classes + 1], level = 60, isPlayer = true,
		playerControlled = true, inGroup = true, reaction = 5, health = 2000, healthMax = 2500,
	}
	for key, value in pairs(extra or {}) do
		fields[key] = value
	end
	return fields
end

-- Puts the player in a party with `count` others.
local function Party(count)
	M.raidSize = 0
	M.partySize = count
	for index = 1, 4 do
		M.SetUnit("party" .. index, index <= count and Friend(index) or nil)
	end
	M.RosterChanged()
end

local function Raid(count)
	M.partySize = 0
	M.raidSize = count
	for index = 1, 40 do
		M.SetUnit("raid" .. index, index <= count and Friend(index) or nil)
	end
	M.RosterChanged()
end

local function Target(fields)
	M.SetUnit("target", fields)
	M.Fire("PLAYER_TARGET_CHANGED")
	M.UpdateUnitWatch()
end

local HOGGER = { name = "Hogger", class = "WARRIOR", level = 11, health = 300, healthMax = 600, reaction = 2, canAttack = true, classification = "elite" }

local function PartyButton(ns, index)
	return ns.Group.Get("party"):GetAttribute("child" .. index)
end

local function ShownIcons(frame)
	local shown = {}
	for _, icon in ipairs(frame.auras.icons) do
		if icon:IsShown() then
			shown[#shown + 1] = icon
		end
	end
	return shown
end

---------------------------------------------------------------------------
-- Login and the frames themselves
---------------------------------------------------------------------------
Test("login builds a secure unit button for each single unit", function()
	local ns = Login()
	True(ns.IsBuilt(), "built")
	for _, kind in ipairs({ "player", "target", "targettarget", "focus", "pet" }) do
		local frame = _G["FreeUnitFrames_" .. kind]
		True(frame, kind .. " frame")
		True(frame:IsProtected(), kind .. " is protected")
		Equal(kind, frame:GetAttribute("unit"), kind .. " unit")
		Equal("target", frame:GetAttribute("*type1"), "a click targets")
		Equal("togglemenu", frame:GetAttribute("*type2"), "a right click opens the menu")
		Equal(SecureUnitButton_OnClick, frame:GetScript("OnClick"), "the secure click handler is still there")
		True(ClickCastFrames[frame], kind .. " is offered to click-casting addons")
	end
	True(FreeUnitFrames_player:IsShown(), "the player's frame is up")
	False(FreeUnitFrames_target:IsShown(), "no target, no target frame")
	False(FreeUnitFrames_pet:IsShown(), "no pet, no pet frame")
	Equal(0, #ns.GetProblems(), "problems")
	Equal(0, #M.blocked, "refused calls")
end)

Test("a frame is placed from the middle of the screen, in screen units whatever its scale", function()
	local ns = Login()
	local cfg = ns.db.units.player
	local anchor = FreeUnitFrames_player.anchors[1]
	Equal("CENTER", anchor[1])
	Equal(UIParent, anchor[2])
	Equal(cfg.x, anchor[4])
	Equal(cfg.y, anchor[5])
	cfg.scale = 2
	ns.Refresh()
	anchor = FreeUnitFrames_player.anchors[1]
	Near(cfg.x / 2, anchor[4], "x at double scale")
	Near(cfg.y / 2, anchor[5], "y at double scale")
	Near(2, FreeUnitFrames_player:GetScale(), "scale")
end)

Test("a frame comes and goes with its unit, and a disabled one stays away", function()
	local ns = Login()
	Target(HOGGER)
	True(FreeUnitFrames_target:IsShown(), "target frame with a target")
	Target(nil)
	False(FreeUnitFrames_target:IsShown(), "target frame without one")

	ns.db.units.target.enabled = false
	ns.Refresh()
	Target(HOGGER)
	False(FreeUnitFrames_target:IsShown(), "a disabled frame stays hidden")
	ns.db.units.target.enabled = true
	ns.Refresh()
	True(FreeUnitFrames_target:IsShown(), "enabled again")
end)

---------------------------------------------------------------------------
-- Health, power and the words
---------------------------------------------------------------------------
Test("the player's health reaches the bar sealed, and is never opened on the way", function()
	Login()
	local bar = FreeUnitFrames_player.health
	Sealed(bar.value, "health")
	Equal(4000, Value(bar.value), "health")
	-- A player's own maximum health is one of the things the game does not seal.
	PlainValue(bar.high, "maximum health of a player")
	Equal(5000, bar.high, "maximum health")
	Equal(0, bar.low)
end)

Test("health text is written by the game from the sealed numbers, in every style", function()
	local ns = Login()
	local cfg, text = ns.db.units.player, FreeUnitFrames_player.texts.health
	local expected = { value = "4,000", short = "4,000", percent = "80%", both = "4,000  80%", max = "4,000 / 5,000", deficit = "1000" }
	for style, written in pairs(expected) do
		cfg.healthText = style
		ns.Refresh()
		Sealed(text.text, style .. " text")
		Equal(written, Value(text.text), style)
	end
	cfg.healthText = "none"
	ns.Refresh()
	False(text:IsShown(), "no health text when switched off")

	cfg.healthText = "deficit"
	M.units.player.health = 5000
	ns.Refresh()
	Equal("", Value(text.text), "nothing is missing at full health")

	-- Long numbers: the exact style keeps every digit, the short one is the game's own short form.
	M.units.player.health, M.units.player.healthMax = 1234567, 2000000
	cfg.healthText = "value"
	ns.Refresh()
	Equal("1,234,567", Value(text.text))
	cfg.healthText = "short"
	ns.Refresh()
	Equal("1234K", Value(text.text))
end)

Test("a health change redraws the bar and the text", function()
	Login()
	M.units.player.health = 1000
	M.Fire("UNIT_HEALTH", "player")
	Equal(1000, Value(FreeUnitFrames_player.health.value), "bar")
	Equal("1,000  20%", Value(FreeUnitFrames_player.texts.health.text), "text")
	Equal(Enum.StatusBarInterpolation.ExponentialEaseOut, FreeUnitFrames_player.health.interpolation, "a change of the same unit glides")
end)

Test("a creature's name and maximum health are sealed and still shown", function()
	Login()
	Target(HOGGER)
	local frame = FreeUnitFrames_target
	Sealed(frame.texts.name.text, "a creature's name")
	Equal("Hogger", Value(frame.texts.name.text))
	Sealed(frame.health.high, "a creature's maximum health")
	Equal(600, Value(frame.health.high))
	Equal(300, Value(frame.health.value))
	Equal("11+", frame.texts.level.text, "level of an elite")
	Equal(Enum.StatusBarInterpolation.Immediate, frame.health.interpolation, "a new target's bar jumps, it does not glide")
end)

Test("a creature is coloured by how it stands to the player, a player by class", function()
	local ns = Login()
	local tone = ns.Style.theme.tone
	Target(HOGGER)
	local hostile = ns.Style.REACTION.hostile
	Near(hostile[1] * tone, FreeUnitFrames_target.health.barColor[1], "hostile red")

	Target({ name = "Jaina", class = "MAGE", isPlayer = true, playerControlled = true, reaction = 5, health = 10, healthMax = 10 })
	local mage = M.CLASS_COLORS.MAGE
	Near(mage[1] * tone, FreeUnitFrames_target.health.barColor[1], "mage red part")
	Near(mage[3] * tone, FreeUnitFrames_target.health.barColor[3], "mage blue part")

	Target({ name = "Wolf", tapped = true, reaction = 2, canAttack = true })
	Near(ns.Style.REACTION.tapped[1] * tone, FreeUnitFrames_target.health.barColor[1], "someone else's kill is grey")
end)

Test("a class the game seals still colours the bar, untouched", function()
	Login()
	-- Contrived: a "player" the game does not treat as player-controlled, so its class is sealed.
	Target({ name = "Echo", class = "DRUID", isPlayer = true, playerControlled = false, inGroup = false, reaction = 4 })
	local color = FreeUnitFrames_target.health.barColor
	Sealed(color[1], "a sealed class gives sealed colour numbers")
	Near(M.CLASS_COLORS.DRUID[1], Value(color[1]), "they are handed on as they came, not toned")
end)

Test("colouring by health goes through a curve inside the game", function()
	local ns = Login()
	ns.db.units.player.color = "health"
	ns.Refresh()
	local color = FreeUnitFrames_player.health.barColor
	Sealed(color[1], "red part")
	Sealed(color[2], "green part")
	-- 80% lies between the amber point at 55% and the green one at 100%.
	True(Value(color[1]) < 0.88 and Value(color[1]) > 0.36, "between amber and green")
	M.units.player.health = 100
	M.Fire("UNIT_HEALTH", "player")
	True(Value(FreeUnitFrames_player.health.barColor[1]) > 0.8, "nearly empty is red")
end)

Test("power reaches its bar sealed, coloured by its kind", function()
	local ns = Login()
	local bar = FreeUnitFrames_player.power
	Sealed(bar.value, "mana")
	Equal(3000, Value(bar.value))
	Equal(4000, Value(bar.high))
	local r, g, b = ns.Style.PowerColor("MANA")
	Near(b, bar.barColor[3], "mana is blue")
	Equal("3,000", Value(FreeUnitFrames_player.texts.power.text), "power text")

	M.units.player.powerType, M.units.player.powerToken, M.units.player.power, M.units.player.powerMax = 1, "RAGE", 40, 100
	M.Fire("UNIT_DISPLAYPOWER", "player")
	local rr = ns.Style.PowerColor("RAGE")
	Near(rr, bar.barColor[1], "rage is red")
	Equal(40, Value(bar.value))
end)

Test("a frame with no power bar has none, and gets one when asked", function()
	local ns = Login()
	ns.db.units.player.powerHeight = 0
	ns.Refresh()
	False(FreeUnitFrames_player.power:IsShown(), "power bar")
	False(FreeUnitFrames_player.active.Power, "power element")
	ns.db.units.player.powerHeight = 8
	ns.Refresh()
	True(FreeUnitFrames_player.power:IsShown(), "power bar back")
end)

Test("dead, ghost and offline are said in words, with an empty bar", function()
	local ns = Login()
	Party(2)
	local button = PartyButton(ns, 1)
	M.units.party1.dead = true
	M.Fire("UNIT_HEALTH", "party1")
	Equal(ns.L["Dead"], button.texts.health.text)
	Equal(0, button.health.value, "a dead member's bar is empty")
	Equal(1, button.health.high)

	M.units.party1.dead, M.units.party1.ghost = false, true
	M.Fire("UNIT_HEALTH", "party1")
	Equal(ns.L["Ghost"], button.texts.health.text)

	M.units.party1.ghost, M.units.party1.connected = false, false
	M.Fire("UNIT_CONNECTION", "party1")
	Equal(ns.L["Offline"], button.texts.health.text)
	Equal(0, button.power.value, "an offline member's power bar is empty")

	M.units.party1.connected = true
	M.Fire("UNIT_CONNECTION", "party1")
	Equal("80%", Value(button.texts.health.text), "back to the number")
end)

Test("healing on its way is drawn past the end of the health bar", function()
	Login()
	local heal = FreeUnitFrames_player.health.heal
	Equal(0, heal.value, "nothing coming")
	M.units.player.incomingHeals = 700
	M.Fire("UNIT_HEAL_PREDICTION", "player")
	Sealed(heal.value, "the heal's size")
	Equal(700, Value(heal.value))
	Equal(5000, heal.high, "on the health bar's scale")
end)

---------------------------------------------------------------------------
-- Threat, range, marks
---------------------------------------------------------------------------
Test("threat fills the outlines up to its level, sealed or not", function()
	Login()
	local bars = FreeUnitFrames_player.threat.bars
	for level, bar in ipairs(bars) do
		Equal(level - 1, bar.low, "outline " .. level .. " starts at")
		Equal(level, bar.high, "outline " .. level .. " is full at")
		Equal(0, bar.value, "no threat")
	end
	M.units.player.threat = 2
	M.Fire("UNIT_THREAT_SITUATION_UPDATE", "player")
	for _, bar in ipairs(bars) do
		Equal(2, bar.value)
	end
	M.sealThreat = true
	M.units.player.threat = 3
	M.Fire("UNIT_THREAT_SITUATION_UPDATE", "player")
	for _, bar in ipairs(bars) do
		Sealed(bar.value, "a sealed threat level")
		Equal(3, Value(bar.value))
	end
end)

Test("a party member out of range fades, from two sealed answers", function()
	local ns = Login()
	Party(2)
	local button = PartyButton(ns, 1)
	Sealed(button.body.alpha, "the alpha comes out of sealed booleans")
	Equal(1, Value(button.body.alpha), "in range")
	M.units.party1.inRange = false
	-- The event's own payload is sealed too, and is not looked at.
	M.Fire("UNIT_IN_RANGE_UPDATE", "party1", M.Seal(false))
	Near(ns.db.farAlpha, Value(button.body.alpha), "out of range")
	M.units.party1.rangeChecked = false
	M.Fire("UNIT_IN_RANGE_UPDATE", "party1", M.Seal(false))
	Equal(1, Value(button.body.alpha), "a range that could not be checked counts as near")
	Equal(nil, FreeUnitFrames_player.body.alpha, "the player's own frame does not fade")
end)

Test("a raid mark is one cell of the game's sheet, chosen by a sealed number", function()
	Login()
	local mark = FreeUnitFrames_player.marks.raid
	False(mark:IsShown(), "no mark")
	M.units.player.raidMark = 8
	M.Fire("RAID_TARGET_UPDATE")
	True(mark:IsShown(), "skull")
	Sealed(mark.cell, "which mark")
	Equal(8, Value(mark.cell))
	M.units.player.raidMark = nil
	M.Fire("RAID_TARGET_UPDATE")
	False(mark:IsShown(), "mark taken off")
end)

Test("leader, combat and resting marks follow the game", function()
	local ns = Login()
	local marks = FreeUnitFrames_player.marks
	Equal(0, marks.leader.alpha, "not the leader")
	M.units.player.leader = true
	M.Fire("PARTY_LEADER_CHANGED")
	Equal(1, marks.leader.alpha, "leader")

	False(marks.state:IsShown(), "neither resting nor fighting")
	M.resting = true
	M.Fire("PLAYER_UPDATE_RESTING")
	True(marks.state:IsShown(), "resting")
	Equal(ns.ART .. "Mark-Rest", marks.state.texture)
	M.units.player.combat = true
	M.Fire("UNIT_FLAGS", "player")
	Equal(ns.ART .. "Mark-Combat", marks.state.texture, "combat outranks resting")
end)

Test("a ready check shows each answer, and a resurrection on its way shows too", function()
	local ns = Login()
	Party(2)
	local center = PartyButton(ns, 1).marks.center
	False(center:IsShown())
	M.readyCheck.party1 = "waiting"
	M.Fire("READY_CHECK")
	Equal(ns.ART .. "Mark-Waiting", center.texture)
	M.readyCheck.party1 = "ready"
	M.Fire("READY_CHECK_CONFIRM")
	Equal(ns.ART .. "Mark-Ready", center.texture)
	M.Fire("READY_CHECK_FINISHED")
	True(center:IsShown(), "the answer lingers")
	M.readyCheck.party1 = nil
	M.Advance(7)
	False(center:IsShown(), "and goes once the game has forgotten it")

	M.units.party1.resurrecting = true
	M.Fire("INCOMING_RESURRECT_CHANGED", "party1")
	Equal(ns.ART .. "Mark-Resurrect", center.texture)
end)

---------------------------------------------------------------------------
-- Casting
---------------------------------------------------------------------------
local function Cast(token, fields)
	M.units[token].cast = fields
	M.Fire(fields and (fields.channel and "UNIT_SPELLCAST_CHANNEL_START" or "UNIT_SPELLCAST_START") or "UNIT_SPELLCAST_STOP", token)
end

Test("another unit's cast is sealed and still drawn: timer, name, icon, shield", function()
	Login()
	Target(HOGGER)
	local cast = FreeUnitFrames_target.cast
	False(cast:IsShown(), "no cast")
	Cast("target", { name = "Fireball", icon = 135812, start = M.now, length = 2.5, id = 7 })
	True(cast:IsShown(), "cast bar")
	Sealed(cast.text.text, "the spell's name")
	Equal("Fireball", Value(cast.text.text))
	Equal(135812, Value(cast.icon.texture), "icon")
	Equal(2.5, M.SpanOf(cast.bar.timer.duration).length, "the timer the game runs")
	Equal(Enum.StatusBarTimerDirection.ElapsedTime, cast.bar.timer.direction, "a cast fills")
	Sealed(cast.shield.alpha, "whether it can be interrupted")
	Equal(0, Value(cast.shield.alpha), "it can")
	Equal(7, cast.id, "the cast's id is never sealed")

	Cast("target", { name = "Shadow Bolt", icon = 1, start = M.now, length = 3, id = 8, shielded = true })
	Equal(1, Value(cast.shield.alpha), "this one cannot")
	Cast("target", nil)
	False(cast:IsShown(), "cast over")
end)

Test("a channel drains instead of filling, and the player's own cast is not sealed", function()
	Login()
	Cast("player", { name = "Blizzard", icon = 2, start = M.now, length = 8, id = 3, channel = true })
	local cast = FreeUnitFrames_player.cast
	True(cast:IsShown())
	Equal(Enum.StatusBarTimerDirection.RemainingTime, cast.bar.timer.direction, "a channel drains")
	PlainValue(cast.text.text, "the player's own spell")
	Equal("Blizzard", cast.text.text)
	M.units.player.cast = nil
	M.Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
	False(cast:IsShown())
end)

Test("an interrupted cast stays up a moment in red, then goes, unless a new cast began", function()
	local ns = Login()
	local cast = FreeUnitFrames_player.cast
	Cast("player", { name = "Heal", icon = 3, start = M.now, length = 2, id = 4 })
	M.units.player.cast = nil
	M.Fire("UNIT_SPELLCAST_INTERRUPTED", "player")
	M.Fire("UNIT_SPELLCAST_STOP", "player")
	True(cast:IsShown(), "held")
	Equal(ns.L["Interrupted"], cast.text.text)
	Equal(1, cast.bar.value, "full")
	M.Advance(1)
	False(cast:IsShown(), "gone after the hold")

	Cast("player", { name = "Heal", icon = 3, start = M.now, length = 2, id = 5 })
	M.units.player.cast = nil
	M.Fire("UNIT_SPELLCAST_INTERRUPTED", "player")
	Cast("player", { name = "Smite", icon = 4, start = M.now, length = 2, id = 6 })
	Equal("Smite", cast.text.text, "the new cast takes over at once")
	M.Advance(1)
	True(cast:IsShown(), "and the old hold does not put it away")
end)

Test("a new target that is casting shows its cast at once", function()
	Login()
	local caster = CopyTable(HOGGER)
	caster.cast = { name = "Net", icon = 5, start = M.now, length = 1.5, id = 9 }
	Target(caster)
	True(FreeUnitFrames_target.cast:IsShown())
	Target(HOGGER)
	False(FreeUnitFrames_target.cast:IsShown(), "and one that is not, does not")
end)

---------------------------------------------------------------------------
-- Auras
---------------------------------------------------------------------------
local function WithAuras(fields, auras)
	local unit = CopyTable(fields)
	unit.auras = auras
	return unit
end

local AURAS = {
	{ id = 11, icon = 111, helpful = false, kind = 1, stacks = 0, length = 12 },              -- magic
	{ id = 12, icon = 112, helpful = false, kind = 4, stacks = 3, length = 8, mine = true }, -- poison, mine
	{ id = 13, icon = 113, helpful = false, kind = 0, length = 0 },
	{ id = 21, icon = 121, helpful = true, stacks = 0, length = 60 },
	{ id = 22, icon = 122, helpful = true, stacks = 5, length = 0 },
}

Test("in combat the auras are sealed and still drawn: icon, stacks, time, kind", function()
	local ns = Login()
	M.SetCombat(true)
	Target(WithAuras(HOGGER, AURAS))
	local frame = FreeUnitFrames_target
	local icons = ShownIcons(frame)
	Equal(5, #icons, "icons")

	local poison = icons[2]
	Equal(12, poison.auraInstanceID, "debuffs come first, in the game's order")
	Sealed(poison.icon.texture, "the icon")
	Equal(112, Value(poison.icon.texture))
	Sealed(poison.count.text, "the stack count")
	Equal("3", Value(poison.count.text))
	Equal(8, M.SpanOf(poison.cooldown.duration).length, "the sweep")
	local curve = ns.Style.debuffKindCurve
	Sealed(poison.edge.vertex[1], "the rim's colour")
	Near(0.27, Value(poison.edge.vertex[1]), "poison is green: red part")
	Near(0.78, Value(poison.edge.vertex[2]), "poison is green: green part")
	Equal("", Value(icons[1].count.text), "one stack shows no number")

	-- Buffs start on a fresh row: the three debuffs took slots 0-2 of a row of nine.
	local perRow, step = ns.db.units.target.auraPerRow, ns.db.units.target.auraSize + 2
	Equal(0, icons[4].anchors[1][4], "the first buff is at the start of its row")
	True(icons[4].anchors[1][5] > icons[1].anchors[1][5], "which is the next row up")
	Equal(2 * step, icons[3].anchors[1][4], "the third debuff is third in its row")
	Equal(0, #ns.GetProblems(), "problems")
end)

Test("out of combat the same auras arrive plain and are drawn the same way", function()
	Login()
	Target(WithAuras(HOGGER, AURAS))
	local icons = ShownIcons(FreeUnitFrames_target)
	Equal(5, #icons)
	PlainValue(icons[2].icon.texture)
	Equal(112, icons[2].icon.texture)
	Equal("3", icons[2].count.text)
end)

Test("only-mine shows just the player's debuffs, and the limits are kept", function()
	local ns = Login()
	local cfg = ns.db.units.target
	cfg.myDebuffs, cfg.buffs = true, 1
	ns.Refresh()
	Target(WithAuras(HOGGER, AURAS))
	local icons = ShownIcons(FreeUnitFrames_target)
	Equal(2, #icons, "one debuff of mine, one buff")
	Equal(12, icons[1].auraInstanceID)
	Equal(21, icons[2].auraInstanceID)
end)

Test("aura changes are drawn once, on the next screen update, however many arrive", function()
	Login()
	local unit = WithAuras(HOGGER, AURAS)
	Target(unit)
	table.remove(unit.auras, 1)
	M.Fire("UNIT_AURA", "target")
	M.Fire("UNIT_AURA", "target")
	Equal(5, #ShownIcons(FreeUnitFrames_target), "not redrawn yet")
	M.Advance(0)
	Equal(4, #ShownIcons(FreeUnitFrames_target), "redrawn on the next update")
	M.units.target.auras = {}
	M.Fire("UNIT_AURA", "target")
	M.Advance(0)
	Equal(0, #ShownIcons(FreeUnitFrames_target), "all gone")
end)

Test("an aura icon shows the game's tooltip for it", function()
	Login()
	Target(WithAuras(HOGGER, AURAS))
	local icon = ShownIcons(FreeUnitFrames_target)[1]
	icon:GetScript("OnEnter")(icon)
	Equal("target", M.tooltip.unit)
	Equal(11, M.tooltip.aura)
	icon:GetScript("OnLeave")(icon)
	Equal(nil, M.tooltip.aura)
end)

Test("a party frame lights up in the colour of a debuff the player can remove", function()
	local ns = Login()
	Party(2)
	local button = PartyButton(ns, 1)
	local light = button.auras.light
	False(light[1]:IsShown(), "nothing to remove")
	M.SetCombat(true)
	M.units.party1.auras = {
		{ id = 31, icon = 1, helpful = false, kind = 2 },                  -- a curse the player cannot remove
		{ id = 32, icon = 2, helpful = false, kind = 3, removable = true }, -- a disease the player can
	}
	M.Fire("UNIT_AURA", "party1")
	M.Advance(0)
	True(light[1]:IsShown(), "lit")
	Sealed(light[1].vertex[1], "in a sealed colour")
	Near(0.72, Value(light[1].vertex[1]), "the disease's, not the curse's")
	Near(0.52, Value(light[4].vertex[2]), "on all four sides")
	M.units.party1.auras = { { id = 31, icon = 1, helpful = false, kind = 2 } }
	M.Fire("UNIT_AURA", "party1")
	M.Advance(0)
	False(light[1]:IsShown(), "out again")
end)

Test("icons on a raid frame let the mouse through, icons beside a frame do not", function()
	local ns = Login()
	Raid(3)
	local button = ns.Group.Get("raid"):GetAttribute("child1")
	M.units.raid1.auras = { { id = 41, icon = 1, helpful = false } }
	M.Fire("UNIT_AURA", "raid1")
	M.Advance(0)
	local icon = ShownIcons(button)[1]
	True(icon, "a debuff on the raid frame")
	False(icon.mouse, "a click there still picks the member")
	Target(WithAuras(HOGGER, AURAS))
	True(ShownIcons(FreeUnitFrames_target)[1].mouse, "an icon beside a frame has its tooltip")
end)

---------------------------------------------------------------------------
-- Class pieces
---------------------------------------------------------------------------
Test("a rogue's combo points fill the pips from a sealed count", function()
	Login("ROGUE")
	Target(HOGGER)
	local bars = FreeUnitFrames_target.points.bars
	Equal(5, #bars)
	M.comboPoints = 3
	M.Fire("UNIT_POWER_UPDATE", "player")
	for index, bar in ipairs(bars) do
		Equal(index - 1, bar.low)
		Equal(index, bar.high)
		Sealed(bar.value, "the count")
		Equal(3, Value(bar.value))
	end
	Equal(nil, FreeUnitFrames_player.points, "only the target frame has them")
end)

Test("a class without combo points has no pips", function()
	Login("PALADIN")
	Target(HOGGER)
	Equal(nil, FreeUnitFrames_target.points)
	Equal(nil, FreeUnitFrames_player.totems, "and a class without totems has none")
end)

Test("a shaman's totems show while they stand, also when the game seals them", function()
	Login("SHAMAN")
	local buttons = FreeUnitFrames_player.totems.buttons
	Equal(4, #buttons)
	Equal(0, Value(buttons[2].alpha), "nothing standing")
	M.totems[2] = { icon = 310, start = M.now, length = 120 }
	M.Fire("PLAYER_TOTEM_UPDATE", 2)
	Equal(1, buttons[2].alpha, "slot 2")
	Equal(310, buttons[2].icon.texture)
	Equal(120, M.SpanOf(buttons[2].cooldown.duration).length)
	Equal(0, buttons[1].alpha, "slot 1 is still empty")

	M.SetCombat(true)
	M.totems[3] = { icon = 311, start = M.now, length = 60 }
	M.Fire("PLAYER_TOTEM_UPDATE", 3)
	Sealed(buttons[3].alpha, "in combat even whether one stands is sealed")
	Equal(1, Value(buttons[3].alpha))
	Equal(311, Value(buttons[3].icon.texture))
end)

---------------------------------------------------------------------------
-- Groups
---------------------------------------------------------------------------
Test("the party header makes a dressed frame for each member", function()
	local ns = Login()
	Party(3)
	local header = ns.Group.Get("party")
	True(header:IsShown(), "header")
	for index = 1, 3 do
		local button = PartyButton(ns, index)
		True(button, "button " .. index)
		Equal("party", button.kind)
		Equal("party" .. index, button.unit, "the drawing follows the unit the header gave")
		Equal(ns.db.units.party.width, button:GetWidth(), "sized by the secure snippet")
		Equal("target", button:GetAttribute("*type1"))
		Equal("togglemenu", button:GetAttribute("*type2"))
		Equal(5, #button.clicks, "all mouse buttons, from the template")
		Equal("Friend" .. index, button.texts.name.text, "a group member's name is not sealed")
		True(ClickCastFrames[button])
	end
	Equal(nil, PartyButton(ns, 4))
	Equal(0, #ns.GetProblems())
end)

Test("the party frames can stay up with only the player on them", function()
	local ns = Login()
	local header = ns.Group.Get("party")
	Equal(nil, header:GetAttribute("child1"), "alone, no party frames")
	ns.db.units.party.showSolo = true
	ns.Refresh()
	local button = header:GetAttribute("child1")
	True(button and button:IsShown(), "the player's own party frame")
	Equal("player", button.unit)
	Equal("Uther", button.texts.name.text)
end)

Test("the player's own party frame does not repeat the player's cast bar", function()
	local ns = Login()
	ns.db.units.party.castbar, ns.db.units.party.showPlayer = true, true
	ns.Refresh()
	Party(2)
	local mine, theirs = PartyButton(ns, 1), PartyButton(ns, 2)
	Equal("player", mine.unit)
	M.units.player.cast = { name = "Heal", icon = 3, start = M.now, length = 2, id = 4 }
	M.Fire("UNIT_SPELLCAST_START", "player")
	True(FreeUnitFrames_player.cast:IsShown(), "on the player's frame")
	False(mine.cast:IsShown(), "not a second time among the party")
	M.units.party1.cast = { name = "Smite", icon = 4, start = M.now, length = 2, id = 5 }
	M.Fire("UNIT_SPELLCAST_START", "party1")
	True(theirs.cast:IsShown(), "another member's cast is shown")
end)

Test("someone joining in the middle of a fight gets a working frame, with nothing refused", function()
	local ns = Login()
	Party(1)
	M.SetCombat(true)
	Party(3)
	local button = PartyButton(ns, 3)
	True(button, "the header made the button in combat")
	True(button.health, "and it is dressed")
	Equal("party3", button.unit)
	Equal(2000, Value(button.health.value))
	Equal(0, #M.blocked, "no protected call was attempted")
	Equal(0, #ns.GetProblems())
end)

Test("a header's button follows when the header points it at someone else", function()
	local ns = Login()
	Party(2)
	local button = PartyButton(ns, 1)
	Equal("Friend1", button.texts.name.text)
	M.Secure(function() button:SetAttribute("unit", "party2") end)
	Equal("party2", button.unit)
	Equal("Friend2", button.texts.name.text, "redrawn for the new unit")
	True(button:IsEventRegistered("UNIT_HEALTH"))
	M.units.party2.health = 5
	M.Fire("UNIT_HEALTH", "party2")
	Equal(5, Value(button.health.value), "and listening for it")
end)

Test("the same unit standing for a different person after a roster change is redrawn", function()
	local ns = Login()
	Party(2)
	M.units.party1.name = "Newcomer"
	M.RosterChanged()
	Equal("Newcomer", PartyButton(ns, 1).texts.name.text)
end)

Test("in a raid the raid frames are up and the party frames are not", function()
	local ns = Login()
	Party(2)
	True(PartyButton(ns, 1):IsShown())
	Raid(12)
	local raid = ns.Group.Get("raid")
	local count = 0
	for index = 1, 40 do
		local button = raid:GetAttribute("child" .. index)
		if button and button:IsShown() then
			count = count + 1
			Equal("raid", button.kind)
		end
	end
	Equal(12, count, "raid frames")
	False(PartyButton(ns, 1):IsShown(), "party frames")
	Equal("GROUP", raid:GetAttribute("groupBy"))
	Equal(5, raid:GetAttribute("unitsPerColumn"))
	Equal(8, raid:GetAttribute("maxColumns"))
end)

Test("raid frames are larger in a small raid, and change size only out of combat", function()
	local ns = Login()
	local cfg, raid = ns.db.units.raid, nil
	Raid(8)
	raid = ns.Group.Get("raid")
	Near(cfg.scale * cfg.scaleSmall, raid:GetScale(), "up to 10")
	Raid(15)
	Near(cfg.scale * cfg.scaleMid, raid:GetScale(), "up to 20")
	M.SetCombat(true)
	Raid(30)
	Near(cfg.scale * cfg.scaleMid, raid:GetScale(), "not in the middle of a fight")
	Equal(0, #M.blocked)
	M.SetCombat(false)
	Near(cfg.scale, raid:GetScale(), "once it is over")
end)

Test("a group grows the way the settings say, anchored by the corner that stays put", function()
	local ns = Login()
	local cfg, header = ns.db.units.party, ns.Group.Get("party")
	Equal("TOP", header:GetAttribute("point"), "members go down")
	Equal(-cfg.spacing, header:GetAttribute("yOffset"))
	Equal("TOPLEFT", header.anchors[1][1])
	cfg.growth = "up"
	ns.Refresh()
	Equal("BOTTOM", header:GetAttribute("point"))
	Equal(cfg.spacing, header:GetAttribute("yOffset"))
	Equal("BOTTOMLEFT", header.anchors[1][1])
	cfg.growth = "left"
	ns.Refresh()
	Equal("RIGHT", header:GetAttribute("point"))
	Equal("TOPRIGHT", header.anchors[1][1])

	local raid = ns.db.units.raid
	raid.growth, raid.columnGrowth = "down", "down" -- nonsense: columns cannot run the way members do
	Equal("right", ns.Group.ColumnGrowth(raid), "read as the usual choice")
	raid.growth, raid.columnGrowth = "right", "up"
	Equal("BOTTOMLEFT", ns.Group.Corner(raid))
end)

---------------------------------------------------------------------------
-- Combat
---------------------------------------------------------------------------
Test("a change of size made in a fight waits for its end, and nothing is refused", function()
	local ns = Login()
	local cfg = ns.db.units.player
	local width = cfg.width
	M.SetCombat(true)
	cfg.width = width + 40
	ns.Refresh()
	Equal(width, FreeUnitFrames_player:GetWidth(), "still the old width")
	Equal(0, #M.blocked)
	M.SetCombat(false)
	Equal(width + 40, FreeUnitFrames_player:GetWidth(), "applied when the fight ended")
end)

Test("a reload in the middle of a fight builds the frames when it ends", function()
	Player()
	M.combat = true
	local ns = Login()
	False(ns.IsBuilt(), "nothing can be built yet")
	Equal(nil, _G.FreeUnitFrames_player)
	Equal(0, #M.blocked)
	M.SetCombat(false)
	True(ns.IsBuilt())
	M.UpdateUnitWatch()
	True(FreeUnitFrames_player:IsShown())
	Equal(4000, Value(FreeUnitFrames_player.health.value))
end)

Test("what a frame draws keeps changing in combat", function()
	Login()
	Target(HOGGER)
	M.SetCombat(true)
	M.units.target.health = 20
	M.Fire("UNIT_HEALTH", "target")
	Equal(20, Value(FreeUnitFrames_target.health.value))
	Cast("target", { name = "Enrage", icon = 9, start = M.now, length = 1, id = 2 })
	True(FreeUnitFrames_target.cast:IsShown(), "a cast bar may come up in a fight: it is not protected")
	Equal(0, #M.blocked)
end)

---------------------------------------------------------------------------
-- The game's own frames
---------------------------------------------------------------------------
Test("the game's frames step aside, and what an addon may not touch is left alone", function()
	local ns = Login()
	False(PlayerFrame:IsShown())
	True(PlayerFrame.parent ~= UIParent, "moved off the screen's tree")
	Equal(nil, next(PlayerFrame.events), "its events are gone")
	Equal(nil, next(PlayerFrameHealthBar.events), "and its children's")
	False(TargetFrame:IsShown())
	True(TargetFrameAuraRows.events.UNIT_AURA, "the forbidden rows keep their events")
	False(PlayerCastingBarFrame:IsShown())
	False(ns.Blizzard.NeedsReload())
end)

Test("a frame of the game's is kept when the player says so, or when ours is off", function()
	FreeUnitFramesDB = { profiles = { Default = { hide = { player = false }, units = { focus = { enabled = false } } } } }
	local ns = Login()
	True(PlayerFrame:IsShown(), "kept by choice")
	True(FocusFrame:IsShown(), "kept because our focus frame is off")
	False(TargetFrame:IsShown())

	ns.db.hide.target = false
	ns.Refresh()
	True(ns.Blizzard.NeedsReload(), "the target frame is gone until a reload")
end)

Test("the game's frames are put away as the addon loads, before any of them has come up", function()
	Player()
	LoadAddon()
	M.Fire("ADDON_LOADED", "SomeOtherAddon")
	True(PlayerFrame:IsShown(), "not on another addon's account")
	M.Fire("ADDON_LOADED", "FreeUnitFrames")
	False(PlayerFrame:IsShown(), "away before login")
	False(PartyFrame:IsShown())
	Equal(nil, _G.FreeUnitFrames_player, "our own frames are made at login")
	Equal(0, #M.blocked)
end)

Test("with the game's target frame away, picking and losing a target still sounds as it does", function()
	local ns = Login()
	Target(HOGGER)
	Equal(SOUNDKIT.IG_CREATURE_AGGRO_SELECT, M.sounds[1], "an enemy")
	Target(Friend(1))
	Equal(SOUNDKIT.IG_CHARACTER_NPC_SELECT, M.sounds[2], "a friend")
	Target({ name = "Deer", reaction = 4 })
	Equal(SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT, M.sounds[3], "something neutral")
	Target(nil)
	Equal(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT, M.sounds[4], "target lost")
	M.looseTarget = true
	Target(nil)
	Equal(4, #M.sounds, "a target the game picked by itself goes quietly")
end)

Test("with the game's target frame kept, it plays its own sounds and we play none", function()
	FreeUnitFramesDB = { profiles = { Default = { hide = { target = false } } } }
	Login()
	Target(HOGGER)
	Target(nil)
	Equal(0, #M.sounds)
end)

Test("the game's cast bar is kept unless ours is drawn", function()
	FreeUnitFramesDB = { profiles = { Default = { units = { player = { castbar = false } } } } }
	Login()
	True(PlayerCastingBarFrame:IsShown())
	Equal(nil, FreeUnitFrames_player.cast, "and ours is not made")
end)

---------------------------------------------------------------------------
-- Moving frames
---------------------------------------------------------------------------
local function Handle(kind)
	for _, frame in ipairs(M.frames) do
		if frame.kind == kind and frame.movable then
			return frame
		end
	end
end

Test("unlocking shows a handle on each frame; a dropped handle moves its frame", function()
	local ns = Login()
	Equal(nil, Handle("focus"), "no handles while locked")
	SlashCmdList.FREEUNITFRAMES("unlock")
	False(ns.db.locked)
	local handle = Handle("focus")
	True(handle and handle:IsShown(), "focus handle")
	local cfg = ns.db.units.focus
	Equal(cfg.width, handle:GetWidth())

	handle:GetScript("OnDragStart")(handle)
	handle.dropped = { "CENTER", UIParent, "CENTER", 123.4, -45.6 }
	handle:GetScript("OnDragStop")(handle)
	handle.dropped = nil
	Equal(123, cfg.x, "whole screen units")
	Equal(-46, cfg.y)
	Equal(123, FreeUnitFrames_focus.anchors[1][4], "the frame went there")
	Equal(123, handle.anchors[1][4], "and the handle sits on it")

	SlashCmdList.FREEUNITFRAMES("lock")
	True(ns.db.locked)
	False(handle:IsShown())
end)

Test("a group's handle takes the room of a full group and is measured from its corner", function()
	local ns = Login()
	ns.Movers.SetLocked(false)
	local cfg, handle = ns.db.units.party, Handle("party")
	Equal("TOPLEFT", handle.point)
	Equal(cfg.width, handle:GetWidth())
	Equal(4 * cfg.height + 3 * cfg.spacing, handle:GetHeight(), "four members")
	handle.dropped = { "TOPLEFT", UIParent, "CENTER", -500, 300 }
	handle:GetScript("OnDragStop")(handle)
	handle.dropped = nil
	Equal(-500, cfg.x)
	Equal(300, cfg.y)
	Equal("TOPLEFT", ns.Group.Get("party").anchors[1][1])
	Equal(-500, ns.Group.Get("party").anchors[1][4])

	local raid, raidHandle = ns.db.units.raid, Handle("raid")
	Near((8 * raid.width + 7 * raid.columnSpacing) * raid.scale * raid.scaleSmall, raidHandle:GetWidth(), "eight columns")
end)

Test("frames cannot be unlocked in a fight, and a fight locks them again", function()
	local ns = Login()
	M.SetCombat(true)
	SlashCmdList.FREEUNITFRAMES("unlock")
	True(ns.db.locked, "stays locked")
	True(Printed(ns.L["Frames cannot be moved during a fight. Unlock them when it is over."]))
	M.SetCombat(false)
	SlashCmdList.FREEUNITFRAMES("unlock")
	False(ns.db.locked)
	M.SetCombat(true)
	True(ns.db.locked, "the fight locked them")
	False(Handle("player"):IsShown())
end)

---------------------------------------------------------------------------
-- Settings: saved, checked, carried in and out
---------------------------------------------------------------------------
Test("a saved file that is nonsense is replaced by the defaults", function()
	FreeUnitFramesDB = "broken"
	FreeUnitFramesCharDB = { profile = 12 }
	local ns = Login()
	Equal("Default", ns.profileName)
	Equal("slate", ns.db.theme)
	Equal(232, ns.db.units.player.width)
	Equal("table", type(FreeUnitFramesDB.profiles.Default))
	Equal("Default", FreeUnitFramesCharDB.profile)
end)

Test("each setting that is not what it may be goes back to its default; the rest is kept", function()
	FreeUnitFramesDB = { profiles = { Default = {
		theme = "neon", fontSize = 99, outline = "yes", farAlpha = 0.6, stray = true,
		hide = { player = "sure", raid = false, moon = true },
		units = {
			player = { width = "wide", height = 0 / 0, scale = 1.5, color = "plain", junk = 1, growth = "down" },
			alien = { enabled = true },
			raid = "nope",
		},
	} } }
	local ns = Login()
	local db = ns.db
	Equal("slate", db.theme)
	Equal(11, db.fontSize)
	Equal(false, db.outline)
	Equal(0.6, db.farAlpha, "a good value is kept")
	Equal(nil, db.stray, "what is not a setting is dropped")
	Equal(true, db.hide.player)
	Equal(false, db.hide.raid)
	Equal(nil, db.hide.moon)
	local player = db.units.player
	Equal(232, player.width)
	Equal(46, player.height, "not-a-number is not a height")
	Equal(1.5, player.scale)
	Equal("plain", player.color)
	Equal(nil, player.junk)
	Equal(nil, player.growth, "a single frame has no growth direction")
	Equal(nil, db.units.alien)
	Equal(82, db.units.raid.width)
end)

Test("on a narrow screen, fresh settings start inside it; chosen places are left alone", function()
	UIParent.width = 1024 -- a 4:3 screen: 512 either side of the middle
	FreeUnitFramesDB = { profiles = { Mine = { units = { party = { x = -900 } } } } }
	local ns = Login()
	local units = ns.db.units
	Equal(-500, units.party.x, "the party starts twelve in from the left edge")
	Equal(-500, units.raid.x)
	Equal(-438, units.pet.x, "the pet frame's left edge is twelve in")
	Equal(438, units.targettarget.x, "and the frame on the far right likewise")
	Equal(-290, units.player.x, "what fits stays where it was laid out")

	True(ns.Profiles.Switch("Mine"))
	Equal(-900, ns.db.units.party.x, "a place the player chose is not second-guessed")
	SlashCmdList.FREEUNITFRAMES("reset party")
	Equal(-500, ns.db.units.party.x, "until the frame is reset")
end)

Test("each character remembers its profile through its own saved file", function()
	FreeUnitFramesDB = { profiles = { Healer = { fontSize = 14 }, Default = {} } }
	FreeUnitFramesCharDB = { profile = "Healer" }
	local ns = Login()
	Equal("Healer", ns.profileName)
	Equal(14, ns.db.fontSize)
	True(ns.Profiles.Switch("Default"))
	Equal("Default", FreeUnitFramesCharDB.profile)
	Equal(11, ns.db.fontSize)
	False(ns.Profiles.Switch("Nobody"), "a profile that is not there")
end)

Test("a profile goes out as text and comes back the same", function()
	local ns = Login()
	ns.db.theme = "night"
	ns.db.units.raid.perColumn = 8
	ns.db.hide.pet = false
	local text = ns.Profiles.Export(ns.db)
	Equal("FREEUF1:", text:sub(1, 8))
	local copy = ns.Profiles.Import("  " .. text:sub(1, 40) .. "\n" .. text:sub(41) .. "  ")
	True(copy, "read back, spaces and line breaks and all")
	Equal("night", copy.theme)
	Equal(8, copy.units.raid.perColumn)
	Equal(false, copy.hide.pet)
	Equal(ns.db.units.player.width, copy.units.player.width)
end)

Test("text that is not a profile is turned away with a reason, and changes nothing", function()
	local ns = Login()
	local before = ns.Profiles.Export(ns.db)
	local function Refused(text)
		local settings, why = ns.Profiles.Import(text)
		Equal(nil, settings)
		True(type(why) == "string" and #why > 0, "a reason")
	end
	Refused(nil)
	Refused("")
	Refused("hello there")
	Refused("FREEUF1:not base64 at all!")
	Refused("FREEUF1:abcd")                               -- decodes, but is not packed data
	Refused("FREEUF1:" .. C_EncodingUtil.EncodeBase64("Z{{{")) -- unpacks, but is not a table
	Refused("FREEUF1:" .. C_EncodingUtil.EncodeBase64("Z12"))  -- a number, not settings
	Refused("FREEUF1:" .. ("ab"):rep(40000))
	Equal(before, ns.Profiles.Export(ns.db))
	Equal(0, #M.luaErrors, "being handed rubbish is not an error in the addon")
end)

Test("an imported profile is checked like a saved one", function()
	local ns = Login()
	local hostile = { theme = "night", fontSize = 500, units = { player = { width = -5, healthText = "everything" }, raid = 7 }, payload = { 1, 2, 3 } }
	local text = "FREEUF1:" .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(hostile)))
	local settings = ns.Profiles.Import(text)
	Equal("night", settings.theme)
	Equal(11, settings.fontSize)
	Equal(232, settings.units.player.width)
	Equal("both", settings.units.player.healthText)
	Equal(5, settings.units.raid.perColumn)
	Equal(nil, settings.payload)
end)

Test("the profile window copies settings out and brings pasted ones in as a new profile", function()
	local ns = Login()
	ns.db.theme = "hearth"
	SlashCmdList.FREEUNITFRAMES("profile")
	local window = FreeUnitFramesProfileWindow
	True(window:IsShown())
	local exported = window.edit:GetText()
	True(window.edit.highlighted, "selected, ready to copy")

	ns.db.theme = "slate"
	window.edit:SetText(exported)
	ns.Profiles.ImportFromWindow()
	False(window:IsShown())
	Equal("Imported", ns.profileName)
	Equal("hearth", ns.db.theme)
	Equal("slate", ns.saved.profiles.Default.theme, "the old profile is untouched")

	SlashCmdList.FREEUNITFRAMES("profile")
	window.edit:SetText("rubbish")
	ns.Profiles.ImportFromWindow()
	True(window:IsShown(), "stays open so the text can be fixed")
	Equal("Imported", ns.profileName)
end)

Test("profiles can be copied and deleted, down to the last one", function()
	local ns = Login()
	local copy = ns.Profiles.Copy()
	Equal("Profile", copy)
	Equal("Profile 2", ns.Profiles.Copy(), "a name in use gets a number")
	True(ns.Profiles.DeleteCurrent())
	Equal("Default", ns.profileName, "deleting moves to another profile")
	True(ns.Profiles.DeleteCurrent())
	Equal("Profile", ns.profileName)
	Equal(1, #ns.GetProfileNames())
	False(ns.Profiles.DeleteCurrent(), "the last one stays")
	Equal("Profile", FreeUnitFramesCharDB.profile)
end)

---------------------------------------------------------------------------
-- Options and commands
---------------------------------------------------------------------------
Test("the general page builds and its controls change the settings", function()
	local ns = Login()
	ns.Options.Open()
	local page = ns.Options.pages.general
	True(page.panel, "built when first shown")
	True(#page.controls >= 7 + 7, "a control per look setting and per frame of the game's")
	page.lock:Click()
	False(ns.db.locked, "the lock button unlocks")
	Equal(ns.L["Lock frames"], page.lock:GetText())
	page.lock:Click()
	True(ns.db.locked)
	Equal(0, #ns.GetProblems())
end)

Test("the frames page shows each kind of frame the controls it has, and they work", function()
	local ns = Login()
	Settings.OpenToCategory(ns.Options.framesCategory:GetID())
	local page = ns.Options.pages.frames
	True(page.panel)
	True(page.controls.width:IsShown())
	False(page.controls.perColumn:IsShown(), "the player's frame has no columns")

	-- A stepper is a row with a minus and a plus button.
	local cfg = ns.db.units.player
	local width = cfg.width
	page.controls.width.children[2]:Click()
	Equal(width + 2, cfg.width, "plus")
	Equal(width + 2, FreeUnitFrames_player:GetWidth(), "and the frame follows")
	page.controls.width.children[1]:Click()
	page.controls.width.children[1]:Click()
	Equal(width - 2, cfg.width, "minus")
	cfg.width = 500
	page.controls.width.children[2]:Click()
	Equal(500, cfg.width, "not past the most it may be")

	-- A choice is a row with one button: left click forward, right click back.
	Equal("class", cfg.color)
	page.controls.color.children[1]:Click("LeftButton")
	Equal("reaction", cfg.color)
	page.controls.color.children[1]:Click("RightButton")
	page.controls.color.children[1]:Click("RightButton")
	Equal("plain", cfg.color, "round the end")

	page.controls.castbar:SetChecked(false)
	page.controls.castbar:Click()
	Equal(false, cfg.castbar)

	page.tabs.raid:Click()
	True(page.controls.perColumn:IsShown(), "the raid has columns")
	False(page.controls.castbar:IsShown(), "and no cast bars")
	page.controls.perColumn.children[2]:Click()
	Equal(6, ns.db.units.raid.perColumn)
	Equal(0, #ns.GetProblems())
end)

Test("every command answers", function()
	local ns = Login()
	SlashCmdList.FREEUNITFRAMES("status")
	True(Printed(ns.L["No errors recorded."]))
	True(Printed(ns.L["Sealed values"]))
	SlashCmdList.FREEUNITFRAMES("what")
	True(Printed("/freeuf unlock"), "anything unknown lists the commands")
	SlashCmdList.FREEUNITFRAMES("")
	Equal(ns.Options.category, M.settings.opened, "bare /freeuf opens the options")

	ns.db.units.player.width = 300
	SlashCmdList.FREEUNITFRAMES("reset player")
	Equal(232, ns.db.units.player.width)
	Equal(232, FreeUnitFrames_player:GetWidth())
	ns.db.theme, ns.db.units.target.height = "night", 90
	SlashCmdList.FREEUNITFRAMES("  RESET   All ")
	Equal("slate", ns.db.theme)
	Equal(46, ns.db.units.target.height)
	SlashCmdList.FREEUNITFRAMES("reset everything")
	True(Printed(ns.L["Reset what?"]))
end)

Test("the game's language decides the words", function()
	M.locale = "deDE"
	local ns = Login()
	Equal("Fenster sperren", ns.L["Lock frames"])
	Equal("Ziel des Ziels", ns.Defaults.Label("targettarget"))
	Equal("no such text", ns.L["no such text"], "a text without a translation is shown as it is")
	ns.Options.Open()
	Settings.OpenToCategory(ns.Options.framesCategory:GetID())
	Equal(0, #ns.GetProblems())
end)

Test("the frame tooltip follows the setting", function()
	local ns = Login()
	local frame = FreeUnitFrames_player
	frame:GetScript("OnEnter")(frame)
	Equal("player", M.tooltip.unit)
	frame:GetScript("OnLeave")(frame)
	ns.db.tooltips = "never"
	frame:GetScript("OnEnter")(frame)
	Equal(nil, M.tooltip.unit)
	ns.db.tooltips = "calm"
	frame:GetScript("OnEnter")(frame)
	Equal("player", M.tooltip.unit, "out of combat")
	frame:GetScript("OnLeave")(frame)
	M.SetCombat(true)
	frame:GetScript("OnEnter")(frame)
	Equal(nil, M.tooltip.unit, "not in combat")
end)

---------------------------------------------------------------------------
-- Looks and odd corners
---------------------------------------------------------------------------
Test("every theme, texture and text setting can be put on", function()
	local ns = Login()
	Target(WithAuras(HOGGER, AURAS))
	for _, theme in ipairs(ns.Style.THEME_ORDER) do
		for _, texture in ipairs(ns.Style.TEXTURE_ORDER) do
			ns.db.theme, ns.db.texture = theme, texture
			ns.db.outline = not ns.db.outline
			ns.Refresh()
			Equal(ns.Style.TEXTURES[texture], FreeUnitFrames_player.health.barTexture.texture)
		end
	end
	Equal(0, #ns.GetProblems())
end)

Test("every optional part can be switched on, on every frame, and off again", function()
	local ns = Login("SHAMAN")
	Party(2)
	Target(WithAuras(HOGGER, AURAS))
	M.SetUnit("targettarget", Friend(9))
	M.SetUnit("focus", HOGGER)
	M.SetUnit("pet", { name = "Wolf", playerControlled = true, reaction = 5 })
	M.UpdateUnitWatch()
	for _, kind in ipairs(ns.Defaults.KINDS) do
		local cfg = ns.db.units[kind]
		for _, pass in ipairs({ "last", "first" }) do
			for key, spec in pairs(ns.Defaults.UNIT_SPEC) do
				if cfg[key] ~= nil and key ~= "enabled" then
					if spec.type == "bool" then
						cfg[key] = pass == "last"
					elseif spec.type == "choice" then
						cfg[key] = spec.choices[pass == "last" and #spec.choices or 1]
					elseif key == "buffs" or key == "debuffs" then
						cfg[key] = pass == "last" and 8 or 0
					end
				end
			end
			ns.Refresh()
			M.Advance(0.3)
		end
	end
	Equal(0, #ns.GetProblems())
	Equal(0, #M.blocked)
end)

Test("the target's target, which sends no events, is looked at again a few times a second", function()
	Login()
	Target(HOGGER)
	M.SetUnit("targettarget", Friend(1, { health = 900, healthMax = 1000 }))
	M.UpdateUnitWatch()
	local frame = FreeUnitFrames_targettarget
	True(frame:IsShown())
	Equal(900, Value(frame.health.value))
	M.units.targettarget.health = 400
	M.Advance(0.1)
	Equal(900, Value(frame.health.value), "not yet")
	M.Advance(0.2)
	Equal(400, Value(frame.health.value), "now")
end)

Test("a frame only hears about its own unit", function()
	local ns = Login()
	Party(2)
	local first, second = PartyButton(ns, 1), PartyButton(ns, 2)
	M.units.party1.health, M.units.party2.health = 111, 222
	M.Fire("UNIT_HEALTH", "party2")
	Equal(2000, Value(first.health.value), "the other member's frame did not redraw")
	Equal(222, Value(second.health.value))
end)

Test("an error in one part of a frame is reported and does not stop the others", function()
	local ns = Login()
	ns.Elements.Power.Update = function()
		error("the power bar broke")
	end
	M.units.player.health = 50
	ns.Frame.RefreshAll()
	Equal(50, Value(FreeUnitFrames_player.health.value), "health still drawn")
	Equal(1, #ns.GetProblems(), "kept for /freeuf status")
	True(ns.GetProblems()[1].text:find("the power bar broke", 1, true))
	True(Printed("/freeuf status"), "said once in chat")
	Equal(1, #M.luaErrors, "and handed to the game's own error handler, not swallowed")
	SlashCmdList.FREEUNITFRAMES("status")
	True(Printed("the power bar broke"))

	ns.Frame.RefreshAll()
	Equal(1, #ns.GetProblems(), "the same error is counted, not listed again")
	Equal(2, ns.GetProblems()[1].count)
	M.luaErrors = {} -- expected in this scenario
end)

Test("a refused call is kept with the errors", function()
	local ns = Login()
	M.Fire("ADDON_ACTION_BLOCKED", "FreeUnitFrames", "Frame:SetPoint()")
	M.Fire("ADDON_ACTION_BLOCKED", "SomeoneElse", "Frame:Hide()")
	Equal(1, #ns.GetProblems())
	True(ns.GetProblems()[1].text:find("SetPoint", 1, true))
end)

Test("portraits are drawn by the game for the unit on show", function()
	local ns = Login()
	Equal(nil, FreeUnitFrames_player.portrait, "none by default")
	ns.db.units.player.portrait = "left"
	ns.Refresh()
	local picture = FreeUnitFrames_player.portrait
	True(picture:IsShown())
	Equal("player", picture.portraitOf)
	True(FreeUnitFrames_player.barLeft > 40, "the bars make room for it")
	ns.db.units.player.portrait = "none"
	ns.Refresh()
	False(picture:IsShown())
end)

Test("a narrow frame with no health number still says that someone is dead", function()
	local ns = Login()
	Raid(3)
	local button = ns.Group.Get("raid"):GetAttribute("child2")
	Equal("Friend2", button.texts.name.text)
	M.units.raid2.dead = true
	M.Fire("UNIT_HEALTH", "raid2")
	Equal(ns.L["Dead"], button.texts.name.text)
	M.units.raid2.dead = false
	M.Fire("UNIT_HEALTH", "raid2")
	Equal("Friend2", button.texts.name.text, "and the name comes back")
end)
