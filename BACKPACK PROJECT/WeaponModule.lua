--==================================================
-- WeaponModule
-- ModuleScript inside PlayerController > Modules
--
-- Manages all weapon firing logic: shoot, reload,
-- ADS, fire mode cycling, burst fire.
--
-- REWORKED:
--   • Per-weapon spread (hipSpread / adsSpread from item data)
--   • Per-weapon recoil kick intensity
--   • Headshot detection (checks hit part name)
--   • Shotgun pellet fan (pelletCount > 1)
--   • Damage falloff past effectiveRange ? maxRange
--   • Per-weapon sound IDs (shootSound, reloadOutSound,
--     reloadInSound from item data, with fallback defaults)
--   • Recoil kick value exposed via GetRecoilKick() so
--     Viewmodel can scale its kick animation
--==================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")
local Players           = game:GetService("Players")

local weaponEquippedEvent = ReplicatedStorage:WaitForChild("WeaponEquipped", 10)
local zombieRemotes       = ReplicatedStorage:WaitForChild("ZombieRemotes", 10)
local RE_DealDamage       = zombieRemotes and zombieRemotes:WaitForChild("DealDamage", 10)
local RE_ShotFired 	= Instance.new("RemoteEvent")
RE_ShotFired.Name   = "ShotFired"
RE_ShotFired.Parent = ReplicatedStorage

local WeaponModule = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ============================================================
-- DEV CONFIG
-- ============================================================
local DEV = {
	INFINITE_AMMO = false,
}

-- ============================================================
-- STATE
-- ============================================================
local activeSlotName = "primary"   -- which equipment slot is active
local ammoInMag      = {}          -- [slotName] = current magazine count
local isReloading    = false
local isADS          = false
local canShoot       = true
local mouseHeld      = false
local lastShot       = 0
local burstActive    = false
local fireModeIndex  = 1
local reloadToken    = 0

local onADSEnter    = nil
local onADSExit     = nil
local onEquip       = nil
local InventoryRef  = nil
local EquipmentRef  = nil
local AttachmentRef = nil

-- ============================================================
-- ACTIVE WEAPON HELPER
-- ============================================================
local function getActiveItem()
	if not EquipmentRef then return nil end
	return EquipmentRef.GetSlot(activeSlotName)
end

-- ============================================================
-- WEAPON STAT ACCESSORS
-- ============================================================
local function getMaxAmmo()
	local item = getActiveItem()
	return (item and item.data and item.data.maxAmmo) or 0
end

local function getReloadTime()
	local item = getActiveItem()
	return (item and item.data and item.data.reloadTime) or 2.0
end

local function getAmmoType()
	local item = getActiveItem()
	return (item and item.data and item.data.ammoType) or ""
end

local function getDamage()
	local item = getActiveItem()
	return (item and item.data and item.data.damage) or 0
end

-- NEW: per-weapon spread
local function getHipSpread()
	local item = getActiveItem()
	return (item and item.data and item.data.hipSpread) or 8
end

local function getAdsSpread()
	local item = getActiveItem()
	return (item and item.data and item.data.adsSpread) or 2
end

-- NEW: per-weapon recoil
local function getRecoilKick()
	local item = getActiveItem()
	return (item and item.data and item.data.recoilKick) or 0.35
end

-- NEW: headshot multiplier
local function getHeadshotMulti()
	local item = getActiveItem()
	return (item and item.data and item.data.headshotMulti) or 2.0
end

-- NEW: range stats
local function getEffectiveRange()
	local item = getActiveItem()
	return (item and item.data and item.data.effectiveRange) or 150
end

local function getMaxRange()
	local item = getActiveItem()
	return (item and item.data and item.data.maxRange) or 300
end

-- NEW: pellet stats (shotgun)
local function getPelletCount()
	local item = getActiveItem()
	return (item and item.data and item.data.pelletCount) or 1
end

local function getPelletSpread()
	local item = getActiveItem()
	return (item and item.data and item.data.pelletSpread) or 0
end

local function getFireModes()
	local item = getActiveItem()
	if not item or not item.data or not item.data.fireModes then
		return { { name = "Semi", fireRate = 0.25, burstCount = 1, burstDelay = 0 } }
	end
	local modes = {}
	for _, modeName in ipairs(item.data.fireModes) do
		if modeName == "Semi" then
			table.insert(modes, { name = "Semi",  fireRate = item.data.fireRate or 0.25, burstCount = 1, burstDelay = 0 })
		elseif modeName == "Auto" then
			table.insert(modes, { name = "Auto",  fireRate = item.data.fireRate or 0.10, burstCount = 1, burstDelay = 0 })
		elseif modeName == "Burst" then
			table.insert(modes, { name = "Burst", fireRate = (item.data.fireRate or 0.10) * 4, burstCount = 3, burstDelay = item.data.fireRate or 0.09 })
		elseif modeName == "Pump" then
			table.insert(modes, { name = "Pump",  fireRate = item.data.fireRate or 0.90, burstCount = 1, burstDelay = 0 })
		end
	end
	return #modes > 0 and modes or { { name = "Semi", fireRate = 0.25, burstCount = 1, burstDelay = 0 } }
end

local function getDefaultModeIndex()
	local item = getActiveItem()
	return (item and item.data and item.data.defaultMode) or 1
end

local function getAssetName()
	local item = getActiveItem()
	return (item and item.data and item.data.assetName) or nil
end

-- ============================================================
-- ATTACHMENT STAT HELPER
-- ============================================================
local function getActiveStats()
	if AttachmentRef and EquipmentRef then
		local weapon = EquipmentRef.GetSlot(activeSlotName)
		if weapon then
			return AttachmentRef.GetStats(weapon)
		end
	end
	return {
		zoomFOV       = 50,
		aimSpread     = 1.0,
		recoilMulti   = 1.0,
		damageMulti   = 1.0,
		reticleId     = "",
		reticleSize   = 1,
		isSuppressed  = false,
		suppressedSnd = "",
	}
end

-- ============================================================
-- SOUNDS
-- Reworked: per-weapon sounds from item data, with fallbacks.
-- Sound instances are cached per weapon ID to avoid re-creation.
-- ============================================================
local FALLBACK_SOUNDS = {
	shoot      = "rbxassetid://78007328611560",
	modeSwitch = "rbxassetid://72425104284712",
	reloadIn   = "rbxassetid://138919936613216",
	reloadOut  = "rbxassetid://122517153269360",
	weaponSwap = "rbxassetid://94023874036646",
	emptyClick = "rbxassetid://132693556036201",
}

-- Cache keyed by weapon id (e.g. "m4a1") so each gun gets its own sounds
local soundCache = {}

local function getWeaponSoundId(item, key)
	if not item or not item.data then return FALLBACK_SOUNDS[key] end
	local mapping = {
		shoot     = "shootSound",
		reloadOut = "reloadOutSound",
		reloadIn  = "reloadInSound",
	}
	local dataKey = mapping[key]
	if dataKey and item.data[dataKey] and item.data[dataKey] ~= "" then
		return item.data[dataKey]
	end
	return FALLBACK_SOUNDS[key]
end

local function getWeaponVolume(item, key)
	if key == "shoot" and item and item.data and item.data.shootVolume then
		return item.data.shootVolume
	end
	if key == "modeSwitch" then return 0.5 end
	return 0.8
end

local function ensureSounds(slotName)
	local item = nil
	if EquipmentRef then item = EquipmentRef.GetSlot(slotName) end
	local cacheKey = (item and item.id) or ("slot_" .. slotName)

	if soundCache[cacheKey] then return cacheKey end

	local tbl = {}
	for _, key in ipairs({"shoot", "modeSwitch", "reloadIn", "reloadOut", "weaponSwap", "emptyClick"}) do
		local s = Instance.new("Sound")
		s.Name               = key
		s.SoundId            = getWeaponSoundId(item, key)
		s.Volume             = getWeaponVolume(item, key)
		s.RollOffMaxDistance = 0
		s.Parent             = camera
		tbl[key] = s
	end
	soundCache[cacheKey] = tbl
	return cacheKey
end

-- Active cache key for the current weapon
local activeSoundKey = "slot_primary"

local function playSound(key)
	local tbl = soundCache[activeSoundKey]
	if not tbl then return end
	local s = tbl[key]
	if s then s:Play() end
end

local function playShootSound()
	local stats = getActiveStats()
	if stats.isSuppressed and stats.suppressedSnd ~= "" then
		local s = Instance.new("Sound")
		s.SoundId            = stats.suppressedSnd
		s.Volume             = 0.35
		s.RollOffMaxDistance = 0
		s.Parent             = camera
		s:Play()
		Debris:AddItem(s, 3)
		return
	end
	local tbl = soundCache[activeSoundKey]
	if not tbl or not tbl.shoot then return end
	-- Clone so overlapping shots don't cut each other off
	local s = tbl.shoot:Clone()
	s.Parent = camera
	s:Play()
	Debris:AddItem(s, 3)
end

-- ============================================================
-- PUBLIC SETTERS
-- ============================================================
function WeaponModule.SetEquipment(equipMod)   EquipmentRef  = equipMod end
function WeaponModule.SetAttachment(attachMod)  AttachmentRef = attachMod end
function WeaponModule.SetInventory(inv)         InventoryRef  = inv end
function WeaponModule.SetMouseHeld(val)         mouseHeld     = val end
function WeaponModule.SetInfiniteAmmo(val)
	DEV.INFINITE_AMMO = val
	print("[WeaponModule] Infinite ammo: " .. tostring(val))
end
function WeaponModule.SetAmmo(val)
	ammoInMag[activeSlotName] = math.clamp(val, 0, getMaxAmmo())
end

-- ============================================================
-- PUBLIC GETTERS
-- ============================================================
function WeaponModule.GetActiveSlotName()   return activeSlotName end
function WeaponModule.GetAmmo()             return ammoInMag[activeSlotName] or 0 end
function WeaponModule.GetIsADS()            return isADS end
function WeaponModule.GetIsReloading()      return isReloading end
function WeaponModule.GetAttachmentStats()  return getActiveStats() end
function WeaponModule.GetFireModeIndex()    return fireModeIndex end

-- NEW: expose recoil kick so Viewmodel can scale its animation
function WeaponModule.GetRecoilKick()
	local stats = getActiveStats()
	return getRecoilKick() * (stats.recoilMulti or 1.0)
end

function WeaponModule.GetFireMode()
	local modes = getFireModes()
	local idx   = math.clamp(fireModeIndex, 1, #modes)
	return modes[idx]
end

-- Returns a weapon-shaped table PlayerController/HUD/Viewmodel
-- can use — mirrors the old format so callers need no changes.
function WeaponModule.GetActiveWeapon()
	local item = getActiveItem()
	if not item then
		return {
			name        = "",
			assetName   = nil,
			maxAmmo     = 0,
			reloadTime  = 2.0,
			ammoType    = "",
			fireModes   = { { name = "Semi", fireRate = 0.25, burstCount = 1, burstDelay = 0 } },
			defaultMode = 1,
			hipCF       = CFrame.new(0.40, -0.50, -0.55),
			adsCF       = CFrame.new(-0.10, -0.25, -0.60),
			iconId      = "",
		}
	end

	local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
	local cfg = item.data and item.data.assetName
		and WeaponConfig.Get(item.data.assetName) or {}

	return {
		name        = item.name,
		assetName   = item.data and item.data.assetName,
		maxAmmo     = getMaxAmmo(),
		reloadTime  = getReloadTime(),
		ammoType    = getAmmoType(),
		fireModes   = getFireModes(),
		defaultMode = getDefaultModeIndex(),
		hipCF       = cfg.hipCF   or CFrame.new(0.40, -0.50, -0.55),
		adsCF       = cfg.adsCF   or CFrame.new(-0.10, -0.25, -0.60),
		axisFix     = cfg.axisFix,
		scale       = cfg.scale,
		iconId      = item.iconId or "",
	}
end

-- ============================================================
-- CALLBACKS
-- ============================================================
function WeaponModule.OnADSEnter(fn) onADSEnter = fn end
function WeaponModule.OnADSExit(fn)  onADSExit  = fn end
function WeaponModule.OnEquip(fn)    onEquip    = fn end

-- ============================================================
-- ADS
-- ============================================================
function WeaponModule.EnterADS()
	if isReloading then return end
	if activeSlotName == "melee" then return end
	isADS = true
	if onADSEnter then onADSEnter() end
end

function WeaponModule.ExitADS()
	isADS = false
	if onADSExit then onADSExit() end
end

-- ============================================================
-- FIRE MODE
-- ============================================================
function WeaponModule.CycleFireMode()
	if isReloading then return "RELOADING" end
	local modes = getFireModes()
	if #modes <= 1 then return "ONLY ONE MODE" end
	fireModeIndex = (fireModeIndex % #modes) + 1
	playSound("modeSwitch")
	return modes[fireModeIndex].name:upper()
end

-- ============================================================
-- SET ACTIVE SLOT
-- ============================================================
function WeaponModule.SetActiveSlot(slotName)
	reloadToken    = reloadToken + 1
	isReloading    = false
	canShoot       = true
	mouseHeld      = false
	burstActive    = false
	lastShot       = 0
	activeSlotName = slotName

	activeSoundKey = ensureSounds(slotName)

	-- First time equipping this slot ? fill the magazine
	if ammoInMag[slotName] == nil then
		ammoInMag[slotName] = getMaxAmmo()
	end

	fireModeIndex = getDefaultModeIndex()

	playSound("weaponSwap")
	if isADS then WeaponModule.ExitADS() end

	local weapon = WeaponModule.GetActiveWeapon()
	if onEquip then onEquip(slotName, weapon) end

	local assetName = getAssetName()
	if weaponEquippedEvent then
		weaponEquippedEvent:FireServer(assetName or "")
	end
end

-- ============================================================
-- RELOAD
-- ============================================================
function WeaponModule.Reload(onStart, onComplete)
	local slotAtStart = activeSlotName
	local maxAmmo     = getMaxAmmo()

	if maxAmmo == 0 then return end
	if not DEV.INFINITE_AMMO and ammoInMag[activeSlotName] == maxAmmo then return end
	if isReloading then return end

	local ammoType = getAmmoType()

	if not DEV.INFINITE_AMMO and InventoryRef then
		local hasReserve = false
		for i = 1, InventoryRef.GetSlotCount() do
			local slot = InventoryRef.GetSlot(i)
			if slot and slot.name == ammoType and slot.quantity > 0 then
				hasReserve = true; break
			end
		end
		if not hasReserve then
			if onComplete then onComplete(ammoInMag[activeSlotName], maxAmmo, true) end
			return
		end
	end

	reloadToken = reloadToken + 1
	local myToken    = reloadToken
	local reloadTime = getReloadTime()

	isReloading = true
	canShoot    = false
	if isADS then WeaponModule.ExitADS() end
	if onStart then onStart() end

	playSound("reloadOut")
	task.wait(reloadTime * 0.4)

	if activeSlotName ~= slotAtStart or reloadToken ~= myToken then
		isReloading = false; canShoot = true; return
	end

	playSound("reloadIn")
	task.wait(reloadTime * 0.6)

	if activeSlotName ~= slotAtStart or reloadToken ~= myToken then
		isReloading = false; canShoot = true; return
	end

	if not DEV.INFINITE_AMMO and InventoryRef then
		local needed = maxAmmo - (ammoInMag[activeSlotName] or 0)
		for i = 1, InventoryRef.GetSlotCount() do
			if needed <= 0 then break end
			local slot = InventoryRef.GetSlot(i)
			if slot and slot.name == ammoType then
				local take = math.min(needed, slot.quantity)
				InventoryRef.RemoveQuantity(i, take)
				ammoInMag[activeSlotName] = (ammoInMag[activeSlotName] or 0) + take
				needed = needed - take
			end
		end
	else
		ammoInMag[activeSlotName] = maxAmmo
	end

	isReloading = false
	canShoot    = true
	if onComplete then onComplete(ammoInMag[activeSlotName], maxAmmo, false) end
end

-- ============================================================
-- DAMAGE FALLOFF HELPER
-- Full damage up to effectiveRange, linear falloff to 30%
-- at maxRange, zero beyond maxRange.
-- ============================================================
local function calcFalloff(distance)
	local effRange = getEffectiveRange()
	local maxRange = getMaxRange()

	if distance <= effRange then
		return 1.0
	elseif distance >= maxRange then
		return 0.0
	else
		-- Linear falloff from 100% ? 30% between effective and max range
		local t = (distance - effRange) / (maxRange - effRange)
		return 1.0 - (t * 0.7)   -- 1.0 at effective, 0.3 at max
	end
end

-- ============================================================
-- SINGLE RAY CAST  (used for both normal shots and pellets)
-- Returns: RaycastResult or nil
-- ============================================================
local function castRay(spreadPixels, pelletAngle)
	local cx = camera.ViewportSize.X / 2 + math.random(-spreadPixels, spreadPixels)
	local cy = camera.ViewportSize.Y / 2 + math.random(-spreadPixels, spreadPixels)

	local ray = camera:ViewportPointToRay(cx, cy)
	local dir = ray.Direction

	-- Apply pellet cone spread (additional angular offset for shotguns)
	if pelletAngle and pelletAngle > 0 then
		local angleRad = math.rad(pelletAngle)
		local randAngle = math.random() * 2 * math.pi
		local randRadius = math.random() * angleRad
		-- Rotate direction vector by random offset within cone
		local right = dir:Cross(Vector3.new(0, 1, 0)).Unit
		local up    = right:Cross(dir).Unit
		local offset = right * (math.cos(randAngle) * math.sin(randRadius))
			+ up    * (math.sin(randAngle) * math.sin(randRadius))
		dir = (dir + offset).Unit
	end

	local params = RaycastParams.new()
	local char   = player.Character
	local vmFolder = camera:FindFirstChild("Viewmodel")
	local filterList = {}
	if char     then table.insert(filterList, char) end
	if vmFolder then table.insert(filterList, vmFolder) end
	params.FilterDescendantsInstances = filterList
	params.FilterType = Enum.RaycastFilterType.Exclude

	return workspace:Raycast(ray.Origin, dir * (getMaxRange() + 50), params), ray.Origin
end

-- ============================================================
-- PROCESS A HIT  (damage calc with headshot + falloff)
-- ============================================================
local function processHit(result, origin)
	local stats = getActiveStats()

	-- Impact spark
	local spark = Instance.new("Part", workspace)
	spark.Size       = Vector3.new(0.1, 0.1, 0.1)
	spark.CFrame     = CFrame.new(result.Position)
	spark.Anchored   = true
	spark.CanCollide = false
	spark.BrickColor = BrickColor.new("Bright yellow")
	spark.Material   = Enum.Material.Neon
	Debris:AddItem(spark, 0.08)

	local model = result.Instance:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then
		if RE_DealDamage then
			local baseDamage = getDamage() * stats.damageMulti

			-- Headshot check
			local hitPart = result.Instance
			local isHeadshot = hitPart and (hitPart.Name == "Head" or hitPart.Name == "head")
			if isHeadshot then
				baseDamage = baseDamage * getHeadshotMulti()
			end

			-- Distance falloff
			local distance = (result.Position - origin).Magnitude
			local falloff  = calcFalloff(distance)
			baseDamage = baseDamage * falloff

			local finalDamage = math.floor(baseDamage)
			if finalDamage > 0 then
				RE_DealDamage:FireServer(model, finalDamage)
			end
		end
	end
end

-- ============================================================
-- SHOOT — REWORKED
-- Now supports per-weapon spread, pellet fan for shotguns,
-- headshot detection, and damage falloff.
-- ============================================================
local function fireBullet(vmMuzzle, onFired)
	local stats = getActiveStats()

	if not DEV.INFINITE_AMMO then
		ammoInMag[activeSlotName] = (ammoInMag[activeSlotName] or 1) - 1
	end

	playShootSound()

	-- Alert zombies + broadcast sound to other players
	if RE_ShotFired then
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local stats = getActiveStats()
			local shootSoundId = ""
			local isSuppressed = false

			-- Get the weapon's shoot sound ID so other clients play the right sound
			local soundTbl = soundCache[activeSoundKey]
			if soundTbl and soundTbl.shoot then
				shootSoundId = soundTbl.shoot.SoundId
			end

			if stats.isSuppressed then
				isSuppressed = true
				if stats.suppressedSnd and stats.suppressedSnd ~= "" then
					shootSoundId = stats.suppressedSnd
				end
			end

			RE_ShotFired:FireServer(root.Position, shootSoundId, isSuppressed)
		end
	end

	-- Muzzle flash
	if vmMuzzle then
		local flash = Instance.new("PointLight", vmMuzzle)
		flash.Brightness = 8
		flash.Range      = 14
		flash.Color      = Color3.fromRGB(255, 200, 80)
		Debris:AddItem(flash, 0.05)
	end

	-- Per-weapon spread (from item data, modified by attachment aimSpread)
	local baseSpread = isADS and getAdsSpread() or getHipSpread()
	local spread     = math.max(1, math.floor(baseSpread * stats.aimSpread))

	local pellets       = getPelletCount()
	local pelletAngle   = getPelletSpread()

	if pellets <= 1 then
		-- Standard single-projectile weapon
		local result, origin = castRay(spread, 0)
		if result then
			processHit(result, origin)
		end
	else
		-- Shotgun: fire multiple pellets in a cone
		for _ = 1, pellets do
			local result, origin = castRay(spread, pelletAngle)
			if result then
				processHit(result, origin)
			end
		end
	end

	if onFired then onFired(ammoInMag[activeSlotName], getMaxAmmo()) end
end

function WeaponModule.Shoot(vmMuzzle, onFired)
	if not canShoot or isReloading then return end
	if activeSlotName == "melee" then return end

	local currentAmmo = ammoInMag[activeSlotName] or 0
	if not DEV.INFINITE_AMMO and currentAmmo <= 0 then
		playSound("emptyClick")
		if onFired then onFired(0, getMaxAmmo()) end
		return
	end

	local mode = WeaponModule.GetFireMode()
	local now  = tick()
	if now - lastShot < mode.fireRate then return end
	lastShot = now

	if mode.name == "Semi" or mode.name == "Auto" or mode.name == "Pump" then
		fireBullet(vmMuzzle, onFired)

	elseif mode.name == "Burst" then
		if burstActive then return end
		burstActive = true
		local shotsLeft = mode.burstCount
		local function fireNext()
			if shotsLeft <= 0 then burstActive = false; return end
			if not DEV.INFINITE_AMMO and (ammoInMag[activeSlotName] or 0) <= 0 then
				burstActive = false; return
			end
			fireBullet(vmMuzzle, onFired)
			shotsLeft = shotsLeft - 1
			if shotsLeft > 0 then
				task.delay(mode.burstDelay, fireNext)
			else
				burstActive = false
			end
		end
		fireNext()
	end
end

function WeaponModule.TryAutoShoot(vmMuzzle, onFired)
	if not mouseHeld then return end
	local mode = WeaponModule.GetFireMode()
	if mode.name ~= "Auto" then return end
	WeaponModule.Shoot(vmMuzzle, onFired)
end

-- ============================================================
-- INIT
-- ============================================================
function WeaponModule.Init()
	-- Pre-warm fallback sounds for each slot category
	ensureSounds("primary")
	ensureSounds("secondary")
	ensureSounds("melee")
	print("[WeaponModule] Initialized (reworked: per-weapon ballistics).")
end

return WeaponModule