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
--
-- One frame is not hidden but set aside: the target frame. The game's controller mode opens the
-- target's menu (inspect, trade, follow) as that frame's own menu (TargetFrame_OpenMenu, called
-- by Blizzard_GamepadActionBars), and a menu closes the moment the frame it belongs to is no
-- longer on screen (Blizzard_Menu). Hidden, the frame would take that menu away from everyone
-- who plays with a controller. So it stays: without its events, on a frame of ours that is
-- see-through and a thousandth of its size, where it can be neither seen nor clicked, and shown
-- by the game while there is a target, in a fight too, exactly when it always was.
local Blizzard = {}
ns.Blizzard = Blizzard

local nowhere = CreateFrame("Frame")
nowhere:Hide()

local aside = CreateFrame("Frame", nil, UIParent)
aside:SetPoint("CENTER")
aside:SetSize(1, 1)
aside:SetScale(0.001)
aside:SetAlpha(0)

local away = {} -- [frame] = true once put away or set aside
local kept = {} -- [frame] = true for one that was set aside

local NO_EVENT_CHANGES = Enum.ForbiddenAspect.EventRegistrations
local NO_NEW_PARENT = Enum.ForbiddenAspect.ChangeParent

-- Takes the events from a frame and everything on it, so the game's code for it stops running.
-- Some of the game's frames are closed to addons, wholly (forbidden) or in part (a forbidden
-- aspect: its secure aura rows may not have their events touched). Those are left as they are:
-- they sit on a frame that is hidden or set aside unseen, which is enough to keep them off the
-- screen.
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

-- Sets a frame aside (see the top of this file). One that may not be given a new parent is hidden
-- like the others: its menu is then lost to a controller, and nothing else.
local function SetAside(frame)
	if not frame or away[frame] or frame:IsForbidden() then
		return
	end
	if frame:HasAnyForbiddenAspects(NO_NEW_PARENT) then
		PutAway(frame)
		return
	end
	away[frame] = true
	kept[frame] = true
	Silence(frame)
	frame:SetParent(aside)
	-- From here on the game shows it while its unit exists and hides it when not.
	RegisterUnitWatch(frame)
end

-- A frame set aside is moved to the right edge of ours, so that its menu, which the game opens
-- to its right, comes up beside the frame the player is looking at. The game's layout code may
-- move it again later; then the menu comes up where that code put the frame, and still works.
local function Beside(frame, ours)
	if kept[frame] and ours then
		frame:ClearAllPoints()
		frame:SetPoint("RIGHT", ours, "RIGHT", 0, 0)
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

-- The frames that are set aside instead of hidden.
local SET_ASIDE = { TargetFrame = true }

-- Whether the game's frame for `key` should be out of the way: the player asked for that, and
-- our own frame for it is in use or the player wants the game's gone regardless (the "also where
-- mine is switched off" setting: someone who shows themselves in the party frames wants no player
-- frame at all). The game's cast bar is the exception: with ours off it is the only one there is.
local function Wanted(key)
	local db = ns.db
	if not db.hide[key] then
		return false
	end
	if key == "castbar" then
		return db.units.player.enabled and db.units.player.castbar
	end
	return db.units[key].enabled or db.hideAll
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

-- Whether the game's frame for `key` was set aside, not hidden: it is still there, unseen.
function Blizzard.IsKept(key)
	for _, name in ipairs(THEIRS[key] or {}) do
		if kept[_G[name]] then
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
				if SET_ASIDE[name] then
					SetAside(_G[name])
					Beside(_G[name], ns.Units.Get(key))
				else
					PutAway(_G[name])
				end
			end
		end
	end
	if Wanted("castbar") then
		PutAway(PlayerCastingBarFrame)
	end
end

local function ApplyLater()
	if ns.IsBuilt() then
		ns.RunOutOfCombat("blizzard", Blizzard.Apply)
	end
end

ns.On("GROUP_ROSTER_UPDATE", ApplyLater)
-- The game's layout code (Edit Mode) puts its frames back where its own settings say when a
-- layout is applied: the one set aside is then moved beside ours again.
ns.On("EDIT_MODE_LAYOUTS_UPDATED", ApplyLater)
ns.On("PLAYER_ENTERING_WORLD", ApplyLater)
