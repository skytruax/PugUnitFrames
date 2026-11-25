-- Stand-ins for client functions the simulator does not have (tools/sim/run.sh loads this file
-- into the scratch copy of the addon, never into the addon you ship).
--
-- Each one exists in the Forever client (tools/sim/lab/tools/api_lint.py lists them as SIM GAP)
-- and is given the plainest behaviour that fits Blizzard's description of it. The simulator does
-- not seal values, so these work on plain ones. What the addon does with sealed values is the
-- business of tools/tests, where the stand-in for the client does seal them.
local function Shim(holder, name, fn)
	if holder[name] == nil then
		holder[name] = fn
	end
end

Shim(C_CurveUtil, "EvaluateColorValueFromBoolean", function(flag, whenTrue, whenFalse)
	if flag then
		return whenTrue
	end
	return whenFalse
end)

C_Secrets = C_Secrets or {}
Shim(C_Secrets, "HasSecretRestrictions", function() return false end)
Shim(C_Secrets, "ShouldUnitHealthMaxBeSecret", function() return false end)
Shim(C_Secrets, "ShouldUnitPowerBeSecret", function() return false end)

C_StringUtil = C_StringUtil or {}
Shim(C_StringUtil, "TruncateWhenZero", function(number)
	local whole = math.floor(number)
	if whole == 0 then
		return ""
	end
	return tostring(whole)
end)

Shim(C_UnitAuras, "GetAuraApplicationDisplayCount", function(unit, auraInstanceID, minimum, maximum)
	local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
	local count = aura and aura.applications or 0
	if count < (minimum or 2) then
		return ""
	end
	if maximum and count > maximum then
		return "*"
	end
	return tostring(count)
end)

Shim(C_UnitAuras, "GetAuraDuration", function(unit, auraInstanceID)
	local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
	local duration = C_DurationUtil.CreateDuration()
	if aura and aura.duration and aura.duration > 0 and aura.expirationTime then
		duration:SetTimeFromEnd(aura.expirationTime, aura.duration)
	end
	return duration
end)

Shim(_G, "GetTotemDuration", function(slot)
	local _, _, start, length = GetTotemInfo(slot)
	local duration = C_DurationUtil.CreateDuration()
	if start and length and length > 0 then
		duration:SetTimeFromStart(start, length)
	end
	return duration
end)

-- Nothing comes back when there is no pet that has a mood, which is the simulator's case.
C_PetInfo = C_PetInfo or {}
Shim(C_PetInfo, "GetPetHappiness", function() end)

Shim(_G, "UnitHealthMissing", function(unit)
	return UnitHealthMax(unit) - UnitHealth(unit)
end)

-- A player may have the game leave their own surname off. The simulator has no such setting:
-- shown, which is how the game starts out.
C_PlayerInfo = C_PlayerInfo or {}
Shim(C_PlayerInfo, "ShouldDisplaySurname", function() return true end)

-- The simulator has the game's calculator for healing on its way and shields, but its calculator
-- hands a shield back whole, whatever it was told to keep the shield within. Blizzard documents
-- what each rule keeps it within (Enum.UnitDamageAbsorbClampMode); this does that, and passes
-- everything else on to the simulator's own.
do
	local MODES = Enum.UnitDamageAbsorbClampMode
	local create, fill = CreateUnitHealPredictionCalculator, UnitGetDetailedHealPrediction

	local function KeepsWithin()
		local probe = create()
		probe:SetDamageAbsorbClampMode(MODES.MissingHealth)
		probe:SetPredictedValues({ health = 50, healthMax = 100, totalIncomingHeals = 0, totalIncomingHealsFromHealer = 0,
			totalDamageAbsorbs = 80, totalHealAbsorbs = 0 })
		return (probe:GetDamageAbsorbs()) == 50
	end

	if create and fill and MODES and not KeepsWithin() then
		local inside = setmetatable({}, { __mode = "k" }) -- our calculator -> the simulator's

		function CreateUnitHealPredictionCalculator()
			local inner, mode = create(), MODES.MissingHealth
			local calculator = setmetatable({}, { __index = function(_, name)
				local member = inner[name]
				if type(member) ~= "function" then
					return member
				end
				return function(_, ...)
					return member(inner, ...)
				end
			end })
			function calculator:SetDamageAbsorbClampMode(newMode)
				mode = newMode
				inner:SetDamageAbsorbClampMode(newMode)
			end
			function calculator:GetDamageAbsorbs()
				local values = inner:GetPredictedValues()
				local health, most = values.health or 0, values.healthMax or 0
				local shield, heals = values.totalDamageAbsorbs or 0, values.totalIncomingHeals or 0
				local room = most
				if mode == MODES.MissingHealth then
					room = math.max(0, most - health - heals)
				elseif mode == MODES.MissingHealthWithoutIncomingHeals then
					room = math.max(0, most - health)
				end
				return math.min(shield, room), shield > room
			end
			inside[calculator] = inner
			return calculator
		end

		function UnitGetDetailedHealPrediction(unit, healer, calculator)
			return fill(unit, healer, inside[calculator] or calculator)
		end
	end
end
