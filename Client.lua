local NOKILLTARGETASSIGNED = "No kill target assigned."
local assignedFrame

-- Adapted from l2target --
function TCCA.setupTargetMarker()
    local LibNameplate = LibStub("LibNameplate-1.0", true)
	
	local targetFrame = CreateFrame("Button", "targetFrame", UIParent)
    targetFrame:SetNormalTexture("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8") -- Skull Raid Target Icon
    targetFrame:SetWidth(TCCAUserConfig.targetAssistance.markerSize)
    targetFrame:SetHeight(TCCAUserConfig.targetAssistance.markerSize)

	local function updateTargetMarker()
		if TCCA.assignedKillTarget then
            local assignedTargetNamePlate
            local assignedKillTargetCharName = TCCA.assignedKillTarget:match("^(%a*)-")
            if assignedKillTargetCharName then
                --guess not on connected realm
                assignedTargetNamePlate = LibNameplate:GetNameplateByName(assignedKillTargetCharName .. " (*)")
                --in case of being on connected realm
                assignedTargetNamePlate = assignedTargetNamePlate or LibNameplate:GetNameplateByName(assignedKillTargetCharName)
            else
                -- target certainly on player character's home realm or an NPC as no '-' in local name
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
    TCCA.assignedKillTarget = newTarget
    local tA = TCCAUserConfig.targetAssistance
    if tA.chatText then
        TCCA.printTarget()
    end
    if tA.frameText then
        assignedFrame.text:SetText(newTarget or NOKILLTARGETASSIGNED)
    end
    if tA.wrongTargetSound then
    end
    if tA.assignedSwitchSound then
        PlaySoundFile(TCCAUserConfig.assignedSwitchSoundEffect)
    end
end

function TCCA.setLocalTarget()
    local newTarget = GetUnitName("target", true)
    if newTarget ~= TCCA.assignedKillTarget then
        TCCA.targetChanged(newTarget)
    end
    return newTarget
end

function TCCA.clearLocalTarget()
    if TCCA.assignedKillTarget then
        TCCA.targetChanged(nil)
    end
end