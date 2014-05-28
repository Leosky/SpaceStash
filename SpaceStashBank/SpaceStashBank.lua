require "Apollo"

-- Create the addon object and register it with Apollo in a single line.
local MAJOR, MINOR = "SpaceStashBank-Beta", 4

local CodeEnumTabDisplay = {
  None = 0,
  BankBags = 1
}

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
tDefaults.tConfig.SelectedTab = CodeEnumTabDisplay.None

local tItemSlotBGPixie = {loc = {fPoints = {0,0,1,10},nOffsets = {0,0,0,0},},strSprite="WhiteFill", cr= "black",fRotation="0"}

-----------------------------------------------------------------------------------------------
-- Libraries
-----------------------------------------------------------------------------------------------
local SpaceStashBank, GeminiLocale, GeminiGUI, GeminiLogging, inspect, glog, LibError = Apollo.GetPackage("Gemini:Addon-1.0").tPackage:NewAddon(tDefaults,"SpaceStashBank", false, {}), Apollo.GetPackage("Gemini:Locale-1.0").tPackage
local L = GeminiLocale:GetLocale("SpaceStashBank", true)

-- Replaces MyAddon:OnLoad
function SpaceStashBank:OnInitialize()
  Apollo.CreateTimer("SSBLoadingTimer", 5.0, false)
  Apollo.RegisterTimerHandler("SSBLoadingTimer", "OnLoadingTimer", self)
  self.xmlDoc = XmlDoc.CreateFromFile("SpaceStashBank.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)
  self.bWindowCreated = false
  self.bReady = false
  self.bSavedDataRestored = false
  GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage
  inspect = Apollo.GetPackage("Drafto:Lib:inspect-1.2").tPackage
  
end

function SpaceStashBank:OnLoadingTimer()
  Apollo.StopTimer("SSBLoadingTimer")

  if self.bSavedDataRestored == false and self.bWindowCreated == true then
  	glog:info("SpaceStashBank no data to restore.")
    self:OnSpaceStashBankReady()
  end
end

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
  self.bWindowCreated = true

  if self.bSavedDataRestored then 
    self:OnSpaceStashBankReady()
  end
end

-- Called when player has loaded and entered the world
function SpaceStashBank:OnEnable()
  glog = GeminiLogging:GetLogger({
    level = GeminiLogging.INFO,
    pattern = "%d [%c:%n] %l - %m",
    appender = "Print"
  })

  Apollo.RegisterEventHandler("HideBank", "OnHideBank", self)
  Apollo.RegisterEventHandler("ShowBank", "OnShowBank", self)

end

-- Replaces MyAddon:OnSave
function SpaceStashBank:OnSaveSettings(eLevel)
  if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then 
    return
  end

  return self.tConfig
end

-- Replaces MyAddon:OnRestore
function SpaceStashBank:OnRestoreSettings(eLevel, tSavedData)
  if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then 
    return
  elseif tSavedData == nil or tSavedData.version == nil or tSavedData.version.MAJOR ~= MAJOR then --change to corrupted save in general?

  elseif tSavedData.version.MINOR < MINOR then

  else
    self.tConfig = tSavedData
  end
  self.bSavedDataRestored = true

  if self.bWindowCreated then
    self:OnSpaceStashBankReady()
  end
end

function SpaceStashBank:OnSpaceStashBankReady()

  Apollo.RegisterSlashCommand("ssb", "OnSlashCommand", self)
  Apollo.RegisterEventHandler("BankSlotPurchased", "OnBankSlotPurchased", self)
  Apollo.RegisterEventHandler("PlayerEquippedItemChanged", "OnEquippedItemChanged", self)
  Apollo.RegisterEventHandler("PlayerCurrencyChanged", "OnPlayerCurrencyChanged", self)

  self.bottomFrameHeight = self.wndBottomFrame:GetHeight()
  self.wndNextBankBagCost:SetAmount(GameLib.GetNextBankBagCost():GetAmount(), true)
  self.wndCash:SetAmount(GameLib.GetPlayerCurrency(), true)

  local nBankBagSlots = GameLib.GetNumBankBagSlots()
  if nBankBagSlots > 0 then
    for k, v in ipairs(self.wndBankBags) do
      if k <= nBankBagSlots then
        v:Show(true)
        v:FindChild("BuyBankSlotButton"):Destroy()
      elseif k == nBankBagSlots +1 then
        v:Show(true)
        v:FindChild("BuyBankSlotButton"):SetTooltip(L["BUYBANKBAGSLOT"])
      end
    end
  end

  
  self:UpdateTabState()
  self:OnIconSizeChange()
  self:UpdateWindowSize()

  GeminiLocale:TranslateWindow(L, self.wndMain)

  self.bReady = true
  self.wndMain:Show(self.bEarlyShowBank,true)
end

function SpaceStashBank:OnHideBank()
  if self.bReady then
    
    self.wndMain:Show(false,true)
  else
    self.bEarlyShowBank = false
  end
end

function SpaceStashBank:OnShowBank()
  if self.bReady then
    self.wndMain:Show(true,true)  
  else
    self.bEarlyShowBank = true
  end
  
end

function SpaceStashBank:OnWindowMove()
  self.tConfig.location.x, self.tConfig.location.y = self.wndMain:GetPos()

end

function SpaceStashBank:OnPlayerCurrencyChanged()
  self.wndCash:SetAmount(GameLib.GetPlayerCurrency(), true)
end

function SpaceStashBank:OnSlashCommand(strCommand, strParam)
  if strParam == "" then 
    self:OnShowBank()
  elseif strParam == "info" then 
    glog:info(self)
  elseif string.find(string.lower(strParam), "option") ~= nil then
    
    local args = {}

    for arg in string.gmatch(strParam, "[%a%d]+") do table.insert(args, arg) end

    if string.lower(args[2]) == "rowsize" then
      local size = string.match(args[3],"%d+")
      if size ~= nil then
        self.tConfig.RowSize = size
        self:OnRowSizeChange()
        self:UpdateWindowSize()
      end
    elseif string.lower(args[2]) == "iconsize" then
      local size = string.match(args[3],"%d+")
      if size ~= nil then
        self.tConfig.IconSize = size
        self:OnIconSizeChange()
        self:UpdateWindowSize()
      end
    end
  end
end

function SpaceStashBank:UpdateTabState()
  if self.tConfig.SelectedTab == CodeEnumTabDisplay.BankBags then
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
  self.tConfig.SelectedTab = CodeEnumTabDisplay.BankBags
  self:UpdateTabState()

  self:OnIconSizeChange()
  self:UpdateWindowSize();
end

function SpaceStashBank:OnBankBagsTabUnhecked( wndHandler, wndControl, eMouseButton )
  self.tConfig.SelectedTab = CodeEnumTabDisplay.None
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

function SpaceStashBank:OnBuyBankSlot()

  GameLib.BuyBankBagSlot()
  self.wndNextBankBagCost:SetAmount(GameLib.GetNextBankBagCost():GetAmount(), true)
  local nBankBagSlots = GameLib.GetNumBankBagSlots()
  if nBankBagSlots ~= 5 then

    if nBankBagSlots > 0 then
      for k, v in ipairs(self.wndBankBags) do
        if k <= nBankBagSlots then
          v:Show(true)
          if v:FindChild("BuyBankSlotButton") then v:FindChild("BuyBankSlotButton"):Destroy() end
          
        elseif k == nBankBagSlots +1 then
          v:Show(true)
          v:FindChild("BuyBankSlotButton"):SetTooltip(L["BUYBANKBAGSLOT"])
        end
      end
    end

  else
    self.wndMain:FindChild("NextBagCost"):Destroy()
    self.wndBottomFrame:FindChild("CashFrame"):SetAnchorOffsets(0,0,0,0)
    self.wndBottomFrame:FindChild("BankCashFrame"):SetAnchorOffsets(-256,-46,-8,-4)
    self.wndBottomFrame:SetAnchorOffsets(0,-50,0,0)
    
    SpaceStashBank:UpdateWindowSize()
  end
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
  self.wndBank:SetBoxesPerRow(self.tConfig.RowSize)

  self.rowCount = math.floor(self.wndBank:GetBagCapacity() / self.tConfig.RowSize)
  if self.wndBank:GetBagCapacity() % self.tConfig.RowSize ~= 0 then self.rowCount = self.rowCount +1 end

end

function SpaceStashBank:OnIconSizeChange()

  self.wndBank:SetSquareSize(self.tConfig.IconSize, self.tConfig.IconSize)

  self.wndBankBagsTabFrame:SetAnchorOffsets(1,self.wndMenuFrame:GetHeight(),0,self.wndMenuFrame:GetHeight() + self.tConfig.IconSize )

  

  for k,v in ipairs(self.wndBankBags) do
  	v:SetAnchorOffsets(0,0,self.tConfig.IconSize,self.tConfig.IconSize)
  end
  self.wndBankBagsTabFrame:ArrangeChildrenHorz(0)

  if self.tConfig.SelectedTab == CodeEnumTabDisplay.BankBags then
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

  self.wndMain:SetAnchorOffsets(
    self.tConfig.location.x,
    self.tConfig.location.y,
    self.tConfig.location.x + self.nInventoryFrameWidth - self.leftOffset + self.rightOffset,
    self.tConfig.location.y + self.nInventoryFrameHeight + self.bottomFrameHeight + self.topFrameHeight - self.topOffset + self.bottomOffset)

end

function SpaceStashBank:UpdateWindowSize()

  self.nInventoryFrameHeight = self.rowCount * self.tConfig.IconSize
  self.nInventoryFrameWidth = self.tConfig.IconSize * self.tConfig.RowSize

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
  self.tConfig.IconSize = nSize
  self:OnIconSizeChange()
  self:UpdateWindowSize()
end

function SpaceStashBank:GetIconsSize()
  return self.tConfig.IconSize
end

function SpaceStashBank:SetRowsSize(nSize)
  self.tConfig.RowSize = nSize
  self:OnRowSizeChange()
  self:UpdateWindowSize()
end

function SpaceStashBank:GetRowsSize()
  return self.tConfig.RowSize
end