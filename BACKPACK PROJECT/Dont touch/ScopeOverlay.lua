--==================================================
-- ScopeOverlay
-- ModuleScript inside PlayerController > Modules
--
-- Renders a full-screen scope reticle overlay when
-- the player ADS with a scope attachment fitted.
--
-- If the equipped weapon has no scope, or the scope
-- has no reticleId set, the overlay stays invisible
-- and only the FOV zoom takes effect.
--
-- PlayerController calls:
--   ScopeOverlay.Show(reticleId, reticleSize)  on ADS enter
--   ScopeOverlay.Hide()                         on ADS exit
--==================================================

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ScopeOverlay = {}

local player = Players.LocalPlayer

-- ============================================================
-- BUILD THE OVERLAY UI
-- Created once at module load, hidden until needed.
-- ============================================================
local screenGui = Instance.new("ScreenGui", player.PlayerGui)
screenGui.Name           = "ScopeOverlay"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled        = false   -- hidden until ADS

-- Dark vignette that covers the whole screen
-- The "scope tunnel" effect comes from this frame combined
-- with the circular cutout below.
local vignette = Instance.new("Frame", screenGui)
vignette.Name                   = "Vignette"
vignette.Size                   = UDim2.new(1, 0, 1, 0)
vignette.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
vignette.BackgroundTransparency = 0   -- fully opaque black
vignette.BorderSizePixel        = 0
vignette.ZIndex                 = 50

-- Circular scope lens — sits in the centre of the screen.
-- When a reticleId is provided this shows the reticle image.
-- When not provided it's just a transparent circle (still
-- gets the FOV zoom, no visual overlay).
local lens = Instance.new("ImageLabel", screenGui)
lens.Name                   = "Lens"
lens.AnchorPoint            = Vector2.new(0.5, 0.5)
lens.Position               = UDim2.new(0.5, 0, 0.5, 0)
lens.Size                   = UDim2.new(0, 420, 0, 420)
lens.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
lens.BackgroundTransparency = 1
lens.BorderSizePixel        = 0
lens.Image                  = ""   -- filled on Show()
lens.ScaleType              = Enum.ScaleType.Fit
lens.ZIndex                 = 51
Instance.new("UICorner", lens).CornerRadius = UDim.new(1, 0)  -- fully circular

-- Thin scope ring border
local ring = Instance.new("UIStroke", lens)
ring.Color     = Color3.fromRGB(30, 30, 30)
ring.Thickness = 3

-- "Punch hole" frame — same circle, same position, but
-- set to cut through the vignette by using a negative
-- ZIndex trick isn't available in Roblox, so instead we
-- use a UIGradient on the vignette to fade to transparent
-- at the centre, creating the tunnel effect.
local vigGrad = Instance.new("UIGradient", vignette)
vigGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0,   1.0),   -- centre: fully transparent (lens shows through)
	NumberSequenceKeypoint.new(0.3, 1.0),
	NumberSequenceKeypoint.new(0.5, 0.0),   -- edge of lens: opaque black starts
	NumberSequenceKeypoint.new(1.0, 0.0),
})
vigGrad.Rotation = 0   -- radial isn't native; we use a circular frame instead

-- Since Roblox UIGradient is linear not radial, we achieve
-- the circular tunnel by layering 4 directional gradient
-- frames at 0/90/180/270 degrees — each fades from
-- black at the edge to transparent at the centre.
local function makeEdge(rotation)
	local f = Instance.new("Frame", screenGui)
	f.Size                   = UDim2.new(1, 0, 1, 0)
	f.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	f.BackgroundTransparency = 0
	f.BorderSizePixel        = 0
	f.ZIndex                 = 50
	local g = Instance.new("UIGradient", f)
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.0),
		NumberSequenceKeypoint.new(0.28, 0.0),
		NumberSequenceKeypoint.new(0.50, 1.0),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})
	g.Rotation = rotation
	return f
end

local edgeTop    = makeEdge(270)
local edgeBottom = makeEdge(90)
local edgeLeft   = makeEdge(0)
local edgeRight  = makeEdge(180)

-- Remove the simple vignette gradient — replaced by the 4-edge system
vigGrad:Destroy()
vignette:Destroy()

-- ============================================================
-- TWEEN INFO
-- ============================================================
local FADE_IN  = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- ============================================================
-- PUBLIC API
-- ============================================================

-- Show the overlay.
-- reticleId   : rbxassetid:// string, or "" for no reticle image
-- reticleSize : scale multiplier for the lens circle (default 1)
function ScopeOverlay.Show(reticleId, reticleSize)
	reticleSize = reticleSize or 1
	local diameter = 420 * reticleSize

	lens.Size  = UDim2.new(0, diameter, 0, diameter)
	lens.Image = reticleId or ""

	screenGui.Enabled = true

	-- Fade edges in
	for _, edge in ipairs({ edgeTop, edgeBottom, edgeLeft, edgeRight }) do
		edge.BackgroundTransparency = 1
		TweenService:Create(edge, FADE_IN, { BackgroundTransparency = 0 }):Play()
	end
end

function ScopeOverlay.Hide()
	-- Fade edges out then disable gui
	local count  = 0
	local target = 4
	for _, edge in ipairs({ edgeTop, edgeBottom, edgeLeft, edgeRight }) do
		local t = TweenService:Create(edge, FADE_OUT, { BackgroundTransparency = 1 })
		t:Play()
		t.Completed:Connect(function()
			count = count + 1
			if count >= target then
				screenGui.Enabled = false
			end
		end)
	end
end

-- Returns true if the overlay is currently visible
function ScopeOverlay.IsVisible()
	return screenGui.Enabled
end

print("[ScopeOverlay] Loaded.")

return ScopeOverlay