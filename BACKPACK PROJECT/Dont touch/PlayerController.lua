--==================================================
-- PlayerController (LocalScript) -- DECLARATIONS--
--==================================================
print("PlayerController running")

local UIS               = game:GetService("UserInputService")
local CAS               = game:GetService("ContextActionService") -- ADDED: for multi-platform input
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")


local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local Modules   = script:WaitForChild("Modules")
local Movement  = require(Modules:WaitForChild("MovementModule"))
local Camera    = require(Modules:WaitForChild("CameraModule"))
local Weapon    = require(Modules:WaitForChild("WeaponModule"))
local Viewmodel = require(Modules:WaitForChild("ViewmodelModule"))
local HUD       = require(Modules:WaitForChild("HUDModule"))
local Health    = require(Modules:WaitForChild("HealthModule"))
local Debug     = require(Modules:WaitForChild("DebugModule"))
local Inventory = require(Modules:WaitForChild("InventoryModule"))
local Backpack    = require(Modules:WaitForChild("BackpackUI"))
local Equipment   = require(Modules:WaitForChild("EquipmentModule"))
local Attachment  = require(Modules:WaitForChild("AttachmentModule"))
local ScopeOverlay = require(Modules:WaitForChild("ScopeOverlay"))
local Survival  = require(Modules:WaitForChild("SurvivalModule"))
local MobileHUD = require(Modules:WaitForChild("MobileHUD"))
local Melee     = require(Modules:WaitForChild("MeleeModule"))
local GuiService = game:GetService("GuiService")
local Flashlight = require(Modules:WaitForChild("FlashlightModule"))

local StarterGui = game:GetService("StarterGui")
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

-- ============================================================
-- PLATFORM DETECTION  -- ADDED
-- Detects whether the player is on PC, controller, or mobile
-- so we can show correct hints and adjust input behaviour
-- ============================================================
local isMobile = UIS.TouchEnabled 
	and not UIS.KeyboardEnabled

local isPC         = UIS.MouseEnabled 
	and UIS.KeyboardEnabled

local isController = UIS.GamepadEnabled 
	and not UIS.MouseEnabled

-- ============================================================
-- WIRE MODULES TOGETHER
-- ============================================================
Viewmodel.Init(function() return Weapon.GetIsADS() end)

local PLACEHOLDER_RETICLE_ID = "rbxassetid://0"

local function hasRealReticle(reticleId)
	return reticleId ~= nil and reticleId ~= "" and reticleId ~= PLACEHOLDER_RETICLE_ID
end

Weapon.OnADSEnter(function()
	local stats = Weapon.GetAttachmentStats()
	Camera.EnterADS(stats.zoomFOV)
	if Camera.GetIsOTS() then
		-- Third person OTS â€” show dot reticle, no viewmodel ADS
		HUD.ShowOTSDot(true)
	else
		-- First person ADS â€” viewmodel and scope overlay
		Viewmodel.SetADSTarget(Weapon.GetActiveWeapon().adsCF)
		HUD.SetCrosshair(false)
		local shouldShowScopeOverlay = hasRealReticle(stats.reticleId) or ((stats.zoomFOV or 50) <= 30)
		if shouldShowScopeOverlay then
			ScopeOverlay.Show(hasRealReticle(stats.reticleId) and stats.reticleId or "", stats.reticleSize)
		end
	end
end)

Weapon.OnADSExit(function()
	local wasOTS = Camera.GetIsOTS()
	Camera.ExitADS()
	if wasOTS then
		HUD.ShowOTSDot(false)
		HUD.SetCrosshair(false)  -- third person has no crosshair at hip
	else
		Viewmodel.SetHipTarget(Weapon.GetActiveWeapon().hipCF)
		HUD.SetCrosshair(true)
		ScopeOverlay.Hide()
	end
end)

Weapon.OnEquip(function(slotName, weapon)
	if weapon and weapon.assetName then
		Viewmodel.Build(weapon)
	end
	HUD.UpdateWeapon(weapon)
	if weapon and weapon.maxAmmo and weapon.maxAmmo > 0 then
		HUD.UpdateAmmo(weapon.name, Weapon.GetAmmo(), weapon.maxAmmo)
	else
		HUD.UpdateAmmo("", 0, 0)
	end
	if weapon and weapon.fireModes then
		HUD.UpdateFireMode(weapon.fireModes, Weapon.GetFireModeIndex())
	end
	if weapon and weapon.name and weapon.name ~= "" then
		HUD.ShowNotif("[ " .. weapon.name:upper() .. " ]", 1.0)
	end
end)

Movement.SetCanRunCheck(function()
	return Health.CanRun()
end)

local cancelHandsAction
local lastHealthValue = 100

Health.OnHealthChanged(function(health, max)
	HUD.UpdateHealth(health, max)
	if health < lastHealthValue then
		cancelHandsAction("ACTION INTERRUPTED", true)
	end
	lastHealthValue = health
end)

Health.OnDeath(function()
	cancelHandsAction(nil, true)
	HUD.ShowNotif("YOU DIED", 3)
end)

Health.OnCritical(function(health)
	HUD.ShowNotif("LOW HEALTH!", 2)
end)

-- ============================================================
-- INIT
-- ============================================================
local function initSurvival(char)
	Survival.Init(
		function() return Movement.GetState() end,
		function(amt) Health.Heal(amt) end,
		function() return char:FindFirstChild("Humanoid") end
	)
end

Movement.Init(character)
Camera.Init(character)
Weapon.Init()
Weapon.SetEquipment(Equipment)
Weapon.SetAttachment(Attachment)
Health.Init(character)
lastHealthValue = Health.GetHealth()
Inventory.Init()
Equipment.Init()
Backpack.Init(Inventory, Equipment)
Weapon.SetInventory(Inventory)
Inventory.SetSurvival(Survival)
initSurvival(character)
Melee.Init()
Melee.SetEquipment(Equipment)
Melee.SetViewmodel(Viewmodel)
Melee.SetCamera(Camera)
--------flashlight----
Flashlight.Init()
Flashlight.SetCamera(Camera)
Flashlight.SetViewmodel(Viewmodel)
Flashlight.SetWeapon(Weapon)
Flashlight.SetHUD(HUD)
-------------added---
Melee.SetMovement(Movement)
Melee.SetHUD(HUD)
Viewmodel.SetMelee(Melee)

Survival.OnHungerChanged(function(h, max) HUD.UpdateHunger(h, max) end)
Survival.OnThirstChanged(function(t, max) HUD.UpdateThirst(t, max) end)
Inventory.OnSlotChanged(function(index, item)
	HUD.HotbarRefreshSlot(index, item)
end)

local function refreshCarryHotbar()
	HUD.HotbarRefreshCarrySlot("primary", Equipment.GetSlot("primary"))
	HUD.HotbarRefreshCarrySlot("secondary", Equipment.GetSlot("secondary"))
	HUD.HotbarRefreshCarrySlot("melee", Equipment.GetSlot("melee"))
end

for i = 1, Inventory.GetSlotCount() do
	HUD.HotbarRefreshSlot(i, Inventory.GetSlot(i))
end
refreshCarryHotbar()

-- ============================================================
-- HANDS-DRIVEN ACTIVE ITEM FLOW
-- Carry slots act as holsters. The only active / usable item
-- is whatever is currently in the hands slot.
-- ============================================================
local EMPTY_VIEWMODEL = {
	assetName = nil,
	hipCF = CFrame.new(),
	adsCF = CFrame.new(),
	axisFix = CFrame.new(),
	scale = 1,
}

local function getHandsItem()
	return Equipment.GetSlot("hands")
end

local function getHandsUseType()
	local item = getHandsItem()
	return item and item.type or nil
end

local function isHandsEmpty()
	return getHandsItem() == nil
end

local function isHandsGun()
	local itemType = getHandsUseType()
	return itemType == "primary" or itemType == "secondary"
end

local function isHandsMeleeOrEmpty()
	local itemType = getHandsUseType()
	return itemType == "melee" or itemType == nil
end

local PLACEHOLDER_ASSET_ID = "rbxassetid://0"
local activeHandsAction = nil
local ignoreHandsSlotActionCancel = false

local function isPlaceholderAssetId(assetId)
	return assetId == nil or assetId == "" or assetId == PLACEHOLDER_ASSET_ID
end

local function getActionAnimator()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	return animator
end

local function playHandsActionAnimation(animationId)
	if isPlaceholderAssetId(animationId) then return nil end
	local animator = getActionAnimator()
	if not animator then return nil end

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not ok or not track then
		warn("[PlayerController] Failed to load hands action animation: " .. tostring(animationId))
		return nil
	end

	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play(0.1)
	return track
end

local function playHandsActionSound(soundId)
	if isPlaceholderAssetId(soundId) then return nil end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.7
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = 4
	sound.RollOffMaxDistance = 24
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, 8)
	return sound
end

local function stopHandsActionPlayback(action)
	if not action then return end
	if action.track then
		pcall(function()
			action.track:Stop(0.1)
			action.track:Destroy()
		end)
		action.track = nil
	end
	if action.sound then
		pcall(function()
			action.sound:Stop()
			action.sound:Destroy()
		end)
		action.sound = nil
	end
end

cancelHandsAction = function(reason, silent)
	if not activeHandsAction then return false end
	local action = activeHandsAction
	activeHandsAction = nil
	stopHandsActionPlayback(action)
	if HUD and HUD.ClearActionProgress then
		HUD.ClearActionProgress()
	end
	if reason and not silent and HUD and HUD.ShowNotif then
		HUD.ShowNotif(reason, 1.1)
	end
	return true
end

local function getHandsActionSpec(item)
	if not item or not item.data then return nil end
	local data = item.data

	if item.type == "grenade" then
		return {
			label = data.throwLabel or data.useLabel or "THROWING",
			duration = tonumber(data.throwDuration) or 0.55,
			animationId = data.throwAnimationId or data.useAnimationId or "",
			soundId = data.throwSoundId or data.useSoundId or "",
			cancelOnMove = data.throwCancelOnMove == true,
			canUse = function()
				return true
			end,
			apply = function(liveItem)
				local throwRemote = ReplicatedStorage:FindFirstChild("ThrowGrenade")
				local cameraCf = workspace.CurrentCamera and workspace.CurrentCamera.CFrame
				local direction = cameraCf and cameraCf.LookVector
				if not direction then
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					direction = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
				end
				if not throwRemote then
					HUD.ShowNotif("GRENADE SERVER MISSING", 1.4)
					return false
				end
				throwRemote:FireServer({
					id = liveItem.id or "",
					name = liveItem.name or "",
					type = liveItem.type or "",
					iconId = liveItem.iconId or "",
					quantity = 1,
					maxStack = liveItem.maxStack or 1,
					data = liveItem.data or {},
				}, direction)
				return true
			end,
		}
	elseif data.hungerRestore then
		return {
			label = data.useLabel or "EATING",
			duration = tonumber(data.useDuration) or 3.4,
			animationId = data.useAnimationId or "",
			soundId = data.useSoundId or "",
			cancelOnMove = data.cancelOnMove ~= false,
			canUse = function()
				return Survival.GetHunger() < 100
			end,
			apply = function(liveItem)
				return Survival.Eat(liveItem)
			end,
		}
	elseif data.waterRestore then
		return {
			label = data.useLabel or "DRINKING",
			duration = tonumber(data.useDuration) or 2.8,
			animationId = data.useAnimationId or "",
			soundId = data.useSoundId or "",
			cancelOnMove = data.cancelOnMove ~= false,
			canUse = function()
				return Survival.GetThirst() < 100
			end,
			apply = function(liveItem)
				return Survival.Drink(liveItem)
			end,
		}
	elseif data.healAmount then
		return {
			label = data.useLabel or "BANDAGING",
			duration = tonumber(data.useDuration) or 3.2,
			animationId = data.useAnimationId or "",
			soundId = data.useSoundId or "",
			cancelOnMove = data.cancelOnMove ~= false,
			canUse = function()
				return Health.GetHealth() < Health.GetMaxHealth()
			end,
			apply = function(liveItem)
				return Survival.UseBandage(liveItem)
			end,
		}
	end

	return nil
end

local function syncHandsState()
	Flashlight.OnWeaponSwitch()
	Melee.Reset()

	local handsItem = getHandsItem()
	local activeType = (handsItem and (handsItem.type == "primary" or handsItem.type == "secondary" or handsItem.type == "melee" or handsItem.type == "grenade"))
		and handsItem.type or "hands"

	Weapon.SetActiveSlot(activeType)

	local w = Weapon.GetActiveWeapon()
	if w and w.assetName then
		Viewmodel.SetAlwaysVisible(true)
		Viewmodel.Build(w)
	else
		Viewmodel.SetAlwaysVisible(false)
		Viewmodel.Build(EMPTY_VIEWMODEL)
		local weaponEquipped = ReplicatedStorage:FindFirstChild("WeaponEquipped")
		if weaponEquipped then weaponEquipped:FireServer("") end
	end

	HUD.UpdateWeapon(handsItem and {
		name = handsItem.name or "",
		iconId = handsItem.iconId or "",
	} or w)

	if w and w.maxAmmo and w.maxAmmo > 0 and (activeType == "primary" or activeType == "secondary") then
		HUD.UpdateAmmo(w.name, Weapon.GetAmmo(), w.maxAmmo)
		if w.fireModes then
			HUD.UpdateFireMode(w.fireModes, Weapon.GetFireModeIndex())
		end
	else
		HUD.UpdateAmmo("", 0, 0)
		HUD.UpdateFireMode({}, 1)
	end
end

local function activateWeaponSlot(slotName)
	local handsItem = getHandsItem()
	if handsItem and handsItem.type == slotName and Equipment.IsSlotEmpty(slotName) then
		syncHandsState()
		return true
	end
	if Equipment.IsSlotEmpty(slotName) then
		return false
	end
	if not Equipment.MoveSlot(slotName, "hands") then
		return false
	end
	syncHandsState()
	return true
end

local function moveInventoryItemToEquipment(slotIndex, targetSlot)
	local item = Inventory.GetSlot(slotIndex)
	if not item or not targetSlot or not Equipment.CanEquipInto(targetSlot, item) then
		return false
	end

	Inventory.ClearSlot(slotIndex)
	local displaced = Equipment.Swap(targetSlot, item)
	if displaced then
		Inventory.SetSlot(slotIndex, {
			id = displaced.id or "",
			name = displaced.name,
			type = displaced.type or "",
			quantity = displaced.quantity or 1,
			maxStack = displaced.maxStack or 1,
			iconId = displaced.iconId or "",
			data = displaced.data or {},
		})
	end
	if targetSlot == "hands" then
		syncHandsState()
	end
	return true
end

local function useHandsItem()
	local item = getHandsItem()
	if not item or not item.data then return false end
	if activeHandsAction then
		return false
	end

	local spec = getHandsActionSpec(item)
	if not spec then
		return false
	end

	if spec.canUse and not spec.canUse() then
		HUD.ShowNotif("CAN'T USE RIGHT NOW", 1.2)
		return false
	end

	activeHandsAction = {
		label = spec.label,
		startedAt = tick(),
		duration = math.max(0.1, spec.duration or 0.1),
		itemId = item.id or "",
		itemName = item.name or "",
		cancelOnMove = spec.cancelOnMove ~= false,
		apply = spec.apply,
		track = playHandsActionAnimation(spec.animationId),
		sound = playHandsActionSound(spec.soundId),
	}

	if HUD and HUD.SetActionProgress then
		HUD.SetActionProgress(spec.label, 0)
	end
	return true
end

-- Guard flag: suppress OnSlotChanged during initial knife give
local suppressSlotChanged = false

-- ============================================================
-- LISTEN FOR EQUIPMENT CHANGES
-- ============================================================
Equipment.OnSlotChanged(function(slotName)
	if suppressSlotChanged then return end
	if slotName == "primary" or slotName == "secondary" or slotName == "melee" then
		refreshCarryHotbar()
	end
	if slotName == "hands" then
		if activeHandsAction and not ignoreHandsSlotActionCancel then
			cancelHandsAction("ACTION CANCELLED", true)
		end
		task.defer(syncHandsState)
	end
end)

-- ============================================================
-- SYNC ARMOR TO SERVER  (with durability)
-- ============================================================
local RE_SyncArmor = ReplicatedStorage:WaitForChild("ZombieRemotes"):WaitForChild("SyncArmor", 10)
local RE_ArmorDurability = ReplicatedStorage:WaitForChild("ZombieRemotes"):WaitForChild("ArmorDurability", 10)
local RE_GrenadeEffect = ReplicatedStorage:WaitForChild("GrenadeEffect", 15)

local function syncArmor()
	if RE_SyncArmor then
		RE_SyncArmor:FireServer(Equipment.GetArmorData())
	end
	HUD.UpdateArmor(Equipment.GetTotalArmor(), Equipment.GetArmorDurabilityPercent())
end

Equipment.OnSlotChanged(function(slotName, item)
	if slotName == "helmet" or slotName == "carrier" then
		syncArmor()
	end
end)

-- Listen for durability updates from server (after taking damage)
if RE_ArmorDurability then
	RE_ArmorDurability.OnClientEvent:Connect(function(durabilityData)
		Equipment.ApplyDurabilityUpdate(durabilityData)
		HUD.UpdateArmor(Equipment.GetTotalArmor(), Equipment.GetArmorDurabilityPercent())
		if RE_SyncArmor then
			RE_SyncArmor:FireServer(Equipment.GetArmorData())
		end
	end)
end

-- Listen for durability updates from server (after taking damage)
if RE_ArmorDurability then
	RE_ArmorDurability.OnClientEvent:Connect(function(durabilityData)
		Equipment.ApplyDurabilityUpdate(durabilityData)
		-- Refresh HUD
		HUD.UpdateArmor(Equipment.GetTotalArmor(), Equipment.GetArmorDurabilityPercent())
		-- Re-sync to server so it has latest state
		if RE_SyncArmor then
			RE_SyncArmor:FireServer(Equipment.GetArmorData())
		end
	end)
end

if RE_GrenadeEffect then
	RE_GrenadeEffect.OnClientEvent:Connect(function(effectType, intensity)
		if effectType == "flashbang" then
			HUD.Flashbang(intensity or 1)
			HUD.ShowNotif("FLASHED", 0.8)
		end
	end)
end

-- ============================================================
-- SPAWN WITH KNIFE
-- ============================================================
local function giveStartingKnife()
	local knifeItem = {
		id       = "combat_knife",
		name     = "Combat Knife",
		type     = "melee",
		quantity = 1,
		maxStack = 1,
		iconId   = "",
		data     = {
			damage    = 45,
			range     = 4,
			swingRate = 0.5,
			canBlock  = false,
			assetName = "CombatKnifeVM",
		},
	}
	suppressSlotChanged = true
	Equipment.ForceEquip("melee", knifeItem)
	suppressSlotChanged = false
	activateWeaponSlot("melee")
end

-- Start with empty hands â€” pick up weapons in the world.
-- Call giveStartingKnife() here instead if you want knife on spawn.
syncHandsState()
if isMobile then
	MobileHUD.Init(Movement, Weapon, Camera, Viewmodel, HUD, Inventory, Backpack, Equipment, Melee, Flashlight, character, activateWeaponSlot, useHandsItem)
end

-- Hide cursor, lock mouse
-- CHANGED: only lock mouse on PC â€” controller/mobile don't need this
if isPC then
	UIS.MouseIconEnabled = false
	UIS.MouseBehavior    = Enum.MouseBehavior.LockCenter
end

-- ============================================================
-- RESPAWN
-- ============================================================
player.CharacterAdded:Connect(function(newChar)
	cancelHandsAction(nil, true)
	character = newChar
	Movement.Init(newChar)
	Health.Init(newChar)
	Camera.SetCharacter(newChar)
	initSurvival(newChar)
	HUD.UpdateHealth(100, 100)
	lastHealthValue = 100
	HUD.UpdateHunger(100, 100)
	HUD.UpdateThirst(100, 100)
	task.wait(0.5)
	Equipment.Init()
	Inventory.Init()
	for i = 1, Inventory.GetSlotCount() do
		HUD.HotbarRefreshSlot(i, Inventory.GetSlot(i))
	end
	refreshCarryHotbar()
	Melee.Reset()
	Flashlight.Reset()
	syncHandsState()  -- restore hands-driven active item state on respawn
	if isMobile then MobileHUD.UpdateCharacter(newChar) end
end)

-- ============================================================
-- PERSISTENCE
-- ============================================================
local persistRemotes = ReplicatedStorage:WaitForChild("PersistRemotes")
local RE_DataLoaded  = persistRemotes:WaitForChild("DataLoaded")
local RE_SaveRequest = persistRemotes:WaitForChild("SaveRequest")

local function collectSaveData()
	local invSlots = {}
	for i = 1, Inventory.GetSlotCount() do
		local slot = Inventory.GetSlot(i)
		if slot then
			invSlots[i] = {
				name     = slot.name,
				type     = slot.type,
				quantity = slot.quantity,
				maxStack = slot.maxStack,
				iconId   = slot.iconId or "",
				gridX    = slot.gridX,
				gridY    = slot.gridY,
				gridW    = slot.gridW,
				gridH    = slot.gridH,
				data     = slot.data   or {},
			}
		end
	end

	local equip = {}
	for _, slotName in ipairs(Equipment.SLOTS) do
		local item = Equipment.GetSlot(slotName)
		if item then
			equip[slotName] = {
				name     = item.name,
				type     = item.type,
				quantity = item.quantity or 1,
				maxStack = item.maxStack or 1,
				iconId   = item.iconId or "",
				data     = item.data   or {},
			}
		end
	end

	return {
		health    = Health.GetHealth(),
		hunger    = Survival.GetHunger(),
		thirst    = Survival.GetThirst(),
		magAmmo   = Weapon.GetAmmo(),
		inventory = invSlots,
		equipment = equip,
	}
end

RE_DataLoaded.OnClientEvent:Connect(function(data)
	-- Health
	if data.health and data.health > 0 then
		local current = Health.GetHealth()
		local diff = data.health - current
		if diff > 0 then
			local lootRemotes = ReplicatedStorage:WaitForChild("LootRemotes")
			local healRE = lootRemotes:WaitForChild("HealPlayer")
			healRE:FireServer(diff)
		elseif diff < 0 then
			Health.TakeDamage(math.abs(diff))
		end
	end

	-- Magazine
	if data.magAmmo and data.magAmmo > 0 then
		Weapon.SetAmmo(data.magAmmo)
	end

	-- Survival
	if data.hunger then Survival.SetHunger(data.hunger) end
	if data.thirst then Survival.SetThirst(data.thirst) end

	-- Inventory
	Inventory.ClearAll()
	if data.inventory then
		for i, item in pairs(data.inventory) do
			Inventory.SetSlot(i, item)
		end
	end
	for i = 1, Inventory.GetSlotCount() do
		HUD.HotbarRefreshSlot(i, Inventory.GetSlot(i))
	end

	-- Equipment
	if data.equipment then
		for slotName, item in pairs(data.equipment) do
			Equipment.ForceEquip(slotName, item)
		end
	end
	refreshCarryHotbar()

	syncHandsState()
	print("[PlayerController] Data restored.")
end)

-- Autosave every 5 minutes
task.spawn(function()
	while true do
		task.wait(300)
		RE_SaveRequest:FireServer(collectSaveData())
		print("[PlayerController] Autosaved.")
	end
end)

-- ============================================================
-- HOTKEYS
-- ============================================================
local inventoryHotkeys = {
	[Enum.KeyCode.Four]  = 1,
	[Enum.KeyCode.Five]  = 2,
	[Enum.KeyCode.Six]   = 3,
	[Enum.KeyCode.Seven] = 4,
	[Enum.KeyCode.Eight] = 5,
	[Enum.KeyCode.Nine]  = 6,
}

-- ============================================================
-- INPUT  -- CHANGED: UIS keyboard/mouse kept as-is.
-- All new controller + mobile bindings added via CAS below.
-- ============================================================
UIS.InputBegan:Connect(function(input, gpe)
	
	if gpe then return end
	
---------Move hotbar items into equipment / hands----------
	if not Backpack.IsOpen() then
		local invSlot = inventoryHotkeys[input.KeyCode]
		if invSlot then
			local item = Inventory.GetSlot(invSlot)
			if item then
				local attachTypes = { scope = true, suppressor = true, grip = true }
				if not attachTypes[item.type] then
					local targetSlot = Equipment.GetValidSlot(item)
					if targetSlot then
						moveInventoryItemToEquipment(invSlot, targetSlot)
					end
				end
			end
		end
	end

	-- Movement
	if input.KeyCode == Enum.KeyCode.LeftShift   then Movement.Run()       end
	if input.KeyCode == Enum.KeyCode.C           then Movement.Crouch()    end
	if input.KeyCode == Enum.KeyCode.Z           then Movement.Prone()     end
	if input.KeyCode == Enum.KeyCode.LeftControl then Movement.Slide()     end
	if input.KeyCode == Enum.KeyCode.E           then Movement.LeanLeft()  end
	if input.KeyCode == Enum.KeyCode.Q           then Movement.LeanRight() end

	-- Camera
	if input.KeyCode == Enum.KeyCode.V then Camera.TogglePerson() end
	
	---Flashlight
	if input.KeyCode == Enum.KeyCode.L then
		if Flashlight.IsOn() then
			Flashlight.TurnOff()
			-- Return to previous weapon
			activateWeaponSlot(Flashlight.GetSavedSlot())
		else
			Flashlight.TurnOn()
		end
	end

	-- Weapon
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		if isHandsGun() then
			Weapon.EnterADS()
		elseif isHandsMeleeOrEmpty() then
			-- Melee / empty â€” enter OTS aim (block handled by movement check)
			Camera.EnterADS()
		end
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isHandsGun() then
			-- Gun active â€” shoot as normal
			Weapon.SetMouseHeld(true)
			local mode = Weapon.GetFireMode()
			if mode.name ~= "Auto" then
				Weapon.Shoot(Viewmodel.GetMuzzle(), function(current, max)
					local w = Weapon.GetActiveWeapon()
					HUD.UpdateAmmo(w.name, current, max)
					Viewmodel.Kick(Weapon.GetIsADS(), w.hipCF, w.adsCF, Weapon.GetRecoilKick())
					if current <= 0 then HUD.SetEmpty() end
				end)
			end
		elseif isHandsMeleeOrEmpty() then
			-- Melee slot or empty â€” punch / slash
			Melee.TryAttack()
		else
			useHandsItem()
		end
	end

	if input.KeyCode == Enum.KeyCode.R then
		if isHandsGun() then
			task.spawn(function()
				Weapon.Reload(
					function()
						HUD.SetReloading(true)
					end,
					function(current, max, noAmmo)
						local w = Weapon.GetActiveWeapon()
						HUD.SetReloading(false)
						HUD.UpdateAmmo(w.name, current, max)
						if noAmmo then
							HUD.ShowNotif("NO AMMO", 2.0)
						end
					end
				)
			end)
		end
	end

	if input.KeyCode == Enum.KeyCode.X then
		if isHandsGun() then
			local modeName = Weapon.CycleFireMode()
			local w = Weapon.GetActiveWeapon()
			HUD.UpdateFireMode(w.fireModes, Weapon.GetFireModeIndex())
			HUD.ShowNotif("[ " .. modeName .. " ]", 1.2)
		end
	end

	local weaponHotkeys = {
		[Enum.KeyCode.One] = "primary",
		[Enum.KeyCode.Two] = "secondary",
		[Enum.KeyCode.Three] = "melee",  -- optional: 3 switches to melee
	}
	local targetSlot = weaponHotkeys[input.KeyCode]
	if targetSlot then
		-- Only switch if that slot has a weapon
		if not Equipment.IsSlotEmpty(targetSlot) then
			activateWeaponSlot(targetSlot)
		end
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then Movement.Walk()     end
	if input.KeyCode == Enum.KeyCode.E         then Movement.LeanStop() end
	if input.KeyCode == Enum.KeyCode.Q         then Movement.LeanStop() end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		if isHandsGun() then
			Weapon.ExitADS()
		elseif isHandsMeleeOrEmpty() then
			Camera.ExitADS()
			Melee.StopBlock()
		end
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isHandsGun() then
			Weapon.SetMouseHeld(false)
		end
	end
end)

-- ============================================================
-- CONTROLLER BINDINGS  -- ADDED
-- Uses ContextActionService so each action responds to
-- gamepad buttons alongside existing keyboard bindings.
-- Mobile input is handled entirely by MobileHUD module.
--
-- Controller layout (Xbox / standard mapping):
--   Left Stick        = move         (handled by Roblox automatically)
--   Right Stick       = camera       (handled by Roblox automatically)
--   A                 = jump         (handled by Roblox automatically)
--   RT (R2)           = shoot
--   LT (L2)           = ADS
--   RB (R1)           = reload
--   LB (L1)           = crouch
--   Left Stick Click  = sprint
--   B                 = prone
--   Y                 = cycle fire mode
--   X                 = lean left
--   DPad Right        = lean right
--   DPad Up           = weapon slot 1
--   DPad Down         = weapon slot 2
--   DPad Left         = toggle 1st/3rd person camera
--   Start (Options)   = open/close backpack
-- ============================================================

-- â”€â”€ Sprint â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Controller: Left Stick click (L3)
CAS:BindAction("Sprint", function(_, state)
	if state == Enum.UserInputState.Begin then
		Movement.Run()
	elseif state == Enum.UserInputState.End then
		Movement.Walk()
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.ButtonL3            -- controller: click left stick
)

-- â”€â”€ Lean Left â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Controller: X button
CAS:BindAction("LeanLeft", function(_, state)
	if state == Enum.UserInputState.Begin then
		Movement.LeanLeft()
	elseif state == Enum.UserInputState.End then
		Movement.LeanStop()
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.ButtonX             -- controller: X (Xbox) / Square (PS)
)

-- â”€â”€ Lean Right â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Controller: DPad Right
CAS:BindAction("LeanRight", function(_, state)
	if state == Enum.UserInputState.Begin then
		Movement.LeanRight()
	elseif state == Enum.UserInputState.End then
		Movement.LeanStop()
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.DPadRight           -- controller: D-Pad Right
)

-- â”€â”€ Crouch â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Controller: LB (L1)
CAS:BindAction("Crouch", function(_, state)
	if state == Enum.UserInputState.Begin then
		Movement.Crouch()
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.ButtonL1            -- controller: left bumper
)

-- â”€â”€ Prone â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Controller: B button
CAS:BindAction("Prone", function(_, state)
	if state == Enum.UserInputState.Begin then
		Movement.Prone()
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.ButtonB             -- controller: B (Xbox) / Circle (PS)
)

-- â”€â”€ Slide â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Controller: no dedicated bind â€” slide is typically triggered
-- by sprinting + crouching. Wire that in MovementModule if needed.
-- Keeping this bind here as a placeholder; assign a button when ready.
-- CAS:BindAction("Slide", ...) -- uncomment and assign a KeyCode to enable

-- â”€â”€ Toggle Camera Person â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Controller: DPad Left
CAS:BindAction("TogglePerson", function(_, state)
	if state == Enum.UserInputState.Begin then
		Camera.TogglePerson()
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.DPadLeft            -- controller: D-Pad Left
)

-- â”€â”€ Weapon Slot 1 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Controller: DPad Up
CAS:BindAction("WeaponSlot1", function(_, state)
	if state == Enum.UserInputState.Begin then
		if not Equipment.IsSlotEmpty("primary") then
			activateWeaponSlot("primary")
		end
	end
end, false,
Enum.KeyCode.DPadUp
)

-- â”€â”€ Weapon Slot 2 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Controller: DPad Down
CAS:BindAction("WeaponSlot2", function(_, state)
	if state == Enum.UserInputState.Begin then
		if not Equipment.IsSlotEmpty("secondary") then
			activateWeaponSlot("secondary")
		end
	end
end, false,
Enum.KeyCode.DPadDown
)

-- â”€â”€ Reload â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Controller: RB (R1)
CAS:BindAction("Reload", function(_, state)
	if state == Enum.UserInputState.Begin then
		if not isHandsGun() then return end
		task.spawn(function()
			Weapon.Reload(
				function()
					HUD.SetReloading(true)
				end,
				function(current, max, noAmmo)
					local w = Weapon.GetActiveWeapon()
					HUD.SetReloading(false)
					HUD.UpdateAmmo(w.name, current, max)
					if noAmmo then
						HUD.ShowNotif("NO AMMO", 2.0)
					end
				end
			)
		end)
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.ButtonR1            -- controller: right bumper
)

-- â”€â”€ Cycle Fire Mode â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Controller: Y button
CAS:BindAction("CycleFireMode", function(_, state)
	if state == Enum.UserInputState.Begin then
		if not isHandsGun() then return end
		local modeName = Weapon.CycleFireMode()
		local w = Weapon.GetActiveWeapon()
		HUD.UpdateFireMode(w.fireModes, Weapon.GetFireModeIndex())
		HUD.ShowNotif("[ " .. modeName .. " ]", 1.2)
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.ButtonY             -- controller: Y (Xbox) / Triangle (PS)
)

-- â”€â”€ ADS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Controller: LT (L2)
CAS:BindAction("ADS", function(_, state)
	if state == Enum.UserInputState.Begin then
		if isHandsGun() then
			Weapon.EnterADS()
		elseif isHandsMeleeOrEmpty() then
			Camera.EnterADS()
		end
	elseif state == Enum.UserInputState.End then
		if isHandsGun() then
			Weapon.ExitADS()
		elseif isHandsMeleeOrEmpty() then
			Camera.ExitADS()
			Melee.StopBlock()
		end
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.ButtonL2            -- controller: left trigger
)

-- â”€â”€ Shoot â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Controller: RT (R2)
-- Trigger is held to fire, matching MouseButton1 behaviour
CAS:BindAction("Shoot", function(_, state)
	if state == Enum.UserInputState.Begin then
		if isHandsGun() then
			Weapon.SetMouseHeld(true)
			local mode = Weapon.GetFireMode()
			if mode.name ~= "Auto" then
				Weapon.Shoot(Viewmodel.GetMuzzle(), function(current, max)
					local w = Weapon.GetActiveWeapon()
					HUD.UpdateAmmo(w.name, current, max)
					Viewmodel.Kick(Weapon.GetIsADS(), w.hipCF, w.adsCF, Weapon.GetRecoilKick())
					if current <= 0 then HUD.SetEmpty() end
				end)
			end
		elseif isHandsMeleeOrEmpty() then
			Melee.TryAttack()
		else
			useHandsItem()
		end
	elseif state == Enum.UserInputState.End then
		if isHandsGun() then
			Weapon.SetMouseHeld(false)
		end
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.ButtonR2            -- controller: right trigger
)

-- â”€â”€ Open / Close Backpack â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Controller: Start (Options) button
CAS:BindAction("ToggleBackpack", function(_, state)
	if state == Enum.UserInputState.Begin then
		Backpack.Toggle()
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.ButtonStart         -- controller: Start (Xbox) / Options (PS)
)

-- â”€â”€ Jump â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Controller: A button handled by Roblox automatically.
-- No CAS bind needed here â€” Roblox's default jump handles it.

-- â”€â”€ Inventory Hotkeys
-- Controller: not mapped â€” use backpack UI to manage inventory.

-- ============================================================
-- HEARTBEAT
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
	HUD.Tick(dt)
	HUD.UpdateStamina(Movement.GetStamina(), 100)

	if activeHandsAction then
		local handsItem = getHandsItem()
		if not handsItem or (handsItem.id or "") ~= activeHandsAction.itemId or (handsItem.name or "") ~= activeHandsAction.itemName then
			cancelHandsAction("ACTION CANCELLED", true)
		else
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if activeHandsAction.cancelOnMove and hum and hum.MoveDirection.Magnitude > 0.08 then
				cancelHandsAction("ACTION INTERRUPTED", false)
			else
				local progress = math.clamp((tick() - activeHandsAction.startedAt) / activeHandsAction.duration, 0, 1)
				if HUD.SetActionProgress then
					HUD.SetActionProgress(activeHandsAction.label, progress)
				end
				if progress >= 1 then
					local action = activeHandsAction
					activeHandsAction = nil
					stopHandsActionPlayback(action)
					if HUD.ClearActionProgress then
						HUD.ClearActionProgress()
					end

					local liveItem = getHandsItem()
					local consumed = liveItem and action.apply and action.apply(liveItem)
					if consumed then
						ignoreHandsSlotActionCancel = true
						if (liveItem.quantity or 1) > 1 then
							Equipment.Swap("hands", {
								id = liveItem.id or "",
								name = liveItem.name,
								type = liveItem.type or "",
								quantity = (liveItem.quantity or 1) - 1,
								maxStack = liveItem.maxStack or 1,
								iconId = liveItem.iconId or "",
								data = liveItem.data or {},
							})
						else
							Equipment.Unequip("hands")
						end
						ignoreHandsSlotActionCancel = false
						task.defer(syncHandsState)
					else
						HUD.ShowNotif("ACTION FAILED", 1.2)
					end
				end
			end
		end
	end

	-- Melee block: only active when aiming (OTS) + moving backward
	local activeSlot = Weapon.GetActiveSlotName()
	local isMeleeAim = (activeSlot == "melee" or Equipment.IsSlotEmpty(activeSlot))
		and Camera.GetIsOTS()

	if isMeleeAim then
		-- Check if player is moving backward
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.MoveDirection.Magnitude > 0.1 then
			local dot = hum.MoveDirection:Dot(hrp.CFrame.LookVector)
			if dot < -0.3 then
				-- Moving backward while aiming â€” block!
				if not Melee.IsBlocking() then
					Melee.StartBlock()
				end
			else
				-- Moving forward/sideways or standing still â€” drop block
				if Melee.IsBlocking() then
					Melee.StopBlock()
				end
			end
		else
			-- Standing still while aiming â€” no block
			if Melee.IsBlocking() then
				Melee.StopBlock()
			end
		end
	else
		-- Not in melee aim â€” make sure block is off
		if Melee.IsBlocking() then
			Melee.StopBlock()
		end
	end

	Melee.UpdateBlock(dt)

	Weapon.TryAutoShoot(Viewmodel.GetMuzzle(), function(current, max)
		local w = Weapon.GetActiveWeapon()
		HUD.UpdateAmmo(w.name, current, max)
		Viewmodel.Kick(Weapon.GetIsADS(), w.hipCF, w.adsCF, Weapon.GetRecoilKick())
		if current <= 0 then HUD.SetEmpty() end
	end)
end)

print("[PlayerController] Ready")

