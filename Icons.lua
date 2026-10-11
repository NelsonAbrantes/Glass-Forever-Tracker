local _, ns = ...
local Core = ns.Core

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
-- luacheck: pop

local ASSETS = "Interface\\AddOns\\GlassForeverTracker\\Assets\\"
local SCAN_EVERY = 0.3

----
-- Icons
--
-- With the Glass look, the tracker's round quest icons ("?" ready to turn in,
-- "..." in progress) and its minimize buttons become plain icons in the Glass
-- gold, white under the mouse or on the quest you're following. Only the look
-- changes: clicks still go to the game. Other icons (world quests, bonus
-- objectives...) keep the game's look.

local tracker = _G.ObjectiveTrackerFrame
local GOLD = Core.GOLD

local function GlassLook() return Core.db.profile.glassLook end

-- Keeps one of the game's textures (or frames) transparent while its button
-- uses the Glass icon
local function KeepHidden(region, button)
  if not region or region.gftHidden then return end
  region.gftHidden = true
  hooksecurefunc(region, "SetAlpha", function (_, alpha)
    if button.gftStyled and alpha ~= 0 then region:SetAlpha(0) end
  end)
end

local function CreateIcon(button, size)
  local icon = button:CreateTexture(nil, "OVERLAY", nil, 7)
  icon:SetSize(size, size)
  icon:SetPoint("CENTER")
  button.gftIcon = icon

  -- The frame's own HookScript (secure)
  button:HookScript("OnEnter", function () button.gftHover = true; button:gftUpdate() end)
  button:HookScript("OnLeave", function () button.gftHover = false; button:gftUpdate() end)
  return icon
end

local function SetIconColor(button, bright)
  if bright or button.gftHover then
    button.gftIcon:SetVertexColor(1, 1, 1)
  else
    button.gftIcon:SetVertexColor(GOLD.r, GOLD.g, GOLD.b)
  end
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

local function UpdatePoi(button)
  local icon = GlassLook() and PoiIcon(button:GetStyle())
  local styled = icon and true or false
  button.gftStyled = styled

  local buttonAlpha = button.CalculateButtonAlpha and button:CalculateButtonAlpha() or 1
  for _, region in ipairs({ button.NormalTexture, button.PushedTexture }) do
    region:SetAlpha(styled and 0 or buttonAlpha)
  end
  for _, region in ipairs({ button.HighlightTexture, button.Glow, button.Display }) do
    region:SetAlpha(styled and 0 or 1)
  end

  if styled then
    button.gftIcon:SetTexture(ASSETS..icon)
    button.gftIcon:Show()
    SetIconColor(button, button:IsSelected())
  else
    button.gftIcon:Hide()
  end
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
  UpdatePoi(button)
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
    button.gftIcon:SetTexture(ASSETS..(collapsed and "expand" or "collapse"))
    button.gftIcon:Show()
    SetIconColor(button, false)
  else
    button.gftIcon:Hide()
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
-- Finding them: quest blocks come and go, so the tracker is checked often
-- (cheap: only icons not seen before are set up)

local function Scan()
  StyleMinimize(tracker.Header)
  for _, module in ipairs(tracker.modules or {}) do
    StyleMinimize(module.Header)
    for _, blocks in pairs(module.usedBlocks or {}) do
      for _, block in pairs(blocks) do
        if block.poiButton and not POI_ICONS[block.poiButton] then
          StylePoi(block.poiButton)
        end
      end
    end
  end
end

local function UpdateAll()
  for button in pairs(POI_ICONS) do UpdatePoi(button) end
  for button in pairs(MINIMIZE_BUTTONS) do UpdateMinimize(button) end
end

Core:OnChange(function (key)
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
  elseif key == "glassLook" or key == "profile" then
    UpdateAll()
  end
end)
