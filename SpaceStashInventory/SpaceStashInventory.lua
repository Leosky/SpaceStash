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
-- SpaceStashInventory Module Definition
-----------------------------------------------------------------------------------------------
local SpaceStashInventory = {} 

-----------------------------------------------------------------------------------------------
-- Libraries
-----------------------------------------------------------------------------------------------
local GeminiLogging	
local inspect

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local MAJOR, MINOR = "SpaceStashInventory-Beta", 2

local kcrSelectedText = ApolloColor.new("UI_BtnTextHoloPressedFlyby")
local kcrNormalText = ApolloColor.new("UI_BtnTextHoloNormal")
local tCurrencies = {}
tCurrencies["ElderGems"] = Money.CodeEnumCurrencyType.ElderGems
tCurrencies["Prestige"] = Money.CodeEnumCurrencyType.Prestige
tCurrencies["Renown"] = Money.CodeEnumCurrencyType.Renown
tCurrencies["CraftingVouchers"] = Money.CodeEnumCurrencyType.CraftingVouchers

function SpaceStashInventory:OnLoad()
	inspect = Apollo.GetPackage("Drafto:Lib:inspect-1.2").tPackage
	GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage

	self.glog = GeminiLogging:GetLogger({
		  level = GeminiLogging.DEBUG,
		  pattern = "%d [%c:%n] %l - %m",
		  appender = "Print"
		})

	self.tConfig = {}
	self.tConfig.version = {}
	self.tConfig.version.MAJOR = MAJOR
	self.tConfig.version.MINOR = MINOR
	self.tConfig.window = { IconSize = 36, RowSize = 10}
	self.tConfig.window.location = { fPoints = {0,0,0,0}, nOffsets = {64,64,576,756}}
	self.tConfig.currencies = {eCurrencyType = Money.CodeEnumCurrencyType.Renown}

	self.nInventorySize = 16

    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("SpaceStashInventory.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

function SpaceStashInventory:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "SpaceStashInventoryForm", nil, self)
	    self.wndDeleteConfirm 	= Apollo.LoadForm(self.xmlDoc, "InventoryDeleteNotice", nil, self)

		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		self.xmlDoc = nil

		self.wndMain:Show(false, true)
		self.wndDeleteConfirm:Show(false, true)
		Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
		Apollo.RegisterEventHandler("PlayerCurrencyChanged", "OnPlayerCurrencyChanged", self)
		Apollo.RegisterEventHandler("WindowMove", "OnWindowMove", self)
		Apollo.RegisterEventHandler("PlayerEquippedItemChanged", "OnBagsChange", self)
		Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)

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
-- SpaceStashInventory Persistance
-----------------------------------------------------------------------------------------------
function SpaceStashInventory:OnSave(eLevel)

	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Account then 
		return 
	end

	return self.tConfig
end

function SpaceStashInventory:OnRestore(eLevel, tData )
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Account then 
		return
	end
	
	self.tConfig = tData

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
	self.wndMain:FindChild("CashWindow"):SetAmount(GameLib.GetPlayerCurrency(), true)
	self.wndMain:FindChild("CurrencyWindow"):SetAmount(GameLib.GetPlayerCurrency(self.tConfig.currencies.eCurrencyType):GetAmount())
end

---------------------------------------------------------------------------------------------------
-- SpaceStashInventory Commands 
---------------------------------------------------------------------------------------------------

-- on /ssi console command
function SpaceStashInventory:OnSSCmd(strCommand, strParam)
	if strParam == "" then 
		self:OnVisibilityToggle()
	elseif strParam == "help" then 
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, 
				[[/ssi : This command toggle the visibility state of the SpaceStashInventory\n
				/ssi help : Show this help\n
				/ssi option RowSize [number] : define the number of item per row you want.\n
				/ssi option IconSize [number] : define size of item icons.\n
				/ssi option currency [ElderGems,Prestige,Renown,CraftingVouchers] : define the currently tracked alternative currency.\n
				/ssi redraw : debuging purpose - redraw the bag window\n
				/ssi info : debuging purpose - send the metatable to GeminiConsole]]
			)

	elseif strParam == "info" then 
		self.glog:info(self)
	elseif strParam == "redraw" then
		self:UpdateWindow()
	elseif string.find(string.lower(strParam), "option") ~= nil then
		
		local args = {}

		for arg in string.gmatch(strParam, "[%a%d]+") do table.insert(args, arg) end

		if args[2] == "currency" then

			local eType = tCurrencies[args[3]]
			if eType ~= nil then
				self.tConfig.currencies.eCurrencyType = eType
				self.wndMain:FindChild("CurrencyWindow"):SetMoneySystem(eType)
				self:UpdateCashAmount()
			else
				ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, args[3] .. " is not a valid currency[ElderGems,Prestige,Renown,CraftingVouchers]")
			end
		elseif string.lower(args[2]) == "rowsize" then
			local size = string.match(args[3],"%d+")
			if size ~= nil then
				self.tConfig.window.RowSize = size
				self:UpdateWindow()
			end
		elseif string.lower(args[2]) == "iconsize" then
			local size = string.match(args[3],"%d+")
			if size ~= nil then
				self.tConfig.window.IconSize = size
				self:UpdateWindow()
			end
		end
	end
end
---------------------------------------------------------------------------------------------------
-- SpaceStashInventoryForm 
---------------------------------------------------------------------------------------------------
-- Reacting to the inventory keybind
-- TODO
function SpaceStashInventory:OnKeyDown(wndHandler, wndControl, strKeyName, nCode, eModifier)

end

-- update the windows position in the config as the user move it to save position between sessions.
function  SpaceStashInventory:OnWindowMove()
	-- TODO: Check that the window is in the screen
	-- TODO: add an option to keep the entire frame in screen
	self.tConfig.window.location = self.wndMain:GetLocation():ToTable()
end

-- When the SalvageButton is pressed.
function SpaceStashInventory:OnSalvageButton()
	-- TODO: option to configure how button work
	-- TODO: option to set the fired event.
	-- MODDERS : if you have a personal addon for salvaging, just make it to handle "RequestSalvageAll". You will need to disable the current ImprovedSalvage addon packed with SpaceStash.
	Event_FireGenericEvent("RequestSalvageAll", tAnchors)
end

function SpaceStashInventory:OnTradskillStashButton()
	Event_FireGenericEvent("ToggleTradeskillInventoryFromBag", tAnchors)
end

-- calculation of the windows offets
function SpaceStashInventory:UpdateConfig()

	self.tConfig.window.location.nOffsets[3] = self.tConfig.window.location.nOffsets[1] + self.tConfig.window.IconSize * self.tConfig.window.RowSize + 12

	local rowCount = math.floor(self.nInventorySize / self.tConfig.window.RowSize)
	if self.nInventorySize % self.tConfig.window.RowSize ~= 0 then rowCount = rowCount +1 end

	self.tConfig.window.location.nOffsets[4] = self.tConfig.window.location.nOffsets[2] + rowCount * self.tConfig.window.IconSize + 24 + 54

end

-- return the size of the inventory and update the window and config if doUpdate is set
function SpaceStashInventory:OnBagsChange()
	local nInventorySize = 16
	local itemEquipped = GameLib.GetPlayerUnit():GetEquippedItems()

	for idx=1, #itemEquipped  do 
		if itemEquipped[idx]:GetBagSlots() > 0 then
			nInventorySize = nInventorySize + itemEquipped[idx]:GetBagSlots()
		end
	end
	
	self.nInventorySize = nInventorySize
	
	self:UpdateWindow()
end

-- when the Cancel button is clicked
function SpaceStashInventory:OnClose()
	self:OnVisibilityToggle(self)
end

function SpaceStashInventory:OnVisibilityToggle()
	if self.wndMain:IsShown() then
		self.wndMain:Show(false)
		self.wndMain:FindChild("BagWindow"):MarkAllItemsAsSeen()
		Sound.Play(Sound.PlayUIBagClose)
	else
		self:OnBagsChange()
		self.wndMain:Show(true)
		Sound.Play(Sound.PlayUIBagOpen)
	end
end

-- Update the window sizing an properties (not the 'volatiles' as currencies amounts, new item icon, etc.)
function SpaceStashInventory:UpdateWindow()
	self:UpdateConfig()

	self.wndMain:SetAnchorOffsets(self.tConfig.window.location.nOffsets[1],self.tConfig.window.location.nOffsets[2],self.tConfig.window.location.nOffsets[3],self.tConfig.window.location.nOffsets[4])
	self.wndMain:FindChild("BagWindow"):SetSquareSize(self.tConfig.window.IconSize, self.tConfig.window.IconSize) 
	self.wndMain:FindChild("BagWindow"):SetBoxesPerRow(self.tConfig.window.RowSize)
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

-----------------------------------------------------------------------------------------------
-- SpaceStashInventory Instance
-----------------------------------------------------------------------------------------------
function SpaceStashInventory:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
    return o
end

Apollo.RegisterAddon(SpaceStashInventory:new(), false, "", {
	"Gemini:Logging-1.2", 
	"Drafto:Lib:inspect-1.2"
})
 