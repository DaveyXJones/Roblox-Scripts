--==================================================
-- MeleeModule
-- ModuleScript ? PlayerController > Modules
--
-- Full melee combat system:
--
-- LIGHT ATTACK (left click):
--   2-hit combo (left swing ? right swing)
--   Quick, low stamina cost
--   Camera punch + hit sound on connect
--   Impact particles on hit
--
-- BLOCK (right click, held):
--   Reduces incoming melee damage by 50%
--   Drains stamina while held
--   Slows movement while blocking
--   Visual feedback: viewmodel raises to guard position
--   Guard break: if stamina runs out while blocking,
--   brief stagger (can't attack or block for 1 sec)
--
-- HEAVY ATTACK (hold left click):
--   Hold for 0.6s to charge, releases on mouse up
--   Double damage, more knockback/stagger
--   Higher stamina cost
--   Slower recovery
--   (Foundation built, can expand later)
--
-- STAMINA:
--   Each swing costs stamina
--   Can't attack if stamina too low
--   Blocking drains stamina over time
--   Works with existing MovementModule stamina pool
--
-- HIT FEEDBACK:
--   Camera shake on hit (subtle, directional)
--   Impact sound (different for hit vs miss)
--   Spark/blood particles on contact
--   Slight target knockback
--==================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")
local TweenService      = game:GetService("TweenService")

local MeleeModule = {}

-- ============================================================
-- REMOTES
-- ============================================================
local zombieRemotes = ReplicatedStorage:WaitForChild("ZombieRemotes", 10)
local RE_DealDamage = zombieRemotes and zombieRemotes:WaitForChild("DealDamage", 10)

-- ============================================================
-- SOUND IDs (replace with your assets)
-- ============================================================
local SOUNDS = {
	hitFlesh    = "",   -- hitting a zombie/player (replace with impact thud)
	hitHard     = "",   -- hitting a surface/object (replace with clang/thud)
	whiff       = "",   -- swing and miss
 
	swingLight  = "",   -- light attack swoosh
	swingHeavy  = "",   -- heavy attack swoosh
 
	blockImpact = "",   -- sound when blocking an incoming hit
	guardBreak  = "",   -- guard break stagger sound
}

-- ============================================================
-- CONFIG
-- ============================================================

-- Unarmed (bare fist) stats
local PUNCH = {
	damage       = 15,
	range        = 5,
	cooldown     = 0.45,
	comboWindow  = 1.2,
	staminaCost  = 8,
	heavyMult    = 2.0,
	heavyStamina = 18,
	anim1        = "rbxassetid://140442444373691",
	anim2        = "rbxassetid://102385419353974",
}

-- Fallback melee stats
local MELEE_FALLBACK = {
	damage       = 35,
	range        = 5,
	cooldown     = 0.4,
	comboWindow  = 1.1,
	staminaCost  = 10,
	heavyMult    = 2.0,
	heavyStamina = 22,
}

-- Block config
local BLOCK = {
	damageReduction = 0.50,     -- 50% less damage while blocking
	staminaDrain    = 6,        -- stamina per second while holding block
	moveSpeedMult   = 0.5,      -- movement speed multiplier while blocking
	staggerDuration = 1.0,      -- seconds of stagger on guard break
	minStaminaToBlock = 5,      -- can't block below this stamina
}

-- Heavy attack config
local HEAVY = {
	chargeTime      = 0.6,      -- seconds to hold before heavy triggers
	cooldownMult    = 1.8,      -- heavy attack has longer recovery
	cameraShakeMult = 2.0,      -- bigger camera punch on heavy hit
}

-- Camera punch config
local CAM_PUNCH = {
	hitIntensity    = 0.3,      -- degrees of rotation on light hit
	heavyIntensity  = 0.6,      -- degrees on heavy hit
	duration        = 0.12,     -- how long the punch lasts
	recovery        = 0.25,     -- how long to smooth back to normal
}

-- Viewmodel swing offsets
local SWING = {
	[1] = {
		kick    = CFrame.new(-0.12, -0.05, 0.08) * CFrame.Angles(math.rad(-8), math.rad(-12), math.rad(6)),
		recover = CFrame.new(0.35, -0.45, -0.50),
	},
	[2] = {
		kick    = CFrame.new(0.12, -0.05, 0.08) * CFrame.Angles(math.rad(-8), math.rad(12), math.rad(-6)),
		recover = CFrame.new(0.35, -0.45, -0.50),
	},
}

-- Block viewmodel position (guard raised)
local BLOCK_VM_CF = CFrame.new(0.15, -0.20, -0.55) * CFrame.Angles(math.rad(25), math.rad(5), math.rad(-10))

-- ============================================================
-- STATE
-- ============================================================
local comboStep      = 1
local lastHitTime    = 0
local isSwinging     = false
local comboResetTask = nil

-- Block state
local isBlocking     = false
local isStaggered    = false

-- Heavy attack state
local isCharging     = false
local chargeStart    = 0
local isHeavyReady   = false

-- Module references
local EquipmentRef   = nil
local ViewmodelRef   = nil
local CameraRef      = nil
local MovementRef    = nil
local HUDRef         = nil
local player         = Players.LocalPlayer

-- ============================================================
-- ANIMATION STATE
-- ============================================================
local animCache      = {}
local currentTrack   = nil

local function clearAnimCache()
	for _, track in pairs(animCache) do
		if track.IsPlaying then track:Stop(0) end
	end
	animCache    = {}
	currentTrack = nil
end

local function getAnimTrack(animId)
	if not animId or animId == "" then return nil end
	if animCache[animId] then return animCache[animId] end

	local char = player.Character
	if not char then return nil end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then animator = Instance.new("Animator", humanoid) end

	local anim = Instance.new("Animation")
	anim.AnimationId = animId

	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)

	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		animCache[animId] = track
		return track
	else
		warn("[MeleeModule] Failed to load animation: " .. animId)
		return nil
	end
end

-- ============================================================
-- PUBLIC SETTERS
-- ============================================================
function MeleeModule.SetEquipment(equipMod) EquipmentRef = equipMod end
function MeleeModule.SetViewmodel(vmMod)    ViewmodelRef = vmMod    end
function MeleeModule.SetCamera(camMod)      CameraRef    = camMod   end
function MeleeModule.SetMovement(movMod)    MovementRef  = movMod   end
function MeleeModule.SetHUD(hudMod)         HUDRef       = hudMod   end

-- ============================================================
-- PUBLIC GETTERS
-- ============================================================
function MeleeModule.IsSwinging()  return isSwinging  end
function MeleeModule.IsBlocking()  return isBlocking   end
function MeleeModule.IsStaggered() return isStaggered  end

-- ============================================================
-- SOUND HELPER
-- ============================================================
local function playSound3D(soundId, position, volume)
	if not soundId or soundId == "" then return end
	local part = Instance.new("Part", workspace)
	part.Size         = Vector3.new(0.1, 0.1, 0.1)
	part.Transparency = 1
	part.Anchored     = true
	part.CanCollide   = false
	part.CanQuery     = false
	part.CFrame       = CFrame.new(position)

	local s = Instance.new("Sound", part)
	s.SoundId            = soundId
	s.Volume             = volume or 0.5
	s.RollOffMaxDistance = 60
	s.PlaybackSpeed      = 0.95 + math.random() * 0.10
	s:Play()
	Debris:AddItem(part, 2)
end

-- ============================================================
-- CAMERA PUNCH (directional screen shake on hit)
-- ============================================================
local camPunchOffset = CFrame.new()

local function doCameraPunch(intensity)
	local rx = (math.random() - 0.5) * intensity * 2
	local ry = (math.random() - 0.5) * intensity
	local rz = (math.random() - 0.5) * intensity * 0.5

	camPunchOffset = CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))

	task.delay(CAM_PUNCH.duration, function()
		-- Smooth recovery
		local steps = 6
		for i = 1, steps do
			camPunchOffset = camPunchOffset:Lerp(CFrame.new(), i / steps)
			task.wait(CAM_PUNCH.recovery / steps)
		end
		camPunchOffset = CFrame.new()
	end)
end

-- Apply camera punch each frame (called from outside if needed)
function MeleeModule.GetCameraPunch()
	return camPunchOffset
end

-- ============================================================
-- HIT PARTICLES
-- ============================================================
local function spawnHitParticles(position, normal, hitType)
	-- Spark/impact burst
	local count = hitType == "heavy" and 8 or 4
	for i = 1, count do
		local p = Instance.new("Part", workspace)
		p.Size        = Vector3.new(0.08, 0.08, 0.08)
		p.CFrame      = CFrame.new(position)
		p.Anchored    = false
		p.CanCollide  = false
		p.CanQuery    = false
		p.CanTouch    = false
		p.Material    = Enum.Material.Neon
		p.BrickColor  = hitType == "miss" and BrickColor.new("Medium stone grey")
			or BrickColor.new("Bright red")

		-- Scatter velocity
		local dir = (normal or Vector3.new(0, 1, 0)) + Vector3.new(
			(math.random() - 0.5) * 2,
			math.random() * 1.5,
			(math.random() - 0.5) * 2
		)
		p.Velocity = dir.Unit * (12 + math.random() * 8)

		Debris:AddItem(p, 0.3)
	end
end

-- ============================================================
-- STAMINA HELPERS
-- ============================================================
local function getStamina()
	if MovementRef and MovementRef.GetStamina then
		return MovementRef.GetStamina()
	end
	return 100
end

local function drainStamina(amount)
	if MovementRef and MovementRef.DrainStamina then
		MovementRef.DrainStamina(amount)
	end
end

-- ============================================================
-- MELEE STATS
-- ============================================================
local function getMeleeStats()
	if EquipmentRef then
		local item = EquipmentRef.GetSlot("melee")
		if item and item.data then
			local d = item.data
			if d.damage and d.range then
				return {
					damage       = d.damage,
					range        = d.range,
					cooldown     = d.swingRate    or MELEE_FALLBACK.cooldown,
					comboWindow  = MELEE_FALLBACK.comboWindow,
					staminaCost  = d.staminaCost  or MELEE_FALLBACK.staminaCost,
					heavyMult    = d.heavyMult    or MELEE_FALLBACK.heavyMult,
					heavyStamina = d.heavyStamina or MELEE_FALLBACK.heavyStamina,
					isArmed      = true,
					name         = item.name,
					anim1        = d.anim1 or "",
					anim2        = d.anim2 or "",
					canBlock     = (d.canBlock ~= false),  -- default true for weapons
				}
			end
		end
	end
	return {
		damage       = PUNCH.damage,
		range        = PUNCH.range,
		cooldown     = PUNCH.cooldown,
		comboWindow  = PUNCH.comboWindow,
		staminaCost  = PUNCH.staminaCost,
		heavyMult    = PUNCH.heavyMult,
		heavyStamina = PUNCH.heavyStamina,
		isArmed      = false,
		name         = "Punch",
		anim1        = PUNCH.anim1,
		anim2        = PUNCH.anim2,
		canBlock     = true,
	}
end

-- ============================================================
-- HIT RAYCAST
-- ============================================================
local function doHitRaycast(range, damage, isHeavy)
	local char   = player.Character
	local camera = workspace.CurrentCamera
	if not char or not camera then return false end

	local origin    = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * range

	-- Third person fix: cast from the character's head, not the camera
	-- The camera is far behind in third person, so a short-range
	-- melee raycast from the camera would never reach anything.
	local head = char:FindFirstChild("Head")
	local hrp  = char:FindFirstChild("HumanoidRootPart")
	if head then
		local camDist = (camera.CFrame.Position - head.Position).Magnitude
		if camDist > 2 then
			-- We're in third person — cast from the character's head
			-- in the camera's look direction
			origin    = head.Position
			direction = camera.CFrame.LookVector * range
		end
	end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { char }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(origin, direction, params)

	if not result then
		if SOUNDS.whiff ~= "" then
			local soundPos = origin + direction.Unit * 2
			playSound3D(SOUNDS.whiff, soundPos, 0.3)
		end
		return false
	end

	local model = result.Instance:FindFirstAncestorOfClass("Model")
	if model and model ~= char then
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			if RE_DealDamage then
				RE_DealDamage:FireServer(model, damage)
			end

			local punchIntensity = isHeavy and CAM_PUNCH.heavyIntensity or CAM_PUNCH.hitIntensity
			doCameraPunch(punchIntensity)

			playSound3D(SOUNDS.hitFlesh, result.Position, 0.6)
			spawnHitParticles(result.Position, result.Normal, isHeavy and "heavy" or "light")

			return true
		end
	end

	local model = result.Instance:FindFirstAncestorOfClass("Model")
	if model and model ~= char then
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			-- HIT! Deal damage
			if RE_DealDamage then
				RE_DealDamage:FireServer(model, damage)
			end

			-- Camera punch
			local punchIntensity = isHeavy and CAM_PUNCH.heavyIntensity or CAM_PUNCH.hitIntensity
			doCameraPunch(punchIntensity)

			-- Impact sound
			playSound3D(SOUNDS.hitFlesh, result.Position, 0.6)

			-- Hit particles
			spawnHitParticles(result.Position, result.Normal, isHeavy and "heavy" or "light")

			return true
		end
	end

	-- Hit a wall/object
	playSound3D(SOUNDS.hitHard, result.Position, 0.4)
	spawnHitParticles(result.Position, result.Normal, "miss")

	return false
end

-- ============================================================
-- VIEWMODEL SWING
-- ============================================================
local function swingViewmodel(step, hipCF)
	if not ViewmodelRef then return end
	local swingData = SWING[step]
	if not swingData then return end

	ViewmodelRef.SetHipTarget(swingData.kick)

	local recoverCF = hipCF or swingData.recover
	task.delay(0.15, function()
		if not isBlocking then
			ViewmodelRef.SetHipTarget(recoverCF)
		end
	end)
end

-- Play character animation
local function playSwingAnim(animId)
	if currentTrack and currentTrack.IsPlaying then
		currentTrack:Stop(0.1)
	end
	local track = getAnimTrack(animId)
	if track then
		track:Play(0.1)
		track:AdjustSpeed(2.5)
		currentTrack = track
	end
end

-- Reset combo
local function resetCombo()
	comboStep = 1
end

-- Get weapon hipCF for recovery
local function getWeaponHipCF()
	local hipCF = CFrame.new(0.35, -0.45, -0.50)
	if EquipmentRef then
		local item = EquipmentRef.GetSlot("melee")
		if item and item.data and item.data.assetName then
			local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
			local cfg = WeaponConfig.Get(item.data.assetName)
			if cfg then hipCF = cfg.hipCF end
		end
	end
	return hipCF
end

-- ============================================================
-- LIGHT ATTACK
-- ============================================================
function MeleeModule.TryAttack()
	local now   = tick()
	local stats = getMeleeStats()
	print("[Melee] TryAttack called. isSwinging:", isSwinging, 
		"isBlocking:", isBlocking, "isStaggered:", isStaggered,
		"stamina:", getStamina(), "cost:", stats.staminaCost,
		"cooldownLeft:", stats.cooldown - (now - lastHitTime))

	if isSwinging or isBlocking or isStaggered then return end
	if now - lastHitTime < stats.cooldown then return end

	-- Stamina check
	if getStamina() < stats.staminaCost then
		if HUDRef then HUDRef.ShowNotif("Too tired!", 1.0) end
		return
	end

	-- Cancel pending combo reset
	if comboResetTask then
		task.cancel(comboResetTask)
		comboResetTask = nil
	end

	isSwinging  = true
	lastHitTime = now

	local currentStep = comboStep
	comboStep = (comboStep % 2) + 1

	-- Drain stamina
	drainStamina(stats.staminaCost)

	-- Swing sound
	if SOUNDS.swingLight ~= "" then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then playSound3D(SOUNDS.swingLight, hrp.Position, 0.3) end
	end

	-- Play animation
	local animId = (currentStep == 1) and stats.anim1 or stats.anim2
	playSwingAnim(animId)

	-- Swing viewmodel
	local hipCF = getWeaponHipCF()
	swingViewmodel(currentStep, hipCF)

	-- Hit detection with slight delay (sell the animation wind-up)
	task.delay(0.10, function()
		doHitRaycast(stats.range, stats.damage, false)
	end)

	-- Release swing lock
	task.delay(stats.cooldown, function()
		isSwinging = false
	end)

	-- Combo reset timer
	comboResetTask = task.delay(stats.comboWindow, function()
		resetCombo()
		comboResetTask = nil
	end)
end

-- ============================================================
-- HEAVY ATTACK
-- ============================================================
function MeleeModule.StartCharge()
	if isSwinging or isBlocking or isStaggered then return end
	local stats = getMeleeStats()
	if getStamina() < stats.heavyStamina then
		if HUDRef then HUDRef.ShowNotif("Too tired!", 1.0) end
		return
	end

	isCharging  = true
	chargeStart = tick()
	isHeavyReady = false

	-- Visual feedback: slight pull-back on viewmodel
	if ViewmodelRef then
		local hipCF = getWeaponHipCF()
		ViewmodelRef.SetHipTarget(hipCF * CFrame.new(0, 0.05, 0.1) * CFrame.Angles(math.rad(10), 0, 0))
	end
end

function MeleeModule.ReleaseCharge()
	if not isCharging then return end
	isCharging = false

	local stats    = getMeleeStats()
	local holdTime = tick() - chargeStart

	if holdTime >= HEAVY.chargeTime then
		-- HEAVY ATTACK
		if isSwinging or isBlocking or isStaggered then return end
		if getStamina() < stats.heavyStamina then return end

		isSwinging  = true
		lastHitTime = tick()

		drainStamina(stats.heavyStamina)

		-- Heavy swing sound
		if SOUNDS.swingHeavy ~= "" then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then playSound3D(SOUNDS.swingHeavy, hrp.Position, 0.5) end
		end

		-- Play anim (use anim1 for heavy, at slower speed)
		local animId = stats.anim1
		if currentTrack and currentTrack.IsPlaying then
			currentTrack:Stop(0.1)
		end
		local track = getAnimTrack(animId)
		if track then
			track:Play(0.1)
			track:AdjustSpeed(1.5)  -- slower, heavier
			currentTrack = track
		end

		-- Big viewmodel swing
		if ViewmodelRef then
			ViewmodelRef.SetHipTarget(
				CFrame.new(-0.15, -0.10, 0.15)
					* CFrame.Angles(math.rad(-15), math.rad(-20), math.rad(8))
			)
		end

		-- Hit with more damage
		local heavyDamage = math.floor(stats.damage * stats.heavyMult)
		task.delay(0.15, function()
			doHitRaycast(stats.range, heavyDamage, true)
		end)

		-- Longer recovery
		local heavyCooldown = stats.cooldown * HEAVY.cooldownMult
		task.delay(0.25, function()
			local hipCF = getWeaponHipCF()
			if ViewmodelRef and not isBlocking then
				ViewmodelRef.SetHipTarget(hipCF)
			end
		end)

		task.delay(heavyCooldown, function()
			isSwinging = false
		end)

		-- Reset combo after heavy
		resetCombo()
	else
		-- Held too short — do a regular light attack
		local hipCF = getWeaponHipCF()
		if ViewmodelRef then ViewmodelRef.SetHipTarget(hipCF) end
		MeleeModule.TryAttack()
	end
end

-- ============================================================
-- BLOCK
-- ============================================================
function MeleeModule.StartBlock()
	if isSwinging or isStaggered then return end

	local stats = getMeleeStats()
	if not stats.canBlock then return end
	if getStamina() < BLOCK.minStaminaToBlock then return end

	isBlocking = true

	-- Raise viewmodel to guard position
	if ViewmodelRef then
		ViewmodelRef.SetHipTarget(BLOCK_VM_CF)
	end
end

function MeleeModule.StopBlock()
	if not isBlocking then return end
	isBlocking = false

	-- Return viewmodel to hip
	local hipCF = getWeaponHipCF()
	if ViewmodelRef and not isSwinging then
		ViewmodelRef.SetHipTarget(hipCF)
	end
end

-- Called by external systems when this player takes melee damage.
-- Returns the modified damage after block reduction.
function MeleeModule.OnIncomingMeleeDamage(rawDamage)
	if isBlocking and not isStaggered then
		-- Block sound
		if SOUNDS.blockImpact ~= "" then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then playSound3D(SOUNDS.blockImpact, hrp.Position, 0.5) end
		end

		-- Drain stamina on block
		drainStamina(rawDamage * 0.5)

		-- Camera punch (lighter than a full hit)
		doCameraPunch(CAM_PUNCH.hitIntensity * 0.5)

		-- Check for guard break
		if getStamina() <= 0 then
			isBlocking  = false
			isStaggered = true

			if SOUNDS.guardBreak ~= "" then
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then playSound3D(SOUNDS.guardBreak, hrp.Position, 0.6) end
			end

			-- Return viewmodel to hip during stagger
			local hipCF = getWeaponHipCF()
			if ViewmodelRef then ViewmodelRef.SetHipTarget(hipCF) end

			task.delay(BLOCK.staggerDuration, function()
				isStaggered = false
			end)

			return rawDamage  -- guard broke, full damage
		end

		return rawDamage * (1 - BLOCK.damageReduction)
	end

	-- Not blocking — full damage + camera punch
	doCameraPunch(CAM_PUNCH.hitIntensity)
	return rawDamage
end

-- ============================================================
-- BLOCK STAMINA DRAIN (called each frame from PlayerController)
-- ============================================================
function MeleeModule.UpdateBlock(dt)
	if not isBlocking then return end

	drainStamina(BLOCK.staminaDrain * dt)

	-- Guard break if stamina runs out while blocking
	if getStamina() <= 0 then
		MeleeModule.StopBlock()
		isStaggered = true

		if SOUNDS.guardBreak ~= "" then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then playSound3D(SOUNDS.guardBreak, hrp.Position, 0.6) end
		end

		task.delay(BLOCK.staggerDuration, function()
			isStaggered = false
		end)
	end
end

-- ============================================================
-- INIT
-- ============================================================
function MeleeModule.Init()
	comboStep      = 1
	lastHitTime    = 0
	isSwinging     = false
	isBlocking     = false
	isStaggered    = false
	isCharging     = false
	comboResetTask = nil
	clearAnimCache()
	print("[MeleeModule] Initialized (combat system).")
end

function MeleeModule.Reset()
	if comboResetTask then
		task.cancel(comboResetTask)
		comboResetTask = nil
	end
	comboStep   = 1
	isSwinging  = false
	isBlocking  = false
	isStaggered = false
	isCharging  = false
	lastHitTime = 0
	camPunchOffset = CFrame.new()
	if currentTrack and currentTrack.IsPlaying then
		currentTrack:Stop(0.1)
	end
	currentTrack = nil
	clearAnimCache()
end

return MeleeModule