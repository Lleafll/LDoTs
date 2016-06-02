local addonName, addonTable = ...
local Addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0")

--------------
-- Upvalues --
--------------
pairs = pairs


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
      db[#db] = {
        name = "New Aura",
        ownOnly = true,
        height = 32,
        width = 32,
        posX = 0,
        posY = 0,
      }
    end
  }
  
  order = order + 1
  
  for k, v in pairs(db) do
    tbl[k] = {
      order = order,
      name = v.name,
      type = group,
      args = {
        name = {
          order = 0,
          name = "Name",
          type = "input",
          -- TODO: Add validation
        },
        spellID = {
          order = 1,
          name = "Spell ID",
          type = "input",
          -- TODO: Add validation
        },
        unitID = {
          order = 2,
          name = "Unit ID",
          type = "input",
          -- TODO: Add validation
        },
        ownOnly = {
          order = 3,
          name = "Own Only",
          type = "toggle",
        },
        pandemic = {
          order = 4,
          name = "Pandemic",
          type = "toggle",
        },
        height = {
          order = 5,
          name = "Height",
          type = "range",
          min = 1,
          softMax = 100,
        },
        width = {
          order = 6,
          name = "Width",
          type = "range",
          min = 1,
          softMax = 100,
        },
        posX = {
          order = 7,
          name = "X Position",
          type = "range",
          min = -math.ceil(GetScreenWidth()),
          max = math.ceil(GetScreenWidth()),
        },
        posY = {
          order = 8,
          name = "X Position",
          type = "range",
          min = -math.ceil(GetScreenHeight()),
          max = math.ceil(GetScreenHeight()),
        }
      }
    }
    order = order + 1
  end
end

local function options()
  local tbl = {
    type = "group",
		name = addonName,
		childGroups = "tab",
		args = {
      global = {
        type = "group",
        name = "Global Auras",
        childGroups = "select",
        get = function(info)
          return Addon.db.global[info[#info-1]][info[#info]]
        end,
        set = function(info, value)
          Addon.db.global[info[#info-1]][info[#info]] = value
          Addon:Build()
        end,
        args = {}
      },
      class = {
        type = "group",
        name = "Class Auras",
        childGroups = "select",
        get = function(info)
          return Addon.db.class[info[#info-1]][info[#info]]
        end,
        set = function(info, value)
          Addon.db.class[info[#info-1]][info[#info]] = value
          Addon:Build()
        end,
        args = {}
      }
    }
  }
  
  addAuras(tbl.args.global.args, Addon.db.global.auras)
  addAuras(tbl.args.class.args, Addon.db.class.auras)
  
  return tbl
endend

local defaultSettings = {}

LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, defaultSettings)


-----------------
-- Options GUI --
-----------------
local ACD = LibStub("AceConfigDialog-3.0")
ACD:SetDefaultSize(addonName, 200, 300)


------------------
-- Chat Command --
------------------
Addon:HandleChatCommand(input) {
  if ACD.OpenFrames[addons] then  -- TODO: Check why this works
		ACD:Close(addonName)
	else
		ACD:Open(addonName)
	end
}

Addon:RegisterChatCommand(addonName, "HandleChatCommand")