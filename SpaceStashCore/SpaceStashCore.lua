require "Apollo"

-- Create the addon object and register it with Apollo in a single line.
local MAJOR, MINOR = "SpaceStashCore-Beta", 4

local tDefaults = {}
tDefaults.tConfig = {}
tDefaults.tConfig.version = {}
tDefaults.tConfig.version.MAJOR = MAJOR
tDefaults.tConfig.version.MINOR = MINOR
tDefaults.tConfig.auto = {}
tDefaults.tConfig.auto.inventory = {}
tDefaults.tConfig.auto.inventory.vendor = false
tDefaults.tConfig.auto.inventory.bank = false
tDefaults.tConfig.auto.inventory.auctionhouse = false
tDefaults.tConfig.auto.inventory.commoditiesexchange = false
tDefaults.tConfig.auto.inventory.mailbox = false
tDefaults.tConfig.auto.inventory.engravingstation = false
tDefaults.tConfig.auto.inventory.craftingstation = false
tDefaults.tConfig.auto.inventory.sort = 0
tDefaults.tConfig.auto.repair = false
tDefaults.tConfig.auto.sell = false
tDefaults.tConfig.auto.sellSalvagables = false
tDefaults.tConfig.auto.sellQualityTreshold = 1


-----------------------------------------------------------------------------------------------
-- Libraries
-----------------------------------------------------------------------------------------------
local SpaceStashCore, GeminiLocale, GeminiGUI, GeminiLogging, inspect, glog, LibError = Apollo.GetPackage("Gemini:Addon-1.0").tPackage:NewAddon(tDefaults,"SpaceStashCore", false, {}), Apollo.GetPackage("Gemini:Locale-1.0").tPackage
local L

local SpaceStashInventory, SpaceStashBank

-- Replaces MyAddon:OnLoad
function SpaceStashCore:OnInitialize()
  Apollo.CreateTimer("SSCLoadingTimer", 5.0, false)
  Apollo.RegisterTimerHandler("SSCLoadingTimer", "OnLoadingTimer", self)
  self.xmlDoc = XmlDoc.CreateFromFile("SpaceStashCore.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)
  self.bWindowCreated = false
  self.bReady = false
  self.bSavedDataRestored = false
  GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage
  inspect = Apollo.GetPackage("Drafto:Lib:inspect-1.2").tPackage
  L = GeminiLocale:GetLocale("SpaceStashCore", true)
  SpaceStashInventory = Apollo.GetAddon("SpaceStashInventory")
  SpaceStashBank = Apollo.GetAddon("SpaceStashBank")
end

function SpaceStashCore:OnLoadingTimer()
  Apollo.StopTimer("SSICoadingTimer")
  if self.bSavedDataRestored == false and self.bWindowCreated == true then
    glog:info("SpaceStashCore no data to restore.")
    self:OnSpaceStashCoreReady()
  end
end

function SpaceStashCore:OnDocumentReady()

  self.wndMain = Apollo.LoadForm(self.xmlDoc, "SpaceStashCoreForm", nil, self)
  self.targetFrame = self.wndMain:FindChild("TargetFrame")

  self.wndMain:Show(false,true)

  self.SSCOptionsFrame = Apollo.LoadForm(self.xmlDoc, "SSCOptionsFrame", self.targetFrame, self)
  self.SSCAutoVendor = self.SSCOptionsFrame:FindChild("SSCAutoVendor")
  self.SSCAutoBank = self.SSCOptionsFrame:FindChild("SSCAutoBank")
  self.SSCAutoAH = self.SSCOptionsFrame:FindChild("SSCAutoAH")
  self.SSCAutoCE = self.SSCOptionsFrame:FindChild("SSCAutoCE")
  self.SSCAutoMailbox = self.SSCOptionsFrame:FindChild("SSCAutoMailbox")
  self.SSCAutoES = self.SSCOptionsFrame:FindChild("SSCAutoES")
  self.SSCAutoCS = self.SSCOptionsFrame:FindChild("SSCAutoCS")
  self.SSCInventorySortChooserButton = self.SSCOptionsFrame:FindChild("InventorySortChooserButton")
  self.SSCAutoRepair = self.SSCOptionsFrame:FindChild("SSCAutoRepair")
  self.SSCAutoSell = self.SSCOptionsFrame:FindChild("SSCAutoSell")
  self.SSCSellSavagable = self.SSCOptionsFrame:FindChild("SSCSellSavagable")
  self.SSCSellQualityChooserButton = self.SSCOptionsFrame:FindChild("SellQualityChooserButton")
  self.SellWhitelist = self.SSCOptionsFrame:FindChild("SellWhitelist")
  self.SellBlacklist = self.SSCOptionsFrame:FindChild("SellBlacklist")

  -----SSI OPtions -----
  self.SSIOptionsFrame = Apollo.LoadForm(self.xmlDoc, "SSIOptionsFrame", self.targetFrame, self)
  self.SSIElderGemsButton = self.SSIOptionsFrame:FindChild("ElderGemsButton")
  self.SSIPrestigeButton = self.SSIOptionsFrame:FindChild("PrestigeButton")
  self.SSIRenownButton = self.SSIOptionsFrame:FindChild("RenownButton")  self.SSICraftingVouchersButton = self.SSIOptionsFrame:FindChild("CraftingVouchersButton")
  self.SSIIconsSizeSlider = self.SSIOptionsFrame:FindChild("SSIIconsSizeSlider")
  self.SSIIconsSizeText = self.SSIOptionsFrame:FindChild("SSIIconsSizeText")
  self.SSIRowsSizeSlider = self.SSIOptionsFrame:FindChild("SSIRowsSizeSlider")
  self.SSIRowsSizeText = self.SSIOptionsFrame:FindChild("SSIRowsSizeText")

  --- SSB Options ---
  self.SSBOptionsFrame = Apollo.LoadForm(self.xmlDoc, "SSBOptionsFrame", self.targetFrame, self)
  self.SSBIconsSizeSlider = self.SSBOptionsFrame:FindChild("SSBIconsSizeSlider")
  self.SSBIconsSizeText = self.SSBOptionsFrame:FindChild("SSBIconsSizeText")
  self.SSBRowsSizeSlider = self.SSBOptionsFrame:FindChild("SSBRowsSizeSlider")
  self.SSBRowsSizeText = self.SSBOptionsFrame:FindChild("SSBRowsSizeText")
  if self.wndMain == nil or self.SSCOptionsFrame == nil then
    Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
    return
  end

  self.btnSSCOptions = self.wndMain:FindChild("SSCOptionsButton")
  self.btnSSBOptions = self.wndMain:FindChild("SSBOptionsButton")
  self.btnSSIOptions = self.wndMain:FindChild("SSIOptionsButton")

  if not SpaceStashInventory then
    self.btnSSIOptions:Show(false)
    self.btnSSBOptions:SetAnchorOffsets(0,32,0,64)
  else
    self:UpdateTrackedCurrency()
    self:UpdateInventoryIconsSize()
    self:UpdateInventoryRowsSize()
  end
  
  if not SpaceStashBank then
    self.btnSSBOptions:Show(false)
  else
    self:UpdateBankRowsSize()
    self:UpdateBankIconsSize()
  end

  self.bWindowCreated = true

  if self.bSavedDataRestored then 
    self:OnSpaceStashCoreReady()
  end
end

-- Called when player has loaded and entered the world
function SpaceStashCore:OnEnable()
  glog = GeminiLogging:GetLogger({
    level = GeminiLogging.INFO,
    pattern = "%d [%c:%n] %l - %m",
    appender = "Print"
  })

end

-- Replaces MyAddon:OnSave
function SpaceStashCore:OnSaveSettings(eLevel)
  if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then 
    return
  end

  return self.tConfig
end

-- Replaces MyAddon:OnRestore
function SpaceStashCore:OnRestoreSettings(eLevel, tSavedData)
  if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then 
    return
  elseif tSavedData == nil or tSavedData.version == nil or tSavedData.version.MAJOR ~= MAJOR then --change to corrupted save in general?

  elseif tSavedData.version.MINOR < MINOR then

  else
    self.tConfig = tSavedData
  end

  self.bSavedDataRestored = true

  if self.bWindowCreated and self.bReady == false then
    self:OnSpaceStashCoreReady()
  elseif self.bReady then
    self.SSCAutoCS:SetCheck(self.tConfig.auto.inventory.craftingstation)
    self.SSCAutoSell:SetCheck(self.tConfig.auto.sell)
    self.SSCSellSavagable:SetCheck(self.tConfig.auto.sellSalvagables)
    self.SSCAutoRepair:SetCheck(self.tConfig.auto.repair)
    self.SSCAutoES:SetCheck(self.tConfig.auto.inventory.engravingstation)

    self.SSCAutoMailbox:SetCheck(self.tConfig.auto.inventory.mailbox)
    self.SSCAutoCE:SetCheck(self.tConfig.auto.inventory.commoditiesexchange)
    self.SSCAutoAH:SetCheck(self.tConfig.auto.inventory.auctionhouse)
    self.SSCAutoBank:SetCheck(self.tConfig.auto.inventory.bank)
    self.SSCAutoVendor:SetCheck(self.tConfig.auto.inventory.vendor)
    
    if self.tConfig.auto.sellQualityTreshold == Item.CodeEnumItemQuality.Inferior then
      self.SSCSellQualityChooserButton:FindChild("Choice1"):SetCheck(true)
      self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice1"):GetText())
    elseif self.tConfig.auto.sellQualityTreshold == Item.CodeEnumItemQuality.Average then
      self.SSCSellQualityChooserButton:FindChild("Choice2"):SetCheck(true)
      self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice2"):GetText())
    elseif self.tConfig.auto.sellQualityTreshold == Item.CodeEnumItemQuality.Good then
      self.SSCSellQualityChooserButton:FindChild("Choice3"):SetCheck(true)
      self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice3"):GetText())
    elseif self.tConfig.auto.sellQualityTreshold == Item.CodeEnumItemQuality.Excellent then
      self.SSCSellQualityChooserButton:FindChild("Choice4"):SetCheck(true)
      self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice4"):GetText())
    elseif self.tConfig.auto.sellQualityTreshold == Item.CodeEnumItemQuality.Superb then
      self.SSCSellQualityChooserButton:FindChild("Choice5"):SetCheck(true)
      self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice5"):GetText())
    elseif self.tConfig.auto.sellQualityTreshold == Item.CodeEnumItemQuality.Legendary then
      self.SSCSellQualityChooserButton:FindChild("Choice6"):SetCheck(true)
      self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice6"):GetText())
    elseif self.tConfig.auto.sellQualityTreshold == Item.CodeEnumItemQuality.Artifact then
      self.SSCSellQualityChooserButton:FindChild("Choice7"):SetCheck(true)
      self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice7"):GetText())
    end

    if self.tConfig.auto.inventory.sort == 0 then
      self.SSCInventorySortChooserButton:FindChild("Choice1"):SetCheck(true)
      self.SSCInventorySortChooserButton:SetText(self.SSCInventorySortChooserButton:FindChild("Choice1"):GetText())
    elseif self.tConfig.auto.inventory.sort == 1 then
      self.SSCInventorySortChooserButton:FindChild("Choice2"):SetCheck(true)
      self.SSCInventorySortChooserButton:SetText(self.SSCInventorySortChooserButton:FindChild("Choice2"):GetText())
    elseif self.tConfig.auto.inventory.sort == 2 then
      self.SSCInventorySortChooserButton:FindChild("Choice3"):SetCheck(true)
      self.SSCInventorySortChooserButton:SetText(self.SSCInventorySortChooserButton:FindChild("Choice3"):GetText())
    elseif self.tConfig.auto.inventory.sort == 3 then
      self.SSCInventorySortChooserButton:FindChild("Choice4"):SetCheck(true)
      self.SSCInventorySortChooserButton:SetText(self.SSCInventorySortChooserButton:FindChild("Choice4"):GetText())
    end
  end
end

function SpaceStashCore:OnSpaceStashCoreReady()

self.SSCAutoCS:SetCheck(self.tConfig.auto.inventory.craftingstation)
self.SSCAutoSell:SetCheck(self.tConfig.auto.sell)
self.SSCSellSavagable:SetCheck(self.tConfig.auto.sellSalvagables)
self.SSCAutoRepair:SetCheck(self.tConfig.auto.repair)
self.SSCAutoES:SetCheck(self.tConfig.auto.inventory.engravingstation)

self.SSCAutoMailbox:SetCheck(self.tConfig.auto.inventory.mailbox)
self.SSCAutoCE:SetCheck(self.tConfig.auto.inventory.commoditiesexchange)
self.SSCAutoAH:SetCheck(self.tConfig.auto.inventory.auctionhouse)
self.SSCAutoBank:SetCheck(self.tConfig.auto.inventory.bank)
self.SSCAutoVendor:SetCheck(self.tConfig.auto.inventory.vendor)

if self.tConfig.auto.sellQualityTreshold == Item.CodeEnumItemQuality.Inferior then
  self.SSCSellQualityChooserButton:FindChild("Choice1"):SetCheck(true)
  self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice1"):GetText())
elseif self.tConfig.auto.sellQualityTreshold == Item.CodeEnumItemQuality.Average then
  self.SSCSellQualityChooserButton:FindChild("Choice2"):SetCheck(true)
  self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice2"):GetText())
elseif self.tConfig.auto.sellQualityTreshold == Item.CodeEnumItemQuality.Good then
  self.SSCSellQualityChooserButton:FindChild("Choice3"):SetCheck(true)
  self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice3"):GetText())
elseif self.tConfig.auto.sellQualityTreshold == Item.CodeEnumItemQuality.Excellent then
  self.SSCSellQualityChooserButton:FindChild("Choice4"):SetCheck(true)
  self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice4"):GetText())
elseif self.tConfig.auto.sellQualityTreshold == Item.CodeEnumItemQuality.Superb then
  self.SSCSellQualityChooserButton:FindChild("Choice5"):SetCheck(true)
  self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice5"):GetText())
elseif self.tConfig.auto.sellQualityTreshold == Item.CodeEnumItemQuality.Legendary then
  self.SSCSellQualityChooserButton:FindChild("Choice6"):SetCheck(true)
  self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice6"):GetText())
elseif self.tConfig.auto.sellQualityTreshold == Item.CodeEnumItemQuality.Artifact then
  self.SSCSellQualityChooserButton:FindChild("Choice7"):SetCheck(true)
  self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice7"):GetText())
end

if self.tConfig.auto.inventory.sort == 0 then
  self.SSCInventorySortChooserButton:FindChild("Choice1"):SetCheck(true)
  self.SSCInventorySortChooserButton:SetText(self.SSCInventorySortChooserButton:FindChild("Choice1"):GetText())
elseif self.tConfig.auto.inventory.sort == 1 then
  self.SSCInventorySortChooserButton:FindChild("Choice2"):SetCheck(true)
  self.SSCInventorySortChooserButton:SetText(self.SSCInventorySortChooserButton:FindChild("Choice2"):GetText())
elseif self.tConfig.auto.inventory.sort == 2 then
  self.SSCInventorySortChooserButton:FindChild("Choice3"):SetCheck(true)
  self.SSCInventorySortChooserButton:SetText(self.SSCInventorySortChooserButton:FindChild("Choice3"):GetText())
elseif self.tConfig.auto.inventory.sort == 3 then
  self.SSCInventorySortChooserButton:FindChild("Choice4"):SetCheck(true)
  self.SSCInventorySortChooserButton:SetText(self.SSCInventorySortChooserButton:FindChild("Choice4"):GetText())
end

  Apollo.RegisterSlashCommand("ssc", "OnSlashCommand", self)
  Apollo.RegisterEventHandler("SpaceStashCore_OpenOptions", "OnOpenOptions", self)
  Apollo.RegisterEventHandler("ShowBank", "OnShowBank", self)
  Apollo.RegisterEventHandler("ToggleAuctionWindow", "OnShowAuctionHouse", self)
  Apollo.RegisterEventHandler("ToggleMarketplaceWindow", "OnShowCommoditiesExchange", self)
  Apollo.RegisterEventHandler("InvokeVendorWindow", "OnShowVendor", self)
  Apollo.RegisterEventHandler("MailBoxActivate","OnShowMailbox",self)
  Apollo.RegisterEventHandler("GenericEvent_CraftingResume_OpenEngraving",  "OnShowEngravingStation", self)
  Apollo.RegisterEventHandler("ToggleTradeskills",  "OnShowCraftingStation", self)
  Apollo.RegisterEventHandler("GenericEvent_OpenToSpecificSchematic", "OnShowCraftingStation", self)
  Apollo.RegisterEventHandler("GenericEvent_OpenToSpecificTechTree",   "OnShowCraftingStation", self)
  Apollo.RegisterEventHandler("GenericEvent_OpenToSearchSchematic",   "OnShowCraftingStation", self)
  Apollo.RegisterEventHandler("AlwaysShowTradeskills",   "OnShowCraftingStation", self)
  GeminiLocale:TranslateWindow(L, self.wndMain)

  self.bReady = true
  self.wndMain:Show(self.bEarlyShowBank,true)
end

function SpaceStashCore:OnSlashCommand(strCommand, strParam)
  if strParam == "" then 

    self.wndMain:Show(true,true)
  elseif strParam == "info" then 
    glog:info(self)
  else

  end
end

function SpaceStashCore:OnOpenOptions( oHandler )
  self.wndMain:Show(true,true)

  if oHandler == SpaceStashBank then
    self.btnSSBOptions:SetCheck(true)
    self:SpaceStashBankButtonCheck()

    self.btnSSIOptions:SetCheck(false)
    self.btnSSCOptions:SetCheck(false)
    SpaceStashCore:SpaceStashCoreButtonUncheck()
    SpaceStashCore:SpaceStashInventoryButtonUncheck()
  elseif oHandler == SpaceStashInventory then

    self.btnSSIOptions:SetCheck(true)
    self:SpaceStashInventoryButtonCheck()

    self.btnSSCOptions:SetCheck(false)
    self.btnSSBOptions:SetCheck(false)
    SpaceStashCore:SpaceStashCoreButtonUncheck()
    SpaceStashCore:SpaceStashBankButtonUncheck()
  else
    self.btnSSCOptions:SetCheck(true)
    self:SpaceStashCoreButtonCheck()

    self.btnSSIOptions:SetCheck(false)
    self.btnSSBOptions:SetCheck(false)
    SpaceStashCore:SpaceStashInventoryButtonUncheck()
    SpaceStashCore:SpaceStashBankButtonUncheck()
  end
end

function SpaceStashCore:OnClose( ... )

  self.wndMain:Show(false,true)
end


function SpaceStashCore:OnModuleButton(strType,strName)
  glog:info("strName " .. strType)
  if strType == "Check" then
    if strName == "SpaceStashCoreButton" then
      self:SpaceStashCoreButtonCheck()
    elseif strName == "SpaceStashInventoryButton" then
      self:SpaceStashInventoryButtonCheck()
    elseif strName == "SpaceStashBankButton" then
      self:SpaceStashBankButtonCheck()
    end
  else
    if strName == "SpaceStashCore" then
      self:SpaceStashCoreButtonUncheck()
    elseif strName == "SpaceStashInventory" then
      self:SpaceStashInventoryButtonUncheck()
    elseif strName == "SpaceStashBankButton" then
      self:SpaceStashBankButtonUncheck()
    end
  end
end

function  SpaceStashCore:OnEscape(...)
	glog:info(...)
end

function SpaceStashCore:SpaceStashCoreButtonCheck()
  self.SSCOptionsFrame:Show(true)
  self.targetFrame:TransitionPulse()
end

function SpaceStashCore:SpaceStashCoreButtonUncheck()
  self.SSCOptionsFrame:Show(false)
  self.targetFrame:TransitionPulse()
end

function SpaceStashCore:SpaceStashInventoryButtonCheck()
  self.SSIOptionsFrame:Show(true)
  self.targetFrame:TransitionPulse()
end

function SpaceStashCore:SpaceStashInventoryButtonUncheck()
  self.SSIOptionsFrame:Show(false)
  self.targetFrame:TransitionPulse()
end

  
function SpaceStashCore:SpaceStashBankButtonCheck()
  self.SSBOptionsFrame:Show(true)
  self.targetFrame:TransitionPulse()
end


function SpaceStashCore:SpaceStashBankButtonUncheck()
  self.SSBOptionsFrame:Show(false)
  self.targetFrame:TransitionPulse()
end

function SpaceStashCore:OnCurrencySelectionChange(wndHandler, wndControl, eMouseButton)
  if wndHandler == self.SSIElderGemsButton then
    SpaceStashInventory:SetTrackedCurrency(Money.CodeEnumCurrencyType.ElderGems)
  elseif wndHandler == self.SSIPrestigeButton then
    SpaceStashInventory:SetTrackedCurrency(Money.CodeEnumCurrencyType.Prestige)
  elseif wndHandler == self.SSIRenownButton then
    SpaceStashInventory:SetTrackedCurrency(Money.CodeEnumCurrencyType.Renown)
  elseif wndHandler == self.SSICraftingVouchersButton then
    SpaceStashInventory:SetTrackedCurrency(Money.CodeEnumCurrencyType.CraftingVouchers)
  end
end

function SpaceStashCore:UpdateTrackedCurrency()
  local tracked = SpaceStashInventory:GetTrackedCurrency()
  if tracked == Money.CodeEnumCurrencyType.ElderGems then
    self.SSIElderGemsButton:SetCheck(true)
  elseif tracked == Money.CodeEnumCurrencyType.Prestige then
    self.SSIPrestigeButton:SetCheck(true)
  elseif tracked == Money.CodeEnumCurrencyType.Renown then
    self.SSIRenownButton:SetCheck(true)
  elseif tracked == Money.CodeEnumCurrencyType.CraftingVouchers then
    self.SSICraftingVouchersButton:SetCheck(true)
  end
end

function SpaceStashCore:OnInventoryIconsSizeChanged( wndHandler, wndControl, fNewValue, fOldValue )
  SpaceStashInventory:SetIconsSize(fNewValue)
  self.SSIIconsSizeText:SetText(fNewValue)
end 

function SpaceStashCore:UpdateInventoryIconsSize()
  self.SSIIconsSizeSlider:SetValue(SpaceStashInventory:GetIconsSize())
  self.SSIIconsSizeText:SetText(SpaceStashInventory:GetIconsSize())
end

function SpaceStashCore:OnInventoryRowsSizeChanged( wndHandler, wndControl, fNewValue, fOldValue )
  SpaceStashInventory:SetRowsSize(fNewValue)
  self.SSIRowsSizeText:SetText(fNewValue)
end 

function SpaceStashCore:UpdateInventoryRowsSize()
  self.SSIRowsSizeSlider:SetValue(SpaceStashInventory:GetRowsSize())
  self.SSIRowsSizeText:SetText(SpaceStashInventory:GetRowsSize())
end

function SpaceStashCore:OnBankIconsSizeChanged( wndHandler, wndControl, fNewValue, fOldValue )
  SpaceStashBank:SetIconsSize(fNewValue)
  self.SSBIconsSizeText:SetText(fNewValue)
end 

function SpaceStashCore:UpdateBankIconsSize()
  self.SSBIconsSizeSlider:SetValue(SpaceStashBank:GetIconsSize())
  self.SSBIconsSizeText:SetText(SpaceStashBank:GetIconsSize())
end

function SpaceStashCore:OnBankRowsSizeChanged( wndHandler, wndControl, fNewValue, fOldValue )
  SpaceStashBank:SetRowsSize(fNewValue)
  self.SSBRowsSizeText:SetText(fNewValue)
end 

-------------------------------------------------------------------------------------
--- SSC Options
--------------------------------------------------------------------------------------

function SpaceStashCore:UpdateBankRowsSize()
  self.SSBRowsSizeSlider:SetValue(SpaceStashBank:GetRowsSize())
  self.SSBRowsSizeText:SetText(SpaceStashBank:GetRowsSize())
end

function SpaceStashCore:OnInventoyAtVendorChanged( wndHandler, wndControl )
  self.tConfig.auto.inventory.vendor = self.SSCAutoVendor:IsChecked()
end

function SpaceStashCore:OnInventoyAtBankChanged( wndHandler, wndControl )
  self.tConfig.auto.inventory.bank = self.SSCAutoBank:IsChecked()
end

function SpaceStashCore:OnInventoyAtAHChanged( wndHandler, wndControl )
  self.tConfig.auto.inventory.auctionhouse = self.SSCAutoAH:IsChecked()
end

function SpaceStashCore:OnInventoyAtCEChanged( wndHandler, wndControl )
  self.tConfig.auto.inventory.commoditiesexchange = self.SSCAutoCE:IsChecked()
end

function SpaceStashCore:OnInventoyAtMailboxChanged( wndHandler, wndControl )
  self.tConfig.auto.inventory.mailbox = self.SSCAutoMailbox:IsChecked()
end

function SpaceStashCore:OnInventoyAtESChanged( wndHandler, wndControl )
  self.tConfig.auto.inventory.engravingstation = self.SSCAutoES:IsChecked()
end

function SpaceStashCore:OnInventoyAtCraftingStationChanged( wndHandler, wndControl )
  self.tConfig.auto.inventory.craftingstation = self.SSCAutoCS:IsChecked()
end

function SpaceStashCore:OnAutoRepairChange( wndHandler, wndControl )
  self.tConfig.auto.repair = self.SSCAutoRepair:IsChecked()
end

function SpaceStashCore:OnAutoSellChange( wndHandler, wndControl )
  self.tConfig.auto.sell = self.SSCAutoSell:IsChecked()
end

function SpaceStashCore:OnSellSalvagableChange( wndHandler, wndControl )
  self.tConfig.auto.sellSalvagables = self.SSCSellSavagable:IsChecked()
end



function SpaceStashCore:OnInventorySortToggle( wndHandler, wndControl )
  self.SSCInventorySortChooserButton:FindChild("ChoiceContainer"):Show(self.SSCInventorySortChooserButton:IsChecked(),true)
end

function SpaceStashCore:OnInventorySortChooserContainerClose()
  self.SSCInventorySortChooserButton:SetCheck(false)
end

function SpaceStashCore:OnInventorySortSelected(wndHandler, wndControl)
  if wndHandler == wndControl then
    if wndHandler:GetName() == "Choice1" then
      tDefaults.tConfig.auto.inventory.sort = 0
    elseif wndHandler:GetName() == "Choice2" then
      tDefaults.tConfig.auto.inventory.sort = 1
    elseif wndHandler:GetName() == "Choice3" then
      tDefaults.tConfig.auto.inventory.sort = 2
    elseif wndHandler:GetName() == "Choice4" then
      tDefaults.tConfig.auto.inventory.sort = 3
    end
    
    self.SSCInventorySortChooserButton:SetText(wndHandler:GetText())
    self.SSCInventorySortChooserButton:FindChild("ChoiceContainer"):Show(false,true)
  end
  self:OnInventorySortChooserContainerClose()
  if SpaceStashInventory then
    SpaceStashInventory:SetSortMehtod(tDefaults.tConfig.auto.inventory.sort)
  end
end

function SpaceStashCore:OnSellQualityChooserToggle( wndHandler, wndControl )
  self.SSCSellQualityChooserButton:FindChild("ChoiceContainer"):Show(self.SSCSellQualityChooserButton:IsChecked(),true)
end

function SpaceStashCore:OnSellQualityChooserContainerClose()
  self.SSCSellQualityChooserButton:SetCheck(false)
end

function SpaceStashCore:OnAutoSellQualitySelected(wndHandler, wndControl)
  if wndHandler == wndControl then
    if wndHandler:GetName() == "Choice1" then
      self.tConfig.auto.sellQualityTreshold = Item.CodeEnumItemQuality.Inferior
    elseif wndHandler:GetName() == "Choice2" then
      self.tConfig.auto.sellQualityTreshold = Item.CodeEnumItemQuality.Average
    elseif wndHandler:GetName() == "Choice3" then
      self.tConfig.auto.sellQualityTreshold = Item.CodeEnumItemQuality.Good
    elseif wndHandler:GetName() == "Choice4" then
      self.tConfig.auto.sellQualityTreshold = Item.CodeEnumItemQuality.Excellent
    elseif wndHandler:GetName() == "Choice5" then
      self.tConfig.auto.sellQualityTreshold = Item.CodeEnumItemQuality.Superb
    elseif wndHandler:GetName() == "Choice6" then
      self.tConfig.auto.sellQualityTreshold = Item.CodeEnumItemQuality.Legendary
    elseif wndHandler:GetName() == "Choice7" then
      self.tConfig.auto.sellQualityTreshold = Item.CodeEnumItemQuality.Artifact
    end
    
    self.SSCSellQualityChooserButton:SetText(wndHandler:GetText())
    self.SSCSellQualityChooserButton:FindChild("ChoiceContainer"):Show(false,true)
  end
  self:OnSellQualityChooserContainerClose()
end

-------------------------------------------------------------------------------------
--- Automation related events
--------------------------------------------------------------------------------------
function SpaceStashCore:OnShowVendor() 
  if self.tConfig.auto.inventory.vendor then 
    SpaceStashInventory:OpenInventory()
  end

  if self.tConfig.auto.sell then
    self:SellItems()
  end

  if self.tConfig.auto.repair then
    RepairAllItemsVendor()
  end
  
end

function SpaceStashCore:SellItems()
  for _, item in ipairs(GameLib.GetPlayerUnit():GetInventoryItems()) do
    if item.itemInBag:GetItemQuality() <= self.tConfig.auto.sellQualityTreshold and (not item.itemInBag:CanSalvage() or (item.itemInBag:CanSalvage() and self.tConfig.auto.sellSalvagables)) and item.itemInBag:GetSellPrice() then --check behavior for 'refunding' token items
      SellItemToVendorById(item.itemInBag:GetInventoryId(), item.itemInBag:GetStackCount())
    end
  end
end

function SpaceStashCore:OnSellWhitelistChange()
-- 	local lines = {}

-- 	for line in string.gmatch(self.SellWhitelist:GetText(), "([%w%p]*)\n") do 
-- 		table.insert(lines, line) 
-- 	end
-- 	local key, value
-- 	for _,v in ipairs(lines) do
-- 		key, value = string.match(self.SellWhitelist:GetText(), "(%w*):(%w*)")
-- 		if key ~= nil and value ~= nil then
-- 			glog:info(key .. "=" .. value)
-- 		end
-- 		key, value = nil, nil
-- 	end
-- 	glog:info(lines)
end



------------------------------------------------------------------------

function SpaceStashCore:OnShowBank() 
  if not self.tConfig.auto.inventory.bank then return end

  SpaceStashInventory:OpenInventory()
end

function SpaceStashCore:OnShowAuctionHouse( wndHandler, wndControl )
  if not self.tConfig.auto.inventory.auctionhouse then return end

  SpaceStashInventory:OpenInventory()
end

function SpaceStashCore:OnShowCommoditiesExchange( wndHandler, wndControl )
  if not self.tConfig.auto.inventory.commoditiesexchange then return end

  SpaceStashInventory:OpenInventory()
end

function SpaceStashCore:OnShowMailbox( wndHandler, wndControl )
  if not self.tConfig.auto.inventory.mailbox then return end

  SpaceStashInventory:OpenInventory()
end

function SpaceStashCore:OnShowEngravingStation()
  if not self.tConfig.auto.inventory.engravingstation then return end

  SpaceStashInventory:OpenInventory()
end

function SpaceStashCore:OnShowCraftingStation()
  if not self.tConfig.auto.inventory.craftingstation then return end

  SpaceStashInventory:OpenInventory()
end