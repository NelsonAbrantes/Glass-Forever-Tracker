local _, ns = ...
local Core = ns.Core

----
-- EditMode
--
-- Adds the main Glass Forever Tracker settings to the game's own Objective
-- Tracker entry in Edit Mode, next to its Height and Opacity. They're the
-- same settings as in the Options window.

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
    {
      name = "Title size",
      kind = LEM.SettingType.Slider,
      default = defaults.headerFontSize,
      minValue = 8,
      maxValue = 24,
      valueStep = 1,
      get = function () return profile().headerFontSize end,
      set = function (_, value) Set("headerFontSize", value) end,
    },
    {
      name = "Objective size",
      kind = LEM.SettingType.Slider,
      default = defaults.lineFontSize,
      minValue = 8,
      maxValue = 24,
      valueStep = 1,
      get = function () return profile().lineFontSize end,
      set = function (_, value) Set("lineFontSize", value) end,
    },
    {
      name = "Glass background",
      desc = "Opacity of the Glass background behind the tracker",
      kind = LEM.SettingType.Slider,
      default = defaults.backgroundOpacity,
      minValue = 0,
      maxValue = 1,
      valueStep = 0.05,
      formatter = RoundTo2,
      get = function () return profile().backgroundOpacity end,
      set = function (_, value) Set("backgroundOpacity", RoundTo2(value)) end,
    },
  })
end

Core:OnChange(function (key)
  if key == "enable" and not Core.editModeReady then
    Core.editModeReady = true
    Setup()
  end
end)
