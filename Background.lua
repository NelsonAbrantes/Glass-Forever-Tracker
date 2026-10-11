local _, ns = ...
local Core = ns.Core

-- luacheck: push ignore 113
local CreateColor = CreateColor
local CreateFrame = CreateFrame
local UIParent = UIParent
-- luacheck: pop

local FADE_RATIO = 0.3 -- how much of the width fades in at each side
local PAD_X = 12       -- how far it reaches past the tracker's edges
local PAD_Y = 6

----
-- Background
--
-- The Glass background behind the tracker: dark in the middle, fading out at
-- both sides, like the background of the Glass chat. It's a frame of its own
-- behind the tracker, so the game's tracker isn't changed. Fade.lua sets its
-- visibility together with the tracker's.

local background = CreateFrame("Frame", "GlassForeverTrackerBackground", UIParent)
background:SetFrameStrata("BACKGROUND")
background:EnableMouse(false)
Core.background = background

local function Texture()
  local texture = background:CreateTexture(nil, "BACKGROUND")
  texture:SetColorTexture(1, 1, 1, 1)
  return texture
end

local left, center, right = Texture(), Texture(), Texture()
left:SetPoint("TOPLEFT")
left:SetPoint("BOTTOMLEFT")
right:SetPoint("TOPRIGHT")
right:SetPoint("BOTTOMRIGHT")
center:SetPoint("TOPLEFT", left, "TOPRIGHT")
center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")

function background:Update()
  local profile = Core.db.profile
  local opacity = profile.glassLook and profile.backgroundOpacity or 0
  local fade = math.max(20, math.floor(self:GetWidth() * FADE_RATIO))

  left:SetWidth(fade)
  right:SetWidth(fade)
  left:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, opacity))
  right:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, opacity), CreateColor(0, 0, 0, 0))
  center:SetColorTexture(0, 0, 0, opacity)
end

function background:Attach(tracker)
  self:ClearAllPoints()
  self:SetPoint("TOPLEFT", tracker, "TOPLEFT", -PAD_X, PAD_Y)
  self:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", PAD_X, -PAD_Y)
  self:Update()
end

background:SetScript("OnSizeChanged", function (self) self:Update() end)

Core:OnChange(function (key)
  if key == "backgroundOpacity" or key == "glassLook" or key == "profile" then
    background:Update()
  end
end)
