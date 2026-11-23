local ADDON, ns = ...

-- The group button template (Templates.xml) reaches the addon through this global, and so can a
-- player with /run. Blizzard code never reads it.
_G.FreeUnitFrames = ns

ns.name = ADDON
ns.version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.ART = "Interface\\AddOns\\" .. ADDON .. "\\Art\\"

local L = ns.L

---------------------------------------------------------------------------
-- Output
---------------------------------------------------------------------------
local PREFIX = "|cff7fd4a8Free Unit Frames|r: "
function ns.Print(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	print(PREFIX .. table.concat(parts, " "))
end

---------------------------------------------------------------------------
-- Errors
---------------------------------------------------------------------------
-- The game hides addon errors unless the player has switched them on, so an error while a frame
-- is being drawn would end that update without anyone seeing why. Code run through ns.Try still
-- hands every error to the game's own error handler, exactly as an uncaught one would be. On top
-- of that the first one is said in chat and they are kept for /freeuf status, so a problem can be
-- reported even with errors hidden. One failing handler or frame does not stop the next.
local MAX_PROBLEMS = 8 -- different errors kept; repeats of a kept one are only counted
local problems = {}    -- { text = "...", count = n }, in order of first appearance
local problemByText = {}

local function Record(text)
	local problem = problemByText[text]
	if problem then
		problem.count = problem.count + 1
	elseif #problems < MAX_PROBLEMS then
		problem = { text = text, count = 1 }
		problems[#problems + 1] = problem
		problemByText[text] = problem
		if #problems == 1 then
			ns.Print("|cffff4040" .. L["Something went wrong inside Free Unit Frames, so a frame may not be updating. Type /freeuf status to see the error."] .. "|r")
		end
	end
end

local function OnError(message)
	Record(tostring(message))
	geterrorhandler()(message)
	return message
end

-- Runs fn(...). Returns true and what it returned, or false after reporting what went wrong.
function ns.Try(fn, ...)
	return xpcall(fn, OnError, ...)
end

function ns.GetProblems()
	return problems
end

-- Runs fn in a while, with its errors reported like any other's.
function ns.After(seconds, fn)
	C_Timer.After(seconds, function()
		ns.Try(fn)
	end)
end

-- The game refuses some calls from addons, in a fight above all. That is not an error in Lua:
-- the call simply does nothing and the game announces it with one of these events, which nobody
-- sees. They are kept with the errors, so that a frame that quietly stays put can be explained.
local function OnBlocked(_, addon, what)
	if addon == ADDON then
		Record(("The game refused to let Free Unit Frames call %s."):format(tostring(what)))
	end
end

---------------------------------------------------------------------------
-- Events: modules register handlers here, Core owns the one event frame for game-wide events.
-- (Each unit frame listens for its own unit's events itself; see Frame.lua.)
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers = {}

function ns.On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		eventFrame:RegisterEvent(event)
	end
	table.insert(handlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	for _, fn in ipairs(handlers[event]) do
		ns.Try(fn, event, ...)
	end
end)

ns.On("ADDON_ACTION_BLOCKED", OnBlocked)
ns.On("ADDON_ACTION_FORBIDDEN", OnBlocked)

---------------------------------------------------------------------------
-- Combat: unit frames are protected, so they can only be moved, sized, shown or re-pointed at
-- another unit by addon code while the player is out of combat.
---------------------------------------------------------------------------
local pending, order = {}, {}

-- Runs fn now, or as soon as combat ends. A later call with the same key replaces the earlier one.
-- Returns true when it ran right away.
function ns.RunOutOfCombat(key, fn)
	if InCombatLockdown() then
		if not pending[key] then
			order[#order + 1] = key
		end
		pending[key] = fn
		return false
	end
	fn()
	return true
end

ns.On("PLAYER_REGEN_ENABLED", function()
	local keys = order
	order = {}
	for _, key in ipairs(keys) do
		local fn = pending[key]
		pending[key] = nil
		ns.Try(fn)
	end
end)

---------------------------------------------------------------------------
-- Saved settings
---------------------------------------------------------------------------
-- FreeUnitFramesDB = {                      -- shared by every character on the account
--     schema   = 1,
--     profiles = { [name] = profile },     -- every setting lives in a profile (Defaults.lua)
-- }
-- FreeUnitFramesCharDB = { profile = name } -- per character: which profile it uses
--
-- The per-character file is what ties a character to its profile, so the addon never has to ask
-- the game for the character's name: that is one of the answers the game can seal, and a reload
-- in the middle of a fight would then have nothing to look the profile up by.
local SCHEMA = 1
local DEFAULT_PROFILE = "Default"
local MAX_PROFILE_NAME = 32

-- A profile name is shown in chat and in the options, and typed by the player: plain and short.
function ns.IsProfileName(name)
	return type(name) == "string" and #name >= 1 and #name <= MAX_PROFILE_NAME and not name:find("[%c|]")
end

-- Saved variables are plain text the player can edit, and they outlive versions of this addon,
-- so the files are checked on the way in and anything that is not what it should be is replaced.
local function LoadDatabase()
	local saved = FreeUnitFramesDB
	if type(saved) ~= "table" then
		saved = {}
	end
	if type(saved.profiles) ~= "table" then saved.profiles = {} end
	saved.schema = SCHEMA
	for name, profile in pairs(saved.profiles) do
		if not ns.IsProfileName(name) or type(profile) ~= "table" then
			saved.profiles[name] = nil
		else
			ns.Defaults.Sanitize(profile)
		end
	end

	local own = FreeUnitFramesCharDB
	if type(own) ~= "table" then
		own = {}
	end
	if not ns.IsProfileName(own.profile) then
		own.profile = DEFAULT_PROFILE
	end

	FreeUnitFramesDB = saved
	FreeUnitFramesCharDB = own
	ns.saved = saved
	ns.own = own
	ns.UseProfile(own.profile)
end

-- Makes the named profile this character's, creating it from the defaults if it is new.
function ns.UseProfile(name)
	local saved = ns.saved
	if not saved.profiles[name] then
		saved.profiles[name] = ns.Defaults.Fresh()
	end
	ns.own.profile = name
	ns.profileName = name
	ns.db = saved.profiles[name]
end

function ns.GetProfileNames()
	local names = {}
	for name in pairs(ns.saved.profiles) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local built = false

function ns.IsBuilt()
	return built
end

-- Brings every frame in line with the settings: called after a setting changes, a profile is
-- switched or imported. Sizes and positions wait for the end of a fight; the rest is immediate.
function ns.Refresh()
	if not built then
		return
	end
	ns.Style.Apply()
	ns.RunOutOfCombat("layout", function()
		ns.Units.ApplyLayout()
		ns.Group.ApplyLayout()
		ns.Blizzard.Apply()
		ns.Movers.Sync()
	end)
	ns.Frame.RefreshAll()
end

ns.On("ADDON_LOADED", function(_, name)
	if name == ADDON then
		LoadDatabase()
		-- The game's own frames step aside now, before any of them has come up (see Blizzard.lua).
		ns.RunOutOfCombat("blizzard", ns.Blizzard.Apply)
	end
end)

ns.On("PLAYER_LOGIN", function()
	ns.Style.Apply()
	-- A reload in the middle of a fight starts in combat: the frames are then made when it ends.
	ns.RunOutOfCombat("build", function()
		ns.Units.Spawn()
		ns.Group.Spawn()
		ns.Blizzard.Apply()
		built = true
		ns.Frame.RefreshAll()
	end)
	ns.Options.Register()
end)

---------------------------------------------------------------------------
-- /freeuf
---------------------------------------------------------------------------
-- For /freeuf status: what the client says about sealed ("secret") values right now.
local function DescribeSealing()
	if not C_Secrets.HasSecretRestrictions() then
		return L["this client does not seal values"]
	end
	local parts = {}
	parts[#parts + 1] = C_Secrets.ShouldUnitHealthMaxBeSecret("player") and L["maximum health sealed"] or L["maximum health open"]
	parts[#parts + 1] = C_Secrets.ShouldUnitPowerBeSecret("player") and L["power sealed"] or L["power open"]
	parts[#parts + 1] = C_Secrets.ShouldAurasBeSecret() and L["auras sealed"] or L["auras open"]
	parts[#parts + 1] = C_Secrets.ShouldUnitIdentityBeSecret("target") and L["target identity sealed"] or L["target identity open"]
	return table.concat(parts, ", ")
end

local function Status()
	local _, build, _, interface = GetBuildInfo()
	ns.Print(("%s %s. %s %s (%s)."):format(L["Version"], ns.version, L["Client"], tostring(interface), tostring(build)))
	ns.Print(("%s: %s. %s: %s."):format(L["Profile"], ns.profileName, L["Frames"],
		built and (ns.db.locked and L["locked"] or L["unlocked"]) or L["not built yet (waiting for the fight to end)"]))
	ns.Print(L["Sealed values"] .. ": " .. DescribeSealing() .. ".")
	if #problems == 0 then
		ns.Print(L["No errors recorded."])
		return
	end
	ns.Print(("|cffff4040%s|r"):format(L["Errors recorded this session:"]))
	for index, problem in ipairs(problems) do
		ns.Print(("%d. (x%d) %s"):format(index, problem.count, problem.text))
	end
end

local function Help()
	ns.Print(L["Commands:"])
	ns.Print("  /freeuf  -  " .. L["open the options"])
	ns.Print("  /freeuf unlock  -  " .. L["show the handles and drag the frames"])
	ns.Print("  /freeuf lock  -  " .. L["put the handles away"])
	ns.Print("  /freeuf reset <" .. table.concat(ns.Defaults.KINDS, "|") .. "|all>  -  " .. L["put a frame back where and how it started"])
	ns.Print("  /freeuf profile  -  " .. L["copy your settings out, or paste a set in"])
	ns.Print("  /freeuf status  -  " .. L["version, what the game is sealing, and any errors"])
end

local function Reset(what)
	if what == "all" then
		ns.Defaults.Reset(ns.db)
		ns.Print(L["Every frame is back to its starting place and settings."])
	elseif ns.Defaults.UNITS[what] then
		ns.Defaults.Reset(ns.db, what)
		ns.Print(L["Back to its starting place and settings:"] .. " " .. ns.Defaults.Label(what) .. ".")
	else
		ns.Print(L["Reset what?"] .. " /freeuf reset <" .. table.concat(ns.Defaults.KINDS, "|") .. "|all>")
		return
	end
	ns.Refresh()
	if InCombatLockdown() then
		ns.Print(L["You are in combat: sizes and positions change when the fight ends."])
	end
end

local function OnSlash(message)
	local command, rest = (message or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	if command == "" or command == "options" or command == "config" then
		ns.Options.Open()
	elseif command == "unlock" or command == "move" then
		ns.Movers.SetLocked(false)
	elseif command == "lock" then
		ns.Movers.SetLocked(true)
	elseif command == "reset" then
		Reset(rest)
	elseif command == "profile" or command == "profiles" then
		ns.Profiles.ShowWindow()
	elseif command == "status" then
		Status()
	else
		Help()
	end
end

SLASH_FREEUNITFRAMES1 = "/freeuf"
SLASH_FREEUNITFRAMES2 = "/freeunitframes"
SlashCmdList["FREEUNITFRAMES"] = function(message)
	ns.Try(OnSlash, message)
end
