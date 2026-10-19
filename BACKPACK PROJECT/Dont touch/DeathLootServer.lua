--==================================================
-- DeathLootServer
-- Script ? ServerScriptService
--
-- Listens for player death, collects everything in
-- their inventory AND equipment via RemoteFunction,
-- then spawns a physical loot bag in the world that
-- any other player can walk up to and loot.
--
-- Bag contents are stored server-side; the client
-- triggers pickup through the existing LootRemotes
-- PickupResult flow so LootClient handles it cleanly.
--
-- PLACEMENT:  ServerScriptService
-- REQUIRES:   LootRemotes folder (created by LootServer)
--==================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")

-- ============================================================
-- REMOTES
-- We add two new remotes to the existing LootRemotes folder.
-- LootServer creates that folder on start; we wait for it.
-- ============================================================
local remotes = ReplicatedStorage:WaitForChild("LootRemotes", 15)
if not remotes then
	error("[DeathLootServer] LootRemotes folder not found. Is LootServer running?")
end

-- Client ? Server: "send me the contents of my inventory/equipment before I die"
-- We use a RemoteFunction so the server can block until it has the data.
local RF_RequestDropData = Instance.new("RemoteFunction", remotes)
RF_RequestDropData.Name  = "RequestDropData"

-- Server ? Client: a death bag appeared at this position with this bagId
local RE_BagSpawned = Instance.new("RemoteEvent", remotes)
RE_BagSpawned.Name  = "BagSpawned"

-- Server ? Client: a death bag was looted / expired
local RE_BagRemoved = Instance.new("RemoteEvent", remotes)
RE_BagRemoved.Name  = "BagRemoved"

local RF_GetDeathBagVicinity = Instance.new("RemoteFunction", remotes)
RF_GetDeathBagVicinity.Name  = "GetDeathBagVicinity"

local RF_TakeDeathBagItem = Instance.new("RemoteFunction", remotes)
RF_TakeDeathBagItem.Name  = "TakeDeathBagItem"

-- Reuse the existing PickupResult remote (already created by LootServer)
local RE_PickupResult = remotes:WaitForChild("PickupResult")

-- ============================================================
-- BAG CONFIG
-- ============================================================
local BAG_LIFETIME      = 120   -- seconds before an uncollected bag auto-despawns
local BAG_PROMPT_DIST   = 8     -- studs, how close before prompt shows
local BAG_SIZE          = Vector3.new(1.5, 1, 1)
local BAG_COLOR         = BrickColor.new("Sand red")
local BAG_MATERIAL      = Enum.Material.Fabric
local BAG_LABEL         = "Loot Bag"   -- ProximityPrompt object text

-- ============================================================
-- STATE
-- bagData[bagId] = { items = {...}, part = BasePart }
-- ============================================================
local bagData    = {}
local bagCounter = 0
local BAG_VICINITY_RADIUS = 14

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
		id       = item.id,
		name     = tostring(item.name):sub(1, 50),
		type     = tostring(item.type or "Misc"):sub(1, 20),
		quantity = math.max(1, tonumber(item.quantity) or 1),
		maxStack = math.max(1, tonumber(item.maxStack) or 1),
		iconId   = type(item.iconId) == "string" and item.iconId or "",
		data     = type(item.data) == "table" and deepCopy(item.data) or {},
	}
end

local function getPlayerRoot(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function isNearPlayer(player, part)
	local root = getPlayerRoot(player)
	if not root or not part then return false end
	return (part.Position - root.Position).Magnitude <= BAG_VICINITY_RADIUS
end

local function newBagId()
	bagCounter = bagCounter + 1
	return "deathbag_" .. bagCounter
end

-- ============================================================
-- SPAWN A BAG
-- ============================================================
local function spawnBag(position, items)
	if not items or #items == 0 then return end

	local bagId = newBagId()

	-- Physical part
	local part = Instance.new("Part")
	part.Name      = "DeathBag"
	part.Size      = BAG_SIZE
	part.BrickColor = BAG_COLOR
	part.Material  = BAG_MATERIAL
	part.CFrame    = CFrame.new(position + Vector3.new(0, BAG_SIZE.Y / 2 + 0.1, 0))
	part.Anchored  = true
	part.CanCollide = true
	part.CastShadow = true
	part.Parent    = workspace

	-- Tag with bagId so client can reference it
	local tag = Instance.new("StringValue", part)
	tag.Name  = "BagId"
	tag.Value = bagId

	-- Decorative label above the bag
	local billboard = Instance.new("BillboardGui", part)
	billboard.Size             = UDim2.new(0, 120, 0, 30)
	billboard.StudsOffset      = Vector3.new(0, 1.2, 0)
	billboard.AlwaysOnTop      = false
	billboard.MaxDistance      = 30

	local label = Instance.new("TextLabel", billboard)
	label.Size            = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text            = BAG_LABEL
	label.TextColor3      = Color3.fromRGB(255, 220, 100)
	label.TextStrokeTransparency = 0.4
	label.Font            = Enum.Font.GothamBold
	label.TextScaled      = true

	-- Proximity prompt
	local prompt = Instance.new("ProximityPrompt", part)
	prompt.ActionText    = "Loot"
	prompt.ObjectText    = BAG_LABEL
	prompt.MaxActivationDistance = BAG_PROMPT_DIST
	prompt.HoldDuration  = 0
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E

	-- Store state
	bagData[bagId] = {
		items = items,
		part  = part,
	}

	-- Triggered: give items to looting player then destroy bag
	prompt.Triggered:Connect(function(player)
		local bag = bagData[bagId]
		if not bag then return end  -- already looted

		-- Send items to the looting player via existing PickupResult flow
		RE_PickupResult:FireClient(player, true, bagId, bag.items)

		-- Despawn
		bagData[bagId] = nil
		part:Destroy()
		RE_BagRemoved:FireAllClients(bagId)
	end)

	-- Auto-despawn after lifetime expires
	task.delay(BAG_LIFETIME, function()
		if bagData[bagId] then
			bagData[bagId] = nil
			if part and part.Parent then
				part:Destroy()
			end
			RE_BagRemoved:FireAllClients(bagId)
			print("[DeathLootServer] Bag " .. bagId .. " expired.")
		end
	end)

	-- Notify all clients a bag appeared
	RE_BagSpawned:FireAllClients(bagId, position)

	print("[DeathLootServer] Spawned bag " .. bagId .. " with " .. #items .. " item(s).")
	return bagId
end

RF_GetDeathBagVicinity.OnServerInvoke = function(player)
	local root = getPlayerRoot(player)
	if not root then
		return {}
	end

	local entries = {}
	for bagId, bag in pairs(bagData) do
		if bag.part and isNearPlayer(player, bag.part) and bag.items and #bag.items > 0 then
			local entryItems = {}
			for _, item in ipairs(bag.items) do
				local safe = sanitizeClientItem(item)
				if safe then
					table.insert(entryItems, safe)
				end
			end

			if #entryItems > 0 then
				table.insert(entries, {
					sourceId   = bagId,
					sourceType = "death_bag",
					label      = BAG_LABEL,
					position   = bag.part.Position,
					distance   = (bag.part.Position - root.Position).Magnitude,
					items      = entryItems,
				})
			end
		end
	end

	table.sort(entries, function(a, b)
		return (a.distance or math.huge) < (b.distance or math.huge)
	end)

	return entries
end

RF_TakeDeathBagItem.OnServerInvoke = function(player, bagId, itemIndex)
	itemIndex = tonumber(itemIndex) or 1

	local bag = bagData[bagId]
	if not bag or not bag.part then
		return false, "Bag unavailable"
	end

	if not isNearPlayer(player, bag.part) then
		return false, "Too far away"
	end

	local item = bag.items and bag.items[itemIndex]
	if not item then
		return false, "Missing item"
	end

	table.remove(bag.items, itemIndex)
	if #bag.items <= 0 then
		bagData[bagId] = nil
		if bag.part and bag.part.Parent then
			bag.part:Destroy()
		end
		RE_BagRemoved:FireAllClients(bagId)
	end

	return true, sanitizeClientItem(item)
end

-- ============================================================
-- COLLECT DROP DATA FROM CLIENT
-- The client knows its own inventory/equipment state since
-- InventoryModule and EquipmentModule are client-side data layers.
-- We invoke the client right before death resolves so it can
-- hand us the full item list to drop.
-- ============================================================
local function collectDropItems(player)
	local ok, result = pcall(function()
		-- Give client 3 seconds to respond before we give up
		return RF_RequestDropData:InvokeClient(player)
	end)

	if not ok or type(result) ~= "table" then
		warn("[DeathLootServer] Failed to collect drop data from " .. player.Name)
		return {}
	end

	-- Sanitise: make sure every item at least has a name and type
	local clean = {}
	for _, item in ipairs(result) do
		if type(item) == "table" and type(item.name) == "string" and item.name ~= "" then
			table.insert(clean, {
				name     = item.name,
				type     = item.type     or "Misc",
				quantity = math.max(1, tonumber(item.quantity) or 1),
				maxStack = math.max(1, tonumber(item.maxStack) or 1),
				iconId   = item.iconId   or "",
				data     = type(item.data) == "table" and item.data or {},
			})
		end
	end

	return clean
end

-- ============================================================
-- DEATH HANDLING
-- ============================================================
local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	-- HumanoidRootPart may not exist yet; wait for it
	local hrp = character:WaitForChild("HumanoidRootPart", 5)

	humanoid.Died:Connect(function()
		-- Find the owning player
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		-- Grab the drop position before character is cleaned up
		local dropPos = hrp and hrp.Position or Vector3.new(0, 5, 0)

		-- Collect items from the client
		local items = collectDropItems(player)

		-- Spawn bag if there's anything to drop
		if #items > 0 then
			spawnBag(dropPos, items)
		else
			print("[DeathLootServer] " .. player.Name .. " had nothing to drop.")
		end
	end)
end

-- ============================================================
-- PLAYER HOOKS
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(character)
	end)

	-- Handle players already in-game when this script runs
	if player.Character then
		onCharacterAdded(player.Character)
	end
end)

-- Handle players already in-game
for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

print("[DeathLootServer] Initialized. Watching for player deaths.")
