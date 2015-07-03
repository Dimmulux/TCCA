local groupChangeFrame = CreateFrame("Frame", "groupChangeFrame")
groupChangeFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
groupChangeFrame:RegisterEvent("PLAYER_LOGIN")
groupChangeFrame:SetScript("OnEvent", TCCA.rosterUpdate)

local function slashHelp()
    print("Not yet implemented.")
end
   
local function slashCommandHandler(command)
    local lookup = {
        showtarget = TCCA.createIfNeededAndShowAssignedFrame,
        hidetarget = TCCA.hideAssignedFrame,
        setlocaltarget = TCCA.setLocalTarget,
        l = TCCA.setLocalTarget,
        printtarget = TCCA.printTarget,
        help = slashHelp,
        assigntarget =  TCCA.assignKillTarget,
        k = TCCA.assignKillTarget,
        announceinchat = TCCA.changeAnnounceInChat,
        host = TCCA.hostSlash,
        request = TCCA.requestInfo,
        assigners = TCCA.setAssigners,
        d = TCCA.assignDelayedSwitch
    }
    key, args = strlower(command):match("(%S+)%s?(.*)")
    local f = lookup[key]
    if f then
        local t = {}
        for elem in args:gmatch("(%S+)%s?") do
            table.insert(t, args)
        end
        f(unpack(t))
    else
        print("TCCA: Command '" .. command .. "' not recognised. Showing a listing of TCCA commands.")
        slashHelp()
    end
end

SLASH_TCCA_OPTIONS1 = "/TCCA"
SlashCmdList["TCCA_OPTIONS"] = slashCommandHandler

-- To get mem usage: UpdateAddOnMemoryUsage() print(GetAddOnMemoryUsage("TCCA"))
-- conversion between raid and party does indeed fire GROUP_ROSTER_UPDATE

-- Code
-- TODO switch away from DBM timers - they do not have ms precision
-- TODO fix line 50 comms error
-- TODO consider whether GetHomePartyInfo is useful
-- TODO add commands to list those in and not in party


-- Lookup / ASK

-- TODO find how to dereference frame
-- TODO find why setting bindings does not work.
-- TODO find how to send Addon whisper message to a unit that is from a different unconnected realm that is in the raid/party
-- TODO find how to integrate with battleground targets to mark skulls on players in the BGT frame
-- TODO is there a difference between (".*%-.*") and (".*-.*")? As I understand it, the '-' symbol should need to be escaped by the '%' symbol, but the escape seems to be unnecessary - each seems to match the same set of strings.
-- TODO find world time to millisecond precision. Do I need to poll GetRealmTime?
-- TODO find why TRUE and FALSE are used in l2target, rather than true and false. Surely both are equivalent to nil?
-- TODO find whether it is possible to detect whether a character is on a connected realm
-- TODO find how to get the name of the raid members that are not in the instance group
-- TODO find how to check whether a unit is using direct damage abilities at a unit other than the target.