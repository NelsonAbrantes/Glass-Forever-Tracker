local _, ns = ...
local Core = ns.Core

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
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

-- Smooth start and end
local function Ease(k) return k * k * (3 - 2 * k) end

-- The game can start its own fade of the objectives again while ours runs:
-- ours wins, otherwise they flash
local function KeepOurFade(line)
  if line.gftFadeHooked or not line.FadeInAnim then return end
  line.gftFadeHooked = true
  line.FadeInAnim:HookScript("OnPlay", function (group)
    if line.gftAnimating then group:Stop() end
  end)
end

-- The objectives appear one by one, top to bottom, starting after `delay`
local function ShowLines(block, delay)
  local lines = {}
  for _, line in pairs(block.usedLines or {}) do
    table.insert(lines, line)
  end

  -- Hidden right away; the game fades them all in at once, ours instead
  for _, line in ipairs(lines) do
    KeepOurFade(line)
    line.gftAnimating = true
    if line.FadeInAnim then line.FadeInAnim:Stop() end
    line:SetAlpha(0)
    -- Never left invisible, even if something stopped the fade
    C_Timer.After(delay + #lines * LINE_DELAY + LINE_FADE + 1, function ()
      if line.gftAnimating then
        line.gftAnimating = false
        line:SetAlpha(1)
      end
    end)
  end

  -- Their order on screen is only known once the game has placed them, a
  -- moment later: sort then, top to bottom
  local order
  Run(function (elapsed)
    if not order then
      table.sort(lines, function (a, b) return (a:GetTop() or 0) > (b:GetTop() or 0) end)
      order = {}
      for i, line in ipairs(lines) do order[line] = i end
    end
    local done = true
    for _, line in ipairs(lines) do
      if line.gftAnimating then
        local start = delay + (order[line] - 1) * LINE_DELAY
        local progress = (elapsed - start) / LINE_FADE
        if progress >= 1 then
          line:SetAlpha(1)
          line.gftAnimating = false
        else
          line:SetAlpha(Ease(math.max(0, progress)))
          done = false
        end
      end
    end
    return done
  end)
end

Core:OnChange(function (key, block)
  if key ~= "questAdded" or not block then return end
  if not Core:Animates() then return end
  -- The quest's item button can't be moved in a fight: no slide then. Nor
  -- while the whole tracker is sliding in: two slides at once looked jumpy.
  if not InCombatLockdown() and not Core:TrackerSliding() then Slide(block) end
  local typing = TypeName(block.HeaderText)
  -- Objectives start when the name is about half written
  ShowLines(block, typing * 0.5)
end)
