local ADDON, ns = ...

-- Profiles: named sets of settings, and a way to carry one out of the game and back in as text.
local Profiles = {}
ns.Profiles = Profiles

local L = ns.L
local Defaults = ns.Defaults

-- An exported profile starts with this, so text that is something else is turned away at once.
local MARK = "PUGUF1:"
local MAX_IMPORT = 60000 -- characters; a real export is a few hundred

---------------------------------------------------------------------------
-- Text out, text in
---------------------------------------------------------------------------
function Profiles.Export(profile)
	local packed = C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(profile))
	return MARK .. C_EncodingUtil.EncodeBase64(packed)
end

local function Unpack(encoded)
	local packed = C_EncodingUtil.DecodeBase64(encoded)
	if not packed or packed == "" then
		error("not base64")
	end
	local serialized = C_EncodingUtil.DecompressString(packed)
	if not serialized or serialized == "" then
		error("cannot be unpacked")
	end
	return C_EncodingUtil.DeserializeCBOR(serialized)
end

-- Reads text made by Export. Returns a checked profile, or nil and why not.
-- The text comes from outside (a forum post, a friend), so nothing in it is trusted: it is only
-- ever read as data, and the result goes through the same check as the saved file does.
function Profiles.Import(text)
	if type(text) ~= "string" then
		return nil, L["There is nothing to import."]
	end
	text = text:gsub("%s+", "")
	if text == "" then
		return nil, L["There is nothing to import."]
	end
	if #text > MAX_IMPORT then
		return nil, L["That text is far too long to be a profile."]
	end
	if text:sub(1, #MARK) ~= MARK then
		return nil, L["That is not a Pug Unit Frames profile: it should start with PUGUF1:"]
	end
	-- Damaged text makes the game's decoders raise an error. Here that is an answer, not a
	-- fault: the player is told what the game said, and nothing is changed.
	local ok, result = pcall(Unpack, text:sub(#MARK + 1))
	if not ok then
		return nil, L["That profile text is damaged and could not be read:"] .. " " .. tostring(result)
	end
	if type(result) ~= "table" then
		return nil, L["That profile text is damaged and could not be read:"] .. " " .. L["it does not hold settings."]
	end
	return Defaults.Sanitize(result)
end

---------------------------------------------------------------------------
-- Named profiles
---------------------------------------------------------------------------
-- A name not in use yet, made from `base`.
local function FreeName(base)
	local profiles = ns.saved.profiles
	if not profiles[base] then
		return base
	end
	local number = 2
	while profiles[base .. " " .. number] do
		number = number + 1
	end
	return base .. " " .. number
end

-- Makes a new profile holding `settings` (a checked profile table) and switches to it.
function Profiles.Add(settings, base)
	local name = FreeName(base)
	ns.saved.profiles[name] = settings
	ns.UseProfile(name)
	ns.Refresh()
	return name
end

function Profiles.Copy()
	return Profiles.Add(CopyTable(ns.db), L["Profile"])
end

function Profiles.Switch(name)
	if not ns.saved.profiles[name] then
		return false
	end
	ns.UseProfile(name)
	ns.Refresh()
	return true
end

-- Deletes the profile in use and moves to another. The last profile cannot be deleted.
function Profiles.DeleteCurrent()
	local names = ns.GetProfileNames()
	if #names < 2 then
		return false
	end
	local current = ns.profileName
	ns.saved.profiles[current] = nil
	for _, name in ipairs(names) do
		if name ~= current then
			ns.UseProfile(name)
			break
		end
	end
	ns.Refresh()
	return true
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local window

local function CreateWindow()
	local frame = CreateFrame("Frame", "PugUnitFramesProfileWindow", UIParent)
	frame:SetSize(620, 300)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)

	local fill = frame:CreateTexture(nil, "BACKGROUND")
	fill:SetAllPoints(frame)
	fill:SetColorTexture(0.03, 0.04, 0.05, 0.96)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 12, -10)
	title:SetPoint("TOPRIGHT", -12, -10)
	title:SetJustifyH("LEFT")
	frame.title = title

	local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	close:SetSize(90, 22)
	close:SetPoint("BOTTOMRIGHT", -10, 10)
	close:SetText(L["Close"])
	close:SetScript("OnClick", function()
		frame:Hide()
	end)

	local import = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	import:SetSize(200, 22)
	import:SetPoint("BOTTOMLEFT", 10, 10)
	import:SetText(L["Import what is in the box"])
	import:SetScript("OnClick", function()
		ns.Try(Profiles.ImportFromWindow)
	end)

	local edit = CreateFrame("EditBox", nil, frame)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetMaxLetters(MAX_IMPORT)
	edit:SetFontObject("GameFontHighlightSmall")
	edit:SetPoint("TOPLEFT", 12, -50)
	edit:SetPoint("BOTTOMRIGHT", -12, 42)
	edit:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		frame:Hide()
	end)
	frame.edit = edit
	return frame
end

-- /pug profile: the profile in use as text, selected and ready to copy; pasting other text
-- over it and pressing Import brings that in as a new profile.
function Profiles.ShowWindow()
	window = window or CreateWindow()
	window.title:SetText(L["Your settings as text. Ctrl+C copies them. To bring settings in, paste them here instead and press Import."])
	window.edit:SetText(Profiles.Export(ns.db))
	window:Show()
	window.edit:SetFocus()
	window.edit:HighlightText()
end

function Profiles.ImportFromWindow()
	local settings, why = Profiles.Import(window.edit:GetText())
	if not settings then
		ns.Print("|cffff4040" .. why .. "|r")
		return
	end
	local name = Profiles.Add(settings, L["Imported"])
	window:Hide()
	ns.Print(L["Imported as a new profile:"] .. " " .. name .. ".")
	if InCombatLockdown() then
		ns.Print(L["You are in combat: sizes and positions change when the fight ends."])
	end
end
