-- Used for determining what chat type to use.
-- SendAddonMessage(..., "RAID") does NOT default to "PARTY" when in arena
local groupType = nil

-- Transform for sending
function TCCA.convertToFullName(unitName) 
    local fullName 
    if not UnitIsPlayer(unitName) or unitName:find(".*%-.*") then
        fullName = unitName
    else
        fullName = unitName .. "-" .. TCCA.homeRealm
    end
    return fullName
end

-- Transform for receiving
function TCCA.convertToLocalName(fullName) 
    local unitName, realmName = fullName:match("([^-]*)%-?(.*)")
    if not UnitIsPlayer(unitName) or not realmName or realmName ~= TCCA.homeRealm then
         unitName = fullName
    end
    return unitName
end

-- Ensures that the first letter of character name and, if present, character realm are converted to upper case
local function convertToUpperAsAppropriate(name) 
    return string.gsub("-"..name,"%-%l", string.upper):sub(2)
end

function TCCA:rosterUpdate(event)
    if TCCAUserConfig.debug then 
        print("rosterUpdated")
    end
    if not IsInGroup(LE_PARTY_CATEGORY_HOME) then
        wipe(TCCA.assigners)
        TCCA.assigners[TCCA.playerName] = true
        TCCA.host = nil
		groupType = nil
    else
		local amGroupLeader = UnitIsGroupLeader("Player", LE_PARTY_CATEGORY_HOME)
        local groupLeader
        if amGroupLeader then 
            groupLeader = TCCA.playerName
        end
		-- If unit is raid, potential problems because we get information about instance raid rather than home raid.
        if IsInRaid(LE_PARTY_CATEGORY_HOME) then
			groupType = "RAID"
			for i = 1, math.max(GetNumGroupMembers(LE_PARTY_CATEGORY_HOME), GetNumGroupMembers(LE_PARTY_CATEGORY_INSTANCE)) do
				local unit = "raid"..i
				local unitName = GetUnitName(unit, true)
				if not unitName or unitName == "Unknown" then
					break
				end
				if UnitIsGroupLeader(unit, LE_PARTY_CATEGORY_HOME) then
					groupLeader = unitName
				end
			end
        else
			groupType = "PARTY"
            for _, unitName in ipairs(GetHomePartyInfo) do
				if not unitName or unitName == "Unknown" then
					break
				end
				if UnitIsGroupLeader(unitName, LE_PARTY_CATEGORY_HOME) then
					groupLeader = unitName
				end
			end
        end
        local isHostStillInGroup = TCCA.host and (TCCA.playerName==TCCA.host or UnitInParty(TCCA.host) or UnitInRaid(TCCA.Host))
        if groupLeader and not isHostStillInGroup then
            TCCA.host = groupLeader
            wipe(TCCA.assigners)
            TCCA.assigners[TCCA.host] = true
        end
    end
end

function TCCA.changeAnnounceInChat(channel)
    local channels = {
        raid = "RAID", 
        party = "PARTY", 
        instance = "INSTANCE_CHAT", 
        battleground = "BATTLEGROUND",
    }
    TCCAUserConfig.announceInChat = channels[channel]
    if TCCAUserConfig.announceInChat then
        print("Announcing new target calls in " .. TCCAUserConfig.announceInChat .. ".")
    else
        print("Not announcing new target calls in chat. They will still be given to other group members with the addon.")
    end
end

do 
    function TCCA:groupJoined(event)
        if IsInGroup(LE_PARTY_CATEGORY_HOME) and not UnitIsGroupLeader("Player", LE_PARTY_CATEGORY_HOME) then
            wipe(TCCA.assigners)
            TCCA.host = nil
            TCCA.requestInfo()
        end
    end

    local groupJoinedFrame = CreateFrame("Frame")
    groupJoinedFrame:RegisterEvent("GROUP_JOINED")
    groupJoinedFrame:SetScript("OnEvent", TCCA.groupJoined)
end

function TCCA.hostSlash(newHost)
    local host = TCCA.host or "no-one"
    if not newHost or newHost == "" then
        print("The current host is: " .. host .. ".")
    elseif host ~= TCCA.playerName 
     and not UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME) 
     and not UnitIsGroupAssistant("player", LE_PARTY_CATEGORY_HOME) then
        print("You must be a group leader, raid assistant or the current host to change the host. The current host is: " .. host .. ".")
    elseif UnitIsPlayer(newHost) and UnitClass(newHost) then --using unitClass to check whether unit is in group
        local newHostCap = convertToUpperAsAppropriate(newHost)
        print("Changing host from " .. host .. " to " .. newHostCap .. ".")
        TCCA.host = newHostCap
        SendAddonMessage("TCCA", "host:" .. TCCA.convertToFullName(newHostCap), groupType)
    else
        print("There is no group member by the name of " .. convertToUpperAsAppropriate(newHost) .. ". The current host is: " .. host .. ".")
    end
end

local function receiveHost(lSender, newHost)
    if newHost == TCCA.host then
        --common case, do nothing
    elseif UnitIsGroupLeader(lSender, LE_PARTY_CATEGORY_HOME) or UnitIsGroupAssistant(lSender, LE_PARTY_CATEGORY_HOME) or host==lSender then
        TCCA.host = TCCA.convertToLocalName(newHost)
        print(TCCA.host .. " is now the host.")
    else
        print(lSender .. " attempted to change host without the permission to do so.")
    end
end

local function printAssigners()
    local currentAssignersList = ""
    for assigner in pairs(TCCA.assigners) do
        currentAssignersList = currentAssignersList .. assigner
    end
    print("The current kill target assigners are: " .. currentAssignersList .. ".")
end

local function receiveAssigners(lSender, ...)
    if UnitIsGroupLeader(lSender, LE_PARTY_CATEGORY_HOME) or UnitIsGroupAssistant(lSender, LE_PARTY_CATEGORY_HOME) or TCCA.host==lSender then
        wipe(TCCA.assigners)
        for _, assigner in ipairs{...} do
            TCCA.assigners[TCCA.convertToLocalName(assigner)] = true
        end
        printAssigners()
    else
        print(lSender .. " attempted to change assigners without the permission to do so.")
    end
end

function TCCA.broadcastInfo()
    --TODO should also provide target info
    if UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME) then
        SendAddonMessage("TCCA", "host:" .. TCCA.convertToFullName(TCCA.host), groupType)
        local assignersList = ""
        --potentially inefficient concatenation if there are many assigners, but unlikely to be a problem
        for assigner in pairs(TCCA.assigners) do
            assignersList = assignersList .. TCCA.convertToFullName(assigner) .. " "
        end
        SendAddonMessage("TCCA", "assigners:" .. assignersList, groupType)
    end
end

function TCCA.requestInfo()
    if IsInGroup(LE_PARTY_CATEGORY_HOME) then
        SendAddonMessage("TCCA", "requesting", groupType)
    end
end

function TCCA.setAssigners(newAssigners)
    --TODO deal with case where first name of someone on other server is given
    local assigners = TCCA.assigners
    if not newAssigners or newAssigners == "" then
       printAssigners()
    elseif TCCA.host ~= TCCA.playerName 
     and not UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME) 
     and not UnitIsGroupAssistant("player", LE_PARTY_CATEGORY_HOME) then
        print("You must be a group leader, raid assistant or the current host to change the assigners.")
        printAssigners()
    else 
        local assignersList = ""
        for assigner in newAssigners:gmatch("(%S+)%s?") do
            if UnitIsPlayer(assigner) and UnitClass(assigner) then --using unitClass to check whether unit is in same group
                assignersList = assignersList .. convertToUpperAsAppropriate(TCCA.convertToFullName(assigner)) .. " "
            else
                 print("There is no group member by the name of " .. convertToUpperAsAppropriate(assigner) .. ".")
            end
        end
        receiveAssigners(assignersList, TCCA.playerName)
        SendAddonMessage("TCCA", "assigners:" .. assignersList, groupType)
    end
end

local function receivedKillTargetAssignment(lSender, timeDelay, ...)
    local newTarget = ""
    for _, nameSegment in ipairs{...} do
        newTarget = newTarget .. " " .. nameSegment
    end
    newTarget = TCCA.convertToLocalName(newTarget:sub(2))
    if not TCCA.assigners[lSender] then
        print(lSender .. " attempted to send you a kill target without the permission to do so.")
    elseif newTarget ~= TCCA.assignedKillTarget then
        if TCCA.timer then
            TCCA.timer:Cancel()
            TCCA.timer = nil
        end
        timeDelay = tonumber(timeDelay)
        if not timeDelay or timeDelay == 0 then
            TCCA.targetChanged(newTarget)
        else
            local function f()
                TCCA.targetChanged(newTarget)
            end
            TCCA.timer = C_Timer.NewTimer(timeDelay, f)
        end
    end
end

local function pushKillTargetToGroup(killTarget, timeDelay)
    local assignedKillTargetFullName = TCCA.convertToFullName(killTarget)
    local aIC = TCCAUserConfig.announceInChat
    if aIC and IsInGroup() then
		if (aIC == "INSTANCE_CHAT" and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) or 
         (aIC == "BATTLEGROUND" and UnitInBattleground("Player")) or 
         (aIC == "RAID" and IsInRaid(LE_PARTY_CATEGORY_HOME)) or
         (aIC == "PARTY" and IsInGroup(LE_PARTY_CATEGORY_HOME)) then
			if timeDelay == 0 then
				SendChatMessage("TCCA: Kill target is " .. assignedKillTargetFullName, aIC)
			else
				SendChatMessage("TCCA: Kill target switching to " .. assignedKillTargetFullName .. " in " .. timeDelay .. " seconds.", aIC)
			end
        end
    end
    SendAddonMessage("TCCA", "killTarget:" .. timeDelay .. " " .. assignedKillTargetFullName, groupType)
end

function TCCA.assignDelayedSwitch(timeDelay, newKillTarget)
    
    if not TCCA.assigners[TCCA.playerName] then
        print("You do not have permission to assign a kill target for your group.")
    else
        if not newKillTarget or newKillTarget == "" then
            newKillTarget = GetUnitName("target", true)
        end
         --TODO find a way of excluding friendly NPCs as well
        if UnitIsFriend("Player", newKillTarget) and not TCCAUserConfig.allowFriendlyKillTargets then
            print (newKillTarget .. " is friendly.")
        else
            timeDelay = tonumber(timeDelay)
            if not timeDelay then
                if TCCA.debug then
					print("No time delay given. Using a default value instead.")
				end
                timeDelay = 5
            end
            if TCCAUserConfig.targetAssistance.countdownTimer and timeDelay > 0 and DBM and DBT then
                SlashCmdList["DEADLYBOSSMODS"]("broadcast timer ".. math.floor(timeDelay + 0.5) .. " Switch to " .. newKillTarget)
            end
            receivedKillTargetAssignment(TCCA.playerName, timeDelay, GetUnitName(newKillTarget, true) or newKillTarget)
            pushKillTargetToGroup(GetUnitName(newKillTarget, true) or newKillTarget, timeDelay)
        end
    end
end

function TCCA.assignKillTarget(newKillTarget)
    if not newKillTarget or newKillTarget == "" then
        newKillTarget = GetUnitName("target", true)
    end
    TCCA.assignDelayedSwitch("0", newKillTarget) 
end   

--leave at bottom of file

local commands = {
    killTarget = receivedKillTargetAssignment,
    requesting = TCCA.broadcastInfo,
    host = receiveHost,
    assigners = receiveAssigners, 
}

function TCCA:messageReader(event, prefix, message, channel, sender)
    local lSender = TCCA.convertToLocalName(sender)
    if TCCAUserConfig.debug then
        print("received message '".. message .. "' from " .. lSender)
    end
    if prefix == "TCCA" and lSender ~= UnitName("Player") and 
        (channel == "RAID" or channel == "PARTY") then  -- to ensure that
        local command, args = message:match("([^:]+):?([^:]*)")
        local f = commands[command]
        if f then
            local t = {}
            for arg in args:gmatch("(%S+)%s?") do
                table.insert(t, arg)
            end
            f(lSender, unpack(t))
        else
            print("TCCA received an invalid command from " .. lSender .. ".")
        end
    end
end

-- do not add below this