--==================================================
-- FlashlightModule
-- ModuleScript ? PlayerController > Modules
--
-- Handheld flashlight that replaces the active weapon
-- when toggled on. Player cannot shoot or melee while
-- holding the flashlight.
--
-- BEHAVIOUR:
--   L key toggles flashlight on/off
--   When ON:
--     - Viewmodel hides, weapon deactivates
--     - SpotLight attaches to character (visible to all)
--     - In first person: light follows camera look direction
--     - In third person: light follows character forward
--     - HUD shows "FLASHLIGHT" in weapon panel
--   When OFF:
--     - Returns to previously held weapon
--     - Light part is destroyed
--
--   Switching weapons (1/2/3 keys) auto-disables flashlight
--
-- SETUP:
--   Requires RemoteEvent "FlashlightToggle" in ReplicatedStorage
--   (created automatically). Server script FlashlightServer
--   handles replication to other players.
--==================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlashlightModule = {}

local player = Players.LocalPlayer

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
	-- SpotLight properties
	brightness   = 2.5,
	range        = 60,
	angle        = 45,         -- cone angle in degrees
	color        = Color3.fromRGB(255, 245, 220),  -- warm white

	-- Ambient point light (soft glow around the player)
	ambientRange     = 12,
	ambientBrightness = 0.8,

	-- First person: offset from camera
	fpOffset     = CFrame.new(0.3, -0.2, -0.5),

	-- Sound
	toggleOnSound  = "",   -- replace with rbxassetid:// for click on
	toggleOffSound = "",   -- replace with rbxassetid:// for click off
}

-- ============================================================
-- STATE
-- ============================================================
local isOn           = false
local lightPart      = nil
local spotLight      = nil
local ambientLight   = nil
local renderConn     = nil

-- References set by Init
local CameraRef      = nil
local ViewmodelRef   = nil
local WeaponRef      = nil
local HUDRef         = nil
local savedSlot      = nil   -- weapon slot to return to when turning off

-- ============================================================
-- REMOTE (for other players to see the light)
-- ============================================================
local RE_FlashlightToggle = ReplicatedStorage:FindFirstChild("FlashlightToggle")
if not RE_FlashlightToggle then
	RE_FlashlightToggle = Instance.new("RemoteEvent", ReplicatedStorage)
	RE_FlashlightToggle.Name = "FlashlightToggle"
end

-- ============================================================
-- SOUND HELPER
-- ============================================================
local function playToggleSound(on)
	local id = on and CONFIG.toggleOnSound or CONFIG.toggleOffSound
	if not id or id == "" then return end
	local camera = workspace.CurrentCamera
	local s = Instance.new("Sound", camera)
	s.SoundId = id
	s.Volume  = 0.4
	s:Play()
	game:GetService("Debris"):AddItem(s, 1)
end

-- ============================================================
-- CREATE / DESTROY LIGHT
-- ============================================================
local function createLight()
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Create a small invisible part to hold the light
	lightPart = Instance.new("Part")
	lightPart.Name        = "Flashlight"
	lightPart.Size        = Vector3.new(0.2, 0.2, 0.2)
	lightPart.Transparency = 1
	lightPart.Anchored    = true
	lightPart.CanCollide  = false
	lightPart.CanQuery    = false
	lightPart.CanTouch    = false
	lightPart.CastShadow = false
	lightPart.Parent      = char

	-- SpotLight (directional beam)
	spotLight = Instance.new("SpotLight", lightPart)
	spotLight.Brightness = CONFIG.brightness
	spotLight.Range      = CONFIG.range
	spotLight.Angle      = CONFIG.angle
	spotLight.Color      = CONFIG.color
	spotLight.Face       = Enum.NormalId.Front
	spotLight.Shadows    = true

	-- Ambient glow (soft light around player)
	ambientLight = Instance.new("PointLight", lightPart)
	ambientLight.Brightness = CONFIG.ambientBrightness
	ambientLight.Range      = CONFIG.ambientRange
	ambientLight.Color      = CONFIG.color

	-- Update loop: position the light each frame
	renderConn = RunService.RenderStepped:Connect(function()
		if not lightPart or not lightPart.Parent then return end

		local camera = workspace.CurrentCamera
		local head   = char:FindFirstChild("Head")
		local hrpNow = char:FindFirstChild("HumanoidRootPart")

		if not hrpNow then return end

		-- Check if first person
		local isFirstPerson = false
		if head then
			local dist = (camera.CFrame.Position - head.Position).Magnitude
			isFirstPerson = dist < 1.5
		end

		if isFirstPerson then
			-- First person: light follows camera direction
			lightPart.CFrame = camera.CFrame * CONFIG.fpOffset
		else
			-- Third person: light from character's chest area, facing forward
			local chestPos = hrpNow.Position + Vector3.new(0, 0.5, 0)
			lightPart.CFrame = CFrame.lookAt(chestPos, chestPos + hrpNow.CFrame.LookVector)
		end
	end)
end

local function destroyLight()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	if lightPart then
		lightPart:Destroy()
		lightPart    = nil
		spotLight    = nil
		ambientLight = nil
	end
end

-- ============================================================
-- PUBLIC API
-- ============================================================

function FlashlightModule.IsOn()
	return isOn
end

function FlashlightModule.TurnOn()
	if isOn then return end
	isOn = true

	-- Save current weapon slot so we can return to it
	if WeaponRef then
		savedSlot = WeaponRef.GetActiveSlotName()
	end

	-- Hide viewmodel
	if ViewmodelRef then
		ViewmodelRef.SetAlwaysVisible(false)
	end

	-- Update HUD
	if HUDRef then
		HUDRef.UpdateWeapon({ name = "Flashlight", iconId = "" })
		HUDRef.UpdateAmmo("", 0, 0)
		HUDRef.UpdateFireMode({}, 1)
	end

	createLight()
	playToggleSound(true)

	-- Tell server so other players see the light
	RE_FlashlightToggle:FireServer(true)
end

function FlashlightModule.TurnOff()
	if not isOn then return end
	isOn = false

	destroyLight()
	playToggleSound(false)

	-- Tell server
	RE_FlashlightToggle:FireServer(false)

	-- Return to previous weapon (handled by PlayerController)
end

function FlashlightModule.Toggle()
	if isOn then
		FlashlightModule.TurnOff()
	else
		FlashlightModule.TurnOn()
	end
end

-- Called when player switches weapons via hotkeys
-- Auto-disables flashlight
function FlashlightModule.OnWeaponSwitch()
	if isOn then
		isOn = false
		destroyLight()
		RE_FlashlightToggle:FireServer(false)
	end
end

-- Returns the saved slot name to return to after turning off
function FlashlightModule.GetSavedSlot()
	return savedSlot or "melee"
end

-- ============================================================
-- SETTERS
-- ============================================================
function FlashlightModule.SetCamera(cam)    CameraRef    = cam    end
function FlashlightModule.SetViewmodel(vm)  ViewmodelRef = vm     end
function FlashlightModule.SetWeapon(wep)    WeaponRef    = wep    end
function FlashlightModule.SetHUD(hud)       HUDRef       = hud    end

-- ============================================================
-- INIT
-- ============================================================
function FlashlightModule.Init()
	isOn      = false
	savedSlot = nil
	destroyLight()
	print("[FlashlightModule] Initialized.")
end

-- Cleanup on respawn
function FlashlightModule.Reset()
	isOn      = false
	savedSlot = nil
	destroyLight()
end

return FlashlightModule