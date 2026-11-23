local ADDON, ns = ...

-- The look: themes, bar textures, the lettering, and the colours frames are painted with.
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

-- The lettering. The addon brings Inter with it (Fonts\Inter-SemiBold.ttf, under the SIL Open
-- Font License, which is beside it): even strokes and clear figures, drawn to be read small.
Style.FONTS = {
	inter = ns.FONTS .. "Inter-SemiBold.ttf",
	game = STANDARD_TEXT_FONT,
}
Style.FONT_ORDER = { "inter", "game" }

-- Inter has Latin, Greek and Cyrillic letters and no others. Where the game runs in a language
-- written otherwise, its own font is used whatever the setting says, or names would be boxes.
local OTHER_SCRIPT = { koKR = true, zhCN = true, zhTW = true }

-- A theme is a handful of tones. Colours that carry meaning (class, reaction, power, debuff kind)
-- are the same in every theme; `tone` is how strongly they are laid on.
Style.THEMES = {
	slate = {
		back = { 0.05, 0.06, 0.07, 0.90 },   -- behind a whole frame
		edge = { 0.00, 0.00, 0.00, 1.00 },   -- the thin line around it
		text = { 0.95, 0.95, 0.93 },
		quiet = { 0.63, 0.66, 0.69 },        -- lesser text: level, power numbers
		plain = { 0.34, 0.39, 0.44 },        -- a health bar that is not coloured by class or reaction
		tone = 0.84,
		shade = 0.70,  -- how dark the empty part of a bar is: this much of the veil over the bar's own colour
		veil = { 0.00, 0.00, 0.00 }, -- what the empty part of a bar is darkened with
		shadow = 0.85, -- how strong the shadow under a plate is
	},
	night = {
		back = { 0.03, 0.04, 0.08, 0.92 },
		edge = { 0.01, 0.01, 0.03, 1.00 },
		text = { 0.90, 0.93, 1.00 },
		quiet = { 0.55, 0.62, 0.78 },
		plain = { 0.24, 0.33, 0.55 },
		tone = 0.78,
		shade = 0.74,
		veil = { 0.02, 0.05, 0.16 }, -- a deep blue: the empty parts of the bars are what makes the night
		shadow = 0.90,
	},
	hearth = {
		back = { 0.10, 0.07, 0.05, 0.90 },
		edge = { 0.02, 0.01, 0.00, 1.00 },
		text = { 1.00, 0.96, 0.88 },
		quiet = { 0.78, 0.68, 0.54 },
		plain = { 0.52, 0.40, 0.26 },
		tone = 0.92,
		shade = 0.66,
		veil = { 0.15, 0.08, 0.03 }, -- a warm brown
		shadow = 0.80,
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
	{ 0.55, 0.80, 0.66, 0.20 },
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
Style.shadows = true

-- Whether the game can read a font file. It refuses one it cannot: by an error on some clients,
-- by answering no on others, and on some by quietly leaving the text without a font, which
-- would be an error the first time anything is written with it. So the file is tried once, on a
-- piece of text nobody sees, and the answer kept.
local readable = {}
local tryout

local function CanRead(font)
	if readable[font] == nil then
		tryout = tryout or CreateFrame("Frame")
		-- A fresh text has no font yet, so one that has a font afterwards got it from this file.
		local text = tryout:CreateFontString()
		local ran, answer = pcall(text.SetFont, text, font, 12, "")
		readable[font] = ran and answer ~= false and text:GetFont() ~= nil
		if not readable[font] then
			ns.Report(("The font %s could not be loaded (%s). The game's own font is used instead."):format(
				font, ran and "the game would not take it" or tostring(answer)))
		end
	end
	return readable[font]
end

-- Reads the look out of the settings. Frames pick it up on their next Frame.Layout.
function Style.Apply()
	local db = ns.db
	Style.theme = Style.THEMES[db.theme] or Style.THEMES.slate
	Style.texture = Style.TEXTURES[db.texture] or Style.TEXTURES.smooth
	Style.fontSize = db.fontSize
	Style.fontFlags = db.outline and "OUTLINE" or ""
	Style.shadows = db.shadows

	local font = Style.FONTS[db.font] or STANDARD_TEXT_FONT
	if font ~= STANDARD_TEXT_FONT and (OTHER_SCRIPT[GetLocale()] or not CanRead(font)) then
		font = STANDARD_TEXT_FONT
	end
	Style.font = font
end

-- Sets a font string to the font in use at the base size plus `delta`.
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

-- A very light colour (a priest's white, a rogue's yellow) taken down far enough for the light
-- lettering to stand out on it. Only for plain numbers: a sealed colour is drawn as it comes.
local LIGHTEST = 0.62
function Style.Readable(r, g, b)
	local light = 0.30 * r + 0.59 * g + 0.11 * b
	if light > LIGHTEST then
		local down = LIGHTEST / light
		return r * down, g * down, b * down
	end
	return r, g, b
end

-- A plain colour as it looks in the empty part of a bar: under the theme's veil. (A health bar
-- lays the veil over the colour instead, because its colour can be sealed; see Health.lua.)
function Style.Veiled(r, g, b)
	local theme = Style.theme
	local shade, veil = theme.shade, theme.veil
	local left = 1 - shade
	return r * left + veil[1] * shade, g * left + veil[2] * shade, b * left + veil[3] * shade
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
