-- Runs in the simulator after login, just before the screenshot is taken (tools/sim/run.sh).
-- Gives the frames something to show: a hostile elite target, a cast, a hurt party.
-- The simulator ships no Blizzard art and none of the game's fonts, so spell icons and raid
-- marks come out as blank squares and the lettering is not the game's; the frames, bars and
-- marks are ours.
local ns = FreeUnitFrames

-- The simulator answers "is the pet visible" with yes although there is no pet, which leaves an
-- empty pet frame in the picture. In the game the frame is only up while a pet is.
ns.db.units.pet.enabled = false
ns.Refresh()

A_Admin.SetTarget("Hogger", 11, 1, true)
A_Admin.SetTargetType("elite", "Humanoid", 2)
A_Admin.SetTargetHealth(640, 1000)
A_Admin.SetTargetPower(35, 100, 1)
A_Admin.SetPlayerHealth(3550, 5000)
A_Admin.SetPartyMemberHealth(2, 35, 100)
A_Admin.SetPartyMemberHealth(3, 80, 100)
A_Admin.KillPartyMember(4)
A_Admin.SetCasting(635, "Holy Light", "Interface\\Icons\\Spell_Holy_HolyBolt", 2.5)
A_Admin.FireEvent("UNIT_SPELLCAST_START", "player")
ns.Frame.RefreshAll()
