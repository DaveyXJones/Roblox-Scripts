--==================================================
-- GrenadeServer
-- Script for ServerScriptService
--
-- Server-authoritative grenade spawning and detonation.
-- Creates ReplicatedStorage remotes:
--   ThrowGrenade   : client -> server
--   GrenadeEffect  : server -> client (flashbang effects)
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local ArmorManager = nil
pcall(function()
	ArmorManager = require(script.Parent:WaitForChild("ArmorManager"))
end)

local RE_ThrowGrenade = ReplicatedStorage:FindFirstChild("ThrowGrenade")
if not RE_ThrowGrenade then
	RE_ThrowGrenade = Instance.new("RemoteEvent")
	RE_ThrowGrenade.Name = "ThrowGrenade"
	RE_ThrowGrenade.Parent = ReplicatedStorage
end

local RE_GrenadeEffect = ReplicatedStorage:FindFirstChild("GrenadeEffect")
if not RE_GrenadeEffect then
	RE_GrenadeEffect = Instance.new("RemoteEvent")
	RE_GrenadeEffect.Name = "GrenadeEffect"
	RE_GrenadeEffect.Parent = ReplicatedStorage
end

local THROW_SPEED = 72
local THROW_UPWARD = 18
local PROJECTILE_LIFETIME = 20
local FIRE_TICK = 0.5

local function getCharacterRoot(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function getCharacterHumanoid(player)
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function sanitizeDirection(direction, fallback)
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.001 then
		return fallback
	end
	return direction.Unit
end

local function sanitizeGrenade(itemData)
	if type(itemData) ~= "table" then return nil end
	if tostring(itemData.type or "") ~= "grenade" then return nil end
	local data = type(itemData.data) == "table" and itemData.data or {}

	return {
		id = tostring(itemData.id or ""),
		name = tostring(itemData.name or "Grenade"),
		data = {
			fuseTime = math.clamp(tonumber(data.fuseTime) or 3, 0, 10),
			blastRadius = math.clamp(tonumber(data.blastRadius) or 10, 0, 40),
			damage = math.clamp(tonumber(data.damage) or 0, 0, 250),
			grenadeType = tostring(data.grenadeType or "frag"),
		},
	}
end

local function makeExplosionVisual(position, radius, color)
	local blast = Instance.new("Part")
	blast.Name = "GrenadeBlast"
	blast.Shape = Enum.PartType.Ball
	blast.Size = Vector3.new(1, 1, 1)
	blast.Anchored = true
	blast.CanCollide = false
	blast.Transparency = 1
	blast.CFrame = CFrame.new(position)
	blast.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = color or Color3.fromRGB(255, 185, 120)
	light.Range = radius * 3
	light.Brightness = 4
	light.Parent = blast

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Lifetime = NumberRange.new(0.25, 0.5)
	emitter.Speed = NumberRange.new(radius * 1.5, radius * 2.4)
	emitter.Rate = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-140, 140)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(255, 185, 120))
	emitter.Parent = blast
	emitter:Emit(55)

	Debris:AddItem(blast, 2)
end

local function applyRadialDamage(position, radius, damage)
	if radius <= 0 or damage <= 0 then return end

	local affectedModels = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(position, radius)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local root = model and model:FindFirstChild("HumanoidRootPart")
		if model and humanoid and root and humanoid.Health > 0 and not affectedModels[model] then
			affectedModels[model] = true
			local distance = (root.Position - position).Magnitude
			local scale = 1 - math.clamp(distance / math.max(radius, 0.01), 0, 1)
			local finalDamage = math.floor(damage * scale)
			if finalDamage > 0 then
				local targetPlayer = Players:GetPlayerFromCharacter(model)
				if targetPlayer and ArmorManager and ArmorManager.ReduceDamage then
					finalDamage = ArmorManager.ReduceDamage(targetPlayer, finalDamage)
				end
				humanoid:TakeDamage(finalDamage)
			end
		end
	end
end

local function sendFlashbang(position, radius)
	for _, player in ipairs(Players:GetPlayers()) do
		local root = getCharacterRoot(player)
		if root then
			local distance = (root.Position - position).Magnitude
			if distance <= radius then
				local intensity = 1 - math.clamp(distance / math.max(radius, 0.01), 0, 1)
				RE_GrenadeEffect:FireClient(player, "flashbang", intensity)
			end
		end
	end
end

local function createSmokeCloud(position)
	local cloud = Instance.new("Part")
	cloud.Name = "SmokeCloud"
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.Transparency = 1
	cloud.Size = Vector3.new(2, 2, 2)
	cloud.CFrame = CFrame.new(position)
	cloud.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Lifetime = NumberRange.new(4, 6)
	emitter.Speed = NumberRange.new(1.5, 3.5)
	emitter.Rate = 30
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3),
		NumberSequenceKeypoint.new(0.6, 7),
		NumberSequenceKeypoint.new(1, 9),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = cloud

	Debris:AddItem(cloud, 12)
end

local function createFireZone(position, radius, damagePerTick)
	local zone = Instance.new("Part")
	zone.Name = "MolotovFire"
	zone.Anchored = true
	zone.CanCollide = false
	zone.Transparency = 1
	zone.Size = Vector3.new(radius * 2, 1, radius * 2)
	zone.CFrame = CFrame.new(position)
	zone.Parent = workspace

	local fire = Instance.new("Fire")
	fire.Size = math.max(6, radius * 3)
	fire.Heat = 7
	fire.Color = Color3.fromRGB(255, 170, 90)
	fire.SecondaryColor = Color3.fromRGB(255, 95, 40)
	fire.Parent = zone

	task.spawn(function()
		local expireAt = tick() + 8
		while zone.Parent and tick() < expireAt do
			applyRadialDamage(zone.Position, radius, damagePerTick)
			task.wait(FIRE_TICK)
		end
	end)

	Debris:AddItem(zone, 8.5)
end

local function detonateGrenade(position, grenade)
	local grenadeType = grenade.data.grenadeType
	local radius = grenade.data.blastRadius
	local damage = grenade.data.damage

	if grenadeType == "frag" then
		makeExplosionVisual(position, radius, Color3.fromRGB(255, 185, 120))
		applyRadialDamage(position, radius, damage)
	elseif grenadeType == "smoke" then
		makeExplosionVisual(position, 5, Color3.fromRGB(190, 190, 190))
		createSmokeCloud(position)
	elseif grenadeType == "flashbang" then
		makeExplosionVisual(position, 7, Color3.fromRGB(255, 245, 220))
		sendFlashbang(position, radius > 0 and radius or 10)
	elseif grenadeType == "molotov" then
		makeExplosionVisual(position, 6, Color3.fromRGB(255, 130, 60))
		applyRadialDamage(position, radius, damage)
		createFireZone(position, radius, math.max(4, damage))
	else
		makeExplosionVisual(position, radius, Color3.fromRGB(255, 185, 120))
		applyRadialDamage(position, radius, damage)
	end
end

local function spawnGrenadeProjectile(player, grenade, direction)
	local root = getCharacterRoot(player)
	local humanoid = getCharacterHumanoid(player)
	if not root or not humanoid or humanoid.Health <= 0 then return end

	local projectile = Instance.new("Part")
	projectile.Name = grenade.name:gsub("%s+", "") .. "Projectile"
	projectile.Shape = Enum.PartType.Ball
	projectile.Size = Vector3.new(0.55, 0.55, 0.55)
	projectile.Material = Enum.Material.Metal
	projectile.Color = grenade.data.grenadeType == "smoke"
		and Color3.fromRGB(110, 110, 110)
		or (grenade.data.grenadeType == "flashbang" and Color3.fromRGB(225, 225, 215) or Color3.fromRGB(70, 78, 64))
	projectile.CFrame = CFrame.new(root.Position + Vector3.new(0, 1.6, 0) + root.CFrame.LookVector * 1.4)
	projectile.CanCollide = true
	projectile.Massless = false
	projectile.Parent = workspace

	pcall(function()
		projectile:SetNetworkOwner(nil)
	end)

	projectile.AssemblyLinearVelocity = direction * THROW_SPEED + Vector3.new(0, THROW_UPWARD, 0)
	projectile.AssemblyAngularVelocity = Vector3.new(12, 18, 7)

	local detonated = false
	local function detonate(atPosition)
		if detonated then return end
		detonated = true
		local position = atPosition or projectile.Position
		if projectile and projectile.Parent then
			projectile:Destroy()
		end
		detonateGrenade(position, grenade)
	end

	if grenade.data.grenadeType == "molotov" then
		projectile.Touched:Connect(function(hit)
			if not hit or not hit.Parent then return end
			if player.Character and hit:IsDescendantOf(player.Character) then return end
			detonate(projectile.Position)
		end)
	end

	task.delay(math.max(0.05, grenade.data.fuseTime), function()
		detonate()
	end)

	Debris:AddItem(projectile, PROJECTILE_LIFETIME)
end

RE_ThrowGrenade.OnServerEvent:Connect(function(player, itemData, direction)
	local grenade = sanitizeGrenade(itemData)
	if not grenade then return end

	local root = getCharacterRoot(player)
	if not root then return end

	local fallback = root.CFrame.LookVector
	local throwDir = sanitizeDirection(direction, fallback)
	spawnGrenadeProjectile(player, grenade, throwDir)
end)

print("[GrenadeServer] Initialized.")
