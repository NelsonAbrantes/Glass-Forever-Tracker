local _, ns = ...
local Core = ns.Core

-- luacheck: push ignore 113
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetTime = GetTime
local UIParent = UIParent
-- luacheck: pop

----
-- Fade
--
-- Fades the tracker out when you're not using it, and brings it back while
-- the mouse is over it, when an objective changes, and while Edit Mode is
-- open. Only the tracker's transparency changes: the game allows that even in
-- combat, so the quest item buttons keep working.

local tracker = _G.ObjectiveTrackerFrame

local state = {
  alpha = 1,          -- current visibility
  target = 1,         -- where it's going
  visibleUntil = 0,   -- shown until this time (GetTime), then it fades out
  mouseOver = false,
}

local function Profile() return Core.db.profile end

-- Keeps it shown for holdTime seconds from now
local function Reveal()
  state.visibleUntil = math.max(state.visibleUntil, GetTime() + Profile().holdTime)
end
Core.Reveal = Reveal

local function InEditMode()
  local manager = _G.EditModeManagerFrame
  return manager and manager:IsShown()
end

local applying = false
local function Apply(alpha)
  applying = true
  tracker:SetAlpha(alpha)
  applying = false
  Core.background:SetAlpha(alpha)
end

local ticker = CreateFrame("Frame", nil, UIParent)
ticker:SetScript("OnUpdate", function (_, elapsed)
  local profile = Profile()

  local mouseOver = tracker:IsVisible() and tracker:IsMouseOver(8, -8, -8, 8)
  if mouseOver ~= state.mouseOver then
    state.mouseOver = mouseOver
    -- Leaving it starts the countdown again
    if not mouseOver then Reveal() end
  end

  local shown = not profile.fade
    or InEditMode()
    or (profile.showOnMouseOver and mouseOver)
    or GetTime() < state.visibleUntil
  state.target = shown and 1 or profile.fadedAlpha

  -- Move towards the target over the fade in / fade out duration
  if state.alpha ~= state.target then
    local duration = state.target > state.alpha and profile.fadeInDuration or profile.fadeOutDuration
    local step = duration > 0 and elapsed / duration or 1
    if state.target > state.alpha then
      state.alpha = math.min(state.target, state.alpha + step)
    else
      state.alpha = math.max(state.target, state.alpha - step)
    end
    Apply(state.alpha)
  end
end)

-- Something else changing the tracker's transparency (e.g. the game) gets
-- ours back
local function KeepAlpha()
  if not applying and math.abs(tracker:GetAlpha() - state.alpha) > 0.01 then
    Apply(state.alpha)
  end
end

-- Objective changes that bring the tracker back
local PROGRESS_EVENTS = {
  "QUEST_WATCH_UPDATE",       -- an objective of a tracked quest moved
  "QUEST_ACCEPTED",
  "QUEST_TURNED_IN",
  "QUEST_REMOVED",
  "QUEST_LOG_CRITERIA_UPDATE",
  "TRACKED_ACHIEVEMENT_UPDATE",
  "SCENARIO_CRITERIA_UPDATE",
  "SCENARIO_UPDATE",
}

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function (_, event)
  if event == "PLAYER_ENTERING_WORLD" then
    Reveal()
  elseif Profile().showOnProgress then
    Reveal()
  end
end)

function Core:OnEnable()
  Core.background:Attach(tracker)
  Apply(state.alpha)
  self:SecureHook(tracker, "SetAlpha", KeepAlpha)

  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  for _, event in ipairs(PROGRESS_EVENTS) do
    pcall(events.RegisterEvent, events, event)
  end

  Reveal()
  -- Skins and settings that need the game's tracker to be ready
  C_Timer.After(0, function () Core:Changed("enable") end)
end

Core:OnChange(function (key)
  if key == "fade" or key == "profile" then
    Reveal()
  end
end)
