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
      if db["New Aura"] then
        print("LDoTs: New Aura already exists")
      else
        db["New Aura"] = {
          spellID = "",
          unitID = "target",
          auraType = "Debuff",
          ownOnly = true,
          pandemicExtra = 0,
          pandemicHasted = true,
          height = 30,
          width = 30,
          anchor = "CENTER",
          posX = 0,
          posY = 0,
          hideSwirl = true,
        }
      end
    end
  }
  
  order = order + 1
  
  for k, v in pairs(db) do
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
        name = {
          order = 0,
          name = "Name",
          type = "input",
          validate = function(info, val)
            return db[val] and ("LDoTs: "..val.." already exists") or true
          end,
          get = function(info)
            return k
          end,
          set = function(info, val)
            db[val] = v
            db[k] = nil
          end,
        },
        spellID = {
          order = 1,
          name = "Spell ID: "..(GetSpellInfo(v.spellID) or ""),
          type = "input",
          -- TODO: Add validation
        },
        unitID = {
          order = 2,
          name = "Unit ID",
          type = "input",
          -- TODO: Add validation
        },
        auraType = {
          order = 2.1,
          name = "Aura Type",
          type = "select",
          style = dropdown,
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
        pandemic = {
          order = 4,
          name = "Pandemic",
          type = "toggle",
        },
        pandemicExtra = {
          order = 4.1,
          name = "Add to Pandemic Duration",
          type = "input",
        },
        pandemicHasted = {
          order = 4.2,
          name = "Extra Pandemic Time is Hasted",
          type = "toggle",
        },
        height = {
          order = 5,
          name = "Height",
          type = "range",
          min = 1,
          softMax = 100,
          step = 1
        },
        width = {
          order = 6,
          name = "Width",
          type = "range",
          min = 1,
          softMax = 100,
          step = 1
        },
        hideSwirl = {
          order = 6.1,
          name = "Hide Cooldown Swirl",
          type = "toggle",
        },
        anchor = {
          order = 7,
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
        },
        posX = {
          order = 8,
          name = "X Position",
          type = "range",
          min = -math.ceil(GetScreenWidth()),
          max = math.ceil(GetScreenWidth()),
          step = 0.1
        },
        posY = {
          order = 9,
          name = "Y Position",
          type = "range",
          min = -math.ceil(GetScreenHeight()),
          max = math.ceil(GetScreenHeight()),
          step = 0.1
        },
        deleteAura = {
          order = 10,
          name = "Delete Aura",
          type = "execute",
          func = function()
            db[k] = nil
            Addon:Build()
          end,
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
      --[[unlock = {
        order = 1,
        type = "execute",
        name = "Toggle Lock",
        func = function(info)
          Addon.unlocked = not Addon.unlocked
          Addon:Build()
        end,
      },]]--
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


------------------
-- Chat Command --
------------------
function Addon:HandleChatCommand(input)
  if ACD.OpenFrames[addonName] then  -- TODO: Check why this works
		ACD:Close(addonName)
	else
    Addon.unlocked = true
    Addon:Build()
		ACD:Open(addonName, optionsFrame)
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