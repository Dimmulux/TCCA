local NOKILLTARGETASSIGNED = "No kill target assigned."
local assignedFrame

function TCCA.setupTargetMarker()
    local LibNameplate = LibStub("LibNameplate-1.0", true)
	
	local targetFrame = CreateFrame("Button", "targetFrame", UIParent)
    targetFrame:SetNormalTexture("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8") -- Skull Raid Target Icon
    targetFrame:SetWidth(TCCAUserConfig.targetAssistance.markerSize)
    targetFrame:SetHeight(TCCAUserConfig.targetAssistance.markerSize)

	local function updateTargetMarker()
		if TCCA.assignedKillTarget then
            local assignedTargetNamePlate
            local assignedKillTargetCharName, assignedKillTargetRealm = TCCA.assignedKillTarget:match("^(%a+)%-(%a*)")
            if assignedKillTargetRealm and TCCA.connectedRealms[assignedKillTargetRealm] then
				--on connected realm
                assignedTargetNamePlate = assignedTargetNamePlate or LibNameplate:GetNameplateByName(assignedKillTargetCharName)
			elseif assignedKillTargetRealm then
                --not on connected realm
                assignedTargetNamePlate = LibNameplate:GetNameplateByName(assignedKillTargetCharName .. " (*)")
            else
                -- target on player character's home realm or an NPC as no '-' in local name
                assignedTargetNamePlate = LibNameplate:GetNameplateByName(TCCA.assignedKillTarget)
            end
            if assignedTargetNamePlate then
				targetFrame:SetPoint("CENTER", assignedTargetNamePlate, "TOP", 0, 30)
				targetFrame:Show()
			elseif targetFrame:IsVisible() then
				targetFrame:Hide()
			end
        elseif targetFrame:IsVisible() then
				targetFrame:Hide()
		end
	end
	TCCA.markerUpdateTicker = API C_Timer.NewTicker(0.05, updateTargetMarker)
end

function TCCA.hideAssignedFrame()
    if assignedFrame:IsVisible() then
        assignedFrame:Hide()
        print("Target frame hidden. To show again, type " .. SLASH_TCCA_OPTIONS1 .. " showtarget .")
        TCCAUserConfig.targetAssistance.frameText = false
    end
end

function TCCA.createIfNeededAndShowAssignedFrame()
    if assignedFrame then
        assignedFrame:Show()
    else
        TCCAUserConfig.targetAssistance.frameText = true
        local saved = TCCAUserConfig.assignedKillTargetFrame
        assignedFrame = CreateFrame("Frame", "assignedFrame", UIParent)
        assignedFrame:SetFrameStrata("MEDIUM")
        assignedFrame:SetBackdrop(StaticPopup1:GetBackdrop())
        assignedFrame:SetHeight(40)
        assignedFrame:SetWidth(200)
        assignedFrame:SetPoint(saved.point, nil, saved.point, saved.x, saved.y)
        assignedFrame:SetMovable(not saved.locked)
        assignedFrame:EnableMouse(true)
        
        assignedFrame.text = assignedFrame:CreateFontString("testString", "BACKGROUND", "GameFontNormal")
        assignedFrame.text:SetText(NOKILLTARGETASSIGNED)
        assignedFrame.text:SetPoint("CENTER", assignedFrame, "CENTER")
        
        local optionsFrame = CreateFrame("Frame", "assignedFrameOptionsFrame", assignedFrame)
        assignedFrame.optionsFrame = optionsFrame
        optionsFrame:Hide()
        optionsFrame:SetFrameStrata("DIALOG")
        optionsFrame:SetBackdrop(StaticPopup3:GetBackdrop())
        optionsFrame:SetHeight(120)
        optionsFrame:SetWidth(100)
        optionsFrame:SetPoint("BOTTOMRIGHT", assignedFrame, "TOPRIGHT")
        optionsFrame:Raise()
        
        optionsFrame.optionsFrameHideButton = CreateFrame("Button", "assignedFrameOptionsFrameoptionsFrameHideButton", optionsFrame, "UIPanelButtonTemplate")
        local optionsFrameHideButton = optionsFrame.optionsFrameHideButton
        optionsFrameHideButton:SetFrameStrata("DIALOG")
        optionsFrameHideButton:SetText("Hide options")
        optionsFrameHideButton:SetHeight(40)
        optionsFrameHideButton:SetWidth(100)
        optionsFrameHideButton:SetPoint("TOP", optionsFrame, "TOP")
        optionsFrameHideButton:Raise()
        optionsFrameHideButton:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
               optionsFrame:Hide()
            end
        end)
        
        optionsFrame.assignedFrameHideButton = CreateFrame("Button", "assignedFrameOptionsFrameassignedFrameHideButton", optionsFrame, "UIPanelButtonTemplate")
        local assignedFrameHideButton = optionsFrame.assignedFrameHideButton
        assignedFrameHideButton:SetFrameStrata("DIALOG")
        assignedFrameHideButton:SetText("Hide target")
        assignedFrameHideButton:SetHeight(40)
        assignedFrameHideButton:SetWidth(100)
        assignedFrameHideButton:SetPoint("TOP", optionsFrameHideButton, "BOTTOM")
        assignedFrameHideButton:Raise()
        assignedFrameHideButton:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
               TCCA.hideAssignedFrame()
            end
        end)
        
       
        
        optionsFrame.lockButton = CreateFrame("Button", "assignedFrameOptionsFrameLockButton", optionsFrame, "UIPanelButtonTemplate")
        local lockButton = optionsFrame.lockButton
        lockButton:SetFrameStrata("DIALOG")
        lockButton:SetText(saved.locked and "Unlock" or "Lock")
        lockButton:SetHeight(40)
        lockButton:SetWidth(100)
        lockButton:SetPoint("TOP", assignedFrameHideButton, "BOTTOM")
        lockButton:Raise()
        lockButton:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                if assignedFrame:IsMovable() then
                    TCCAUserConfig.assignedKillTargetFrame.locked = true
                    lockButton:SetText("Unlock")
                    assignedFrame:SetMovable(false)
                    self:StopMovingOrSizing();
                    self.isMoving = false;
                else
                    TCCAUserConfig.assignedKillTargetFrame.locked = false
                    lockButton:SetText("Lock")
                    assignedFrame:SetMovable(true)
                end
            end
        end)
        
           
        assignedFrame:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" and not self.isMoving and self:IsMovable() then
                self:StartMoving();
                self.isMoving = true;
            end
            -- TODO make this on OnClick rather than OnMouseDown
            -- TODO make this hide when anything else is clicked
            if button == "RightButton" then
                assignedFrame.optionsFrame:Show()
            end
        end)
        assignedFrame:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" and self.isMoving then
                self:StopMovingOrSizing();
                self.isMoving = false;
                local saved = TCCAUserConfig.assignedKillTargetFrame
                local _
                saved.point, _, _, saved.x, saved.y = self:GetPoint()
            end
        end)
        assignedFrame:SetScript("OnHide", function(self)
          if self.isMoving then
           self:StopMovingOrSizing();
           self.isMoving = false;
          end
        end)
    end
end

function TCCA.printTarget()
    if TCCA.assignedKillTarget then
        print("Kill target assigned: " .. TCCA.assignedKillTarget)
    else
        print(NOKILLTARGETASSIGNED)
    end
end

function TCCA.targetChanged(newTarget)
	if TCCA.assignedKillTarget == newTarget then
        return
	end
	if TCCA.assignedKillTarget then
		TCCA.switchedAwayFromTime[TCCA.assignedKillTarget] = TCCA.latestTimestamp
	end
    TCCA.assignedKillTarget = newTarget
    local tA = TCCAUserConfig.targetAssistance
    if tA.chatText then
        TCCA.printTarget()
    end
    if tA.frameText then
        assignedFrame.text:SetText(newTarget or NOKILLTARGETASSIGNED)
    end
    if tA.assignedSwitchSound then
        PlaySoundFile(TCCAUserConfig.targetAssistance.assignedSwitchSoundEffect)
    end
end

function TCCA.setLocalTarget(newTarget)
    newTarget = newTarget or GetUnitName("target", true)
    TCCA.targetChanged(newTarget)
    return newTarget
end

do
	local directDamage = {
		SWING_DAMAGE = true,
		RANGE_DAMAGE = true,
		SPELL_DAMAGE = true,
		SWING_MISSED = true,
		RANGE_MISSED = true,
		SPELL_MISSED = true,
	}	
	function TCCA.wrongTargetSound(timeStamp, event, _, _, sourceName, _, _, _, destName)
		if TCCA.assignedKillTarget and sourceName == TCCA.playerName and destName ~= TCCA.assignedKillTarget 
		 and directDamage[event] and (not TCCA.switchedAwayFromTime[destName] 
		  or timeStamp > TCCA.switchedAwayFromTime[destName] + TCCAUserConfig.targetAsssistance.switchSecondsGrace) then
			PlaySoundFile(TCCAUserConfig.targetAssistance.wrongTargetSoundEffect)
		end	
	end
	function TCCA.attackStatisticsUpdate(timeStamp, event, _, _, sourceName, _, _, _, destName)
		if TCCA.assignedKillTarget and directDamage[event] then
			local _, maxRange = TCCA.rangeChecker:GetRange(destName)
			if true --[[maxRange and maxRange <= 50]] then
				if destName == TCCA.assignedKillTarget then
					TCCA.attacksOnCorrectTargetBy[sourceName] = (TCCA.attacksOnCorrectTargetBy[sourceName] or 0) + 1
				else
					TCCA.attacksOnWrongTargetBy[sourceName] = (TCCA.attacksOnWrongTargetBy[sourceName] or 0) + 1
				end
			end
		end
	end
end

function TCCA.printGroupMembersWithTCCA()
	local message = "Group members with TCCA: "
	--inefficient concatenation
	for name in pairs(TCCA.groupMembersWithTCCA) do
		message = message .. name .. ", " 
	end
	print(message)
end 
function TCCA.printGroupMembersWithoutTCCA()
	local message = "Group members without TCCA: "
	local withTCCA = TCCA.groupMembersWithTCCA
	--inefficient concatenation
	for name in pairs(TCCA.groupMembers) do
		if not withTCCA[name] then
			message = message .. name .. ", "
		end
	end
	print(message)
end 

