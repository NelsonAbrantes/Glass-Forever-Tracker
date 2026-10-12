local _, ns = ...
local Core = ns.Core

-- luacheck: push ignore 113
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetMouseFocus = GetMouseFocus
local GetMouseFoci = GetMouseFoci
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local WorldFrame = WorldFrame
local IsInInstance = IsInInstance
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

-- The slide that goes with the fade in (Animations: Glass): the tracker and
-- its background come in from a little to the right. Only out of combat, to
-- leave the tracker alone during fights.
local SLIDE_DISTANCE = 24
local SLIDE_TIME = 0.35

local function SlideGroup(frame)
  local group = frame:CreateAnimationGroup()
  local away = group:CreateAnimation("Translation")
  away:SetOffset(SLIDE_DISTANCE, 0)
  away:SetDuration(0)
  away:SetOrder(1)
  local back = group:CreateAnimation("Translation")
  back:SetOffset(-SLIDE_DISTANCE, 0)
  back:SetDuration(SLIDE_TIME)
  back:SetOrder(2)
  back:SetSmoothing("OUT")
  return group
end

local slides
local function SlideIn()
  if not Core:Animates() or InCombatLockdown() or InEditMode() then return end
  slides = slides or { SlideGroup(tracker), SlideGroup(Core.background) }
  for _, group in ipairs(slides) do
    group:Stop()
    group:Play()
  end
end

-- True while the tracker slides in (Animations.lua leaves a new quest's own
-- slide out then)
function Core:TrackerSliding()
  return slides ~= nil and slides[1]:IsPlaying()
end

-- Part of the tracker (its quests, buttons...) or its background
local function IsTrackerPart(frame)
  for _ = 1, 20 do
    if not frame then return false end
    if frame == tracker or frame == Core.background then return true end
    frame = frame.GetParent and frame:GetParent()
  end
  return false
end

-- Another window (bags, character...) under the mouse, on top of the tracker
local function OtherWindowOnTop()
  local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
  for _, focus in ipairs(foci) do
    if focus and focus ~= WorldFrame and not IsTrackerPart(focus) then return true end
  end
  return false
end

-- The mouse over the quests: only the part with something shown (the
-- tracker's box goes on, empty, down to its Edit Mode height), with nothing
-- else on top
local function MouseOverQuests()
  if not tracker:IsVisible() then return false end
  local empty = 0
  local contentHeight = Core.background.contentHeight
  if contentHeight then
    empty = math.max(0, tracker:GetHeight() - contentHeight)
  end
  return tracker:IsMouseOver(8, empty - 8, -8, 8) and not OtherWindowOnTop()
end

local ticker = CreateFrame("Frame", nil, UIParent)
ticker:SetScript("OnUpdate", function (_, elapsed)
  local profile = Profile()

  local mouseOver = MouseOverQuests()
  if mouseOver ~= state.mouseOver then
    state.mouseOver = mouseOver
    -- Leaving it starts the countdown again
    if not mouseOver then Reveal() end
  end

  -- In dungeons and raids (Options): hidden, or always shown
  local instanceMode = state.inInstance and profile.instanceMode or "normal"

  local shown = not profile.fade
    or instanceMode == "show"
    or InEditMode()
    or (profile.showOnMouseOver and mouseOver)
    or GetTime() < state.visibleUntil
  if instanceMode == "hide" and not InEditMode() then
    shown = false
  end
  local target = shown and 1 or (instanceMode == "hide" and 0 or profile.fadedAlpha)
  -- Coming back from (nearly) hidden: it also slides in a little
  if target == 1 and state.target ~= 1 and state.alpha < 0.3 then
    SlideIn()
  end
  state.target = target

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
  "QUEST_WATCH_LIST_CHANGED", -- a quest tracked or untracked
  "QUEST_TURNED_IN",
  "QUEST_REMOVED",
  "QUEST_LOG_CRITERIA_UPDATE",
  "TRACKED_ACHIEVEMENT_UPDATE",
}

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function (_, event)
  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    -- Dungeons and raids
    local inInstance, instanceType = IsInInstance()
    state.inInstance = inInstance and (instanceType == "party" or instanceType == "raid") or false
    if event == "PLAYER_ENTERING_WORLD" then Reveal() end
  elseif Profile().showOnProgress then
    Reveal()
  end
end)

function Core:OnEnable()
  Core.background:Attach(tracker)
  Apply(state.alpha)
  self:SecureHook(tracker, "SetAlpha", KeepAlpha)

  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  for _, event in ipairs(PROGRESS_EVENTS) do
    pcall(events.RegisterEvent, events, event)
  end

  Reveal()
  -- Skins and settings that need the game's tracker to be ready
  C_Timer.After(0, function () Core:Changed("enable") end)
end

Core:OnChange(function (key)
  if key == "fade" or key == "profile" or key == "sectionAdded" then
    Reveal()
  end
end)
