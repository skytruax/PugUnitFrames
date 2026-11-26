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
local L = ns.L

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
Style.CAST_LOCKED = { 0.74, 0.56, 0.42 } -- a cast that cannot be interrupted: a greyed orange, plainly not the cast's gold
Style.HEAL = { 0.45, 0.92, 0.55, 0.55 } -- healing on its way, drawn past the end of the health bar
Style.ABSORB = { 0.66, 0.84, 1.00, 0.72 } -- a shield that soaks up damage, drawn after the health as healing on its way is
Style.POINT = { 0.96, 0.78, 0.25 }      -- a combo point
Style.LEVEL = { 1.00, 0.84, 0.38 }      -- the level of someone who cannot be fought: the gold the game writes levels in

-- The time left on an icon is written by the game, in one of its own fonts: small figures of even
-- width with an outline, the one its own aura icons use.
Style.TIMER_FONT = "NumberFontNormalSmall"

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
Style.fontSize = 11
Style.fontFlags = ""
Style.shadows = true

-- The lettering. Every text is given the game's own font first, which the game always has,
-- and the addon's on top of it where that is the one asked for. The game answers text by text:
-- one it gives the addon's font to carries it from then on, one it does not keeps the game's,
-- at the right size, and either can be written on. Nothing is decided beforehand on a piece of
-- text nobody sees: that is how it was done up to version 0.3.4, and in the game the answer
-- was no for a whole evening, on a file that other addons load in this client.
--
-- What is known of this client: it knows the files that were in an addon's folder when the
-- game was started, and no others until it is started again. C_UIFileAsset.IsKnownFile says
-- which, and a file the game says it does not know is not offered to it at all. Other authors
-- have measured that a font file written after the start is not taken either, not even under
-- a name the game knows. So a refusal is not an error of this addon's and none is recorded
-- for it: /pug status says how many texts carry the addon's font, what the game answered, and
-- what there is to do, which is to start the game again.
--
-- A refusal holds for ten seconds for texts of the same size and style: the game is not asked
-- again with every text. It is asked again when frames are next laid out after that, and once
-- on its own, a little after the session's first refusal. Should it take the file after having
-- refused it, the texts lettered in the game's font meanwhile are lettered again, so that no
-- frame is left in another font than its neighbours.
local GAME = STANDARD_TEXT_FONT
local RETRY_GAP = 10       -- seconds a refusal holds for texts of the same size and style
local MAX_RELETTERS = 3    -- times a session that everything is lettered again on its own
local own                  -- the font file laid on top of the game's; nil: the game's alone
local raised = {}          -- [font] = true: the game raised an error when given it, so it is left alone
local refusal              -- what the game answered the last time it refused `own`: false, or nil for no answer
local refusedAt            -- when that was; nil once a text has taken the font since
local refusedFor = {}      -- [size and style] = when a text of that size and style was last refused
local looked               -- the one look back after the session's first refusal has been set up
local relettering, reletters = false, 0
-- [text] = whether it carries `own` (false: the game refused it there). Only the texts lettered
-- since the look was last read (Style.Apply), while the addon's font was the one asked for.
local lettered = setmetatable({}, { __mode = "k" })

-- Whether this running game knows a file: true, false, or nil where it cannot be asked.
local function Known(file)
	local ask = C_UIFileAsset and C_UIFileAsset.IsKnownFile
	if not ask then
		return nil
	end
	local ran, known = ns.Try(ask, file)
	if ran and type(known) == "boolean" then
		return known
	end
	return nil
end

-- Letters everything again in a moment. Not without end: a game that says yes and no by turns
-- is left with what it has.
local function Reletter()
	if relettering or reletters >= MAX_RELETTERS then
		return
	end
	relettering = true
	reletters = reletters + 1
	ns.After(0.5, function()
		relettering = false
		ns.Refresh()
	end)
end

-- Lays the addon's font over the game's on one text, and says whether the text now carries it.
--
-- The game says so itself: on this client SetFont answers true or false. A yes or a no is
-- taken as it is, and the text is not asked what it holds: nothing in the game has shown that
-- a text gives a font's file back the way it was given, or at once. Only a client that answers
-- nothing at all is judged by the text: by whether what it holds is the game's font or not.
local function LayOwn(text, size, flags)
	local kind = size .. flags
	if refusedFor[kind] and GetTime() - refusedFor[kind] < RETRY_GAP then
		return false
	end
	-- Through ns.Try: an error over the file is kept for /pug status and handed to the game as
	-- any error is.
	local ran, answer = ns.Try(text.SetFont, text, own, size, flags)
	local took = ran and answer and true or false
	if ran and answer == nil then
		-- No answer either way. The text is asked what it holds, with the addon's font on it
		-- and then with the game's. If it had taken the addon's, that is laid on once more and
		-- looked at once more: a game that does not answer is not taken at its word twice.
		local held = text:GetFont()
		text:SetFont(GAME, size, flags)
		local plain = text:GetFont()
		if held ~= nil and held ~= plain then
			ran = ns.Try(text.SetFont, text, own, size, flags)
			if ran then
				local now = text:GetFont()
				took = now ~= nil and now ~= plain
			end
		end
	end
	if not ran then
		-- An error is raised once: the file is left alone after that, and whatever had taken
		-- it before is lettered again, so that everything ends in one font.
		raised[own] = true
		own = nil
		text:SetFont(GAME, size, flags)
		Reletter()
		return false
	end
	if not took then
		-- The game's font again. A refusal is known to leave a text the font it had; should a
		-- client take it away instead, the text has it back, or the next thing written on it
		-- would be an error.
		text:SetFont(GAME, size, flags)
		refusal, refusedAt = answer, GetTime()
		refusedFor[kind] = refusedAt
		if not looked then
			-- One look back, should the game only have been slow: everything is lettered again
			-- a little after the session's first refusal. After that it is asked when frames
			-- are laid out, and not on a timer.
			looked = true
			ns.After(RETRY_GAP + 1, function()
				if own and refusedAt then
					ns.Refresh()
				end
			end)
		end
		return false
	end
	if refusedFor[kind] then
		-- Taken, where a text of this size and style was refused before: the game has changed
		-- its mind. Every refusal is forgotten, and whatever was lettered in the game's font
		-- meanwhile is lettered again. (A game that takes one style and refuses another has
		-- not changed its mind, and is left to answer for each.)
		refusedAt = nil
		wipe(refusedFor)
		for _, has in pairs(lettered) do
			if has == false then
				Reletter()
				break
			end
		end
	end
	return true
end

-- For /pug status: which font the frames are lettered in. Where that is not plainly the one
-- asked for, what is known follows in brackets: how many texts carry the addon's font out of
-- how many lettered, whether the game knows the file, and what it answered when it refused.
function Style.FontStatus()
	local wanted = Style.FONTS[ns.db.font]
	if not wanted or wanted == GAME then
		return L["the game's own"]
	elseif OTHER_SCRIPT[GetLocale()] then
		return L["the game's own, for this language's script"]
	end
	local with, all = 0, 0
	for _, has in pairs(lettered) do
		all = all + 1
		if has then
			with = with + 1
		end
	end
	if all > 0 and with == all then
		return L["the addon's own"]
	end
	local known = Known(wanted)
	local facts = { ("%d/%d"):format(with, all), "IsKnownFile: " .. (known == nil and "?" or tostring(known)) }
	if raised[wanted] then
		facts[#facts + 1] = "SetFont: error"
	elseif with < all or refusedAt then
		facts[#facts + 1] = "SetFont: " .. tostring(refusal)
	end
	local state
	if with > 0 then
		state = L["the addon's own, but not on every text"]
	elseif all == 0 and known ~= false and not raised[wanted] and not refusedAt then
		-- Nothing has been lettered yet (the frames are waiting for a fight to end), and nothing
		-- speaks against it: the game has not been asked, or said yes when it last was.
		state = L["the addon's own"]
	else
		state = L["the game's own: the game has not taken the addon's font file. If the addon was installed or updated while the game was running, close the game completely and start it again"]
	end
	return ("%s (%s)"):format(state, table.concat(facts, "; "))
end

-- Reads the look out of the settings. Frames pick it up on their next Frame.Layout, which
-- whoever calls this sees to (ns.Refresh, the login code): the count of lettered texts starts
-- over here.
function Style.Apply()
	local db = ns.db
	Style.theme = Style.THEMES[db.theme] or Style.THEMES.slate
	Style.texture = Style.TEXTURES[db.texture] or Style.TEXTURES.smooth
	Style.fontSize = db.fontSize
	Style.fontFlags = db.outline and "OUTLINE" or ""
	Style.shadows = db.shadows

	local wanted = Style.FONTS[db.font] or GAME
	own = nil
	if wanted ~= GAME and not OTHER_SCRIPT[GetLocale()] and not raised[wanted] and Known(wanted) ~= false then
		own = wanted
	end
	wipe(lettered)
end

-- Sets a font string to the font in use at the base size plus `delta`. `outlined` gives it an
-- outline whatever the setting says (small figures on a picture, which need one to be read).
function Style.SetFont(text, delta, outlined)
	local flags = outlined and "OUTLINE" or Style.fontFlags
	local size = math.max(6, Style.fontSize + (delta or 0))
	text:SetFont(GAME, size, flags)
	lettered[text] = nil
	if own then
		lettered[text] = LayOwn(text, size, flags)
	end
	if flags == "" then
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
