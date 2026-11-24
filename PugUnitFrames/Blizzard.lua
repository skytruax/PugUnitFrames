local ADDON, ns = ...

-- Has the game's own unit frames step aside for ours.
--
-- A frame of the game's is put away by taking its events from it, hiding it, and making it the
-- child of a frame that is never shown, so that nothing brings it back. That cannot be undone
-- without loading the interface again, which is why the options ask for a reload when one of
-- these settings is switched off. Only possible out of combat.
--
-- When this happens matters. Hiding a frame that is on screen runs that frame's own "I am being
-- hidden" code, and run on an addon's account that code leaves the addon's mark on whatever it
-- writes; the game then refuses protected actions that later depend on it ("Interface action
-- failed because of an AddOn"), which players with a controller meet first. So the frames are put
-- away as this addon loads, before the game has brought any of them up, and with their events
-- gone they never come up. Nothing of the game's is hooked, and its menus are never touched.
local Blizzard = {}
ns.Blizzard = Blizzard

local nowhere = CreateFrame("Frame")
nowhere:Hide()

local away = {} -- [frame] = true once put away

local NO_EVENT_CHANGES = Enum.ForbiddenAspect.EventRegistrations
local NO_NEW_PARENT = Enum.ForbiddenAspect.ChangeParent

-- Takes the events from a frame and everything on it, so the game's code for it stops running.
-- Some of the game's frames are closed to addons, wholly (forbidden) or in part (a forbidden
-- aspect: its secure aura rows may not have their events touched). Those are left as they are:
-- they sit on a frame that is hidden, which is enough to keep them off the screen.
local function Silence(frame)
	if frame:IsForbidden() then
		return
	end
	if not frame:HasAnyForbiddenAspects(NO_EVENT_CHANGES) then
		frame:UnregisterAllEvents()
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		Silence(child)
	end
end

local function PutAway(frame)
	if not frame or away[frame] or frame:IsForbidden() then
		return
	end
	away[frame] = true
	Silence(frame)
	frame:Hide()
	if not frame:HasAnyForbiddenAspects(NO_NEW_PARENT) then
		frame:SetParent(nowhere)
	end
end

-- What stands aside for each of ours. A name the client does not have is skipped.
local THEIRS = {
	player = { "PlayerFrame" },
	target = { "TargetFrame", "ComboFrame" },
	focus = { "FocusFrame" },
	pet = { "PetFrame" },
	party = { "PartyFrame", "CompactPartyFrame" },
	raid = { "CompactRaidFrameContainer" },
}

-- Whether the game's frame for `key` should be out of the way: the player asked for that and
-- our own frame for it is in use.
local function Wanted(key)
	local db = ns.db
	if not db.hide[key] then
		return false
	end
	if key == "castbar" then
		return db.units.player.enabled and db.units.player.castbar
	end
	return db.units[key].enabled
end
Blizzard.Wanted = Wanted

-- Whether the game's frame (or frames) for `key` have been put away this session.
function Blizzard.IsAway(key)
	if key == "castbar" then
		return away[PlayerCastingBarFrame] or false
	end
	for _, name in ipairs(THEIRS[key]) do
		if away[_G[name]] then
			return true
		end
	end
	return false
end

-- True if something has been put away that the settings no longer ask for: only a reload brings
-- it back.
function Blizzard.NeedsReload()
	for key, names in pairs(THEIRS) do
		if not Wanted(key) then
			for _, name in ipairs(names) do
				if away[_G[name]] then
					return true
				end
			end
		end
	end
	return not Wanted("castbar") and away[PlayerCastingBarFrame] or false
end

-- Call out of combat. Safe to call again: what is already away is left alone, and frames the
-- game only makes later (its raid-style party frames) are caught the next time.
function Blizzard.Apply()
	for key, names in pairs(THEIRS) do
		if Wanted(key) then
			for _, name in ipairs(names) do
				PutAway(_G[name])
			end
		end
	end
	if Wanted("castbar") then
		PutAway(PlayerCastingBarFrame)
	end
end

ns.On("GROUP_ROSTER_UPDATE", function()
	if ns.IsBuilt() then
		ns.RunOutOfCombat("blizzard", Blizzard.Apply)
	end
end)
