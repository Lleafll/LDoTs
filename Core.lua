local addonName, addonTable = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addonName)


---------------
-- Libraries --
---------------
local ACR = LibStub("AceConfigRegistry-3.0")


--------------
-- Upvalues --
--------------
local UnitAura = UnitAura


---------------
-- Variables --
---------------
local auraFrames = {}
local auraFrameCache = {}


-------------------------
-- Aura Frame Dragging --
-------------------------
local function onEnterHandler(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine("LDoTs", 0.51, 0.31, 0.67, 1, 1, 1)
  GameTooltip:AddLine("dragFrameTooltip", 1, 1, 1, 1, 1, 1)
  GameTooltip:Show()
end

local function onLeaveHandler(self)
  GameTooltip:Hide()
end

local function onMouseDownHandler(self, button)
  if button == "LeftButton" then
    self:StartMoving()
  end
end

local function onMouseUpHandler(self, button)
  self:StopMovingOrSizing()
  local _, _, anchor, posX, posY = self:GetPoint()
  --self.db.anchor = anchor
  self.db.posX = posX
  self.db.posY = posY
  ACR:NotifyChange(addonName)
end

local function onMouseWheelHandler(self, delta)
  if IsShiftKeyDown() then
    self.db.posX = self.db.posX + delta
  else
    self.db.posY = self.db.posY + delta
  end
  self:SetPoint(self.db.anchor or "CENTER", self.db.posX, self.db.posY)  -- TODO: Check if it changes from CENTER
  ACR:NotifyChange(addonName)
end

local function frameUnlock(self)  -- TODO: Events should be supressed
  self:Show()
  self:SetMovable(true)
  self:SetScript("OnEnter", onEnterHandler)
  self:SetScript("OnLeave", onLeaveHandler)
  self:SetScript("OnMouseDown", onMouseDownHandler)
  self:SetScript("OnMouseUp", onMouseUpHandler)
  self:SetScript("OnMouseWheel", onMouseWheelHandler)
end

local function frameLock(self)
  self:SetMovable(false)  -- Necessary? 
  self:EnableMouse(false)  -- Necessary? 
  self:SetScript("OnEnter", nil)
  self:SetScript("OnLeave", nil)
  self:SetScript("OnMouseDown", nil)
  self:SetScript("OnMouseUp", nil)
  self:SetScript("OnMouseWheel", nil)
end


-------------------------------
-- Frame Factory and Caching --
-------------------------------
local function createAuraFrame()
  local frame = CreateFrame("Frame")
  
  frame.texture = frame:CreateTexture(nil, "BACKGROUND")
  frame.texture:SetAllPoints()
  
  frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  frame.cooldown:SetAllPoints()
  
  frame.Unlock = frameUnlock
  frame.Lock = frameLock
  
  return frame
end

local function getAuraFrame()
  local frame
  
  local auraFrameCacheLength = #auraFrameCache
  if #auraFrameCacheLength == 0 then
    frame = createAuraFrame()
  else
    frame = auraFrameCache[#auraFrameCacheLength]
    auraFrameCache[#auraFrameCacheLength] = nil
  end
  
  auraFrames[#auraFrames] = frame
  
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
  if event == "NAME_PLATE_UNIT_ADDED" then
    self.duration = nil
    self.expires = nil
  end
  
  local _, _, _, _, _, duration, expires = UnitAura(self.unitID, self.spellID, "PLAYER")
  if duration then
    if duration != self.duration or expires != self.expires then
      self:Show()
      self.cooldown:SetCooldown(expires - duration, duration)
      self.duration = duration
      self.expires = expires
    end
  else
    self:Hide()
  end
end

local function initializeFrame(frame)
  local db = frame.db
  
  frame:SetSize(db.width, db.height)
  frame:SetPoint("CENTER", db.posX, db.posY)
  
  frame.texture:SetTexture(select(3, GetSpellInfo(db.spellID)))
  
  frame:SetScript("OnEvent", auraEventHandler)
  frame:RegisterUnitEvent("UNIT_AURA", db.unitID)
  -- TODO: Add events based on unitID
end

local function buildFrames(db)
  for k, v in pairs(db) do
    local frame = getAuraFrame()
    frame.db = db
    initializeFrame(frame)
  end
end


--------------------
-- Initialization --
--------------------
function Addon:Build()
  wipeAuraFrames()
  buildFrames(self.db.class.auras)
  buildFrames(self.db.global.auras)
end