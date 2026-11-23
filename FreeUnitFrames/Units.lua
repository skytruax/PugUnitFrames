local ADDON, ns = ...

-- The frames that each show one unit: the player, the target, the target's target, the focus
-- and the pet.
local Units = {}
ns.Units = Units

local Frame = ns.Frame

local SINGLES = { "player", "target", "targettarget", "focus", "pet" }
local frames = {} -- [kind] = the frame

local TARGET_OF_TARGET_POLL = 0.25 -- seconds; the game sends no events for a target's target

function Units.Get(kind)
	return frames[kind]
end

function Units.Kinds()
	return SINGLES
end

-- Puts a frame where its settings say, at their size, and has it come and go with its unit.
-- Only possible out of combat.
local function Place(frame, cfg)
	frame:ClearAllPoints()
	-- The settings hold the position in screen units; a scaled frame measures in its own.
	frame:SetPoint("CENTER", UIParent, "CENTER", cfg.x / cfg.scale, cfg.y / cfg.scale)
	frame:SetSize(cfg.width, cfg.height)
	frame:SetScale(cfg.scale)
	if cfg.enabled then
		-- From here on the game shows the frame while the unit exists and hides it when not,
		-- also in the middle of a fight.
		RegisterUnitWatch(frame)
	else
		UnregisterUnitWatch(frame)
		frame:Hide()
	end
end

-- Call out of combat (ns.Refresh and the login code see to that).
function Units.ApplyLayout()
	for _, kind in ipairs(SINGLES) do
		local frame = frames[kind]
		if frame then
			Place(frame, ns.db.units[kind])
			Frame.Layout(frame)
		end
	end
end

-- Call out of combat, once.
function Units.Spawn()
	-- Other addons that bind spells to clicks on unit frames look in this table for frames.
	_G.ClickCastFrames = _G.ClickCastFrames or {}

	for _, kind in ipairs(SINGLES) do
		local frame = CreateFrame("Button", "FreeUnitFrames_" .. kind, UIParent, "SecureUnitButtonTemplate")
		frame:SetFrameStrata("LOW")
		frame:SetAttribute("unit", kind)
		frame:SetAttribute("*type1", "target")     -- a click targets the unit
		frame:SetAttribute("*type2", "togglemenu") -- a right click opens its menu
		frame:RegisterForClicks("AnyUp")
		Frame.Build(frame, kind)
		_G.ClickCastFrames[frame] = true
		frames[kind] = frame
	end
	Frame.SetPolling(frames.targettarget, TARGET_OF_TARGET_POLL)
	Units.ApplyLayout()
end

---------------------------------------------------------------------------
-- When a frame comes to show someone else
---------------------------------------------------------------------------
-- A frame that is already up does not hear when its unit becomes a different creature (a new
-- target, a new pet): these events say so.
local function Redraw(kind)
	local frame = frames[kind]
	if frame and frame:IsVisible() then
		Frame.Refresh(frame)
	end
end

-- The sounds of picking a target and of losing one are played by the game's own target frame.
-- With that frame put away nobody plays them, so we do: the same sounds, in the same cases.
local function PlayTargetSound()
	if not ns.Blizzard.IsAway("target") then
		return
	end
	if UnitExists("target") then
		if C_PlayerInteractionManager.IsReplacingUnit() then
			return
		elseif UnitIsEnemy("target", "player") then
			C_Sound.PlaySound(SOUNDKIT.IG_CREATURE_AGGRO_SELECT)
		elseif UnitIsFriend("player", "target") then
			C_Sound.PlaySound(SOUNDKIT.IG_CHARACTER_NPC_SELECT)
		else
			C_Sound.PlaySound(SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT)
		end
	elseif not IsTargetLoose() then -- a target the game picked by itself comes and goes quietly
		C_Sound.PlaySound(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT, nil, true)
	end
end

ns.On("PLAYER_TARGET_CHANGED", function()
	PlayTargetSound()
	Redraw("target")
	Redraw("targettarget")
end)

ns.On("PLAYER_FOCUS_CHANGED", function()
	Redraw("focus")
end)

ns.On("PLAYER_ENTERING_WORLD", function()
	Frame.RefreshAll()
end)

local watcher = CreateFrame("Frame")
watcher:RegisterUnitEvent("UNIT_PET", "player")
watcher:RegisterUnitEvent("UNIT_TARGET", "target")
watcher:SetScript("OnEvent", function(_, event)
	if event == "UNIT_PET" then
		ns.Try(Redraw, "pet")
	else
		ns.Try(Redraw, "targettarget")
	end
end)
