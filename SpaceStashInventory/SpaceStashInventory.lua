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
-- SpaceStashInventory Addon Definition
-----------------------------------------------------------------------------------------------
local SpaceStashInventory = {} 
-----------------------------------------------------------------------------------------------
-- Libraries
-----------------------------------------------------------------------------------------------
local GeminiLogging	
local inspect

-----------------------------------------------------------------------------------------------
-- Constants and Defaults parameters
-----------------------------------------------------------------------------------------------
local MAJOR, MINOR = "SpaceStashInventory-Beta", 5

local kcrSelectedText = ApolloColor.new("UI_BtnTextHoloPressedFlyby")
local kcrNormalText = ApolloColor.new("UI_BtnTextHoloNormal")
local tCurrencies = {
	ElderGems = Money.CodeEnumCurrencyType.ElderGems,
	Prestige = Money.CodeEnumCurrencyType.Prestige,
	Renown = Money.CodeEnumCurrencyType.Renown,
	CraftingVouchers = Money.CodeEnumCurrencyType.CraftingVouchers
}

local codeEnumTabDisplay = {
	None = 0,
 	BagsTab = 1, 
	VirtualItemsTab = 2, 
	TradeskillsBagTab = 3
}

local tDefaults = {}
tDefaults.version = {}
tDefaults.version.MAJOR = MAJOR
tDefaults.version.MINOR = MINOR
tDefaults.IconSize = 36
tDefaults.RowSize = 10
tDefaults.location = {}
tDefaults.location.x = 64
tDefaults.location.y = 64
tDefaults.currencies = {eCurrencyType = Money.CodeEnumCurrencyType.Renown}
tDefaults.SelectedTab = codeEnumTabDisplay.BagsTab
tDefaults.auto.Repair = true
tDefaults.auto.SellJunk = true

-----------------------------------------------------------------------------------------------
-- Base Wildstar addon behaviours
-----------------------------------------------------------------------------------------------

function SpaceStashInventory:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
    return o
end

function SpaceStashInventory:OnLoad()
	inspect = Apollo.GetPackage("Drafto:Lib:inspect-1.2").tPackage
	GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage
	self.tConfig = tDefaults -- tCOnfig is set here to avoid late loading
	
    -- load the base form
	self.xmlDoc = XmlDoc.CreateFromFile("SpaceStashInventory.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end




function SpaceStashInventory:OnSave(eLevel)

	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then 
		return 
	end

	return self.tConfig
end

function SpaceStashInventory:OnRestore(eLevel, tData )
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then 
		return
	end

	if tData == nil then
		self:ResetConfig()
	else
		if tData.version.MINOR ~= 5 then
			self:ResetConfig()
			self.tConfig.version.MINOR = 5
		else
			self.tConfig = tData
		end
	end

end

-----------------------------------------------------------------------------------------------
-- Async loading handling
-----------------------------------------------------------------------------------------------
function SpaceStashInventory:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
		
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "SpaceStashInventoryForm", nil, self)
	    self.wndDeleteConfirm = Apollo.LoadForm(self.xmlDoc, "InventoryDeleteNotice", nil, self)
	    if self.wndMain == nil or self.wndDeleteConfirm == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end

		self.wndMain:Show(false, true)

	    self.wndDeleteConfirm:Show(false)
		
		self.wndContentFrame = self.wndMain:FindChild("ContentFrame")
		self.wndTopFrame = self.wndMain:FindChild("TopFrame")
			self.wndMenuFrame = self.wndTopFrame:FindChild("MenuFrame")
			self.wndBagsTabFrame = self.wndTopFrame:FindChild("BagsTabFrame")
			self.wndBagsTabFrame:Show(false)
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
		
		self.wndPlayerMenuFrame = self.wndMain:FindChild("PlayerMenuFrame")
		self.boxIconSize = self.wndPlayerMenuFrame :FindChild("IconSizeBox")
		self.boxRowSize = self.wndPlayerMenuFrame :FindChild("RowSizeBox")
		
		self.xmlDoc = nil
		
		self.display = {}
		_, self.display.height, _, _, self.display.width = Apollo.GetDisplaySize()

		self.glog = GeminiLogging:GetLogger({
		  level = GeminiLogging.INFO,
		  pattern = "%d [%c:%n] %l - %m",
		  appender = "GeminiConsole"
		})


		if self.tConfig.SelectedTab == codeEnumTabDisplay.BagsTab then
			self.wndTopFrame:FindChild("ShowBagsTabButton"):SetCheck(true)
			self.wndBagsTabFrame:Show(true)
			self.wndTopFrame:FindChild("ShowVirtualItemsTabButton"):SetCheck(false)
			self.wndVirtualItemsTabFrame:Show(false)
			self.wndTopFrame:FindChild("ShowTradeskillsBagTabButton"):SetCheck(false)
			self.wndTradeskillsBagTabFrame:Show(false)
		elseif self.tConfig.SelectedTab == codeEnumTabDisplay.VirtualItemsTab then
			self.wndTopFrame:FindChild("ShowBagsTabButton"):SetCheck(false)
			self.wndBagsTabFrame:Show(false)
			self.wndTopFrame:FindChild("ShowVirtualItemsTabButton"):SetCheck(true)
			self.wndVirtualItemsTabFrame:Show(true)
			self.wndTopFrame:FindChild("ShowTradeskillsBagTabButton"):SetCheck(false)
			self.wndTradeskillsBagTabFrame:Show(false)
		elseif self.tConfig.SelectedTab == codeEnumTabDisplay.TradeskillsBagTab then
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

		if self.tConfig.currencies.eCurrencyType == Money.CodeEnumCurrencyType.ElderGems then
			self.wndPlayerMenuFrame:FindChild("ElderGemsRadio"):SetCheck(true)
		elseif self.tConfig.currencies.eCurrencyType == Money.CodeEnumCurrencyType.Prestige then
			self.wndPlayerMenuFrame:FindChild("PrestigeRadio"):SetCheck(true)
		elseif self.tConfig.currencies.eCurrencyType == Money.CodeEnumCurrencyType.Renown then
			self.wndPlayerMenuFrame:FindChild("RenownRadio"):SetCheck(true)
		elseif self.tConfig.currencies.eCurrencyType == Money.CodeEnumCurrencyType.CraftingVouchers then
			self.wndPlayerMenuFrame:FindChild("CraftingVouchersRadio"):SetCheck(true)
		end
		
		self.boxIconSize:SetText(tostring(self.tConfig.IconSize))
		self.boxRowSize:SetText(tostring(self.tConfig.RowSize))
		
		self:Redraw()

		Apollo.RegisterEventHandler("InvokeVendorWindow",	"OnVendorInterfaceOpened", self)

		Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
		Apollo.RegisterEventHandler("PlayerCurrencyChanged", "OnPlayerCurrencyChanged", self)
		Apollo.RegisterEventHandler("WindowMove", "OnWindowMove", self)
		Apollo.RegisterEventHandler("PlayerEquippedItemChanged", "Redraw", self)

		Apollo.RegisterEventHandler("GuildBank_ShowPersonalInventory", "OnVisibilityToggle", self)
		Apollo.RegisterEventHandler("InterfaceMenu_ToggleInventory", "OnVisibilityToggle", self)
		Apollo.RegisterEventHandler("ToggleInventory", "OnVisibilityToggle", self)
		Apollo.RegisterEventHandler("ShowInventory", "OnVisibilityToggle", self)

		Apollo.RegisterEventHandler("DragDropSysBegin", "OnSystemBeginDragDrop", self)
		Apollo.RegisterEventHandler("DragDropSysEnd", "OnSystemEndDragDrop", self)
		Apollo.RegisterEventHandler("SplitItemStack", "OnSplitItemStack", self)
		Apollo.RegisterSlashCommand("ssi", "OnSSCmd", self)
		-- Do additional Addon initialization here


	end
end

function SpaceStashInventory:OnInterfaceMenuListHasLoaded()
	self.glog:debug("SpaceStashInventory added to the Menu.")
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_Inventory"), {"InterfaceMenu_ToggleInventory", "Inventory", ""})
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
-- @Automation
-----------------------------------------------------------------------------------------------

function SpaceStashInventory:OnVendorInterfaceOpened()
	if self.tConfig.auto.SellJunks then
		self:SellJunks()
	end

	if self.tConfig.auto.Repair then
		RepairAllItemsVendor()
	end
end

--@return nSoldValue the total value of item sold.
--should i have to add a whitelite to ignore items that have been buyback ?
function SpaceStashInventory:SellJunks()
	local arJunks = self.GetItemByQuality(Item.codeEnumQuality.Inferior)
	local nSoldValue = 0
	for _, item in ipairs(arJunks) do
		if not item:IsSalvagable() and item:IsSellable() and item:GetSellPrice() > 0 then	--check behavior for 'refunding' token items
			SellItemToVendorById(item:GetInventoryId(), item:GetStackCount())
		end
	end
end

function SpaceStashInventory.GetItemByQuality(codeEnumQuality)
	local codeEnumItemQuality = Item.codeEnumItemQuality --not loaded in general because should not loaded often.
	local arItems = {}
	for _, item in ipairs(GameLib.GetPlayerUnit():GetInventoryItems()) do 
		if item:GetQuality() > codeEnumItemQuality.Inferior then
			table.insert(arItems, item)
		end
	end

	return arItems
end

-- return an array containing all item where funcFilter(item) returned true
function SpaceStashInventory.GetItemByFilterFunction(funcFilter)
	if type(funcFilter) ~= "function" then return end
	local arItems = {}

	for _, item in ipairs(GameLib.GetPlayerUnit():GetInventoryItems()) do  ---check key type, to see if it can be usefull to pass it to the function too.
		if funcFilter(item) then
			table.insert(arItems, item)
		end
	end
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
	self.wndCurrencies:SetTooltip(String_GetWeaselString(
	"<P>Elder Gems : ".. GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.ElderGems):GetAmount().." </P>"
		.."<P>Prestige : ".. GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Prestige):GetAmount() .." </P>"
		.."<P>Renown : ".. GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Renown):GetAmount() .." </P>"
		.."<P>Crafting Vouchers : ".. GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.CraftingVouchers):GetAmount() .." </P>"))

	self.wndCash:SetAmount(GameLib.GetPlayerCurrency(), true)
	self.wndCurrency:SetAmount(GameLib.GetPlayerCurrency(self.tConfig.currencies.eCurrencyType):GetAmount())
end

function SpaceStashInventory:ResetConfig() 
	self.tConfig = tDefaults
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
		self.glog:info(self)
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
			else
				ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, args[3] .. " is not a valid currency[ElderGems,Prestige,Renown,CraftingVouchers]")
			end
		elseif string.lower(args[2]) == "rowsize" then
			local size = string.match(args[3],"%d+")
			if size ~= nil then
				self:RowSizeChange(size)
			end
		elseif string.lower(args[2]) == "iconsize" then
			local size = string.match(args[3],"%d+")
			if size ~= nil then
				self:IconSizeChange(size)
			end
		elseif string.lower(args[2]) == "autoselljunks" then
			if args[3] == string.lower("true") then
				self.tConfig.auto.SellJunks = true
			else
				self.tConfig.auto.SellJunks = false
			end
		elseif string.lower(args[2]) == "autorepair" then
			if args[3] == string.lower("true") then
				self.tConfig.auto.Repair = true
			else
				self.tConfig.auto.Repair = false
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

-- When the SalvageButton is pressed.
function SpaceStashInventory:OnSalvageButton()
	-- TODO: option to configure how button work
	-- MODDERS : if you have a personal addon for salvaging, just make it to handle "RequestSalvageAll". You will need to disable the current ImprovedSalvage addon packed with SpaceStash.
	Event_FireGenericEvent("RequestSalvageAll", tAnchors)
end

function SpaceStashInventory:OnTradskillStashButton()
	Event_FireGenericEvent("ToggleTradeskillInventoryFromBag", tAnchors)
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

end

function SpaceStashInventory:OnInventoryDisplayChange()


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
		self.wndMain:Show(false)
		self.wndMain:FindChild("BagWindow"):MarkAllItemsAsSeen()
		Sound.Play(Sound.PlayUIBagClose)				
	else
		self:OnInventoryDisplayChange()
		self:UpdateCashAmount()
		self.wndMain:Show(true)
		Sound.Play(Sound.PlayUIBagOpen)
	end
end

-- Update the window sizing an properties (not the 'volatiles' as currencies amounts, new item icon, etc.)
function SpaceStashInventory:Redraw()
	self.leftOffset, self.topOffset, self.rightOffset, self.bottomOffset = self.wndContentFrame:GetAnchorOffsets()
	self.bottomFrameHeight = self.wndBottomFrame:GetHeight()

	if self.tConfig.SelectedTab == codeEnumTabDisplay.BagsTab then
		self.topFrameHeight = self.wndMenuFrame:GetHeight() + self.wndBagsTabFrame:GetHeight()
	elseif self.tConfig.SelectedTab == codeEnumTabDisplay.VirtualItemsTab then
		self.topFrameHeight = self.wndMenuFrame:GetHeight() + self.wndVirtualItemsTabFrame:GetHeight()
	elseif self.tConfig.SelectedTab == codeEnumTabDisplay.TradeskillsBagTab then
		self.topFrameHeight = self.wndMenuFrame:GetHeight() + self.wndTradeskillsBagTabFrame:GetHeight()
	else
		self.topFrameHeight = self.wndMenuFrame:GetHeight()
	end
	self.wndInventoryFrame:SetAnchorOffsets(0,self.topFrameHeight,0,-self.bottomFrameHeight)

	
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

function SpaceStashInventory:OnGenerateBagTooltip(wndControl, wndHandler, tType, item)
	if wndControl ~= wndHandler then return end
	wndControl:SetTooltipDoc(nil)
	if item ~= nil then
		Tooltip.GetItemTooltipForm(self, wndControl, item, {bPrimary = true, bSelling = false})
	else
		wndControl:SetTooltip(wndControl:GetName() and ("<P Font=\"CRB_InterfaceSmall_O\">No bag equipped.</P>") or "")
	end
end

function SpaceStashInventory:OnShowBagsTab()
	if self.tConfig.SelectedTab == codeEnumTabDisplay.BagsTab then
		self:OnTabUnshow()
	else
		self.tConfig.SelectedTab = codeEnumTabDisplay.BagsTab
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
	if self.tConfig.SelectedTab == codeEnumTabDisplay.VirtualItemsTab then
		self:OnTabUnshow()
	else
		self.tConfig.SelectedTab = codeEnumTabDisplay.VirtualItemsTab
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
	if self.tConfig.SelectedTab == codeEnumTabDisplay.TradeskillsBagTab then
		self:OnTabUnshow()
	else
		self.tConfig.SelectedTab = codeEnumTabDisplay.TradeskillsBagTab
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

	self.tConfig.SelectedTab = codeEnumTabDisplay.None

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

function SpaceStashInventory:OnElderGemsCheck( wndHandler, wndControl, eMouseButton )
	self.tConfig.currencies.eCurrencyType = Money.CodeEnumCurrencyType.ElderGems
	self.wndCurrency:SetMoneySystem(self.tConfig.currencies.eCurrencyType )
	self:UpdateCashAmount()
end

function SpaceStashInventory:OnCVChecked( wndHandler, wndControl, eMouseButton )
	self.tConfig.currencies.eCurrencyType = Money.CodeEnumCurrencyType.CraftingVouchers
	self.wndCurrency:SetMoneySystem(self.tConfig.currencies.eCurrencyType )
	self:UpdateCashAmount()
end

function SpaceStashInventory:OnRenownCheck( wndHandler, wndControl, eMouseButton )
	self.tConfig.currencies.eCurrencyType = Money.CodeEnumCurrencyType.Renown
	self.wndCurrency:SetMoneySystem(self.tConfig.currencies.eCurrencyType )
	self:UpdateCashAmount()
end

function SpaceStashInventory:OnPrestigeCheck( wndHandler, wndControl, eMouseButton )
	self.tConfig.currencies.eCurrencyType = Money.CodeEnumCurrencyType.Prestige
	self.wndCurrency:SetMoneySystem(self.tConfig.currencies.eCurrencyType )
	self:UpdateCashAmount()
end	

function SpaceStashInventory:OnPlayerButtonUncheck( wndHandler, wndControl, eMouseButton )
	self.wndPlayerMenuFrame:Show(false,true)
	self.boxIconSize:SetText(self.tConfig.IconSize)
	self.boxRowSize:SetText(self.tConfig.RowSize)
end

function SpaceStashInventory:OnIconSizeChange( wndHandler, wndControl, strText )
	self:IconSizeChange(strText)
	self:OnInventoryDisplayChange()
end

function SpaceStashInventory:OnRowSizeChange( wndHandler, wndControl, strText )
	self:RowSizeChange(strText)
	self:OnInventoryDisplayChange()
end

function SpaceStashInventory:OnOptionAccept( wndHandler, wndControl, eMouseButton )

	self:IconSizeChange(tonumber(self.boxIconSize:GetText()))
	self:RowSizeChange(tonumber(self.boxRowSize:GetText()))
	
	self.wndPlayerMenuFrame:Show(false,true)
	self:OnInventoryDisplayChange()
end
--

-----------------------------------------------------------------------------------------------
-- SpaceStashInventory Instance
-----------------------------------------------------------------------------------------------

Apollo.RegisterAddon(SpaceStashInventory:new(), false, "", {
	"Gemini:Logging-1.2", 
	"Drafto:Lib:inspect-1.2"
})
 