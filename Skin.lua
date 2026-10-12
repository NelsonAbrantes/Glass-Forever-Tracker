local _, ns = ...
local Core = ns.Core

-- luacheck: push ignore 113
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetTime = GetTime
local hooksecurefunc = hooksecurefunc
-- luacheck: pop

----
-- Skin
--
-- The Glass look: no header bars or panel background from the game, the
-- tracker's text in the Glass font, and section titles in the Glass gold.
-- Nothing of the game's tracker is replaced: its art is kept transparent and
-- its fonts get another typeface, so turning the look off brings it all back.

local tracker = _G.ObjectiveTrackerFrame

-- The tracker's own fonts: titles (sections and quest names) and objectives
local FONTS = {
  { name = "ObjectiveTrackerHeaderFont", size = "headerFontSize", title = true },
  { name = "ObjectiveTrackerLineFont", size = "lineFontSize" },
}
local originalFonts = {}

local function Profile() return Core.db.profile end

-- Keeps a piece of the game's art transparent while the Glass look is on
local hidden = {}
local function KeepHidden(region)
  if not region then return end
  region:SetAlpha(Profile().glassLook and 0 or 1)
  if hidden[region] then return end
  hidden[region] = true
  hooksecurefunc(region, "SetAlpha", function (_, alpha)
    if Profile().glassLook and alpha ~= 0 then region:SetAlpha(0) end
  end)
end

-- Titles hidden in the options. They keep their place: the space is the
-- game's layout, and changing it could block the quest item buttons in combat.
local function ShowHeader(header, show)
  if header then header:SetAlpha(show and 1 or 0) end
end

local SOFT = "Interface\\AddOns\\GlassForeverTracker\\Assets\\softBackground"
local LINE = "Interface\\AddOns\\GlassForeverTracker\\Assets\\line"

-- The Glass animation: a thin line in the title color lights up under a text
-- (fading at both ends, like the Glass edit box line) and, for titles, a soft
-- shine passes over it; then it all fades. Made of our own textures on the
-- frame that owns the text:
-- - "title": a new section or quest (with the shine)
-- - "line": an objective that moved on (only the line, quicker)
local function GlassAnimation(owner, anchor, kind)
  owner.gftAnims = owner.gftAnims or {}
  if owner.gftAnims[kind] then return owner.gftAnims[kind] end

  -- One line across the text, fading at both ends (the image does that)
  local glassLine = Core.Smooth(owner:CreateTexture(nil, "ARTWORK"))
  glassLine:SetTexture(LINE)
  glassLine:SetHeight(1)
  glassLine:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -1)
  glassLine:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -1)
  glassLine:SetAlpha(0)

  local anim = owner:CreateAnimationGroup()
  local function Fade(target, from, to, duration, delay)
    local fade = anim:CreateAnimation("Alpha")
    fade:SetTarget(target)
    fade:SetFromAlpha(from)
    fade:SetToAlpha(to)
    fade:SetDuration(duration)
    fade:SetStartDelay(delay or 0)
    fade:SetSmoothing("IN_OUT")
    return fade
  end

  local quick = kind == "line"
  Fade(glassLine, 0, 1, quick and 0.2 or 0.3, 0.1)
  Fade(glassLine, 1, 0, quick and 0.6 or 0.9, quick and 0.6 or 1.2)

  local shine
  if not quick then
    shine = Core.Smooth(owner:CreateTexture(nil, "OVERLAY"))
    shine:SetTexture(SOFT)
    shine:SetBlendMode("ADD")
    shine:SetPoint("LEFT", anchor, "LEFT", -35, 0)
    shine:SetAlpha(0)
    Fade(shine, 0, 0.5, 0.3, 0.2)
    Fade(shine, 0.5, 0, 0.5, 0.9)
    local move = anim:CreateAnimation("Translation")
    move:SetTarget(shine)
    move:SetDuration(1.2)
    move:SetStartDelay(0.2)
    move:SetSmoothing("IN_OUT")
    anim.gftMove = move
  end

  anim:SetScript("OnFinished", function ()
    glassLine:SetAlpha(0)
    if shine then shine:SetAlpha(0) end
  end)

  anim.gftLine = glassLine
  anim.gftShine = shine
  anim.gftAnchor = anchor
  owner.gftAnims[kind] = anim
  return anim
end

local function PlayGlass(owner, anchor, kind)
  local anim = GlassAnimation(owner, anchor, kind)
  local r, g, b = Core:Color(Profile().titleColor)
  r, g, b = r or Core.GOLD.r, g or Core.GOLD.g, b or Core.GOLD.b
  anim.gftLine:SetVertexColor(r, g, b)
  if anim.gftShine then
    -- Shine as tall as the text, passing over its whole width
    anim.gftShine:SetSize(70, math.max(12, anchor:GetHeight()))
    anim.gftMove:SetOffset(math.max(100, anchor:GetWidth()), 0)
  end
  anim:Stop()
  anim:Play()
end

-- A new section: the title also fades in
local function PlayGlassAnimation(header)
  if header.Text then
    header.gftTitleFade = header.gftTitleFade or header.Text:CreateAnimationGroup()
    local fadeIn = header.gftTitleFade
    if not fadeIn.gftReady then
      fadeIn.gftReady = true
      local alpha = fadeIn:CreateAnimation("Alpha")
      alpha:SetFromAlpha(0)
      alpha:SetToAlpha(1)
      alpha:SetDuration(0.5)
      alpha:SetSmoothing("OUT")
    end
    fadeIn:Stop()
    fadeIn:Play()
  end
  PlayGlass(header, header.Text or header, "title")
end

----
-- Quests and objectives: the game's gold glows are made invisible (their
-- animations keep running, so the tracker works as usual) and the Glass
-- animation plays instead. Hooked once per quest block and objective line;
-- the game reuses them.

local GLOW_ATLAS = "ui-questtracker-objfx-barglow"
local FLASH_TIME = 0.45 -- how long a completed objective stays white

-- The check of a completed objective pops: a little bigger, then back to
-- its size. Worked out frame by frame and capped, unlike the game's own.
local CHECK_SIZE, CHECK_GROW, CHECK_TIME = 16, 0.25, 0.3
local popping = {} -- check texture -> start time
local popper = CreateFrame("Frame")
popper:Hide()
popper:SetScript("OnUpdate", function ()
  local now = GetTime()
  for check, start in pairs(popping) do
    local k = (now - start) / CHECK_TIME
    if k >= 1 then
      check:SetSize(CHECK_SIZE, CHECK_SIZE)
      popping[check] = nil
    else
      local size = CHECK_SIZE * (1 + CHECK_GROW * math.sin(math.pi * k))
      check:SetSize(size, size)
    end
  end
  if next(popping) == nil then popper:Hide() end
end)

local function PopCheck(check)
  Core.Smooth(check) -- grows smoothly, not pixel by pixel
  popping[check] = GetTime()
  popper:Show()
end

local function GlassAnimations()
  local profile = Profile()
  return profile.glassLook and profile.sectionAnimation ~= "game"
end

local function SetGlow(texture)
  if not texture then return end
  if GlassAnimations() then
    texture:SetTexture(nil)
  else
    texture:SetAtlas(GLOW_ATLAS)
  end
end

local hookedBlocks, hookedLines = {}, {}
local ADDED_AGAIN = 1 -- seconds: the same quest again this soon isn't new

local function HookBlock(block)
  if hookedBlocks[block] then return end
  hookedBlocks[block] = true
  SetGlow(block.HeaderGlow)
  local function Play(added)
    SetGlow(block.HeaderGlow)
    -- The game can report the same new quest twice: starting it all over
    -- halfway looked like a jump
    if added then
      local now = GetTime()
      if block.gftAddedID == block.id and now - (block.gftAddedAt or 0) < ADDED_AGAIN then return end
      block.gftAddedAt, block.gftAddedID = now, block.id
    end
    if GlassAnimations() and Profile().sectionAnimation ~= "off" and block.HeaderText then
      Core:Changed("sectionAdded") -- shows the tracker
      if Core:Animates() then
        PlayGlass(block, block.HeaderText, "title")
      end
      -- A quest just added: its entrance (Animations.lua, Icons.lua)
      if added then Core:Changed("questAdded", block) end
    end
  end
  if block.AddAnim then
    block.AddAnim:HookScript("OnPlay", function () Play(true) end)
  end
  if block.TurnInAnim then
    block.TurnInAnim:HookScript("OnPlay", function () Play(false) end)
  end
  -- Caught while its animation was already playing
  if block.AddAnim and block.AddAnim:IsPlaying() then
    Play(true)
  elseif block.TurnInAnim and block.TurnInAnim:IsPlaying() then
    Play(false)
  end
end

local function HookLine(line)
  if hookedLines[line] then return end
  hookedLines[line] = true
  SetGlow(line.Glow)
  if line.GlowAnim then
    local function Play()
      SetGlow(line.Glow)
      if Core:Animates() and line.Text then
        PlayGlass(line, line.Text, "line")
      end
    end
    line.GlowAnim:HookScript("OnPlay", Play)
    -- Caught while its animation was already playing
    if line.GlowAnim:IsPlaying() then Play() end
  end

  -- An objective completed (the game shows its green check). The game's own
  -- animation makes the check grow, and growing animations go wrong in this
  -- game version (the check flew at the screen, huge): it's stopped, and the
  -- check pops by hand instead. Then the text lights up white for a moment
  -- and goes back to its color.
  if line.CheckAnim then
    line.CheckAnim:HookScript("OnPlay", function ()
      line.CheckAnim:Stop()
      if line.CheckGlow then line.CheckGlow:SetAlpha(0) end
      if line.Icon then
        line.Icon:SetAlpha(1)
        if Core:Animates() then PopCheck(line.Icon) end
      end
      if not Core:Animates() or not line.Text then return end
      local text = line.Text
      local r, g, b = text:GetTextColor()
      text:SetTextColor(1, 1, 1)
      C_Timer.After(FLASH_TIME, function ()
        -- Unless the game has colored it again meanwhile
        local nr, ng, nb = text:GetTextColor()
        if nr == 1 and ng == 1 and nb == 1 then text:SetTextColor(r, g, b) end
      end)
    end)
  end
end

local function HookQuestAnimations()
  for _, module in ipairs(tracker.modules or {}) do
    for _, blocks in pairs(module.usedBlocks or {}) do
      for _, block in pairs(blocks) do
        if block.AddAnim then HookBlock(block) end
        for _, line in pairs(block.usedLines or {}) do
          if line.GlowAnim then HookLine(line) end
        end
      end
    end
  end
end

local function UpdateGlows()
  for block in pairs(hookedBlocks) do SetGlow(block.HeaderGlow) end
  for line in pairs(hookedLines) do SetGlow(line.Glow) end
end

-- /gft testanim: plays the chosen animation on the first section shown.
-- Returns "off" when the animation is off, false when no section is shown.
function Core:TestAnimation()
  local mode = Profile().sectionAnimation
  if mode == "off" then return "off" end
  for _, module in ipairs(tracker.modules or {}) do
    local header = module.Header
    if header and header:IsVisible() then
      Core:Changed("sectionAdded") -- shows the tracker
      if mode == "game" or not Profile().glassLook then
        if header.AddAnim then header.AddAnim:Restart() end
      else
        PlayGlassAnimation(header)
      end
      return true
    end
  end
  return false
end

-- When a section appears (e.g. "Quests" with the first quest), the game plays
-- an animation with its own header bar, a gold glow and a shine. It sets
-- those directly, past KeepHidden. With the Glass look it's replaced by the
-- Glass animation (or none), as the options say; the new section gets the
-- look right away.
local function HookAddAnimation(header)
  local anim = header and header.AddAnim
  if not anim or anim.gftHooked then return end
  anim.gftHooked = true

  local function Replace()
    local profile = Profile()
    if not profile.glassLook or profile.sectionAnimation == "game" then return end
    anim:Stop()
    for _, key in ipairs({ "Background", "Glow", "Shine" }) do
      if header[key] then header[key]:SetAlpha(0) end
    end
    if header.MinimizeButton then header.MinimizeButton:SetAlpha(1) end
    if Core:Animates() then
      PlayGlassAnimation(header)
    end
    Core:Changed("sectionAdded")
  end

  -- The game starts it with Restart, which doesn't send OnPlay: catch the
  -- function that starts it (or OnPlay, if the game has no such function)
  if header.PlayAddAnimation then
    hooksecurefunc(header, "PlayAddAnimation", Replace)
  else
    anim:HookScript("OnPlay", Replace)
  end
end

-- The game's art: the panel background (Edit Mode "Opacity", replaced by the
-- Glass background) and the bar behind each section title
local function SkinArt()
  local profile = Profile()
  KeepHidden(tracker.NineSlice)
  KeepHidden(tracker.Header and tracker.Header.Background)
  ShowHeader(tracker.Header, not profile.hideMainHeader)
  for _, module in ipairs(tracker.modules or {}) do
    local header = module.Header
    KeepHidden(header and header.Background)
    HookAddAnimation(header)
    ShowHeader(header, not profile.hideSectionHeaders)
  end
end

local function SkinFonts()
  local profile = Profile()
  local path = Core.LSM:Fetch(Core.LSM.MediaType.FONT, profile.font, true)

  for _, info in ipairs(FONTS) do
    local font = _G[info.name]
    if font and font.SetFont then
      if not originalFonts[info.name] then
        local file, size, flags = font:GetFont()
        local r, g, b = font:GetTextColor()
        originalFonts[info.name] = { file, size, flags, r, g, b, font:GetSpacing() }
      end

      local original = originalFonts[info.name]
      if profile.glassLook and path then
        font:SetFont(path, profile[info.size], profile.fontFlags)
        -- Extra space between the lines of a text (the game follows it)
        font:SetSpacing((original[7] or 0) + profile.lineSpacing)
        if info.title then
          local r, g, b = Core:Color(profile.titleColor)
          if r then font:SetTextColor(r, g, b) end
        end
      else
        font:SetFont(original[1], original[2], original[3])
        font:SetTextColor(original[4], original[5], original[6])
        font:SetSpacing(original[7] or 0)
      end
    end
  end
end

local function Skin()
  SkinArt()
  SkinFonts()
end

-- Sections added later (e.g. a new section appears) get the look too. Some are
-- set up by the game a while after login, so the art is checked again now
-- and then (cheap: it only sets transparency).
local CHECK_EVERY = 1
local QUEST_CHECK_EVERY = 0.05
local function HookModules()
  if tracker.AddModule and not Core:IsHooked(tracker, "AddModule") then
    Core:SecureHook(tracker, "AddModule", SkinArt)
  end

  local checker = CreateFrame("Frame")
  local elapsedTotal, questElapsed = 0, 0
  checker:SetScript("OnUpdate", function (_, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    questElapsed = questElapsed + elapsed
    if elapsedTotal >= CHECK_EVERY then
      elapsedTotal = 0
      SkinArt()
    end
    -- New quests play their animation as soon as they show: checked often
    if questElapsed >= QUEST_CHECK_EVERY then
      questElapsed = 0
      HookQuestAnimations()
    end
  end)
end

local FONT_KEYS = {
  font = true, fontFlags = true, headerFontSize = true, lineFontSize = true,
  lineSpacing = true, titleColor = true,
}

Core:OnChange(function (key)
  if key == "init" then
    -- As early as possible: before the game lays the tracker out with its
    -- own fonts (texts sized for another font could overlap)
    SkinFonts()
  elseif key == "enable" then
    HookModules()
    Skin()
  elseif key == "glassLook" or key == "profile" or key == "sectionAnimation" then
    UpdateGlows()
    Skin()
  elseif key == "hideMainHeader" or key == "hideSectionHeaders" or key == "sectionAdded" then
    SkinArt()
  elseif FONT_KEYS[key] then
    SkinFonts()
  end
end)
