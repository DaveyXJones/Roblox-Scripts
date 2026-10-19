--==================================================
-- HealthModule
-- ModuleScript inside PlayerController > Modules
--==================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local HealthModule = {}

local player    = Players.LocalPlayer
local character = nil
local humanoid  = nil

-- ============================================================
-- CONFIG
-- ============================================================
local MAX_HEALTH         = 100
local REGEN_RATE         = 0.005      -- HP per second
local REGEN_DELAY        = 15      -- seconds after damage before regen starts
local LOW_HEALTH         = 20     -- below this % blocks running
local CRITICAL_HEALTH    = 25     -- below this % triggers visual warning

local lastDamageTime     = 0
local regenActive        = false

-- Callbacks
local onHealthChanged    = nil
local onDeath            = nil
local onCritical         = nil

-- ============================================================
-- PUBLIC GETTERS
-- ============================================================
function HealthModule.GetHealth()
	if not humanoid then return 0 end
	return humanoid.Health
end

function HealthModule.GetMaxHealth()
	return MAX_HEALTH
end

function HealthModule.GetPercent()
	if not humanoid then return 0 end
	return humanoid.Health / MAX_HEALTH
end

function HealthModule.CanRun()
	return HealthModule.GetPercent() > (LOW_HEALTH / 100)
end

function HealthModule.IsCritical()
	return HealthModule.GetPercent() <= (CRITICAL_HEALTH / 100)
end

-- ============================================================
-- CALLBACKS
-- ============================================================
function HealthModule.OnHealthChanged(fn) onHealthChanged = fn end
function HealthModule.OnDeath(fn)         onDeath         = fn end
function HealthModule.OnCritical(fn)      onCritical      = fn end

-- ============================================================
-- DAMAGE / HEAL
-- ============================================================
function HealthModule.TakeDamage(amount)
	if not humanoid or humanoid.Health <= 0 then return end
	lastDamageTime = tick()
	regenActive    = false
	humanoid.Health = math.max(0, humanoid.Health - amount)
end



function HealthModule.Heal(amount)
	if not humanoid or humanoid.Health <= 0 then return end
	regenActive    = false
	lastDamageTime = tick()
	-- Ask the server to apply the heal
	local remotes = ReplicatedStorage:FindFirstChild("LootRemotes")
	if remotes then
		local re = remotes:FindFirstChild("HealPlayer")
		if re then re:FireServer(amount) end
	end
end

-- ============================================================
-- INTERNAL SETUP
-- ============================================================
local function setupCharacter(char)
	character = char
	humanoid  = char:WaitForChild("Humanoid")

	humanoid.MaxHealth = MAX_HEALTH
	humanoid.Health    = MAX_HEALTH

	-- Disable Roblox's built-in regen (we handle it ourselves)
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	-- Track health changes
	humanoid.HealthChanged:Connect(function(health)
		if onHealthChanged then
			onHealthChanged(health, MAX_HEALTH)
		end
		if health <= 0 then
			if onDeath then onDeath() end
		elseif HealthModule.IsCritical() then
			if onCritical then onCritical(health) end
		end
	end)
end

-- ============================================================
-- REGEN LOOP
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
	if not humanoid or humanoid.Health <= 0 then return end
	if humanoid.Health >= MAX_HEALTH then return end

	local timeSinceDamage = tick() - lastDamageTime
	if timeSinceDamage >= REGEN_DELAY then
		regenActive = true
	end

	if regenActive then
		humanoid.Health = math.min(MAX_HEALTH, humanoid.Health + REGEN_RATE * dt)
	end
end)

-- ============================================================
-- INIT
-- ============================================================
function HealthModule.Init(char)
	lastDamageTime = 0
	regenActive    = false
	setupCharacter(char)
end

return HealthModule