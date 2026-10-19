--==================================================
-- CameraModule
-- ModuleScript inside PlayerController > Modules
--
-- CHANGED FROM PREVIOUS VERSION:
--   EnterADS() now behaves differently depending on
--   whether the player is in first or third person.
--
--   FIRST PERSON ? same as before (LockFirstPerson)
--   THIRD PERSON ? over-the-shoulder camera offset
--                  using a manual CFrame each frame.
--                  Character stays free (no lock).
--
--   GetIsOTS() lets other modules (HUD, Melee) know
--   when OTS aim is active in third person.
--
--   SetUIOverride() unlocks the mouse for BackpackUI
--     while keeping the camera following the character.
--     - Captures the camera CFrame at the moment the
--       bag opens, then every frame re-applies that
--       same *relative* offset from the character so
--       the view travels with WASD movement.
--
--   OTS aiming now rotates character to face the
--   camera look direction (strafe/backpedal movement).
--==================================================

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")

local CameraModule = {}

local camera = workspace.CurrentCamera
local player = Players.LocalPlayer

-- ============================================================
-- CONFIG
-- ============================================================
local FOV = {
	THIRD = 70,
	FIRST = 70,
	ADS   = 50,
	SCOPE = 20,
	OTS   = 65,
}

local ZOOM = {
	THIRD = 12,
	FIRST = 0.5,
}

local OTS_OFFSET    = Vector3.new(1.8, 1.6, -5.5)
local OTS_LERP      = 12

-- ============================================================
-- STATE
-- ============================================================
local state     = "third"
local prevState = "third"

local otsActive     = false
local otsCurrent    = CFrame.new()
local characterRef  = nil
local uiOverride    = false
local uiPrevCameraMode = Enum.CameraMode.Classic
local uiPrevMouseBehavior = Enum.MouseBehavior.Default
local uiPrevMouseIconEnabled = true

-- Snapshot taken when bag opens so camera can follow the character
local uiCamOffset   = CFrame.new()   -- camera offset relative to HRP
local uiWasFirstPerson = false
local uiCamAnchor = Vector3.new()

-- ============================================================
-- HELPERS
-- ============================================================
local function tweenFOV(target)
	TweenService:Create(camera, TweenInfo.new(0.15), { FieldOfView = target }):Play()
end

local function setZoom(dist)
	player.CameraMaxZoomDistance = dist
	player.CameraMinZoomDistance = dist
end

-- ============================================================
-- OTS RENDER LOOP
-- ============================================================
local otsYaw   = 0
local otsPitch = 0
local OTS_SENSITIVITY = 0.3

RunService.RenderStepped:Connect(function(dt)
	-- --------------------------------------------------------
	-- UI OVERRIDE: keep camera following character, no mouse
	-- --------------------------------------------------------
	if uiOverride then
		if characterRef then
			local hum = characterRef:FindFirstChildOfClass("Humanoid")
			if hum then hum.AutoRotate = true end

			local root = characterRef:FindFirstChild("HumanoidRootPart")
			if root then
				if uiWasFirstPerson then
					-- First person: pin camera to head position,
					-- keep the same look direction we captured.
					local head = characterRef:FindFirstChild("Head")
					local anchor = head and head.Position or root.Position + Vector3.new(0, 1.5, 0)
					camera.CFrame = CFrame.new(anchor) * uiCamOffset.Rotation
				else
					-- Third person: maintain the same offset from
					-- HumanoidRootPart that we had when bag opened.
					local delta = root.Position - uiCamAnchor
					camera.CFrame = uiCamOffset + delta
				end
			end
		end
		return
	end

	if not otsActive then return end
	if not characterRef then return end

	local root = characterRef:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Read mouse delta to rotate the aim direction
	local delta = UIS:GetMouseDelta()
	otsYaw   = otsYaw   - delta.X * OTS_SENSITIVITY
	otsPitch = math.clamp(otsPitch - delta.Y * OTS_SENSITIVITY, -60, 75)

	-- Build the aim CFrame from accumulated angles
	local aimCF = CFrame.new(root.Position)
		* CFrame.Angles(0, math.rad(otsYaw), 0)
		* CFrame.Angles(math.rad(otsPitch), 0, 0)

	-- Offset to right shoulder
	local targetPos = root.Position
		+ aimCF.RightVector   * OTS_OFFSET.X
		+ Vector3.new(0, 1, 0) * OTS_OFFSET.Y
		+ aimCF.LookVector    * OTS_OFFSET.Z

	local lookTarget = targetPos + aimCF.LookVector * 100
	local targetCF   = CFrame.lookAt(targetPos, lookTarget)

	otsCurrent    = otsCurrent:Lerp(targetCF, math.min(1, dt * OTS_LERP))
	camera.CFrame = otsCurrent

	-- Rotate character to face camera look direction (strafe/backpedal)
	local humanoid = characterRef:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = false
		local lookFlat = Vector3.new(aimCF.LookVector.X, 0, aimCF.LookVector.Z).Unit
		root.CFrame = CFrame.lookAt(root.Position, root.Position + lookFlat)
	end
end)

-- ============================================================
-- PUBLIC API
-- ============================================================

function CameraModule.Init(character)
	characterRef = character or (player.Character)
	player.CameraMode  = Enum.CameraMode.Classic
	setZoom(ZOOM.THIRD)
	camera.FieldOfView = FOV.THIRD
	state     = "third"
	prevState = "third"
	otsActive = false
end

function CameraModule.SetCharacter(character)
	characterRef = character
end

function CameraModule.TogglePerson()
	if state == "ads" or state == "scope" or state == "ots" then return end
	if state == "third" then
		state = "first"
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		setZoom(ZOOM.FIRST)
		tweenFOV(FOV.FIRST)
	else
		state = "third"
		player.CameraMode = Enum.CameraMode.Classic
		setZoom(ZOOM.THIRD)
		tweenFOV(FOV.THIRD)
	end
end

function CameraModule.EnterADS(fov)
	if state == "scope" then return end
	if state == "ads" or state == "ots" then return end

	prevState = state

	if prevState == "third" then
		state      = "ots"
		otsActive  = true
		otsCurrent = camera.CFrame
		local _, cy, _ = camera.CFrame:ToEulerAnglesYXZ()
		local cx, _, _ = camera.CFrame:ToEulerAnglesYXZ()
		otsYaw   = math.deg(cy)
		otsPitch = math.clamp(math.deg(cx), -60, 75)
		camera.CameraType = Enum.CameraType.Scriptable
		UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
		tweenFOV(fov or FOV.OTS)
	else
		state = "ads"
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		setZoom(ZOOM.FIRST)
		tweenFOV(fov or FOV.ADS)
	end
end

function CameraModule.ExitADS()
	if state == "ots" then
		otsActive = false
		state     = "third"
		-- Restore character auto-rotation
		if characterRef then
			local humanoid = characterRef:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.AutoRotate = true
			end
		end
		camera.CameraType = Enum.CameraType.Custom
		UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
		player.CameraMode = Enum.CameraMode.Classic
		setZoom(ZOOM.THIRD)
		tweenFOV(FOV.THIRD)
		return
	end

	if state ~= "ads" then return end
	state = prevState
	if state == "third" then
		player.CameraMode = Enum.CameraMode.Classic
		setZoom(ZOOM.THIRD)
	else
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		setZoom(ZOOM.FIRST)
	end
	tweenFOV(state == "third" and FOV.THIRD or FOV.FIRST)
end

function CameraModule.EnterScope()
	prevState = state
	state     = "scope"
	otsActive = false
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	setZoom(ZOOM.FIRST)
	tweenFOV(FOV.SCOPE)
end

function CameraModule.ExitScope()
	state     = prevState
	otsActive = false
	if state == "third" then
		player.CameraMode = Enum.CameraMode.Classic
		setZoom(ZOOM.THIRD)
		tweenFOV(FOV.THIRD)
	else
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		setZoom(ZOOM.FIRST)
		tweenFOV(FOV.FIRST)
	end
end

-- ============================================================
-- GETTERS
-- ============================================================
function CameraModule.GetState()   return state     end
function CameraModule.GetIsOTS()   return otsActive end
function CameraModule.GetIsFirstPerson()
	return state == "first" or state == "ads" or state == "scope"
end

-- ============================================================
-- UI OVERRIDE (BackpackUI camera freeze)
-- ============================================================
function CameraModule.SetUIOverride(active)
	uiOverride = active
	if active then
		uiPrevCameraMode = player.CameraMode
		uiPrevMouseBehavior = UIS.MouseBehavior
		uiPrevMouseIconEnabled = UIS.MouseIconEnabled

		-- Remember which perspective we're in
		uiWasFirstPerson = (state == "first" or state == "ads" or state == "scope")

		-- Snapshot the camera's offset relative to the character
		-- so the RenderStepped loop can re-apply it each frame.
		if characterRef then
			local root = characterRef:FindFirstChild("HumanoidRootPart")
			if root then
				if uiWasFirstPerson then
					-- For first person we just need the rotation
					-- (the position will be pinned to the head)
					uiCamOffset = camera.CFrame
				else
					-- For third person, store offset from HRP
					uiCamOffset = camera.CFrame
					uiCamAnchor = root.Position
				end
			end
		end

		-- Scriptable so Roblox stops fighting us for camera control.
		-- Our RenderStepped loop takes over and keeps following.
		player.CameraMode    = Enum.CameraMode.Classic
		camera.CameraType    = Enum.CameraType.Scriptable
		UIS.MouseBehavior    = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
	else
		-- RESTORE normal camera control
		camera.CameraType = Enum.CameraType.Custom
		if state == "first" or state == "ads" or state == "scope" then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
		else
			player.CameraMode = Enum.CameraMode.Classic
		end
		UIS.MouseBehavior    = uiPrevMouseBehavior
		UIS.MouseIconEnabled = uiPrevMouseIconEnabled
	end
end

function CameraModule.GetUIOverride()
	return uiOverride
end

return CameraModule
