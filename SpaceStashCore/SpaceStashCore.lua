require "Apollo"

-- Create the addon object and register it with Apollo in a single line.
local MAJOR, MINOR = "SpaceStashCore-Beta", 8

-----------------------------------------------------------------------------------------------
-- Libraries
-----------------------------------------------------------------------------------------------
local GeminiLocale = Apollo.GetPackage("Gemini:Locale-1.0").tPackage
local SpaceStashCore, glog, LibError = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon("SpaceStashCore","SpaceStash")
local L = GeminiLocale:GetLocale("SpaceStashCore", true)

local SpaceStashInventory, SpaceStashBank

SpaceStashCore.CodeEnumItemFilter = {
	[1] = "Salvagable",
	[2] = "Consumable",
	[3] = "Housing",
	[4] = "Crafting",
	[5] = "AMP",
	[6] = "Costume",
	[7] = "Schematic",
}

local defaults = {}
defaults.profile = {}
defaults.profile.config = {}
defaults.profile.version = {}
defaults.profile.version.MAJOR = MAJOR
defaults.profile.version.MINOR = MINOR
defaults.profile.config.auto = {}
defaults.profile.config.auto.inventory = {}
defaults.profile.config.auto.inventory.vendor = false
defaults.profile.config.auto.inventory.bank = false
defaults.profile.config.auto.inventory.auctionhouse = false
defaults.profile.config.auto.inventory.commoditiesexchange = false
defaults.profile.config.auto.inventory.mailbox = false
defaults.profile.config.auto.inventory.engravingstation = false
defaults.profile.config.auto.inventory.craftingstation = false
defaults.profile.config.auto.inventory.sort = 0
defaults.profile.config.auto.repair = false
defaults.profile.config.auto.sell = {}
defaults.profile.config.auto.sell.whitelist = {}
defaults.profile.config.auto.sell.blacklist = {}
defaults.profile.config.auto.sell.whitelistRaw = ""
defaults.profile.config.auto.sell.blacklistRaw = ""
defaults.profile.config.auto.sell.active = false
defaults.profile.config.auto.sell.filters = {}
defaults.profile.config.auto.sell.filters.Salvagables = { active = false, filter = 1, group = 1}
defaults.profile.config.auto.sell.filters.Consumables = { active = false, filter = 2, group = 2}
defaults.profile.config.auto.sell.filters.Housing = { active = false, filter = 3, group = 2 }
defaults.profile.config.auto.sell.filters.Crafting = { active = false, filter = 4, group = 2 }
defaults.profile.config.auto.sell.filters.AMP = { active = false, filter = 5, group = 2 }
defaults.profile.config.auto.sell.filters.Costumes = { active = false, filter = 6, group = 2 }
defaults.profile.config.auto.sell.filters.Schematics = { active = false, filter = 7, group = 2 }

defaults.profile.config.auto.sell.QualityTreshold = 1


-- Replaces MyAddon:OnLoad
function SpaceStashCore:OnInitialize()

  self.db = Apollo.GetPackage("Gemini:DB-1.0").tPackage:New(self, defaults, true)

  

  GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage
  inspect = Apollo.GetPackage("Drafto:Lib:inspect-1.2").tPackage
  L = GeminiLocale:GetLocale("SpaceStashCore", true)
  SpaceStashInventory = Apollo.GetAddon("SpaceStashInventory")
  SpaceStashBank = Apollo.GetAddon("SpaceStashBank")

  self.filters = {}
 	self.filters.Salvagable = ItemFilterProperty_Salvagable
	self.filters.Consumable = ItemFilterFamily_Consumable
	self.filters.Housing = ItemFilterFamily_Housing
	self.filters.Crafting = ItemFilterFamily_Crafting
	self.filters.AMP = ItemFilterFamily_AMP
	self.filters.Costume = ItemFilterFamily_Costume
	self.filters.Schematic = ItemFilterFamily_Schematic

  glog = Apollo.GetPackage("Gemini:Logging-1.2").tPackage:GetLogger({
    level = "INFO",
    pattern = "%d [%c:%n] %l - %m",
    appender = "Print"
  })
end

function SpaceStashCore:OnConfigure()
  Event_FireGenericEvent("SpaceStashCore_OpenOptions", self)
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
  self.SSCAutoRepair = self.SSCOptionsFrame:FindChild("SSCAutoRepair")
  self.SSCAutoSell = self.SSCOptionsFrame:FindChild("SSCAutoSell")
  self.SSCSellQualityChooserButton = self.SSCOptionsFrame:FindChild("SellQualityChooserButton")
  self.SSCSellSavagable = self.SSCOptionsFrame:FindChild("SSCSellSavagable")
  self.SSCSellConsumables = self.SSCOptionsFrame:FindChild("SSCSellConsumables")
  self.SSCSellAMP = self.SSCOptionsFrame:FindChild("SSCSellAMP")
  self.SSCSellHousing = self.SSCOptionsFrame:FindChild("SSCSellHousing")
  self.SSCSellCrafting = self.SSCOptionsFrame:FindChild("SSCSellCrafting")
  self.SSCSellCostumes = self.SSCOptionsFrame:FindChild("SSCSellCostumes")
  self.SSCSellSchematics = self.SSCOptionsFrame:FindChild("SSCSellSchematics")
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
  self.SSISortChooserButton = self.SSIOptionsFrame:FindChild("SSISortChooserButton")

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
  
  self:OnSpaceStashCoreReady()
end

-- Called when player has loaded and entered the world
function SpaceStashCore:OnEnable()
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

  self.xmlDoc = XmlDoc.CreateFromFile("SpaceStashCore.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end


function SpaceStashCore:OnSpaceStashCoreReady()

self.SSCAutoCS:SetCheck(self.db.profile.config.auto.inventory.craftingstation)
self.SSCAutoSell:SetCheck(self.db.profile.config.auto.sell.active)
self.SSCSellSavagable:SetCheck(self.db.profile.config.auto.sell.filters.Salvagables.active)
self.SSCSellConsumables:SetCheck(self.db.profile.config.auto.sell.filters.Consumables.active)
self.SSCSellAMP:SetCheck(self.db.profile.config.auto.sell.filters.AMP.active)
self.SSCSellHousing:SetCheck(self.db.profile.config.auto.sell.filters.Housing.active)
self.SSCSellCrafting:SetCheck(self.db.profile.config.auto.sell.filters.Crafting.active)
self.SSCSellCostumes:SetCheck(self.db.profile.config.auto.sell.filters.Costumes.active)
self.SSCSellSchematics:SetCheck(self.db.profile.config.auto.sell.filters.Schematics.active)
self.SSCAutoRepair:SetCheck(self.db.profile.config.auto.repair)
self.SSCAutoES:SetCheck(self.db.profile.config.auto.inventory.engravingstation)

self.SSCAutoMailbox:SetCheck(self.db.profile.config.auto.inventory.mailbox)
self.SSCAutoCE:SetCheck(self.db.profile.config.auto.inventory.commoditiesexchange)
self.SSCAutoAH:SetCheck(self.db.profile.config.auto.inventory.auctionhouse)
self.SSCAutoBank:SetCheck(self.db.profile.config.auto.inventory.bank)
self.SSCAutoVendor:SetCheck(self.db.profile.config.auto.inventory.vendor)

self.SellWhitelist:SetText(self.db.profile.config.auto.sell.whitelistRaw or "")
self.SellBlacklist:SetText(self.db.profile.config.auto.sell.blacklistRaw or "")

if self.db.profile.config.auto.sell.QualityTreshold == Item.CodeEnumItemQuality.Inferior then
  self.SSCSellQualityChooserButton:FindChild("Choice1"):SetCheck(true)
  self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice1"):GetText())
elseif self.db.profile.config.auto.sell.QualityTreshold == Item.CodeEnumItemQuality.Average then
  self.SSCSellQualityChooserButton:FindChild("Choice2"):SetCheck(true)
  self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice2"):GetText())
elseif self.db.profile.config.auto.sell.QualityTreshold == Item.CodeEnumItemQuality.Good then
  self.SSCSellQualityChooserButton:FindChild("Choice3"):SetCheck(true)
  self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice3"):GetText())
elseif self.db.profile.config.auto.sell.QualityTreshold == Item.CodeEnumItemQuality.Excellent then
  self.SSCSellQualityChooserButton:FindChild("Choice4"):SetCheck(true)
  self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice4"):GetText())
elseif self.db.profile.config.auto.sell.QualityTreshold == Item.CodeEnumItemQuality.Excellent then
  self.SSCSellQualityChooserButton:FindChild("Choice5"):SetCheck(true)
  self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice5"):GetText())
elseif self.db.profile.config.auto.sell.QualityTreshold == Item.CodeEnumItemQuality.Excellent then
  self.SSCSellQualityChooserButton:FindChild("Choice6"):SetCheck(true)
  self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice6"):GetText())
elseif self.db.profile.config.auto.sell.QualityTreshold == Item.CodeEnumItemQuality.Excellent then
  self.SSCSellQualityChooserButton:FindChild("Choice7"):SetCheck(true)
  self.SSCSellQualityChooserButton:SetText(self.SSCSellQualityChooserButton:FindChild("Choice7"):GetText())
end

if self.db.profile.config.auto.inventory.sort == 0 then
  self.SSISortChooserButton:FindChild("Choice1"):SetCheck(true)
  self.SSISortChooserButton:SetText(self.SSISortChooserButton:FindChild("Choice1"):GetText())
elseif self.db.profile.config.auto.inventory.sort == 1 then
  self.SSISortChooserButton:FindChild("Choice2"):SetCheck(true)
  self.SSISortChooserButton:SetText(self.SSISortChooserButton:FindChild("Choice2"):GetText())
elseif self.db.profile.config.auto.inventory.sort == 2 then
  self.SSISortChooserButton:FindChild("Choice3"):SetCheck(true)
  self.SSISortChooserButton:SetText(self.SSISortChooserButton:FindChild("Choice3"):GetText())
elseif self.db.profile.config.auto.inventory.sort == 3 then
  self.SSISortChooserButton:FindChild("Choice4"):SetCheck(true)
  self.SSISortChooserButton:SetText(self.SSISortChooserButton:FindChild("Choice4"):GetText())
end

self:SetSortMehtod(self.db.profile.config.auto.inventory.sort)
  GeminiLocale:TranslateWindow(L, self.wndMain)

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
  self.db.profile.config.auto.inventory.vendor = self.SSCAutoVendor:IsChecked()
end

function SpaceStashCore:OnInventoyAtBankChanged( wndHandler, wndControl )
  self.db.profile.config.auto.inventory.bank = self.SSCAutoBank:IsChecked()
end

function SpaceStashCore:OnInventoyAtAHChanged( wndHandler, wndControl )
  self.db.profile.config.auto.inventory.auctionhouse = self.SSCAutoAH:IsChecked()
end

function SpaceStashCore:OnInventoyAtCEChanged( wndHandler, wndControl )
  self.db.profile.config.auto.inventory.commoditiesexchange = self.SSCAutoCE:IsChecked()
end

function SpaceStashCore:OnInventoyAtMailboxChanged( wndHandler, wndControl )
  self.db.profile.config.auto.inventory.mailbox = self.SSCAutoMailbox:IsChecked()
end

function SpaceStashCore:OnInventoyAtESChanged( wndHandler, wndControl )
  self.db.profile.config.auto.inventory.engravingstation = self.SSCAutoES:IsChecked()
end

function SpaceStashCore:OnInventoyAtCraftingStationChanged( wndHandler, wndControl )
  self.db.profile.config.auto.inventory.craftingstation = self.SSCAutoCS:IsChecked()
end

function SpaceStashCore:OnAutoRepairChange( wndHandler, wndControl )
  self.db.profile.config.auto.repair = self.SSCAutoRepair:IsChecked()
end

function SpaceStashCore:OnAutoSellChange( wndHandler, wndControl )
  self.db.profile.config.auto.sell.active = self.SSCAutoSell:IsChecked()
end

function SpaceStashCore:OnSellSalvagableChange( wndHandler, wndControl )
  self.db.profile.config.auto.sell.filters.Salvagables.active = self.SSCSellSavagable:IsChecked()
end

function SpaceStashCore:OnSellConsumablesChange( wndHandler, wndControl )
	self.db.profile.config.auto.sell.filters.Consumables.active = self.SSCSellConsumables:IsChecked()
end

function SpaceStashCore:OnSellCostumesChange( wndHandler, wndControl )
	self.db.profile.config.auto.sell.filters.Costumes.active = self.SSCSellCostumes:IsChecked()
end

function SpaceStashCore:OnSellAMPChange( wndHandler, wndControl )
	self.db.profile.config.auto.sell.filters.AMP.active = self.SSCSellAMP:IsChecked()
end

function SpaceStashCore:OnSellHousingChange( wndHandler, wndControl )
	self.db.profile.config.auto.sell.filters.Housing.active = self.SSCSellHousing:IsChecked()
end

function SpaceStashCore:OnSellCraftingChange( wndHandler, wndControl )
	self.db.profile.config.auto.sell.filters.Crafting.active = self.SSCSellCrafting:IsChecked()
end

function SpaceStashCore:OnSellSchematicsChange( wndHandler, wndControl )
	self.db.profile.config.auto.sell.filters.Schematics.active = self.SSCSellSchematics:IsChecked()
end

function SpaceStashCore:OnInventorySortToggle( wndHandler, wndControl )
  self.SSISortChooserButton:FindChild("ChoiceContainer"):Show(self.SSISortChooserButton:IsChecked(),true)
end

function SpaceStashCore:OnInventorySortChooserContainerClose()
  self.SSISortChooserButton:SetCheck(false)
end

local fnSortItemsByName = function(itemLeft, itemRight)
  if itemLeft == itemRight then
    return 0
  end
  if itemLeft and itemRight == nil then
    return -1
  end
  if itemLeft == nil and itemRight then
    return 1
  end
  
  local strLeftName = itemLeft:GetName()
  local strRightName = itemRight:GetName()
  if strLeftName < strRightName then
    return -1
  end
  if strLeftName > strRightName then
    return 1
  end
  
  return 0
end

local fnSortItemsByCategory = function(itemLeft, itemRight)
  if itemLeft == itemRight then
    return 0
  end
  if itemLeft and itemRight == nil then
    return -1
  end
  if itemLeft == nil and itemRight then
    return 1
  end
  
  local strLeftName = itemLeft:GetItemCategoryName()
  local strRightName = itemRight:GetItemCategoryName()
  if strLeftName < strRightName then
    return -1
  end
  if strLeftName > strRightName then
    return 1
  end
  
  local strLeftName = itemLeft:GetName()
  local strRightName = itemRight:GetName()
  if strLeftName < strRightName then
    return -1
  end
  if strLeftName > strRightName then
    return 1
  end
  
  return 0
end

local fnSortItemsByQuality = function(itemLeft, itemRight)
  if itemLeft == itemRight then
    return 0
  end
  if itemLeft and itemRight == nil then
    return -1
  end
  if itemLeft == nil and itemRight then
    return 1
  end
  
  local eLeftQuality = itemLeft:GetItemQuality()
  local eRightQuality = itemRight:GetItemQuality()
  if eLeftQuality > eRightQuality then
    return -1
  end
  if eLeftQuality < eRightQuality then
    return 1
  end
  
  local strLeftName = itemLeft:GetName()
  local strRightName = itemRight:GetName()
  if strLeftName < strRightName then
    return -1
  end
  if strLeftName > strRightName then
    return 1
  end
  
  return 0
end

function SpaceStashCore:OnInventorySortSelected(wndHandler, wndControl)
  if wndHandler == wndControl then
    if wndHandler:GetName() == "Choice1" then
      self.db.profile.config.auto.inventory.sort = 0
    elseif wndHandler:GetName() == "Choice2" then
      self.db.profile.config.auto.inventory.sort = 1
    elseif wndHandler:GetName() == "Choice3" then
      self.db.profile.config.auto.inventory.sort = 2
    elseif wndHandler:GetName() == "Choice4" then
      self.db.profile.config.auto.inventory.sort = 3
    end
    
    self.SSISortChooserButton:SetText(wndHandler:GetText())
    self.SSISortChooserButton:FindChild("ChoiceContainer"):Show(false,true)
  end
  self:OnInventorySortChooserContainerClose()

  if SpaceStashInventory then
    self:SetSortMehtod(self.db.profile.config.auto.inventory.sort)
  end
end

function SpaceStashCore:SetSortMehtod(nSortMethod)
  self.db.profile.config.sort = nSortMethod



  if nSortMethod == 1 then
    SpaceStashInventory:SetSortMehtod(fnSortItemsByName)
  elseif nSortMethod == 2 then
    SpaceStashInventory:SetSortMehtod(fnSortItemsByQuality)
  elseif nSortMethod == 3 then
    SpaceStashInventory:SetSortMehtod(fnSortItemsByCategory)
  elseif nSortMethod == 0 then 
    SpaceStashInventory:SetSortMehtod()
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
      self.db.profile.config.auto.sell.QualityTreshold = Item.CodeEnumItemQuality.Inferior
    elseif wndHandler:GetName() == "Choice2" then
      self.db.profile.config.auto.sell.QualityTreshold = Item.CodeEnumItemQuality.Average
    elseif wndHandler:GetName() == "Choice3" then
      self.db.profile.config.auto.sell.QualityTreshold = Item.CodeEnumItemQuality.Good
    elseif wndHandler:GetName() == "Choice4" then
      self.db.profile.config.auto.sell.QualityTreshold = Item.CodeEnumItemQuality.Excellent
    elseif wndHandler:GetName() == "Choice5" then
      self.db.profile.config.auto.sell.QualityTreshold = Item.CodeEnumItemQuality.Superb
    elseif wndHandler:GetName() == "Choice6" then
      self.db.profile.config.auto.sell.QualityTreshold = Item.CodeEnumItemQuality.Legendary
    elseif wndHandler:GetName() == "Choice7" then
      self.db.profile.config.auto.sell.QualityTreshold = Item.CodeEnumItemQuality.Artifact
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
  if self.db.profile.config.auto.inventory.vendor then 
    SpaceStashInventory:OpenInventory()
  end

  if self.db.profile.config.auto.sell.active then
    self:SellItems()
  end

  if self.db.profile.config.auto.repair then
    RepairAllItemsVendor()
  end
  
end

function SpaceStashCore:SellItems()
  for _, item in ipairs(GameLib.GetPlayerUnit():GetInventoryItems()) do
    if self.stringInArray(item.itemInBag:GetName(),self.db.profile.config.auto.sell.whitelist) and item.itemInBag:GetSellPrice() then
      SellItemToVendorById(item.itemInBag:GetInventoryId(), item.itemInBag:GetStackCount())
    elseif (not self.stringInArray(item.itemInBag:GetName(),self.db.profile.config.auto.sell.blacklist)) and item.itemInBag:GetItemQuality() <= self.db.profile.config.auto.sell.QualityTreshold and self:FilterItem(item.itemInBag) and item.itemInBag:GetSellPrice() then
    	SellItemToVendorById(item.itemInBag:GetInventoryId(), item.itemInBag:GetStackCount())
    end
  end
end

function SpaceStashCore.stringInArray(str,array)
	for k,v in ipairs(array) do
		if str == v then return true end
	end
end

function SpaceStashCore:OnSellWhitelistChange()
	local lines = {}
	local str = self.SellWhitelist:GetText()
	self.db.profile.config.auto.sell.whitelistRaw = self.SellWhitelist:GetText()
	local function helper(line) table.insert(lines, line) end
	helper((str:gsub("(.-)\r?\n", helper)))

	self.db.profile.config.auto.sell.whitelist = lines
end

function SpaceStashCore:OnSellBlacklistChange()
	local lines = {}
	local str = self.SellBlacklist:GetText()
	self.db.profile.config.auto.sell.blacklistRaw = self.SellBlacklist:GetText()
	local function helper(line) table.insert(lines, line) end
	helper((str:gsub("(.-)\r?\n", helper)))

	self.db.profile.config.auto.sell.blacklist = lines
end

function SpaceStashCore:FilterItem(item)
	local filterArray = self.db.profile.config.auto.sell.filters
	local bFamily = false
	local bNoFamily = true
	for _, type in pairs(filterArray) do
		-- group 1 is exclusive
		local bFilterResult = self.filters[self.CodeEnumItemFilter[type.filter]](item)
		if type.group == 1 then
			if bFilterResult and not type.active then return false end
		elseif type.group == 2 and not bFamily then
			if bFilterResult then
				if not type.active then 
					return false
				else
					bFamily = true -- not return true cause group1 is exclusive and may be filtered later
				end
				bNoFamily = false
			end
			
		end
	end
  
	return bFamily or bNoFamily
end

function SpaceStashCore.FilterItemFamily(item)

end


------------------------------------------------------------------------

function SpaceStashCore:OnShowBank() 
  if not self.db.profile.config.auto.inventory.bank then return end

  SpaceStashInventory:OpenInventory()
end

function SpaceStashCore:OnShowAuctionHouse( wndHandler, wndControl )
  if not self.db.profile.config.auto.inventory.auctionhouse then return end

  SpaceStashInventory:OpenInventory()
end

function SpaceStashCore:OnShowCommoditiesExchange( wndHandler, wndControl )
  if not self.db.profile.config.auto.inventory.commoditiesexchange then return end

  SpaceStashInventory:OpenInventory()
end

function SpaceStashCore:OnShowMailbox( wndHandler, wndControl )
  if not self.db.profile.config.auto.inventory.mailbox then return end

  SpaceStashInventory:OpenInventory()
end

function SpaceStashCore:OnShowEngravingStation()
  if not self.db.profile.config.auto.inventory.engravingstation then return end

  SpaceStashInventory:OpenInventory()
end

function SpaceStashCore:OnShowCraftingStation()
  if not self.db.profile.config.auto.inventory.craftingstation then return end

  SpaceStashInventory:OpenInventory()
end

function ItemFilterProperty_Salvagable(item)
  if item:CanSalvage() then return true else return false end
end
function ItemFilterFamily_Consumable(item)
  if item:GetItemFamily() == 16 then return true else return false end
end

function ItemFilterFamily_Crafting(item)
  if item:GetItemFamily() == 27 then return true else return false end
end

function ItemFilterFamily_Housing(item)
  if item:GetItemFamily() == 20 then return true else return false end
end

function ItemFilterFamily_AMP(item)
  if item:GetItemFamily() == 32 then return true else return false end
end

function ItemFilterFamily_Schematic(item)
  if item:GetItemFamily() == 19 then return true else return false end
end

function ItemFilterFamily_Costume(item)
  if item:GetItemFamily() == 26 then return true else return false end
end 
