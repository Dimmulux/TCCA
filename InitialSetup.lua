BINDING_HEADER_TCCA = "Target and Crowd Control Assistant"
BINDING_NAME_ASSIGN_TARGET = "Assign a kill target"
TCCA = {
    playerName = GetUnitName("Player"),
    homeRealm = GetRealmName(),
    assigners = {},
}
TCCA.assigners[TCCA.playerName] = true
local function setup()
    if not TCCAUserConfig then
        print "No config found. Using default config instead."
        TCCAUserConfig = {
            wrongTargetSoundEffect = "Sound\\Creature\\Loathstare\\Loa_Naxx_Aggro02.ogg",
            assignedSwitchSoundEffect = "Sound\\Doodad\\BellTollNightElf.ogg",
            announceInChat = nil, --can be "RAID", "PARTY", "INSTANCE_CHAT", "BATTLEGROUND" or nil
            delay = 5,
            debug = true,
        }
    end
    if not TCCAUserConfig.targetAssistance then 
         TCCAUserConfig.targetAssistance = {
            chatText = true,
            frameText = true,
            wrongTargetSound = false,
            marker = true,
            markerSize = 80,
            assignedSwitchSound = true,
            countdownTimer = true,
            markInBGT = false,
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
    RegisterAddonMessagePrefix("TCCA")
    local TCCAmessageReadFrame = CreateFrame("Frame")
    TCCAmessageReadFrame:RegisterEvent("CHAT_MSG_ADDON")
    TCCAmessageReadFrame:SetScript("OnEvent", TCCA.messageReader)
end

local setupFrame = CreateFrame("Frame", "setupFrame")
setupFrame:RegisterEvent("PLAYER_LOGIN")
setupFrame:SetScript("OnEvent", setup)