--==================================================
-- MovementModule
-- ModuleScript inside PlayerController > Modules
--==================================================

local UIS        = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Movement = {}

--==================================================
-- REFERENCES (set by Init)
--==================================================
local Player, Character, Humanoid, Root

--==================================================
-- CONFIG
--==================================================
local SPEED = {
	WALK   = 8,
	RUN    = 22,
	CROUCH = 8,
	PRONE  = 3
}

local HIP = {}  -- filled in Init once we have the Humanoid

local STAMINA_MAX      = 100
local STAMINA_DRAIN    = 12
local STAMINA_RECOVER  = 8

local BACKWARD_MULTIPLIER = 0.65
local STRAFE_MULTIPLIER   = 0.85
local WEAPON_WEIGHT       = 0.9

--==================================================
-- VAULT CONFIG
--==================================================
local VAULT = {
	REACH          = 2.8,   -- how far forward to probe for an obstacle (studs)
	MIN_HEIGHT     = 0.8,   -- obstacle must be at least this tall to vault
	MAX_HEIGHT     = 4.2,   -- obstacle taller than this is a wall, not a vault
	CLEARANCE      = 4.5,   -- headroom needed above the landing surface
	DURATION       = 0.38,  -- seconds the vault tween takes
	COOLDOWN       = 0.6,   -- seconds before you can vault again
	AUTO_ONLY_RUN  = true,  -- auto-vault only triggers while sprinting (manual always works)
}

--==================================================
-- STATE
--==================================================
local state         = "walk"
local stamina       = STAMINA_MAX
local sliding       = false
local slideVelocity = 0
local leaning       = 0
local leanAmount    = 0
local targetLean    = 0
local getCanRun     = nil

local vaulting      = false
local vaultCooldown = 0   -- counts down each Heartbeat

--==================================================
-- STATE APPLICATION
--==================================================
local function applyState()
	if state == "walk" then
		Humanoid.WalkSpeed = SPEED.WALK
		Humanoid.HipHeight = HIP.STAND

	elseif state == "run" then
		Humanoid.WalkSpeed = SPEED.RUN
		Humanoid.HipHeight = HIP.STAND

	elseif state == "crouch" then
		Humanoid.WalkSpeed = SPEED.CROUCH
		Humanoid.HipHeight = HIP.CROUCH

	elseif state == "prone" then
		Humanoid.WalkSpeed = SPEED.PRONE
		Humanoid.HipHeight = HIP.PRONE
	end
end

--==================================================
-- VAULT HELPERS
--==================================================

-- Returns the landing CFrame if a vault is geometrically possible,
-- or nil if not.  Two-ray approach:
--   Ray 1 (forward) : checks there IS an obstacle in range + height
--   Ray 2 (downward): finds the top surface to land on
local function getVaultLanding()
	if not Root or not Character then return nil end

	local origin    = Root.Position
	local forward   = Root.CFrame.LookVector
	local params    = RaycastParams.new()
	params.FilterDescendantsInstances = { Character }
	params.FilterType = Enum.RaycastFilterType.Exclude

	-- Ray 1 — cast forward at mid-torso height to find the obstacle face
	local fwdOrigin = origin + Vector3.new(0, 0.5, 0)
	local fwdHit    = workspace:Raycast(fwdOrigin, forward * VAULT.REACH, params)
	if not fwdHit then return nil end

	-- Measure obstacle height: cast downward from just above MAX_HEIGHT
	-- at the hit position to find the actual top surface
	local probeTop   = Vector3.new(fwdHit.Position.X, origin.Y + VAULT.MAX_HEIGHT, fwdHit.Position.Z)
	local topHit     = workspace:Raycast(probeTop, Vector3.new(0, -(VAULT.MAX_HEIGHT + 1), 0), params)
	if not topHit then return nil end

	local obstacleTop = topHit.Position.Y
	local obstacleH   = obstacleTop - (origin.Y - HIP.STAND - 0.5)  -- height above feet

	-- Height gate
	if obstacleH < VAULT.MIN_HEIGHT or obstacleH > VAULT.MAX_HEIGHT then return nil end

	-- Clearance check — make sure there's headroom above the landing spot
	local clearOrigin = Vector3.new(topHit.Position.X, obstacleTop + VAULT.CLEARANCE, topHit.Position.Z)
	local clearHit    = workspace:Raycast(clearOrigin, Vector3.new(0, -VAULT.CLEARANCE, 0), params)
	if clearHit then return nil end  -- something blocking overhead

	-- Landing position: land just past the obstacle, on top of it
	local landPos = Vector3.new(
		topHit.Position.X + forward.X * 1.2,
		obstacleTop + HIP.STAND + 0.5,
		topHit.Position.Z + forward.Z * 1.2
	)

	return CFrame.new(landPos) * CFrame.Angles(0, math.atan2(-forward.X, -forward.Z), 0)
end

--==================================================
-- PUBLIC API
--==================================================
function Movement.GetState()
	return state
end

function Movement.GetStamina()
	return stamina
end
---------Melee System----------
function Movement.DrainStamina(amount)
	stamina = math.clamp(stamina - amount, 0, STAMINA_MAX)
	if stamina <= 0 and state == "run" then
		state = "walk"
		applyState()
	end
end
------------------------------------------
function Movement.SetCanRunCheck(fn) getCanRun = fn end

function Movement.Run()
	if state == "crouch" or state == "prone" then return end
	if stamina <= 10 then return end
	if getCanRun and not getCanRun() then return end
	state = "run"
	applyState()
end

function Movement.Walk()
	state = "walk"
	applyState()
end

function Movement.Crouch()
	if state == "prone" then return end  -- must stand up from prone first
	state = state ~= "crouch" and "crouch" or "walk"
	applyState()
end

function Movement.Prone()
	state = state ~= "prone" and "prone" or "walk"
	applyState()
end

function Movement.Slide()
	if state == "run" then
		sliding       = true
		slideVelocity = 70
	end
end

function Movement.LeanLeft()  leaning = -1 end
function Movement.LeanRight() leaning =  1 end
function Movement.LeanStop()  leaning =  0 end

-- Returns true if a vault is currently possible (used by PlayerController
-- to decide whether Space should vault or jump)
function Movement.CanVault()
	if vaulting then return false end
	if vaultCooldown > 0 then return false end
	if not Root or not Humanoid then return false end
	return getVaultLanding() ~= nil
end

-- Attempt a vault.  Returns true if the vault started, false if not possible.
function Movement.Vault()
	if vaulting or vaultCooldown > 0 then return false end
	if not Root or not Humanoid then return false end

	local landCF = getVaultLanding()
	if not landCF then return false end

	vaulting = true

	-- Disable normal movement briefly so the tween isn't fought
	local prevSpeed = Humanoid.WalkSpeed
	Humanoid.WalkSpeed = 0

	-- Tween the root part to the landing CFrame
	local tween = TweenService:Create(
		Root,
		TweenInfo.new(VAULT.DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ CFrame = landCF }
	)
	tween:Play()
	tween.Completed:Connect(function()
		Humanoid.WalkSpeed = prevSpeed
		vaulting      = false
		vaultCooldown = VAULT.COOLDOWN
	end)

	return true
end

--==================================================
-- INIT  (call once from PlayerController)
--==================================================
function Movement.Init(character)
	Character = character
	Humanoid  = character:WaitForChild("Humanoid")
	Root      = character:WaitForChild("HumanoidRootPart")
	Player    = game.Players.LocalPlayer

	-- Build HIP table now that Humanoid exists
	HIP.STAND  = Humanoid.HipHeight
	HIP.CROUCH = Humanoid.HipHeight - 1
	HIP.PRONE  = Humanoid.HipHeight - 2

	-- Reset state on respawn
	state         = "walk"
	stamina       = STAMINA_MAX
	sliding       = false
	slideVelocity = 0
	leaning       = 0
	leanAmount    = 0
	targetLean    = 0
	vaulting      = false
	vaultCooldown = 0

	applyState()
end

--==================================================
-- LOOPS  (connect once, guard with Character check)
--==================================================

-- Movement modifiers: backward/strafe/weapon weight
RunService.RenderStepped:Connect(function(dt)
	if not Humanoid or not Root then return end
	if vaulting then return end  -- don't fight the vault tween

	local move      = Humanoid.MoveDirection
	local baseSpeed = SPEED[state:upper()] or SPEED.WALK
	local speedMod  = 1

	if move:Dot(Root.CFrame.LookVector) < -0.3 then
		speedMod *= BACKWARD_MULTIPLIER
	end
	if math.abs(move:Dot(Root.CFrame.RightVector)) > 0.3 then
		speedMod *= STRAFE_MULTIPLIER
	end
	speedMod *= WEAPON_WEIGHT

	Humanoid.WalkSpeed = baseSpeed * speedMod
end)

-- Slide
RunService.RenderStepped:Connect(function(dt)
	if not Root then return end
	if not sliding then return end

	Root.Velocity    = Root.CFrame.LookVector * slideVelocity
	slideVelocity    = slideVelocity - (120 * dt)

	if slideVelocity <= 0 then
		sliding = false
		state   = "crouch"   -- slide exits into crouch
		applyState()
	end
end)

-- Stamina
RunService.Heartbeat:Connect(function(dt)
	if not Humanoid then return end

	if state == "run" then
		stamina -= STAMINA_DRAIN * dt
	else
		stamina += STAMINA_RECOVER * dt
	end
	stamina = math.clamp(stamina, 0, STAMINA_MAX)

	if stamina <= 0 and state == "run" then
		state = "walk"
		applyState()
	end

	-- Vault cooldown ticker
	if vaultCooldown > 0 then
		vaultCooldown = math.max(0, vaultCooldown - dt)
	end

	-- Auto-vault while sprinting: if the player is moving forward into
	-- a vault-able obstacle, trigger automatically (no button needed)
	if VAULT.AUTO_ONLY_RUN and state == "run" and not vaulting and vaultCooldown == 0 then
		if Humanoid.MoveDirection.Magnitude > 0.1 then
			local dot = Humanoid.MoveDirection:Dot(Root.CFrame.LookVector)
			if dot > 0.7 then  -- only auto-vault when moving mostly forward
				Movement.Vault()
			end
		end
	end
end)

-- Lean
RunService.RenderStepped:Connect(function(dt)
	if not Root then return end

	targetLean = leaning == -1 and -15 or leaning == 1 and 15 or 0
	leanAmount = leanAmount + (targetLean - leanAmount) * 0.15
	Root.CFrame = Root.CFrame * CFrame.Angles(0, 0, math.rad(leanAmount))
end)

return Movement