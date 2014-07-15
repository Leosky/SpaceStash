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
local MAJOR, MINOR = "SpaceStashInventory-Beta", 21

-----------------------------------------------------------------------------------------------
-- Libraries
-----------------------------------------------------------------------------------------------
local GeminiLocale = Apollo.GetPackage("Gemini:Locale-1.0").tPackage
local Addon, glog = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon("SpaceStashInventory")
local L = GeminiLocale:GetLocale("SpaceStashInventory", true)

local SpaceStashCore

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
defaults.profile.config.CurrenciesMicroMenu = { anchors = {-207, -171, -6, -5} }
defaults.profile.config.SplitWindow = { anchors = {0, 75, 164, 125} }
defaults.profile.config.currencies = {}
defaults.profile.config.currencies[Money.CodeEnumCurrencyType.Credits] = true
defaults.profile.config.SelectedTab = Addon.CodeEnumTabDisplay.BagsTab
defaults.profile.config.DisplayNew = false

local tCurrenciesWindows = {}
local nCurrenciesWindowsSize = 0

-----------------------------------------------------------------------------------------------
-- Base Wildstar addon behaviours
-----------------------------------------------------------------------------------------------
function Addon:OnInitialize()

  self.db = Apollo.GetPackage("Gemini:DB-1.0").tPackage:New(self, defaults, true)


  glog = Apollo.GetPackage("Gemini:Logging-1.2").tPackage:GetLogger({
      level = "INFO",
      pattern = "%d [%c:%n] %l - %m",
      appender = "GeminiConsole"
    })

end

function Addon:OnEnable()
 	SpaceStashCore = Apollo.GetAddon("SpaceStashCore")

	self.xmlDoc = XmlDoc.CreateFromFile("SpaceStashInventory.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)

end

function Addon:OnDocumentReady()
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
	self.wndCash = self.wndCurrencies:FindChild("CashWindow")
	self.CurrenciesContainer = self.wndCurrencies:FindChild("CurrenciesContainer")
	self.CurrencyMenuButton = self.wndBottomFrame:FindChild("CurrencyMenuButton")

	self.wndCurrenciesMicroMenu = self.wndMain:FindChild("SSICurenciesMicroMenu")
	self.wndCurrenciesMicroMenu:Show(false,true)
	self.SSICashButton = self.wndCurrenciesMicroMenu:FindChild("SSICashButton")
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

	self.wndSplitWindow = self.wndMain:FindChild("SplitStackContainer")

	self:SetSortMehtod(self.db.profile.config.sort)

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

	Apollo.RegisterSlashCommand("ssi", "OnSlashCommand", self)
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("WindowManagementReady", "OnWindowManagementReady", self)
	Apollo.RegisterEventHandler("WindowManagementAdd", "OnRover", self)

	Apollo.RegisterEventHandler("PlayerCurrencyChanged", "OnPlayerCurrencyChanged", self)
	Apollo.RegisterEventHandler("PlayerEquippedItemChanged", "Redraw", self)

	Apollo.RegisterEventHandler("GuildBank_ShowPersonalInventory", "OnVisibilityToggle", self)
	Apollo.RegisterEventHandler("InterfaceMenu_ToggleInventory", "OnVisibilityToggle", self)


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

	self.bReady = true
	-- self:UpdateVirtualItemInventory()
	Event_FireGenericEvent("AddonFullyLoaded", {addon = self, strName = "SpaceStashInventory"})
end

function Addon:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_Inventory"), {"InterfaceMenu_ToggleInventory", "Inventory", ""})
end

function Addon:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = "SpaceStashInventory"})
end

function Addon:OnRover(args)
	if args.strName == "Rover" then
		Event_FireGenericEvent("SendVarToRover", "SpaceStashInventory", self)
        Event_FireGenericEvent("SendVarToRover", "tCurrenciesWindows", tCurrenciesWindows)
	end
end
-----------------------------------------------------------------------------------------------
-- Item Deleting (c) Carbine
-----------------------------------------------------------------------------------------------
function Addon:OnSystemBeginDragDrop(wndSource, strType, iData)
	if strType ~= "DDBagItem" then return end

	Sound.Play(Sound.PlayUI45LiftVirtual)
end

function Addon:OnSystemEndDragDrop(strType, iData)
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:FindChild("TrashIcon") or strType == "DDGuildBankItem" or strType == "DDWarPartyBankItem" or strType == "DDGuildBankItemSplitStack" then
		return -- TODO Investigate if there are other types///
	end

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

---------------------------------------------------------------------------------------------------
-- SpaceStashInventory Commands
---------------------------------------------------------------------------------------------------
function Addon:OnQuestObjectiveUpdated()
	self:UpdateVirtualItemInventory()
end

function Addon:OnChallengeUpdated()
	self:UpdateVirtualItemInventory()
end

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
---------------------------------------------------------------------------------------------------
-- SpaceStashInventory Commands
---------------------------------------------------------------------------------------------------

-- on /ssi console command
function Addon:OnSlashCommand(strCommand, strParam)
	if strParam == "" then
		self:OnVisibilityToggle()
	elseif strParam == "info" then
		glog:info(self)
	elseif strParam == "redraw" then
		self:Redraw()
	end
end
---------------------------------------------------------------------------------------------------
-- SpaceStashInventoryForm
---------------------------------------------------------------------------------------------------
-- update the windows position in the config as the user move it to save position between sessions.
function  Addon:OnWindowMove()
	-- TODO: Check that the window is in the screen
	-- TODO: add an option to keep the entire frame in screen


end


function Addon:OnOptions()
  Event_FireGenericEvent("SpaceStashCore_OpenOptions", self)
end

-- When the SalvageButton is pressed.
function Addon:OnSalvageButton()
	-- TODO: option to configure how button work
	-- MODDERS : if you have a personal addon for salvaging, just make it to handle "RequestSalvageAll". You will need to disable the current ImprovedSalvage addon packed with SpaceStash.
	Event_FireGenericEvent("RequestSalvageAll")
end

function Addon:OnTradskillStashButton()
	Event_FireGenericEvent("ToggleTradeskillInventoryFromBag")
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

-- when the Cancel button is clicked
function Addon:OnClose()
  self.wndMain:Show(false,true)
  self.wndBagWindow:MarkAllItemsAsSeen()
  Sound.Play(Sound.PlayUIBagClose)
end

function Addon:OnItemLoot()
  if not self.db.profile.config.DisplayNew then self.wndBagWindow:MarkAllItemsAsSeen() end
end

function Addon:OnVisibilityToggle()
	if self.wndMain:IsShown() then
		self.wndMain:Show(false,true)
    self.wndBagWindow:MarkAllItemsAsSeen()
		Sound.Play(Sound.PlayUIBagClose)
	else
		self:OnInventoryDisplayChange()
		self:UpdateCashAmount()
		self.wndMain:Show(true,true)
		Sound.Play(Sound.PlayUIBagOpen)
	end
end

function Addon:OpenInventory()
	if not self.wndMain:IsShown() then
		self:OnInventoryDisplayChange()
		self:UpdateCashAmount()
		self.wndMain:Show(true,true)
		Sound.Play(Sound.PlayUIBagOpen)
	end
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
end

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

function Addon:AddTrackedCurrency(eCurrencyType)
    self.db.profile.config.currencies[eCurrencyType] = true

    self:UpdateCashAmount()
    self:UpdateTrackedCurrencies()
    self:UpdateCurrenciesMicroMenu()
end

function Addon:RemoveTrackedCurrency(eCurrencyType)
    self.db.profile.config.currencies[eCurrencyType] = false

    self:UpdateTrackedCurrencies()
    self:UpdateCurrenciesMicroMenu()
end

function Addon:SetTrackedCurrency(eCurrencyType, bTrack)
    self.db.profile.config.currencies[eCurrencyType] = bTrack

    self:UpdateCashAmount()
    self:UpdateTrackedCurrencies()
    self:UpdateCurrenciesMicroMenu()
end

--- This function update the checked / unchecked state of the right clic menu
function Addon:UpdateCurrenciesMicroMenu()
    self.SSICashButton:SetCheck(self.db.profile.config.currencies[Money.CodeEnumCurrencyType.Credits])
    self.SSIElderGemsButton:SetCheck(self.db.profile.config.currencies[Money.CodeEnumCurrencyType.ElderGems])
    self.SSIPrestigeButton:SetCheck(self.db.profile.config.currencies[Money.CodeEnumCurrencyType.Prestige])
    self.SSIRenownButton:SetCheck(self.db.profile.config.currencies[Money.CodeEnumCurrencyType.Renown])
    self.SSICraftingVouchersButton:SetCheck(self.db.profile.config.currencies[Money.CodeEnumCurrencyType.CraftingVouchers])
end


function Addon:GetTrackedCurrency(eCurrencyType)
    if not eCurrencyType then return self.db.profile.config.currencies end
	return self.db.profile.config.currencies[eCurrencyType]
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
    self:AddTrackedCurrency(Money.CodeEnumCurrencyType.Credits)
  elseif wndHandler == self.SSIElderGemsButton then
    self:AddTrackedCurrency(Money.CodeEnumCurrencyType.ElderGems)
  elseif wndHandler == self.SSIPrestigeButton then
    self:AddTrackedCurrency(Money.CodeEnumCurrencyType.Prestige)
  elseif wndHandler == self.SSIRenownButton then
    self:AddTrackedCurrency(Money.CodeEnumCurrencyType.Renown)
  elseif wndHandler == self.SSICraftingVouchersButton then
    self:AddTrackedCurrency(Money.CodeEnumCurrencyType.CraftingVouchers)
  end
end

function Addon:OnDropdownButtonUncheck(wndHandler, wndControl, eMouseButton)
    if wndHandler == self.SSICashButton then
        self:RemoveTrackedCurrency(Money.CodeEnumCurrencyType.Credits)
    elseif wndHandler == self.SSIElderGemsButton then
        self:RemoveTrackedCurrency(Money.CodeEnumCurrencyType.ElderGems)
    elseif wndHandler == self.SSIPrestigeButton then
        self:RemoveTrackedCurrency(Money.CodeEnumCurrencyType.Prestige)
    elseif wndHandler == self.SSIRenownButton then
        self:RemoveTrackedCurrency(Money.CodeEnumCurrencyType.Renown)
    elseif wndHandler == self.SSICraftingVouchersButton then
        self:RemoveTrackedCurrency(Money.CodeEnumCurrencyType.CraftingVouchers)
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

    if self.db.profile.config.currencies[Money.CodeEnumCurrencyType.Credits] == true then
        self.wndCash:SetAnchorOffsets(0,-20,0,0)
        self.CurrenciesContainer:SetAnchorOffsets(0,0,0,-20)
        self.wndCash:Show(true,true)
    else
        self.wndCash:SetAnchorOffsets(0,0,0,0)
        self.CurrenciesContainer:SetAnchorOffsets(0,0,0,0)
        self.wndCash:Show(false,true)
    end

    if self.db.profile.config.currencies[Money.CodeEnumCurrencyType.ElderGems] == true then
        if not tCurrenciesWindows[Money.CodeEnumCurrencyType.ElderGems] then
            tCurrenciesWindows[Money.CodeEnumCurrencyType.ElderGems] = Apollo.LoadForm(self.xmlDoc, "_CurrencyWindow", targetColumn, self)
            if targetColumn == rightColumn then targetColumn = leftColumn else targetColumn = rightColumn end

            tCurrenciesWindows[Money.CodeEnumCurrencyType.ElderGems]:SetName("ElderGems_CurrencyWindow")
            tCurrenciesWindows[Money.CodeEnumCurrencyType.ElderGems]:SetMoneySystem(Money.CodeEnumCurrencyType.ElderGems)
            tCurrenciesWindows[Money.CodeEnumCurrencyType.ElderGems]:SetAmount(GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.ElderGems):GetAmount(), true)
        end
    end

    if self.db.profile.config.currencies[Money.CodeEnumCurrencyType.Prestige] == true then
        if not tCurrenciesWindows[Money.CodeEnumCurrencyType.Prestige] then
            tCurrenciesWindows[Money.CodeEnumCurrencyType.Prestige] = Apollo.LoadForm(self.xmlDoc, "_CurrencyWindow", targetColumn, self)
            if targetColumn == rightColumn then targetColumn = leftColumn else targetColumn = rightColumn end
            tCurrenciesWindows[Money.CodeEnumCurrencyType.Prestige]:SetName("Prestige_CurrencyWindow")
            tCurrenciesWindows[Money.CodeEnumCurrencyType.Prestige]:SetMoneySystem(Money.CodeEnumCurrencyType.Prestige)
            tCurrenciesWindows[Money.CodeEnumCurrencyType.Prestige]:SetAmount(GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Prestige):GetAmount(), true)
        end
    end

    if self.db.profile.config.currencies[Money.CodeEnumCurrencyType.Renown] == true then
        if not tCurrenciesWindows[Money.CodeEnumCurrencyType.Renown] then
            tCurrenciesWindows[Money.CodeEnumCurrencyType.Renown] = Apollo.LoadForm(self.xmlDoc, "_CurrencyWindow", targetColumn, self)
            if targetColumn == rightColumn then targetColumn = leftColumn else targetColumn = rightColumn end
            tCurrenciesWindows[Money.CodeEnumCurrencyType.Renown]:SetName("Renown_CurrencyWindow")
            tCurrenciesWindows[Money.CodeEnumCurrencyType.Renown]:SetMoneySystem(Money.CodeEnumCurrencyType.Renown)
            tCurrenciesWindows[Money.CodeEnumCurrencyType.Renown]:SetAmount(GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Renown):GetAmount(), true)
        end
    end

    if self.db.profile.config.currencies[Money.CodeEnumCurrencyType.CraftingVouchers] == true then
        if not tCurrenciesWindows[Money.CodeEnumCurrencyType.CraftingVouchers] then
            tCurrenciesWindows[Money.CodeEnumCurrencyType.CraftingVouchers] = Apollo.LoadForm(self.xmlDoc, "_CurrencyWindow", targetColumn, self)
            if targetColumn == rightColumn then targetColumn = leftColumn else targetColumn = rightColumn end
            tCurrenciesWindows[Money.CodeEnumCurrencyType.CraftingVouchers]:SetName("CraftingVouchers_CurrencyWindow")
            tCurrenciesWindows[Money.CodeEnumCurrencyType.CraftingVouchers]:SetMoneySystem(Money.CodeEnumCurrencyType.CraftingVouchers)
            tCurrenciesWindows[Money.CodeEnumCurrencyType.CraftingVouchers]:SetAmount(GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.CraftingVouchers):GetAmount(), true)
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
    self.wndCurrencies:SetTooltip(string.format(L["CurrenciesTooltip"],
        GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.ElderGems):GetAmount(),
        GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Prestige):GetAmount(),
        GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Renown):GetAmount(),
        GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.CraftingVouchers):GetAmount()))

    self.wndCash:SetAmount(GameLib.GetPlayerCurrency(), true)

    for k, v in pairs(tCurrenciesWindows) do
        v:SetAmount(GameLib.GetPlayerCurrency(k):GetAmount())
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
