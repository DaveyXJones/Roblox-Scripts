--==================================================
-- FootstepSystem.lua
-- LocalScript ? StarterPlayerScripts
--
-- Surface-aware footstep sounds synced to actual
-- movement speed. Includes jump, land, crouch, and
-- prone step cadences.
--
-- TUNING GUIDE:
--   The key to natural-sounding footsteps is matching
--   the step interval to the walk/run animation cycle.
--   Roblox's default walk animation has ~2 steps/sec
--   at WalkSpeed 16, and ~3.3 steps/sec at WalkSpeed 28.
--
--   If steps sound "clunky" or out of sync:
--     - Too fast? Increase the interval values
--     - Too slow? Decrease the interval values
--     - Double-tapping? Your sound file might have
--       silence at the start — trim it in an audio editor
--==================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris     = game:GetService("Debris")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")

-- ============================================================
-- MUTE ROBLOX DEFAULT SOUNDS
-- ============================================================
local function disableDefaultFootsteps(char)
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if not hrp then return end

	local defaultSounds = {
		"Running",
		"Jumping",
		"Landing",
		"Splash",
		"Died",
	}

	for _, soundName in ipairs(defaultSounds) do
		local sound = hrp:FindFirstChild(soundName)
		if sound then sound.Volume = 0 end
	end

	hrp.ChildAdded:Connect(function(child)
		if child:IsA("Sound") and table.find(defaultSounds, child.Name) then
			child.Volume = 0
		end
	end)
end

disableDefaultFootsteps(character)

-- ============================================================
-- SOUND ASSET IDs
-- Replace placeholder IDs with your actual audio assets.
-- Use 2-3 variants per surface to avoid repetition.
-- ============================================================
local SOUND_IDS = {
	grass = {
		"rbxassetid://92224829837432",
		"rbxassetid://73076319380473",
		"rbxassetid://110522236020035",

	},
	stone = {
		"rbxassetid://139406838352611",
		"rbxassetid://139406838352611",
		"rbxassetid://139406838352611",
	},
	wood = {
		"rbxassetid://127740512681270",
		"rbxassetid://119901675516391",
		"rbxassetid://96901665384796",
	},
	sand = {
		"rbxassetid://SAND_SOUND_1",
		"rbxassetid://SAND_SOUND_2",
	},
	metal = {
		"rbxassetid://139723537411614",
		"rbxassetid://134846179256941",
	},
	default = {
		"rbxassetid://135890657963973",
		"rbxassetid://134846179256941",
	},
}

-- ============================================================
-- JUMP / LAND / MISC SOUND IDs
-- Set to "" to use the surface footstep sound as placeholder
-- ============================================================
local ACTION_SOUNDS = {
	jump      = "",   -- replace with "rbxassetid://YOUR_JUMP_SOUND"
	landSoft  = "rbxassetid://109849547441373",   -- landing from a short fall
	landHard  = "",   -- landing from a high fall (future)
}

-- ============================================================
-- MATERIAL ? SURFACE TYPE MAPPING
-- ============================================================
local MATERIAL_MAP = {
	-- Grass / Dirt / Nature
	[Enum.Material.Grass]         = "grass",
	[Enum.Material.LeafyGrass]    = "grass",
	[Enum.Material.Mud]           = "grass",
	[Enum.Material.Ground]        = "grass",
	[Enum.Material.Snow]          = "grass",

	-- Stone / Rock / Concrete
	[Enum.Material.SmoothPlastic] = "stone",
	[Enum.Material.Concrete]      = "stone",
	[Enum.Material.Cobblestone]   = "stone",
	[Enum.Material.Rock]          = "stone",
	[Enum.Material.Basalt]        = "stone",
	[Enum.Material.Limestone]     = "stone",
	[Enum.Material.Slate]         = "stone",
	[Enum.Material.Pavement]      = "stone",
	[Enum.Material.Marble]        = "stone",
	[Enum.Material.Granite]       = "stone",

	-- Wood
	[Enum.Material.Wood]          = "wood",
	[Enum.Material.WoodPlanks]    = "wood",

	-- Sand
	[Enum.Material.Sand]          = "sand",
	[Enum.Material.Sandstone]     = "sand",

	-- Metal
	[Enum.Material.Metal]         = "metal",
	[Enum.Material.DiamondPlate]  = "metal",
	[Enum.Material.CorrodedMetal] = "metal",
}

-- ============================================================
-- SETTINGS
--
-- Step intervals are tuned to Roblox's default animations:
--   Walk (WalkSpeed 16)  ˜ 2 steps/sec  ? 0.48s interval
--   Run  (WalkSpeed 28)  ˜ 3.3 steps/sec ? 0.28s interval
--   Crouch (WalkSpeed 8) ˜ 1.3 steps/sec ? 0.72s interval
--   Prone  (WalkSpeed 3) ˜ 0.6 steps/sec ? 1.50s interval
-- ============================================================
local CONFIG = {
	-- Step intervals per movement state
	walkInterval    = 0.48,
	runInterval     = 0.28,
	crouchInterval  = 0.72,
	proneInterval   = 1.50,

	-- Speed thresholds (match your MovementModule speeds)
	walkSpeed       = 8,
	runSpeed        = 22,
	crouchSpeed     = 8,
	proneSpeed      = 3,
	minMoveSpeed    = 1.0,

	-- Audio tuning
	baseVolume      = 0.08,
	runVolumeBoost  = 0.06,
	crouchVolumeCut = 0.08,
	pitchMin        = 0.93,
	pitchMax        = 1.07,

	-- Raycast
	raycastDistance  = 4.0,

	-- Jump/Land
	jumpVolume      = 0.2,
	landVolume      = 0.25,
}

-- ============================================================
-- BUILD SOUND INSTANCES
-- ============================================================
local soundInstances = {}

local function buildSounds(hrp)
	soundInstances = {}
	for surface, ids in pairs(SOUND_IDS) do
		soundInstances[surface] = {}
		for i, id in ipairs(ids) do
			local sound = Instance.new("Sound")
			sound.SoundId            = id
			sound.Volume             = CONFIG.baseVolume
			sound.RollOffMaxDistance = 40
			sound.Parent             = hrp
			soundInstances[surface][i] = sound
		end
	end
end

buildSounds(rootPart)

-- ============================================================
-- SURFACE DETECTION
-- ============================================================
local raycastParams = RaycastParams.new()
raycastParams.FilterDescendantsInstances = { character }
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function detectSurface()
	local origin    = rootPart.Position
	local direction = Vector3.new(0, -CONFIG.raycastDistance, 0)
	local result    = workspace:Raycast(origin, direction, raycastParams)

	if result then
		return MATERIAL_MAP[result.Material] or "default"
	end
	return "default"
end

-- ============================================================
-- FOOTSTEP PLAYBACK
-- ============================================================
local lastSoundIndex = -1

local function playFootstep(surface, volumeOverride)
	local variants = soundInstances[surface] or soundInstances["default"]
	if not variants or #variants == 0 then return end
	local count = #variants

	local index
	if count == 1 then
		index = 1
	else
		repeat
			index = math.random(1, count)
		until index ~= lastSoundIndex
	end
	lastSoundIndex = index

	local sound = variants[index]
	sound.Volume = volumeOverride or CONFIG.baseVolume
	sound.PlaybackSpeed = CONFIG.pitchMin + math.random() * (CONFIG.pitchMax - CONFIG.pitchMin)
	sound:Play()
end

-- ============================================================
-- ACTION SOUND PLAYBACK (jump, land, etc)
-- ============================================================
local function playActionSound(actionKey, volumeOverride)
	local id = ACTION_SOUNDS[actionKey]
	if id and id ~= "" then
		local sound = Instance.new("Sound", rootPart)
		sound.SoundId = id
		sound.Volume  = volumeOverride or CONFIG.baseVolume
		sound.PlaybackSpeed = CONFIG.pitchMin + math.random() * (CONFIG.pitchMax - CONFIG.pitchMin)
		sound:Play()
		Debris:AddItem(sound, 2)
	else
		local surface = detectSurface()
		playFootstep(surface, volumeOverride)
	end
end

-- ============================================================
-- GET STEP INTERVAL BASED ON CURRENT SPEED
-- ============================================================
local function getStepInterval()
	local vel   = rootPart.Velocity
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local ws    = humanoid.WalkSpeed

	if ws <= CONFIG.proneSpeed + 1 then
		return CONFIG.proneInterval
	elseif ws <= CONFIG.crouchSpeed + 1 then
		local t = math.clamp(speed / CONFIG.crouchSpeed, 0.3, 1)
		return CONFIG.crouchInterval / t
	elseif ws <= CONFIG.walkSpeed + 1 then
		local t = math.clamp(speed / CONFIG.walkSpeed, 0.3, 1)
		return CONFIG.walkInterval / t
	else
		local t = math.clamp(speed / CONFIG.runSpeed, 0.3, 1)
		return CONFIG.runInterval / t
	end
end

-- ============================================================
-- GET VOLUME BASED ON MOVEMENT STATE
-- ============================================================
local function getStepVolume()
	local ws = humanoid.WalkSpeed
	if ws <= CONFIG.crouchSpeed + 1 then
		return CONFIG.baseVolume - CONFIG.crouchVolumeCut
	elseif ws > CONFIG.walkSpeed + 1 then
		return CONFIG.baseVolume + CONFIG.runVolumeBoost
	end
	return CONFIG.baseVolume
end

-- ============================================================
-- FOOTSTEP LOOP
-- ============================================================
local isWalking      = false
local stepLoopActive = false

local function footstepLoop()
	stepLoopActive = true

	while isWalking do
		local vel   = rootPart.Velocity
		local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude

		if speed > CONFIG.minMoveSpeed then
			local surface  = detectSurface()
			local volume   = getStepVolume()
			playFootstep(surface, volume)

			local interval = getStepInterval()
			task.wait(interval)
		else
			task.wait(0.1)
		end
	end

	stepLoopActive = false
end

-- ============================================================
-- CONNECT TO HUMANOID
-- ============================================================
humanoid.Running:Connect(function(speed)
	if speed > CONFIG.minMoveSpeed then
		isWalking = true
		if not stepLoopActive then
			task.spawn(footstepLoop)
		end
	else
		isWalking = false
	end
end)

-- ============================================================
-- JUMP / LAND SOUNDS
-- ============================================================
humanoid.StateChanged:Connect(function(oldState, newState)
	if newState == Enum.HumanoidStateType.Jumping then
		playActionSound("jump", CONFIG.jumpVolume)
	elseif newState == Enum.HumanoidStateType.Landed then
		playActionSound("landSoft", CONFIG.landVolume)
	end
end)

-- ============================================================
-- CHARACTER RESPAWN
-- ============================================================
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid  = newCharacter:WaitForChild("Humanoid")
	rootPart  = newCharacter:WaitForChild("HumanoidRootPart")
	isWalking      = false
	stepLoopActive = false
	lastSoundIndex = -1

	disableDefaultFootsteps(newCharacter)
	raycastParams.FilterDescendantsInstances = { newCharacter }
	buildSounds(rootPart)

	humanoid.Running:Connect(function(speed)
		if speed > CONFIG.minMoveSpeed then
			isWalking = true
			if not stepLoopActive then
				task.spawn(footstepLoop)
			end
		else
			isWalking = false
		end
	end)

	humanoid.StateChanged:Connect(function(oldState, newState)
		if newState == Enum.HumanoidStateType.Jumping then
			playActionSound("jump", CONFIG.jumpVolume)
		elseif newState == Enum.HumanoidStateType.Landed then
			playActionSound("landSoft", CONFIG.landVolume)
		end
	end)
end)

print("[FootstepSystem] Ready.")