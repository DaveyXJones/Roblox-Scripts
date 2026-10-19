--==================================================
-- PlayerController (LocalScript) -- DECLARATIONS--
--==================================================
print("PlayerController running")

local UIS               = game:GetService("UserInputService")
local CAS               = game:GetService("ContextActionService") -- ADDED: for multi-platform input
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


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

Weapon.OnADSEnter(function()
	local stats = Weapon.GetAttachmentStats()
	Camera.EnterADS(stats.zoomFOV)
	if Camera.GetIsOTS() then
		-- Third person OTS — show dot reticle, no viewmodel ADS
		HUD.ShowOTSDot(true)
	else
		-- First person ADS — viewmodel and scope overlay
		Viewmodel.SetADSTarget(Weapon.GetActiveWeapon().adsCF)
		HUD.SetCrosshair(false)
		if stats.reticleId and stats.reticleId ~= "" then
			ScopeOverlay.Show(stats.reticleId, stats.reticleSize)
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
	HUD.ShowNotif("[ " .. (weapon and weapon.name or ""):upper() .. " ]", 1.0)
end)

Movement.SetCanRunCheck(function()
	return Health.CanRun()
end)

Health.OnHealthChanged(function(health, max)
	HUD.UpdateHealth(health, max)
end)

Health.OnDeath(function()
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

-- ============================================================
-- WEAPON SLOT ACTIVATION HELPER
-- Called whenever we want to make a particular equipment
-- slot the active weapon (primary / secondary / melee).
-- Tells WeaponModule, updates the viewmodel and HUD.
-- ============================================================
local function activateWeaponSlot(slotName)
	Flashlight.OnWeaponSwitch()
	Weapon.SetActiveSlot(slotName)
	-- Reset melee combo whenever the active slot changes
	Melee.Reset()
	local w = Weapon.GetActiveWeapon()

	-- Melee always shows at hip. Guns only show during ADS.
	-- Change the guns line to `true` when you want hip-fire viewmodels.
	local showAtHip = true
	Viewmodel.SetAlwaysVisible(showAtHip)

	if w and w.assetName then
		Viewmodel.Build(w)
	else
		Viewmodel.Build({ assetName = nil, hipCF = CFrame.new(), adsCF = CFrame.new(), axisFix = CFrame.new(), scale = 1 })
		-- Explicitly tell GunHolder to clear the hand
		local weaponEquipped = ReplicatedStorage:FindFirstChild("WeaponEquipped")
		if weaponEquipped then weaponEquipped:FireServer("") end
	end
	HUD.UpdateWeapon(w)
	if w and w.maxAmmo and w.maxAmmo > 0 then
		HUD.UpdateAmmo(w.name, Weapon.GetAmmo(), w.maxAmmo)
	else
		-- Melee / empty — clear the ammo display completely
		HUD.UpdateAmmo("", 0, 0)
		HUD.UpdateFireMode({}, 1)  -- clears fire mode label too
	end
	if w and w.fireModes then
		HUD.UpdateFireMode(w.fireModes, Weapon.GetFireModeIndex())
	end
end

-- Guard flag: suppress OnSlotChanged during initial knife give
local suppressSlotChanged = false

-- ============================================================
-- LISTEN FOR EQUIPMENT CHANGES
-- ============================================================
Equipment.OnSlotChanged(function(slotName, item)
	if suppressSlotChanged then return end
	local weaponSlots = { primary = true, secondary = true, melee = true }
	if not weaponSlots[slotName] then return end
	local currentSlot = Weapon.GetActiveSlotName()
	local currentItem = Equipment.GetSlot(currentSlot)
	if slotName == currentSlot then
		activateWeaponSlot(slotName)
	elseif not currentItem and item then
		activateWeaponSlot(slotName)
	end
	-- Primary/secondary cleared while active — fall back to melee
	if (slotName == "primary" or slotName == "secondary") and not item and currentSlot == slotName then
		activateWeaponSlot("melee")
	end
	-- Melee cleared while active — go to empty hands
	if slotName == "melee" and not item and currentSlot == "melee" then
		activateWeaponSlot("melee")
	end
end)

-- ============================================================
-- SYNC ARMOR TO SERVER  (with durability)
-- ============================================================
local RE_SyncArmor = ReplicatedStorage:WaitForChild("ZombieRemotes"):WaitForChild("SyncArmor", 10)
local RE_ArmorDurability = ReplicatedStorage:WaitForChild("ZombieRemotes"):WaitForChild("ArmorDurability", 10)

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

-- Start with empty hands — pick up weapons in the world.
-- Call giveStartingKnife() here instead if you want knife on spawn.
activateWeaponSlot("melee")
if isMobile then
	MobileHUD.Init(Movement, Weapon, Camera, Viewmodel, HUD, Inventory, Backpack, Equipment, Melee, character)
end

-- Hide cursor, lock mouse
-- CHANGED: only lock mouse on PC — controller/mobile don't need this
if isPC then
	UIS.MouseIconEnabled = false
	UIS.MouseBehavior    = Enum.MouseBehavior.LockCenter
end

-- ============================================================
-- RESPAWN
-- ============================================================
player.CharacterAdded:Connect(function(newChar)
	character = newChar
	Movement.Init(newChar)
	Health.Init(newChar)
	Camera.SetCharacter(newChar)
	initSurvival(newChar)
	HUD.UpdateHealth(100, 100)
	HUD.UpdateHunger(100, 100)
	HUD.UpdateThirst(100, 100)
	task.wait(0.5)
	Equipment.Init()
	Inventory.Init()
	Melee.Reset()
	Flashlight.Reset()
	activateWeaponSlot("melee")  -- empty hands on respawn
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
				data     = slot.data   or {},
			}
		end
	end

	local equip = {}
	for _, slotName in ipairs(Equipment.SLOTS) do
		local item = Equipment.GetSlot(slotName)
		if item then
			equip[slotName] = {
				name   = item.name,
				type   = item.type,
				iconId = item.iconId or "",
				data   = item.data   or {},
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

	-- Equipment
	if data.equipment then
		for slotName, item in pairs(data.equipment) do
			Equipment.ForceEquip(slotName, item)
		end
	end

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
	[Enum.KeyCode.Three] = 1,
	[Enum.KeyCode.Four]  = 2,
	[Enum.KeyCode.Five]  = 3,
	[Enum.KeyCode.Six]   = 4,
	[Enum.KeyCode.Seven] = 5,
	[Enum.KeyCode.Eight] = 6,
}

-- ============================================================
-- INPUT  -- CHANGED: UIS keyboard/mouse kept as-is.
-- All new controller + mobile bindings added via CAS below.
-- ============================================================
UIS.InputBegan:Connect(function(input, gpe)
	
	if gpe then return end
	
---------Don't Consume item Unless Needed----------
	if not Backpack.IsOpen() then
		local invSlot = inventoryHotkeys[input.KeyCode]
		if invSlot then
			local item = Inventory.GetSlot(invSlot)
			if item then
				local attachTypes = { scope = true, suppressor = true, grip = true }
				local weaponTypes = { primary = true, secondary = true, melee = true }
				if attachTypes[item.type] then
					-- Attachments: do nothing from hotbar
				elseif weaponTypes[item.type] then
					local targetSlot = Equipment.GetValidSlot(item)
					if targetSlot then
						Inventory.ClearSlot(invSlot)
						local displaced = Equipment.Swap(targetSlot, item)
						if displaced then
							Inventory.SetSlot(invSlot, {
								id       = displaced.id     or "",
								name     = displaced.name,
								type     = displaced.type   or "",
								quantity = 1,
								maxStack = 1,
								iconId   = displaced.iconId or "",
								data     = displaced.data   or {},
							})
						end
					end
				else
					Inventory.UseItem(invSlot)
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
		local activeSlot = Weapon.GetActiveSlotName()
		if activeSlot == "primary" or activeSlot == "secondary" then
			Weapon.EnterADS()
		else
			-- Melee / empty — enter OTS aim (block handled by movement check)
			Camera.EnterADS()
		end
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local activeSlot = Weapon.GetActiveSlotName()
		if activeSlot == "primary" or activeSlot == "secondary" then
			-- Gun active — shoot as normal
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
		else
			-- Melee slot or empty — punch / slash
			Melee.TryAttack()
		end
	end

	if input.KeyCode == Enum.KeyCode.R then
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

	if input.KeyCode == Enum.KeyCode.X then
		local modeName = Weapon.CycleFireMode()
		local w = Weapon.GetActiveWeapon()
		HUD.UpdateFireMode(w.fireModes, Weapon.GetFireModeIndex())
		HUD.ShowNotif("[ " .. modeName .. " ]", 1.2)
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
		local activeSlot = Weapon.GetActiveSlotName()
		if activeSlot == "primary" or activeSlot == "secondary" then
			Weapon.ExitADS()
		else
			Camera.ExitADS()
			Melee.StopBlock()
		end
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Weapon.SetMouseHeld(false)
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

-- ── Sprint ──────────────────────────────────────────────────
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

-- ── Lean Left ────────────────────────────────────────────────
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

-- ── Lean Right ───────────────────────────────────────────────
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

-- ── Crouch ──────────────────────────────────────────────────
-- Controller: LB (L1)
CAS:BindAction("Crouch", function(_, state)
	if state == Enum.UserInputState.Begin then
		Movement.Crouch()
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.ButtonL1            -- controller: left bumper
)

-- ── Prone ────────────────────────────────────────────────────
-- Controller: B button
CAS:BindAction("Prone", function(_, state)
	if state == Enum.UserInputState.Begin then
		Movement.Prone()
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.ButtonB             -- controller: B (Xbox) / Circle (PS)
)

-- ── Slide ────────────────────────────────────────────────────
-- Controller: no dedicated bind — slide is typically triggered
-- by sprinting + crouching. Wire that in MovementModule if needed.
-- Keeping this bind here as a placeholder; assign a button when ready.
-- CAS:BindAction("Slide", ...) -- uncomment and assign a KeyCode to enable

-- ── Toggle Camera Person ─────────────────────────────────────
-- Controller: DPad Left
CAS:BindAction("TogglePerson", function(_, state)
	if state == Enum.UserInputState.Begin then
		Camera.TogglePerson()
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.DPadLeft            -- controller: D-Pad Left
)

-- ── Weapon Slot 1 ────────────────────────────────────────────
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

-- ── Weapon Slot 2 ────────────────────────────────────────────
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

-- ── Reload ───────────────────────────────────────────────────
-- Controller: RB (R1)
CAS:BindAction("Reload", function(_, state)
	if state == Enum.UserInputState.Begin then
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

-- ── Cycle Fire Mode ──────────────────────────────────────────
-- Controller: Y button
CAS:BindAction("CycleFireMode", function(_, state)
	if state == Enum.UserInputState.Begin then
		local modeName = Weapon.CycleFireMode()
		local w = Weapon.GetActiveWeapon()
		HUD.UpdateFireMode(w.fireModes, Weapon.GetFireModeIndex())
		HUD.ShowNotif("[ " .. modeName .. " ]", 1.2)
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.ButtonY             -- controller: Y (Xbox) / Triangle (PS)
)

-- ── ADS ──────────────────────────────────────────────────────
-- Controller: LT (L2)
CAS:BindAction("ADS", function(_, state)
	if state == Enum.UserInputState.Begin then
		Weapon.EnterADS()
	elseif state == Enum.UserInputState.End then
		Weapon.ExitADS()
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.ButtonL2            -- controller: left trigger
)

-- ── Shoot ────────────────────────────────────────────────────
-- Controller: RT (R2)
-- Trigger is held to fire, matching MouseButton1 behaviour
CAS:BindAction("Shoot", function(_, state)
	if state == Enum.UserInputState.Begin then
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
	elseif state == Enum.UserInputState.End then
		Weapon.SetMouseHeld(false)
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.ButtonR2            -- controller: right trigger
)

-- ── Open / Close Backpack ────────────────────────────────────
-- Controller: Start (Options) button
CAS:BindAction("ToggleBackpack", function(_, state)
	if state == Enum.UserInputState.Begin then
		Backpack.Toggle()
	end
end, false,                          -- false = no mobile button
Enum.KeyCode.ButtonStart         -- controller: Start (Xbox) / Options (PS)
)

-- ── Jump ─────────────────────────────────────────────────────
-- Controller: A button handled by Roblox automatically.
-- No CAS bind needed here — Roblox's default jump handles it.

-- ── Inventory Hotkeys
-- Controller: not mapped — use backpack UI to manage inventory.

-- ============================================================
-- HEARTBEAT
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
	HUD.Tick(dt)
	HUD.UpdateStamina(Movement.GetStamina(), 100)

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
				-- Moving backward while aiming — block!
				if not Melee.IsBlocking() then
					Melee.StartBlock()
				end
			else
				-- Moving forward/sideways or standing still — drop block
				if Melee.IsBlocking() then
					Melee.StopBlock()
				end
			end
		else
			-- Standing still while aiming — no block
			if Melee.IsBlocking() then
				Melee.StopBlock()
			end
		end
	else
		-- Not in melee aim — make sure block is off
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