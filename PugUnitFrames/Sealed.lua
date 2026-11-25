local ADDON, ns = ...

-- Sealed values, and the one place in this addon that touches them.
--
-- On this client much of what a unit frame shows comes back to an addon sealed: a "secret" value
-- that can be stored and handed to the game's own drawing functions, and nothing else. An addon
-- may not compare one, calculate with it, test it in an "if", index a table with it or join it to
-- a string; any of those is an error on the spot. Health is always sealed. Maximum health, power,
-- names, classes, auras, casts, threat and range are sealed some of the time (in a fight, in an
-- encounter, in a battleground: the game decides, and Blizzard's API documentation marks every
-- answer that can be: SecretReturns and SecretWhen... in Blizzard_APIDocumentationGenerated).
--
-- So nothing here ever looks at such a value. Each function below fetches what a widget needs and
-- hands it straight to a widget method Blizzard documents as accepting sealed values from addons
-- (SecretArguments = "AllowedWhenTainted"): a bar's value, a text, a texture, an alpha, a colour.
-- The widget draws it; this addon never learns what it was. Where a decision is unavoidable
-- (is there a cast at all? a raid mark?) the value is first asked "are you sealed?" and is only
-- compared when the answer is no.
--
-- The rest of the addon calls these functions and never the game functions behind them. The test
-- suite checks that (tools/tests/run.py, "only Sealed.lua reads values that can be sealed").
local Sealed = {}
ns.Sealed = Sealed

local issecretvalue = issecretvalue
local canaccesstable = canaccesstable

local IMMEDIATE = Enum.StatusBarInterpolation.Immediate
local EASE_OUT = Enum.StatusBarInterpolation.ExponentialEaseOut
local ELAPSED = Enum.StatusBarTimerDirection.ElapsedTime
local REMAINING = Enum.StatusBarTimerDirection.RemainingTime

-- True for a value that is not sealed and is nil. A sealed value is never asked what it is.
local function IsPlainNil(value)
	return not issecretvalue(value) and value == nil
end

-- Turns the 0-1 share the game works out into 0-100 for a text. The game does the arithmetic.
local PERCENT = C_CurveUtil.CreateCurve()
PERCENT:SetType(Enum.LuaCurveType.Linear)
PERCENT:AddPoint(0, 0)
PERCENT:AddPoint(1, 100)

-- Turns a length of time into "is there any": 1 while some is left, 0 when none is. A span of
-- time (a cast, a totem's life) can be put through it by the game, and what comes out, sealed or
-- not, is an alpha: something drawn with it is there while the time runs and gone when it is up.
local TIME_LEFT = C_CurveUtil.CreateCurve()
TIME_LEFT:SetType(Enum.LuaCurveType.Step)
TIME_LEFT:AddPoint(0, 0)
TIME_LEFT:AddPoint(0.001, 1)

---------------------------------------------------------------------------
-- Health
---------------------------------------------------------------------------
function Sealed.HealthToBar(bar, unit, smooth)
	bar:SetMinMaxValues(0, UnitHealthMax(unit))
	bar:SetValue(UnitHealth(unit), smooth and EASE_OUT or IMMEDIATE)
end

-- Colours a bar by how full the unit's health is, through a colour curve (Style.lua builds them:
-- red when nearly empty, through yellow, to green when full). `also`, when given, is a texture
-- that takes the same colour (the empty part of the bar, behind it); `bar` may be left out when
-- only that texture is to be coloured. Returns whether the game gave a colour.
function Sealed.HealthShareToBarColor(bar, unit, colorCurve, also)
	local color = UnitHealthPercent(unit, true, colorCurve)
	if not IsPlainNil(color) and canaccesstable(color) then
		if bar then
			bar:SetStatusBarColor(color:GetRGB())
		end
		if also then
			also:SetVertexColor(color:GetRGB())
		end
		return true
	end
	return false
end

-- style: "value" 1,234,567 | "short" 1234K | "percent" 87% | "both" short and percent |
--        "max" short / maximum | "deficit" what is missing, and nothing when nothing is
-- The short form is the game's own (AbbreviateLargeNumbers, what its default frames write): a
-- number of up to five digits in full, a longer one in thousands or millions.
function Sealed.HealthToText(text, unit, style)
	if style == "value" then
		text:SetText(BreakUpLargeNumbers(UnitHealth(unit)))
	elseif style == "short" then
		text:SetText(AbbreviateLargeNumbers(UnitHealth(unit)))
	elseif style == "percent" then
		text:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, PERCENT))
	elseif style == "both" then
		text:SetFormattedText("%s  %.0f%%", AbbreviateLargeNumbers(UnitHealth(unit)), UnitHealthPercent(unit, true, PERCENT))
	elseif style == "max" then
		text:SetFormattedText("%s / %s", AbbreviateLargeNumbers(UnitHealth(unit)), AbbreviateLargeNumbers(UnitHealthMax(unit)))
	elseif style == "deficit" then
		text:SetText(C_StringUtil.TruncateWhenZero(UnitHealthMissing(unit)))
	else
		text:SetText("")
	end
end

-- The healing on its way to the unit, as a bar that shares the health bar's scale.
function Sealed.IncomingHealsToBar(bar, unit)
	local amount = UnitGetIncomingHeals(unit)
	if IsPlainNil(amount) then
		amount = 0
	end
	bar:SetMinMaxValues(0, UnitHealthMax(unit))
	bar:SetValue(amount)
end

-- What is soaking up damage before the unit's health does (a priest's shield), as a bar that
-- shares the health bar's scale: as long as the shield is large against maximum health.
function Sealed.AbsorbsToBar(bar, unit)
	bar:SetMinMaxValues(0, UnitHealthMax(unit))
	bar:SetValue(UnitGetTotalAbsorbs(unit))
end

---------------------------------------------------------------------------
-- Power (mana, rage, energy, focus)
---------------------------------------------------------------------------
function Sealed.PowerToBar(bar, unit, powerType, smooth)
	bar:SetMinMaxValues(0, UnitPowerMax(unit, powerType))
	bar:SetValue(UnitPower(unit, powerType), smooth and EASE_OUT or IMMEDIATE)
end

-- Whether the unit plainly has none of a power: true only when the game says so in a number
-- this addon may read. The most a unit can hold is sealed for anything a player does not
-- control; how much it holds now is sealed only when the unit has that power at all, so an
-- unsealed nought there means there is none to show. Anything sealed counts as "has some".
function Sealed.HasNoPower(unit, powerType)
	local most = UnitPowerMax(unit, powerType)
	if not issecretvalue(most) then
		return most == 0
	end
	local now = UnitPower(unit, powerType)
	if not issecretvalue(now) then
		return now == 0
	end
	return false
end

function Sealed.PowerToText(text, unit, powerType, style)
	if style == "value" then
		text:SetText(BreakUpLargeNumbers(UnitPower(unit, powerType)))
	elseif style == "short" then
		text:SetText(AbbreviateLargeNumbers(UnitPower(unit, powerType)))
	elseif style == "percent" then
		text:SetFormattedText("%.0f%%", UnitPowerPercent(unit, powerType, false, PERCENT))
	elseif style == "max" then
		text:SetFormattedText("%s / %s", AbbreviateLargeNumbers(UnitPower(unit, powerType)), AbbreviateLargeNumbers(UnitPowerMax(unit, powerType)))
	else
		text:SetText("")
	end
end

-- Combo points on the target, shown on a row of small bars: bar i runs from i-1 to i, so it is
-- full once there are i points and empty before. The bars' ranges are set where they are made.
function Sealed.ComboPointsToBars(bars)
	local points = GetComboPoints("player", "target")
	for _, bar in ipairs(bars) do
		bar:SetValue(points)
	end
end

---------------------------------------------------------------------------
-- Who the unit is
---------------------------------------------------------------------------
-- On this client a character has a first name and a surname, and the game hands them over as
-- two answers: the second, which other clients use for a realm, is the surname here. The game's
-- own frames join the two with this separator (NameUtil.FormatUnitNameForDisplay, in the
-- Blizzard_FrameXMLUtil of this client).
local SEPARATORS = Constants and Constants.CharacterNameSeparatorConsts
local SURNAME_SEPARATOR = SEPARATORS and SEPARATORS.CHARACTERNAME_SURNAME_SEPARATOR or " "

-- Whether the unit is the player's own character, as far as the game will say.
local function IsOwnCharacter(unit)
	if unit == "player" then
		return true
	end
	local same = UnitIsUnit(unit, "player")
	return not issecretvalue(same) and same == true
end

-- Writes the unit's name on a text. how:
--   "full"     first name and surname on one line, as the game's own frames write them
--   "stacked"  the surname on a line of its own under the first name (a narrow plate)
--   "first"    the first name alone
-- Only a character has a surname, and a character's two names are never sealed. The name the
-- game does seal is a creature's, which has one part: sealed, it goes to the text untouched.
function Sealed.NameToText(text, unit, how)
	local name, surname = UnitName(unit)
	if how == "first" or issecretvalue(name) or issecretvalue(surname) or name == nil or surname == nil or surname == "" then
		text:SetText(name)
		return
	end
	-- A player can ask the game not to show their own surname. Its own player frame then leaves
	-- it off, and so does this one.
	if IsOwnCharacter(unit) and RegionalUniqueNamesEnabled() and not C_PlayerInfo.ShouldDisplaySurname() then
		text:SetText(name)
		return
	end
	text:SetText(name .. (how == "stacked" and "\n" or SURNAME_SEPARATOR) .. surname)
end

-- The unit's class colour as r, g, b, or nothing when the client will not say. The numbers can
-- themselves be sealed (the class of something that is neither a player's nor in the group is):
-- the fourth result says whether they are plain numbers. Sealed ones may only be handed on to a
-- colour setter.
function Sealed.ClassColor(unit)
	local _, classFile = UnitClass(unit)
	if IsPlainNil(classFile) then
		return nil
	end
	local color = C_ClassColor.GetClassColor(classFile)
	if IsPlainNil(color) or not canaccesstable(color) then
		return nil
	end
	local r, g, b = color:GetRGB()
	return r, g, b, not issecretvalue(r)
end

-- The player's own class as the game's token for it ("SHAMAN"), or nil if the game seals it.
function Sealed.PlayerClassFile()
	local _, classFile = UnitClass("player")
	if issecretvalue(classFile) then
		return nil
	end
	return classFile
end

-- The unit's GUID if it is a creature of the world and the game lets that be read, else nil.
-- The game seals a creature's GUID where it restricts addons (in a dungeon, say); a player's or
-- a pet's is of no use to whoever asks which creature this is.
function Sealed.CreatureGUID(unit)
	local guid = UnitGUID(unit)
	if issecretvalue(guid) or type(guid) ~= "string" then
		return nil
	end
	local kind = guid:match("^(%a+)%-")
	if kind == "Creature" or kind == "Vehicle" then
		return guid
	end
	return nil
end

-- Shows a mark while the unit leads its group.
function Sealed.LeaderToAlpha(region, unit)
	region:SetAlphaFromBoolean(UnitIsGroupLeader(unit), 1, 0)
end

-- Shows a mark while the unit is flagged for fighting other players.
function Sealed.PvPToAlpha(region, unit)
	region:SetAlphaFromBoolean(UnitIsPVP(unit), 1, 0)
end

-- The part a group member has taken: "TANK", "HEALER" or "DAMAGER", or nil for none. The game
-- seals it for anyone outside the group, who then counts as having none.
function Sealed.Role(unit)
	local role = UnitGroupRolesAssigned(unit)
	if issecretvalue(role) or role == "NONE" then
		return nil
	end
	return role
end

-- Shows a region while two unit names stand for the same creature (a group member who is the
-- player's target). The game answers nothing for pairs it will not compare.
function Sealed.SameUnitToAlpha(region, unit, other)
	local same = UnitIsUnit(unit, other)
	if IsPlainNil(same) then
		region:SetAlpha(0)
		return
	end
	region:SetAlphaFromBoolean(same, 1, 0)
end

---------------------------------------------------------------------------
-- Range, raid marks, threat
---------------------------------------------------------------------------
-- Fades a region while a group member is out of range. The game answers with two booleans: is the
-- unit in range, and could that be checked at all. Unchecked counts as in range.
function Sealed.RangeToAlpha(region, unit, nearAlpha, farAlpha)
	local inRange, checked = UnitInRange(unit)
	local whenChecked = C_CurveUtil.EvaluateColorValueFromBoolean(inRange, nearAlpha, farAlpha)
	region:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(checked, whenChecked, nearAlpha))
end

-- The raid mark (star, circle, ...) on a unit: one cell of the game's own sheet of eight.
local MARK_ROWS = RAID_TARGET_TEXTURE_ROWS or 4
local MARK_COLUMNS = RAID_TARGET_TEXTURE_COLUMNS or 4
function Sealed.RaidMarkToTexture(texture, unit)
	local index = GetRaidTargetIndex(unit)
	if IsPlainNil(index) then
		texture:Hide()
		return
	end
	texture:SetSpriteSheetCell(index, MARK_ROWS, MARK_COLUMNS)
	texture:Show()
end

-- How much the unit is being attacked, from 0 (not at all) to 3 (everything is on it), shown on
-- three stacked outlines: outline i runs from i-1 to i, so it is drawn once the level reaches i.
function Sealed.ThreatToBars(bars, unit)
	local level = UnitThreatSituation(unit)
	if IsPlainNil(level) then
		level = 0
	end
	for _, bar in ipairs(bars) do
		bar:SetValue(level)
	end
end

---------------------------------------------------------------------------
-- Casting
---------------------------------------------------------------------------
-- Puts the unit's cast or channel on a cast bar: the timer on parts.bar, the spell's name on
-- parts.text, its icon on parts.icon, and parts.shield shown while it cannot be interrupted.
-- Returns whether there is one, and the game's id for it (never sealed), which says later whether
-- a "cast ended" event is about the cast on show or about an older one.
function Sealed.CastToParts(parts, unit)
	local channel = false
	local duration = UnitCastingDuration(unit)
	if IsPlainNil(duration) then
		duration = UnitChannelDuration(unit)
		channel = true
		if IsPlainNil(duration) then
			return false
		end
	end

	local label, icon, shielded, castBarID, _
	if channel then
		_, label, icon, _, _, _, shielded, _, _, _, castBarID = UnitChannelInfo(unit)
	else
		_, label, icon, _, _, _, _, shielded, _, castBarID = UnitCastingInfo(unit)
	end
	if IsPlainNil(shielded) then
		shielded = false
	end

	-- A cast fills up; a channel drains.
	parts.bar:SetTimerDuration(duration, IMMEDIATE, channel and REMAINING or ELAPSED)
	parts.text:SetText(label)
	parts.icon:SetTexture(icon)
	parts.shield:SetAlphaFromBoolean(shielded, 1, 0)
	return true, castBarID
end

-- Looks at a cast that is on show again: returns false if the unit is plainly not casting any
-- more, and otherwise makes the regions see-through once the cast's time is up. The game does not
-- always say that a cast has ended (a party member out of sight; players report a hunter's Aimed
-- Shot staying up for good, on the game's own frames too), and a bar that waited for the word
-- would then stand there until the next cast.
function Sealed.CastTimeLeftToAlpha(regions, unit)
	local duration = UnitCastingDuration(unit)
	if IsPlainNil(duration) then
		duration = UnitChannelDuration(unit)
		if IsPlainNil(duration) then
			return false
		end
	end
	local alpha = duration:EvaluateRemainingDuration(TIME_LEFT)
	for _, region in ipairs(regions) do
		region:SetAlpha(alpha)
	end
	return true
end

---------------------------------------------------------------------------
-- Auras (buffs and debuffs)
---------------------------------------------------------------------------
local SORT_DEFAULT = Enum.UnitAuraSortRule.Default
local SORT_NORMAL = Enum.UnitAuraSortDirection.Normal

-- The ids of the unit's auras that pass the filter, in the game's own order, at most `limit`.
-- The ids are plain numbers. filter is one of Blizzard's filter strings, such as "HELPFUL" or
-- "HARMFUL|PLAYER".
function Sealed.AuraIDs(unit, filter, limit)
	return C_UnitAuras.GetUnitAuraInstanceIDs(unit, filter, limit, SORT_DEFAULT, SORT_NORMAL)
end

-- A colour object handed back by the game that this addon may take the numbers out of (the
-- numbers themselves can still be sealed, and are only ever handed on).
local function IsReadableColor(color)
	return not IsPlainNil(color) and canaccesstable(color)
end

-- Draws one aura on an icon button: button.icon, button.count (how many stacks), button.cooldown
-- (the sweep of its time left) and, when a curve is given, button.edge tinted by what kind of
-- debuff it is (magic, curse, disease, poison). Returns false if the aura is gone.
function Sealed.AuraToButton(button, unit, auraInstanceID, kindColorCurve)
	local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
	if IsPlainNil(aura) or not canaccesstable(aura) then
		return false
	end
	local duration = C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
	if IsPlainNil(duration) then
		return false
	end
	button.icon:SetTexture(aura.icon)
	button.count:SetText(C_UnitAuras.GetAuraApplicationDisplayCount(unit, auraInstanceID, 2, 99))
	button.cooldown:SetCooldownFromDurationObject(duration, true)
	if kindColorCurve then
		local color = C_UnitAuras.GetAuraDispelTypeColor(unit, auraInstanceID, kindColorCurve)
		if IsReadableColor(color) then
			button.edge:SetVertexColor(color:GetRGB())
		end
	end
	return true
end

-- Tints every region in the list by the kind of the given debuff. Returns whether it could.
function Sealed.AuraKindToColor(regions, unit, auraInstanceID, kindColorCurve)
	local color = C_UnitAuras.GetAuraDispelTypeColor(unit, auraInstanceID, kindColorCurve)
	if not IsReadableColor(color) then
		return false
	end
	local r, g, b = color:GetRGB()
	for _, region in ipairs(regions) do
		region:SetVertexColor(r, g, b)
	end
	return true
end

---------------------------------------------------------------------------
-- Totems
---------------------------------------------------------------------------
-- Draws totem slot `slot` on an icon button (button.icon, button.cooldown), visible while a
-- totem stands there with time left on it. Returns whether one does, or nil when the game will
-- not say (in a fight everything about a totem is sealed).
--
-- "Is there a totem" alone is not enough. In a fight the game answers yes for the slot of every
-- element the shaman has learnt, standing or not, and an empty one differs only in having no
-- time on it: the game's own totem frame shows a slot only when its time is above nought, and
-- players of another addon met black squares that stayed until the fight ended. So the time
-- left decides as well, through a curve when it may not be looked at.
function Sealed.TotemToButton(button, slot)
	local standing, _, _, length, icon = GetTotemInfo(slot)
	if IsPlainNil(standing) then
		button:SetAlpha(0)
		return false
	end
	local duration = GetTotemDuration(slot)
	button.icon:SetTexture(icon)
	button.cooldown:SetCooldownFromDurationObject(duration, true)
	if not issecretvalue(standing) and not issecretvalue(length) then
		local up = standing and length > 0
		button:SetAlpha(up and 1 or 0)
		return up
	end
	local left = duration:EvaluateRemainingDuration(TIME_LEFT)
	button:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(standing, left, 0))
	return nil
end

---------------------------------------------------------------------------
-- Three old functions the documentation says nothing about
---------------------------------------------------------------------------
-- Blizzard's generated API documentation does not describe these, so it does not say whether
-- their answers can be sealed. The game's own raid frames call all three. They are asked here
-- and treated as if they could be: a sealed answer counts as no answer.

-- "ready", "notready" or "waiting" while a ready check is up, else nil.
function Sealed.ReadyCheckAnswer(unit)
	local answer = GetReadyCheckStatus(unit)
	if issecretvalue(answer) then
		return nil
	end
	return answer
end

function Sealed.IsBeingResurrected(unit)
	local coming = UnitHasIncomingResurrection(unit)
	if issecretvalue(coming) then
		return false
	end
	return coming
end

-- How many are in the group, the player included; 0 alone. Unknown counts as a full raid.
function Sealed.GroupSize()
	local members = GetNumGroupMembers()
	if issecretvalue(members) then
		return 40
	end
	return members
end
