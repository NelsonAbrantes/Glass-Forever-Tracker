local _, ns = ...
local Core = ns.Core

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local UIParent = UIParent
-- luacheck: pop

local TEXTURE = "Interface\\AddOns\\GlassForeverTracker\\Assets\\softBackground"
local SOFT_EDGE = 56 -- how many pixels of the image fade out at each side
local PAD = 36       -- how far it reaches past the tracker's text
local UPDATE_EVERY = 0.2

----
-- Background
--
-- The Glass background behind the tracker: dark in the middle and fading out
-- softly on every side, like a diffuse shadow. It covers only the part of the
-- tracker that has something in it, not the whole height set in Edit Mode.
-- It's a frame of its own behind the tracker, so the game's tracker isn't
-- changed. Fade.lua sets its visibility together with the tracker's.

local background = CreateFrame("Frame", "GlassForeverTrackerBackground", UIParent)
background:SetFrameStrata("BACKGROUND")
background:EnableMouse(false)
Core.background = background

local texture = background:CreateTexture(nil, "BACKGROUND")
texture:SetAllPoints()
texture:SetTexture(TEXTURE)
if texture.SetTextureSliceMargins then
  texture:SetTextureSliceMargins(SOFT_EDGE, SOFT_EDGE, SOFT_EDGE, SOFT_EDGE)
  if texture.SetTextureSliceMode and _G.Enum and _G.Enum.UITextureSliceMode then
    texture:SetTextureSliceMode(_G.Enum.UITextureSliceMode.Stretched)
  end
end

function background:UpdateColor()
  local profile = Core.db.profile
  local opacity = profile.glassLook and profile.backgroundOpacity or 0
  texture:SetVertexColor(0, 0, 0, opacity)
end

-- The lowest point with something shown: the bottom of the last section, or
-- the tracker's own title when everything is collapsed
local function ContentBottom(tracker)
  local bottom
  for _, module in ipairs(tracker.modules or {}) do
    if module:IsShown() and module:GetHeight() > 1 then
      local moduleBottom = module:GetBottom()
      if moduleBottom and (not bottom or moduleBottom < bottom) then
        bottom = moduleBottom
      end
    end
  end
  if not bottom and tracker.Header then
    bottom = tracker.Header:GetBottom()
  end
  return bottom
end

function background:UpdateSize()
  local tracker = self.tracker
  local top, bottom = tracker:GetTop(), ContentBottom(tracker)
  if not top or not bottom then return end

  local height = math.floor(top - bottom + 0.5)
  if height == self.contentHeight then return end
  self.contentHeight = height

  self:ClearAllPoints()
  self:SetPoint("TOPLEFT", tracker, "TOPLEFT", -PAD, PAD)
  self:SetPoint("BOTTOMRIGHT", tracker, "TOPRIGHT", PAD, -(height + PAD))
end

function background:Attach(tracker)
  self.tracker = tracker
  self.contentHeight = nil
  self:UpdateColor()
  self:UpdateSize()

  -- Sections grow and shrink as quests come and go
  local elapsedTotal = 0
  self:SetScript("OnUpdate", function (_, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal >= UPDATE_EVERY then
      elapsedTotal = 0
      self:UpdateSize()
    end
  end)
end

Core:OnChange(function (key)
  if key == "backgroundOpacity" or key == "glassLook" or key == "profile" then
    background:UpdateColor()
  end
end)
