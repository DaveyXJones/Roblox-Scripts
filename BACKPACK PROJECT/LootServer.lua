--==================================================
-- LootServer
-- Script ? ServerScriptService
--
-- Owns all loot state on the server.
-- Spawns world parts/chests, manages respawn timers,
-- handles pickup RemoteEvents from clients.
--==================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local LootTable  = require(ReplicatedStorage:WaitForChild("LootTableModule"))
local SpawnData  = require(ReplicatedStorage:WaitForChild("LootSpawnData"))

-- ============================================================
-- REMOTE EVENTS
-- Create them here so LootClient can WaitForChild reliably.
-- ============================================================
local remotes = Instance.new("Folder")
remotes.Name   = "LootRemotes"
remotes.Parent = ReplicatedStorage

local RE_RequestPickup  = Instance.new("RemoteEvent", remotes)
RE_RequestPickup.Name   = "RequestPickup"    -- client ? server: "I want to pick up spawnId"

local RE_LootSpawned    = Instance.new("RemoteEvent", remotes)
RE_LootSpawned.Name     = "LootSpawned"      -- server ? client: spawn appeared

local RE_LootRemoved    = Instance.new("RemoteEvent", remotes)
RE_LootRemoved.Name     = "LootRemoved"      -- server ? client: spawn despawned

local RE_PickupResult   = Instance.new("RemoteEvent", remotes)
RE_PickupResult.Name    = "PickupResult"     -- server ? client: pickup granted/denied + item data

local RE_PickupAck      = Instance.new("RemoteEvent", remotes)
RE_PickupAck.Name       = "PickupAck"        -- client ? server: how many items were accepted

local RE_HealPlayer = Instance.new("RemoteEvent", remotes)
RE_HealPlayer.Name  = "HealPlayer"

RE_HealPlayer.OnServerEvent:Connect(function(player, amount)
	-- Sanity check: clamp to reasonable range, never trust raw client values
	amount = math.clamp(amount, 0, 100)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
end)
-- ============================================================
-- DROP ITEM  (player drops an item into the world)
-- ============================================================
local RE_DropItem = Instance.new("RemoteEvent", remotes)
RE_DropItem.Name  = "DropItem"

-- Config for dropped item bags
local DROP_BAG_LIFETIME   = 120    -- seconds before it despawns
local DROP_BAG_PROMPT_DIST = 6
local DROP_BAG_SIZE       = Vector3.new(0.8, 0.6, 0.8)
local DROP_BAG_COLOR      = BrickColor.new("Khaki")
local DROP_BAG_MATERIAL   = Enum.Material.Fabric

-- Counter for unique drop IDs
local dropCounter = 0
local dropBags    = {}

RE_DropItem.OnServerEvent:Connect(function(player, itemData)
	-- Validate: must be a table with at least a name
	if type(itemData) ~= "table" then return end
	if type(itemData.name) ~= "string" or itemData.name == "" then return end

	-- Must be alive with a character
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Sanitize item data (never trust the client)
	local cleanItem = {
		name     = tostring(itemData.name):sub(1, 50),
		type     = tostring(itemData.type or "Misc"):sub(1, 20),
		quantity = math.clamp(tonumber(itemData.quantity) or 1, 1, 999),
		maxStack = math.clamp(tonumber(itemData.maxStack) or 1, 1, 999),
		iconId   = type(itemData.iconId) == "string" and itemData.iconId or "",
		data     = type(itemData.data) == "table" and itemData.data or {},
	}

	-- Spawn position: 3 studs in front of the player, on the ground
	local lookDir = hrp.CFrame.LookVector
	local dropPos = hrp.Position + Vector3.new(lookDir.X, 0, lookDir.Z).Unit * 3

	-- Create unique drop ID
	dropCounter = dropCounter + 1
	local dropId = "drop_" .. player.UserId .. "_" .. dropCounter

	-- Build the physical bag
	local part = Instance.new("Part")
	part.Name       = "DroppedItem"
	part.Size       = DROP_BAG_SIZE
	part.BrickColor = DROP_BAG_COLOR
	part.Material   = DROP_BAG_MATERIAL
	part.CFrame     = CFrame.new(dropPos + Vector3.new(0, DROP_BAG_SIZE.Y / 2 + 0.1, 0))
	part.Anchored   = true
	part.CanCollide = true
	part.CastShadow = true
	part.Parent     = workspace

	-- Tag
	local tag = Instance.new("StringValue", part)
	tag.Name  = "DropId"
	tag.Value = dropId

	-- Billboard label showing item name
	local billboard = Instance.new("BillboardGui", part)
	billboard.Size             = UDim2.new(0, 140, 0, 30)
	billboard.StudsOffset      = Vector3.new(0, 1, 0)
	billboard.AlwaysOnTop      = false
	billboard.MaxDistance       = 25

	local label = Instance.new("TextLabel", billboard)
	label.Size                  = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text                  = cleanItem.name
	label.TextColor3            = Color3.fromRGB(220, 210, 170)
	label.TextStrokeTransparency = 0.4
	label.Font                  = Enum.Font.GothamBold
	label.TextScaled            = true

	-- Quantity subtitle if more than 1
	if cleanItem.quantity > 1 then
		local qtyLabel = Instance.new("TextLabel", billboard)
		qtyLabel.Size                  = UDim2.new(1, 0, 0.5, 0)
		qtyLabel.Position              = UDim2.new(0, 0, 1, 0)
		qtyLabel.BackgroundTransparency = 1
		qtyLabel.Text                  = "x" .. cleanItem.quantity
		qtyLabel.TextColor3            = Color3.fromRGB(180, 175, 150)
		qtyLabel.TextStrokeTransparency = 0.5
		qtyLabel.Font                  = Enum.Font.Gotham
		qtyLabel.TextScaled            = true
	end

	-- Proximity prompt
	local prompt = Instance.new("ProximityPrompt", part)
	prompt.ActionText              = "Take"
	prompt.ObjectText              = cleanItem.name
	prompt.MaxActivationDistance   = DROP_BAG_PROMPT_DIST
	prompt.HoldDuration            = 0
	prompt.RequiresLineOfSight     = false
	prompt.KeyboardKeyCode         = Enum.KeyCode.E

	-- Store state
	dropBags[dropId] = {
		items = { cleanItem },
		part  = part,
	}

	-- Pickup handler: anyone can pick it up
	prompt.Triggered:Connect(function(picker)
		local bag = dropBags[dropId]
		if not bag then return end

		-- Send item to the picker via existing PickupResult flow
		RE_PickupResult:FireClient(picker, true, dropId, bag.items)

		-- Despawn
		dropBags[dropId] = nil
		part:Destroy()
	end)

	-- Auto-despawn after lifetime
	task.delay(DROP_BAG_LIFETIME, function()
		if dropBags[dropId] then
			dropBags[dropId] = nil
			if part and part.Parent then
				part:Destroy()
			end
		end
	end)

	print("[LootServer] " .. player.Name .. " dropped: " .. cleanItem.name
		.. " x" .. cleanItem.quantity)
end)

-- ============================================================
-- VISUAL CONFIG
-- ============================================================

-- Ground loot: small neon part sitting on the ground
local GROUND_PART_SIZE  = Vector3.new(0.5, 0.5, 0.5)
local GROUND_PART_COLOR = BrickColor.new("Bright yellow")
local GROUND_PART_MAT   = Enum.Material.SmoothPlastic

-- Chest: box model (swap PrimaryPart asset ID later)
local CHEST_SIZE        = Vector3.new(2, 1.5, 1)
local CHEST_COLOR       = BrickColor.new("Reddish brown")
local CHEST_MAT         = Enum.Material.Wood

-- Prompt config
local PROMPT_DISTANCE   = 8    -- studs, how close before E prompt shows
local PROMPT_HOLD_TIME  = 0    -- 0 = instant tap, raise for hold-to-loot

-- ============================================================
-- STATE
-- ============================================================
-- spawnState[spawnId] = {
--   part        : BasePart or nil (world object, nil when despawned)
--   prompt      : ProximityPrompt or nil
--   rolledItems : {item, ...} or nil  (chest only, rolled on spawn)
--   respawnAt   : number or nil       (tick() time to respawn)
--   active      : bool
-- }
local spawnState = {}

-- ============================================================
-- BUILD WORLD OBJECT
-- ============================================================
local function buildGroundPart(pos)
	local part = Instance.new("Part")
	part.Size         = GROUND_PART_SIZE
	part.BrickColor   = GROUND_PART_COLOR
	part.Material     = GROUND_PART_MAT
	part.CFrame       = CFrame.new(pos)
	part.Anchored     = true
	part.CanCollide   = false
	part.CastShadow   = false
	part.Name         = "LootPickup"
	part.Parent       = workspace
	return part
end

local function buildChest(pos)
	local part = Instance.new("Part")
	part.Size       = CHEST_SIZE
	part.BrickColor = CHEST_COLOR
	part.Material   = CHEST_MAT
	part.CFrame     = CFrame.new(pos)
	part.Anchored   = true
	part.CanCollide = true
	part.Name       = "LootChest"
	part.Parent     = workspace

	-- Simple lid to hint it's a chest
	local lid = Instance.new("Part", part)
	lid.Size       = Vector3.new(CHEST_SIZE.X, 0.2, CHEST_SIZE.Z)
	lid.BrickColor = BrickColor.new("Dark orange")
	lid.Material   = CHEST_MAT
	lid.CFrame     = part.CFrame * CFrame.new(0, CHEST_SIZE.Y / 2 + 0.1, 0)
	lid.Anchored   = true
	lid.CanCollide = false
	lid.Name       = "Lid"

	local weld = Instance.new("WeldConstraint", part)
	weld.Part0 = part
	weld.Part1 = lid

	return part
end

-- ============================================================
-- DESPAWN (after pickup)
-- Must be defined before attachPrompt which references it.
-- ============================================================
local function despawnLoot(spawnId)
	local state = spawnState[spawnId]
	if not state or not state.active then return end

	if state.part then
		state.part:Destroy()
		state.part   = nil
		state.prompt = nil
	end

	state.active      = false
	state.rolledItems = nil
	state.respawnAt   = tick() + LootTable.RESPAWN_TIME

	RE_LootRemoved:FireAllClients(spawnId)
end

local function attachPrompt(part, spawnId, spawnType)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText    = spawnType == "chest" and "Open" or "Take"
	prompt.ObjectText    = spawnType == "chest" and "Chest"  or "Loot"
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.HoldDuration  = PROMPT_HOLD_TIME
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent        = part

	prompt.Triggered:Connect(function(player)
		local state = spawnState[spawnId]
		if not state or not state.active then
			RE_PickupResult:FireClient(player, false, spawnId, nil)
			return
		end

		local items = state.rolledItems or {}

		-- Fire items to client and wait for acknowledgement of how many were accepted.
		-- We use a one-shot BindableEvent handshake keyed to this player + spawnId
		-- so we know whether to despawn or keep the loot for others.
		local ackEvent = Instance.new("BindableEvent")
		local ackCount = 0
		local ackDone  = false

		-- Client sends back accepted count via RE_PickupAck
		local conn
		conn = RE_PickupAck.OnServerEvent:Connect(function(ackPlayer, ackSpawnId, accepted)
			if ackPlayer ~= player or ackSpawnId ~= spawnId then return end
			conn:Disconnect()
			ackCount = accepted or 0
			ackDone  = true
			ackEvent:Fire()
		end)

		RE_PickupResult:FireClient(player, true, spawnId, items)

		-- Wait up to 3 seconds for ack
		local t = 0
		repeat task.wait(0.05); t = t + 0.05 until ackDone or t >= 3

		conn:Disconnect()  -- safety disconnect if timeout hit
		ackEvent:Destroy()

		if ackCount > 0 then
			-- At least one item made it in — despawn the loot
			despawnLoot(spawnId)
		end
		-- If ackCount == 0 (full inventory), loot stays for others to take
	end)

	return prompt
end

-- ============================================================
-- ROLL ITEMS FOR A SPAWN
-- ============================================================
local function rollItems(spawn)
	local items = {}

	if spawn.type == "ground" then
		-- Ground loot: always exactly one item
		local item = LootTable.Roll(spawn.tier, spawn.context)
		if item then table.insert(items, item) end

	elseif spawn.type == "chest" then
		-- Chest: roll count based on tier, then roll each item
		local countRange = LootTable.CHEST_COUNT[spawn.tier]
		local count = math.random(countRange.min, countRange.max)
		for _ = 1, count do
			local item = LootTable.Roll(spawn.tier, spawn.context)
			if item then table.insert(items, item) end
		end
	end

	return items
end

-- ============================================================
-- SPAWN A LOOT POINT
-- ============================================================
local function spawnLoot(spawn)
	local state = spawnState[spawn.id]
	if not state then return end
	if state.active then return end   -- already active

	local part
	if spawn.type == "ground" then
		part = buildGroundPart(spawn.pos)
	else
		part = buildChest(spawn.pos)
	end

	local prompt = attachPrompt(part, spawn.id, spawn.type)

	-- Roll items now (chest items revealed on pickup)
	local items = rollItems(spawn)

	state.part        = part
	state.prompt      = prompt
	state.rolledItems = items
	state.respawnAt   = nil
	state.active      = true

	-- Tag the part with the spawn id so client can identify it
	local tag = Instance.new("StringValue", part)
	tag.Name  = "SpawnId"
	tag.Value = spawn.id

	-- Notify all clients a loot point appeared
	RE_LootSpawned:FireAllClients(spawn.id, spawn.pos, spawn.type)

	print("[LootServer] Spawned " .. spawn.type .. " at " .. spawn.label)
end

-- ============================================================
-- RESPAWN LOOP
-- ============================================================
local RESPAWN_CHECK_INTERVAL = 5   -- check every 5 seconds
local lastCheck = 0

RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastCheck < RESPAWN_CHECK_INTERVAL then return end
	lastCheck = now

	for _, spawn in ipairs(SpawnData.SPAWNS) do
		local state = spawnState[spawn.id]
		if state and not state.active and state.respawnAt then
			if now >= state.respawnAt then
				spawnLoot(spawn)
			end
		end
	end
end)

-- ============================================================
-- INIT ? spawn all loot points at game start
-- ============================================================
for _, spawn in ipairs(SpawnData.SPAWNS) do
	-- Initialize state table for every spawn
	spawnState[spawn.id] = {
		part        = nil,
		prompt      = nil,
		rolledItems = nil,
		respawnAt   = nil,
		active      = false,
	}
	-- Stagger spawns slightly to avoid one-frame lag spike
	task.delay(0.05, function()
		spawnLoot(spawn)
	end)
end

print("[LootServer] Initialized. " .. #SpawnData.SPAWNS .. " spawn points registered.")