local _, ns = ...
local Core = ns.Core

----
-- Skin
--
-- The Glass look: no header bars or panel background from the game, the
-- tracker's text in the Glass font, and section titles in the Glass gold.
-- Nothing of the game's tracker is replaced: its art is kept transparent and
-- its fonts get another typeface, so turning the look off brings it all back.

local tracker = _G.ObjectiveTrackerFrame

-- The tracker's own fonts: titles (sections and quest names) and objectives
local FONTS = {
  { name = "ObjectiveTrackerHeaderFont", size = "headerFontSize", gold = true },
  { name = "ObjectiveTrackerLineFont", size = "lineFontSize" },
}
local originalFonts = {}

local function Profile() return Core.db.profile end

-- Keeps a piece of the game's art transparent while the Glass look is on
local hidden = {}
local function KeepHidden(region)
  if not region then return end
  region:SetAlpha(Profile().glassLook and 0 or 1)
  if hidden[region] then return end
  hidden[region] = true
  hooksecurefunc(region, "SetAlpha", function (_, alpha)
    if Profile().glassLook and alpha ~= 0 then region:SetAlpha(0) end
  end)
end

-- The game's art: the panel background (Edit Mode "Opacity", replaced by the
-- Glass background) and the bar behind each section title
local function SkinArt()
  KeepHidden(tracker.NineSlice)
  KeepHidden(tracker.Header and tracker.Header.Background)
  for _, module in ipairs(tracker.modules or {}) do
    KeepHidden(module.Header and module.Header.Background)
  end
end

local function SkinFonts()
  local profile = Profile()
  local path = Core.LSM:Fetch(Core.LSM.MediaType.FONT, profile.font)

  for _, info in ipairs(FONTS) do
    local font = _G[info.name]
    if font and font.SetFont then
      if not originalFonts[info.name] then
        local file, size, flags = font:GetFont()
        local r, g, b = font:GetTextColor()
        originalFonts[info.name] = { file, size, flags, r, g, b }
      end

      local original = originalFonts[info.name]
      if profile.glassLook and path then
        font:SetFont(path, profile[info.size], profile.fontFlags)
        if info.gold then
          font:SetTextColor(Core.GOLD.r, Core.GOLD.g, Core.GOLD.b)
        end
      else
        font:SetFont(original[1], original[2], original[3])
        font:SetTextColor(original[4], original[5], original[6])
      end
    end
  end
end

local function Skin()
  SkinArt()
  SkinFonts()
end

-- Sections added later (e.g. a scenario starts) get the look too
local function HookModules()
  if tracker.AddModule and not Core:IsHooked(tracker, "AddModule") then
    Core:SecureHook(tracker, "AddModule", SkinArt)
  end
end

Core:OnChange(function (key)
  if key == "enable" then
    HookModules()
    Skin()
  elseif key == "glassLook" or key == "profile" then
    Skin()
  elseif key == "font" or key == "fontFlags" or key == "headerFontSize" or key == "lineFontSize" then
    SkinFonts()
  end
end)
