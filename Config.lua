local addonName, addonTable = ...
local Addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0")


--------------
-- Upvalues --
--------------
local math_ceil = math.ceil
local pairs = pairs
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
local function addAuras(tbl, db)  
  local order = #tbl + 1
  
  tbl.newAura = {
    order = order,
    name = "New Aura",
    type = "execute",
    func = function()
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
          height = 30,
          width = 30,
          arrangePriority = "Horizontal-Vertical",
          arrangeRows = 1,
          arrangeXDistance = 32,
          arrangeYDistance = 32,
          anchor = "CENTER",
          posX = 0,
          posY = 0,
        }
      end
    end
  }
  
  order = order + 1
    
  local anchor = {
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
    }
  }
  local posX = {
    order = 11,
    name = "X Position",
    type = "range",
    min = -math_ceil(GetScreenWidth()),
    max = math_ceil(GetScreenWidth()),
    step = 1
  }
  local posY = {
    order = 12,
    name = "Y Position",
    type = "range",
    min = -math_ceil(GetScreenHeight()),
    max = math_ceil(GetScreenHeight()),
    step = 1
  }
  
  for k, v in pairsByKeys(db) do
    tbl[k] = {
      order = order,
      name = k,
      type = "group",
      get = function(info)
        return db[info[#info-1]][info[#info]]
      end,
      set = function(info, value)
        db[info[#info-1]][info[#info]] = value
        Addon:Build()
      end,
      args = {
        auraConfig = {
          order = 0.1,
          name = "Aura Config",
          type = "header"
        },
        name = {
          order = 0.2,
          name = "Name",
          type = "input",
          validate = function(info, value)
            return db[value] and (addonName..": "..value.." already exists") or true
          end,
          get = function(info)
            return k
          end,
          set = function(info, value)
            db[info[#info-1]][info[#info]] = value
            db[value] = v
            db[k] = nil
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
          name = "Multitarget",
          type = "toggle"
        },
        multitargetCount = {
          order = 2.2,
          name = "Multitarget Count",
          type = "range",
          min = 1,
          softMax = 20,
          step = 1,
          hidden = not v.multitarget
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
          hidden = not v.pandemic
        },
        pandemicHasted = {
          order = 4.2,
          name = "Extra Pandemic Time is Hasted",
          type = "toggle",
          hidden = not v.pandemic
        },
        headerVisuals = {
          order = 4.4,
          name = "Visuals",
          type = "header"
        },
        iconOverride = {
          order = 4.45,
          name = "Icon Override",
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
        anchor = anchor,
        posX = posX,
        posY = posY,
        arrangeInGrid = {
          order = 20,
          name = "Arrange Icons",
          type = "execute",
          hidden = not v.multitarget,
          func = function()
            local i = 1
            local xOffset = 0
            local yOffset = 0
            if v.arrangePriority == "Horizontal-Vertical" then
              local columns = math_ceil(v.multitargetCount / v.arrangeRows)
              for m = 1, v.arrangeRows do
                for n = 1, columns do
                  local numberString = tostring(i)
                  v[numberString].anchor = v.anchor
                  v[numberString].posX = v.posX + xOffset
                  v[numberString].posY = v.posY + yOffset
                  xOffset = xOffset + v.arrangeXDistance
                  i = i + 1
                  if i > v.multitargetCount then
                    Addon:Build()
                    return
                  end
                end
                xOffset = 0
                yOffset = yOffset + v.arrangeYDistance
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
          hidden = not v.multitarget,
        },
        arrangeRows = {
          order = 22,
          name = "No. of Rows for Arranging",
          type = "range",
          min = 1,
          max = v.multitargetCount,
          step = 1,
          hidden = not v.multitarget,
        },
        arrangeXDistance = {
          order = 23,
          name = "X Distance for Arranging",
          type = "range",
          softMin = -100,
          softMax = 100,
          step = 1,
          hidden = not v.multitarget,
        },
        arrangeYDistance = {
          order = 24,
          name = "Y Distance for Arranging",
          type = "range",
          softMin = -100,
          softMax = 100,
          step = 1,
          hidden = not v.multitarget,
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
            db[k] = nil
            Addon:Build()
          end,
        },
      }
    }
    
    if v.multitarget then
      for i = 1, v.multitargetCount do
        local name = tostring(i)
        
        v[name] = v[name] or {}
        v[name].name = v.name.."\n"..name
        v[name].unitID = v.unitID..name
        setmetatable(v[name], {__index = v})  -- Might be hacky and corrupt the database
        
        tbl[k].args[name] = {
          order = i,
          name = name,
          type = "group",
          get = function(info)
            return db[info[#info-2]][info[#info-1]][info[#info]]
          end,
          set = function(info, value)
            local dbParent = db[info[#info-2]]
            local dbChild = dbParent[info[#info-1]] or {}
            dbChild[info[#info]] = value
            Addon:Build()
          end,
          args = {
            anchor = anchor,
            posX = posX,
            posY = posY,
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
  
  addAuras(tbl.args.class.args, Addon.db.class.auras)
  addAuras(tbl.args.global.args, Addon.db.global.auras)
  
  return tbl
end

LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options, "/"..addonName)


-----------------
-- Options GUI --
-----------------
local ACD = LibStub("AceConfigDialog-3.0")
ACD:SetDefaultSize(addonName, 800, 650)
local optionsFrame = LibStub("AceGUI-3.0"):Create("Frame")  -- Create own container so we can register OnShow and OnHide
optionsFrame:Hide()
optionsFrame:SetCallback("OnClose", function()
  Addon.unlocked = nil
  Addon:Build()
end)
function Addon:Options()
  self:Build()
  ACD:Open(addonName, optionsFrame)
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
    auras = {}
  },
  class = {
    auras = {}
  }
}

function Addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New(addonName.."DB", defaultSettings, true)
  
  self:RegisterEvent("PLAYER_ENTERING_WORLD", function()  -- Delay so UIScale can be read
    Addon:Build()
    Addon:UnregisterEvent("PLAYER_ENTERING_WORLD")
  end)
end