require "Apollo"

-- Create the addon object and register it with Apollo in a single line.
local MAJOR, MINOR = "SpaceStashBank-Beta", 11



local tItemSlotBGPixie = {loc = {fPoints = {0,0,1,10},nOffsets = {0,0,0,0},},strSprite="WhiteFill", cr= "black",fRotation="0"}




-----------------------------------------------------------------------------------------------
-- Libraries
-----------------------------------------------------------------------------------------------
local GeminiLocale = Apollo.GetPackage("Gemini:Locale-1.0").tPackage
local SpaceStashBank, glog, LibDialog = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon("SpaceStashBank")
local L = GeminiLocale:GetLocale("SpaceStashBank", true)

SpaceStashBank.CodeEnumTabDisplay = {
  None = 0,
  BankBags = 1
}

local defaults = {}
defaults.profile = {}
defaults.profile.config = {}
defaults.profile.version = {}
defaults.profile.version.MAJOR = MAJOR
defaults.profile.version.MINOR = MINOR
defaults.profile.config.IconSize = 36
defaults.profile.config.RowSize = 10
defaults.profile.config.SelectedTab = SpaceStashBank.CodeEnumTabDisplay.None

-- Replaces MyAddon:OnLoad
function SpaceStashBank:OnInitialize()

  self.db = Apollo.GetPackage("Gemini:DB-1.0").tPackage:New(self, defaults, true)

  

  glog = Apollo.GetPackage("Gemini:Logging-1.2").tPackage:GetLogger({
    level = "INFO",
    pattern = "%d [%c:%n] %l - %m",
    appender = "Print"
  })

  LibDialog = Apollo.GetPackage("Gemini:LibDialog-1.0").tPackage

  LibDialog:Register("Confirm", {
    buttons = {
      {
        text = Apollo.GetString("CRB_Yes"),
        OnClick = function(settings, data, reason)
          self:OnBuyBankSlot()
        end,
      },
      {
        color = "Red",
        text = Apollo.GetString("CRB_No"),
        OnClick = function(settings, data, reason)
          
        end,
      },
    },
    OnCancel = function(settings, data, reason)
      if reason == "timeout" then
       
      end
    end,
    text = "Are you sure ?",
    duration = 10,
    showWhileDead=true,
  })
end

local bDocumentCreated = false

function SpaceStashBank:OnDocumentReady()
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "SpaceStashBankWindow", nil, self)

	if self.wndMain == nil then
		Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
		return
	end

	self.wndMain:Show(false)
	self.wndContentFrame = self.wndMain:FindChild("Content")
	self.wndPlayerMenu = self.wndMain:FindChild("BankPlayerMenu")
	self.wndPlayerMenu:FindChild("OptionsButton"):SetTooltip(L["SSOPTIONS_TOOLTIP"])
	self.wndTopFrame = self.wndMain:FindChild("TopFrame")
	self.wndMenuFrame = self.wndTopFrame:FindChild("MenuFrame")
	self.btnPlayerMenu = self.wndTopFrame:FindChild("PlayerMenuButton")
	self.btnBankBagsTab = self.wndTopFrame:FindChild("ShowBankBagsTabButton")
	self.btnClose = self.wndMenuFrame:FindChild("CloseButton")
	self.wndBankBagsTabFrame = self.wndTopFrame:FindChild("BankBagsTabFrame")
	self.wndBankBags = {
		self.wndBankBagsTabFrame:FindChild("ItemWidget1"),
		self.wndBankBagsTabFrame:FindChild("ItemWidget2"),
		self.wndBankBagsTabFrame:FindChild("ItemWidget3"),
		self.wndBankBagsTabFrame:FindChild("ItemWidget4"),
		self.wndBankBagsTabFrame:FindChild("ItemWidget5")
	}

	self.wndBankFrame = self.wndMain:FindChild("BankFrame")
	self.wndBank = self.wndBankFrame:FindChild("BankWindow")

	self.wndBottomFrame = self.wndMain:FindChild("BottomFrame")
	self.wndCash = self.wndMain:FindChild("CashWindow")
	self.wndNextBankBagCost = self.wndMain:FindChild("BankBuyPrice")

	self.xmlDoc = nil

	self.bottomFrameHeight = self.wndBottomFrame:GetHeight()
	self.wndCash:SetAmount(GameLib.GetPlayerCurrency(), true)

	self:UpdateBankBagSlots()
	self:UpdateTabState()
	self:OnIconSizeChange()
	self:UpdateWindowSize()

	GeminiLocale:TranslateWindow(L, self.wndMain)
	self.wndNextBankBagCost:SetAmount(GameLib.GetNextBankBagCost():GetAmount(), true)

	Event_FireGenericEvent("AddonFullyLoaded", {addon = self, strName = "SpaceStashBank"})  
end

-- Called when player has loaded and entered the world
function SpaceStashBank:OnEnable()
  
  Apollo.RegisterSlashCommand("ssb", "OnSlashCommand", self)
  Apollo.RegisterEventHandler("PlayerEquippedItemChanged", "OnEquippedItemChanged", self)
  Apollo.RegisterEventHandler("PlayerCurrencyChanged", "OnPlayerCurrencyChanged", self)
  Apollo.RegisterEventHandler("HideBank", "OnHideBank", self)
  Apollo.RegisterEventHandler("ShowBank", "OnShowBank", self)

  Apollo.RegisterEventHandler("WindowManagementReady", "OnWindowManagementReady", self)
  Apollo.RegisterEventHandler("WindowManagementAdd", "OnRover", self)
  self.xmlDoc = XmlDoc.CreateFromFile("SpaceStashBank.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function SpaceStashBank:OnWindowManagementReady()
  Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = "SpaceStashBank"})
end

function SpaceStashBank:OnRover(args)
  if args.strName == "Rover" then
    Event_FireGenericEvent("SendVarToRover", "SpaceStashBank", self)
  end
end


function SpaceStashBank:OnHideBank()
  self.wndMain:Show(false,true)
end

function SpaceStashBank:OnShowBank()
  self:OnIconSizeChange()
  self:UpdateWindowSize()
  self.wndMain:Show(true,true)  
end

function SpaceStashBank:OnPlayerCurrencyChanged()
  if self.wndCash then self.wndCash:SetAmount(GameLib.GetPlayerCurrency(), true) end
end

function SpaceStashBank:OnSlashCommand(strCommand, strParam)
  if strParam == "" then 
    self:OnShowBank()
  elseif strParam == "info" then 
    glog:info(self)
  end
end

function SpaceStashBank:UpdateTabState()
  if self.db.profile.config.SelectedTab == SpaceStashBank.CodeEnumTabDisplay.BankBags then
    self.topFrameHeight = self.wndMenuFrame:GetHeight() + self.wndBankBagsTabFrame:GetHeight()
    self.wndBankBagsTabFrame:Show(true)
    self.btnBankBagsTab:SetCheck(true)
  else
    self.topFrameHeight = self.wndMenuFrame:GetHeight()
    self.wndBankBagsTabFrame:Show(false)
    self.btnBankBagsTab:SetCheck(false)
  end
end

function SpaceStashBank:OnBankBagsTabChecked( wndHandler, wndControl, eMouseButton )
  self.db.profile.config.SelectedTab = SpaceStashBank.CodeEnumTabDisplay.BankBags
  self:UpdateTabState()

  self:OnIconSizeChange()
  self:UpdateWindowSize();
end

function SpaceStashBank:OnBankBagsTabUnhecked( wndHandler, wndControl, eMouseButton )
  self.db.profile.config.SelectedTab = SpaceStashBank.CodeEnumTabDisplay.None
  self:UpdateTabState()
  self:UpdateWindowSize();
end

function SpaceStashBank:OnBankPlayerMenuChecked( wndHandler, wndControl, eMouseButton )
  self.wndPlayerMenu:Show(true,false)
  self.wndPlayerMenu:ToFront(true)
end

function SpaceStashBank:OnBankPlayerMenuUnchecked( wndHandler, wndControl, eMouseButton )
  self:OnPlayerMenuClose()
end

function SpaceStashBank:OnPlayerMenuClose( wndHandler, wndControl )
  self.wndPlayerMenu:Show(false,true)
  self.btnPlayerMenu:SetCheck(false)
end

function SpaceStashBank:OnClose( wndHandler, wndControl, eMouseButton )
  Event_CancelBanking()
  self:OnHideBank()
end

function SpaceStashBank:UpdateBankBagSlots()
  local nBankBagSlots = GameLib.GetNumBankBagSlots()

  if nBankBagSlots > 0 then
    for k, v in ipairs(self.wndBankBags) do
      if k <= nBankBagSlots then
        v:Show(true)
        if v:FindChild("BuyBankSlotButton") then v:FindChild("BuyBankSlotButton"):Destroy() end
        
      elseif k == nBankBagSlots+1 then
        v:Show(true)
        v:FindChild("BuyBankSlotButton"):SetTooltip(L["BUYBANKBAGSLOT"])
      else
        v:Show(false)
      end
    end
  end

  if nBankBagSlots == 5 then
    if self.wndMain:FindChild("NextBagCost") then self.wndMain:FindChild("NextBagCost"):Destroy() end
    self.wndBottomFrame:FindChild("CashFrame"):SetAnchorOffsets(0,0,0,0)
    self.wndBottomFrame:FindChild("BankCashFrame"):SetAnchorOffsets(-256,-46,-8,-4)
    self.wndBottomFrame:SetAnchorOffsets(0,-50,0,0)
    
    SpaceStashBank:UpdateWindowSize()
  end
  self.wndBankBagsTabFrame:ArrangeChildrenHorz(0)
end

function SpaceStashBank:OnSlotButtonClick()
  LibDialog:Spawn("Confirm")
end

function SpaceStashBank:OnBuyBankSlot()
    GameLib.BuyBankBagSlot()
    self.wndNextBankBagCost:SetAmount(GameLib.GetNextBankBagCost():GetAmount(), true)
    self:UpdateBankBagSlots()

end

function SpaceStashBank:OnGenerateTooltip( wndControl, wndHandler, tType, item )
  if wndControl ~= wndHandler then return end
  wndControl:SetTooltipDoc(nil) 
  if item ~= nil then 
    local itemEquipped = item:GetEquippedItemForItemType()
    Tooltip.GetItemTooltipForm(self, wndControl, item, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
  end
end

function SpaceStashBank:OnGenerateBagTooltip( wndControl, wndHandler, tType, item )
  if wndControl ~= wndHandler then return end
  wndControl:SetTooltipDoc(nil)
  if item ~= nil then
    Tooltip.GetItemTooltipForm(self, wndControl, item, {bPrimary = true, bSelling = false})
  else
    wndControl:SetTooltip(wndControl:GetName() and (L["EMPTYSLOT"]) or "")
  end
end

function SpaceStashBank:OnBagDragDropCancel( wndHandler, wndControl, strType, iData, eReason, bDragDropHasBeenReset )

end

function SpaceStashBank:OnDragDropNothingCursor( wndHandler, wndControl, strType, iData )

end

function SpaceStashBank:OnEquippedItemChanged()
  self:OnRowSizeChange()
  self:UpdateWindowSize()
end

function SpaceStashBank:OnRowSizeChange()
  self.wndBank:SetBoxesPerRow(self.db.profile.config.RowSize)

  self.rowCount = math.floor(self.wndBank:GetBagCapacity() / self.db.profile.config.RowSize)
  if self.wndBank:GetBagCapacity() % self.db.profile.config.RowSize ~= 0 then self.rowCount = self.rowCount +1 end

end

function SpaceStashBank:OnIconSizeChange()

  self.wndBank:SetSquareSize(self.db.profile.config.IconSize, self.db.profile.config.IconSize)

  self.wndBankBagsTabFrame:SetAnchorOffsets(1,self.wndMenuFrame:GetHeight(),0,self.wndMenuFrame:GetHeight() + self.db.profile.config.IconSize )

  

  for k,v in ipairs(self.wndBankBags) do
  	v:SetAnchorOffsets(0,0,self.db.profile.config.IconSize,self.db.profile.config.IconSize)
  end
  self.wndBankBagsTabFrame:ArrangeChildrenHorz(0)

  if self.db.profile.config.SelectedTab == SpaceStashBank.CodeEnumTabDisplay.BankBags then
    self.topFrameHeight = self.wndMenuFrame:GetHeight() + self.wndBankBagsTabFrame:GetHeight()
  else
    self.topFrameHeight = self.wndMenuFrame:GetHeight()
  end

  self.wndTopFrame:SetAnchorOffsets(0,0,0,self.topFrameHeight)

  self:OnRowSizeChange()

end

function SpaceStashBank:OnOptions()
  Event_FireGenericEvent("SpaceStashCore_OpenOptions", self)
end

function SpaceStashBank:UpdateLocation()
  local x, y = self.wndMain:GetPos()

  self.wndMain:SetAnchorOffsets(
    x,
    y,
    x + self.nInventoryFrameWidth - self.leftOffset + self.rightOffset,
    y + self.nInventoryFrameHeight + self.bottomFrameHeight + self.topFrameHeight - self.topOffset + self.bottomOffset)

end

function SpaceStashBank:UpdateWindowSize()

  self.nInventoryFrameHeight = self.rowCount * self.db.profile.config.IconSize
  self.nInventoryFrameWidth = self.db.profile.config.IconSize * self.db.profile.config.RowSize

  self.leftOffset, self.topOffset, self.rightOffset, self.bottomOffset = self.wndContentFrame:GetAnchorOffsets()

  self.bottomFrameHeight = self.wndBottomFrame:GetHeight()

  self.wndBankFrame:SetAnchorOffsets(0,self.topFrameHeight-1,0,-self.bottomFrameHeight)

  for _,v in ipairs(self.wndBankBags) do
    local BagArtWindow = v:FindChild("BagArtWindow")
    BagArtWindow:DestroyAllPixies()

    if BagArtWindow:FindChild("Bag"):GetItem() then
      BagArtWindow:FindChild("Capacity"):SetText(BagArtWindow:FindChild("Bag"):GetItem():GetBagSlots())
      BagArtWindow:AddPixie(tItemSlotBGPixie)
    else
      BagArtWindow:FindChild("Capacity"):SetText()
    end

  end

  self:UpdateLocation()

end

-----------------------------------------------------------------------------------------------
-- SpaceStashBank Setters / Getters
-----------------------------------------------------------------------------------------------
function SpaceStashBank:SetIconsSize(nSize)
	self.db.profile.config.IconSize = nSize
	self:OnIconSizeChange()
	self:UpdateWindowSize()
end

function SpaceStashBank:GetIconsSize()
	return self.db.profile.config.IconSize
end

function SpaceStashBank:SetRowsSize(nSize)
	self.db.profile.config.RowSize = nSize
	self:OnRowSizeChange()
	self:UpdateWindowSize()
end

function SpaceStashBank:GetRowsSize()
	return self.db.profile.config.RowSize
end

function SpaceStashBank:SetSortMehtod(fSortMethod)
	if not fSortMethod then 
		self.wndBank:SetSort(false)
		return
	elseif type(fSortMethod) == "function" then
		self.wndBank:SetSort(true)
		self.wndBank:SetItemSortComparer(fSortMethod)
	end
end