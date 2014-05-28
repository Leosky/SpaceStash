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
local MAJOR, MINOR = "SpaceStashInventory-Beta", 13

local CodeEnumTabDisplay = {
	None = 0,
 	BagsTab = 1, 
	VirtualItemsTab = 2, 
	TradeskillsBagTab = 3
}

local tItemSlotBGPixie = {loc = {fPoints = {0,0,1,10},nOffsets = {0,0,0,0},},strSprite="WhiteFill", cr= "black",fRotation="0"}

local tDefaults = {}
tDefaults.tConfig = {}
tDefaults.tConfig.version = {}
tDefaults.tConfig.version.MAJOR = MAJOR
tDefaults.tConfig.version.MINOR = MINOR
tDefaults.tConfig.IconSize = 36
tDefaults.tConfig.RowSize = 10
tDefaults.tConfig.location = {}
tDefaults.tConfig.location.x = 64
tDefaults.tConfig.location.y = 64
tDefaults.tConfig.currencies = {eCurrencyType = Money.CodeEnumCurrencyType.Renown}
tDefaults.tConfig.SelectedTab = CodeEnumTabDisplay.BagsTab

-----------------------------------------------------------------------------------------------
-- Libraries
-----------------------------------------------------------------------------------------------
local SpaceStashInventory, GeminiLocale, GeminiLogging, inspect, LibError, glog = Apollo.GetPackage("Gemini:Addon-1.0").tPackage:NewAddon(tDefaults,"SpaceStashInventory", false, {}), Apollo.GetPackage("Gemini:Locale-1.0").tPackage
local L = GeminiLocale:GetLocale("SpaceStashInventory", true)

local SpaceStashCore
-----------------------------------------------------------------------------------------------
-- Base Wildstar addon behaviours
-----------------------------------------------------------------------------------------------
function SpaceStashInventory:OnInitialize()
  Apollo.CreateTimer("SSILoadingTimer", 5.0, false)
  Apollo.RegisterTimerHandler("SSILoadingTimer", "OnLoadingTimer", self)
  
	self.xmlDoc = XmlDoc.CreateFromFile("SpaceStashInventory.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)

  self.bWindowCreated = false
  self.bReady = false
  self.bSavedDataRestored = false

  GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage
  inspect = Apollo.GetPackage("Drafto:Lib:inspect-1.2").tPackage

end

function SpaceStashInventory:OnDocumentReady()
  self.wndMain = Apollo.LoadForm(self.xmlDoc, "SpaceStashInventoryForm", nil, self)
  self.wndDeleteConfirm = Apollo.LoadForm(self.xmlDoc, "InventoryDeleteNotice", nil, self)

  if self.wndMain == nil or self.wndDeleteConfirm == nil then
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
      self.wndCurrency = self.wndCurrencies:FindChild("CurrencyWindow")
      self.wndCash = self.wndCurrencies:FindChild("CashWindow")
      self.wndCurrenciesMicroMenu = self.wndCurrencies:FindChild("SSICurenciesMicroMenu")
      self.wndCurrenciesMicroMenu:Show(false,true)
        self.SSIElderGemsButton = self.wndCurrenciesMicroMenu:FindChild("SSIElderGemsButton")
        self.SSIPrestigeButton = self.wndCurrenciesMicroMenu:FindChild("SSIPrestigeButton")
        self.SSIRenownButton = self.wndCurrenciesMicroMenu:FindChild("SSIRenownButton")
        self.SSICraftingVouchersButton = self.wndCurrenciesMicroMenu:FindChild("SSICraftingVouchersButton")

  	self.btnSalvage = self.wndBottomFrame:FindChild("SpaceStashInventorySalvageButton")
  	self.btnSalvage:SetTooltip(L["SALVAGEALLBUTTON"])
  	self.btnTradskillsBag = self.wndBottomFrame:FindChild("TradeskillsBagButton")
  	self.btnTradskillsBag:SetTooltip(L["TRADSKILLINVENTORY"])

  self.buttonPlayerButton = self.wndMain:FindChild("PlayerButton")
  self.wndPlayerMenuFrame = self.wndMain:FindChild("PlayerMenuFrame")

  self.xmlDoc = nil
  self.bWindowCreated = true

  if self.bSavedDataRestored then 
    self:OnSpaceStashInventoryReady()
  end
end

function SpaceStashInventory:OnLoadingTimer()
  Apollo.StopTimer("SSILoadingTimer")
  if self.bSavedDataRestored == false and self.bWindowCreated == true then
    glog:info("SpaceStashInventory no data to restore.")
    self:OnSpaceStashInventoryReady()
  end
end

function SpaceStashInventory:OnEnable()
  SpaceStashCore = Apollo.GetAddon("SpaceStashCore")
  glog = GeminiLogging:GetLogger({
      level = GeminiLogging.INFO,
      pattern = "%d [%c:%n] %l - %m",
      appender = "Print"
    })

end


-- Replaces MyAddon:OnSave
function SpaceStashInventory:OnSaveSettings(eLevel)
  if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then 
    return
  end

  return self.tConfig
end

function SpaceStashInventory:OnRestoreSettings(eLevel, tSavedData)
  if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then 
    return
  elseif tSavedData == nil or tSavedData.version == nil or tSavedData.version.MAJOR ~= MAJOR then --change to corrupted save in general?

  elseif tSavedData.version.MINOR < MINOR then

  else
    self.tConfig = tSavedData
  end

  self.bSavedDataRestored = true

  if self.bWindowCreated then
    self:OnSpaceStashInventoryReady()
  end
end

function SpaceStashInventory:OnSpaceStashInventoryReady()
  
  Apollo.RegisterEventHandler("ShowInventory", "InventoryBagOpenCallback", self)
  Apollo.RegisterEventHandler("ToggleInventory", "InventoryBagOpenCallback", self)
  Apollo.RegisterTimerHandler("InventoryBag_DelayTimer", "DelayTimer", self)
  Apollo.CreateTimer("InventoryBag_DelayTimer", 0.01, false)

  Apollo.RegisterSlashCommand("ssi", "OnSSCmd", self)
  Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
  
  Apollo.RegisterEventHandler("PlayerCurrencyChanged", "OnPlayerCurrencyChanged", self)
  Apollo.RegisterEventHandler("WindowMove", "OnWindowMove", self)
  Apollo.RegisterEventHandler("PlayerEquippedItemChanged", "Redraw", self)
  Apollo.RegisterEventHandler("LootedItem", 'OnItemLoot', self)

  Apollo.RegisterEventHandler("GuildBank_ShowPersonalInventory", "OnVisibilityToggle", self)
  Apollo.RegisterEventHandler("InterfaceMenu_ToggleInventory", "OnVisibilityToggle", self)
  
  Apollo.RegisterEventHandler("ToggleInventory", "OnVisibilityToggle", self)
  Apollo.RegisterEventHandler("ShowInventory", "OnVisibilityToggle", self)

  Apollo.RegisterEventHandler("DragDropSysBegin", "OnSystemBeginDragDrop", self)
  Apollo.RegisterEventHandler("DragDropSysEnd", "OnSystemEndDragDrop", self)
  Apollo.RegisterEventHandler("SplitItemStack", "OnSplitItemStack", self)

  SpaceStashInventory:SetSortMehtod(self.tConfig.sort)

  if self.tConfig.SelectedTab == CodeEnumTabDisplay.BagsTab then
    self.wndTopFrame:FindChild("ShowBagsTabButton"):SetCheck(true)
    self.wndBagsTabFrame:Show(true)
    self.wndTopFrame:FindChild("ShowVirtualItemsTabButton"):SetCheck(false)
    self.wndVirtualItemsTabFrame:Show(false)
    self.wndTopFrame:FindChild("ShowTradeskillsBagTabButton"):SetCheck(false)
    self.wndTradeskillsBagTabFrame:Show(false)
  elseif self.tConfig.SelectedTab == CodeEnumTabDisplay.VirtualItemsTab then
    self.wndTopFrame:FindChild("ShowBagsTabButton"):SetCheck(false)
    self.wndBagsTabFrame:Show(false)
    self.wndTopFrame:FindChild("ShowVirtualItemsTabButton"):SetCheck(true)  
    self.wndVirtualItemsTabFrame:Show(true)
    self.wndTopFrame:FindChild("ShowTradeskillsBagTabButton"):SetCheck(false)
    self.wndTradeskillsBagTabFrame:Show(false)
  elseif self.tConfig.SelectedTab == CodeEnumTabDisplay.TradeskillsBagTab then
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

  self:Redraw()
  GeminiLocale:TranslateWindow(L, self.wndMain)
end

function SpaceStashInventory:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_Inventory"), {"InterfaceMenu_ToggleInventory", "Inventory", ""})
end

-----------------------------------------------------------------------------------------------
-- Killing base inventory window in the case of other addon repacking it
-----------------------------------------------------------------------------------------------
 
function SpaceStashInventory:DelayTimer()
        Apollo.StartTimer("InventoryBag_DelayTimer")
end
 
function SpaceStashInventory:InventoryBagOpenCallback()
  local wndInventoryBag = Apollo.FindWindowByName("InventoryBag")
  if wndInventoryBag then
    wndInventoryBag:Show(false)
  end
end

-----------------------------------------------------------------------------------------------
-- Item Deleting (c) Carbine
-----------------------------------------------------------------------------------------------
function SpaceStashInventory:OnSystemBeginDragDrop(wndSource, strType, iData)
	if strType ~= "DDBagItem" then return end

	Sound.Play(Sound.PlayUI45LiftVirtual)
end

function SpaceStashInventory:OnSystemEndDragDrop(strType, iData)
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:FindChild("TrashIcon") or strType == "DDGuildBankItem" or strType == "DDWarPartyBankItem" or strType == "DDGuildBankItemSplitStack" then
		return -- TODO Investigate if there are other types
	end

	Sound.Play(Sound.PlayUI46PlaceVirtual)
end

function SpaceStashInventory:OnDeleteCancel()
	self.wndDeleteConfirm:SetData(nil)
	self.wndDeleteConfirm:Close()
end

function SpaceStashInventory:InvokeDeleteConfirmWindow(iData) 
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

function SpaceStashInventory:OnDeleteConfirm()
	self:OnDeleteCancel()
end

function SpaceStashInventory:OnBagDragDropCancel(wndHandler, wndControl, strType, iData, eReason)
	if strType ~= "DDBagItem" or eReason == Apollo.DragDropCancelReason.EscapeKey or eReason == Apollo.DragDropCancelReason.ClickedOnNothing then
		return false
	end

	if eReason == Apollo.DragDropCancelReason.ClickedOnWorld or eReason == Apollo.DragDropCancelReason.DroppedOnNothing then
		self:InvokeDeleteConfirmWindow(iData)
	end
	return false
end

-- Trash Icon
function SpaceStashInventory:OnDragDropTrash(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType == "DDBagItem" then
		self:InvokeDeleteConfirmWindow(iData)
	end
	return false
end
-----------------------------------------------------------------------------------------------
-- Stack Splitting (c) Carbine
-----------------------------------------------------------------------------------------------

function SpaceStashInventory:OnSplitItemStack(item)
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

function SpaceStashInventory:OnSplitStackCloseClick()
	self.wndMain:FindChild("SplitStackContainer"):Show(false)
end

function SpaceStashInventory:OnSplitStackConfirm(wndHandler, wndCtrl)
	local wndSplit = self.wndMain:FindChild("SplitStackContainer")
	local tItem = wndSplit:GetData()
	wndSplit:Show(false)
	self.wndMain:FindChild("BagWindow"):StartSplitStack(tItem, wndSplit:FindChild("SplitValue"):GetValue())
end

-----------------------------------------------------------------------------------------------
-- Currencies Functions
-----------------------------------------------------------------------------------------------
-- currency event fired
function SpaceStashInventory:OnPlayerCurrencyChanged()
	if self.wndMain:IsShown() then 
	 	self:UpdateCashAmount() 
	 end
end

function SpaceStashInventory:UpdateCashAmount()
	self.wndCurrencies:SetTooltip(string.format(L["CurrenciesTooltip"],
		GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.ElderGems):GetAmount(),
		GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Prestige):GetAmount(),
		GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Renown):GetAmount(),
		GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.CraftingVouchers):GetAmount() ))

	self.wndCash:SetAmount(GameLib.GetPlayerCurrency(), true)
	self.wndCurrency:SetAmount(GameLib.GetPlayerCurrency(self.tConfig.currencies.eCurrencyType):GetAmount())
end

function SpaceStashInventory:ResetConfig() 
	self.tConfig = tDefaults
	
	self:OnPlayerButtonUncheck() --to be sure that the option window is corresponding
end
---------------------------------------------------------------------------------------------------
-- SpaceStashInventory Commands 
---------------------------------------------------------------------------------------------------

-- on /ssi console command
function SpaceStashInventory:OnSSCmd(strCommand, strParam)
	if strParam == "" then 
		self:OnVisibilityToggle()
	elseif strParam == "reset" then
		self:ResetConfig() 
		self:Redraw()
	elseif strParam == "help" then 
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, 
				[[
				/ssi : This command toggle the visibility state of the SpaceStashInventory\n
				/ssi help : Show this help\n
				/ssi option RowSize [number] : define the number of item per row you want.\n
				/ssi option IconSize [number] : define size of item icons.\n
				/ssi option currency [ElderGems,Prestige,Renown,CraftingVouchers] : define the currently tracked alternative currency.\n
				/ssi redraw : debuging purpose - redraw the bag window\n
				/ssi info : debuging purpose - send the metatable to GeminiConsole
				/ssi option AutoSellJunks [true or false]
				/ssi option AutoRepair [true or false]
				]]
			)
	elseif strParam == "info" then 
		glog:info(self.tConfig)
	elseif strParam == "redraw" then
		self:Redraw()
	elseif string.find(string.lower(strParam), "option") ~= nil then
		
		local args = {}

		for arg in string.gmatch(strParam, "[%a%d]+") do table.insert(args, arg) end

		if args[2] == "currency" then

			local eType = tCurrencies[args[3]]
			if eType ~= nil then
				self.tConfig.currencies.eCurrencyType = eType
				self.wndCurrency:SetMoneySystem(eType)
				self:UpdateCashAmount()
				self:OnPlayerButtonUncheck()
				self.buttonPlayerButton:SetCheck(false)	
			else
				ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, args[3] .. " is not a valid currency[ElderGems,Prestige,Renown,CraftingVouchers]")
			end
		elseif string.lower(args[2]) == "rowsize" then
			local size = string.match(args[3],"%d+")
			if size ~= nil then

				self:RowSizeChange(size)
				self:OnInventoryDisplayChange()
				self:OnPlayerButtonUncheck()
				self.buttonPlayerButton:SetCheck(false)
			end
		elseif string.lower(args[2]) == "iconsize" then
			local size = string.match(args[3],"%d+")
			if size ~= nil then
				self:IconSizeChange(size)
				self:OnInventoryDisplayChange()
				self:OnPlayerButtonUncheck()
				self.buttonPlayerButton:SetCheck(false)
			end
		elseif string.lower(args[2]) == "autoselljunks" then
			if args[3] == string.lower("true") then
				self.tConfig.auto.SellJunks = true
				self:OnPlayerButtonUncheck()
			elseif args[3] == string.lower("false") then
				self.tConfig.auto.SellJunks = false
				self:OnPlayerButtonUncheck()
				self.buttonPlayerButton:SetCheck(false)
			end
		elseif string.lower(args[2]) == "autorepair" then
			if args[3] == string.lower("true") then
				self.tConfig.auto.Repair = true
				self:OnPlayerButtonUncheck()
			elseif args[3] == string.lower("false") then
				self.tConfig.auto.Repair = false
				self:OnPlayerButtonUncheck()
				self.buttonPlayerButton:SetCheck(false)
			end
		end
	end
end
---------------------------------------------------------------------------------------------------
-- SpaceStashInventoryForm 
---------------------------------------------------------------------------------------------------
-- update the windows position in the config as the user move it to save position between sessions.
function  SpaceStashInventory:OnWindowMove()
	-- TODO: Check that the window is in the screen
	-- TODO: add an option to keep the entire frame in screen

	self.tConfig.location.x, self.tConfig.location.y = self.wndMain:GetPos()
end


function SpaceStashInventory:OnOptions()
  Event_FireGenericEvent("SpaceStashCore_OpenOptions", self)
end

-- When the SalvageButton is pressed.
function SpaceStashInventory:OnSalvageButton()
	-- TODO: option to configure how button work
	-- MODDERS : if you have a personal addon for salvaging, just make it to handle "RequestSalvageAll". You will need to disable the current ImprovedSalvage addon packed with SpaceStash.
	Event_FireGenericEvent("RequestSalvageAll")
end

function SpaceStashInventory:OnTradskillStashButton()
	Event_FireGenericEvent("ToggleTradeskillInventoryFromBag")
end

function SpaceStashInventory:RowSizeChange(nNewValue)
	nNewValue = nNewValue or self.tConfig.RowSize
	self.tConfig.RowSize = nNewValue
	self.wndMain:FindChild("BagWindow"):SetBoxesPerRow(self.tConfig.RowSize)

	self.rowCount = math.floor(self.wndBagWindow:GetBagCapacity() / self.tConfig.RowSize)
	if self.wndBagWindow:GetBagCapacity() % self.tConfig.RowSize ~= 0 then self.rowCount = self.rowCount +1 end

end

function SpaceStashInventory:IconSizeChange(nNewValue)
	nNewValue = nNewValue or self.tConfig.IconSize
	self.tConfig.IconSize = nNewValue
	self.wndMain:FindChild("BagWindow"):SetSquareSize(self.tConfig.IconSize, self.tConfig.IconSize) 
	self.wndMain:FindChild("BagWindow"):SetBoxesPerRow(self.tConfig.RowSize) --necessary

	self.wndBagsTabFrame:SetAnchorOffsets(1,self.wndMenuFrame:GetHeight(),0,self.wndMenuFrame:GetHeight() + self.tConfig.IconSize )
	self.wndTopFrame:SetAnchorOffsets(0,0,0,self.wndMenuFrame:GetHeight() + self.tConfig.IconSize )
	self.ItemWidget1:SetAnchorOffsets(0,0,self.tConfig.IconSize,self.tConfig.IconSize)
	self.ItemWidget2:SetAnchorOffsets(0,0,self.tConfig.IconSize,self.tConfig.IconSize)
	self.ItemWidget3:SetAnchorOffsets(0,0,self.tConfig.IconSize,self.tConfig.IconSize)
	self.ItemWidget4:SetAnchorOffsets(0,0,self.tConfig.IconSize,self.tConfig.IconSize)
	self.wndBagsTabFrame:ArrangeChildrenHorz(0)

	if self.tConfig.SelectedTab == CodeEnumTabDisplay.BagsTab then
		self.topFrameHeight = self.wndMenuFrame:GetHeight() + self.wndBagsTabFrame:GetHeight()
	elseif self.tConfig.SelectedTab == CodeEnumTabDisplay.VirtualItemsTab then
		self.topFrameHeight = self.wndMenuFrame:GetHeight() + self.wndVirtualItemsTabFrame:GetHeight()
	elseif self.tConfig.SelectedTab == CodeEnumTabDisplay.TradeskillsBagTab then
		self.topFrameHeight = self.wndMenuFrame:GetHeight() + self.wndTradeskillsBagTabFrame:GetHeight()
	else
		self.topFrameHeight = self.wndMenuFrame:GetHeight()
	end
	self.wndInventoryFrame:SetAnchorOffsets(0,self.topFrameHeight-1,0,-self.bottomFrameHeight)

end

function SpaceStashInventory:OnInventoryDisplayChange()

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

	local nInventoryFrameHeight = self.rowCount * self.tConfig.IconSize
	local nInventoryFrameWidth = self.tConfig.IconSize * self.tConfig.RowSize

	self.wndMain:SetAnchorOffsets(
		self.tConfig.location.x,
		self.tConfig.location.y,
		self.tConfig.location.x + nInventoryFrameWidth - self.leftOffset + self.rightOffset,
		self.tConfig.location.y + self.topFrameHeight + self.bottomFrameHeight + nInventoryFrameHeight - self.topOffset + self.bottomOffset + 4)
	
end

-- when the Cancel button is clicked
function SpaceStashInventory:OnClose()
	self:OnVisibilityToggle()
end

function SpaceStashInventory:OnVisibilityToggle()
	if self.wndMain:IsShown() then
		self.wndMain:Show(false,true)
		Sound.Play(Sound.PlayUIBagClose)				
	else
    self.wndMain:FindChild("BagWindow"):MarkAllItemsAsSeen()
		self:OnInventoryDisplayChange()
		self:UpdateCashAmount()
		self.wndMain:Show(true,true)
		Sound.Play(Sound.PlayUIBagOpen)
	end
end

function SpaceStashInventory:OpenInventory()
	if not self.wndMain:IsShown() then
		self:OnInventoryDisplayChange()
		self:UpdateCashAmount()
		self.wndMain:Show(true,true)
		Sound.Play(Sound.PlayUIBagOpen)
	end
end

function SpaceStashInventory:OnItemLoot()
	if self.wndMain:IsShown() then
    self.wndMain:FindChild("BagWindow"):MarkAllItemsAsSeen()
  end
end

-- Update the window sizing an properties (not the 'volatiles' as currencies amounts, new item icon, etc.)
function SpaceStashInventory:Redraw()
	self.leftOffset, self.topOffset, self.rightOffset, self.bottomOffset = self.wndContentFrame:GetAnchorOffsets()
	self.bottomFrameHeight = self.wndBottomFrame:GetHeight()

	self:IconSizeChange()
	self:RowSizeChange()
	self:OnInventoryDisplayChange()

	self.wndMain:FindChild("CurrencyWindow"):SetMoneySystem(self.tConfig.currencies.eCurrencyType)
	self:UpdateCashAmount()
end

-- Generate the tooltips. From stock addon
-- TODO: Mark item as viewed
function SpaceStashInventory:OnGenerateTooltip(wndControl, wndHandler, tType, item)
	if wndControl ~= wndHandler then return end
	wndControl:SetTooltipDoc(nil)
	if item ~= nil then 
		local itemEquipped = item:GetEquippedItemForItemType()
		Tooltip.GetItemTooltipForm(self, wndControl, item, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
	end
end

function SpaceStashInventory:OnGenerateBagTooltip( wndControl, wndHandler, tType, item )
  if wndControl ~= wndHandler then return end
  wndControl:SetTooltipDoc(nil)
  if item ~= nil then
    Tooltip.GetItemTooltipForm(self, wndControl, item, {bPrimary = true, bSelling = false})
  else
    wndControl:SetTooltip(wndControl:GetName() and (L["EMPTYSLOT"]) or "")
  end
end

function SpaceStashInventory:OnShowBagsTab()
	if self.tConfig.SelectedTab == CodeEnumTabDisplay.BagsTab then
		self:OnTabUnshow()
	else
		self.tConfig.SelectedTab = CodeEnumTabDisplay.BagsTab
		self.wndTopFrame:FindChild("ShowBagsTabButton"):SetCheck(true)
		self.wndBagsTabFrame:Show(true)
		self.wndTopFrame:FindChild("ShowVirtualItemsTabButton"):SetCheck(false)
		self.wndVirtualItemsTabFrame:Show(false)
		self.wndTopFrame:FindChild("ShowTradeskillsBagTabButton"):SetCheck(false)
		self.wndTradeskillsBagTabFrame:Show(false)
		self:Redraw()
	end
end


function SpaceStashInventory:OnShowVirtualItemsTab(wndHandler, wndControl, eMouseButton )
	if self.tConfig.SelectedTab == CodeEnumTabDisplay.VirtualItemsTab then
		self:OnTabUnshow()
	else
		self.tConfig.SelectedTab = CodeEnumTabDisplay.VirtualItemsTab
		self.wndTopFrame:FindChild("ShowBagsTabButton"):SetCheck(false)
		self.wndBagsTabFrame:Show(false)
		self.wndTopFrame:FindChild("ShowVirtualItemsTabButton"):SetCheck(true)
		self.wndVirtualItemsTabFrame:Show(true)
		self.wndTopFrame:FindChild("ShowTradeskillsBagTabButton"):SetCheck(false)
		self.wndTradeskillsBagTabFrame:Show(false)
		self:Redraw()
	end
end

function SpaceStashInventory:OnShowTradeskillsBagTab(wndHandler, wndControl, eMouseButton )
	if self.tConfig.SelectedTab == CodeEnumTabDisplay.TradeskillsBagTab then
		self:OnTabUnshow()
	else
		self.tConfig.SelectedTab = CodeEnumTabDisplay.TradeskillsBagTab
		self.wndTopFrame:FindChild("ShowBagsTabButton"):SetCheck(false)
		self.wndBagsTabFrame:Show(false)
		self.wndTopFrame:FindChild("ShowVirtualItemsTabButton"):SetCheck(false)
		self.wndVirtualItemsTabFrame:Show(false)
		self.wndTopFrame:FindChild("ShowTradeskillsBagTabButton"):SetCheck(true)
		self.wndTradeskillsBagTabFrame:Show(true)
		self:Redraw()
	end 
end

function SpaceStashInventory:OnTabUnshow(wndHandler, wndControl, eMouseButton )

	self.tConfig.SelectedTab = CodeEnumTabDisplay.None

	self.wndTopFrame:FindChild("ShowBagsTabButton"):SetCheck(false)
	self.wndBagsTabFrame:Show(false)
	self.wndTopFrame:FindChild("ShowVirtualItemsTabButton"):SetCheck(false)
	self.wndVirtualItemsTabFrame:Show(false)
	self.wndTopFrame:FindChild("ShowTradeskillsBagTabButton"):SetCheck(false)
	self.wndTradeskillsBagTabFrame:Show(false)

	self:Redraw()
end	

function SpaceStashInventory:OnPlayerButtonCheck( wndHandler, wndControl, eMouseButton )
	self.wndPlayerMenuFrame:Show(true)
end

function SpaceStashInventory:OnPlayerButtonUncheck( wndHandler, wndControl, eMouseButton )
	self.wndPlayerMenuFrame:Show(false,true)
	self.buttonPlayerButton:SetCheck(false)
end

-----------------------------------------------------------------------------------------------
-- SpaceStashInventory Setters / Getters
-----------------------------------------------------------------------------------------------
function SpaceStashInventory:SetTrackedCurrency(eLevel)
	self.tConfig.currencies.eCurrencyType = eLevel
	self.wndCurrency:SetMoneySystem(self.tConfig.currencies.eCurrencyType )
	self:UpdateCashAmount()
  SpaceStashCore:UpdateTrackedCurrency()
  if self.tConfig.currencies.eCurrencyType == Money.CodeEnumCurrencyType.ElderGems then
    self.SSIElderGemsButton:SetCheck(true)
  elseif self.tConfig.currencies.eCurrencyType == Money.CodeEnumCurrencyType.Prestige then
    self.SSIPrestigeButton:SetCheck(true)
  elseif self.tConfig.currencies.eCurrencyType == Money.CodeEnumCurrencyType.Renown then
    self.SSIRenownButton:SetCheck(true)
  elseif self.tConfig.currencies.eCurrencyType == Money.CodeEnumCurrencyType.CraftingVouchers then
    self.SSICraftingVouchersButton:SetCheck(true)
  end
end

function SpaceStashInventory:GetTrackedCurrency()
	return self.tConfig.currencies.eCurrencyType
end

function SpaceStashInventory:SetIconsSize(nSize)
	self:IconSizeChange(nSize)
	self:OnInventoryDisplayChange()
end

function SpaceStashInventory:GetIconsSize()
	return self.tConfig.IconSize
end

function SpaceStashInventory:SetRowsSize(nSize)
	self:RowSizeChange(nSize)
	self:OnInventoryDisplayChange()
end

function SpaceStashInventory:GetRowsSize()
	return self.tConfig.RowSize
end

function SpaceStashInventory:OnShowBank()
	Event_FireGenericEvent("ShowBank")
end

function SpaceStashInventory:OnCurrenciesRightClick(wndHandler, wndControl, eMouseButton)
	if eMouseButton == 1 then
    if self.tConfig.currencies.eCurrencyType == Money.CodeEnumCurrencyType.ElderGems then
      self.SSIElderGemsButton:SetCheck(true)
    elseif self.tConfig.currencies.eCurrencyType == Money.CodeEnumCurrencyType.Prestige then
      self.SSIPrestigeButton:SetCheck(true)
    elseif self.tConfig.currencies.eCurrencyType == Money.CodeEnumCurrencyType.Renown then
      self.SSIRenownButton:SetCheck(true)
    elseif self.tConfig.currencies.eCurrencyType == Money.CodeEnumCurrencyType.CraftingVouchers then
      self.SSICraftingVouchersButton:SetCheck(true)
    end
		self.wndCurrenciesMicroMenu:Show(true,true)
	end
end

function SpaceStashInventory:OnCurrencySelectionChange(wndHandler, wndControl, eMouseButton)
  if wndHandler == self.SSIElderGemsButton then
    self:SetTrackedCurrency(Money.CodeEnumCurrencyType.ElderGems)
  elseif wndHandler == self.SSIPrestigeButton then
    self:SetTrackedCurrency(Money.CodeEnumCurrencyType.Prestige)
  elseif wndHandler == self.SSIRenownButton then
    self:SetTrackedCurrency(Money.CodeEnumCurrencyType.Renown)
  elseif wndHandler == self.SSICraftingVouchersButton then
    self:SetTrackedCurrency(Money.CodeEnumCurrencyType.CraftingVouchers)
  end
end

function SpaceStashInventory:OnCloseCurrenciesMicroMenu()
  self.wndCurrenciesMicroMenu:Show(false,true)
end

function SpaceStashInventory:SetSortMehtod(nSortMethod)
  self.tConfig.sort = nSortMethod

  if nSortMethod == 1 then
    self.wndBagWindow:SetSort(true)
    self.wndBagWindow:SetItemSortComparer(self.fnSortItemsByName)
    
  elseif nSortMethod == 2 then
    self.wndBagWindow:SetSort(true)
    self.wndBagWindow:SetItemSortComparer(self.fnSortItemsByQuality)
    
  elseif nSortMethod == 3 then
    self.wndBagWindow:SetSort(true)
    self.wndBagWindow:SetItemSortComparer(self.fnSortItemsByCategory)
    
  else
    self.wndBagWindow:SetSort(false)
  end
  
end

function SpaceStashInventory.fnSortItemsByName(itemLeft, itemRight)
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

function SpaceStashInventory.fnSortItemsByCategory(itemLeft, itemRight)
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

function SpaceStashInventory.fnSortItemsByQuality(itemLeft, itemRight)
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