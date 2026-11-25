-- A stand-in for the parts of the WoW Forever client that Pug Unit Frames touches, strict enough
-- to catch real mistakes:
--
--   * what the client seals, it seals here: health always; maximum health, power, names, classes,
--     casts, auras, threat, range and raid marks under the conditions Blizzard documents
--     (SecretReturns and SecretWhen... in Blizzard_APIDocumentationGenerated, explained in its
--     SecretPredicatesDocumentation.lua). A sealed value can be stored and handed on. Indexing
--     it, calling it, calculating with it, ordering it or joining it to a string is an error;
--   * a game function or widget method only takes a sealed value where Blizzard's documentation
--     says addon code may pass one (SecretArguments = "AllowedWhenTainted"). Anywhere else it is
--     an error, as in the client;
--   * widgets only have the methods listed here, so a misspelt or invented method is an error;
--   * protected frames (secure unit buttons, group headers, the game's own unit frames) refuse to
--     be shown, hidden, moved, sized or re-pointed by addon code while "in combat";
--   * the group header makes its buttons itself, from the addon's XML template, also in combat,
--     and runs the addon's initialConfigFunction for each, as SecureGroupHeaders.lua does;
--   * some of the game's own frames carry a forbidden aspect and refuse to have their events
--     touched, which the first simulator run of this addon showed the client does;
--   * an error the addon hands to the game's error handler fails the test that caused it.
--
-- What this cannot model, Lua 5.1 being what it is: comparing a sealed value with == and testing
-- one in an "if" are errors in the client and pass silently here. That is why only one file of
-- the addon (Sealed.lua) is allowed near such values, and run.py checks that it is so.
--
-- This is a model of the client, not the client: a pass here shows the addon's own logic is
-- consistent with Blizzard's documentation, not that the game agrees with the model.

local M = {
	combat = false,
	secure = 0,            -- > 0 while the game's own (secure) code is running
	now = 1000,            -- seconds on the game's clock
	locale = "enUS",
	units = {},            -- [token] = unit record, see M.SetUnit
	partySize = 0,         -- other members of the party
	raidSize = 0,          -- members of the raid, the player included; 0 = not in a raid
	resting = false,
	sealThreat = false,    -- one-unit threat queries are "generally not secret"; a test can make them so
	plainPower = {},       -- [power type] = true for a power the game never seals
	comboPoints = 0,
	totems = {},           -- [slot] = { icon =, start =, length = }
	readyCheck = {},       -- [unit] = "ready" | "notready" | "waiting"
	frames = {},           -- every frame made, in order
	named = {},            -- [name] = frame
	watched = {},          -- [frame] = true: shown and hidden with its unit by the game
	timers = {},           -- C_Timer.After calls waiting: { due =, fn = }
	printed = {},
	sounds = {},           -- sound kit ids played, in order
	luaErrors = {},        -- what reached the game's error handler
	blocked = {},          -- protected calls the client refused
	templateScripts = {},  -- [template] = { OnLoad = "lua source" }, read from the addon's XML by run.py
	templateParents = {},  -- [template] = the template it inherits
	settings = { categories = {}, opened = nil },
	tooltip = {},          -- what the tooltip was last asked to show
	reloads = 0,
	unreadableFonts = {},  -- [path] = true: a font file the game cannot read
	unknownFilters = {},   -- [word] = true: an aura filter word this client's containers do not know
	loadedAddOns = {},     -- [name] = true: another addon that is loaded
	driven = {},           -- [frame] = the rule the game shows and hides it by (RegisterStateDriver)
	keyDown = true,        -- the game's "cast on key down" setting, on unless the player changes it
	modifiers = "",        -- the keys held during a click: "", "shift-", "ctrl-", "alt-"
	destroyed = {},        -- totem slots sent away by a click, in order
	macros = {},           -- macro texts run by a click, in order
	petHappiness = nil,    -- 1 unhappy, 2 content, 3 happy; nil: no pet that has a mood
	sealComparisons = false, -- whether two unit names being the same creature comes back sealed
	emptySlotsSayYes = false, -- in a fight, an empty totem slot answers "there is a totem"
}
Mock = M

local function insecure()
	return M.secure == 0
end

-- Runs fn as the game's own code: protected calls are allowed whatever the combat state.
function M.Secure(fn, ...)
	M.secure = M.secure + 1
	local results = { pcall(fn, ...) }
	M.secure = M.secure - 1
	if not results[1] then
		error(results[2], 0)
	end
	return unpack(results, 2)
end

---------------------------------------------------------------------------
-- Sealed ("secret") values
---------------------------------------------------------------------------
local sealedValue = setmetatable({}, { __mode = "k" }) -- [sealed] = what is inside

local function Refuse(what)
	return function()
		error("attempted to " .. what .. " a sealed value", 2)
	end
end

local SEALED = {
	__index = Refuse("index"),
	__newindex = Refuse("index"),
	__call = Refuse("call"),
	__concat = Refuse("join"),
	__add = Refuse("calculate with"),
	__sub = Refuse("calculate with"),
	__mul = Refuse("calculate with"),
	__div = Refuse("calculate with"),
	__mod = Refuse("calculate with"),
	__pow = Refuse("calculate with"),
	__unm = Refuse("calculate with"),
	__lt = Refuse("order"),
	__le = Refuse("order"),
	__tostring = function() return "<sealed>" end,
}

local function Seal(value)
	local sealed = setmetatable({}, SEALED)
	sealedValue[sealed] = value
	return sealed
end

local function IsSealed(value)
	return type(value) == "table" and getmetatable(value) == SEALED
end

local function Unseal(value)
	if IsSealed(value) then
		return sealedValue[value]
	end
	return value
end

local function SealIf(condition, value)
	if condition and value ~= nil then
		return Seal(value)
	end
	return value
end

local function AnySealed(...)
	for i = 1, select("#", ...) do
		if IsSealed((select(i, ...))) then
			return true
		end
	end
	return false
end

M.Seal, M.Unseal, M.IsSealed = Seal, Unseal, IsSealed

-- For functions and methods that do not take sealed values from addon code.
local function Plain(what, ...)
	if insecure() and AnySealed(...) then
		error(what .. " does not accept a sealed value from addon code", 3)
	end
end

function issecretvalue(value)
	return IsSealed(value)
end

function canaccesstable(value)
	return type(value) == "table" and not IsSealed(value)
end

C_Secrets = {
	HasSecretRestrictions = function() return true end,
	ShouldUnitHealthMaxBeSecret = function(unit) local u = M.units[unit] return u ~= nil and not u.playerControlled end,
	ShouldUnitPowerBeSecret = function(unit) local u = M.units[unit] return u ~= nil and not M.plainPower[u.powerType] end,
	ShouldAurasBeSecret = function() return M.combat end,
	ShouldUnitIdentityBeSecret = function(unit) local u = M.units[unit] return u ~= nil and not (u.playerControlled or u.inGroup) end,
}

---------------------------------------------------------------------------
-- Small globals
---------------------------------------------------------------------------
Enum = {
	StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
	StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
	LuaCurveType = { Linear = 0, Step = 1, Cosine = 2, Cubic = 3 },
	UnitAuraSortRule = { Unsorted = 0, Default = 1 },
	UnitAuraSortDirection = { Normal = 0, Reverse = 1 },
	ForbiddenAspect = { EventRegistrations = 16, ChangeParent = 1024 },
	PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4 },
}

function Mixin(object, ...)
	for index = 1, select("#", ...) do
		for key, value in pairs((select(index, ...))) do
			object[key] = value
		end
	end
	return object
end

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
RAID_TARGET_TEXTURE_ROWS = 4
RAID_TARGET_TEXTURE_COLUMNS = 4

function print(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	M.printed[#M.printed + 1] = table.concat(parts, " ")
end

function geterrorhandler()
	return function(message)
		M.luaErrors[#M.luaErrors + 1] = tostring(message)
	end
end

-- The client's xpcall hands extra arguments on to the function; plain Lua 5.1's does not.
local plainXpcall = xpcall
function xpcall(fn, handler, ...)
	local count, arguments = select("#", ...), { ... }
	return plainXpcall(function() return fn(unpack(arguments, 1, count)) end, handler)
end

function GetLocale() return M.locale end
function GetTime() return M.now end
function GetBuildInfo() return "1.60.1", "71037", "Nov 20 2026", 16001 end
function InCombatLockdown() return M.combat end
function IsResting() return M.resting end
function ReloadUI() M.reloads = M.reloads + 1 end

function CopyTable(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = type(value) == "table" and CopyTable(value) or value
	end
	return copy
end

function wipe(target)
	for key in pairs(target) do
		target[key] = nil
	end
	return target
end

C_AddOns = {
	GetAddOnMetadata = function() return "0.0.0-test" end,
	-- M.loadedAddOns[name] = true for an addon a scenario wants to be there besides this one.
	IsAddOnLoaded = function(name) return M.loadedAddOns[name] or false end,
}
PixelUtil = { GetNearestPixelSize = function(size) return size end }
SlashCmdList = {}

C_Timer = {
	After = function(seconds, fn)
		Plain("C_Timer.After", seconds)
		M.timers[#M.timers + 1] = { due = M.now + seconds, fn = fn }
	end,
}

-- Colour objects, as CreateColor and the game's colour-returning functions make them.
local COLOR = {}
COLOR.__index = COLOR
function COLOR:GetRGB() return self.r, self.g, self.b end
function COLOR:GetRGBA() return self.r, self.g, self.b, self.a end

function CreateColor(r, g, b, a)
	return setmetatable({ r = r, g = g, b = b, a = a or 1 }, COLOR)
end

local CLASS_COLORS = {
	WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 },
	ROGUE = { 1.00, 0.96, 0.41 }, PRIEST = { 1.00, 1.00, 1.00 }, SHAMAN = { 0.00, 0.44, 0.87 },
	MAGE = { 0.25, 0.78, 0.92 }, WARLOCK = { 0.53, 0.53, 0.93 }, DRUID = { 1.00, 0.49, 0.04 },
}
M.CLASS_COLORS = CLASS_COLORS

-- SecretArguments = "AllowedWhenTainted": a sealed class in, sealed numbers out.
C_ClassColor = {
	GetClassColor = function(classFile)
		local sealed = IsSealed(classFile)
		local color = CLASS_COLORS[Unseal(classFile)]
		if not color then
			return nil
		end
		return CreateColor(SealIf(sealed, color[1]), SealIf(sealed, color[2]), SealIf(sealed, color[3]), 1)
	end,
}

function GetCreatureDifficultyColor(level)
	Plain("GetCreatureDifficultyColor", level)
	return { r = 1, g = level >= 999 and 0.1 or 0.82, b = 0 }
end

---------------------------------------------------------------------------
-- Numbers to text. These take sealed numbers from addon code and answer with sealed text.
---------------------------------------------------------------------------
local function Thousands(number)
	local text = tostring(math.floor(number))
	local grouped = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (grouped:gsub("^,", ""))
end

local function Short(number)
	if number >= 1000000 then
		return ("%.1fM"):format(number / 1000000)
	elseif number >= 1000 then
		return ("%.1fK"):format(number / 1000)
	end
	return tostring(math.floor(number))
end

local function TextOf(fn)
	return function(number)
		return SealIf(IsSealed(number), fn(Unseal(number)))
	end
end

-- What the game's own frames write: up to five digits in full, more in thousands or millions.
local function Large(number)
	local digits = tostring(math.floor(number))
	if #digits > 8 then
		return digits:sub(1, -7) .. "M"
	elseif #digits > 5 then
		return digits:sub(1, -4) .. "K"
	end
	return Thousands(number)
end

BreakUpLargeNumbers = TextOf(Thousands)
AbbreviateNumbers = TextOf(Short)
AbbreviateLargeNumbers = TextOf(Large)
C_StringUtil = {
	TruncateWhenZero = TextOf(function(number)
		local whole = math.floor(number)
		return whole == 0 and "" or tostring(whole)
	end),
}

---------------------------------------------------------------------------
-- Curves and durations
---------------------------------------------------------------------------
local CURVE = {}
CURVE.__index = CURVE
function CURVE:SetType(curveType) Plain("Curve:SetType", curveType) self.type = curveType end
function CURVE:AddPoint(x, y)
	Plain("Curve:AddPoint", x, y)
	self.points[#self.points + 1] = { x = x, y = y }
	table.sort(self.points, function(a, b) return a.x < b.x end)
end

-- The value of a curve at x: for a colour curve a table of four numbers, else a number.
local function Evaluate(curve, x)
	local points = curve.points
	if #points == 0 then
		return curve.isColor and { 0, 0, 0, 0 } or 0
	end
	local function Value(point)
		if curve.isColor then
			return { point.y.r, point.y.g, point.y.b, point.y.a }
		end
		return point.y
	end
	if x <= points[1].x then
		return Value(points[1])
	end
	for index = #points, 1, -1 do
		local point = points[index]
		if x >= point.x then
			local nextPoint = points[index + 1]
			if curve.type == Enum.LuaCurveType.Step or not nextPoint then
				return Value(point)
			end
			local share = (x - point.x) / (nextPoint.x - point.x)
			local from, to = Value(point), Value(nextPoint)
			if curve.isColor then
				local mixed = {}
				for channel = 1, 4 do
					mixed[channel] = from[channel] + (to[channel] - from[channel]) * share
				end
				return mixed
			end
			return from + (to - from) * share
		end
	end
end

-- What a game function hands back after putting a (sealed) number through a curve.
local function Through(curve, x, sealed)
	if not curve then
		return SealIf(sealed, x)
	end
	local value = Evaluate(curve, x)
	if curve.isColor then
		return CreateColor(SealIf(sealed, value[1]), SealIf(sealed, value[2]), SealIf(sealed, value[3]), SealIf(sealed, value[4]))
	end
	return SealIf(sealed, value)
end

C_CurveUtil = {
	CreateCurve = function()
		return setmetatable({ points = {}, type = Enum.LuaCurveType.Linear }, CURVE)
	end,
	CreateColorCurve = function()
		return setmetatable({ points = {}, type = Enum.LuaCurveType.Linear, isColor = true }, CURVE)
	end,
	-- SecretArguments = "AllowedWhenTainted"
	EvaluateColorValueFromBoolean = function(flag, whenTrue, whenFalse)
		local sealed = AnySealed(flag, whenTrue, whenFalse)
		local value
		if Unseal(flag) then
			value = Unseal(whenTrue)
		else
			value = Unseal(whenFalse)
		end
		return SealIf(sealed, value)
	end,
}

-- A span of time the game can draw but an addon cannot read. The mock keeps what it stands for.
local durationSpan = setmetatable({}, { __mode = "k" }) -- [object] = { start =, length =, sealed = }
local DURATION_METHODS = {}
-- The time left, put through a curve by the game. What comes out is sealed when the span is of
-- something the game seals.
function DURATION_METHODS:EvaluateRemainingDuration(curve)
	local span = durationSpan[self]
	assert(type(curve) == "table" and curve.points and not curve.isColor, "EvaluateRemainingDuration needs a number curve")
	return Through(curve, math.max(0, span.start + span.length - M.now), span.sealed)
end
local DURATION = {
	__index = function(_, key)
		local method = DURATION_METHODS[key]
		if not method then
			error("this model's duration objects have no '" .. tostring(key) .. "'", 2)
		end
		return method
	end,
	__tostring = function() return "LuaDurationObject" end,
}

local function Duration(start, length, sealed)
	local object = setmetatable({}, DURATION)
	durationSpan[object] = { start = start, length = length, sealed = sealed and true or false }
	return object
end

local function IsDuration(value)
	return type(value) == "table" and getmetatable(value) == DURATION
end

function M.SpanOf(duration)
	return durationSpan[duration]
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
-- A widget here is a plain table, and the addon keeps things of its own on its frames (frame.kind,
-- frame.unit, frame.health, ...) as it does in the game. The model's own bookkeeping therefore
-- uses names the addon does not: anchors, widget, shown, scripts, events, attributes, aspects,
-- children, regions, level, strata and the like.
local Region, Texture, FontString, Frame, StatusBar, Cooldown, Button, CheckButton, EditBox = {}, {}, {}, {}, {}, {}, {}, {}, {}

local function Inherit(class, parent)
	for key, value in pairs(parent) do
		if class[key] == nil then
			class[key] = value
		end
	end
end

-- Refuses a protected call from addon code in combat. The client does not raise a Lua error for
-- these: it does nothing and fires ADDON_ACTION_BLOCKED. Here it is both noted and an error, so
-- the test that caused it fails where it happened.
local function Guard(self, what)
	if self.protected and M.combat and insecure() then
		M.blocked[#M.blocked + 1] = (self.name or "?") .. ":" .. what
		error(("%s is protected: addon code cannot call %s in combat"):format(self.name or "a frame", what), 3)
	end
end

local function Forbid(self)
	if self.forbidden and insecure() then
		error("attempt to use a forbidden object from addon code", 3)
	end
end

-- Region: what textures, font strings and frames share --------------------
function Region:GetParent() return self.parent end
function Region:SetPoint(point, ...)
	Guard(self, "SetPoint")
	Plain("SetPoint", point, ...)
	assert(type(point) == "string", "SetPoint needs a point name")
	self.anchors[#self.anchors + 1] = { point, ... }
end
function Region:ClearAllPoints() Guard(self, "ClearAllPoints") self.anchors = {} end
function Region:SetAllPoints(other)
	Guard(self, "SetAllPoints")
	self.anchors = { { "ALL", other or self.parent } }
end
function Region:SetSize(width, height)
	Guard(self, "SetSize")
	Plain("SetSize", width, height)
	assert(type(width) == "number" and type(height) == "number", "SetSize needs two numbers")
	self.width, self.height = width, height
end
function Region:SetWidth(width) Guard(self, "SetWidth") Plain("SetWidth", width) assert(type(width) == "number") self.width = width end
function Region:SetHeight(height) Guard(self, "SetHeight") Plain("SetHeight", height) assert(type(height) == "number") self.height = height end
function Region:GetWidth() return self.width or 0 end
function Region:GetHeight() return self.height or 0 end
function Region:IsShown() return self.shown end
function Region:IsVisible()
	local region = self
	while region do
		if not region.shown then
			return false
		end
		region = region.parent
	end
	return true
end
-- SecretArguments = "AllowedWhenTainted"
function Region:SetAlpha(alpha) self.alpha = alpha end
function Region:SetAlphaFromBoolean(flag, whenTrue, whenFalse)
	local value
	if Unseal(flag) then
		value = Unseal(whenTrue)
	else
		value = Unseal(whenFalse)
	end
	self.alpha = SealIf(AnySealed(flag, whenTrue, whenFalse), value)
end
function Region:GetAlpha() return self.alpha end

-- Showing and hiding. A frame's OnShow runs when it comes into view, its own doing or a parent's.
local function Appeared(region)
	if region.scripts and region.scripts.OnShow then
		region.scripts.OnShow(region)
	end
	for _, child in ipairs(region.children or {}) do
		if child.shown then
			Appeared(child)
		end
	end
end

function Region:Show()
	Forbid(self)
	Guard(self, "Show")
	if not self.shown then
		self.shown = true
		if self:IsVisible() then
			Appeared(self)
		end
	end
end
function Region:Hide()
	Forbid(self)
	Guard(self, "Hide")
	if self.shown then
		self.shown = false
		if self.scripts and self.scripts.OnHide then
			self.scripts.OnHide(self)
		end
	end
end
function Region:SetShown(shown)
	Plain("SetShown", shown)
	if shown then
		self:Show()
	else
		self:Hide()
	end
end

-- Texture ------------------------------------------------------------------
Inherit(Texture, Region)
-- SecretArguments = "AllowedWhenTainted" for all of these.
function Texture:SetTexture(texture) self.texture = texture self.atlas = nil end
-- A picture out of one of the game's own sheets, by name.
function Texture:SetAtlas(atlas, useAtlasSize)
	Plain("SetAtlas's own size flag", useAtlasSize)
	self.atlas = atlas
	self.texture = nil
end
function Texture:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
function Texture:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a } end
function Texture:SetTexCoord(...) self.coords = { ... } end
-- A colour that runs from one to another across the texture: from `low` at the left or the
-- bottom to `high` at the right or the top.
function Texture:SetGradient(orientation, low, high)
	Plain("SetGradient's orientation", orientation)
	assert(orientation == "HORIZONTAL" or orientation == "VERTICAL", "SetGradient: not an orientation: " .. tostring(orientation))
	assert(type(low) == "table" and low.GetRGBA and type(high) == "table" and high.GetRGBA, "SetGradient takes two colour objects")
	self.gradient = { orientation = orientation, low = { low:GetRGBA() }, high = { high:GetRGBA() } }
end
function Texture:SetBlendMode(mode) Plain("SetBlendMode", mode) self.blend = mode end
function Texture:SetSpriteSheetCell(cell, rows, columns)
	Plain("SetSpriteSheetCell's rows and columns", rows, columns)
	self.cell = cell
end

-- FontString ---------------------------------------------------------------
Inherit(FontString, Region)
-- A font file the game cannot read is refused (M.unreadableFonts[path]): the text keeps whatever
-- font it had, which for a fresh one is none.
function FontString:SetFont(path, size, flags)
	Plain("SetFont", path, size, flags)
	assert(type(path) == "string" and type(size) == "number", "SetFont needs a path and a size")
	if M.unreadableFonts[path] then
		return false
	end
	self.font = { path, size, flags }
	return true
end
function FontString:GetFont()
	if self.font then
		return self.font[1], self.font[2], self.font[3]
	end
end
function FontString:SetFontObject(name) Plain("SetFontObject", name) self.fontObject = name end
function FontString:SetJustifyH(justify) Plain("SetJustifyH", justify) self.justify = justify end
function FontString:SetWordWrap(wrap) Plain("SetWordWrap", wrap) self.wrap = wrap end
function FontString:SetMaxLines(lines) Plain("SetMaxLines", lines) assert(type(lines) == "number") self.maxLines = lines end
function FontString:SetShadowColor(...) Plain("SetShadowColor", ...) end
function FontString:SetShadowOffset(...) Plain("SetShadowOffset", ...) end
-- SecretArguments = "AllowedWhenTainted"
function FontString:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
-- A text with no font cannot be written on: in the game that is an error.
function FontString:SetText(text)
	if not self.font and not self.fontObject then
		error("FontString:SetText(): Font not set", 2)
	end
	self.text = text
end
function FontString:SetFormattedText(format, ...)
	Plain("SetFormattedText's format", format)
	if not self.font and not self.fontObject then
		error("FontString:SetFormattedText(): Font not set", 2)
	end
	local arguments = { ... }
	local sealed = AnySealed(...)
	for index = 1, select("#", ...) do
		arguments[index] = Unseal(arguments[index])
	end
	self.text = SealIf(sealed, format:format(unpack(arguments, 1, select("#", ...))))
end
function FontString:GetText() return self.text end

-- Frame --------------------------------------------------------------------
Inherit(Frame, Region)
function Frame:CreateTexture(name, layer, template, sublevel)
	local texture = setmetatable({ widget = "Texture", parent = self, shown = true, anchors = {}, layer = layer, sublevel = sublevel or 0 }, { __index = Texture })
	self.regions[#self.regions + 1] = texture
	return texture
end
function Frame:CreateFontString(name, layer, fontObject)
	local text = setmetatable({ widget = "FontString", parent = self, shown = true, anchors = {}, layer = layer, fontObject = fontObject }, { __index = FontString })
	self.regions[#self.regions + 1] = text
	return text
end
function Frame:GetChildren() return unpack(self.children) end
function Frame:SetParent(parent)
	Forbid(self)
	Guard(self, "SetParent")
	if self.aspects[Enum.ForbiddenAspect.ChangeParent] and insecure() then
		error("Function call not permitted due to forbidden aspect 'ChangeParent'", 2)
	end
	if self.parent then
		for index, child in ipairs(self.parent.children) do
			if child == self then
				table.remove(self.parent.children, index)
				break
			end
		end
	end
	self.parent = parent
	if parent then
		parent.children[#parent.children + 1] = self
	end
end
function Frame:IsProtected() return self.protected or false, self.protected or false end
function Frame:IsForbidden() return self.forbidden or false end
function Frame:HasAnyForbiddenAspects(aspect) Forbid(self) return self.aspects[aspect] or false end
function Frame:SetScale(scale)
	Guard(self, "SetScale")
	Plain("SetScale", scale)
	assert(type(scale) == "number" and scale > 0, "SetScale needs a positive number")
	self.scale = scale
end
function Frame:GetScale() return self.scale end
function Frame:GetEffectiveScale()
	local scale, frame = 1, self
	while frame do
		scale = scale * (frame.scale or 1)
		frame = frame.parent
	end
	return scale
end
function Frame:SetFrameLevel(level)
	Guard(self, "SetFrameLevel")
	Plain("SetFrameLevel", level)
	assert(type(level) == "number" and level >= 0, "a frame level cannot be negative")
	self.level = level
end
function Frame:GetFrameLevel() return self.level end
function Frame:SetFrameStrata(strata) Guard(self, "SetFrameStrata") Plain("SetFrameStrata", strata) self.strata = strata end
function Frame:SetClipsChildren(clips) Plain("SetClipsChildren", clips) self.clips = clips end
function Frame:EnableMouse(enable) Guard(self, "EnableMouse") Plain("EnableMouse", enable) self.mouse = enable and true or false end
function Frame:SetMovable(movable) Plain("SetMovable", movable) self.movable = movable end
function Frame:SetClampedToScreen(clamped) Guard(self, "SetClampedToScreen") self.clamped = clamped end
function Frame:RegisterForDrag(...) Plain("RegisterForDrag", ...) self.drag = { ... } end
function Frame:StartMoving() Guard(self, "StartMoving") assert(self.movable, "StartMoving on a frame that is not movable") self.moving = true end
function Frame:StopMovingOrSizing() Guard(self, "StopMovingOrSizing") self.moving = false end

-- Where a frame is, worked out from a single anchor to UIParent's centre or to nothing; enough
-- for the handles, which are the only frames the addon asks.
local function Box(frame)
	local width, height = frame:GetWidth(), frame:GetHeight()
	local anchor = frame.dropped or frame.anchors[1]
	if not anchor then
		return 0, 0, width, height
	end
	local point, x, y = anchor[1], anchor[4] or 0, anchor[5] or 0
	local left = point:find("LEFT") and x or point:find("RIGHT") and x - width or x - width / 2
	local bottom = point:find("BOTTOM") and y or point:find("TOP") and y - height or y - height / 2
	return left, bottom, width, height
end
function Frame:GetLeft() return (Box(self)) end
function Frame:GetRight() local left, _, width = Box(self) return left + width end
function Frame:GetBottom() return (select(2, Box(self))) end
function Frame:GetTop() local _, bottom, _, height = Box(self) return bottom + height end
function Frame:GetCenter()
	local left, bottom, width, height = Box(self)
	return left + width / 2, bottom + height / 2
end

-- Giving a frame a script for the mouse switches its mouse on, as the game does (the simulator,
-- which runs the game's own widget code, showed it: an EnableMouse(false) before such a script
-- is undone by it).
local MOUSE_SCRIPTS = { OnEnter = true, OnLeave = true, OnMouseDown = true, OnMouseUp = true }

function Frame:SetScript(script, fn)
	Forbid(self)
	assert(fn == nil or type(fn) == "function", "SetScript needs a function or nil")
	self.scripts[script] = fn
	if fn and MOUSE_SCRIPTS[script] then
		self.mouse = true
	end
end
function Frame:GetScript(script) return self.scripts[script] end
function Frame:HookScript(script, fn)
	Forbid(self)
	assert(type(fn) == "function", "HookScript needs a function")
	if MOUSE_SCRIPTS[script] then
		self.mouse = true
	end
	local before = self.scripts[script]
	self.scripts[script] = function(...)
		if before then
			before(...)
		end
		fn(...)
	end
end

function Frame:RegisterEvent(event)
	Forbid(self)
	Plain("RegisterEvent", event)
	self.events[event] = true
end
function Frame:RegisterUnitEvent(event, unit1, unit2)
	Forbid(self)
	Plain("RegisterUnitEvent", event, unit1, unit2)
	assert(type(unit1) == "string", "RegisterUnitEvent needs a unit")
	self.events[event] = { [unit1] = true, [unit2 or unit1] = true }
end
function Frame:UnregisterEvent(event) self.events[event] = nil end
function Frame:UnregisterAllEvents()
	Forbid(self)
	if self.aspects[Enum.ForbiddenAspect.EventRegistrations] and insecure() then
		error("Function call not permitted due to forbidden aspect 'EventRegistrations'", 2)
	end
	self.events = {}
end
function Frame:IsEventRegistered(event) return self.events[event] ~= nil end

function Frame:SetAttribute(name, value)
	Guard(self, "SetAttribute")
	Plain("SetAttribute", name, value)
	self.attributes[name] = value
	if self.scripts.OnAttributeChanged then
		self.scripts.OnAttributeChanged(self, name, value)
	end
end
function Frame:GetAttribute(name) return self.attributes[name] end

-- Animations: only what makes a frame pulse.
local AnimationGroup, Animation = {}, {}
AnimationGroup.__index = function(_, key)
	return AnimationGroup[key] or error("this model's animation groups have no '" .. tostring(key) .. "'", 2)
end
Animation.__index = function(_, key)
	return Animation[key] or error("this model's animations have no '" .. tostring(key) .. "'", 2)
end
local LOOPS = { NONE = true, REPEAT = true, BOUNCE = true }
function Frame:CreateAnimationGroup()
	local group = setmetatable({}, AnimationGroup)
	rawset(group, "owner", self)
	rawset(group, "animations", {})
	rawset(group, "playing", false)
	return group
end
function AnimationGroup:SetLooping(kind) assert(LOOPS[kind], "SetLooping needs NONE, REPEAT or BOUNCE") rawset(self, "looping", kind) end
function AnimationGroup:CreateAnimation(kind)
	assert(kind == "Alpha", "this model only has Alpha animations")
	local animation = setmetatable({}, Animation)
	rawset(animation, "kind", kind)
	local animations = rawget(self, "animations")
	animations[#animations + 1] = animation
	return animation
end
function AnimationGroup:Play() rawset(self, "playing", true) end
function AnimationGroup:Stop() rawset(self, "playing", false) end
function AnimationGroup:IsPlaying() return rawget(self, "playing") end
function Animation:SetFromAlpha(alpha) Plain("SetFromAlpha", alpha) rawset(self, "from", alpha) end
function Animation:SetToAlpha(alpha) Plain("SetToAlpha", alpha) rawset(self, "to", alpha) end
function Animation:SetDuration(seconds) Plain("SetDuration", seconds) rawset(self, "seconds", seconds) end
function Animation:SetSmoothing(kind) Plain("SetSmoothing", kind) rawset(self, "smoothing", kind) end

-- StatusBar ----------------------------------------------------------------
Inherit(StatusBar, Frame)
function StatusBar:SetStatusBarTexture(texture)
	Plain("SetStatusBarTexture", texture)
	self.barTexture = self.barTexture or self:CreateTexture()
	self.barTexture.texture = texture
end
function StatusBar:GetStatusBarTexture() return self.barTexture end
-- SecretArguments = "AllowedWhenTainted" for the values and the colour, never for the interpolation.
function StatusBar:SetMinMaxValues(low, high, interpolation)
	Plain("SetMinMaxValues' interpolation", interpolation)
	self.low, self.high = low, high
end
function StatusBar:SetValue(value, interpolation)
	Plain("SetValue's interpolation", interpolation)
	assert(value ~= nil, "SetValue needs a value")
	self.value, self.interpolation, self.timer = value, interpolation, nil
end
function StatusBar:GetValue() return self.value end
function StatusBar:SetOrientation(orientation)
	Plain("SetOrientation", orientation)
	assert(orientation == "HORIZONTAL" or orientation == "VERTICAL", "SetOrientation needs HORIZONTAL or VERTICAL")
	self.orientation = orientation
end
function StatusBar:SetReverseFill(reverse) Plain("SetReverseFill", reverse) self.reverseFill = reverse and true or false end
function StatusBar:GetMinMaxValues() return self.low, self.high end
function StatusBar:SetStatusBarColor(r, g, b, a) self.barColor = { r, g, b, a } end
function StatusBar:SetTimerDuration(duration, interpolation, direction)
	Plain("SetTimerDuration's interpolation and direction", interpolation, direction)
	assert(IsDuration(duration), "SetTimerDuration needs a duration object")
	self.timer = { duration = duration, direction = direction }
end

-- Cooldown -----------------------------------------------------------------
Inherit(Cooldown, Frame)
function Cooldown:SetReverse(reverse) Plain("SetReverse", reverse) self.reverse = reverse end
function Cooldown:SetDrawEdge(draw) self.drawEdge = draw end
function Cooldown:SetHideCountdownNumbers(hide) Plain("SetHideCountdownNumbers", hide) self.hideNumbers = hide end
-- Takes the name of one of the game's font objects.
local GAME_FONTS = { NumberFontNormalSmall = true }
function Cooldown:SetCountdownFont(name)
	Plain("SetCountdownFont", name)
	assert(GAME_FONTS[name], "this model has no font object '" .. tostring(name) .. "'")
	self.countdownFont = name
end
function Cooldown:SetCooldownFromDurationObject(duration, clearIfZero)
	Guard(self, "SetCooldownFromDurationObject")
	-- The sweep of a secure button is the button's business: set on a cooldown that sits
	-- directly on a protected frame, this is refused in a fight (the simulator, which runs the
	-- game's own widget rules, refused exactly that and nothing one step further away).
	if self.parent and self.parent.protected and M.combat and insecure() then
		M.blocked[#M.blocked + 1] = "SetCooldownFromDurationObject"
		error("a cooldown on a protected frame cannot be set by addon code in combat", 2)
	end
	Plain("SetCooldownFromDurationObject's clearIfZero", clearIfZero)
	assert(IsDuration(duration), "SetCooldownFromDurationObject needs a duration object")
	self.duration = duration
end

-- Button, CheckButton, EditBox ---------------------------------------------
Inherit(Button, Frame)
function Button:RegisterForClicks(...) Guard(self, "RegisterForClicks") Plain("RegisterForClicks", ...) self.clicks = { ... } end
function Button:SetText(text) Plain("Button:SetText", text) self.text = text end
function Button:GetText() return self.text end
function Button:SetEnabled(enabled) Guard(self, "SetEnabled") self.enabled = enabled and true or false end
function Button:IsEnabled() return self.enabled end
function Button:Click(mouseButton)
	if self.scripts.OnClick then
		self.scripts.OnClick(self, mouseButton or "LeftButton", false)
	end
end

-- A click of the mouse as the player makes it: the press, then the release, each handed to the
-- button only if it takes that half of a click of that button, is on screen and takes the mouse.
-- `modifiers` is "", "shift-", "ctrl-" or "alt-". The game's handlers run as the game's own code.
function M.Press(button, mouseButton, modifiers)
	mouseButton = mouseButton or "LeftButton"
	M.modifiers = modifiers or ""
	M.clicked = nil
	for _, down in ipairs({ true, false }) do
		local half = down and "Down" or "Up"
		local takes = false
		for _, registered in ipairs(button.clicks or { "LeftButtonUp" }) do
			if registered == mouseButton .. half or registered == "Any" .. half then
				takes = true
			end
		end
		if takes and button.mouse ~= false and button:IsVisible() and button.scripts.OnClick then
			M.Secure(button.scripts.OnClick, button, mouseButton, down)
		end
	end
	M.modifiers = ""
end

Inherit(CheckButton, Button)
function CheckButton:SetChecked(checked) Plain("SetChecked", checked) self.checked = checked and true or false end
function CheckButton:GetChecked() return self.checked end

Inherit(EditBox, Frame)
function EditBox:SetMultiLine(multi) self.multiLine = multi end
function EditBox:SetAutoFocus(auto) self.autoFocus = auto end
function EditBox:SetMaxLetters(count) self.maxLetters = count end
function EditBox:SetFontObject(name) self.fontObject = name end
function EditBox:SetText(text) Plain("EditBox:SetText", text) assert(type(text) == "string") self.text = text end
function EditBox:GetText() return self.text or "" end
function EditBox:SetFocus() self.focused = true end
function EditBox:ClearFocus() self.focused = false end
function EditBox:HighlightText() self.highlighted = true end

local CLASSES = { Frame = Frame, StatusBar = StatusBar, Cooldown = Cooldown, Button = Button, CheckButton = CheckButton, EditBox = EditBox }

---------------------------------------------------------------------------
-- Templates and CreateFrame
---------------------------------------------------------------------------
-- An attribute as a secure button looks it up for a click: with the keys held and the button,
-- then with "any keys", then with "any button", then bare (SecureButton_GetModifiedAttribute).
local function ClickAttribute(self, name, mouseButton)
	local prefix = M.modifiers
	local suffix = mouseButton == "RightButton" and "2" or "1"
	local attributes = self.attributes
	local value = attributes[prefix .. name .. suffix]
	if value == nil then value = attributes["*" .. name .. suffix] end
	if value == nil then value = attributes[prefix .. name .. "*"] end
	if value == nil then value = attributes["*" .. name .. "*"] end
	if value == nil then value = attributes[name] end
	return value
end

-- What Blizzard's SecureUnitButton_OnClick does with a click. "target" and the menu only go
-- through for a click that Blizzard's click bindings list, and those list the plain left click
-- and the plain right click: with a key held, such a click does nothing. Other actions (a macro)
-- are not held back.
function SecureUnitButton_OnClick(self, mouseButton, down)
	if down then
		return
	end
	local kind = ClickAttribute(self, "type", mouseButton)
	local listed = M.modifiers == ""
	if (kind == "target" or kind == "menu" or kind == "togglemenu") and not listed then
		return
	end
	M.clicked = { frame = self, button = mouseButton, unit = self:GetAttribute("unit"), action = kind }
	if kind == "macro" then
		M.clicked.macro = ClickAttribute(self, "macrotext", mouseButton)
		M.macros[#M.macros + 1] = M.clicked.macro
	end
end

-- What Blizzard's SecureActionButton_OnClick does: it acts on the press or on the release of a
-- click, as the "cast on key down" setting says, and passes over the other.
function SecureActionButton_OnClick(self, mouseButton, down)
	if (down and true or false) ~= M.keyDown then
		return
	end
	local kind = ClickAttribute(self, "type", mouseButton)
	if kind == "destroytotem" then
		local slot = ClickAttribute(self, "totem-slot", mouseButton)
		assert(type(slot) == "number", "destroytotem needs a totem-slot")
		M.destroyed[#M.destroyed + 1] = slot
		M.totems[slot] = nil
	end
end

local PROTECTED_TEMPLATES = { SecureUnitButtonTemplate = true, SecureGroupHeaderTemplate = true, SecureActionButtonTemplate = true }

local function IsTemplate(template, wanted)
	while template do
		if template == wanted then
			return true
		end
		template = M.templateParents[template]
	end
	return false
end

function CreateFrame(kind, name, parent, template)
	local class = CLASSES[kind]
	assert(class, "this model has no frame type '" .. tostring(kind) .. "'")
	-- The buttons of an aura container are the game's to make.
	if kind == "AuraButton" and insecure() then
		error("CreateFrame: AuraButton cannot be created by addons", 2)
	end
	if kind == "AuraContainer" then
		assert(template == "CustomAuraContainerTemplate", "this model has aura containers of the template CustomAuraContainerTemplate only")
	end
	local frame = setmetatable({
		widget = kind, name = name, parent = parent, shown = true, anchors = {}, scale = 1,
		level = parent and parent.level + 1 or 0,
		children = {}, regions = {}, scripts = {}, events = {}, attributes = {}, aspects = {},
	}, { __index = class })
	if parent then
		parent.children[#parent.children + 1] = frame
	end
	if name then
		M.named[name] = frame
		_G[name] = frame
	end
	M.frames[#M.frames + 1] = frame

	if template then
		assert(template == "CooldownFrameTemplate" or template == "UICheckButtonTemplate" or template == "UIPanelButtonTemplate"
			or template == "CustomAuraContainerTemplate"
			or template == "SecureUnitButtonTemplate" or template == "SecureGroupHeaderTemplate"
			or template == "SecureActionButtonTemplate" or M.templateScripts[template],
			"this model has no template '" .. tostring(template) .. "'")
		for protected in pairs(PROTECTED_TEMPLATES) do
			if IsTemplate(template, protected) then
				frame.protected = true
			end
		end
		if IsTemplate(template, "SecureUnitButtonTemplate") then
			frame.scripts.OnClick = SecureUnitButton_OnClick
			frame.clicks = { "LeftButtonUp" }
		end
		if template == "SecureActionButtonTemplate" then
			frame.scripts.OnClick = SecureActionButton_OnClick
			frame.clicks = { "LeftButtonUp" }
		end
		if template == "UICheckButtonTemplate" then
			frame.Text = frame:CreateFontString()
		end
		if template == "SecureGroupHeaderTemplate" then
			frame.isHeader = true
			frame.shown = false -- a header starts hidden until it is shown
			frame.scripts.OnShow = function(self) M.UpdateHeader(self) end
			frame.scripts.OnAttributeChanged = function(self, attribute)
				if attribute ~= "_ignore" and self:IsVisible() then
					M.UpdateHeader(self)
				end
			end
		end
		-- The addon's own template: its click registration and its OnLoad, which runs as addon code.
		local own = M.templateScripts[template]
		if own then
			if own.registerForClicks then
				frame.clicks = own.registerForClicks
			end
			if own.OnLoad then
				local chunk = assert(loadstring("return function(self) " .. own.OnLoad .. "\nend", "@" .. template .. ":OnLoad"))
				local saved = M.secure
				M.secure = 0
				local ok, problem = pcall(chunk(), frame)
				M.secure = saved
				if not ok then
					error(problem, 0)
				end
			end
		end
	end
	if kind == "AuraContainer" then
		M.NewAuraContainer(frame)
	end
	return frame
end

UIParent = CreateFrame("Frame", "UIParent")
UIParent.width, UIParent.height = 1600, 1200
UIParent.anchors = { { "CENTER", nil, "CENTER", 0, 0 } }

---------------------------------------------------------------------------
-- The game's own secure code: unit watch and the group header
---------------------------------------------------------------------------
local function Exists(unit)
	return unit ~= nil and M.units[unit] ~= nil
end

function RegisterUnitWatch(frame)
	if frame.protected and M.combat and insecure() then
		error("RegisterUnitWatch on a protected frame in combat", 2)
	end
	assert(not M.driven[frame], "a frame shown by a rule was also put under a unit watch")
	M.watched[frame] = true
	M.Secure(function()
		if Exists(frame:GetAttribute("unit")) then frame:Show() else frame:Hide() end
	end)
end

function UnregisterUnitWatch(frame)
	if frame.protected and M.combat and insecure() then
		error("UnregisterUnitWatch on a protected frame in combat", 2)
	end
	M.watched[frame] = nil
end

-- A frame shown and hidden by a rule, written as macro conditions. This model knows the one rule
-- the addon uses.
local RULES = {
	["[group] hide; show"] = function() return M.partySize == 0 and M.raidSize == 0 end,
}

local function FollowRule(frame)
	if RULES[M.driven[frame]]() then frame:Show() else frame:Hide() end
end

function RegisterStateDriver(frame, state, rule)
	if frame.protected and M.combat and insecure() then
		error("RegisterStateDriver on a protected frame in combat", 2)
	end
	assert(state == "visibility", "this model only drives visibility")
	assert(RULES[rule], "this model does not know the rule '" .. tostring(rule) .. "'")
	assert(not M.watched[frame], "a frame under a unit watch was also given a rule")
	M.driven[frame] = rule
	M.Secure(FollowRule, frame)
end

function UnregisterStateDriver(frame, state)
	if frame.protected and M.combat and insecure() then
		error("UnregisterStateDriver on a protected frame in combat", 2)
	end
	assert(state == "visibility", "this model only drives visibility")
	M.driven[frame] = nil
end

-- Shows and hides the watched frames with their units and the ruled ones by their rules, as the
-- game does a moment after a change.
function M.UpdateUnitWatch()
	M.Secure(function()
		for frame in pairs(M.watched) do
			if Exists(frame:GetAttribute("unit")) then frame:Show() else frame:Hide() end
		end
		for frame in pairs(M.driven) do
			FollowRule(frame)
		end
	end)
end

-- The units a header shows, in order.
local function HeaderUnits(header)
	local units = {}
	if M.raidSize > 0 then
		if header:GetAttribute("showRaid") then
			for index = 1, M.raidSize do
				units[#units + 1] = "raid" .. index
			end
		end
	elseif M.partySize > 0 then
		if header:GetAttribute("showParty") then
			if header:GetAttribute("showPlayer") then
				units[#units + 1] = "player"
			end
			for index = 1, M.partySize do
				units[#units + 1] = "party" .. index
			end
		end
	elseif header:GetAttribute("showSolo") then
		units[#units + 1] = "player"
	end
	-- Grouped by the part each member has taken, in the order the header was given; within a
	-- part, in the order they stood.
	if header:GetAttribute("groupBy") == "ASSIGNEDROLE" then
		local order, place = {}, {}
		local index = 0
		for role in header:GetAttribute("groupingOrder"):gmatch("[^,]+") do
			index = index + 1
			order[role] = index
		end
		for position, unit in ipairs(units) do
			place[unit] = { order[M.units[unit] and M.units[unit].role or "NONE"] or index + 1, position }
		end
		table.sort(units, function(a, b)
			if place[a][1] ~= place[b][1] then
				return place[a][1] < place[b][1]
			end
			return place[a][2] < place[b][2]
		end)
	end
	return units
end

-- What SecureGroupHeader_Update does: a button for every member, made from the template the
-- addon named and run through its initialConfigFunction, each pointed at its unit.
function M.UpdateHeader(header)
	M.Secure(function()
		local units = HeaderUnits(header)
		local template = header:GetAttribute("template")
		for index, unit in ipairs(units) do
			local button = header:GetAttribute("child" .. index)
			if not button then
				button = CreateFrame("Button", (header.name or "Header") .. "UnitButton" .. index, header, template)
				header.attributes["child" .. index] = button
				local config = header:GetAttribute("initialConfigFunction")
				if config then
					assert(loadstring("return function(self) " .. config .. "\nend", "@initialConfigFunction"))()(button)
				end
			end
			button:SetAttribute("unit", unit)
			button:Show()
		end
		local index = #units + 1
		while header:GetAttribute("child" .. index) do
			local button = header:GetAttribute("child" .. index)
			button:SetAttribute("unit", nil)
			button:Hide()
			index = index + 1
		end
	end)
end

-- The roster changed: the game's headers lay their buttons out again (secure code, so also in
-- combat), then everyone is told.
function M.RosterChanged()
	for _, frame in ipairs(M.frames) do
		if frame.isHeader and frame:IsVisible() then
			M.UpdateHeader(frame)
		end
	end
	M.Fire("GROUP_ROSTER_UPDATE")
end

---------------------------------------------------------------------------
-- Events and time
---------------------------------------------------------------------------
-- Sends an event to every frame registered for it. A unit event goes to frames registered for
-- that unit (the first payload value); `...` is handed on as it is, sealed values and all.
function M.Fire(event, ...)
	local unit = ...
	for _, frame in ipairs(M.frames) do
		local registration = frame.events[event]
		if registration and (registration == true or registration[unit]) and frame.scripts.OnEvent then
			frame.scripts.OnEvent(frame, event, ...)
		end
	end
	-- The game's aura containers hear of a unit's auras changing themselves.
	if event == "UNIT_AURA" then
		for _, container in ipairs(M.auraContainers or {}) do
			if container.unitToken == unit then
				container.dirty = true
			end
		end
	end
end

-- The game announces a fight before it locks protected frames and seals what a fight seals, and
-- announces its end after it has let go again: a handler of either event may still change them.
function M.SetCombat(combat)
	if M.combat == combat then
		return
	end
	if combat then
		M.Fire("PLAYER_REGEN_DISABLED")
		M.combat = true
	else
		M.combat = false
		M.Fire("PLAYER_REGEN_ENABLED")
	end
end

-- Lets `seconds` pass: frames on screen get their OnUpdate, and timers that have come due run.
function M.Advance(seconds)
	M.now = M.now + seconds
	for _, frame in ipairs(M.frames) do
		if frame.scripts.OnUpdate and frame:IsVisible() then
			frame.scripts.OnUpdate(frame, seconds)
		end
	end
	M.FillAuraContainers()
	local waiting = M.timers
	M.timers = {}
	for _, timer in ipairs(waiting) do
		if timer.due <= M.now then
			timer.fn()
		else
			M.timers[#M.timers + 1] = timer
		end
	end
end

---------------------------------------------------------------------------
-- Units
---------------------------------------------------------------------------
-- M.SetUnit(token, { name =, class =, level =, health =, healthMax =, power =, powerMax =,
--   powerType = 0, powerToken = "MANA", isPlayer =, playerControlled =, inGroup =, reaction = 5,
--   dead =, ghost =, connected = true, combat =, tapped =, classification = "normal", canAttack =,
--   leader =, inRange = true, rangeChecked = true, raidMark =, threat =, incomingHeals =,
--   cast = { name =, icon =, start =, length =, channel =, shielded =, id = },
--   auras = { { id =, icon =, helpful =, stacks =, length =, mine =, removable =, kind = } },
--   resurrecting = }), or M.SetUnit(token, nil) to remove it.
local UNIT_DEFAULTS = {
	name = "Someone", class = "WARRIOR", level = 60, health = 100, healthMax = 100, power = 100, powerMax = 100,
	powerType = 0, powerToken = "MANA", isPlayer = false, playerControlled = false, inGroup = false, reaction = 4,
	connected = true, classification = "normal", inRange = true, rangeChecked = true,
}

function M.SetUnit(token, fields)
	if fields == nil then
		M.units[token] = nil
		return
	end
	local unit = {}
	for key, value in pairs(UNIT_DEFAULTS) do
		unit[key] = value
	end
	for key, value in pairs(fields) do
		unit[key] = value
	end
	unit.auras = unit.auras or {}
	M.units[token] = unit
	return unit
end

local function Unit(token, what)
	if insecure() and IsSealed(token) then
		error(what .. " does not accept a sealed unit from addon code", 3)
	end
	return M.units[token]
end

-- The conditions Blizzard documents (SecretPredicatesDocumentation.lua).
-- Who a unit is: sealed for anything that is not a player's and not in the group. Players of
-- this client report that in the open world a creature's name and GUID can be read all the same,
-- and that it is inside dungeons that they cannot: M.openWorld = true stands for the first.
local function IdentitySealed(unit) return not M.openWorld and not (unit.playerControlled or unit.inGroup) end
local function HealthMaxSealed(unit) return not unit.playerControlled end
local function PowerSealed(unit) return not M.plainPower[unit.powerType] end
local function CastSealed(token) return token ~= "player" and token ~= "pet" end

-- Never sealed.
function UnitExists(token) return Unit(token, "UnitExists") ~= nil end
function UnitIsConnected(token) local unit = Unit(token, "UnitIsConnected") return unit ~= nil and unit.connected end
function UnitIsDead(token) local unit = Unit(token, "UnitIsDead") return unit ~= nil and (unit.dead or false) end
function UnitIsGhost(token) local unit = Unit(token, "UnitIsGhost") return unit ~= nil and (unit.ghost or false) end
function UnitIsDeadOrGhost(token) return UnitIsDead(token) or UnitIsGhost(token) end
function UnitIsPlayer(token) local unit = Unit(token, "UnitIsPlayer") return unit ~= nil and unit.isPlayer end
function UnitLevel(token) local unit = Unit(token, "UnitLevel") return unit and unit.level or 0 end
function UnitClassification(token) local unit = Unit(token, "UnitClassification") return unit and unit.classification or "normal" end
function UnitReaction(token, other) local unit = Unit(token, "UnitReaction") Plain("UnitReaction", other) return unit and unit.reaction end
function UnitIsTapDenied(token) local unit = Unit(token, "UnitIsTapDenied") return unit ~= nil and (unit.tapped or false) end
function UnitCanAttack(attacker, token) local unit = Unit(token, "UnitCanAttack") return unit ~= nil and (unit.canAttack or false) end
function UnitAffectingCombat(token) local unit = Unit(token, "UnitAffectingCombat") return unit ~= nil and (unit.combat or false) end
function UnitPlayerControlled(token) local unit = Unit(token, "UnitPlayerControlled") return unit ~= nil and (unit.playerControlled or false) end
-- Marked for fighting other players: sealed like the rest of who a unit is; the side it fights
-- for and "everyone's enemy" are not.
function UnitIsPVP(token)
	local unit = Unit(token, "UnitIsPVP")
	if not unit then
		return false
	end
	return SealIf(not (unit.playerControlled or unit.inGroup), unit.pvp or false)
end
function UnitIsPVPFreeForAll(token) local unit = Unit(token, "UnitIsPVPFreeForAll") return unit ~= nil and (unit.freeForAll or false) end
function UnitFactionGroup(token) local unit = Unit(token, "UnitFactionGroup") return unit and unit.faction end
-- The part taken in a group: sealed for anyone outside it.
function UnitGroupRolesAssigned(token)
	local unit = Unit(token, "UnitGroupRolesAssigned")
	if not unit then
		return "NONE"
	end
	return SealIf(not (unit.playerControlled or unit.inGroup), unit.role or "NONE")
end
-- Whether two unit names stand for the same creature. This model tells creatures apart by name.
function UnitIsUnit(token, other)
	local unit, second = Unit(token, "UnitIsUnit"), Unit(other, "UnitIsUnit")
	return SealIf(M.sealComparisons, unit ~= nil and second ~= nil and unit.name == second.name)
end
-- A GUID as the game writes one: a creature's carries the number of its kind (unit.npc) in the
-- sixth place, a player's has three parts, a pet's starts with "Pet".
function UnitGUID(token)
	local unit = Unit(token, "UnitGUID")
	if not unit then
		return nil
	end
	local guid
	if unit.isPlayer then
		guid = "Player-4444-" .. unit.name
	else
		guid = ("%s-0-4444-0-12-%d-00001A2B3C"):format(unit.isPet and "Pet" or "Creature", unit.npc or 0)
	end
	return SealIf(IdentitySealed(unit), guid)
end
C_PetInfo = {
	GetPetHappiness = function()
		if M.petHappiness then
			return M.petHappiness, 100, 0
		end
	end,
}

-- What Blizzard's own unit frames answer the ping key with, mixed into a frame.
PingableType_UnitFrameMixin = {
	GetIsPingable = function() return true end,
	GetAllowRadialWheel = function() return true end,
	GetTargetInfo = function(self) return { guid = UnitGUID(self.unit or self:GetAttribute("unit")) } end,
}

-- The ping key pressed with the mouse over a frame: whom the ping is for, or nil when the frame
-- does not take pings and the ping falls through to the world behind it.
function M.PingOver(frame)
	if not frame:GetAttribute("ping-receiver") or not frame.GetIsPingable then
		return nil
	end
	return M.Secure(function()
		if frame:GetIsPingable() then
			return frame:GetTargetInfo().guid
		end
	end)
end
function UnitHasIncomingResurrection(token) local unit = Unit(token, "UnitHasIncomingResurrection") return unit ~= nil and (unit.resurrecting or false) end
function GetReadyCheckStatus(token) Unit(token, "GetReadyCheckStatus") return M.readyCheck[token] end
function UnitPowerType(token)
	local unit = Unit(token, "UnitPowerType")
	if not unit then
		return nil
	end
	return unit.powerType, unit.powerToken
end
function UnitIsEnemy(token, other) local unit = Unit(token, "UnitIsEnemy") return unit ~= nil and (unit.reaction or 4) <= 3 end
function UnitIsFriend(other, token) local unit = Unit(token, "UnitIsFriend") return unit ~= nil and (unit.reaction or 4) >= 5 end
function IsTargetLoose() return M.looseTarget or false end
C_PlayerInteractionManager = { IsReplacingUnit = function() return false end }
SOUNDKIT = { IG_CREATURE_AGGRO_SELECT = 873, IG_CHARACTER_NPC_SELECT = 867, IG_CREATURE_NEUTRAL_SELECT = 871, INTERFACE_SOUND_LOST_TARGET_UNIT = 684 }
C_Sound = {
	PlaySound = function(sound, subType, noDuplicates)
		Plain("C_Sound.PlaySound", sound, subType, noDuplicates)
		assert(type(sound) == "number", "PlaySound needs a sound kit id")
		M.sounds[#M.sounds + 1] = sound
	end,
}
function GetNumGroupMembers()
	if M.raidSize > 0 then
		return M.raidSize
	end
	return M.partySize > 0 and M.partySize + 1 or 0
end
function SetPortraitTexture(texture, token)
	Unit(token, "SetPortraitTexture")
	texture.portraitOf = token
end

-- Health: UnitHealth and what is worked out from it are always sealed (SecretReturns).
function UnitHealth(token) local unit = Unit(token, "UnitHealth") return Seal(unit and unit.health or 0) end
function UnitHealthMax(token)
	local unit = Unit(token, "UnitHealthMax")
	if not unit then
		return 0
	end
	return SealIf(HealthMaxSealed(unit), unit.healthMax)
end
function UnitHealthMissing(token) local unit = Unit(token, "UnitHealthMissing") return Seal(unit and unit.healthMax - unit.health or 0) end
function UnitHealthPercent(token, usePredicted, curve)
	local unit = Unit(token, "UnitHealthPercent")
	Plain("UnitHealthPercent", usePredicted)
	local share = unit and unit.healthMax > 0 and unit.health / unit.healthMax or 0
	return Through(curve, share, true)
end
function UnitGetIncomingHeals(token)
	local unit = Unit(token, "UnitGetIncomingHeals")
	if not unit or not unit.incomingHeals then
		return nil
	end
	return Seal(unit.incomingHeals)
end

-- What is soaking up damage for the unit: always sealed (SecretReturns).
function UnitGetTotalAbsorbs(token) local unit = Unit(token, "UnitGetTotalAbsorbs") return Seal(unit and unit.absorb or 0) end

-- The game's calculator for healing on its way and shields: an object that is filled with a
-- unit's numbers and hands back, sealed, how much of a shield fits under the rule it was given
-- (Enum.UnitDamageAbsorbClampMode), and whether there was more than that.
Enum.UnitDamageAbsorbClampMode = { MissingHealth = 0, MissingHealthWithoutIncomingHeals = 1, MaximumHealth = 2 }
M.calculators = 0
function CreateUnitHealPredictionCalculator()
	M.calculators = M.calculators + 1
	local calculator = { mode = 0, health = 0, healthMax = 0, heals = 0, absorb = 0 }
	function calculator:SetDamageAbsorbClampMode(mode)
		Plain("SetDamageAbsorbClampMode", mode)
		assert(mode == 0 or mode == 1 or mode == 2, "SetDamageAbsorbClampMode: not a clamp mode: " .. tostring(mode))
		self.mode = mode
	end
	function calculator:GetDamageAbsorbs()
		local room = self.healthMax
		if self.mode == 0 then
			room = math.max(0, self.healthMax - self.health - self.heals)
		elseif self.mode == 1 then
			room = math.max(0, self.healthMax - self.health)
		end
		return Seal(math.min(self.absorb, room)), Seal(self.absorb > room)
	end
	return calculator
end
function UnitGetDetailedHealPrediction(token, healer, calculator)
	local unit = Unit(token, "UnitGetDetailedHealPrediction")
	Plain("UnitGetDetailedHealPrediction's healer", healer)
	assert(type(calculator) == "table" and calculator.GetDamageAbsorbs, "UnitGetDetailedHealPrediction needs a calculator")
	calculator.health = unit and unit.health or 0
	calculator.healthMax = unit and unit.healthMax or 0
	calculator.heals = unit and unit.incomingHeals or 0
	calculator.absorb = unit and unit.absorb or 0
end

-- Power. A unit has the power it runs on, and a druid in a form has mana besides (mana, manaMax);
-- `powerless` is something that runs on a power in name only. Asked for a power it does not
-- have, the game answers a plain nought: how much there is is sealed "unless the subject unit
-- does not have a power of this type".
local function PowerOf(unit, powerType)
	if unit.powerless then
		return 0, 0, false
	elseif powerType == nil or powerType == unit.powerType then
		return unit.power, unit.powerMax, true
	elseif powerType == 0 and unit.manaMax then
		return unit.mana or 0, unit.manaMax, true
	end
	return 0, 0, false
end
function UnitPower(token, powerType)
	local unit = Unit(token, "UnitPower")
	Plain("UnitPower", powerType)
	if not unit then
		return 0
	end
	local now, _, has = PowerOf(unit, powerType)
	return SealIf(has and not M.plainPower[powerType or unit.powerType], now)
end
function UnitPowerMax(token, powerType)
	local unit = Unit(token, "UnitPowerMax")
	Plain("UnitPowerMax", powerType)
	if not unit then
		return 0
	end
	local _, most, has = PowerOf(unit, powerType)
	return SealIf((has and not M.plainPower[powerType or unit.powerType]) or not unit.playerControlled, most)
end
function UnitPowerPercent(token, powerType, unmodified, curve)
	local unit = Unit(token, "UnitPowerPercent")
	Plain("UnitPowerPercent", powerType, unmodified)
	local share = unit and unit.powerMax > 0 and unit.power / unit.powerMax or 0
	return Through(curve, share, unit ~= nil and PowerSealed(unit))
end
function GetComboPoints(attacker, target)
	Plain("GetComboPoints", attacker, target)
	return SealIf(not M.plainPower.combo, M.comboPoints)
end

-- Identity: sealed unless the unit is a player's or in the group.
-- On this client the second answer is a character's surname (unit.surname); a creature has none.
function UnitName(token)
	local unit = Unit(token, "UnitName")
	if not unit then
		return nil
	end
	local sealed = IdentitySealed(unit)
	return SealIf(sealed, unit.name), SealIf(sealed and unit.surname ~= nil, unit.surname)
end
-- Characters are named by first name and surname, unique across a region, and a player may hide
-- their own surname (M.hideOwnSurname).
function RegionalUniqueNamesEnabled() return not M.realmNames end
C_PlayerInfo = {
	ShouldDisplaySurname = function() return not M.hideOwnSurname end,
}
Constants = Constants or {}
Constants.CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " ", CHARACTERNAME_REALMNAME_SEPARATOR = "-" }
function UnitClass(token)
	local unit = Unit(token, "UnitClass")
	if not unit then
		return nil
	end
	local sealed = IdentitySealed(unit)
	return SealIf(sealed, unit.class), SealIf(sealed, unit.class), SealIf(sealed, 1)
end
function UnitIsGroupLeader(token)
	local unit = Unit(token, "UnitIsGroupLeader")
	if not unit then
		return false
	end
	return SealIf(IdentitySealed(unit), unit.leader or false)
end

-- Range and raid marks: always sealed (SecretReturns). No mark is a plain nil.
function UnitInRange(token)
	local unit = Unit(token, "UnitInRange")
	if not unit then
		return Seal(false), Seal(false)
	end
	return Seal(unit.inRange), Seal(unit.rangeChecked)
end
function GetRaidTargetIndex(token)
	local unit = Unit(token, "GetRaidTargetIndex")
	if not unit or not unit.raidMark then
		return nil
	end
	return Seal(unit.raidMark)
end

-- Threat: a one-unit query is "generally not secret"; M.sealThreat makes it so.
function UnitThreatSituation(token, mob)
	local unit = Unit(token, "UnitThreatSituation")
	Plain("UnitThreatSituation", mob)
	if not unit or unit.threat == nil then
		return nil
	end
	return SealIf(M.sealThreat, unit.threat)
end

-- Casting: sealed unless the unit is the player or the pet. The cast bar id never is.
function UnitCastingDuration(token)
	local unit = Unit(token, "UnitCastingDuration")
	local cast = unit and unit.cast
	if not cast or cast.channel then
		return nil
	end
	return Duration(cast.start, cast.length, CastSealed(token))
end
function UnitChannelDuration(token)
	local unit = Unit(token, "UnitChannelDuration")
	local cast = unit and unit.cast
	if not cast or not cast.channel then
		return nil
	end
	return Duration(cast.start, cast.length, CastSealed(token))
end
function UnitCastingInfo(token)
	local unit = Unit(token, "UnitCastingInfo")
	local cast = unit and unit.cast
	if not cast or cast.channel then
		return nil
	end
	local s = CastSealed(token)
	return SealIf(s, cast.name), SealIf(s, cast.name), SealIf(s, cast.icon), SealIf(s, cast.start * 1000),
		SealIf(s, (cast.start + cast.length) * 1000), false, SealIf(s, "Cast-" .. cast.id), SealIf(s, cast.shielded or false),
		SealIf(s, 133), cast.id, 0
end
function UnitChannelInfo(token)
	local unit = Unit(token, "UnitChannelInfo")
	local cast = unit and unit.cast
	if not cast or not cast.channel then
		return nil
	end
	local s = CastSealed(token)
	return SealIf(s, cast.name), SealIf(s, cast.name), SealIf(s, cast.icon), SealIf(s, cast.start * 1000),
		SealIf(s, (cast.start + cast.length) * 1000), false, SealIf(s, cast.shielded or false), SealIf(s, 133), false, 0, cast.id
end

-- Totems: sealed while combat restrictions are in force.
function GetTotemInfo(slot)
	Plain("GetTotemInfo", slot)
	local totem = M.totems[slot]
	local s = M.combat
	if not totem then
		-- In a fight the game answers "there is a totem" for the slot of every element the shaman
		-- has learnt, standing or not (M.emptySlotsSayYes); an empty one has no time on it.
		return SealIf(s, s and M.emptySlotsSayYes or false), SealIf(s, ""), SealIf(s, 0), SealIf(s, 0), SealIf(s, 0)
	end
	return SealIf(s, true), SealIf(s, totem.name or "Totem"), SealIf(s, totem.start), SealIf(s, totem.length), SealIf(s, totem.icon)
end
function GetTotemDuration(slot)
	Plain("GetTotemDuration", slot)
	local totem = M.totems[slot]
	return Duration(totem and totem.start or 0, totem and totem.length or 0, M.combat)
end

---------------------------------------------------------------------------
-- Auras: what they are is sealed while combat restrictions are in force; their ids never are.
---------------------------------------------------------------------------
local function AuraOf(token, id)
	local unit = M.units[token]
	for _, aura in ipairs(unit and unit.auras or {}) do
		if aura.id == id then
			return aura
		end
	end
end

local KNOWN_FILTERS = { HELPFUL = true, HARMFUL = true, PLAYER = true, RAID = true }

C_UnitAuras = {
	GetUnitAuraInstanceIDs = function(token, filter, limit, sortRule, sortDirection)
		local unit = Unit(token, "GetUnitAuraInstanceIDs")
		Plain("GetUnitAuraInstanceIDs", filter, limit, sortRule, sortDirection)
		assert(type(filter) == "string", "GetUnitAuraInstanceIDs needs a filter")
		local wanted = {}
		for word in filter:gmatch("[^|]+") do
			assert(KNOWN_FILTERS[word], "this model has no aura filter '" .. word .. "'")
			wanted[word] = true
		end
		local ids = {}
		for _, aura in ipairs(unit and unit.auras or {}) do
			local fits = (not wanted.HELPFUL or aura.helpful) and (not wanted.HARMFUL or not aura.helpful)
				and (not wanted.PLAYER or aura.mine)
				-- RAID: a buff the player can cast, or a debuff the player can remove.
				and (not wanted.RAID or (aura.helpful and aura.mine) or (not aura.helpful and aura.removable))
			if fits and (not limit or #ids < limit) then
				ids[#ids + 1] = aura.id
			end
		end
		return ids
	end,
	GetAuraDataByAuraInstanceID = function(token, id)
		Unit(token, "GetAuraDataByAuraInstanceID")
		Plain("GetAuraDataByAuraInstanceID", id)
		local aura = AuraOf(token, id)
		if not aura then
			return nil
		end
		local s = M.combat
		return {
			auraInstanceID = id, icon = SealIf(s, aura.icon), applications = SealIf(s, aura.stacks or 0),
			isHelpful = SealIf(s, aura.helpful or false), name = SealIf(s, aura.name or "Aura"),
		}
	end,
	GetAuraDuration = function(token, id)
		Unit(token, "GetAuraDuration")
		Plain("GetAuraDuration", id)
		local aura = AuraOf(token, id)
		if not aura then
			return nil
		end
		return Duration(M.now, aura.length or 0, M.combat)
	end,
	GetAuraApplicationDisplayCount = function(token, id, minimum, maximum)
		Unit(token, "GetAuraApplicationDisplayCount")
		Plain("GetAuraApplicationDisplayCount", id, minimum, maximum)
		local aura = AuraOf(token, id)
		if not aura then
			return nil
		end
		local stacks = aura.stacks or 0
		return SealIf(M.combat, stacks >= (minimum or 2) and tostring(stacks) or "")
	end,
	GetAuraDispelTypeColor = function(token, id, curve)
		Unit(token, "GetAuraDispelTypeColor")
		Plain("GetAuraDispelTypeColor", id)
		local aura = AuraOf(token, id)
		if not aura then
			return nil
		end
		assert(curve and curve.isColor, "GetAuraDispelTypeColor needs a colour curve")
		return Through(curve, aura.kind or 0, M.combat)
	end,
}

---------------------------------------------------------------------------
-- The game's aura container (Blizzard_AuraContainer)
---------------------------------------------------------------------------
-- While auras are sealed, an addon may not ask the game about a unit's auras at all: every
-- C_UnitAuras question above raises an error (the precondition RequiresUnitAuraAccess, failure
-- mode "Error"; in the game: "Auras cannot be accessed when secret while tainted by <addon>").
-- What an addon has instead is this: a frame it creates and sets up, which the game's own code
-- fills with one button for each aura. The addon makes the parts of a button (an icon, a sweep,
-- a count, a rim) as the button is created and hands them to it; the game puts the aura on
-- them. Once made, a button may not be touched by addon code while auras are sealed.
--
-- This model does what the game's code does with such a container, as the game's code.
do
	local guarded = { "GetUnitAuraInstanceIDs", "GetAuraDataByAuraInstanceID", "GetAuraDuration", "GetAuraApplicationDisplayCount", "GetAuraDispelTypeColor" }
	for _, name in ipairs(guarded) do
		local answer = C_UnitAuras[name]
		C_UnitAuras[name] = function(...)
			if M.combat and insecure() then
				M.auraRefusals = (M.auraRefusals or 0) + 1
				error(name .. "(): Auras cannot be accessed when secret while tainted by 'PugUnitFrames'", 2)
			end
			return answer(...)
		end
	end
end

AuraContainerSortMethod = { Default = 0, BigDefensive = 1, UnitFrameDebuff = 2, ImportantOnly = 3, Expiration = 4, ExpirationOnly = 5, Name = 6, NameOnly = 7, AuraInstanceIDOnly = 8 }
AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
AnchorUtil = { FlowLayoutAxis = { Horizontal = 0, Vertical = 1 }, FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 } }
Enum.CustomAuraButtonDispelTypeTextureStyle = { Border = 0, BorderWithIcon = 1, Icon = 2, PreserveAsset = 3, CustomAsset = 4 }

local AuraContainer, AuraButton = {}, {}
Inherit(AuraContainer, Frame)
M.auraContainers = {}

local BATCH = 10 -- buttons the game makes at a time, so that their making says nothing about the auras
local FILTER_WORDS = { HELPFUL = true, HARMFUL = true, PLAYER = true, RAID = true, CANCELABLE = true }

local function ValidFilter(filter)
	assert(type(filter) == "string", "an aura filter must be a string")
	for word in filter:gmatch("[^|%s]+") do
		local bare = word:gsub("^!", "")
		assert(FILTER_WORDS[bare] and not M.unknownFilters[bare], "Unknown aura filter component: '" .. bare .. "'")
	end
	return true
end

local function InEnum(enum, value)
	for _, known in pairs(enum) do
		if known == value then
			return true
		end
	end
	return false
end

local function IsDescendant(region, owner)
	local parent = region.owner or region.parent
	while parent do
		if parent == owner then
			return true
		end
		parent = parent.owner or parent.parent
	end
	return false
end

-- A part handed to a button has to be the button's own: one of its regions, or of a frame on it.
local function Own(button, object, widget, what)
	assert(type(object) == "table", what .. ": bad object in function call")
	if widget == "AnimationGroup" then
		assert(rawget(object, "animations"), what .. ": expected object type 'AnimationGroup'")
	else
		assert(object.widget == widget, what .. ": expected object type '" .. widget .. "', got '" .. tostring(object.widget) .. "'")
	end
	assert(IsDescendant(object, button), what .. ": must be the owner or a direct or indirect descendant of owner")
	return object
end

-- Addon code may not touch a finished button while auras are sealed.
local function Restricted(button, what)
	if rawget(button, "restricted") and M.combat and insecure() then
		M.blocked[#M.blocked + 1] = "AuraButton:" .. what
		error("AuraButton:" .. what .. "(): access denied while auras are secret", 3)
	end
end
-- A button is one of the game's buttons with every call guarded. What only looks (is it shown,
-- how large is it) is left open here for the scenarios to read; the addon itself never asks.
local LOOKS = { IsShown = true, IsVisible = true, GetParent = true, GetWidth = true, GetHeight = true, GetFrameLevel = true, GetScript = true }
for name, method in pairs(Button) do
	if type(method) == "function" then
		if LOOKS[name] then
			AuraButton[name] = method
		else
			AuraButton[name] = function(self, ...)
				Restricted(self, name)
				return method(self, ...)
			end
		end
	end
end

-- The game brings a button's display up to date the moment a part is handed over: with no aura
-- on it, a question mark for the icon and an empty count. So a count has to have its font by then.
function AuraButton:SetIcon(texture)
	Restricted(self, "SetIcon")
	self.parts.icon = Own(self, texture, "Texture", "SetIcon")
	texture.texture = "Interface\\Icons\\INV_Misc_QuestionMark"
end
function AuraButton:SetDurationCooldown(cooldown) Restricted(self, "SetDurationCooldown") self.parts.cooldown = Own(self, cooldown, "Cooldown", "SetDurationCooldown") end
function AuraButton:SetApplicationCount(text, options)
	Restricted(self, "SetApplicationCount")
	assert(options == nil or type(options) == "table", "SetApplicationCount: options must be a table or nil")
	self.parts.count = Own(self, text, "FontString", "SetApplicationCount")
	text:SetText("")
end
local DISPEL_OPTIONS = { showAlways = "boolean", showWhenHarmful = "boolean", showWhenHelpful = "boolean", showWithoutDispelType = "boolean",
	style = "number", customDispelColorCurve = "table", customDispelColorMap = "table", customDispelAssetMap = "table", stealableFilter = "number" }
function AuraButton:AddDispelTypeTexture(texture, options)
	Restricted(self, "AddDispelTypeTexture")
	Own(self, texture, "Texture", "AddDispelTypeTexture")
	options = options or {}
	for key, value in pairs(options) do
		assert(DISPEL_OPTIONS[key], "AddDispelTypeTexture: unknown option '" .. tostring(key) .. "'")
		assert(type(value) == DISPEL_OPTIONS[key], "AddDispelTypeTexture: option '" .. key .. "' must be a " .. DISPEL_OPTIONS[key])
	end
	if options.style ~= nil then
		assert(InEnum(Enum.CustomAuraButtonDispelTypeTextureStyle, options.style), "AddDispelTypeTexture: bad style")
	end
	assert(options.customDispelColorCurve == nil or options.customDispelColorCurve.isColor, "customDispelColorCurve must be a colour curve")
	for _, known in ipairs(self.parts.dispel) do
		assert(known.texture ~= texture, "Display element has already been added.")
	end
	self.parts.dispel[#self.parts.dispel + 1] = {
		texture = texture, showAlways = options.showAlways or false,
		harmful = options.showWhenHarmful ~= false, helpful = options.showWhenHelpful or false,
		untyped = options.showWithoutDispelType or false, curve = options.customDispelColorCurve,
		-- With no style given the game puts its own bordered picture on the texture.
		style = options.style or Enum.CustomAuraButtonDispelTypeTextureStyle.BorderWithIcon,
	}
end
function AuraButton:AddAuraShownAnimation(group)
	Restricted(self, "AddAuraShownAnimation")
	self.parts.shownAnimations[#self.parts.shownAnimations + 1] = Own(self, group, "AnimationGroup", "AddAuraShownAnimation")
end
local TOOLTIP_ANCHORS = { ANCHOR_LEFT = true, ANCHOR_RIGHT = true, ANCHOR_BOTTOMLEFT = true, ANCHOR_BOTTOM = true, ANCHOR_BOTTOMRIGHT = true,
	ANCHOR_TOPLEFT = true, ANCHOR_TOP = true, ANCHOR_TOPRIGHT = true, ANCHOR_CURSOR = true, ANCHOR_NONE = true, ANCHOR_PRESERVE = true }
function AuraButton:SetTooltipAnchorPoint(point, x, y)
	Restricted(self, "SetTooltipAnchorPoint")
	assert(TOOLTIP_ANCHORS[point], "point must be a valid tooltip anchor point name")
	assert((x == nil or type(x) == "number") and (y == nil or type(y) == "number"), "offsets must be numbers or nil")
	self.tooltipAnchor = point
end
function AuraButton:SetHideTooltipInCombat(hide) Restricted(self, "SetHideTooltipInCombat") self.tooltipHideInCombat = hide == true end

-- The game's own code puts an aura on a button, or takes it off.
local function Apply(button, token, aura)
	local parts, sealed = button.parts, M.combat
	button.aura, button.unit = aura, aura and token or nil
	if parts.icon then
		parts.icon.texture = aura and SealIf(sealed, aura.icon) or nil
	end
	if parts.count then
		local stacks = aura and aura.stacks or 0
		parts.count.text = aura and SealIf(sealed, stacks > 1 and tostring(stacks) or "") or ""
	end
	if parts.cooldown then
		parts.cooldown.duration = Duration(M.now, aura and aura.length or 0, sealed)
	end
	for _, dispel in ipairs(parts.dispel) do
		local show = aura ~= nil and (dispel.showAlways
			or (((aura.helpful and dispel.helpful) or (not aura.helpful and dispel.harmful)) and ((aura.kind or 0) ~= 0 or dispel.untyped)))
		dispel.texture.shown = show and true or false
		if show and dispel.curve then
			local color = Through(dispel.curve, aura.kind or 0, sealed)
			dispel.texture.vertex = { color:GetRGBA() }
		end
	end
	local was = button.shown
	button.shown = aura ~= nil
	for _, group in ipairs(parts.shownAnimations) do
		if button.shown and not was then
			group:Play()
		elseif not button.shown then
			group:Stop()
		end
	end
end

local function NewButton(container, initializeFrame)
	local button = M.Secure(CreateFrame, "AuraButton", nil, container)
	button.parts = { dispel = {}, shownAnimations = {} }
	button.shown = false
	button.mouse = true
	if initializeFrame then
		-- The addon's own function, run as addon code, before the button is closed to it.
		local saved = M.secure
		M.secure = 0
		local ok, problem = pcall(initializeFrame, button)
		M.secure = saved
		if not ok then
			error(problem, 0)
		end
	end
	rawset(button, "restricted", true)
	return button
end

local function Matches(aura, filter, candidates)
	for word in filter:gmatch("[^|%s]+") do
		local negated = word:sub(1, 1) == "!"
		local bare = negated and word:sub(2) or word
		local fits = true
		if bare == "HELPFUL" then
			fits = aura.helpful and true or false
		elseif bare == "HARMFUL" then
			fits = not aura.helpful
		elseif bare == "PLAYER" then
			fits = aura.mine and true or false
		elseif bare == "RAID" then
			-- A buff the player can cast, or a debuff the player can remove.
			fits = (aura.helpful and aura.mine) or (not aura.helpful and aura.removable) or false
		end
		if fits == negated then
			return false
		end
	end
	if candidates then
		if candidates.isFromPlayerOrPlayerPet ~= nil and (aura.mine or false) ~= candidates.isFromPlayerOrPlayerPet then
			return false
		end
		if candidates.maxDuration ~= nil and ((aura.length or 0) == 0 or aura.length > candidates.maxDuration) then
			return false
		end
	end
	return true
end

local CANDIDATE_FIELDS = { includeSpellIDs = "table", excludeSpellIDs = "table", includeDispelTypes = "table", excludeDispelTypes = "table",
	maxDuration = "number", isFromPlayerOrPlayerPet = "boolean", isStealable = "boolean", isBossAura = "boolean" }
local LAYOUT_FIELDS = { elementSpacing = "number", lineSpacing = "number", groupSpacing = "number", groupLineSpacing = "number",
	forceNewLine = "boolean", elementWidth = "number", elementHeight = "number", layoutIndex = "number" }

local function CheckFields(what, given, known)
	assert(given == nil or type(given) == "table", what .. " must be a table or nil.")
	for key, value in pairs(given or {}) do
		assert(known[key], what .. ": unknown field '" .. tostring(key) .. "'")
		assert(type(value) == known[key], what .. "." .. key .. " must be a " .. known[key])
	end
	return given
end

local function CheckCount(count)
	assert(count == math.huge or (type(count) == "number" and count >= 0 and count == math.floor(count)), "maxFrameCount must be a non-negative integer or infinity.")
	return count
end

local function Dirty(container)
	container.dirty = true
end

function AuraContainer:GetUnit() return self.unitToken end
function AuraContainer:SetUnit(token)
	assert(type(token) == "string", "SetUnit needs a unit token")
	if self.unitToken ~= token then
		self.unitToken = token
		Dirty(self)
	end
end
function AuraContainer:IsEnabled() return self.enabled == true end
function AuraContainer:SetEnabled(enabled)
	if self.enabled ~= enabled then
		self.enabled = enabled
		Dirty(self)
	end
end
function AuraContainer:UpdateAllAuras() self.refreshes = self.refreshes + 1 Dirty(self) end
function AuraContainer:SetEditModePreviewEnabled(enabled) self.editModePreview = enabled == true end

function AuraContainer:HasAuraGroup(key) return self.groupByKey[key] ~= nil end
local function Group(self, key)
	return self.groupByKey[key] or error(("aura group '%s' was not found with this key."):format(tostring(key)), 3)
end
function AuraContainer:AddAuraGroup(key, filter, options)
	assert(type(key) == "string" and key ~= "", "groupKey must be a non-empty string.")
	ValidFilter(filter)
	assert(not self.groupByKey[key], ("aura group '%s' already exists with this key."):format(key))
	options = options or {}
	assert(options.initializeFrame == nil or type(options.initializeFrame) == "function", "initializeFrame must be a function or nil.")
	assert(options.templateNames == nil or type(options.templateNames) == "table", "templateNames must be a table or nil.")
	assert(InEnum(AuraContainerSortMethod, options.sortMethod or 0), "sortMethod must be a valid AuraContainerSortMethod.")
	assert(InEnum(AuraContainerSortDirection, options.sortDirection or 0), "sortDirection must be a valid AuraContainerSortDirection.")
	local group = {
		key = key, filter = filter, enabled = true, buttons = {}, shown = {},
		maxFrameCount = CheckCount(options.maxFrameCount == nil and math.huge or options.maxFrameCount),
		candidates = CheckFields("candidateFilters", options.candidateFilters, CANDIDATE_FIELDS),
		layout = CheckFields("layout", options.layout, LAYOUT_FIELDS) or {},
		initializeFrame = options.initializeFrame, registered = #self.groups + 1,
	}
	self.groups[#self.groups + 1] = group
	self.groupByKey[key] = group
	for _ = 1, BATCH do
		group.buttons[#group.buttons + 1] = NewButton(self, group.initializeFrame)
	end
	Dirty(self)
end
function AuraContainer:GetAuraGroupFrameCount(key) local group = self.groupByKey[key] return group and #group.buttons or 0 end
function AuraContainer:GetAuraGroupFrame(key, index) local group = self.groupByKey[key] return group and group.buttons[index] or nil end
function AuraContainer:IsAuraGroupEnabled(key) return Group(self, key).enabled end
function AuraContainer:SetAuraGroupEnabled(key, enabled)
	assert(type(enabled) == "boolean", "enabled must be a boolean.")
	Group(self, key).enabled = enabled
	Dirty(self)
end
function AuraContainer:SetAuraGroupFilterString(key, filter)
	local group = Group(self, key)
	ValidFilter(filter)
	group.filter = filter
	Dirty(self)
end
function AuraContainer:SetAuraGroupMaxFrameCount(key, count)
	Group(self, key).maxFrameCount = CheckCount(count)
	Dirty(self)
end
function AuraContainer:SetAuraGroupCandidateFilters(key, candidates)
	Group(self, key).candidates = CheckFields("candidateFilters", candidates, CANDIDATE_FIELDS)
	Dirty(self)
end
function AuraContainer:SetAuraGroupLayout(key, layout)
	Group(self, key).layout = CheckFields("layout", layout, LAYOUT_FIELDS) or {}
	Dirty(self)
end

-- (The game has no "is there such a slot" for addons; GetAuraSlotFrame answers nil for none.)
local function Slot(self, key)
	return self.slotByKey[key] or error(("aura slot '%s' was not found with this key."):format(tostring(key)), 3)
end
function AuraContainer:AddAuraSlot(key, filter, options)
	assert(type(key) == "string" and key ~= "", "slotKey must be a non-empty string.")
	ValidFilter(filter)
	assert(not self.slotByKey[key], ("aura slot '%s' already exists with this key."):format(key))
	options = options or {}
	assert(options.initializeFrame == nil or type(options.initializeFrame) == "function", "initializeFrame must be a function or nil.")
	local slot = { key = key, filter = filter, enabled = true,
		candidates = CheckFields("candidateFilters", options.candidateFilters, CANDIDATE_FIELDS) }
	slot.button = NewButton(self, options.initializeFrame)
	self.slots[#self.slots + 1] = slot
	self.slotByKey[key] = slot
	Dirty(self)
	return slot.button
end
function AuraContainer:GetAuraSlotFrame(key) local slot = self.slotByKey[key] return slot and slot.button or nil end
function AuraContainer:IsAuraSlotEnabled(key) return Slot(self, key).enabled end
function AuraContainer:SetAuraSlotEnabled(key, enabled)
	assert(type(enabled) == "boolean", "enabled must be a boolean.")
	Slot(self, key).enabled = enabled
	Dirty(self)
end

function AuraContainer:SetFlowLayoutAxis(axis)
	assert(InEnum(AnchorUtil.FlowLayoutAxis, axis), "layoutAxis must be valid.")
	self.flow.axis = axis
	Dirty(self)
end
local POINTS = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true, CENTER = true }
function AuraContainer:SetFlowLayoutAnchorPoint(point)
	assert(type(point) == "string" and POINTS[point], "anchorPoint must be a string.")
	self.flow.anchorPoint = point
	Dirty(self)
end
function AuraContainer:SetFlowLayoutGrowthDirection(horizontal, vertical)
	assert(horizontal == 1 or horizontal == -1, "horizontalDirection must be valid.")
	assert(vertical == 1 or vertical == -1, "verticalDirection must be valid.")
	self.flow.horizontal, self.flow.vertical = horizontal, vertical
	Dirty(self)
end
function AuraContainer:SetFlowLayoutPadding(left, right, top, bottom)
	assert(type(left) == "number" and type(right) == "number" and type(top) == "number" and type(bottom) == "number", "padding must be numbers.")
	self.flow.padding = { left, right, top, bottom }
	Dirty(self)
end
function AuraContainer:SetFlowLayoutMaximumLineSize(size)
	assert(size == nil or type(size) == "number", "maximumLineSize must be a number or nil.")
	self.flow.maximumLineSize = size or math.huge
	Dirty(self)
end

-- What the game's code does when a container has something new to show: the auras each group
-- lets through, in the game's order, one to a button; then the buttons in rows.
local function Fill(container)
	local unit = M.units[container.unitToken]
	local auras = container.enabled and unit and unit.auras or {}
	for _, group in ipairs(container.groups) do
		group.shown = {}
		local used = 0
		if group.enabled then
			for _, aura in ipairs(auras) do
				if used < group.maxFrameCount and Matches(aura, group.filter, group.candidates) then
					used = used + 1
					if not group.buttons[used] then
						for _ = 1, BATCH do
							group.buttons[#group.buttons + 1] = NewButton(container, group.initializeFrame)
						end
					end
					Apply(group.buttons[used], container.unitToken, aura)
					group.shown[used] = group.buttons[used]
				end
			end
		end
		for index = used + 1, #group.buttons do
			Apply(group.buttons[index], nil, nil)
		end
	end
	for _, slot in ipairs(container.slots) do
		local chosen
		if slot.enabled then
			for _, aura in ipairs(auras) do
				if Matches(aura, slot.filter, slot.candidates) then
					chosen = aura
					break
				end
			end
		end
		Apply(slot.button, container.unitToken, chosen)
	end

	-- The rows (the game's flow layout, along the horizontal axis as this addon uses it).
	local flow = container.flow
	assert(flow.axis == AnchorUtil.FlowLayoutAxis.Horizontal, "this model lays aura buttons out along the horizontal axis only")
	local order = {}
	for _, group in ipairs(container.groups) do
		order[#order + 1] = group
	end
	table.sort(order, function(a, b)
		local left, right = a.layout.layoutIndex or a.registered, b.layout.layoutIndex or b.registered
		if left ~= right then
			return left < right
		end
		return a.registered < b.registered
	end)
	local x, y, line, tallest, placed = 0, 0, 0, 0, false
	local width, height = 1, 1
	for _, group in ipairs(order) do
		local layout = group.layout
		local spacing, lineSpacing = layout.elementSpacing or 0, layout.lineSpacing or 0
		if placed and #group.shown > 0 and layout.forceNewLine then
			x, y, line = 0, y + (tallest + (layout.groupLineSpacing or lineSpacing)) * flow.vertical, 0
			tallest = 0
		end
		for _, button in ipairs(group.shown) do
			local w, h = layout.elementWidth or button:GetWidth(), layout.elementHeight or button:GetHeight()
			if line > 0 and line + w > flow.maximumLineSize then
				x, y, line = 0, y + (tallest + lineSpacing) * flow.vertical, 0
				tallest = 0
			end
			button.anchors = { { flow.anchorPoint, container, flow.anchorPoint, x, y } }
			x = x + (w + spacing) * flow.horizontal
			line = line + w + spacing
			tallest = math.max(tallest, h)
			width, height = math.max(width, line - spacing), math.max(height, math.abs(y) + h)
			placed = true
		end
	end
	-- The container takes the size of what it holds; in the game that size is sealed.
	container.width, container.height = width, height
	container.dirty = false
	container.fills = container.fills + 1
end

function M.NewAuraContainer(frame)
	frame.unitToken, frame.enabled, frame.groups, frame.groupByKey, frame.slots, frame.slotByKey = "none", true, {}, {}, {}, {}
	frame.flow = { axis = 0, anchorPoint = "TOPLEFT", horizontal = 1, vertical = -1, padding = { 0, 0, 0, 0 }, maximumLineSize = math.huge }
	frame.dirty, frame.fills, frame.refreshes, frame.wasVisible = true, 0, 0, false
	M.auraContainers[#M.auraContainers + 1] = frame
end

-- The game works a container through on the next screen update, while it is on screen.
function M.FillAuraContainers()
	for _, container in ipairs(M.auraContainers) do
		local visible = container:IsVisible()
		if visible and (container.dirty or not container.wasVisible) then
			M.Secure(Fill, container)
		end
		container.wasVisible = visible
	end
end

-- The buttons of a group that have an aura on them, in order.
function M.AuraButtons(container, key)
	local shown = {}
	for _, button in ipairs(container.groupByKey[key] and container.groupByKey[key].buttons or {}) do
		if button.shown then
			shown[#shown + 1] = button
		end
	end
	return shown
end

CLASSES.AuraContainer = AuraContainer
CLASSES.AuraButton = AuraButton

---------------------------------------------------------------------------
-- Tooltip, settings window, text encoding
---------------------------------------------------------------------------
GameTooltip = {
	SetOwner = function(self, owner, anchor) M.tooltip = { owner = owner } end,
	SetUnit = function(self, unit) Plain("GameTooltip:SetUnit", unit) M.tooltip.unit = unit end,
	SetUnitAuraByAuraInstanceID = function(self, unit, id)
		Plain("GameTooltip:SetUnitAuraByAuraInstanceID", unit, id)
		M.tooltip.unit, M.tooltip.aura = unit, id
	end,
	SetTotem = function(self, slot) Plain("GameTooltip:SetTotem", slot) M.tooltip.totem = slot end,
	Hide = function() M.tooltip = {} end,
}
function GameTooltip_SetDefaultAnchor(tooltip, owner) M.tooltip = { owner = owner } end

Settings = {
	RegisterCanvasLayoutCategory = function(panel, name)
		local category = { panel = panel, name = name, id = #M.settings.categories + 1 }
		function category:GetID() return self.id end
		M.settings.categories[category.id] = category
		return category
	end,
	RegisterCanvasLayoutSubcategory = function(parent, panel, name)
		local category = Settings.RegisterCanvasLayoutCategory(panel, name)
		category.parent = parent
		return category
	end,
	RegisterAddOnCategory = function(category) category.registered = true end,
	-- Opening a page puts its panel on screen; leaving it takes the last one off.
	OpenToCategory = function(id)
		local category = assert(M.settings.categories[id], "no such settings category")
		if M.settings.opened then
			M.settings.opened.panel:Hide()
		end
		M.settings.opened = category
		category.panel:Show()
	end,
}

-- Stand-ins that keep the two properties the addon relies on: what is packed comes back the
-- same, and damaged text is refused (with nil, or with an error for the deserialiser).
local function Serialize(value)
	local kind = type(value)
	if kind == "table" then
		local keys = {}
		for key in pairs(value) do
			keys[#keys + 1] = key
		end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		local parts = {}
		for _, key in ipairs(keys) do
			parts[#parts + 1] = "[" .. Serialize(key) .. "]=" .. Serialize(value[key])
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return ("%q"):format(value)
	end
	return tostring(value)
end

C_EncodingUtil = {
	SerializeCBOR = function(value) return Serialize(value) end,
	DeserializeCBOR = function(source)
		local chunk = loadstring("return " .. source)
		if not chunk then
			error("malformed CBOR")
		end
		setfenv(chunk, {})
		return chunk()
	end,
	CompressString = function(source) return "Z" .. source end,
	DecompressString = function(source)
		if source:sub(1, 1) ~= "Z" then
			return nil
		end
		return source:sub(2)
	end,
	EncodeBase64 = function(source)
		return (source:gsub(".", function(character) return ("%02x"):format(character:byte()) end))
	end,
	DecodeBase64 = function(source)
		if #source % 2 ~= 0 or source:find("[^0-9a-f]") then
			return nil
		end
		return (source:gsub("..", function(pair) return string.char(tonumber(pair, 16)) end))
	end,
}

---------------------------------------------------------------------------
-- The game's own unit frames, for Blizzard.lua
---------------------------------------------------------------------------
for _, name in ipairs({ "PlayerFrame", "TargetFrame", "ComboFrame", "FocusFrame", "PetFrame", "PartyFrame", "CompactRaidFrameContainer", "PlayerCastingBarFrame" }) do
	local frame = CreateFrame("Frame", name, UIParent)
	frame.protected = true
	frame.events = { PLAYER_ENTERING_WORLD = true }
	local bar = CreateFrame("StatusBar", name .. "HealthBar", frame)
	bar.events = { UNIT_HEALTH = true }
end
-- The target frame is one of the game's unit buttons, hidden until there is a target, and plays
-- the sound of losing one as it goes.
TargetFrame.attributes.unit = "target"
TargetFrame.shown = false
TargetFrame.scripts.OnHide = function()
	if not IsTargetLoose() then
		M.sounds[#M.sounds + 1] = SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT
	end
end
-- The target frame's secure aura rows may not have their events touched by an addon.
local rows = CreateFrame("Frame", "TargetFrameAuraRows", TargetFrame)
rows.events = { UNIT_AURA = true }
rows.aspects[Enum.ForbiddenAspect.EventRegistrations] = true
