-- Used for determining what chat type to use.
-- SendAddonMessage(..., "RAID") does NOT default to "PARTY" when in arena
local groupType = nil
local heartbeatTicker = nil
local requestCounter = 0
local lastResponse = {}

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

--heartbeats are required to detect the case where a group member disables this addon while reloadingUI
--and also to find raid members not present in the instance group
--and also to treat a player with several seconds latency as effectively useless for CCs)
local function updateAndSendHeartbeat()
	if not IsInGroup(LE_PARTY_CATEGORY_HOME) or TCCA.host ~= TCCA.playerName then
		heartbeatTicker:Cancel()
	else
		TCCA.groupMembersWithTCCA = lastResponse
		-- inefficient concatenation
		local groupMembersWithTCCAList = ""
		for character in pairs(TCCA.groupMembersWithTCCA) do
			groupMembersWithTCCAList = groupMembersWithTCCAList .. TCCA.convertToFullName(character) .. " "
		end
		SendAddonMessage("TCCA", "groupMembersWithTCCA:" .. groupMembersWithTCCAList, groupType)
		lastResponse = {}
		lastResponse[TCCA.playerName] = true
		requestCounter = requestCounter + 1
		SendAddonMessage("TCCA", "heartbeat:" .. requestCounter, groupType)
	end
end

local function receiveGroupMembersWithTCCA(lsender, ...)
	local groupMembersWithTCCA = {}
	for _, name in ipairs({...}) do
		print("reached " .. name)
		groupMembersWithTCCA[TCCA.convertToLocalName(name)] = true
	end
	TCCA.groupMembersWithTCCA = groupMembersWithTCCA
end

local function receiveHeartbeat(lsender, messageCounter)
	if lsender == TCCA.host then
		SendAddonMessage("TCCA", "acknowledge:" .. messageCounter, groupType)
	end
end

local function receiveAcknowledgement(lsender, messageCounter)
	if tonumber(messageCounter) == requestCounter then
		lastResponse[TCCA.convertToLocalName(lsender)] = true
	end
end

local function startHosting()
	if not heartbeatTicker or heartbeatTicker._cancelled then
		heartbeatTicker = C_Timer.NewTicker(5, updateAndSendHeartbeat)
	end
end

function TCCA.requestInfo()
    if IsInGroup(LE_PARTY_CATEGORY_HOME) then
        SendAddonMessage("TCCA", "requesting", groupType)
    end
end

function TCCA:rosterUpdate(event)
    if TCCAUserConfig.debug then 
        print("rosterUpdated")
    end
	local groupMembers = {}
	groupMembers[TCCA.playerName] = true
    if not IsInGroup(LE_PARTY_CATEGORY_HOME) then
        TCCA.assigners = {}
        TCCA.assigners[TCCA.playerName] = true
        TCCA.host = nil
		TCCA.groupLeader = nil
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
				groupMembers[unitName] = true
				if UnitIsGroupLeader(unit, LE_PARTY_CATEGORY_HOME) then
					groupLeader = unitName
				end
			end
        else
			groupType = "PARTY"
            for _, unitName in ipairs(GetHomePartyInfo()) do
				if not unitName or unitName == "Unknown" then
					break
				end
				groupMembers[unitName] = true
				if UnitIsGroupLeader(unitName, LE_PARTY_CATEGORY_HOME) then
					groupLeader = unitName
				end
			end
        end
		TCCA.groupLeader = groupLeader
		--TODO what if host is now in instance group but not home group?
		local isHostStillInGroup = TCCA.host and (TCCA.playerName==TCCA.host or UnitInParty(TCCA.host) or UnitInRaid(TCCA.Host))
        if TCCA.host == TCCA.playerName then
			startHosting()
		end
		if groupLeader and not isHostStillInGroup then
            TCCA.host = groupLeader
			wipe(TCCA.assigners)
            TCCA.assigners[TCCA.host] = true
			--TODO maybe make this request only host instead
			TCCA.requestInfo()
        end
	TCCA.groupMembers = groupMembers
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
    elseif UnitInRaid(newHost) or UnitInGroup(newHost) then
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
		if host == TCCA.playerName then
			startHosting()
		end
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

local function receiveKillTargetAssignment(lSender, timeToSwitch, timeDelay, ...)
    --Written this way to deal with NPCs that may have spaces in their names
	local newTarget = ""
	for _, nameSegment in ipairs{...} do
        newTarget = newTarget .. " " .. nameSegment
    end
	if newTarget == "!unset" then
		newTarget = nil
	else
		newTarget = TCCA.convertToLocalName(newTarget:sub(2))
	end
    if not TCCA.assigners[lSender] then
        print(lSender .. " attempted to send you a kill target without the permission to do so.")
    elseif newTarget ~= TCCA.assignedKillTarget then
        if TCCA.timer then
            TCCA.timer:Cancel()
            TCCA.timer = nil
        end
		if tonumber(timeToSwitch) then
			timeDelay = timeToSwitch - (TCCA.timeStamp + GetTime())
		else
			timeDelay = tonumber(timeDelay)
		end
        if not timeDelay or timeDelay == 0 then
            TCCA.targetChanged(newTarget)
        else
			if TCCAUserConfig.targetAssistance.countdownTimer and DBM then
                if TCCA.delaySwitchTimerText then
					DBM.Bars:CancelBar(TCCA.delaySwitchTimerText)
				end
				local barText =  "Switch to " .. newTarget
				TCCA.delaySwitchTimerText = barText
				DBM.Bars:CreateBar(timeDelay, barText, "Interface\\Icons\\Spell_Holy_BorrowedTime")
			end
			if TCCAUserConfig.targetAssistance.chatText then
				print("Kill target changing to " .. newTarget .. " in " .. timeDelay .. " seconds.")
			end
            local function f()
                TCCA.targetChanged(newTarget)
            end
            TCCA.timer = C_Timer.NewTimer(timeDelay, f)
        end
    end
end

function TCCA.unsetKillTarget()
	if not TCCA.assigners[TCCA.playerName] then
        print("You do not have permission to unset the kill target for your group.")
    else
		receiveKillTargetAssignment(TCCA.playerName, "unused",  0, "!unset")
		SendAddonMessage("TCCA", "killTarget:unused 0 !unset", groupType)
	end
end

function TCCA.assignDelayedSwitch(timeDelay, newKillTarget)
     if not TCCA.assigners[TCCA.playerName] then
        print("You do not have permission to assign a kill target for your group.")
    else
        if not newKillTarget or newKillTarget == "" then
            newKillTarget = GetUnitName("target", true)
			if not newKillTarget then
				return
			end
        end
         --TODO find a way of excluding friendly NPCs and cross realm players outside group as well
        if UnitIsFriend("Player", newKillTarget) and not TCCAUserConfig.allowFriendlyKillTargets then
            print (newKillTarget .. " is friendly.")
        else
            timeDelay = tonumber(timeDelay)
            if not timeDelay then
                if TCCA.debug then
					print("No time delay given. Using default value instead.")
				end
                timeDelay = TCCAUserConfig.defaultSwitchDelay
            end
            
            local assignedKillTargetFullName = TCCA.convertToFullName(newKillTarget)
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
			if timeDelay ~= 0 and TCCA.timestampOffset then
				timeToSwitch = GetTime() + TCCA.timestampOffset + timeDelay
			else
				timeToSwitch = "unused"
			end
			SendAddonMessage("TCCA", "killTarget:" .. timeToSwitch .. " " .. timeDelay .. " " .. assignedKillTargetFullName, groupType)
			receiveKillTargetAssignment(TCCA.playerName, "unused", timeDelay, newKillTarget)
        end
    end
end

function TCCA.assignKillTarget(newKillTarget)
    TCCA.assignDelayedSwitch(0, newKillTarget) 
end   

local function reportPersonalStats(lSender)
	if TCCA.host ~= TCCA.playerName 
	 and not UnitIsGroupLeader(lSender, LE_PARTY_CATEGORY_HOME) 
	 and not UnitIsGroupAssistant(lSender, LE_PARTY_CATEGORY_HOME) then
		print("TCCA: " .. lSender .. " asked you to report your stats without the permission to do so.")
	else
		local c = TCCA.attacksOnCorrectTargetBy[TCCA.playerName] or 0
		local w = TCCA.attacksOnWrongTargetBy[TCCA.playerName] or 0
		if c + w == 0 then
			SendChatMessage("I have not attacked anything while a kill target was assigned and in range.", groupType)
		else
			SendChatMessage("I have " .. c .. " attacks on the correct target and " .. w 
			 .. " attacks on the wrong target so their proportion of attacks on the correct target is " .. c/( c + w) .. " .", groupType)
		end
	end
end

function TCCA.report(dataSource, toSelf)
	if not IsInGroup(LE_PARTY_CATEGORY_HOME) then
		print "You are not in a group."
		return
	end
	
	if dataSource ~= "local" then
		if TCCA.host ~= TCCA.playerName 
		 and not UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME) 
		 and not UnitIsGroupAssistant("player", LE_PARTY_CATEGORY_HOME) then
			if dataSource == "global" then
				print "Cannot use global source if you are not the host, group leader or raid assistant."
			end
			dataSource = "local"
		elseif toSelf then
			if dataSource == "global" then
				print "Cannot use global source if you are printing to self."
			end
			dataSource = "local"
		else
			dataSource = "global"
		end
	end
	if dataSource == "global" then
		SendChatMessage("TCCA: reporting global stats", groupType)
		SendAddonMessage("TCCA", "reportPersonalStats", groupType)
		reportPersonalStats()
	else
		--Essentially, insertion sort.
		local orderedByProportionOfCorrectAttacks = {} 
		local indexAndProportion = {}
		local cT = TCCA.attacksOnCorrectTargetBy
		local wT = TCCA.attacksOnWrongTargetBy
		for character in pairs(TCCA.groupMembers) do
			local c = cT[character] or 0
			local w = wT[character] or 0
			local proportion
			local m
			if c + w == 0 then
				proportion = 0
				m = character .. " has not attacked anything while a kill target was assigned and in range."
			else
				proportion = c / (c + w)
				m = character .. " has " .. c .. " attacks on the correct target and " .. w 
				 .. " attacks on the wrong target so my proportion of attacks on the correct target is " .. proportion .. " ."
			end
			local indexToInsert = 1
			for index, entryProportion in ipairs(indexAndProportion) do
				if proportion > entryProportion then
					indexToInsert = index
					break
				end
			end
			table.insert(orderedByProportionOfCorrectAttacks, indexToInsert, m)
			table.insert(indexAndProportion, indexToInsert, proportion)
		end
		SendChatMessage("TCCA: reporting local stats", groupType)
		for _, m in ipairs(orderedByProportionOfCorrectAttacks) do
			if toSelf then
				print(m)
			else
				SendChatMessage(m, groupType)
			end
		end
	end
end

--leave at bottom of file

local commands = {
    killTarget = receiveKillTargetAssignment,
    requesting = TCCA.broadcastInfo,
    host = receiveHost,
    assigners = receiveAssigners,
	heartbeat = receiveHeartbeat,
	acknowledge = receiveAcknowledgement,
	groupMembersWithTCCA = receiveGroupMembersWithTCCA,
	reportPersonalStats = reportPersonalStats,
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