local _, ns = ...
local Core = ns.Core

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local GetTime = GetTime
local hooksecurefunc = hooksecurefunc
-- luacheck: pop

local ASSETS = "Interface\\AddOns\\GlassForeverTracker\\Assets\\"
local SCAN_EVERY = 0.5

----
-- Icons
--
-- With the Glass look, the tracker's round quest icons ("?" ready to turn in,
-- "..." in progress) and its minimize buttons become plain icons in the Glass
-- gold (or another color), lighter under the mouse or on the quest you're
-- following. Only the look changes: clicks still go to the game. Other icons
-- (world quests, bonus objectives...) keep the game's look.

local tracker = _G.ObjectiveTrackerFrame
local GOLD = Core.GOLD

-- Glass icons are on with the Glass look, unless the icon color is "game"
local function GlassLook()
  local profile = Core.db.profile
  return profile.glassLook and profile.iconColor ~= "game"
end

-- Keeps one of the game's textures (or frames) transparent while its button
-- uses the Glass icon
local function KeepHidden(region, button)
  if not region or region.gftHidden then return end
  region.gftHidden = true
  hooksecurefunc(region, "SetAlpha", function (_, alpha)
    if button.gftStyled and alpha ~= 0 then region:SetAlpha(0) end
  end)
end

local Smooth = Core.Smooth -- grows smoothly, not pixel by pixel

local function CreateIcon(button, size)
  local icon = Smooth(button:CreateTexture(nil, "OVERLAY", nil, 7))
  icon:SetSize(size, size)
  icon:SetPoint("CENTER")
  button.gftIcon = icon

  -- The outline: the icon's shape a little bigger, in black, behind it
  local outline = Smooth(button:CreateTexture(nil, "OVERLAY", nil, 6))
  outline:SetSize(size, size)
  outline:SetPoint("CENTER")
  outline:SetVertexColor(0, 0, 0, 0.9)
  outline:Hide()
  button.gftOutline = outline

  -- The frame's own HookScript (secure)
  button:HookScript("OnEnter", function () button.gftHover = true; button:gftUpdate() end)
  button:HookScript("OnLeave", function () button.gftHover = false; button:gftUpdate() end)
  return icon
end

-- Shows a Glass icon (and its outline, with the option on), or hides them
local function ShowIcon(button, name)
  if name then
    button.gftIcon:SetTexture(ASSETS..name)
    button.gftIcon:Show()
    button.gftOutline:SetTexture(ASSETS..name.."Outline")
    button.gftOutline:SetShown(Core.db.profile.iconOutline)
  else
    button.gftIcon:Hide()
    button.gftOutline:Hide()
  end
end

local LIGHTER = 0.55 -- how much white is mixed in on the followed quest

-- The chosen icon color. Under the mouse and on the quest you follow it's a
-- lighter version of it, so the color still shows (white icons get gold).
local function SetIconColor(button, bright)
  local choice = Core.db.profile.iconColor
  local r, g, b = Core:Color(choice)
  r, g, b = r or GOLD.r, g or GOLD.g, b or GOLD.b
  if bright or button.gftHover then
    if choice == "white" then
      r, g, b = GOLD.r, GOLD.g, GOLD.b
    else
      r, g, b = r + (1 - r) * LIGHTER, g + (1 - g) * LIGHTER, b + (1 - b) * LIGHTER
    end
  end
  button.gftIcon:SetVertexColor(r, g, b)
end

----
-- Quest icons

local POI_ICONS = {}
local function PoiIcon(style)
  local styles = _G.POIButtonUtil and _G.POIButtonUtil.Style
  if not styles then return nil end
  if style == styles.QuestComplete then return "questComplete" end
  if style == styles.QuestInProgress then return "questProgress" end
  return nil
end

-- Icon animations, done frame by frame by the addon itself (the game's scale
-- animations kept growing here): the size is worked out each frame and can't
-- go past MAX_SCALE.
-- - Pulse: a quest ready to turn in, its "?" a little bigger and fainter,
--   then back, over and over
-- - Ring: a quest just added, a soft ring opens around its icon
local ICON_SIZE = 16
local MAX_SCALE = 1.5
local PULSE_TIME = 0.7   -- seconds to grow (and as many to come back)
local PULSE_GROW = 0.18  -- 18% bigger at the top
local RING_TIME, RING_SIZE = 1.0, 30
local RING_LIGHT_UP = 0.25 -- part of the time it takes to light up
local PULSE_EASE = 0.4     -- seconds the "?" pulse takes to calm down or come back around the ring

local animated = {} -- button -> { pulse = start time, ring = start time }
local animator = CreateFrame("Frame")
animator:Hide()

animator:SetScript("OnUpdate", function ()
  local now = GetTime()
  for button, state in pairs(animated) do
    local scale, alpha = 1, 1

    if state.pulse then
      -- On a shared clock, not from its start: the game redoes the icons
      -- often (any quest log change), which restarted the pulse halfway
      local t = now % (PULSE_TIME * 2)
      local wave = 0.5 - 0.5 * math.cos(math.pi * t / PULSE_TIME)
      -- Quiet while the ring opens (both together looked like a double
      -- pulse): it eases out as the ring starts and back in after it ends
      local strength = 1
      if state.ring then
        strength = 1 - math.min(1, (now - state.ring) / PULSE_EASE)
      elseif state.ringEnded then
        strength = math.min(1, (now - state.ringEnded) / PULSE_EASE)
        if strength >= 1 then state.ringEnded = nil end
      end
      wave = wave * strength * strength * (3 - 2 * strength)
      scale = scale * (1 + PULSE_GROW * wave)
      alpha = 1 - 0.4 * wave
    end

    if state.ring and button.gftRing then
      local k = (now - state.ring) / RING_TIME
      if k < 1 then
        -- Opens with a soft start and end, lights up gently at first and
        -- fades out smoothly at the end
        local size = RING_SIZE * (0.6 + 0.9 * k * k * (3 - 2 * k))
        button.gftRing:SetSize(size, size)
        local light = k < RING_LIGHT_UP and k / RING_LIGHT_UP or (1 - k) / (1 - RING_LIGHT_UP)
        button.gftRing:SetAlpha(0.8 * light * light * (3 - 2 * light))
      else
        button.gftRing:SetAlpha(0)
        button.gftRing:Hide()
        state.ring = nil
        state.ringEnded = now
      end
    end

    local size = ICON_SIZE * math.min(scale, MAX_SCALE)
    button.gftIcon:SetSize(size, size)
    button.gftIcon:SetAlpha(alpha)
    button.gftOutline:SetSize(size, size)
    button.gftOutline:SetAlpha(alpha)

    if not (state.pulse or state.ring) then
      animated[button] = nil
    end
  end
  if next(animated) == nil then animator:Hide() end
end)

local function Animate(button, key, on)
  local state = animated[button]
  if on then
    if not state then
      state = {}
      animated[button] = state
    end
    if key == "pulse" and not state.pulse then Core:AnimLog("? pulse starts", tostring(button)) end
    if key ~= "pulse" or not state.pulse then state[key] = GetTime() end
    animator:Show()
  elseif state and state[key] then
    state[key] = nil
    if key == "pulse" then button.gftIcon:SetAlpha(1) end
    -- Back to its normal size (the animator lets go of it once nothing's left)
    animator:Show()
  end
end

-- The game's art of a quest icon, as lists made once per icon (this runs
-- many times a second as the game updates its icons; new lists each time
-- were garbage)
local function PoiParts(button)
  if not button.gftParts then
    button.gftFadedParts = { button.NormalTexture, button.PushedTexture }
    button.gftLitParts = { button.HighlightTexture, button.Glow, button.Display }
    button.gftParts = { button.NormalTexture, button.PushedTexture, button.HighlightTexture, button.Glow, button.Display }
  end
  return button.gftParts
end

local function UpdatePoi(button)
  local icon = GlassLook() and PoiIcon(button:GetStyle())
  local styled = icon and true or false
  button.gftStyled = styled

  PoiParts(button)
  local buttonAlpha = button.CalculateButtonAlpha and button:CalculateButtonAlpha() or 1
  for _, region in ipairs(button.gftFadedParts) do
    region:SetAlpha(styled and 0 or buttonAlpha)
  end
  for _, region in ipairs(button.gftLitParts) do
    region:SetAlpha(styled and 0 or 1)
  end

  if styled then
    ShowIcon(button, icon)
    SetIconColor(button, button:IsSelected())
  else
    ShowIcon(button, nil)
  end

  -- A quest ready to turn in: the "?" pulses gently until it's turned in
  Animate(button, "pulse", styled and icon == "questComplete" and Core:Animates())
end

local function StylePoi(button)
  if not button or POI_ICONS[button] then
    if button then UpdatePoi(button) end
    return
  end
  POI_ICONS[button] = true

  CreateIcon(button, 16)
  button.gftUpdate = UpdatePoi
  for _, region in ipairs({ button.NormalTexture, button.PushedTexture, button.HighlightTexture, button.Glow, button.Display }) do
    KeepHidden(region, button)
  end
  -- The game changes the icon when a quest is completed or followed
  hooksecurefunc(button, "UpdateButtonStyle", UpdatePoi)
  hooksecurefunc(button, "SetSelected", UpdatePoi)
  -- Other moments the game touches its art (when reused for another quest,
  -- its transparency, its highlight...): hide it again after each
  for _, method in ipairs({ "UpdateButtonAlpha", "EvaluateManagedHighlight", "UpdateSelected", "SetStyle", "Reset" }) do
    if button[method] then hooksecurefunc(button, method, UpdatePoi) end
  end
  button:HookScript("OnShow", UpdatePoi)
  -- The game's own entrance makes the whole icon grow, and growing
  -- animations go wrong in this game version: it's stopped (the Glass icon
  -- has its own ring)
  -- The game starts it with Play or with Restart, and Restart doesn't fire
  -- OnPlay: both are caught
  if button.AddAnim then
    local group = button.AddAnim
    group:HookScript("OnPlay", function () group:Stop() end)
    hooksecurefunc(group, "Restart", function () group:Stop() end)
    hooksecurefunc(group, "Play", function () group:Stop() end)
  end
  UpdatePoi(button)
end

-- Safety check, from the regular scan: the game's art of a quest icon must
-- stay hidden while it uses the Glass icon, and the icon must match its quest
local function EnforcePoi(button)
  -- A ring left over after its animation
  if button.gftRing and button.gftRing:IsShown() and not (animated[button] and animated[button].ring) then
    button.gftRing:SetAlpha(0)
    button.gftRing:Hide()
  end
  local wanted = GlassLook() and PoiIcon(button:GetStyle()) and true or false
  if wanted ~= button.gftStyled then
    UpdatePoi(button)
    return
  end
  if not wanted then return end
  for _, region in ipairs(PoiParts(button)) do
    if region and region:GetAlpha() > 0.001 then
      UpdatePoi(button)
      return
    end
  end
end

-- A quest just added (Animations: Glass): a soft ring opens around its icon,
-- in the icon color
local function RingIcon(button)
  if not button or not button.gftIcon or not button.gftStyled then
    Core:AnimLog("ring skipped: icon not ready", tostring(button))
    return
  end
  if not button.gftRing then
    local ring = Smooth(button:CreateTexture(nil, "OVERLAY", nil, 5))
    ring:SetTexture(ASSETS.."ring")
    ring:SetBlendMode("ADD")
    ring:SetPoint("CENTER")
    ring:SetAlpha(0)
    button.gftRing = ring
  end
  -- Already opening: the game can report the same new quest again a moment
  -- later, and starting over halfway looked like a jump back
  local state = animated[button]
  if state and state.ring and GetTime() - state.ring < RING_TIME then
    Core:AnimLog("ring skipped: already opening", tostring(button))
    return
  end
  Core:AnimLog("ring starts", tostring(button), "quest", tostring(button.questID))
  local r, g, b = button.gftIcon:GetVertexColor()
  button.gftRing:SetVertexColor(r, g, b)
  button.gftRing:Show()
  -- Only the ring: the icon also growing at the same time looked like a
  -- double pulse
  Animate(button, "ring", true)
end

----
-- Minimize buttons

local MINIMIZE_BUTTONS = {}

local function UpdateMinimize(button)
  local header = button:GetParent()
  local owner = header and header:GetParent()
  local collapsed = owner and owner.IsCollapsed and owner:IsCollapsed()
  local styled = GlassLook()
  button.gftStyled = styled

  for _, region in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture() }) do
    if region then region:SetAlpha(styled and 0 or 1) end
  end

  if styled then
    ShowIcon(button, collapsed and "expand" or "collapse")
    SetIconColor(button, false)
  else
    ShowIcon(button, nil)
  end
end

local function StyleMinimize(header)
  local button = header and header.MinimizeButton
  if not button then return end
  if MINIMIZE_BUTTONS[button] then return end
  MINIMIZE_BUTTONS[button] = true

  CreateIcon(button, 14)
  button.gftUpdate = UpdateMinimize
  for _, region in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture() }) do
    KeepHidden(region, button)
  end
  -- Plus when collapsed, bar when open
  hooksecurefunc(header, "SetCollapsed", function () UpdateMinimize(button) end)
  UpdateMinimize(button)
end

----
-- Quest names in the chosen color. The game (and other addons) color them
-- again on every update, so the color is put back right after.

local QUEST_NAMES = {}

-- The game's own color and text of each name are remembered (as the game or
-- another addon sets them), so "Game colors" can put them back right away.

local function ApplyQuestNameColor(text)
  local r, g, b = Core:Color(Core.db.profile.questNameColor)
  local game = text.gftGameColor
  if not r then
    -- "auto": back to the game's color
    if not game then return end
    r, g, b = game[1], game[2], game[3]
  end
  text.gftColoring = true
  text:SetTextColor(r, g, b)
  text.gftColoring = false
end

-- Other addons can put a color inside the text itself (e.g. the quest level
-- in its difficulty color), which wins over any text color: with a chosen
-- color, those inline colors are taken out (and put back with "Game colors")
local function StripInlineColors(text)
  local value = text.gftGameText
  if type(value) ~= "string" then return end
  local shown = value
  if Core:Color(Core.db.profile.questNameColor) and value:find("|c") then
    shown = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn.-:", ""):gsub("|r", "")
  end
  if text:GetText() == shown then return end
  text.gftColoring = true
  text:SetText(shown)
  text.gftColoring = false
end

local function Readable(value)
  return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function ColorQuestName(text)
  if not text or QUEST_NAMES[text] then return end
  QUEST_NAMES[text] = true

  local r, g, b = text:GetTextColor()
  if Readable(r) then text.gftGameColor = { r, g, b } end
  local value = text:GetText()
  if Readable(value) then text.gftGameText = value end

  hooksecurefunc(text, "SetTextColor", function (_, nr, ng, nb)
    if text.gftColoring then return end
    if Readable(nr) then text.gftGameColor = { nr, ng, nb } end
    ApplyQuestNameColor(text)
  end)
  hooksecurefunc(text, "SetText", function (_, newValue)
    if text.gftColoring then return end
    text.gftGameText = Readable(newValue) and newValue or nil
    StripInlineColors(text)
  end)
  StripInlineColors(text)
  ApplyQuestNameColor(text)
end

-- For /gft debug: the state of each quest icon
function Core:IconsDetails()
  local function Part(region)
    if not region then return "-" end
    return string.format("%s/%.2f", region:IsShown() and "shown" or "hidden", region:GetAlpha())
  end
  for button in pairs(POI_ICONS) do
    if button:IsVisible() then
      print(string.format("  icon style %s glass %s | normal %s glow %s highlight %s display %s | ours %s ring %s",
        tostring(button:GetStyle()), tostring(button.gftStyled),
        Part(button.NormalTexture), Part(button.Glow), Part(button.HighlightTexture), Part(button.Display),
        Part(button.gftIcon), Part(button.gftRing)))
    end
  end
end

-- For /gft debug
function Core:IconsDebug()
  local pois, names = 0, 0
  for _ in pairs(POI_ICONS) do pois = pois + 1 end
  for _ in pairs(QUEST_NAMES) do names = names + 1 end
  return pois, names
end

----
-- Finding them: quest blocks come and go, so the tracker is checked often
-- (cheap: only things not seen before are set up)

local function Scan()
  StyleMinimize(tracker.Header)
  for _, module in ipairs(tracker.modules or {}) do
    StyleMinimize(module.Header)
    for _, blocks in pairs(module.usedBlocks or {}) do
      for _, block in pairs(blocks) do
        if block.poiButton and POI_ICONS[block.poiButton] then
          EnforcePoi(block.poiButton)
        elseif block.poiButton then
          StylePoi(block.poiButton)
        end
        ColorQuestName(block.HeaderText)
      end
    end
  end
end

local function UpdateAll()
  for button in pairs(POI_ICONS) do UpdatePoi(button) end
  for button in pairs(MINIMIZE_BUTTONS) do UpdateMinimize(button) end
end

Core:OnChange(function (key, ...)
  if key == "enable" then
    local scanner = CreateFrame("Frame")
    local elapsedTotal = 0
    scanner:SetScript("OnUpdate", function (_, elapsed)
      elapsedTotal = elapsedTotal + elapsed
      if elapsedTotal >= SCAN_EVERY then
        elapsedTotal = 0
        Scan()
      end
    end)
    Scan()
  elseif key == "sectionAdded" then
    Scan() -- the icons of a new section, without waiting for the next check
  elseif key == "questAdded" then
    local block = ...
    if block and block.poiButton and Core:Animates() then
      StylePoi(block.poiButton)
      RingIcon(block.poiButton)
    end
  elseif key == "glassLook" or key == "iconColor" or key == "iconOutline" or key == "sectionAnimation" or key == "profile" then
    UpdateAll()
  end
  if key == "questNameColor" or key == "profile" then
    -- Back to "auto": the game colors them again on its next update
    for text in pairs(QUEST_NAMES) do
      StripInlineColors(text)
      ApplyQuestNameColor(text)
    end
  end
end)
