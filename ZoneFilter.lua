local _, ns = ...
local Core = ns.Core

-- luacheck: push ignore 113
local C_QuestLog = C_QuestLog
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetRealZoneText = GetRealZoneText
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
-- luacheck: pop

----
-- ZoneFilter
--
-- "Only quests in this zone" (Options, off by default): tracks the quests of
-- the zone you're in and stops tracking the others, again whenever you change
-- zone or accept a quest. The quests stay in your quest log. It's like
-- clicking them yourself, which the game only allows out of combat, so in
-- combat it waits until the fight is over. Turning it off tracks again the
-- quests it had stopped tracking. The same happens inside a dungeon or raid
-- with "In dungeons and raids: Dungeon quests only".

local function Profile() return Core.db.profile end

-- Quests this filter stopped tracking (per character, kept between sessions)
local function Untracked()
  Core.db.char.zoneUntracked = Core.db.char.zoneUntracked or {}
  return Core.db.char.zoneUntracked
end

-- The filter runs with "Only quests in this zone" on, or inside a dungeon or
-- raid with "In dungeons and raids: Dungeon quests only". Inside, the
-- zone is the dungeon itself.
local function Active()
  local profile = Profile()
  if profile.zoneOnly then return true end
  if profile.instanceMode ~= "dungeon" then return false end
  local inInstance, instanceType = IsInInstance()
  return inInstance and (instanceType == "party" or instanceType == "raid") or false
end

local function IsTracked(questID)
  return C_QuestLog.GetQuestWatchType(questID) ~= nil
end

local pendingCombat = false

local function Apply()
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return end
  if InCombatLockdown() then
    pendingCombat = true
    return
  end

  local untracked = Untracked()

  -- Off: give back what it took
  if not Active() then
    for questID in pairs(untracked) do
      if C_QuestLog.GetLogIndexForQuestID(questID) and not IsTracked(questID) then
        C_QuestLog.AddQuestWatch(questID)
      end
      untracked[questID] = nil
    end
    return
  end

  -- The quest log groups quests under zone names
  local zone = GetRealZoneText()
  local header
  for i = 1, C_QuestLog.GetNumQuestLogEntries() do
    local info = C_QuestLog.GetInfo(i)
    if info then
      if info.isHeader then
        header = info.title
      elseif info.questID and not info.isHidden then
        local questID = info.questID
        local inZone = info.isOnMap or (header ~= nil and header == zone)
        if inZone and not IsTracked(questID) then
          C_QuestLog.AddQuestWatch(questID)
          untracked[questID] = nil
        elseif not inZone and IsTracked(questID) then
          C_QuestLog.RemoveQuestWatch(questID)
          untracked[questID] = true
        end
      end
    end
  end
end

-- Zone changes come with a few events in a row: apply once, a moment later
local pending = false
local function ApplySoon()
  if pending then return end
  pending = true
  C_Timer.After(0.5, function ()
    pending = false
    Apply()
  end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function (_, event)
  if event == "PLAYER_REGEN_ENABLED" then
    if pendingCombat then
      pendingCombat = false
      ApplySoon()
    end
  else
    ApplySoon()
  end
end)

Core:OnChange(function (key)
  if key == "enable" then
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:RegisterEvent("QUEST_ACCEPTED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    ApplySoon()
  elseif key == "zoneOnly" or key == "instanceMode" or key == "profile" then
    ApplySoon()
  end
end)
