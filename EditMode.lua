local _, ns = ...
local Core = ns.Core

----
-- EditMode
--
-- Adds the main Glass Forever Tracker settings to the game's own Objective
-- Tracker entry in Edit Mode, next to its Height and Opacity. They're the
-- same settings as in the Options window. The game's own Opacity and Text
-- Size there control the Glass background and the text sizes.

local function RoundTo2(value)
  return math.floor(value * 100 + 0.5) / 100
end

local function Setup()
  local LEM = LibStub("LibEditMode", true)
  local system = _G.Enum and _G.Enum.EditModeSystem and _G.Enum.EditModeSystem.ObjectiveTracker
  if not LEM or not system or not LEM.AddSystemSettings then return end

  local profile = function () return Core.db.profile end
  local defaults = Core.defaults.profile

  local function Set(key, value)
    profile()[key] = value
    Core:Changed(key)
  end

  LEM:AddSystemSettings(system, {
    {
      name = "Fade out",
      desc = "The tracker fades out when you're not using it",
      kind = LEM.SettingType.Checkbox,
      default = defaults.fade,
      get = function () return profile().fade end,
      set = function (_, value) Set("fade", value) end,
    },
    {
      name = "Fade out delay",
      desc = "Seconds before the tracker fades out",
      kind = LEM.SettingType.Slider,
      default = defaults.holdTime,
      minValue = 1,
      maxValue = 60,
      valueStep = 1,
      get = function () return profile().holdTime end,
      set = function (_, value) Set("holdTime", value) end,
    },
    {
      name = "Glass look",
      desc = "The Glass background and font, without the game's header bars",
      kind = LEM.SettingType.Checkbox,
      default = defaults.glassLook,
      get = function () return profile().glassLook end,
      set = function (_, value) Set("glassLook", value) end,
    },
  })

  -- The game's own Opacity and Text Size settings drive the Glass background
  -- and the text sizes, so they keep doing something with the Glass look.
  -- Only changes made in Edit Mode count: the game also applies them when it
  -- loads, which would undo the sizes chosen in the Options window.
  local manager = _G.ObjectiveTrackerManager
  if manager then
    local function InEditMode()
      local frame = _G.EditModeManagerFrame
      return frame and frame:IsShown()
    end

    hooksecurefunc(manager, "SetOpacity", function (_, opacity)
      if InEditMode() then
        Set("backgroundOpacity", RoundTo2((opacity or 0) / 100))
      end
    end)

    hooksecurefunc(manager, "SetTextSize", function (_, size)
      if not size then return end
      if InEditMode() then
        profile().lineFontSize = size
        profile().headerFontSize = size + 2 -- like the game: titles 2 bigger
      end
      -- The game has just put its own fonts back: Glass' again
      Core:Changed("lineFontSize")
    end)
  end
end

Core:OnChange(function (key)
  if key == "enable" and not Core.editModeReady then
    Core.editModeReady = true
    Setup()
  end
end)
