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

Shim(_G, "UnitHealthMissing", function(unit)
	return UnitHealthMax(unit) - UnitHealth(unit)
end)
