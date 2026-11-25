local ADDON, ns = ...

-- A creature that one of the player's quests needs carries Questie's icon for what is wanted of
-- it (kill it, loot it, talk to it): the icon Questie puts on the creature's nameplate.
--
-- Questie is another addon. It knows the quests and the creatures; this addon only asks it which
-- icon it would show, through the function its own nameplate code calls, and draws that. Nothing
-- of Questie's is copied here, and without Questie installed there is nothing to draw.
--
-- Questie can also hang the icon on the game's own target frame. With that frame put away by
-- this addon the icon was lost; this is where it comes back, on the target, its target and the
-- focus.
--
-- Where the game restricts addons (in a dungeon) it does not say which creature a unit is, and
-- there is no icon: Questie's own are gone there too.
local Frame, Sealed = ns.Frame, ns.Sealed

local Quest = { name = "Quest" }

-- The game says the quest log changed; Questie works a change through a moment after that.
-- Coming into the world it takes Questie longer still to have its quests ready.
Quest.worldEvents = { "QUEST_LOG_UPDATE", "PLAYER_ENTERING_WORLD" }

local LOOK_AGAIN = 1.5   -- seconds after the last change of the quest log before asking Questie once more
local AFTER_ENTERING = 8 -- and after coming into the world (a login, a reload with a target kept)
local ASK_EVERY = 1      -- seconds between questions about the same creature, on a frame that is redrawn several times a second

function Quest.Wanted(cfg)
	return cfg.quest or false
end

-- Asks Questie for its icon for the creature with this GUID. Nothing comes back when it has
-- none, and when Questie is not installed (or is a version without this function).
local function QuestieIcon(guid)
	local loader = _G.QuestieLoader
	if type(loader) ~= "table" or type(loader.ImportModule) ~= "function" then
		return nil
	end
	local nameplates = loader:ImportModule("QuestieNameplate")
	if type(nameplates) ~= "table" or type(nameplates.GetIcon) ~= "function" then
		return nil
	end
	local icon = nameplates.GetIcon(guid)
	-- A texture is named by its path or by a file's number.
	if type(icon) == "string" or type(icon) == "number" then
		return icon
	end
	return nil
end

function Quest.Create(frame)
	-- Above the bars, the words and the icons, with the other marks.
	local holder = CreateFrame("Frame", nil, frame.body)
	holder:SetAllPoints(frame.body)
	holder:SetFrameLevel(frame.body:GetFrameLevel() + 8)
	local icon = holder:CreateTexture(nil, "OVERLAY")
	icon:Hide()
	frame.quest = { holder = holder, icon = icon }
end

function Quest.Layout(frame, cfg, on)
	local quest = frame.quest
	quest.holder:SetShown(on)
	quest.guid, quest.askedAt = nil, nil
	if not on then
		return
	end
	-- It rides the top edge in the right corner, a little larger than the marks beside it
	-- (Marks.lua leaves the corner to it).
	local small = Frame.MarkSize(cfg)
	local size = small + 2
	quest.icon:ClearAllPoints()
	quest.icon:SetSize(size, size)
	quest.icon:SetPoint("CENTER", frame.body, "TOPRIGHT", -small * 0.5, 0)
end

local function Show(frame, unit)
	local quest = frame.quest
	local guid = Sealed.CreatureGUID(unit)
	quest.guid, quest.askedAt = guid, GetTime()
	local art = guid and QuestieIcon(guid)
	if art then
		quest.icon:SetTexture(art)
		quest.icon:Show()
	else
		quest.icon:Hide()
	end
end

local function LookAgain(frame)
	if frame.unit and frame.active.Quest and UnitExists(frame.unit) then
		Show(frame, frame.unit)
	end
end

-- Asks once more a moment after the last call: changes of the quest log come in bursts, and
-- the look that counts is the one after the last of them.
local function LookLater(frame)
	local quest = frame.quest
	quest.lookAt = GetTime() + LOOK_AGAIN
	if quest.waiting then
		return
	end
	quest.waiting = true
	local function Look()
		local left = quest.lookAt - GetTime()
		if left > 0.05 then
			ns.After(left, Look)
			return
		end
		quest.waiting = false
		LookAgain(frame)
	end
	ns.After(LOOK_AGAIN, Look)
end

function Quest.Update(frame, unit, event)
	local quest = frame.quest
	if event == nil then
		-- A frame that is redrawn several times a second (the target's target) does not ask
		-- Questie about the same creature each time.
		if frame.pollEvery and quest.askedAt and GetTime() - quest.askedAt < ASK_EVERY and Sealed.CreatureGUID(unit) == quest.guid then
			return
		end
		Show(frame, unit)
		return
	end
	Show(frame, unit)
	if event == "PLAYER_ENTERING_WORLD" then
		ns.After(AFTER_ENTERING, function()
			LookAgain(frame)
		end)
	else
		LookLater(frame)
	end
end

Frame.Register(Quest)
