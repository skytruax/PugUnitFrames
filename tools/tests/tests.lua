-- Scenarios for Pug Unit Frames, run by tools/tests/run.py against wowmock.lua.
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
		chunk("PugUnitFrames", ns)
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
	M.Fire("ADDON_LOADED", "PugUnitFrames")
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
		local frame = _G["PugUnitFrames_" .. kind]
		True(frame, kind .. " frame")
		True(frame:IsProtected(), kind .. " is protected")
		Equal(kind, frame:GetAttribute("unit"), kind .. " unit")
		Equal("target", frame:GetAttribute("type1"), "a click targets")
		Equal("togglemenu", frame:GetAttribute("*type2"), "a right click opens the menu")
		Equal(SecureUnitButton_OnClick, frame:GetScript("OnClick"), "the secure click handler is still there")
		True(ClickCastFrames[frame], kind .. " is offered to click-casting addons")
	end
	True(PugUnitFrames_player:IsShown(), "the player's frame is up")
	False(PugUnitFrames_target:IsShown(), "no target, no target frame")
	False(PugUnitFrames_pet:IsShown(), "no pet, no pet frame")
	Equal(0, #ns.GetProblems(), "problems")
	Equal(0, #M.blocked, "refused calls")
end)

Test("a frame is placed from the middle of the screen, in screen units whatever its scale", function()
	local ns = Login()
	local cfg = ns.db.units.player
	local anchor = PugUnitFrames_player.anchors[1]
	Equal("CENTER", anchor[1])
	Equal(UIParent, anchor[2])
	Equal(cfg.x, anchor[4])
	Equal(cfg.y, anchor[5])
	cfg.scale = 2
	ns.Refresh()
	anchor = PugUnitFrames_player.anchors[1]
	Near(cfg.x / 2, anchor[4], "x at double scale")
	Near(cfg.y / 2, anchor[5], "y at double scale")
	Near(2, PugUnitFrames_player:GetScale(), "scale")
end)

Test("a frame comes and goes with its unit, and a disabled one stays away", function()
	local ns = Login()
	Target(HOGGER)
	True(PugUnitFrames_target:IsShown(), "target frame with a target")
	Target(nil)
	False(PugUnitFrames_target:IsShown(), "target frame without one")

	ns.db.units.target.enabled = false
	ns.Refresh()
	Target(HOGGER)
	False(PugUnitFrames_target:IsShown(), "a disabled frame stays hidden")
	ns.db.units.target.enabled = true
	ns.Refresh()
	True(PugUnitFrames_target:IsShown(), "enabled again")
end)

---------------------------------------------------------------------------
-- Health, power and the words
---------------------------------------------------------------------------
Test("the player's health reaches the bar sealed, and is never opened on the way", function()
	Login()
	local bar = PugUnitFrames_player.health
	Sealed(bar.value, "health")
	Equal(4000, Value(bar.value), "health")
	-- A player's own maximum health is one of the things the game does not seal.
	PlainValue(bar.high, "maximum health of a player")
	Equal(5000, bar.high, "maximum health")
	Equal(0, bar.low)
end)

Test("health text is written by the game from the sealed numbers, in every style", function()
	local ns = Login()
	local cfg, text = ns.db.units.player, PugUnitFrames_player.texts.health
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
	Equal(1000, Value(PugUnitFrames_player.health.value), "bar")
	Equal("1,000  20%", Value(PugUnitFrames_player.texts.health.text), "text")
	Equal(Enum.StatusBarInterpolation.ExponentialEaseOut, PugUnitFrames_player.health.interpolation, "a change of the same unit glides")
end)

Test("a creature's name and maximum health are sealed and still shown", function()
	Login()
	Target(HOGGER)
	local frame = PugUnitFrames_target
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
	Near(hostile[1] * tone, PugUnitFrames_target.health.barColor[1], "hostile red")

	Target({ name = "Jaina", class = "MAGE", isPlayer = true, playerControlled = true, reaction = 5, health = 10, healthMax = 10 })
	local mage = M.CLASS_COLORS.MAGE
	Near(mage[1] * tone, PugUnitFrames_target.health.barColor[1], "mage red part")
	Near(mage[3] * tone, PugUnitFrames_target.health.barColor[3], "mage blue part")

	Target({ name = "Wolf", tapped = true, reaction = 2, canAttack = true })
	Near(ns.Style.REACTION.tapped[1] * tone, PugUnitFrames_target.health.barColor[1], "someone else's kill is grey")
end)

Test("a class the game seals still colours the bar, untouched", function()
	Login()
	-- Contrived: a "player" the game does not treat as player-controlled, so its class is sealed.
	Target({ name = "Echo", class = "DRUID", isPlayer = true, playerControlled = false, inGroup = false, reaction = 4 })
	local color = PugUnitFrames_target.health.barColor
	Sealed(color[1], "a sealed class gives sealed colour numbers")
	Near(M.CLASS_COLORS.DRUID[1], Value(color[1]), "they are handed on as they came, not toned")
end)

Test("colouring by health goes through a curve inside the game", function()
	local ns = Login()
	ns.db.units.player.color = "health"
	ns.Refresh()
	local color = PugUnitFrames_player.health.barColor
	Sealed(color[1], "red part")
	Sealed(color[2], "green part")
	-- 80% lies between the amber point at 55% and the green one at 100%.
	True(Value(color[1]) < 0.88 and Value(color[1]) > 0.36, "between amber and green")
	M.units.player.health = 100
	M.Fire("UNIT_HEALTH", "player")
	True(Value(PugUnitFrames_player.health.barColor[1]) > 0.8, "nearly empty is red")
end)

Test("power reaches its bar sealed, coloured by its kind", function()
	local ns = Login()
	local bar = PugUnitFrames_player.power
	Sealed(bar.value, "mana")
	Equal(3000, Value(bar.value))
	Equal(4000, Value(bar.high))
	local r, g, b = ns.Style.PowerColor("MANA")
	Near(b, bar.barColor[3], "mana is blue")
	Equal("3,000", Value(PugUnitFrames_player.texts.power.text), "power text")

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
	False(PugUnitFrames_player.power:IsShown(), "power bar")
	False(PugUnitFrames_player.active.Power, "power element")
	ns.db.units.player.powerHeight = 8
	ns.Refresh()
	True(PugUnitFrames_player.power:IsShown(), "power bar back")
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
	local heal = PugUnitFrames_player.health.heal
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
	local bars = PugUnitFrames_player.threat.bars
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
	Near(ns.db.farAlpha, Value(button.body.shadow.holder.alpha), "and the plate's shadow fades with it")
	M.units.party1.rangeChecked = false
	M.Fire("UNIT_IN_RANGE_UPDATE", "party1", M.Seal(false))
	Equal(1, Value(button.body.alpha), "a range that could not be checked counts as near")
	Equal(nil, PugUnitFrames_player.body.alpha, "the player's own frame does not fade")
end)

Test("a raid mark is one cell of the game's sheet, chosen by a sealed number", function()
	Login()
	local mark = PugUnitFrames_player.marks.raid
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

Test("the raid mark sits inside a wide frame and rides the edge of a narrow one", function()
	local ns = Login()
	Equal("TOP", PugUnitFrames_player.marks.raid.anchors[1][1], "inside, clear of icons above the plate")
	Raid(3)
	local button = ns.Group.Get("raid"):GetAttribute("child1")
	Equal("CENTER", button.marks.raid.anchors[1][1], "on the edge, clear of the name")
end)

Test("leader, combat and resting marks follow the game", function()
	local ns = Login()
	local marks = PugUnitFrames_player.marks
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
	local cast = PugUnitFrames_target.cast
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
	local cast = PugUnitFrames_player.cast
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
	local cast = PugUnitFrames_player.cast
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
	True(PugUnitFrames_target.cast:IsShown())
	Target(HOGGER)
	False(PugUnitFrames_target.cast:IsShown(), "and one that is not, does not")
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
	local frame = PugUnitFrames_target
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
	local icons = ShownIcons(PugUnitFrames_target)
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
	local icons = ShownIcons(PugUnitFrames_target)
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
	Equal(5, #ShownIcons(PugUnitFrames_target), "not redrawn yet")
	M.Advance(0)
	Equal(4, #ShownIcons(PugUnitFrames_target), "redrawn on the next update")
	M.units.target.auras = {}
	M.Fire("UNIT_AURA", "target")
	M.Advance(0)
	Equal(0, #ShownIcons(PugUnitFrames_target), "all gone")
end)

Test("an aura icon shows the game's tooltip for it", function()
	Login()
	Target(WithAuras(HOGGER, AURAS))
	local icon = ShownIcons(PugUnitFrames_target)[1]
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
	local light, lamp, pulse = button.auras.light, button.auras.lamp, button.auras.pulse
	False(lamp:IsShown(), "nothing to remove")
	False(pulse:IsPlaying())
	M.SetCombat(true)
	M.units.party1.auras = {
		{ id = 31, icon = 1, helpful = false, kind = 2 },                  -- a curse the player cannot remove
		{ id = 32, icon = 2, helpful = false, kind = 3, removable = true }, -- a disease the player can
	}
	M.Fire("UNIT_AURA", "party1")
	M.Advance(0)
	True(light[1]:IsVisible(), "lit")
	True(pulse:IsPlaying(), "and breathing, so that it is seen in a fight")
	Sealed(light[1].vertex[1], "in a sealed colour")
	Near(0.72, Value(light[1].vertex[1]), "the disease's, not the curse's")
	Near(0.52, Value(light[4].vertex[2]), "on all four sides")
	M.units.party1.auras = { { id = 31, icon = 1, helpful = false, kind = 2 } }
	M.Fire("UNIT_AURA", "party1")
	M.Advance(0)
	False(light[1]:IsVisible(), "out again")
	False(pulse:IsPlaying())
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
	True(ShownIcons(PugUnitFrames_target)[1].mouse, "an icon beside a frame has its tooltip")
end)

---------------------------------------------------------------------------
-- Class pieces
---------------------------------------------------------------------------
Test("a rogue's combo points fill the pips from a sealed count", function()
	Login("ROGUE")
	Target(HOGGER)
	local bars = PugUnitFrames_target.points.bars
	Equal(5, #bars)
	M.comboPoints = 3
	M.Fire("UNIT_POWER_UPDATE", "player")
	for index, bar in ipairs(bars) do
		Equal(index - 1, bar.low)
		Equal(index, bar.high)
		Sealed(bar.value, "the count")
		Equal(3, Value(bar.value))
	end
	Equal(nil, PugUnitFrames_player.points, "only the target frame has them")
end)

Test("a class without combo points has no pips", function()
	Login("PALADIN")
	Target(HOGGER)
	Equal(nil, PugUnitFrames_target.points)
	Equal(nil, PugUnitFrames_player.totems, "and a class without totems has none")
end)

Test("a shaman's totems show while they stand, also when the game seals them", function()
	Login("SHAMAN")
	local buttons = PugUnitFrames_player.totems.buttons
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

Test("in a fight an empty totem slot stays unseen although the game calls it taken, and a totem is gone when its time is up", function()
	Login("SHAMAN")
	local buttons = PugUnitFrames_player.totems.buttons
	M.emptySlotsSayYes = true
	M.totems[2] = { icon = 310, start = M.now, length = 120 }
	M.SetCombat(true)
	M.Fire("PLAYER_TOTEM_UPDATE", 2)
	Sealed(buttons[1].alpha)
	Equal(0, Value(buttons[1].alpha), "an empty slot: the game says yes, its time says no")
	Equal(0, Value(buttons[4].alpha))
	Equal(1, Value(buttons[2].alpha), "the one that stands")
	-- Its time runs out and the game sends no word of it.
	M.Advance(121)
	Equal(0, Value(buttons[2].alpha), "gone with its time")
	Equal(0, #M.blocked)
end)

Test("a right click sends a totem away, whichever half of a click the game acts on, and an empty slot is not in the mouse's way", function()
	Login("SHAMAN")
	local totems = PugUnitFrames_player.totems
	local clicks = totems.clicks
	True(clicks[1]:IsProtected(), "what is clicked is the game's secure button")
	False(totems.buttons[1]:IsProtected(), "what is seen is an ordinary frame")
	Equal(totems.buttons[1], totems.buttons[1].cooldown.parent, "with the sweep on it, not on the secure button")
	False(clicks[1].mouse, "an empty slot lets the mouse through")
	M.totems[1] = { icon = 310, start = M.now, length = 120 }
	M.Fire("PLAYER_TOTEM_UPDATE", 1)
	True(clicks[1].mouse, "a totem's slot takes it")
	False(clicks[2].mouse)

	M.Press(clicks[1], "LeftButton")
	Equal(0, #M.destroyed, "a left click does nothing")
	M.Press(clicks[1], "RightButton")
	Equal(1, M.destroyed[1], "with the game acting on the press")
	Equal(1, #M.destroyed, "once, not on the press and the release both")

	M.keyDown = false
	M.totems[1] = { icon = 310, start = M.now, length = 120 }
	M.Fire("PLAYER_TOTEM_UPDATE", 1)
	M.Press(clicks[1], "RightButton")
	Equal(2, #M.destroyed, "and with the game acting on the release")

	clicks[1].scripts.OnEnter(clicks[1])
	Equal(1, M.tooltip.totem, "the mouse over a slot says what stands there")

	-- A fight: nothing readable about the slots and no button may be changed, so all four take
	-- the mouse from its first moment, and a totem set down in the fight can be sent away.
	M.SetCombat(true)
	True(clicks[3].mouse)
	M.totems[3] = { icon = 311, start = M.now, length = 60 }
	M.Fire("PLAYER_TOTEM_UPDATE", 3)
	Equal(1, Value(totems.buttons[3].alpha), "drawn in the fight, sweep and all")
	M.Press(clicks[3], "RightButton")
	Equal(3, M.destroyed[3])
	M.SetCombat(false)
	False(clicks[3].mouse, "after the fight the empty slots step back")
	Equal(0, #M.blocked)
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
		Equal("target", button:GetAttribute("type1"))
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
	True(PugUnitFrames_player.cast:IsShown(), "on the player's frame")
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
	Equal(width, PugUnitFrames_player:GetWidth(), "still the old width")
	Equal(0, #M.blocked)
	M.SetCombat(false)
	Equal(width + 40, PugUnitFrames_player:GetWidth(), "applied when the fight ended")
end)

Test("a reload in the middle of a fight builds the frames when it ends", function()
	Player()
	M.combat = true
	local ns = Login()
	False(ns.IsBuilt(), "nothing can be built yet")
	Equal(nil, _G.PugUnitFrames_player)
	Equal(0, #M.blocked)
	M.SetCombat(false)
	True(ns.IsBuilt())
	M.UpdateUnitWatch()
	True(PugUnitFrames_player:IsShown())
	Equal(4000, Value(PugUnitFrames_player.health.value))
end)

Test("what a frame draws keeps changing in combat", function()
	Login()
	Target(HOGGER)
	M.SetCombat(true)
	M.units.target.health = 20
	M.Fire("UNIT_HEALTH", "target")
	Equal(20, Value(PugUnitFrames_target.health.value))
	Cast("target", { name = "Enrage", icon = 9, start = M.now, length = 1, id = 2 })
	True(PugUnitFrames_target.cast:IsShown(), "a cast bar may come up in a fight: it is not protected")
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
	PugUnitFramesDB = { profiles = { Default = { hide = { player = false }, units = { focus = { enabled = false } } } } }
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
	M.Fire("ADDON_LOADED", "PugUnitFrames")
	False(PlayerFrame:IsShown(), "away before login")
	False(PartyFrame:IsShown())
	Equal(nil, _G.PugUnitFrames_player, "our own frames are made at login")
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
	PugUnitFramesDB = { profiles = { Default = { hide = { target = false } } } }
	Login()
	Target(HOGGER)
	Target(nil)
	Equal(0, #M.sounds)
end)

Test("the game's cast bar is kept unless ours is drawn", function()
	PugUnitFramesDB = { profiles = { Default = { units = { player = { castbar = false } } } } }
	Login()
	True(PlayerCastingBarFrame:IsShown())
	Equal(nil, PugUnitFrames_player.cast, "and ours is not made")
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
	SlashCmdList.PUGUNITFRAMES("unlock")
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
	Equal(123, PugUnitFrames_focus.anchors[1][4], "the frame went there")
	Equal(123, handle.anchors[1][4], "and the handle sits on it")

	SlashCmdList.PUGUNITFRAMES("lock")
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
	SlashCmdList.PUGUNITFRAMES("unlock")
	True(ns.db.locked, "stays locked")
	True(Printed(ns.L["Frames cannot be moved during a fight. Unlock them when it is over."]))
	M.SetCombat(false)
	SlashCmdList.PUGUNITFRAMES("unlock")
	False(ns.db.locked)
	M.SetCombat(true)
	True(ns.db.locked, "the fight locked them")
	False(Handle("player"):IsShown())
end)

---------------------------------------------------------------------------
-- Settings: saved, checked, carried in and out
---------------------------------------------------------------------------
Test("a saved file that is nonsense is replaced by the defaults", function()
	PugUnitFramesDB = "broken"
	PugUnitFramesCharDB = { profile = 12 }
	local ns = Login()
	Equal("Default", ns.profileName)
	Equal("slate", ns.db.theme)
	Equal(232, ns.db.units.player.width)
	Equal("table", type(PugUnitFramesDB.profiles.Default))
	Equal("Default", PugUnitFramesCharDB.profile)
end)

Test("each setting that is not what it may be goes back to its default; the rest is kept", function()
	PugUnitFramesDB = { profiles = { Default = {
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
	PugUnitFramesDB = { profiles = { Mine = { units = { party = { x = -900 } } } } }
	local ns = Login()
	local units = ns.db.units
	Equal(-500, units.party.x, "the party starts twelve in from the left edge")
	Equal(-500, units.raid.x)
	Equal(-438, units.pet.x, "the pet frame's left edge is twelve in")
	Equal(438, units.targettarget.x, "and the frame on the far right likewise")
	Equal(-290, units.player.x, "what fits stays where it was laid out")

	True(ns.Profiles.Switch("Mine"))
	Equal(-900, ns.db.units.party.x, "a place the player chose is not second-guessed")
	SlashCmdList.PUGUNITFRAMES("reset party")
	Equal(-500, ns.db.units.party.x, "until the frame is reset")
end)

Test("each character remembers its profile through its own saved file", function()
	PugUnitFramesDB = { profiles = { Healer = { fontSize = 14 }, Default = {} } }
	PugUnitFramesCharDB = { profile = "Healer" }
	local ns = Login()
	Equal("Healer", ns.profileName)
	Equal(14, ns.db.fontSize)
	True(ns.Profiles.Switch("Default"))
	Equal("Default", PugUnitFramesCharDB.profile)
	Equal(11, ns.db.fontSize)
	False(ns.Profiles.Switch("Nobody"), "a profile that is not there")
end)

Test("a profile goes out as text and comes back the same", function()
	local ns = Login()
	ns.db.theme = "night"
	ns.db.units.raid.perColumn = 8
	ns.db.hide.pet = false
	local text = ns.Profiles.Export(ns.db)
	Equal("PUGUF1:", text:sub(1, 7))
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
	Refused("PUGUF1:not base64 at all!")
	Refused("PUGUF1:abcd")                               -- decodes, but is not packed data
	Refused("PUGUF1:" .. C_EncodingUtil.EncodeBase64("Z{{{")) -- unpacks, but is not a table
	Refused("PUGUF1:" .. C_EncodingUtil.EncodeBase64("Z12"))  -- a number, not settings
	Refused("PUGUF1:" .. ("ab"):rep(40000))
	Equal(before, ns.Profiles.Export(ns.db))
	Equal(0, #M.luaErrors, "being handed rubbish is not an error in the addon")
end)

Test("an imported profile is checked like a saved one", function()
	local ns = Login()
	local hostile = { theme = "night", fontSize = 500, units = { player = { width = -5, healthText = "everything" }, raid = 7 }, payload = { 1, 2, 3 } }
	local text = "PUGUF1:" .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(hostile)))
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
	SlashCmdList.PUGUNITFRAMES("profile")
	local window = PugUnitFramesProfileWindow
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

	SlashCmdList.PUGUNITFRAMES("profile")
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
	Equal("Profile", PugUnitFramesCharDB.profile)
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
	page.hideAll:SetChecked(true)
	page.hideAll:Click()
	True(ns.db.hideAll, "the game's frames stay hidden also where ours is off")
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
	Equal(width + 2, PugUnitFrames_player:GetWidth(), "and the frame follows")
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

	-- A frame's settings come a section at a time.
	False(page.controls.color:IsShown(), "the bars' settings are on another section")
	page.sections.bars:Click()
	True(page.controls.color:IsShown())
	True(page.controls.absorbs:IsShown())
	False(page.controls.perColumn:IsShown())
	page.sections.icons:Click()
	True(page.controls.myBuffs:IsShown())
	False(page.controls.color:IsShown())
	-- Every setting is on exactly one section.
	local seen = {}
	for _, section in ipairs(ns.Defaults.UNIT_SECTIONS) do
		for _, key in ipairs(section.keys) do
			False(seen[key], key .. " is listed twice")
			seen[key] = true
			True(ns.Defaults.UNIT_SPEC[key], key .. " is a setting")
		end
	end
	for key in pairs(ns.Defaults.UNIT_SPEC) do
		True(seen[key] or key == "x" or key == "y", key .. " has no section")
	end
	Equal(0, #ns.GetProblems())
end)

Test("a copy left behind under the addon's old name is pointed out at login", function()
	Login()
	False(Printed("FreeUnitFrames folder"), "nothing to say when the old copy is gone")
end)

Test("with the old copy still installed, login says to delete it", function()
	M.loadedAddOns.FreeUnitFrames = true
	Login()
	True(Printed("Delete the FreeUnitFrames folder"), "said in chat")
end)

Test("every command answers", function()
	local ns = Login()
	SlashCmdList.PUGUNITFRAMES("status")
	True(Printed(ns.L["No errors recorded."]))
	True(Printed(ns.L["Sealed values"]))
	SlashCmdList.PUGUNITFRAMES("what")
	True(Printed("/pug unlock"), "anything unknown lists the commands")
	SlashCmdList.PUGUNITFRAMES("")
	Equal(ns.Options.category, M.settings.opened, "bare /pug opens the options")

	ns.db.units.player.width = 300
	SlashCmdList.PUGUNITFRAMES("reset player")
	Equal(232, ns.db.units.player.width)
	Equal(232, PugUnitFrames_player:GetWidth())
	ns.db.theme, ns.db.units.target.height = "night", 90
	SlashCmdList.PUGUNITFRAMES("  RESET   All ")
	Equal("slate", ns.db.theme)
	Equal(46, ns.db.units.target.height)
	SlashCmdList.PUGUNITFRAMES("reset everything")
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
	local frame = PugUnitFrames_player
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
---------------------------------------------------------------------------
-- The look: lettering, shadows, and the empty part of a bar
---------------------------------------------------------------------------
Test("the frames are lettered in the addon's own font, or the game's when the player says so", function()
	local ns = Login()
	local inter = ns.Style.FONTS.inter
	True(inter:find("PugUnitFrames\\Fonts\\Inter-SemiBold.ttf", 1, true), "the font is the addon's own file")
	Equal(inter, PugUnitFrames_player.texts.name.font[1], "name")
	Equal(inter, PugUnitFrames_player.texts.health.font[1], "numbers")
	Equal(inter, PugUnitFrames_player.cast.text.font[1], "cast bar")

	ns.db.font = "game"
	ns.Refresh()
	Equal(STANDARD_TEXT_FONT, PugUnitFrames_player.texts.name.font[1], "the game's font on request")
	Equal(0, #ns.GetProblems())
end)

Test("where the game's language is written in another script, its own font is used", function()
	M.locale = "koKR"
	local ns = Login()
	Equal("inter", ns.db.font, "the setting is left as it is")
	Equal(STANDARD_TEXT_FONT, PugUnitFrames_player.texts.name.font[1])
	Equal(0, #ns.GetProblems())
end)

Test("a font file the game cannot read is tried again, then reported once, and the game's font is used", function()
	M.unreadableFonts["Interface\\AddOns\\PugUnitFrames\\Fonts\\Inter-SemiBold.ttf"] = true
	local ns = Login()
	Equal(STANDARD_TEXT_FONT, PugUnitFrames_player.texts.name.font[1], "every text still has a font")
	Equal(STANDARD_TEXT_FONT, PugUnitFrames_player.texts.health.font[1])
	Equal(0, #ns.GetProblems(), "not given up at the first refusal: the game may still be loading the file")
	M.Advance(1)
	M.Advance(3)
	Equal(0, #ns.GetProblems(), "nor at the third")
	M.Advance(8)
	local problems = ns.GetProblems()
	Equal(1, #problems, "said once, however many texts there are")
	True(problems[1].text:find("Inter-SemiBold.ttf", 1, true), "and it names the file")
	ns.Refresh()
	M.Advance(30)
	Equal(1, #ns.GetProblems(), "and not again on the next layout")
	Equal(STANDARD_TEXT_FONT, PugUnitFrames_player.texts.name.font[1])
end)

Test("a font the game is slow to have ready is taken up when it arrives, and nothing is reported", function()
	local inter = "Interface\\AddOns\\PugUnitFrames\\Fonts\\Inter-SemiBold.ttf"
	M.unreadableFonts[inter] = true
	local ns = Login()
	Equal(STANDARD_TEXT_FONT, PugUnitFrames_player.texts.name.font[1], "the game's font in the meantime")
	M.Advance(1)
	M.unreadableFonts[inter] = nil
	M.Advance(3)
	Equal(inter, PugUnitFrames_player.texts.name.font[1], "the addon's own once the game has it")
	Equal(inter, PugUnitFrames_player.texts.health.font[1])
	Equal(0, #ns.GetProblems())
	False(Printed("went wrong"))
end)

Test("the empty part of a health bar is the bar's own colour under a dark veil", function()
	local ns = Login()
	local bar = PugUnitFrames_player.health
	local paladin, tone = M.CLASS_COLORS.PALADIN, ns.Style.theme.tone
	Near(paladin[1] * tone, bar.barColor[1], "the bar")
	Near(paladin[1] * tone, bar.trough.vertex[1], "the empty part, red")
	Near(paladin[3] * tone, bar.trough.vertex[3], "the empty part, blue")
	Equal(ns.Style.texture, bar.trough.texture, "drawn with the bar's texture")
	Near(ns.Style.theme.shade, bar.veil.color[4], "the veil is as thick as the theme's shade")
	Equal(ns.Style.theme.veil[3], bar.veil.color[3], "and of the theme's own dark tone")
	True(bar.veil.sublevel > bar.trough.sublevel, "the veil lies over the colour")

	-- A colour the game seals cannot be darkened by arithmetic: it is handed to both as it came.
	Target({ name = "Echo", class = "DRUID", isPlayer = true, playerControlled = false, inGroup = false, reaction = 4 })
	local target = PugUnitFrames_target.health
	Sealed(target.trough.vertex[1], "a sealed colour reaches the empty part sealed")
	Near(M.CLASS_COLORS.DRUID[1], Value(target.trough.vertex[1]))

	ns.db.units.player.color = "health"
	ns.Refresh()
	Sealed(bar.trough.vertex[1], "colouring by health reaches it too")
	Near(Value(bar.barColor[2]), Value(bar.trough.vertex[2]), "the same colour as the bar")
end)

Test("someone dead or offline has a grey bar, whatever colour they had", function()
	local ns = Login()
	Party(2)
	local frame = PartyButton(ns, 1)
	M.units.party1.dead = true
	M.Fire("UNIT_HEALTH", "party1")
	Near(ns.Style.REACTION.gone[1] * ns.Style.theme.tone, frame.health.trough.vertex[1], "dead")
	M.units.party1.dead = false
	M.Fire("UNIT_HEALTH", "party1")
	Near(M.CLASS_COLORS.WARRIOR[1] * ns.Style.theme.tone, frame.health.trough.vertex[1], "alive again, class colour again")
end)

Test("the empty part of a power bar is its colour, darkened by the theme's shade", function()
	local ns = Login()
	local bar = PugUnitFrames_player.power
	local left = 1 - ns.Style.theme.shade
	Near(bar.barColor[1] * left, bar.trough.vertex[1], "red")
	Near(bar.barColor[3] * left, bar.trough.vertex[3], "blue")

	-- A theme can darken with a colour of its own: Night's empty bars lean blue.
	ns.db.theme = "night"
	ns.Refresh()
	local night = ns.Style.THEMES.night
	Near(bar.barColor[3] * (1 - night.shade) + night.veil[3] * night.shade, bar.trough.vertex[3], "under Night's veil")
	Equal(night.veil[3], PugUnitFrames_player.health.veil.color[3], "and the health bar wears the same veil")
end)

Test("every plate has a shadow under it, at the button's own level, and it can be switched off", function()
	local ns = Login()
	local frame = PugUnitFrames_player
	local shadow = frame.body.shadow
	Equal(9, #shadow.pieces, "nine pieces")
	True(shadow.holder:IsShown(), "shown")
	Equal(frame:GetFrameLevel(), shadow.holder:GetFrameLevel(), "under the threat outline and the plate")
	True(shadow.holder:GetFrameLevel() < frame.body:GetFrameLevel())
	Equal(frame, shadow.holder.parent, "a child of the unit button, beside the plate")
	for index, piece in ipairs(shadow.pieces) do
		True(piece.texture:find("Shadow", 1, true), "piece " .. index .. " is cut from the shadow picture")
		Near(ns.Style.theme.shadow, piece.alpha, "at the theme's strength")
	end
	-- The corner pieces reach past the plate by the same distance on every side, shifted down.
	local corner = shadow.pieces[1].anchors[1]
	Equal("TOPLEFT", corner[1])
	Equal(frame.body, corner[2])
	Equal(-ns.Frame.SHADOW_REACH, corner[4], "out to the left")
	Equal(ns.Frame.SHADOW_REACH - ns.Frame.SHADOW_DROP, corner[5], "up, less the drop")
	-- The cast bar's own shadow comes and goes with the cast bar.
	local cast = frame.cast
	False(cast:IsShown(), "no cast")
	False(cast.shadow.holder:IsShown(), "so no shadow of a cast bar")
	Cast("player", { name = "Heal", icon = 3, start = M.now, length = 2, id = 4 })
	True(cast.shadow.holder:IsShown(), "it comes with the cast bar")
	M.units.player.cast = nil
	M.Fire("UNIT_SPELLCAST_STOP", "player")
	False(cast.shadow.holder:IsShown(), "and goes with it")

	ns.db.shadows = false
	ns.Refresh()
	False(shadow.holder:IsShown(), "off")
	ns.db.shadows = true
	ns.Refresh()
	True(shadow.holder:IsShown(), "and on again")
	Equal(0, #ns.GetProblems())
end)

Test("a cast bar has a bright edge on the end of its fill, and loses it when interrupted", function()
	local ns = Login()
	local cast = PugUnitFrames_player.cast
	local spark = cast.spark
	Equal("ADD", spark.blend, "added to what is under it")
	Equal(cast.bar:GetStatusBarTexture(), spark.anchors[1][2], "pinned to the fill the game moves")
	Equal("TOPRIGHT", spark.anchors[1][3], "at its end")
	Cast("player", { name = "Heal", icon = 3, start = M.now, length = 2, id = 4 })
	True(spark:IsShown(), "while casting")
	local r = ns.Style.CAST[1] * ns.Style.theme.tone
	Near(r * (1 - ns.Style.theme.shade), cast.trough.vertex[1], "behind the fill, the cast colour darkened")
	M.units.player.cast = nil
	M.Fire("UNIT_SPELLCAST_INTERRUPTED", "player")
	False(spark:IsShown(), "an interrupted cast is a full red bar with no edge")
	M.Advance(1)
	Cast("player", { name = "Smite", icon = 4, start = M.now, length = 2, id = 6 })
	True(spark:IsShown(), "and the next cast has it again")
end)

Test("every theme, texture and text setting can be put on", function()
	local ns = Login()
	Target(WithAuras(HOGGER, AURAS))
	for _, theme in ipairs(ns.Style.THEME_ORDER) do
		for _, texture in ipairs(ns.Style.TEXTURE_ORDER) do
			ns.db.theme, ns.db.texture = theme, texture
			ns.db.outline = not ns.db.outline
			ns.db.shadows = not ns.db.shadows
			ns.db.font = ns.db.font == "inter" and "game" or "inter"
			ns.Refresh()
			Equal(ns.Style.TEXTURES[texture], PugUnitFrames_player.health.barTexture.texture)
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
	local frame = PugUnitFrames_targettarget
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
	Equal(50, Value(PugUnitFrames_player.health.value), "health still drawn")
	Equal(1, #ns.GetProblems(), "kept for /pug status")
	True(ns.GetProblems()[1].text:find("the power bar broke", 1, true))
	True(Printed("/pug status"), "said once in chat")
	Equal(1, #M.luaErrors, "and handed to the game's own error handler, not swallowed")
	SlashCmdList.PUGUNITFRAMES("status")
	True(Printed("the power bar broke"))

	ns.Frame.RefreshAll()
	Equal(1, #ns.GetProblems(), "the same error is counted, not listed again")
	Equal(2, ns.GetProblems()[1].count)
	M.luaErrors = {} -- expected in this scenario
end)

Test("a refused call is kept with the errors", function()
	local ns = Login()
	M.Fire("ADDON_ACTION_BLOCKED", "PugUnitFrames", "Frame:SetPoint()")
	M.Fire("ADDON_ACTION_BLOCKED", "SomeoneElse", "Frame:Hide()")
	Equal(1, #ns.GetProblems())
	True(ns.GetProblems()[1].text:find("SetPoint", 1, true))
end)

Test("portraits are drawn by the game for the unit on show", function()
	local ns = Login()
	Equal(nil, PugUnitFrames_player.portrait, "none by default")
	ns.db.units.player.portrait = "left"
	ns.Refresh()
	local picture = PugUnitFrames_player.portrait
	True(picture:IsShown())
	Equal("player", picture.portraitOf)
	True(PugUnitFrames_player.barLeft > 40, "the bars make room for it")
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

---------------------------------------------------------------------------
-- What players of unit frames ran into: clicks, pings, a controller's menu
---------------------------------------------------------------------------
Test("the game's target frame is set aside and not hidden, so that a controller's target menu has a frame to belong to", function()
	local ns = Login()
	local aside = TargetFrame.parent
	True(aside ~= UIParent and aside:IsVisible(), "it sits on a frame of ours that is on screen")
	Equal(0, aside.alpha, "see-through")
	True(aside.scale <= 0.001, "and far too small to be seen or to be in the mouse's way")
	Equal(nil, next(TargetFrame.events), "its events are gone like the others'")
	True(ns.Blizzard.IsAway("target"))
	True(ns.Blizzard.IsKept("target"))
	False(ns.Blizzard.IsKept("player"), "the others are hidden")
	False(TargetFrame:IsVisible(), "no target: not there")

	Target(HOGGER)
	True(TargetFrame:IsVisible(), "with a target it is there, which is what keeps its menu open")
	Equal(PugUnitFrames_target, TargetFrame.anchors[1][2], "beside ours, where its menu then opens")
	M.SetCombat(true)
	Target(nil)
	False(TargetFrame:IsVisible(), "the game hides it in a fight too")
	Target(HOGGER)
	True(TargetFrame:IsVisible())
	Equal(0, #M.blocked)
	Equal(0, #ns.GetProblems())
end)

Test("losing a target sounds once: by the game's frame when it was set aside", function()
	Login()
	Target(HOGGER)
	Target(nil)
	Equal(2, #M.sounds, "picked, lost")
	Equal(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT, M.sounds[2])
end)

Test("a target frame of the game's that may not be given a new parent is hidden like the rest, and we play its sound", function()
	TargetFrame.aspects[Enum.ForbiddenAspect.ChangeParent] = true
	local ns = Login()
	False(ns.Blizzard.IsKept("target"))
	True(ns.Blizzard.IsAway("target"))
	Equal(UIParent, TargetFrame.parent, "left where it was")
	Target(HOGGER)
	False(TargetFrame:IsShown())
	Target(nil)
	Equal(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT, M.sounds[2], "ours")
	Equal(2, #M.sounds)
	Equal(0, #ns.GetProblems())
end)

Test("the game's frames can stay hidden also where ours is switched off", function()
	PugUnitFramesDB = { profiles = { Default = { hideAll = true, units = { player = { enabled = false } } } } }
	local ns = Login()
	False(PugUnitFrames_player:IsShown(), "ours is off")
	False(PlayerFrame:IsShown(), "and the game's does not come back for it")
	True(PlayerCastingBarFrame:IsShown(), "the game's cast bar stays: with ours off it is the only one")
	False(ns.Blizzard.NeedsReload())
end)

Test("a click with Shift, Ctrl or Alt held targets too, where the game alone would do nothing", function()
	local ns = Login()
	Target(HOGGER)
	M.Press(PugUnitFrames_target, "LeftButton")
	Equal("target", M.clicked.action, "a plain click targets directly")
	for _, held in ipairs({ "shift-", "ctrl-", "alt-" }) do
		M.Press(PugUnitFrames_target, "LeftButton", held)
		True(M.clicked, held .. "click does something")
		Equal("macro", M.clicked.action)
		Equal("/target [@mouseover,exists]", M.clicked.macro, "the unit under the mouse is the frame's")
	end
	M.Press(PugUnitFrames_target, "RightButton")
	Equal("togglemenu", M.clicked.action, "a plain right click opens the menu")
	M.Press(PugUnitFrames_target, "RightButton", "ctrl-")
	Equal(nil, M.clicked, "with a key held the game does not open it, and nothing else happens")

	Party(2)
	local button = PartyButton(ns, 2)
	M.Press(button, "LeftButton")
	Equal("target", M.clicked.action)
	Equal("party2", M.clicked.unit)
	M.Press(button, "LeftButton", "shift-")
	Equal("macro", M.clicked.action, "the members' buttons, which the game makes, do the same")
end)

Test("the game's ping key over a frame pings the frame's unit", function()
	local ns = Login()
	Party(1)
	Equal("GUID-Uther", M.PingOver(PugUnitFrames_player))
	Equal("GUID-Friend1", M.PingOver(PartyButton(ns, 1)), "a member's button, made by the game in or out of a fight")
	Target(HOGGER)
	True(IsSealed(M.PingOver(PugUnitFrames_target)), "a creature's identity stays sealed on the way: we never see it")
	Equal(0, #ns.GetProblems())
end)

---------------------------------------------------------------------------
-- Casts, power and health
---------------------------------------------------------------------------
Test("a cast the game never ends is unseen once its time is up, and put away when the unit is plainly not casting", function()
	Login()
	Target(HOGGER)
	local cast = PugUnitFrames_target.cast
	Cast("target", { name = "Aimed Shot", icon = 5, start = M.now, length = 3, id = 7 })
	True(cast:IsShown())
	M.Advance(1)
	Sealed(cast.alpha, "how long another unit's cast has left is sealed")
	Equal(1, Value(cast.alpha), "still running")
	Equal(1, Value(cast.shadow.holder.alpha), "its shadow with it")
	-- The cast is over and the game sends no word of it.
	M.Advance(2.5)
	Equal(0, Value(cast.alpha), "unseen")
	Equal(0, Value(cast.shadow.holder.alpha))
	M.units.target.cast = nil
	M.Advance(0.3)
	False(cast:IsShown(), "and put away")

	Cast("target", { name = "Shoot", icon = 6, start = M.now, length = 2, id = 8 })
	True(cast:IsShown())
	Equal(1, cast.alpha, "the next cast is drawn in full")
	Equal(0, #M.blocked)
end)

Test("the power number and the combo points move with every tick on the frames watched closely", function()
	local ns = Login("ROGUE")
	Target(HOGGER)
	M.units.player.power = 2500
	M.Fire("UNIT_POWER_FREQUENT", "player")
	Equal("2,500", Value(PugUnitFrames_player.texts.power.text))
	M.comboPoints = 2
	M.Fire("UNIT_POWER_FREQUENT", "player")
	Equal(2, Value(PugUnitFrames_target.points.bars[1].value))
	Party(1)
	False(PartyButton(ns, 1):IsEventRegistered("UNIT_POWER_FREQUENT"), "group frames are spared the stream")
end)

Test("a creature with no power to show has no power bar, and its health bar takes the room", function()
	local ns = Login()
	local frame = PugUnitFrames_target
	local function Bottom()
		return frame.health.anchors[2][5]
	end
	Target({ name = "Wizard", reaction = 2, canAttack = true, power = 50, powerMax = 100 })
	True(frame.power:IsShown(), "a creature with mana keeps its bar: how much it has is sealed, so it may have some")
	Equal(ns.db.units.target.powerHeight + 2, Bottom())

	-- Runs on rage, which a creature never gathers.
	Target({ name = "Brute", reaction = 2, canAttack = true, powerType = 1, powerToken = "RAGE", power = 0, powerMax = 100 })
	False(frame.power:IsShown())
	Equal(1, Bottom(), "the health bar reaches the plate's edge")
	Equal("", frame.texts.power.text, "and no number is written for it")

	-- Runs on mana in name only: the game says plainly that there is none.
	Target({ name = "Boar", reaction = 2, canAttack = true, powerless = true })
	False(frame.power:IsShown())

	-- A player who runs on rage has a bar worth watching.
	Target(Friend(1, { powerType = 1, powerToken = "RAGE", power = 30, powerMax = 100 }))
	True(frame.power:IsShown())
	Equal(ns.db.units.target.powerHeight + 2, Bottom())

	-- It changes in a fight too: the bars are not protected.
	M.SetCombat(true)
	Target({ name = "Brute", reaction = 2, canAttack = true, powerType = 1, powerToken = "RAGE", power = 0, powerMax = 100 })
	False(frame.power:IsShown())
	Equal(0, #M.blocked)
	M.SetCombat(false)

	ns.db.units.target.hideNoPower = false
	ns.Refresh()
	True(frame.power:IsShown(), "and it is a setting")
	Equal(ns.db.units.target.powerHeight + 2, Bottom())
end)

Test("a druid in a form keeps a strip of mana under the form's bar", function()
	Player("DRUID", { powerType = 1, powerToken = "RAGE", power = 20, powerMax = 100, mana = 900, manaMax = 1500 })
	local ns = Login()
	local strip = PugUnitFrames_player.power.mana
	True(strip:IsShown(), "bear form: rage on the bar, mana on the strip")
	Equal(900, Value(strip.value))
	Equal(1500, Value(strip.high))
	local _, _, blue = ns.Style.PowerColor("MANA")
	Near(blue, strip.barColor[3], "in mana's colour")
	Equal(20, Value(PugUnitFrames_player.power.value), "the bar itself is the form's")

	M.units.player.mana = 400
	M.Fire("UNIT_POWER_UPDATE", "player")
	Equal(400, Value(strip.value))

	-- Back in caster form the bar is mana and needs no strip.
	M.units.player.powerType, M.units.player.powerToken, M.units.player.power, M.units.player.powerMax = 0, "MANA", 400, 1500
	M.Fire("UNIT_DISPLAYPOWER", "player")
	False(strip:IsShown())
	Equal(nil, PugUnitFrames_target.power.mana, "only the player's frame has one")
end)

Test("a class with no mana has no mana strip", function()
	Player("WARRIOR", { powerType = 1, powerToken = "RAGE", power = 20, powerMax = 100 })
	Login()
	False(PugUnitFrames_player.power.mana:IsShown())
	True(PugUnitFrames_player.power:IsShown(), "the player's own bar is never put away")
end)

Test("someone else's kill is grey whatever colours the bar", function()
	PugUnitFramesDB = { profiles = { Default = { units = { target = { color = "health" } } } } }
	local ns = Login()
	local bar = PugUnitFrames_target.health
	local tapped = CopyTable(HOGGER)
	tapped.tapped = true
	Target(tapped)
	local r, g, b = ns.Style.Toned(ns.Style.REACTION.tapped)
	Near(r, bar.barColor[1])
	Near(g, bar.barColor[2])
	Near(b, bar.trough.vertex[3], "the empty part too")
	M.units.target.tapped = false
	M.Fire("UNIT_FACTION", "target")
	Sealed(bar.barColor[1], "free again, it is coloured by its health")
end)

Test("a shield shows as a band along the top of the health bar, on the health bar's scale", function()
	local ns = Login()
	local band = PugUnitFrames_player.health.absorb
	True(band:IsShown())
	Equal(0, Value(band.value), "no shield, nothing drawn")
	M.units.player.absorb = 1200
	M.Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
	Sealed(band.value, "the size of a shield is always sealed")
	Equal(1200, Value(band.value))
	Equal(5000, Value(band.high), "against full health")
	Equal("TOPLEFT", band.anchors[1][1], "from the bar's start, so it shows at full health too")

	M.units.player.dead = true
	M.Fire("UNIT_HEALTH", "player")
	Equal(0, band.value, "nobody shields the dead")
	M.units.player.dead = false

	ns.db.units.player.absorbs = false
	ns.Refresh()
	False(band:IsShown())
end)

Test("bars can fill to the left or upwards, and a bar can be turned round", function()
	local ns = Login()
	local cfg, bar = ns.db.units.player, PugUnitFrames_player.health
	Equal("HORIZONTAL", bar.orientation)
	False(bar.reverseFill)
	Equal("TOPLEFT", bar.heal.anchors[1][1], "healing on its way starts where the health ends")
	Equal("TOPRIGHT", bar.heal.anchors[1][3])

	cfg.fill = "left"
	ns.Refresh()
	True(bar.reverseFill)
	True(bar.heal.reverseFill, "the healing runs the same way")
	Equal("TOPRIGHT", bar.heal.anchors[1][1])
	Equal("TOPLEFT", bar.heal.anchors[1][3], "from the other end of the fill")
	True(PugUnitFrames_player.power.reverseFill, "and so does the power bar")
	True(bar.absorb.reverseFill)

	cfg.fill = "up"
	ns.Refresh()
	Equal("VERTICAL", bar.orientation)
	Equal("VERTICAL", bar.heal.orientation)
	Equal("BOTTOMLEFT", bar.heal.anchors[1][1])
	False(PugUnitFrames_player.power.reverseFill, "the power bar, a strip along the bottom, fills as ever")

	-- Turned round: a dark bar, and the class colour where health is missing.
	cfg.fill, cfg.invert = "right", true
	ns.Refresh()
	False(bar.veil:IsShown(), "the colour behind the bar is bare")
	local r, g, b = ns.Style.Readable(ns.Style.Toned(M.CLASS_COLORS.PALADIN))
	Near(r, bar.trough.vertex[1], "the class colour, behind")
	True(bar.barColor[1] < 0.25 and bar.barColor[2] < 0.25, "the bar itself dark")
	cfg.color = "health"
	ns.Refresh()
	Sealed(bar.trough.vertex[1], "by health as well, the sealed colour goes behind")
	True(type(bar.barColor[1]) == "number" and bar.barColor[1] < 0.25, "and the bar stays dark")
	Equal(0, #ns.GetProblems())
end)

Test("a rare creature is marked beside its level", function()
	Login()
	Target({ name = "Mazzranache", level = 9, reaction = 2, canAttack = true, classification = "rare" })
	Equal("9R", PugUnitFrames_target.texts.level.text)
	M.units.target.classification = "rareelite"
	M.Fire("UNIT_CLASSIFICATION_CHANGED", "target")
	Equal("9R+", PugUnitFrames_target.texts.level.text)
	Target(HOGGER)
	Equal("11+", PugUnitFrames_target.texts.level.text, "an elite as before")
end)

---------------------------------------------------------------------------
-- Marks, a pet's mood, the member targeted, fading
---------------------------------------------------------------------------
Test("a group member's part shows as a mark, and nobody's outside the group", function()
	local ns = Login()
	Party(2)
	M.units.party1.role = "HEALER"
	M.Fire("PLAYER_ROLES_ASSIGNED")
	local first, second = PartyButton(ns, 1).marks.role, PartyButton(ns, 2).marks.role
	True(first:IsShown())
	True(first.texture:find("Mark-Healer", 1, true))
	False(second:IsShown(), "no part taken, no mark")
	M.units.party2.role = "TANK"
	M.Fire("GROUP_ROSTER_UPDATE")
	True(second.texture:find("Mark-Tank", 1, true))

	local stranger = Friend(7, { inGroup = false, playerControlled = false, role = "TANK" })
	Target(stranger)
	False(PugUnitFrames_target.marks.role:IsShown(), "sealed for someone outside the group: counted as none")
	Equal(0, #ns.GetProblems())
end)

Test("the party can be put in order of the parts its members play", function()
	local ns = Login()
	Party(3)
	M.units.party1.role, M.units.party2.role, M.units.party3.role = "DAMAGER", "TANK", "HEALER"
	ns.db.units.party.byRole = true
	ns.Refresh()
	Equal("party2", PartyButton(ns, 1).unit, "the tank first")
	Equal("party3", PartyButton(ns, 2).unit, "then the healer")
	Equal("party1", PartyButton(ns, 3).unit)
	ns.db.units.party.byRole = false
	ns.Refresh()
	Equal("party1", PartyButton(ns, 1).unit, "and back to the order they joined in")
end)

Test("someone marked for fighting other players carries a flag in their side's colour", function()
	Login()
	local flag = PugUnitFrames_player.marks.pvp
	Equal(0, flag.alpha, "not marked, no flag")
	M.units.player.pvp, M.units.player.faction = true, "Alliance"
	M.Fire("UNIT_FACTION", "player")
	Equal(1, flag.alpha)
	True(flag.vertex[3] > flag.vertex[1], "blue for the Alliance")

	-- A guard: whether a creature is marked comes back sealed, and is drawn all the same.
	Target({ name = "Orgrimmar Grunt", reaction = 2, canAttack = true, pvp = true, faction = "Horde" })
	local theirs = PugUnitFrames_target.marks.pvp
	Sealed(theirs.alpha)
	Equal(1, Value(theirs.alpha))
	True(theirs.vertex[1] > theirs.vertex[3], "red for the Horde")

	M.units.target.freeForAll, M.units.target.faction = true, nil
	M.Fire("UNIT_FACTION", "target")
	Equal(1, theirs.alpha, "everyone's enemy")
	True(theirs.vertex[1] > 0.9 and theirs.vertex[2] > 0.6, "in amber")
end)

Test("a hunter sees how the pet feels beside its frame", function()
	Player("HUNTER")
	M.SetUnit("pet", { name = "Wolf", playerControlled = true, reaction = 5 })
	M.petHappiness = 1
	local ns = Login()
	local face = PugUnitFrames_pet.mood
	True(face:IsShown())
	True(face.texture:find("Mood-Unhappy", 1, true), "unhappy: time to feed it")
	M.petHappiness = 3
	M.Fire("UNIT_HAPPINESS", "pet")
	True(face.texture:find("Mood-Happy", 1, true))
	M.petHappiness = nil
	M.Fire("UNIT_PET", "player")
	False(face:IsShown(), "a pet without a mood has no face")
	ns.db.units.pet.happiness = false
	ns.Refresh()
	False(PugUnitFrames_pet.active.Mood)
end)

Test("only a hunter's pet frame has a mood", function()
	Player("WARLOCK")
	M.SetUnit("pet", { name = "Imp", playerControlled = true, reaction = 5 })
	M.petHappiness = 3
	Login()
	Equal(nil, PugUnitFrames_pet.mood)
end)

Test("the group member the player has targeted is outlined", function()
	local ns = Login()
	Party(2)
	local first, second = PartyButton(ns, 1).highlight, PartyButton(ns, 2).highlight
	Equal(0, first.alpha)
	Target(Friend(2))
	Equal(1, second.alpha, "the one targeted")
	Equal(0, first.alpha)
	M.sealComparisons = true
	Target(Friend(1))
	Sealed(first.alpha, "where the game seals the comparison it is drawn all the same")
	Equal(1, Value(first.alpha))
	Equal(0, Value(second.alpha))
	Equal(nil, PugUnitFrames_player.highlight, "single frames have no such line")
	ns.db.units.party.highlight = false
	ns.Refresh()
	False(first:IsShown())
end)

Test("every frame takes the overall opacity, and the player's frame can step back when nothing is going on", function()
	PugUnitFramesDB = { profiles = { Default = { alpha = 0.8, units = { player = { calm = 0.5 } } } } }
	local ns = Login()
	local frame = PugUnitFrames_player
	Near(0.4, frame.alpha, "no fight, no target: the overall opacity, faded")
	Target(HOGGER)
	Near(0.8, frame.alpha, "a target brings it back")
	Near(0.8, PugUnitFrames_target.alpha, "a frame that does not fade is at the overall opacity")
	Target(nil)
	Near(0.4, frame.alpha)
	frame.scripts.OnEnter(frame)
	Near(0.8, frame.alpha, "the mouse over it brings it back")
	frame.scripts.OnLeave(frame)
	Near(0.4, frame.alpha)
	M.SetCombat(true)
	Near(0.8, frame.alpha, "and so does a fight, from its first moment")
	M.SetCombat(false)
	Near(0.4, frame.alpha)
	Equal(0, #M.blocked, "a protected frame's alpha may change in a fight")

	ns.db.units.player.calm = 1
	ns.Refresh()
	Near(0.8, frame.alpha, "switched off, it stays in full")
	Party(1)
	Near(0.8, PartyButton(ns, 1).alpha, "group frames too")
end)

Test("the player's frame can stay away while in a group, also when the group forms in a fight", function()
	PugUnitFramesDB = { profiles = { Default = { units = { player = { hideInGroup = true } } } } }
	local ns = Login()
	True(PugUnitFrames_player:IsShown(), "alone: there")
	Party(2)
	M.UpdateUnitWatch()
	False(PugUnitFrames_player:IsShown(), "in a party: away")
	M.SetCombat(true)
	Party(0)
	M.UpdateUnitWatch()
	True(PugUnitFrames_player:IsShown(), "the game brings it back in a fight")
	Equal(0, #M.blocked)

	-- Switched off in a fight: waits for its end, then the frame simply follows its unit again.
	ns.db.units.player.hideInGroup = false
	ns.Refresh()
	M.SetCombat(false)
	Party(2)
	M.UpdateUnitWatch()
	True(PugUnitFrames_player:IsShown())
	Equal(0, #M.blocked)
	Equal(0, #ns.GetProblems())
end)

---------------------------------------------------------------------------
-- Icons
---------------------------------------------------------------------------
Test("stack counts are outlined, time left can be a number, and buffs can be the player's own only", function()
	local ns = Login()
	local mine = { id = 23, icon = 123, helpful = true, stacks = 2, length = 30, mine = true }
	local auras = CopyTable(AURAS)
	auras[#auras + 1] = mine
	Target(WithAuras(HOGGER, auras))
	local icons = ShownIcons(PugUnitFrames_target)
	Equal(6, #icons)
	Equal("OUTLINE", icons[1].count.font[3], "readable on a bright icon, whatever the text setting")
	Equal("", PugUnitFrames_target.texts.name.font[3], "the rest of the lettering keeps its soft shadow")
	True(icons[1].cooldown.hideNumbers, "the sweep alone, unless asked")
	Equal("NumberFontNormalSmall", icons[1].cooldown.countdownFont)

	ns.db.auraTimers = true
	ns.db.units.target.myBuffs = true
	ns.Refresh()
	icons = ShownIcons(PugUnitFrames_target)
	False(icons[1].cooldown.hideNumbers, "the game writes the time left on the icon")
	Equal(4, #icons, "three debuffs, and of three buffs the one that is the player's")
	Equal(123, icons[4].icon.texture)
end)
