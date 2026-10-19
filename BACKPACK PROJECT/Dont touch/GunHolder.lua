--==================================================
-- GunHolder
-- Script ? ServerScriptService
--
-- Welds the correct world model to each player's
-- right hand. Swaps when the client fires the
-- WeaponEquipped RemoteEvent.
--
-- CHANGED FROM PREVIOUS VERSION:
--   No longer has a hardcoded WORLD_WEAPONS table.
--   The client fires WeaponEquipped with the
--   assetName string (e.g. "ARVM", "P226").
--   GunHolder looks up the visual config from
--   WeaponConfig in ReplicatedStorage and builds
--   the world model from there.
--
--   To add a new gun: add its model to GunAssets
--   and add its entry to WeaponConfig. Done.
--
--   Firing an empty string "" clears the hand
--   (used for melee / bare hands spawn).
--==================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- WeaponEquipped is created by GunHolder so both sides
-- can WaitForChild reliably.
local weaponEquippedEvent = Instance.new("RemoteEvent")
weaponEquippedEvent.Name   = "WeaponEquipped"
weaponEquippedEvent.Parent = ReplicatedStorage

local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))

-- ============================================================
-- BUILD AND ATTACH A WORLD GUN MODEL
-- assetName = "" clears the hand (bare hands / knife)
-- ============================================================
local function attachWorldGun(character, assetName)
	-- Remove ALL existing world guns first (FindFirstChild only gets one)
	for _, child in ipairs(character:GetChildren()) do
		if child.Name == "WorldGun" then child:Destroy() end
	end
	-- Also check RightHand in case it was parented there
	local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if rightHand then
		for _, child in ipairs(rightHand:GetChildren()) do
			if child.Name == "WorldGun" then child:Destroy() end
		end
	end

	-- Empty string = bare hands (melee or spawn state)
	if not assetName or assetName == "" then return end

	local config = WeaponConfig.Get(assetName)
	if not config then
		local existingOnFail = character:FindFirstChild("WorldGun")
		if existingOnFail then existingOnFail:Destroy() end
		return
	end

	local GunAssets = ReplicatedStorage:FindFirstChild("GunAssets")
	if not GunAssets then
		local existingOnFail = character:FindFirstChild("WorldGun")
		if existingOnFail then existingOnFail:Destroy() end
		return
	end

	local asset = GunAssets:FindFirstChild(assetName)
	if not asset then
		local existingOnFail = character:FindFirstChild("WorldGun")
		if existingOnFail then existingOnFail:Destroy() end
		return
	end

	local rightHand = character:FindFirstChild("RightHand")
		or character:FindFirstChild("Right Arm")
	if not rightHand then return end

	local gun = asset:Clone()
	gun.Name = "WorldGun"

	-- Disable physics on all parts before parenting
	for _, p in ipairs(gun:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored   = false
			p.CanCollide = false
			p.CastShadow = false
			p.Massless   = true
		end
	end

	-- Strip any pre-existing constraints from the asset
	for _, d in ipairs(gun:GetDescendants()) do
		if d:IsA("WeldConstraint") or d:IsA("Weld") or d:IsA("Motor6D") then
			d:Destroy()
		end
	end

	gun.Parent = rightHand
	gun:ScaleTo(config.scale)

	-- Re-apply after ScaleTo in case it reset anything
	for _, p in ipairs(gun:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored   = false
			p.CanCollide = false
			p.Massless   = true
		end
	end

	local primary = gun.PrimaryPart or gun:FindFirstChildWhichIsA("BasePart")
	if not primary then
		warn("[GunHolder] No PrimaryPart found on: " .. assetName)
		gun:Destroy()
		return
	end

	if config.partOffsets then
		-- Hardcoded offsets: park primary far away then place each
		-- part relative to it
		primary.CFrame = CFrame.new(0, -9999, 0)
		for _, p in ipairs(gun:GetDescendants()) do
			if p:IsA("BasePart") and p ~= primary then
				local offset = config.partOffsets[p.Name]
				if offset then
					p.CFrame = primary.CFrame * CFrame.new(offset * config.scale)
				else
					p.CFrame = primary.CFrame
					warn("[GunHolder] No partOffset for part '" .. p.Name .. "' on " .. assetName)
				end
			end
		end
	else
		-- No offsets needed: pivot the whole model so relative
		-- positions are preserved exactly as imported
		gun:PivotTo(CFrame.new(0, -9999, 0))
	end

	-- Weld all parts to primary
	local primaryCF = primary.CFrame
	for _, p in ipairs(gun:GetDescendants()) do
		if p:IsA("BasePart") and p ~= primary then
			local dw = Instance.new("Weld")
			dw.Part0  = primary
			dw.Part1  = p
			dw.C0     = primaryCF:ToObjectSpace(p.CFrame)
			dw.Parent = primary
		end
	end

	-- Weld primary to right hand
	local w = Instance.new("Weld")
	w.Part0  = rightHand
	w.Part1  = primary
	w.C0     = config.handC0
	w.Parent = rightHand

	print("[GunHolder] Attached " .. assetName .. " to " .. character.Name)
end

-- ============================================================
-- PER-PLAYER SETUP
-- Spawn with empty hands — player starts with only a knife
-- (stats only, no world model until a gun is picked up)
-- ============================================================
local function setupPlayer(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(1)
		-- Start with nothing in hand
		attachWorldGun(character, "")
	end)

	-- Handle character already loaded when script runs
	if player.Character then
		task.wait(1)
		attachWorldGun(player.Character, "")
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)

-- ============================================================
-- LISTEN FOR WEAPON SWAP FROM CLIENT
-- Client fires: WeaponEquipped:FireServer(assetName)
-- assetName "" = clear hand (bare hands / melee)
-- ============================================================
weaponEquippedEvent.OnServerEvent:Connect(function(player, assetName)
	local character = player.Character
	if not character then return end

	-- Sanitise: must be a string
	if type(assetName) ~= "string" then
		warn("[GunHolder] Received non-string assetName from " .. player.Name)
		return
	end

	attachWorldGun(character, assetName)
end)

print("[GunHolder] Initialized.")