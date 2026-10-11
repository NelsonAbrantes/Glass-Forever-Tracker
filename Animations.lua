local _, ns = ...
local Core = ns.Core

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local GetTime = GetTime
local geterrorhandler = geterrorhandler
-- luacheck: pop

local SLIDE_DISTANCE = 30
local SLIDE_TIME = 0.4
local TYPE_SPEED = 45        -- letters per second when the name writes itself
local TYPE_SOFTNESS = 6      -- letters fading in at the edge of the writing
local LINE_DELAY = 0.12      -- between one objective and the next
local LINE_FADE = 0.3

----
-- Animations
--
-- The entrance of a quest just added to the tracker (Animations: Glass):
-- - the quest slides in from the right
-- - its name writes itself, letter by letter
-- - its objectives appear one by one, right after the name
-- (the icon's pop and ring are in Icons.lua). Only the look changes: the
-- quest is already in its place in the game's tracker.

-- Small animations run frame by frame: each task gets the time since it
-- started and returns true when it's done
local tasks = {}
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function ()
  local now = GetTime()
  for task, started in pairs(tasks) do
    -- A task that fails is dropped, so an error can't repeat every frame
    local ok, done = pcall(task, now - started)
    if not ok or done then tasks[task] = nil end
    if not ok then geterrorhandler()(done) end
  end
  if next(tasks) == nil then driver:Hide() end
end)

local function Run(task)
  tasks[task] = GetTime()
  driver:Show()
end

-- The quest slides in from the right
local function Slide(block)
  if not block.gftSlide then
    local group = block:CreateAnimationGroup()
    local away = group:CreateAnimation("Translation")
    away:SetOffset(SLIDE_DISTANCE, 0)
    away:SetDuration(0)
    away:SetOrder(1)
    local back = group:CreateAnimation("Translation")
    back:SetOffset(-SLIDE_DISTANCE, 0)
    back:SetDuration(SLIDE_TIME)
    back:SetOrder(2)
    back:SetSmoothing("OUT")
    block.gftSlide = group
  end
  block.gftSlide:Stop()
  block.gftSlide:Play()
end

-- The name writes itself: the letters show from left to right, with a soft
-- edge. Returns how long it takes.
local function TypeName(text)
  if not text or not text.SetAlphaGradient then return 0 end
  local value = text:GetText()
  if type(value) ~= "string" or (issecretvalue and issecretvalue(value)) then return 0 end
  local _, length = value:gsub("[^\128-\191]", "") -- letters, not bytes (accented letters take more)
  local duration = length / TYPE_SPEED
  text:SetAlphaGradient(0, TYPE_SOFTNESS)
  Run(function (elapsed)
    if elapsed >= duration then
      text:SetAlphaGradient(length + TYPE_SOFTNESS, 1) -- all shown (the game needs a length of at least 1)
      return true
    end
    text:SetAlphaGradient(math.floor(elapsed * TYPE_SPEED), TYPE_SOFTNESS)
    return false
  end)
  return duration
end

-- The objectives appear one by one, top to bottom, starting after `delay`
local function ShowLines(block, delay)
  local lines = {}
  for _, line in pairs(block.usedLines or {}) do
    table.insert(lines, line)
  end
  table.sort(lines, function (a, b) return (a:GetTop() or 0) > (b:GetTop() or 0) end)

  for i, line in ipairs(lines) do
    -- The game fades them all in at once: ours instead
    if line.FadeInAnim then line.FadeInAnim:Stop() end
    line.gftAnimating = true
    line:SetAlpha(0)
    local start = delay + (i - 1) * LINE_DELAY
    Run(function (elapsed)
      local progress = (elapsed - start) / LINE_FADE
      if progress >= 1 then
        line:SetAlpha(1)
        line.gftAnimating = false
        return true
      end
      line:SetAlpha(math.max(0, progress))
      return false
    end)
  end
end

Core:OnChange(function (key, block)
  if key ~= "questAdded" or not block then return end
  if not Core:Animates() then return end
  Slide(block)
  local typing = TypeName(block.HeaderText)
  -- Objectives start when the name is about half written
  ShowLines(block, typing * 0.5)
end)
