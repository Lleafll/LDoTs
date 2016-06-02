local addonName, addonTable = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addonName)


--------------
-- Upvalues --
--------------


---------------
-- Functions --
---------------
local function createAuraFrame()
  local frame = CreateFrame("Frame")
  frame.texture = frame:CreateTexture(nil, "BACKGROUND")
  frame.texture:SetAllPoints()
  frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  frame.cooldown:SetAllPoints()
end

local auraFrameCache = {}
local function getAuraFrame()
  local frame
  local auraFrameCacheLength = #auraFrameCache
  if #auraFrameCacheLength == 0 then
    frame = createAuraFrame()
  else
    frame = auraFrameCache[#auraFrameCacheLength]
    auraFrameCache[#auraFrameCacheLength] = nil
  end
  return frame
end

local function SetFrame()
  
end

function Addon:Build()
  
end