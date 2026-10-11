local AddonName, ns = ...

local Core = LibStub("AceAddon-3.0"):NewAddon(AddonName, "AceHook-3.0")
ns.Core = Core
_G.GlassForeverTracker = Core

Core.Version = "0.1.0-forever"
Core.LSM = LibStub("LibSharedMedia-3.0")
Core.listeners = {} -- filled while the files load, see Core:OnChange

-- The Glass gold, for titles and highlights
Core.GOLD = { r = 223 / 255, g = 186 / 255, b = 105 / 255 }

-- Colors offered in the options (the Glass Forever accent colors), in order
Core.COLORS = {
  { "gold", "Gold", { Core.GOLD.r, Core.GOLD.g, Core.GOLD.b } },
  { "white", "White", { 1, 1, 1 } },
  { "silver", "Silver", { 0.75, 0.76, 0.80 } },
  { "bronze", "Bronze", { 0.88, 0.62, 0.36 } },
  { "cyan", "Cyan", { 0.30, 0.80, 0.95 } },
  { "green", "Green", { 0.40, 0.90, 0.45 } },
  { "purple", "Purple", { 0.72, 0.50, 0.95 } },
  { "red", "Red", { 0.95, 0.38, 0.32 } },
  { "class", "Class color" },
}

---
-- r, g, b of a color from Core.COLORS by its key; nil if unknown
function Core:Color(key)
  if key == "class" then
    local _, class = UnitClass("player")
    local color = class and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class]
    if color then return color.r, color.g, color.b end
    key = "gold"
  end
  for _, entry in ipairs(self.COLORS) do
    if entry[1] == key then
      return entry[3][1], entry[3][2], entry[3][3]
    end
  end
  return nil
end

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
    backgroundColor = "black", -- black, brown, blue or grey
    backgroundSize = 36,      -- how far the background reaches past the text
    lineSpacing = 0,          -- extra space between the lines of a text
    titleColor = "gold",      -- section titles ("Quests"); see Core.COLORS
    questNameColor = "auto",  -- quest names; "auto" keeps the game's colors
    iconColor = "gold",       -- quest and minimize icons; "game" = the game's own
    hideMainHeader = false,   -- hide the "All Objectives" title
    hideSectionHeaders = false, -- hide the section titles ("Quests"...)

    questCount = true,        -- "Quests 12/25" in the Quests title
    completedObjectives = "show", -- finished objectives: show or dim
    glassBars = true,         -- progress bars in the Glass style
    sectionAnimation = "glass", -- animations of sections, quests and objectives: glass, game or off
    -- Each Glass animation, on its own (with sectionAnimation = "glass")
    animTitles = true,        -- line and shine on new sections and quests
    animProgress = true,      -- line under an objective that moved on
    animComplete = true,      -- a completed objective lights up white
    animPulse = true,         -- the "?" of a quest ready to turn in pulses
    animTrackerSlide = true,  -- the tracker slides in when it comes back
    animQuestSlide = true,    -- a new quest slides in
    animQuestType = true,     -- a new quest's name writes itself
    animQuestIcon = true,     -- a new quest's icon pops, with a ring
    animQuestLines = true,    -- a new quest's objectives appear one by one

    -- Behavior
    zoneOnly = false,         -- track only the quests of the current zone
    instanceMode = "normal",  -- in dungeons and raids: normal, hide or show
    completeSound = true,     -- a sound when an objective or quest is done
  }
}

----
-- Core
--
-- Settings changes are announced with Core:Changed(key); the other parts of
-- the addon listen with Core:OnChange(function (key, ...) ... end). Some
-- announcements carry more (e.g. "questAdded" carries the quest block).

function Core:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("GlassForeverTrackerDB", self.defaults, true)

  local function Refresh() self:Changed("profile") end
  self.db.RegisterCallback(self, "OnProfileChanged", Refresh)
  self.db.RegisterCallback(self, "OnProfileCopied", Refresh)
  self.db.RegisterCallback(self, "OnProfileReset", Refresh)

  self:Changed("init")
end

function Core:OnChange(listener)
  table.insert(self.listeners, listener)
end

function Core:Changed(key, ...)
  for _, listener in ipairs(self.listeners) do
    listener(key, ...)
  end
end

---
-- True if a Glass animation is on: the Glass look, Animations set to Glass,
-- and that animation's own option (e.g. "animPulse")
function Core:Animates(key)
  local profile = self.db.profile
  return profile.glassLook and profile.sectionAnimation == "glass" and profile[key] ~= false
end
