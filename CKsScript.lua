-- CKsScript

-- Create addon table and initialize saved variables
local addonName, addon = ...
local CKS = CreateFrame("Frame", "CKsScript")
CKS:RegisterEvent("ADDON_LOADED")

-- Default settings
CKS.defaults = {
    disableLootWarnings = false,
    fasterAutoLoot = false,
    needOnRunes = false,
    needOnScourgestones = false,
}

-- Table to store roll choices
CKS.rollChoices = {}

-- Initialize variables
CKS.isLoaded = false

-- Main initialization function
function CKS:Init()
    -- Create saved variables if they don't exist
    if CKsScriptDB == nil then
        CKsScriptDB = CopyTable(self.defaults)
    end
    
    -- Create options panel
    self:CreateOptionsPanel()
    
    -- Register events
    self:RegisterEvents()
    
    -- Mark as loaded
    self.isLoaded = true
    
    -- Show message
    print("|cFF00FF00CKsScript|r: Addon loaded. Type /cks to open options.")
end

-- Event handling
function CKS:OnEvent(event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        self:Init()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "CONFIRM_LOOT_ROLL" then
        -- print("|cFFFF8C00[CKsScript]|r CONFIRM_LOOT_ROLL event triggered with rollID: " .. tostring(arg1))
        if CKsScriptDB.needOnRunes and self.rollChoices[arg1] == 1 then
            print("|cFFFF8C00[CKsScript]|r Auto-confirming Need roll for rollID: " .. tostring(arg1))
            -- Confirm the Need roll
            ConfirmLootRoll(arg1, 1)
            -- Hide the confirmation popup
            StaticPopup_Hide("CONFIRM_LOOT_ROLL")
            return
        
        elseif CKsScriptDB.disableLootWarnings then
            -- Auto-confirm loot dialogs
            for i = 1, STATICPOPUP_NUMDIALOGS do
                local dialog = _G["StaticPopup" .. i]
                if dialog:IsShown() and dialog.which == "CONFIRM_LOOT_ROLL" then
                    StaticPopup_OnClick(dialog, 1)
                end
            end
        end
    elseif event == "LOOT_BIND_CONFIRM" then
        if CKsScriptDB.disableLootWarnings then
            -- Auto-confirm bind on pickup loot directly
            ConfirmLootSlot(arg1, arg2)
            StaticPopup_Hide("LOOT_BIND")
            StaticPopup_Hide("LOOT_BIND_CONFIRM")
        end
    elseif event == "START_LOOT_ROLL" then
        -- Need on Necrotic Runes feature
        -- print("|cFF00FFFF[CKsScript]|r START_LOOT_ROLL event triggered with rollID: " .. tostring(arg1))
        if CKsScriptDB.needOnRunes or CKsScriptDB.needOnScourgestones then
            self:AutoNeedRunes(arg1)
        end
        
    elseif event == "LOOT_READY" then
        -- Faster auto loot feature
        if CKsScriptDB.fasterAutoLoot then
            self:FastLoot()
        end
    end
end

-- Register necessary events based on enabled features
function CKS:RegisterEvents()
    -- If disable loot warnings is enabled
    if CKsScriptDB.disableLootWarnings then
        self:RegisterEvent("CONFIRM_LOOT_ROLL")
        -- CONFIRM_DISENCHANT_ROLL removed as it's not valid in Classic Era
        self:RegisterEvent("LOOT_BIND_CONFIRM")
    else
        self:UnregisterEvent("CONFIRM_LOOT_ROLL")
        -- CONFIRM_DISENCHANT_ROLL removed as it's not valid in Classic Era
        self:UnregisterEvent("LOOT_BIND_CONFIRM")
    end
    
-- If faster auto loot is enabled
if CKsScriptDB.fasterAutoLoot then
    self:RegisterEvent("LOOT_READY")
else
    self:UnregisterEvent("LOOT_READY")
end

-- If need on runes or scourgestones is enabled
if CKsScriptDB.needOnRunes or CKsScriptDB.needOnScourgestones then
    self:RegisterEvent("START_LOOT_ROLL")
    self:RegisterEvent("CONFIRM_LOOT_ROLL")
else
    self:UnregisterEvent("START_LOOT_ROLL")
    -- Only unregister CONFIRM_LOOT_ROLL if disableLootWarnings is also disabled
    if not CKsScriptDB.disableLootWarnings then
        self:UnregisterEvent("CONFIRM_LOOT_ROLL")
    end
end
end

-- Fast loot function
function CKS:FastLoot()
    if GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
        for i = GetNumLootItems(), 1, -1 do
            LootSlot(i)
        end
    end
end

-- Auto-need Necrotic Runes and Invader Scourgestones function
function CKS:AutoNeedRunes(rollID)
    -- Print diagnostic message at the beginning
    -- print("|cFF00FF00[CKsScript]|r AutoNeedRunes called for rollID: " .. tostring(rollID))
    
    -- Get roll info for name display
    local texture, name = GetLootRollItemInfo(rollID)
    
    -- Get item link directly using GetLootRollItemLink (more reliable method)
    local itemLink = GetLootRollItemLink(rollID)
    
    -- Print item info
    -- print("|cFF00FF00[CKsScript]|r Item info - Name: " .. tostring(name) .. ", Link: " .. tostring(itemLink))
    
    -- Extract item ID from item link if available
    local itemID = itemLink and tonumber(itemLink:match("item:(%d+)"))
    -- print("|cFF00FF00[CKsScript]|r Extracted itemID: " .. tostring(itemID))
    
    -- Check if the item is a Necrotic Rune (ID 22484) or Invader Scourgestone (ID 40753)
    if itemID then
        if itemID == 22484 and CKsScriptDB.needOnRunes then
            -- print("|cFF00FFFF[CKsScript]|r DETECTED NECROTIC RUNE! Rolling need...")
            -- Roll need on Necrotic Rune
            RollOnLoot(rollID, 1) -- 1 = Need, 2 = Greed, 3 = Pass
            -- Store our roll choice
            self.rollChoices[rollID] = 1
            -- Print message to chat
            print("|cFF00FF00CKsScript|r: Auto-rolled |cFFFF0000Need|r on " .. name .. " (ID: " .. itemID .. ")")
        elseif itemID == 40753 and CKsScriptDB.needOnScourgestones then
            -- Roll need on Invader Scourgestone
            RollOnLoot(rollID, 1) -- 1 = Need, 2 = Greed, 3 = Pass
            -- Store our roll choice
            self.rollChoices[rollID] = 1
            -- Print message to chat
            print("|cFF00FF00CKsScript|r: Auto-rolled |cFFFF0000Need|r on " .. name .. " (ID: " .. itemID .. ")")
        else
            print("|cFFFF9900[CKsScript]|r Item is not configured for auto-need. No auto-roll performed.")
        end
    end
end

-- Create the options panel
function CKS:CreateOptionsPanel()
    -- Get a reference to the frame defined in XML
    local mainFrame = _G["CKsScriptFrame"]
    
    -- Ensure the frame has proper scripts for movement
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:Hide()
    
    -- Get references to existing XML elements (checkboxes)
    local disableLootWarnings = _G["CKsScriptDisableLootWarningsCheckbox"]
    local fasterAutoLoot = _G["CKsScriptFasterAutoLootCheckbox"]
    local needOnRunes = _G["CKsScriptNeedOnRunesCheckbox"]
    local needOnScourgestones = _G["CKsScriptNeedOnScourgestonesCheckbox"]
    
    -- Set their checked state based on the saved variables
    disableLootWarnings:SetChecked(CKsScriptDB.disableLootWarnings)
    fasterAutoLoot:SetChecked(CKsScriptDB.fasterAutoLoot)
    needOnRunes:SetChecked(CKsScriptDB.needOnRunes)
    needOnScourgestones:SetChecked(CKsScriptDB.needOnScourgestones)
    
    -- Connect the toggle functions to the checkboxes
    disableLootWarnings:SetScript("OnClick", function(self)
        CKsScript_ToggleDisableLootWarnings()
        self:SetChecked(CKsScriptDB.disableLootWarnings)
    end)
    
    fasterAutoLoot:SetScript("OnClick", function(self)
        CKsScript_ToggleFasterAutoLoot()
        self:SetChecked(CKsScriptDB.fasterAutoLoot)
    end)
    
    needOnRunes:SetScript("OnClick", function(self)
        CKsScript_ToggleNeedOnRunes()
        self:SetChecked(CKsScriptDB.needOnRunes)
    end)
    
    needOnScourgestones:SetScript("OnClick", function(self)
        CKsScript_ToggleNeedOnScourgestones()
        self:SetChecked(CKsScriptDB.needOnScourgestones)
    end)
    
    -- Save the main frame
    self.optionsFrame = mainFrame
end

-- Toggle options panel visibility
function CKS:ToggleOptionsPanel()
    if self.optionsFrame:IsShown() then
        self.optionsFrame:Hide()
    else
        self.optionsFrame:Show()
    end
end

-- Set up slash command
SLASH_CKSSCRIPT1 = "/cks"
SlashCmdList["CKSSCRIPT"] = function()
    CKS:ToggleOptionsPanel()
end

-- Toggle Need on Necrotic Runes setting
function CKsScript_ToggleNeedOnRunes()
    CKsScriptDB.needOnRunes = not CKsScriptDB.needOnRunes
    CKS:RegisterEvents()
end

-- Set up event handling
CKS:SetScript("OnEvent", CKS.OnEvent)

-- Toggle Disable Loot Warnings setting
function CKsScript_ToggleDisableLootWarnings()
    CKsScriptDB.disableLootWarnings = not CKsScriptDB.disableLootWarnings
    CKS:RegisterEvents()
end

-- Toggle Faster Auto Loot setting
function CKsScript_ToggleFasterAutoLoot()
    CKsScriptDB.fasterAutoLoot = not CKsScriptDB.fasterAutoLoot
    CKS:RegisterEvents()
end

-- Toggle Need on Invader Scourgestones setting
function CKsScript_ToggleNeedOnScourgestones()
    CKsScriptDB.needOnScourgestones = not CKsScriptDB.needOnScourgestones
    CKS:RegisterEvents()
end
