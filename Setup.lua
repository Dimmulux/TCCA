local versionMajor = 0
local versionMinor = 1

BINDING_HEADER_TCCA = "Target and Crowd Control Assistant"
BINDING_NAME_ASSIGN_LOCAL_TARGET = "Assign a local kill target"
TCCA = {
    playerName = GetUnitName("Player"),
    homeRealm = string.gsub(GetRealmName(), "%s+", ""),
    assigners = {},
	connectedRealms = {},
	switchedAwayFromTime = {},
	groupMembers = {},
	groupMembersWithTCCA = {},
	attacksOnCorrectTargetBy = {},
	attacksOnWrongTargetBy = {},
}
TCCA.assigners[TCCA.playerName] = true
TCCA.groupMembersWithTCCA[TCCA.playerName] = true
local function setup()
	TCCA.rangeChecker = LibStub("LibRangeCheck-2.0")
    if not TCCAUserConfig or not TCCAUserConfig.versionMajor or not TCCAUserConfig.versionMinor 
	 or TCCAUserConfig.versionMajor < versionMajor
	 or (TCCAUserConfig.versionMajor == versionMajor and TCCAUserConfig.versionMinor < versionMinor) then
        if not TCCAUserConfig then
			print "No config found. Using default config instead."
		else 
			print "Config rewritten due to being out of date."
		end
        TCCAUserConfig = {
			versionMajor = versionMajor,
			versionMinor = versionMinor,
            announceInChat = nil, --can be "RAID", "PARTY", "INSTANCE_CHAT", "BATTLEGROUND" or nil
            defaultSwitchDelay = 5,
            debug = false,
			allowFriendlyKillTargets = false,
        }
	end
    if not TCCAUserConfig.targetAssistance then 
         TCCAUserConfig.targetAssistance = {
            chatText = true,
            frameText = true,
            wrongTargetSound = true,
			wrongTargetSoundEffect = "Sound\\Creature\\Loathstare\\Loa_Naxx_Aggro02.ogg",
			switchSecondsGrace = 0.3,
            marker = true,
            markerSize = 80,
            assignedSwitchSound = true,
			assignedSwitchSoundEffect = "Sound\\Doodad\\BellTollNightElf.ogg",
            countdownTimer = true,
            markInBGT = true,
        }
    end
    if not TCCAUserConfig.assignedKillTargetFrame then
        TCCAUserConfig.assignedKillTargetFrame = {
            locked = false,
            point = "CENTER",
            x = 0,
            y = 0
        }
    end
    if TCCAUserConfig.targetAssistance.marker then
        TCCA.setupTargetMarker()
    end
    if TCCAUserConfig.targetAssistance.frameText then
        TCCA.createIfNeededAndShowAssignedFrame()
    end
	for _, realm in ipairs(GetAutoCompleteRealms()) do
		TCCA.connectedRealms[realm] = true
	end
    RegisterAddonMessagePrefix("TCCA")
    local TCCAmessageReadFrame = CreateFrame("Frame")
    TCCAmessageReadFrame:RegisterEvent("CHAT_MSG_ADDON")
    TCCAmessageReadFrame:SetScript("OnEvent", TCCA.messageReader)
	local function combatLogHandler(self, event, timestamp, ...)
		-- This is our calculated offset from the system time
		local offset = timestamp - GetTime();
		-- If we haven't stored an offset before or we have a lower offset due to variance in latency, update it
		if not TCCA.timestampOffset or offset < TCCA.timestampOffset then
			TCCA.timestampOffset = offset;
		end
		TCCA.latestTimestamp = timestamp
		TCCA.attackStatisticsUpdate(timestamp, ...) --client
		if TCCAUserConfig.targetAssistance.wrongTargetSound then
			TCCA.wrongTargetSound(timestamp, ...) --client
		end
		if TCCA.playerName == TCCA.host then
			TCCA.informNewCombatLogEvent(timestamp, ...) --host
		end
	end
	local TCCAcombatLogEventFrame = CreateFrame("Frame")
	TCCAcombatLogEventFrame:SetScript("OnEvent", combatLogHandler)
	TCCAcombatLogEventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	
	local groupChangeFrame = CreateFrame("Frame", "groupChangeFrame")
	groupChangeFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	groupChangeFrame:RegisterEvent("PLAYER_LOGIN")
	groupChangeFrame:SetScript("OnEvent", TCCA.rosterUpdate)

	-- Leave at bottom
	
	local function slashHelp()
		print("Not yet implemented.")
	end
	
	do
		local lookup = {
			showtarget = TCCA.createIfNeededAndShowAssignedFrame,
			hidetarget = TCCA.hideAssignedFrame,
			setlocaltarget = TCCA.setLocalTarget,
			l = TCCA.setLocalTarget,
			printtarget = TCCA.printTarget,
			help = slashHelp,
			assignkilltarget =  TCCA.assignKillTarget,
			k = TCCA.assignKillTarget,
			announceinchat = TCCA.changeAnnounceInChat,
			host = TCCA.hostSlash,
			request = TCCA.requestInfo,
			assigners = TCCA.setAssigners,
			d = TCCA.assignDelayedSwitch,
			withtcca = TCCA.printGroupMembersWithTCCA,
			withouttcca = TCCA.printGroupMembersWithoutTCCA,
			unsetkilltarget = TCCA.unsetKillTarget,
			u = TCCA.unsetKillTarget,
			unsetlocalkilltarget =  TCCA.targetChanged,
			ul = TCCA.targetChanged,
			report = TCCA.report,
		}
		local function slashCommandHandler(command)
			key, args = strlower(command):match("(%S+)%s?(.*)")
			local f = lookup[key]
			if f then
				local t = {}
				for elem in args:gmatch("(%S+)%s?") do
					table.insert(t, args)
				end
				f(unpack(t))
			else
				print("TCCA: Command '" .. strlower(command) .. "' not recognised. Showing a listing of TCCA commands.")
				slashHelp()
			end
		end
		SLASH_TCCA_OPTIONS1 = "/TCCA"
		SlashCmdList["TCCA_OPTIONS"] = slashCommandHandler
	end
	-- Do not add below this
end

local setupFrame = CreateFrame("Frame", "setupFrame")
setupFrame:RegisterEvent("PLAYER_LOGIN")
setupFrame:SetScript("OnEvent", setup)


-- To get mem usage: UpdateAddOnMemoryUsage() print(GetAddOnMemoryUsage("TCCA"))
-- conversion between raid and party does indeed fire GROUP_ROSTER_UPDATE
-- It is not possible to send Addon whisper message to a unit that is from a different unconnected realm even if they are in the raid/party.

-- ** Code:
-- TODO fix problem with insertion sort on proportion of attacks to use correct order.
-- ##

-- ** To test:
-- timing system
-- reporting system, thoroughly

-- ##

-- ** Lookup / ASK general
-- TODO find how to avoid rewriting the saved variables table after each update.
-- TODO find how to check whether a unit exists (UnitExists returns false if NPC not interacted with) how about unitGUID (in same way as [exists] conditional in macros)
-- TODO find how to check whether a unit is in the home group (not UnitInRaid because UnitInRaid refers to instance over home raid)
-- TODO find how to get a list of the members of the home raid
-- TODO find how to get NamePlate by name when name has special characters
-- TODO find way of range checking by unit name (if at all possible)
-- ##



-- specific

-- WAIT find how to integrate with battleground targets to mark skulls on players in the BGT frame