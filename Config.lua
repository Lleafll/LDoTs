local addonName, addonTable = ...
local Addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0")


---------------
-- Libraries --
---------------
local ACD = LibStub("AceConfigDialog-3.0")
local ADB = LibStub("AceDB-3.0")


--------------
-- Upvalues --
--------------
local math_ceil = math.ceil
local pairs = pairs
local string_match = string.match
local table_insert = table.insert
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


----------------------
-- Default Settings --
----------------------
local defaultSettings = {
  global = {
    auras = {},
    groups = {}
  },
  class = {
    auras = {},
    groups = {}
  }
}



-------------
-- Options --
-------------

--[[  
----  Pretty wasteful with table generation which isn't an issue with out-of-combat garbage collection
----  Widgets get recycled by AceConfig/AceGUI
]]-- 
 
local groupPool = {}  -- Store created group option for later reference by children (auras or other groups)
local renamedGroup = {}

local function getGroupParent(optionsParent, groupDB)
  local groupParent
  if groupDB.parent then
    groupParent = groupPool[optionsParent][groupDB.parent] and groupPool[optionsParent][groupDB.parent].args
  end
  if not groupParent then
    groupParent = groupPool[optionsParent]["Root"]
    groupDB.parent = "Root"
  end
  return groupParent
end

local function selectFromTree(parentDB, db)
  local path = {db.name}
  if parentDB == Addon.db.class.groups or parentDB == Addon.db.class.auras then
    groupDB = Addon.db.class.groups
  elseif parentDB == Addon.db.global.groups or parentDB == Addon.db.global.auras then
    groupDB = Addon.db.global.groups
  end
  
  while db and db.parent do
    table_insert(path, 1, db.parent)
    db = groupDB[db.parent]
  end
  
  if parentDB == Addon.db.class.groups or parentDB == Addon.db.class.auras then
    path[1] = "class"
  elseif parentDB == Addon.db.global.groups or parentDB == Addon.db.global.auras then
    path[1] = "global"
  end

  ACD:SelectGroup(addonName, unpack(path))
end

local function buildParentGroupOption(profileOptions, parentDB, childDB, order)
  local groupDB
  if (parentDB == Addon.db.class.auras) or (parentDB == Addon.db.class.groups) then
    groupDB = Addon.db.class.groups
  else  -- (db == Addon.db.global.auras) or (db == Addon.db.global.groups)
    groupDB = Addon.db.global.groups
  end
  
  local tbl = {
    order = order,
    name = "Parent Group",
    type = "select",
    values = {Root = "Root"},
    set = function(info, value)
      childDB[info[#info]] = value
      Addon:Build()
      selectFromTree(parentDB, childDB)
    end,
  }
  for k, v in pairs(groupDB) do
    if v ~= childDB then  -- don't include itself
      tbl.values[k] = k
    end
  end
  
  return tbl
end

local function addGroups(profileOptions, db)
  local order = #profileOptions + 1
  groupPool[profileOptions] = {}
  groupPool[profileOptions]["Root"] = profileOptions
  renamedGroup[profileOptions] = renamedGroup[profileOptions] or {}
  
  -- Group creation execute widget
  profileOptions.newGroup = {
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
    -- Check if parent group name has changed
    if renamedGroup[profileOptions].old == groupDB.parent then
      groupDB.parent = renamedGroup[profileOptions].new
    end
    
    local groupOptions = {
      order = order,
      name = groupName,
      type = "group",
      get = function(info)
        return groupDB[info[#info]]
      end,
      set = function(info, value)
        groupDB[info[#info]] = value
        Addon:Build()
      end,
      args = {
        parent = buildParentGroupOption(profileOptions, db, groupDB, 1.1),
        name = {
          order = 1,
          name = "Name",
          type = "input",
          validate = function(info, value)
            return (db[value] or value == "Root") and (addonName..": "..value.." already exists") or true
          end,
          get = function(info)
            return groupName
          end,
          set = function(info, value)
            renamedGroup[profileOptions] = {old = groupName, new = value}
            groupDB.name = value
            db[value] = groupDB
            db[groupName] = nil
            selectFromTree(db, groupDB)
            Addon:Build()
          end,
        },
        deleteGroup = {
          order = 100,
          name = "Delete Group",
          type = "execute",
          confirm = true,
          confirmText = "Delete "..groupName.."?",
          func = function()
            db[groupName] = nil
            Addon:Build()
          end,
        },
      }
    }
    
    profileOptions[groupName] = groupOptions.args
    groupPool[profileOptions][groupName] = groupOptions
    order = order + 1
  end
  
  -- Group options nesting
  for groupName, groupDB in pairsByKeys(db) do
    getGroupParent(profileOptions, groupDB)[groupName] = groupPool[profileOptions][groupName]
  end
end

local function addAuras(profileOptions, db)  
  local order = #profileOptions + 1
  
  profileOptions.newAura = {
    order = order,
    name = "New Aura",
    type = "execute",
    func = function(info)
      if db["New Aura"] then
        print(addonName..": New Aura already exists")
      else
        db["New Aura"] = {
          parent = "Root",
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
    -- Check if parent group name has changed
    if renamedGroup[profileOptions].old == auraDB.parent then
      auraDB.parent = renamedGroup[profileOptions].new
    end
    
    -- Get parent group according to db and add aura to it
    local groupParent = getGroupParent(profileOptions, auraDB)
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
        hide = {
          order = 0.11,
          name = "Hide",
          type = "toggle"
        },
        parent = buildParentGroupOption(profileOptions, db, auraDB, 0.12),
        disable = {
          order = 0.13,
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
            auraDB.name = value
            db[value] = auraDB
            db[auraName] = nil
            selectFromTree(db, auraDB)
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
            auraDB.spell = value
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
          confirm = true,
          confirmText = "Delete "..auraName.."?",
          func = function()
            db[auraName] = nil
            Addon:Build()
          end,
        },
      }
    }
    
    -- Add multi unit auras if applicable
    if auraDB.multitarget then      
      for i = 1, auraDB.multitargetCount do
        local childName = tostring(i)
        
        auraDB[childName] = auraDB[childName] or {}
        local childDB = auraDB[childName]
        childDB.name = auraDB.name.."\n"..auraDB.unitID..childName
        childDB.unitID = auraDB.unitID..childName
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
    
  -- Nil name check for renamed groups since we iterated over all auras
  renamedGroup[profileOptions] = nil
end

local optionsBaseTbl = {
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

local function options()
  wipe(optionsBaseTbl.args.class.args)
  wipe(optionsBaseTbl.args.global.args)
  wipe(groupPool)
  
  -- Class options
  addGroups(optionsBaseTbl.args.class.args, Addon.db.class.groups)
  addAuras(optionsBaseTbl.args.class.args, Addon.db.class.auras)
  -- Global options
  addGroups(optionsBaseTbl.args.global.args, Addon.db.global.groups)
  addAuras(optionsBaseTbl.args.global.args, Addon.db.global.auras)
  
  return optionsBaseTbl
end

LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options, "/"..addonName)


-----------------
-- Options GUI --
-----------------
ACD:SetDefaultSize(addonName, 800, 750)
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
function Addon:OnInitialize()
	self.db = ADB:New(addonName.."DB", defaultSettings, true)
  
  self:RegisterEvent("PLAYER_ENTERING_WORLD", function()  -- Delay so UIScale can be read
    Addon:Build()
    Addon:UnregisterEvent("PLAYER_ENTERING_WORLD")
  end)
end