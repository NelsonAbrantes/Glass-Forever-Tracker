local _, ns = ...
local Core = ns.Core

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local CreateFromMixins = CreateFromMixins
-- luacheck: pop

local TITLE = "Glass Forever Tracker"

----
-- Options
--
-- The addon's page in the game's Options window (Options > AddOns > Glass
-- Forever Tracker), built with the game's own controls. /gft opens it.

local function Profile() return Core.db.profile end

local function RoundTo2(value)
  return math.floor(value * 100 + 0.5) / 100
end

local function Header(layout, text)
  if _G.CreateSettingsListSectionHeaderInitializer then
    layout:AddInitializer(_G.CreateSettingsListSectionHeaderInitializer(text))
  end
end

-- A setting stored in the profile; changes are announced with its key
local function ProfileSetting(category, key, varType, name, round)
  return _G.Settings.RegisterProxySetting(
    category,
    "GLASSFOREVERTRACKER_"..key:upper(),
    varType,
    name,
    Core.defaults.profile[key],
    function () return Profile()[key] end,
    function (value)
      if round then value = RoundTo2(value) end
      Profile()[key] = value
      Core:Changed(key)
    end
  )
end

local function Slider(category, key, name, minValue, maxValue, step, tooltip)
  local Settings = _G.Settings
  local decimals = step < 1
  local setting = ProfileSetting(category, key, Settings.VarType.Number, name, decimals)
  local options = Settings.CreateSliderOptions(minValue, maxValue, step)
  options:SetLabelFormatter(_G.MinimalSliderWithSteppersMixin.Label.Right, function (value)
    return decimals and RoundTo2(value) or value
  end)
  Settings.CreateSlider(category, setting, options, tooltip)
end

local function Checkbox(category, key, name, tooltip)
  local Settings = _G.Settings
  Settings.CreateCheckbox(category, ProfileSetting(category, key, Settings.VarType.Boolean, name), tooltip)
end

local function Dropdown(category, key, name, values, tooltip)
  local Settings = _G.Settings
  local setting = ProfileSetting(category, key, Settings.VarType.String, name)
  Settings.CreateDropdown(category, setting, function ()
    local container = Settings.CreateControlTextContainer()
    for _, entry in ipairs(values) do
      container:Add(entry[1], entry[2])
    end
    return container:GetData()
  end, tooltip)
end

-- Font list with scrolling: there can be many fonts, more than fit on screen
local function FontDropdown(layout)
  local Initializer = CreateFromMixins(
    _G.ScrollBoxFactoryInitializerMixin,
    _G.SettingsElementHierarchyMixin,
    _G.SettingsSearchableElementMixin
  )

  function Initializer:Init()
    _G.ScrollBoxFactoryInitializerMixin.Init(self, "SettingsListElementTemplate")
    self.data = { name = "Font", tooltip = "Font of the tracker's text" }
    self:AddSearchTags("Font")
  end

  function Initializer:GetExtent()
    return 26
  end

  function Initializer:InitFrame(frame)
    frame:SetSize(280, 26)
    frame.data = self.data
    frame.Text:SetFontObject("GameFontNormal")
    frame.Text:SetText("Font")
    frame.Text:SetPoint("LEFT", 37, 0)
    frame.Text:SetPoint("RIGHT", frame, "CENTER", -85, 0)

    if not frame.gftFontDropdown then
      local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
      dropdown:SetPoint("LEFT", frame, "CENTER", -80, 0)
      dropdown:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
      dropdown:SetHeight(26)
      frame.gftFontDropdown = dropdown
    end

    local dropdown = frame.gftFontDropdown
    dropdown:Show()
    dropdown:SetupMenu(function (_, rootDescription)
      rootDescription:SetScrollMode(300)
      -- A copy: the font list is shared with other addons
      local fonts = {}
      for _, font in ipairs(Core.LSM:List("font")) do
        table.insert(fonts, font)
      end
      for _, font in ipairs(fonts) do
        rootDescription:CreateRadio(
          font,
          function (value) return Profile().font == value end,
          function (value)
            Profile().font = value
            Core:Changed("font")
            dropdown:OverrideText(value)
          end,
          font
        )
      end
    end)
    dropdown:OverrideText(Profile().font)
  end

  function Initializer:Resetter(frame)
    if frame.gftFontDropdown then
      frame.gftFontDropdown:Hide()
    end
  end

  local initializer = CreateFromMixins(Initializer)
  initializer:Init()
  layout:AddInitializer(initializer)
end

local function Build()
  local Settings = _G.Settings
  local category, layout = Settings.RegisterVerticalLayoutCategory(TITLE)

  Header(layout, "Fade")
  Checkbox(category, "fade", "Fade out", "The tracker fades out when you're not using it. Turn off to keep it always visible")
  Slider(category, "holdTime", "Fade out delay", 1, 60, 1, "Seconds before the tracker fades out")
  Slider(category, "fadedAlpha", "Faded visibility", 0, 0.8, 0.05, "How visible the tracker stays when faded. 0 hides it completely")
  Slider(category, "fadeInDuration", "Fade in duration", 0, 3, 0.05, "Seconds the tracker takes to appear")
  Slider(category, "fadeOutDuration", "Fade out duration", 0, 3, 0.05, "Seconds the tracker takes to disappear")
  Checkbox(category, "showOnMouseOver", "Show on mouse over", "Show the tracker while the mouse is over it")
  Checkbox(category, "showOnProgress", "Show on progress", "Show the tracker for a while when a quest or achievement objective changes, or you accept or turn in a quest")

  Header(layout, "Look")
  Checkbox(category, "glassLook", "Glass look", "No header bars or panel background from the game, the Glass background and font, and section titles in gold. Off: the game's own look")
  FontDropdown(layout)
  Dropdown(category, "fontFlags", "Font outline", {
    { "", "None" },
    { "OUTLINE", "Outline" },
    { "OUTLINE, MONOCHROME", "Outline Monochrome" },
  }, "Outline around the letters")
  Slider(category, "headerFontSize", "Title size", 8, 24, 1, "Size of the section titles and quest names")
  Slider(category, "lineFontSize", "Objective size", 8, 24, 1, "Size of the objectives")
  Slider(category, "backgroundOpacity", "Background opacity", 0, 1, 0.05, "Opacity of the Glass background behind the tracker. 0 turns it off")

  Settings.RegisterAddOnCategory(category)
  return category
end

Core:OnChange(function (key)
  if key ~= "enable" or Core.optionsCategory then return end
  if not (_G.Settings and _G.Settings.RegisterVerticalLayoutCategory) then return end
  Core.optionsCategory = Build()

  _G.SLASH_GLASSFOREVERTRACKER1 = "/gft"
  _G.SlashCmdList.GLASSFOREVERTRACKER = function ()
    _G.Settings.OpenToCategory(Core.optionsCategory:GetID())
  end
end)
