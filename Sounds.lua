local _, ns = ...
local Core = ns.Core

-- luacheck: push ignore 113
local C_QuestLog = C_QuestLog
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local PlaySound = PlaySound
local SOUNDKIT = SOUNDKIT
-- luacheck: pop

----
-- Sounds
--
-- A discreet sound when a quest objective is done, and another when a quest
-- is ready to turn in (Options: Sound on complete). Works from the quest log,
-- comparing it with how it was a moment before.

-- questID -> { done = finished objectives, complete = ready to turn in }
local known

local function Snapshot()
  local quests = {}
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return quests end
  for i = 1, C_QuestLog.GetNumQuestLogEntries() do
    local info = C_QuestLog.GetInfo(i)
    if info and not info.isHeader and info.questID then
      local done = 0
      for _, objective in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
        if objective.finished then done = done + 1 end
      end
      quests[info.questID] = { done = done, complete = C_QuestLog.IsComplete(info.questID) and true or false }
    end
  end
  return quests
end

local function Play(sound)
  if sound then PlaySound(sound) end
end

local function Check()
  local now = Snapshot()
  if known and Core.db.profile.completeSound then
    local questDone, objectiveDone = false, false
    for questID, quest in pairs(now) do
      local before = known[questID]
      if before then
        if quest.complete and not before.complete then
          questDone = true
        elseif quest.done > before.done then
          objectiveDone = true
        end
      end
    end
    -- One sound at a time: a finished quest wins over its last objective
    if questDone then
      Play(SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE)
    elseif objectiveDone then
      Play(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
  end
  known = now
end

-- The quest log changes in bursts: check once after each burst
local pending = false
local function CheckSoon()
  if pending then return end
  pending = true
  C_Timer.After(0.2, function ()
    pending = false
    Check()
  end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", CheckSoon)

Core:OnChange(function (key)
  if key == "enable" then
    events:RegisterEvent("QUEST_LOG_UPDATE")
    events:RegisterEvent("QUEST_WATCH_UPDATE")
    -- The first look only remembers how things are (no sounds on login)
    CheckSoon()
  end
end)
