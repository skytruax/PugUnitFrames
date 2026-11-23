local ADDON, ns = ...

-- The look: themes, bar textures, the font, and the colours frames are painted with.
local Style = {}
ns.Style = Style

local ART = ns.ART

-- Bar fills, drawn by tools/make_art.py.
Style.TEXTURES = {
	smooth = ART .. "Bar-Smooth", -- a soft top-to-bottom shade
	flat = ART .. "Bar-Flat",     -- one even tone
	glass = ART .. "Bar-Glass",   -- a bright band along the top
}
Style.TEXTURE_ORDER = { "smooth", "flat", "glass" }

-- A theme is a handful of tones. Colours that carry meaning (class, reaction, power, debuff kind)
-- are the same in every theme; `tone` is how strongly they are laid on.
Style.THEMES = {
	slate = {
		back = { 0.05, 0.06, 0.07, 0.90 },   -- behind a whole frame
		edge = { 0.00, 0.00, 0.00, 1.00 },   -- the thin line around it
		trough = { 0.14, 0.15, 0.17, 1.00 }, -- the empty part of a bar
		text = { 0.95, 0.95, 0.93 },
		quiet = { 0.63, 0.66, 0.69 },        -- lesser text: level, power numbers
		plain = { 0.34, 0.39, 0.44 },        -- a health bar that is not coloured by class or reaction
		tone = 0.84,
	},
	night = {
		back = { 0.03, 0.04, 0.08, 0.92 },
		edge = { 0.01, 0.01, 0.03, 1.00 },
		trough = { 0.09, 0.11, 0.18, 1.00 },
		text = { 0.90, 0.93, 1.00 },
		quiet = { 0.55, 0.62, 0.78 },
		plain = { 0.24, 0.33, 0.55 },
		tone = 0.78,
	},
	hearth = {
		back = { 0.10, 0.07, 0.05, 0.90 },
		edge = { 0.02, 0.01, 0.00, 1.00 },
		trough = { 0.20, 0.15, 0.11, 1.00 },
		text = { 1.00, 0.96, 0.88 },
		quiet = { 0.78, 0.68, 0.54 },
		plain = { 0.52, 0.40, 0.26 },
		tone = 0.92,
	},
}
Style.THEME_ORDER = { "slate", "night", "hearth" }

-- How a unit stands towards the player (UnitReaction: 1-3 hostile, 4 neutral, 5-8 friendly).
local REACTION = {
	hostile = { 0.84, 0.29, 0.24 },
	neutral = { 0.89, 0.77, 0.31 },
	friendly = { 0.35, 0.74, 0.38 },
	tapped = { 0.52, 0.53, 0.55 },  -- someone else's kill
	gone = { 0.42, 0.43, 0.45 },    -- dead or offline
}
Style.REACTION = REACTION

-- By the power's token, as UnitPowerType names it.
local POWER = {
	MANA = { 0.27, 0.53, 0.93 },
	RAGE = { 0.83, 0.24, 0.22 },
	ENERGY = { 0.94, 0.82, 0.31 },
	FOCUS = { 0.92, 0.56, 0.27 },
}
local POWER_OTHER = { 0.60, 0.62, 0.66 }

-- The kinds of debuff, by the game's id for each (0 none, 1 magic, 2 curse, 3 disease, 4 poison,
-- 9 frenzy; the ids in between are never shown on a debuff).
local DEBUFF_KIND = {
	[0] = { 0.72, 0.16, 0.14 },
	[1] = { 0.27, 0.58, 0.98 },
	[2] = { 0.66, 0.31, 0.92 },
	[3] = { 0.72, 0.52, 0.20 },
	[4] = { 0.27, 0.78, 0.33 },
	[5] = { 0.72, 0.16, 0.14 },
	[9] = { 0.95, 0.47, 0.15 },
	[10] = { 0.72, 0.16, 0.14 },
}

-- Threat outlines: someone is on you, most of it is on you, all of it is on you.
Style.THREAT = {
	{ 0.93, 0.80, 0.27 },
	{ 0.95, 0.55, 0.20 },
	{ 0.90, 0.22, 0.18 },
}

Style.CAST = { 0.93, 0.74, 0.28 }
Style.HEAL = { 0.45, 0.92, 0.55, 0.55 } -- healing on its way, drawn past the end of the health bar
Style.POINT = { 0.96, 0.78, 0.25 }      -- a combo point

---------------------------------------------------------------------------
-- Curves: the game colours by a sealed number through one of these, see Sealed.lua
---------------------------------------------------------------------------
local function ColorCurve(curveType, points)
	local curve = C_CurveUtil.CreateColorCurve()
	curve:SetType(curveType)
	for _, point in ipairs(points) do
		curve:AddPoint(point[1], CreateColor(point[2], point[3], point[4], 1))
	end
	return curve
end

-- Health by how full it is: red when nearly empty, amber at half, green when full.
Style.healthCurve = ColorCurve(Enum.LuaCurveType.Linear, {
	{ 0.00, 0.85, 0.20, 0.18 },
	{ 0.25, 0.85, 0.36, 0.18 },
	{ 0.55, 0.88, 0.76, 0.24 },
	{ 1.00, 0.36, 0.76, 0.36 },
})

do
	local points = {}
	for id, color in pairs(DEBUFF_KIND) do
		points[#points + 1] = { id, color[1], color[2], color[3] }
	end
	table.sort(points, function(a, b) return a[1] < b[1] end)
	Style.debuffKindCurve = ColorCurve(Enum.LuaCurveType.Step, points)
end

---------------------------------------------------------------------------
-- The theme in use
---------------------------------------------------------------------------
Style.theme = Style.THEMES.slate
Style.texture = Style.TEXTURES.smooth
Style.font = STANDARD_TEXT_FONT
Style.fontSize = 11
Style.fontFlags = ""

-- Reads the look out of the settings. Frames pick it up on their next Frame.Layout.
function Style.Apply()
	local db = ns.db
	Style.theme = Style.THEMES[db.theme] or Style.THEMES.slate
	Style.texture = Style.TEXTURES[db.texture] or Style.TEXTURES.smooth
	Style.fontSize = db.fontSize
	Style.fontFlags = db.outline and "OUTLINE" or ""
end

-- Sets a font string to the theme's font at the base size plus `delta`.
function Style.SetFont(text, delta)
	text:SetFont(Style.font, math.max(6, Style.fontSize + (delta or 0)), Style.fontFlags)
	if Style.fontFlags == "" then
		text:SetShadowColor(0, 0, 0, 0.9)
		text:SetShadowOffset(1, -1)
	else
		text:SetShadowOffset(0, 0)
	end
end

-- A plain colour laid on at the theme's strength.
function Style.Toned(color)
	local tone = Style.theme.tone
	return color[1] * tone, color[2] * tone, color[3] * tone
end

function Style.PowerColor(token)
	return Style.Toned(POWER[token] or POWER_OTHER)
end

-- The colour for a unit that is not a player, from how it stands towards the player.
function Style.ReactionColor(unit)
	if UnitIsTapDenied(unit) then
		return Style.Toned(REACTION.tapped)
	end
	local reaction = UnitReaction(unit, "player")
	if not reaction then
		return Style.Toned(REACTION.neutral)
	elseif reaction <= 3 then
		return Style.Toned(REACTION.hostile)
	elseif reaction == 4 then
		return Style.Toned(REACTION.neutral)
	end
	return Style.Toned(REACTION.friendly)
end
