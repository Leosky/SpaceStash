require "Apollo"

-- Create the addon object and register it with Apollo in a single line.
local MAJOR, MINOR = "SpaceStashCore", 14

-----------------------------------------------------------------------------------------------
-- Libraries
-----------------------------------------------------------------------------------------------
local GeminiLocale = Apollo.GetPackage("Gemini:Locale-1.0").tPackage
local Addon, glog, LibError = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon(MAJOR,"SpaceStash")
local L = GeminiLocale:GetLocale(MAJOR, true)

local SpaceStashInventory, SpaceStashBank

Addon.CodeEnumItemFilter = {
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
defaults.profile.config.auto.bank = {}
defaults.profile.config.auto.bank.sort = 0
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
defaults.profile.config.DisplayNew = true

local _tLoadingInfo = {
	WindowManagement = { isReady = false , isInit = false },
	SpaceStashInventory = { isReady = false , isInit = false },
	SpaceStashBank = { isReady = false , isInit = false },
	GUI = { isReady = false, isInit = false },
}

-- Replaces MyAddon:OnLoad
function Addon:OnInitialize()

	self.db = Apollo.GetPackage("Gemini:DB-1.0").tPackage:New(self, defaults, true)

	GeminiLogging = _G.Apollo.GetPackage("Gemini:Logging-1.2").tPackage
	inspect = _G.Apollo.GetPackage("Drafto:Lib:inspect-1.2").tPackage
	L = GeminiLocale:GetLocale(MAJOR, true)

	self._tLoadingInfo = _tLoadingInfo

	self.filters = {
		Salvagable = ItemFilterProperty_Salvagable,
		Consumable = ItemFilterFamily_Consumable,
		Housing = ItemFilterFamily_Housing,
		Crafting = ItemFilterFamily_Crafting,
		AMP = ItemFilterFamily_AMP,
		Costume = ItemFilterFamily_Costume,
		Schematic = ItemFilterFamily_Schematic,
	}

	glog = Apollo.GetPackage("Gemini:Logging-1.2").tPackage:GetLogger({
		level = "INFO",
		pattern = "%d [%c:%n] %l - %m",
		appender = "GeminiConsole"
	})

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("WindowManagementReady", "OnWindowManagementReady", self)
	Apollo.RegisterEventHandler("WindowManagementAdd", "OnAddonFullyLoaded", self) --rover
	Apollo.RegisterEventHandler("AddonFullyLoaded","OnAddonFullyLoaded", self) -- spacestash
	Apollo.RegisterSlashCommand("ssc", "OnSlashCommand", self)
end


-- Called when player has loaded and entered the world
function Addon:OnEnable()
	self._tLoadingInfo.SpaceStashInventory.instance = Apollo.GetAddon("SpaceStashInventory")
	SpaceStashInventory = self._tLoadingInfo.SpaceStashInventory.instance

	self._tLoadingInfo.SpaceStashBank.instance = Apollo.GetAddon("SpaceStashBank")
	SpaceStashBank = self._tLoadingInfo.SpaceStashBank.instance
	
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

function Addon:OnDocumentReady()

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "SpaceStashCoreForm", nil, self)
	self.targetFrame = self.wndMain:FindChild("TargetFrame")

	if self.wndMain == nil then
		Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
		return
	end

	self.wndMain:Show(false,true)
	self.wndTarget = self.wndMain:FindChild("TargetFrame");
	self.SSCOptionsFrame = Apollo.LoadForm(self.xmlDoc, "SSCOptionsFrame", self.targetFrame, self)

	if self.SSCOptionsFrame == nil then
		Apollo.AddAddonErrorText(self, "Could not load SSCOptionsFrame for some reason.")
		return
	end

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

	self.SSICashButton = self.SSIOptionsFrame:FindChild("CashButton")
	self.SSIRenownButton = self.SSIOptionsFrame:FindChild("RenownButton")
	self.SSIElderGemsButton = self.SSIOptionsFrame:FindChild("ElderGemsButton")
	self.SSIGloryButton = self.SSIOptionsFrame:FindChild("GloryButton")
	self.SSIPrestigeButton = self.SSIOptionsFrame:FindChild("PrestigeButton")
	self.SSICraftingVouchersButton = self.SSIOptionsFrame:FindChild("CraftingVouchersButton")
	self.SSIOmnibitsButtonButton = self.SSIOptionsFrame:FindChild("OmnibitsButton")
	self.SSIServiceTokensButton = self.SSIOptionsFrame:FindChild("ServiceTokensButton")
	self.SSIFortuneCoinsButton = self.SSIOptionsFrame:FindChild("FortuneCoinsButton")

	self.SSIIconsSizeSlider = self.SSIOptionsFrame:FindChild("SSIIconsSizeSlider")
	self.SSIIconsSizeText = self.SSIOptionsFrame:FindChild("SSIIconsSizeText")
	self.SSIRowsSizeSlider = self.SSIOptionsFrame:FindChild("SSIRowsSizeSlider")
	self.SSIRowsSizeText = self.SSIOptionsFrame:FindChild("SSIRowsSizeText")
	self.SSISortChooserButton = self.SSIOptionsFrame:FindChild("SSISortChooserButton")
	self.SSCNewItemDisplay = self.SSIOptionsFrame:FindChild("SSCNewItemDisplay")

	--- SSB Options ---
	self.SSBOptionsFrame = Apollo.LoadForm(self.xmlDoc, "SSBOptionsFrame", self.targetFrame, self)

	
	self.SSBIconsSizeSlider = self.SSBOptionsFrame:FindChild("SSBIconsSizeSlider")
	self.SSBIconsSizeText = self.SSBOptionsFrame:FindChild("SSBIconsSizeText")
	self.SSBRowsSizeSlider = self.SSBOptionsFrame:FindChild("SSBRowsSizeSlider")
	self.SSBRowsSizeText = self.SSBOptionsFrame:FindChild("SSBRowsSizeText")
	self.SSBSortChooserButton = self.SSBOptionsFrame:FindChild("SSBSortChooserButton")

	self.btnSSCOptions = self.wndMain:FindChild("SSCOptionsButton")
	self.btnSSBOptions = self.wndMain:FindChild("SSBOptionsButton")
	self.btnSSIOptions = self.wndMain:FindChild("SSIOptionsButton")

	--todo change to use new soft dependency loading
	if not SpaceStashInventory then 
		self.btnSSIOptions:Show(false,true)
		self.btnSSBOptions:SetAnchorOffsets(0,32,0,64)
	end

	if not SpaceStashBank then
		self.btnSSBOptions:Show(false,true)
	end

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
	self.SSCNewItemDisplay:SetCheck(self.db.profile.config.displayNew)

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


	if self.db.profile.config.auto.bank.sort == 0 then
		self.SSBSortChooserButton:FindChild("Choice1"):SetCheck(true)
		self.SSBSortChooserButton:SetText(self.SSBSortChooserButton:FindChild("Choice1"):GetText())
	elseif self.db.profile.config.auto.bank.sort == 1 then
		self.SSBSortChooserButton:FindChild("Choice2"):SetCheck(true)
		self.SSBSortChooserButton:SetText(self.SSBSortChooserButton:FindChild("Choice2"):GetText())
	elseif self.db.profile.config.auto.bank.sort == 2 then
		self.SSBSortChooserButton:FindChild("Choice3"):SetCheck(true)
		self.SSBSortChooserButton:SetText(self.SSBSortChooserButton:FindChild("Choice3"):GetText())
	elseif self.db.profile.config.auto.bank.sort == 3 then
		self.SSBSortChooserButton:FindChild("Choice4"):SetCheck(true)
		self.SSBSortChooserButton:SetText(self.SSBSortChooserButton:FindChild("Choice4"):GetText())
	end

	self.SSCNewItemDisplay:SetCheck(self.db.profile.config.DisplayNew)
	
	GeminiLocale:TranslateWindow(L, self.wndMain)

	self:FinalizeLoading();
end

function Addon:FinalizeLoading()
	self._tLoadingInfo.GUI.isReady = true;

	if self._tLoadingInfo.WindowManagement.isReady then
        Event_FireGenericEvent("WindowManagementRegister", {strName = MAJOR, nSaveVersion=MINOR})
        Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = MAJOR, nSaveVersion=MINOR})
		self._tLoadingInfo.WindowManagement.isInit = true
	end
 
	if self._tLoadingInfo.SpaceStashInventory.isReady then 
		self:InitSpaceStashInventory()
	end
	
	if self._tLoadingInfo.SpaceStashBank.isReady then 
		self:InitSpaceStashBank()
	end

	self._tLoadingInfo.GUI.isInit = true
	Event_FireGenericEvent("AddonFullyLoaded", {addon = self, strName = MAJOR})
end

function Addon:OnWindowManagementReady()
	self._tLoadingInfo.WindowManagement.isReady = true
	if self._tLoadingInfo.GUI.isReady then
        Event_FireGenericEvent("WindowManagementRegister", {strName = MAJOR, nSaveVersion=MINOR})
        Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = MAJOR, nSaveVersion=MINOR})
		self._tLoadingInfo.WindowManagement.isInit = true
	end
 
end

function Addon:OnAddonFullyLoaded(args)
	if args.strName == "Rover" then
		Event_FireGenericEvent("SendVarToRover", MAJOR, self)
 	elseif args.strName == "SpaceStashInventory" then
		self._tLoadingInfo.SpaceStashInventory.isReady = true
		self:InitSpaceStashInventory()
 	elseif args.strName == "SpaceStashBank" then
 		self._tLoadingInfo.SpaceStashBank.isReady = true
		self:InitSpaceStashBank()
 	end
end

function Addon:OnConfigure()
	Event_FireGenericEvent("SpaceStashCore_OpenOptions", self)
end

function Addon:InitSpaceStashBank()
	if not self._tLoadingInfo.GUI.isReady then return end

	if self.SSBOptionsFrame == nil then
		Apollo.AddAddonErrorText(self, "Could not load SSBOptionsFrame	 for some reason.")
		return
	end

	self:SetBankSortMehtod(self.db.profile.config.auto.bank.sort)
	self:UpdateBankRowsSize()
	self:UpdateBankIconsSize()

	self._tLoadingInfo.SpaceStashBank.isInit = true
end

function Addon:InitSpaceStashInventory()
	if not self._tLoadingInfo.GUI.isReady then return end

	if self.SSIOptionsFrame == nil then
		Apollo.AddAddonErrorText(self, "Could not load SSIOptionsFrame for some reason.")
		return
	end

	self:SetInventorySortMehtod(self.db.profile.config.auto.inventory.sort)
	SpaceStashInventory:SetDisplayNew(self.db.profile.config.DisplayNew)
	self:UpdateTrackedCurrency()
	self:UpdateInventoryIconsSize()
	self:UpdateInventoryRowsSize()

	self.SSICashButton:SetCheck(SpaceStashInventory:GetTrackedCurrency(1))
	self.SSIRenownButton:SetCheck(SpaceStashInventory:GetTrackedCurrency(2))
	self.SSIElderGemsButton:SetCheck(SpaceStashInventory:GetTrackedCurrency(3))
	self.SSIGloryButton:SetCheck(SpaceStashInventory:GetTrackedCurrency(3))
	self.SSIPrestigeButton:SetCheck(SpaceStashInventory:GetTrackedCurrency(5))
	self.SSICraftingVouchersButton:SetCheck(SpaceStashInventory:GetTrackedCurrency(6))
	self.SSIOmnibitsButtonButton:SetCheck(SpaceStashInventory:GetTrackedCurrency(7))
	self.SSIServiceTokensButton:SetCheck(SpaceStashInventory:GetTrackedCurrency(8))
	self.SSIFortuneCoinsButton:SetCheck(SpaceStashInventory:GetTrackedCurrency(9))

	self._tLoadingInfo.SpaceStashInventory.isInit = true
end	

function Addon:OnSlashCommand(strCommand, strParam)
	if strParam == "" then 

	self.wndMain:Show(true,true)
	elseif strParam == "info" then 
		glog:info(self)
	elseif strParam == "reset" then
		self.db:ResetProfile()
	end
end

function Addon:OnOpenOptions( oHandler )
	self.wndMain:Show(true,true)

	self.btnSSCOptions:SetCheck(true)
	self:SpaceStashCoreButtonCheck()

	self.btnSSIOptions:SetCheck(false)
	self.btnSSBOptions:SetCheck(false)
	Addon:SpaceStashInventoryButtonUncheck()
	Addon:SpaceStashBankButtonUncheck()
end

function Addon:OnClose( ... )

  self.wndMain:Show(false,true)
end


function Addon:OnModuleButton(strType,strName)
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

function Addon:SpaceStashCoreButtonCheck()
	self.SSCOptionsFrame:Show(true)
	self.wndTarget:SetVScrollPos(0)
	self.wndTarget:Reposition()
end

function Addon:SpaceStashCoreButtonUncheck()
	self.SSCOptionsFrame:Show(false)
end

function Addon:SpaceStashInventoryButtonCheck()
	self.SSIOptionsFrame:Show(true)
	self.wndTarget:SetVScrollPos(0)
	self.wndTarget:Reposition()
end

function Addon:SpaceStashInventoryButtonUncheck()
	self.SSIOptionsFrame:Show(false)
end
  
function Addon:SpaceStashBankButtonCheck()
	self.SSBOptionsFrame:Show(true)
	self.wndTarget:SetVScrollPos(0)
	self.wndTarget:Reposition()
end


function Addon:SpaceStashBankButtonUncheck()
	self.SSBOptionsFrame:Show(false)
end

function Addon:OnCurrencySelectionChange(wndHandler, wndControl, eMouseButton)
    if not self._tLoadingInfo.SpaceStashInventory.isInit then return end
	if wndHandler == self.SSICashButton then
		SpaceStashInventory:SetTrackedCurrency(1, self.SSICashButton:IsChecked())
	elseif wndHandler == self.SSIRenownButton then
		SpaceStashInventory:SetTrackedCurrency(2, self.SSIRenownButton:IsChecked())
	elseif wndHandler == self.SSIElderGemsButton then
		SpaceStashInventory:SetTrackedCurrency(3, self.SSIElderGemsButton:IsChecked())
	elseif wndHandler == self.SSIGloryButton then
		SpaceStashInventory:SetTrackedCurrency(4, self.SSIGloryButton:IsChecked())
	elseif wndHandler == self.SSIPrestigeButton then
		SpaceStashInventory:SetTrackedCurrency(5, self.SSIPrestigeButton:IsChecked())
	elseif wndHandler == self.SSICraftingVouchersButton then
		SpaceStashInventory:SetTrackedCurrency(6, self.SSICraftingVouchersButton:IsChecked())
	elseif wndHandler == self.SSIOmnibitsButtonButton then
		SpaceStashInventory:SetTrackedCurrency(7, self.SSIOmnibitsButtonButton:IsChecked())
	elseif wndHandler == self.SSIServiceTokensButton then
		SpaceStashInventory:SetTrackedCurrency(8, self.SSIServiceTokensButton:IsChecked())
	elseif wndHandler == self.SSIFortuneCoinsButton then
		SpaceStashInventory:SetTrackedCurrency(9, self.SSIFortuneCoinsButton:IsChecked())
	end
end

function Addon:UpdateTrackedCurrency()
    if not self._tLoadingInfo.SpaceStashInventory.isInit then return end
	local tracked = SpaceStashInventory:GetTrackedCurrency()
	self.SSICashButton:SetCheck(tracked[1])
	self.SSIRenownButton:SetCheck(tracked[2])
	self.SSIElderGemsButton:SetCheck(tracked[3])
	self.SSIGloryButton:SetCheck(tracked[4])
	self.SSIPrestigeButton:SetCheck(tracked[5])
	self.SSICraftingVouchersButton:SetCheck(tracked[6])
	self.SSIOmnibitsButtonButton:SetCheck(tracked[7])
	self.SSIServiceTokensButton:SetCheck(tracked[8])
	self.SSIFortuneCoinsButton:SetCheck(tracked[9])
end
	
function Addon:OnInventoryIconsSizeChanged( wndHandler, wndControl, fNewValue, fOldValue )
    if not self._tLoadingInfo.SpaceStashInventory.isInit then return end
    SpaceStashInventory:SetIconsSize(fNewValue)
    self.SSIIconsSizeText:SetText(fNewValue)
end 

function Addon:UpdateInventoryIconsSize()
    if not self._tLoadingInfo.SpaceStashInventory.isInit then return end
    self.SSIIconsSizeSlider:SetValue(SpaceStashInventory:GetIconsSize())
    self.SSIIconsSizeText:SetText(SpaceStashInventory:GetIconsSize())
end

function Addon:OnInventoryRowsSizeChanged( wndHandler, wndControl, fNewValue, fOldValue )
    if not self._tLoadingInfo.SpaceStashInventory.isInit then return end
    SpaceStashInventory:SetRowsSize(fNewValue)
    self.SSIRowsSizeText:SetText(fNewValue)
end 

function Addon:UpdateInventoryRowsSize()
    if not self._tLoadingInfo.SpaceStashInventory.isInit then return end
    self.SSIRowsSizeSlider:SetValue(SpaceStashInventory:GetRowsSize())
    self.SSIRowsSizeText:SetText(SpaceStashInventory:GetRowsSize())
end

function Addon:OnBankIconsSizeChanged( wndHandler, wndControl, fNewValue, fOldValue )
    if not self._tLoadingInfo.SpaceStashBank.isInit then return end
    SpaceStashBank:SetIconsSize(fNewValue)
    self.SSBIconsSizeText:SetText(fNewValue)
end 

function Addon:UpdateBankIconsSize()
    if not self._tLoadingInfo.SpaceStashBank.isInit then return end
    self.SSBIconsSizeSlider:SetValue(SpaceStashBank:GetIconsSize())
    self.SSBIconsSizeText:SetText(SpaceStashBank:GetIconsSize())
end

function Addon:OnBankRowsSizeChanged( wndHandler, wndControl, fNewValue, fOldValue )
    if not self._tLoadingInfo.SpaceStashBank.isInit then return end
    SpaceStashBank:SetRowsSize(fNewValue)
    self.SSBRowsSizeText:SetText(fNewValue)
end 

-------------------------------------------------------------------------------------
--- SSC Options
--------------------------------------------------------------------------------------

function Addon:UpdateBankRowsSize()
  self.SSBRowsSizeSlider:SetValue(SpaceStashBank:GetRowsSize())
  self.SSBRowsSizeText:SetText(SpaceStashBank:GetRowsSize())
end
	
function Addon:OnInventoyAtVendorChanged( wndHandler, wndControl )
  self.db.profile.config.auto.inventory.vendor = self.SSCAutoVendor:IsChecked()
end

function Addon:OnInventoyAtBankChanged( wndHandler, wndControl )
  self.db.profile.config.auto.inventory.bank = self.SSCAutoBank:IsChecked()
end

function Addon:OnInventoyAtAHChanged( wndHandler, wndControl )
  self.db.profile.config.auto.inventory.auctionhouse = self.SSCAutoAH:IsChecked()
end

function Addon:OnInventoyAtCEChanged( wndHandler, wndControl )
  self.db.profile.config.auto.inventory.commoditiesexchange = self.SSCAutoCE:IsChecked()
end

function Addon:OnInventoyAtMailboxChanged( wndHandler, wndControl )
  self.db.profile.config.auto.inventory.mailbox = self.SSCAutoMailbox:IsChecked()
end

function Addon:OnInventoyAtESChanged( wndHandler, wndControl )
  self.db.profile.config.auto.inventory.engravingstation = self.SSCAutoES:IsChecked()
end

function Addon:OnInventoyAtCraftingStationChanged( wndHandler, wndControl )
  self.db.profile.config.auto.inventory.craftingstation = self.SSCAutoCS:IsChecked()
end

function Addon:OnAutoRepairChange( wndHandler, wndControl )
  self.db.profile.config.auto.repair = self.SSCAutoRepair:IsChecked()
end

function Addon:OnAutoSellChange( wndHandler, wndControl )
  self.db.profile.config.auto.sell.active = self.SSCAutoSell:IsChecked()
end

function Addon:OnSellSalvagableChange( wndHandler, wndControl )
  self.db.profile.config.auto.sell.filters.Salvagables.active = self.SSCSellSavagable:IsChecked()
end

function Addon:OnSellConsumablesChange( wndHandler, wndControl )
	self.db.profile.config.auto.sell.filters.Consumables.active = self.SSCSellConsumables:IsChecked()
end

function Addon:OnSellCostumesChange( wndHandler, wndControl )
	self.db.profile.config.auto.sell.filters.Costumes.active = self.SSCSellCostumes:IsChecked()
end

function Addon:OnSellAMPChange( wndHandler, wndControl )
	self.db.profile.config.auto.sell.filters.AMP.active = self.SSCSellAMP:IsChecked()
end

function Addon:OnSellHousingChange( wndHandler, wndControl )
	self.db.profile.config.auto.sell.filters.Housing.active = self.SSCSellHousing:IsChecked()
end

function Addon:OnSellCraftingChange( wndHandler, wndControl )
	self.db.profile.config.auto.sell.filters.Crafting.active = self.SSCSellCrafting:IsChecked()
end

function Addon:OnSellSchematicsChange( wndHandler, wndControl )
	self.db.profile.config.auto.sell.filters.Schematics.active = self.SSCSellSchematics:IsChecked()
end

function Addon:OnInventorySortToggle( wndHandler, wndControl )
  self.SSISortChooserButton:FindChild("ChoiceContainer"):Show(self.SSISortChooserButton:IsChecked(),true)
end

function Addon:OnInventorySortChooserContainerClose()
  self.SSISortChooserButton:SetCheck(false)
end

function Addon:OnBankSortToggle( wndHandler, wndControl )
  self.SSBSortChooserButton:FindChild("ChoiceContainer"):Show(self.SSBSortChooserButton:IsChecked(),true)
end

function Addon:OnBankSortChooserContainerClose()
  self.SSBSortChooserButton:SetCheck(false)
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

function Addon:OnInventorySortSelected(wndHandler, wndControl)
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
	self:SetInventorySortMehtod(self.db.profile.config.auto.inventory.sort)
  end
end

function Addon:SetInventorySortMehtod(nSortMethod)
  self.db.profile.config.auto.inventory.sort = nSortMethod

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


function Addon:OnBankSortSelected(wndHandler, wndControl)
  if wndHandler == wndControl then
	if wndHandler:GetName() == "Choice1" then
	  self.db.profile.config.auto.bank.sort = 0
	elseif wndHandler:GetName() == "Choice2" then
	  self.db.profile.config.auto.bank.sort = 1
	elseif wndHandler:GetName() == "Choice3" then
	  self.db.profile.config.auto.bank.sort = 2
	elseif wndHandler:GetName() == "Choice4" then
	  self.db.profile.config.auto.bank.sort = 3
	end
	
	self.SSBSortChooserButton:SetText(wndHandler:GetText())
	self.SSBSortChooserButton:FindChild("ChoiceContainer"):Show(false,true)
  end

  self:OnBankSortChooserContainerClose()

  if SpaceStashBank then
	self:SetBankSortMehtod(self.db.profile.config.auto.bank.sort)
  end
end


function Addon:SetBankSortMehtod(nSortMethod)
  self.db.profile.config.auto.bank.sort = nSortMethod

  if nSortMethod == 1 then
	SpaceStashBank:SetSortMehtod(fnSortItemsByName)
  elseif nSortMethod == 2 then
	SpaceStashBank:SetSortMehtod(fnSortItemsByQuality)
  elseif nSortMethod == 3 then
	SpaceStashBank:SetSortMehtod(fnSortItemsByCategory)
  elseif nSortMethod == 0 then 
	SpaceStashBank:SetSortMehtod()
  end
  
end

function Addon:OnDisplayNewItemsChanged()
  self.db.profile.config.DisplayNew = self.SSCNewItemDisplay:IsChecked()
  SpaceStashInventory:SetDisplayNew(self.db.profile.config.DisplayNew)
end

function Addon:OnSellQualityChooserToggle( wndHandler, wndControl )
  self.SSCSellQualityChooserButton:FindChild("ChoiceContainer"):Show(self.SSCSellQualityChooserButton:IsChecked(),true)
end

function Addon:OnSellQualityChooserContainerClose()
  self.SSCSellQualityChooserButton:SetCheck(false)
end

function Addon:OnAutoSellQualitySelected(wndHandler, wndControl)
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
function Addon:OnShowVendor() 
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

function Addon:SellItems()
  for _, item in ipairs(GameLib.GetPlayerUnit():GetInventoryItems()) do
	if self.stringInArray(item.itemInBag:GetName(),self.db.profile.config.auto.sell.whitelist) and item.itemInBag:GetSellPrice() then
	  SellItemToVendorById(item.itemInBag:GetInventoryId(), item.itemInBag:GetStackCount())
	elseif (not self.stringInArray(item.itemInBag:GetName(),self.db.profile.config.auto.sell.blacklist)) and item.itemInBag:GetItemQuality() <= self.db.profile.config.auto.sell.QualityTreshold and self:FilterItem(item.itemInBag) and item.itemInBag:GetSellPrice() then
		SellItemToVendorById(item.itemInBag:GetInventoryId(), item.itemInBag:GetStackCount())
	end
  end
end

function Addon.stringInArray(str,array)
	for k,v in ipairs(array) do
		if str == v then return true end
	end
end

function Addon:OnSellWhitelistChange()
	local lines = {}
	local str = self.SellWhitelist:GetText()
	self.db.profile.config.auto.sell.whitelistRaw = self.SellWhitelist:GetText()
	local function helper(line) table.insert(lines, line) end
	helper((str:gsub("(.-)\r?\n", helper)))

	self.db.profile.config.auto.sell.whitelist = lines
end

function Addon:OnSellBlacklistChange()
	local lines = {}
	local str = self.SellBlacklist:GetText()
	self.db.profile.config.auto.sell.blacklistRaw = self.SellBlacklist:GetText()
	local function helper(line) table.insert(lines, line) end
	helper((str:gsub("(.-)\r?\n", helper)))

	self.db.profile.config.auto.sell.blacklist = lines
end

function Addon:FilterItem(item)
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

function Addon.FilterItemFamily(item)

end


------------------------------------------------------------------------

function Addon:OnShowBank() 
  if not self.db.profile.config.auto.inventory.bank then return end

  SpaceStashInventory:OpenInventory()
end

function Addon:OnShowAuctionHouse( wndHandler, wndControl )
  if not self.db.profile.config.auto.inventory.auctionhouse then return end

  SpaceStashInventory:OpenInventory()
end

function Addon:OnShowCommoditiesExchange( wndHandler, wndControl )
  if not self.db.profile.config.auto.inventory.commoditiesexchange then return end

  SpaceStashInventory:OpenInventory()
end

function Addon:OnShowMailbox( wndHandler, wndControl )
  if not self.db.profile.config.auto.inventory.mailbox then return end

  SpaceStashInventory:OpenInventory()
end

function Addon:OnShowEngravingStation()
  if not self.db.profile.config.auto.inventory.engravingstation then return end

  SpaceStashInventory:OpenInventory()
end

function Addon:OnShowCraftingStation()
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

