--==================================================
-- LootServer
-- Script -> ServerScriptService
--
-- Owns all loot state on the server.
-- Ground loot remains instant pickup.
-- Container loot now behaves like a searchable prop:
--   - the prop stays in the world
--   - players must search it before contents appear in vicinity
--   - contents respawn inside the same prop later
--==================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LootTable = require(ReplicatedStorage:WaitForChild("LootTableModule"))
local SpawnData = require(ReplicatedStorage:WaitForChild("LootSpawnData"))

-- ============================================================
-- REMOTES
-- ============================================================
local remotes = ReplicatedStorage:FindFirstChild("LootRemotes")
if not remotes or not remotes:IsA("Folder") then
	if remotes then remotes:Destroy() end
	remotes = Instance.new("Folder")
	remotes.Name = "LootRemotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemote(className, name)
	local existing = remotes:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local RE_RequestPickup = ensureRemote("RemoteEvent", "RequestPickup")
local RE_LootSpawned = ensureRemote("RemoteEvent", "LootSpawned")
local RE_LootRemoved = ensureRemote("RemoteEvent", "LootRemoved")
local RE_PickupResult = ensureRemote("RemoteEvent", "PickupResult")
local RE_PickupAck = ensureRemote("RemoteEvent", "PickupAck")
local RE_HealPlayer = ensureRemote("RemoteEvent", "HealPlayer")
local RE_DropItem = ensureRemote("RemoteEvent", "DropItem")
local RE_LootFeedback = ensureRemote("RemoteEvent", "LootFeedback")

local RF_GetVicinityLoot = ensureRemote("RemoteFunction", "GetVicinityLoot")
local RF_TakeVicinityLoot = ensureRemote("RemoteFunction", "TakeVicinityLoot")

RE_RequestPickup.OnServerEvent:Connect(function() end)

-- ============================================================
-- CONFIG
-- ============================================================
local DROP_BAG_LIFETIME = 120
local DROP_BAG_PROMPT_DIST = 6
local DROP_BAG_SIZE = Vector3.new(0.8, 0.6, 0.8)
local DROP_BAG_COLOR = BrickColor.new("Khaki")
local DROP_BAG_MATERIAL = Enum.Material.Fabric
local VICINITY_RADIUS = 14
local PROMPT_DISTANCE = 8
local RESPAWN_CHECK_INTERVAL = 5
local DEFAULT_CONTAINER_NAME = "Container"

local ASSET_FOLDER_NAMES = LootTable.LOOT_ASSET_FOLDERS or { "LootWorldAssets", "LootAssets" }

-- ============================================================
-- STATE
-- ============================================================
local dropCounter = 0
local dropBags = {}
local spawnState = {}
local despawnLoot

-- ============================================================
-- HELPERS
-- ============================================================
local function deepCopy(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

local function sanitizeClientItem(item)
	if type(item) ~= "table" then return nil end
	if type(item.name) ~= "string" or item.name == "" then return nil end
	return {
		id = item.id,
		name = tostring(item.name):sub(1, 50),
		type = tostring(item.type or "Misc"):sub(1, 20),
		quantity = math.clamp(tonumber(item.quantity) or 1, 1, 999),
		maxStack = math.clamp(tonumber(item.maxStack) or 1, 1, 999),
		iconId = type(item.iconId) == "string" and item.iconId or "",
		data = type(item.data) == "table" and deepCopy(item.data) or {},
	}
end

local function getPlayerRoot(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function isSourceNearPlayer(player, part)
	local hrp = getPlayerRoot(player)
	if not hrp or not part then return false end
	return (part.Position - hrp.Position).Magnitude <= VICINITY_RADIUS
end

local function makeVicinityEntry(sourceId, sourceType, label, part, items)
	if not part or not items or #items == 0 then return nil end
	local entryItems = {}
	for _, item in ipairs(items) do
		local safe = sanitizeClientItem(item)
		if safe then
			table.insert(entryItems, safe)
		end
	end
	if #entryItems == 0 then return nil end
	return {
		sourceId = sourceId,
		sourceType = sourceType,
		label = label,
		position = part.Position,
		items = entryItems,
	}
end

local function normalizeSoundId(soundId)
	if type(soundId) ~= "string" then return "" end
	if soundId == "" or soundId == "rbxassetid://0" then return "" end
	return soundId
end

local function fireLootFeedback(player, kind, payload)
	RE_LootFeedback:FireClient(player, kind, payload or {})
end

local function getContainerMeta(spawn)
	if LootTable.GetContainerStyle then
		return LootTable.GetContainerStyle(spawn)
	end
	return {
		label = spawn and spawn.label or DEFAULT_CONTAINER_NAME,
		objectText = DEFAULT_CONTAINER_NAME,
		assetName = "",
		fallbackStyle = "crate",
		searchDuration = LootTable.DEFAULT_CONTAINER_SEARCH_TIME or 1.65,
		searchSoundId = LootTable.DEFAULT_SEARCH_SOUND_ID or "",
		searchSoundVolume = 0.8,
		respawnTime = tonumber(spawn and spawn.respawnTime) or LootTable.RESPAWN_TIME,
	}
end

local function getWorldVisual(item, spawn)
	if LootTable.GetWorldVisual then
		return LootTable.GetWorldVisual(item, spawn)
	end
	return {
		assetName = item and item.name or "",
		fallbackStyle = "small_item",
		displayLabel = item and item.name or "Loot",
		pickupSoundId = "",
		pickupSoundVolume = 0.76,
	}
end

local function findLootAsset(assetName)
	if type(assetName) ~= "string" or assetName == "" then return nil end
	for _, folderName in ipairs(ASSET_FOLDER_NAMES) do
		local root = ReplicatedStorage:FindFirstChild(folderName)
		if root then
			local found = root:FindFirstChild(assetName, true)
			if found and (found:IsA("Model") or found:IsA("BasePart")) then
				return found
			end
		end
	end
	local found = ReplicatedStorage:FindFirstChild(assetName, true)
	if found and (found:IsA("Model") or found:IsA("BasePart")) then
		return found
	end
	return nil
end

local function findBasePart(instance)
	if not instance then return nil end
	if instance:IsA("BasePart") then return instance end
	if instance:IsA("Model") then
		if instance.PrimaryPart then return instance.PrimaryPart end
		for _, descendant in ipairs(instance:GetDescendants()) do
			if descendant:IsA("BasePart") then
				return descendant
			end
		end
	end
	return nil
end

local function setWorldInstancePose(instance, position, canCollide)
	if not instance then return nil end
	if instance:IsA("Model") then
		instance:PivotTo(CFrame.new(position))
		for _, descendant in ipairs(instance:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = canCollide
			end
		end
	elseif instance:IsA("BasePart") then
		instance.CFrame = CFrame.new(position)
		instance.Anchored = true
		instance.CanCollide = canCollide
	end
	return findBasePart(instance)
end

local function addPromptTag(parent, name, value)
	local tag = Instance.new("StringValue")
	tag.Name = name
	tag.Value = value
	tag.Parent = parent
end

local function addFloatingLabel(part, text, quantity)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 150, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 0.95, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 25
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text or "Loot"
	label.TextColor3 = Color3.fromRGB(220, 210, 170)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard

	if (quantity or 1) > 1 then
		local qtyLabel = Instance.new("TextLabel")
		qtyLabel.Size = UDim2.new(1, 0, 0.5, 0)
		qtyLabel.Position = UDim2.new(0, 0, 1, 0)
		qtyLabel.BackgroundTransparency = 1
		qtyLabel.Text = "x" .. tostring(quantity)
		qtyLabel.TextColor3 = Color3.fromRGB(180, 175, 150)
		qtyLabel.TextStrokeTransparency = 0.5
		qtyLabel.Font = Enum.Font.Gotham
		qtyLabel.TextScaled = true
		qtyLabel.Parent = billboard
	end
end

local function buildFallbackGround(position, visual)
	local part = Instance.new("Part")
	part.Name = "LootPickup"
	part.Anchored = true
	part.CanCollide = false

	local style = visual and visual.fallbackStyle or "small_item"
	if style == "long_weapon" then
		part.Size = Vector3.new(2.6, 0.18, 0.35)
		part.Color = Color3.fromRGB(62, 68, 72)
		part.Material = Enum.Material.Metal
		part.CFrame = CFrame.new(position + Vector3.new(0, 0.12, 0))
	elseif style == "sidearm" then
		part.Size = Vector3.new(1.2, 0.2, 0.45)
		part.Color = Color3.fromRGB(48, 52, 57)
		part.Material = Enum.Material.Metal
		part.CFrame = CFrame.new(position + Vector3.new(0, 0.12, 0))
	elseif style == "bottle_item" then
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.35, 0.85, 0.35)
		part.Color = Color3.fromRGB(98, 131, 144)
		part.Material = Enum.Material.Glass
		part.CFrame = CFrame.new(position + Vector3.new(0, 0.42, 0)) * CFrame.Angles(0, 0, math.rad(90))
	elseif style == "can_item" then
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.42, 0.48, 0.42)
		part.Color = Color3.fromRGB(121, 130, 101)
		part.Material = Enum.Material.Metal
		part.CFrame = CFrame.new(position + Vector3.new(0, 0.24, 0)) * CFrame.Angles(0, 0, math.rad(90))
	elseif style == "grenade" then
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(0.45, 0.45, 0.45)
		part.Color = Color3.fromRGB(74, 89, 72)
		part.Material = Enum.Material.Metal
		part.CFrame = CFrame.new(position + Vector3.new(0, 0.22, 0))
	elseif style == "gear_item" or style == "clothing_item" then
		part.Size = Vector3.new(0.95, 0.25, 0.75)
		part.Color = Color3.fromRGB(58, 68, 58)
		part.Material = Enum.Material.Fabric
		part.CFrame = CFrame.new(position + Vector3.new(0, 0.14, 0))
	else
		part.Size = Vector3.new(0.6, 0.22, 0.5)
		part.Color = Color3.fromRGB(168, 147, 92)
		part.Material = Enum.Material.SmoothPlastic
		part.CFrame = CFrame.new(position + Vector3.new(0, 0.11, 0))
	end

	part.Parent = workspace
	return part, part
end

local function buildFallbackContainer(position, containerMeta)
	local part = Instance.new("Part")
	part.Name = "LootContainer"
	part.Anchored = true
	part.CanCollide = true

	local style = containerMeta and containerMeta.fallbackStyle or "crate"
	if style == "weapon_case" then
		part.Size = Vector3.new(2.5, 0.55, 1.05)
		part.Color = Color3.fromRGB(34, 40, 48)
		part.Material = Enum.Material.Metal
		part.CFrame = CFrame.new(position + Vector3.new(0, 0.28, 0))
	elseif style == "duffel_bag" then
		part.Size = Vector3.new(2.0, 0.8, 1.0)
		part.Color = Color3.fromRGB(44, 50, 46)
		part.Material = Enum.Material.Fabric
		part.CFrame = CFrame.new(position + Vector3.new(0, 0.4, 0))
	elseif style == "box_pile" then
		part.Size = Vector3.new(2.0, 1.0, 1.3)
		part.Color = Color3.fromRGB(123, 96, 66)
		part.Material = Enum.Material.Wood
		part.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0))
	else
		part.Size = Vector3.new(2.1, 1.25, 1.25)
		part.Color = Color3.fromRGB(112, 80, 52)
		part.Material = Enum.Material.Wood
		part.CFrame = CFrame.new(position + Vector3.new(0, 0.62, 0))
	end

	part.Parent = workspace
	return part, part
end

local function buildGroundWorldObject(spawn, item)
	local visual = getWorldVisual(item, spawn)
	local asset = findLootAsset(visual.assetName)
	local instance, promptPart
	if asset then
		instance = asset:Clone()
		instance.Parent = workspace
		promptPart = setWorldInstancePose(instance, spawn.pos, false)
	end
	if not instance or not promptPart then
		instance, promptPart = buildFallbackGround(spawn.pos, visual)
	end
	addFloatingLabel(promptPart, visual.displayLabel or item.name or "Loot", item and item.quantity or 1)
	return instance, promptPart, visual
end

local function buildContainerWorldObject(spawn, containerMeta)
	local asset = findLootAsset(containerMeta.assetName)
	local instance, promptPart
	if asset then
		instance = asset:Clone()
		instance.Parent = workspace
		promptPart = setWorldInstancePose(instance, spawn.pos, true)
	end
	if not instance or not promptPart then
		instance, promptPart = buildFallbackContainer(spawn.pos, containerMeta)
	end
	return instance, promptPart
end

local function getSpawnRespawnTime(spawn, state)
	if state and state.containerMeta and tonumber(state.containerMeta.respawnTime) then
		return tonumber(state.containerMeta.respawnTime)
	end
	return tonumber(spawn and spawn.respawnTime) or LootTable.RESPAWN_TIME
end

local function clearContainerViewers(state)
	state.openUsers = {}
end

local function playerHasContainerAccess(state, player)
	return state and state.openUsers and state.openUsers[player.UserId] and isSourceNearPlayer(player, state.part)
end

local function grantContainerAccess(state, player)
	state.openUsers = state.openUsers or {}
	state.openUsers[player.UserId] = true
end

local function updatePromptText(state)
	if not state or not state.prompt then return end
	if state.spawnType == "chest" then
		local meta = state.containerMeta or {}
		state.prompt.ActionText = "Search"
		state.prompt.ObjectText = (meta.objectText or DEFAULT_CONTAINER_NAME) .. (((state.rolledItems and #state.rolledItems > 0) and "") or " (Empty)")
		state.prompt.HoldDuration = tonumber(meta.searchDuration) or (LootTable.DEFAULT_CONTAINER_SEARCH_TIME or 1.65)
	else
		local label = (state.worldVisual and state.worldVisual.displayLabel) or (state.rolledItems and state.rolledItems[1] and state.rolledItems[1].name) or "Loot"
		state.prompt.ActionText = "Take"
		state.prompt.ObjectText = label
		state.prompt.HoldDuration = 0
	end
end

local function resolvePickupFeedback(item, state)
	local visual = state and state.worldVisual or getWorldVisual(item, state and state.spawnDef)
	return {
		itemName = item and item.name or "Loot",
		showText = true,
		soundId = normalizeSoundId((item and item.pickupSoundId) or (item and item.data and item.data.pickupSoundId) or visual.pickupSoundId),
		soundVolume = tonumber((item and item.pickupSoundVolume) or (item and item.data and item.data.pickupSoundVolume) or visual.pickupSoundVolume) or 0.76,
	}
end

local function markContainerEmpty(spawnId)
	local state = spawnState[spawnId]
	if not state or state.spawnType ~= "chest" then return end
	state.rolledItems = {}
	state.respawnAt = tick() + getSpawnRespawnTime(state.spawnDef, state)
	state.active = true
	clearContainerViewers(state)
	updatePromptText(state)
end

-- ============================================================
-- HEAL
-- ============================================================
RE_HealPlayer.OnServerEvent:Connect(function(player, amount)
	amount = math.clamp(amount, 0, 100)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
end)

-- ============================================================
-- DROP ITEM
-- ============================================================
RE_DropItem.OnServerEvent:Connect(function(player, itemData)
	if type(itemData) ~= "table" then return end
	if type(itemData.name) ~= "string" or itemData.name == "" then return end

	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local cleanItem = {
		name = tostring(itemData.name):sub(1, 50),
		type = tostring(itemData.type or "Misc"):sub(1, 20),
		quantity = math.clamp(tonumber(itemData.quantity) or 1, 1, 999),
		maxStack = math.clamp(tonumber(itemData.maxStack) or 1, 1, 999),
		iconId = type(itemData.iconId) == "string" and itemData.iconId or "",
		data = type(itemData.data) == "table" and deepCopy(itemData.data) or {},
	}

	local lookDir = hrp.CFrame.LookVector
	local flatDir = Vector3.new(lookDir.X, 0, lookDir.Z)
	if flatDir.Magnitude <= 0.01 then
		flatDir = Vector3.new(0, 0, -1)
	else
		flatDir = flatDir.Unit
	end
	local dropPos = hrp.Position + flatDir * 3

	dropCounter += 1
	local dropId = "drop_" .. player.UserId .. "_" .. dropCounter

	local part = Instance.new("Part")
	part.Name = "DroppedItem"
	part.Size = DROP_BAG_SIZE
	part.BrickColor = DROP_BAG_COLOR
	part.Material = DROP_BAG_MATERIAL
	part.CFrame = CFrame.new(dropPos + Vector3.new(0, DROP_BAG_SIZE.Y / 2 + 0.1, 0))
	part.Anchored = true
	part.CanCollide = true
	part.Parent = workspace

	addPromptTag(part, "DropId", dropId)
	addFloatingLabel(part, cleanItem.name, cleanItem.quantity)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take"
	prompt.ObjectText = cleanItem.name
	prompt.MaxActivationDistance = DROP_BAG_PROMPT_DIST
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = part

	dropBags[dropId] = {
		items = { cleanItem },
		part = part,
	}

	prompt.Triggered:Connect(function(picker)
		local bag = dropBags[dropId]
		if not bag then return end
		RE_PickupResult:FireClient(picker, true, dropId, bag.items)
		dropBags[dropId] = nil
		part:Destroy()
	end)

	task.delay(DROP_BAG_LIFETIME, function()
		if dropBags[dropId] then
			dropBags[dropId] = nil
			if part and part.Parent then
				part:Destroy()
			end
		end
	end)
end)

-- ============================================================
-- VICINITY
-- ============================================================
RF_GetVicinityLoot.OnServerInvoke = function(player)
	local root = getPlayerRoot(player)
	if not root then return {} end

	local entries = {}

	for dropId, bag in pairs(dropBags) do
		if bag.part and isSourceNearPlayer(player, bag.part) then
			local entry = makeVicinityEntry(dropId, "drop", bag.items[1] and bag.items[1].name or "Dropped Item", bag.part, bag.items)
			if entry then
				entry.distance = (bag.part.Position - root.Position).Magnitude
				table.insert(entries, entry)
			end
		end
	end

	for spawnId, state in pairs(spawnState) do
		if state.active and state.part and state.rolledItems and #state.rolledItems > 0 and isSourceNearPlayer(player, state.part) then
			local canSee = state.spawnType ~= "chest" or playerHasContainerAccess(state, player)
			if canSee then
				local label = state.spawnType == "chest"
					and ((state.containerMeta and state.containerMeta.label) or state.label or DEFAULT_CONTAINER_NAME)
					or ((state.worldVisual and state.worldVisual.displayLabel) or "Ground Loot")
				local entry = makeVicinityEntry(spawnId, state.spawnType or "ground", label, state.part, state.rolledItems)
				if entry then
					entry.distance = (state.part.Position - root.Position).Magnitude
					table.insert(entries, entry)
				end
			end
		end
	end

	table.sort(entries, function(a, b)
		return (a.distance or math.huge) < (b.distance or math.huge)
	end)

	return entries
end

RF_TakeVicinityLoot.OnServerInvoke = function(player, sourceId, itemIndex)
	itemIndex = tonumber(itemIndex) or 1

	local bag = dropBags[sourceId]
	if bag then
		if not bag.part or not isSourceNearPlayer(player, bag.part) then
			return false, "Too far away"
		end
		local item = bag.items[itemIndex]
		if not item then
			return false, "Missing item"
		end

		table.remove(bag.items, itemIndex)
		if #bag.items <= 0 then
			dropBags[sourceId] = nil
			if bag.part and bag.part.Parent then
				bag.part:Destroy()
			end
		end

		fireLootFeedback(player, "item_picked", resolvePickupFeedback(item))
		return true, sanitizeClientItem(item)
	end

	local state = spawnState[sourceId]
	if not state or not state.active or not state.part then
		return false, "Source unavailable"
	end
	if not isSourceNearPlayer(player, state.part) then
		return false, "Too far away"
	end
	if state.spawnType == "chest" and not playerHasContainerAccess(state, player) then
		return false, "Search the container first"
	end

	local item = state.rolledItems and state.rolledItems[itemIndex]
	if not item then
		return false, "Missing item"
	end

	table.remove(state.rolledItems, itemIndex)
	fireLootFeedback(player, "item_picked", resolvePickupFeedback(item, state))

	if #state.rolledItems <= 0 then
		if state.spawnType == "chest" then
			markContainerEmpty(sourceId)
		else
			despawnLoot(sourceId)
		end
	else
		updatePromptText(state)
	end

	return true, sanitizeClientItem(item)
end

-- ============================================================
-- DESPAWN
-- ============================================================
despawnLoot = function(spawnId)
	local state = spawnState[spawnId]
	if not state or not state.active then return end

	if state.instance and state.instance.Parent then
		state.instance:Destroy()
	elseif state.part and state.part.Parent then
		state.part:Destroy()
	end

	state.instance = nil
	state.part = nil
	state.prompt = nil
	state.active = false
	state.rolledItems = nil
	state.respawnAt = tick() + getSpawnRespawnTime(state.spawnDef, state)
	state.worldVisual = nil
	clearContainerViewers(state)

	RE_LootRemoved:FireAllClients(spawnId)
end

-- ============================================================
-- PROMPTS
-- ============================================================
local function attachPrompt(promptPart, spawnId, spawnType)
	local prompt = Instance.new("ProximityPrompt")
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = promptPart

	local state = spawnState[spawnId]
	if state then
		state.prompt = prompt
		updatePromptText(state)
	end

	prompt.Triggered:Connect(function(player)
		local liveState = spawnState[spawnId]
		if not liveState or not liveState.active or not liveState.part then
			RE_PickupResult:FireClient(player, false, spawnId, nil)
			return
		end

		if spawnType == "chest" then
			if not isSourceNearPlayer(player, liveState.part) then return end
			if not liveState.rolledItems or #liveState.rolledItems == 0 then
				fireLootFeedback(player, "container_empty", {
					label = (liveState.containerMeta and liveState.containerMeta.label) or liveState.label or DEFAULT_CONTAINER_NAME,
					soundId = normalizeSoundId(liveState.containerMeta and liveState.containerMeta.searchSoundId),
					soundVolume = tonumber(liveState.containerMeta and liveState.containerMeta.searchSoundVolume) or 0.8,
					text = "Nothing useful.",
				})
				return
			end
			grantContainerAccess(liveState, player)
			fireLootFeedback(player, "container_opened", {
				label = (liveState.containerMeta and liveState.containerMeta.label) or liveState.label or DEFAULT_CONTAINER_NAME,
				soundId = normalizeSoundId(liveState.containerMeta and liveState.containerMeta.searchSoundId),
				soundVolume = tonumber(liveState.containerMeta and liveState.containerMeta.searchSoundVolume) or 0.8,
				text = "Searched " .. string.lower((liveState.containerMeta and liveState.containerMeta.label) or DEFAULT_CONTAINER_NAME),
			})
			return
		end

		local items = liveState.rolledItems or {}
		local ackCount = 0
		local ackDone = false
		local conn

		conn = RE_PickupAck.OnServerEvent:Connect(function(ackPlayer, ackSpawnId, accepted)
			if ackPlayer ~= player or ackSpawnId ~= spawnId then return end
			if conn then
				conn:Disconnect()
				conn = nil
			end
			ackCount = accepted or 0
			ackDone = true
		end)

		RE_PickupResult:FireClient(player, true, spawnId, items)

		local elapsed = 0
		repeat
			task.wait(0.05)
			elapsed += 0.05
		until ackDone or elapsed >= 3

		if conn then conn:Disconnect() end

		if ackCount > 0 and items[1] then
			local feedback = resolvePickupFeedback(items[1], liveState)
			feedback.showText = false
			fireLootFeedback(player, "item_picked", feedback)
			despawnLoot(spawnId)
		end
	end)

	return prompt
end

-- ============================================================
-- ROLL ITEMS
-- ============================================================
local function rollItems(spawn)
	local items = {}

	if spawn.type == "ground" then
		local item = LootTable.Roll(spawn.tier, spawn.context)
		if item then table.insert(items, item) end
	elseif spawn.type == "chest" then
		local countRange = LootTable.CHEST_COUNT[spawn.tier]
		local minCount = countRange and countRange.min or 1
		local maxCount = countRange and countRange.max or minCount
		local count = math.random(minCount, maxCount)
		for _ = 1, count do
			local item = LootTable.Roll(spawn.tier, spawn.context)
			if item then table.insert(items, item) end
		end
	end

	return items
end

-- ============================================================
-- SPAWN POINT
-- ============================================================
local function spawnLoot(spawn)
	local state = spawnState[spawn.id]
	if not state then return end
	if state.active and state.part then return end

	local items = rollItems(spawn)
	local instance, promptPart

	if spawn.type == "ground" then
		local firstItem = items[1]
		if not firstItem then
			state.active = false
			state.respawnAt = tick() + getSpawnRespawnTime(spawn, state)
			return
		end
		instance, promptPart, state.worldVisual = buildGroundWorldObject(spawn, firstItem)
	else
		state.containerMeta = state.containerMeta or getContainerMeta(spawn)
		instance, promptPart = buildContainerWorldObject(spawn, state.containerMeta)
	end

	if not promptPart then
		if instance and instance.Parent then instance:Destroy() end
		state.active = false
		state.respawnAt = tick() + getSpawnRespawnTime(spawn, state)
		return
	end

	state.instance = instance
	state.part = promptPart
	state.prompt = nil
	state.rolledItems = items
	state.respawnAt = (#items == 0 and spawn.type == "chest") and (tick() + getSpawnRespawnTime(spawn, state)) or nil
	state.active = true
	state.spawnType = spawn.type
	state.label = spawn.label
	state.spawnDef = spawn
	clearContainerViewers(state)

	addPromptTag(promptPart, "SpawnId", spawn.id)
	attachPrompt(promptPart, spawn.id, spawn.type)
	RE_LootSpawned:FireAllClients(spawn.id, promptPart.Position, spawn.type)
end

-- ============================================================
-- RESPAWN LOOP
-- ============================================================
local lastCheck = 0
RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastCheck < RESPAWN_CHECK_INTERVAL then return end
	lastCheck = now

	for _, spawn in ipairs(SpawnData.SPAWNS) do
		local state = spawnState[spawn.id]
		if state then
			if spawn.type == "chest" then
				if state.active and state.part and state.respawnAt and now >= state.respawnAt then
					state.rolledItems = rollItems(spawn)
					state.respawnAt = (#state.rolledItems == 0) and (tick() + getSpawnRespawnTime(spawn, state)) or nil
					clearContainerViewers(state)
					updatePromptText(state)
				elseif not state.active and state.respawnAt and now >= state.respawnAt then
					spawnLoot(spawn)
				end
			elseif not state.active and state.respawnAt and now >= state.respawnAt then
				spawnLoot(spawn)
			end
		end
	end
end)

-- ============================================================
-- INIT
-- ============================================================
for _, spawn in ipairs(SpawnData.SPAWNS) do
	spawnState[spawn.id] = {
		instance = nil,
		part = nil,
		prompt = nil,
		rolledItems = nil,
		respawnAt = nil,
		active = false,
		spawnType = spawn.type,
		label = spawn.label,
		spawnDef = spawn,
		openUsers = {},
		containerMeta = spawn.type == "chest" and getContainerMeta(spawn) or nil,
		worldVisual = nil,
	}
	task.delay(0.05, function()
		spawnLoot(spawn)
	end)
end

print("[LootServer] Initialized. " .. #SpawnData.SPAWNS .. " spawn points registered.")
