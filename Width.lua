local _, ns = ...
local Core = ns.Core

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
-- luacheck: pop

local DEFAULT = 260 -- the game's own width

----
-- Width
--
-- "Width" (Options and Edit Mode): makes the tracker wider or narrower. The
-- game builds it 260 wide, with each section the same width; quest names and
-- objectives then wrap to whatever room there is. Only sizes change, never
-- the game's own values, and only out of combat (changed in a fight, it waits
-- until the fight is over). Left at 260 it doesn't touch anything.

local touched = false   -- set a size at least once this session
local pendingCombat = false

local function Width()
  return Core.db.profile.width or DEFAULT
end

local function SizeModule(module, width)
  module:SetWidth(width)
  if module.Header then module.Header:SetWidth(width) end
end

local function Apply()
  local tracker = _G.ObjectiveTrackerFrame
  if not tracker then return end
  local width = Width()
  if width == DEFAULT and not touched then return end
  if InCombatLockdown() then
    pendingCombat = true
    return
  end
  touched = true

  for _, module in ipairs(tracker.modules or {}) do
    SizeModule(module, width)
  end
  if tracker.Header then tracker.Header:SetWidth(width) end
  -- A new size makes the game lay the tracker out again by itself
  tracker:SetWidth(width)
end

local hooked = false
local function Hook()
  local tracker = _G.ObjectiveTrackerFrame
  if hooked or not tracker or not tracker.AddModule then return end
  hooked = true
  -- Sections can appear later (first quest of a kind): give them the width
  -- before the game lays them out
  hooksecurefunc(tracker, "AddModule", function (_, module)
    if touched and module and not InCombatLockdown() then
      SizeModule(module, Width())
    end
  end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function ()
  if pendingCombat then
    pendingCombat = false
    Apply()
  end
end)

Core:OnChange(function (key)
  if key == "enable" then
    Hook()
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    Apply()
  elseif key == "width" or key == "profile" then
    Apply()
  end
end)
