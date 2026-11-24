local ADDON, ns = ...

-- The player's totems: four small icons under the plate, each with the sweep of its time left.
-- A right click on one sends that totem away and the mouse over one says what it is, as on the
-- game's own totem frame (which is part of the game's player frame, and gone with it).
--
-- A slot is two things, one over the other. What is seen (icon, rim, sweep) is an ordinary
-- frame, drawn and redrawn in a fight like everything else on the plate. What is clicked is one
-- of the game's secure buttons, with nothing drawn on it: only such a button may send a totem
-- away, and in a fight addon code may change nothing about one. Keeping the two apart also
-- keeps the sweep off the secure button, where the game refuses to have it set during a fight.
local Frame, Style, Sealed = ns.Frame, ns.Style, ns.Sealed

local Totems = { name = "Totems" }

Totems.worldEvents = { "PLAYER_TOTEM_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

local SLOTS = 4
local SIZE = 22
local GAP = 3
local LOOK_AGAIN = 0.5 -- seconds between looks at the slots while a fight is on

function Totems.Wanted(cfg, kind)
	return cfg.totems and kind == "player" and Sealed.PlayerClassFile() == "SHAMAN" or false
end

local function OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetTotem(self.slot)
end

local function OnLeave()
	GameTooltip:Hide()
end

-- In a fight the game does not say when a totem's time is up in a way this addon may read, and
-- does not always announce it either: the slots are simply looked at again twice a second, and
-- each is drawn or not by the time it has left (Sealed.TotemToButton).
local function OnUpdate(self, elapsed)
	self.since = self.since + elapsed
	if self.since >= LOOK_AGAIN then
		self.since = 0
		if InCombatLockdown() then
			ns.Try(Totems.Update, self.frame)
		end
	end
end

-- Only possible out of combat, like everything else that makes or places a secure button.
function Totems.Create(frame)
	local holder = CreateFrame("Frame", nil, frame.body)
	holder.frame = frame
	holder.since = 0
	holder:SetScript("OnUpdate", OnUpdate)
	-- The secure buttons hang on the unit button itself and are placed against it: whatever a
	-- secure button sits on or is pinned to can itself not be shown, hidden or moved in a fight,
	-- and the plate should stay free of that.
	local clickHolder = CreateFrame("Frame", nil, frame)
	clickHolder:SetAllPoints(frame)
	clickHolder:SetFrameLevel(frame.body:GetFrameLevel() + 10)

	local buttons, clicks = {}, {}
	for slot = 1, SLOTS do
		local button = CreateFrame("Frame", nil, holder)
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetAllPoints(button)
		button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trims the icon's own border
		button.edge = Frame.MakeEdge(button, "OVERLAY")
		button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
		button.cooldown:SetAllPoints(button)
		button.cooldown:SetReverse(true)
		button.cooldown:SetDrawEdge(false)
		button:SetAlpha(0)
		buttons[slot] = button

		-- The game's "destroytotem" action sends the totem in a slot away, in a fight too.
		local click = CreateFrame("Button", nil, clickHolder, "SecureActionButtonTemplate")
		click.slot = slot
		click:SetAttribute("*type2", "destroytotem")
		click:SetAttribute("totem-slot", slot)
		-- The game acts on the press or on the release of a click, as its "cast on key down"
		-- setting says, and passes over the other. A button that only took one of the two would
		-- do nothing for half the players, so it takes both.
		click:RegisterForClicks("RightButtonDown", "RightButtonUp")
		click:HookScript("OnEnter", OnEnter)
		click:HookScript("OnLeave", OnLeave)
		-- After the scripts: giving a frame a script for the mouse switches its mouse on.
		click:EnableMouse(false)
		click.mouseOn = false
		clicks[slot] = click
	end
	frame.totems = { holder = holder, clickHolder = clickHolder, buttons = buttons, clicks = clicks }
end

function Totems.Layout(frame, cfg, on)
	local totems = frame.totems
	totems.holder:SetShown(on)
	totems.clickHolder:SetShown(on)
	if not on then
		return
	end
	local offset = Frame.TakeBelow(frame, SIZE)
	totems.holder:ClearAllPoints()
	totems.holder:SetPoint("TOPLEFT", frame.body, "BOTTOMLEFT", 0, -offset)
	totems.holder:SetSize(SLOTS * (SIZE + GAP) - GAP, SIZE)
	for slot, button in ipairs(totems.buttons) do
		local along = (slot - 1) * (SIZE + GAP)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", totems.holder, "TOPLEFT", along, 0)
		button:SetSize(SIZE, SIZE)
		Frame.LayoutEdge(button.edge, button, frame.pixel, Style.theme.edge)
		local click = totems.clicks[slot]
		click:ClearAllPoints()
		click:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", along, -offset)
		click:SetSize(SIZE, SIZE)
	end
end

-- Whether a slot takes the mouse. An empty slot does not, or it would be an unseen square under
-- the plate that swallows clicks meant for the world. Being secure, the buttons can only be
-- changed out of combat.
local function Mouse(click, on)
	if click.mouseOn ~= on and not InCombatLockdown() then
		click:EnableMouse(on)
		click.mouseOn = on
	end
end

function Totems.Update(frame, _, event)
	local totems = frame.totems
	for slot, button in ipairs(totems.buttons) do
		local standing = Sealed.TotemToButton(button, slot)
		if event == "PLAYER_REGEN_DISABLED" then
			-- A fight is starting. Until it ends the game says nothing readable about the slots
			-- and lets no button be changed, so all four take the mouse now: a totem set down in
			-- the fight can then be sent away with a right click. (The game announces a fight a
			-- moment before it locks the frames. Were it ever the other way round, the slots
			-- would simply stay as they were: Mouse() changes nothing once frames are locked.)
			Mouse(totems.clicks[slot], true)
		elseif standing ~= nil then
			Mouse(totems.clicks[slot], standing)
		end
	end
end

Frame.Register(Totems)
