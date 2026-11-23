local ADDON, ns = ...

-- The options: a page for the look and the profile, and a page for the frames, one at a time.
-- The controls are drawn from the description of the settings in Defaults.lua, so a setting
-- added there appears here by itself, checked the same way wherever it comes from.
local Options = {}
ns.Options = Options

local L = ns.L
local Defaults = ns.Defaults

local ROW = 28
local LABEL_WIDTH = 190
local COLUMN = 330

---------------------------------------------------------------------------
-- What the settings are called
---------------------------------------------------------------------------
local SETTING_LABELS = {
	theme = "Theme", texture = "Bar texture", fontSize = "Text size", outline = "Outlined text",
	smooth = "Bars glide to a new value", farAlpha = "Out-of-range members fade to", tooltips = "Tooltips on frames",
	enabled = "Show this frame", width = "Width", height = "Height", scale = "Scale",
	powerHeight = "Power bar height", color = "Health colour", healthText = "Health text", powerText = "Power text",
	name = "Name", level = "Level", portrait = "Portrait",
	buffs = "Buffs shown", debuffs = "Debuffs shown", myDebuffs = "Only my debuffs",
	auraSize = "Icon size", auraPerRow = "Icons per row", auraSide = "Icons go",
	castbar = "Cast bar", castHeight = "Cast bar height",
	threat = "Outline when attacked", range = "Fade when out of range", heals = "Healing on its way",
	marks = "Marks (raid icon, leader, combat)", dispel = "Light up debuffs I can remove",
	points = "Combo points", totems = "Totems",
	growth = "Members go", spacing = "Gap between members", showPlayer = "Include me", showSolo = "Show when alone",
	perColumn = "Members per column", columnGrowth = "Columns go", columnSpacing = "Gap between columns",
	scaleSmall = "Size with up to 10 players", scaleMid = "Size with up to 20 players",
}

local CHOICE_LABELS = {
	theme = { slate = "Slate", night = "Night", hearth = "Hearth" },
	texture = { smooth = "Smooth", flat = "Flat", glass = "Glass" },
	tooltips = { always = "Always", calm = "Out of combat", never = "Never" },
	color = { class = "Class", reaction = "Friend or foe", health = "By health", plain = "Plain" },
	healthText = { none = "None", value = "Exact (1,234,567)", short = "Short (1234K)", percent = "Percent (87%)", both = "Short and percent", max = "Short / maximum", deficit = "What is missing" },
	powerText = { none = "None", value = "Exact (1,234,567)", short = "Short (1234K)", percent = "Percent (87%)", max = "Short / maximum" },
	portrait = { none = "None", left = "Left", right = "Right" },
	auraSide = { below = "Below", above = "Above", right = "Right", left = "Left", inside = "On the frame" },
	growth = { down = "Down", up = "Up", right = "Right", left = "Left" },
	columnGrowth = { down = "Down", up = "Up", right = "Right", left = "Left" },
}

-- Numbers that are a share of something are shown as a percentage.
local AS_PERCENT = { scale = true, scaleSmall = true, scaleMid = true, farAlpha = true }

local function SettingLabel(key)
	return L[SETTING_LABELS[key]]
end

local function ChoiceLabel(key, value)
	return L[CHOICE_LABELS[key][value]]
end

local function NumberText(key, value)
	if AS_PERCENT[key] then
		return ("%d%%"):format(value * 100 + 0.5)
	end
	return ("%d"):format(value)
end

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------
-- Every control has :Sync(), which shows the setting's current value, and :Place(x, y).
-- `get` returns the value, `set` stores it and brings the frames up to date.

local function PlaceAt(self, x, y)
	self:ClearAllPoints()
	self:SetPoint("TOPLEFT", self:GetParent(), "TOPLEFT", x, y)
end

local function MakeCheck(panel, key, get, set)
	local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check.Text:SetFontObject("GameFontHighlight")
	check.Text:SetText(SettingLabel(key))
	check:SetScript("OnClick", function(self)
		ns.Try(set, self:GetChecked() and true or false)
	end)
	check.Sync = function(self)
		self:SetChecked(get())
	end
	check.Place = PlaceAt
	return check
end

-- A label, then - and + around the value.
local function MakeStepper(panel, key, spec, get, set)
	local row = CreateFrame("Frame", nil, panel)
	row:SetSize(COLUMN - 10, ROW - 4)
	local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("LEFT", 4, 0)
	label:SetText(SettingLabel(key))
	local value = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	value:SetPoint("CENTER", row, "LEFT", LABEL_WIDTH + 62, 0)

	local function Step(direction)
		-- Onto the step's grid, so 46 + 2 is 48 and not 47.999.
		local stepped = math.floor((get() + direction * spec.step) / spec.step + 0.5) * spec.step
		set(math.max(spec.low, math.min(spec.high, stepped)))
	end
	local minus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	minus:SetSize(24, 22)
	minus:SetPoint("LEFT", row, "LEFT", LABEL_WIDTH, 0)
	minus:SetText("-")
	minus:SetScript("OnClick", function() ns.Try(Step, -1) end)
	local plus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	plus:SetSize(24, 22)
	plus:SetPoint("LEFT", row, "LEFT", LABEL_WIDTH + 100, 0)
	plus:SetText("+")
	plus:SetScript("OnClick", function() ns.Try(Step, 1) end)

	row.Sync = function()
		value:SetText(NumberText(key, get()))
	end
	row.Place = PlaceAt
	return row
end

-- A label, then a button that shows the choice and moves to the next one when clicked
-- (the previous one with the right mouse button).
local function MakeChoice(panel, key, spec, get, set)
	local row = CreateFrame("Frame", nil, panel)
	row:SetSize(COLUMN - 10, ROW - 4)
	local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("LEFT", 4, 0)
	label:SetText(SettingLabel(key))

	local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	button:SetSize(134, 22)
	button:SetPoint("LEFT", row, "LEFT", LABEL_WIDTH, 0)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetScript("OnClick", function(_, mouseButton)
		ns.Try(function()
			local choices, current = spec.choices, get()
			local index = 1
			for i, choice in ipairs(choices) do
				if choice == current then
					index = i
				end
			end
			local step = mouseButton == "RightButton" and -1 or 1
			set(choices[(index - 1 + step) % #choices + 1])
		end)
	end)

	row.Sync = function()
		button:SetText(ChoiceLabel(key, get()))
	end
	row.Place = PlaceAt
	return row
end

local function MakeControl(panel, key, spec, get, set)
	if spec.type == "bool" then
		return MakeCheck(panel, key, get, set)
	elseif spec.type == "number" then
		return MakeStepper(panel, key, spec, get, set)
	end
	return MakeChoice(panel, key, spec, get, set)
end

local function MakeButton(panel, text, width, onClick)
	local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetText(text)
	button:SetScript("OnClick", function()
		ns.Try(onClick)
	end)
	button.Place = PlaceAt
	return button
end

local function MakeHeading(panel, text, x, y)
	local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", x, y)
	heading:SetText(text)
	return heading
end

---------------------------------------------------------------------------
-- The general page
---------------------------------------------------------------------------
local general = { controls = {} }

local function SyncGeneral()
	if not general.panel then
		return
	end
	for _, control in ipairs(general.controls) do
		control:Sync()
	end
	general.lock:SetText(ns.db.locked and L["Unlock frames to move them"] or L["Lock frames"])
	general.profile:SetText(L["Profile"] .. ": |cffffffff" .. ns.profileName .. "|r")
	general.reload:SetShown(ns.Blizzard.NeedsReload())
	general.reloadNote:SetShown(ns.Blizzard.NeedsReload())
end

local function BuildGeneral(panel)
	local db = function() return ns.db end
	local y = -16
	MakeHeading(panel, "Free Unit Frames", 16, y)
	local version = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	version:SetPoint("TOPLEFT", 190, y - 4)
	version:SetText(L["Version"] .. " " .. ns.version .. "    /freeuf")
	y = y - 34

	general.lock = MakeButton(panel, "", 230, function()
		ns.Movers.SetLocked(not ns.db.locked)
		SyncGeneral()
	end)
	general.lock:Place(16, y)
	y = y - 38

	MakeHeading(panel, L["Look"], 16, y)
	y = y - 26
	for index, key in ipairs(Defaults.GENERAL_ORDER) do
		local control = MakeControl(panel, key, Defaults.GENERAL_SPEC[key],
			function() return db()[key] end,
			function(value)
				db()[key] = value
				ns.Refresh()
				SyncGeneral()
			end)
		local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
		control:Place(16 + column * COLUMN, y - row * ROW)
		general.controls[#general.controls + 1] = control
	end
	y = y - math.ceil(#Defaults.GENERAL_ORDER / 2) * ROW - 14

	MakeHeading(panel, L["Hide the game's own frames"], 16, y)
	y = y - 26
	for index, key in ipairs(Defaults.HIDE_ORDER) do
		local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
		check:SetSize(24, 24)
		check.Text:SetFontObject("GameFontHighlight")
		check.Text:SetText(key == "castbar" and L["Cast bar"] or Defaults.Label(key))
		check:SetScript("OnClick", function(self)
			ns.Try(function()
				db().hide[key] = self:GetChecked() and true or false
				ns.Refresh()
				SyncGeneral()
			end)
		end)
		check.Sync = function(self)
			self:SetChecked(db().hide[key])
		end
		local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
		check:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + column * 160, y - row * ROW)
		general.controls[#general.controls + 1] = check
	end
	y = y - math.ceil(#Defaults.HIDE_ORDER / 4) * ROW - 4

	general.reloadNote = panel:CreateFontString(nil, "ARTWORK", "GameFontRedSmall")
	general.reloadNote:SetPoint("TOPLEFT", 20, y - 4)
	general.reloadNote:SetText(L["A frame of the game's that was hidden comes back after a reload."])
	general.reload = MakeButton(panel, L["Reload now"], 120, ReloadUI)
	general.reload:Place(470, y)
	y = y - 36

	MakeHeading(panel, L["Profile"], 16, y)
	y = y - 28
	general.profile = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	general.profile:SetPoint("TOPLEFT", 20, y - 4)
	local x = 250
	local function Add(text, width, onClick)
		local button = MakeButton(panel, text, width, onClick)
		button:Place(x, y)
		x = x + width + 6
	end
	Add(L["Next"], 70, function()
		local names = ns.GetProfileNames()
		for index, name in ipairs(names) do
			if name == ns.profileName then
				ns.Profiles.Switch(names[index % #names + 1])
				break
			end
		end
		Options.Sync()
	end)
	Add(L["Copy"], 70, function()
		ns.Profiles.Copy()
		Options.Sync()
	end)
	Add(L["Delete"], 70, function()
		if not ns.Profiles.DeleteCurrent() then
			ns.Print(L["This is the only profile, so it stays."])
		end
		Options.Sync()
	end)
	Add(L["Export / import"], 130, function()
		ns.Profiles.ShowWindow()
	end)
end

---------------------------------------------------------------------------
-- The frames page
---------------------------------------------------------------------------
local frames = { kind = "player", controls = {}, tabs = {} }

local function SyncFrames()
	if not frames.panel then
		return
	end
	local kind = frames.kind
	for tabKind, tab in pairs(frames.tabs) do
		tab:SetEnabled(tabKind ~= kind)
	end
	-- The controls this kind of frame has, in two columns; the rest are put away.
	local shown = {}
	for _, key in ipairs(Defaults.UNIT_ORDER) do
		local control = frames.controls[key]
		if Defaults.UnitSpec(kind, key) then
			shown[#shown + 1] = control
		else
			control:Hide()
		end
	end
	local perColumn = math.ceil(#shown / 2)
	for index, control in ipairs(shown) do
		local column, row = math.floor((index - 1) / perColumn), (index - 1) % perColumn
		control:Place(16 + column * COLUMN, -84 - row * ROW)
		control:Show()
		control:Sync()
	end
end

local function BuildFrames(panel)
	MakeHeading(panel, L["Frames"], 16, -16)
	local x = 16
	for _, kind in ipairs(Defaults.KINDS) do
		local label = Defaults.Label(kind)
		local tab = MakeButton(panel, label, math.max(64, #label * 7 + 16), function()
			frames.kind = kind
			SyncFrames()
		end)
		tab:Place(x, -44)
		x = x + tab:GetWidth() + 4
		frames.tabs[kind] = tab
	end

	for _, key in ipairs(Defaults.UNIT_ORDER) do
		frames.controls[key] = MakeControl(panel, key, Defaults.UNIT_SPEC[key],
			function() return ns.db.units[frames.kind][key] end,
			function(value)
				ns.db.units[frames.kind][key] = value
				ns.Refresh()
				SyncFrames()
			end)
	end

	local reset = MakeButton(panel, L["Reset this frame"], 160, function()
		Defaults.Reset(ns.db, frames.kind)
		ns.Refresh()
		SyncFrames()
	end)
	reset:ClearAllPoints()
	reset:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 14)
end

-- For the test suite, which presses the controls.
Options.pages = { general = general, frames = frames }

---------------------------------------------------------------------------
-- Registering with the game's Settings window
---------------------------------------------------------------------------
function Options.Sync()
	if general.panel and general.panel:IsShown() then
		SyncGeneral()
	end
	if frames.panel and frames.panel:IsShown() then
		SyncFrames()
	end
end

-- A page is filled in the first time it is opened.
local function MakePanel(page, build, sync)
	local panel = CreateFrame("Frame")
	panel:Hide()
	panel:SetScript("OnShow", function(self)
		ns.Try(function()
			if not page.panel then
				page.panel = self
				build(self)
			end
			sync()
		end)
	end)
	return panel
end

function Options.Register()
	local generalPanel = MakePanel(general, BuildGeneral, SyncGeneral)
	local framesPanel = MakePanel(frames, BuildFrames, SyncFrames)
	Options.category = Settings.RegisterCanvasLayoutCategory(generalPanel, "Free Unit Frames")
	Settings.RegisterAddOnCategory(Options.category)
	Options.framesCategory = Settings.RegisterCanvasLayoutSubcategory(Options.category, framesPanel, L["Frames"])
end

function Options.Open()
	Settings.OpenToCategory(Options.category:GetID())
end
