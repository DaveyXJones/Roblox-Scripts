--==================================================
-- SurvivalModule
-- ModuleScript inside PlayerController > Modules
--
-- Handles hunger, thirst, and consumable item effects.
-- Wired into MovementModule (speed penalty) and
-- HealthModule (HP drain when starving/dehydrated).
-- HUDModule reads UpdateHunger / UpdateThirst each tick.
--==================================================

local RunService = game:GetService("RunService")

local SurvivalModule = {}

-- ============================================================
-- CONFIG
-- ============================================================
local CFG = {
	-- -- Hunger ----------------------------------------------
	-- Full ? empty at idle in 3600 s (1 hr).
	-- Sprint multiplier applied on top.
	HUNGER_MAX         = 100,
	HUNGER_DRAIN_IDLE  = 100 / 3600,        -- per second at idle
	HUNGER_SPRINT_MULT = 2.0,               -- drain rate while sprinting
	-- Sprint "fast" target: full ? empty in ~40 min of pure sprint
	-- 100 / (40*60) ˜ 0.0417  but we achieve this via the multiplier:
	-- idle_drain * sprint_mult = (100/3600) * 2 ˜ 0.0556 ? ~30 min pure sprint
	-- Tweak HUNGER_SPRINT_MULT to taste (2.5 ? ~24 min, 1.8 ? ~33 min)

	HUNGER_CRITICAL    = 20,                -- below this ? speed penalty kicks in
	HUNGER_EMPTY       = 0,

	-- -- Thirst ----------------------------------------------
	-- Scales with hunger: thirst drains ~1.4× faster than hunger baseline.
	THIRST_MAX         = 100,
	THIRST_DRAIN_IDLE  = 100 / 3600 * 1.4,  -- slightly faster than hunger
	THIRST_SPRINT_MULT = 2.4,               -- thirst spikes harder when sprinting

	THIRST_CRITICAL    = 20,
	THIRST_EMPTY       = 0,

	-- -- Penalties -------------------------------------------
	-- Applied to WalkSpeed as a multiplier when critical/empty.
	PENALTY_CRITICAL   = 0.75,              -- 25% slower when hungry/thirsty
	PENALTY_EMPTY      = 0.50,              -- 50% slower when starving/dehydrated

	-- HP drain when both hunger AND thirst are empty
	HP_DRAIN_RATE      = 2,                 -- HP per second when starving + dehydrated
	HP_DRAIN_RATE_ONE  = 0.5,              -- HP per second when only one is empty

	-- -- Bandage ---------------------------------------------
	BANDAGE_HEAL       = 25,               -- HP restored per bandage use

	-- -- Food / Water restore amounts ------------------------
	-- Set on item.data.hungerRestore / item.data.waterRestore
	-- Defaults used if data fields are absent:
	DEFAULT_FOOD_RESTORE  = 35,
	DEFAULT_WATER_RESTORE = 40,
	-- Eating food also gives a small thirst top-up:
	FOOD_WATER_BONUS      = 10,
}

-- ============================================================
-- STATE
-- ============================================================
local hunger   = CFG.HUNGER_MAX
local thirst   = CFG.THIRST_MAX

-- Injected references (set by Init)
local getMovementState = nil   -- fn() ? "walk"|"run"|"crouch"|"prone"
local takeDamage       = nil   -- fn(amount)
local getHumanoid      = nil   -- fn() ? Humanoid or nil

-- Callbacks
local onHungerChanged  = nil   -- fn(hunger, max)
local onThirstChanged  = nil   -- fn(thirst, max)
local onHungerCritical = nil   -- fn()
local onThirstCritical = nil   -- fn()

-- ============================================================
-- PUBLIC GETTERS
-- ============================================================
function SurvivalModule.GetHunger()        return hunger                        end
function SurvivalModule.GetThirst()        return thirst                        end
function SurvivalModule.GetHungerPct()     return hunger / CFG.HUNGER_MAX       end
function SurvivalModule.GetThirstPct()     return thirst / CFG.THIRST_MAX       end
function SurvivalModule.IsHungry()         return hunger <= CFG.HUNGER_CRITICAL  end
function SurvivalModule.IsThirsty()        return thirst <= CFG.THIRST_CRITICAL  end
function SurvivalModule.IsStarving()       return hunger <= CFG.HUNGER_EMPTY     end
function SurvivalModule.IsDehydrated()     return thirst <= CFG.THIRST_EMPTY     end
---Persistance
function SurvivalModule.SetHunger(val)
	hunger = math.clamp(val, 0, CFG.HUNGER_MAX)
	if onHungerChanged then onHungerChanged(hunger, CFG.HUNGER_MAX) end
end
function SurvivalModule.SetThirst(val)
	thirst = math.clamp(val, 0, CFG.THIRST_MAX)
	if onThirstChanged then onThirstChanged(thirst, CFG.THIRST_MAX) end
end
-- ============================================================
-- SPEED PENALTY MULTIPLIER
-- PlayerController / MovementModule should multiply WalkSpeed
-- by this value each RenderStepped tick.
-- ============================================================
function SurvivalModule.GetSpeedMultiplier()
	local hMult = 1
	local tMult = 1

	if hunger <= CFG.HUNGER_EMPTY then
		hMult = CFG.PENALTY_EMPTY
	elseif hunger <= CFG.HUNGER_CRITICAL then
		hMult = CFG.PENALTY_CRITICAL
	end

	if thirst <= CFG.THIRST_EMPTY then
		tMult = CFG.PENALTY_EMPTY
	elseif thirst <= CFG.THIRST_CRITICAL then
		tMult = CFG.PENALTY_CRITICAL
	end

	-- Take the worse of the two penalties
	return math.min(hMult, tMult)
end

-- ============================================================
-- CALLBACKS
-- ============================================================
function SurvivalModule.OnHungerChanged(fn)  onHungerChanged  = fn end
function SurvivalModule.OnThirstChanged(fn)  onThirstChanged  = fn end
function SurvivalModule.OnHungerCritical(fn) onHungerCritical = fn end
function SurvivalModule.OnThirstCritical(fn) onThirstCritical = fn end

-- ============================================================
-- CONSUME ACTIONS
-- Called by InventoryModule item.data.onUse
-- ============================================================

-- Eat food: restores hunger + small water bonus
function SurvivalModule.Eat(item)
	if hunger >= CFG.HUNGER_MAX then return false end

	local restore = (item and item.data and item.data.hungerRestore)
		or CFG.DEFAULT_FOOD_RESTORE
	local waterBonus = (item and item.data and item.data.foodWaterBonus)
		or CFG.FOOD_WATER_BONUS

	hunger = math.min(CFG.HUNGER_MAX, hunger + restore)
	thirst = math.min(CFG.THIRST_MAX, thirst + waterBonus)

	if onHungerChanged then onHungerChanged(hunger, CFG.HUNGER_MAX) end
	if onThirstChanged then onThirstChanged(thirst, CFG.THIRST_MAX) end
	return true
end

-- Drink water: restores thirst only
function SurvivalModule.Drink(item)
	if thirst >= CFG.THIRST_MAX then return false end

	local restore = (item and item.data and item.data.waterRestore)
		or CFG.DEFAULT_WATER_RESTORE

	thirst = math.min(CFG.THIRST_MAX, thirst + restore)

	if onThirstChanged then onThirstChanged(thirst, CFG.THIRST_MAX) end
	return true
end

-- Use bandage: heals HP
function SurvivalModule.UseBandage(item)
	local hum = getHumanoid and getHumanoid()
	if hum and hum.Health >= hum.MaxHealth then return false end

	local healAmt = (item and item.data and item.data.healAmount)
		or CFG.BANDAGE_HEAL
	if SurvivalModule._healFn then
		SurvivalModule._healFn(healAmt)
	end
	return true
end

-- ============================================================
-- DRAIN LOOP
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
	if not getMovementState then return end

	local isSprinting = getMovementState() == "run"

	-- Hunger drain
	local hDrain = CFG.HUNGER_DRAIN_IDLE
		* (isSprinting and CFG.HUNGER_SPRINT_MULT or 1)
		* dt

	local prevHunger = hunger
	hunger = math.max(0, hunger - hDrain)

	if onHungerChanged then onHungerChanged(hunger, CFG.HUNGER_MAX) end

	-- Hunger critical callback (fire once on crossing threshold)
	if prevHunger > CFG.HUNGER_CRITICAL and hunger <= CFG.HUNGER_CRITICAL then
		if onHungerCritical then onHungerCritical() end
	end

	-- Thirst drain (sprinting spikes thirst harder)
	local tDrain = CFG.THIRST_DRAIN_IDLE
		* (isSprinting and CFG.THIRST_SPRINT_MULT or 1)
		* dt

	local prevThirst = thirst
	thirst = math.max(0, thirst - tDrain)

	if onThirstChanged then onThirstChanged(thirst, CFG.THIRST_MAX) end

	if prevThirst > CFG.THIRST_CRITICAL and thirst <= CFG.THIRST_CRITICAL then
		if onThirstCritical then onThirstCritical() end
	end

	-- HP drain when starving / dehydrated
	local starving     = hunger <= CFG.HUNGER_EMPTY
	local dehydrated   = thirst <= CFG.THIRST_EMPTY
	local hum          = getHumanoid and getHumanoid()

	if hum and hum.Health > 0 then
		if starving and dehydrated then
			hum.Health = math.max(0, hum.Health - CFG.HP_DRAIN_RATE * dt)
		elseif starving or dehydrated then
			hum.Health = math.max(0, hum.Health - CFG.HP_DRAIN_RATE_ONE * dt)
		end
	end
end)

-- ============================================================
-- INIT
-- Called from PlayerController after character loads.
--
-- movementStateFn  : fn() ? current movement state string
-- healFn           : fn(amount) ? heals the player (from HealthModule)
-- humanoidFn       : fn() ? current Humanoid instance
-- ============================================================
function SurvivalModule.Init(movementStateFn, healFn, humanoidFn)
	getMovementState   = movementStateFn
	SurvivalModule._healFn = healFn
	getHumanoid        = humanoidFn

	-- Reset on (re)spawn
	hunger = CFG.HUNGER_MAX
	thirst = CFG.THIRST_MAX

	print("[Survival] Initialized.")
end

return SurvivalModule