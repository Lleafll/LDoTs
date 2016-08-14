local addonName, addonTable = ...
local Addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0")



---------------
-- Libraries --
---------------
local ACD = LibStub("AceConfigDialog-3.0")
local ADB = LibStub("AceDB-3.0")
local ASE = LibStub("AceSerializer-3.0")
local FIP = IndentationLib
local GUI = LibStub("AceGUI-3.0")
local LSM = LibStub('LibSharedMedia-3.0')



--------------
-- Upvalues --
--------------
local C_Timer_NewTimer = C_Timer.NewTimer
local GetItemInfo = GetItemInfo
local GetSpellInfo = GetSpellInfo
local math_ceil = math.ceil
local pairs = pairs
local string_match = string.match
local table_insert = table.insert
local table_sort = table.sort
local tostring = tostring
local wipe = wipe



---------------
-- Constants --
---------------
local CONTAINER_WIDTH = 800
local CONTAINER_HEIGHT = 750



---------------
-- Variables --
---------------
local groupPool = {}  -- Store created group option for later reference by children (auras or other groups)



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
      fontSize = 12,
      stacksAnchor = "BOTTOMRIGHT",
      stacksPosX = -1,
      stacksPosY = 1,
      borderPandemicColor = {r=1, b=0, g=0, a=1},
    },
    visibilityTemplates = {
    },
  },
  class = {
    profile = "class",
    auras = {
    },
    groups = {
    }
  }
}



--------------------
-- New Icon/Group --
--------------------
local function addGroupToDB(profileName, profileDB, groupDB, parent)
  local groupName
  if groupDB then
    groupName = groupDB.name
  else
    groupName = "New Group"
  end
  
  if profileDB[groupName] then
    local i = 2
    while profileDB[groupName..i] do
      i = i + 1
    end
    groupName = groupName..i
  end
  
  if auraDB then
    profileDB[groupName] = groupDB
  else
    profileDB[groupName] = {
      groupType = "Group",
      direction = "Right",
      posX = GetScreenWidth() / 2,
      posY = GetScreenHeight() / 2,
      unitID = "",
      distance = 33,
      multiunitCount = 5
    }
  end
  
  profileDB[groupName].parent = parent or "Root"
  profileDB[groupName].name = groupName
  
  ACD:SelectGroup(addonName, profileName, groupName)
  
  return groupName
end

local function addIconToDB(profileName, profileDB, auraDB, parent)
  local auraName
  if auraDB then
    auraName = auraDB.name
  else
    auraName = "New Icon"
  end
  
  if profileDB[auraName] then
    auraName = auraName.." "
    local i = 2
    while profileDB[auraName..i] do
      i = i + 1
    end
    auraName = auraName..i
  end
  
  if auraDB then
    profileDB[auraName] = auraDB
  else
    profileDB[auraName] = {
      spell = "",
      unitID = "target",
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
      visibility = "show",
      showMissing = false
    }
  end
  
  profileDB[auraName].parent = parent or "Root"
  profileDB[auraName].name = auraName
  
  ACD:SelectGroup(addonName, profileName, auraName)
end



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
--local customTextFrameEditBox

local function customTextFrameOnClose(widget)
  --FIP.disable(customTextFrameEditBox.editBox)
  GUI:Release(widget)
  customTextFrame = nil
  --customTextFrameEditBox = nil
end

local function buildEditBox(type, name, db, description)
  local box = GUI:Create(type)
  box:SetFullWidth(true)
  box:SetLabel(description)
  if db[name] then
    box:SetText(db[name])
  end
  box:SetCallback("OnEnterPressed", function(widget, event, text)
    db[name] = text
  end)
  customTextFrame:AddChild(box)
  return box
end

function Addon:OpenCustomTextFrame(name, db, parametersString, ...)
  if customTextFrame then
    customTextFrameOnClose(customTextFrame)
  end
  
  customTextFrame = GUI:Create("Frame")
  customTextFrame:SetTitle(name.." Custom Function")
  customTextFrame:SetWidth(CONTAINER_WIDTH)
  customTextFrame:SetWidth(CONTAINER_HEIGHT)
  customTextFrame:SetCallback("OnClose", customTextFrameOnClose)
  customTextFrame:SetLayout("List")
  GUI:SetFocus(customTextFrame)
  
  if ... then
    for k, v in ipairs({...}) do
      buildEditBox("EditBox", name..v, db, v)
    end
  end
  
  box = buildEditBox("MultiLineEditBox", name, db, "Passed parameters: "..parametersString)
  box:SetNumLines(25)
  FIP.enable(box.editBox, colorTable, 2)
  box:SetFocus()
  --customTextFrameEditBox = box
end


-----------------------
-- Export Icon Frame --
-----------------------
local customExportFrame
local customExportFrameEditBox

local function customExportFrameOnClose(widget)
  GUI:Release(widget)
  customExportFrame = nil
  customExportFrameEditBox = nil
end

function Addon:OpenCustomExportFrame(auraDB)
  if customExportFrame then
    customExportFrameOnClose(customExportFrame)
  end
  
  customExportFrame = GUI:Create("Frame")
  customExportFrame:SetTitle("Icon Export")
  customExportFrame:SetWidth(CONTAINER_WIDTH)
  customExportFrame:SetWidth(CONTAINER_HEIGHT)
  customExportFrame:SetCallback("OnClose", customExportFrameOnClose)
  customExportFrame:SetLayout("Fill")
  GUI:SetFocus(customExportFrame)
  
  local box = GUI:Create("MultiLineEditBox")
  box:DisableButton()
  box:SetLabel("Export Table")
  box:SetText("i"..ASE:Serialize(auraDB))
  box:HighlightText()
  box:SetFocus()
  customExportFrame:AddChild(box)
  customExportFrameEditBox = box
end



------------------
-- Import Frame --
------------------
local customImportFrame
local customImportFrameEditBox

local function customImportFrameOnClose(widget)
  GUI:Release(widget)
  customImportFrame = nil
  customImportFrameEditBox = nil
end

local function importIconFromString(profileName, profileDB, text, parent)
  local success, ret = ASE:Deserialize(text)
  if success then
    addIconToDB(profileName, profileDB.auras, ret, parent)
  else
    print(addonName..": "..ret)
  end
end

local function importGroupFromString(profileName, profileDB, text, parent)
  local success, ret = ASE:Deserialize(text)
  if success then
    return addGroupToDB(profileName, profileDB.groups, ret, parent)
  else
    print(addonName..": "..ret)
  end
end

local function importFromString(profileName, profileDB, text)
  local parent = {}
  for subStr in text:gmatch("%S+") do
    if subStr:find("^g") then
      parent[subStr:match("^g(%d-)|")] = importGroupFromString(profileName, profileDB, subStr, parent[subStr:match("|(%d-)%^")])
    elseif subStr:find("^i") then
      importIconFromString(profileName, profileDB, subStr, parent[subStr:match("^i(%d-)%^")])
    end
  end
  customImportFrameOnClose(customImportFrame)
  Addon:Options()
end

function Addon:OpenCustomImportFrame(profileName, profileDB)
  if customImportFrame then
    customImportFrameOnClose(customImportFrame)
  end
  
  customImportFrame = GUI:Create("Frame")
  customImportFrame:SetTitle("Icon Import")
  customImportFrame:SetWidth(CONTAINER_WIDTH)
  customImportFrame:SetWidth(CONTAINER_HEIGHT)
  customImportFrame:SetCallback("OnClose", customImportFrameOnClose)
  customImportFrame:SetLayout("Fill")
  GUI:SetFocus(customImportFrame)
  
  local box = GUI:Create("MultiLineEditBox")
  box:SetLabel("Paste Icon String")
  box:SetCallback("OnEnterPressed", function(widget, event, text)
    importFromString(profileName, profileDB, text)
  end)
  box:SetFocus()
  customImportFrame:AddChild(box)
  customImportFrameEditBox = box
end



------------------------
-- Export Group Frame --
------------------------
local customExportGroupFrame
local customExportGroupFrameEditBox

local function customExportGroupFrameOnClose(widget)
  GUI:Release(widget)
  customExportGroupFrame = nil
  customExportGroupFrameEditBox = nil
end

local function serializeGroupAndChildren(profileDB, groupDB)
  serializedGroupAndChildren = ""
  local groupNumber = 0
  
  local function addGroupToString(groupDB, parentGroupNumber)
    groupNumber = groupNumber + 1
    local thisGroupNumber = groupNumber
    
    serializedGroupAndChildren = serializedGroupAndChildren.." g"..thisGroupNumber.."|"..parentGroupNumber..ASE:Serialize(groupDB)
    for auraName, auraDB in pairs(profileDB.auras) do
      if auraDB.parent == groupDB.name then
        serializedGroupAndChildren = serializedGroupAndChildren.." i"..thisGroupNumber..ASE:Serialize(auraDB)
      end
    end
    for k, v in pairs(profileDB.groups) do
      if v.parent == groupDB.name then
        addGroupToString(v, thisGroupNumber)
      end
    end
  end
  
  addGroupToString(groupDB, groupNumber)
  
  return serializedGroupAndChildren
end

function Addon:OpenCustomExportGroupFrame(profileDB, groupDB)
  if customExportGroupFrame then
    customExportGroupFrameOnClose(customExportGroupFrame)
  end
  
  customExportGroupFrame = GUI:Create("Frame")
  customExportGroupFrame:SetTitle("Group Export")
  customExportGroupFrame:SetWidth(CONTAINER_WIDTH)
  customExportGroupFrame:SetWidth(CONTAINER_HEIGHT)
  customExportGroupFrame:SetCallback("OnClose", customExportGroupFrameOnClose)
  customExportGroupFrame:SetLayout("Fill")
  GUI:SetFocus(customExportGroupFrame)
  
  local box = GUI:Create("MultiLineEditBox")
  box:DisableButton()
  box:SetLabel("Export Table")
  box:SetText(serializeGroupAndChildren(profileDB, groupDB))
  box:HighlightText()
  box:SetFocus()
  customExportGroupFrame:AddChild(box)
  customExportGroupFrameEditBox = box
end



-------------
-- Options --
-------------

--[[  
----  Pretty wasteful with table generation which isn't an issue with out-of-combat garbage collection
----  Widgets get recycled by AceConfig/AceGUI
]]-- 

local function getGroupParent(profileName, groupDB)
  local groupParent
  if groupDB.parent then
    groupParent = groupPool[profileName][groupDB.parent] and groupPool[profileName][groupDB.parent].args
  end
  if not groupParent then
    groupParent = groupPool[profileName]["Root"]
    groupDB.parent = "Root"
  end
  return groupParent
end

-- Get dynamic ancestor group closest to root
function Addon:GetUltimateDynamicGroupParentName(iconDB, profileName)
  local profileGroups = self.db[profileName].groups
  local dynamicGroupParentName
  local groupParentName = iconDB.parent
  while groupParentName ~= "Root" do
    if profileGroups[groupParentName].groupType == "Dynamic" then
      dynamicGroupParentName = groupParentName
    end
    groupParentName = profileGroups[groupParentName].parent
  end
  return dynamicGroupParentName
end

-- Get nearest multiunit group ancestor
function Addon:GetMultiunitGroupParentName(iconDB, profileName)
  local profileGroups = self.db[profileName].groups
  local groupParentName = iconDB.parent
  while groupParentName ~= "Root" do
    if profileGroups[groupParentName].groupType == "Multiunit" then
      return groupParentName
    end
    groupParentName = profileGroups[groupParentName].parent
  end
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
  local order = #profileOptions + 1000  -- Insert Groups after icons
  groupPool[profileDB.profile] = {}
  groupPool[profileDB.profile]["Root"] = profileOptions
  
  -- Group creation execute widget
  profileOptions.newGroup = {
    order = order,
    name = "New Group",
    type = "execute",
    func = function(info)
      addGroupToDB(info[#info-1], db)
    end
  }
  order = order + 1
  
  -- Import (also for icon strings)
  profileOptions.import = {
    order = order,
    name = "Import",
    type = "execute",
    func = function(info)
      Addon:OpenCustomImportFrame(info[#info-1], profileDB)
    end,
  }
  order = order + 1
  
  -- Group options creation
  for groupName, groupDB in pairsByKeys(db) do
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
            for k, v in pairs(profileDB.auras) do
              if v.parent == groupName then
                v.parent = value
              end
            end
            for k, v in pairs(profileDB.groups) do
              if v.parent == groupName then
                v.parent = value
              end
            end
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
            ["Dynamic"] = "Dynamic Group",
            ["Multiunit"] = "Multiunit Group",
          }
        },
        unitID = {
          order = 3.1,
          name = "Multiunit ID",
          type = "input",
          hidden = groupDB.groupType ~= "Multiunit"
        },
        attachFrame = {
          order = 3.2,
          name = "Parent Frame",
          type = "input",
          hidden = groupDB.groupType ~= "Multiunit"
        },
        --[[multiunitCount = {
          order = 3.2,
          name = "Multiunit Count",
          type = "range",
          min = 1,
          softMax = 40,
          step = 1,
          hidden = groupDB.groupType ~= "Multiunit"
        },]]--
        direction = {
          order = 4,
          name = "Direction",
          type = "select",
          style = "dropdown",
          values = {
            ["Left"] = "Left",
            ["Right"] = "Right",
            ["Up"] = "Up",
            ["Down"] = "Down"
          },
          hidden = groupDB.groupType ~= "Dynamic",
        },
        posX = {
          order = 5,
          name = "X Position",
          type = "range",
          softMin = -math_ceil(GetScreenWidth()),
          softMax = math_ceil(GetScreenWidth()),
          step = 1,
          hidden = groupDB.groupType ~= "Dynamic"
        },
        posY = {
          order = 6,
          name = "Y Position",
          type = "range",
          softMin = -math_ceil(GetScreenHeight()),
          softMax = math_ceil(GetScreenHeight()),
          step = 1,
          hidden = groupDB.groupType ~= "Dynamic"
        },
        --[[distance = {
          order = 6.1,
          name = "Distance",
          type = "range",
          min = 0,
          softMax = 100,
          step = 1,
          hidden = groupDB.groupType ~= "Multiunit"
        },]]--
        templateHeader = {
          order = 7,
          name = "Templates",
          type = "header"
        },
        exportGroupHeader = {
          order = 7.9,
          name = "Export Group",
          type = "header"
        },
        exportGroup = {
          order = 8,
          name = "Export Group",
          type = "execute",
          func = function()
            Addon:OpenCustomExportGroupFrame(profileDB, groupDB)
          end,
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
    
    groupPool[profileDB.profile][groupName] = groupOptions
    order = order + 1
  end
  
  -- Group options nesting
  for groupName, groupDB in pairsByKeys(db) do
    getGroupParent(profileDB.profile, groupDB)[groupName] = groupPool[profileDB.profile][groupName]
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
      addIconToDB(info[#info-1], db)
    end
  }
  order = order + 1
  
  for auraName, auraDB in pairsByKeys(db) do   
    -- Get parent group according to db and add aura to it
    local groupParent = getGroupParent(profileDB.profile, auraDB)
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
          name = auraDB.iconType or "",
          type = "input",
          set = function(info, value)
            local numberValue = tonumber(value)
            if numberValue then
              value = numberValue
            else
              value = GetItemInfo(value) or value  -- Strip away link to make item more general
            end
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
        showMissing = {
          order = 3.1,
          name = auraDB.showMissing == true and "Always Show" or auraDB.showMissing == false and "Show When Applied" or "Show When Missing",
          type = "toggle",
          tristate = true,
          hidden = auraDB.iconType ~= "Aura"
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
          type = "select",
          style = "dropdown",
          values = function()
            local tbl = {
              ["show"] = "Show"
            }
            for k, v in pairs(Addon.db.global.visibilityTemplates) do
              tbl[k] = k
            end
            return tbl
          end,
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
        posX = {
          order = 11,
          name = "X Position",
          type = "range",
          softMin = -math_ceil(GetScreenWidth()),
          softMax = math_ceil(GetScreenWidth()),
          step = 1,
        },
        posY = {
          order = 12,
          name = "Y Position",
          type = "range",
          softMin = -math_ceil(GetScreenHeight()),
          softMax = math_ceil(GetScreenHeight()),
          step = 1,
        },
        customFunctionsheader = {
          order = 25,
          name = "Custom Functions",
          type = "header"
        },
        Stacks = {
          order = 26,
          name = auraDB.Stacks and auraDB.Stacks ~= "" and "|cFF00FF00Stacks|r" or "Stacks",
          type = "execute",
          func = function()
            Addon:OpenCustomTextFrame("Stacks", auraDB, "self, stacks")
          end
        },
        OnEvent = {
          order = 27,
          name = auraDB.OnEvent and auraDB.OnEvent ~= "" and "|cFF00FF00OnEvent|r" or "OnEvent",
          type = "execute",
          func = function()
            Addon:OpenCustomTextFrame("OnEvent", auraDB, "... (varargs passed by events, with self as first argument)")
          end
        },
        OnUpdate = {
          order = 28,
          name = auraDB.OnUpdate and auraDB.OnUpdate ~= "" and "|cFF00FF00OnUpdate|r" or "OnUpdate",
          type = "execute",
          func = function()
            Addon:OpenCustomTextFrame("OnUpdate", auraDB, "self, elapsed", "Interval")
          end
        },
        headerExport = {
          order = 29,
          name = "Export Aura",
          type = "header"
        },
        exportAura = {
          order = 30,
          name = "Export",
          type = "execute",
          func = function()
            Addon:OpenCustomExportFrame(auraDB)
          end,
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
    order = order + 1
  end
end

local function addOptions(profileOptions, profileDB)
  local db = profileDB.options
  
  profileOptions.options = {
    order = 12,
    type = "group",
    name = "General Options",
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
      fontSize = {
        order = 2,
        name = "Font Size",
        type = "range",
        min = 1,
        softMax = 32,
        step = 1
      },
      stacksHeader = {
        order = 10,
        name = "Stacks/Charges",
        type = "header"
      },
      stacksAnchor = {
        order = 11,
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
      stacksPosX = {
        order = 12,
        name = "X Offset",
        type = "range",
        softMin = -32,
        softMax = 32,
        step = 1,
      },
      stacksPosY = {
        order = 13,
        name = "Y Offset",
        type = "range",
        softMin = -32,
        softMax = 32,
        step = 1,
      },
      bordersHeader = {
        order = 20,
        name = "Borders",
        type = "header",
      },
      borderPandemicColor = {
        order = 21,
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
  
  profileOptions.visibilityTemplates = {
    order = 13,
    name = "Visibility Templates",
    type = "group",
    get = function(info)
      return db[info[#info]]
    end,
    set = function(info, value)
      db[info[#info]] = value
      Addon:Build()
    end,
    args = {
      addTemplate = {
        order = 1,
        type = "execute",
        name = "Add Template",
        func = function()
          if profileDB.visibilityTemplates["New Template"] then
            print(addonName..": 'New Template' already exists.")
          else
            profileDB.visibilityTemplates["New Template"] = ""
            ACD:SelectGroup(addonName, "visibilityTemplates", "New Template")
          end
        end
      }
    }
  }
  
  local templatesDB = profileDB.visibilityTemplates
  local order = #profileOptions.visibilityTemplates.args + 1
  for name, command in pairsByKeys(templatesDB) do
    profileOptions.visibilityTemplates.args[name] = {
      order = order,
      name = name,
      type = "group",
      args = {
        name = {
          order = 1,
          name = "Name",
          type = "input",
          validate = function(info, value)
            return templatesDB[value] and (addonName..": '"..value.."' already exists") or true
          end,
          get = function(info)
            return name
          end,
          set = function(info, value)
            for _, v in pairs(Addon.db.global.auras) do
              if v.visibility == name then
                v.visibility = value
              end
            end
            for _, v in pairs(Addon.db.class.auras) do
              if v.visibility == name then
                v.visibility = value
              end
            end
            templatesDB[value] = templatesDB[name]
            templatesDB[name] = nil
            ACD:SelectGroup(addonName, "visibilityTemplates", value)
          end,
        },
        newline = {
          order = 3,
          name = "",
          type = "description",
          width = "full"
        },
        command = {
          order = 11,
          name = "Command",
          type = "input",
          width = "full",
          set = function(info, value)
            templatesDB[name] = value
            Addon:Build()
          end,
          get = function()
            return command
          end
        },
        delete = {
          order = 21,
          name = "Delete Template",
          type = "execute",
          func = function()
            templatesDB[name] = nil
          end,
          confirm = true,
          confirmText = "Delete "..name.."?",
        },
      }      
    }
    
    order = order + 1
  end
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
-- Event Handling --
--------------------
do
  local equipmentChangedTimer
  
  local function delayBuild()
    equipmentChangedTimer = nil
    Addon:Build()
  end
  
  function Addon:PLAYER_EQUIPMENT_CHANGED()  -- Needs to be delayed because it gets spammed on set change (and EQUIPMENT_SWAP_FINISHED fires too early)
    if equipmentChangedTimer then
      equipmentChangedTimer:Cancel()
    end
    equipmentChangedTimer = C_Timer_NewTimer(0.1, delayBuild)
  end
end

function Addon:PLAYER_ENTERING_WORLD()
  -- Everything should be available, build icons
  self:Build()
  -- Hook CreateFrame to initialize icons w/o parent as soon as their parents are created
  hooksecurefunc("CreateFrame", self.CheckCreateFrameForParents)
  -- Register events which could make rebuilding icons necessary
  self:RegisterEvent("PLAYER_TALENT_UPDATE", "Build")
  self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end



--------------------
-- Initialization --
--------------------
function Addon:OnInitialize()
  -- Load addon settings
  self.db = ADB:New(addonName.."DB", defaultSettings, true)
  -- Delay building icons until later
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
end