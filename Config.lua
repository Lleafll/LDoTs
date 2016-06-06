local addonName, addonTable = ...
local Addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0")


---------------
-- Libraries --
---------------
local ACD = LibStub("AceConfigDialog-3.0")


--------------
-- Upvalues --
--------------
local math_ceil = math.ceil
local pairs = pairs
local string_match = string.match
local table_sort = table.sort


-------------
-- Utility --
-------------
local function pairsByKeys(t, f)  -- https://www.lua.org/pil/19.3.html
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table_sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end


-------------
-- Options --
-------------

--[[  
----  Pretty wasteful with table generation which isn't an issue with out-of-combat garbage collection
----  Widgets get recycled by AceConfig/AceGUI
]]-- 
 
local groupPool = {}  -- Store created group option for later reference by children (auras or other groups)

local function getGroupParent(optionsParent, groupDB)
  local groupParent = groupPool[optionsParent][groupDB.parent].args
  if not groupParent then
    groupParent = groupPool[optionsParent]["root"].args
    v.parent = nil
  end
  return groupParent
end

local function addGroups(parent, db)
  local order = #parent + 1
  groupPool[parent] = {}
  groupPool[parent]["root"] = parent
  
  -- Group creation execute widget
  parent.newGroup = {
    order = order,
    name = "New Group",
    type = "execute",
    func = function(info)
      if db["New Aura"] then
        print(addonName..": New Group already exists")
      else
        db["New Group"] = {
        }
        ACD:SelectGroup(addonName, info[#info-1], "New Group")
      end
    end
  }
  
  order = order + 1
  
  -- Group options creation
  for groupName, groupDB in pairsByKeys(db) do
    local groupOptions = {
      order = order,
      name = groupName,
      type = "group",
      args = {}
    }
    
    parent[groupName] = groupOptions.args
    groupPool[parent][groupName] = groupOptions
    order = order + 1
  end
  
  -- Group options nesting
  for groupName, groupDB in pairsByKeys(db) do
    getGroupParent(parent, groupDB)[groupName] = groupPool[parent][groupName]
  end
end

local function addAuras(optionsTbl, db)  
  local order = #optionsTbl + 1
  
  optionsTbl.newAura = {
    order = order,
    name = "New Aura",
    type = "execute",
    func = function(info)
      if db["New Aura"] then
        print(addonName..": New Aura already exists")
      else
        db["New Aura"] = {
          name = "New Aura",
          spell = "",
          unitID = "target",
          --multitarget = false,
          multitargetCount = 1,
          auraType = "Debuff",
          ownOnly = true,
          --showStacks = false,
          pandemic = true,
          pandemicExtra = 0,
          pandemicHasted = true,
          --hideSwirl = false,
          iconOverride = "",
          height = 32,
          width = 32,
          arrangePriority = "Horizontal-Vertical",
          arrangeRows = 1,
          arrangeXDistance = 33,
          arrangeYDistance = 33,
          anchor = "CENTER",
          posX = 0,
          posY = 0,
        }
        ACD:SelectGroup(addonName, info[#info-1], "New Aura")
      end
    end
  }
  
  order = order + 1
  
  for auraName, auraDB in pairsByKeys(db) do
    local groupParent = getGroupParent(optionsTbl, auraDB)
    groupParent[auraName] = {
      order = order,
      name = auraName,
      type = "group",
      icon = auraDB.iconOverride and auraDB.iconOverride ~= "" and "Interface\\Icons\\"..auraDB.iconOverride or "Interface\\Icons\\ability_garrison_orangebird",
      get = function(info)
        return auraDB[info[#info]]
      end,
      set = function(info, value)
        auraDB[info[#info]] = value
        Addon:Build()
      end,
      args = {
        -- dev
        parent = {
          order = 0.01,
          name = "Parent",
          type = "input"
        },
        -- end-dev
        disable = {
          order = 0.1,
          name = "Disable",
          type = "toggle"
        },
        auraConfigHeader = {
          order = 0.2,
          name = "Aura Config",
          type = "header"
        },
        name = {
          order = 0.3,
          name = "Name",
          type = "input",
          validate = function(info, value)
            return db[value] and (addonName..": "..value.." already exists") or true
          end,
          get = function(info)
            return auraName
          end,
          set = function(info, value)
            db[info[#info-1]][info[#info]] = value
            db[value] = auraDB
            db[auraName] = nil
            ACD:SelectGroup(addonName, info[#info-2], value)
            Addon:Build()
          end,
        },
        spell = {
          order = 1,
          name = "Spell",
          type = "input",
          set = function(info, value)
            local numberValue = tonumber(value)
            value = numberValue and numberValue or value
            db[info[#info-1]][info[#info]] = value
            if not auraDB.iconOverride or auraDB.iconOverride == "" then
              local _, _, icon = GetSpellInfo(value)
              if icon then
                auraDB.iconOverride = string_match(icon, "Interface\\Icons\\(.+)")
              end
            end
            Addon:Build()
          end,
        },
        unitID = {
          order = 2,
          name = "Unit ID",
          type = "input",
          -- TODO: Add validation
        },
        multitarget = {
          order = 2.1,
          name = "Multi Unit",
          type = "toggle"
        },
        multitargetCount = {
          order = 2.2,
          name = "Multi Unit Count",
          type = "range",
          min = 1,
          softMax = 20,
          step = 1,
          hidden = not auraDB.multitarget
        },
        auraType = {
          order = 2.4,
          name = "Aura Type",
          type = "select",
          style = "dropdown",
          values = {
            ["Buff"] = "Buff",
            ["Debuff"] = "Debuff",
          }
        },
        ownOnly = {
          order = 3,
          name = "Own Only",
          type = "toggle",
        },
        headerPandemic = {
          order = 3.9,
          name = "Pandemic Configuration",
          type = "header"
        },
        pandemic = {
          order = 4,
          name = "Pandemic",
          type = "toggle",
        },
        pandemicExtra = {
          order = 4.1,
          name = "Add to Pandemic Duration",
          type = "range",
          min = 0,
          softMax = 10,
          step = 0.1,
          hidden = not auraDB.pandemic
        },
        pandemicHasted = {
          order = 4.2,
          name = "Extra Pandemic Time is Hasted",
          type = "toggle",
          hidden = not auraDB.pandemic or auraDB.pandemicExtra == 0
        },
        headerVisuals = {
          order = 4.4,
          name = "Visuals",
          type = "header"
        },
        iconOverride = {
          order = 4.45,
          name = "Icon",
          type = "input",
        },
        showStacks = {
          order = 4.5,
          name = "Show Stacks",
          type = "toggle",
        },
        hideSwirl = {
          order = 4.6,
          name = "Hide Cooldown Swirl",
          type = "toggle",
        },
        height = {
          order = 5,
          name = "Icon Height",
          type = "range",
          min = 1,
          softMax = 100,
          step = 1
        },
        width = {
          order = 6,
          name = "Icon Width",
          type = "range",
          min = 1,
          softMax = 100,
          step = 1
        },
        headerPositioning = {
          order = 6.9,
          name = "Positioning",
          type = "header",
        },
        anchor = {
          order = 10,
          name = "Anchor",
          type = "select",
          style = "dropdown",
          values = {
            ["CENTER"] = "CENTER",
            ["BOTTOM"] = "BOTTOM",
            ["TOP"] = "TOP",
            ["LEFT"] = "LEFT",
            ["RIGHT"] = "RIGHT",
            ["BOTTOMLEFT"] = "BOTTOMLEFT",
            ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
            ["TOPLEFT"] = "TOPLEFT",
            ["TOPRIGHT"] = "TOPRIGHT"
          },
          hidden = auraDB.multitarget
        },
        posX = {
          order = 11,
          name = "X Position",
          type = "range",
          min = -math_ceil(GetScreenWidth()),
          max = math_ceil(GetScreenWidth()),
          step = 1,
          hidden = auraDB.multitarget
        },
        posY = {
          order = 12,
          name = "Y Position",
          type = "range",
          min = -math_ceil(GetScreenHeight()),
          max = math_ceil(GetScreenHeight()),
          step = 1,
          hidden = auraDB.multitarget
        },
        arrangeInGrid = {
          order = 20,
          name = "Arrange Icons",
          type = "execute",
          hidden = not auraDB.multitarget,
          func = function()
            local i = 1
            local xOffset = 0
            local yOffset = 0
            if auraDB.arrangePriority == "Horizontal-Vertical" then
              local columns = math_ceil(auraDB.multitargetCount / auraDB.arrangeRows)
              for m = 1, auraDB.arrangeRows do
                for n = 1, columns do
                  local numberString = tostring(i)
                  auraDB[numberString].anchor = auraDB["1"].anchor
                  auraDB[numberString].posX = auraDB["1"].posX + xOffset
                  auraDB[numberString].posY = auraDB["1"].posY + yOffset
                  xOffset = xOffset + auraDB.arrangeXDistance
                  i = i + 1
                  if i > auraDB.multitargetCount then
                    Addon:Build()
                    return
                  end
                end
                xOffset = 0
                yOffset = yOffset + auraDB.arrangeYDistance
              end
            else
              
            end
          end,          
        },
        arrangePriority = {
          order = 21,
          name = "Arrange Priority",
          type = "select",
          style = "dropdown",
          values = {
            ["Horizontal-Vertical"] = "Horizontal-Vertical",
            ["Vertical-Horizontal"] = "Vertical-Horizontal",
          },
          hidden = not auraDB.multitarget,
        },
        arrangeRows = {
          order = 22,
          name = "No. of Rows for Arranging",
          type = "range",
          min = 1,
          max = auraDB.multitargetCount,
          step = 1,
          hidden = not auraDB.multitarget,
        },
        arrangeXDistance = {
          order = 23,
          name = "X Distance for Arranging",
          type = "range",
          softMin = -100,
          softMax = 100,
          step = 1,
          hidden = not auraDB.multitarget,
        },
        arrangeYDistance = {
          order = 24,
          name = "Y Distance for Arranging",
          type = "range",
          softMin = -100,
          softMax = 100,
          step = 1,
          hidden = not auraDB.multitarget,
        },
        headerDelete = {
          order = 99,
          name = "Delete Aura",
          type = "header"
        },
        deleteAura = {
          order = 100,
          name = "Delete Aura",
          type = "execute",
          func = function()
            db[auraName] = nil
            Addon:Build()
          end,
        },
      }
    }
    
    if auraDB.multitarget then      
      for i = 1, auraDB.multitargetCount do
        local childName = tostring(i)
        
        auraDB[childName] = auraDB[childName] or {}
        local childDB = auraDB[childName]
        childDB.name = auraDB.name.."\n"..auraDB.unitID..name
        childDB.unitID = auraDB.unitID..name
        setmetatable(childDB, {__index = auraDB})  -- Might be hacky and corrupt the database
        
        groupParent[auraName].args[childName] = {
          order = i,
          name = childName,
          type = "group",
          get = function(info)
            return childDB[info[#info]]
          end,
          set = function(info, value)
            childDB[info[#info]] = value
            Addon:Build()
          end,
          args = {
            headerPositioning = {
              order = 6.9,
              name = "Positioning",
              type = "header",
            },
            anchor = {
              order = 10,
              name = "Anchor",
              type = "select",
              style = "dropdown",
              values = {
                ["CENTER"] = "CENTER",
                ["BOTTOM"] = "BOTTOM",
                ["TOP"] = "TOP",
                ["LEFT"] = "LEFT",
                ["RIGHT"] = "RIGHT",
                ["BOTTOMLEFT"] = "BOTTOMLEFT",
                ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                ["TOPLEFT"] = "TOPLEFT",
                ["TOPRIGHT"] = "TOPRIGHT"
              },
            },
            posX = {
              order = 11,
              name = "X Position",
              type = "range",
              min = -math_ceil(GetScreenWidth()),
              max = math_ceil(GetScreenWidth()),
              step = 1,
            },
            posY = {
              order = 12,
              name = "Y Position",
              type = "range",
              min = -math_ceil(GetScreenHeight()),
              max = math_ceil(GetScreenHeight()),
              step = 1,
            }
          }
        }
      end
    end
    
    order = order + 1
  end
end

local function options()
  local tbl = {
    type = "group",
		name = addonName,
		childGroups = "tab",
		args = {
      class = {
        order = 10,
        type = "group",
        name = "Class Auras",
        childGroups = "tree",
        args = {}
      },
      global = {
        order = 11,
        type = "group",
        name = "Global Auras",
        childGroups = "tree",
        args = {}
      },
    }
  }
  
  wipe(groupPool)
  -- Class options
  addGroups(tbl.args.class.args, Addon.db.class.groups)
  addAuras(tbl.args.class.args, Addon.db.class.auras)
  -- Global options
  addGroups(tbl.args.class.args, Addon.db.global.groups)
  addAuras(tbl.args.global.args, Addon.db.global.auras)
  
  return tbl
end

LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options, "/"..addonName)


-----------------
-- Options GUI --
-----------------
ACD:SetDefaultSize(addonName, 800, 700)
local optionsFrame = LibStub("AceGUI-3.0"):Create("Frame")  -- Create own container so we can register OnClose
optionsFrame:Hide()
optionsFrame:SetCallback("OnClose", function()
  Addon.unlocked = nil
  Addon:Build()
end)
function Addon:Options()
  self:Build()
  ACD:Open(addonName, optionsFrame)  -- Also use for refresh (ACD:NotifyChange() - which does not work with custom containers - would do the same)
end


------------------
-- Chat Command --
------------------
function Addon:HandleChatCommand(input)
  if ACD.OpenFrames[addonName] then  -- TODO: Check why this works
		ACD:Close(addonName)
	else
    self.unlocked = true
		self:Options()
	end
end

Addon:RegisterChatCommand(addonName, "HandleChatCommand")


--------------------
-- Initialization --
--------------------
local defaultSettings = {
  global = {
    auras = {},
    groups = {
    }
  },
  class = {
    auras = {},
    groups = {
    }
  }
}

function Addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New(addonName.."DB", defaultSettings, true)
  
  self:RegisterEvent("PLAYER_ENTERING_WORLD", function()  -- Delay so UIScale can be read
    Addon:Build()
    Addon:UnregisterEvent("PLAYER_ENTERING_WORLD")
  end)
end