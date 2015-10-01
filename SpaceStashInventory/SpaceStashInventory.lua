-----------------------------------------------------------------------------------------------
-- Client Lua Script for SpaceStashInventory
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Apollo"
require "GameLib"
require "Item"
require "Window"
require "Money"
require "Sound"

-----------------------------------------------------------------------------------------------
-- Constants and Defaults parameters
-----------------------------------------------------------------------------------------------
local MAJOR, MINOR = "SpaceStashInventory", 22

-----------------------------------------------------------------------------------------------
-- Libraries
-----------------------------------------------------------------------------------------------
local GeminiLocale = Apollo.GetPackage("Gemini:Locale-1.0").tPackage
local GeminiHook = Apollo.GetPackage("Gemini:Hook-1.0").tPackage
local Addon, glog = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon(MAJOR, false, {}, "Gemini:Hook-1.0")
local L = GeminiLocale:GetLocale(MAJOR, true)

local tItemSlotBGPixie = {loc = {fPoints = {0,0,1,10},nOffsets = {0,0,0,0},},strSprite="WhiteFill", cr= "black",fRotation="0"}

Addon.CodeEnumTabDisplay = {
  None = 0,
  BagsTab = 1,
  VirtualItemsTab = 2,
  TradeskillsBagTab = 3
}

local defaults = {}
defaults.profile = {}
defaults.profile.config = {}
defaults.profile.version = {}
defaults.profile.version.MAJOR = MAJOR
defaults.profile.version.MINOR = MINOR
defaults.profile.config.IconSize = 36
defaults.profile.config.RowSize = 10
defaults.profile.config.CurrenciesMicroMenu = { anchors = {0, -271, 200, 0} }
defaults.profile.config.SplitWindow = { anchors = {0, 75, 164, 125} }
function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

defaults.profile.config.currencies = {
	[1] = true,
	[2] = false,
	[3] = false,
	[4] = false,
	[5] = false,
	[6] = false,
	[7] = false,
	[8] = false,
	[9] = false
}
defaults.profile.config.SelectedTab = Addon.CodeEnumTabDisplay.BagsTab
defaults.profile.config.DisplayNew = false

local _tLoadingInfo = {
	WindowManagement = { isReady = false , isInit = false },
	SpaceStashCore = { isReady = false , isInit = false },
	GUI = { isReady = false, isInit = false },
}

local tCurrenciesWindows = {}
local nCurrenciesWindowsSize = 0
local currencies = {
    [1] = {eType = Money.CodeEnumCurrencyType.Credits                   , name = Apollo.GetString("CRB_Cash")                         , desc = "moneymoney"},
    [2] = {eType = Money.CodeEnumCurrencyType.Renown                    , name = Apollo.GetString("CRB_Renown")                       , desc = Apollo.GetString("CRB_Renown_desc")},
    [3] = {eType = Money.CodeEnumCurrencyType.ElderGems                 , name = Apollo.GetString("CRB_Elder_Gems")                   , desc = Apollo.GetString("CRB_Elder_Gems_desc")},
    [4] = {eType = Money.CodeEnumCurrencyType.Glory                     , name = Apollo.GetString("CRB_Glory")                        , desc = Apollo.GetString("CRB_Glory_desc")},
    [5] = {eType = Money.CodeEnumCurrencyType.Prestige                  , name = Apollo.GetString("CRB_Prestige")                     , desc = Apollo.GetString("CRB_Prestige_desc")},
    [6] = {eType = Money.CodeEnumCurrencyType.CraftingVouchers          , name = Apollo.GetString("CRB_Crafting_Vouchers")            , desc = Apollo.GetString("CRB_Crafting_Vouchers_desc")},
    [7] = {eType = AccountItemLib.CodeEnumAccountCurrency.Omnibits      , name = Apollo.GetString("CRB_OmniBits")                     , desc = Apollo.GetString("CRB_OmniBits_desc"), account = true, capped = true},
    [8] = {eType = AccountItemLib.CodeEnumAccountCurrency.ServiceToken  , name = Apollo.GetString("AccountInventory_ServiceToken")    , desc = Apollo.GetString("AccountInventory_ServiceToken_desc"), account = true},
    [9] = {eType = AccountItemLib.CodeEnumAccountCurrency.MysticShiny   , name = Apollo.GetString("CRB_FortuneCoin")                  , desc = Apollo.GetString("CRB_FortuneCoin_desc"), account = true},
}

-----------------------------------------------------------------------------------------------
-- SSI Base GeminiAddon behaviors
-----------------------------------------------------------------------------------------------
function Addon:OnInitialize()
	self.db = Apollo.GetPackage("Gemini:DB-1.0").tPackage:New(self, defaults, true)
 
	self._tLoadingInfo = _tLoadingInfo

	glog = Apollo.GetPackage("Gemini:Logging-1.2").tPackage:GetLogger({
		level = "INFO",
		pattern = "%d [%c:%n] %l - %m",
		appender = "print"
	})
	
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("WindowManagementReady", "OnWindowManagementReady", self)
	Apollo.RegisterEventHandler("WindowManagementAdd", "OnAddonFullyLoaded", self) --rover
	Apollo.RegisterEventHandler("AddonFullyLoaded","OnAddonFullyLoaded", self) -- spacestash
	Apollo.RegisterEventHandler("InterfaceMenu_ToggleInventory", "OnVisibilityToggle", self)
	Apollo.RegisterSlashCommand("ssi", "OnSlashCommand", self)

end

function Addon:OnEnable()
 	self._tLoadingInfo.SpaceStashCore.instance = Apollo.GetAddon("SpaceStashCore")

	self.xmlDoc = XmlDoc.CreateFromFile("SpaceStashInventory.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
	self:RawHook(Apollo.GetAddon("Inventory"),"OnGenerateTooltip")

	for i = 1, #currencies do
    	if currencies[i].account then 
    		currencies[i].currencyObject = AccountItemLib.GetAccountCurrency(currencies[i].eType)
    	else
    		currencies[i].currencyObject = GameLib.GetPlayerCurrency(currencies[i].eType)
    	end
    end

    self:RawHook(Apollo.GetAddon("Inventory"),"OnToggleVisibility")
    self:RawHook(Apollo.GetAddon("Inventory"),"OnSupplySatchelOpen")
    self:RawHook(Apollo.GetAddon("Inventory"),"OnSupplySatchelClosed")
    self:RawHook(Apollo.GetAddon("Inventory"),"OnToggleVisibilityAlways")
    self:RawHook(Apollo.GetAddon("Inventory"),"OnGenericEvent_SplitItemStack")
end


--Hooked function
function Addon:OnToggleVisibility()
	return
end
function Addon:OnSupplySatchelOpen()
	return
end
function Addon:OnSupplySatchelClosed()
	return
end
function Addon:OnToggleVisibilityAlways()
	return
end
function Addon:OnGenericEvent_SplitItemStack()
	return
end

function Addon:OnDocumentReady()
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "SpaceStashInventoryForm", nil, self)
	self.wndDeleteConfirm = Apollo.LoadForm(self.xmlDoc, "InventoryDeleteNotice", nil, self)
	self.wndSalvageConfirm = Apollo.LoadForm(self.xmlDoc, "InventorySalvageNotice", nil, self)

	if self.wndMain == nil or self.wndDeleteConfirm == nil or self.wndSalvageConfirm == nil 	then
		Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
		return
	end

	self.wndMain:Show(false, true)
	self.wndDeleteConfirm:Show(false,true)

	self.wndContentFrame = self.wndMain:FindChild("ContentFrame")
	self.wndTopFrame = self.wndMain:FindChild("TopFrame")
	self.wndMenuFrame = self.wndTopFrame:FindChild("MenuFrame")
	self.btnShowBagsTab = self.wndMenuFrame:FindChild("ShowBagsTabButton")
	self.btnShowBagsTab:SetTooltip(L["SHOWBAGSBUTTON"]);
	self.wndBagsTabFrame = self.wndTopFrame:FindChild("BagsTabFrame")
	self.wndBagsTabFrame:Show(false)
	self.ItemWidget1 = self.wndBagsTabFrame:FindChild("ItemWidget1")
	self.BagArtWindow1 = self.ItemWidget1:FindChild("BagArtWindow1")
	self.ItemWidget2 = self.wndBagsTabFrame:FindChild("ItemWidget2")
	self.BagArtWindow2 = self.ItemWidget2:FindChild("BagArtWindow2")
	self.ItemWidget3 = self.wndBagsTabFrame:FindChild("ItemWidget3")
	self.BagArtWindow3 = self.ItemWidget3:FindChild("BagArtWindow3")
	self.ItemWidget4 = self.wndBagsTabFrame:FindChild("ItemWidget4")
	self.BagArtWindow4 = self.ItemWidget4:FindChild("BagArtWindow4")
	self.wndVirtualItemsTabFrame = self.wndTopFrame:FindChild("VirtualItemsTabFrame")
	self.wndVirtualItemsTabFrame:Show(false)
	self.wndTradeskillsBagTabFrame = self.wndTopFrame:FindChild("TradeskillsBagTabFrame")
	self.wndTradeskillsBagTabFrame:Show(false)

	self.wndInventoryFrame = self.wndMain:FindChild("InventoryFrame")
	self.wndBagWindow = self.wndInventoryFrame:FindChild("BagWindow")


	self.wndBottomFrame = self.wndMain:FindChild("BottomFrame")
	self.wndCurrencies = self.wndBottomFrame:FindChild("CurrenciesFrame")
	self.wndCash = self.wndCurrencies:FindChild("CashWindow")
	self.CurrenciesContainer = self.wndCurrencies:FindChild("CurrenciesContainer")
	self.CurrencyMenuButton = self.wndBottomFrame:FindChild("CurrencyMenuButton")

	self.wndCurrenciesMicroMenu = self.wndMain:FindChild("SSICurenciesMicroMenu")
	self.wndCurrenciesMicroMenu:Show(false,true)
	self.SSICashButton 					= self.wndCurrenciesMicroMenu:FindChild("SSICashButton")
	self.SSIRenownButton 				= self.wndCurrenciesMicroMenu:FindChild("SSIRenownButton")
	self.SSIElderGemsButton 			= self.wndCurrenciesMicroMenu:FindChild("SSIElderGemsButton")
	self.SSIGloryButton 				= self.wndCurrenciesMicroMenu:FindChild("SSIGloryButton")
	self.SSIPrestigeButton 				= self.wndCurrenciesMicroMenu:FindChild("SSIPrestigeButton")
	self.SSICraftingVouchersButton 		= self.wndCurrenciesMicroMenu:FindChild("SSICraftingVouchersButton")
	self.SSIOmnibitsButton 				= self.wndCurrenciesMicroMenu:FindChild("SSIOmnibitsButton")
	self.SSIServicetokenButton 			= self.wndCurrenciesMicroMenu:FindChild("SSIServicetokenButton")
	self.SSIFortunecoinButton 			= self.wndCurrenciesMicroMenu:FindChild("SSIFortunecoinButton")

	self.btnSalvage = self.wndBottomFrame:FindChild("SpaceStashInventorySalvageButton")
	self.btnSalvage:SetTooltip(L["SALVAGEALLBUTTON"])
	self.btnTradskillsBag = self.wndBottomFrame:FindChild("TradeskillsBagButton")
	self.btnTradskillsBag:SetTooltip(L["TRADSKILLINVENTORY"])

	self.buttonPlayerButton = self.wndMain:FindChild("PlayerButton")
	self.wndPlayerMenuFrame = self.wndMain:FindChild("PlayerMenuFrame")

	self.wndSplitWindow = self.wndMain:FindChild("SplitStackContainer")

	self:SetSortMehtod(self.db.profile.config.sort)


	--TODO: refactor following if block
	if self.db.profile.config.SelectedTab == Addon.CodeEnumTabDisplay.BagsTab then
		self.wndTopFrame:FindChild("ShowBagsTabButton"):SetCheck(true)
		self.wndBagsTabFrame:Show(true)
		self.wndTopFrame:FindChild("ShowVirtualItemsTabButton"):SetCheck(false)
		self.wndVirtualItemsTabFrame:Show(false)
		self.wndTopFrame:FindChild("ShowTradeskillsBagTabButton"):SetCheck(false)
		self.wndTradeskillsBagTabFrame:Show(false)
	elseif self.db.profile.config.SelectedTab == Addon.CodeEnumTabDisplay.VirtualItemsTab then
		self.wndTopFrame:FindChild("ShowBagsTabButton"):SetCheck(false)
		self.wndBagsTabFrame:Show(false)
		self.wndTopFrame:FindChild("ShowVirtualItemsTabButton"):SetCheck(true)
		self.wndVirtualItemsTabFrame:Show(true)
		self.wndTopFrame:FindChild("ShowTradeskillsBagTabButton"):SetCheck(false)
		self.wndTradeskillsBagTabFrame:Show(false)
	elseif self.db.profile.config.SelectedTab == Addon.CodeEnumTabDisplay.TradeskillsBagTab then
		self.wndTopFrame:FindChild("ShowBagsTabButton"):SetCheck(false)
		self.wndBagsTabFrame:Show(false)
		self.wndTopFrame:FindChild("ShowVirtualItemsTabButton"):SetCheck(false)
		self.wndVirtualItemsTabFrame:Show(false)
		self.wndTopFrame:FindChild("ShowTradeskillsBagTabButton"):SetCheck(true)
		self.wndTradeskillsBagTabFrame:Show(true)
	else
		self.wndTopFrame:FindChild("ShowBagsTabButton"):SetCheck(false)
		self.wndBagsTabFrame:Show(false)
		self.wndTopFrame:FindChild("ShowVirtualItemsTabButton"):SetCheck(false)
		self.wndVirtualItemsTabFrame:Show(false)
		self.wndTopFrame:FindChild("ShowTradeskillsBagTabButton"):SetCheck(false)
		self.wndTradeskillsBagTabFrame:Show(false)
	end

	self:UpdateTrackedCurrencies()
	self:UpdateCurrenciesMicroMenu()
	self:Redraw()
	GeminiLocale:TranslateWindow(L, self.wndMain)

	Apollo.RegisterEventHandler("ToggleInventory", "OnVisibilityToggle", self)
	Apollo.RegisterEventHandler("ShowInventory", "OnVisibilityToggle", self)

	
	Apollo.RegisterEventHandler("PlayerCurrencyChanged", "OnPlayerCurrencyChanged", self)
	Apollo.RegisterEventHandler("AccountCurrencyChanged", "OnPlayerCurrencyChanged", self)
	Apollo.RegisterEventHandler("PlayerEquippedItemChanged", "Redraw", self)

	Apollo.RegisterEventHandler("GuildBank_ShowPersonalInventory", "OnVisibilityToggle", self)
	
	Apollo.RegisterEventHandler("LootedItem","OnItemLoot", self)
	Apollo.RegisterEventHandler("ItemAdded","OnItemLoot", self)
	Apollo.RegisterEventHandler("CombatLogLoot","OnItemLoot", self)
	Apollo.RegisterEventHandler("GenericEvent_LootChannelMessage","OnItemLoot", self)

	Apollo.RegisterEventHandler("DragDropSysBegin", "OnSystemBeginDragDrop", self)
	Apollo.RegisterEventHandler("DragDropSysEnd", "OnSystemEndDragDrop", self)
	Apollo.RegisterEventHandler("SplitItemStack", "OnSplitItemStack", self)

	--virtual inventory related
	-- Apollo.RegisterEventHandler("PlayerPathMissionUpdate", "OnQuestObjectiveUpdated", self)
	-- Apollo.RegisterEventHandler("QuestObjectiveUpdated", "OnQuestObjectiveUpdated", self)
	-- Apollo.RegisterEventHandler("PlayerPathRefresh", "OnQuestObjectiveUpdated", self)
	-- Apollo.RegisterEventHandler("QuestStateChanged", "OnQuestObjectiveUpdated", self)
	-- Apollo.RegisterEventHandler("ChallengeUpdated", "OnChallengeUpdated", self)

	self.wndCurrenciesMicroMenu:SetAnchorOffsets(self.db.profile.config.CurrenciesMicroMenu.anchors[1],
		self.db.profile.config.CurrenciesMicroMenu.anchors[2],
		self.db.profile.config.CurrenciesMicroMenu.anchors[3],
		self.db.profile.config.CurrenciesMicroMenu.anchors[4])

	self.wndSplitWindow:SetAnchorOffsets(self.db.profile.config.SplitWindow.anchors[1],
		self.db.profile.config.SplitWindow.anchors[2],
		self.db.profile.config.SplitWindow.anchors[3],
		self.db.profile.config.SplitWindow.anchors[4])



	self:FinalizeLoading();
end

function Addon:FinalizeLoading()
	self._tLoadingInfo.GUI.isReady = true;
	if self._tLoadingInfo.WindowManagement.isReady and not self._tLoadingInfo.WindowManagement.isInit then
		Event_FireGenericEvent("WindowManagementRegister", {strName = MAJOR, nSaveVersion=MINOR})
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = MAJOR, nSaveVersion=MINOR})
		self._tLoadingInfo.WindowManagement.isInit = true
	end
 
	if self._tLoadingInfo.SpaceStashCore.isReady and not self._tLoadingInfo.SpaceStashCore.isInit then 
		self:InitSpaceStashCore()
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

function Addon:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_Inventory"), {"InterfaceMenu_ToggleInventory", "Inventory", "Icon_Windows32_UI_CRB_InterfaceMenu_Inventory"})
end

function Addon:OnAddonFullyLoaded(args)
	if args.strName == "SpaceStashCore" then
		self._tLoadingInfo.SpaceStashCore.isReady = true
		self:InitSpaceStashCore()
	end
end

function Addon:InitSpaceStashCore()
	if not self._tLoadingInfo.GUI.isReady then return end
	-- TODO: a way to defer SSI fully loaded to SSC (for senor plow modification).
 
	self._tLoadingInfo.SpaceStashCore.isInit = true
	Event_FireGenericEvent("SendVarToRover", MAJOR, self)
end

---------------------------------------------------------------------------------------------------
-- SSI Commands
---------------------------------------------------------------------------------------------------

-- on /ssi console command
function Addon:OnSlashCommand(strCommand, strParam)
	if strParam == "" then
		self:OnVisibilityToggle()
	elseif strParam == "info" then
		glog:info(self)
	elseif strParam == "redraw" then
		self:Redraw()
	elseif strParam == "reset" then
		self:ResetConfig()
	end
end

---------------------------------------------------------------------------------------------------
-- SSI Visibility and positionning
---------------------------------------------------------------------------------------------------
function Addon:CloseInventory()
	if not self._tLoadingInfo.GUI.isReady then return end

	--TODO: implement 'standby mode' to use less perf.
	self.wndMain:Show(false,true)
	self.wndBagWindow:MarkAllItemsAsSeen()

	Sound.Play(Sound.PlayUIBagClose) --CUSTOM: chosable sound
end

---
--- This function show the inventory and update relevant 
---
function Addon:OpenInventory()
	if not self._tLoadingInfo.GUI.isReady then return end
	
	--TODO: implement 'standby mode' to use less perf. see @CloseInventory()

	--TODO: Verify that currency things here are useful.
	self:OnInventoryDisplayChange()
	self:UpdateCashAmount()
	self.wndMain:Show(true,true)
	self.wndMain:ToFront()
	Sound.Play(Sound.PlayUIBagOpen) --CUSTOM: chosable sound
end

function Addon:OnVisibilityToggle() --TODO: Check if isReady is enought or if isInit will be required (see @CloseInventory and @OpenInventory too)
	if not self._tLoadingInfo.GUI.isReady then return end

	if self.wndMain:IsShown() then
		self:CloseInventory()
	else
		self:OpenInventory()
	end
end

---------------------------------------------------------------------------------------------------
-- TODO: SSI quest inventory tab
---------------------------------------------------------------------------------------------------
function Addon:OnQuestObjectiveUpdated()
	self:UpdateVirtualItemInventory()
end

function Addon:OnChallengeUpdated()
	self:UpdateVirtualItemInventory()
end

function Addon:OnOptions()
  Event_FireGenericEvent("SpaceStashCore_OpenOptions")
end

-- When the SalvageButton is pressed.
function Addon:OnSalvageButton()
	-- TODO: option to configure how button work
	-- MODDERS : if you have a personal addon for salvaging, just make it to handle "RequestSalvageAll". You will need to disable the current ImprovedSalvage addon packed with SpaceStash.
	Event_FireGenericEvent("RequestSalvageAll")
end

function Addon:OnTradskillStashButton()
	local tAnchors = {}
	tAnchors.nLeft, tAnchors.nTop, tAnchors.nRight, tAnchors.nBottom = self.wndMain:GetAnchorOffsets()
	Event_FireGenericEvent("ToggleTradeskillInventoryFromBag", tAnchors)
end

function Addon:RowSizeChange(nNewValue)
	nNewValue = nNewValue or self.db.profile.config.RowSize
	self.db.profile.config.RowSize = nNewValue
	self.wndMain:FindChild("BagWindow"):SetBoxesPerRow(self.db.profile.config.RowSize)

	self.rowCount = math.floor(self.wndBagWindow:GetBagCapacity() / self.db.profile.config.RowSize)
	if self.wndBagWindow:GetBagCapacity() % self.db.profile.config.RowSize ~= 0 then self.rowCount = self.rowCount +1 end

end

function Addon:IconSizeChange(nNewValue)
	nNewValue = nNewValue or self.db.profile.config.IconSize
	self.db.profile.config.IconSize = nNewValue
	self.wndMain:FindChild("BagWindow"):SetSquareSize(self.db.profile.config.IconSize, self.db.profile.config.IconSize)
	self.wndMain:FindChild("BagWindow"):SetBoxesPerRow(self.db.profile.config.RowSize) --necessary

	self.wndBagsTabFrame:SetAnchorOffsets(1,self.wndMenuFrame:GetHeight(),0,self.wndMenuFrame:GetHeight() + self.db.profile.config.IconSize )
	self.wndTopFrame:SetAnchorOffsets(0,0,0,self.wndMenuFrame:GetHeight() + self.db.profile.config.IconSize )
	self.ItemWidget1:SetAnchorOffsets(0,0,self.db.profile.config.IconSize,self.db.profile.config.IconSize)
	self.ItemWidget2:SetAnchorOffsets(0,0,self.db.profile.config.IconSize,self.db.profile.config.IconSize)
	self.ItemWidget3:SetAnchorOffsets(0,0,self.db.profile.config.IconSize,self.db.profile.config.IconSize)
	self.ItemWidget4:SetAnchorOffsets(0,0,self.db.profile.config.IconSize,self.db.profile.config.IconSize)
	self.wndBagsTabFrame:ArrangeChildrenHorz(0)

	if self.db.profile.config.SelectedTab == Addon.CodeEnumTabDisplay.BagsTab then
		self.topFrameHeight = self.wndMenuFrame:GetHeight() + self.wndBagsTabFrame:GetHeight()
	elseif self.db.profile.config.SelectedTab == Addon.CodeEnumTabDisplay.VirtualItemsTab then
		self.topFrameHeight = self.wndMenuFrame:GetHeight() + self.wndVirtualItemsTabFrame:GetHeight()
	elseif self.db.profile.config.SelectedTab == Addon.CodeEnumTabDisplay.TradeskillsBagTab then
		self.topFrameHeight = self.wndMenuFrame:GetHeight() + self.wndTradeskillsBagTabFrame:GetHeight()
	else
		self.topFrameHeight = self.wndMenuFrame:GetHeight()
	end
	self.wndInventoryFrame:SetAnchorOffsets(0,self.topFrameHeight-1,0,-self.bottomFrameHeight+28)

end

function Addon:OnInventoryDisplayChange()

	self.BagArtWindow1:DestroyAllPixies()
	self.BagArtWindow2:DestroyAllPixies()
	self.BagArtWindow3:DestroyAllPixies()
	self.BagArtWindow4:DestroyAllPixies()

	if self.BagArtWindow1:FindChild("Bag"):GetItem() then
		self.BagArtWindow1:FindChild("Capacity"):SetText(self.BagArtWindow1:FindChild("Bag"):GetItem():GetBagSlots())
		self.BagArtWindow1:AddPixie(tItemSlotBGPixie)
	else
		self.BagArtWindow1:FindChild("Capacity"):SetText()

	end
	if self.BagArtWindow2:FindChild("Bag"):GetItem() then
		self.BagArtWindow2:FindChild("Capacity"):SetText(self.BagArtWindow2:FindChild("Bag"):GetItem():GetBagSlots())
		self.BagArtWindow2:AddPixie(tItemSlotBGPixie)
	else
		self.BagArtWindow2:FindChild("Capacity"):SetText()

	end
	if self.BagArtWindow3:FindChild("Bag"):GetItem() then
		self.BagArtWindow3:FindChild("Capacity"):SetText(self.BagArtWindow3:FindChild("Bag"):GetItem():GetBagSlots())
		self.BagArtWindow3:AddPixie(tItemSlotBGPixie)
	else
		self.BagArtWindow3:FindChild("Capacity"):SetText()
	end
	if self.BagArtWindow4:FindChild("Bag"):GetItem() then
		self.BagArtWindow4:FindChild("Capacity"):SetText(self.BagArtWindow4:FindChild("Bag"):GetItem():GetBagSlots())
		self.BagArtWindow4:AddPixie(tItemSlotBGPixie)
	else
		self.BagArtWindow4:FindChild("Capacity"):SetText()
	end

	local nInventoryFrameHeight = self.rowCount * self.db.profile.config.IconSize
	local nInventoryFrameWidth = self.db.profile.config.IconSize * self.db.profile.config.RowSize
	local x, y = self.wndMain:GetPos()

	self.wndMain:SetAnchorOffsets(
		x,
		y,
		x + nInventoryFrameWidth - self.leftOffset + self.rightOffset,
		y + self.topFrameHeight + self.bottomFrameHeight + nInventoryFrameHeight - self.topOffset + self.bottomOffset + 4)

end



function Addon:OnItemLoot()
	if not self._tLoadingInfo.GUI.isReady then return end

	if not self.db.profile.config.DisplayNew then self.wndBagWindow:MarkAllItemsAsSeen() end
end

-- Update the window sizing an properties (not the 'volatiles' as currencies amounts, new item icon, etc.)
function Addon:Redraw()
	self.leftOffset, self.topOffset, self.rightOffset, self.bottomOffset = self.wndContentFrame:GetAnchorOffsets()
	self.bottomFrameHeight = self.wndBottomFrame:GetHeight()

	self:IconSizeChange()
	self:RowSizeChange()
	self:OnInventoryDisplayChange()

	self:UpdateCashAmount()
end

-- Generate the tooltips. From stock addon
-- TODO: Mark item as viewed
function Addon:OnGenerateTooltip(wndControl, wndHandler, tType, item)
	if wndControl ~= wndHandler then return end
	wndControl:SetTooltipDoc(nil)
	if item ~= nil then
		local itemEquipped = item:GetEquippedItemForItemType()
		Tooltip.GetItemTooltipForm(self, wndControl, item, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
	end
end

function Addon:OnGenerateBagTooltip( wndControl, wndHandler, tType, item )
  if wndControl ~= wndHandler then return end
  wndControl:SetTooltipDoc(nil)
  if item ~= nil then
    Tooltip.GetItemTooltipForm(self, wndControl, item, {bPrimary = true, bSelling = false})
  else
    wndControl:SetTooltip(wndControl:GetName() and (L["EMPTYSLOT"]) or "")
  end
end

function Addon:OnShowBagsTab()
	if self.db.profile.config.SelectedTab == Addon.CodeEnumTabDisplay.BagsTab then
		self:OnTabUnshow()
	else
		self.db.profile.config.SelectedTab = Addon.CodeEnumTabDisplay.BagsTab
		self.wndTopFrame:FindChild("ShowBagsTabButton"):SetCheck(true)
		self.wndBagsTabFrame:Show(true)
		self.wndTopFrame:FindChild("ShowVirtualItemsTabButton"):SetCheck(false)
		self.wndVirtualItemsTabFrame:Show(false)
		self.wndTopFrame:FindChild("ShowTradeskillsBagTabButton"):SetCheck(false)
		self.wndTradeskillsBagTabFrame:Show(false)
		self:Redraw()
	end
end

--[[
function Addon:UpdateVirtualItemInventory()
	local tVirtualItems = Item.GetVirtualItems()
	local bThereAreItems = #tVirtualItems > 0

	local wndVirtalItemsFrame = self.wndMain:FindChild("VirtualItemsTabFrame")
	wndVirtalItemsFrame:SetData(#tVirtualItems)

	if not bThereAreItems then

	elseif wndVirtalItemsFrame:GetData() == 0 then

	end

	-- Draw items
	wndVirtalItemsFrame:DestroyChildren()
	local nOnGoingCount = 0
	for key, tCurrItem in pairs(tVirtualItems) do
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "VirtualItem", wndVirtalItemsFrame, self)
		if tCurrItem.nCount > 1 then
			wndCurr:FindChild("_Count"):SetText(tCurrItem.nCount)
		end
		nOnGoingCount = nOnGoingCount + tCurrItem.nCount
		wndCurr:FindChild("_Item"):SetSprite(tCurrItem.strIcon)
		wndCurr:SetTooltip(string.format("<P Font=\"CRB_InterfaceSmall\">%s</P><P Font=\"CRB_InterfaceSmall\" TextColor=\"aaaaaaaa\">%s</P>", tCurrItem.strName, tCurrItem.strFlavor))
	end
	
	-- Adjust heights
	if not self.nQuestItemContainerHeight then
		local nLeft, nTop, nRight, nBottom = wndVirtalItemsFrame:GetAnchorOffsets()
		self.nQuestItemContainerHeight = nBottom - nTop
	end

	wndVirtalItemsFrame:SetAnchorOffsets(2,38,0,self.nQuestItemContainerHeight)

	self:Redraw()
end

function Addon:OnShowVirtualItemsTab(wndHandler, wndControl, eMouseButton )
	if self.db.profile.config.SelectedTab == Addon.CodeEnumTabDisplay.VirtualItemsTab then
		self:OnTabUnshow()
	else
		self.db.profile.config.SelectedTab = Addon.CodeEnumTabDisplay.VirtualItemsTab
		self.wndTopFrame:FindChild("ShowBagsTabButton"):SetCheck(false)
		self.wndBagsTabFrame:Show(false)
		self.wndTopFrame:FindChild("ShowVirtualItemsTabButton"):SetCheck(true)
		self.wndVirtualItemsTabFrame:Show(true)
		self.wndTopFrame:FindChild("ShowTradeskillsBagTabButton"):SetCheck(false)
		self.wndTradeskillsBagTabFrame:Show(false)
		self:Redraw()
	end
end

function Addon:OnShowTradeskillsBagTab(wndHandler, wndControl, eMouseButton )
	if self.db.profile.config.SelectedTab == Addon.CodeEnumTabDisplay.TradeskillsBagTab then
		self:OnTabUnshow()
	else
		self.db.profile.config.SelectedTab = Addon.CodeEnumTabDisplay.TradeskillsBagTab
		self.wndTopFrame:FindChild("ShowBagsTabButton"):SetCheck(false)
		self.wndBagsTabFrame:Show(false)
		self.wndTopFrame:FindChild("ShowVirtualItemsTabButton"):SetCheck(false)
		self.wndVirtualItemsTabFrame:Show(false)
		self.wndTopFrame:FindChild("ShowTradeskillsBagTabButton"):SetCheck(true)
		self.wndTradeskillsBagTabFrame:Show(true)
		self:Redraw()
	end
end]]

function Addon:OnTabUnshow(wndHandler, wndControl, eMouseButton )

	self.db.profile.config.SelectedTab = Addon.CodeEnumTabDisplay.None

	self.wndTopFrame:FindChild("ShowBagsTabButton"):SetCheck(false)
	self.wndBagsTabFrame:Show(false)
	self.wndTopFrame:FindChild("ShowVirtualItemsTabButton"):SetCheck(false)
	self.wndVirtualItemsTabFrame:Show(false)
	self.wndTopFrame:FindChild("ShowTradeskillsBagTabButton"):SetCheck(false)
	self.wndTradeskillsBagTabFrame:Show(false)

	self:Redraw()
end

function Addon:OnPlayerButtonCheck( wndHandler, wndControl, eMouseButton )
	self.wndPlayerMenuFrame:Show(true)
end

function Addon:OnPlayerButtonUncheck( wndHandler, wndControl, eMouseButton )
	self.wndPlayerMenuFrame:Show(false,true)
	self.buttonPlayerButton:SetCheck(false)
end

function Addon:UpdateBottomFrameSize()
    if not self.wndCurrencies:IsShown() then
        self.wndBottomFrame:SetAnchorOffsets(0,-30,0,0)
    else
        self.wndBottomFrame:SetAnchorOffsets(0,math.min(-30, -self.wndCurrencies:GetHeight() -4),0,0)
    end
    self:Redraw()
end

-----------------------------------------------------------------------------------------------
-- Currencies functions and events
-----------------------------------------------------------------------------------------------

function Addon:AddTrackedCurrency(idx)
    self.db.profile.config.currencies[idx] = true

    self:UpdateCashAmount()
    self:UpdateTrackedCurrencies()
    self:UpdateCurrenciesMicroMenu()
end

function Addon:RemoveTrackedCurrency(idx)
    self.db.profile.config.currencies[idx] = false

    self:UpdateTrackedCurrencies()
    self:UpdateCurrenciesMicroMenu()
end

function Addon:SetTrackedCurrency(idx, bTrack)
    self.db.profile.config.currencies[idx] = bTrack

    self:UpdateCashAmount()
    self:UpdateTrackedCurrencies()
    self:UpdateCurrenciesMicroMenu()
end

--- This function update the checked / unchecked state of the right clic menu
function Addon:UpdateCurrenciesMicroMenu()
	self.SSICashButton:SetCheck(self.db.profile.config.currencies[1])
	self.SSIRenownButton:SetCheck(self.db.profile.config.currencies[2]) 
	self.SSIElderGemsButton:SetCheck(self.db.profile.config.currencies[3]) 
	self.SSIGloryButton:SetCheck(self.db.profile.config.currencies[4]) 
	self.SSIPrestigeButton:SetCheck(self.db.profile.config.currencies[5]) 
	self.SSICraftingVouchersButton:SetCheck(self.db.profile.config.currencies[6])
	self.SSIOmnibitsButton:SetCheck(self.db.profile.config.currencies[7])
	self.SSIServicetokenButton:SetCheck(self.db.profile.config.currencies[8])
	self.SSIFortunecoinButton:SetCheck(self.db.profile.config.currencies[9])

	if self._tLoadingInfo.SpaceStashCore.isInit then 
		self._tLoadingInfo.SpaceStashCore.instance:UpdateTrackedCurrency();
	end
	
end


function Addon:GetTrackedCurrency(idx)
    if not idx then return self.db.profile.config.currencies end
	return self.db.profile.config.currencies[idx]
end


function Addon:OnOpenCurrenciesMenu(wndHandler, wndControl, eMouseButton)
  if wndHandler == CurrenciesFrame then
    if eMouseButton == 1 then
      self.wndCurrenciesMicroMenu:Show(true,true)
    end
  else
    self.wndCurrenciesMicroMenu:Show(true,true)
  end
end

function Addon:OnDropdownButtonCheck(wndHandler, wndControl, eMouseButton)
	if wndHandler == self.SSICashButton then
		self:AddTrackedCurrency(1)
	elseif wndHandler == self.SSIRenownButton then
		self:AddTrackedCurrency(2)
	elseif wndHandler == self.SSIElderGemsButton then
		self:AddTrackedCurrency(3)
	elseif wndHandler == self.SSIGloryButton then
		self:AddTrackedCurrency(4)
	elseif wndHandler == self.SSIPrestigeButton then
		self:AddTrackedCurrency(5)
	elseif wndHandler == self.SSICraftingVouchersButton then
		self:AddTrackedCurrency(6)
	elseif wndHandler == self.SSIOmnibitsButton then
		self:AddTrackedCurrency(7)
	elseif wndHandler == self.SSIServicetokenButton then
		self:AddTrackedCurrency(8)
	elseif wndHandler == self.SSIFortunecoinButton then
		self:AddTrackedCurrency(9)
	end
end

function Addon:OnDropdownButtonUncheck(wndHandler, wndControl, eMouseButton)
	if wndHandler == self.SSICashButton then
		self:RemoveTrackedCurrency(1)
	elseif wndHandler == self.SSIRenownButton then
		self:RemoveTrackedCurrency(2)
	elseif wndHandler == self.SSIElderGemsButton then
		self:RemoveTrackedCurrency(3)
	elseif wndHandler == self.SSIGloryButton then
		self:RemoveTrackedCurrency(4)
	elseif wndHandler == self.SSIPrestigeButton then
		self:RemoveTrackedCurrency(5)
	elseif wndHandler == self.SSICraftingVouchersButton then
		self:RemoveTrackedCurrency(6)
	elseif wndHandler == self.SSIOmnibitsButton then
		self:RemoveTrackedCurrency(7)
	elseif wndHandler == self.SSIServicetokenButton then
		self:RemoveTrackedCurrency(8)
	elseif wndHandler == self.SSIFortunecoinButton then
		self:RemoveTrackedCurrency(9)
	end
end

function Addon:UpdateTrackedCurrencies()
    local k = 0
    local rightColumn = self.CurrenciesContainer:FindChild("RightColumn")
    local leftColumn = self.CurrenciesContainer:FindChild("LeftColumn")
    local targetColumn = rightColumn

    for k,v in pairs(tCurrenciesWindows) do
        v:Destroy()
        tCurrenciesWindows[k] = nil
    end

    if self.db.profile.config.currencies[1] == true then
        self.wndCash:SetAnchorOffsets(0,-20,0,0)
        self.CurrenciesContainer:SetAnchorOffsets(0,0,0,-20)
        self.wndCash:Show(true,true)
    else
        self.wndCash:SetAnchorOffsets(0,0,0,0)
        self.CurrenciesContainer:SetAnchorOffsets(0,0,0,0)
        self.wndCash:Show(false,true)
    end

    for k,v in pairs(currencies) do
        if k ~= 1 and self.db.profile.config.currencies[k] then
        	if not tCurrenciesWindows[k] then
	            tCurrenciesWindows[k] = Apollo.LoadForm(self.xmlDoc, "_CurrencyWindow", targetColumn, self)
	            if targetColumn == rightColumn then targetColumn = leftColumn else targetColumn = rightColumn end
	            tCurrenciesWindows[k]:SetName("CurrencyWindow_" .. k)
	            if currencies[k].account then 
	            	tCurrenciesWindows[k]:SetMoneySystem(Money.CodeEnumCurrencyType.GroupCurrency, 0, 0, currencies[k].eType)
	            	tCurrenciesWindows[k]:SetAmount(currencies[k].currencyObject:GetAmount(), true)
	            else
	            	tCurrenciesWindows[k]:SetMoneySystem(currencies[k].eType)
	            	tCurrenciesWindows[k]:SetAmount(currencies[k].currencyObject:GetAmount(), true)
	            end
	        end
        end
    end

    if self.wndCash:IsShown() then
      self.wndCurrencies:SetAnchorOffsets(-190, - (28 + self.CurrenciesContainer:FindChild("RightColumn"):ArrangeChildrenVert(2)),0,-2)
    else
      self.wndCurrencies:SetAnchorOffsets(-190, - (13 + (self.CurrenciesContainer:FindChild("RightColumn"):ArrangeChildrenVert(2))),0,-2)
    end

    local frame_size = self.CurrenciesContainer:FindChild("RightColumn"):ArrangeChildrenVert(1)
    self.CurrenciesContainer:FindChild("LeftColumn"):ArrangeChildrenVert(1)

    if frame_size <= 0 and not self.wndCash:IsShown() then
        self.wndCurrencies:Show(false,true)
        self.CurrencyMenuButton:Show(true,true)
    else
        self.wndCurrencies:Show(true,true)
        self.CurrencyMenuButton:Show(false,true)
    end

    self:UpdateBottomFrameSize()

    if self._tLoadingInfo.SpaceStashCore.isInit then 
		self._tLoadingInfo.SpaceStashCore.instance:UpdateTrackedCurrency();
	end
end

function Addon:OnCloseCurrenciesMicroMenu()
    self.wndCurrenciesMicroMenu:Show(false,true)
    self.CurrencyMenuButton:SetCheck(false)
end

function Addon:OnPlayerCurrencyChanged()
    if self.wndMain:IsShown() then
        self:UpdateCashAmount()
     end
end

function Addon:OnCurrenciesMicroMenuMove()
	self.db.profile.config.CurrenciesMicroMenu.anchors = { self.wndCurrenciesMicroMenu:GetAnchorOffsets() }
end

function Addon:OnSplitWindowMove()
	self.db.profile.config.SplitWindow.anchors = { self.wndSplitWindow:GetAnchorOffsets() }
end

function Addon:UpdateCashAmount()
    --[[self.wndCurrencies:SetTooltip(string.format(currenciesTooltipPrototype,
        GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Credits):GetAmount(),
		GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Renown):GetAmount(),
		GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.ElderGems):GetAmount(),
		GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Glory):GetAmount(),
		GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Prestige):GetAmount(),
		GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.CraftingVouchers):GetAmount(),
		AccountItemLib.GetAccountCurrency(AccountItemLib.CodeEnumAccountCurrency.Omnibits):GetAmount(),0,0,
		AccountItemLib.GetAccountCurrency(AccountItemLib.CodeEnumAccountCurrency.ServiceToken):GetAmount(),
		AccountItemLib.GetAccountCurrency(AccountItemLib.CodeEnumAccountCurrency.MysticShiny):GetAmount()))]]

    self.wndCash:SetAmount(currencies[1].currencyObject:GetAmount(), true)

    for k, v in pairs(tCurrenciesWindows) do
        if k ~= 1 then v:SetAmount(currencies[k].currencyObject:GetAmount()) end
    end
end

-----------------------------------------------------------------------------------------------
-- Inventory display functions
-----------------------------------------------------------------------------------------------
function Addon:SetIconsSize(nSize)
	self:IconSizeChange(nSize)
	self:OnInventoryDisplayChange()
end

function Addon:GetIconsSize()
	return self.db.profile.config.IconSize
end

function Addon:SetRowsSize(nSize)
	self:RowSizeChange(nSize)
	self:OnInventoryDisplayChange()
end

function Addon:GetRowsSize()
	return self.db.profile.config.RowSize
end

function Addon:OnShowBank()
	Event_FireGenericEvent("ShowBank")
end

function Addon:SetSortMehtod(fSortMethod)
	if not fSortMethod then
		self.wndBagWindow:SetSort(false)
		return
	elseif type(fSortMethod) == "function" then
		self.wndBagWindow:SetSort(true)
    	self.wndBagWindow:SetItemSortComparer(fSortMethod)
	end
end

function Addon:SetDisplayNew(bDisplay)
	self.db.profile.config.DisplayNew = bDisplay
end

-----------------------------------------------------------------------------------------------
-- Item Deleting (c) Carbine
-----------------------------------------------------------------------------------------------
function Addon:OnSystemBeginDragDrop(wndSource, strType, iData)
	if strType ~= "DDBagItem" then return end

	local item = self.wndBagWindow:GetItem(iData)

	if item and item:CanSalvage() then
		self.btnSalvage:SetData(true)
	end

	Sound.Play(Sound.PlayUI45LiftVirtual)
end

function Addon:OnSystemEndDragDrop(strType, iData)
	if not self.wndMain or not self.wndMain:IsValid() or not self.btnSalvage or strType == "DDGuildBankItem" or strType == "DDWarPartyBankItem" or strType == "DDGuildBankItemSplitStack" then
		return -- TODO Investigate if there are other types///
	end

	self.btnSalvage:SetData(false)

	Sound.Play(Sound.PlayUI46PlaceVirtual)
end

function Addon:OnDeleteCancel()
	self.wndDeleteConfirm:SetData(nil)
	self.wndDeleteConfirm:Close()
end

function Addon:InvokeDeleteConfirmWindow(iData)
	local itemData = Item.GetItemFromInventoryLoc(iData)
	if itemData and not itemData:CanDelete() then
		return
	end
	self.wndDeleteConfirm:SetData(iData)
	self.wndDeleteConfirm:Show(true)
	self.wndDeleteConfirm:ToFront()
	self.wndDeleteConfirm:FindChild("DeleteBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.DeleteItem, iData)
	Sound.Play(Sound.PlayUI55ErrorVirtual)
end

function Addon:OnDeleteConfirm()
	self:OnDeleteCancel()
end

function Addon:OnBagDragDropCancel(wndHandler, wndControl, strType, iData, eReason)
	if strType ~= "DDBagItem" or eReason == Apollo.DragDropCancelReason.EscapeKey or eReason == Apollo.DragDropCancelReason.ClickedOnNothing then
		return false
	end

	if eReason == Apollo.DragDropCancelReason.ClickedOnWorld or eReason == Apollo.DragDropCancelReason.DroppedOnNothing then
		self:InvokeDeleteConfirmWindow(iData)
	end
	return false
end

-- Trash Icon
function Addon:OnDragDropTrash(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType == "DDBagItem" then
		self:InvokeDeleteConfirmWindow(iData)
	end
	return false
end

-----------------------------------------------------------------------------------------------
-- Drag & Drop On Salvage button support
-----------------------------------------------------------------------------------------------
function Addon:OnDragDropSalvage(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType == "DDBagItem" and self.btnSalvage:GetData() then
		self:InvokeSalvageConfirmWindow(iData)
	end
	return false
end

function Addon:OnQueryDragDropSalvage(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType == "DDBagItem" and self.btnSalvage:GetData() then
		return Apollo.DragDropQueryResult.Accept
	end
	return Apollo.DragDropQueryResult.Ignore
end

function Addon:OnDragDropNotifySalvage(wndHandler, wndControl, bMe) -- TODO: We can probably replace this with a button mouse over state
	if bMe and self.btnSalvage:GetData() then
		--self.wndMain:FindChild("SalvageIcon"):SetSprite("CRB_Inventory:InvBtn_SalvageToggleFlyby")
		--self.wndMain:FindChild("TextActionPrompt_Salvage"):Show(true)
	elseif self.btnSalvage:GetData() then
		--self.wndMain:FindChild("SalvageIcon"):SetSprite("CRB_Inventory:InvBtn_SalvageTogglePressed")
		--self.wndMain:FindChild("TextActionPrompt_Salvage"):Show(false)
	end
end

function Addon:InvokeDeleteConfirmWindow(iData)
	local itemData = Item.GetItemFromInventoryLoc(iData)
	if itemData and not itemData:CanDelete() then
		return
	end
	self.wndDeleteConfirm:SetData(iData)
	self.wndDeleteConfirm:Show(true)
	self.wndDeleteConfirm:ToFront()
	self.wndDeleteConfirm:FindChild("DeleteBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.DeleteItem, iData)
	Sound.Play(Sound.PlayUI55ErrorVirtual)
end

function Addon:InvokeSalvageConfirmWindow(iData)
	self.wndSalvageConfirm:SetData(iData)
	self.wndSalvageConfirm:Show(true)
	self.wndSalvageConfirm:ToFront()
	self.wndSalvageConfirm:FindChild("SalvageBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.SalvageItem, iData)
	Sound.Play(Sound.PlayUI55ErrorVirtual)
end

function Addon:OnSalvageConfirm()
	self:OnSalvageCancel()
end

function Addon:OnSalvageCancel()
	self.wndSalvageConfirm:SetData(nil)
	self.wndSalvageConfirm:Close()
end

-----------------------------------------------------------------------------------------------
-- Stack Splitting (c) Carbine
-----------------------------------------------------------------------------------------------

function Addon:OnSplitItemStack(item)
	if not item then return end
	local wndSplit = self.wndMain:FindChild("SplitStackContainer")
	local nStackCount = item:GetStackCount()
	if nStackCount < 2 then
		wndSplit:Show(false)
		return
	end
	wndSplit:SetData(item)
	wndSplit:FindChild("SplitValue"):SetValue(1)
	wndSplit:FindChild("SplitValue"):SetMinMax(1, nStackCount - 1)
	wndSplit:Show(true)
end

function Addon:OnSplitStackCloseClick()
	self.wndMain:FindChild("SplitStackContainer"):Show(false)
end

function Addon:OnSplitStackConfirm(wndHandler, wndCtrl)
	local wndSplit = self.wndMain:FindChild("SplitStackContainer")
	local tItem = wndSplit:GetData()
	wndSplit:Show(false)
	self.wndMain:FindChild("BagWindow"):StartSplitStack(tItem, wndSplit:FindChild("SplitValue"):GetValue())
end

function Addon:ResetConfig()
	self.db.profile.config = defaults

	self:OnPlayerButtonUncheck() --to be sure that the option window is corresponding
end
