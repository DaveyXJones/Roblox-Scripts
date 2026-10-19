--==================================================
-- ViewmodelModule
--
-- ADDITIONS:
--   Camera Bob   – subtle vertical + horizontal bob
--                  synced to movement speed (first person only).
--   Idle Sway    – gentle figure-eight drift when standing
--                  still, simulates breathing / weapon weight.
--   Movement Sway – gun lags behind camera rotation,
--                   giving the weapon a sense of mass.
--   All effects disabled during ADS for precision aiming.
--==================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local UIS               = game:GetService("UserInputService")

local ViewmodelModule = {}

local camera  = workspace.CurrentCamera
local player  = Players.LocalPlayer

local MeleeRef = nil


local vmFolder  = Instance.new("Folder", camera)
vmFolder.Name   = "Viewmodel"

local viewmodel = nil
local vmRoot    = nil
local vmMuzzle  = nil
local vmVisible = false
local vmCurrent = CFrame.new()
local vmTarget  = CFrame.new()

-- Set by WeaponModule via callbacks
local getIsADS      = nil
local getHipCF      = nil
local getADSCF      = nil
------Melee-------
local MeleeRef = nil

function ViewmodelModule.SetMelee(meleeMod)
	MeleeRef = meleeMod
end

-- ============================================================
-- CAMERA BOB CONFIG  (first person only)
-- ============================================================
local BOB = {
	-- Vertical bob (up/down with each step)
	vertAmount    = 0.12,   -- studs of vertical travel
	vertFreq      = 2.0,     -- cycles per second while walking

	-- Horizontal bob (side to side weight shift)
	horizAmount   = 0.08,   -- studs of horizontal travel
	horizFreq     = 1.0,     -- half the vertical freq (left-right-left per two steps)

	-- Roll tilt (slight head tilt with each step)
	rollAmount    = 0.15,    -- degrees of roll
	rollFreq      = 2.75,     -- same as horizontal

	-- Sprint multipliers
	sprintVertMult  = 1.8,
	sprintFreqMult  = 1.4,

	-- Smoothing
	lerpSpeed     = 5.0,     -- how fast bob blends in/out
}

-- ============================================================
-- GUN SWAY CONFIG
-- ============================================================
local SWAY = {
	-- Idle sway (breathing / weapon weight, always active at hip)
	idleAmountX   = 0.0008,  -- horizontal drift (studs)
	idleAmountY   = 0.0012,  -- vertical drift (studs)
	idleFreqX     = 1.1,     -- slightly different freqs = figure-eight
	idleFreqY     = 0.8,
	idleRotAmount = 0.08,    -- degrees of gentle rotation

	-- Movement sway (gun lags behind mouse/camera turns)
	moveSway      = 0.08,    -- how much the gun trails behind (studs per pixel of mouse delta)
	moveSwayMax   = 0.25,    -- max offset so it doesn't fly off screen
	moveSwaySmooth = 8.0,    -- how fast it recovers to center
	moveRotSway   = 0.15,    -- degrees of roll when strafing

	-- Walk sway (additional subtle sway while moving)
	walkAmount    = 0.004,   -- extra horizontal drift while walking
	walkFreq      = 4.0,
}

-- ============================================================
-- STATE
-- ============================================================
local bobTimer    = 0
local bobCurrent  = CFrame.new()
local bobTarget   = CFrame.new()

local swayOffset  = Vector3.new(0, 0, 0)  -- current mouse-lag offset
local swayVel     = Vector3.new(0, 0, 0)  -- for smooth damping
local lastCamCF   = CFrame.new()

-- ============================================================
-- HELPERS
-- ============================================================
local function makePart(parent, size, color)
	local p = Instance.new("Part", parent)
	p.Size           = size
	p.BrickColor     = color or BrickColor.new("Dark stone grey")
	p.Material       = Enum.Material.SmoothPlastic
	p.CanCollide     = false
	p.Anchored       = false
	p.CastShadow     = false
	p.TopSurface     = Enum.SurfaceType.Smooth
	p.BottomSurface  = Enum.SurfaceType.Smooth
	return p
end

local function weldParts(parent, p0, p1, c0)
	local w = Instance.new("Weld", parent)
	w.Part0 = p0; w.Part1 = p1; w.C0 = c0 or CFrame.new()
	return w
end

local function setVisible(visible)
	if vmVisible == visible then return end
	vmVisible = visible
	if not viewmodel then return end
	for _, p in ipairs(viewmodel:GetDescendants()) do
		if p:IsA("BasePart") and p ~= vmRoot then
			p.LocalTransparencyModifier = visible and 0 or 1
		end
	end
end

-- ============================================================
-- BUILD
-- ============================================================
function ViewmodelModule.Build(weapon)
	if viewmodel then viewmodel:Destroy() end
	vmMuzzle = nil

	local vm = Instance.new("Model", vmFolder)
	vm.Name  = "ViewModel"

	local root = makePart(vm, Vector3.new(0.05, 0.05, 0.05), BrickColor.new("Black"))
	root.Name        = "Root"
	root.Transparency = 1
	root.Anchored    = true
	root.CFrame      = camera.CFrame
	vm.PrimaryPart   = root
	vmRoot           = root

	vmCurrent = weapon.hipCF
	vmTarget  = weapon.hipCF

	local GunAssets = ReplicatedStorage:FindFirstChild("GunAssets")
	local asset     = weapon.assetName
		and GunAssets
		and GunAssets:FindFirstChild(weapon.assetName)

	if asset then
		local clone = asset:Clone()
		clone.Parent = vm

		local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
		if primary then
			clone:ScaleTo(weapon.scale)

			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.Anchored   = true
					d.CastShadow = false
				end
			end

			local savedOffsets = {}
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("BasePart") and d ~= primary then
					savedOffsets[d] = primary.CFrame:ToObjectSpace(d.CFrame)
				end
			end

			primary.CFrame = CFrame.new(0, -9999, 0)

			for d, rel in pairs(savedOffsets) do
				d.CFrame = primary.CFrame * rel
			end

			local primaryCF = primary.CFrame
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("BasePart") and d ~= primary then
					local dw = Instance.new("Weld", primary)
					dw.Part0 = primary
					dw.Part1 = d
					dw.C0    = primaryCF:ToObjectSpace(d.CFrame)
				end
			end

			local w = Instance.new("Weld", root)
			w.Part0 = root
			w.Part1 = primary
			w.C0    = weapon.axisFix or CFrame.new()

			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored    = false
					d.CanCollide  = false
					d.CanTouch    = false
					d.CanQuery    = false
					d.Massless    = true
				end
			end
		end

		vmMuzzle = clone:FindFirstChild("Muzzle", true)
		if not vmMuzzle then
			local muzzle = makePart(vm, Vector3.new(0.05, 0.05, 0.05), BrickColor.new("Black"))
			muzzle.Name        = "Muzzle"
			muzzle.Transparency = 1
			weldParts(vm, root, muzzle, CFrame.new(0, 0, -0.5))
			vmMuzzle = muzzle
		end
		print("[ViewmodelModule] Loaded: " .. weapon.assetName)
	else
		if weapon.assetName then
			warn("[ViewmodelModule] Asset not found: " .. weapon.assetName)
		end
		local muzzle = makePart(vm, Vector3.new(0.05, 0.05, 0.05), BrickColor.new("Black"))
		muzzle.Name        = "Muzzle"
		muzzle.Transparency = 1
		weldParts(vm, root, muzzle, CFrame.new(0, 0, -0.5))
		vmMuzzle = muzzle
	end

	viewmodel = vm

	-- Reset sway/bob state for new weapon
	bobTimer   = 0
	bobCurrent = CFrame.new()
	bobTarget  = CFrame.new()
	swayOffset = Vector3.new(0, 0, 0)
	lastCamCF  = camera.CFrame
end

-- ============================================================
-- PUBLIC
-- ============================================================
function ViewmodelModule.GetMuzzle()
	return vmMuzzle
end

function ViewmodelModule.Kick(isADS, hipCF, adsCF, intensity)
	intensity = intensity or 0.35
	local kickBack = 0.05 * intensity / 0.35
	local kickUp   = 0.02 * intensity / 0.35
	local kickRot  = math.rad(1) * intensity / 0.35
	vmTarget = vmTarget * CFrame.new(0, kickUp, kickBack) * CFrame.Angles(kickRot, 0, 0)
	task.delay(0.09, function()
		vmTarget = isADS and adsCF or hipCF
	end)
end

function ViewmodelModule.SetADSTarget(adsCF)
	vmTarget = adsCF
end

function ViewmodelModule.SetHipTarget(hipCF)
	vmTarget = hipCF
end

local alwaysVisible = true

function ViewmodelModule.SetAlwaysVisible(val)
	alwaysVisible = val
	if vmRoot then
		if not val and not (getIsADS and getIsADS()) then
			vmRoot.CFrame = CFrame.new(0, -9999, 0)
			setVisible(false)
		end
	end
end

-- ============================================================
-- RENDER LOOP
-- ============================================================
RunService.RenderStepped:Connect(function(dt)
	if not vmRoot then return end

	local isADS = getIsADS and getIsADS() or false

	vmCurrent = vmCurrent:Lerp(vmTarget, dt * 20)

	-- Detect first-person
	local isFirstPerson = false
	local char = player.Character
	if char then
		local head = char:FindFirstChild("Head")
		if head then
			local dist = (camera.CFrame.Position - head.Position).Magnitude
			isFirstPerson = dist < 1.5
		end
	end

	if (isADS or alwaysVisible) and isFirstPerson then
		-- ==================================================
		-- CAMERA BOB (applied to camera, first person only)
		-- ==================================================
		local camBob = CFrame.new()

		if not isADS then
			-- Get player speed
			local moveSpeed = 0
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					local vel = hrp.Velocity
					moveSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
				end
			end

			-- Only bob when moving
			local bobIntensity = math.clamp(moveSpeed / 16, 0, 1)

			if bobIntensity > 0.05 then
				-- Detect sprint (using humanoid WalkSpeed as proxy)
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local isSprinting = hum and hum.WalkSpeed > 14

				local freqMult = isSprinting and BOB.sprintFreqMult or 1.0
				local vertMult = isSprinting and BOB.sprintVertMult or 1.0

				bobTimer = bobTimer + dt * freqMult

				local vertBob  = math.sin(bobTimer * BOB.vertFreq * math.pi * 2) * BOB.vertAmount * vertMult * bobIntensity
				local horizBob = math.sin(bobTimer * BOB.horizFreq * math.pi * 2) * BOB.horizAmount * bobIntensity
				local rollBob  = math.sin(bobTimer * BOB.rollFreq * math.pi * 2) * math.rad(BOB.rollAmount) * bobIntensity

				bobTarget = CFrame.new(horizBob, vertBob, 0) * CFrame.Angles(0, 0, rollBob)
			else
				bobTimer = 0
				bobTarget = CFrame.new()
			end
		else
			-- No bob during ADS
			bobTarget = CFrame.new()
		end

		bobCurrent = bobCurrent:Lerp(bobTarget, dt * BOB.lerpSpeed)

		-- ==================================================
		-- GUN SWAY
		-- ==================================================
		local swayCF = CFrame.new()

		if not isADS then
			local t = os.clock()

			-- Idle sway (breathing figure-eight)
			local idleX = math.sin(t * SWAY.idleFreqX * math.pi * 2) * SWAY.idleAmountX
			local idleY = math.sin(t * SWAY.idleFreqY * math.pi * 2) * SWAY.idleAmountY
			local idleRot = math.sin(t * 0.7 * math.pi * 2) * math.rad(SWAY.idleRotAmount)

			-- Movement sway (mouse lag)
			local mouseDelta = UIS:GetMouseDelta()
			local swayTargetX = math.clamp(-mouseDelta.X * SWAY.moveSway * 0.01, -SWAY.moveSwayMax, SWAY.moveSwayMax)
			local swayTargetY = math.clamp(-mouseDelta.Y * SWAY.moveSway * 0.01, -SWAY.moveSwayMax, SWAY.moveSwayMax)

			swayOffset = swayOffset:Lerp(
				Vector3.new(swayTargetX, swayTargetY, 0),
				dt * SWAY.moveSwaySmooth
			)

			-- Walk sway (extra horizontal drift while moving)
			local walkSway = 0
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					local vel = hrp.Velocity
					local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
					local walkIntensity = math.clamp(speed / 16, 0, 1)
					walkSway = math.sin(t * SWAY.walkFreq * math.pi * 2) * SWAY.walkAmount * walkIntensity
				end
			end

			-- Movement roll (slight tilt when strafing)
			local strafeRoll = 0
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					local localVel = hrp.CFrame:VectorToObjectSpace(hrp.Velocity)
					local strafeAmount = math.clamp(localVel.X / 16, -1, 1)
					strafeRoll = -strafeAmount * math.rad(SWAY.moveRotSway)
				end
			end

			swayCF = CFrame.new(
				idleX + swayOffset.X + walkSway,
				idleY + swayOffset.Y,
				0
			) * CFrame.Angles(0, 0, idleRot + strafeRoll)
		else
			-- Minimal sway during ADS (just breathing)
			local t = os.clock()
			local adsIdleX = math.sin(t * 0.6 * math.pi * 2) * SWAY.idleAmountX * 0.3
			local adsIdleY = math.sin(t * 0.5 * math.pi * 2) * SWAY.idleAmountY * 0.3
			swayCF = CFrame.new(adsIdleX, adsIdleY, 0)
			swayOffset = swayOffset:Lerp(Vector3.zero, dt * 12)
		end

		-- ==================================================
		-- APPLY: camera bob + viewmodel with sway
		-- ==================================================
		-- Apply bob + sway to viewmodel only (no camera modification)
		local meleePunch = MeleeRef and MeleeRef.GetCameraPunch and MeleeRef.GetCameraPunch() or CFrame.new()
		vmRoot.CFrame = camera.CFrame * vmCurrent * meleePunch * bobCurrent * swayCF
		setVisible(true)
	else
		vmRoot.CFrame = CFrame.new(0, -9999, 0)
		setVisible(false)
		-- Reset states when not visible
		bobTimer   = 0
		bobCurrent = CFrame.new()
		swayOffset = Vector3.zero
	end

	lastCamCF = camera.CFrame
end)

-- ============================================================
-- INIT
-- ============================================================
function ViewmodelModule.Init(isADSFn)
	getIsADS = isADSFn

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
	end)
end

-- ============================================================
-- TUNER HOOK
-- ============================================================
function ViewmodelModule.SetTargetOverride(cf)
	vmTarget = cf
end

function ViewmodelModule.GetCurrentTarget()
	return vmTarget
end

return ViewmodelModule