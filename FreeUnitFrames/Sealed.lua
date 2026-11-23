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

---------------------------------------------------------------------------
-- Health
---------------------------------------------------------------------------
function Sealed.HealthToBar(bar, unit, smooth)
	bar:SetMinMaxValues(0, UnitHealthMax(unit))
	bar:SetValue(UnitHealth(unit), smooth and EASE_OUT or IMMEDIATE)
end

-- Colours a bar by how full the unit's health is, through a colour curve (Style.lua builds them:
-- red when nearly empty, through yellow, to green when full).
function Sealed.HealthShareToBarColor(bar, unit, colorCurve)
	local color = UnitHealthPercent(unit, true, colorCurve)
	if not IsPlainNil(color) and canaccesstable(color) then
		bar:SetStatusBarColor(color:GetRGB())
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

---------------------------------------------------------------------------
-- Power (mana, rage, energy, focus)
---------------------------------------------------------------------------
function Sealed.PowerToBar(bar, unit, powerType, smooth)
	bar:SetMinMaxValues(0, UnitPowerMax(unit, powerType))
	bar:SetValue(UnitPower(unit, powerType), smooth and EASE_OUT or IMMEDIATE)
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
function Sealed.NameToText(text, unit)
	local name = UnitName(unit)
	text:SetText(name)
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

-- Shows a mark while the unit leads its group.
function Sealed.LeaderToAlpha(region, unit)
	region:SetAlphaFromBoolean(UnitIsGroupLeader(unit), 1, 0)
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
-- totem stands there.
function Sealed.TotemToButton(button, slot)
	local standing, _, _, _, icon = GetTotemInfo(slot)
	if IsPlainNil(standing) then
		button:SetAlpha(0)
		return
	end
	button.icon:SetTexture(icon)
	button.cooldown:SetCooldownFromDurationObject(GetTotemDuration(slot), true)
	button:SetAlphaFromBoolean(standing, 1, 0)
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
