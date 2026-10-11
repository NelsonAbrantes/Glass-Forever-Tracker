local AddonName, ns = ...

local Core = LibStub("AceAddon-3.0"):NewAddon(AddonName, "AceHook-3.0")
ns.Core = Core
_G.GlassForeverTracker = Core

Core.Version = "0.1.0-forever"
Core.LSM = LibStub("LibSharedMedia-3.0")
Core.listeners = {} -- filled while the files load, see Core:OnChange

-- The Glass gold, for titles and highlights
Core.GOLD = { r = 223 / 255, g = 186 / 255, b = 105 / 255 }

Core.defaults = {
  profile = {
    -- Fade
    fade = true,              -- the tracker fades out when you're not using it
    holdTime = 8,             -- seconds before it fades out
    fadeInDuration = 0.3,
    fadeOutDuration = 0.8,
    fadedAlpha = 0,           -- how visible it stays when faded (0 = hidden)
    showOnMouseOver = true,   -- comes back while the mouse is over it
    showOnProgress = true,    -- comes back for a while when an objective changes

    -- Look
    glassLook = true,         -- no game backgrounds, Glass font
    font = "Friz Quadrata TT",
    fontFlags = "",
    headerFontSize = 14,      -- section titles ("Quests") and quest names
    lineFontSize = 12,        -- objectives
    backgroundOpacity = 0.25, -- the Glass fading background behind the tracker
  }
}

----
-- Core
--
-- Settings changes are announced with Core:Changed(key); the other parts of
-- the addon listen with Core:OnChange(function (key) ... end).

function Core:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("GlassForeverTrackerDB", self.defaults, true)

  local function Refresh() self:Changed("profile") end
  self.db.RegisterCallback(self, "OnProfileChanged", Refresh)
  self.db.RegisterCallback(self, "OnProfileCopied", Refresh)
  self.db.RegisterCallback(self, "OnProfileReset", Refresh)
end

function Core:OnChange(listener)
  table.insert(self.listeners, listener)
end

function Core:Changed(key)
  for _, listener in ipairs(self.listeners) do
    listener(key)
  end
end
