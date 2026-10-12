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

-- The colors from Core.COLORS as dropdown entries, after any extra ones
local function ColorValues(extra)
  local values = {}
  for _, entry in ipairs(extra or {}) do
    table.insert(values, entry)
  end
  for _, entry in ipairs(Core.COLORS) do
    table.insert(values, { text = entry[2], value = entry[1] })
  end
  return values
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
      name = "Width",
      desc = "Width of the tracker. The game's own is 260",
      kind = LEM.SettingType.Slider,
      default = defaults.width,
      minValue = 200,
      maxValue = 500,
      valueStep = 10,
      get = function () return profile().width end,
      set = function (_, value) Set("width", value) end,
    },
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
      name = "Faded visibility",
      desc = "How visible the tracker stays when faded. 0 hides it completely",
      kind = LEM.SettingType.Slider,
      default = defaults.fadedAlpha,
      minValue = 0,
      maxValue = 0.8,
      valueStep = 0.05,
      formatter = RoundTo2,
      get = function () return profile().fadedAlpha end,
      set = function (_, value) Set("fadedAlpha", RoundTo2(value)) end,
    },
    {
      name = "Title size",
      desc = "Size of the section titles and quest names. Text Size (above) sets it 2 bigger than the objectives; this fine-tunes it",
      kind = LEM.SettingType.Slider,
      default = defaults.headerFontSize,
      minValue = 8,
      maxValue = 24,
      valueStep = 1,
      get = function () return profile().headerFontSize end,
      set = function (_, value) Set("headerFontSize", value) end,
    },
    {
      name = "Line spacing",
      desc = "Extra space between the lines of a text that takes more than one line",
      kind = LEM.SettingType.Slider,
      default = defaults.lineSpacing,
      minValue = 0,
      maxValue = 10,
      valueStep = 1,
      get = function () return profile().lineSpacing end,
      set = function (_, value) Set("lineSpacing", value) end,
    },
    {
      name = "Background size",
      desc = "How far the Glass background reaches past the text, where it fades out",
      kind = LEM.SettingType.Slider,
      default = defaults.backgroundSize,
      minValue = 0,
      maxValue = 80,
      valueStep = 2,
      get = function () return profile().backgroundSize end,
      set = function (_, value) Set("backgroundSize", value) end,
    },
    {
      name = "Background color",
      kind = LEM.SettingType.Dropdown,
      default = defaults.backgroundColor,
      values = {
        { text = "Black", value = "black" },
        { text = "Dark brown", value = "brown" },
        { text = "Dark blue", value = "blue" },
        { text = "Dark grey", value = "grey" },
      },
      get = function () return profile().backgroundColor end,
      set = function (_, value) Set("backgroundColor", value) end,
    },
    {
      name = "Title color",
      desc = "Color of the section titles",
      kind = LEM.SettingType.Dropdown,
      default = defaults.titleColor,
      values = ColorValues(),
      get = function () return profile().titleColor end,
      set = function (_, value) Set("titleColor", value) end,
    },
    {
      name = "Icon color",
      desc = "Color of the quest icons and minimize buttons. Game icons: the game's own",
      kind = LEM.SettingType.Dropdown,
      default = defaults.iconColor,
      values = ColorValues({ { text = "Game icons", value = "game" } }),
      get = function () return profile().iconColor end,
      set = function (_, value) Set("iconColor", value) end,
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
