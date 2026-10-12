local _, ns = ...
local Core = ns.Core

-- luacheck: push ignore 113
local C_QuestLog = C_QuestLog
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
-- luacheck: pop

local FLAT = "Interface\\Buttons\\WHITE8x8"
local SCAN_EVERY = 0.5

----
-- Extras
--
-- - Quest count: "Quests 12/25" in the Quests title, how many quests you have
--   and how many fit in the quest log.
-- - Glass progress bars: the bars some objectives show (a percentage) get a
--   flat bar in the Glass gold on a dark background, without the game's frame.
-- - Completed objectives can be dimmed.

local tracker = _G.ObjectiveTrackerFrame
local function Profile() return Core.db.profile end

----
-- Quest count

local function QuestCount()
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return nil end
  local _, quests = C_QuestLog.GetNumQuestLogEntries()
  local max = C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()
    or _G.MAX_QUESTS or 25
  return quests, max
end

local countText -- the Quests title's text
local function UpdateCount()
  if not countText or not countText.gftBase then return end
  local text = countText.gftBase
  if Profile().questCount then
    local quests, max = QuestCount()
    if quests then text = string.format("%s  %d/%d", text, quests, max) end
  end
  countText.gftSetting = true
  countText:SetText(text)
  countText.gftSetting = false
end

local function SetupCount()
  local module = _G.QuestObjectiveTracker
  local text = module and module.Header and module.Header.Text
  if not text or countText then return end
  countText = text
  text.gftBase = text:GetText()
  -- The game sets the title again now and then: keep its text, add the count
  hooksecurefunc(text, "SetText", function (_, value)
    if text.gftSetting then return end
    text.gftBase = value
    UpdateCount()
  end)
  UpdateCount()
end

----
-- Progress bars

local BARS = {}

local function StyleBar(progressBar)
  local bar = progressBar and progressBar.Bar
  if not bar then return end
  local glass = Profile().glassLook and Profile().glassBars

  if not BARS[progressBar] then
    BARS[progressBar] = true
    bar.gftGameTexture = bar:GetStatusBarTexture() and bar:GetStatusBarTexture():GetTexture()
    -- A dark background of our own, under the bar
    bar.gftBackground = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    bar.gftBackground:SetAllPoints()
    bar.gftBackground:SetColorTexture(0, 0, 0, 0.5)
    for _, key in ipairs({ "BorderLeft", "BorderRight", "BorderMid" }) do
      local border = bar[key]
      if border then
        hooksecurefunc(border, "SetAlpha", function (_, alpha)
          if Profile().glassLook and Profile().glassBars and alpha ~= 0 then border:SetAlpha(0) end
        end)
      end
    end
  end

  for _, key in ipairs({ "BorderLeft", "BorderRight", "BorderMid" }) do
    if bar[key] then bar[key]:SetAlpha(glass and 0 or 1) end
  end
  bar.gftBackground:SetShown(glass)

  if glass then
    bar:SetStatusBarTexture(FLAT)
    local r, g, b = Core:Color(Profile().titleColor)
    bar:SetStatusBarColor(r or Core.GOLD.r, g or Core.GOLD.g, b or Core.GOLD.b)
  elseif bar.gftGameTexture then
    bar:SetStatusBarTexture(bar.gftGameTexture)
  end
end

local function ScanBars()
  for _, module in ipairs(tracker.modules or {}) do
    for _, progressBar in pairs(module.usedProgressBars or {}) do
      if not BARS[progressBar] then StyleBar(progressBar) end
    end
  end
end

local function UpdateBars()
  for progressBar in pairs(BARS) do StyleBar(progressBar) end
end

----
-- Completed objectives dimmed (Options). They keep their place: removing
-- them would mean changing how the game lays the tracker out.

local DIM_ALPHA = 0.35
-- Lines in the "complete" style that aren't finished objectives
local NOT_OBJECTIVES = { QuestComplete = true, ClickComplete = true }

local function DimCompleted()
  local colors = _G.OBJECTIVE_TRACKER_COLOR
  local complete = colors and colors.Complete
  local dim = Profile().completedObjectives == "dim"
  for _, module in ipairs(tracker.modules or {}) do
    for _, blocks in pairs(module.usedBlocks or {}) do
      for _, block in pairs(blocks) do
        for key, line in pairs(block.usedLines or {}) do
          local done = complete and line.Text and line.Text.colorStyle == complete
            and not NOT_OBJECTIVES[key]
          -- Not while it's appearing (Animations.lua)
          if not line.gftAnimating then
            line:SetAlpha((dim and done) and DIM_ALPHA or 1)
          end
        end
      end
    end
  end
end

----

local events = CreateFrame("Frame")
events:SetScript("OnEvent", UpdateCount)

Core:OnChange(function (key)
  if key == "enable" then
    SetupCount()
    events:RegisterEvent("QUEST_LOG_UPDATE")

    local scanner = CreateFrame("Frame")
    local elapsedTotal = 0
    scanner:SetScript("OnUpdate", function (_, elapsed)
      elapsedTotal = elapsedTotal + elapsed
      if elapsedTotal >= SCAN_EVERY then
        elapsedTotal = 0
        SetupCount() -- the Quests section may only exist after the first quest
        ScanBars()
        DimCompleted()
      end
    end)
  elseif key == "questCount" or key == "profile" then
    UpdateCount()
  end
  if key == "completedObjectives" or key == "profile" then
    DimCompleted()
  end
  if key == "glassBars" or key == "glassLook" or key == "titleColor" or key == "profile" then
    UpdateBars()
  end
end)
