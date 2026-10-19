--==================================================
-- FlashlightServer
-- Script ? ServerScriptService
--
-- When a player toggles their flashlight, this script
-- creates/removes a SpotLight on their character that
-- all other players can see.
--
-- The owning player's light is handled client-side
-- (FlashlightModule) for smooth camera-following.
-- This server light is a simpler version that just
-- points in the character's forward direction.
--==================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

-- Wait for the remote (created by FlashlightModule if needed)
local RE_FlashlightToggle = ReplicatedStorage:WaitForChild("FlashlightToggle", 15)
if not RE_FlashlightToggle then
	RE_FlashlightToggle = Instance.new("RemoteEvent", ReplicatedStorage)
	RE_FlashlightToggle.Name = "FlashlightToggle"
end

-- ============================================================
-- CONFIG (match FlashlightModule values)
-- ============================================================
local LIGHT_CONFIG = {
	brightness = 2.5,
	range      = 60,
	angle      = 45,
	color      = Color3.fromRGB(255, 245, 220),
}

-- ============================================================
-- STATE
-- playerLights[userId] = { part = Part, connection = RBXConnection }
-- ============================================================
local playerLights = {}

-- ============================================================
-- CREATE SERVER-SIDE LIGHT ON CHARACTER
-- ============================================================
local function createServerLight(player)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Remove existing if any
	if playerLights[player.UserId] then
		local existing = playerLights[player.UserId]
		if existing.part then existing.part:Destroy() end
		if existing.connection then existing.connection:Disconnect() end
		playerLights[player.UserId] = nil
	end

	-- Create light part attached to character
	local lightPart = Instance.new("Part")
	lightPart.Name        = "ServerFlashlight"
	lightPart.Size        = Vector3.new(0.2, 0.2, 0.2)
	lightPart.Transparency = 1
	lightPart.Anchored    = true
	lightPart.CanCollide  = false
	lightPart.CanQuery    = false
	lightPart.CanTouch    = false
	lightPart.CastShadow = false
	lightPart.Parent      = char

	local spot = Instance.new("SpotLight", lightPart)
	spot.Brightness = LIGHT_CONFIG.brightness
	spot.Range      = LIGHT_CONFIG.range
	spot.Angle      = LIGHT_CONFIG.angle
	spot.Color      = LIGHT_CONFIG.color
	spot.Face       = Enum.NormalId.Front
	spot.Shadows    = true

	-- Ambient glow
	local ambient = Instance.new("PointLight", lightPart)
	ambient.Brightness = 0.8
	ambient.Range      = 12
	ambient.Color      = LIGHT_CONFIG.color

	-- Update position each frame to follow character
	local conn = RunService.Heartbeat:Connect(function()
		if not char or not char.Parent then return end
		local hrpNow = char:FindFirstChild("HumanoidRootPart")
		if not hrpNow then return end

		local chestPos = hrpNow.Position + Vector3.new(0, 0.5, 0)
		lightPart.CFrame = CFrame.lookAt(chestPos, chestPos + hrpNow.CFrame.LookVector)
	end)

	playerLights[player.UserId] = {
		part       = lightPart,
		connection = conn,
	}
end

local function removeServerLight(player)
	local data = playerLights[player.UserId]
	if not data then return end

	if data.connection then data.connection:Disconnect() end
	if data.part and data.part.Parent then data.part:Destroy() end
	playerLights[player.UserId] = nil
end

-- ============================================================
-- LISTEN FOR TOGGLE EVENTS
-- ============================================================
RE_FlashlightToggle.OnServerEvent:Connect(function(player, isOn)
	if isOn then
		createServerLight(player)
	else
		removeServerLight(player)
	end
end)

-- Cleanup when player leaves or dies
Players.PlayerRemoving:Connect(function(player)
	removeServerLight(player)
end)

-- Also clean up on character death/respawn
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		removeServerLight(player)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function()
		removeServerLight(player)
	end)
end

print("[FlashlightServer] Initialized.")
