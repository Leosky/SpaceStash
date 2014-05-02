-----------------------------------------------------------------------------------------------
-- Client Lua Script for SpaceStashInventory
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Apollo"
require "GameLib"
require "Item"
require "Window"
require "Money"

-----------------------------------------------------------------------------------------------
-- SpaceStashInventory Module Definition
-----------------------------------------------------------------------------------------------
local SpaceStashInventory = {} 

-----------------------------------------------------------------------------------------------
-- Libraries
-----------------------------------------------------------------------------------------------
local GeminiLogging
local GeminiConsole
local inspect
local ImprovedSalvage
local Keybind

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local MAJOR, MINOR = "SpaceStashInventory-Beta", 1

local kcrSelectedText = ApolloColor.new("UI_BtnTextHoloPressedFlyby")
local kcrNormalText = ApolloColor.new("UI_BtnTextHoloNormal")
local tCurrencies = {}
tCurrencies["eldergems"] = Money.CodeEnumCurrencyType.ElderGems
tCurrencies["prestige"] = Money.CodeEnumCurrencyType.Prestige
tCurrencies["renown"] = Money.CodeEnumCurrencyType.Renown
tCurrencies["craftingvouchers"] = Money.CodeEnumCurrencyType.CraftingVouchers


function SpaceStashInventory:OnLoad()
	inspect = Apollo.GetPackage("Drafto:Lib:inspect-1.2").tPackage
	GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage
	GeminiConsole = Apollo.GetAddon("GeminiConsole")	
	ImprovedSalvage = Apollo.GetAddon("ImprovedSalvage")

	self.glog = GeminiLogging:GetLogger({
		  level = GeminiLogging.INFO,
		  pattern = "%d [%c:%n] %l - %m",
		  appender = "GeminiConsole"
		})
	
	

	self.tConfig = {}
	self.tConfig.version = {}
	self.tConfig.version.MAJOR = MAJOR
	self.tConfig.version.MINOR = MINOR
	self.tConfig.window = { SquareSize = 48, BoxPerRow = 10}
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
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		self.xmlDoc = nil

		self.wndMain:Show(false, true)
		

		SpaceStashInventory:UpdateConfig(self)

		Apollo.RegisterEventHandler("PlayerCurrencyChanged", "OnPlayerCurrencyChanged", self)
		Apollo.RegisterEventHandler("WindowMove", "OnWindowMove", self)
		
		-- Register handlers for events, slash commands and timer, etc.
		Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("ssi", "OnSSCmd", self)
		-- Do additional Addon initialization here

	end
end

-----------------------------------------------------------------------------------------------
-- SpaceStashInventory Persistance
-----------------------------------------------------------------------------------------------
function SpaceStashInventory:OnSave(eLevel)

	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then 
		return 
	end
	local tSave = self.config

	return self.tConfig
end

function SpaceStashInventory:OnRestore(eLevel, tData )

	if not tData or tData.version.MAJOR ~= MAJOR then
		return
	end

	self.tSave = tData
	self.tConfig = tData
end
-----------------------------------------------------------------------------------------------
-- SpaceStashInventory OnDocLoaded
-----------------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------------
-- Currencies Functions
-----------------------------------------------------------------------------------------------
-- currency event fired
function SpaceStashInventory:OnPlayerCurrencyChanged()
	if self.wndMain then 
	 	SpaceStashInventory:UpdateCashAmount(self) 
	 end
end

function SpaceStashInventory:UpdateCashAmount(self)
	self.wndMain:FindChild("CashWindow"):SetAmount(GameLib.GetPlayerCurrency(), true)
	self.wndMain:FindChild("CurrencyWindow"):SetAmount(GameLib.GetPlayerCurrency(self.tConfig.currencies.eCurrencyType):GetAmount())
end

---------------------------------------------------------------------------------------------------
-- SpaceStashInventory Commands 
---------------------------------------------------------------------------------------------------

-- on /ss console command
function SpaceStashInventory:OnSSCmd(strCommand, strParam)
	if strParam == "" then 
		SpaceStashInventory:OnVisibilityToggle(self)
	elseif strParam == "help" then 
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, "/ssi - toggle bag visibility\n/ssi help - show this help\n/ssi info - show a debug array\n/ssi option currency [ElderGems,Prestige,Renown,CraftingVouchers] - change the tracked currency")
	elseif strParam == "info" then 
		self.glog:info(self)
	elseif string.find(string.lower(strParam), "option") ~= nil then
		strParam = string.lower(strParam)
		local args = {}

		for arg in string.gmatch(strParam, "[%a%d]+") do table.insert(args, arg) end

		if args[2] == "currency" then
			local eType = tCurrencies[args[3]]
			if eType ~= nil then
				self.tConfig.currencies.eCurrencyType = eType
				self.wndMain:FindChild("CurrencyWindow"):SetMoneySystem(self.tConfig.currencies.eCurrencyType)
				SpaceStashInventory:UpdateCashAmount(self)
			else
				ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, args[3] .. " is not a valid currency[ElderGems,Prestige,Renown,CraftingVouchers]")
			end
		elseif args[2] == "squaresize" then
			local size = string.match(args[3],"%d+")
			if size ~= nil then
				self.tConfig.window.SquareSize = size
				SpaceStashInventory:UpdateWindowConfig(self)
				SpaceStashInventory:UpdateConfig(self)
			end
		elseif args[2] == "boxperrow" then
			local size = string.match(args[3],"%d+")
			if size ~= nil then
				self.tConfig.window.BoxPerRow = size
				SpaceStashInventory:UpdateWindowConfig(self)
				SpaceStashInventory:UpdateConfig(self)
			end
		end
	end
end
---------------------------------------------------------------------------------------------------
-- SpaceStashInventoryForm Visibility 
---------------------------------------------------------------------------------------------------
function SpaceStashInventory:OnKeyDown(wndHandler, wndControl, strKeyName, nCode, eModifier)

end

function  SpaceStashInventory:OnWindowMove(  )
	self.tConfig.window.location = self.wndMain:GetLocation():ToTable()
end

function SpaceStashInventory:OnSalvageButton()
	Event_FireGenericEvent("RequestSalvageAll", tAnchors)
end
-- calculation of the windows offets
function SpaceStashInventory:UpdateWindowConfig(self)
	self.tConfig.window.location.nOffsets[3] = self.tConfig.window.location.nOffsets[1] + self.tConfig.window.SquareSize * self.tConfig.window.BoxPerRow + 12
	
	local nInventorySize = 16
	local itemEquipped = GameLib.GetPlayerUnit():GetEquippedItems()

	for idx=1, #itemEquipped  do 
		if itemEquipped[idx]:GetBagSlots() > 0 then
			nInventorySize = nInventorySize + itemEquipped[idx]:GetBagSlots()
		end
	end

	local rowCount = math.floor(nInventorySize / self.tConfig.window.BoxPerRow)
	if nInventorySize % self.tConfig.window.BoxPerRow ~= 0 then rowCount = rowCount +1 end
	self.glog:info(rowCount)
	self.tConfig.window.location.nOffsets[4] = self.tConfig.window.location.nOffsets[2] + rowCount * self.tConfig.window.SquareSize + 24 + 54
end


-- when the Cancel button is clicked
function SpaceStashInventory:OnClose()
	SpaceStashInventory:OnVisibilityToggle(self)
end

function SpaceStashInventory:OnVisibilityToggle(self)
	if self.wndMain:IsShown() then
		self.wndMain:Show(false)
		Sound.Play(Sound.PlayUIBagClose)
	else
		SpaceStashInventory:UpdateCashAmount(self)
		self.wndMain:Show(true)

		Sound.Play(Sound.PlayUIBagOpen)
	end
end

function SpaceStashInventory:UpdateConfig(self)
	SpaceStashInventory:UpdateWindowConfig(self)
	self.wndMain:SetAnchorOffsets(self.tConfig.window.location.nOffsets[1],self.tConfig.window.location.nOffsets[2],self.tConfig.window.location.nOffsets[3],self.tConfig.window.location.nOffsets[4])
	self.wndMain:FindChild("BagWindow"):SetSquareSize(self.tConfig.window.SquareSize, self.tConfig.window.SquareSize) 
	self.wndMain:FindChild("BagWindow"):SetBoxesPerRow(self.tConfig.window.BoxPerRow)
	self.wndMain:FindChild("CurrencyWindow"):SetMoneySystem(self.tConfig.currencies.eCurrencyType)
	SpaceStashInventory:UpdateCashAmount(self)
end



function SpaceStashInventory:OnGenerateTooltip(wndControl, wndHandler, tType, item)
	if wndControl ~= wndHandler then return end
	wndControl:SetTooltipDoc(nil)
	if item ~= nil then
		local itemEquipped = item:GetEquippedItemForItemType()
		Tooltip.GetItemTooltipForm(self, wndControl, item, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
		-- Tooltip.GetItemTooltipForm(self, wndControl, itemEquipped, {bPrimary = false, bSelling = false, itemCompare = item})
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
	"Drafto:Lib:inspect-1.2",
	"GeminiConsole",
	"ImprovedSalvage"
})
 