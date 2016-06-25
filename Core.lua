local addonName, addonTable = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addonName)



---------------
-- Libraries --
---------------
local LSM = LibStub('LibSharedMedia-3.0')



--------------
-- Upvalues --
--------------
local assert = assert
local GetItemInfo = GetItemInfo
local GetSpellCharges = GetSpellCharges
local GetSpellCooldown = GetSpellCooldown
local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local IsSpellKnown = IsSpellKnown
local loadstring = loadstring
local math_ceil = math.ceil
local SecureCmdOptionParse = SecureCmdOptionParse
local string_match = string.match
local table_sort = table.sort
local tonumber = tonumber
local tostring = tostring
local UnitAura = UnitAura
local wipe = wipe



---------------
-- Variables --
---------------
local auraFrames = {}
local auraFrameCache = {}
local generalDB
local groupFrames = {}
local groupFrameCache = {}



-------------------------
-- Aura Frame Dragging --
-------------------------
local function onEnterHandler(self)
  self.nameString:Show()
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine(addonName, 0.51, 0.31, 0.67, 1, 1, 1)
  GameTooltip:AddLine("|cFFcc0060Left mouse button|r to drag.\n|cFFcc0060Mouse wheel|r and |cFFcc0060shift + mouse wheel|r for fine adjustment.", 1, 1, 1, 1, 1, 1)
  GameTooltip:Show()
end

local function onLeaveHandler(self)
  self.nameString:Hide()
  GameTooltip:Hide()
end

local function onMouseDownHandler(self, button)
  if button == "LeftButton" then
    self:StartMoving()
  elseif button == "RightButton" then
    local db = self.db
    local tbl = getmetatable(db)  -- Get parent if multitarget frame
    tbl = tbl and tbl.__index or db
    tbl.hide = true
    Addon:Options()
  end
end

local function onMouseUpHandler(self, button)
  if button == "LeftButton" then
    self:StopMovingOrSizing()
    local _, _, anchor, posX, posY = self:GetPoint()
    self.db.anchor = anchor
    local UIScale = UIParent:GetScale()
    self.db.posX = math_ceil(posX / UIScale - 0.5)
    self.db.posY = math_ceil(posY / UIScale - 0.5)
    Addon:Options()
  end
end

local function onMouseWheelHandler(self, delta)
  if IsShiftKeyDown() then
    self.db.posX = self.db.posX + delta
  else
    self.db.posY = self.db.posY + delta
  end
  Addon:Options()
end

local function frameLock(self)
  self:SetMovable(false)  -- Necessary? 
  self:EnableMouse(false)  -- Necessary? 
  self:SetScript("OnEnter", nil)
  self:SetScript("OnLeave", nil)
  self:SetScript("OnMouseDown", nil)
  self:SetScript("OnMouseUp", nil)
  self:SetScript("OnMouseWheel", nil)
  self.nameString:Hide()
end

local function frameUnlock(self)  -- TODO: Events should be supressed
  self:Show()
  if self.db.hide then
    frameLock(self)
  else
    self:SetMovable(true)
    self:SetScript("OnEnter", onEnterHandler)
    self:SetScript("OnLeave", onLeaveHandler)
    self:SetScript("OnMouseDown", onMouseDownHandler)
    self:SetScript("OnMouseUp", onMouseUpHandler)
    self:SetScript("OnMouseWheel", onMouseWheelHandler)
    self.pandemicBorder:Hide()  
    self.nameString:SetText(self.db.name)
  end
end



-------------------------------------
-- Group Frame Factory and Caching --
-------------------------------------
local sortGroup = {}

sortGroup.Right = function(a, b)
  return a.db.posX < b.db.posX
end

sortGroup.Left = function(a, b)
  return a.db.posX > b.db.posX
end

sortGroup.Up = function(a, b)
  return a.db.posY < b.db.posY
end

sortGroup.Down = function(a, b)
  return a.db.posY > b.db.posY
end

local function positionIcons(self)
  local firstIcon = self.icons[1]
  if not firstIcon then
    return
  end
  local UIScale = UIParent:GetScale()
  local firstIconDB = firstIcon.db
  local anchor = firstIconDB.anchor
  local x = (firstIconDB.posX + (firstIconDB.width % 2 > 0 and 0.5 or 0)) * UIScale
  local y = (firstIconDB.posY + (firstIconDB.height % 2 > 0 and 0.5 or 0)) * UIScale
  local direction = self.db.direction
  for k, icon in pairs(self.icons) do
    if icon:IsShown() then
      local db = icon.db
      icon:ClearAllPoints()
      icon:SetPoint(anchor, x, y)
      if direction == "Right" then
        x = x + (db.width + 1) * UIScale
      elseif direction == "Left" then
        x = x - (db.width + 1) * UIScale
      elseif direction == "Up" then
        y = y + (db.height + 1) * UIScale
      elseif direction == "Down" then
        y = y - (db.height + 1) * UIScale
      end
    end
  end
end

local function lookupGroup(profileName, groupName)
  for k, v in pairs(groupFrames) do
    if v.db.name == groupName and v.profileName == profileName then
      return v
    end
  end
end

local function registerIconToGroup(icon, profileName, groupName)
  local group = lookupGroup(profileName, groupName)
  if group then
    local icons = group.icons
    icons[#icons+1] = icon
    table_sort(icons, sortGroup[group.db.direction])
    icon:SetScript("OnShow", function() positionIcons(group) end)
    icon:SetScript("OnHide", function() positionIcons(group) end)
    group:PositionIcons()
  else
    icon:SetScript("OnShow", nil)
    icon:SetScript("OnHide", nil)
  end
end

local function createGroupFrame()
  local frame = CreateFrame("Frame")
  frame.PositionIcons = positionIcons
  frame.RegisterIconToGroup = registerIconToGroup
  frame.icons = {}
  return frame
end

local function getGroupFrame()
  local frame
  
  local groupFrameCacheLength = #groupFrameCache
  if groupFrameCacheLength == 0 then
    frame = createGroupFrame()
  else
    frame = groupFrameCache[groupFrameCacheLength]
    groupFrameCache[groupFrameCacheLength] = nil
  end
  
  groupFrames[#groupFrames+1] = frame
  
  return frame
end

local function storeGroupFrame(frame)
  frame:Hide()
  frame:SetScript("OnEvent", nil)
  wipe(frame.icons)
  groupFrameCache[#groupFrameCache+1] = frame
end

local function wipeGroupFrames()
  for k, v in pairs(groupFrames) do
    storeGroupFrame(v)
    groupFrames[k] = nil
  end
end



------------------------------------
-- Icon Frame Factory and Caching --
------------------------------------
local backdrop = {
  bgFile = nil,
  edgeFile = LSM:Fetch('background', "Solid"),
  tile = false,
  edgeSize = 1,
  padding = 1
}
local pandemicBackdrop = {
  bgFile = nil,
  edgeFile = LSM:Fetch('background', "Solid"),
  tile = false,
  edgeSize = 1,
  padding = 1
}

local function createAuraFrame()
  local frame = CreateFrame("Frame")
  
  frame.texture = frame:CreateTexture(nil, "BACKGROUND")
  frame.texture:SetAllPoints()
  frame.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  
  frame.backdrop = CreateFrame("Frame", nil, frame)
  frame.backdrop:SetAllPoints()
  frame.backdrop:SetBackdrop(backdrop)
  frame.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
  local frameLevel = frame:GetFrameLevel()
  frame.backdrop:SetFrameLevel(frameLevel > 0 and (frameLevel - 1) or 0)
  
  frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  frame.cooldown:SetPoint("TOPLEFT", 1, -1)
  frame.cooldown:SetPoint("BOTTOMRIGHT", -1, 1)
  frame.cooldown:SetDrawEdge(false)
  frame.cooldown:SetDrawBling(false)
  
  frame.chargeCooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  frame.chargeCooldown:SetPoint("TOPLEFT", 1, -1)
  frame.chargeCooldown:SetPoint("BOTTOMRIGHT", -1, 1)
  frame.chargeCooldown:SetDrawSwipe(false)
  frame.chargeCooldown:SetDrawBling(false)
  
  frame.stacksStringParent = CreateFrame("Frame", nil, frame)
  frame.stacksStringParent:SetAllPoints()
  frame.stacksString = frame.stacksStringParent:CreateFontString()
  frame.stacksString:SetPoint("BOTTOMRIGHT", 0, 1)
  
  frame.pandemicBorder = CreateFrame("Frame", nil, frame)
  frame.pandemicBorder:SetAllPoints()
  frame.pandemicBorder:SetBackdrop(pandemicBackdrop)
  frame.pandemicBorder:SetBackdropBorderColor(0, 1, 0, 1)
  frame.pandemicBorder:Hide()
  
  frame.nameString = frame:CreateFontString()
  frame.nameString:SetPoint("CENTER")
  frame.nameString:SetWordWrap(true)
  
  frame.Unlock = frameUnlock
  frame.Lock = frameLock
  
  return frame
end

local function getAuraFrame()
  local frame
  
  local auraFrameCacheLength = #auraFrameCache
  if auraFrameCacheLength == 0 then
    frame = createAuraFrame()
  else
    frame = auraFrameCache[auraFrameCacheLength]
    auraFrameCache[auraFrameCacheLength] = nil
  end
  
  auraFrames[#auraFrames+1] = frame
  
  return frame
end

local function storeAuraFrame(frame)
  frame:Hide()
  frame:SetScript("OnEvent", nil)
  auraFrameCache[#auraFrameCache+1] = frame
end

local function wipeAuraFrames()
  for k, v in pairs(auraFrames) do
    storeAuraFrame(v)
    auraFrames[k] = nil
  end
end



-------------------
-- Aura Behavior --
-------------------
local function auraEventHandler(self, event, ...)
  if not self.visible then
    return
  end
  
  if event == "NAME_PLATE_UNIT_ADDED" or event == "PLAYER_TARGET_CHANGED"then
    self.duration = nil
    self.expires = nil
    self.pandemic = nil
    self.inPandemic = nil
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    self:Hide()
    return
  end
  
  local db = self.db
  local _, icon, count, duration, expires
  if db.auraType == "Buff" then
    _, _, icon, count, _, duration, expires = UnitBuff(db.unitID, db.spell, nil, db.ownOnly and "PLAYER" or nil)
  else
    _, _, icon, count, _, duration, expires = UnitDebuff(db.unitID, db.spell, nil, db.ownOnly and "PLAYER" or nil)
  end
  
  if duration then
    local pandemic
    local inPandemic
    if db.pandemic and expires > 0 then
      local timeStamp = GetTime()
      local pandemicExtra = db.pandemicExtra
      if db.pandemicHasted then
        pandemicExtra = pandemicExtra/ (1 + GetHaste() / 100)
        pandemicExtra = pandemicExtra < 1 and 1 or pandemicExtra
      end
      pandemic = duration * 0.3 + pandemicExtra  -- TODO: cache pandemic duration
      inPandemic = expires - timeStamp < pandemic
      if inPandemic then
        self.pandemicBorder:Show()
      else
        Addon:AddPandemicTimer(self, expires - pandemic)
        self.pandemicBorder:Hide()
      end
    end
  
    if duration ~= self.duration or expires ~= self.expires or pandemic ~= self.pandemic or inPandemic ~= self.inPandemic then
      self:Show()
      
      if not self.icon then
        self.texture:SetTexture(icon)
        local tbl = getmetatable(db)  -- Get parent if multitarget frame
        tbl = tbl and tbl.__index or db
        tbl.iconOverride = string_match(icon, "Interface\\Icons\\(.+)")
        self.icon = true
      end
      
      if expires > 0 then
        if db.pandemic then
          if inPandemic then
            self.cooldown:SetCooldown(expires - pandemic, pandemic)
          else
            if self.cooldown:GetCooldownDuration() then
              self.cooldown:SetCooldown(0, 0)
            end
            self.chargeCooldown:SetCooldown(expires - duration, duration - pandemic)
          end
        else
          self.cooldown:SetCooldown(expires - duration, duration)
        end
      elseif self.cooldown:GetCooldownDuration() then
        self.cooldown:SetCooldown(0, 0)
      end
      self.duration = duration
      self.expires = expires
    end
    
    if db.showStacks then
      self.stacksString:SetText(count)
    end
    
  else
    self:Hide()
  end
end

do
  local pandemicTimers = {}
  
  function Addon:AddPandemicTimer(frame, pandemic)    
    if not pandemicTimers[frame] or pandemicTimers[frame] ~= pandemic then
      pandemicTimers[frame] = pandemic
    end
  end
  
  function Addon:ClearPandemicTimers()
    for k, v in pairs(pandemicTimers) do
      pandemicTimers[k] = nil
    end
  end
  
  local pandemicTimer = CreateFrame("Frame")
  local totalElapsed = 0
  pandemicTimer:SetScript("OnUpdate", function(self, elapsed)
    totalElapsed = totalElapsed + elapsed
    if totalElapsed > 0.05 then
      local timeStamp = GetTime()
      for k, v in pairs(pandemicTimers) do
        if v < timeStamp then
          auraEventHandler(k)
          pandemicTimers[k] = nil
        end
      end
      totalElapsed = 0
    end
  end)
end



-----------------------
-- Cooldown Behavior --
-----------------------
local function cooldownEventHandler(self, event, ...)
  if not self.visible then
    return
  end
  
  local db = self.db
  
  local start, duration, enable
  local gcdStart, gcdDuration
  local stacks, maxStacks, stacksStart, stacksDuration
  if db.iconType == "Spell" then
    start, duration, enable = GetSpellCooldown(db.spell)
    gcdStart, gcdDuration = GetSpellCooldown(61304)
    stacks, maxStacks, stacksStart, stacksDuration = GetSpellCharges(db.spell)
  elseif db.iconType == "Item" then
    start, duration, enable = GetItemCooldown(self.itemID)
  end
  
  if start or gcdStart or (stacks and stacks < maxStacks) then
    self:Show()
    
    if stacks and stacks > 0 and stacks < maxStacks and (stacksStart ~= self.stacksStart or stacksDuration ~= self.stacksDuration) then
      self.chargeCooldown:SetCooldown(stacksStart, stacksDuration)
      self.stacksStart = stacksStart
      self.stacksDuration = stacksDuration
    end
    
    if not start or (gcdStart and start + duration < gcdStart + gcdDuration) then
      start = gcdStart
      duration = gcdDuration
    end
    if start ~= self.start or duration ~= self.duration then
      self.cooldown:SetCooldown(start, duration)
      self.start = start
      self.duration = duration
      if stacks and stacks == 0 and self.chargeCooldown:GetCooldownDuration() then
        self.chargeCooldown:SetCooldown(0, 0)
      end
    end
    
  else
    if not self.showOffCooldown then
      self:Hide()
    end
    
  end
  
  if self:IsShown() then
    if db.checkUsability then
      local usable = IsUsableSpell(db.spell)
      if usable then
        self.texture:SetVertexColor(1, 1, 1)
      else
        self.texture:SetVertexColor(0.25, 0.25, 0.25)
      end
      self.usable = usable
    end
    if db.showStacks and stacks ~= self.stacks then
      self.stacksString:SetText(stacks)
      self.stacks = stacks
    end
  end
end



-----------------------
-- Visibility Parser --
-----------------------
local function parseVisibility()
  for _, frame in pairs(auraFrames) do
    if frame.visibility then
      local action = SecureCmdOptionParse(frame.visibility)
      if action ~= "show" then
        if frame.visible then
          frame.visible = false
          frame:Hide()
        end
      elseif not frame.visible then
        frame.visible = true
        frame.eventHandler(frame)
      end
    end
  end
end

do
  local commandParseTimer = CreateFrame("Frame")
  
  local totalElapsed = 0
  commandParseTimer:SetScript("OnUpdate", function(self, elapsed)
    totalElapsed = totalElapsed + elapsed
    if totalElapsed > 0.1 then
      parseVisibility()
      totalElapsed = 0
    end
  end)
  
  -- Increase responsiveness
  commandParseTimer:RegisterEvent("PLAYER_TARGET_CHANGED")
  commandParseTimer:RegisterEvent("PLAYER_REGEN_DISABLED")
  commandParseTimer:SetScript("OnEvent", parseVisibility)
end



------------
-- Groups --
------------
local function initializeDynamicGroup(db, profileName)
  local frame = getGroupFrame()
  frame.db = db
  frame.profileName = profileName
end

local function buildGroups(profileDB)
  local db = profileDB.groups
  for k, v in pairs(db) do
    if v.groupType == "Dynamic Group" then
      initializeDynamicGroup(v, profileDB.profile)
    end
  end
end


-----------
-- Icons --
-----------
local function initializeFrame(frame, db, profileName)
  frame.db = db
  
  frame:Hide()
  local width = db.width
  local height = db.height
  local posX = db.posX + (width % 2 > 0 and 0.5 or 0)
  local posY = db.posY + (height % 2 > 0 and 0.5 or 0)
  local UIScale = UIParent:GetScale()
  frame:SetSize(width * UIScale, height * UIScale)
  frame:ClearAllPoints()
  frame:SetPoint(db.anchor, posX * UIScale, posY * UIScale)
  
  registerIconToGroup(frame, profileName, db.parent)
  
  local _, icon
  if db.iconOverride and db.iconOverride ~= "" then
    icon = "Interface\\Icons\\"..db.iconOverride
  end
  if icon then
    frame.icon = true
  else
    frame.icon = false
    icon = "Interface\\Icons\\ability_garrison_orangebird"
  end
  frame.texture:SetTexture(icon)
  frame.texture:SetVertexColor(1, 1, 1)
  frame.texture:Show()
  
  frame.pandemicBorder:Hide()
  
  if db.showStacks then
    frame.stacksString:Show()
    frame.stacksString:SetFont(LSM:Fetch("font", generalDB.font), 8, "OUTLINE")
  else
    frame.stacksString:Hide()
  end
  
  frame.cooldown:SetDrawSwipe(not db.hideSwirl)
  frame.cooldown:SetCooldown(0, 0)
  frame.chargeCooldown:SetDrawEdge(not db.hideSwirl)
  frame.chargeCooldown:SetCooldown(0, 0)
  
  frame.nameString:SetFont(LSM:Fetch("font", generalDB.font), 8, "OUTLINE")
  
  frame:UnregisterAllEvents()
  
  if Addon.unlocked then
    frame:Unlock()
    frame.visibility = nil
    frame.visible = true
    frame:SetScript("OnEvent", nil)
    if db.hide then
      frame.texture:Hide()
    end
  else
    frame:Lock()
    
    frame.visibility = db.visibility ~= "" and db.visibility or nil
    frame.visible = true
    
    if db.iconType == "Aura" then
      local c = generalDB.borderPandemicColor
      frame.pandemicBorder:SetBackdropBorderColor(c.r, c.b, c.g, c.a)
      
      local unitID = db.unitID
      frame:RegisterUnitEvent("UNIT_AURA", unitID)
      
      if string_match(unitID, "^target") then
        frame:RegisterEvent("PLAYER_TARGET_CHANGED")
      end
      
      local unitMatch, targetMatch = string_match(unitID, "^(.+)(target)$")
      if unitMatch and targetMatch then
        frame:RegisterUnitEvent("UNIT_TARGET", unitMatch)
      end
      
      if string_match(unitID, "^boss") then
        frame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
      end
      
      local nameplateMatch = string_match(unitID, "^nameplate%d")
      if nameplateMatch then
        frame:RegisterUnitEvent("NAME_PLATE_CREATED", nameplateMatch)
        frame:RegisterUnitEvent("NAME_PLATE_UNIT_ADDED", nameplateMatch)
        frame:RegisterUnitEvent("NAME_PLATE_UNIT_REMOVED", nameplateMatch)
      end
      
      if db.pandemic and db.pandemicExtra > 0 and db.pandemicHasted then
        frame:RegisterEvent("UNIT_SPELL_HASTE")
      end
      
      frame.eventHandler = auraEventHandler
      
    elseif db.iconType == "Spell" then
      local _, _, _, _, _, _, spellID = GetSpellInfo(db.spell)
      if spellID and (IsPlayerSpell(spellID) or IsSpellKnown(spellID)) then
        frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        frame:RegisterEvent("SPELL_UPDATE_USABLE")
        if db.showStacks then
          frame:RegisterEvent("SPELL_UPDATE_CHARGES")
        end
        frame:SetScript("OnEvent", cooldownEventHandler)
        if db.showOffCooldown then
          frame:Show()
        end
        frame.eventHandler = cooldownEventHandler
      else
        frame.eventHandler = function() end  -- Dummy function for easier code
        
      end
      
    elseif db.iconType == "Item" then
      local _, link = GetItemInfo(db.spell)
      if link then
        frame.itemID = tonumber(string_match(link, "item:(.-):"))
        frame:RegisterEvent("BAG_UPDATE_COOLDOWN")
        frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        if db.showOffCooldown then
          frame:Show()
        else
          frame:Hide()
        end
        frame.eventHandler = cooldownEventHandler
      else
        frame.eventHandler = function() end  -- Dummy function for easier code
      end
      
    end
    
    frame:SetScript("OnEvent", frame.eventHandler)
    frame:eventHandler()
    
    if db.OnUpdate and db.OnUpdate ~= "" then
      local onUpdateFunc = assert(loadstring("local self, elapsed = ...;"..db.OnUpdate))
      frame:SetScript("OnUpdate", onUpdateFunc)
      onUpdateFunc(frame, 100)
    end
    
  end
end

local function buildFrames(profileDB)
  local db = profileDB.auras
  for k, v in pairs(db) do
    if v.multitarget then
      for k2 = 1, v.multitargetCount do
        local v2 = v[tostring(k2)]
        if v2 and not v2.disable then
          setmetatable(v2, {__index = v})  -- Might be hacky and corrupt the database
          initializeFrame(getAuraFrame(), v2, profileDB.profile)
        end
      end
    else
      if not v.disable then
        initializeFrame(getAuraFrame(), v, profileDB.profile)
      end
    end
  end
  
  if not Addon.unlocked then
    parseVisibility()
  end
end



--------------------
-- Initialization --
--------------------
function Addon:Build()
  generalDB = self.db.global.options
  
  wipeGroupFrames()
  buildGroups(self.db.class)
  buildGroups(self.db.global)
  
  wipeAuraFrames()
  buildFrames(self.db.class)
  buildFrames(self.db.global)
  
  self:ClearPandemicTimers()
end