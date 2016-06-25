local addonName, addonTable = ...
local Addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0")


---------------
-- Libraries --
---------------
local ACD = LibStub("AceConfigDialog-3.0")
local ADB = LibStub("AceDB-3.0")
local FIP = IndentationLib
local GUI = LibStub("AceGUI-3.0")
local LSM = LibStub('LibSharedMedia-3.0')


--------------
-- Upvalues --
--------------
local math_ceil = math.ceil
local pairs = pairs
local string_match = string.match
local table_insert = table.insert
local table_sort = table.sort
local tostring = tostring



---------------
-- Constants --
---------------
local CONTAINER_WIDTH = 800
local CONTAINER_HEIGHT = 750



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
    profile = "global",
    auras = {
    },
    groups = {
    },
    options = {
      font = "Friz Quadrata TT",
      borderPandemicColor = {r=1, b=0, g=0, a=1},
    }
  },
  class = {
    profile = "class",
    auras = {
    },
    groups = {
    }
  }
}



--------------------------------------
-- Extra Frame for Custom Functions --
--------------------------------------
-- Color Table copied from WeakAuras
local colorTable = {}
colorTable[IndentationLib.tokens.TOKEN_SPECIAL] = "|c00ff3333"
colorTable[IndentationLib.tokens.TOKEN_KEYWORD] = "|c004444ff"
colorTable[IndentationLib.tokens.TOKEN_COMMENT_SHORT] = "|c0000aa00"
colorTable[IndentationLib.tokens.TOKEN_COMMENT_LONG] = "|c0000aa00"
colorTable[IndentationLib.tokens.TOKEN_NUMBER] = "|c00ff9900"
colorTable[IndentationLib.tokens.TOKEN_STRING] = "|c00999999"
local tableColor = "|c00ff3333"
colorTable["..."] = tableColor
colorTable["{"] = tableColor
colorTable["}"] = tableColor
colorTable["["] = tableColor
colorTable["]"] = tableColor
local arithmeticColor = "|c00ff3333"
colorTable["+"] = arithmeticColor
colorTable["-"] = arithmeticColor
colorTable["/"] = arithmeticColor
colorTable["*"] = arithmeticColor
colorTable[".."] = arithmeticColor
local logicColor1 = "|c00ff3333"
colorTable["=="] = logicColor1
colorTable["<"] = logicColor1
colorTable["<="] = logicColor1
colorTable[">"] = logicColor1
colorTable[">="] = logicColor1
colorTable["~="] = logicColor1
local logicColor2 = "|c004444ff"
colorTable["and"] = logicColor2
colorTable["or"] = logicColor2
colorTable["not"] = logicColor2
colorTable[0] = "|r"

local customTextFrame
local customTextFrameEditBox

local function customTextFrameOnClose(widget)
  FIP.disable(customTextFrameEditBox.editBox)
  GUI:Release(widget)
  customTextFrame = nil
  customTextFrameEditBox = nil
end

function Addon:OpenCustomTextFrame(name, db, parametersString)
  if customTextFrame then
    customTextFrameOnClose(customTextFrame)
  end
  
  customTextFrame = GUI:Create("Frame")
  customTextFrame:SetTitle(name.." Custom Function")
  customTextFrame:SetWidth(CONTAINER_WIDTH)
  customTextFrame:SetWidth(CONTAINER_HEIGHT)
  customTextFrame:SetCallback("OnClose", customTextFrameOnClose)
  customTextFrame:SetLayout("Fill")
  GUI:SetFocus(customTextFrame)
  
  local box = GUI:Create("MultiLineEditBox")
  box:SetLabel("Passed parameters: "..parametersString)
  if db[name] then
    box:SetText(db[name])
  end
  box:SetCallback("OnEnterPressed", function(widget, event, text)
    db[name] = text
  end)
  FIP.enable(box.editBox, colorTable, 2)
  box:SetFocus()
  customTextFrame:AddChild(box)
  customTextFrameEditBox = box
end



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

local function selectFromTree(parentDB, profileDB, db)
  local path = {db.name}
  local groupDB = Addon.db[profileDB.profile].groups
  
  while db and db.parent do
    table_insert(path, 1, db.parent)
    db = groupDB[db.parent]
  end
  
  path[1] = profileDB.profile
  ACD:SelectGroup(addonName, unpack(path))
end

local function buildParentGroupOption(profileDB, parentDB, childDB, order)
  local groupDB = Addon.db[profileDB.profile].groups
  
  local tbl = {
    order = order,
    name = "Parent Group",
    type = "select",
    values = {Root = "Root"},
    set = function(info, value)
      childDB[info[#info]] = value
      Addon:Build()
      selectFromTree(parentDB, profileDB, childDB)
    end,
  }
  for k, v in pairs(groupDB) do
    if v ~= childDB then  -- don't include itself
      tbl.values[k] = k
    end
  end
  
  return tbl
end

local function addGroups(profileOptions, profileDB)
  local db = profileDB.groups
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
      if db["New Group"] then
        print(addonName..": 'New Group' already exists")
      else
        db["New Group"] = {
          groupType = "Group",
          direction = "Right",
          posX = GetScreenWidth() / 2,
          posY = GetScreenHeight() / 2
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
        name = {
          order = 1,
          name = "Name",
          type = "input",
          validate = function(info, value)
            return (db[value] or value == "Root") and (addonName..": '"..value.."' already exists") or true
          end,
          get = function(info)
            return groupName
          end,
          set = function(info, value)
            renamedGroup[profileOptions] = {old = groupName, new = value}
            groupDB.name = value
            db[value] = groupDB
            db[groupName] = nil
            selectFromTree(db, profileDB, groupDB)
            Addon:Build()
          end,
        },
        parent = buildParentGroupOption(profileDB, db, groupDB, 2),
        groupType = {
          order = 3,
          name = "Type",
          type = "select",
          style = "dropdown",
          values = {
            ["Group"] = "Group",
            ["Dynamic Group"] = "Dynamic Group"
          }
        },
        direction = {
          order = 4,
          name = "Direction",
          type = "select",
          style = "dropdown",
          hidden = groupDB.groupType ~= "Dynamic Group",
          values = {
            ["Left"] = "Left",
            ["Right"] = "Right",
            ["Up"] = "Up",
            ["Down"] = "Down"
          }
        },
        posX = {
          order = 5,
          name = "X Position",
          type = "range",
          min = -math_ceil(GetScreenWidth()),
          max = math_ceil(GetScreenWidth()),
          step = 1,
          hidden = groupDB.groupType ~= "Dynamic Group"
        },
        posY = {
          order = 6,
          name = "Y Position",
          type = "range",
          min = -math_ceil(GetScreenHeight()),
          max = math_ceil(GetScreenHeight()),
          step = 1,
          hidden = groupDB.groupType ~= "Dynamic Group"
        },
        deleteGroupHeader = {
          order = 99,
          name = "Delete Group",
          type = "header"
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

local function addAuras(profileOptions, profileDB)
  local db = profileDB.auras
  local order = #profileOptions + 1
  
  profileOptions.newAura = {
    order = order,
    name = "New Icon",
    type = "execute",
    func = function(info)
      if db["New Icon"] then
        print(addonName..": 'New Icon' already exists")
      else
        db["New Icon"] = {
          parent = "Root",
          name = "New Icon",
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
          --anchor = "CENTER",
          posX = GetScreenWidth() / 2,
          posY = GetScreenHeight() / 2,
        }
        ACD:SelectGroup(addonName, info[#info-1], "New Icon")
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
      icon = auraDB.iconOverride and auraDB.iconOverride ~= "" and (tonumber(auraDB.iconOverride) and auraDB.iconOverride or "Interface\\Icons\\"..auraDB.iconOverride) or "Interface\\Icons\\ability_garrison_orangebird",
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
        parent = buildParentGroupOption(profileDB, db, auraDB, 0.12),
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
            return db[value] and (addonName..": '"..value.."' already exists") or true
          end,
          get = function(info)
            return auraName
          end,
          set = function(info, value)
            auraDB.name = value
            db[value] = auraDB
            db[auraName] = nil
            selectFromTree(db, profileDB, auraDB)
            Addon:Build()
          end,
        },
        iconType = {
          order = 1.1,
          name = "Icon Type",
          type = "select",
          style = "dropdown",
          values = {
            ["Aura"] = "Aura",
            ["Spell"] = "Spell",
            ["Item"] = "Item"
          }
        },
        spell = {
          order = 1.2,
          name = "Spell",
          type = "input",
          set = function(info, value)
            local numberValue = tonumber(value)
            value = numberValue and numberValue or value
            auraDB.spell = value
            if not auraDB.iconOverride or auraDB.iconOverride == "" then
              local _, icon
              if auraDB.iconType == "Spell" or auraDB.iconType == "Aura" then
                _, _, icon = GetSpellInfo(value)
              elseif auraDB.iconType == "Item" then
                icon = GetItemIcon(value)
              end
              if icon then
                auraDB.iconOverride = string_match(icon, "Interface\\Icons\\(.+)") or string_match(icon, "Interface\\ICONS\\(.+)") or string_match(icon, "INTERFACE\\ICONS\\(.+)") or tostring(icon)
              end
            end
            Addon:Build()
          end,
        },
        unitID = {
          order = 2,
          name = "Unit ID",
          type = "input",
          hidden = auraDB.iconType ~= "Aura"
          -- TODO: Add validation
        },
        multitarget = {
          order = 2.1,
          name = "Multi Unit",
          type = "toggle",
          hidden = auraDB.iconType ~= "Aura"
        },
        multitargetCount = {
          order = 2.2,
          name = "Multi Unit Count",
          type = "range",
          min = 1,
          softMax = 20,
          step = 1,
          hidden = auraDB.iconType ~= "Aura" or not auraDB.multitarget
        },
        auraType = {
          order = 2.4,
          name = "Aura Type",
          type = "select",
          style = "dropdown",
          values = {
            ["Buff"] = "Buff",
            ["Debuff"] = "Debuff",
          },
          hidden = auraDB.iconType ~= "Aura"
        },
        ownOnly = {
          order = 3,
          name = "Own Only",
          type = "toggle",
          hidden = auraDB.iconType ~= "Aura"
        },
        showOffCooldown = {
          order = 3.1,
          name = "Show Off Cooldown",
          type = "toggle",
          hidden = auraDB.iconType ~= "Spell" and auraDB.iconType ~= "Item"
        },
        checkUsability = {
          order = 3.2,
          name = "Check Usability",
          type = "toggle",
          hidden = auraDB.iconType ~= "Spell"
        },
        headerVisibility = {
          order = 3.3,
          name = "Visibility",
          type = "header",
        },
        visibility = {
          order = 3.4,
          name = "Visibility",
          type = "input",
          width = "full",
          set = function(info, value)
            auraDB.visibility = value
            Addon:Build()
          end,
        },        
        headerPandemic = {
          order = 3.9,
          name = "Pandemic",
          type = "header",
          hidden = auraDB.iconType ~= "Aura"
        },
        pandemic = {
          order = 4,
          name = "Pandemic",
          type = "toggle",
          hidden = auraDB.iconType ~= "Aura"
        },
        pandemicExtra = {
          order = 4.1,
          name = "Add to Pandemic Duration",
          type = "range",
          min = 0,
          softMax = 10,
          step = 0.1,
          hidden = auraDB.iconType ~= "Aura" or not auraDB.pandemic
        },
        pandemicHasted = {
          order = 4.2,
          name = "Extra Pandemic Time is Hasted",
          type = "toggle",
          hidden = auraDB.iconType ~= "Aura" or not auraDB.pandemic or auraDB.pandemicExtra == 0
        },
        headerVisuals = {
          order = 4.4,
          name = "Visuals",
          type = "header"
        },
        iconOverride = {
          order = 4.5,
          name = "Icon",
          type = "input",
        },
        desaturated = {
          order = 4.6,
          name = "Desaturate",
          type = "toggle"
        },
        showStacks = {
          order = 4.7,
          name = "Show Stacks",
          type = "toggle",
        },
        --[[hideSwirl = {
          order = 4.6,
          name = "Hide Cooldown Swirl",
          type = "toggle",
        },]]--
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
        --[[anchor = {
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
        },]]--
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
        customFunctionsheader = {
          order = 25,
          name = "Custom Functions",
          type = "header"
        },
        Stacks = {
          order = 26,
          name = "Stacks",
          type = "execute",
          func = function() Addon:OpenCustomTextFrame("Stacks", auraDB, "self, stacks") end
        },
        OnEvent = {
          order = 27,
          name = "OnEvent",
          type = "execute",
          func = function() Addon:OpenCustomTextFrame("OnEvent", auraDB, "... (varargs passed by events, with self as first argument)") end
        },
        OnUpdate = {
          order = 28,
          name = "OnUpdate",
          type = "execute",
          func = function() Addon:OpenCustomTextFrame("OnUpdate", auraDB, "self, elapsed") end
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
            --[[anchor = {
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
            },]]--
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

local function addOptions(profileOptions, profileDB)
  local db = profileDB.options
  
  profileOptions.options = {
    order = 12,
    type = "group",
    name = "Options",
    get = function(info)
      return db[info[#info]]
    end,
    set = function(info, value)
      db[info[#info]] = value
      Addon:Build()
    end,
    args = {
      fontHeader = {
        order = 0.9,
        name = "Font",
        type = "header",
      },
      font = {
        order = 1,
        type = "select",
        name = "Font",
        dialogControl = "LSM30_Font",
        values = LSM:HashTable("font")
      },
      bordersHeader = {
        order = 10,
        name = "Borders",
        type = "header",
      },
      borderPandemicColor = {
        order = 11,
        name = "Pandemic Border Color",
        type = "color",
        hasAlpha = true,
        get = function()
          local r, b, g, a = db.borderPandemicColor.r, db.borderPandemicColor.b, db.borderPandemicColor.g, db.borderPandemicColor.a
          return r, b, g, a
        end,
        set = function(info, r, b, g, a)
          db.borderPandemicColor.r, db.borderPandemicColor.b, db.borderPandemicColor.g, db.borderPandemicColor.a = r, b, g, a
          Addon:Build()
        end
      },
    }
  }
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
    options = {}
  }
}

local function options()
  wipe(optionsBaseTbl.args.class.args)
  wipe(optionsBaseTbl.args.global.args)
  wipe(groupPool)
  
  -- Class
  addGroups(optionsBaseTbl.args.class.args, Addon.db.class)
  addAuras(optionsBaseTbl.args.class.args, Addon.db.class)
  -- Global
  addGroups(optionsBaseTbl.args.global.args, Addon.db.global)
  addAuras(optionsBaseTbl.args.global.args, Addon.db.global)
  
  -- Options
  addOptions(optionsBaseTbl.args, Addon.db.global)
  
  return optionsBaseTbl
end

LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options, "/"..addonName)


-----------------
-- Options GUI --
-----------------
ACD:SetDefaultSize(addonName, CONTAINER_WIDTH, CONTAINER_HEIGHT)
local optionsFrame = GUI:Create("Frame")  -- Create own container so we can register OnClose
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
    Addon:RegisterEvent("PLAYER_TALENT_UPDATE", "Build")
    Addon:UnregisterEvent("PLAYER_ENTERING_WORLD")
  end)
end
